import XCTest

/// v54 product-state evidence. Run this class on each requested device/appearance;
/// V54_SHOT_DIR keeps every matrix lane isolated.
final class V54ScheduleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testV57SwitchPausedPlanUpdatesPrimaryAction() throws {
        launch(["-deeplink.planDetail=plan_beginner", "-v54.planState=other"])
        let cta = app.buttons["planDetail.primaryCTA"].firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 20))
        XCTAssertEqual(cta.label, "切换到此计划")
        try capture("v57-switch-before")
        cta.tap()
        let confirm = app.alerts.buttons["确定激活"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        let changed = NSPredicate(format: "label == %@", "编排今天")
        expectation(for: changed, evaluatedWith: cta)
        waitForExpectations(timeout: 10)
        try capture("v57-switch-after")
        openComposer(from: cta)
        XCTAssertTrue(app.buttons["planDetail.addToToday"].waitForExistence(timeout: 8))
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
        for state in ["empty", "suggestion", "single", "mixed", "partial", "completed", "freeCompleted", "suggestionTemplate", "yesterday"] {
            launch(["-v54.todayState=\(state)"])
            let window = app.windows.firstMatch
            XCTAssertTrue(window.waitForExistence(timeout: 15))
            switch state {
            case "empty":
                XCTAssertTrue(app.buttons["trainingHome.freeRecord"].waitForExistence(timeout: 12))
            case "suggestion":
                XCTAssertTrue(app.buttons["trainingHome.startTraining"].waitForExistence(timeout: 12))
                XCTAssertTrue(app.buttons["trainingHome.suggestion"].waitForExistence(timeout: 8))
                XCTAssertTrue(app.descendants(matching: .any)["trainingHome.todaySummary"].firstMatch.label.contains("尚未加入"))
            case "single":
                XCTAssertTrue(app.buttons["开始这节课"].firstMatch.waitForExistence(timeout: 12),
                              "单课时详细内容应直接显示明确开始按钮")
            case "mixed":
                try assertScheduleHasAccessibleSource("官方计划")
                try assertScheduleHasAccessibleSource("赛前热身")
                try assertScheduleHasAccessibleSource("中袋角度球")
                try assertMultiItemDisclosureDoesNotStartTraining()
            case "partial":
                XCTAssertTrue(app.descendants(matching: .any).matching(
                    NSPredicate(format: "label CONTAINS '已完成'")
                ).firstMatch.waitForExistence(timeout: 12))
                XCTAssertEqual(app.buttons["trainingHome.startTraining"].label, "继续")
            case "completed", "freeCompleted":
                XCTAssertTrue(app.descendants(matching: .any)["trainingHome.todaySchedule"].waitForExistence(timeout: 12))
                XCTAssertFalse(app.buttons["trainingHome.startTraining"].exists)
                XCTAssertTrue(app.buttons["trainingHome.freeTraining"].exists)
                XCTAssertTrue(app.descendants(matching: .any)["trainingHome.todaySummary"].firstMatch.label.contains("全部完成"))
            case "suggestionTemplate":
                XCTAssertTrue(app.buttons["trainingHome.suggestion"].waitForExistence(timeout: 12))
                try assertScheduleHasAccessibleSource("赛前热身")
                XCTAssertTrue(app.descendants(matching: .any)["trainingHome.todaySummary"].firstMatch.label.contains("0 / 1"))
            case "yesterday":
                XCTAssertTrue(app.buttons["trainingHome.carryYesterday"].waitForExistence(timeout: 12))
            default:
                XCTFail("unknown fixture")
            }
            try capture("today-\(state)")
        }
    }

    func testV57CompletedTrainingCanSaveAndStartFreeAgain() throws {
        for state in ["completed", "freeCompleted"] {
            launch(["-v54.todayState=\(state)"])
            let free = app.buttons["trainingHome.freeTraining"]
            XCTAssertTrue(free.waitForExistence(timeout: 15))
            free.tap()
            XCTAssertTrue(app.navigationBars["选择训练动作"].waitForExistence(timeout: 10))
            let add = app.buttons["添加中袋直线出杆"].firstMatch
            XCTAssertTrue(add.waitForExistence(timeout: 10))
            add.tap()
            XCTAssertTrue(app.buttons["完成(1)"].waitForExistence(timeout: 5))
            app.buttons["完成(1)"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["activeTraining.timer"].firstMatch.waitForExistence(timeout: 8))
            try capture("v57-\(state)-free-active")
            let end = app.buttons["activeTraining.end"]
            if end.exists && end.isHittable {
                end.tap()
            } else {
                app.buttons["activeTraining.more"].tap()
                app.buttons["结束训练"].tap()
            }
            XCTAssertTrue(app.alerts.buttons["结束"].waitForExistence(timeout: 5))
            app.alerts.buttons["结束"].tap()
            XCTAssertTrue(app.navigationBars["训练心得"].waitForExistence(timeout: 8))
            app.buttons["跳过"].tap()
            let save = app.buttons["保存训练"]
            XCTAssertTrue(save.waitForExistence(timeout: 8))
            if !save.isHittable { app.swipeUp() }
            save.tap()
            XCTAssertTrue(free.waitForExistence(timeout: 10))
            XCTAssertTrue(app.descendants(matching: .any)["trainingHome.todaySummary"].firstMatch.label.contains("全部完成"))
            try capture("v57-\(state)-saved-home")
            free.tap()
            XCTAssertTrue(app.navigationBars["选择训练动作"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["完成"].exists, "新一场训练应没有沿用上次选择")
            XCTAssertFalse(app.buttons["完成(1)"].exists)
            try capture("v57-\(state)-free-again")
        }
    }

    func testV57BrowseFiltersAndEmptyTemplateKeepPosition() throws {
        launch(["-v54.todayState=empty"])
        let official = app.buttons["官方计划"].firstMatch
        XCTAssertTrue(official.waitForExistence(timeout: 15))
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            .press(forDuration: 0.1, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        let headerY = official.frame.minY
        XCTAssertTrue(official.isHittable)
        for label in ["入门", "全部", "初级", "全部", "中级", "全部"] {
            let filter = app.buttons[label].firstMatch
            XCTAssertTrue(filter.isHittable)
            filter.tap()
            XCTAssertEqual(official.frame.minY, headerY, accuracy: 2, "切换 \(label) 后货架位置应保留")
            try capture("v57-filter-\(label)")
        }
        app.buttons["我的模版"].firstMatch.tap()
        XCTAssertTrue(app.buttons["新建模版"].waitForExistence(timeout: 5))
        XCTAssertEqual(official.frame.minY, headerY, accuracy: 2, "空模版页也必须容纳当前滚动位置")
        try capture("v57-empty-template-anchor")
        official.tap()
        XCTAssertEqual(official.frame.minY, headerY, accuracy: 2)
    }

    func testV57TemplateBodyEditsAndMenuAddsOnce() throws {
        for origin in ["trainingHome", "planList"] {
            launch(["-v54.todayState=templateOnly"])
            XCTAssertTrue(app.buttons["trainingHome.suggestion"].waitForExistence(timeout: 15))
            if origin == "trainingHome" {
                app.buttons["我的模版"].firstMatch.tap()
            } else {
                app.buttons["好友"].tap()
                XCTAssertTrue(app.navigationBars["训练计划"].waitForExistence(timeout: 8))
            }
            let body = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "\(origin).template.edit.")).firstMatch
            for _ in 0..<12 {
                if body.exists && body.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(body.isHittable)
            body.tap()
            XCTAssertTrue(app.navigationBars["编辑模版"].waitForExistence(timeout: 8))
            try capture("v57-\(origin)-template-edit")
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(body.waitForExistence(timeout: 8))
            let menu = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "\(origin).template.menu.")).firstMatch
            if !menu.isHittable { app.swipeUp() }
            XCTAssertTrue(menu.isHittable)
            menu.tap()
            let add = app.buttons["加入今日安排"].firstMatch
            XCTAssertTrue(add.waitForExistence(timeout: 5), "仅打开模版编辑不能把模版加入队列")
            add.tap()
            XCTAssertFalse(app.navigationBars["编辑模版"].exists, "菜单操作不能同时触发主体编辑")
            menu.tap()
            let already = app.buttons["已在今日安排"].firstMatch
            XCTAssertTrue(already.waitForExistence(timeout: 5))
            already.tap()
            if origin == "planList" { app.navigationBars.buttons.firstMatch.tap() }
            // Return to the top to inspect the persisted queue projection.
            for _ in 0..<6 {
                let title = app.staticTexts["trainingHome.todaySchedule"]
                if title.exists && title.isHittable { break }
                app.swipeDown()
            }
            let summary = app.descendants(matching: .any)["trainingHome.todaySummary"].firstMatch
            XCTAssertTrue(summary.waitForExistence(timeout: 8))
            XCTAssertTrue(summary.label.contains("0 / 1"), "重复菜单加入不能创建第二份课块：\(summary.label)")
            try capture("v57-\(origin)-template-added-once")
        }
    }

    func testV57PlanShelfShowsSavedStatesAndCanSwitch() throws {
        launch(["-v54.todayState=planStatuses"])
        let active = app.buttons["planPoster-plan_beginner"]
        let paused = app.buttons["planPoster-plan_accuracy"]
        XCTAssertTrue(active.waitForExistence(timeout: 15))
        for _ in 0..<6 {
            if active.isHittable && paused.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(active.label.contains("进行中"))
        XCTAssertTrue(paused.label.contains("已激活"))
        try capture("v57-plan-shelf-active-paused")
        paused.tap()
        let cta = app.buttons["planDetail.primaryCTA"]
        XCTAssertTrue(cta.waitForExistence(timeout: 8))
        XCTAssertEqual(cta.label, "切换到此计划")
        cta.tap()
        XCTAssertTrue(app.alerts.buttons["确定激活"].waitForExistence(timeout: 5))
        app.alerts.buttons["确定激活"].tap()
        expectation(for: NSPredicate(format: "label == %@", "编排今天"), evaluatedWith: cta)
        waitForExpectations(timeout: 10)
        app.navigationBars.buttons.firstMatch.tap()
        for _ in 0..<6 {
            if active.exists && active.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(active.label.contains("已激活"))
        XCTAssertTrue(paused.label.contains("进行中"))
        let completed = app.buttons["planPoster-plan_force"]
        for _ in 0..<8 {
            if completed.exists && completed.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(completed.isHittable)
        XCTAssertTrue(completed.label.contains("已完成"))
        try capture("v57-plan-shelf-completed")
    }

    func testV57MinimizedFreeTrainingRestoresSelection() throws {
        launch(["-v54.todayState=freeCompleted"])
        let free = app.buttons["trainingHome.freeTraining"]
        XCTAssertTrue(free.waitForExistence(timeout: 15))
        free.tap()
        XCTAssertTrue(app.navigationBars["选择训练动作"].waitForExistence(timeout: 8))
        let add = app.buttons["添加中袋直线出杆"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.buttons["完成(1)"].waitForExistence(timeout: 5))
        app.buttons["完成(1)"].tap()
        let minimize = app.buttons["最小化训练"]
        XCTAssertTrue(minimize.waitForExistence(timeout: 8))
        minimize.tap()
        let resume = app.buttons["minimizedTraining.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 8))
        XCTAssertFalse(free.exists, "有最小化训练时应保留唯一的恢复入口")
        try capture("v57-minimized-home")
        resume.tap()
        XCTAssertTrue(minimize.waitForExistence(timeout: 8))
        XCTAssertFalse(app.navigationBars["选择训练动作"].exists)
        let addMore = app.buttons["添加训练动作"].firstMatch
        XCTAssertTrue(addMore.waitForExistence(timeout: 8))
        addMore.tap()
        XCTAssertTrue(app.buttons["完成(1)"].waitForExistence(timeout: 8), "恢复应保留原来的动作选择")
        try capture("v57-minimized-restored-selection")
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

    private func assertMultiItemDisclosureDoesNotStartTraining() throws {
        let start = app.buttons["开始这节课"].firstMatch
        XCTAssertFalse(start.exists, "多课时应默认折叠")

        let firstItem = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'trainingHome.scheduleItem.'")
        ).firstMatch
        XCTAssertTrue(firstItem.waitForExistence(timeout: 8))
        firstItem.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5), "轻点课时应展开详细内容")
        XCTAssertFalse(app.descendants(matching: .any)["activeTraining.timer"].exists, "展开课时不应直接开始训练")
        firstItem.tap()
        XCTAssertTrue(start.waitForNonExistence(timeout: 5), "再次轻点应折叠详细内容")
    }

    private func launch(_ args: [String]) {
        app?.terminate()
        let appearance = (ProcessInfo.processInfo.environment["V54_APPEARANCE"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_V54_APPEARANCE"]) == "dark"
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


/// Verifies complete card visibility and the initially low shelf anchor.
/// These cover geometry not established by partial-card isHittable assertions.
final class V57HomeSupplementUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCompletedBadgeAndLastPlanAreFullyReachable() throws {
        launch("planStatuses")
        let completed = app.buttons["planPoster-plan_force"]
        try revealCompleteCard(completed)
        XCTAssertTrue(completed.label.contains("已完成"))
        capture("v57-completed-full-card")

        let lastPlan = app.buttons["planPoster-plan_fullskill"]
        try revealCompleteCard(lastPlan)
        XCTAssertFalse(lastPlan.frame.intersects(primaryAction.frame),
                       "滚动到底部时，最后卡片必须能完全避开悬浮按钮")
        capture("v57-last-plan-above-primary")
        lastPlan.tap()
        XCTAssertTrue(app.buttons["planDetail.primaryCTA"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(lastPlan.waitForExistence(timeout: 10))
        XCTAssertTrue(lastPlan.isHittable, "详情返回后末尾卡片仍应可达")
        capture("v57-last-plan-return")
    }

    func testLowShelfFilterAndEmptyTemplateKeepAnchor() throws {
        launch("empty")
        let official = app.buttons["官方计划"].firstMatch
        let beginner = app.buttons["filterChip_入门"].firstMatch
        XCTAssertTrue(official.waitForExistence(timeout: 15))
        let templates = app.buttons["我的模版"].firstMatch
        let controls = [official, beginner, templates]
        // Establish the anchor only after every control is exposed. XCTest
        // otherwise scrolls an obscured tab into view before delivering its tap.
        func controlsAreExposed() -> Bool {
            controls.allSatisfy {
                $0.exists && $0.isHittable
                    && $0.frame.maxY <= primaryAction.frame.minY
            }
        }
        for _ in 0..<10 {
            if controlsAreExposed() { break }
            dragContent(upBy: app.windows.firstMatch.frame.height * 0.12)
        }
        XCTAssertTrue(controlsAreExposed(), "先露出所有操作控件，再记录筛选锚点")
        let y = official.frame.minY
        capture("v57-low-shelf-before")
        beginner.tap()
        XCTAssertEqual(official.frame.minY, y, accuracy: 2)
        capture("v57-low-shelf-few")
        app.buttons["filterChip_全部"].firstMatch.tap()
        XCTAssertEqual(official.frame.minY, y, accuracy: 2)
        capture("v57-low-shelf-many")
        app.buttons["我的模版"].firstMatch.tap()
        XCTAssertTrue(app.buttons["新建模版"].waitForExistence(timeout: 5))
        XCTAssertEqual(official.frame.minY, y, accuracy: 2)
        capture("v57-low-shelf-empty")
        official.tap()
        XCTAssertEqual(official.frame.minY, y, accuracy: 2)
    }

    private var primaryAction: XCUIElement {
        let free = app.buttons["trainingHome.freeTraining"]
        return free.exists ? free : app.buttons["trainingHome.startTraining"]
    }

    private func revealCompleteCard(_ card: XCUIElement) throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 15))
        let top = app.buttons["trainingHome.moreMenu"].frame.maxY
        let bottom = primaryAction.frame.minY
        let available = CGRect(x: window.frame.minX, y: top,
                               width: window.frame.width, height: bottom - top)
        XCTAssertGreaterThan(available.height, 0)
        for _ in 0..<16 {
            if card.exists {
                let frame = card.frame
                if frame.minY >= available.minY && frame.maxY <= available.maxY {
                    XCTAssertTrue(card.isHittable)
                    return
                }
                let distance = frame.midY - available.midY
                let bound = available.height / 3
                dragContent(upBy: min(bound, max(-bound, distance)))
            } else {
                dragContent(upBy: available.height / 3)
            }
        }
        XCTFail("无法完整显示卡片：\(card.identifier)，frame=\(card.frame)，可用范围=\(available)")
    }

    private func dragContent(upBy distance: CGFloat) {
        let window = app.windows.firstMatch
        let frame = window.frame
        let startY = frame.midY + distance / 2
        let endY = frame.midY - distance / 2
        window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.width / 2, dy: startY - frame.minY))
            .press(forDuration: 0.1, thenDragTo:
                window.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: frame.width / 2, dy: endY - frame.minY)))
    }

    private func launch(_ fixture: String) {
        let dark = (ProcessInfo.processInfo.environment["TEST_RUNNER_V54_APPEARANCE"]
            ?? ProcessInfo.processInfo.environment["V54_APPEARANCE"]) == "dark"
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", dark ? "-v54.forceDark" : "-v54.forceLight",
            "-v54.todayState=\(fixture)",
        ])
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

final class V57PlanDetailUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws { continueAfterFailure = false }

    func testSingleFormationOpensAndReturnsToSameLesson() {
        launch("plan_beginner")
        let day = app.staticTexts["planLessonDay-plan_beginner.stage01.lesson01"]
        reveal(day)
        XCTAssertEqual(day.label, "第 1 天")
        XCTAssertEqual(app.staticTexts["planLessonTitle-plan_beginner.stage01.lesson01"].label,
                       "中底袋直线出杆")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "围绕")).firstMatch.exists)
        let row = app.buttons["planDrillRow-drill_c012"].firstMatch
        reveal(row)
        let y = row.frame.minY
        capture("v57-plan-single-before")
        row.tap()
        XCTAssertTrue(app.buttons["addToTrainingButton"].waitForExistence(timeout: 15))
        capture("v57-plan-single-detail")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.frame.minY, y, accuracy: 2)
        capture("v57-plan-single-return")
    }

    func testMultiFormationKeepsCollapsedDoseAfterDetailReturn() {
        launch("plan_separation")
        let toggle = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@",
            "planDrillDoseToggle-", "drill_c026")).firstMatch
        reveal(toggle)
        XCTAssertEqual(toggle.value as? String, "已展开")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "已收起")
        let row = app.buttons["planDrillRow-drill_c026"].firstMatch
        reveal(row)
        let y = row.frame.minY
        capture("v57-plan-multi-collapsed")
        row.tap()
        XCTAssertTrue(app.buttons["addToTrainingButton"].waitForExistence(timeout: 15))
        capture("v57-plan-multi-detail")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "已收起")
        XCTAssertEqual(row.frame.minY, y, accuracy: 2)
        capture("v57-plan-multi-return")
    }

    func testStageDaysAndCollapsedStagesSurviveReturn() {
        launch("plan_beginner")
        for ordinal in 1...3 {
            let stageID = String(format: "plan_beginner.stage%02d", ordinal)
            let firstDay = app.staticTexts["planLessonDay-\(stageID).lesson01"]
            reveal(firstDay)
            XCTAssertEqual(firstDay.label, "第 1 天")
            let lastDay = app.staticTexts["planLessonDay-\(stageID).lesson03"]
            XCTAssertEqual(lastDay.label, "第 3 天")
            capture("v57-plan-stage-\(ordinal)")
            if ordinal < 3 {
                let stage = app.buttons["planStage-\(stageID)"]
                // The header is just above the first lesson; reveal it with a
                // small downward drag if it has moved above the viewport.
                if !stage.isHittable {
                    app.swipeDown()
                }
                stage.tap()
                XCTAssertEqual(stage.value as? String, "已收起")
            }
        }
        let row = app.buttons["planDrillRow-drill_c001"].firstMatch
        reveal(row)
        row.tap()
        XCTAssertTrue(app.buttons["addToTrainingButton"].waitForExistence(timeout: 15))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["planDetail.primaryCTA"].waitForExistence(timeout: 10))
        for ordinal in 1...2 {
            let id = String(format: "planStage-plan_beginner.stage%02d", ordinal)
            XCTAssertEqual(app.buttons[id].value as? String, "已收起")
        }
        capture("v57-plan-stages-return")
    }

    func testLockedDrillReturnsToPlanWithoutUnlocking() {
        launch("plan_accuracy3", premium: false)
        let row = app.buttons["planDrillRow-drill_c076"].firstMatch
        reveal(row)
        row.tap()
        XCTAssertTrue(app.buttons["unlockProButton"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["addToTrainingButton"].exists)
        capture("v57-plan-locked-detail")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        capture("v57-plan-locked-return")
    }

    func testUnavailableDrillShowsMessageAndReturnsToPlan() {
        launch("plan_beginner", extra: ["-v57.missingPlanDrill"])
        let row = app.buttons["planDrillRow-v57-missing-drill"].firstMatch
        reveal(row)
        XCTAssertTrue(row.label.contains("动作暂不可用"))
        row.tap()
        XCTAssertTrue(app.staticTexts["动作暂不可用"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["addToTrainingButton"].exists)
        capture("v57-plan-unavailable-detail")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        capture("v57-plan-unavailable-return")
    }

    private var planAction: XCUIElement {
        let standard = app.buttons["planDetail.primaryCTA"]
        return standard.exists ? standard : app.buttons["解锁此计划"]
    }

    private func reveal(_ element: XCUIElement) {
        let window = app.windows.firstMatch
        for _ in 0..<24 {
            let bar = app.navigationBars.firstMatch
            let top = bar.exists ? bar.frame.maxY : window.frame.minY
            let bottom = planAction.frame.minY
            if element.exists && element.isHittable
                && element.frame.minY >= top && element.frame.maxY <= bottom { return }
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.1, thenDragTo:
                    window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        XCTFail("无法露出目标：\(element.identifier)，\(element.frame)")
    }

    private func launch(_ plan: String, premium: Bool = true, extra: [String] = []) {
        let dark = (ProcessInfo.processInfo.environment["V54_APPEARANCE"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_V54_APPEARANCE"]) == "dark"
        app = XCUIApplication.launchClean(extraArgs: [
            premium ? "-forcePremium" : "-forceNonPremium", "-v50.inMemoryStore", dark ? "-v54.forceDark" : "-v54.forceLight",
            "-deeplink.planDetail=\(plan)",
        ] + extra)
        XCTAssertTrue(app.staticTexts["planLessonDay-\(plan).stage01.lesson01"].waitForExistence(timeout: 15))
        XCTAssertTrue(planAction.exists)
    }

    private func capture(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        item.name = name
        item.lifetime = .keepAlways
        add(item)
    }
}

final class V57PracticeLibraryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testSavedEntriesRefreshLibraryWithoutChangingDrillIDSet() {
        launch()
        let search = app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("厚球分离角控制")
        let card = app.buttons["drillCard_drill_c026"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        assertCount(0, card: card)
        capture("v57-count-zero")
        app.buttons["v57.saveEntry"].tap()
        assertCount(1, card: card)
        capture("v57-count-one")
        app.buttons["v57.saveEntry"].tap()
        assertCount(2, card: card)
        capture("v57-count-two")
        app.buttons["v57.deleteEntry"].tap()
        assertCount(1, card: card)
        app.buttons["v57.deleteEntry"].tap()
        assertCount(0, card: card)
        XCTAssertFalse(app.staticTexts["v57.fixtureError"].exists)
        capture("v57-count-deleted")
    }

    func testFilterMenuHasNoCompletedOption() {
        launch()
        let menu = app.buttons["badgeFilterMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.tap()
        XCTAssertTrue(app.staticTexts["精讲类型"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["已完成"].exists)
        capture("v57-count-filter-menu")
    }

    func testThousandSavedEntriesExposeTheFullCount() {
        launch(extra: ["-v57.practiceCount=1000"])
        let search = app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("厚球分离角控制")
        let card = app.buttons["drillCard_drill_c026"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        assertCount(1000, card: card)
        XCTAssertFalse(app.staticTexts["v57.fixtureError"].exists)
        capture("v57-count-thousand")
    }

    func testPrimaryAddActionUsesTodaySheetAndDoesNotCountAsPractice() {
        launch()
        let search = app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("厚球分离角控制")
        let card = app.buttons["drillCard_drill_c026"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()
        let add = app.buttons["addToTrainingButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        capture("v57-count-primary-add")
        add.tap()
        let today = app.buttons["addToTodayTrainingRow"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        capture("v57-count-add-sheet")
        today.tap()
        XCTAssertTrue(app.staticTexts["已加入今日安排"].waitForExistence(timeout: 5))
        // A second service call must see the previously persisted queue item.
        add.tap()
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        XCTAssertTrue(app.staticTexts["已在今日安排"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        assertCount(0, card: card)
        capture("v57-count-queued-not-practiced")
    }

    private func assertCount(_ count: Int, card: XCUIElement) {
        let label = "已练 \(count) 次"
        let labels = [label, "已练 \(count.formatted(.number)) 次"]
        let predicate = NSPredicate { _, _ in
            if count == 0 {
                return !card.label.contains("已练")
                    && !card.descendants(matching: .any)
                        .matching(identifier: "drillCardPracticedBadge").firstMatch.exists
            }
            return labels.contains(where: { card.label.contains($0) })
                || card.descendants(matching: .any)
                    .matching(NSPredicate(format: "label IN %@", labels)).firstMatch.exists
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)],
                                     timeout: 5), .completed, "动作卡应展示完整次数 \(count)")
    }

    private func launch(extra: [String] = []) {
        let env = ProcessInfo.processInfo.environment
        let dark = (env["V54_APPEARANCE"] ?? env["TEST_RUNNER_V54_APPEARANCE"]) == "dark"
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v57.practiceCountFixture",
            dark ? "-v54.forceDark" : "-v54.forceLight",
        ] + extra)
    }

    private func capture(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        item.name = name
        item.lifetime = .keepAlways
        add(item)
    }
}
