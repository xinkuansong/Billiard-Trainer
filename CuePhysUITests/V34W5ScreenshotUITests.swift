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
            label.contains("球形") && label.contains("杆") && label.contains("颗"),
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

    /// ③ 走位链报「第 r 遍 · 第 k/n 杆」
    func testW5_activeTraining_sequenceRoundOnly() {
        let app = launchTraining(drillId: "drill_c039", forcePremium: true)
        assertHost(app)

        let progress = progressElement(in: app)
        XCTAssertTrue(progress.waitForExistence(timeout: 12), "应显示走位链进度\n\(app.debugDescription)")
        let label = progress.label
        XCTAssertTrue(
            label.contains("遍") && label.contains("杆") && !label.contains("颗"),
            "走位链应报遍+链内杆位：\(label)"
        )
        XCTAssertFalse(label.contains("位置"), "走位链不应报位置：\(label)")

        savePNG(app, "03-training-sequence-round")
    }

    /// ④「添加一组」出杆号选择（v34 后续：c001 单球形重复型 → 平铺「杆1…杆5」菜单）
    func testW5_activeTraining_addSetCopiesCurrent() {
        let app = launchTraining(drillId: "drill_c001", forcePremium: false)
        assertHost(app)

        let add = app.buttons["添加一组"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 12), "应有「添加一组」\n\(app.debugDescription)")

        savePNG(app, "04a-training-add-set-before")

        add.tap()
        usleep(500_000)

        // 重复型加组先选打第几杆。
        let shotItem = app.buttons["杆2"].firstMatch
        XCTAssertTrue(shotItem.waitForExistence(timeout: 6), "加组菜单应有杆号选项\n\(app.debugDescription)")
        savePNG(app, "04b-training-add-set-menu")
        shotItem.tap()
        usleep(500_000)

        savePNG(app, "04c-training-add-set-after")
    }

    /// ⑥ 球台示意球形切换（v34 后续）：详情页多球形出切换胶囊，点击后选中态迁移。
    func testW5_drillDetail_formationSwitcher() {
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.drillDetail=drill_c026"])
        sleep(3)

        let chip2 = app.buttons["formationSwitchChip_manual02"].firstMatch
        XCTAssertTrue(chip2.waitForExistence(timeout: 12), "详情页应有球形切换胶囊\n\(app.debugDescription)")
        savePNG(app, "05a-detail-formation-1")

        chip2.tap()
        sleep(2)
        XCTAssertTrue(chip2.label.contains("当前球形"), "点击后应选中球形2：\(chip2.label)")
        savePNG(app, "05b-detail-formation-2")
    }

    /// v39 W1：基本功含 c023 的一天（第 2 周第 3 天）。
    func testW1_planBeginner_c023_day() {
        let w1Dir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v39-w1-logs")
        try? FileManager.default.createDirectory(at: w1Dir, withIntermediateDirectories: true)
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.planDetail=plan_beginner"])
        let row = scrollToIdentifier(app, "planDrillRow-drill_c023")
        XCTAssertTrue(row.exists, "基本功计划页应出现 c023 行")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "用户裁定")).firstMatch.exists)
        savePNG(app, "01-plan-beginner-c023-day", to: w1Dir)
    }

    /// v39 W1b：杆法Ⅰ含斯登 c016 的一天（单球形，第二行应为「球形1 + 模式 + m × n」）。
    func testW1b_planCueball_c016_singleFormation() {
        let w1bDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v39-w1b-logs")
        try? FileManager.default.createDirectory(at: w1bDir, withIntermediateDirectories: true)
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.planDetail=plan_cueball"])
        let row = scrollToIdentifier(app, "planDrillRow-drill_c016")
        XCTAssertTrue(row.exists, "杆法Ⅰ计划页应出现 c016 行")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "球形1")).firstMatch.exists
                || row.label.contains("球形1"),
            "单球形第二行应含「球形1」，不得只剩光秃 m × n：\(row.label)"
        )
        XCTAssertTrue(
            row.label.contains("逐位重复") || row.label.contains("整链走位")
                || app.staticTexts.matching(NSPredicate(format: "label == %@", "逐位重复")).firstMatch.exists
                || app.staticTexts.matching(NSPredicate(format: "label == %@", "整链走位")).firstMatch.exists,
            "单球形第二行应含模式标签：\(row.label)"
        )
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "用户裁定")).firstMatch.exists)
        savePNG(app, "01-plan-cueball-c016-single", to: w1bDir)
    }

    /// v39 W1b：杆法Ⅰ含高杆跟进 c003 的一天（多球形默认展开，「N 球形」与动作名同行）。
    func testW1b_planCueball_c003_multiExpanded() {
        let w1bDir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v39-w1b-logs")
        try? FileManager.default.createDirectory(at: w1bDir, withIntermediateDirectories: true)
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.planDetail=plan_cueball"])
        let row = scrollToIdentifier(app, "planDrillRow-drill_c003")
        XCTAssertTrue(row.exists, "杆法Ⅰ计划页应出现 c003 行")
        let detail = scrollToIdentifier(app, "planDrillDoseDetail-drill_c003")
        XCTAssertTrue(detail.exists, "c003 多球形明细应展开")
        XCTAssertTrue(
            row.label.contains("球形") || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "球形")).firstMatch.exists,
            "多球形条目应含「N 球形」：\(row.label)"
        )
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "用户裁定")).firstMatch.exists)
        savePNG(app, "02-plan-cueball-c003-multi", to: w1bDir)
    }

    /// v39 W7：R5 单球形回归截图 → `build/v39-w7-logs/`（杆法Ⅰ c016 斯登母球控制）。
    func testW7_r5_c016_singleFormation() {
        let w7Dir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v39-w7-logs")
        try? FileManager.default.createDirectory(at: w7Dir, withIntermediateDirectories: true)
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.planDetail=plan_cueball"])
        let row = scrollToIdentifier(app, "planDrillRow-drill_c016")
        XCTAssertTrue(row.exists, "杆法Ⅰ计划页应出现 c016 行")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "球形1")).firstMatch.exists
                || row.label.contains("球形1"),
            "单球形第二行应含「球形1」，不得只剩光秃 m × n：\(row.label)"
        )
        XCTAssertTrue(
            row.label.contains("逐位重复") || row.label.contains("整链走位")
                || app.staticTexts.matching(NSPredicate(format: "label == %@", "逐位重复")).firstMatch.exists
                || app.staticTexts.matching(NSPredicate(format: "label == %@", "整链走位")).firstMatch.exists,
            "单球形第二行应含模式标签：\(row.label)"
        )
        // 底栏「已激活」会挡住最下一行剂量；再轻滚，让 c016 第二行完整入镜。
        app.swipeUp()
        usleep(350_000)
        savePNG(app, "w7-r5-c016-single", to: w7Dir)
    }

    /// v39 W7：R5 多球形回归截图 → `build/v39-w7-logs/`（杆法Ⅰ c003，「N 球形」与动作名同行）。
    func testW7_r5_c003_multiExpanded() {
        let w7Dir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v39-w7-logs")
        try? FileManager.default.createDirectory(at: w7Dir, withIntermediateDirectories: true)
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.planDetail=plan_cueball"])
        let row = scrollToIdentifier(app, "planDrillRow-drill_c003")
        XCTAssertTrue(row.exists, "杆法Ⅰ计划页应出现 c003 行")
        let detail = scrollToIdentifier(app, "planDrillDoseDetail-drill_c003")
        XCTAssertTrue(detail.exists, "c003 多球形明细应展开")
        XCTAssertTrue(
            row.label.contains("球形") || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "球形")).firstMatch.exists,
            "多球形条目应含「N 球形」：\(row.label)"
        )
        savePNG(app, "w7-r5-c003-multi", to: w7Dir)
    }

    /// v39 W7：分离角 W1 摊周截图（只 90°/厚/薄，后 7 条首次不在第 1 周）。
    func testW7_planSeparation_w1() {
        let w7Dir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v39-w7-logs")
        try? FileManager.default.createDirectory(at: w7Dir, withIntermediateDirectories: true)
        let app = XCUIApplication.launchClean(extraArgs: [
            "-forcePremium",
            "-deeplink.planDetail=plan_separation",
        ])
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "90°")).firstMatch.waitForExistence(timeout: 12)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "90")).firstMatch.waitForExistence(timeout: 2),
            "分离角第 1 周主题应含 90°/厚/薄"
        )
        // 收起后周，镜头停在 W1，避免后 7 条首次挤进同一帧。
        for week in [4, 3, 2] {
            let header = app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@", "第 \(week) 周")
            ).firstMatch
            if header.waitForExistence(timeout: 2), header.isHittable {
                header.tap()
                usleep(300_000)
            }
        }
        let c024 = scrollToIdentifier(app, "planDrillRow-drill_c024")
        XCTAssertTrue(c024.exists, "W1 应有 90°（c024）")
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", "planDrillRow-drill_c026"))
                .firstMatch.exists
                || app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", "planDrillRow-drill_c025"))
                .firstMatch.exists,
            "W1 应有厚（c026）或薄（c025）"
        )
        savePNG(app, "w7-plan-separation-w1", to: w7Dir)
    }

    /// 计划行动作名单行：准度Ⅰ「底袋小角度」不得折成两行。
    func testPlanAccuracy_c013_nameSingleLine() {
        let out = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v39-name-oneline-logs")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.planDetail=plan_accuracy"])
        let row = scrollToIdentifier(app, "planDrillRow-drill_c013")
        XCTAssertTrue(row.exists, "准度Ⅰ计划页应出现 c013 行")
        XCTAssertTrue(
            app.staticTexts["底袋小角度"].firstMatch.exists,
            "动作名应作为完整单行文案上屏，不得拆成「底袋小角度入」+「袋」"
        )
        savePNG(app, "c013-name-single-line", to: out)
    }

    /// v39 W1：含 c022 的一天（第 4 周第 1 天），多球形明细默认展开。
    func testW1_planBeginner_c022_expanded() {
        let w1Dir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v39-w1-logs")
        try? FileManager.default.createDirectory(at: w1Dir, withIntermediateDirectories: true)
        let app = XCUIApplication.launchClean(extraArgs: ["-deeplink.planDetail=plan_beginner"])
        let row = scrollToIdentifier(app, "planDrillRow-drill_c022")
        XCTAssertTrue(row.exists, "基本功计划页应出现 c022 行")
        let detail = scrollToIdentifier(app, "planDrillDoseDetail-drill_c022")
        XCTAssertTrue(detail.exists, "c022 多球形明细应展开")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "用户裁定")).firstMatch.exists)
        savePNG(app, "02-plan-beginner-c022-expanded", to: w1Dir)
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

    private func scrollToIdentifier(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let el = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", identifier))
            .firstMatch
        if el.waitForExistence(timeout: 8), el.isHittable { return el }
        for _ in 0..<16 {
            app.swipeUp()
            usleep(250_000)
            if el.exists, el.isHittable { return el }
        }
        return el
    }

    private func savePNG(_ app: XCUIApplication, _ name: String, to directory: URL? = nil) {
        let shot = app.screenshot()
        let dir = directory ?? outDir
        let url = dir.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            print("[SCREENSHOT] \(url.path)")
        } catch {
            XCTFail("写截图失败 \(name): \(error)")
        }
    }
}
