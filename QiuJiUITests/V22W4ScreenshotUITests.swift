import XCTest

/// v22 W4：分离角专项计划列表/详情截图 → `build/v22-w4-screenshots/`
final class V22W4ScreenshotUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v22-w4-screenshots"
    )

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testW4_planSeparationListAndDetailScreenshots() {
        app.switchTab(.training)
        sleep(2)

        openPlanList()
        sleep(2)

        // 列表应出现「分离角专项」（L2；Pro；LazyVStack 需边滚边找）
        let sepCard = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '分离角专项'")
        ).firstMatch
        var listed = false
        for _ in 0..<18 {
            if sepCard.exists, sepCard.isHittable {
                listed = true
                break
            }
            app.swipeUp()
            usleep(400_000)
        }
        XCTAssertTrue(listed, "计划列表应滚到「分离角专项」；debug=\(staticTextLabelsDebug())")
        savePNG("01-plan-list-separation")

        sepCard.tap()
        sleep(3)

        // 滚到训练安排；chapterHeader 用 children.combine，theme 在 button label
        for _ in 0..<4 {
            app.swipeUp()
            usleep(350_000)
        }

        let week1Row = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH '第 1 周' AND label CONTAINS '规则'")
        ).firstMatch
        XCTAssertTrue(
            week1Row.waitForExistence(timeout: 8),
            "详情应可见 W1 手风琴（含 theme「…规则」）；debug=\(buttonLabelsDebug())"
        )
        savePNG("02-plan-separation-detail-week1-theme")

        // 底部 CTA 的 Spacer 挡 hit-test；用 accessibility tap（非 coordinate）才能点到手风琴
        week1Row.tap()
        sleep(2)

        let day1 = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '第 1 天'")
        ).firstMatch
        if !day1.waitForExistence(timeout: 3) {
            let themeText = app.staticTexts.matching(
                NSPredicate(format: "label == '90° 规则' OR label CONTAINS '90° 规则'")
            ).firstMatch
            if themeText.exists { themeText.tap() }
            else { week1Row.tap() }
            sleep(2)
        }
        XCTAssertTrue(
            day1.waitForExistence(timeout: 4),
            "展开后应见「第 1 天」；debug=\(buttonLabelsDebug()) | \(staticTextLabelsDebug())"
        )

        // 展开后内容可能被底部 CTA 遮一点，轻推露出 drill 名
        app.swipeUp()
        usleep(400_000)
        savePNG("03-plan-separation-week1-expanded")

        let drillHit = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "label CONTAINS '分离角90' OR label CONTAINS '90度规则' OR label CONTAINS '直线出杆' OR label CONTAINS '专项训练' OR label CONTAINS '热身'"
            )
        ).firstMatch
        XCTAssertTrue(
            drillHit.waitForExistence(timeout: 6),
            "展开后应看到分离角专项 drill/阶段名；debug=\(staticTextLabelsDebug())"
        )
    }

    // MARK: - Helpers

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
