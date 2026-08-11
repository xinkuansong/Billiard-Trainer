import XCTest

/// v34 W4：动作页「建议训练量」逐球形取证 → `build/v34-w4-logs/`
final class V34W4ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v34-w4-logs"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testW4_suggestedDose_singleRepetition() {
        captureSuggestedDose(
            drillId: "drill_c001",
            expectedName: "半台直线球",
            name: "drill-c001-repetition-dose",
            forcePremium: false
        )
    }

    func testW4_suggestedDose_multiFormation() {
        captureSuggestedDose(
            drillId: "drill_c026",
            expectedName: "厚球分离角控制",
            name: "drill-c026-multi-formation-dose",
            forcePremium: false
        )
    }

    func testW4_suggestedDose_sequence() {
        captureSuggestedDose(
            drillId: "drill_c039",
            expectedName: "直线球组合走位",
            name: "drill-c039-sequence-dose",
            forcePremium: true
        )
    }

    private func captureSuggestedDose(
        drillId: String,
        expectedName: String,
        name: String,
        forcePremium: Bool
    ) {
        var args = ["-deeplink.drillDetail=\(drillId)"]
        if forcePremium {
            args.append("-forcePremium")
        }

        let app = XCUIApplication.launchClean(extraArgs: args)
        sleep(2)

        let title = app.staticTexts[expectedName].firstMatch
        XCTAssertTrue(
            title.waitForExistence(timeout: 8),
            "\(drillId) 深链应打开动作详情（期望标题 \(expectedName)）"
        )

        let doseLabel = app.staticTexts["建议训练量"].firstMatch
        var found = false
        for _ in 0..<12 {
            if doseLabel.exists {
                found = true
                break
            }
            app.swipeUp()
            usleep(350_000)
        }
        XCTAssertTrue(found, "\(drillId) 应滚到「建议训练量」")

        // 再轻推一点，确保多球形合计行入镜
        app.swipeUp()
        usleep(300_000)
        savePNG(app, name)
    }

    private func savePNG(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let url = outDir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            print("[W4-SCREENSHOT] \(url.path)")
        } catch {
            XCTFail("写截图失败 \(name): \(error)")
        }
    }
}
