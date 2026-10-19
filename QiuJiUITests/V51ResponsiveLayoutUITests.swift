import XCTest
import UIKit

/// v51 紧凑手机布局阻断测试。截图与 frame JSON 写入矩阵执行器提供的隔离目录。
final class V51ResponsiveLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFloatingTrainingDragDocksAndSurvivesTabsAndResume() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance",
            "-v51.minimizedTraining", "-v51.elapsedSeconds=360006",
        ])
        let pill = app.buttons["minimizedTraining.resume"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        let original = pill.frame
        try capture("drag-training-before", elements: ["pill": pill])
        dragPill(pill, to: CGVector(dx: 0.25, dy: 0.45))
        XCTAssertTrue(pill.exists, "拖动不能误触返回训练")
        XCTAssertLessThan(pill.frame.midY, original.midY - 80)
        assertPillDocked(pill)
        let movedY = pill.frame.midY
        try capture("drag-training-docked", elements: ["pill": pill])
        for tab in XCUIApplication.Tab.allCases {
            tabElement(tab).tap()
            XCTAssertTrue(pill.exists)
            XCTAssertEqual(pill.frame.midY, movedY, accuracy: 2)
            assertPillDocked(pill)
        }
        // Scroll from outside the pill; the full-window overlay must not intercept.
        let settings = app.buttons["设置"].firstMatch
        XCTAssertTrue(settings.exists)
        let beforeScroll = settings.frame.minY
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.35)))
        XCTAssertLessThan(settings.frame.minY, beforeScroll - 20)
        XCTAssertEqual(pill.frame.midY, movedY, accuracy: 2)
        try capture("drag-training-scroll", elements: ["pill": pill, "settings": settings])
        pill.tap()
        let minimize = app.buttons["最小化训练"].firstMatch
        XCTAssertTrue(minimize.waitForExistence(timeout: 8))
        let timer = app.descendants(matching: .any)["activeTraining.timer"].firstMatch
        XCTAssertTrue(timer.label.contains("100:00:"))
        minimize.tap()
        XCTAssertTrue(pill.waitForExistence(timeout: 8))
        XCTAssertEqual(pill.frame.midY, movedY, accuracy: 2)
        try capture("drag-training-reminimized", elements: ["pill": pill])
    }

    func testRestPillDragKeepsTapAndRespectsTopAndBottomBars() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance",
            "-v51.activeTraining", "-v57.restDuration=180",
        ])
        let rest = app.buttons["activeTraining.rest"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 15))
        rest.tap()
        let minimizeRest = app.buttons["最小化组间休息"].firstMatch
        XCTAssertTrue(minimizeRest.waitForExistence(timeout: 8))
        minimizeRest.tap()
        let pill = app.buttons["activeTraining.restPill"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 8))
        try capture("drag-rest-before", elements: ["pill": pill])
        let originalY = pill.frame.midY
        dragPill(pill, to: CGVector(dx: 0.25, dy: 0.45))
        XCTAssertTrue(pill.exists, "拖动不能误触展开休息卡")
        XCTAssertFalse(minimizeRest.exists)
        assertPillDocked(pill)
        XCTAssertLessThan(pill.frame.midY, originalY - 60)
        let movedY = pill.frame.midY
        try capture("drag-rest-docked", elements: ["pill": pill])
        pill.tap()
        XCTAssertTrue(minimizeRest.waitForExistence(timeout: 5))
        minimizeRest.tap()
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        XCTAssertEqual(pill.frame.midY, movedY, accuracy: 2)
        dragPill(pill, to: CGVector(dx: 0.6, dy: 0.07))
        let title = app.staticTexts["activeTraining.title"].firstMatch
        XCTAssertGreaterThan(pill.frame.minY, title.frame.maxY + 12)
        assertPillDocked(pill)
        try capture("drag-rest-top-limit", elements: ["pill": pill, "title": title])
        dragPill(pill, to: CGVector(dx: 0.6, dy: 0.96))
        let minimizeTraining = app.buttons["最小化训练"].firstMatch
        XCTAssertLessThan(pill.frame.maxY, minimizeTraining.frame.minY)
        assertPillDocked(pill)
        try capture("drag-rest-bottom-limit", elements: ["pill": pill, "minimize": minimizeTraining])
    }

    func testHomeTrainingEntryRemainsFixedAfterDrag() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-v54.todayState=empty",
        ])
        let pill = app.buttons["trainingHome.freeTraining"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        let before = pill.frame
        dragPill(pill, to: CGVector(dx: 0.25, dy: 0.4))
        XCTAssertTrue(pill.exists)
        XCTAssertEqual(pill.frame.minX, before.minX, accuracy: 1)
        XCTAssertEqual(pill.frame.minY, before.minY, accuracy: 1)
        pill.tap()
        XCTAssertTrue(app.navigationBars["选择训练动作"].waitForExistence(timeout: 8))
    }

    func testFloatingTrainingAvoidsKeyboardAndRestoresHeight() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-v51.minimizedTraining",
        ])
        let pill = app.buttons["minimizedTraining.resume"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 15))
        tabElement(.drillLibrary).tap()
        dragPill(pill, to: CGVector(dx: 0.4, dy: 0.72))
        assertPillDocked(pill)
        let preferredY = pill.frame.midY
        let search = app.textFields["librarySearchField"].firstMatch
        XCTAssertTrue(search.exists)
        search.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        let clearOfKeyboard = NSPredicate { _, _ in
            pill.exists && pill.frame.maxY <= keyboard.frame.minY - 12
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: clearOfKeyboard, object: nil)], timeout: 4), .completed)
        assertPillDocked(pill)
        try capture("drag-training-keyboard", elements: ["pill": pill, "keyboard": keyboard])
        search.typeText("\n")
        let restored = NSPredicate { _, _ in
            !keyboard.exists && abs(pill.frame.midY - preferredY) < 2
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: restored, object: nil)], timeout: 5), .completed)
        try capture("drag-training-keyboard-dismissed", elements: ["pill": pill])
    }

    private func dragPill(_ pill: XCUIElement, to target: CGVector) {
        pill.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: target))
    }

    private func assertPillDocked(_ pill: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        // XCTest can finish the gesture while the spring is still returning right.
        let docked = NSPredicate { _, _ in
            pill.exists && abs(window.maxX - pill.frame.maxX - 12) < 1
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: docked, object: nil)], timeout: 3), .completed, file: file, line: line)
        XCTAssertTrue(window.contains(pill.frame), file: file, line: line)
        XCTAssertEqual(window.maxX - pill.frame.maxX, 12, accuracy: 1, file: file, line: line)
        XCTAssertEqual(pill.frame.height, 44, accuracy: 0.5, file: file, line: line)
    }

    func testTrainingNumericKeyboardHidesChromeAndKeepsScore() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.activeTraining", "-v49.forceLight",
        ])
        let switchView = app.buttons["切换到单项视图"]
        XCTAssertTrue(switchView.waitForExistence(timeout: 15))
        switchView.tap()
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "杆1,")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.19, dy: 0.5)).tap()
        let seven = app.buttons["setNumberKeyboard.1"]
        XCTAssertTrue(seven.waitForExistence(timeout: 5))
        seven.tap()
        app.buttons["setNumberKeyboard.2"].tap()
        XCTAssertFalse(app.buttons["最小化训练"].exists)
        let hide = app.buttons["setNumberKeyboard.完成"]
        XCTAssertEqual(hide.label, "收起键盘")
        XCTAssertTrue(hide.isHittable)
        XCTAssertGreaterThanOrEqual(hide.frame.height, 44)
        XCTAssertLessThanOrEqual(row.frame.maxY, seven.frame.minY)
        try capture("input-numeric", elements: ["row": row, "dismiss": hide])
        hide.tap()
        let rest = app.staticTexts["组间休息"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["setNumberKeyboard.完成"].exists)
        try capture("input-confirmed-rest", elements: ["rest": rest])
        app.buttons["最小化组间休息"].tap()
        XCTAssertTrue(row.label.contains("12/15"))
        XCTAssertFalse(app.staticTexts["1/5 组 1/1 项目"].exists)
        XCTAssertEqual(app.staticTexts["activeTrainingSetProgress"].label, "第 2/5 杆")
        try capture("input-confirmed-set", elements: ["row": row])

    }

    func testTrainingInputHidesChromeAndNoteReturnsToSession() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.activeTraining", "-v49.forceLight",
        ])
        let switchView = app.buttons["切换到单项视图"]
        XCTAssertTrue(switchView.waitForExistence(timeout: 15))
        switchView.tap()
        let note = app.textFields["drillNote.editor"].firstMatch
        let multilineNote = app.textViews["drillNote.editor"].firstMatch
        let editor = note.waitForExistence(timeout: 3) ? note : multilineNote
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        let originalHeight = editor.frame.height
        editor.typeText("steady stroke\nsecond line\nthird line\nfourth line\nfifth line\nsixth line")
        XCTAssertGreaterThan(editor.frame.height, originalHeight * 4)
        XCTAssertLessThan(editor.frame.height, 180, "Six standard-size lines must not inherit an unrelated AX font scale")
        XCTAssertEqual(editor.value as? String, "1. steady stroke\n2. second line\n3. third line\n4. fourth line\n5. fifth line\n6. sixth line")
        let hide = app.buttons["drillNote.dismissKeyboard"].firstMatch
        XCTAssertTrue(hide.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(hide.frame.width, 56)
        XCTAssertGreaterThanOrEqual(hide.frame.height, 44)
        XCTAssertFalse(app.buttons["最小化训练"].exists)
        XCTAssertLessThanOrEqual(editor.frame.maxY, app.keyboards.firstMatch.frame.minY)
        try capture("input-drill-note", elements: ["editor": editor, "dismiss": hide])
        hide.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["记录心得"].waitForExistence(timeout: 5))

        app.buttons["activeTraining.rest"].tap()
        let minimizeRest = app.buttons["最小化组间休息"].firstMatch
        XCTAssertTrue(minimizeRest.waitForExistence(timeout: 8))
        minimizeRest.tap()
        app.buttons["记录心得"].tap()
        let sessionEditor = app.textViews["trainingNote.editor"].firstMatch
        XCTAssertTrue(sessionEditor.waitForExistence(timeout: 5))
        sessionEditor.typeText("session reflection\nsecond point\n\nplain text")
        XCTAssertFalse(app.buttons["trainingNote.save"].exists)
        XCTAssertFalse(app.buttons["activeTraining.restPill"].exists)
        XCTAssertFalse(app.buttons["跳过"].exists)
        let sessionHide = app.buttons["trainingNote.dismissKeyboard"]
        XCTAssertTrue(sessionHide.exists)
        XCTAssertGreaterThanOrEqual(sessionHide.frame.width, 56)
        XCTAssertGreaterThanOrEqual(sessionHide.frame.height, 44)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(sessionEditor.frame.maxY, sessionHide.frame.minY)
        XCTAssertLessThanOrEqual(sessionHide.frame.maxY, app.keyboards.firstMatch.frame.minY)
        try capture("input-session-note", elements: ["editor": sessionEditor, "dismiss": sessionHide])
        sessionHide.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5)).tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let save = app.buttons["trainingNote.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isHittable)
        XCTAssertLessThanOrEqual(save.frame.width, 121)
        try capture("input-note-save", elements: ["save": save])
        save.tap()
        XCTAssertTrue(app.buttons["记录心得"].waitForExistence(timeout: 5))
        app.buttons["记录心得"].tap()
        XCTAssertTrue(sessionEditor.waitForExistence(timeout: 5))
        XCTAssertEqual(sessionEditor.value as? String, "1. session reflection\n2. second point\nplain text")
        sessionEditor.typeText(" discarded")
        app.buttons["trainingNote.returnToTraining"].tap()
        XCTAssertTrue(app.buttons["记录心得"].waitForExistence(timeout: 5))
        app.buttons["记录心得"].tap()
        XCTAssertTrue(sessionEditor.waitForExistence(timeout: 5))
        XCTAssertEqual(sessionEditor.value as? String, "1. session reflection\n2. second point\nplain text")
        app.buttons["trainingNote.returnToTraining"].tap()
        XCTAssertTrue(app.buttons["记录心得"].waitForExistence(timeout: 5))
        try capture("input-returned-training", elements: [:])
    }

    func testTrainingDrillSwipesPageAndReturnToOverview() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.activeTraining", "-v49.forceLight",
        ])
        let single = app.buttons["切换到单项视图"]
        XCTAssertTrue(single.waitForExistence(timeout: 15))
        app.buttons["添加训练动作"].firstMatch.tap()
        let add = app.buttons["添加中袋直线出杆"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let finish = app.buttons["完成(2)"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        XCTAssertTrue(single.waitForExistence(timeout: 5))
        single.tap()
        let note = app.descendants(matching: .any)["drillNote.editor"].firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["第 1 项，共 2 项"].exists)
        try capture("two-drills-brand-index", elements: [:])
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(app.staticTexts["第 2 项，共 2 项"].waitForExistence(timeout: 5))
        XCTAssertFalse(single.exists)
        try capture("left-swipe-second-drill", elements: [:])
        end.press(forDuration: 0.05, thenDragTo: start)
        XCTAssertTrue(app.staticTexts["第 1 项，共 2 项"].waitForExistence(timeout: 5))
        XCTAssertFalse(single.exists)
        try capture("right-swipe-first-drill", elements: [:])
        end.press(forDuration: 0.05, thenDragTo: start)
        XCTAssertTrue(single.waitForExistence(timeout: 5))
        try capture("first-drill-returned-list", elements: [:])
    }

    func testHomeTrainingPillsShareCompactHeightAndInsets() throws {
        for (state, title, identifier) in [
            ("single", "开始训练", "trainingHome.startTraining"),
            ("oneRemaining", "继续", "trainingHome.startTraining"),
            ("empty", "自由训练", "trainingHome.freeTraining"),
        ] {
            app = XCUIApplication.launchClean(extraArgs: [
                "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance", "-v54.todayState=\(state)",
            ])
            let pill = app.buttons[identifier].firstMatch
            XCTAssertTrue(pill.waitForExistence(timeout: 15))
            let tab = tabElement(.training)
            try capture("hud-home-\(state)", elements: ["pill": pill, "tab": tab])
            XCTAssertEqual(pill.label, title)
            // The standard tool capsule has a 44pt body plus a centered 1pt border in its AX frame.
            XCTAssertGreaterThanOrEqual(pill.frame.height, 44)
            XCTAssertLessThanOrEqual(pill.frame.height, 45)
            XCTAssertEqual(app.windows.firstMatch.frame.maxX - pill.frame.maxX, 12, accuracy: 1)
            XCTAssertLessThan(pill.frame.width, 130)
            XCTAssertFalse(pill.frame.intersects(tab.frame))
            pill.tap()
            if state == "empty" {
                XCTAssertTrue(app.navigationBars["选择训练动作"].waitForExistence(timeout: 12))
            } else {
                XCTAssertTrue(app.descendants(matching: .any)["activeTraining.timer"].firstMatch.waitForExistence(timeout: 12))
            }
        }
    }

    func testTrainingPillAvoidsDetailActionsAndResetsAfterBack() throws {
        for destination in ["drill", "plan"] {
            app = XCUIApplication.launchClean(extraArgs: [
                "-forcePremium", "-v50.inMemoryStore", "-v51.minimizedTraining",
                "-v51.elapsedSeconds=125", "-hud.destination=\(destination)",
            ])
            let pill = app.buttons["minimizedTraining.resume"].firstMatch
            let action = app.buttons[destination == "drill" ? "bottomTryoutButton" : "planDetail.primaryCTA"].firstMatch
            XCTAssertTrue(action.waitForExistence(timeout: 20))
            XCTAssertTrue(pill.waitForExistence(timeout: 5))
            XCTAssertEqual(pill.frame.height, 44, accuracy: 0.5)
            XCTAssertEqual(app.windows.firstMatch.frame.maxX - pill.frame.maxX, 12, accuracy: 1)
            XCTAssertGreaterThanOrEqual(action.frame.minY - pill.frame.maxY, 11.5)
            XCTAssertFalse(action.frame.intersects(pill.frame))
            XCTAssertTrue(action.isHittable)
            try capture("hud-\(destination)-actions", elements: ["pill": pill, "action": action])
            if destination == "drill" {
                action.tap()
                XCTAssertTrue(action.waitForNonExistence(timeout: 8), "上手试打应真正打开目标页")
                app.navigationBars.buttons.firstMatch.tap()
                XCTAssertTrue(action.waitForExistence(timeout: 10))
            }
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(tabElement(.training).waitForExistence(timeout: 10))
            let tab = tabElement(.training)
            for item in XCUIApplication.Tab.allCases {
                let button = tabElement(item)
                XCTAssertTrue(button.exists)
                XCTAssertFalse(pill.frame.intersects(button.frame), "返回后不得遮挡 \(item.rawValue)")
            }
            XCTAssertLessThanOrEqual(pill.frame.maxY, tab.frame.minY - 11.5)
            XCTAssertGreaterThan(pill.frame.minY, app.windows.firstMatch.frame.midY)
            try capture("hud-\(destination)-returned", elements: ["pill": pill, "tab": tab])
            pill.tap()
            XCTAssertTrue(app.descendants(matching: .any)["activeTraining.timer"].firstMatch.waitForExistence(timeout: 10))
        }
    }

    func testStartTimerOpensDrillFromOverview() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.activeTraining",
        ])
        let toggle = app.buttons["activeTraining.timerToggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 20))
        let overviewSwitch = app.buttons["切换到单项视图"].firstMatch
        XCTAssertTrue(overviewSwitch.exists)
        // The plan fixture starts its timer automatically; pause before testing play.
        XCTAssertEqual(toggle.label, "暂停计时")
        toggle.tap()
        XCTAssertTrue(overviewSwitch.exists, "暂停应保留当前总览")
        try capture("start-paused-overview", elements: [:])
        toggle.tap()
        XCTAssertTrue(app.buttons["切换到总览视图"].waitForExistence(timeout: 5), "开始应自动进入动作训练")
        XCTAssertEqual(toggle.label, "暂停计时")
        try capture("start-opened-drill", elements: [:])
        toggle.tap()
        XCTAssertTrue(app.buttons["切换到总览视图"].exists, "暂停不应退出动作训练")
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
        let expandRest = app.buttons["activeTraining.restPill"].firstMatch
        XCTAssertTrue(expandRest.waitForExistence(timeout: 8))
        XCTAssertEqual(expandRest.frame.height, 44, accuracy: 0.5)
        XCTAssertFalse(app.buttons["minimizedTraining.resume"].exists, "休息卡最小化不能变成跨 Tab 会话浮标")
        XCTAssertTrue(app.descendants(matching: .any)["activeTraining.timer"].firstMatch.exists)
        try capture("active-training-rest-minimized", elements: ["expandRest": expandRest])
    }

    func testV57LongRestDurationsStartWithoutAddingTime() throws {
        for duration in [120, 180] {
            app = XCUIApplication.launchClean(extraArgs: [
                "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance",
                "-v51.activeTraining", "-v57.restDuration=\(duration)",
            ])
            let rest = app.buttons["activeTraining.rest"].firstMatch
            XCTAssertTrue(rest.waitForExistence(timeout: 15))
            rest.tap()
            XCTAssertTrue(app.staticTexts["组间休息"].firstMatch.waitForExistence(timeout: 8))
            let seconds = try XCTUnwrap(Int(rest.label.filter(\.isNumber)))
            XCTAssertGreaterThan(seconds, 60, "Diagnostic entry must start a long rest directly")
            XCTAssertLessThanOrEqual(seconds, duration)
            try capture("v57-rest-\(duration)", elements: ["rest": rest])
            app.buttons["完成休息"].firstMatch.tap()
            XCTAssertTrue(rest.waitForExistence(timeout: 5))
            XCTAssertEqual(rest.label, "休息设置")
            app.terminate()
        }
    }

    func testEndingTrainingDismissesSystemRestActivity() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance",
            "-v54.todayState=single", "-v57.restDuration=180",
        ])
        let start = app.buttons["trainingHome.startTraining"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()
        let rest = app.buttons["activeTraining.rest"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 15))
        rest.tap()
        let minimize = app.buttons["最小化组间休息"].firstMatch
        XCTAssertTrue(minimize.waitForExistence(timeout: 8))
        minimize.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        func openNotifications() {
            XCUIDevice.shared.press(.home)
            XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.005))
                .press(forDuration: 0.1, thenDragTo: springboard.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.08, dy: 0.8)
                ))
        }
        openNotifications()
        let alwaysAllow = springboard.buttons["始终允许"].firstMatch
        let allow = springboard.buttons["允许"].firstMatch
        if alwaysAllow.waitForExistence(timeout: 2) {
            alwaysAllow.tap()
        } else if allow.waitForExistence(timeout: 2) {
            allow.tap()
        }
        let systemRest = springboard.staticTexts["组间休息"].firstMatch
        XCTAssertTrue(systemRest.waitForExistence(timeout: 5))
        try capture("training-end-system-before", elements: [:])

        app.activate()
        let end = app.buttons["activeTraining.end"].firstMatch
        XCTAssertTrue(end.waitForExistence(timeout: 10))
        end.tap()
        let confirm = app.alerts.buttons["结束"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["训练心得"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["activeTraining.restPill"].exists)
        try capture("training-end-note", elements: [:])

        openNotifications()
        XCTAssertTrue(systemRest.waitForNonExistence(timeout: 8), "Ended training must dismiss the system rest activity")
        try capture("training-end-system-after", elements: [:])
        XCUIDevice.shared.press(.home)
        let homeReady = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                springboard.icons.allElementsBoundByIndex.contains { $0.isHittable }
            }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [homeReady], timeout: 8), .completed)
        try capture("training-end-island-after", elements: [:])
        app.activate()
    }

    func testRestSystemSurfaceDeviceMatrix() throws {
        let phone = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        try runRestSystemSurface(hasIsland: phone.frame.height > 700, prefix: "legacy")
    }

    func testRestStyleIslandLightDark() throws {
        try runRestStyleMatrix(hasIsland: true, orientations: [.portrait])
    }

    func testRestStyleCardLightDark() throws {
        try runRestStyleMatrix(hasIsland: false, orientations: [.portrait])
    }

    func testRestStylePadLightDarkBothOrientations() throws {
        try runRestStyleMatrix(hasIsland: false, orientations: [.portrait, .landscapeLeft])
    }

    private func runRestStyleMatrix(hasIsland: Bool, orientations: [UIDeviceOrientation]) throws {
        let originalAppearance = XCUIDevice.shared.appearance
        let originalOrientation = XCUIDevice.shared.orientation
        defer {
            XCUIDevice.shared.appearance = originalAppearance
            XCUIDevice.shared.orientation = originalOrientation
        }
        for appearance: XCUIDevice.Appearance in [.light, .dark] {
            XCUIDevice.shared.appearance = appearance
            XCTAssertEqual(XCUIDevice.shared.appearance, appearance)
            for orientation in orientations {
                XCUIDevice.shared.orientation = orientation
                let prefix = "\(appearance == .light ? "light" : "dark")-\(orientation == .portrait ? "portrait" : "landscape")"
                try runRestSystemSurface(hasIsland: hasIsland, prefix: prefix)
            }
        }
    }

    private func runRestSystemSurface(hasIsland: Bool, prefix: String) throws {
        func captureRest(_ name: String) throws {
            try capture(prefix + "-" + name, elements: [:])
        }
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance",
            "-v54.todayState=single",
        ])
        let start = app.buttons["trainingHome.startTraining"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()
        let rest = app.buttons["activeTraining.rest"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 15))
        rest.tap()
        let minimize = app.buttons["最小化组间休息"].firstMatch
        XCTAssertTrue(minimize.waitForExistence(timeout: 8))
        let extend = app.buttons["+30S"].firstMatch
        XCTAssertTrue(extend.exists)
        for _ in 0..<4 { extend.tap() }
        minimize.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        func openNotifications() {
            XCUIDevice.shared.press(.home)
            XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.005))
                .press(forDuration: 0.1, thenDragTo: springboard.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.08, dy: 0.8)
                ))
        }
        openNotifications()
        let alwaysAllow = springboard.buttons["始终允许"].firstMatch
        let allow = springboard.buttons["允许"].firstMatch
        if alwaysAllow.waitForExistence(timeout: 2) {
            alwaysAllow.tap()
        } else if allow.waitForExistence(timeout: 2) {
            allow.tap()
        }
        let systemRest = springboard.staticTexts["组间休息"].firstMatch
        XCTAssertTrue(systemRest.waitForExistence(timeout: 5))
        try captureRest("training-end-system-before")

        XCUIDevice.shared.press(.home)
        func waitForHome() {
            let ready = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in
                    springboard.icons.allElementsBoundByIndex.contains { $0.isHittable }
                }, object: nil
            )
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
        }
        waitForHome()
        try captureRest("training-end-island-compact-before")
        // The matrix selector declares the system surface; screen height cannot identify an island.
        if hasIsland {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.035))
                .press(forDuration: 1)
            XCTAssertTrue(systemRest.waitForExistence(timeout: 5), "Expanded island must show rest title")
            try captureRest("training-end-island-expanded-before")
        }

        app.activate()
        let timer = app.staticTexts["activeTraining.timer"].firstMatch
        XCTAssertTrue(timer.waitForExistence(timeout: 10))
        let end = app.buttons["activeTraining.end"].firstMatch
        if end.exists {
            end.tap()
        } else {
            let more = app.buttons["activeTraining.more"].firstMatch
            XCTAssertTrue(more.exists)
            more.tap()
            let menuEnd = app.buttons["结束训练"].firstMatch
            XCTAssertTrue(menuEnd.waitForExistence(timeout: 5))
            let menuReady = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "hittable == true"), object: menuEnd
            )
            XCTAssertEqual(XCTWaiter.wait(for: [menuReady], timeout: 5), .completed)
            // Use a deliberate touch on the resolved menu row. XCTest's default
            // 50ms tap intermittently leaves the iOS 26 native menu open on SE.
            menuEnd.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.15)
        }
        let confirm = app.alerts.buttons["结束"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["训练心得"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["activeTraining.restPill"].exists)
        try captureRest("training-end-note")

        openNotifications()
        XCTAssertTrue(systemRest.waitForNonExistence(timeout: 8), "Ended training must dismiss the system rest activity")
        try captureRest("training-end-system-after")
        XCUIDevice.shared.press(.home)
        let homeReady = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                springboard.icons.allElementsBoundByIndex.contains { $0.isHittable }
            }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [homeReady], timeout: 8), .completed)
        try captureRest("training-end-island-after")
        app.activate()
    }

    func testV57SystemRestActivityDisplay() throws {
        app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance",
            "-v51.activeTraining", "-v57.restDuration=180",
        ])
        let rest = app.buttons["activeTraining.rest"].firstMatch
        XCTAssertTrue(rest.waitForExistence(timeout: 15))
        rest.tap()
        XCTAssertTrue(app.staticTexts["组间休息"].firstMatch.waitForExistence(timeout: 8))
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.005))
            .press(forDuration: 0.1, thenDragTo: springboard.coordinate(
                withNormalizedOffset: CGVector(dx: 0.08, dy: 0.8)
            ))
        let allow = springboard.buttons["允许"].firstMatch
        let alwaysAllow = springboard.buttons["始终允许"].firstMatch
        if alwaysAllow.waitForExistence(timeout: 2) {
            alwaysAllow.tap()
        } else if allow.waitForExistence(timeout: 2) {
            allow.tap()
        }
        Thread.sleep(forTimeInterval: 2)
        try capture("rest-system-notifications-start", elements: [:])
        XCTAssertTrue(springboard.staticTexts["组间休息"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(springboard.staticTexts["半台直线球"].firstMatch.exists, "The drill metadata must remain visible")
        Thread.sleep(forTimeInterval: 40)
        try capture("rest-system-notifications-plus40s", elements: [:])
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        try capture("rest-system-compact", elements: [:])
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.035))
            .press(forDuration: 1)
        Thread.sleep(forTimeInterval: 2)
        try capture("rest-system-expanded", elements: [:])
        // These captures require image review; an App overlay does not prove a system surface.
        app.activate()
        let complete = app.buttons["完成休息"].firstMatch
        XCTAssertTrue(complete.waitForExistence(timeout: 10))
        complete.tap()
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
        XCTAssertLessThanOrEqual(resume.frame.width, 210.5, "浮标只应把 210pt 作为宽度上限")
        if elapsedSeconds < 60 {
            XCTAssertLessThan(resume.frame.width, 180, "短时长浮标应按内容收紧，不能留下大块空白")
        }
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

        var aimMode = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "瞄准模式：")
        ).firstMatch
        if !aimMode.waitForExistence(timeout: 20) {
            // iOS 17 CoreSimulator can drop a direct-route launch on the first
            // cold start. Relaunch once with the exact same arguments; the
            // route remains a hard failure if it is still unavailable.
            app.terminate()
            app.launch()
            aimMode = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "瞄准模式：")
            ).firstMatch
        }
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

        var status = app.descendants(matching: .any)["navStatus.subtitle"].firstMatch
        if !status.waitForExistence(timeout: 12) {
            app.terminate()
            app.launch()
            status = app.descendants(matching: .any)["navStatus.subtitle"].firstMatch
        }
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
