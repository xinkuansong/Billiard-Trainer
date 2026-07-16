import XCTest

/// v7 W4：球库拖球放置 / 拖回删球 / pulse 取证。
/// 截图写入 `build/w4-screenshots/`（禁止覆盖 `docs/ui-polish/` 与 DrillThumbnails）。
final class W4_BallPaletteUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w4-screenshots")
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

    /// Composer：拖 9 号上桌 → 截图 → 点库内 9 号 pulse → 再拖回球库删球。
    func testW4ComposerDragPlacePulseRemove() {
        let app = XCUIApplication.launchClean()
        guard openCard(app: app, homeTab: "打", title: "自由走位") else {
            XCTFail("未能进入自由走位"); return
        }
        snap(app, "w4-composer-01-initial")

        let ball9 = paletteBall(app, "_9")
        XCTAssertTrue(ball9.waitForExistence(timeout: 8), "球库应有 9 号")
        let table = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.42))
        ball9.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.35, thenDragTo: table)
        sleep(2)
        snap(app, "w4-composer-02-after-place")

        // pulse：再点库内已上桌的 9 号
        if ball9.exists {
            ball9.tap()
            usleep(500_000)
            snap(app, "w4-composer-03-after-pulse")
        }

        // 拖回删球：从台面中部拖向底部球库带
        let fromTable = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.42))
        let toPalette = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.92))
        fromTable.press(forDuration: 0.35, thenDragTo: toPalette)
        sleep(2)
        snap(app, "w4-composer-04-after-drag-back")
    }

    /// Snooker：拖球放置 + pulse。
    func testW4SnookerDragPlacePulse() {
        let app = XCUIApplication.launchClean()
        guard openCard(app: app, homeTab: "解", title: "防守") else {
            XCTFail("未能进入防守"); return
        }
        snap(app, "w4-snooker-01-initial")

        let ball9 = paletteBall(app, "_9")
        XCTAssertTrue(ball9.waitForExistence(timeout: 8), "球库应有 9 号")
        let table = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.40))
        ball9.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.35, thenDragTo: table)
        sleep(2)
        snap(app, "w4-snooker-02-after-place")
        if ball9.exists {
            ball9.tap()
            usleep(500_000)
            snap(app, "w4-snooker-03-after-pulse")
        }
    }

    /// Extraction：经 `-extract.confirmDemo` 直进确认步，拖球放置 + pulse + 拖回删球取证。
    func testW4ExtractionPaletteInteraction() {
        let app = XCUIApplication.launchClean(extraArgs: ["-extract.confirmDemo"])
        guard openCard(app: app, homeTab: "打", title: "拍照建球形") else {
            XCTFail("未能进入拍照建球形"); return
        }
        snap(app, "w4-extraction-01-entry")

        let ball1 = paletteBall(app, "_1")
        XCTAssertTrue(ball1.waitForExistence(timeout: 8), "确认步应有交互球库（-extract.confirmDemo）")
        let table = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.40))
        ball1.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.35, thenDragTo: table)
        sleep(2)
        snap(app, "w4-extraction-02-after-place")
        if ball1.exists {
            ball1.tap()
            usleep(500_000)
            snap(app, "w4-extraction-03-after-pulse")
        }
        // 拖回删球：台面中部 → 底部球库带
        let fromTable = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.40))
        let toPalette = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.93))
        fromTable.press(forDuration: 0.35, thenDragTo: toPalette)
        sleep(2)
        snap(app, "w4-extraction-04-after-drag-back")
    }
}
