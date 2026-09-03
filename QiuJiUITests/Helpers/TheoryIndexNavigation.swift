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
        // 两台 iPad 并发长巡游在多次软重启后，AX 服务偶尔会有一次
        // 短暂空快照：App 仍在前台，下一次查询即恢复。分段入口是每篇理论页
        // 的共同前置，必须有界重试，不得把一次 AX 空快照转成静默缺图。
        for attempt in 0..<3 {
            if attempt > 0 {
                app.activate()
                Thread.sleep(forTimeInterval: 0.8)
            }
            app.switchTab(.angle)
            let theory = app.descendants(matching: .any)["angleHomeTab_理"]
            if theory.waitForExistence(timeout: 5) {
                theory.tap()
                Thread.sleep(forTimeInterval: 0.8)
                return true
            }
        }
        XCTFail("练习 Tab「理」侧栏应出现（3 次激活/切换重试后仍失败）", file: file, line: line)
        return false
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
        let contentScroll = widestScrollView(in: app)

        // iPad mini 上相邻两张卡可能同处一行：从前一详情页返回时，目标卡会
        // 被 pinned header 裁住一部分，AX 报告 exists=true / isHittable=false。
        // 此时一律向上滚会把它彻底滚出 LazyVGrid。先按目标相对视口的方向
        // 有界调整；若 Lazy 容器仍未实例化目标，再回顶后单向向下搜索。
        for _ in 0..<4 where !card.isHittable {
            if card.exists, card.frame.midY < contentScroll.frame.midY {
                contentScroll.swipeDown(velocity: .slow)
            } else {
                contentScroll.swipeUp(velocity: .slow)
            }
            Thread.sleep(forTimeInterval: 0.35)
        }
        if !card.isHittable {
            for _ in 0..<10 {
                contentScroll.swipeDown(velocity: .fast)
            }
            for _ in 0..<12 where !card.isHittable {
                contentScroll.swipeUp(velocity: .slow)
                Thread.sleep(forTimeInterval: 0.35)
            }
        }
        guard card.waitForExistence(timeout: 6) else {
            XCTFail("「理」分组应有卡片「\(cardTitle)」", file: file, line: line)
            return false
        }
        let nav = navigationTitle ?? cardTitle
        let destination = app.navigationBars[nav]
        // iPhone SE / iOS 17 的 LazyVGrid + pinned section header 在刚滚稳时，
        // XCUITest 偶尔会把第一次 tap 合成出来却未交给 Button（元素仍报告
        // isHittable）。这不是可以忽略的缺图：用同一张真实卡的安全内点重试，
        // 且每次都必须等到目标导航栏出现，避免误把未跳转页面截图成详情页。
        for attempt in 0..<2 {
            if attempt == 0, card.isHittable {
                card.tap()
            } else {
                card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).tap()
            }
            if destination.waitForExistence(timeout: 4) {
                return true
            }
        }
        guard destination.exists else {
            XCTFail("卡片应 push 到「\(nav)」", file: file, line: line)
            return false
        }
        return true
    }

    /// 练习根页左侧分类和右侧内容各自都是 ScrollView；选择宽度最大的右侧
    /// 内容区，避免 iPad 上把滚动手势送进不会滚动的 76pt 侧栏。
    private static func widestScrollView(in app: XCUIApplication) -> XCUIElement {
        app.scrollViews.allElementsBoundByIndex
            .filter { $0.exists }
            .max(by: { $0.frame.width < $1.frame.width })
            ?? app
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
