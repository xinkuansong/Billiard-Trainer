import XCTest

/// 详情页顶栏「整条序列逐杆演示」+ HUD 条时序验收。
///
/// 时间轴（`DrillSceneController`）：点回放 → 读球形 1.5s（素台）→ 逐杆循环
/// 〔亮方案（首杆 1.5s / 后续 0.45s）→ 运杆出杆 → 触球清线 → 物理回放 → 落静止位 →
/// 杆间停顿 0.7s〕→ 全部走完复位静帧。
/// HUD 条（`drillShotHUDBar`）：点播放前不存在 → 播放全程存在（逐杆换值）→ 播完消失。
/// 截图落盘 `build/drill-scene-three-beat/`。
final class DrillSceneThreeBeatUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/drill-scene-three-beat"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    /// `drill_c001` 的示范序列为 5 杆：验证整条播完（而非只播首杆）且 HUD 时序正确。
    func testSequencePlaysAllShotsAndHUDTiming() {
        openDrillC001()

        let hud = app.otherElements["drillShotHUDBar"]
        XCTAssertFalse(hud.exists, "点播放前不应显示打点盘/力度条")
        savePNG("s0-idle-no-hud")

        let play = app.buttons["drillPlayButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5), "详情页无回放按钮")
        play.tap()

        // 播放开始即显示 HUD（读球形拍内）。
        XCTAssertTrue(hud.waitForExistence(timeout: 3), "播放开始后应显示 HUD 条")
        savePNG("s1-observe-hud-on")

        // 首杆亮方案（1.5s 后）：预告线 + 假想球 + 瞄准位球杆。
        usleep(1_800_000)
        savePNG("s2-shot1-plan")

        // 首杆运杆/出杆。
        usleep(1_200_000)
        savePNG("s3-shot1-stroke")

        // 5 杆序列全程 HUD 必须一直在；同时抽样截图看后续杆确实在演示。
        var stillOnSamples = 0
        for i in 0..<8 {
            usleep(2_000_000)
            if hud.exists { stillOnSamples += 1 }
            if i == 2 { savePNG("s4-mid-sequence") }
            if i == 5 { savePNG("s5-late-sequence") }
        }
        XCTAssertGreaterThan(
            stillOnSamples, 4,
            "5 杆序列演示应持续 20s 量级；HUD 过早消失说明只播了首杆"
        )

        // 按钮标签随状态回到「回放」即整条序列播完。
        let deadline = Date().addingTimeInterval(60)
        while play.label != "回放", Date() < deadline {
            usleep(1_000_000)
        }
        XCTAssertEqual(play.label, "回放", "序列应在 60s 内播完并复位按钮状态")
        sleep(1)
        XCTAssertFalse(hud.exists, "整条序列播完后应隐藏打点盘/力度条")
        savePNG("s6-finished-no-hud")
    }

    /// 点播放后按钮须立刻给出「播放中」反馈；暂停在**杆边界**生效（当前杆完整播完）。
    func testPlayButtonStateAndPauseCompletesCurrentShot() {
        openDrillC078()

        let play = app.buttons["drillPlayButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5), "详情页无回放按钮")
        XCTAssertEqual(play.label, "回放", "空闲态按钮应为「回放」")

        play.tap()
        // 用户反馈「点了没变化」：点击后必须立刻切到播放中（可暂停）。
        XCTAssertEqual(play.label, "暂停", "点播放后按钮应立刻变为播放中状态")
        let hud = app.otherElements["drillShotHUDBar"]
        let tableViewport = app.descendants(matching: .any)
            .matching(identifier: "drillSceneTableViewport").firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 3), "播放后应显示 HUD")
        XCTAssertTrue(tableViewport.exists, "未找到球桌视口")
        XCTAssertGreaterThanOrEqual(
            hud.frame.minY,
            tableViewport.frame.maxY - 1,
            "HUD 应位于球桌下方，不得覆盖台面"
        )
        savePNG("p1-playing-state")

        // 播放控制约 2s 后自动隐藏；第一次轻点球桌只负责重新唤出。
        sleep(3)
        XCTAssertFalse(play.exists, "播放中暂停键不应长期覆盖球桌")
        savePNG("p1a-controls-hidden")
        tableViewport.tap()
        XCTAssertTrue(play.waitForExistence(timeout: 2), "轻点球桌后应重新显示暂停键")
        XCTAssertEqual(play.label, "暂停")
        savePNG("p1b-controls-revealed")

        // 此时开播已超过 4s，首杆正在执行；直接请求杆边界暂停。
        play.tap()
        XCTAssertEqual(
            play.label, "本杆结束后暂停",
            "暂停请求应先进入「等本杆播完」，而不是立刻停"
        )
        savePNG("p2-pausing-after-shot")

        // 当前杆播完后落到「继续」态。
        let deadline = Date().addingTimeInterval(40)
        while play.label != "继续", Date() < deadline {
            usleep(500_000)
        }
        XCTAssertEqual(play.label, "继续", "当前杆播完后应停在暂停态")
        savePNG("p3-paused")

        // 暂停确实停住了：读数在静置期间不再变化（未擅自播下一杆）。
        let readout = app.staticTexts.matching(
            NSPredicate(format: "label ENDSWITH 'm/s'")
        ).firstMatch
        XCTAssertTrue(readout.exists, "暂停期间 HUD 应保留（整条序列尚未播完）")
        let atPause = readout.label
        sleep(6)
        XCTAssertEqual(readout.label, atPause, "暂停后不应继续演示下一杆")
        XCTAssertEqual(play.label, "继续", "暂停态应保持到用户点继续")

        // 继续后回到播放中。
        play.tap()
        XCTAssertEqual(play.label, "暂停", "点继续后应恢复播放中状态")
        savePNG("p4-resumed")
    }

    /// HUD 必须逐杆换成当前杆的参数，而非全程停在首杆。
    ///
    /// 取 `drill_c078`（16 杆，每杆打点/力度互不相同，力度 1.5–2.5 m/s）：
    /// `c001` 前三杆恰好同为「中心球 1.5」，无法证伪「只显示首杆」。
    func testHUDUpdatesPerShot() {
        openDrillC078()

        let play = app.buttons["drillPlayButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5), "详情页无回放按钮")
        play.tap()

        // 力度读数（「轻 1.8 m/s」）含数值，逐杆必变；轮询收集去重。
        let readout = app.staticTexts.matching(
            NSPredicate(format: "label ENDSWITH 'm/s'")
        ).firstMatch
        var seen = Set<String>()
        let deadline = Date().addingTimeInterval(40)
        while Date() < deadline, seen.count < 2 {
            if readout.exists { seen.insert(readout.label) }
            usleep(400_000)
        }
        savePNG("h1-hud-per-shot")
        XCTAssertGreaterThanOrEqual(
            seen.count, 2,
            "HUD 应逐杆更新为当前杆参数，实际全程只出现：\(seen)"
        )
    }

    func testDetailInformationHierarchyLight() {
        verifyDetailInformationHierarchy(appearance: .light, label: "Light", slug: "light")
    }

    func testDetailInformationHierarchyDark() {
        verifyDetailInformationHierarchy(appearance: .dark, label: "Dark", slug: "dark")
    }

    /// 训练进行中的「球台示意」复用同一 `DrillSceneView`。
    func testActiveTrainingBallTableUsesSameHUD() {
        _ = app.tabBars.buttons["训练"].waitForExistence(timeout: 15)
        app.switchTab(.training)
        sleep(2)

        if !tapLabel("开始训练", timeout: 6) {
            _ = tapLabel("自由记录", timeout: 4)
        }
        sleep(2)
        if tapLabel("继续", timeout: 6) { sleep(3) }

        // 空训练：先从动作库挑一条，才会出现 `DrillRecordView` 的「球台示意」。
        if tapLabel("添加训练动作", timeout: 4) {
            sleep(2)
            // 选择 sheet 的行不带 drillCard_ 前缀，按动作名命中。
            // 失败机理（v39 W6）：c010/c014 同名「中杆定杆基础」已拆开，c010 改为「定杆停点」。
            let row = app.staticTexts["定杆停点"]
            if row.waitForExistence(timeout: 6) {
                row.tap()
                sleep(1)
                // 选中后按钮文案带计数（「完成 (1)」），需前缀匹配。
                let done = app.buttons
                    .matching(NSPredicate(format: "label BEGINSWITH '完成'")).firstMatch
                if done.waitForExistence(timeout: 4) { done.tap() }
                sleep(4)
            }
        }
        savePNG("t1-active-training-overview")

        // 总览列表 → 点动作行进入 `DrillRecordView`（球台示意在其底部）。
        let row = app.staticTexts["定杆停点"]
        if row.waitForExistence(timeout: 5) {
            row.tap()
            sleep(4)
            // 球台示意在记录页底部，需滚动到底。
            for _ in 0..<3 {
                app.swipeUp()
                usleep(600_000)
            }
            sleep(3)
            savePNG("t2-drill-record-table")

            // 训练页同样遵守「播放前无 HUD」。
            XCTAssertFalse(
                app.otherElements["drillShotHUDBar"].exists,
                "训练页球台示意在播放前也不应显示 HUD 条"
            )
        }
    }

    /// `drill_c078`：16 杆、逐杆打点/力度互不相同，适合验证长序列与逐杆更新。
    private func openDrillC078() {
        app.switchTab(.drillLibrary)
        sleep(2)
        let searchField = app.textFields["搜索动作"]
        if searchField.waitForExistence(timeout: 4) {
            searchField.tap()
            searchField.typeText("远台带塞")
            sleep(2)
        }
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'drillCard_drill_c078'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "未找到 drill_c078 卡片")
        card.tap()
        sleep(3)
    }

    /// 详情页共享布局应保留正文标题、无空闲 HUD 条；达标目标与建议量在「训练要求」卡，
    /// 假五维「训练维度」已删除，页底为六轴难度画像雷达。
    private func verifyDetailInformationHierarchy(
        appearance: XCUIDevice.Appearance,
        label: String,
        slug: String
    ) {
        let originalAppearance = XCUIDevice.shared.appearance
        defer { XCUIDevice.shared.appearance = originalAppearance }

        app.terminate()
        XCUIDevice.shared.appearance = appearance
        app = XCUIApplication.launchClean()
        openDrillC001()

        XCTAssertTrue(app.staticTexts["半台直线球"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["L0 入门"].exists, "难度徽章应与正文标题同组显示")
        XCTAssertFalse(
            app.otherElements["drillShotHUDBar"].exists,
            "空闲详情页不应为 HUD 保留黑色占位条"
        )
        savePNG("layout-\(slug)-top")

        app.swipeUp()
        XCTAssertTrue(
            app.staticTexts["训练要求"].waitForExistence(timeout: 5),
            "\(label) 模式下未显示合并后的训练要求卡"
        )
        XCTAssertTrue(app.staticTexts["达标目标"].exists)
        XCTAssertTrue(app.staticTexts["建议训练量"].exists)
        XCTAssertFalse(app.staticTexts["训练维度"].exists, "假五维「训练维度」必须删除")
        app.swipeUp()
        XCTAssertTrue(
            app.staticTexts["难度画像"].waitForExistence(timeout: 8),
            "\(label) 模式下未显示六轴雷达"
        )
        XCTAssertFalse(app.staticTexts["执行负荷"].exists)
        savePNG("layout-\(slug)-requirements")
    }

    private func openDrillC001() {
        app.switchTab(.drillLibrary)
        sleep(2)

        let searchField = app.textFields["搜索动作"]
        if searchField.waitForExistence(timeout: 4) {
            searchField.tap()
            searchField.typeText("直线")
            sleep(2)
        }
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'drillCard_drill_c001'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "未找到 drill_c001 卡片")
        card.tap()
        sleep(3)
    }

    @discardableResult
    private func tapLabel(_ label: String, timeout: TimeInterval = 6) -> Bool {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }
        let text = app.staticTexts[label]
        if text.waitForExistence(timeout: 1) {
            text.tap()
            return true
        }
        return false
    }

    private func savePNG(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: outDir.appendingPathComponent("\(name).png"))
    }
}
