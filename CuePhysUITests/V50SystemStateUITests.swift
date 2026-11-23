import XCTest

/// v50 W6 系统状态验证。权限必须在调用前由矩阵执行器使用
/// `simctl privacy <UDID> reset photos-add com.xinkuan.qiuji` 重置，保证弹框真实出现。
final class V50SystemStateUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES",
            "-resetDebugPremium",
            "-v50.photoPermissionProbe",
        ]
    }

    func testPhotoPermissionRealPromptDenied() throws {
        try exercisePhotoPermission(allow: false)
    }

    func testPhotoPermissionRealPromptAllowed() throws {
        try exercisePhotoPermission(allow: true)
    }

    private func exercisePhotoPermission(allow: Bool) throws {
        var handledSystemPrompt = false
        let monitor = addUIInterruptionMonitor(
            withDescription: allow ? "允许相册新增权限" : "拒绝相册新增权限"
        ) { alert in
            let predicate: NSPredicate
            if allow {
                predicate = NSPredicate(
                    format: "(label CONTAINS '允许' AND NOT label CONTAINS '不允许') OR label == '好' OR label == 'OK'"
                )
            } else {
                predicate = NSPredicate(
                    format: "label CONTAINS '不允许' OR label CONTAINS \"Don't Allow\""
                )
            }
            let action = alert.buttons.matching(predicate).firstMatch
            guard action.exists else { return false }
            handledSystemPrompt = true
            action.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }

        app.launch()
        let request = app.buttons["v50.photoPermission.request"]
        XCTAssertTrue(request.waitForExistence(timeout: 8), "权限探针请求按钮应出现")
        XCTAssertTrue(app.staticTexts["相册权限：未决定"].exists, "重置后状态必须为未决定")
        request.tap()

        // iOS 26 的权限卡由 SpringBoard 承载，通用 interruption monitor 偶尔不会
        // 因 `app.tap()` 被触发。优先直接查询真实 SpringBoard Alert，monitor 仅兜底。
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let systemAlert = springboard.alerts.firstMatch
        if systemAlert.waitForExistence(timeout: 5) {
            let predicate: NSPredicate
            if allow {
                predicate = NSPredicate(
                    format: "(label CONTAINS '允许' AND NOT label CONTAINS '不允许') OR label == '好' OR label == 'OK'"
                )
            } else {
                predicate = NSPredicate(
                    format: "label CONTAINS '不允许' OR label CONTAINS \"Don't Allow\""
                )
            }
            let action = systemAlert.buttons.matching(predicate).firstMatch
            XCTAssertTrue(action.waitForExistence(timeout: 3), "系统权限弹框缺少预期操作")
            action.tap()
            handledSystemPrompt = true
        } else {
            // 触发 XCTest interruption monitor 的标准兜底路径。
            app.tap()
        }

        let expected = allow ? "相册权限：已允许" : "相册权限：已拒绝"
        XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 8), "App 应回显系统权限结果")
        XCTAssertTrue(handledSystemPrompt, "必须实际处理系统权限弹框，禁止用预授权冒充")
        try capture(allow ? "photo-permission-allowed" : "photo-permission-denied")
    }

    private func capture(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["V50_SHOT_DIR"]
            ?? environment["TEST_RUNNER_V50_SHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(
            to: directory.appendingPathComponent("\(name).png"),
            options: .atomic
        )
    }
}
