import XCTest

/// v49 W4：c052 / c053 详情与精讲的 Light / Dark 页面取证。
final class V49W4CopyEvidenceUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW4_Light_01_C052Detail() {
        captureDetail(
            drillId: "drill_c052",
            title: "极薄角度球",
            focus: "把切角从中大逐步推到极薄",
            suffix: "Light"
        )
    }

    func testW4_Light_02_C052Tutorial() {
        captureTutorial(
            drillId: "drill_c052",
            title: "极薄角度球",
            principle: "厚薄靠瞄准，进袋速度靠力度",
            suffix: "Light",
            bottomSwipes: 7
        )
    }

    func testW4_Light_03_C053Detail() {
        captureDetail(
            drillId: "drill_c053",
            title: "中袋角度球",
            focus: "母球沿 L 形两侧换位",
            suffix: "Light"
        )
    }

    func testW4_Light_04_C053Tutorial() {
        captureC053Tutorial(suffix: "Light")
    }

    func testW4_Dark_01_C052Detail() {
        captureDetail(
            drillId: "drill_c052",
            title: "极薄角度球",
            focus: "把切角从中大逐步推到极薄",
            suffix: "Dark"
        )
    }

    func testW4_Dark_02_C052Tutorial() {
        captureTutorial(
            drillId: "drill_c052",
            title: "极薄角度球",
            principle: "厚薄靠瞄准，进袋速度靠力度",
            suffix: "Dark",
            bottomSwipes: 7
        )
    }

    func testW4_Dark_03_C053Detail() {
        captureDetail(
            drillId: "drill_c053",
            title: "中袋角度球",
            focus: "母球沿 L 形两侧换位",
            suffix: "Dark"
        )
    }

    func testW4_Dark_04_C053Tutorial() {
        captureC053Tutorial(suffix: "Dark")
    }

    private func captureDetail(drillId: String, title: String, focus: String, suffix: String) {
        let app = launch(drillId: drillId, suffix: suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))
        XCTAssertTrue(scrollToTextContaining(app, focus), "\(drillId) 详情应显示 W4 描述")
        savePNG(app, "w4-\(drillId)-detail-\(suffix)")
    }

    private func captureTutorial(
        drillId: String,
        title: String,
        principle: String,
        suffix: String,
        bottomSwipes: Int
    ) {
        let app = openTutorial(drillId: drillId, title: title, suffix: suffix)
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", principle)
            ).firstMatch.waitForExistence(timeout: 8),
            "\(drillId) 精讲应显示 W4 技术原理"
        )
        savePNG(app, "w4-\(drillId)-tutorial-top-\(suffix)")

        for _ in 0..<bottomSwipes {
            app.swipeUp()
            usleep(250_000)
        }
        savePNG(app, "w4-\(drillId)-tutorial-later-\(suffix)")
    }

    private func captureC053Tutorial(suffix: String) {
        let app = openTutorial(drillId: "drill_c053", title: "中袋角度球", suffix: suffix)
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "正反两边都能重新找准厚薄")
            ).firstMatch.waitForExistence(timeout: 8)
        )
        savePNG(app, "w4-drill_c053-tutorial-f1-\(suffix)")

        let picker = app.segmentedControls["tutorialFormationPicker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8), "c053 精讲应显示球形切换")
        let formation2 = picker.buttons.element(boundBy: 1)
        XCTAssertTrue(formation2.exists, "c053 精讲应有球形 2")
        formation2.tap()

        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "第 11 杆示范母球落袋")
            ).firstMatch.waitForExistence(timeout: 8),
            "c053 球形 2 应披露第 11 杆示范摔袋"
        )
        savePNG(app, "w4-drill_c053-tutorial-f2-\(suffix)")

        for _ in 0..<11 {
            app.swipeUp()
            usleep(250_000)
        }
        savePNG(app, "w4-drill_c053-tutorial-f2-later-\(suffix)")
    }

    private func openTutorial(drillId: String, title: String, suffix: String) -> XCUIApplication {
        let app = launch(drillId: drillId, suffix: suffix)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12))

        let tutorial = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !tutorial.exists {
            app.swipeUp()
            usleep(300_000)
        }
        XCTAssertTrue(tutorial.exists, "\(drillId) 应有精讲入口")
        tutorial.tap()
        XCTAssertTrue(app.staticTexts["技术原理"].waitForExistence(timeout: 15))
        return app
    }

    private func scrollToTextContaining(_ app: XCUIApplication, _ text: String) -> Bool {
        let element = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", text)
        ).firstMatch
        if element.waitForExistence(timeout: 4) { return true }
        for _ in 0..<8 {
            app.swipeUp()
            usleep(300_000)
            if element.exists { return true }
        }
        return element.exists
    }

    private func launch(drillId: String, suffix: String) -> XCUIApplication {
        var args = ["-deeplink.drillDetail=\(drillId)", "-forcePremium"]
        if suffix == "Light" { args.append("-v49.forceLight") }
        return XCUIApplication.launchClean(extraArgs: args)
    }

    private func savePNG(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let url = outDir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            print("[V49-W4-SCREENSHOT] \(url.path)")
        } catch {
            XCTFail("写截图失败 \(name): \(error)")
        }
    }
}
