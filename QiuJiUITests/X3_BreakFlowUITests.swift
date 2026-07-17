import XCTest

/// 问题集合 v8 · X3（K6–K8）开球全流程截图取证。
///
/// - Silu / PlanThree：深链进页 → 开球 → racked → strike → settled（完成/重开/取消三钮）
/// - 打点盘：racked 态点打点迷你图开合
/// 截图同时写入 `build/x3-screenshots/`（相对 HOME 探测的仓库根）与 XCTAttachment。
final class X3_BreakFlowUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private var shotDir: URL {
        // UITest 宿主进程 cwd 不保证是仓库根；用常见 worktree 绝对路径优先。
        let candidates = [
            "/Users/song/projects/13.billiard_trainer-x3/build/x3-screenshots",
            FileManager.default.currentDirectoryPath + "/build/x3-screenshots",
        ]
        let path = candidates.first { FileManager.default.fileExists(atPath: ($0 as NSString).deletingLastPathComponent) }
            ?? candidates[0]
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        let data = shot.pngRepresentation
        let url = shotDir.appendingPathComponent("\(name).png")
        try? data.write(to: url)
        print("X3 UITest wrote \(url.path)")
    }

    private func launchDeeplink(_ arg: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES",
            "-\(arg)",
        ]
        app.launch()
        for _ in 0..<2 {
            sleep(2)
            if app.state == .runningForeground { break }
            app.launch()
        }
        return app
    }

    private func startBreak(_ app: XCUIApplication) {
        let place = app.buttons["摆球"]
        XCTAssertTrue(place.waitForExistence(timeout: 20), "求解页应出现")
        sleep(2)
        let entry = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.entry'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 8), "开球入口应可点")
        entry.tap()
        sleep(1)
        let game = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.game.15'")).firstMatch
        if game.waitForExistence(timeout: 3), game.isHittable {
            game.tap()
        } else {
            let label = app.staticTexts["中式八球"]
            XCTAssertTrue(label.waitForExistence(timeout: 3), "玩法选择应出现")
            label.tap()
        }
        sleep(3)
    }

    private func runManualDeliverFlow(arg: String, prefix: String) {
        let app = launchDeeplink(arg)
        startBreak(app)

        // racked：取消 / 重开 / 开球
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'break.strike'"))
                .firstMatch.waitForExistence(timeout: 5),
            "\(prefix) racked 应有开球钮")
        snap(app, "\(prefix)-01-racked")

        // 打点盘打开（K7）。关闭：UITest 点捕获层偶发不命中，改靠开球后
        // `BreakInstrumentsOverlay.onChange(phase!=racked)` 自动收起；03 帧在开球瞬间后截。
        let spinMini = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == '打点'")).firstMatch
        if spinMini.waitForExistence(timeout: 3), spinMini.isHittable {
            spinMini.tap()
            sleep(1)
            XCTAssertTrue(app.buttons["回中"].waitForExistence(timeout: 3)
                          || app.staticTexts["中心球"].waitForExistence(timeout: 1),
                          "\(prefix)：打点盘应打开")
            snap(app, "\(prefix)-02-spinpad-open")
        } else {
            XCTFail("\(prefix)：开球态打点迷你图应可见（K7 onSpinTap）")
        }

        let strike = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.strike'")).firstMatch
        XCTAssertTrue(strike.waitForExistence(timeout: 3), "开球钮")
        strike.tap()
        // 进入 computing/breaking 后打点盘应自动收起（K7）。
        sleep(2)
        XCTAssertFalse(app.buttons["回中"].exists, "\(prefix)：开球后打点盘应自动关闭")
        snap(app, "\(prefix)-03-spinpad-auto-closed-on-break")
        sleep(12)   // 运杆 + 散局停稳

        let confirm = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.confirm'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 15),
                      "\(prefix) 手动交付：停稳后应出现「完成」（K6）")
        let rerack = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.rerack'")).firstMatch
        XCTAssertTrue(rerack.exists, "settled 应有「重开」")
        XCTAssertTrue(app.buttons["取消"].exists || app.staticTexts["取消"].exists
                      || app.descendants(matching: .any)["取消"].exists,
                      "settled 应有「取消」")
        XCTAssertFalse(app.buttons["回中"].exists, "settled 帧不应再盖打点盘")
        snap(app, "\(prefix)-04-settled-three-buttons")

        // 重开 → 回到 racked
        rerack.tap()
        sleep(2)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'break.strike'"))
                .firstMatch.waitForExistence(timeout: 5),
            "重开后应回到 racked（开球钮）")
        snap(app, "\(prefix)-05-reracked")

        // 再开球 → 完成交付
        let strike2 = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.strike'")).firstMatch
        strike2.tap()
        sleep(12)
        let confirm2 = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.confirm'")).firstMatch
        XCTAssertTrue(confirm2.waitForExistence(timeout: 15), "第二次停稳应有完成")
        confirm2.tap()
        sleep(2)
        // 交付后开球模式退出：开球入口复现
        let entryAgain = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.entry'")).firstMatch
        XCTAssertTrue(entryAgain.waitForExistence(timeout: 8),
                      "\(prefix) 点「完成」后应退出开球模式")
        snap(app, "\(prefix)-06-delivered")

        app.terminate()
    }

    func testX3_SiluBreakManualDeliverFlow() {
        runManualDeliverFlow(arg: "deeplink.silu", prefix: "x3-silu")
    }

    func testX3_PlanThreeBreakManualDeliverFlow() {
        runManualDeliverFlow(arg: "deeplink.planThree", prefix: "x3-planthree")
    }
}
