import XCTest

/// Normal UI only. Complete the unchanged 15-set first lesson before checking progression.
/// No fixture, deep link, business mutation hook, source rewriting, login, or purchase.
final class PlanContinuationDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        if app != nil { try capture("terminal"); app.terminate() }
    }

    func testCompleteAllFifteenSetsThenSwitchBackPreservesSecondLesson() throws {
        let env = ProcessInfo.processInfo.environment
        XCTAssertEqual(env["QD_PLAN_CONTINUATION_AUTH"] ?? env["TEST_RUNNER_QD_PLAN_CONTINUATION_AUTH"],
                       "DEDICATED_GUEST_SIMULATOR")
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forceNonPremium", "-v51.followSystemAppearance"])
        XCTAssertEqual(app.state, .runningForeground)
        app.switchTab(.profile)
        ready(app.buttons["profile.login"])
        app.switchTab(.history)
        ready(app.staticTexts["还没有训练记录"])
        app.switchTab(.training)
        try openPlan("plan_beginner")
        activate(expected: "开始此计划")
        tap("planDetail.primaryCTA")
        ready(app.navigationBars["编排今天"])
        assertArrangement(title: "中底袋直线出杆", state: "当前", selected: true)
        let summary = app.descendants(matching: .any)["planDetail.arrangementSummary"].firstMatch
        reveal(summary)
        XCTAssertTrue(summary.label.contains("将加入 1 项"))
        tap("planDetail.addToToday")
        XCTAssertTrue(app.navigationBars["编排今天"].waitForNonExistence(timeout: 10))
        back()
        let lesson = app.buttons["trainingHome.scheduleItem.plan_beginner.stage01.lesson01"]
        reveal(lesson, upward: false); ready(lesson)
        XCTAssertEqual(lesson.value as? String, "已折叠")
        lesson.tap()
        XCTAssertEqual(lesson.value as? String, "已展开")
        let start = app.buttons["开始这节课"].firstMatch
        reveal(start); ready(start); start.tap()
        ready(app.descendants(matching: .any)["activeTraining.timer"].firstMatch)
        try capture("lesson-started")

        // Independent expected doses come from the frozen official lesson, not from live UI.
        // Switching through the actual overview also disambiguates equal group labels on pages.
        showOverview()
        try completeDrill(name: "中袋直线出杆", sets: 8, total: 120)
        try completeDrill(name: "底袋直线出杆", sets: 7, total: 105)
        ready(app.buttons["中袋直线出杆, 8/8 组, 120/120 球"])
        ready(app.buttons["底袋直线出杆, 7/7 组, 105/105 球"])
        try capture("all-fifteen-sets-complete-before-ending")

        tap("activeTraining.more")
        tap("结束训练")
        ready(app.alerts["结束训练？"])
        app.alerts.buttons["结束"].tap()
        ready(app.navigationBars["训练心得"])
        let dismissKeyboard = app.buttons["trainingNote.dismissKeyboard"]
        ready(dismissKeyboard); dismissKeyboard.tap()
        tap("跳过")
        let save = app.buttons["保存训练"].firstMatch
        reveal(save); ready(save)
        try capture("complete-lesson-summary-before-save")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 12))
        XCTAssertFalse(app.alerts["保存失败"].exists)
        // The summary exposes an explicit completion action after persisting. Only use it
        // when actually present; never press Save again or manufacture another session.
        let complete = app.buttons["完成"].firstMatch
        if complete.exists && complete.isHittable { complete.tap() }
        ready(app.buttons["trainingHome.freeTraining"])
        try capture("saved-returned-home")

        try openPlan("plan_beginner")
        try verifySecondLesson(stage: "after-complete")
        back()
        try openPlan("plan_accuracy")
        activate(expected: "切换到此计划")
        tap("planDetail.primaryCTA")
        ready(app.navigationBars["编排今天"])
        assertArrangement(title: "近台小角度入门", state: "当前", selected: true)
        try capture("plan-b-current-first-lesson")
        tap("取消")
        XCTAssertTrue(app.navigationBars["编排今天"].waitForNonExistence(timeout: 8))
        back()
        try openPlan("plan_beginner")
        activate(expected: "切换到此计划")
        try verifySecondLesson(stage: "after-a-b-a")
        back()
        try capture("returned-home-after-a-b-a")
    }

    private func completeDrill(name: String, sets: Int, total: Int) throws {
        let row = app.buttons["\(name), 0/\(sets) 组, 0/\(total) 球"]
        reveal(row); ready(row); row.tap()
        ready(app.buttons["切换到总览视图"])
        for group in 1...sets {
            let made = try visibleField("第\(group)组进球")
            let target = try visibleField("第\(group)组总球")
            XCTAssertEqual(target.value as? String, "15")
            made.tap()
            tap("setNumberKeyboard.1")
            tap("setNumberKeyboard.5")
            XCTAssertEqual(made.value as? String, "15")
            tap("setNumberKeyboard.完成")
            let finishRest = app.buttons["完成休息"].firstMatch
            if finishRest.waitForExistence(timeout: 2) { ready(finishRest); finishRest.tap() }
            XCTAssertFalse(app.buttons["setNumberKeyboard.完成"].exists)
            try capture("\(name)-group-\(group)-confirmed")
        }
        // Final set advances to the next drill automatically; do not click a completed
        // checkmark again (which would toggle the set back to incomplete).
        showOverview()
        let completed = app.buttons["\(name), \(sets)/\(sets) 组, \(total)/\(total) 球"]
        reveal(completed); ready(completed)
        try capture("\(name)-overview-all-complete")
    }

    private func verifySecondLesson(stage: String) throws {
        let primary = app.buttons["planDetail.primaryCTA"]
        ready(primary); XCTAssertEqual(primary.label, "编排今天"); primary.tap()
        ready(app.navigationBars["编排今天"])
        assertArrangement(title: "中底袋直线出杆", state: "已完成", selected: false)
        assertArrangement(title: "底袋直线出杆入门", state: "当前", selected: true)
        assertArrangement(title: "底袋直线出杆检验", state: "未开始", selected: false)
        try capture(stage + "-first-completed-second-current-third-unstarted")
        tap("取消")
        XCTAssertTrue(app.navigationBars["编排今天"].waitForNonExistence(timeout: 8))
    }

    private func assertArrangement(title: String, state: String, selected: Bool) {
        let label = title + "，" + state + "，" + (selected ? "已选择" : "未选择")
        let row = app.buttons[label]
        reveal(row); ready(row)
    }

    private func activate(expected: String) {
        let primary = app.buttons["planDetail.primaryCTA"]
        ready(primary); XCTAssertEqual(primary.label, expected); primary.tap()
        ready(app.alerts["激活训练计划"])
        app.alerts.buttons["确定激活"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "编排今天"), object: primary)], timeout: 10), .completed)
    }

    private func openPlan(_ id: String) throws {
        let card = app.buttons["planPoster-" + id]
        // Return to the start of the shelf, then bound traversal through the catalog.
        for _ in 0..<8 { app.swipeDown() }
        // Original run exposed a card whose center overlapped the tab bar despite
        // isHittable=true. Require the entire card above the observed tab bar.
        let tabs = app.tabBars.firstMatch
        ready(tabs)
        for _ in 0..<16 {
            if card.exists && card.isHittable && card.frame.maxY < tabs.frame.minY { break }
            app.swipeUp()
        }
        ready(card)
        XCTAssertLessThan(card.frame.maxY, tabs.frame.minY)
        try capture("plan-card-before-tap-" + id + "-" + UUID().uuidString)
        card.tap()
        ready(app.buttons["planDetail.primaryCTA"])
    }

    private func showOverview() {
        let toOverview = app.buttons["切换到总览视图"]
        if toOverview.exists && toOverview.isHittable { toOverview.tap() }
        ready(app.buttons["切换到单项视图"])
    }

    private func visibleField(_ label: String) throws -> XCUIElement {
        for _ in 0..<10 {
            let visible = app.textFields.matching(NSPredicate(format: "label == %@", label))
                .allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
            if !visible.isEmpty {
                XCTAssertEqual(visible.count, 1, "Ambiguous visible field: " + label)
                return try XCTUnwrap(visible.first)
            }
            app.swipeUp()
        }
        try capture("field-not-reachable-" + label)
        XCTFail("Expected group field not reachable: " + label)
        throw NSError(domain: "PlanContinuationDiagnostic", code: 1)
    }

    private func ready(_ element: XCUIElement) {
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND hittable == true AND enabled == true"), object: element)], timeout: 12), .completed)
    }
    private func reveal(_ element: XCUIElement, upward: Bool = true) {
        for _ in 0..<16 {
            if element.exists && element.isHittable { return }
            if upward { app.swipeUp() } else { app.swipeDown() }
        }
    }
    private func tap(_ identifier: String) { let e = app.buttons[identifier].firstMatch; ready(e); e.tap() }
    private func back() { let e = app.navigationBars.buttons.firstMatch; ready(e); e.tap() }
    private func capture(_ stage: String) throws {
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stem = "plan-continuation-" + runID + "-" + stage
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        let tree = XCTAttachment(string: app.debugDescription); tree.name = stem + "-AX"; tree.lifetime = .keepAlways; add(tree)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        try Data(app.debugDescription.utf8).write(to: dir.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
