import XCTest

/// 练习 Tab →「理」→ 单篇理论卡（v32.2：首页每篇一卡，不再经「球理」索引总卡）。
enum TheoryIndexNavigation {

    /// 切到练习 Tab 并点侧栏「理」。
    @discardableResult
    static func openTheorySection(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        app.switchTab(.angle)

        let theory = app.descendants(matching: .any)["angleHomeTab_理"]
        guard theory.waitForExistence(timeout: 10) else {
            XCTFail("练习 Tab「理」侧栏应出现", file: file, line: line)
            return false
        }
        theory.tap()
        Thread.sleep(forTimeInterval: 0.8)
        return true
    }

    /// 在理区点指定标题的入口卡，等待导航栏标题（默认与卡标题相同）。
    @discardableResult
    static func openPage(
        in app: XCUIApplication,
        cardTitle: String,
        navigationTitle: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        guard openTheorySection(in: app, file: file, line: line) else { return false }

        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", cardTitle))
            .firstMatch
        // 12 卡可能需轻滚才能点到靠后条目。
        var scrolls = 0
        while !card.exists || !card.isHittable, scrolls < 8 {
            app.swipeUp(velocity: .slow)
            scrolls += 1
            Thread.sleep(forTimeInterval: 0.35)
        }
        guard card.waitForExistence(timeout: 6) else {
            XCTFail("「理」分组应有卡片「\(cardTitle)」", file: file, line: line)
            return false
        }
        if !card.isHittable {
            card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            card.tap()
        }

        let nav = navigationTitle ?? cardTitle
        guard app.navigationBars[nav].waitForExistence(timeout: 6) else {
            XCTFail("卡片应 push 到「\(nav)」", file: file, line: line)
            return false
        }
        return true
    }

    /// 兼容旧名：打开一篇已上线页作为「理区可达」冒烟（不再进入索引页）。
    @discardableResult
    static func openIndex(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        openPage(
            in: app,
            cardTitle: "切线法则",
            navigationTitle: "切线法则",
            file: file,
            line: line
        )
    }
}
