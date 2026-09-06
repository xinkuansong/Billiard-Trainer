import XCTest

final class TrainingJourneyDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication!
    private let runID = UUID().uuidString
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forcePremium", "-v51.followSystemAppearance"])
    }
    override func tearDownWithError() throws { app?.terminate() }
    private func ready(_ element: XCUIElement, timeout: TimeInterval = 12) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout)); XCTAssertTrue(element.isHittable)
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        ready(element)
    }
    private func tap(_ label: String) {
        let element = app.buttons[label].firstMatch
        ready(element); element.tap()
    }
    private func back() { let button = app.navigationBars.buttons.firstMatch; ready(button); button.tap() }
    private func capture(_ stage: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let filename = "journey-\(runID)-\(stage)"
        let item = XCTAttachment(screenshot: shot)
        item.name = filename; item.lifetime = .keepAlways; add(item)
        let env = ProcessInfo.processInfo.environment
        let path = try XCTUnwrap(env["QD_SHOT_DIR"] ?? env["TEST_RUNNER_QD_SHOT_DIR"])
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try shot.pngRepresentation.write(to: dir.appendingPathComponent(filename + ".png"))
        let ax = app.debugDescription
        let tree = XCTAttachment(string: ax); tree.name = filename + "-AX"; tree.lifetime = .keepAlways; add(tree)
        try ax.write(to: dir.appendingPathComponent(filename + ".txt"), atomically: true, encoding: .utf8)
    }

    func testNormalOfficialPlanActivationArrangementAndStart() throws {
        app.switchTab(.training)
        let plan = app.buttons["planPoster-plan_beginner"]
        reveal(plan); ready(plan); plan.tap()
        let primary = app.buttons["planDetail.primaryCTA"]
        ready(primary); XCTAssertEqual(primary.label, "开始此计划")
        primary.tap()
        let confirm = app.alerts.buttons["确定激活"]
        ready(confirm); confirm.tap()
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "编排今天"), object: primary)], timeout: 10), .completed)
        primary.tap()
        XCTAssertTrue(app.navigationBars["编排今天"].waitForExistence(timeout: 8))
        let summary = app.descendants(matching: .any)["planDetail.arrangementSummary"].firstMatch
        reveal(summary); XCTAssertTrue(summary.label.contains("将加入 1 项"))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '当前' AND label CONTAINS '已选择'")).firstMatch.exists)
        try capture("official-current-lesson-selected")
        tap("planDetail.addToToday")
        XCTAssertTrue(app.navigationBars["编排今天"].waitForNonExistence(timeout: 8))
        back()
        let today = app.descendants(matching: .any)["trainingHome.todaySummary"].firstMatch
        for _ in 0..<10 {
            if today.exists && today.isHittable { break }
            app.swipeDown()
        }
        XCTAssertTrue(today.exists); XCTAssertTrue(today.label.contains("0 / 1"))
        let start = app.buttons["开始这节课"].firstMatch
        reveal(start); ready(start); start.tap()
        XCTAssertTrue(app.descendants(matching: .any)["activeTraining.timer"].firstMatch.waitForExistence(timeout: 10))
        try capture("official-normal-session-started")
    }

    func testNormalTemplateNameAndDrillSaveAndReopen() throws {
        app.switchTab(.training)
        try capture("template-before-more-menu")
        tap("trainingHome.moreMenu"); tap("新建模版")
        XCTAssertTrue(app.navigationBars["新建模版"].waitForExistence(timeout: 8))
        let name = app.textFields["customPlanNameField"]
        ready(name); name.tap()
        let intro = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Speed up your typing")).firstMatch
        if intro.exists { tap("Continue") }
        let previous = try XCTUnwrap(name.value as? String)
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count + 2))
        let title = "诊断模版" + runID.prefix(8)
        name.typeText(title + "\n")
        XCTAssertEqual(name.value as? String, title)
        let add = app.buttons["添加训练项目"]
        reveal(add); ready(add); add.tap()
        tap("添加中袋直线出杆")
        tap("完成(1)")
        XCTAssertTrue(app.navigationBars["新建模版"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["中袋直线出杆"].firstMatch.exists)
        try capture("template-fields-before-save")
        tap("保存"); tap("仅保存")
        XCTAssertTrue(app.navigationBars["新建模版"].waitForNonExistence(timeout: 8))
        let templates = app.buttons["我的模版"].firstMatch
        reveal(templates); ready(templates); templates.tap()
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "trainingHome.template.edit.", title)).firstMatch
        reveal(card); ready(card); card.tap()
        XCTAssertTrue(app.navigationBars["编辑模版"].waitForExistence(timeout: 8))
        XCTAssertEqual(name.value as? String, title)
        XCTAssertTrue(app.staticTexts["中袋直线出杆"].firstMatch.exists)
        try capture("template-saved-reopened")
        back(); ready(card)
    }

    func testDailyClearanceNormalStartReturnAndResume() throws {
        app.switchTab(.training)
        let entry = app.buttons["trainingHome.dailyClearance"]
        reveal(entry); ready(entry)
        XCTAssertTrue(entry.label.contains("未开始"), "Use a dedicated device without an existing daily game; do not reset prior evidence")
        entry.tap()
        XCTAssertTrue(app.navigationBars["每日清台"].waitForExistence(timeout: 15))
        let hud = app.descendants(matching: .any)["dailyClearance.hud"].firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 45), "Observe the actual auto-break; no fixtureSettled shortcut")
        XCTAssertTrue(app.descendants(matching: .any)["freeplay.stage"].exists)
        try capture("daily-started")
        back()
        ready(entry); XCTAssertTrue(entry.label.contains("进行中"))
        try capture("daily-returned-home")
        entry.tap()
        XCTAssertTrue(app.navigationBars["每日清台"].waitForExistence(timeout: 10))
        XCTAssertTrue(hud.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["freeplay.stage"].exists)
        try capture("daily-resumed")
    }

    func testStatisticsWeekMonthYearAfterNormalCognitiveAnswer() throws {
        // Prepare a real cognitive session through the normal UI, not fabricated chart values.
        app.switchTab(.angle); tap("angleHomeTab_练"); tap("角度预测")
        XCTAssertTrue(app.navigationBars["角度预测"].waitForExistence(timeout: 10))
        tap("答题"); tap("4"); tap("5"); tap("提交")
        let next = app.buttons["下一题"].firstMatch
        reveal(next); ready(next)
        back(); app.switchTab(.history); tap("统计")
        for (range, expected) in [("周", "本周训练天数"), ("月", "本月训练天数"), ("年", "本年训练天数")] {
            let period = app.buttons[range].firstMatch
            for _ in 0..<8 {
                if period.exists && period.isHittable { break }
                app.swipeDown()
            }
            ready(period); period.tap()
            let heading = app.staticTexts[expected].firstMatch
            reveal(heading); XCTAssertTrue(heading.exists)
            XCTAssertFalse(app.staticTexts["还没有训练数据"].isHittable)
            XCTAssertFalse(app.staticTexts["加载失败"].isHittable)
            try capture("statistics-\(range)")
        }
        tap("历史")
        XCTAssertTrue(app.staticTexts["角度预测"].firstMatch.waitForExistence(timeout: 10))
    }
}
