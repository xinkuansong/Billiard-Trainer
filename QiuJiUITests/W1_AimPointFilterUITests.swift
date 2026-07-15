import XCTest

/// v7 W1/C2：完成一题瞄准点训练后，历史·统计页能筛出「瞄准点训练」记录（截图取证）。
final class W1_AimPointFilterUITests: XCTestCase {

    var app: XCUIApplication!

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w1-screenshots")
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    func testAimPointHistoryFilter() throws {
        // 1) 练一题瞄准点训练，写入 SwiftData（quizType=aimPoint）。
        app.switchTab(.angle)
        sleep(1)
        let trainTab = app.buttons["angleHomeTab_练"]
        guard trainTab.waitForExistence(timeout: 5) else {
            XCTFail("练习首页「练」分段不存在"); return
        }
        trainTab.tap()
        usleep(600_000)

        let card = app.buttons["瞄准点训练"]
        guard card.waitForExistence(timeout: 5) else {
            XCTFail("未找到瞄准点训练入口"); return
        }
        card.tap()
        sleep(2)

        let submit = app.buttons["提交瞄准点"]
        guard submit.waitForExistence(timeout: 6) else {
            XCTFail("瞄准点训练无提交按钮"); return
        }
        submit.tap()
        sleep(1)
        snap("w1-01-aimpoint-result")

        // 返回练习首页
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 3) { back.tap(); sleep(1) }

        // 2) 记录 → 统计 → 筛「瞄准点训练」
        app.switchTab(.history)
        sleep(1)
        let stats = app.descendants(matching: .any).matching(NSPredicate(format: "label == '统计'")).firstMatch
        guard stats.waitForExistence(timeout: 6) else {
            XCTFail("记录页无「统计」"); return
        }
        stats.tap()
        sleep(2)

        let filter = app.buttons["瞄准点训练"]
        // Filter chips are Buttons with Text label; also try staticTexts in case.
        let filterAny = filter.waitForExistence(timeout: 4)
            ? filter
            : app.staticTexts["瞄准点训练"]
        guard filterAny.waitForExistence(timeout: 4) else {
            // Dump visible chips for diagnosis
            snap("w1-02-stats-no-filter-chip")
            XCTFail("统计页未见「瞄准点训练」筛选项"); return
        }
        filterAny.tap()
        sleep(1)
        snap("w1-03-aimpoint-filter-selected")

        // 有数据时应显示总测试次数 ≥ 1，或至少不再是空态。
        let empty = app.staticTexts["还没有训练记录"]
        let typeEmpty = app.staticTexts["该类型暂无数据"]
        XCTAssertFalse(empty.exists && !app.staticTexts["总测试次数"].exists,
                       "筛选后仍像全局空态")
        if typeEmpty.exists {
            snap("w1-04-aimpoint-filter-empty-unexpected")
            XCTFail("已做一题但仍显示该类型暂无数据")
        }
    }
}
