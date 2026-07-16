import XCTest

/// v7 W7/C23：四测验页满额 UI（full 主卡 + compact）截图取证。
/// 截图写入本 worktree `build/w7-screenshots/`（禁止覆盖 `docs/ui-polish/` 基线）。
final class W7_DailyLimitUITests: XCTestCase {

    var app: XCUIApplication!

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-w7/build/w7-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func switchAngleHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000); return true
    }

    private func openCard(homeTab: String, title: String) -> Bool {
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab(homeTab) else { return false }
        let card = app.buttons[title]
        if card.waitForExistence(timeout: 4) {
            card.tap()
        } else if app.staticTexts[title].waitForExistence(timeout: 2) {
            app.staticTexts[title].tap()
        } else {
            return false
        }
        sleep(2)
        return true
    }

    private func backToHome() {
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 2) { back.tap(); sleep(1) }
    }

    /// 满额 + 自由练习 → SceneAiming 展示 full 主卡（非总结 compact）。
    @discardableResult
    private func startSceneAimingFreePracticeAtLimit() -> Bool {
        let free = app.buttons["自由练习"]
        if free.waitForExistence(timeout: 3) {
            free.tap()
            usleep(400_000)
        }
        let start = app.buttons["开始训练"]
        guard start.waitForExistence(timeout: 3) else { return false }
        start.tap()
        sleep(2)
        return true
    }

    func testW7FullLimitGateScreenshots() throws {
        app = XCUIApplication.launchClean(extraArgs: ["-w7.forceDailyLimit"])

        // 1) 角度预测 — full 主卡
        guard openCard(homeTab: "练", title: "角度预测") else {
            XCTFail("未能进入角度预测"); return
        }
        XCTAssertTrue(
            app.staticTexts["今日免费次数已用完"].waitForExistence(timeout: 4),
            "Geometric 应显示满额文案"
        )
        snap("w7-c23-01-geometric-full")
        backToHome()

        // 2) 2D 角度训练 — 自由练习 + 满额 → full 主卡
        guard openCard(homeTab: "练", title: "2D 角度训练") else {
            XCTFail("未能进入 2D 角度训练"); return
        }
        XCTAssertTrue(startSceneAimingFreePracticeAtLimit(), "未能开始自由练习")
        XCTAssertTrue(
            app.staticTexts["今日免费次数已用完"].waitForExistence(timeout: 4),
            "SceneAiming 应显示满额 full 主卡"
        )
        snap("w7-c23-02-scene-aiming-full")
        backToHome()

        // 3) 瞄准点训练 — full 主卡
        guard openCard(homeTab: "练", title: "瞄准点训练") else {
            XCTFail("未能进入瞄准点训练"); return
        }
        XCTAssertTrue(
            app.staticTexts["今日免费次数已用完"].waitForExistence(timeout: 4),
            "AimPointTraining 应显示满额文案"
        )
        snap("w7-c23-03-aimpoint-training-full")
        backToHome()

        // 4) 2D 瞄准点训练 — full 主卡（非全屏撑满形态）
        guard openCard(homeTab: "练", title: "2D 瞄准点训练") else {
            XCTFail("未能进入 2D 瞄准点训练"); return
        }
        XCTAssertTrue(
            app.staticTexts["今日免费次数已用完"].waitForExistence(timeout: 4),
            "AimPointScene 应显示满额 full 主卡"
        )
        snap("w7-c23-04-aimpoint-scene-full")
    }

    /// 每页独立冷启动：共享 `AngleUsageLimiter.shared` 会在同进程内耗尽「剩 1 次」。
    private func relaunchNearLimit() {
        app?.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-w7.forceDailyLimitNear"])
    }

    func testW7CompactLimitGateScreenshots() throws {
        // 1) Geometric 结果区 compact
        relaunchNearLimit()
        guard openCard(homeTab: "练", title: "角度预测") else {
            XCTFail("未能进入角度预测"); return
        }
        let answer = app.buttons["答题"]
        if answer.waitForExistence(timeout: 3) { answer.tap(); usleep(500_000) }
        for digit in ["3", "0"] {
            let key = app.buttons[digit]
            if key.waitForExistence(timeout: 2) { key.tap() }
        }
        let submitAngle = app.buttons["提交"]
        if submitAngle.waitForExistence(timeout: 2) {
            submitAngle.tap()
            sleep(2)
        }
        XCTAssertTrue(
            app.staticTexts["今日免费次数已用完"].waitForExistence(timeout: 4),
            "Geometric 结果区应出现 compact 满额"
        )
        snap("w7-c23-05-geometric-compact")

        // 2) AimPointTraining 结果区 compact
        relaunchNearLimit()
        guard openCard(homeTab: "练", title: "瞄准点训练") else {
            XCTFail("未能进入瞄准点训练"); return
        }
        let submit = app.buttons["提交瞄准点"]
        XCTAssertTrue(submit.waitForExistence(timeout: 4), "瞄准点训练应可提交")
        submit.tap()
        sleep(2)
        XCTAssertTrue(
            app.staticTexts["今日免费次数已用完"].waitForExistence(timeout: 4),
            "AimPointTraining 结果区应出现 compact 满额"
        )
        snap("w7-c23-06-aimpoint-training-compact")

        // 3) AimPointScene 结果区 compact（提交后约 1.5s 自动击球）
        relaunchNearLimit()
        guard openCard(homeTab: "练", title: "2D 瞄准点训练") else {
            XCTFail("未能进入 2D 瞄准点训练"); return
        }
        let submitScene = app.buttons["提交"]
        XCTAssertTrue(submitScene.waitForExistence(timeout: 4), "AimPointScene 应可提交")
        submitScene.tap()
        // 结果/击球验证态均为 compact；等文案出现后立刻截，避免回到 aiming 变 full。
        XCTAssertTrue(
            app.staticTexts["今日免费次数已用完"].waitForExistence(timeout: 3),
            "AimPointScene 结果区应出现 compact 满额"
        )
        snap("w7-c23-07-aimpoint-scene-compact")

        // 4) SceneAiming：满额 + 20 题模式 → 总结 compact
        app.terminate()
        app = XCUIApplication.launchClean(extraArgs: ["-w7.forceDailyLimit"])
        guard openCard(homeTab: "练", title: "2D 角度训练") else {
            XCTFail("未能进入 2D 角度训练"); return
        }
        let start = app.buttons["开始训练"]
        if start.waitForExistence(timeout: 3) {
            start.tap()
            sleep(2)
        }
        XCTAssertTrue(
            app.staticTexts["今日免费次数已用完"].waitForExistence(timeout: 4),
            "SceneAiming 总结区应显示 compact 满额"
        )
        snap("w7-c23-08-scene-aiming-compact")
    }
}
