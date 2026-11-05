import XCTest

/// v8 X2：解三页球库统一为 regular 36 + 底栏重算；与 Composer 同帧对照。
/// 截图写入 worktree `build/x2-screenshots/`（禁止覆盖 docs/ui-polish 与 DrillThumbnails）。
final class X2_BallPaletteUnifyUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-x2/build/x2-screenshots")
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

    private func paletteBall(_ app: XCUIApplication, _ key: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "paletteBall_\(key)")).firstMatch
    }

    private func openCard(app: XCUIApplication, homeTab: String, title: String) -> Bool {
        app.switchTab(.angle)
        sleep(1)
        let seg = app.buttons["angleHomeTab_\(homeTab)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000)
        let card = app.buttons[title]
        guard card.waitForExistence(timeout: 4) else { return false }
        card.tap()
        sleep(3)
        return true
    }

    private func dragPlacePulseDragBack(app: XCUIApplication, prefix: String, key: String = "_9") {
        snap(app, "\(prefix)-01-initial")
        let ball = paletteBall(app, key)
        XCTAssertTrue(ball.waitForExistence(timeout: 8), "\(prefix) 球库应有 \(key)")
        let table = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.42))
        ball.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.35, thenDragTo: table)
        sleep(2)
        snap(app, "\(prefix)-02-after-place")
        if ball.exists {
            ball.tap()
            usleep(500_000)
            snap(app, "\(prefix)-03-after-pulse")
        }
        let fromTable = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.42))
        let toPalette = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.92))
        fromTable.press(forDuration: 0.35, thenDragTo: toPalette)
        sleep(2)
        snap(app, "\(prefix)-04-after-drag-back")
    }

    /// Composer 基准帧（regular 36 + 底栏 94）。
    func testX2ComposerBaseline() {
        let app = XCUIApplication.launchClean()
        guard openCard(app: app, homeTab: "打", title: "自由走位") else {
            XCTFail("未能进入自由走位"); return
        }
        dragPlacePulseDragBack(app: app, prefix: "x2-composer")
    }

    /// 思路训练：36 球径 + 底栏 94，拖球/pulse/拖回。
    func testX2SiluPalette() {
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.silu"])
        sleep(3)
        dragPlacePulseDragBack(app: app, prefix: "x2-silu")
    }

    /// 打一走二想三：36 球径 + 底栏 132（角色行+球库）。
    func testX2PlanThreePalette() {
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.planThree"])
        sleep(3)
        dragPlacePulseDragBack(app: app, prefix: "x2-planthree")
    }

    /// 斯诺克防守：36 球径 + 底栏 94。
    func testX2SnookerPalette() {
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.snooker"])
        sleep(3)
        dragPlacePulseDragBack(app: app, prefix: "x2-snooker")
    }
}
