import XCTest

/// 问题集合 v5 · V8（防守 Q16 + G17/Q15.3）截图核验。
///
/// 经 `RootView` 深链 launch arg 直接进防守页（绕过 Tab 导航——SceneKit 页冷启动导航偶发卡顿；
/// 深链启动稳定），三态盘面由 `SnookerTacticsView.onAppear` 读同一 arg 确定性注入并求解。
/// 盘面经 `SnookerSolverTests` 探针实测确认状态。生产无这些 arg ⇒ 深链/注入永不触发。
///
/// - 三态：完全斯诺克 / 高难度可行解 / 诚实无解。
/// - Q15.3：清除键（BTEraserButton 42×32）正常尺寸、紧贴「摆球」chip 右侧。
final class S8_SnookerV8UITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// 深链启动到防守页并截图。每次调用新起干净 App 进程。
    private func capture(arg: String, name: String, expectStatus: String? = nil) {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-\(arg)"]
        app.launch()
        // 顶栏「摆球」chip 为常驻 Button（BTChipRow）——出现即证明顶栏/球桌完成布局与淡入。
        let placeChip = app.buttons["摆球"]
        XCTAssertTrue(placeChip.waitForExistence(timeout: 20), "防守页顶栏「摆球」chip 应出现")
        if let s = expectStatus {
            let match = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", s)).firstMatch
            XCTAssertTrue(match.waitForExistence(timeout: 20), "应显示状态含：\(s)")
        }
        sleep(2)
        snap(app, name)
        app.terminate()
    }

    /// Q15.3：清除键正常尺寸、紧贴「摆球」chip 右侧（默认盘面）。
    func testV8ClearKeyLayout() {
        capture(arg: "deeplink.snooker", name: "v8-snooker-clearkey")
    }

    /// 完全斯诺克解（对方球组全部挡死）。
    func testV8CompleteSnooker() {
        capture(arg: "snooker.full", name: "v8-complete-snooker",
                expectStatus: "完全斯诺克")
    }

    /// 无完全解时的高难度可行解。
    func testV8HighDifficulty() {
        capture(arg: "snooker.partial", name: "v8-high-difficulty",
                expectStatus: "高难度可行解")
    }

    /// 诚实无解（母球无法合法首触目标球）。
    func testV8NoSolution() {
        capture(arg: "snooker.none", name: "v8-no-solution",
                expectStatus: "未找到可行防守解")
    }
}
