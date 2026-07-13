import XCTest

/// 问题集合 v3 §S2 全局规范推广验收：
/// - 逐页截图核验 G3–G11（分离角与走位 / 自由走位 / 思路训练 / 打一走二想三 / 做斯诺克）；
/// - P11.1：打页入口顺序 = 分离角与走位、自由走位、自由击球、拍照建球形。
final class S2_ShotPagesLayoutUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func switchAngleHomeTab(_ name: String) -> Bool {
        let seg = app.buttons["angleHomeTab_\(name)"]
        guard seg.waitForExistence(timeout: 4) else { return false }
        seg.tap(); usleep(600_000); return true
    }

    /// 从练习首页进入指定卡片页；返回是否成功。
    private func openCard(homeTab: String, title: String) -> Bool {
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab(homeTab) else { return false }
        let card = app.buttons[title]
        guard card.waitForExistence(timeout: 4) else { return false }
        card.tap()
        sleep(3)   // 等场景装桌 + 自动取景
        return true
    }

    private func goBack() {
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap(); sleep(1) }
    }

    /// P11.1：打页卡片顺序（分离角与走位 → 自由走位 → 自由击球 → 拍照建球形）。
    func testPlayEntriesOrder() throws {
        app.switchTab(.angle)
        sleep(1)
        guard switchAngleHomeTab("打") else {
            XCTFail("未能切到「打」分组"); return
        }
        let titles = ["分离角与走位", "自由走位", "自由击球", "拍照建球形"]
        var positions: [CGPoint] = []
        for t in titles {
            let card = app.buttons[t]
            XCTAssertTrue(card.waitForExistence(timeout: 4), "缺少入口卡片：\(t)")
            positions.append(CGPoint(x: card.frame.midX, y: card.frame.midY))
        }
        // 网格从上到下、每行从左到右 ⇒ (y, x) 字典序递增。
        for i in 1..<positions.count {
            let prev = positions[i - 1], cur = positions[i]
            let ordered = cur.y > prev.y + 1 || (abs(cur.y - prev.y) <= 1 && cur.x > prev.x)
            XCTAssertTrue(ordered, "入口顺序错误：\(titles[i]) 应在 \(titles[i - 1]) 之后")
        }
        snap("s2-00-play-entries-order")
    }

    func testShotSimulationLayout() throws {
        guard openCard(homeTab: "打", title: "分离角与走位") else {
            XCTFail("未能进入分离角与走位"); return
        }
        snap("s2-01-shotsim")
    }

    func testComposerLayout() throws {
        guard openCard(homeTab: "打", title: "自由走位") else {
            XCTFail("未能进入自由走位"); return
        }
        snap("s2-02-composer")
    }

    func testSiluLayout() throws {
        guard openCard(homeTab: "解", title: "思路训练") else {
            XCTFail("未能进入思路训练"); return
        }
        snap("s2-03-silu")
    }

    func testPlanThreeLayout() throws {
        guard openCard(homeTab: "解", title: "打一走二想三") else {
            XCTFail("未能进入打一走二想三"); return
        }
        snap("s2-04-planthree")
    }

    func testSnookerLayout() throws {
        guard openCard(homeTab: "解", title: "防守") else {
            XCTFail("未能进入防守"); return
        }
        snap("s2-05-snooker")
    }
}
