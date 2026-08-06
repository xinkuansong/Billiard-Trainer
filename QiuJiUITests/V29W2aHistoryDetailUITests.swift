import XCTest

/// v29 W2a：训练心得键盘收起 + 历史详情页按钮实效取证。
///
/// 流程：训练 Tab → 自由记录 → 添加动作 → 结束训练 → 心得页（下滑收键盘取证）
/// → 保存训练 → 记录 Tab → 打开详情 → 生成分享图 / 编辑心得 / 删除 逐个验证。
/// 截图落盘 `build/w2a-screenshots/`。
final class V29W2aHistoryDetailUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: #filePath, isDirectory: false
    )
        .deletingLastPathComponent()   // QiuJiUITests/
        .deletingLastPathComponent()   // <repo root>
        .appendingPathComponent("build/w2a-screenshots", isDirectory: true)

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    // MARK: - Main flow

    func testV29W2a_noteKeyboardAndHistoryDetailActions() throws {
        try recordOneTrainingSession()
        try inspectHistoryDetail()
    }

    // MARK: - Step 1: record a session (also covers the note page keyboard)

    private func recordOneTrainingSession() throws {
        app.switchTab(.training)
        sleep(2)

        if !tapLabel("自由记录", timeout: 8) {
            guard tapLabel("开始训练", timeout: 4) else {
                snap("00-no-free-record-entry")
                XCTFail("未能进入自由记录")
                return
            }
        }
        sleep(3)

        // Empty session → add one drill so the detail page has a drill card.
        if tapLabel("添加训练动作", timeout: 6) {
            sleep(3)
            snap("01-drill-picker")
            // First row of the fallback drill list (stable order): 握杆稳定性练习.
            let firstDrill = app.buttons["添加握杆稳定性练习"].firstMatch
            let firstCell = app.cells.firstMatch
            if firstDrill.waitForExistence(timeout: 10) {
                firstDrill.tap()
                sleep(2)
            } else if firstCell.waitForExistence(timeout: 4) {
                firstCell.tap()
                sleep(2)
            } else {
                snap("01b-no-drill-row")
                dumpHierarchy("01b-no-drill-row")
            }
            let done = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '完成'")).firstMatch
            if done.waitForExistence(timeout: 4) {
                done.tap()
            }
            sleep(3)
        }

        // Start the timer so the session has a non-zero duration; with 0 drills and
        // 0 elapsed seconds the nav「结束」dismisses instead of ending the session.
        if app.buttons["继续计时"].waitForExistence(timeout: 3) {
            app.buttons["继续计时"].tap()
            sleep(3)
        } else {
            _ = tapLabel("继续", timeout: 3)
            sleep(3)
        }
        snap("02-active-training")

        // End training → confirm
        let endTraining = app.buttons["结束训练"]
        if endTraining.waitForExistence(timeout: 8) {
            endTraining.tap()
        } else if tapLabel("结束", timeout: 4) {
            // tapped via helper
        } else {
            snap("03-no-end-button")
            XCTFail("未见结束训练入口")
            return
        }
        sleep(1)
        let confirmEnd = app.alerts.buttons["结束"]
        if confirmEnd.waitForExistence(timeout: 5) {
            confirmEnd.tap()
        }
        sleep(2)

        // ---- Note page: keyboard evidence ----
        snap("09-note-page-entry")
        let editor = app.textViews.firstMatch
        if !editor.waitForExistence(timeout: 10) {
            snap("09b-no-text-editor")
            dumpHierarchy("09b-no-text-editor")
            XCTFail("应进入训练心得页（TextEditor 存在）")
            return
        }
        editor.tap()
        sleep(1)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 6), "心得页应自动弹出键盘")
        snap("10-note-keyboard-up")

        editor.typeText("W2a note v1")
        sleep(1)
        snap("11-note-typed")

        // `.scrollDismissesKeyboard(.interactively)`: slow downward drag on the ScrollView.
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.6)
        sleep(2)
        snap("12-note-after-swipe-down")
        XCTAssertFalse(
            app.keyboards.firstMatch.exists,
            "下滑应能收起键盘（scrollDismissesKeyboard(.interactively)）"
        )

        // 完成 → summary → 保存训练
        let noteDone = app.buttons["完成"].firstMatch
        XCTAssertTrue(noteDone.waitForExistence(timeout: 5), "心得页应有「完成」按钮")
        noteDone.tap()
        sleep(2)
        snap("13-summary")

        guard tapLabel("保存训练", timeout: 8) else {
            snap("14-no-save-button")
            XCTFail("未见保存训练按钮")
            return
        }
        sleep(3)
        snap("15-after-save")
    }

    // MARK: - Step 2: history detail actions

    private func inspectHistoryDetail() throws {
        app.switchTab(.history)
        sleep(3)
        snap("20-history-list")

        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS '组' AND label CONTAINS '分钟'")).firstMatch
        guard row.waitForExistence(timeout: 8) else {
            snap("21-no-session-row")
            XCTFail("记录页未见训练记录行")
            return
        }
        row.tap()
        sleep(3)
        snap("22-detail-bottom-bar")

        // ---- 生成分享图 ----
        try openOverflowMenu()
        snap("30-overflow-menu")
        guard tapLabel("生成分享图", timeout: 5) else {
            snap("31-no-share-item")
            XCTFail("菜单未见「生成分享图」")
            return
        }
        sleep(3)
        snap("32-share-card")
        XCTAssertTrue(
            app.staticTexts["分享训练"].waitForExistence(timeout: 5)
                || app.buttons["保存相册"].waitForExistence(timeout: 2)
                || app.buttons["shareSaveToPhotos"].waitForExistence(timeout: 2),
            "「生成分享图」应打开 TrainingShareView 分享卡"
        )
        _ = tapLabel("返回", timeout: 5)
        sleep(2)
        snap("33-back-from-share")

        // ---- 编辑心得 ----
        try openOverflowMenu()
        guard tapLabel("编辑心得", timeout: 5) else {
            snap("40-no-note-item")
            XCTFail("菜单未见「编辑心得」")
            return
        }
        sleep(2)
        snap("41-note-editor")
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 6), "「编辑心得」应打开心得编辑器")
        editor.tap()
        editor.typeText(" edited v2")
        sleep(1)
        snap("42-note-editor-typed")
        let done = app.buttons["完成"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "心得编辑器应有「完成」")
        done.tap()
        sleep(3)
        snap("43-detail-after-note-save")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'edited v2'"))
                .firstMatch.waitForExistence(timeout: 6),
            "保存后详情页心得应显示新文本"
        )

        // ---- 删除 ----
        try openOverflowMenu()
        guard tapLabel("删除", timeout: 5) else {
            snap("50-no-delete-item")
            XCTFail("菜单未见「删除」")
            return
        }
        sleep(2)
        snap("51-delete-confirm")
        let confirmTitle = app.staticTexts["删除这条训练记录？"]
        XCTAssertTrue(
            confirmTitle.waitForExistence(timeout: 5) || app.sheets.firstMatch.exists,
            "删除应先弹确认对话框"
        )
        let confirmButtons = app.buttons.matching(NSPredicate(format: "label == '删除'"))
        let confirm = confirmButtons.count > 1
            ? confirmButtons.element(boundBy: confirmButtons.count - 1)
            : confirmButtons.firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "确认对话框应有「删除」")
        confirm.tap()
        sleep(3)
        snap("52-after-delete")

        XCTAssertTrue(
            app.staticTexts["当天无训练记录"].waitForExistence(timeout: 8)
                || app.staticTexts["还没有训练记录"].waitForExistence(timeout: 2),
            "删除后应返回记录页且该条记录消失"
        )
        snap("53-history-after-delete")
    }

    // MARK: - Helpers

    private func openOverflowMenu() throws {
        let menu = app.buttons["更多操作"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 8), "详情页应有「更多操作」菜单按钮")
        menu.tap()
        sleep(2)
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
        let text = app.debugDescription
        try? text.write(
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
