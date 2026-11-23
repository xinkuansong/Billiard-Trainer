import XCTest

/// v29 W7：计划推进的模拟器实跑取证。
///
/// 流程：激活官方计划（第 1 周第 1 天）→ 截图改前 → GO! 录一组计划训练并保存
/// → 回训练首页截图改后（应为第 1 周第 2 天）→ 用「今日安排」的进度菜单
/// 跳过一天（第 3 天）→ 回退一天（回到第 2 天）。
///
/// 截图落盘 `build/w7-screenshots/`；周 / 天断言读「今日安排」卡片的无障碍标签
/// （`今日安排，<计划名>，第 X 周第 Y 天`）与元信息行文案（`第 X 周 · 第 Y 天`）。
final class V29W7PlanProgressUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: #filePath, isDirectory: false
    )
        .deletingLastPathComponent()   // QiuJiUITests/
        .deletingLastPathComponent()   // <repo root>
        .appendingPathComponent("build/w7-screenshots", isDirectory: true)

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testV29W7_planTrainingAdvancesDay_andManualSkipRollback() throws {
        try activateOfficialPlan()

        app.switchTab(.training)
        sleep(3)
        snap("10-before-week1-day1")
        XCTAssertTrue(hasSchedule(week: 1, day: 1),
                      "激活后应停在第 1 周第 1 天，实际卡片文案：\(scheduleTexts())")

        try recordPlanTraining()

        app.switchTab(.training)
        sleep(4)
        snap("20-after-plan-training-week1-day2")
        XCTAssertTrue(hasSchedule(week: 1, day: 2),
                      "完成一次计划训练后应推进到第 1 周第 2 天，实际：\(scheduleTexts())")

        try openProgressMenuAndTap("跳过今天")
        sleep(3)
        snap("30-after-skip-week1-day3")
        XCTAssertTrue(hasSchedule(week: 1, day: 3),
                      "跳过今天后应到第 1 周第 3 天，实际：\(scheduleTexts())")

        try openProgressMenuAndTap("回退一天")
        sleep(3)
        snap("40-after-rollback-week1-day2")
        XCTAssertTrue(hasSchedule(week: 1, day: 2),
                      "回退一天后应回到第 1 周第 2 天，实际：\(scheduleTexts())")
    }

    // MARK: - Steps

    private func activateOfficialPlan() throws {
        app.switchTab(.training)
        sleep(3)
        snap("00-training-home")

        if app.buttons["GO!"].waitForExistence(timeout: 3) { return }

        var activated = false
        for attempt in 0..<4 {
            let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS '周'"))
            guard cards.count > attempt else { break }
            cards.element(boundBy: attempt).tap()
            sleep(3)
            snap("01-plan-detail-\(attempt)")

            if tapLabel("开始此计划", timeout: 6) {
                sleep(1)
                if tapLabel("确定激活", timeout: 5) {
                    sleep(3)
                    snap("02-plan-activated")
                    activated = true
                }
            }
            goBack()
            sleep(2)
            if activated { break }
        }

        XCTAssertTrue(activated, "应能激活一个免费官方计划（W7 推进取证的前置）")
    }

    private func recordPlanTraining() throws {
        guard tapLabel("GO!", timeout: 10) else {
            snap("11-no-go-button")
            dumpHierarchy("11-no-go-button")
            XCTFail("激活计划后训练首页应出现 GO! 入口")
            return
        }
        sleep(4)
        snap("12-plan-training-overview")

        if tapLabel("切换到单项视图", timeout: 4) { sleep(2) }

        let madeField = app.textFields["-"].firstMatch
        if madeField.waitForExistence(timeout: 6) {
            madeField.tap()
            madeField.typeText("6")
            sleep(1)
            dismissKeyboard()
        }
        snap("13-set-filled")

        let markDone = app.buttons["标记完成"].firstMatch
        if markDone.waitForExistence(timeout: 6) {
            markDone.tap()
            sleep(3)
            if tapLabel("完成休息", timeout: 4) { sleep(2) }
        }

        let end = app.buttons["结束训练"].firstMatch
        if end.waitForExistence(timeout: 8) {
            end.tap()
        } else {
            _ = tapLabel("结束", timeout: 5)
        }
        sleep(1)
        let confirm = app.alerts.buttons["结束"]
        if confirm.waitForExistence(timeout: 5) { confirm.tap() }
        sleep(3)

        if tapLabel("完成", timeout: 8) { sleep(2) }
        snap("14-summary")

        guard tapLabel("保存训练", timeout: 10) else {
            snap("15-no-save")
            dumpHierarchy("15-no-save")
            XCTFail("总结页应有「保存训练」")
            return
        }
        sleep(4)
        snap("16-after-save")
    }

    private func openProgressMenuAndTap(_ item: String) throws {
        let menu = app.buttons["调整计划进度"].firstMatch
        guard menu.waitForExistence(timeout: 8) else {
            snap("50-no-progress-menu")
            dumpHierarchy("50-no-progress-menu")
            XCTFail("「今日安排」应有调整计划进度的入口")
            return
        }
        menu.tap()
        sleep(2)
        snap("51-progress-menu-open-\(item)")

        guard tapLabel(item, timeout: 6) else {
            dumpHierarchy("52-no-menu-item-\(item)")
            XCTFail("进度菜单应有「\(item)」")
            return
        }
    }

    // MARK: - Assertions

    /// 「今日安排」卡片是否显示指定周 / 天（无障碍标签或元信息行任一命中即可）。
    private func hasSchedule(week: Int, day: Int) -> Bool {
        let combined = "第 \(week) 周第 \(day) 天"
        let metaWeek = "第 \(week) 周"
        let metaDay = "第 \(day) 天"
        return scheduleTexts().contains { label in
            label.contains(combined) || (label.contains(metaWeek) && label.contains(metaDay))
        }
    }

    private func scheduleTexts() -> [String] {
        let predicate = NSPredicate(format: "label CONTAINS '今日安排'")
        var labels = app.descendants(matching: .any).matching(predicate)
            .allElementsBoundByIndex.map(\.label)
        labels += app.staticTexts.matching(NSPredicate(format: "label CONTAINS '周'"))
            .allElementsBoundByIndex.map(\.label)
        return labels
    }

    // MARK: - Helpers

    private func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else { return }
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
            .press(forDuration: 0.2,
                   thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)),
                   withVelocity: .slow,
                   thenHoldForDuration: 0.5)
        sleep(1)
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists && back.isHittable { back.tap() }
    }

    @discardableResult
    private func tapLabel(_ label: String, timeout: TimeInterval = 6) -> Bool {
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }
        let text = app.staticTexts[label].firstMatch
        if text.waitForExistence(timeout: 1) {
            text.tap()
            return true
        }
        return false
    }

    private func dumpHierarchy(_ name: String) {
        try? app.debugDescription.write(
            to: outDir.appendingPathComponent("\(name)-hierarchy.txt"),
            atomically: true, encoding: .utf8
        )
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: outDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
