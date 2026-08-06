import XCTest

/// 问题集合 v29 W5 完成标准 4 的**接线实证**：单测只验 `ToolUsageTracker.record` 本身，
/// 这里验「页面入口埋点确实挂上了」——真机进「自由击球」页停留后退出，
/// 会话应由页面生命周期自行落库（随后由宿主侧读 sqlite 反证）。
final class V29W5ToolUsageUITests: XCTestCase {

    private var app: XCUIApplication!

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
        // 由本文件路径反推仓库根，避免硬编码某个 worktree 的绝对路径（W1/FL 教训）。
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // QiuJiUITests/
            .deletingLastPathComponent()   // <repo root>
        let dir = repoRoot
            .appendingPathComponent("build", isDirectory: true)
            .appendingPathComponent("w5-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }

    /// 进「打」分区 → 自由击球 → 停留 12 秒（> 5 秒阈值）→ 返回，触发 onDisappear 落库。
    func test_freePlayEntry_recordsToolSession() throws {
        app.switchTab(.angle)
        sleep(1)
        snap("01-practice-home")

        let playTab = app.buttons["angleHomeTab_打"]
        XCTAssertTrue(playTab.waitForExistence(timeout: 6), "「打」分区分段控件应存在")
        playTab.tap()
        sleep(1)
        snap("02-play-section")

        let card = app.buttons["自由击球"]
        XCTAssertTrue(card.waitForExistence(timeout: 6), "自由击球卡片应存在")
        card.tap()

        XCTAssertTrue(app.navigationBars["自由击球"].waitForExistence(timeout: 15),
                      "应进入自由击球页")
        // 停留超过 ToolUsageTracker.minimumDurationSeconds（5 秒）。
        sleep(12)
        snap("03-freeplay-dwell")

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.exists, "应有返回按钮")
        back.tap()
        sleep(2)
        snap("04-back-to-practice")

        // 让 onDisappear 的落库与 SwiftData 写盘落地。
        sleep(3)
    }

    /// 完成标准 2 的接线实证：在「角度预测」页真答 3 题，
    /// 落库后应有 1 条 cognitive 会话、3 条成绩指向它（由宿主侧读 sqlite 反证）。
    func test_geometricQuiz_threeAnswers_recordOneCognitiveSession() throws {
        app.switchTab(.angle)
        sleep(1)

        let practiceTab = app.buttons["angleHomeTab_练"]
        XCTAssertTrue(practiceTab.waitForExistence(timeout: 6), "「练」分区分段控件应存在")
        practiceTab.tap()
        sleep(1)
        snap("10-practice-section")

        let card = app.buttons["角度预测"]
        XCTAssertTrue(card.waitForExistence(timeout: 6), "角度预测卡片应存在")
        card.tap()
        sleep(3)
        snap("11-geometric-quiz")

        for i in 1...3 {
            let answer = app.buttons["答题"]
            XCTAssertTrue(answer.waitForExistence(timeout: 8), "第 \(i) 题应有「答题」入口")
            answer.tap()
            sleep(1)

            // 数字键盘输入 45°。
            for digit in ["4", "5"] {
                let key = app.buttons[digit]
                XCTAssertTrue(key.waitForExistence(timeout: 5), "键盘数字 \(digit) 应存在")
                key.tap()
            }
            let submit = app.buttons["提交"]
            XCTAssertTrue(submit.waitForExistence(timeout: 5), "「提交」应存在")
            submit.tap()
            sleep(2)
            snap("12-answer-\(i)")

            if i < 3 {
                let next = app.buttons["下一题"]
                XCTAssertTrue(next.waitForExistence(timeout: 8), "第 \(i) 题后应有「下一题」")
                next.tap()
                sleep(1)
            }
        }

        // 让落库写盘落地。
        sleep(3)
        snap("13-after-three-answers")
    }
}
