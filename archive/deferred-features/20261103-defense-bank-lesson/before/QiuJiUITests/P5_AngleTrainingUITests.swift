import XCTest

/// 练习 Tab（原「角度」）首页与核心子页冒烟（学 / 理 / 练 / 打 / 解 分类侧栏 + 分组网格）。
final class P5_AngleTrainingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication.launchClean()
        app.switchTab(.angle)
        sleep(2)
    }

    /// 分段 Tab 用 accessibilityIdentifier 精确定位（避免与底部 Tab 重名）。
    @discardableResult
    private func switchHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 3) else { return false }
        seg.tap()
        usleep(600_000)
        return true
    }

    // MARK: - Angle Home

    func testAngleHomeTitle() {
        // D-v45-8 / FL-027：页内大标题已去掉；`staticTexts["练习"]` 会假绿命中底栏。
        XCTAssertTrue(app.tabBars.buttons["练习"].waitForExistence(timeout: 5),
                      "Tab bar '练习' should remain")
        XCTAssertTrue(app.buttons["angleHomeTab_全部"].waitForExistence(timeout: 5),
                      "Practice sidebar '全部' should be visible")
        XCTAssertTrue(app.buttons["瞄准原理"].waitForExistence(timeout: 5),
                      "瞄准原理 card should be visible on the practice home")
        saveW2Shot("practice-home-all-Light")
    }

    func testFiveSegmentTabs() {
        for name in ["学", "理", "练", "打", "解"] {
            XCTAssertTrue(app.buttons["angleHomeTab_\(name)"].waitForExistence(timeout: 3),
                          "Segment tab '\(name)' should exist")
        }
    }

    func testSegmentCards() {
        // 学（默认「全部」可见；显式切学后应有学卡、无球理）
        XCTAssertTrue(switchHomeTab("学"), "Should switch to 学 segment")
        XCTAssertTrue(app.buttons["瞄准原理"].waitForExistence(timeout: 3), "瞄准原理 card should exist in 学")
        XCTAssertTrue(app.buttons["瞄准点对照表"].waitForExistence(timeout: 3), "瞄准点对照表 card should exist in 学")
        XCTAssertFalse(app.descendants(matching: .any)["球理"].exists, "学区不应再有球理入口卡（v32）")
        saveW2Shot("practice-home-learn-Light")
        // 理（v32.2：每篇一卡，无「球理」总卡）
        XCTAssertTrue(switchHomeTab("理"), "Should switch to 理 segment")
        XCTAssertTrue(app.buttons["切线法则"].waitForExistence(timeout: 3), "切线法则 card should exist in 理")
        XCTAssertFalse(app.descendants(matching: .any)["球理"].exists, "理区不应再有球理索引总卡")
        // 练
        XCTAssertTrue(switchHomeTab("练"), "Should switch to 练 segment")
        XCTAssertTrue(app.buttons["角度预测"].waitForExistence(timeout: 3), "角度预测 card should exist in 练")
        saveW2Shot("practice-home-train-Light")
        // 打
        XCTAssertTrue(switchHomeTab("打"), "Should switch to 打 segment")
        XCTAssertTrue(app.buttons["自由击球"].waitForExistence(timeout: 3), "自由击球 card should exist in 打")
        XCTAssertTrue(app.buttons["自由走位"].waitForExistence(timeout: 3), "自由走位 card should exist in 打")
        // 解
        XCTAssertTrue(switchHomeTab("解"), "Should switch to 解 segment")
        XCTAssertTrue(app.buttons["翻袋解球"].waitForExistence(timeout: 3), "翻袋解球 card should exist in 解")
        XCTAssertTrue(app.buttons["颗星解球"].waitForExistence(timeout: 3), "颗星解球 card should exist in 解")
    }

    // MARK: - Search

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// v45 W2 Light 验收截图（不改断言，只落盘）。
    private func saveW2Shot(_ name: String) {
        let dir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w2-screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: dir.appendingPathComponent("\(name).png"))
    }

    func testSearchFiltersEntries() {
        let searchField = app.textFields["搜索练习"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should exist")
        snap("search-idle")
        searchField.tap()
        searchField.typeText("翻袋")
        usleep(600_000)
        snap("search-filtered")
        XCTAssertTrue(app.buttons["翻袋解球"].waitForExistence(timeout: 3),
                      "Matching card 翻袋解球 should remain visible")
        XCTAssertFalse(app.buttons["瞄准原理"].exists,
                       "Non-matching card 瞄准原理 should be filtered out")

        // 清空按钮恢复全部
        let clearButton = app.buttons["xmark.circle.fill"].firstMatch
        if clearButton.exists { clearButton.tap() } else {
            searchField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        }
        usleep(600_000)
        XCTAssertTrue(app.buttons["瞄准原理"].waitForExistence(timeout: 3),
                      "Clearing search should restore all cards")
    }

    func testSearchEmptyState() {
        let searchField = app.textFields["搜索练习"]
        guard searchField.waitForExistence(timeout: 3) else { return }
        searchField.tap()
        searchField.typeText("zzz")
        usleep(600_000)
        snap("search-empty")
        XCTAssertTrue(app.staticTexts["没有找到相关练习"].waitForExistence(timeout: 3),
                      "Empty state should appear for no-match search")
        // BTEmptyState 图标钮与操作钮同 label；点 firstMatch，空态/恢复卡断言不删。
        let browseAll = app.buttons["浏览全部练习"].firstMatch
        XCTAssertTrue(browseAll.waitForExistence(timeout: 3), "Empty state action should exist")
        browseAll.tap()
        usleep(600_000)
        XCTAssertTrue(app.buttons["瞄准原理"].waitForExistence(timeout: 3),
                      "Tapping 浏览全部练习 should clear search and restore cards")
    }

    // MARK: - Contact Point Table（学）

    func testNavigateToContactPointTable() {
        let tableCard = app.buttons["进球点对照表"]
        guard tableCard.waitForExistence(timeout: 3) else { return }
        tableCard.tap()
        sleep(1)
        XCTAssertTrue(app.navigationBars["进球点对照表"].waitForExistence(timeout: 3), "Contact point table should open")
    }

    func testContactPointTableSlider() {
        let tableCard = app.buttons["进球点对照表"]
        guard tableCard.waitForExistence(timeout: 3) else { return }
        tableCard.tap()
        sleep(1)
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 3), "Slider should be visible")
    }

    func testContactPointTableContent() {
        let tableCard = app.buttons["进球点对照表"]
        guard tableCard.waitForExistence(timeout: 3) else { return }
        tableCard.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["拖动查看瞄准点与接触点"].waitForExistence(timeout: 3), "Interactive hint should be visible")
        app.scrollDown(times: 2)
        XCTAssertTrue(app.staticTexts["原理说明"].waitForExistence(timeout: 3), "Principle section should be visible")
    }

    // MARK: - Geometric Quiz（练）

    func testNavigateToGeometricQuiz() {
        guard switchHomeTab("练") else { return }
        let quizCard = app.buttons["角度预测"]
        guard quizCard.waitForExistence(timeout: 3) else { return }
        quizCard.tap()
        sleep(2)
        // 几何角度训练页导航标题为「角度预测」（GeometricAngleQuizView）。
        XCTAssertTrue(app.navigationBars["角度预测"].waitForExistence(timeout: 5),
                      "Geometric quiz view should open")
    }

    // MARK: - Free Play（打，ADR-P18-01 拆页后为独立 FreePlayView）

    func testNavigateToFreePlay() {
        guard switchHomeTab("打") else { return }
        let freePlayCard = app.buttons["自由击球"]
        guard freePlayCard.waitForExistence(timeout: 3) else { return }
        freePlayCard.tap()
        sleep(2)
        // 自由击球拆页（条 15 / ADR-P18-01）：独立页面标题为「自由击球」。
        XCTAssertTrue(app.navigationBars["自由击球"].waitForExistence(timeout: 5),
                      "Free play should open the standalone FreePlayView")
    }
}

/// Repeated category replacement must not retain blank space above the first row.
final class GroupFilterLayoutUITests: XCTestCase {
    private func check(_ app: XCUIApplication, sidebar: String, groups: [String], cardPrefix: String?) {
        continueAfterFailure = true
        for round in 0..<3 {
            for group in groups {
                let tab = app.buttons[sidebar + group]
                XCTAssertTrue(tab.waitForExistence(timeout: 5))
                tab.tap()
                Thread.sleep(forTimeInterval: 0.7)
                let header = cardPrefix == nil
                    ? app.descendants(matching: .any).matching(identifier: "librarySectionHeader_" + group).firstMatch
                    : app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "librarySectionHeader_")).firstMatch
                XCTAssertTrue(header.waitForExistence(timeout: 5))
                let card: XCUIElement
                if let cardPrefix {
                    card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", cardPrefix)).firstMatch
                } else {
                    let first = ["学": "瞄准原理", "理": "30° 法则", "练": "角度预测", "打": "分离角与走位", "解": "思路训练"]
                    card = app.buttons[first[group]!]
                }
                XCTAssertTrue(card.waitForExistence(timeout: 5))
                let gap = card.frame.minY - header.frame.maxY
                print("GROUP_GAP round=\(round) group=\(group) gap=\(gap) header=\(header.frame) card=\(card.frame)")
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "group-\(sidebar)-\(round)-\(group)"
                shot.lifetime = .keepAlways
                add(shot)
                XCTAssertGreaterThanOrEqual(gap, -1, "First row must not be hidden behind its header")
                XCTAssertLessThanOrEqual(gap, 24, "Header-to-card gap must remain within the section spacing")
                if round > 0 {
                    let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.72))
                    let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.3))
                    start.press(forDuration: 0.05, thenDragTo: end)
                }
            }
        }
    }

    func testPracticeAllToSingleAfterScrolling() {
        let app = XCUIApplication.launchClean()
        app.switchTab(.angle)
        for round in 0..<3 {
            app.buttons["angleHomeTab_全部"].tap()
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.72))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.3))
            for _ in 0..<3 { start.press(forDuration: 0.05, thenDragTo: end) }
            app.buttons["angleHomeTab_练"].tap()
            Thread.sleep(forTimeInterval: 0.7)
            let header = app.descendants(matching: .any).matching(identifier: "librarySectionHeader_练").firstMatch
            let card = app.buttons["角度预测"]
            let gap = card.frame.minY - header.frame.maxY
            print("ALL_SINGLE_GAP round=\(round) gap=\(gap)")
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "all-single-\(round)"
            shot.lifetime = .keepAlways
            add(shot)
            XCTAssertGreaterThanOrEqual(gap, -1)
            XCTAssertLessThanOrEqual(gap, 24)
        }
    }

    private func assertTop(_ app: XCUIApplication, card: XCUIElement, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let header = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "librarySectionHeader_")).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        let gap = card.frame.minY - header.frame.maxY
        print("FILTER_GAP name=\(name) gap=\(gap)")
        XCTAssertGreaterThanOrEqual(gap, -1)
        XCTAssertLessThanOrEqual(gap, 24)
        XCTAssertTrue(card.isHittable)
    }

    func testSearchTopicsAndRapidGroups() {
        let app = XCUIApplication.launchClean()
        app.switchTab(.angle)
        for name in ["理", "打", "学", "解", "全部", "练"] {
            app.buttons["angleHomeTab_" + name].tap()
        }
        assertTop(app, card: app.buttons["角度预测"], name: "practice-rapid")
        app.buttons["angleHomeTab_全部"].tap()
        app.buttons["practiceTopicFilterMenu"].tap()
        app.buttons["practiceTopicMenu_防守"].tap()
        assertTop(app, card: app.buttons["风险报酬决策矩阵"], name: "practice-topic")
        app.buttons["practiceTopicFilterMenu"].tap()
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "全部", "angleHomeTab_全部")).firstMatch.tap()
        let field = app.textFields["librarySearchField"]
        field.tap()
        field.typeText("角度预测")
        assertTop(app, card: app.buttons["角度预测"], name: "practice-search")
        app.buttons["清除搜索"].tap()
        field.typeText("zzzz")
        XCTAssertTrue(app.staticTexts["没有找到相关练习"].waitForExistence(timeout: 5))
        app.buttons["浏览全部练习"].firstMatch.tap()
        assertTop(app, card: app.buttons["瞄准原理"], name: "practice-empty-restored")
    }

    func testLibrarySearchAndDetailReturn() {
        let app = XCUIApplication.launchClean()
        app.switchTab(.drillLibrary)
        for name in ["准度", "走位", "控力", "基础", "全部"] {
            app.buttons["sidebar_" + name].tap()
        }
        Thread.sleep(forTimeInterval: 0.7)
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "drillCard_")).firstMatch
        assertTop(app, card: first, name: "library-rapid")
        let field = app.textFields["librarySearchField"]
        field.tap()
        field.typeText("直线")
        Thread.sleep(forTimeInterval: 0.7)
        assertTop(app, card: first, name: "library-search")
        app.buttons["清除搜索"].tap()
        field.typeText("zzzz")
        XCTAssertTrue(app.descendants(matching: .any)["drillListEmptyState"].waitForExistence(timeout: 5))
        app.buttons["清除搜索"].tap()
        app.buttons["sidebar_基础"].tap()
        Thread.sleep(forTimeInterval: 0.7)
        assertTop(app, card: first, name: "library-empty-restored")
        let id = first.identifier
        first.tap()
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[id].isHittable)
    }

    func testPracticeRepeatedGroups() {
        let app = XCUIApplication.launchClean()
        app.switchTab(.angle)
        check(app, sidebar: "angleHomeTab_", groups: ["学", "理", "练", "打", "解"], cardPrefix: nil)
    }

    func testLibraryRepeatedGroups() {
        let app = XCUIApplication.launchClean()
        app.switchTab(.drillLibrary)
        check(app, sidebar: "sidebar_", groups: ["基础", "准度", "杆法", "走位", "控力"], cardPrefix: "drillCard_")
    }
}

/// Physical pointer holds exercise the production gesture wiring; timed screenshots
/// are collected by the host while XCTest keeps the pointer down.
final class AimCloseupHoldUITests: XCTestCase {
    private let evidence = URL(fileURLWithPath: ProcessInfo.processInfo.environment["V61_EVIDENCE_DIR"]
        ?? "/Users/song/projects/13.billiard_trainer/output/aim-closeup-diagnosis-20260910/ui")

    func testFreeDirectionContinuousDrag() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        let app = XCUIApplication.launchClean(extraArgs: ["-v50.inMemoryStore", "-forcePremium"])
        app.switchTab(.angle)
        let search = app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("自由击球")
        app.buttons["自由击球"].tap()
        let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
        if !wheel.waitForExistence(timeout: 3) {
            let mode = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "瞄准模式：")).firstMatch
            XCTAssertTrue(mode.exists, app.debugDescription)
            mode.tap()
        }
        XCTAssertTrue(wheel.waitForExistence(timeout: 15))
        let start = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        try Data().write(to: evidence.appendingPathComponent("freeplay-motion.hold"))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -12)),
                    withVelocity: XCUIGestureVelocity(rawValue: 2), thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 2)
        try save("freeplay-motion-settled")
    }

    func testAimPoint2D() throws { try exercise(title: "2D 瞄准点训练", key: "aimpoint2d") }
    func testShotSimulation() throws { try exercise(title: "分离角与走位", key: "shotBlank") }
    func testFreePlay() throws { try exercise(title: "自由击球", key: "freeplay") }
    func testDailyClearance() throws { try exercise(title: "每日清台", key: "daily") }
    func testAimPoint3D() throws { try exercise(title: "3D 瞄准点训练", key: "aimpoint3d") }

    func testBankShot() throws { try exercise(title: "翻袋解球", key: "bankBlank") }
    func testDiamondSystem() throws { try exercise(title: "颗星解球", key: "diamondAimed") }
    func testComposer() throws { try exercise(title: "自由走位", key: "composer") }

    private func exercise(title: String, key: String) throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        var args = ["-v50.inMemoryStore", "-v53.authenticatedProfileFixture", "-forcePremium"]
        if key == "daily" {
            args += ["-deeplink.dailyClearance", "-dailyClearance.resetState", "-dailyClearance.fixture=progress"]
        }
        let app = XCUIApplication.launchClean(extraArgs: args)
        if key != "daily" {
            app.switchTab(.angle)
            let search = app.textFields["librarySearchField"]
            XCTAssertTrue(search.waitForExistence(timeout: 10))
            search.tap()
            search.typeText(title)
            let card = app.buttons[title]
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            card.tap()
        }
        let wheel = app.descendants(matching: .any)["shotStage.aimWheel"].firstMatch
        if !wheel.waitForExistence(timeout: 3) {
            let mode = app.buttons["solver.mode"]
            if mode.exists { mode.tap() }
            else {
                let free = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "瞄准模式：")).firstMatch
                XCTAssertTrue(free.exists, app.debugDescription)
                free.tap()
            }
        }
        XCTAssertTrue(wheel.waitForExistence(timeout: 15), app.debugDescription)
        if key == "diamondAimed" {
            // The reflection solution initially aims at a cushion. Use the real
            // wheel until the page reports first contact with the object ball.
            let contact = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "首碰")).firstMatch
            for _ in 0..<12 {
                if contact.exists { break }
                let from = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -80)))
            }
            XCTAssertTrue(contact.exists, "The reflection page must be aimed at a ball before checking its closeup")
        }
        try save("\(key)-ready")
        let start = wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: -1))
        try Data().write(to: evidence.appendingPathComponent("\(key)-wheel.hold"))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 8)
        Thread.sleep(forTimeInterval: 0.6)
        try save("\(key)-wheel-released")
        if key == "aimpoint3d" {
            // Orbit the production camera without tapping a new aim point, then
            // reopen the loupe to check the changed projection on the full page.
            let window = app.windows.firstMatch
            let orbit = window.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.70))
            orbit.press(forDuration: 0.1, thenDragTo: orbit.withOffset(CGVector(dx: 55, dy: -24)))
            try Data().write(to: evidence.appendingPathComponent("aimpoint3d-orbit.hold"))
            start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 8)
            try save("aimpoint3d-orbit-released")
            return
        }

        // Use the blank upper-left felt, outside the default balls' 48pt drag targets.
        let window = app.windows.firstMatch
        let frame = window.frame
        let tableStart = window.coordinate(withNormalizedOffset: .zero).withOffset(
            CGVector(dx: frame.width * 0.30, dy: frame.height * 0.30))
        let tableEnd = tableStart.withOffset(CGVector(dx: 14, dy: 0))
        try Data().write(to: evidence.appendingPathComponent("\(key)-table.hold"))
        tableStart.press(forDuration: 0.15, thenDragTo: tableEnd, withVelocity: .slow, thenHoldForDuration: 8)
        Thread.sleep(forTimeInterval: 0.6)
        try save("\(key)-table-released")
    }

    private func save(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        try screenshot.pngRepresentation.write(to: evidence.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
