import XCTest
import SwiftUI
@testable import QiuJi

/// v30 X-1（FL-029）渲染证据：`TutorialSection.content` 放宽为可选后，
/// 纯 `items` 节（全库 45 处「常见错误与纠正」）在精讲页必须正常显示——
/// 不留空段落、不留空白块、不崩。
///
/// 用真实 Bundle drill 渲染真实 `DrillTutorialView`，明暗各出一张 PNG 到
/// `build/x-v30-1-screenshots/`。给足高度让 ScrollView 内容整幅铺开，
/// 使被检查的那一节确实出现在图里（而非被裁掉）。
final class V30X1TutorialEmptyContentRenderTests: XCTestCase {

    /// 三条覆盖两种承载形态：c003 / c024 的纯 items 节在 `formations` 内，
    /// c033 的在单球形 `sections` 内。
    private static let drillIds = ["drill_c003", "drill_c024", "drill_c033"]

    private var drills: [String: DrillContent] = [:]

    override func setUp() async throws {
        try await super.setUp()
        for id in Self.drillIds {
            let drill = await DrillContentService.shared.loadDrillFromBundle(id: id)
            drills[id] = try XCTUnwrap(drill, "\(id) 必须能从 Bundle 加载")
        }
    }

    /// 前置事实断言：这些 drill 确实含「标题 + items、无正文」的节。
    /// 若内容侧哪天补了正文，本断言会失败，提醒截图证据已失去针对性。
    func test_targetDrills_containContentlessItemsSections() throws {
        for id in Self.drillIds {
            let drill = try XCTUnwrap(drills[id])
            let sections = Self.allSections(of: drill)
            let contentless = sections.filter { $0.content == nil }
            XCTAssertFalse(contentless.isEmpty, "\(id) 应含至少一个 content 缺省的节")
            for section in contentless {
                XCTAssertEqual(section.title, "常见错误与纠正",
                               "\(id) content 缺省的节应只有「常见错误与纠正」")
                XCTAssertFalse(section.items?.isEmpty ?? true,
                               "\(id) 「\(section.title)」无正文时必须有 items，否则是空节")
            }
        }
    }

    @MainActor
    func test_tutorialPage_rendersContentlessSections_lightAndDark() throws {
        let outDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/x-v30-1-screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        for id in Self.drillIds {
            let drill = try XCTUnwrap(drills[id])
            // 「聚焦版」：把该 drill 真实的纯 items 节排到首位，后接一个有正文的普通节做对照，
            // 使被检查的那一节落在可视区内。节对象逐字段原样取自 Bundle，未新增任何文案。
            let focused = try Self.focusedOnContentlessSection(drill)

            for scheme in [ColorScheme.light, .dark] {
                let suffix = scheme == .light ? "light" : "dark"
                for (variant, subject) in [("full", drill), ("errors", focused)] {
                    let image = Self.snapshot(
                        DrillTutorialView(drill: subject).environment(\.colorScheme, scheme),
                        size: CGSize(width: 390, height: variant == "full" ? 3600 : 1200),
                        scheme: scheme
                    )
                    let data = try XCTUnwrap(image.pngData())
                    let name = "\(id)-\(variant)-\(suffix).png"
                    try data.write(to: outDir.appendingPathComponent(name))
                    // 空白/占位图会被压成很小的 PNG；真实排版远大于此。
                    XCTAssertGreaterThan(data.count, 150_000, "\(name) 疑似空白图（\(data.count) 字节）")
                }
            }
        }
    }

    /// 取该 drill 真实的纯 items 节 + 一个有正文的普通节，组成单球形精讲。
    private static func focusedOnContentlessSection(_ drill: DrillContent) throws -> DrillContent {
        let sections = allSections(of: drill)
        // 只要 `content == nil`（键整个省略）的节——那正是本批放宽的形态，
        // 全库 45 处全是「常见错误与纠正」。`content: ""` 的节旧版本就已存在，不作证据。
        let contentless = try XCTUnwrap(
            sections.first { $0.content == nil && !($0.items?.isEmpty ?? true) },
            "\(drill.id) 无 content 缺省的纯 items 节")
        let withProse = sections.first { !($0.content?.isEmpty ?? true) }
        return DrillContent(
            id: drill.id, nameZh: drill.nameZh, nameEn: drill.nameEn,
            category: drill.category, subcategory: drill.subcategory,
            ballType: drill.ballType, level: drill.level, difficulty: drill.difficulty,
            isPremium: drill.isPremium, description: drill.description,
            coachingPoints: drill.coachingPoints, standardCriteria: drill.standardCriteria,
            sets: drill.sets, animation: drill.animation,
            tutorial: DrillTutorial(tutorialKind: drill.tutorial?.tutorialKind,
                                    sections: [contentless] + (withProse.map { [$0] } ?? []))
        )
    }

    /// 把 SwiftUI 视图放进真实 UIWindow 里排完版再截图。
    /// 不用 `ImageRenderer`：它不会给 `ScrollView` / `LazyVStack` 内容排版，只出空白图。
    /// 窗口给足高度（内容整幅短于窗口），故 ScrollView 一次铺开、无需滚动。
    @MainActor
    private static func snapshot<V: View>(_ view: V, size: CGSize, scheme: ColorScheme) -> UIImage {
        let host = UIHostingController(rootView: view)
        host.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        // 必须挂到活跃的 windowScene，否则窗口不参与渲染，截出来是全空白。
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = host.overrideUserInterfaceStyle
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        // 让 SwiftUI 完成一轮渲染事务后再抓帧。
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        // 用 layer.render 而非 drawHierarchy：测试里这个额外窗口不真正上屏，
        // afterScreenUpdates 抓到的是空帧。
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            host.view.layer.render(in: ctx.cgContext)
        }
    }

    private static func allSections(of drill: DrillContent) -> [TutorialSection] {
        guard let tutorial = drill.tutorial else { return [] }
        if let formations = tutorial.formations, !formations.isEmpty {
            return formations.flatMap(\.sections)
        }
        return tutorial.sections ?? []
    }
}
