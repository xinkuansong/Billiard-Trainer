import XCTest

/// v30 W0：球理入口卡 → 索引页导航 + 未上线条目不可点（无死链）验收。
///
/// 外观切换：事先 `xcrun simctl ui booted appearance light|dark`，再分别跑 light / dark 用例。
/// 截图落盘 `build/v30-w0-screenshots/`。
final class V30W0TheoryIndexUITests: XCTestCase {

    private let outDir = URL(
        fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v30-w0-screenshots"
    )

    /// 与 `TheoryCatalog` 一致的 12 条 id。
    private let allPageIDs = [
        "t01", "t02", "t03", "t04", "t05", "t06", "t07", "t08", "t09", "t10", "flow", "quickRef",
    ]

    /// 已上线（详情页已在 `MainTabView.theoryDestination` 注册）→ 应是可点链接。
    ///
    /// ⚠️ W1–W4 每上线一页，把该 id 从「未上线」搬到这里（与 `TheoryCatalog.isPublished`
    /// 及 `theoryDestination` 的 switch 三处成对维护）。**不要删除本用例的分治断言**。
    private let publishedPageIDs = ["t03", "t08"]

    /// 未上线 → 应是置灰行、无可点入口（防死链）。
    private var upcomingPageIDs: [String] {
        allPageIDs.filter { !publishedPageIDs.contains($0) }
    }

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

        let learn = app.descendants(matching: .any)["angleHomeTab_学"]
        XCTAssertTrue(learn.waitForExistence(timeout: 10), "练习 Tab「学」侧栏应出现")
        learn.tap()
        sleep(1)
        savePNG("practice-learn-with-theory-card-\(suffix)")

        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "球理"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 6), "「学」分组应有球理入口卡")
        card.tap()

        XCTAssertTrue(
            app.navigationBars["球理"].waitForExistence(timeout: 6),
            "入口卡应 push 到球理索引页"
        )
        sleep(1)
        savePNG("theory-index-top-\(suffix)")

        // 四个分组头齐全。
        for group in ["碰撞与瞄准", "旋转与走位", "战术与决策", "流程与速查"] {
            XCTAssertTrue(
                app.descendants(matching: .any)["theoryGroup_\(group)"].exists,
                "索引页应有分组「\(group)」"
            )
        }

        // 12 条全量呈现，按上线状态分治：
        // 已上线 → 有可点入口、无置灰行；未上线 → 置灰行、无可点入口（防死链）。
        for pageID in publishedPageIDs {
            XCTAssertTrue(
                app.descendants(matching: .any)["theoryEntry_\(pageID)"]
                    .waitForExistence(timeout: 3),
                "\(pageID) 详情页已注册，索引页应有可点入口"
            )
            XCTAssertFalse(
                app.descendants(matching: .any)["theoryEntryUpcoming_\(pageID)"].exists,
                "\(pageID) 已上线，不应再显示「即将上线」置灰行"
            )
        }
        for pageID in upcomingPageIDs {
            let upcoming = app.descendants(matching: .any)["theoryEntryUpcoming_\(pageID)"]
            XCTAssertTrue(upcoming.exists, "\(pageID) 条目应出现在索引页（全量列 12 条）")
            XCTAssertFalse(
                app.descendants(matching: .any)["theoryEntry_\(pageID)"].exists,
                "\(pageID) 尚未注册详情页，不应有可点入口（防死链）"
            )
        }

        app.swipeUp()
        sleep(1)
        savePNG("theory-index-bottom-\(suffix)")

        // 点未上线条目：不应离开索引页（无死链）。
        let firstUpcoming = app.descendants(matching: .any)["theoryEntryUpcoming_t01"]
        if firstUpcoming.exists && firstUpcoming.isHittable {
            firstUpcoming.tap()
            sleep(1)
        }
        XCTAssertTrue(
            app.navigationBars["球理"].exists,
            "点击「即将上线」条目不应发生导航"
        )
        savePNG("theory-index-upcoming-tap-noop-\(suffix)")
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
