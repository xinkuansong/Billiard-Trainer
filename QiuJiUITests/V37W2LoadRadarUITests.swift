import XCTest

/// v37 W2：详情页六轴雷达。截图落 `build/v37-w2-screenshots/`。
final class V37W2LoadRadarUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v37-w2-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testRadarShapesDifferAcrossThreeDrills() {
        captureRadarRelaunch(drillId: "drill_c001", search: "半台直线", slug: "c001-low")
        captureRadarRelaunch(drillId: "drill_c017", search: "低杆远台", slug: "c017-cue")
        captureRadarRelaunch(drillId: "drill_c040", search: "三库", slug: "c040-position")
    }

    func testRadarDarkMode() {
        let original = XCUIDevice.shared.appearance
        defer { XCUIDevice.shared.appearance = original }
        XCUIDevice.shared.appearance = .dark
        captureRadarRelaunch(drillId: "drill_c001", search: "半台直线", slug: "c001-dark")
    }

    private func captureRadarRelaunch(drillId: String, search: String, slug: String) {
        app.terminate()
        app = XCUIApplication.launchClean()
        app.switchTab(.drillLibrary)
        XCTAssertTrue(app.textFields["搜索动作"].waitForExistence(timeout: 8))
        let searchField = app.textFields["搜索动作"]
        searchField.tap()
        searchField.typeText(search)
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'drillCard_\(drillId)'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 8), "未找到 \(drillId)")
        card.tap()
        for _ in 0..<6 { app.swipeUp() }
        XCTAssertTrue(
            app.staticTexts["难度画像"].waitForExistence(timeout: 8),
            "\(drillId) 未显示难度画像雷达"
        )
        XCTAssertFalse(app.staticTexts["训练维度"].exists)
        XCTAssertFalse(app.staticTexts["执行负荷"].exists)
        savePNG(slug)
    }

    private func savePNG(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: outDir.appendingPathComponent("\(name).png"))
    }
}
