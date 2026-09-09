import XCTest

/// Unregistered/unrun snapshot004 candidate. Normal UI, guest, in-memory model store.
/// Does not start training, delete a template, seed a queue, or prove disk persistence.
final class TodayQueueDiagnosticUITests: XCTestCase {
    private var app: XCUIApplication?
    private var output: URL!
    private let token = UUID().uuidString
    private var shotNumber = 0
    private let official = "plan_beginner.stage01.lesson01"
    private let library = "drill_c012"
    private let rowPrefix = "trainingHome.scheduleItem."
    private enum Failure: Error { case requirement(String) }

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        defer { app?.terminate() }
        if app != nil { try capture("terminal-unclassified") }
    }

    func testThreeSourcesDeduplicateMoveAndDeleteOnlyPendingLibraryItem() throws {
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_TODAY_QUEUE_AUTH") == "DEDICATED_GUEST_SIMULATOR", "Dedicated diagnostic simulator authorization required")
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/") else { throw Failure.requirement("Absolute QD_SHOT_DIR required") }
        output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let application = XCUIApplication()
        application.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-hasCompletedOnboarding", "YES", "-v50.inMemoryStore", "-forceNonPremium", "-v51.followSystemAppearance"]
        app = application
        application.launch()
        try require(application.wait(for: .runningForeground, timeout: 15), "App must reach foreground")
        try tab("我的")
        try exists(application.buttons["profile.login"])
        try tab("记录")
        try exists(application.staticTexts["还没有训练记录"])
        try tab("训练")
        try assertQueue([])
        try homeReveal(application.buttons["我的模版"], upward: true)
        try tap(application.buttons["我的模版"])
        try require(templateCards.count == 0, "Initial template shelf must be empty; never delete existing templates")
        try capture("guest-empty-queue-template-shelf")

        try addOfficial(firstActivation: true)
        try assertQueue([official])
        try addOfficial(firstActivation: false)
        try assertQueue([official])
        try capture("official-repeated-one-source")

        let title = "队列诊断" + String(token.prefix(8))
        let template = try createTemplateAndAdd(title: title)
        try assertQueue([official, template])
        try homeReveal(application.buttons["我的模版"], upward: true)
        try tap(application.buttons["我的模版"])
        let templateMenu = application.buttons["trainingHome.template.menu." + template]
        try homeReveal(templateMenu, upward: true)
        try tap(templateMenu)
        try tapUniqueLabel("已在今日安排")
        // This duplicate is stopped by the normal UI guard, not another service write.
        try assertQueue([official, template])
        try capture("template-repeat-keeps-two-sources")

        try addLibraryTwice()
        try tab("训练")
        try assertQueue([official, template, library])
        try assertOrder([official, template, library])
        try capture("three-source-pending-order-A-T-L")

        try openQueueMenu(sourceID: template, label: "管理" + title)
        try tapUniqueLabel("上移")
        try assertOrder([template, official, library])
        try capture("template-moved-up-T-A-L")
        try openQueueMenu(sourceID: template, label: "管理" + title)
        let up = try uniqueButton(label: "上移")
        try require(!up.isEnabled, "First pending item must not move further up")
        try tapUniqueLabel("下移")
        try assertOrder([official, template, library])
        try capture("template-moved-down-A-T-L")

        try openQueueMenu(sourceID: library, label: "管理中袋直线出杆")
        try tapUniqueLabel("删除")
        try disappears(row(library))
        try assertQueue([official, template])
        try assertOrder([official, template])
        try capture("only-library-pending-item-deleted")
        try tab("记录")
        try exists(application.staticTexts["还没有训练记录"])
        try tab("训练")
        try assertQueue([official, template])
        try assertOrder([official, template])
        try homeReveal(application.buttons["我的模版"], upward: true)
        try tap(application.buttons["我的模版"])
        try require(templateCards.matching(identifier: "trainingHome.template.edit." + template).count == 1,
                    "Deleting the pending library item must preserve the newly created template source")
        try openLibraryDetail()
        try exists(application.buttons["addToTrainingButton"])
        try assertLibraryDetail()
        try tabAfterLibraryBack()
        try assertQueue([official, template])
        try capture("verified-final-two-pending-no-history-source-preserved")
        print("[QD-TodayQueue] verified A=\(official) T=\(template) L=\(library); added/repeated/moved; deleted only L pending item; in-memory same process")
    }

    private var application: XCUIApplication { get throws { guard let app else { throw Failure.requirement("App not initialized") }; return app } }
    private var templateCards: XCUIElementQuery {
        app!.buttons.matching(NSPredicate(format: "identifier MATCHES %@", "trainingHome[.]template[.]edit[.][A-Fa-f0-9-]{36}"))
    }
    private var queueCards: XCUIElementQuery {
        app!.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND NOT identifier ENDSWITH %@ AND NOT identifier ENDSWITH %@",
            rowPrefix, ".start", ".detail"))
    }
    private func row(_ source: String) -> XCUIElement { app!.buttons[rowPrefix + source] }

    private func addOfficial(firstActivation: Bool) throws {
        let app = try application
        let officialTab = app.buttons["官方计划"]
        try homeReveal(officialTab, upward: true)
        try tap(officialTab)
        let poster = app.buttons["planPoster-plan_beginner"]
        try homeReveal(poster, upward: true)
        try tap(poster)
        let primary = app.buttons["planDetail.primaryCTA"]
        try exists(primary)
        if firstActivation {
            try require(primary.label == "开始此计划", "A fresh official plan must not already be active")
            try tap(primary)
            try tap(app.alerts.buttons["确定激活"])
        }
        try until("Official plan must offer arrangement") { primary.exists && primary.label == "编排今天" }
        try tap(primary)
        try exists(app.navigationBars["编排今天"])
        let selection = app.buttons.matching(NSPredicate(format: "label == %@", "中底袋直线出杆，当前，已选择"))
        try until("Exactly the actual first lesson must be selected") { selection.count == 1 }
        let summary = app.descendants(matching: .any).matching(identifier: "planDetail.arrangementSummary").firstMatch
        try exists(summary)
        try require(summary.label.replacingOccurrences(of: " ", with: "").contains("将加入1项"), "One lesson source selected, not two action rows")
        try tap(app.buttons["planDetail.addToToday"])
        try disappears(app.navigationBars["编排今天"])
        try back()
        try homeReveal(row(official), upward: false)
    }

    private func createTemplateAndAdd(title: String) throws -> String {
        let app = try application
        try homeReveal(app.buttons["我的模版"], upward: true)
        try tap(app.buttons["我的模版"])
        let create = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "新建模版", "list.bullet.clipboard"))
        try until("New-template action must be unique; reject decorative duplicate") { create.count == 1 }
        try homeReveal(create.firstMatch, upward: true)
        try tap(create.firstMatch)
        let name = app.textFields["customPlanNameField"]
        try tap(name)
        try require((name.value as? String) == "我的模版" || (name.value as? String) == "", "New builder must have empty name/placeholder")
        name.typeText(title + "\n")
        try require(name.value as? String == title, "The unique template name must actually be entered")
        try tap(app.buttons["添加训练项目"])
        let search = app.searchFields.firstMatch
        try tap(search); search.typeText("走位基础")
        try tap(app.buttons["添加走位基础"])
        try exists(app.buttons["取消选择走位基础"])
        try tapUniqueLabel("关闭")
        try disappears(app.keyboards.firstMatch)
        try tapUniqueLabel("完成(1)")
        let save = app.buttons["保存"].firstMatch
        try exists(save)
        // Prior 004 captures showed this actual navigation Menu can report non-hittable.
        // Use only its measured center, with frame/keyboard checks, never screen coordinates.
        try require(save.isEnabled && !save.frame.isEmpty && app.windows.firstMatch.frame.contains(save.frame), "Save menu must be exposed in the real window")
        try require(!app.keyboards.firstMatch.exists, "Keyboard must be closed before the navigation save menu")
        try capture("builder-before-measured-save-menu")
        save.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        try tapUniqueLabel("保存并加入今日安排")
        try disappears(app.navigationBars["新建模版"])
        try homeReveal(app.buttons["我的模版"], upward: true)
        try tap(app.buttons["我的模版"])
        let cards = templateCards.matching(NSPredicate(format: "label CONTAINS %@", title))
        try until("New unique template source must appear") { cards.count == 1 }
        let identifier = cards.firstMatch.identifier
        let prefix = "trainingHome.template.edit."
        let source = String(identifier.dropFirst(prefix.count))
        try require(UUID(uuidString: source) != nil, "Only a pure template UUID, never .cover, identifies T")
        try homeReveal(row(source), upward: false)
        return source
    }

    private func openLibraryDetail() throws {
        let app = try application
        try tab("动作库")
        let search = app.textFields["librarySearchField"]
        try tap(search)
        // First visit is empty; later re-entry preserves the same keyword. Avoid deleting unknown input.
        let current = search.value as? String ?? ""
        if !current.contains("中袋直线出杆") { search.typeText("中袋直线出杆\n") }
        else { search.typeText("\n") }
        let card = app.descendants(matching: .any).matching(identifier: "drillCard_drill_c012").firstMatch
        try exists(card)
        try require(fullyVisible(card, bottom: app.tabBars.firstMatch.frame.minY),
                    "Search result card must be fully exposed above the actual TabBar")
        try tap(card)
        try assertLibraryDetail()
    }
    private func assertLibraryDetail() throws {
        let app = try application
        try exists(app.staticTexts["中袋直线出杆"])
        try exists(app.buttons["addToTrainingButton"])
        try exists(app.descendants(matching: .any).matching(identifier: "drillSceneTableViewport").firstMatch)
        try exists(app.navigationBars.buttons["BackButton"])
    }
    private func addLibraryTwice() throws {
        let app = try application
        try openLibraryDetail()
        for attempt in 1...2 {
            try tap(app.buttons["addToTrainingButton"])
            try tap(app.buttons["addToTodayTrainingRow"])
            try disappears(app.buttons["addToTodayTrainingRow"])
            try capture("library-add-attempt-\(attempt)-sheet-closed")
        }
        try back()
    }
    private func tabAfterLibraryBack() throws { try back(); try tab("训练") }

    private func assertQueue(_ sources: [String]) throws {
        if let first = sources.first { try homeReveal(row(first), upward: false) }
        let expected = Set(sources.map { rowPrefix + $0 })
        try until("Queue must contain exactly the expected source cards: \(sources)") {
            let cards = self.queueCards.allElementsBoundByIndex
            return cards.count == sources.count && Set(cards.map(\.identifier)) == expected
        }
        for source in sources {
            let element = row(source)
            try require(element.label.contains("待训练"), "Every source must remain pending: \(source)")
            try require(element.value as? String == "已折叠", "Keep rows collapsed for reliable order observation")
        }
    }
    private func assertOrder(_ sources: [String]) throws {
        try assertQueue(sources)
        let app = try application
        let bar = app.tabBars.firstMatch
        try exists(bar)
        let elements = sources.map(row)
        // A bounded preparation scroll tries to show all collapsed cards together.
        // If that is impossible, throw an observation limitation instead of inventing a drag/order.
        for _ in 0..<5 {
            if elements.allSatisfy({ fullyVisible($0, bottom: bar.frame.minY) }) { break }
            if let low = elements.last, low.frame.maxY >= bar.frame.minY { app.swipeUp() }
            else { app.swipeDown() }
        }
        try until("All source cards must be fully visible in one stable order observation") {
            let frames = elements.map(\.frame)
            return elements.allSatisfy { self.fullyVisible($0, bottom: bar.frame.minY) }
                && zip(frames, frames.dropFirst()).allSatisfy { pair in pair.0.maxY <= pair.1.minY }
        }
    }
    private func openQueueMenu(sourceID: String, label: String) throws {
        try homeReveal(row(sourceID), upward: false)
        try require(row(sourceID).label.contains("待训练"), "Only a newly-created pending item may be managed")
        let menu = try uniqueButton(label: label)
        try homeReveal(menu, upward: true)
        let a = row(sourceID).frame, b = menu.frame
        // Queue004 actual AX/PNG places this uniquely-labelled menu directly beside
        // its header; use its interior center to establish row ownership, not an
        // exact touching-edge comparison between separately queried AX frames.
        print("[QD-TodayQueue-Menu] source=\(sourceID) header=\(a) menu=\(b) label=\(menu.label)")
        try require(a.minY < b.midY && b.midY < a.maxY && b.midX > a.maxX,
                    "Observed unique menu center must be beside the intended source header, not the template shelf")
        try capture("before-queue-menu-" + sourceID)
        try tap(menu)
    }

    private func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure.requirement(message) }
    }
    private func until(_ message: String, timeout: TimeInterval = 12, _ check: @escaping () -> Bool) throws {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in check() }, object: nil)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        try require(result == .completed, message)
    }
    private func exists(_ element: XCUIElement) throws { try require(element.waitForExistence(timeout: 12), "Missing expected element: \(element)") }
    private func disappears(_ element: XCUIElement) throws { try require(element.waitForNonExistence(timeout: 12), "Expected element did not disappear: \(element)") }
    private func tap(_ element: XCUIElement) throws {
        try until("Target must be visible, enabled and tappable: \(element)") { element.exists && element.isEnabled && element.isHittable }
        element.tap()
    }
    private func uniqueButton(label: String) throws -> XCUIElement {
        let query = try application.buttons.matching(NSPredicate(format: "label == %@", label))
        try until("Exactly one button with observed source label required: \(label)") { query.count == 1 }
        return query.firstMatch
    }
    private func tapUniqueLabel(_ label: String) throws { try tap(uniqueButton(label: label)) }
    private func tab(_ label: String) throws {
        let app = try application
        try exists(app.tabBars.firstMatch)
        try tap(app.tabBars.firstMatch.buttons[label])
    }
    private func back() throws { try tap(application.navigationBars.buttons.firstMatch) }
    private func fullyVisible(_ element: XCUIElement, bottom: CGFloat) -> Bool {
        guard let app, element.exists, !element.frame.isEmpty else { return false }
        let frame = element.frame
        let navigation = app.navigationBars.firstMatch
        let top = navigation.exists ? navigation.frame.maxY : app.windows.firstMatch.frame.minY
        return app.windows.firstMatch.frame.contains(frame) && frame.minY >= top && frame.maxY < bottom
    }
    private func homeReveal(_ element: XCUIElement, upward: Bool) throws {
        let app = try application
        let bar = app.tabBars.firstMatch
        try exists(bar)
        for _ in 0..<10 {
            // Queue001 AX: outer vertical ScrollView (0,120,402,754), nested
            // horizontal filter (0,548,402,44). Select by current geometry, not index.
            let window = app.windows.firstMatch.frame
            let vertical = app.scrollViews.allElementsBoundByIndex.filter {
                let frame = $0.frame
                return $0.exists && frame.height > frame.width
                    && frame.width >= window.width * 0.9
                    && frame.intersects(window)
            }
            try require(vertical.count == 1, "Require one observed outer vertical ScrollView; do not swipe the whole app or horizontal shelf")
            let scroll = vertical[0]
            let navigation = app.navigationBars.firstMatch
            let top = max(scroll.frame.minY, navigation.exists ? navigation.frame.maxY : window.minY)
            let bottom = min(scroll.frame.maxY, bar.frame.minY)
            let height = bottom - top
            try require(height > 0, "The vertical scroll viewport must have an unobstructed height")
            if fullyVisible(element, bottom: bottom), element.frame.minY >= top, element.isHittable { return }
            var moveContentUp = upward
            var overflow = height / 8
            if element.exists, !element.frame.isEmpty {
                try require(element.frame.height < height, "Target is taller than the actual scroll viewport; cannot satisfy complete visibility")
                if element.frame.minY < top {
                    moveContentUp = false
                    overflow = top - element.frame.minY
                } else if element.frame.maxY >= bottom {
                    moveContentUp = true
                    overflow = element.frame.maxY - bottom
                }
                else { throw Failure.requirement("Target frame is exposed but not tappable; inspect AX/overlays instead of scrolling: \(element)") }
            }
            // Short, bounded drags are test navigation settings, not product tolerances.
            // Re-read geometry after every gesture; retain the full-frame assertion.
            let distance = min(height / 8, max(height / 24, overflow + height / 48))
            let centerY = (top + bottom) / 2
            let signed = moveContentUp ? distance : -distance
            let origin = scroll.coordinate(withNormalizedOffset: .zero)
            let x = scroll.frame.width / 2
            let from = origin.withOffset(CGVector(dx: x, dy: centerY + signed / 2 - scroll.frame.minY))
            let to = origin.withOffset(CGVector(dx: x, dy: centerY - signed / 2 - scroll.frame.minY))
            print("[QD-TodayQueue-Reveal] target=\(element.identifier) frame=\(element.frame) viewport=\(top)...\(bottom) drag=\(signed)")
            from.press(forDuration: 0.05, thenDragTo: to)
        }
        throw Failure.requirement("Target not fully exposed above actual TabBar: \(element)")
    }
    private func capture(_ stage: String) throws {
        let app = try application
        shotNumber += 1
        let stem = "today-queue-\(token)-\(shotNumber)-\(stage)"
        let shot = XCUIScreen.main.screenshot()
        let image = XCTAttachment(screenshot: shot); image.name = stem; image.lifetime = .keepAlways; add(image)
        try shot.pngRepresentation.write(to: output.appendingPathComponent(stem + ".png"), options: .withoutOverwriting)
        let ax = app.debugDescription
        let text = XCTAttachment(string: ax); text.name = stem + "-AX"; text.lifetime = .keepAlways; add(text)
        try Data(ax.utf8).write(to: output.appendingPathComponent(stem + ".txt"), options: .withoutOverwriting)
    }
}
