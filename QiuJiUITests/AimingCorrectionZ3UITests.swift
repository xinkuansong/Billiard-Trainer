import XCTest

/// 「瞄准修正」页 Z3 截图核验（问题集合 v12 Z3 完成标准 2/6）：
/// ②③ 风格重做后插图 + ④ 加塞节（左右塞轴联动）+ ⑤ 求解对比与速查表 + ⑥ 收尾。
/// 外观（明/暗）在测试外通过 `xcrun simctl ui <udid> appearance light|dark` 预设；
/// 截图目录经 `Z3_SHOT_DIR`（TEST_RUNNER_Z3_SHOT_DIR）传入。
final class AimingCorrectionZ3UITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private var shotDirURL: URL? {
        if let env = ProcessInfo.processInfo.environment["Z3_SHOT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        return nil
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

    /// 从左侧空白区拖拽上滑，避开滑杆吞手势（Z2 同款）。
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

    func testAimingCorrectionZ3Sections() {
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

        // 控件组：力度 + 高低杆 + 左右塞（Z3 三轴齐全）
        let velocity = app.sliders["aimingCorrection.velocitySlider"]
        XCTAssertTrue(velocity.waitForExistence(timeout: 5), "力度滑杆应存在")
        let spinXSlider = app.sliders["aimingCorrection.spinXSlider"]
        XCTAssertTrue(spinXSlider.waitForExistence(timeout: 4), "左右塞滑杆应存在（Z3）")
        snap("z3-00-controls")

        // 加左塞（滑到偏左区间）→ 插图联动（去抖路径）
        spinXSlider.adjust(toNormalizedSliderPosition: 0.85)
        sleep(2)
        snap("z3-00b-controls-leftenglish")

        // ① Δ 特写
        dragScrollUp(times: 1)
        sleep(2)
        snap("z3-01-section1-delta")

        // ② 投掷节（BTTableFigure 风格重做后）
        dragScrollUp(times: 1)
        sleep(2)
        snap("z3-02-section2-throw-figure")
        XCTAssertTrue(
            app.staticTexts["投掷效应（Throw）"].exists
                || app.otherElements["aimingCorrection.section2"].exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '投掷'")).firstMatch.exists,
            "② 节应可见"
        )

        // ③ 高低杆三联（单图三线）
        dragScrollUp(times: 1)
        sleep(2)
        snap("z3-03-section3-thickness-figure")

        // ④ 加塞节：挤偏 + 弧线
        dragScrollUp(times: 1)
        sleep(2)
        snap("z3-04-section4-english")
        XCTAssertTrue(
            app.staticTexts["加塞：挤偏与弧线"].exists
                || app.otherElements["aimingCorrection.section4"].exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '挤偏'")).firstMatch.exists,
            "④ 节应可见"
        )

        // ④ 图整幅（防裁切）
        dragScrollUp(times: 1)
        sleep(2)
        snap("z3-04b-section4-figure")

        // ⑤ 求解对比 + 速查表
        dragScrollUp(times: 1)
        sleep(2)
        snap("z3-05-section5-compare")
        dragScrollUp(times: 1)
        sleep(1)
        snap("z3-05b-section5-quickref")

        // ⑥ 页末导流
        dragScrollUp(times: 2)
        sleep(1)
        snap("z3-06-section6-cta")
        XCTAssertTrue(
            app.staticTexts["实战启示"].exists
                || app.staticTexts["去思路训练看实况"].exists
                || app.buttons["去思路训练看实况"].exists,
            "⑥ 节内容应在末帧可见"
        )
    }
}
