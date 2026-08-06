import XCTest

/// v29 W4：训练录入链路接上新字段的实跑取证。
///
/// 两段流程：
/// 1. **计划训练** —— 激活一个官方计划 → GO! → 录一组 → 写心得 → 保存
///    （证 `TrainingSession.planId` 不再是死字段）；
/// 2. **自由训练 + 多球形 drill** —— 加入 `中袋角度精准`（drill_c053，Bundle 内两条序列）
///    → 在「球形」列选择本组球形 → 写心得 → 保存
///    （证 `DrillSet.formationToken/formationName` 与 `DrillEntry.note` 有值）。
///
/// 截图落盘 `build/w4-screenshots/`；落库校验在测试外用 sqlite3 直查模拟器 store
/// （UI 测试进程读不到宿主 App 的 SwiftData 容器）。
final class V29W4TrainingRecordUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer-v29w4/build/w4-screenshots",
        isDirectory: true
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    /// 自由训练先做：训练首页只在**无激活计划**时露出「自由记录」入口
    /// （有计划时首页换成当日计划卡，`quickStartBanner` 不再渲染）。
    func testV29W4_planTrainingAndMultiFormationRecording() throws {
        try recordFreeTrainingWithFormationPicker()
        try activateOfficialPlan()
        try recordPlanTraining()
    }

    // MARK: - Step 1: activate an official plan

    private func activateOfficialPlan() throws {
        app.switchTab(.training)
        sleep(3)
        snap("00-training-home")

        // 已有激活计划（重跑场景）直接跳过激活。
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
                snap("02-activate-confirm")
                if tapLabel("确定激活", timeout: 5) {
                    sleep(3)
                    snap("03-plan-activated")
                    activated = true
                }
            }
            goBack()
            sleep(2)
            if activated { break }
        }

        XCTAssertTrue(activated, "应能激活一个免费官方计划（W4 计划训练取证前置）")
    }

    // MARK: - Step 2: plan training → planId

    private func recordPlanTraining() throws {
        app.switchTab(.training)
        sleep(3)
        snap("10-training-home-with-plan")

        guard tapLabel("GO!", timeout: 10) else {
            snap("11-no-go-button")
            dumpHierarchy("11-no-go-button")
            XCTFail("激活计划后训练首页应出现 GO! 入口")
            return
        }
        sleep(4)
        snap("12-plan-training-overview")

        recordOneSetWithNote(note: "计划训练：热身手感偏慢", tag: "13-plan")
        finishAndSave(tag: "14-plan")
    }

    // MARK: - Step 3: free training with a multi-formation drill

    private func recordFreeTrainingWithFormationPicker() throws {
        app.switchTab(.training)
        sleep(4)
        snap("19-training-home-no-plan")

        guard tapLabel("自由记录", timeout: 10) else {
            snap("20-no-free-entry")
            dumpHierarchy("20-no-free-entry")
            XCTFail("训练首页应有「自由记录」入口")
            return
        }
        sleep(3)

        guard tapLabel("添加训练动作", timeout: 8) else {
            snap("21-no-add-drill")
            XCTFail("自由训练空态应有「添加训练动作」")
            return
        }
        sleep(3)

        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 6) {
            search.tap()
            search.typeText("中袋角度精准")
            sleep(2)
        }
        snap("22-drill-picker-search")

        let addC053 = app.buttons["添加中袋角度精准"].firstMatch
        guard addC053.waitForExistence(timeout: 8) else {
            snap("23-no-c053-row")
            dumpHierarchy("23-no-c053-row")
            XCTFail("动作选择器应能搜到多球形动作「中袋角度精准」")
            return
        }
        addC053.tap()
        sleep(2)
        snap("23-drill-added")
        dumpHierarchy("23-drill-added")

        // 搜索态下导航栏被搜索框顶掉，「完成(N)」不在屏上：先退出搜索态再收键盘。
        // iOS 26 的 `.searchable` 退出按钮 accessibility label = "close"（实测层级树）。
        for label in ["close", "取消", "Cancel"] {
            let cancel = app.buttons[label].firstMatch
            if cancel.exists && cancel.isHittable {
                cancel.tap()
                sleep(2)
                break
            }
        }
        dismissKeyboard()
        for _ in 0..<3 {
            guard pickerIsOpen else { break }
            let done = app.buttons["完成(1)"].firstMatch
            if done.waitForExistence(timeout: 4) {
                done.tap()
            } else {
                // 兜底：下拉关闭 sheet。
                app.windows.firstMatch
                    .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
                    .press(forDuration: 0.1,
                           thenDragTo: app.windows.firstMatch
                            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
            }
            sleep(3)
        }
        sleep(2)
        snap("24-free-training-overview")
        if pickerIsOpen {
            dumpHierarchy("24-picker-still-open")
            XCTFail("动作选择器未能关闭")
            return
        }

        // 进单项录入页（总览页不出球形列）。
        if tapLabel("切换到单项视图", timeout: 6) { sleep(3) }
        snap("25-drill-record-with-formation-column")

        // 「球形」列应存在，且默认已落到第一个球形。
        let formationMenu = app.buttons
            .matching(NSPredicate(format: "label CONTAINS '组球形'")).firstMatch
        guard formationMenu.waitForExistence(timeout: 8) else {
            snap("26-no-formation-menu")
            dumpHierarchy("26-no-formation-menu")
            XCTFail("多球形 drill 的录入行应出现「球形」选择入口")
            return
        }
        XCTAssertFalse(
            formationMenu.label.contains("未选择"),
            "多球形 drill 应默认落到第一个球形，实际：\(formationMenu.label)"
        )

        formationMenu.tap()
        sleep(2)
        snap("27-formation-menu-open")

        // 选第二个球形（证明选择确实改写本组归属，而不是恒等于默认值）。
        let secondFormation = app.buttons
            .matching(NSPredicate(format: "label CONTAINS '球形2'")).firstMatch
        if secondFormation.waitForExistence(timeout: 5) {
            secondFormation.tap()
        } else {
            snap("28-no-second-formation")
            dumpHierarchy("28-no-second-formation")
            XCTFail("球形菜单应列出 drill_c053 的第二个球形")
            return
        }
        sleep(2)
        snap("29-formation-selected")

        recordOneSetWithNote(note: "自由训练：球形2 薄球吃厚", tag: "30-free")
        finishAndSave(tag: "31-free")
    }

    // MARK: - Shared recording steps

    /// 录一组成绩 + 写本项心得（心得直连 `drillNotes`，落 `DrillEntry.note`）。
    private func recordOneSetWithNote(note: String, tag: String) {
        if tapLabel("切换到单项视图", timeout: 4) { sleep(2) }

        let noteField = app.textFields["记录本项心得..."].firstMatch
        if noteField.waitForExistence(timeout: 8) {
            noteField.tap()
            noteField.typeText(note)
            sleep(1)
            snap("\(tag)-a-note-typed")
        } else {
            snap("\(tag)-a-no-note-field")
            dumpHierarchy("\(tag)-a-no-note-field")
            XCTFail("录入页应有本项心得输入框（W4 打通 drillNotes 的 UI 入口）")
        }
        dismissKeyboard()

        // 填进球数（第一个可编辑的「进球」输入格）。
        let madeField = app.textFields["-"].firstMatch
        if madeField.waitForExistence(timeout: 5) {
            madeField.tap()
            madeField.typeText("6")
            sleep(1)
            dismissKeyboard()
        }
        snap("\(tag)-b-set-filled")

        // 勾选完成 → 触发每组计时写入 `DrillSetData.duration`。
        let markDone = app.buttons["标记完成"].firstMatch
        if markDone.waitForExistence(timeout: 6) {
            markDone.tap()
            sleep(3)
            // 组间休息倒计时会盖住页面，直接跳过。
            if tapLabel("完成休息", timeout: 4) { sleep(2) }
        }
        snap("\(tag)-c-set-completed")
    }

    private func finishAndSave(tag: String) {
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
        snap("\(tag)-a-note-page")

        if tapLabel("完成", timeout: 8) { sleep(2) }
        snap("\(tag)-b-summary")

        guard tapLabel("保存训练", timeout: 10) else {
            snap("\(tag)-c-no-save")
            dumpHierarchy("\(tag)-c-no-save")
            XCTFail("总结页应有「保存训练」")
            return
        }
        sleep(4)
        snap("\(tag)-d-after-save")
    }

    // MARK: - Helpers

    private var pickerIsOpen: Bool {
        app.staticTexts["选择训练动作"].exists || app.navigationBars["选择训练动作"].exists
    }

    private func dismissKeyboard() {
        if app.keyboards.buttons["search"].exists {
            app.keyboards.buttons["search"].tap()
            sleep(1)
        }
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
