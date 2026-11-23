import XCTest

/// v22 W6：四套专项货架收口截图 → `build/v22-w6-screenshots/`
/// 列表可见：准度（免 PRO）+ 力度/分离角/加塞（带 PRO）；合计 ≥4 帧。
final class V22W6ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v22-w6-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW6_fourSpecialtyPlansListScreenshots() {
        app.switchTab(.training)
        sleep(2)

        openPlanList()
        sleep(2)

        // 01 准度专项（免费钩子，无 PRO）
        scrollToExactLabel("准度专项")
        savePNG("01-plan-list-accuracy-free")

        // 02 力度控制专项（Pro）
        scrollToExactLabel("力度控制专项")
        savePNG("02-plan-list-force-pro")

        // 03 分离角专项（Pro）
        scrollToExactLabel("分离角专项")
        savePNG("03-plan-list-separation-pro")

        // 04 加塞专项（Pro；勿误点「高级专项：加塞与多库」）
        scrollToExactLabel("加塞专项")
        savePNG("04-plan-list-english-pro")

        // 05 点进加塞专项详情（与「高级综合」区分）
        let englishCard = app.staticTexts.matching(
            NSPredicate(format: "label == '加塞专项'")
        ).firstMatch
        XCTAssertTrue(englishCard.isHittable, "加塞专项应可点；debug=\(staticTextLabelsDebug())")
        englishCard.tap()

        let unlockCTA = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '解锁此计划'")
        ).firstMatch
        let arrange = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '训练安排'")
        ).firstMatch
        let detailHero = app.staticTexts.matching(
            NSPredicate(format: "label == '加塞专项'")
        ).firstMatch

        var detailReady = false
        for _ in 0..<20 {
            if unlockCTA.exists || arrange.exists || detailHero.exists {
                detailReady = true
                break
            }
            usleep(500_000)
        }
        XCTAssertTrue(
            detailReady,
            "应进入加塞专项详情；debug=\(buttonLabelsDebug()) | \(staticTextLabelsDebug())"
        )
        savePNG("05-plan-english-detail")
    }

    // MARK: - Helpers

    private func scrollToExactLabel(_ label: String) {
        let card = app.staticTexts.matching(
            NSPredicate(format: "label == %@", label)
        ).firstMatch
        var found = false
        for _ in 0..<24 {
            if card.exists, card.isHittable {
                found = true
                break
            }
            swipeWindowUp()
            usleep(350_000)
        }
        XCTAssertTrue(found, "计划列表应滚到「\(label)」；debug=\(staticTextLabelsDebug())")
    }

    private func swipeWindowUp() {
        let win = app.windows.firstMatch
        guard win.exists else {
            app.swipeUp()
            return
        }
        let start = win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let end = win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func buttonLabelsDebug() -> String {
        let buttons = app.buttons.allElementsBoundByIndex
        let labels = (0..<min(buttons.count, 20)).compactMap { buttons[$0].label }
        return labels.joined(separator: " | ")
    }

    private func staticTextLabelsDebug() -> String {
        let texts = app.staticTexts.allElementsBoundByIndex
        let labels = (0..<min(texts.count, 40)).compactMap { texts[$0].label }
        return labels.joined(separator: " | ")
    }

    private func openPlanList() {
        let menu = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'ellipsis' OR label CONTAINS 'More' OR label CONTAINS '更多'")
        ).firstMatch
        if menu.waitForExistence(timeout: 4) {
            menu.tap()
            usleep(500_000)
        }
        let planList = app.buttons["训练计划"]
        if planList.waitForExistence(timeout: 3) {
            planList.tap()
            return
        }
        let card = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '训练计划'")).firstMatch
        if card.waitForExistence(timeout: 3) {
            card.tap()
        }
    }

    private func savePNG(_ name: String) {
        let shot = app.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
        try? shot.pngRepresentation.write(to: outDir.appendingPathComponent("\(name).png"))
    }
}
