import XCTest

/// 问题集合 v31 W2 实跑取证：
/// 1. 自由训练加入多球形 drill（`drill_c013` 双球形、`drill_c042` 逐球形球数异构），
///    录入界面应按「球形 1 轮 1 → … → 球形 N 轮 M」展开，逐组预填对应球形；
///    保存后由测试外的 sqlite3 直查模拟器 store 验证 `DrillSet` 的
///    `formationToken` / `targetBalls`（UI 测试进程读不到宿主 App 的容器）。
/// 2. 动作库按「走位训练」筛选时，副分类为走位的跨类 drill 也应命中（契约 §3.3）。
///
/// 截图落 `build/v31-w2-screenshots/`。
final class V31W2MultiFormationUITests: XCTestCase {

    private let outDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // QiuJiUITests/
        .deletingLastPathComponent()   // <repo root>
        .appendingPathComponent("build/v31-w2-screenshots", isDirectory: true)

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    // MARK: - 1. 自由训练多球形展开

    func testV31W2_freeTrainingMultiFormationExpansion() throws {
        app.switchTab(.training)
        sleep(4)
        snap("01-training-home")

        // 无激活计划时，首页浮动 CTA「开始训练」即进入自由训练；
        // 空态横幅的「自由记录」按钮仅在部分布局下出现，作为备选入口。
        guard tapLabel("开始训练", timeout: 10) || tapLabel("自由记录", timeout: 5) else {
            snap("01x-no-free-entry")
            dumpHierarchy("01x-no-free-entry")
            XCTFail("训练首页应有自由训练入口（需无激活计划）")
            return
        }
        sleep(3)

        try addDrill(named: "底袋小角度入袋", tag: "02")
        try addDrill(named: "初级蛇彩走位", tag: "03")

        sleep(2)
        snap("04-free-training-overview")

        if tapLabel("切换到单项视图", timeout: 6) { sleep(3) }
        snap("05-record-c013-formation-groups")

        // 多球形 drill 的录入行必须逐组带球形（不是只有第一组有）。
        let formationMenus = app.buttons.matching(NSPredicate(format: "label CONTAINS '组球形'"))
        XCTAssertGreaterThanOrEqual(formationMenus.count, 2,
                                    "多球形 drill 的每一组都应出现球形选择入口")
        for index in 0..<formationMenus.count {
            let label = formationMenus.element(boundBy: index).label
            XCTAssertFalse(label.contains("未选择"), "第 \(index + 1) 组未预填球形：\(label)")
        }
        dumpHierarchy("05-record-c013")

        // 切到第二个 drill（异构逐球形球数）。
        if tapLabel("下一项", timeout: 4) { sleep(2) } else { app.windows.firstMatch.swipeLeft() }
        sleep(3)
        snap("06-record-c042-formation-groups")
        dumpHierarchy("06-record-c042")

        finishAndSave(tag: "07")
    }

    // MARK: - 2. 动作库副分类筛选

    func testV31W2_drillLibrarySecondaryCategoryFilter() {
        app.switchTab(.drillLibrary)
        sleep(4)
        snap("10-library-default")

        let positioning = app.descendants(matching: .any)["sidebar_走位训练"]
        guard positioning.waitForExistence(timeout: 8) else {
            snap("10x-no-sidebar")
            dumpHierarchy("10x-no-sidebar")
            XCTFail("动作库应有「走位训练」分类入口")
            return
        }
        positioning.tap()
        sleep(2)
        snap("11-library-positioning-filter")

        // 副分类命中：c018「侧旋走位控制」等主分类为杆法/控力/分离角的条目也应出现，
        // 且仍分在自己的主分类分节下。
        XCTAssertTrue(app.staticTexts["杆法训练"].waitForExistence(timeout: 5)
                      || app.staticTexts["控力训练"].waitForExistence(timeout: 2)
                      || app.staticTexts["分离角"].waitForExistence(timeout: 2),
                      "按走位训练筛选后，应出现副分类命中的其他主分类分节")
        dumpHierarchy("11-library-positioning-filter")
    }

    // MARK: - Steps

    private func addDrill(named name: String, tag: String) throws {
        guard tapLabel("添加训练动作", timeout: 8) else {
            snap("\(tag)x-no-add-drill")
            dumpHierarchy("\(tag)x-no-add-drill")
            XCTFail("自由训练页应有「添加训练动作」")
            return
        }
        sleep(3)

        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 6) {
            search.tap()
            search.typeText(name)
            sleep(2)
        }

        let addButton = app.buttons["添加\(name)"].firstMatch
        guard addButton.waitForExistence(timeout: 8) else {
            snap("\(tag)x-no-row-\(name)")
            dumpHierarchy("\(tag)x-no-row-\(name)")
            XCTFail("动作选择器应能搜到「\(name)」")
            return
        }
        addButton.tap()
        sleep(2)
        snap("\(tag)-added-\(name)")

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
            let done = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '完成('")).firstMatch
            if done.waitForExistence(timeout: 4) {
                done.tap()
            } else {
                app.windows.firstMatch
                    .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
                    .press(forDuration: 0.1,
                           thenDragTo: app.windows.firstMatch
                            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
            }
            sleep(3)
        }
        sleep(1)
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
            snap("\(tag)x-no-save")
            dumpHierarchy("\(tag)x-no-save")
            XCTFail("总结页应有「保存训练」")
            return
        }
        sleep(4)
        snap("\(tag)-c-after-save")
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
