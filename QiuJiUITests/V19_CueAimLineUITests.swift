import XCTest

/// 问题集合 v19 W1 取证：瞄准线同现球杆 / SceneAiming 仍无杆 / 开球与 Composer。
/// PNG 落盘 `build/v19-evidence/screenshots/`（禁止写 docs/ui-polish）。
final class V19_CueAimLineUITests: XCTestCase {

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v19-evidence/screenshots")
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

    private func dismissOnboardingIfNeeded(_ app: XCUIApplication) {
        let skip = app.buttons["跳过"]
        if skip.waitForExistence(timeout: 3) {
            skip.tap()
            sleep(1)
        }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 15)
    }

    @discardableResult
    private func switchAngleHomeTab(_ app: XCUIApplication, _ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 6) else { return false }
        seg.tap()
        usleep(600_000)
        return true
    }

    private func openCard(_ app: XCUIApplication, homeTab: String, title: String) -> Bool {
        dismissOnboardingIfNeeded(app)
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab(app, homeTab) else { return false }
        let card = app.buttons[title]
        guard card.waitForExistence(timeout: 6) else { return false }
        card.tap()
        sleep(3)
        return true
    }

    /// C2：翻袋求解有解 → 应见瞄准相关线 + 球杆。
    func testV19_bankSolve_hasCue() {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(openCard(app, homeTab: "解", title: "翻袋解球器"), "打开翻袋解球器")
        sleep(5) // 求解去抖 + 引擎
        snap(app, "v19-01-bank-solve-cue")
    }

    /// C3：Composer 开球瞄准期有瞄准线 + 杆。
    func testV19_composerBreak_aimHasCue() {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(openCard(app, homeTab: "打", title: "自由走位"), "打开自由走位")
        let entry = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'break.entry'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 6), "开球入口")
        entry.tap()
        sleep(2)
        // 玩法 sheet（若出现）选中八
        let eight = app.buttons["中式八球"]
        if eight.waitForExistence(timeout: 3) {
            eight.tap()
            sleep(1)
        }
        snap(app, "v19-02-break-aim-cue")
    }

    /// C4：Composer 自由模式拖瞄准预览期有杆。
    func testV19_composerFreeAimDrag_hasCue() {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(openCard(app, homeTab: "打", title: "自由走位"), "打开自由走位")
        sleep(2)
        // BTAimModeToggleButton：accessibilityLabel = "瞄准模式：进袋/自由，点击切换"
        let modeToggle = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '瞄准模式'")
        ).firstMatch
        XCTAssertTrue(modeToggle.waitForExistence(timeout: 6), "应找到瞄准模式切换钮")
        // 若仍是进袋，点一次切到自由
        if (modeToggle.label as String).contains("进袋") {
            modeToggle.tap()
            sleep(1)
        }
        XCTAssertTrue((modeToggle.label as String).contains("自由"),
                      "应已切到自由模式，实际=\(modeToggle.label)")
        // 拖屏相对调向（G13）触发 showGeometryPreviewOnly + 跟杆
        let scene = app.windows.firstMatch
        scene.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.40))
            .press(forDuration: 0.08,
                   thenDragTo: scene.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.38)))
        usleep(250_000)
        snap(app, "v19-03-composer-free-drag-cue")
    }

    /// C5：AimPointScene 瞄准期有杆（沿用户白线）。
    func testV19_aimPointScene_aimingHasCue() {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(openCard(app, homeTab: "练", title: "2D 瞄准点训练"), "打开 2D 瞄准点训练")
        sleep(2)
        snap(app, "v19-04-aimpoint-aiming-cue")
    }

    /// C6：SceneAiming 辅助开仍无瞄准杆（回归）。
    func testV19_sceneAiming_assistStillNoCue() {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(openCard(app, homeTab: "练", title: "2D 角度训练"), "打开 2D 角度训练")
        // 设置 sheet：开始
        let start = app.buttons["开始训练"]
        if start.waitForExistence(timeout: 4) {
            start.tap()
            sleep(2)
        }
        // 打开辅助（若有）
        let assist = app.buttons["辅助"]
        if assist.waitForExistence(timeout: 3) {
            assist.tap()
            sleep(1)
        }
        snap(app, "v19-05-sceneaiming-assist-no-cue")
    }

    /// C7：击球后点回放/上一杆路径——抓取运杆前静止瞄准帧（无闪藏需目视）。
    func testV19_composerPlayback_restAim() {
        let app = XCUIApplication.launchClean()
        XCTAssertTrue(openCard(app, homeTab: "打", title: "自由走位"), "打开自由走位")
        sleep(3)
        if app.buttons["击球"].waitForExistence(timeout: 4) {
            app.buttons["击球"].tap()
            sleep(8)
        }
        // 优先「回放」，否则「上一杆」
        if app.buttons["回放"].waitForExistence(timeout: 3) {
            app.buttons["回放"].tap()
            usleep(150_000)
            snap(app, "v19-06-playback-rest-aim")
            sleep(2)
        } else if app.buttons["上一杆"].waitForExistence(timeout: 3) {
            app.buttons["上一杆"].tap()
            sleep(1)
            snap(app, "v19-06-undo-restored")
        } else {
            snap(app, "v19-06-playback-unavailable")
        }
    }
}
