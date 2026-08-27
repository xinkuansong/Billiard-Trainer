import XCTest

/// W2-7 改后截图采集（本批验收用）。
final class W27ScreenshotUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication.launchClean()
    }

    private var shotDir: URL {
        URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer-w2-7/docs/ui-polish/screenshots-w2-7",
            isDirectory: true)
    }

    private func snap(_ name: String) {
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
        let shot = XCUIScreen.main.screenshot()
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func tapLabel(_ label: String, timeout: TimeInterval = 6) -> Bool {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }
        return false
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        sleep(1)
    }

    /// 全新模拟器首启会落在 OnboardingView：先跳过，再等 TabBar。
    private func skipOnboardingIfNeeded() {
        let skip = app.buttons["跳过"]
        if skip.waitForExistence(timeout: 5) {
            skip.tap()
            sleep(2)
        }
        _ = app.tabBars.buttons["训练"].waitForExistence(timeout: 15)
    }

    // MARK: - Plan detail + builder

    func testW27PlanScreenshots() throws {
        skipOnboardingIfNeeded()
        app.switchTab(.training)
        sleep(1)

        // 计划详情（第一张官方海报卡）
        let posterCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '周'")
        ).firstMatch
        if posterCard.waitForExistence(timeout: 6) {
            posterCard.tap()
            sleep(2)
            snap("after-plan-detail")

            // 展开第 1 周手风琴（F-PL-06/11）
            let weekRow = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH '第 1 周'")
            ).firstMatch
            if weekRow.waitForExistence(timeout: 4) {
                weekRow.tap()
                sleep(1)
                snap("after-plan-detail-week-expanded")
            }
            goBack()
        }

        // PRO 计划详情（F-PL-10 PRO 标 safe area 避让）
        let proCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '进阶' OR label CONTAINS 'PRO'")
        ).firstMatch
        if proCard.waitForExistence(timeout: 4) {
            proCard.tap()
            sleep(2)
            snap("after-plan-detail-pro")
            goBack()
        }

        // 自定义模版构建器（空态 F-PL-14）：「我的模版」segment → 空态 CTA「新建模版」
        if tapLabel("我的模版", timeout: 4) {
            sleep(1)
            if tapLabel("新建模版", timeout: 4) {
                sleep(2)
                snap("after-builder-empty")
                goBack()
            }
        }
    }

    // MARK: - Note / Summary / Share

    func testW27SummaryFlowScreenshots() throws {
        skipOnboardingIfNeeded()
        app.switchTab(.training)
        sleep(1)

        // 无激活计划时首页 CTA 为「自由记录」
        if !tapLabel("自由记录", timeout: 6) {
            guard tapLabel("开始训练", timeout: 4) else {
                snap("flow-no-start-button")
                return
            }
        }
        sleep(2)

        // 先让计时 >0（elapsedSeconds==0 且无 drill 时顶栏「结束」会直接 dismiss）
        if tapLabel("继续", timeout: 6) {
            sleep(3)
        }

        // 顶栏「结束」→ 确认弹窗「结束训练？」→「结束」→ 心得页（F-TS-11 秒级时长）
        guard app.buttons["结束"].waitForExistence(timeout: 10) else {
            snap("flow-no-end-button")
            return
        }
        app.buttons["结束"].tap()
        sleep(1)
        let confirmEnd = app.alerts.buttons["结束"]
        if confirmEnd.waitForExistence(timeout: 4) {
            confirmEnd.tap()
        }
        sleep(2)

        // 心得页（F-TS-05/10、F-TR-10）
        snap("after-note-empty")
        let editor = app.textViews.firstMatch
        if editor.waitForExistence(timeout: 4) {
            editor.tap()
            editor.typeText("今天定杆手感不错")
            sleep(1)
            snap("after-note-with-count")
        }
        // 键盘工具栏与底栏各有一个「完成」：先收键盘再点底栏
        let doneButtons = app.buttons.matching(NSPredicate(format: "label == '完成'"))
        if doneButtons.firstMatch.waitForExistence(timeout: 4) {
            doneButtons.firstMatch.tap()
            sleep(1)
            if doneButtons.firstMatch.exists {
                doneButtons.firstMatch.tap()
            }
        }
        sleep(2)

        // 总结页（F-TS-01/02/11）
        snap("after-summary")

        // 分享页（F-TS-03/07/08/09）
        if tapLabel("生成分享图", timeout: 4) {
            sleep(2)
            snap("after-share")
        }
    }
}
