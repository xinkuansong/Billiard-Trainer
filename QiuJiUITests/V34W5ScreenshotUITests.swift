import XCTest

/// v34 W5：计划页逐球形明细 + 训练页三级进度 / 分节 / 添加一组 → `build/v34-w5-logs/`
final class V34W5ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v34-w5-logs"
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    /// ① 计划页动作条目 + 逐球形明细（c026 多球形）
    func testW5_planDetail_perFormationDose() {
        let app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-deeplink.planDetail=plan_separation",
            "-uitest.expandPlanWeek1",
            "-uitest.expandPlanDrill=drill_c026",
        ])
        sleep(3)

        let detail = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "planDrillDoseDetail-drill_c026"))
            .firstMatch
        XCTAssertTrue(
            detail.waitForExistence(timeout: 12),
            "计划页应展开 c026 逐球形明细"
        )
        // 滚入镜头
        app.swipeUp()
        usleep(400_000)
        savePNG(app, "01-plan-detail-c026-dose")
    }

    /// ② 训练页多球形：三级进度 + 分节头
    func testW5_activeTraining_multiFormationProgress() {
        let app = launchTraining(drillId: "drill_c026", forcePremium: false)
        assertHost(app)

        let progress = progressElement(in: app)
        XCTAssertTrue(progress.waitForExistence(timeout: 12), "应显示三级进度指示\n\(app.debugDescription)")
        let label = progress.label
        XCTAssertTrue(
            label.contains("球形") && label.contains("位置") && label.contains("颗"),
            "多球形进度文案不符：\(label)"
        )

        // 先截顶栏三级进度，再轻滚露出组网格分节头（勿滚穿）
        savePNG(app, "02-training-multi-formation-progress")
        app.swipeUp()
        usleep(400_000)
        let section = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "formationSectionHeader"))
            .firstMatch
        let sectionByLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "分节")
        ).firstMatch
        let sectionFound = section.waitForExistence(timeout: 4) || sectionByLabel.waitForExistence(timeout: 2)
        if sectionFound {
            savePNG(app, "02b-training-multi-formation-sections")
        }
        XCTAssertTrue(sectionFound, "多球形应按球形分节\n\(app.debugDescription)")
    }

    /// ③ 走位链只报「第几轮」
    func testW5_activeTraining_sequenceRoundOnly() {
        let app = launchTraining(drillId: "drill_c039", forcePremium: true)
        assertHost(app)

        let progress = progressElement(in: app)
        XCTAssertTrue(progress.waitForExistence(timeout: 12), "应显示走位链进度\n\(app.debugDescription)")
        let label = progress.label
        XCTAssertTrue(
            label.contains("轮") && !label.contains("颗"),
            "走位链应只报轮：\(label)"
        )
        XCTAssertFalse(label.contains("位置"), "走位链不应报位置：\(label)")

        savePNG(app, "03-training-sequence-round")
    }

    /// ④「添加一组」复制当前位置（前后对照）
    func testW5_activeTraining_addSetCopiesCurrent() {
        let app = launchTraining(drillId: "drill_c001", forcePremium: false)
        assertHost(app)

        let add = app.buttons["添加一组"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 12), "应有「添加一组」\n\(app.debugDescription)")

        savePNG(app, "04a-training-add-set-before")

        add.tap()
        usleep(500_000)

        savePNG(app, "04b-training-add-set-after")
    }

    /// ⑤（W6 走查）开始计划后主页「今日安排」→ `build/v34-w6-logs/`
    func testW6_todaySchedule_afterPlanStart() throws {
        let w6Dir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v34-w6-logs")
        try FileManager.default.createDirectory(at: w6Dir, withIntermediateDirectories: true)

        // 第一段：deeplink 直达计划页并激活计划（SwiftData 持久化跨启动保留）。
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.planDetail=plan_beginner"])
        sleep(3)
        let start = app.buttons["开始此计划"].firstMatch
        if start.waitForExistence(timeout: 12), start.isHittable {
            start.tap()
            sleep(2)
        }
        // 已激活过（重复执行）时按钮可能不在；两种情况都继续走第二段。
        app.terminate()

        // 第二段：干净启动主页，应显示今日安排。
        let home = XCUIApplication.launchClean(extraArgs: [])
        sleep(3)
        let today = home.staticTexts["今日安排"].firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 12), "主页应显示今日安排\n\(home.debugDescription)")

        let shot = home.screenshot()
        try shot.pngRepresentation.write(to: w6Dir.appendingPathComponent("today-schedule-active-plan.png"))
        print("[W6-SCREENSHOT] today-schedule-active-plan.png")
    }

    private func launchTraining(drillId: String, forcePremium: Bool) -> XCUIApplication {
        var args = ["-deeplink.activeTraining=\(drillId)"]
        if forcePremium { args.append("-forcePremium") }
        let app = XCUIApplication.launchClean(extraArgs: args)
        sleep(2)
        return app
    }

    private func assertHost(_ app: XCUIApplication) {
        let host = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "v34w5ActiveTrainingHost"))
            .firstMatch
        XCTAssertTrue(host.waitForExistence(timeout: 8), "deeplink 应进入训练宿主\n\(app.debugDescription)")
        // 默认总览；切到单项视图才有三级进度与组网格。
        let switchBtn = app.buttons["切换到单项视图"].firstMatch
        if switchBtn.waitForExistence(timeout: 4), switchBtn.isHittable {
            switchBtn.tap()
            usleep(400_000)
        }
    }

    private func progressElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "activeTrainingSetProgress"))
            .firstMatch
    }

    private func savePNG(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let url = outDir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            print("[W5-SCREENSHOT] \(url.path)")
        } catch {
            XCTFail("写截图失败 \(name): \(error)")
        }
    }
}
