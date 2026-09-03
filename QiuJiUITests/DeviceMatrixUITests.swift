import XCTest

/// v50 多设备契约冒烟：不按营销型号写分支，只验证每个视口都必须成立的交互不变量。
final class DeviceMatrixUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
    }

    func testRootSafeAreaScrollAndPrimaryCTA() throws {
        app.switchTab(.training)
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))

        let active = app.staticTexts["今日训练进行中"]
        let empty = app.staticTexts["今日训练待安排"]
        XCTAssertTrue(
            active.waitForExistence(timeout: 4) || empty.waitForExistence(timeout: 2),
            "训练根页必须给出可识别状态"
        )

        let primary = app.buttons.matching(
            NSPredicate(format: "label == '开始训练' OR label == '自由记录'")
        ).firstMatch
        XCTAssertTrue(primary.waitForExistence(timeout: 3), "训练根页缺少主操作")
        XCTAssertTrue(primary.isHittable, "训练根页主操作不可点击")
        XCTAssertTrue(window.frame.insetBy(dx: -1, dy: -1).contains(primary.frame), "主操作超出窗口")

        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 3), "训练根页缺少滚动容器")
        for _ in 0..<6 { scroll.swipeUp(velocity: .fast) }

        let tab = app.tabBars.buttons[XCUIApplication.Tab.training.rawValue].firstMatch
        let floatingTab = app.buttons[XCUIApplication.Tab.training.rawValue].firstMatch
        XCTAssertTrue(tab.exists || floatingTab.exists, "滚动到底后训练 Tab 必须仍可达")
        try capture("root-bottom", extra: ["primaryFrame": rectDictionary(primary.frame)])
    }

    func testPhoneLoginKeyboardAndAdaptiveSheet() throws {
        app.terminate()
        let fresh = XCUIApplication()
        fresh.launchArguments += [
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "NO",
            "-resetDebugPremium",
        ]
        fresh.launch()
        app = fresh

        for _ in 0..<2 {
            let next = app.buttons["继续"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            next.tap()
        }
        let login = app.buttons["登录已有账号"]
        XCTAssertTrue(login.waitForExistence(timeout: 4))
        login.tap()
        let phone = app.buttons["手机号登录"]
        XCTAssertTrue(phone.waitForExistence(timeout: 4))
        phone.tap()

        let field = app.textFields["请输入手机号"]
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.tap()
        field.typeText("13800138000")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4), "输入后键盘未出现")

        let send = app.buttons["发送验证码"]
        XCTAssertTrue(send.exists, "键盘态必须保留发送验证码操作")
        let window = app.windows.firstMatch
        XCTAssertTrue(window.frame.insetBy(dx: -1, dy: -1).intersects(send.frame), "发送按钮完全落在窗口外")
        let navigationBar = app.navigationBars["手机号登录"]
        let pageTitle = app.staticTexts["输入手机号"]
        if pageTitle.exists, window.frame.intersects(pageTitle.frame) {
            XCTAssertFalse(
                navigationBar.frame.intersects(pageTitle.frame),
                "键盘避让不得把页内标题推到固定导航栏下面"
            )
        }
        try capture("phone-keyboard-sheet", extra: [
            "sheetOrPopoverFrame": rectDictionary(field.frame.union(send.frame)),
            "keyboardFrame": rectDictionary(app.keyboards.firstMatch.frame),
            "navigationBarFrame": rectDictionary(navigationBar.frame),
            "pageTitleFrame": rectDictionary(pageTitle.frame),
        ])
    }

    func testRepresentativeTableStageAndCTA() throws {
        app.switchTab(.angle)
        let train = app.buttons["angleHomeTab_练"]
        XCTAssertTrue(train.waitForExistence(timeout: 5))
        train.tap()

        let entry = app.buttons["2D 角度训练"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 4), "缺少 2D 角度训练入口")
        entry.tap()
        XCTAssertTrue(app.navigationBars["2D 角度训练"].waitForExistence(timeout: 5))

        let start = app.buttons["开始训练"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "设置 Sheet 缺少开始训练")
        XCTAssertTrue(start.isHittable, "设置 Sheet 主 CTA 不可点击")
        start.tap()
        XCTAssertTrue(app.navigationBars["2D 角度训练"].waitForExistence(timeout: 4))

        let screen = XCUIScreen.main.screenshot()
        XCTAssertGreaterThan(screen.image.size.height, screen.image.size.width, "本轮产品契约必须保持 Portrait")
        try capture("table-stage", extra: [
            "tableGeometryContract": ["long": 2, "short": 1],
            "screenPixelWidth": screen.image.size.width,
            "screenPixelHeight": screen.image.size.height,
        ])
    }

    private func capture(_ name: String, extra: [String: Any] = [:]) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = injectedArtifactDirectory() else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(
            to: directory.appendingPathComponent("\(name).png"),
            options: .atomic
        )

        var metadata: [String: Any] = [
            "name": name,
            "appearance": appearanceName,
            "windowFrame": rectDictionary(app.windows.firstMatch.frame),
            "screenPixelWidth": screenshot.image.size.width,
            "screenPixelHeight": screenshot.image.size.height,
        ]
        extra.forEach { metadata[$0.key] = $0.value }
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("\(name).json"), options: .atomic)
    }

    private func injectedArtifactDirectory() -> URL? {
        if let value = ProcessInfo.processInfo.environment["V50_SHOT_DIR"], !value.isEmpty {
            return URL(fileURLWithPath: value, isDirectory: true)
        }
        if let value = ProcessInfo.processInfo.environment["TEST_RUNNER_V50_SHOT_DIR"], !value.isEmpty {
            return URL(fileURLWithPath: value, isDirectory: true)
        }
        guard let value = try? String(contentsOfFile: "/tmp/qiuji-v50/shot_dir", encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: value, isDirectory: true)
    }

    private var appearanceName: String {
        switch XCUIDevice.shared.appearance {
        case .light: return "light"
        case .dark: return "dark"
        case .unspecified: return "unspecified"
        @unknown default: return "unknown"
        }
    }

    private func rectDictionary(_ rect: CGRect) -> [String: Double] {
        [
            "x": rect.origin.x,
            "y": rect.origin.y,
            "width": rect.size.width,
            "height": rect.size.height,
        ]
    }
}
