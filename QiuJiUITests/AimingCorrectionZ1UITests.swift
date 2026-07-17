import XCTest

/// 「瞄准修正」页 Z1 截图核验（问题集合 v12 Z1 完成标准 2）。
/// 外观（明/暗）在测试外通过 `xcrun simctl ui <udid> appearance light|dark` 预设；
/// 截图目录经 `Z1_SHOT_DIR`（TEST_RUNNER_Z1_SHOT_DIR）传入。
final class AimingCorrectionZ1UITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private var shotDirURL: URL? {
        guard let env = ProcessInfo.processInfo.environment["Z1_SHOT_DIR"],
              !env.isEmpty else { return nil }
        return URL(fileURLWithPath: env, isDirectory: true)
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
        let host: XCUIElement = app.scrollViews.firstMatch.exists
            ? app.scrollViews.firstMatch
            : app.windows.firstMatch
        for _ in 0..<times {
            let start = host.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.82))
            let end = host.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.25))
            start.press(forDuration: 0.05, thenDragTo: end)
            usleep(400_000)
        }
    }

    func testAimingCorrectionSections() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        let seg = app.buttons["angleHomeTab_学"]
        if seg.waitForExistence(timeout: 5) { seg.tap() }
        usleep(700_000)
        snap("z1-00-learn-cards")

        let card = app.staticTexts["瞄准修正"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "瞄准修正卡不可达")
        if card.isHittable {
            card.tap()
        } else {
            app.swipeUp()
            usleep(400_000)
            app.staticTexts["瞄准修正"].tap()
        }
        sleep(5)

        XCTAssertTrue(app.navigationBars["瞄准修正"].waitForExistence(timeout: 6),
                      "应进入瞄准修正页")
        snap("z1-01-section1-intro")

        // 一次拖拽即可把 Δ 实况图滚进视口中部（两次会直接到页底、图被导航栏裁掉）。
        dragScrollUp(times: 1)
        sleep(2)
        snap("z1-02-section1-delta-figure")

        dragScrollUp(times: 4)
        sleep(1)
        snap("z1-03-section6-cta")

        let hasSection6 = app.staticTexts["实战启示"].exists
            || app.staticTexts["去思路训练看实况"].exists
            || app.buttons["去思路训练看实况"].exists
        XCTAssertTrue(hasSection6, "⑥ 节内容应在末帧可见")
    }
}
