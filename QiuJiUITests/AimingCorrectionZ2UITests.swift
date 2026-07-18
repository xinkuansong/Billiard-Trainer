import XCTest

/// 「瞄准修正」页 Z2 截图核验（问题集合 v12 Z2 完成标准 2 + Z1 ①节特写补账）。
/// 外观（明/暗）在测试外通过 `xcrun simctl ui <udid> appearance light|dark` 预设；
/// 截图目录经 `Z2_SHOT_DIR`（TEST_RUNNER_Z2_SHOT_DIR）传入。
final class AimingCorrectionZ2UITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private var shotDirURL: URL? {
        if let env = ProcessInfo.processInfo.environment["Z2_SHOT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        // Fallback when TEST_RUNNER_ env wiring is absent
        return URL(fileURLWithPath:
            "/Users/song/projects/13.billiard_trainer-z2/build/z2-screenshots/fallback",
                   isDirectory: true)
    }

    private func snap(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = shotDirURL {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: url)
        }
    }

    /// 从左侧空白区拖拽上滑，避开滑杆吞手势。
    private func dragScrollUp(times: Int = 1) {
        guard app.state == .runningForeground else { return }
        let host: XCUIElement = app.scrollViews.firstMatch.exists
            ? app.scrollViews.firstMatch
            : app.windows.firstMatch
        for _ in 0..<times {
            guard app.state == .runningForeground else { return }
            let start = host.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.78))
            let end = host.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.28))
            start.press(forDuration: 0.05, thenDragTo: end)
            usleep(500_000)
        }
    }

    func testAimingCorrectionZ2Sections() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        let seg = app.buttons["angleHomeTab_学"]
        if seg.waitForExistence(timeout: 5) { seg.tap() }
        usleep(700_000)

        let card = app.staticTexts["瞄准修正"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "瞄准修正卡不可达")
        if card.isHittable {
            card.tap()
        } else {
            app.swipeUp()
            usleep(400_000)
            app.staticTexts["瞄准修正"].tap()
        }
        sleep(6)

        XCTAssertTrue(app.navigationBars["瞄准修正"].waitForExistence(timeout: 8),
                      "应进入瞄准修正页")

        // 控件组：力度滑杆 + 高低杆三档
        let velocity = app.sliders["aimingCorrection.velocitySlider"]
        XCTAssertTrue(velocity.waitForExistence(timeout: 5), "力度滑杆应存在")
        let spinPicker = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'aimingCorrection.spinYPicker'"))
            .firstMatch
        XCTAssertTrue(spinPicker.waitForExistence(timeout: 4), "高低杆三档应存在")
        snap("z2-00-controls")

        // 切高杆 → 插图联动（去抖路径）
        let highBtn = app.buttons["高杆"]
        if highBtn.waitForExistence(timeout: 2), highBtn.isHittable {
            highBtn.tap()
            usleep(800_000)
        }
        snap("z2-00b-controls-high")

        // ① Δ 虚实线特写（Z1 补账）
        dragScrollUp(times: 1)
        sleep(2)
        snap("z2-01-section1-delta-closeup")

        // ② 投掷节
        dragScrollUp(times: 1)
        sleep(2)
        snap("z2-02-section2-throw")
        XCTAssertTrue(
            app.staticTexts["投掷效应（Throw）"].exists
                || app.otherElements["aimingCorrection.section2"].exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '投掷'")).firstMatch.exists,
            "② 节应可见"
        )

        // ③ 高低杆节
        dragScrollUp(times: 1)
        sleep(2)
        snap("z2-03-section3-thickness")
        XCTAssertTrue(
            app.staticTexts["高低杆改变有效厚度"].exists
                || app.otherElements["aimingCorrection.section3"].exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '有效厚度'")).firstMatch.exists,
            "③ 节应可见"
        )

        // ③ 三联插图整幅（防上下裁切）
        dragScrollUp(times: 1)
        sleep(2)
        snap("z2-03b-section3-figure")

        // ⑥ 页末导流
        dragScrollUp(times: 2)
        sleep(1)
        snap("z2-04-section6-cta")
        XCTAssertTrue(
            app.staticTexts["实战启示"].exists
                || app.staticTexts["去思路训练看实况"].exists
                || app.buttons["去思路训练看实况"].exists,
            "⑥ 节内容应在末帧可见"
        )
    }
}
