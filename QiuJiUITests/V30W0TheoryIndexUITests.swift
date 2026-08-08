import XCTest

/// v30 W0 / v32.2：理区每篇一卡直达详情（不再经「球理」索引总卡）。
///
/// 外观切换：事先 `xcrun simctl ui booted appearance light|dark`，再分别跑 light / dark 用例。
/// 截图落盘 `build/v30-w0-screenshots/`。
final class V30W0TheoryIndexUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v30-w0-screenshots"
    )

    /// 与 `TheoryCatalog` 已上线条目标题一致（accessibilityIdentifier = title）。
    private let publishedCardTitles = [
        "30° 法则",
        "90° 法则",
        "切线法则",
        "母球速度分级",
        "最少加塞原则",
        "反向规划",
        "关键球原理",
        "球团管理",
        "风险报酬决策矩阵",
        "安全球三维度模型",
        "清台 5 步决策流程",
        "清台速查手册",
    ]

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        app = XCUIApplication.launchClean()
    }

    func testV30W0_TheoryIndexLight() {
        captureAndVerify(suffix: "Light")
    }

    func testV30W0_TheoryIndexDark() {
        captureAndVerify(suffix: "Dark")
    }

    private func captureAndVerify(suffix: String) {
        app.switchTab(.angle)

        // 学区不应有球理总卡，也不应有定理卡（定理只在理区）。
        let learn = app.descendants(matching: .any)["angleHomeTab_学"]
        XCTAssertTrue(learn.waitForExistence(timeout: 10), "练习 Tab「学」侧栏应出现")
        learn.tap()
        sleep(1)
        savePNG("practice-learn-no-theory-card-\(suffix)")
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", "球理"))
                .firstMatch.exists,
            "学区不应再有球理入口卡"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", "切线法则"))
                .firstMatch.exists,
            "学区不应出现理区定理卡"
        )

        XCTAssertTrue(TheoryIndexNavigation.openTheorySection(in: app))
        sleep(1)
        // 首页不再放「球理」总卡。
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", "球理"))
                .firstMatch.exists,
            "理区不应再有「球理」索引总卡（v32.2）"
        )
        savePNG("practice-theory-grid-\(suffix)")

        // 12 张已上线卡均可定位（必要时滚动）。
        for title in publishedCardTitles {
            let card = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", title))
                .firstMatch
            var scrolls = 0
            while !card.exists, scrolls < 10 {
                app.swipeUp(velocity: .slow)
                scrolls += 1
            }
            XCTAssertTrue(card.waitForExistence(timeout: 3), "理区应有卡片「\(title)」")
        }
        savePNG("practice-theory-grid-scrolled-\(suffix)")

        // 点一篇直达详情（不再经索引页）。
        XCTAssertTrue(
            TheoryIndexNavigation.openPage(
                in: app,
                cardTitle: "切线法则",
                navigationTitle: "切线法则"
            )
        )
        sleep(1)
        savePNG("theory-t03-from-home-\(suffix)")
    }

    /// 12 篇全部上线：理区卡数与清单一致（替代旧「索引页无置灰行」断言）。
    func testV30W4_NoUpcomingEntriesRemain() {
        XCTAssertEqual(publishedCardTitles.count, 12, "v30 W4 起应有 12 张理区卡")
        XCTAssertTrue(TheoryIndexNavigation.openTheorySection(in: app))
        for title in publishedCardTitles {
            let card = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", title))
                .firstMatch
            var scrolls = 0
            while !card.exists, scrolls < 10 {
                app.swipeUp(velocity: .slow)
                scrolls += 1
            }
            XCTAssertTrue(card.exists, "理区应有「\(title)」")
        }
        savePNG("theory-home-12-cards")
    }

    private func savePNG(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: outDir.appendingPathComponent("\(name).png"))
    }
}
