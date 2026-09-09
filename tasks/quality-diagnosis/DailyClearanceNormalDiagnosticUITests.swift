import XCTest

/// Unregistered, unrun diagnostic draft. Normal daily-clearance entry; no state reset or board fixture.
final class DailyClearanceNormalDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var output: URL!
    private let runID = UUID().uuidString

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        // Preserve current screen and AX before termination, including failed assertions.
        defer { app?.terminate() }
        if app != nil { try capture("terminal") }
    }

    func testNormalAutomaticBreakReturnAndResumePreservesHUD() throws {
        let env = ProcessInfo.processInfo.environment
        func value(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        XCTAssertEqual(value("QD_DAILY_BOUNDARY"), "NEW_DEDICATED_GUEST_SIMULATOR")
        let expectedDevice = try XCTUnwrap(value("QD_DAILY_DEVICE_UDID"))
        _ = try XCTUnwrap(UUID(uuidString: expectedDevice))
        let actualDevice = try XCTUnwrap(env["SIMULATOR_UDID"])
        XCTAssertEqual(actualDevice.lowercased(), expectedDevice.lowercased(), "Runner must be on the authorized new device")
        output = URL(fileURLWithPath: try XCTUnwrap(value("QD_SHOT_DIR")), isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        // Deliberately avoid launchClean's resetDebugPremium and all daily-clearance reset arguments.
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES", "-forceNonPremium", "-v51.followSystemAppearance"]
        app = application
        application.launch()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 15))
        application.switchTab(.profile)
        XCTAssertTrue(application.buttons["profile.login"].waitForExistence(timeout: 12), "Must be a guest, with no synthetic or real authenticated account")
        application.switchTab(.training)
        let entry = application.buttons["trainingHome.dailyClearance"]
        try revealHomeEntry(entry)
        try capture("home-unstarted")
        XCTAssertTrue(entry.label.contains("未开始"), "Existing draft/completion is a boundary failure; never reset it")
        let initialHomeLabel = entry.label
        try tap(entry)
        XCTAssertTrue(application.navigationBars["每日清台"].waitForExistence(timeout: 15))
        try capture("entered-real-auto-break")

        // HUD is only displayed outside break mode. A failed/unsettled break can also expose
        // it, so require real stage, no auto/manual break UI, and no failure/replay CTA below.
        let hud = application.descendants(matching: .any).matching(identifier: "dailyClearance.hud").firstMatch
        let reachedHUD = hud.waitForExistence(timeout: 45)
        try capture("automatic-break-wait-result")
        XCTAssertTrue(reachedHUD, "Retain timeout evidence; do not inject fixtureSettled or retry with another seed")
        try assertPlayablePresentation()
        let before = try readHUD(hud)
        XCTAssertTrue(initialHomeLabel.contains(before.game))
        XCTAssertEqual(before.shots, 0, "Automatic break is the question setup, not a user shot")
        XCTAssertEqual(before.fouls, 0, "Automatic break does not count as a user foul")
        XCTAssertGreaterThan(before.remaining, 0, "A playable board must retain object balls")
        print("[QD-Daily] beforeReturn \(before) monotonic=\(ProcessInfo.processInfo.systemUptime)")
        try capture("settled-hud-before-return")

        let navigation = application.navigationBars["每日清台"]
        XCTAssertTrue(navigation.exists)
        try tap(navigation.buttons.firstMatch)
        XCTAssertTrue(navigation.waitForNonExistence(timeout: 12))
        try revealHomeEntry(entry)
        try capture("home-in-progress")
        XCTAssertTrue(entry.label.contains("进行中"))
        XCTAssertTrue(entry.label.contains(before.game))
        XCTAssertFalse(entry.label.contains("已完成"))
        try tap(entry)
        XCTAssertTrue(navigation.waitForExistence(timeout: 12))
        XCTAssertTrue(hud.waitForExistence(timeout: 15))
        try assertPlayablePresentation()
        let after = try readHUD(hud)
        try capture("resumed-hud")
        XCTAssertEqual(after.game, before.game)
        XCTAssertEqual(after.remaining, before.remaining)
        XCTAssertEqual(after.shots, before.shots)
        XCTAssertEqual(after.fouls, before.fouls)
        XCTAssertGreaterThanOrEqual(after.seconds, before.seconds, "Elapsed HUD may advance; it must not reset")
        print("[QD-Daily] afterReentry \(after) monotonic=\(ProcessInfo.processInfo.systemUptime)")
        // No user shot, completion, replay, process relaunch or independent board-coordinate proof here.
    }

    func testExistingDraftEarlyEightFailureReentryAndExplicitRerack() throws {
        let env = ProcessInfo.processInfo.environment
        func value(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        XCTAssertEqual(value("QD_DAILY_BOUNDARY"), "EXISTING_004_GUEST_DRAFT_0_SHOTS_VERIFIED")
        XCTAssertEqual(env["SIMULATOR_UDID"], try XCTUnwrap(value("QD_DAILY_DEVICE_UDID")))
        output = URL(fileURLWithPath: try XCTUnwrap(value("QD_SHOT_DIR")), isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-forceNonPremium", "-v51.followSystemAppearance"]
        app = application; application.launch()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 15))
        application.switchTab(.profile)
        XCTAssertTrue(application.buttons["profile.login"].waitForExistence(timeout: 12))
        application.switchTab(.training)
        let entry = application.buttons["trainingHome.dailyClearance"]
        try revealHomeEntry(entry)
        XCTAssertTrue(entry.label.contains("进行中"))
        try tap(entry)
        let hud = application.descendants(matching: .any)["dailyClearance.hud"].firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 15))
        try assertPlayablePresentation()
        let before = try readHUD(hud)
        XCTAssertEqual(before.shots, 0); XCTAssertEqual(before.fouls, 0); XCTAssertEqual(before.remaining, 14)
        try capture("existing-draft-before-real-eight-shot")
        // SceneKit tree nodes are present in debugDescription while XCUI's
        // identifier convenience query resolves the palette label instead.
        let tree = application.debugDescription
        let pattern = #"\{\{([0-9.]+), ([0-9.]+)\}, \{([0-9.]+), ([0-9.]+)\}\}, identifier: '_8'"#
        let expression = try NSRegularExpression(pattern: pattern)
        let match = try XCTUnwrap(expression.firstMatch(in: tree, range: NSRange(tree.startIndex..., in: tree)))
        func scalar(_ index: Int) throws -> CGFloat {
            let range = try XCTUnwrap(Range(match.range(at: index), in: tree))
            return CGFloat(try XCTUnwrap(Double(tree[range])))
        }
        let frame = try CGRect(x: scalar(1), y: scalar(2), width: scalar(3), height: scalar(4))
        XCTAssertEqual(frame.midX, 95.45, accuracy: 1)
        XCTAssertEqual(frame.midY, 231.15, accuracy: 1)
        XCTAssertLessThan(frame.width, 20)
        application.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        // Pocket measured on this exact402x874 normal persisted board.
        XCTAssertEqual(application.windows.firstMatch.frame.size, CGSize(width: 402, height: 874))
        application.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 71.6, dy: 201)).tap()
        try capture("eight-pocket-selected-before-strike")
        try tap(application.buttons["击球"])
        let rerack = application.buttons["dailyClearance.rerack"]
        XCTAssertTrue(rerack.waitForExistence(timeout: 60), "Actual early-eight candidate must reach failure; retain real shot outcome if it does not")
        let failed = try readHUD(hud)
        XCTAssertEqual(failed.shots, 1)
        try capture("actual-eight-shot-failed")
        print("[QD-Daily] actualFailure \(failed)")
        try tap(application.navigationBars["每日清台"].buttons.firstMatch)
        try revealHomeEntry(entry); try tap(entry)
        XCTAssertTrue(rerack.waitForExistence(timeout: 15))
        let restored = try readHUD(hud)
        XCTAssertEqual(restored.shots, failed.shots)
        XCTAssertEqual(restored.fouls, failed.fouls)
        XCTAssertEqual(restored.remaining, failed.remaining)
        try capture("failed-draft-reentered")
        try tap(rerack)
        let destructive = application.buttons["放弃并重新开球"].firstMatch
        XCTAssertTrue(destructive.waitForExistence(timeout: 8))
        try capture("rerack-confirmation")
        try tap(application.buttons["取消"].firstMatch)
        XCTAssertTrue(rerack.exists)
        XCTAssertEqual(try readHUD(hud).shots, 1)
        try capture("rerack-cancel-keeps-failure")
        try tap(rerack); try tap(destructive)
        XCTAssertTrue(rerack.waitForNonExistence(timeout: 12))
        XCTAssertTrue(hud.waitForExistence(timeout: 45))
        try assertPlayablePresentation()
        let fresh = try readHUD(hud)
        XCTAssertEqual(fresh.shots, 0); XCTAssertEqual(fresh.fouls, 0)
        XCTAssertGreaterThan(fresh.remaining, 0)
        try capture("explicit-rerack-new-playable-board")
        print("[QD-Daily] explicitRerack \(fresh)")
    }

    func testExistingDraftLegalShotCountReentryAndRerackCancel() throws {
        let env = ProcessInfo.processInfo.environment
        func value(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        XCTAssertEqual(value("QD_DAILY_BOUNDARY"), "EXISTING_004_GUEST_DRAFT_0_SHOTS_VERIFIED")
        XCTAssertEqual(env["SIMULATOR_UDID"], try XCTUnwrap(value("QD_DAILY_DEVICE_UDID")))
        output = URL(fileURLWithPath: try XCTUnwrap(value("QD_SHOT_DIR")), isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-forceNonPremium", "-v51.followSystemAppearance"]
        app = application; application.launch()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 15))
        application.switchTab(.profile)
        XCTAssertTrue(application.buttons["profile.login"].waitForExistence(timeout: 12))
        application.switchTab(.training)
        let entry = application.buttons["trainingHome.dailyClearance"]
        try revealHomeEntry(entry)
        XCTAssertTrue(entry.label.contains("进行中"))
        try tap(entry)
        let hud = application.descendants(matching: .any)["dailyClearance.hud"].firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 15))
        try assertPlayablePresentation()
        let before = try readHUD(hud)
        XCTAssertEqual(before.shots, 0); XCTAssertEqual(before.fouls, 0); XCTAssertEqual(before.remaining, 14)
        try capture("existing-draft-before-real-legal-shot")
        // SceneKit tree nodes are present in debugDescription while XCUI's
        // identifier convenience query resolves the palette label instead.
        let tree = application.debugDescription
        let pattern = #"\{\{([0-9.]+), ([0-9.]+)\}, \{([0-9.]+), ([0-9.]+)\}\}, identifier: '_1'"#
        let expression = try NSRegularExpression(pattern: pattern)
        let match = try XCTUnwrap(expression.firstMatch(in: tree, range: NSRange(tree.startIndex..., in: tree)))
        func scalar(_ index: Int) throws -> CGFloat {
            let range = try XCTUnwrap(Range(match.range(at: index), in: tree))
            return CGFloat(try XCTUnwrap(Double(tree[range])))
        }
        let frame = try CGRect(x: scalar(1), y: scalar(2), width: scalar(3), height: scalar(4))
        XCTAssertEqual(frame.midX, 310.2, accuracy: 1)
        XCTAssertEqual(frame.midY, 371.1, accuracy: 1)
        XCTAssertLessThan(frame.width, 20)
        application.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        // Pocket measured on this exact402x874 normal persisted board.
        XCTAssertEqual(application.windows.firstMatch.frame.size, CGSize(width: 402, height: 874))
        application.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 333, dy: 454)).tap()
        try capture("legal-pocket-selected-before-strike")
        try tap(application.buttons["击球"])
        let advanced = NSPredicate { [weak self] _, _ in
            guard let self, let reading = try? self.readHUD(hud) else { return false }
            return reading.shots == 1
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: advanced, object: hud)], timeout: 60), .completed)
        let after = try readHUD(hud)
        XCTAssertEqual(after.shots, 1)
        XCTAssertLessThanOrEqual(after.remaining, before.remaining)
        try capture("actual-legal-shot-settled")
        print("[QD-Daily] actualLegalShot \(after)")
        try tap(application.navigationBars["每日清台"].buttons.firstMatch)
        try revealHomeEntry(entry); try tap(entry)
        XCTAssertTrue(hud.waitForExistence(timeout: 15))
        let restored = try readHUD(hud)
        XCTAssertEqual(restored.shots, after.shots)
        XCTAssertEqual(restored.fouls, after.fouls)
        XCTAssertEqual(restored.remaining, after.remaining)
        try capture("actual-legal-shot-disk-reentry")
        try tap(application.buttons["freeplay.moreMenu"])
        try tap(application.buttons["dailyClearance.rerackMenu"])
        XCTAssertTrue(application.buttons["放弃并重新开球"].waitForExistence(timeout: 8))
        try capture("played-rerack-confirmation")
        try tap(application.buttons["取消"].firstMatch)
        XCTAssertEqual(try readHUD(hud).shots, 1)
        try capture("played-rerack-cancel-keeps-shot")
    }

    func testPlayedDraftRerackDismissAndConfirmNewBoard() throws {
        let env = ProcessInfo.processInfo.environment
        func value(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        XCTAssertEqual(value("QD_DAILY_BOUNDARY"), "EXISTING_004_GUEST_DRAFT_1_SHOT_VERIFIED")
        XCTAssertEqual(env["SIMULATOR_UDID"], try XCTUnwrap(value("QD_DAILY_DEVICE_UDID")))
        output = URL(fileURLWithPath: try XCTUnwrap(value("QD_SHOT_DIR")), isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-forceNonPremium", "-v51.followSystemAppearance"]
        app = application; application.launch()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 15))
        application.switchTab(.profile)
        XCTAssertTrue(application.buttons["profile.login"].waitForExistence(timeout: 12))
        application.switchTab(.training)
        let entry = application.buttons["trainingHome.dailyClearance"]
        try revealHomeEntry(entry)
        XCTAssertTrue(entry.label.contains("进行中"))
        try tap(entry)
        let hud = application.descendants(matching: .any)["dailyClearance.hud"].firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 15))
        try assertPlayablePresentation()
        let before = try readHUD(hud)
        XCTAssertEqual(before.shots, 1); XCTAssertEqual(before.fouls, 0); XCTAssertEqual(before.remaining, 14)
        try capture("existing-draft-before-real-legal-shot")
        try tap(application.buttons["freeplay.moreMenu"])
        try tap(application.buttons["dailyClearance.rerackMenu"])
        let destructive = application.buttons["放弃并重新开球"].firstMatch
        XCTAssertTrue(destructive.waitForExistence(timeout: 8))
        let dismiss = application.otherElements["PopoverDismissRegion"].firstMatch
        XCTAssertTrue(dismiss.exists)
        XCTAssertEqual(dismiss.frame, CGRect(x: 0, y: 0, width: 402, height: 874))
        try capture("played-confirm-before-dismiss")
        // Observed empty chrome outside popover81...321x72...299, away from
        // Back/More buttons and the scene. Do not use full-screen center tap.
        dismiss.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 390, dy: 120)).tap()
        XCTAssertTrue(destructive.waitForNonExistence(timeout: 8))
        XCTAssertEqual(try readHUD(hud).shots, 1)
        try capture("played-dismiss-keeps-state")
        try tap(application.buttons["freeplay.moreMenu"])
        try tap(application.buttons["dailyClearance.rerackMenu"])
        try tap(destructive)
        let playable = NSPredicate { _, _ in
            hud.exists && !application.descendants(matching: .any)["dailyClearance.autoBreaking"].exists &&
            !application.descendants(matching: .any)["dailyClearance.breakStatus"].exists &&
            !application.buttons["dailyClearance.rerack"].exists
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: playable, object: hud)], timeout: 60), .completed)
        try assertPlayablePresentation()
        let fresh = try readHUD(hud)
        XCTAssertEqual(fresh.shots, 0); XCTAssertEqual(fresh.fouls, 0)
        XCTAssertGreaterThan(fresh.remaining, 0)
        try capture("confirmed-rerack-new-playable")
        print("[QD-Daily] confirmedRerack \(fresh)")
    }

    func testPersistedManualRackActualBreakReturnsPlayable() throws {
        let env = ProcessInfo.processInfo.environment
        func value(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        XCTAssertEqual(value("QD_DAILY_BOUNDARY"), "EXISTING_004_MANUAL_RACK_VERIFIED")
        XCTAssertEqual(env["SIMULATOR_UDID"], try XCTUnwrap(value("QD_DAILY_DEVICE_UDID")))
        output = URL(fileURLWithPath: try XCTUnwrap(value("QD_SHOT_DIR")), isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-forceNonPremium", "-v51.followSystemAppearance"]
        app = application; application.launch()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 15))
        application.switchTab(.profile)
        XCTAssertTrue(application.buttons["profile.login"].waitForExistence(timeout: 12))
        application.switchTab(.training)
        let entry = application.buttons["trainingHome.dailyClearance"]
        try revealHomeEntry(entry)
        XCTAssertTrue(entry.label.contains("进行中"))
        try tap(entry)
        let status = application.descendants(matching: .any)["dailyClearance.breakStatus"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 15))
        XCTAssertTrue(status.label.contains("待手动开球"))
        try capture("persisted-manual-rack")
        try tap(application.buttons["break.strike"])
        let hud = application.descendants(matching: .any)["dailyClearance.hud"].firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 60))
        try assertPlayablePresentation()
        let fresh = try readHUD(hud)
        XCTAssertEqual(fresh.shots, 0); XCTAssertEqual(fresh.fouls, 0)
        XCTAssertGreaterThan(fresh.remaining, 0)
        try capture("actual-manual-break-playable")
        print("[QD-Daily] actualManualBreak \(fresh)")
    }

    func testPersistedManualRackStrikeConfirmAndResume() throws {
        let env = ProcessInfo.processInfo.environment
        func value(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        XCTAssertEqual(value("QD_DAILY_BOUNDARY"), "EXISTING_004_MANUAL_RACK_VERIFIED")
        XCTAssertEqual(env["SIMULATOR_UDID"], try XCTUnwrap(value("QD_DAILY_DEVICE_UDID")))
        output = URL(fileURLWithPath: try XCTUnwrap(value("QD_SHOT_DIR")), isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-forceNonPremium", "-v51.followSystemAppearance"]
        app = application; application.launch()
        XCTAssertTrue(application.wait(for: .runningForeground, timeout: 15))
        application.switchTab(.profile)
        XCTAssertTrue(application.buttons["profile.login"].waitForExistence(timeout: 12))
        let trainingTab = application.tabBars.buttons["训练"]
        try tap(trainingTab)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "selected == true"), object: trainingTab)], timeout: 8), .completed)

        let entry = application.buttons["trainingHome.dailyClearance"]
        try revealHomeEntry(entry)
        XCTAssertTrue(entry.label.contains("进行中"))
        try tap(entry)
        let status = application.descendants(matching: .any)["dailyClearance.breakStatus"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 15))
        XCTAssertTrue(status.label.contains("待手动开球"))
        try capture("persisted-manual-rack")
        try tap(application.buttons["break.strike"])
        let confirm = application.buttons["break.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 45))
        XCTAssertTrue(confirm.isEnabled)
        try capture("manual-break-settled-before-confirm")
        try tap(confirm)
        let hud = application.descendants(matching: .any)["dailyClearance.hud"].firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 15))
        try assertPlayablePresentation()
        let fresh = try readHUD(hud)
        XCTAssertEqual(fresh.shots, 0); XCTAssertEqual(fresh.fouls, 0)
        XCTAssertGreaterThan(fresh.remaining, 0)
        try capture("actual-manual-break-playable")
        try tap(application.buttons["BackButton"])
        try revealHomeEntry(entry)
        try tap(entry)
        XCTAssertTrue(hud.waitForExistence(timeout: 15))
        try assertPlayablePresentation()
        let resumed = try readHUD(hud)
        XCTAssertEqual(resumed.remaining, fresh.remaining)
        XCTAssertEqual(resumed.shots, fresh.shots)
        XCTAssertEqual(resumed.fouls, fresh.fouls)
        try capture("manual-break-confirmed-reentry")
        print("[QD-Daily] actualManualBreak \(fresh)")
    }

    private struct HUD: CustomStringConvertible {
        let game: String
        let remaining: Int
        let shots: Int
        let fouls: Int
        let seconds: Int
        var description: String { "game=\(game) remaining=\(remaining) shots=\(shots) fouls=\(fouls) seconds=\(seconds)" }
    }

    private func readHUD(_ element: XCUIElement) throws -> HUD {
        let label = element.label
        let regex = try NSRegularExpression(pattern: "^每日清台，(.+)，剩余 ([0-9]+) 球，([0-9]+) 杆，([0-9]+) 次犯规，用时 ([0-9]+):([0-9]{2})$")
        let match = try XCTUnwrap(regex.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)), "Unexpected actual HUD label: \(label)")
        func field(_ n: Int) throws -> String { String(label[try XCTUnwrap(Range(match.range(at: n), in: label))]) }
        let minute = try XCTUnwrap(Int(try field(5)))
        let second = try XCTUnwrap(Int(try field(6)))
        XCTAssertLessThan(second, 60)
        return HUD(game: try field(1), remaining: try XCTUnwrap(Int(try field(2))),
                   shots: try XCTUnwrap(Int(try field(3))), fouls: try XCTUnwrap(Int(try field(4))),
                   seconds: minute * 60 + second)
    }

    private func assertPlayablePresentation() throws {
        let application = try XCTUnwrap(app)
        XCTAssertTrue(application.descendants(matching: .any).matching(identifier: "freeplay.stage").firstMatch.exists)
        for identifier in ["dailyClearance.autoBreaking", "dailyClearance.breakStatus", "dailyClearance.rerack", "dailyClearance.replay"] {
            XCTAssertFalse(application.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists, "Unexpected non-playing state: \(identifier)")
        }
        XCTAssertFalse(application.staticTexts["玩家 A"].exists)
        XCTAssertFalse(application.staticTexts["玩家 B"].exists)
    }

    private func revealHomeEntry(_ element: XCUIElement) throws {
        let application = try XCTUnwrap(app)
        let bar = application.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 8), "This candidate is scoped to a new iPhone device with a real bottom TabBar")
        for _ in 0..<6 {
            if element.exists {
                let frame = element.frame
                let window = application.windows.firstMatch.frame
                if !frame.isEmpty, window.contains(frame), frame.maxY < bar.frame.minY, element.isHittable { return }
            }
            application.swipeUp()
        }
        try capture("home-entry-not-fully-exposed")
        XCTFail("Daily-clearance entry must be fully visible above the actual TabBar before tapping")
    }

    private func tap(_ element: XCUIElement) throws {
        let predicate = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        let outcome = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 12)
        if outcome != .completed { try capture("tap-unavailable") }
        XCTAssertEqual(outcome, .completed)
        element.tap()
    }

    private func capture(_ stage: String) throws {
        let application = try XCTUnwrap(app)
        let stem = "daily-normal-\(runID)-\(stage)"
        let screenshot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: screenshot)
        image.name = stem; image.lifetime = .keepAlways; add(image)
        try screenshot.pngRepresentation.write(to: output.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = application.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
