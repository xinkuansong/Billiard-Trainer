import XCTest

/// 练习 Tab → 控球／策略 → 单篇理论卡（v32.2：首页每篇一卡，不再经「球理」索引总卡）。
enum TheoryIndexNavigation {

    /// 切到练习 Tab 并点侧栏理论。
    @discardableResult
    static func openTheorySection(
        in app: XCUIApplication,
        section: String = "控球",
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
            let theory = app.descendants(matching: .any)["angleHomeTab_" + section]
            if theory.waitForExistence(timeout: 5) {
                PracticeHomeNavigation.select(section, in: app)
                Thread.sleep(forTimeInterval: 0.8)
                return true
            }
        }
        XCTFail("练习 Tab理论侧栏应出现（3 次激活/切换重试后仍失败）", file: file, line: line)
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
        guard openTheorySection(in: app, section: PracticeHomeNavigation.section(for: cardTitle), file: file, line: line) else { return false }

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
            XCTFail("理论分组应有卡片「\(cardTitle)」", file: file, line: line)
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


/// Current practice-home navigation; titles select a single approved section.
enum PracticeHomeNavigation {
    static func section(for title: String) -> String {
        switch title {
        case "瞄准原理", "瞄准方法", "旋转与加塞", "瞄准修正", "瞄准点对照表", "浅谈凭感觉瞄准", "进球容错角", "浅谈球感": return "基础"
        case "角度与瞄准", "角度预测", "角度练习", "假想球练习", "瞄准点练习", "准度练习", "2D角度", "3D角度", "2D 角度训练", "3D 角度训练", "2D瞄准点", "3D瞄准点", "2D 瞄准点训练", "3D 瞄准点训练", "瞄准点训练", "2D准度", "3D准度": return "准度"
        case "分离角图谱", "加塞吃库图谱", "30° 法则", "90° 法则", "切线法则", "母球速度分级", "最少加塞原则": return "控球"
        case "分离角与走位", "走位求解", "打一走二想三", "分离角练习", "两球走位", "三球走位", "多球走位", "蛇彩练习", "自定义球形", "拍照建球形", "自由走位", "自由击球", "思路训练", "批量出片台", "2D分离角", "3D分离角", "2D两球走位", "3D两球走位", "2D三球走位", "3D三球走位": return "走位"
        case "翻袋解球", "颗星解球", "翻袋练习", "解球练习", "K球练习", "防守练习", "防守": return "进阶"
        case "反向规划", "关键球原理", "球团管理", "风险报酬决策矩阵", "安全球三维度模型", "清台 5 步决策流程", "清台速查手册": return "策略"
        default:
            XCTFail("Unknown practice card: \(title)")
            return "全部"
        }
    }

    static func select(_ section: String, in app: XCUIApplication) {
        let button = app.buttons["angleHomeTab_" + section]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        let sidebar = app.scrollViews.allElementsBoundByIndex
            .filter { $0.exists }.min { $0.frame.width < $1.frame.width } ?? app
        for _ in 0..<4 where !button.isHittable {
            if section == "全部" || section == "基础" { sidebar.swipeDown() }
            else { sidebar.swipeUp() }
        }
        XCTAssertTrue(button.isHittable, "Section must be reachable: \(section)")
        button.tap()
    }
}
