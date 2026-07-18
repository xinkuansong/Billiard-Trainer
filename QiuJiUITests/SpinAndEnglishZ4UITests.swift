import XCTest

/// 「旋转与加塞」页 Z4 交互取证（问题集合 v12 Z4）：
/// 切角滑杆可达 + 瞄准修正 CTA 真跳转 + 逐节截图落盘。
/// 外观（明/暗）在测试外通过 `xcrun simctl ui <udid> appearance light|dark` 预设；
/// 截图目录经 `Z4_SHOT_DIR`（TEST_RUNNER_Z4_SHOT_DIR）传入。
final class SpinAndEnglishZ4UITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private var shotDirURL: URL? {
        if let env = ProcessInfo.processInfo.environment["Z4_SHOT_DIR"], !env.isEmpty {
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

    func testSpinAndEnglishZ4Interactions() {
        sleep(3)
        app.switchTab(.angle)
        sleep(2)

        let seg = app.buttons["angleHomeTab_学"]
        if seg.waitForExistence(timeout: 5) { seg.tap() }
        usleep(700_000)

        let card = app.staticTexts["旋转与加塞"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "旋转与加塞卡不可达")
        if card.isHittable {
            card.tap()
        } else {
            app.swipeUp()
            usleep(400_000)
            app.staticTexts["旋转与加塞"].tap()
        }
        sleep(3)

        XCTAssertTrue(app.navigationBars["旋转与加塞"].waitForExistence(timeout: 8),
                      "应进入旋转与加塞页")
        snap("z4-00-top")

        let theta = app.sliders["spinAndEnglish.thetaSlider"]
        XCTAssertTrue(theta.waitForExistence(timeout: 5), "切角滑杆应存在")
        theta.adjust(toNormalizedSliderPosition: 0.7)
        usleep(400_000)
        snap("z4-01-theta-dragged")

        let picker = app.segmentedControls["spinAndEnglish.spinPicker"]
        if picker.waitForExistence(timeout: 2) {
            let follow = picker.buttons["前旋"]
            if follow.exists { follow.tap() }
            usleep(300_000)
            snap("z4-02-spin-follow")
        }

        // 主轴读数：教学折线文案（半球或非半球均应出现「教学折线」）。
        let fold = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "教学折线")
        ).firstMatch
        XCTAssertTrue(fold.waitForExistence(timeout: 3), "应显示示意角·教学折线读数")

        dragScrollUp(times: 2)
        snap("z4-03-tip-or-miscue")

        dragScrollUp(times: 2)
        snap("z4-04-cushion")

        dragScrollUp(times: 2)
        // CTA：打开瞄准修正（真 NavigationLink；用 AX id 消歧，页内 crossRefs 另有同名按钮）
        let cta = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'spinAndEnglish.aimingCorrectionCTA'"))
            .firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 6), "瞄准修正 CTA 应可达")
        snap("z4-05-aiming-correction-cta")
        cta.tap()
        sleep(2)
        XCTAssertTrue(app.navigationBars["瞄准修正"].waitForExistence(timeout: 8),
                      "CTA 应真跳转到瞄准修正页")
        snap("z4-06-aiming-correction-arrived")

        // 过期文案不得出现（在旋转与加塞页已验证过；此处在瞄准修正落地页再扫一次无妨）。
        let stale = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "尚未上线")
        ).firstMatch
        XCTAssertFalse(stale.exists, "不得残留「尚未上线」文案")
    }
}
