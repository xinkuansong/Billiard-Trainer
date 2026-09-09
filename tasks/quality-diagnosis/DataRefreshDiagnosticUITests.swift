import XCTest

/// Unregistered draft. Synthetic disk ledger; never proves normal record creation.
/// One ordered method avoids inter-test dependency between deletion and goal persistence.
final class DataRefreshDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString
    private var output: URL!
    private let marker = "QD-DATA-REFRESH-0908-A"
    private func env(_ key: String) -> String? {
        let values = ProcessInfo.processInfo.environment
        return values[key] ?? values["TEST_RUNNER_" + key]
    }
    private func require(_ value: Bool, _ reason: String) throws {
        guard value else { XCTFail(reason); throw NSError(domain: "DataRefreshUI", code: 1, userInfo: [NSLocalizedDescriptionKey: reason]) }
    }
    private func dayGuard() throws {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone.current; f.dateFormat = "yyyy-MM-dd"
        try require(TimeZone.current.identifier == "Asia/Shanghai" && Calendar.current.identifier == .gregorian && f.string(from: Date()) == "2026-09-08", "Fixed ledger expired or wrong timezone/calendar; prepare a new ledger, never change clock")
    }
    override func setUpWithError() throws {
        continueAfterFailure = false
        try dayGuard()
        let expectedDevice = try XCTUnwrap(env("QD_EXPECTED_DEVICE_UDID"))
        let actualDevice = try XCTUnwrap(env("SIMULATOR_UDID"))
        try require(!expectedDevice.isEmpty && actualDevice == expectedDevice, "Runner is not on the explicitly authorized simulator")
        try require(env("QD_UI_ENVIRONMENT") == "SEEDED_DEDICATED_GUEST_SIMULATOR", "Dedicated seed authorization required")
        let raw = try XCTUnwrap(env("QD_EXPECTED_MANIFEST_JSON"))
        let m = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        try require(m["fixture"] as? String == "DATA-REFRESH-20260908-v1" && m["localDay"] as? String == "2026-09-08" && m["timezone"] as? String == "Asia/Shanghai", "Wrong manifest")
        try require(m["bundleID"] as? String == "com.xinkuan.qiuji", "Wrong host manifest")
        let owner = try XCTUnwrap(m["owner"] as? String)
        try require(owner.hasPrefix("guest:") && owner == env("QD_EXPECTED_GUEST_OWNER"), "Wrong owner")
        let relative = try XCTUnwrap(m["storeRelativePath"] as? String)
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
        try require(relative == env("QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH") && !relative.hasPrefix("/") && !parts.isEmpty && parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }, "Wrong relative store")
        for (key, expected) in ["sessionCount":3, "entryCount":4, "setCount":4, "answerCount":0, "pendingSyncCount":0] {
            try require((m[key] as? NSNumber)?.intValue == expected, "Wrong ledger count " + key)
        }
        let rows = try XCTUnwrap(m["rows"] as? [[String: Any]])
        try require(rows.count == 3 && Set(rows.compactMap { $0["note"] as? String }) == Set([marker,"QD-DATA-REFRESH-0908-B","QD-DATA-REFRESH-0908-C"]), "Wrong ledger identities")
        output = URL(fileURLWithPath: try XCTUnwrap(env("QD_SHOT_DIR")), isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-hasCompletedOnboarding", "YES", "-v51.followSystemAppearance", "-forcePremium"]
        // forcePremium unlocks statistics/old history only; no login, in-memory store or data injection.
        app.launch()
        try require(app.wait(for: .runningForeground, timeout: 12), "Initial App launch not foreground")
    }
    override func tearDownWithError() throws {
        guard app != nil else { return }
        defer { app.terminate() }
        if output != nil { try capture("teardown") }
    }
    private func capture(_ stage: String) throws {
        let stem = "data-refresh-" + runID + "-" + stage
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot); attachment.name = stem; attachment.lifetime = .keepAlways; add(attachment)
        try shot.pngRepresentation.write(to: output.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let tree = app.debugDescription
        let ax = XCTAttachment(string: tree); ax.name = stem + "-AX"; ax.lifetime = .keepAlways; add(ax)
        try Data(tree.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
    private func shown(_ e: XCUIElement) -> Bool {
        guard e.exists else { return false }
        let r = e.frame
        guard !r.isEmpty && r.minX.isFinite && r.minY.isFinite && app.windows.firstMatch.frame.contains(r) else { return false }
        let tab = app.tabBars.firstMatch
        return !tab.exists || !tab.isHittable || r.maxY <= tab.frame.minY
    }
    private func ready(_ e: XCUIElement) throws {
        let p = NSPredicate(format: "exists == true AND hittable == true AND enabled == true")
        try require(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: p, object: e)], timeout: 12) == .completed && shown(e), "Control absent/occluded: " + e.description)
    }
    private func scroll(_ up: Bool) throws {
        let s = app.scrollViews.firstMatch
        try require(s.exists && !s.frame.isEmpty, "No actual scroll container")
        let window = app.windows.firstMatch.frame
        let tab = app.tabBars.firstMatch
        let r = s.frame.intersection(window)
        let bottom = tab.exists && tab.isHittable ? min(r.maxY, tab.frame.minY) : r.maxY
        try require(r.width > 0 && bottom - r.minY > 100, "Invalid scroll bounds")
        let x = r.midX, low = r.minY + (bottom-r.minY)*0.25, high = r.minY + (bottom-r.minY)*0.75
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: x, dy: up ? high : low)).press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: up ? low : high)))
    }
    private func reveal(_ e: XCUIElement) throws {
        for _ in 0..<12 {
            if shown(e) { return }
            let above = e.exists && e.frame.maxY < app.scrollViews.firstMatch.frame.minY
            try scroll(!above)
        }
        try require(shown(e), "Bounded reveal failed: " + e.description)
    }
    private func tap(_ e: XCUIElement) throws { try reveal(e); try ready(e); e.tap() }
    private func text(_ value: String) throws { try reveal(app.staticTexts[value].firstMatch) }
    private func row(_ minutes: Int) throws -> XCUIElement {
        let q = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "半台直线球", "\(minutes) 分钟"))
        try require(q.count == 1, "Unique seeded history row missing: \(minutes)")
        try reveal(q.firstMatch); return q.firstMatch
    }
    private func calendarDay(_ number: Int, title: String) throws {
        let q = app.buttons.matching(NSPredicate(format: "label MATCHES %@ AND enabled == true", "^\(number)(、.*)?$"))
        try require(q.count == 1, "Actual calendar day absent/ambiguous")
        try tap(q.firstMatch); try text(title)
    }
    private func month(_ direction: String, expected: String) throws {
        let q = app.buttons.matching(identifier: "chevron." + direction)
        try require(q.count == 1, "Observed month arrow absent/ambiguous")
        try tap(q.firstMatch); try text(expected)
    }
    private func home(_ goal: Int) throws {
        app.switchTab(.training)
        let e = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "本周训练 1 / \(goal) 天，连续训练 1 天")).firstMatch
        try reveal(e); try capture("home-goal-\(goal)-" + UUID().uuidString)
    }
    private func count(_ n: Int) throws {
        app.switchTab(.drillLibrary)
        let search = app.textFields["librarySearchField"]; try ready(search)
        if (search.value as? String) != "半台直线球" {
            search.tap()
            let intro = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
            if intro.waitForExistence(timeout: 2) {
                let buttons = app.buttons.matching(NSPredicate(format: "label == %@", "Continue"))
                try require(buttons.count == 1 && buttons.firstMatch.isHittable, "Observed typing introduction needs one Continue action")
                buttons.firstMatch.tap()
                try require(intro.waitForNonExistence(timeout: 8), "Typing introduction did not dismiss")
            }
            search.typeText("半台直线球\n")
            try require(search.value as? String == "半台直线球", "Actual search text must match the ledger drill")
        }
        let card = app.buttons["drillCard_drill_c001"]; try reveal(card)
        let badge = card.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "已练 \(n) 次")).firstMatch
        try require(card.label.contains("已练 \(n) 次") || shown(badge), "Automatic entry count refresh failed")
        try capture("practice-count-\(n)-" + UUID().uuidString)
    }
    private func metric(_ caption: String, _ expected: Int) throws {
        try text(caption)
        let labels = app.staticTexts.matching(NSPredicate(format: "label == %@", caption)).allElementsBoundByIndex.filter(shown)
        try require(labels.count == 1, "Ambiguous metric caption")
        let b = labels[0].frame
        let numbers = app.staticTexts.allElementsBoundByIndex.filter { e in
            guard shown(e), Int(e.label) != nil else { return false }
            let r = e.frame, gap = b.minY-r.maxY
            return gap >= -4 && gap <= 70 && min(r.maxX,b.maxX) > max(r.minX,b.minX)
        }
        try require(numbers.count == 1 && numbers[0].label == String(expected), "Wrong caption-bound metric: " + caption)
    }
    private func stats(_ minutes: Int, sets: Int) throws {
        app.switchTab(.history); try tap(app.buttons["统计"].firstMatch); try tap(app.buttons["周"].firstMatch)
        try capture("statistics-before-assert-\(minutes)")
        try metric("本周训练天数", 1); try metric("分钟 · 总时长", minutes); try metric("训练组数", sets)
        try tap(app.buttons["历史"].firstMatch)
    }
    private func goalPage(_ goal: Int) throws {
        app.switchTab(.profile)
        try ready(app.buttons["profile.login"])
        try require(!app.descendants(matching: .any)["profile.accountHeader"].exists, "Expected guest")
        try tap(app.staticTexts["训练目标"].firstMatch)
        try text("/ \(goal) 天"); try capture("goal-page-\(goal)-" + UUID().uuidString)
    }
    func testCalendarNoteDeleteAutomaticRefreshAndGoalThreeToFivePersists() throws {
        do {
            try home(3); try count(4); try stats(50, sets: 3)
            try text("2026年9月")
            try calendarDay(7, title: "9月7日 星期一"); try text("当天无训练记录"); try capture("empty-september-seven")
            try month("left", expected: "2026年8月")
            try calendarDay(31, title: "8月31日 星期一")
            try tap(try row(40)); try text("QD-DATA-REFRESH-0908-C"); try capture("august-C")
            try tap(app.navigationBars.buttons.firstMatch)
            try month("right", expected: "2026年9月")
            try calendarDay(8, title: "9月8日 星期二")
            _ = try row(30); try tap(try row(20)); try text(marker); try capture("A-identity-before-edit")
            try tap(app.buttons["更多操作"]); try tap(app.buttons["编辑心得"])
            let editor = app.textViews["trainingNote.editor"]; try ready(editor)
            try require(editor.value as? String == marker, "Wrong note editor identity")
            // Keep existing cursor position; prove one literal insertion anywhere, not a guessed caret.
            try require(app.keyboards.firstMatch.waitForExistence(timeout: 8), "Existing note editor must actually have keyboard focus")
            editor.typeText("-EDIT")
            let edited = try XCTUnwrap(editor.value as? String)
            try require(edited.components(separatedBy: "-EDIT").count == 2 && edited.replacingOccurrences(of: "-EDIT", with: "") == marker, "Insertion altered existing note unexpectedly")
            try capture("A-edited-input")
            try tap(app.buttons["trainingNote.dismissKeyboard"]); try tap(app.buttons["完成"].firstMatch)
            try text(edited); try capture("A-edited-saved")
            try tap(app.navigationBars.buttons.firstMatch)
            try tap(try row(20)); try text(edited); try capture("A-edited-reopened")
            try tap(app.buttons["更多操作"]); try tap(app.buttons["删除"].firstMatch)
            try text("删除这条训练记录？"); try capture("A-delete-confirmation")
            try tap(app.buttons["删除"].firstMatch)
            try require(app.buttons["编辑数据"].waitForNonExistence(timeout: 10), "Delete did not dismiss detail")
            try require(!app.alerts["操作失败"].exists, "Delete failed")
            _ = try row(30)
            try require(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "半台直线球", "20 分钟")).count == 0, "Deleted row remains")
            try capture("history-after-delete")
            try home(3); try count(2); try stats(30, sets: 1)
            try goalPage(3); try tap(app.buttons["5 天"].firstMatch); try text("/ 5 天"); try capture("goal-five-written")
            try tap(app.navigationBars.buttons.firstMatch); try home(5)
            try goalPage(5); try tap(app.navigationBars.buttons.firstMatch)
            app.terminate()
            try require(app.wait(for: .notRunning, timeout: 12), "Previous App process did not terminate")
            try dayGuard(); app.launch()
            try require(app.wait(for: .runningForeground, timeout: 12), "Restarted App not foreground")
            try home(5); try goalPage(5); try tap(app.navigationBars.buttons.firstMatch)
            try count(2)
            app.switchTab(.history); try calendarDay(8, title: "9月8日 星期二")
            try tap(try row(30)); try text("QD-DATA-REFRESH-0908-B"); try capture("restart-B-preserved")
            try tap(app.navigationBars.buttons.firstMatch)
            try require(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "半台直线球", "20 分钟")).count == 0, "Deleted A returned after restart")
            try dayGuard(); try capture("completed-UI-chain")
        } catch {
            try capture("failure-before-termination")
            throw error
        }
    }

    /// Separate continuation of the actual UI001 post-deletion disk; does not rerun or weaken UI001.
    func testGoalThreeToFivePersistsAfterRecordedDeletion() throws {
        do {
            try verifyGoalCompanionSQL()
            try home(3); try count(2)
            try companionHistory(stage: "companion-before-goal", includeC: true)
            try goalPage(3)
            try tap(app.buttons["5 天"].firstMatch)
            try text("/ 5 天"); try capture("companion-goal-five-written")
            try tap(app.navigationBars.buttons.firstMatch)
            try home(5)
            try goalPage(5)
            try tap(app.navigationBars.buttons.firstMatch)
            app.terminate()
            try require(app.wait(for: .notRunning, timeout: 12), "Companion old process must terminate")
            try dayGuard()
            app.launch()
            try require(app.wait(for: .runningForeground, timeout: 12), "Companion restarted process must reach foreground")
            try home(5); try goalPage(5)
            try tap(app.navigationBars.buttons.firstMatch)
            try count(2)
            try companionHistory(stage: "companion-after-restart", includeC: false)
            try dayGuard()
            try capture("companion-goal-persistence-verified-before-statistics")
            print("[QD-GoalCompanion] goal 3->5, normal reentry and notRunning/relaunch verified; count2/B preserved/A absent; statistics not yet asserted")
            // Keep the 30/1 oracle strict, but run it only after the independent goal branch.
            try stats(30, sets: 1)
            try capture("companion-statistics-thirty-after-goal")
        } catch {
            try capture("companion-failure-before-termination")
            throw error
        }
    }
    private func companionHistory(stage: String, includeC: Bool) throws {
        app.switchTab(.history)
        try tap(app.buttons["历史"].firstMatch)
        try text("2026年9月")
        try calendarDay(8, title: "9月8日 星期二")
        try require(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "半台直线球", "20 分钟")).count == 0, "Deleted A must not be visible on its actual day")
        try tap(try row(30)); try text("QD-DATA-REFRESH-0908-B")
        try capture(stage + "-B-original-note")
        try tap(app.navigationBars.buttons.firstMatch)
        if includeC {
            try month("left", expected: "2026年8月")
            try calendarDay(31, title: "8月31日 星期一")
            try tap(try row(40)); try text("QD-DATA-REFRESH-0908-C")
            try capture(stage + "-C-original-note")
            try tap(app.navigationBars.buttons.firstMatch)
            try month("right", expected: "2026年9月")
            try calendarDay(8, title: "9月8日 星期二")
        }
    }

    private func verifyGoalCompanionSQL() throws {
        try dayGuard()
        try require(env("QD_GOAL_COMPANION_AUTHORIZATION") == "AFTER_UI001_DELETION_SQL_VERIFIED", "Explicit post-UI001 companion authorization required")
        let owner = "guest:c24e68e8-857e-47c4-9cc5-82165b40a01a"
        try require(env("QD_EXPECTED_DEVICE_UDID") == "269AB5D4-0E43-41E6-9806-016B99996F25" && env("QD_EXPECTED_GUEST_OWNER") == owner, "Companion is bounded to the actual UI001 disk guest/device")
        let raw = try XCTUnwrap(env("QD_GOAL_AFTER_SQL_JSON"))
        let sql = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        let counts = try XCTUnwrap(sql["counts"] as? [String: Any])
        for (key, expected) in ["ZTRAININGSESSION": 2, "ZDRILLENTRY": 2, "ZDRILLSET": 2, "ZANGLETESTRESULT": 0, "ZSYNCPENDINGITEM": 2] {
            try require((counts[key] as? NSNumber)?.intValue == expected, "Wrong actual after-SQL count: " + key)
        }
        try require(sql["owners"] as? [String] == [owner], "After-SQL owner must be the one original guest")
        let orphans = try XCTUnwrap(sql["orphans"] as? [String: Any])
        try require((orphans["entries"] as? NSNumber)?.intValue == 0 && (orphans["sets"] as? NSNumber)?.intValue == 0, "After-SQL must show no orphan children")
        try require(sql["unchangedBC"] as? Bool == true && sql["deletedAAndChildren"] as? Bool == true, "Independent deletion/retained identity verification required")
        try require((sql["weeklyGoalDays"] as? NSNumber)?.intValue == 3 && sql["goalPreferencePresent"] as? Bool == false, "Companion must begin at the actual untouched default goal3")
        let initialRaw = try XCTUnwrap(env("QD_EXPECTED_MANIFEST_JSON"))
        let initial = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(initialRaw.utf8)) as? [String: Any])
        let initialRows = try XCTUnwrap(initial["rows"] as? [[String: Any]])
        let afterRows = try XCTUnwrap(sql["rows"] as? [[String: Any]])
        let aID = "24C19AFD-C5A8-46E7-A75C-072AF68029E8"
        let bID = "C17DCDE9-A840-437F-856C-67680AB5C1E0"
        let cID = "DCD6693F-4C0F-4F56-88B7-283567C143DA"
        try require(afterRows.count == 2 && Set(afterRows.compactMap { $0["id"] as? String }) == Set([bID, cID]), "Only original B/C UUIDs may remain")
        for (id, note) in [(aID, marker), (bID, "QD-DATA-REFRESH-0908-B"), (cID, "QD-DATA-REFRESH-0908-C")] {
            let originals = initialRows.filter { $0["id"] as? String == id && $0["note"] as? String == note }
            try require(originals.count == 1, "Original manifest UUID/note mismatch")
            if id != aID {
                let remaining = afterRows.filter { $0["id"] as? String == id }
                try require(remaining.count == 1, "Retained row must be unique")
                let before = try JSONSerialization.data(withJSONObject: originals[0], options: .sortedKeys)
                let after = try JSONSerialization.data(withJSONObject: remaining[0], options: .sortedKeys)
                try require(before == after, "Retained B/C full date/score/note/entry ledger changed")
            }
        }
        let queue = try XCTUnwrap(sql["queue"] as? [[String: Any]])
        try require(queue.count == 2 && Set(queue.compactMap { $0["operation"] as? String }) == Set(["update", "delete"]), "Actual A update/delete pair must remain; never require or force zero queue")
        try require(queue.allSatisfy { $0["owner"] as? String == owner && $0["entityID"] as? String == aID && $0["entityType"] as? String == "TrainingSession" }, "Pending items must belong only to the actual A session")
        let attachment = XCTAttachment(string: raw); attachment.name = "goal-companion-external-after-SQL-input"; attachment.lifetime = .keepAlways; add(attachment)
    }

    /// Independent readback after companion001 wrote goal5 and failed at warm home refresh.
    func testColdRestartRetainsWrittenGoalAndDeletedLedger() throws {
        try require(env("QD_COLD_GOAL_AUTHORIZATION") == "AFTER_COMPANION001_GOAL5_DISK_VERIFIED", "Explicit cold-readback authorization required")
        try require(env("QD_EXPECTED_DEVICE_UDID") == "269AB5D4-0E43-41E6-9806-016B99996F25", "Only actual companion001 device")
        let raw = try XCTUnwrap(env("QD_COLD_GOAL_VERIFICATION_JSON"))
        let v = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
        try require((v["weeklyGoalDays"] as? NSNumber)?.intValue == 5 && v["goalPreferencePresent"] as? Bool == true && v["allFiveTablesExactlyUnchanged"] as? Bool == true, "Independent goal5/unchanged ledger verification required")
        try home(5); try goalPage(5); try tap(app.navigationBars.buttons.firstMatch)
        try count(2); try companionHistory(stage: "cold-goal5", includeC: true)
        app.terminate()
        try require(app.wait(for: .notRunning, timeout: 12), "Readback process did not terminate")
        try dayGuard(); app.launch()
        try require(app.wait(for: .runningForeground, timeout: 12), "Second cold readback not foreground")
        try home(5); try goalPage(5); try tap(app.navigationBars.buttons.firstMatch)
        try stats(30, sets: 1)
        try capture("cold-restart-goal-five-and-thirty-minutes")
    }
}
