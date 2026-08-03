import XCTest

/// v27 W2：封面分区色板 + glyph token + 缩略图相框取证。
///
/// 外观切换：事先 `xcrun simctl ui <udid> appearance light|dark`，再分别跑 light / dark 用例。
/// 截图落盘 `build/w2-screenshots/`。
final class V27W2ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w2-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW2_LightScreenshots() throws {
        try captureSeries(suffix: "Light")
    }

    func testW2_DarkScreenshots() throws {
        try captureSeries(suffix: "Dark")
    }

    private func captureSeries(suffix: String) throws {
        // 1) Training — plan poster covers (CoverPalette.PlanStyle)
        app.switchTab(.training)
        sleep(2)
        let official = app.buttons["官方计划"]
        if official.waitForExistence(timeout: 4) {
            official.tap()
            sleep(1)
        }
        try savePNG("training-plan-covers-\(suffix)")

        // 2) Drill library — grid thumbnail frame (vignette + corner)
        app.switchTab(.drillLibrary)
        sleep(2)
        let allSidebar = app.descendants(matching: .any)["sidebar_全部"]
        if allSidebar.waitForExistence(timeout: 5) {
            allSidebar.tap()
            sleep(1)
        }
        try savePNG("drill-library-grid-frame-\(suffix)")

        // 3) Favorites list — 64×64 BTDrillThumbnail frame (if reachable)
        app.switchTab(.profile)
        sleep(1)
        let favorites = app.staticTexts["我的收藏"].firstMatch
        if favorites.waitForExistence(timeout: 3) {
            favorites.tap()
            sleep(2)
            let row = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'drillCard_' OR label CONTAINS '推荐'"))
                .firstMatch
            if row.waitForExistence(timeout: 3) {
                try savePNG("favorites-row-thumbnail-frame-\(suffix)")
            } else {
                try savePNG("favorites-row-thumbnail-empty-\(suffix)")
            }
            app.tapBackButton()
            sleep(1)
        } else {
            try savePNG("favorites-row-thumbnail-skipped-\(suffix)")
        }

        // 4) Practice tab — full scroll covering 学 / 练 / 打 / 解
        app.switchTab(.angle)
        sleep(2)
        try savePNG("practice-home-top-\(suffix)")

        // Prefer 「全部」 so all zones appear in one scroll (`angleHomeTab_*`).
        let practiceAll = app.descendants(matching: .any)["angleHomeTab_全部"]
        if practiceAll.waitForExistence(timeout: 3) {
            practiceAll.tap()
            sleep(1)
        }

        try savePNG("practice-zone-learn-\(suffix)")
        app.scrollDown(times: 2)
        sleep(1)
        try savePNG("practice-zone-train-\(suffix)")
        app.scrollDown(times: 2)
        sleep(1)
        try savePNG("practice-zone-play-\(suffix)")
        app.scrollDown(times: 2)
        sleep(1)
        try savePNG("practice-zone-solve-\(suffix)")

        // Section sidebars for clearer per-zone evidence
        for (id, name) in [
            ("angleHomeTab_学", "learn"),
            ("angleHomeTab_练", "train"),
            ("angleHomeTab_打", "play"),
            ("angleHomeTab_解", "solve"),
        ] {
            let chip = app.descendants(matching: .any)[id]
            if chip.waitForExistence(timeout: 2) {
                chip.tap()
                sleep(1)
                try savePNG("practice-section-\(name)-\(suffix)")
            }
        }
    }

    private func savePNG(_ name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        let file = outDir.appendingPathComponent("\(name).png")
        try shot.pngRepresentation.write(to: file)
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
