import XCTest

/// v8 X1（K1–K4）截图取证。写入 `build/x1-screenshots/`。
/// 禁止覆盖 `docs/ui-polish/` 与 `QiuJi/Resources/DrillThumbnails/`。
final class X1_PracticePolishUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-x1/build/x1-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let url = shotDir.appendingPathComponent("\(name).png")
        try? shot.pngRepresentation.write(to: url)
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func switchAngleHomeTab(_ app: XCUIApplication, _ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap()
        usleep(600_000)
        return true
    }

    private func openCard(_ app: XCUIApplication, homeTab: String, title: String) -> Bool {
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab(app, homeTab) else { return false }
        let card = app.buttons[title]
        guard card.waitForExistence(timeout: 4) else { return false }
        card.tap()
        sleep(1)
        return true
    }

    private func dismissAimingSettingsIfNeeded(_ app: XCUIApplication) {
        let start = app.buttons["开始训练"]
        if start.waitForExistence(timeout: 3) {
            start.tap()
            sleep(1)
        }
    }

    private func backToHome(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 2) {
            back.tap()
            sleep(1)
        }
    }

    // MARK: - K1

    func testK1_homeCardsConstantTypeSize() throws {
        let app = XCUIApplication.launchClean()
        app.switchTab(.angle)
        sleep(1)
        _ = switchAngleHomeTab(app, "全部")
        snap(app, "k1-01-home-all-cards")
        _ = switchAngleHomeTab(app, "练")
        snap(app, "k1-02-home-train-cards")
        _ = switchAngleHomeTab(app, "学")
        snap(app, "k1-03-home-learn-cards")
    }

    // MARK: - K2

    private func runK2ReferenceShot(angle: String) {
        let app = XCUIApplication.launchClean(extraArgs: [
            "-geometricQuiz.forcedAngle", angle
        ])
        guard openCard(app, homeTab: "练", title: "角度预测") else {
            XCTFail("未能进入角度预测 angle=\(angle)")
            return
        }
        let showRef = app.buttons["显示参考"]
        if showRef.waitForExistence(timeout: 3) {
            showRef.tap()
            usleep(500_000)
        }
        snap(app, "k2-ref-\(angle)deg")
    }

    func testK2_referenceRays_90() throws { runK2ReferenceShot(angle: "90") }
    func testK2_referenceRays_45() throws { runK2ReferenceShot(angle: "45") }
    func testK2_referenceRays_0() throws { runK2ReferenceShot(angle: "0") }

    /// 答题键盘：输入两位角度并点「提交」。
    private func submitAngleAnswer(_ app: XCUIApplication, digits: [String] = ["3", "0"]) {
        let answer = app.buttons["答题"]
        guard answer.waitForExistence(timeout: 3) else { return }
        answer.tap()
        usleep(400_000)
        for ch in digits {
            let key = app.buttons[ch]
            if key.waitForExistence(timeout: 1) { key.tap() }
        }
        let submit = app.buttons["提交"]
        if submit.waitForExistence(timeout: 2) {
            submit.tap()
            sleep(1)
        }
    }

    // MARK: - K3

    func testRecentPerformance_answerCancelAndLastFive() throws {
        let environment = ProcessInfo.processInfo.environment
        let dark = environment["RECENT_DARK"] == "1" || environment["TEST_RUNNER_RECENT_DARK"] == "1"
        let app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-appearanceMode", dark ? "dark" : "light",
            "-geometricQuiz.forcedAngle", "34"
        ])
        XCTAssertTrue(openCard(app, homeTab: "练", title: "角度预测"))
        let empty = app.staticTexts["geometric.recent.empty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 5))
        recentSnap(app, "01-empty")

        let change = app.buttons["换题"]
        let originalY = change.frame.midY
        app.buttons["答题"].tap()
        XCTAssertTrue(app.buttons["取消"].waitForExistence(timeout: 3))
        XCTAssertFalse(empty.exists)
        XCTAssertEqual(change.frame.midY, originalY, accuracy: 2)
        XCTAssertLessThan(change.frame.maxY, app.staticTexts["估算角度"].frame.minY)
        recentSnap(app, "02-keypad")
        app.buttons["取消"].tap()
        XCTAssertTrue(empty.waitForExistence(timeout: 3))
        XCTAssertEqual(change.frame.midY, originalY, accuracy: 2)

        for question in 1...6 {
            app.buttons["答题"].tap()
            XCTAssertTrue(app.buttons["提交"].waitForExistence(timeout: 3))
            if question > 1 {
                XCTAssertFalse(app.otherElements["geometric.recent.row.\(question - 1)"].exists)
            }
            app.buttons["3"].tap()
            app.buttons["0"].tap()
            app.buttons["提交"].tap()
            let row = app.descendants(matching: .any)
                .matching(identifier: "geometric.recent.row.\(question)").firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 3))
            if question == 1 {
                XCTAssertTrue(row.label.contains("偏小 4.0°"), row.label)
                recentSnap(app, "03-submitted")
            }
            // The existing change-question action keeps the upper question visible.
            change.tap()
            XCTAssertTrue(app.buttons["答题"].waitForExistence(timeout: 3))
        }
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "geometric.recent.row.1").firstMatch.exists)
        for question in 2...6 {
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "geometric.recent.row.\(question)").firstMatch.exists)
        }
        recentSnap(app, "04-recent-five")
        app.swipeUp()
        recentSnap(app, "05-recent-five-scrolled")
        app.buttons["重置统计"].tap()
        app.buttons["重置"].tap()
        XCTAssertTrue(empty.waitForExistence(timeout: 3))
        recentSnap(app, "06-reset")
    }

    private func recentSnap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "recent-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testK3_scene3D_angleArcForward() throws {
        let app = XCUIApplication.launchClean()
        guard openCard(app, homeTab: "练", title: "3D 角度训练") else {
            XCTFail("未能进入 3D 角度训练"); return
        }
        dismissAimingSettingsIfNeeded(app)
        sleep(1)
        snap(app, "k3-01-scene3d-entry")
        // 提交后结果可视化含角弧（辅助档故意隐藏数值弧）
        submitAngleAnswer(app)
        sleep(1)
        snap(app, "k3-02-scene3d-result-arc")
    }

    // MARK: - K4

    func testK4_scene3D_consistentNearEntry_5questions() throws {
        let app = XCUIApplication.launchClean()
        guard openCard(app, homeTab: "练", title: "3D 角度训练") else {
            XCTFail("未能进入 3D 角度训练"); return
        }
        dismissAimingSettingsIfNeeded(app)
        sleep(1)
        snap(app, "k4-q01-entry")

        for i in 2...5 {
            submitAngleAnswer(app)
            let next = app.buttons["下一题"]
            XCTAssertTrue(next.waitForExistence(timeout: 5), "第\(i)题前应出现下一题")
            next.tap()
            sleep(1) // 等 enterAiming 0.6s 落定
            snap(app, String(format: "k4-q%02d-entry", i))
        }
    }
}
