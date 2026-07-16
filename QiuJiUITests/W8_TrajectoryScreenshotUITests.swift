import XCTest

/// v7 W8：Silu / PlanThree / Snooker / Composer 轨迹渲染截图取证。
/// 写入 `build/w8-screenshots/`（禁止覆盖 `docs/ui-polish/` 与 DrillThumbnails）。
final class W8_TrajectoryScreenshotUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-w8/build/w8-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func captureDeepLink(arg: String, name: String, expectStatus: String? = nil, waitSolve: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-\(arg)"]
        app.launch()
        let placeChip = app.buttons["摆球"]
        XCTAssertTrue(placeChip.waitForExistence(timeout: 20), "顶栏「摆球」应出现 (\(name))")
        if waitSolve {
            let solve = app.buttons["求解"]
            if solve.waitForExistence(timeout: 5), solve.isEnabled {
                solve.tap()
                sleep(3)
            }
        }
        if let s = expectStatus {
            let match = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", s)).firstMatch
            XCTAssertTrue(match.waitForExistence(timeout: 25), "应显示状态含：\(s) (\(name))")
        }
        sleep(2)
        snap(app, name)
        app.terminate()
    }

    /// Snooker 防守解轨迹（无 objectPath，ghost←firstContact）。
    func testW8SnookerTrajectory() {
        captureDeepLink(arg: "snooker.full", name: "w8-01-snooker-trajectory",
                        expectStatus: "完全斯诺克")
    }

    /// PlanThree：自选约束后求解，轨迹 + 约束青环同时可见。
    func testW8PlanThreeTrajectoryWithConstraint() {
        captureDeepLink(arg: "planThree.twoBallDimmed", name: "w8-02-planthree-trajectory-constraint",
                        expectStatus: nil, waitSolve: true)
    }

    /// Silu：默认盘面画约束并求解。
    func testW8SiluTrajectoryWithConstraint() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                                "-deeplink.silu"]
        app.launch()
        let placeChip = app.buttons["摆球"]
        XCTAssertTrue(placeChip.waitForExistence(timeout: 20), "Silu 顶栏「摆球」应出现")

        // 选「落区」工具拖一笔约束（coordinateSpace 经共享 overlay）。
        let region = app.buttons["落区"]
        if region.waitForExistence(timeout: 5) { region.tap(); usleep(400_000) }
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.42))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.58, dy: 0.55))
        start.press(forDuration: 0.15, thenDragTo: end)
        sleep(1)
        snap(app, "w8-03-silu-constraint-drawn")

        let solve = app.buttons["求解"]
        if solve.waitForExistence(timeout: 5), solve.isEnabled {
            solve.tap()
            sleep(4)
        }
        snap(app, "w8-04-silu-trajectory")
        app.terminate()
    }

    /// Composer（自由走位）：经练习 Tab「打」分组进入并截取默认轨迹。
    func testW8ComposerTrajectory() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        app.switchTab(.angle)
        sleep(1)
        let playSeg = app.buttons["angleHomeTab_打"]
        XCTAssertTrue(playSeg.waitForExistence(timeout: 5), "应找到「打」分段")
        playSeg.tap(); usleep(600_000)
        let card = app.buttons["自由走位"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "应找到「自由走位」入口")
        card.tap()
        sleep(3)
        let strike = app.buttons["击球"]
        _ = strike.waitForExistence(timeout: 10)
        sleep(2)
        snap(app, "w8-05-composer-trajectory")
        app.terminate()
    }
}
