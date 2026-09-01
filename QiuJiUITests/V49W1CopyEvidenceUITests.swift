import XCTest

/// v49 W1：c001 / c011 / c012 文案样张的真实 App 取证。
///
/// 外观由执行脚本先通过 `simctl ui <udid> appearance light|dark` 设置，再分别运行
/// Light / Dark 用例。截图落盘 `build/v49-screenshots/`。
final class V49W1CopyEvidenceUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v49-screenshots"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW1_Light_01_C011Detail() { captureC011Detail(suffix: "Light") }
    func testW1_Light_02_C001Tutorial() { captureC001Tutorial(suffix: "Light") }
    func testW1_Light_03_C012Tutorial() { captureC012Tutorial(suffix: "Light") }
    func testW1_Light_04_Tryout() { captureTryout(suffix: "Light") }
    func testW1_Light_05_Plan() { capturePlan(suffix: "Light") }
    func testW1_Light_06_Record() { captureDrillRecord(suffix: "Light") }

    func testW1_Dark_01_C011Detail() { captureC011Detail(suffix: "Dark") }
    func testW1_Dark_02_C001Tutorial() { captureC001Tutorial(suffix: "Dark") }
    func testW1_Dark_03_C012Tutorial() { captureC012Tutorial(suffix: "Dark") }
    func testW1_Dark_04_Tryout() { captureTryout(suffix: "Dark") }
    func testW1_Dark_05_Plan() { capturePlan(suffix: "Dark") }
    func testW1_Dark_06_Record() { captureDrillRecord(suffix: "Dark") }

    func testW1_SmallLight_01_C001Tutorial() {
        captureC001Tutorial(suffix: "Small-Light")
    }

    func testW1_SmallLight_02_C012Tutorial() {
        captureC012Tutorial(suffix: "Small-Light")
    }

    private func captureC001Tutorial(suffix: String) {
        captureTutorial(
            drillId: "drill_c001",
            expectedTitle: "半台直线球",
            expectedPrinciple: "这组练换位后的直线出杆",
            suffix: suffix,
            bottomSwipes: 4
        )
    }

    private func captureC012Tutorial(suffix: String) {
        captureTutorial(
            drillId: "drill_c012",
            expectedTitle: "中袋直线出杆",
            expectedPrinciple: "进不进中袋，直接能看出",
            suffix: suffix,
            bottomSwipes: 7
        )
    }

    private func captureC011Detail(suffix: String) {
        let app = launch(extraArgs: ["-deeplink.drillDetail=drill_c011"], suffix: suffix)
        XCTAssertTrue(app.staticTexts["近台小角度进球"].waitForExistence(timeout: 12))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "每换一次位置，都重新找瞄准点")
            ).firstMatch.waitForExistence(timeout: 6),
            "c011 详情应显示新的最小训练命题"
        )
        savePNG(app, "w1-c011-detail-top-\(suffix)")

        let firstPoint = "先看 8 号球的进球线，再定母球该撞哪儿"
        XCTAssertTrue(scrollToText(app, firstPoint), "c011 详情应显示首要点")
        savePNG(app, "w1-c011-detail-coaching-\(suffix)")
    }

    private func captureTutorial(
        drillId: String,
        expectedTitle: String,
        expectedPrinciple: String,
        suffix: String,
        bottomSwipes: Int
    ) {
        let app = launch(extraArgs: ["-deeplink.drillDetail=\(drillId)"], suffix: suffix)
        XCTAssertTrue(app.staticTexts[expectedTitle].waitForExistence(timeout: 12))

        let tutorial = app.buttons["查看精讲"].firstMatch
        for _ in 0..<8 where !tutorial.exists {
            app.swipeUp()
            usleep(350_000)
        }
        XCTAssertTrue(tutorial.exists, "\(drillId) 应有精讲入口")
        tutorial.tap()

        XCTAssertTrue(app.staticTexts["技术原理"].waitForExistence(timeout: 15))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", expectedPrinciple)
            ).firstMatch.waitForExistence(timeout: 8),
            "\(drillId) 精讲应显示本轮技术原理"
        )
        savePNG(app, "w1-\(drillId)-tutorial-top-\(suffix)")

        for _ in 0..<bottomSwipes {
            app.swipeUp()
            usleep(300_000)
        }
        savePNG(app, "w1-\(drillId)-tutorial-later-\(suffix)")
    }

    private func captureTryout(suffix: String) {
        let focus = "换个位置，就从袋口重新拉线，再站上去"
        let app = launch(extraArgs: ["-deeplink.tryout=drill_c012"], suffix: suffix)
        XCTAssertTrue(app.staticTexts["训练重点"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[focus].waitForExistence(timeout: 8))
        savePNG(app, "w1-c012-tryout-brief-\(suffix)")
    }

    private func capturePlan(suffix: String) {
        let quote = "换个位置，就从袋口重新拉线，再站上去"
        let app = launch(extraArgs: ["-deeplink.planDetail=plan_beginner"], suffix: suffix)
        XCTAssertTrue(app.staticTexts[quote].waitForExistence(timeout: 15))
        savePNG(app, "w1-c012-plan-coaching-\(suffix)")
    }

    private func captureDrillRecord(suffix: String) {
        let description = "从半台五个位置打直线球。每次换位都重新站线，把球杆直着送出去。"
        let app = launch(extraArgs: ["-deeplink.activeTraining=drill_c001"], suffix: suffix)
        XCTAssertTrue(
            app.descendants(matching: .any)["v34w5ActiveTrainingHost"]
                .waitForExistence(timeout: 12)
        )
        let switchButton = app.buttons["切换到单项视图"].firstMatch
        if switchButton.waitForExistence(timeout: 5), switchButton.isHittable {
            switchButton.tap()
            usleep(500_000)
        }
        XCTAssertTrue(scrollToText(app, description, attempts: 10), "训练记录页应显示 c001 描述")
        savePNG(app, "w1-c001-drill-record-\(suffix)")
    }

    private func scrollToText(
        _ app: XCUIApplication,
        _ text: String,
        attempts: Int = 8
    ) -> Bool {
        let element = app.staticTexts[text].firstMatch
        if element.waitForExistence(timeout: 4) { return true }
        for _ in 0..<attempts {
            app.swipeUp()
            usleep(350_000)
            if element.exists { return true }
        }
        return element.exists
    }

    private func launch(extraArgs: [String], suffix: String) -> XCUIApplication {
        var args = extraArgs
        if suffix.contains("Light") {
            args.append("-v49.forceLight")
        }
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
            print("[V49-W1-SCREENSHOT] \(url.path)")
        } catch {
            XCTFail("写截图失败 \(name): \(error)")
        }
    }
}
