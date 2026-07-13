import XCTest

/// 问题集合 v5 · V7（打一走二想三 Q15.1/Q15.2/Q15.3）截图核验。
///
/// 经 `RootView` 深链 launch arg 直接进反解页（绕过 Tab 导航——SceneKit 页在冷启动导航
/// 偶发卡顿；深链启动稳定），中盘状态由 `PlanThreeView.onAppear` 读同一 arg 确定性注入。
/// 生产无这些 arg ⇒ 深链/注入永不触发。
///
/// - Q15.3：清除键正常尺寸、紧贴「摆球」chip 右侧（打三 + 思路两页）。
/// - Q15.1：扇形默认落区（高亮）↔ 用户自选约束后扇形降级（灰）。
/// - Q15.2：1 球 pot-only（「仅剩此球」可求解）+ 清台终局提示。
final class S7_PlanThreeV7UITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    /// 深链启动到反解页并截图。每次调用都新起一次干净 App 进程（状态干净），
    /// 因此单个用例内连续多次调用即「每页各 launch 一次干净 App」。
    private func capture(arg: String, name: String, expectStatus: String? = nil) {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-\(arg)"]
        app.launch()
        // 求解页顶栏「摆球」chip 为常驻 Button（BTChipRow）。等它出现即证明顶栏/球桌
        // 已完成布局与淡入，避免截到启动或页面过渡的泛白/发灰帧。
        let placeChip = app.buttons["摆球"]
        XCTAssertTrue(placeChip.waitForExistence(timeout: 20), "求解页顶栏「摆球」chip 应出现")
        if let s = expectStatus {
            let match = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", s)).firstMatch
            XCTAssertTrue(match.waitForExistence(timeout: 5), "应显示状态含：\(s)")
        }
        // 顶栏可交互后，SceneKit 球桌仍可能处于淡入尾段；再稳一拍确保整帧清晰。
        sleep(2)
        snap(app, name)
        // 显式回收当前进程，避免同一用例内下一次 launch 与旧进程重启竞态。
        app.terminate()
    }

    /// Q15.3：清除键正常尺寸、紧贴「摆球」chip 右侧（打三 + 思路两页）。
    /// 两页各自独立 launch 一次干净 App 取证，互不影响。
    func testV7ClearKeyLayout() {
        capture(arg: "deeplink.planThree", name: "v7-planthree-clearkey")
        capture(arg: "deeplink.silu", name: "v7-silu-clearkey")
    }

    func testV7SectorDefault() {
        capture(arg: "planThree.twoBall", name: "v7-sector-default",
                expectStatus: "扇形为默认落区")
    }

    func testV7SectorDimmed() {
        capture(arg: "planThree.twoBallDimmed", name: "v7-sector-dimmed",
                expectStatus: "约束就绪")
    }

    func testV7OneBallPotOnly() {
        capture(arg: "planThree.oneBall", name: "v7-oneball-potonly",
                expectStatus: "台面仅剩此球")
    }

    func testV7ClearedEndgame() {
        capture(arg: "planThree.cleared", name: "v7-endgame-cleared",
                expectStatus: "清台完成")
    }
}
