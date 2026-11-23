import XCTest

/// v29 W2b：历史详情「编辑数据」实效取证。
///
/// 流程：训练 Tab → 自由记录 → 添加多球形 drill（厚球分离角控制，3 个球形）→ 结束训练
/// → 保存 → 记录 Tab → 详情 → 编辑数据 → 改 made / 用时 / 球形 → 保存 → 详情数字刷新
/// → 再次进入编辑器 → made > target → 保存被拒并弹提示。
/// 截图落盘 `build/w2b-screenshots/`。
final class V29W2bTrainingDataEditUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: #filePath, isDirectory: false
    )
        .deletingLastPathComponent()   // QiuJiUITests/
        .deletingLastPathComponent()   // <repo root>
        .appendingPathComponent("build/w2b-screenshots", isDirectory: true)

    /// 多球形 drill：`QiuJi/Resources/DrillBoards/drill_c026__manual0{1,2,3}-*.json`
    private let drillName = "厚球分离角控制"

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testV29W2b_editTrainingDataFlow() throws {
        try recordOneSession()
        try editData()
        try rejectInvalidInput()
    }

    // MARK: - Step 1: 录一条训练

    private func recordOneSession() throws {
        app.switchTab(.training)
        sleep(2)

        if !tapLabel("自由记录", timeout: 8) {
            XCTAssertTrue(tapLabel("开始训练", timeout: 4), "未能进入自由记录")
        }
        sleep(3)

        guard tapLabel("添加训练动作", timeout: 8) else {
            snap("00-no-add-drill")
            XCTFail("未见「添加训练动作」入口")
            return
        }
        sleep(2)

        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 6) {
            search.tap()
            search.typeText(drillName)
            // iOS 26 的底部搜索栏在编辑态会顶掉导航栏（「完成」不可达），先回车结束编辑。
            search.typeText("\n")
            sleep(2)
        }
        snap("01-drill-picker")
        dumpHierarchy("01-drill-picker")

        let addDrill = app.buttons["添加\(drillName)"].firstMatch
        guard addDrill.waitForExistence(timeout: 8) else {
            snap("01b-drill-not-found")
            XCTFail("动作选择器未见「\(drillName)」（多球形 drill）")
            return
        }
        addDrill.tap()
        sleep(2)
        snap("01c-drill-selected")
        dumpHierarchy("01c-drill-selected")
        XCTAssertTrue(
            app.buttons["取消选择\(drillName)"].waitForExistence(timeout: 5),
            "点击后该动作应变为已选中"
        )

        // iOS 26 搜索态是全屏覆盖，导航栏（含「完成」）不可达：先按 close 退出搜索。
        let done = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '完成'")).firstMatch
        if !done.waitForExistence(timeout: 3) {
            for label in ["close", "取消", "Cancel"] where app.buttons[label].exists {
                app.buttons[label].tap()
                break
            }
            sleep(2)
        }
        snap("01d-search-dismissed")
        XCTAssertTrue(done.waitForExistence(timeout: 8), "动作选择器应有「完成」按钮")
        done.tap()
        sleep(3)

        if app.buttons["继续计时"].waitForExistence(timeout: 3) {
            app.buttons["继续计时"].tap()
        } else {
            _ = tapLabel("继续", timeout: 3)
        }
        sleep(3)
        snap("02-active-training")

        let endTraining = app.buttons["结束训练"]
        if endTraining.waitForExistence(timeout: 8) {
            endTraining.tap()
        } else {
            XCTAssertTrue(tapLabel("结束", timeout: 4), "未见结束训练入口")
        }
        sleep(1)
        let confirmEnd = app.alerts.buttons["结束"]
        if confirmEnd.waitForExistence(timeout: 5) { confirmEnd.tap() }
        sleep(2)

        // 心得页直接完成
        if app.textViews.firstMatch.waitForExistence(timeout: 8) {
            let noteDone = app.buttons["完成"].firstMatch
            if noteDone.waitForExistence(timeout: 5) { noteDone.tap() }
        }
        sleep(2)
        snap("03-summary")

        guard tapLabel("保存训练", timeout: 8) else {
            snap("04-no-save")
            XCTFail("未见「保存训练」")
            return
        }
        sleep(3)
    }

    // MARK: - Step 2: 编辑数据

    private func editData() throws {
        try openDetail()
        snap("10-detail-before-edit")

        guard tapLabel("编辑数据", timeout: 8) else {
            snap("11-no-edit-button")
            XCTFail("详情页「编辑数据」未生效")
            return
        }
        sleep(2)
        snap("12-editor-opened")
        XCTAssertTrue(
            app.navigationBars["编辑数据"].waitForExistence(timeout: 6),
            "「编辑数据」应打开编辑器"
        )

        setField("editSetTarget_1", to: "9")
        setField("editSetMade_1", to: "7")
        setField("editSetDuration_1", to: "150")
        dismissKeyboard()
        snap("13-editor-values-typed")

        // 球形改为「球形2」
        let formation = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '第1组球形'")
        ).firstMatch
        if formation.waitForExistence(timeout: 5) {
            formation.tap()
            sleep(1)
            snap("14-formation-menu")
            let option = app.buttons.matching(
                NSPredicate(format: "label CONTAINS '球形2'")
            ).firstMatch
            if option.waitForExistence(timeout: 5) {
                option.tap()
                sleep(1)
            } else {
                XCTFail("球形菜单未见「球形2」选项")
            }
        } else {
            XCTFail("多球形 drill 的编辑器应出现球形选择")
        }
        snap("15-editor-formation-picked")

        app.buttons["dataEditorSave"].tap()
        sleep(3)
        snap("16-detail-after-save")

        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '7/9'"))
                .firstMatch.waitForExistence(timeout: 8),
            "保存后详情页该组应显示 7/9"
        )
    }

    // MARK: - Step 3: 非法输入被拒

    private func rejectInvalidInput() throws {
        guard tapLabel("编辑数据", timeout: 8) else {
            XCTFail("未能再次打开编辑器")
            return
        }
        sleep(2)

        setField("editSetMade_1", to: "99")
        dismissKeyboard()
        sleep(1)
        snap("20-editor-inline-error")
        XCTAssertTrue(
            app.staticTexts["editSetError_1"].waitForExistence(timeout: 5),
            "made > target 应即时给出行内提示"
        )

        app.buttons["dataEditorSave"].tap()
        sleep(2)
        snap("21-save-rejected-alert")
        XCTAssertTrue(
            app.alerts["无法保存"].waitForExistence(timeout: 5),
            "非法输入点保存应被拒并弹出提示"
        )
        app.alerts.buttons["确定"].tap()
        sleep(1)

        XCTAssertTrue(
            app.navigationBars["编辑数据"].exists,
            "被拒后编辑器应保持打开，用户修改不丢"
        )
        app.buttons["dataEditorCancel"].tap()
        sleep(2)
        snap("22-after-cancel")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '7/9'"))
                .firstMatch.waitForExistence(timeout: 6),
            "取消后详情页仍是上一轮保存的 7/9（非法值未落库）"
        )
    }

    // MARK: - Helpers

    private func openDetail() throws {
        app.switchTab(.history)
        sleep(3)
        let row = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '组' AND label CONTAINS '分钟'")
        ).firstMatch
        guard row.waitForExistence(timeout: 10) else {
            snap("09-no-session-row")
            XCTFail("记录页未见训练记录行")
            return
        }
        row.tap()
        sleep(3)
    }

    private func setField(_ identifier: String, to text: String) {
        let field = app.textFields[identifier]
        guard field.waitForExistence(timeout: 8) else {
            snap("field-missing-\(identifier)")
            XCTFail("编辑器缺少输入框 \(identifier)")
            return
        }
        // 点输入框右缘把光标落到文本末尾，否则删除键作用在行首等于没删。
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        sleep(1)
        // 空 TextField 的 value 是 placeholder（"—" / "0" 占位），只按数字位数删。
        let digits = ((field.value as? String) ?? "").filter(\.isNumber)
        if !digits.isEmpty {
            app.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: digits.count + 2))
        }
        app.typeText(text)
        sleep(1)
        XCTAssertEqual(
            ((field.value as? String) ?? "").filter(\.isNumber), text,
            "输入框 \(identifier) 应被改写为 \(text)"
        )
    }

    private func dismissKeyboard() {
        if app.keyboards.firstMatch.exists {
            app.navigationBars["编辑数据"].tap()
            sleep(1)
        }
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
            atomically: true,
            encoding: .utf8
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
