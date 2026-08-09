import XCTest

/// 问题集合 v31 W5 收尾走查：模拟器实跑取证。
///
/// 覆盖五类界面（截图落 `build/v31-w5-screenshots/`）：
/// 1. 动作库列表：按主分类分组 + 副分类筛选命中（契约 §3.3）；
/// 2. drill 详情：主徽章 + 副分类次徽章 + 规格行剂量文案；
/// 3. 多球形训练展开：录入界面逐组球形（`drill_c042` 逐球形球数异构 10/5）；
/// 4. 官方计划「今日安排」：W3a 与 W3b 各一份（取免费计划——付费计划未订阅时
///    详情页只给前几周预览、无法激活，见 `PlanDetailView` 的 `isPremiumLocked` 分支）；
/// 5. 自定义计划构建器：轮数 stepper + 只读派生球数。
///
/// 方法名带序号以固定执行顺序：自由训练需要「无激活计划」，故必须排在计划激活之前。
final class V31W5WalkthroughUITests: XCTestCase {

    private let outDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // QiuJiUITests/
        .deletingLastPathComponent()   // <repo root>
        .appendingPathComponent("build/v31-w5-screenshots", isDirectory: true)

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    // MARK: - 1/2. 动作库分组、副分类筛选、drill 详情

    func test01_drillLibraryGroupingFilterAndDetail() throws {
        app.switchTab(.drillLibrary)
        sleep(4)
        snap("01-library-grouped-by-primary-category")

        let positioning = app.descendants(matching: .any)["sidebar_走位训练"]
        guard positioning.waitForExistence(timeout: 8) else {
            snap("02x-no-sidebar")
            dumpHierarchy("02x-no-sidebar")
            XCTFail("动作库应有「走位训练」分类入口")
            return
        }
        positioning.tap()
        sleep(2)
        snap("02-library-positioning-filter-secondary-hit")
        dumpHierarchy("02-library-positioning-filter")

        // c046「控力走位圈」主分类 forceControl、副分类 positioning ⇒ 命中筛选、
        // 但仍分在「控力训练」分节下（统计只记主分类）。
        XCTAssertTrue(app.staticTexts["控力训练"].waitForExistence(timeout: 6),
                      "按走位训练筛选后应出现副分类命中的「控力训练」分节")

        // c018/c020/c021（杆法）、c030/c031（分离角）、c046（控力）都是靠副分类命中的跨类条目。
        // 按网格顺序（走位 → 控力）依次打开，避免返回后还要反向滚动。
        try openDrillDetail(drillId: "drill_c042", named: "初级蛇彩走位", tag: "03")
        try openDrillDetail(drillId: "drill_c046", named: "控力走位圈", tag: "04")
    }

    // MARK: - 3. 多球形训练展开（异构球数）

    func test02_freeTrainingMultiFormationExpansion() throws {
        app.switchTab(.training)
        sleep(4)

        guard tapLabel("开始训练", timeout: 10) || tapLabel("自由记录", timeout: 5) else {
            snap("05x-no-free-entry")
            dumpHierarchy("05x-no-free-entry")
            XCTFail("训练首页应有自由训练入口（需无激活计划）")
            return
        }
        sleep(3)

        try addDrill(named: "初级蛇彩走位", tag: "05a")
        sleep(2)
        if tapLabel("切换到单项视图", timeout: 6) { sleep(3) }
        snap("05-record-c042-formation-groups")
        dumpHierarchy("05-record-c042")

        let formationMenus = app.buttons.matching(NSPredicate(format: "label CONTAINS '组球形'"))
        XCTAssertGreaterThanOrEqual(formationMenus.count, 2,
                                    "多球形 drill 每一组都应带球形")
        for index in 0..<formationMenus.count {
            XCTAssertFalse(formationMenus.element(boundBy: index).label.contains("未选择"),
                           "第 \(index + 1) 组未预填球形")
        }

        abandonTraining()
    }

    // MARK: - 4. 官方计划「今日安排」

    func test03_officialPlanTodaySchedule_W3a_accuracy() throws {
        try activatePlanAndSnapSchedule(planName: "准度专项", tag: "06")
    }

    func test04_officialPlanTodaySchedule_W3b_beginner() throws {
        try activatePlanAndSnapSchedule(planName: "新手入门计划", tag: "07")
    }

    // MARK: - 5. 自定义计划构建器

    func test05_customPlanBuilderRoundsStepper() throws {
        app.switchTab(.training)
        sleep(3)

        // 入口在训练首页右上角「More」菜单里（`TrainingHomeView` 的 Menu）。
        var entered = tapLabel("新建自定义计划", timeout: 4)
        if !entered {
            let more = app.buttons["More"].firstMatch
            if more.waitForExistence(timeout: 6) {
                more.tap()
                sleep(2)
                snap("08x-more-menu")
            }
            entered = tapLabel("新建自定义计划", timeout: 6)
        }
        guard entered else {
            snap("08x-no-builder-entry")
            dumpHierarchy("08x-no-builder-entry")
            XCTFail("训练首页应有「新建自定义计划」入口")
            return
        }
        sleep(3)
        snap("08a-custom-plan-builder-empty")

        guard tapLabel("添加训练项目", timeout: 8) else {
            dumpHierarchy("08x-no-add-item")
            XCTFail("构建器应有「添加训练项目」")
            return
        }
        sleep(3)
        try pickDrill(named: "初级蛇彩走位", tag: "08b")
        closePicker()
        sleep(2)
        snap("08-custom-plan-builder-drill-row")
        dumpHierarchy("08-custom-plan-builder")

        // 打开该条目的设置弹窗：轮数 stepper 可调，每轮球数由内容派生只读。
        let settings = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'ellipsis' OR identifier CONTAINS[c] 'ellipsis'")
        ).firstMatch
        if settings.waitForExistence(timeout: 6) {
            settings.tap()
            sleep(2)
            snap("09-custom-plan-rounds-stepper")
            dumpHierarchy("09-custom-plan-rounds-stepper")
            XCTAssertTrue(app.staticTexts["每球形轮数"].waitForExistence(timeout: 5),
                          "设置弹窗应有「每球形轮数」stepper")
            XCTAssertTrue(
                app.staticTexts["每轮球数（逐球形）"].waitForExistence(timeout: 3)
                    || app.staticTexts["每轮球数"].waitForExistence(timeout: 2),
                "设置弹窗应展示内容派生的只读每轮球数"
            )
        } else {
            dumpHierarchy("09x-no-settings-button")
            XCTFail("条目行应有设置入口（ellipsis.circle）")
        }
    }

    // MARK: - Steps

    /// 动作库卡片带稳定 identifier（`drillCard_<drillId>`），比按文案匹配可靠。
    private func openDrillDetail(drillId: String, named name: String, tag: String) throws {
        // LazyVGrid 只实例化视口附近的卡片 ⇒ 先滚动到它出现，再判可点。
        let card = app.buttons["drillCard_\(drillId)"]
        var attempts = 0
        while !(card.exists && card.isHittable) && attempts < 16 {
            app.windows.firstMatch.swipeUp()
            sleep(1)
            attempts += 1
        }
        guard card.exists else {
            snap("\(tag)x-no-drill-\(name)")
            dumpHierarchy("\(tag)x-no-drill-\(name)")
            XCTFail("动作库应有卡片 drillCard_\(drillId)（滚动 \(attempts) 次仍未出现）")
            return
        }
        card.tap()
        sleep(3)
        snap("\(tag)-detail-\(name)")
        dumpHierarchy("\(tag)-detail-\(name)")
        // 详情页规格行在下方，滚一屏再补一张。
        app.windows.firstMatch.swipeUp()
        sleep(2)
        snap("\(tag)b-detail-\(name)-spec-row")
        dumpHierarchy("\(tag)b-detail-\(name)-spec")
        goBack()
        sleep(2)
    }

    private func activatePlanAndSnapSchedule(planName: String, tag: String) throws {
        app.switchTab(.training)
        sleep(3)

        var opened = false
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", planName)).firstMatch
        if card.waitForExistence(timeout: 8) {
            card.tap()
            opened = true
        } else if tapLabel("查看全部", timeout: 4) || tapLabel("计划库", timeout: 4) {
            sleep(2)
            let inList = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", planName)).firstMatch
            if inList.waitForExistence(timeout: 8) {
                inList.tap()
                opened = true
            }
        }
        guard opened else {
            snap("\(tag)x-no-plan-card")
            dumpHierarchy("\(tag)x-no-plan-card")
            XCTFail("训练首页应能找到计划「\(planName)」")
            return
        }
        sleep(3)
        snap("\(tag)a-plan-detail-\(planName)")

        if tapLabel("开始此计划", timeout: 8) {
            sleep(1)
            _ = tapLabel("确定激活", timeout: 6)
            sleep(3)
        } else if tapLabel("切换到此计划", timeout: 4) {
            sleep(1)
            _ = tapLabel("确定", timeout: 6)
            sleep(3)
        } else {
            dumpHierarchy("\(tag)x-no-activate")
            XCTFail("计划详情应可激活「\(planName)」")
            return
        }

        // 计划详情页隐藏了 TabBar（`.toolbar(.hidden, for: .tabBar)`），
        // 激活后必须先退回训练首页，不能直接 switchTab。
        for _ in 0..<3 where !hasTodaySchedule {
            goBack()
            sleep(2)
        }
        sleep(3)
        snap("\(tag)-today-schedule-\(planName)")
        dumpHierarchy("\(tag)-today-schedule")

        XCTAssertTrue(hasTodaySchedule, "激活后训练首页应出现「今日安排」")
    }

    private var hasTodaySchedule: Bool {
        !app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS '今日安排'"))
            .allElementsBoundByIndex.isEmpty
    }

    private func addDrill(named name: String, tag: String) throws {
        guard tapLabel("添加训练动作", timeout: 8) else {
            snap("\(tag)x-no-add-drill")
            dumpHierarchy("\(tag)x-no-add-drill")
            XCTFail("自由训练页应有「添加训练动作」")
            return
        }
        sleep(3)
        try pickDrill(named: name, tag: tag)
        closePicker()
    }

    private func pickDrill(named name: String, tag: String) throws {
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 6) {
            search.tap()
            search.typeText(name)
            sleep(2)
        }
        let addButton = app.buttons["添加\(name)"].firstMatch
        guard addButton.waitForExistence(timeout: 8) else {
            snap("\(tag)x-no-row-\(name)")
            dumpHierarchy("\(tag)x-no-row-\(name)")
            XCTFail("动作选择器应能搜到「\(name)」")
            return
        }
        addButton.tap()
        sleep(2)
    }

    private func closePicker() {
        for label in ["close", "取消", "Cancel"] {
            let cancel = app.buttons[label].firstMatch
            if cancel.exists && cancel.isHittable {
                cancel.tap()
                sleep(2)
                break
            }
        }
        dismissKeyboard()
        for _ in 0..<3 {
            guard pickerIsOpen else { break }
            let done = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '完成('")).firstMatch
            if done.waitForExistence(timeout: 4) {
                done.tap()
            } else {
                app.windows.firstMatch
                    .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
                    .press(forDuration: 0.1,
                           thenDragTo: app.windows.firstMatch
                            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
            }
            sleep(3)
        }
        sleep(1)
    }

    /// 走查不落库：结束训练后在总结页放弃，避免污染后续计划推进状态。
    private func abandonTraining() {
        let end = app.buttons["结束训练"].firstMatch
        if end.waitForExistence(timeout: 8) { end.tap() } else { _ = tapLabel("结束", timeout: 5) }
        sleep(1)
        let confirm = app.alerts.buttons["结束"]
        if confirm.waitForExistence(timeout: 5) { confirm.tap() }
        sleep(3)
        for label in ["放弃", "不保存", "取消"] where tapLabel(label, timeout: 3) {
            sleep(2)
            break
        }
    }

    // MARK: - Helpers

    private var pickerIsOpen: Bool {
        app.staticTexts["选择训练动作"].exists || app.navigationBars["选择训练动作"].exists
    }

    private func dismissKeyboard() {
        if app.keyboards.buttons["search"].exists {
            app.keyboards.buttons["search"].tap()
            sleep(1)
        }
        guard app.keyboards.firstMatch.exists else { return }
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
            .press(forDuration: 0.2,
                   thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)),
                   withVelocity: .slow,
                   thenHoldForDuration: 0.5)
        sleep(1)
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists && back.isHittable { back.tap() }
    }

    @discardableResult
    private func tapLabel(_ label: String, timeout: TimeInterval = 6) -> Bool {
        let button = app.buttons[label].firstMatch
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }
        let text = app.staticTexts[label].firstMatch
        if text.waitForExistence(timeout: 1) {
            text.tap()
            return true
        }
        return false
    }

    private func dumpHierarchy(_ name: String) {
        try? app.debugDescription.write(
            to: outDir.appendingPathComponent("\(name)-hierarchy.txt"),
            atomically: true, encoding: .utf8
        )
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: outDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
