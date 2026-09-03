import XCTest

/// v51 紧凑手机布局阻断测试。截图与 frame JSON 写入矩阵执行器提供的隔离目录。
final class V51ResponsiveLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testActiveTrainingTimerIsSingleLineAndClearsActions() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-v50.inMemoryStore",
            "-v51.followSystemAppearance",
            "-v51.activeTraining",
            "-v51.elapsedSeconds=360006",
        ])

        let timer = app.descendants(matching: .any)["activeTraining.timer"].firstMatch
        if !timer.waitForExistence(timeout: 20) {
            // iOS 17 CoreSimulator 偶发让 UI 测试首个冷启动停在无参数的普通首页。
            // 使用完全相同的 launchArguments 只重启一次；若路由仍未生效则保持阻断。
            app.terminate()
            app.launch()
        }
        XCTAssertTrue(timer.waitForExistence(timeout: 20), "必须进入 v51 训练测试宿主")
        XCTAssertLessThanOrEqual(timer.frame.height, 44, "计时不得折成两行")

        let actionIDs = ["activeTraining.timerToggle", "activeTraining.rest", "activeTraining.more"]
        var elements: [String: XCUIElement] = ["timer": timer]
        for id in actionIDs {
            let control = app.descendants(matching: .any)[id].firstMatch
            XCTAssertTrue(control.waitForExistence(timeout: 5), "缺少 \(id)")
            XCTAssertGreaterThanOrEqual(control.frame.width, 44)
            XCTAssertGreaterThanOrEqual(control.frame.height, 44)
            XCTAssertFalse(timer.frame.intersects(control.frame), "计时不得与 \(id) 相交")
            elements[id] = control
        }
        try capture("active-training-long-timer", elements: elements)

        let timerToggle = app.buttons["activeTraining.timerToggle"].firstMatch
        timerToggle.tap()
        let continueTimer = app.buttons["继续计时"].firstMatch
        if !continueTimer.waitForExistence(timeout: 5) {
            XCTAssertEqual(timerToggle.label, "暂停计时")
            XCTAssertTrue(timerToggle.isHittable)
            timerToggle.tap()
        }
        XCTAssertTrue(continueTimer.waitForExistence(timeout: 5))
        try capture("active-training-paused", elements: ["timer": timer])

        app.buttons["activeTraining.more"].tap()
        let skipTimer = app.buttons["跳过计时"].firstMatch
        XCTAssertTrue(skipTimer.waitForExistence(timeout: 5))
        skipTimer.tap()
        let skipped = app.descendants(matching: .any)["activeTraining.timer"].firstMatch
        XCTAssertTrue(skipped.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(skipped.frame.height, 44, "跳过计时状态不得折行")
        try capture("active-training-skipped", elements: ["timer": skipped])
    }

    func testMinimizedTrainingClearsAllFiveTabs() throws {
        try assertMinimizedTraining(elapsedSeconds: 360_006, artifactSuffix: "long", resumesSession: true)
    }

    func testMinimizedTrainingShortTimeClearsAllFiveTabs() throws {
        try assertMinimizedTraining(elapsedSeconds: 6, artifactSuffix: "short", resumesSession: false)
    }

    func testRestOverlayAndSessionLocalMinimizeRemainReachable() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-v50.inMemoryStore",
            "-v51.followSystemAppearance",
            "-v51.activeTraining",
        ])

        let rest = app.buttons["activeTraining.rest"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 15))
        rest.tap()

        let overlayTitle = app.staticTexts["组间休息"].firstMatch
        let minimizeRest = app.buttons["最小化组间休息"].firstMatch
        if !overlayTitle.waitForExistence(timeout: 8) {
            // 并行模拟器高负载下 UIKit 偶尔会合成触摸但未交付给 SwiftUI；
            // 只在状态完全未变化时做一次有界重试，仍失败则保持阻断。
            XCTAssertEqual(rest.label, "休息设置")
            XCTAssertTrue(rest.isHittable)
            rest.tap()
        }
        XCTAssertTrue(overlayTitle.waitForExistence(timeout: 8))
        XCTAssertTrue(minimizeRest.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(minimizeRest.frame.height, 43.5)
        try capture(
            "active-training-rest-overlay",
            elements: ["overlayTitle": overlayTitle, "minimizeRest": minimizeRest]
        )

        minimizeRest.tap()
        let expandRest = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "展开组间休息")
        ).firstMatch
        XCTAssertTrue(expandRest.waitForExistence(timeout: 8))
        XCTAssertGreaterThanOrEqual(expandRest.frame.height, 43.5)
        XCTAssertFalse(app.buttons["minimizedTraining.resume"].exists, "休息卡最小化不能变成跨 Tab 会话浮标")
        XCTAssertTrue(app.descendants(matching: .any)["activeTraining.timer"].firstMatch.exists)
        try capture("active-training-rest-minimized", elements: ["expandRest": expandRest])
    }

    private func assertMinimizedTraining(
        elapsedSeconds: Int,
        artifactSuffix: String,
        resumesSession: Bool
    ) throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-v50.inMemoryStore",
            "-v51.followSystemAppearance",
            "-v51.minimizedTraining",
            "-v51.elapsedSeconds=\(elapsedSeconds)",
        ])

        let resume = app.buttons["minimizedTraining.resume"].firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 12))
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.frame.contains(resume.frame), "继续训练必须完整落在窗口内")
        var elements: [String: XCUIElement] = ["resume": resume]
        for tab in XCUIApplication.Tab.allCases {
            let item = tabElement(tab)
            XCTAssertTrue(item.waitForExistence(timeout: 8), "缺少 Tab \(tab.rawValue)")
            XCTAssertTrue(item.isHittable, "Tab \(tab.rawValue) 不可点击")
            XCTAssertFalse(resume.frame.intersects(item.frame), "继续训练不得遮挡 \(tab.rawValue)")
            elements["tab-\(tab.rawValue)"] = item
            item.tap()
            XCTAssertTrue(resume.exists)
        }
        try capture("minimized-training-\(artifactSuffix)-five-tabs", elements: elements)

        if resumesSession {
            XCTAssertTrue(resume.isHittable, "继续训练必须在切换五个 Tab 后仍可点击")
            resume.tap()
            let timer = app.descendants(matching: .any)["activeTraining.timer"].firstMatch
            XCTAssertTrue(timer.waitForExistence(timeout: 10))
            let restoredTime = timer.label.replacingOccurrences(of: "训练时间 ", with: "")
            let parts = restoredTime.split(separator: ":").compactMap { Int($0) }
            XCTAssertEqual(parts.count, 3)
            XCTAssertEqual(parts.first, 100, "恢复后不能丢失累计的 100 小时会话")
            XCTAssertEqual(parts.dropFirst().first, 0)
            XCTAssertTrue((6...30).contains(parts.last ?? -1), "恢复后计时应从原值继续，而不是重置或异常跳变")
            try capture("minimized-training-resumed-session", elements: ["timer": timer])
        }
    }

    func testCompactShotStageRailsAndPaletteDoNotOverlap() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-v50.inMemoryStore",
            "-v51.followSystemAppearance",
            "-deeplink.freePlay",
        ])

        let aimMode = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "瞄准模式：")
        ).firstMatch
        XCTAssertTrue(aimMode.waitForExistence(timeout: 20))
        let readyStatus = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "navStatus.subtitle", "已就绪")
        ).firstMatch
        XCTAssertTrue(readyStatus.waitForExistence(timeout: 20), "场景初始化完成后再切换瞄准模式")
        aimMode.tap()
        let freeMode = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "瞄准模式：自由")
        ).firstMatch
        XCTAssertTrue(freeMode.waitForExistence(timeout: 8), "瞄准模式必须稳定切到自由")

        let aim = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
        let instrument = app.descendants(matching: .any)["shotStage.instrument"].firstMatch
        XCTAssertTrue(aim.waitForExistence(timeout: 20))
        XCTAssertTrue(instrument.waitForExistence(timeout: 8))
        let windowWidth = app.windows.firstMatch.frame.width
        let expectedRailCap: CGFloat = windowWidth <= 390 ? 180.5 : 264.5
        XCTAssertLessThanOrEqual(aim.frame.height, expectedRailCap)
        XCTAssertEqual(aim.frame.maxY, instrument.frame.maxY, accuracy: 1.5)

        let spinEntry = app.buttons["shotStage.spinEntry"].firstMatch
        XCTAssertTrue(spinEntry.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(spinEntry.frame.width, 43.5)
        XCTAssertGreaterThanOrEqual(spinEntry.frame.height, 43.5)

        let ball1 = app.descendants(matching: .any)["paletteBall__1"].firstMatch
        let ball2 = app.descendants(matching: .any)["paletteBall__2"].firstMatch
        let ball8 = app.descendants(matching: .any)["paletteBall__8"].firstMatch
        let ball15 = app.descendants(matching: .any)["paletteBall__15"].firstMatch
        for ball in [ball1, ball2, ball8, ball15] {
            XCTAssertTrue(ball.waitForExistence(timeout: 8))
            XCTAssertTrue(ball.isHittable)
            XCTAssertGreaterThanOrEqual(ball.frame.width, 43.5)
            XCTAssertGreaterThanOrEqual(ball.frame.height, 43.5)
        }
        XCTAssertFalse(ball1.frame.intersects(ball2.frame))
        XCTAssertFalse(ball2.frame.intersects(ball8.frame))
        XCTAssertFalse(ball8.frame.intersects(ball15.frame))
        try capture(
            "compact-shot-stage",
            elements: [
                "aim": aim,
                "instrument": instrument,
                "spinEntry": spinEntry,
                "ball1": ball1,
                "ball2": ball2,
                "ball8": ball8,
                "ball15": ball15,
            ]
        )

        spinEntry.tap()
        let closeSpin = app.buttons["关闭打点"].firstMatch
        XCTAssertTrue(closeSpin.waitForExistence(timeout: 5), "打点入口必须能打开共享打点盘")
        try capture("compact-shot-stage-spin-pad", elements: ["closeSpin": closeSpin])
        closeSpin.tap()
    }

    func testResponsiveComponentProbeKeepsPaletteStatusAndChipsReachable() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-v50.inMemoryStore",
            "-v51.followSystemAppearance",
            "-v51.componentProbe",
        ])

        let status = app.descendants(matching: .any)["navStatus.subtitle"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 12))
        XCTAssertEqual(status.label, "第 12 个候选解 · 右上角袋 · 两库反射后保留完整状态语义")
        XCTAssertTrue(app.windows.firstMatch.frame.intersects(status.frame))

        let chipRow = app.scrollViews["shotStage.chipRow"].firstMatch
        for index in 0..<4 {
            let chip = app.buttons["shotStage.chip.\(index)"].firstMatch
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "缺少模式 Chip \(index)")
            if !chip.isHittable {
                if chipRow.exists { chipRow.swipeLeft() } else { app.swipeLeft() }
            }
            XCTAssertTrue(chip.isHittable, "模式 Chip \(index) 在当前字号不可达")
            XCTAssertGreaterThanOrEqual(chip.frame.height, 43.5)
        }

        let lastTap = app.staticTexts["v51.probe.lastTap"].firstMatch
        XCTAssertTrue(lastTap.waitForExistence(timeout: 5))
        for number in 1...15 {
            let key = "_\(number)"
            let ball = app.descendants(matching: .any)["paletteBall_\(key)"].firstMatch
            XCTAssertTrue(ball.waitForExistence(timeout: 5), "缺少球库球 \(key)")
            XCTAssertTrue(ball.isHittable)
            XCTAssertGreaterThanOrEqual(ball.frame.width, 43.5)
            XCTAssertGreaterThanOrEqual(ball.frame.height, 43.5)
            ball.tap()
            let updated = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "最后点击：\(key)"),
                object: lastTap
            )
            XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 2), .completed)
        }

        try capture(
            "responsive-components",
            elements: ["status": status, "lastTap": lastTap]
        )
    }

    private func tabElement(_ tab: XCUIApplication.Tab) -> XCUIElement {
        let inBar = app.tabBars.buttons[tab.rawValue].firstMatch
        return inBar.exists ? inBar : app.buttons[tab.rawValue].firstMatch
    }

    private func capture(_ name: String, elements: [String: XCUIElement]) throws {
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
        let frames = elements.mapValues { element in
            let frame = element.frame
            return ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
        }
        let data = try JSONSerialization.data(withJSONObject: frames, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("\(name)-frames.json"), options: .atomic)
    }
}

private extension XCUIApplication.Tab {
    static var allCases: [XCUIApplication.Tab] {
        [.training, .drillLibrary, .angle, .history, .profile]
    }
}
