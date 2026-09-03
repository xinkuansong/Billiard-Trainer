import XCTest

/// v54 product-state evidence. Run this class on each requested device/appearance;
/// V54_SHOT_DIR keeps every matrix lane isolated.
final class V54ScheduleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPlanDetailFourBusinessStatesAndComposerAccessibility() throws {
        let states: [(String, String)] = [
            ("start", "开始此计划"),
            ("other", "切换到此计划"),
            ("current", "编排今天"),
            ("completed", "选择课程复练"),
        ]
        for (state, expectedCTA) in states {
            launch([
                "-deeplink.planDetail=plan_beginner",
                "-v54.planState=\(state)",
            ])
            let cta = app.buttons["planDetail.primaryCTA"].firstMatch
            XCTAssertTrue(cta.waitForExistence(timeout: 20), "\(state) 缺少计划主按钮")
            XCTAssertEqual(cta.label, expectedCTA)
            XCTAssertTrue(app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS '个阶段'")
            ).firstMatch.exists)
            XCTAssertTrue(app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS '预计约'")
            ).firstMatch.exists || state == "completed")
            try capture("plan-\(state)")

            if state == "current" {
                openComposer(from: cta)
                let summary = app.descendants(matching: .any)["planDetail.arrangementSummary"].firstMatch
                if !summary.waitForExistence(timeout: 5) {
                    app.sheets.firstMatch.swipeUp()
                }
                XCTAssertTrue(summary.waitForExistence(timeout: 8))
                XCTAssertTrue(summary.label.contains("将加入 1 项"), "当前课应默认选中：\(summary.label)")
                XCTAssertTrue(app.buttons["planDetail.addToToday"].isEnabled)
                XCTAssertTrue(app.descendants(matching: .any).matching(
                    NSPredicate(format: "label CONTAINS '当前' AND label CONTAINS '已选择'")
                ).firstMatch.exists, "VoiceOver 标签应同时表达课程状态和选择状态")
                try capture("plan-current-composer")
            }
        }
    }

    /// iPad may present the composer as a form sheet and occasionally consumes the
    /// first tap while the split-view column is settling. Require the sheet title,
    /// then retry once only when the button is still the active surface.
    private func openComposer(from cta: XCUIElement) {
        cta.tap()
        let composerTitle = app.navigationBars["编排今天"].firstMatch
        guard !composerTitle.waitForExistence(timeout: 5), cta.exists, cta.isHittable else { return }
        cta.tap()
        XCTAssertTrue(composerTitle.waitForExistence(timeout: 8), "编排今天未呈现")
    }

    func testTodayScheduleSixStates() throws {
        for state in ["empty", "suggestion", "mixed", "partial", "completed", "yesterday"] {
            launch(["-v54.todayState=\(state)"])
            let window = app.windows.firstMatch
            XCTAssertTrue(window.waitForExistence(timeout: 15))
            switch state {
            case "empty":
                XCTAssertTrue(app.buttons["trainingHome.freeRecord"].waitForExistence(timeout: 12))
            case "suggestion":
                XCTAssertTrue(app.buttons["trainingHome.startTraining"].waitForExistence(timeout: 12))
                XCTAssertFalse(app.descendants(matching: .any)["trainingHome.todaySchedule"].exists)
            case "mixed":
                try assertScheduleHasAccessibleSource("官方计划")
                try assertScheduleHasAccessibleSource("赛前热身")
                try assertScheduleHasAccessibleSource("中袋角度球")
            case "partial":
                XCTAssertTrue(app.descendants(matching: .any).matching(
                    NSPredicate(format: "label CONTAINS '已完成'")
                ).firstMatch.waitForExistence(timeout: 12))
                XCTAssertEqual(app.buttons["trainingHome.startTraining"].label, "继续")
            case "completed":
                XCTAssertTrue(app.descendants(matching: .any)["trainingHome.todaySchedule"].waitForExistence(timeout: 12))
                XCTAssertFalse(app.buttons["trainingHome.startTraining"].exists)
            case "yesterday":
                XCTAssertTrue(app.buttons["trainingHome.carryYesterday"].waitForExistence(timeout: 12))
            default:
                XCTFail("unknown fixture")
            }
            try capture("today-\(state)")
        }
    }

    func testHistoryKeepsFrozenSourceWhenLiveSourceDisappears() throws {
        launch(["-v54.historySource=official"])
        let breadcrumb = app.buttons["trainingDetail.sourceBreadcrumb"].firstMatch
        XCTAssertTrue(breadcrumb.waitForExistence(timeout: 15))
        XCTAssertTrue(breadcrumb.label.contains("官方计划"))
        XCTAssertTrue(breadcrumb.label.contains("基本功 · 第 1 阶段"))
        XCTAssertTrue(breadcrumb.label.contains("中袋直线出杆与底袋直线出杆"))
        XCTAssertTrue(breadcrumb.isEnabled)
        try capture("history-source-existing")

        launch(["-v54.historySource=deleted"])
        let deleted = app.buttons["trainingDetail.sourceBreadcrumb"].firstMatch
        XCTAssertTrue(deleted.waitForExistence(timeout: 15))
        XCTAssertTrue(deleted.label.contains("我的模版"))
        XCTAssertTrue(deleted.label.contains("赛前热身模版"))
        XCTAssertTrue(deleted.label.contains("来源已删除"))
        XCTAssertFalse(deleted.isEnabled)
        try capture("history-source-deleted")
    }

    private func assertScheduleHasAccessibleSource(_ text: String) throws {
        let schedule = app.descendants(matching: .any)["trainingHome.todaySchedule"].firstMatch
        XCTAssertTrue(schedule.waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", text)
        ).firstMatch.exists, "队列应可访问地表达 \(text)")
    }

    private func launch(_ args: [String]) {
        app?.terminate()
        let appearance = ProcessInfo.processInfo.environment["V54_APPEARANCE"] == "dark"
            ? "-v54.forceDark" : "-v54.forceLight"
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", appearance,
        ] + args)
    }

    private func capture(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let path = ProcessInfo.processInfo.environment["V54_SHOT_DIR"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_V54_SHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try screenshot.pngRepresentation.write(
            to: directory.appendingPathComponent("\(name).png"), options: .atomic
        )
    }
}
