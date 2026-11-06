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

    func testSixSegmentTabs() {
        for name in ["基础", "准度", "控球", "走位", "进阶", "策略"] {
            XCTAssertTrue(app.buttons["angleHomeTab_\(name)"].waitForExistence(timeout: 3),
                          "Segment tab '\(name)' should exist")
        }
    }

    func testSegmentCards() {
        let firstCards = [("基础", "瞄准原理"), ("准度", "角度与瞄准"),
                          ("控球", "分离角图谱"), ("走位", "分离角与走位"),
                          ("进阶", "翻袋解球"), ("策略", "反向规划")]
        for (section, title) in firstCards {
            PracticeHomeNavigation.select(section, in: app)
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["球理"].exists)
            snap("practice-six-" + section)
        }
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
        guard switchHomeTab("准度") else { return }
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
        guard switchHomeTab("走位") else { return }
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
                    let first = ["基础": "瞄准原理", "准度": "角度与瞄准", "控球": "分离角图谱", "走位": "分离角与走位", "进阶": "翻袋解球", "策略": "反向规划"]
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
            app.buttons["angleHomeTab_准度"].tap()
            Thread.sleep(forTimeInterval: 0.7)
            let header = app.descendants(matching: .any).matching(identifier: "librarySectionHeader_准度").firstMatch
            let card = app.buttons["角度与瞄准"]
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
        for name in ["控球", "走位", "基础", "进阶", "策略", "全部", "准度"] {
            app.buttons["angleHomeTab_" + name].tap()
        }
        assertTop(app, card: app.buttons["角度与瞄准"], name: "practice-rapid")
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
        check(app, sidebar: "angleHomeTab_", groups: ["基础", "准度", "控球", "走位", "进阶", "策略"], cardPrefix: nil)
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


/// Product-contract coverage for the six groups and the approved card copy.
final class PracticeSixGroupsUITests: XCTestCase {
    private let cards: [(group: String, title: String, subtitle: String, difficulty: String, destination: String)] = [
        ("基础", "瞄准原理", "理解切角、厚薄与瞄准点的关系", "学习难度三星，入门", "瞄准原理"),
        ("基础", "瞄准方法", "对比同一球形的三种瞄准方法", "学习难度三星，入门", "瞄准方法"),
        ("基础", "旋转与加塞", "认识打点、旋转与母球走向", "学习难度四星，应用", "旋转与加塞"),
        ("基础", "瞄准修正", "观察力度与旋转造成的瞄准偏差", "学习难度四星，应用", "瞄准修正"),
        ("基础", "瞄准点对照表", "按切角查瞄准点与接触点", "学习难度三星，入门", "瞄准点对照表"),
        ("基础", "浅谈凭感觉瞄准", "用参照和练习建立瞄准感觉", "学习难度三星，入门", "浅谈凭感觉瞄准"),
        ("基础", "进球容错角", "摆球查看可进袋的方向范围", "学习难度三星，入门", "pocketTolerance.more"),
        ("准度", "角度与瞄准", "拖动球形观察切角与瞄准方向", "学习难度三星，入门", "angleDynamic.more"),
        ("准度", "角度预测", "看简图估切角，对照答案与误差", "学习难度三星，入门", "geometric.figure"),
        ("准度", "角度练习", "在球桌场景中练习切角判断", "学习难度四星，应用", "angleTraining.start"),
        ("准度", "假想球练习", "根据切角摆准假想球位置", "学习难度三星，入门", "aimPointDiagram.figure"),
        ("准度", "瞄准点练习", "在球桌上选准瞄准方向", "学习难度四星，应用", "aimPointTraining.start"),
        ("准度", "准度练习", "调整瞄准与杆速，击球检验进袋", "学习难度四星，应用", "accuracy.start"),
        ("控球", "分离角图谱", "对比不同高低杆的母球路线", "学习难度四星，应用", "separationAngleAtlas.more"),
        ("控球", "加塞吃库图谱", "对比不同左右塞的母球吃库路线", "学习难度四星，应用", "cushionEnglishAtlas.more"),
        ("控球", "30° 法则", "理解自然滚动的碰后方向与条件", "学习难度四星，应用", "30° 法则"),
        ("控球", "90° 法则", "理解斯登击球的直角分离条件", "学习难度四星，应用", "90° 法则"),
        ("控球", "切线法则", "用切线建立母球碰后路线参照", "学习难度四星，应用", "切线法则"),
        ("控球", "母球速度分级", "建立力度参照，按球形校准", "学习难度三星，入门", "母球速度分级"),
        ("控球", "最少加塞原则", "按路线需要选择合适塞量", "学习难度四星，应用", "最少加塞原则"),
        ("走位", "分离角与走位", "自由摆球试打，观察母球走位", "学习难度四星，应用", "freeplay.moreMenu"),
        ("走位", "走位求解", "指定落位要求，求解击球方案", "学习难度四星，应用", "silu.more"),
        ("走位", "打一走二想三", "根据后两颗球倒推当前走位", "学习难度五星，综合", "planthree.more"),
        ("走位", "分离角练习", "调整打点与力度，复现母球路线", "学习难度四星，应用", "separation.start"),
        ("走位", "两球走位", "打进第一球，为第二球留下位置", "学习难度四星，应用", "twoBall.start"),
        ("走位", "三球走位", "提前选袋，完成两杆走位衔接", "学习难度五星，综合", "threeBall.start"),
        ("走位", "多球走位", "规划球序，练习残局连续走位", "学习难度五星，综合", "multiBall.start"),
        ("走位", "蛇彩练习", "按指定顺序连续进球与走位", "学习难度五星，综合", "snake.start"),
        ("走位", "自定义球形", "编辑保存球形，随时重复练习", "工具，不评级", "formation.new"),
        ("走位", "拍照建球形", "从照片还原球形，校准后推演", "工具，不评级", "选择照片"),
        ("进阶", "翻袋解球", "摆球求解目标球翻库入袋", "学习难度四星，应用", "bankshot.more"),
        ("进阶", "颗星解球", "摆球求解母球绕库碰球", "学习难度四星，应用", "reflection.more"),
        ("进阶", "翻袋练习", "按指定库序将目标球翻进袋", "学习难度五星，综合", "bank.start"),
        ("进阶", "解球练习", "按指定库序让母球解到目标球", "学习难度五星，综合", "kick.start"),
        ("进阶", "K球练习", "进球同时让母球碰到第二球", "学习难度五星，综合", "kBall.start"),
        ("进阶", "防守练习", "控制双方球位，限制对手进攻", "学习难度五星，综合", "defense.start"),
        ("策略", "反向规划", "从收尾球倒推球序与落位", "学习难度四星，应用", "反向规划"),
        ("策略", "关键球原理", "识别关键球，安排收尾衔接", "学习难度四星，应用", "关键球原理"),
        ("策略", "球团管理", "判断球团处理时机与后续衔接", "学习难度五星，综合", "球团管理"),
        ("策略", "风险报酬决策矩阵", "权衡成功收益与失败代价", "学习难度五星，综合", "风险报酬决策矩阵"),
        ("策略", "安全球三维度模型", "从距离、库位与障碍分析防守", "学习难度四星，应用", "安全球三维度模型"),
        ("策略", "清台 5 步决策流程", "串起观察、规划、执行与复盘", "学习难度五星，综合", "清台 5 步决策流程"),
        ("策略", "清台速查手册", "快速查阅控球与清台判断要点", "速查，不评级", "清台速查手册"),
    ]

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-v50.inMemoryStore", "-v51.followSystemAppearance",
                                                         "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"])
        app.switchTab(.angle)
        return app
    }

    private func find(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let card = app.buttons[title]
        let scroll = app.scrollViews.allElementsBoundByIndex.max { $0.frame.width < $1.frame.width } ?? app
        for _ in 0..<14 {
            if card.exists && card.isHittable { return card }
            scroll.swipeUp(velocity: .slow)
        }
        XCTFail("Missing or unreachable card: \(title)")
        return card
    }

    private func capture(_ app: XCUIApplication, _ name: String, fullScreen: Bool = false) throws {
        let screenshot = fullScreen ? XCUIScreen.main.screenshot() : app.screenshot()
        let shot = XCTAttachment(screenshot: screenshot)
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
        if let directory = ProcessInfo.processInfo.environment["V50_SHOT_DIR"] {
            let url = URL(fileURLWithPath: directory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: url.appendingPathComponent(name + ".png"))
            try app.debugDescription.write(to: url.appendingPathComponent(name + ".txt"), atomically: true, encoding: .utf8)
        }
    }

    func testCatalogCopyDifficultyAndTailReachability() throws {
        let app = launch()
        for group in ["基础", "准度", "控球", "走位", "进阶", "策略"] {
            PracticeHomeNavigation.select(group, in: app)
            let expected = cards.filter { $0.group == group }
            for (index, card) in expected.enumerated() {
                if index == 0 {
                    XCTAssertTrue(app.buttons[card.title].waitForExistence(timeout: 4), "Group must open at its first card: \(group)")
                    XCTAssertTrue(app.buttons[card.title].isHittable)
                }
                let button = find(card.title, in: app)
                XCTAssertTrue(button.label.contains(card.subtitle), card.title)
                XCTAssertTrue(button.label.contains(card.difficulty), card.title)
                if index == 0 || index == expected.count - 1 { try capture(app, "six-\(group)-\(index)") }
            }
        }
        XCTAssertFalse(app.buttons["practiceDifficultyInfo"].exists)
    }

    func testPracticeCardWindowNarrowAndRestore() throws {
        let app = launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        PracticeHomeNavigation.select("基础", in: app)
        let window = app.windows.firstMatch
        let card = find("瞄准原理", in: app)
        let title = card.staticTexts["瞄准原理"]
        let stars = card.staticTexts["★★★"]
        func checkCard() {
            XCTAssertTrue(card.isHittable)
            XCTAssertFalse(app.buttons["practiceDifficultyInfo"].exists)
            XCTAssertFalse(card.staticTexts["学习难度"].exists)
            XCTAssertTrue(title.exists && stars.exists)
            let gap = stars.frame.minY - title.frame.maxY
            XCTAssertGreaterThanOrEqual(gap, -1)
            XCTAssertLessThanOrEqual(gap, 8, "A one-line title should not reserve a second line")
            XCTAssertTrue(app.buttons["angleHomeTab_基础"].isSelected)
        }
        func waitFor(_ predicate: @escaping () -> Bool) -> Bool {
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in predicate() }, object: nil)], timeout: 8) == .completed
        }
        checkCard()
        let original = window.frame
        let originalCard = card.frame
        try capture(app, "wide", fullScreen: true)
        let origin = window.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(.init(dx: original.width - 7, dy: original.height - 7))
            .press(forDuration: 0.5, thenDragTo: origin.withOffset(.init(dx: original.width * 0.65, dy: original.height * 0.78)))
        func maximize() {
            let corner = window.coordinate(withNormalizedOffset: .zero)
            corner.withOffset(.init(dx: 52, dy: 32)).tap()
            if abs(window.frame.width - original.width) > 2 {
                corner.withOffset(.init(dx: 104, dy: 32)).tap()
            }
        }
        defer { if window.frame.width < original.width - 50 { maximize() } }
        XCTAssertTrue(waitFor { window.frame.width < original.width - 80 && card.frame.width < originalCard.width - 20 })
        checkCard()
        print("PRACTICE_WINDOW wide=\(original) narrow=\(window.frame) card=\(originalCard.width)->\(card.frame.width)")
        try capture(app, "narrow", fullScreen: true)
        maximize()
        XCTAssertTrue(waitFor { abs(window.frame.width - original.width) <= 2 && abs(window.frame.height - original.height) <= 2 && abs(card.frame.width - originalCard.width) <= 2 })
        checkCard()
        try capture(app, "restored", fullScreen: true)
    }

    func testPersonalTemplateReappearsFromPracticeHome() throws {
        let app = launch()
        func openManager() {
            PracticeHomeNavigation.select("走位", in: app)
            find("自定义球形", in: app).tap()
            XCTAssertTrue(app.buttons["formation.new"].waitForExistence(timeout: 8))
        }
        openManager()
        app.buttons["formation.templateMenu.B1115000-0000-4000-8000-000000000002"].tap()
        app.buttons["复制到我的球形"].tap()
        let personal = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "formation.template.", "已选")).firstMatch
        XCTAssertTrue(personal.waitForExistence(timeout: 5))
        let id = personal.identifier
        let expected = personal.label
        XCTAssertTrue(expected.contains("L型球形") && expected.contains("15颗目标球"))
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(app.buttons["angleHomeTab_走位"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.switchTab(.angle)
        openManager()
        let restored = app.buttons[id]
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        XCTAssertTrue(restored.label.contains("L型球形") && restored.label.contains("15颗目标球"))
        restored.tap()
        XCTAssertEqual(restored.value as? String, "已选")
        try capture(app, "reopened-personal-template")
        let uuid = String(id.dropFirst("formation.template.".count))
        app.buttons["formation.templateMenu." + uuid].tap()
        app.buttons["删除"].firstMatch.tap()
        app.alerts.buttons["删除模板"].tap()
        XCTAssertTrue(restored.waitForNonExistence(timeout: 5))
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(app.buttons["angleHomeTab_走位"].waitForExistence(timeout: 5))
        find("拍照建球形", in: app).tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "选择照片").firstMatch.waitForExistence(timeout: 8))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["angleHomeTab_走位"].waitForExistence(timeout: 8))
    }

    func testFoundationAndAccuracyRoutes() throws { try verifyRoutes(["基础", "准度"]) }
    func testControlAndPositionRoutes() throws { try verifyRoutes(["控球", "走位"]) }
    func testAdvancedAndStrategyRoutes() throws { try verifyRoutes(["进阶", "策略"]) }

    private func verifyRoutes(_ groups: Set<String>) throws {
        for card in cards where groups.contains(card.group) {
            let app = launch()
            PracticeHomeNavigation.select(card.group, in: app)
            find(card.title, in: app).tap()
            let destination = app.descendants(matching: .any).matching(identifier: card.destination).firstMatch
            XCTAssertTrue(destination.waitForExistence(timeout: 20), "Wrong destination: \(card.title) → \(card.destination)")
            XCTAssertFalse(app.buttons["angleHomeTab_全部"].isHittable, "Home must be left")
            try capture(app, "route-" + card.title)
            app.terminate()
        }
    }

    func testSubtitleSearchAndEmptyStateRetainsGroup() {
        let app = launch()
        PracticeHomeNavigation.select("进阶", in: app)
        let search = app.textFields["librarySearchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("绕库碰球")
        XCTAssertTrue(app.buttons["颗星解球"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["翻袋解球"].exists)
        app.buttons["清除搜索"].tap(); search.typeText("不存在的内容")
        let clearResults = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "浏览全部练习", "magnifyingglass")).firstMatch
        XCTAssertTrue(clearResults.waitForExistence(timeout: 5)); clearResults.tap()
        XCTAssertTrue(app.buttons["angleHomeTab_进阶"].isSelected)
        XCTAssertTrue(app.buttons["翻袋解球"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["瞄准原理"].exists)
    }
}
