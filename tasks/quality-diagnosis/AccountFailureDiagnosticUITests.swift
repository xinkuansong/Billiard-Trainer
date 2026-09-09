import XCTest

/// Unregistered/unrun. Existing snapshot004 identity-only fixture blocks APIClient before transport.
final class AccountFailureDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var directory: URL!
    private let runID = UUID().uuidString
    private var captureIndex = 0
    private let fixture = "-v53.authenticatedProfileFixture"
    private let oldName = "服务端球友"
    private enum Failure: Error { case requirement(String) }

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil { try capture("terminal-unclassified") }
    }

    func testOfflineProfileFailureDeletionFailureAndLogoutPreserveIdentityBoundaries() throws {
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_ACCOUNT_FAILURE_AUTH") == "NEW_DEDICATED_OFFLINE_FIXTURE_SIMULATOR", "Require new isolated simulator authorization")
        guard let expected = setting("QD_ACCOUNT_FAILURE_UDID"), UUID(uuidString: expected) != nil,
              let actual = env["SIMULATOR_UDID"], actual.lowercased() == expected.lowercased()
        else { throw Failure.requirement("Actual runner UDID must equal the authorized new device") }
        try require(setting("QD_ACCOUNT_API_GUARD") == "SNAPSHOT004_REQUESTDATA_PRETRANSPORT_THROW_VERIFIED",
                    "Orchestrator must verify frozen APIClient Debug fixture guard before enabling account mutations")
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/") else { throw Failure.requirement("Absolute evidence directory required") }
        directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Establish guest first on this newly created device; do not read or clear credentials.
        try launch(useFixture: false)
        try guest()
        try capture("initial-new-device-guest")
        try terminate()
        try launch(useFixture: true)
        try identity()
        try capture("offline-fixture-identity")

        try openProfilePage("个人信息")
        try fixtureRequired()
        let nameButton = app!.buttons["personalInfo.displayNameButton"]
        try require(nameButton.label.contains(oldName), "Original normalized name must be present before editing")
        try tap(nameButton)
        let field = app!.textFields["personalInfo.displayNameField"]
        try tap(field)
        let typingIntro = app!.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if typingIntro.waitForExistence(timeout: 2) {
            try tapUnique("Continue")
            try disappears(typingIntro)
        }
        try require(field.value as? String == oldName, "Only the fixture's own original name may be edited")
        // The contract needs a valid changed name, not an assumed caret or full replacement.
        // Verify one literal insertion preserves every original character before saving.
        let insertion = "QD" + String(runID.prefix(4))
        field.typeText(insertion)
        guard let candidate = field.value as? String else { throw Failure.requirement("Missing actual editor value") }
        try require(candidate.components(separatedBy: insertion).count == 2 && candidate.replacingOccurrences(of: insertion, with: "") == oldName,
                    "Actual changed name must contain exactly one insertion and preserve the original name")
        try capture("valid-new-name-before-save")
        try tap(app!.buttons["personalInfo.displayNameSave"])
        let profileError = app!.alerts["个人资料未保存"]
        try exists(profileError)
        // The title and dismissal action are source-backed; OS-localized URLError text is observed only.
        try capture("profile-request-failed-alert")
        try tap(profileError.buttons["知道了"])
        try disappears(profileError)
        try back()
        try identity()
        try openProfilePage("个人信息")
        try exists(nameButton)
        try require(nameButton.label.contains(oldName) && !nameButton.label.contains(candidate), "Failed save must retain the old committed name on reopen")
        try capture("profile-reopened-old-name")
        try back()
        try identity()

        try openProfilePage("偏好设置")
        let deletion = app!.staticTexts["注销账号"].firstMatch
        try reveal(deletion)
        try fixtureRequired()
        try tap(deletion)
        try exists(app!.buttons["确认注销"])
        try capture("delete-confirmation-before-cancel")
        // iOS26.2 presents this confirmation as a popover with outside dismissal,
        // not a Cancel button. Use its observed accessibility dismissal region.
        let dismiss = app!.otherElements["PopoverDismissRegion"]
        let popover = app!.popovers.firstMatch
        try exists(dismiss); try exists(popover)
        let center = CGPoint(x: dismiss.frame.midX, y: dismiss.frame.midY)
        try require(!popover.frame.contains(center), "Dismissal region center must be outside confirmation popover")
        try tap(dismiss)
        try disappears(app!.buttons["确认注销"])
        try back()
        try identity()
        try capture("delete-cancel-keeps-fixture-account")

        try openProfilePage("偏好设置")
        try reveal(deletion)
        try fixtureRequired()
        try tap(deletion)
        try tap(app!.buttons["确认注销"])
        let deleteError = app!.alerts["注销失败"]
        try exists(deleteError)
        try capture("account-delete-fixed-offline-failure")
        try fixtureRequired()
        try tap(deleteError.buttons["重试"])
        // Failure flag is reset synchronously before a Task; its absence may be too brief for AX.
        // Preserve the actual retry tap and post-idle alert, never require a fabricated transient frame.
        try exists(deleteError)
        try exists(deleteError.buttons["重试"])
        try capture("account-delete-retry-still-failed")
        try tap(deleteError.buttons["取消"])
        try disappears(deleteError)
        try back()
        try identity()
        try capture("delete-failure-cancel-keeps-fixture-identity")

        try fixtureRequired()
        let logout = app!.buttons["退出登录"]
        try reveal(logout)
        try tap(logout)
        try guest()
        try capture("logout-guest-in-same-process")
        try terminate()
        // Keeping the fixture would deliberately authenticate again at bootstrap.
        try launch(useFixture: false)
        try guest()
        try capture("verified-guest-relaunch-with-fixture-removed")
        print("[QD-AccountFailure] normal profile failure retained old name; delete cancel/failure/retry retained synthetic identity; logout guest and non-fixture restart guest; no successful server deletion or recovery claimed")
    }

    private func launch(useFixture: Bool) throws {
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES", "-v50.inMemoryStore", "-forceNonPremium", "-v51.followSystemAppearance"]
        if useFixture { application.launchArguments.append(fixture) }
        app = application
        application.launch()
        try require(application.wait(for: .runningForeground, timeout: 15), "App must reach foreground")
        try exists(application.tabBars.firstMatch)
        try tap(application.tabBars.firstMatch.buttons["我的"])
    }
    private func terminate() throws {
        app!.terminate()
        try require(app!.wait(for: .notRunning, timeout: 10), "Old process must be stopped")
    }
    private func fixtureRequired() throws {
        try require(app?.launchArguments.contains(fixture) == true, "Mutation is permitted only with the existing pretransport offline guard")
    }
    private func identity() throws {
        try fixtureRequired()
        let header = app!.buttons["profile.accountHeader"]
        try exists(header)
        try require(header.label == "个人信息，" + oldName, "Require exact synthetic normalized identity, not any logged-in user")
        try require(!app!.buttons["profile.login"].exists, "Unexpected guest after failed account operation")
    }
    private func guest() throws {
        let login = app!.buttons["profile.login"]
        try exists(login)
        try require(login.label.contains("游客模式"), "Must display the actual guest state")
        try require(!app!.descendants(matching: .any).matching(identifier: "profile.accountHeader").firstMatch.exists,
                    "Authenticated header must be absent")
    }
    private func openProfilePage(_ title: String) throws {
        let row = app!.staticTexts[title].firstMatch
        try reveal(row)
        try tap(row)
        try exists(app!.navigationBars[title])
    }
    private func reveal(_ target: XCUIElement) throws {
        for _ in 0..<10 {
            let window = app!.windows.firstMatch.frame
            let nav = app!.navigationBars.firstMatch
            let top = nav.exists ? nav.frame.maxY : window.minY
            let bar = app!.tabBars.firstMatch
            let bottom = bar.exists ? bar.frame.minY : window.maxY
            if target.exists, !target.frame.isEmpty, target.isHittable,
               window.contains(target.frame), target.frame.minY >= top, target.frame.maxY < bottom { return }
            let scrolls = app!.scrollViews.allElementsBoundByIndex.filter { $0.frame.height > $0.frame.width }
            try require(scrolls.count == 1, "Need one actual vertical scroll surface; do not guess coordinates")
            let scroll = scrolls[0]
            let upper = max(top, scroll.frame.minY), lower = min(bottom, scroll.frame.maxY)
            try require(lower > upper, "No unobstructed scroll area")
            let sign: CGFloat = target.exists && target.frame.minY < upper ? -1 : 1
            let delta = (lower - upper) / 8, middle = (upper + lower) / 2
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let from = origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: middle + sign * delta / 2 - scroll.frame.minY))
            let to = origin.withOffset(CGVector(dx: scroll.frame.width / 2, dy: middle - sign * delta / 2 - scroll.frame.minY))
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        throw Failure.requirement("Target not fully exposed: \(target)")
    }
    private func back() throws { try tap(app!.navigationBars.buttons.firstMatch) }
    private func tapUnique(_ label: String) throws {
        let matches = app!.buttons.matching(NSPredicate(format: "label == %@", label))
        try until("Require one unambiguous action: \(label)") { matches.count == 1 }
        try tap(matches.firstMatch)
    }
    private func exists(_ element: XCUIElement) throws { try require(element.waitForExistence(timeout: 12), "Missing expected element: \(element)") }
    private func disappears(_ element: XCUIElement) throws { try require(element.waitForNonExistence(timeout: 12), "Element did not dismiss: \(element)") }
    private func tap(_ element: XCUIElement) throws {
        try until("Control must be actionable: \(element)") { element.exists && element.isHittable && element.isEnabled }
        element.tap()
    }
    private func until(_ message: String, _ check: @escaping () -> Bool) throws {
        let item = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in check() }, object: nil)
        try require(XCTWaiter.wait(for: [item], timeout: 12) == .completed, message)
    }
    private func require(_ condition: Bool, _ message: String) throws { if !condition { throw Failure.requirement(message) } }
    private func capture(_ stage: String) throws {
        captureIndex += 1
        let stem = "account-failure-\(runID)-\(captureIndex)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: directory.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app!.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: directory.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
