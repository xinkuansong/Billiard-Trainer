import XCTest

/// v27 W1：筛选 chip 三处收敛 + 网格覆层徽章可读性取证。
///
/// 外观切换：事先 `xcrun simctl ui <udid> appearance light|dark`，再分别跑 light / dark 用例。
/// 截图落盘 `build/w1-screenshots/`。
final class V27W1ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w1-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW1_LightScreenshots() {
        captureSeries(suffix: "Light")
    }

    func testW1_DarkScreenshots() {
        captureSeries(suffix: "Dark")
    }

    private func captureSeries(suffix: String) {
        // 1) Training filter chips
        app.switchTab(.training)
        sleep(2)
        let official = app.buttons["官方计划"]
        if official.waitForExistence(timeout: 4) {
            official.tap()
            sleep(1)
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["filterChip_全部"].waitForExistence(timeout: 5)
                || app.staticTexts["全部"].waitForExistence(timeout: 3),
            "训练页应出现筛选 chip"
        )
        savePNG("training-filter-chips-\(suffix)")

        // 2) Drill library — ball type + level chips + grid overlay badges
        app.switchTab(.drillLibrary)
        sleep(2)
        let allSidebar = app.descendants(matching: .any)["sidebar_全部"]
        if allSidebar.waitForExistence(timeout: 5) {
            allSidebar.tap()
            sleep(1)
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["levelFilter_全部"].waitForExistence(timeout: 5),
            "动作库等级 chip 应存在"
        )
        // v28 W3: ball-type chips moved into filter Menu; keep menu reachable.
        XCTAssertTrue(
            app.descendants(matching: .any)["badgeFilterMenu"].waitForExistence(timeout: 3),
            "动作库筛选菜单应存在（含球种）"
        )
        savePNG("drill-library-chips-\(suffix)")

        // Focus L1 初级 — grid card overlay badge readability
        let levelL1 = app.descendants(matching: .any)["levelFilter_初级"]
        if levelL1.waitForExistence(timeout: 3) {
            levelL1.tap()
            sleep(2)
        }
        savePNG("drill-library-grid-L1-badge-\(suffix)")

        // 3) Detail page default BTLevelBadge (light-surface / non-overlay)
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'drillCard_'"))
            .firstMatch
        if card.waitForExistence(timeout: 6) {
            card.tap()
            sleep(2)
            savePNG("drill-detail-level-badge-default-\(suffix)")
            app.tapBackButton()
            sleep(1)
        } else {
            XCTFail("筛选初级后应至少有一张网格卡")
        }

        // 4) Favorites list uses BTDrillCard (white-card default badge) if reachable
        app.switchTab(.profile)
        sleep(1)
        let favorites = app.staticTexts["我的收藏"].firstMatch
        if favorites.waitForExistence(timeout: 3) {
            favorites.tap()
            sleep(2)
            savePNG("favorites-list-badge-default-\(suffix)")
        } else {
            // Profile IA may differ; keep grid+detail evidence as primary.
            savePNG("favorites-list-badge-skipped-\(suffix)")
        }
    }

    private func savePNG(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let file = outDir.appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: file)
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
