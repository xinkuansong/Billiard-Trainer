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
    /// ⚠️ 每上线一页，把该 id 从「未上线」搬到这里（与 `TheoryCatalog.isPublished`
    /// 及 `theoryDestination` 的 switch 三处成对维护）。**不要删除本用例的分治断言**。
    /// v30 W4 起 **12 条全部上线**，置灰集合为空——此时下面的置灰循环会退化成空转，
    /// 故另加一条**显式断言置灰集合为空**（`testV30W4_NoUpcomingEntriesRemain`），
    /// 避免「永远为真的空用例」冒充覆盖。
    private let publishedPageIDs = [
        "t01", "t02", "t03", "t04", "t05", "t06", "t07", "t08", "t09", "t10", "flow", "quickRef",
    ]

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

        if let firstUpcoming = upcomingPageIDs.first {
            // 仍有未上线条目时：点它不应离开索引页（无死链）。
            let row = app.descendants(matching: .any)["theoryEntryUpcoming_\(firstUpcoming)"]
            if row.exists && row.isHittable {
                row.tap()
                sleep(1)
            }
            XCTAssertTrue(
                app.navigationBars["球理"].exists,
                "点击「即将上线」条目不应发生导航"
            )
            savePNG("theory-index-upcoming-tap-noop-\(suffix)")
        }
    }

    /// v30 W4：12 条全部上线后，上面的置灰循环会退化为空转。
    /// 这里**显式**断言置灰集合为空——既守住「不该再有置灰行」，
    /// 也让日后新增未上线页时必须回来更新清单（而不是悄悄空转过去）。
    func testV30W4_NoUpcomingEntriesRemain() {
        XCTAssertEqual(
            upcomingPageIDs, [],
            "v30 W4 起 12 篇应全部上线；若新增了未上线页，请更新 publishedPageIDs 并恢复置灰用例覆盖"
        )

        app.switchTab(.angle)
        let learn = app.descendants(matching: .any)["angleHomeTab_学"]
        XCTAssertTrue(learn.waitForExistence(timeout: 10), "练习 Tab「学」侧栏应出现")
        learn.tap()
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "球理"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 6), "「学」分组应有球理入口卡")
        card.tap()
        XCTAssertTrue(app.navigationBars["球理"].waitForExistence(timeout: 6), "应进入球理索引页")

        // 屏幕上也不应再出现任何一条置灰行。
        for pageID in allPageIDs {
            XCTAssertFalse(
                app.descendants(matching: .any)["theoryEntryUpcoming_\(pageID)"].exists,
                "\(pageID) 不应再显示「即将上线」置灰行"
            )
        }
        savePNG("theory-index-no-upcoming")
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
