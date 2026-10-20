import XCTest

final class SceneTrainingRulesUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func open(_ title: String, nearLimit: Bool = false, light: Bool = false) {
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication.launchClean(extraArgs: [nearLimit ? "-w7.forceDailyLimitNear" : "-forcePremium", "-v50.inMemoryStore", "-dailyLayout.probe"] + (light ? ["-v54.forceLight"] : []))
        app.switchTab(.angle)
        let training = app.buttons["angleHomeTab_练"]
        XCTAssertTrue(training.waitForExistence(timeout: 10)); training.tap()
        let card = app.buttons[title]
        XCTAssertTrue(card.waitForExistence(timeout: 10)); card.tap()
    }
    func testAngle2D() { checkAngle("2D") }
    func testAngle3D() { checkAngle("3D") }
    func testAimPoint2D() { checkAimPoint("2D") }
    func testAimPoint3D() { checkAimPoint("3D") }
    func testLastFreeAnswerKeepsResultAndAllowsSummary() { checkAimPoint("2D", nearLimit: true) }

    func testNewAimPointHistoryUsesMillimetresAndSeparateSummary() {
        open("2D瞄准点",light:true); start("aimPointTraining", name: "history-point")
        let submit = app.buttons["aimPointTraining.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout:40)); submit.tap()
        XCTAssertTrue(app.buttons["aimPointTraining.next"].waitForExistence(timeout:5))
        app.buttons["aimPointTraining.back"].tap()
        XCUIDevice.shared.orientation = .portrait
        app.switchTab(.history)
        let row = app.buttons["history.cognitive.aimPoint2D"]
        for _ in 0..<4 where !row.isHittable { app.swipeUp() }
        XCTAssertTrue(row.waitForExistence(timeout:10))
        XCTAssertTrue(row.label.contains("mm"))
        capture("point-history-list-mm")
        row.tap()
        let summary = app.descendants(matching:.any).matching(identifier:"training.summary").firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout:5))
        capture("point-history-summary")
        app.buttons["完成"].tap()
        let stats = app.descendants(matching:.any).matching(NSPredicate(format:"label == '统计'")).firstMatch
        stats.tap()
        let cohort = app.descendants(matching:.any).matching(identifier:"history.trainingCohort").firstMatch
        for _ in 0..<7 where !(cohort.exists && cohort.isHittable) { app.swipeUp() }
        capture("point-history-statistics")
        print(app.debugDescription)
        XCTAssertTrue(cohort.isHittable)
    }

    func testFreePracticeRestartAppliesDraftOnConfirmation() {
        open("2D瞄准点")
        XCTAssertTrue(app.buttons["aimPointTraining.start"].waitForExistence(timeout:10))
        app.buttons["自由练习"].tap()
        app.buttons["training.range.straight"].tap()
        app.buttons["aimPointTraining.start"].tap()
        let submit = app.buttons["aimPointTraining.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout:40))
        let info = app.descendants(matching:.any).matching(identifier:"aimPointTraining.questionInfo").firstMatch
        XCTAssertFalse(info.label.contains("/20"))
        app.buttons["aimPointTraining.angleHint"].tap()
        let hint = app.descendants(matching:.any).matching(identifier:"aimPointTraining.angleHintText").firstMatch
        let degrees = hint.label.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertTrue((0...10).contains(degrees.first ?? -1))
        submit.tap(); app.buttons["aimPointTraining.next"].tap()
        XCTAssertTrue(submit.waitForExistence(timeout:5))
        app.buttons["aimPointTraining.settings"].tap(); app.buttons["aimPointTraining.trainingSettings"].tap()
        app.buttons["20题"].tap()
        app.buttons["training.range.mixed"].tap()
        app.buttons["training.range.small"].tap()
        app.buttons["aimPointTraining.start"].tap()
        XCTAssertTrue(submit.waitForExistence(timeout:20))
        XCTAssertTrue(info.label.contains("1/20"))
        app.buttons["aimPointTraining.angleHint"].tap()
        let changed = hint.label.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertTrue((11...30).contains(changed.first ?? -1))
        capture("2D-point-restarted-with-new-range")
    }

    private func start(_ prefix: String, name: String) {
        let button = app.buttons[prefix + ".start"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: prefix + ".scene").firstMatch.exists)
        XCTAssertTrue(app.staticTexts["练习模式"].exists)
        for mode in ["自由练习", "20题"] {
            for _ in 0..<3 where !app.buttons[mode].isHittable { app.swipeDown() }
            app.buttons[mode].tap()
            capture(name + "-settings-" + mode)
            for id in ["training.cueDistance", "training.pocketDistance", "training.pockets"] {
                let condition = app.buttons[id]
                for _ in 0..<3 where !condition.isHittable { app.swipeUp() }
                XCTAssertTrue(condition.exists, "球形条件默认展开，可滚动到达")
                let content = ([condition] + condition.descendants(matching: .any).allElementsBoundByIndex)
                    .map { $0.label + " " + ($0.value as? String ?? "") }.joined(separator: " ")
                XCTAssertTrue(content.contains("随机"), condition.debugDescription)
            }
        }
        capture(name + "-settings")
        button.tap()
        if UIDevice.current.userInterfaceIdiom == .pad { XCUIDevice.shared.orientation = .landscapeLeft }
    }
    private func checkAngle(_ mode: String) {
        open(mode + "角度"); start("angleTraining", name: mode + "-angle")
        let answer = app.buttons["答题"]
        XCTAssertTrue(answer.waitForExistence(timeout: 40))
        capture(mode + "-angle-observe")
        let assist = app.buttons["angleTraining.assist"]
        assist.tap(); assist.tap()
        answer.tap(); app.buttons["取消"].tap()
        XCTAssertTrue(answer.exists)
        answer.tap(); app.buttons["2"].firstMatch.tap(); app.buttons["0"].firstMatch.tap(); app.buttons["提交"].tap()
        XCTAssertTrue(app.buttons["angleTraining.primaryAction"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["angleTraining.retry"].exists)
        XCTAssertFalse(app.buttons["重试"].exists)
        XCTAssertFalse(answer.exists)
        capture(mode + "-angle-result")
        app.buttons["angleTraining.primaryAction"].tap()
        XCTAssertTrue(app.staticTexts["2/20"].waitForExistence(timeout: 5))
        checkSettingsCancel(prefix: "angleTraining", action: answer)
        checkRotations(prefix: "angleTraining", action: answer, name: mode + "-angle")
        app.buttons["angleTraining.settings"].tap(); app.buttons["angleTraining.finish"].tap()
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"training.summary").firstMatch.waitForExistence(timeout:5))
        capture(mode + "-angle-summary")
    }
    private func checkAimPoint(_ mode: String, nearLimit: Bool = false) {
        open(mode + "瞄准点", nearLimit: nearLimit); start("aimPointTraining", name: mode + "-point")
        let submit = app.buttons["aimPointTraining.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 40))
        let hint = app.buttons["aimPointTraining.angleHint"]
        XCTAssertFalse(app.staticTexts["aimPointTraining.angleHintText"].exists)
        hint.tap()
        let hintText = app.descendants(matching:.any).matching(identifier:"aimPointTraining.angleHintText").firstMatch
        XCTAssertTrue(hintText.waitForExistence(timeout:3))
        let originalHint = hintText.label
        capture(mode + "-point-hint")
        let wheel = app.descendants(matching:.any).matching(identifier:"aimPointTraining.aimWheel").firstMatch
        wheel.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.4)).press(forDuration:0.1,
            thenDragTo:wheel.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.6)))
        XCTAssertEqual(hintText.label, originalHint, "提示不随用户方向改变")
        hint.tap()
        if mode == "3D" {
            let top = app.buttons["shotCamera.temporaryTopDown"]
            top.tap(); capture("3D-point-temporary"); top.tap()
        }
        submit.tap()
        let next = app.buttons["aimPointTraining.next"]
        XCTAssertTrue(next.waitForExistence(timeout:5))
        XCTAssertGreaterThanOrEqual(next.frame.width,44)
        XCTAssertGreaterThanOrEqual(next.frame.height,44)
        let info = app.descendants(matching:.any).matching(identifier:"aimPointTraining.questionInfo").firstMatch
        let result = info.label
        capture(mode + "-point-result")
        sleep(3)
        XCUIDevice.shared.press(.home)
        app.activate()
        // Activation can return before UIKit finishes restoring the forced landscape frame.
        sleep(2)
        capture(mode + "-point-resumed")
        XCTAssertEqual(info.label,result)
        XCTAssertTrue(next.exists); XCTAssertFalse(submit.exists, "结果不得定时切题或出杆")
        XCTAssertFalse(app.staticTexts["验证中"].exists)
        XCTAssertFalse(app.buttons["aimPointTraining.retry"].exists)
        XCTAssertFalse(app.buttons["重试"].exists)
        next.tap()
        if nearLimit {
            XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"training.summary").firstMatch.waitForExistence(timeout:5))
            capture("2D-point-quota-summary")
            return
        }
        XCTAssertTrue(submit.waitForExistence(timeout:5))
        XCTAssertTrue(info.label.contains("2/20"))
        checkSettingsCancel(prefix:"aimPointTraining",action:submit)
        checkRotations(prefix:"aimPointTraining",action:submit,name:mode + "-point")
        app.buttons["aimPointTraining.settings"].tap(); app.buttons["aimPointTraining.finish"].tap()
        XCTAssertTrue(app.descendants(matching:.any).matching(identifier:"training.summary").firstMatch.waitForExistence(timeout:5))
        capture(mode + "-point-summary")
    }
    private func checkSettingsCancel(prefix: String, action: XCUIElement) {
        app.buttons[prefix + ".settings"].tap()
        app.buttons[prefix + ".trainingSettings"].tap()
        XCTAssertTrue(app.buttons["training.range.straight"].waitForExistence(timeout:5))
        app.buttons["training.range.straight"].tap()
        app.buttons["training.settingsCancel"].tap()
        XCTAssertTrue(action.waitForExistence(timeout:5))
    }
    private func checkRotations(prefix: String, action: XCUIElement, name: String) {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        XCUIDevice.shared.orientation = .portrait; sleep(2)
        XCTAssertTrue(action.isHittable)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(action.frame))
        capture(name + "-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft; sleep(2)
        XCTAssertTrue(action.isHittable); capture(name + "-landscape")
    }
}
