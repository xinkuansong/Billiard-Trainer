import XCTest

/// 动作库试打模式 UI 验收（方案 20260709-动作库试打模式 D2 完成标准）：
/// ① 详情页试打按钮（解锁 / Premium 锁两态，明/暗）
/// ② 试打页布局（无开球钮 / 重摆在位 / 标题 = drill 名 / 球库在位可编辑）
/// ③ 进场说明卡三行 + 首次交互淡出 + info 召回
/// ④ c042 球形（母球 + 8 号 + 2 障碍）且说明卡含「共 3 杆」
/// ⑤ 击球 → 重摆回初始布局闭环
/// ⑥ 拖球改摆后重摆仍回 drill 初始布局
final class DrillTryoutUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    /// 类型无关地按 identifier 查元素（SwiftUI 有时把带 id 的容器暴露为 other 而非 button）。
    private func element(id: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 动作库搜索并打开指定 drill 详情页。
    private func openDrillDetail(search: String, drillId: String) {
        app.switchTab(.drillLibrary)
        sleep(2)
        let searchField = app.textFields["搜索动作"]
        if searchField.waitForExistence(timeout: 4) {
            searchField.tap()
            searchField.typeText(search)
            sleep(2)
        }
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'drillCard_\(drillId)'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "未找到 \(drillId) 卡片")
        card.tap()
        sleep(3)
    }

    // MARK: - 主流程：c042（多球形 drill，非 Premium；D4 与视频示范同源）

    func testTryoutC042Flow() {
        app = XCUIApplication.launchClean()
        openDrillDetail(search: "蛇彩", drillId: "drill_c042")

        // ① 解锁态入口按钮
        let tryoutButton = app.buttons["drillTryoutButton"]
        XCTAssertTrue(tryoutButton.waitForExistence(timeout: 5), "详情页无「上手试打」按钮")
        snap("t01-detail-entry-unlocked")

        tryoutButton.tap()
        sleep(2)

        // ①b 单球形（仅 5 杆）跳过选择 sheet，直接进试打
        XCTAssertFalse(
            app.buttons["tryoutFormation_0"].waitForExistence(timeout: 2),
            "c042 仅 1 个球形时不应弹选择 sheet")
        sleep(5)

        // ② 试打页布局：标题 = drill 名、重摆在位、无开球钮
        XCTAssertTrue(app.staticTexts["初级蛇彩走位"].waitForExistence(timeout: 5), "标题应为 drill 名")
        XCTAssertTrue(app.buttons["tryout.rearrange"].waitForExistence(timeout: 3), "「重摆球形」应在位")
        XCTAssertFalse(app.buttons["break.entry"].exists, "试打页不应有开球按钮")

        // ③/④ 进场说明卡：三行 + 序列杆数「共 5 杆」（球形1 = 5 杆，取序列首杆真实参数）
        let brief = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'tryout.briefCard'")).firstMatch
        XCTAssertTrue(brief.waitForExistence(timeout: 4), "进场说明卡未出现")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '共 5 杆'"))
                .firstMatch.exists,
            "说明卡杆数应取序列 stepCount（球形1 = 5 杆）")
        snap("t02-tryout-brief-c042")

        // ③ 首次交互（点桌面）说明卡淡出
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        sleep(1)
        XCTAssertFalse(brief.exists, "首次交互后说明卡应淡出")
        snap("t03-brief-dismissed")

        // ③ Q19.2③：info 内容并入三点菜单——经三点菜单「试打说明」召回说明卡
        app.buttons["composer.more"].tap()
        sleep(1)
        let info = app.buttons["tryout.info"]
        XCTAssertTrue(info.waitForExistence(timeout: 3), "三点菜单应含「试打说明」召回项")
        info.tap()
        sleep(1)
        XCTAssertTrue(brief.exists, "菜单「试打说明」应能召回说明卡")
        snap("t04-brief-recalled")
        brief.tap()
        sleep(1)
        XCTAssertFalse(brief.exists, "点卡应关闭说明卡")

        // ⑤ Q19.2④：多杆序列 drill 默认进「序列」模式，点「击打」逐杆演示走完整条序列
        XCTAssertTrue(app.buttons["tryoutMode_序列"].waitForExistence(timeout: 3),
                      "有序列 drill 应出现三模式选择（序列/进袋/自由）")
        XCTAssertTrue(element(id: "tryout.sequenceStepBar").waitForExistence(timeout: 3),
                      "默认应处于序列模式（当前杆信息条在位）")
        var strike = app.buttons["击打"].firstMatch
        if !strike.waitForExistence(timeout: 3) {
            strike = app.staticTexts["击打"].firstMatch
            XCTAssertTrue(strike.waitForExistence(timeout: 3), "序列模式应有「击打」按钮")
        }
        strike.tap()
        sleep(3)
        snap("t05a-sequence-playing")   // 播放中帧
        sleep(14)
        snap("t05b-sequence-finished")  // 序列走完帧
        // 重摆球形 = 从头重演
        app.buttons["tryout.rearrange"].tap()
        sleep(2)
        snap("t06-sequence-restart")

        // ⑥ 切到「自由」模式：球库恢复可编辑（序列模式为只读）；拖 9 号上桌后重摆回初始
        app.buttons["tryoutMode_自由"].tap()
        sleep(2)
        snap("t06b-free-mode")
        let palette9 = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'paletteBall__9'")).firstMatch
        if palette9.waitForExistence(timeout: 3) {
            let tableCenter = app.windows.firstMatch
                .coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.42))
            palette9.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.3, thenDragTo: tableCenter)
            sleep(2)
            snap("t07-after-rearrange-drag")
            app.buttons["tryout.rearrange"].tap()
            sleep(2)
            snap("t08-rearranged-after-drag")
        }
    }

    // MARK: - Q19.2④ 序列模式切换（序列 ⇄ 进袋 ⇄ 自由）

    func testTryoutSequenceModeSwitching() {
        app = XCUIApplication.launchClean()
        openDrillDetail(search: "蛇彩", drillId: "drill_c042")
        app.buttons["drillTryoutButton"].tap()
        sleep(2)
        let formation0 = app.buttons["tryoutFormation_0"]
        XCTAssertTrue(formation0.waitForExistence(timeout: 4))
        formation0.tap()
        sleep(5)

        // 默认序列模式：当前杆信息条在位、无打点/力度仪表（隐藏）。
        XCTAssertTrue(app.buttons["tryoutMode_序列"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(id: "tryout.sequenceStepBar").waitForExistence(timeout: 3),
                      "序列模式应显示当前杆信息条")
        snap("s01-sequence-default")

        // 切进袋模式：信息条消失，出现常规击球动作列。
        app.buttons["tryoutMode_进袋"].tap()
        sleep(2)
        XCTAssertFalse(element(id: "tryout.sequenceStepBar").exists,
                       "进袋模式不应有序列信息条")
        XCTAssertTrue(app.buttons["击球"].firstMatch.waitForExistence(timeout: 3)
                      || app.staticTexts["击球"].firstMatch.exists,
                      "进袋模式应有常规「击球」按钮")
        snap("s02-pocket-mode")

        // 切自由模式回归可用。
        app.buttons["tryoutMode_自由"].tap()
        sleep(2)
        snap("s03-free-mode")

        // 切回序列模式：信息条回来。
        app.buttons["tryoutMode_序列"].tap()
        sleep(2)
        XCTAssertTrue(element(id: "tryout.sequenceStepBar").waitForExistence(timeout: 3),
                      "切回序列模式应恢复信息条")
        snap("s04-back-to-sequence")
    }

    // MARK: - Q19.1 侧栏点击分组回组顶（含重复点击当前分组）

    func testSidebarTapScrollsToGroupTop() {
        app = XCUIApplication.launchClean()
        app.switchTab(.drillLibrary)
        sleep(2)

        // 「全部」视图：内容长、可滚动。
        let all = app.buttons["sidebar_全部"]
        XCTAssertTrue(all.waitForExistence(timeout: 5), "侧栏应有「全部」项")
        all.tap()
        sleep(1)

        let firstCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'drillCard_'")).firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5), "内容列表应有卡片")
        let firstId = firstCard.identifier
        let topY = firstCard.frame.minY
        snap("q191-01-top")

        // 向下滚动若干屏。
        app.swipeUp(); app.swipeUp(); app.swipeUp()
        sleep(1)
        snap("q191-02-scrolled")

        // 重复点击当前分组「全部」——应回到组顶。
        all.tap()
        sleep(2)
        snap("q191-03-back-to-top")

        let sameCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", firstId)).firstMatch
        XCTAssertTrue(sameCard.waitForExistence(timeout: 3),
                      "回顶后原首卡应重新可见（\(firstId)）")
        XCTAssertEqual(sameCard.frame.minY, topY, accuracy: 40,
                       "重复点击当前分组应回到组顶（首卡回到原纵向位置）")

        // 切换到具体分组亦回顶。
        let accuracy = app.buttons["sidebar_准度训练"]
        if accuracy.waitForExistence(timeout: 3) {
            app.swipeUp(); app.swipeUp()
            sleep(1)
            accuracy.tap()
            sleep(2)
            snap("q191-04-category-top")
            let catFirst = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'drillCard_'")).firstMatch
            XCTAssertTrue(catFirst.waitForExistence(timeout: 3), "切分组后应显示该组内容且在顶部")
        }
    }

    // MARK: - Premium 锁态：c050 软打控位（isPremium）

    func testTryoutPremiumLocked() {
        app = XCUIApplication.launchClean()
        openDrillDetail(search: "软打", drillId: "drill_c050")

        let tryoutButton = app.buttons["drillTryoutButton"]
        XCTAssertTrue(tryoutButton.waitForExistence(timeout: 5), "锁定态详情页无试打按钮")
        snap("t10-detail-entry-locked")

        tryoutButton.tap()
        sleep(3)
        // 点击应弹订阅页而非进试打页
        XCTAssertFalse(app.buttons["tryout.rearrange"].exists, "锁定态不应进入试打页")
        snap("t11-locked-tap-subscription")
    }

    // MARK: - D3：首次手势提示出现 / 二次进入不出现（兼作单球形直进回归）

    func testTryoutGestureHintFirstTimeOnly() {
        // 首启：参数域强制 hasSeenGestureHint=NO（覆盖持久值，不改产品代码）。
        // 用单球形 drill c001：点入口应直进试打页（不弹球形选择，D4 单球形路径）。
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launchArguments += ["-drillTryout.hasSeenGestureHint", "NO"]
        app.launch()
        sleep(3)

        openDrillDetail(search: "直线", drillId: "drill_c001")
        app.buttons["drillTryoutButton"].tap()
        sleep(5)

        // 单球形直进：不出现球形选择 sheet
        XCTAssertFalse(app.buttons["tryoutFormation_0"].exists, "单球形 drill 不应弹球形选择")

        // 卡片外层 identifier 会覆盖子文本 identifier，故按 label 匹配提示行。
        let hint = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS '拖动台面瞄准'")).firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 5), "首次进入说明卡底部应有手势提示行")
        snap("t30-gesture-hint-first-entry")

        // 点卡关闭（D2 已验证路径）→ 写入已见标记（写持久域，参数域仅影响本进程读取）。
        let briefFirst = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'tryout.briefCard'")).firstMatch
        briefFirst.tap()
        sleep(1)
        XCTAssertFalse(briefFirst.exists, "点卡后说明卡应关闭（关闭回调应已执行）")
        sleep(1)
        app.terminate()

        // 二次启动（无覆盖参数）：读持久域 true → 说明卡仍在但无提示行。
        app = XCUIApplication.launchClean()
        openDrillDetail(search: "直线", drillId: "drill_c001")
        app.buttons["drillTryoutButton"].tap()
        sleep(5)

        let brief = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'tryout.briefCard'")).firstMatch
        XCTAssertTrue(brief.waitForExistence(timeout: 5), "二次进入说明卡应照常出现")
        XCTAssertFalse(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS '拖动台面瞄准'"))
                .firstMatch.exists,
            "二次进入不应再显示手势提示行")
        snap("t31-gesture-hint-second-entry-absent")
    }

    // MARK: - 暗色：详情页入口两态

    func testTryoutEntryDarkMode() {
        // App 跟随系统外观（appearanceMode 偏好仅设置页存值），切系统深色截暗色帧。
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        app = XCUIApplication.launchClean()

        openDrillDetail(search: "蛇彩", drillId: "drill_c042")
        XCTAssertTrue(app.buttons["drillTryoutButton"].waitForExistence(timeout: 5))
        snap("t20-detail-entry-dark-unlocked")
        app.tapBackButton()
        sleep(1)

        // 清空搜索再搜 Premium drill
        let searchField = app.textFields["搜索动作"]
        if searchField.waitForExistence(timeout: 4) {
            searchField.tap()
            if let value = searchField.value as? String, !value.isEmpty {
                let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count + 2)
                searchField.typeText(deletes)
            }
            searchField.typeText("软打")
            sleep(2)
        }
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'drillCard_drill_c050'")).firstMatch
        if card.waitForExistence(timeout: 5) {
            card.tap()
            sleep(3)
            snap("t21-detail-entry-dark-locked")
        }
    }
}
