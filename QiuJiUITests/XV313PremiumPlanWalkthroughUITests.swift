import XCTest

/// 遗留项 X-v31-3：付费官方计划的「今日安排」走查。
///
/// v31 W5 只能用免费计划（plan_accuracy / plan_beginner）走查，因为 `isPremium: true`
/// 的计划在未订阅态下 `PlanDetailView` 走 `isPremiumLocked` 分支、无法激活。本套用
/// DEBUG-only 的 `-forcePremium`（`SubscriptionManager.forcePremiumArgument`）注入订阅态，
/// 补齐 `plan_positioning`（走位Ⅰ·短距到一库）与 `plan_fullskill`（全能精选）的运行时走查。
///
/// 方法名带序号以固定执行顺序：
/// 1. `test01` 反向用例（不传开关 ⇒ 仍锁定）；判据取周列表的渐进锁，它只看
///    `plan.isPremium && !subscriptionManager.isPremium`，不受上一轮遗留的激活态影响；
/// 2. `test02` / `test03` 注入订阅态后激活两份付费计划并截「今日安排」。
///
/// 截图 / 层级 dump 落 `build/x-v31-3-screenshots/`。
final class XV313PremiumPlanWalkthroughUITests: XCTestCase {

    private static let positioningPlanName = "走位Ⅰ·短距到一库"
    private static let fullSkillPlanName = "全能精选"

    private let outDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // QiuJiUITests/
        .deletingLastPathComponent()   // <repo root>
        .appendingPathComponent("build/x-v31-3-screenshots", isDirectory: true)

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    // MARK: - 1. 反向用例：不注入订阅态时付费计划仍锁定

    func test01_premiumPlanStaysLockedWithoutInjection() throws {
        app = XCUIApplication.launchClean(extraArgs: ["-forceNonPremium"])

        try openPlanDetail(named: Self.positioningPlanName, tag: "01")
        snap("01-locked-\(Self.positioningPlanName)")
        dumpHierarchy("01-locked-\(Self.positioningPlanName)")

        // 周列表的渐进锁（`BTPremiumLock`）只看 `plan.isPremium && !isPremium`，
        // 不受「当前是否已激活此计划」影响，故是最稳的锁定态判据。
        XCTAssertTrue(app.buttons["解锁 Pro"].firstMatch.exists,
                      "未注入订阅态时付费计划周列表应停在渐进锁预览")
        XCTAssertFalse(app.buttons["开始此计划"].exists,
                       "未注入订阅态时付费计划不应可激活")
        XCTAssertTrue(app.buttons["解锁此计划"].firstMatch.exists,
                      "未注入订阅态时付费计划底部 CTA 应是「解锁此计划」")
    }

    // MARK: - 2/3. 注入订阅态后的付费计划走查

    func test02_positioningPlanTodaySchedule() throws {
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        try walkPremiumPlan(named: Self.positioningPlanName, tag: "02")
    }

    func test03_fullSkillPlanTodaySchedule() throws {
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium"])
        try walkPremiumPlan(named: Self.fullSkillPlanName, tag: "03")
    }

    // MARK: - 4. 两个开关同传时 `-forceNonPremium` 优先

    func test04_forceNonPremiumWinsOverForcePremium() throws {
        app = XCUIApplication.launchClean(extraArgs: ["-forcePremium", "-forceNonPremium"])

        try openPlanDetail(named: Self.positioningPlanName, tag: "04")
        snap("04-both-flags-\(Self.positioningPlanName)")
        dumpHierarchy("04-both-flags-\(Self.positioningPlanName)")

        XCTAssertTrue(app.buttons["解锁 Pro"].firstMatch.exists,
                      "同时传两个开关时应按 -forceNonPremium 判为未订阅")
        XCTAssertFalse(app.buttons["开始此计划"].exists,
                       "同时传两个开关时付费计划不应可激活")
    }

    // MARK: - Steps

    private func walkPremiumPlan(named planName: String, tag: String) throws {
        try openPlanDetail(named: planName, tag: tag)
        snap("\(tag)a-plan-detail-\(planName)")
        dumpHierarchy("\(tag)a-plan-detail-\(planName)")

        XCTAssertFalse(app.buttons["解锁此计划"].exists,
                       "注入订阅态后付费计划不应再走 isPremiumLocked 分支")
        XCTAssertTrue(app.buttons["开始此计划"].waitForExistence(timeout: 8),
                      "注入订阅态后付费计划应可激活")

        activateOpenedPlan(tag: tag)
        returnToTrainingHome()

        XCTAssertTrue(hasTodaySchedule, "激活「\(planName)」后训练首页应出现「今日安排」")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label == %@", planName))
                .firstMatch.waitForExistence(timeout: 8),
            "「今日安排」标题行应是「\(planName)」"
        )

        snap("\(tag)-today-schedule-\(planName)")
        dumpHierarchy("\(tag)-today-schedule-\(planName)")

        let volumeTexts = doseVolumeTexts()
        try volumeTexts.joined(separator: "\n").write(
            to: outDir.appendingPathComponent("\(tag)-today-schedule-\(planName)-dose-texts.txt"),
            atomically: true, encoding: .utf8
        )
        XCTAssertFalse(
            volumeTexts.isEmpty,
            "「今日安排」条目应展示 dose 派生量值（「N 轮 × M 球/杆」或异构「N 球形 · …」）"
        )
    }

    /// 计划卡片在首页 LazyVGrid 里，需滚动到视口才实例化。
    ///
    /// 冷启动后首页仍在加载计划/缩略图时，NavigationLink 的第一次点击可能被丢弃
    /// （实测：点击后仍停在首页，甚至压栈后又被弹回），故整段「点卡片 → 确认落在详情页」
    /// 允许重试；重试只是重放同一个用户动作，不改变任何断言。
    private func openPlanDetail(named planName: String, tag: String) throws {
        for attempt in 1...3 {
            app.switchTab(.training)
            sleep(4)

            if tapPlanCard(named: planName, swipes: 14), planDetailIsLoaded(named: planName) {
                return
            }

            snap("\(tag)x-open-retry\(attempt)-\(planName)")
            dumpHierarchy("\(tag)x-open-retry\(attempt)-\(planName)")
            goBack()
            sleep(2)
        }

        XCTFail("应能打开计划「\(planName)」详情页（重试 3 次仍未落地）")
    }

    /// 详情页判据：`PlanDetailView` 的「训练安排」分节标题 + hero 里的计划名。
    private func planDetailIsLoaded(named planName: String) -> Bool {
        guard app.staticTexts["训练安排"].waitForExistence(timeout: 12) else { return false }
        return app.staticTexts.matching(NSPredicate(format: "label == %@", planName))
            .firstMatch.waitForExistence(timeout: 6)
    }

    private func tapPlanCard(named planName: String, swipes: Int) -> Bool {
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", planName)).firstMatch
        var attempts = 0
        while !(card.exists && card.isHittable) && attempts < swipes {
            app.windows.firstMatch.swipeUp()
            sleep(1)
            attempts += 1
        }
        guard card.exists && card.isHittable else { return false }
        card.tap()
        return true
    }

    private func activateOpenedPlan(tag: String) {
        guard tapLabel("开始此计划", timeout: 8) else {
            if app.staticTexts["当前已激活此计划"].exists { return }
            dumpHierarchy("\(tag)x-no-activate")
            XCTFail("计划详情应可激活")
            return
        }
        sleep(1)
        // 已有激活计划时是「替换」文案，按钮标题同为「确定激活」。
        _ = tapLabel("确定激活", timeout: 8)
        sleep(3)
    }

    /// 计划详情页隐藏 TabBar（`.toolbar(.hidden, for: .tabBar)`），只能逐级返回。
    private func returnToTrainingHome() {
        for _ in 0..<3 where !hasTodaySchedule {
            goBack()
            sleep(2)
        }
        sleep(3)
    }

    private var hasTodaySchedule: Bool {
        !app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS '今日安排'"))
            .allElementsBoundByIndex.isEmpty
    }

    /// `ResolvedDose.volumeText`（v34 R10/R11 紧凑口径：「m × n」或「N 球形 · 共 M 球」）。
    private func doseVolumeTexts() -> [String] {
        let predicate = NSPredicate(
            format: "label MATCHES %@ OR label MATCHES %@",
            ".*[0-9]+ × [0-9]+.*",
            ".*[0-9]+ 球形 · 共 [0-9]+ .*"
        )
        return app.staticTexts.matching(predicate).allElementsBoundByIndex.map(\.label)
    }

    // MARK: - Helpers

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
