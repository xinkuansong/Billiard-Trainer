import XCTest
import SwiftUI
@testable import QiuJi

/// v30 X-1（FL-029）渲染证据：`TutorialSection.content` 放宽为可选后，
/// 纯 `items` 节在精讲页必须正常显示——
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

    /// 前置契约断言：模型仍能表达「标题 + items、无正文」。生产文案可以在
    /// `nil` 与 `""` 之间正常演进，渲染回归不应绑定某几条内容的当前写法。
    func test_contentlessItemsSection_fixturePreservesOptionalContentContract() {
        let contentless = Self.contentlessFixture
        XCTAssertNil(contentless.content)
        XCTAssertEqual(contentless.title, "常见错误与纠正")
        XCTAssertFalse(contentless.items?.isEmpty ?? true)
    }

    @MainActor
    func test_tutorialPage_rendersContentlessSections_lightAndDark() throws {
        let outDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/x-v30-1-screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        for id in Self.drillIds {
            let drill = try XCTUnwrap(drills[id])
            // 「聚焦版」：把 nil-content fixture 排到首位，后接该 drill 的真实正文做对照，
            // 使可选正文分支始终落在可视区内，不依赖生产内容是否写成空字符串。
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
                    let pixels = try XCTUnwrap(image.cgImage, "\(name) 无 CGImage")
                    XCTAssertEqual(pixels.width, Int(image.size.width * image.scale))
                    XCTAssertEqual(pixels.height, Int(image.size.height * image.scale))
                    XCTAssertGreaterThan(Self.distinctSampleColors(in: image), 20,
                                         "\(name) 疑似空白或纯色图")
                }
            }
        }
    }

    /// 取 nil-content fixture + 一个真实有正文的普通节，组成单球形精讲。
    private static func focusedOnContentlessSection(_ drill: DrillContent) throws -> DrillContent {
        let sections = allSections(of: drill)
        let withProse = sections.first { !($0.content?.isEmpty ?? true) }
        return DrillContent(
            id: drill.id, nameZh: drill.nameZh, nameEn: drill.nameEn,
            category: drill.category, subcategory: drill.subcategory,
            ballType: drill.ballType, level: drill.level, difficulty: drill.difficulty,
            isPremium: drill.isPremium, description: drill.description,
            coachingPoints: drill.coachingPoints, standardCriteria: drill.standardCriteria,
            sets: drill.sets, animation: drill.animation,
            tutorial: DrillTutorial(tutorialKind: drill.tutorial?.tutorialKind,
                                    sections: [contentlessFixture] + (withProse.map { [$0] } ?? []))
        )
    }

    private static var contentlessFixture: TutorialSection {
        TutorialSection(
            title: "常见错误与纠正",
            items: [TutorialItem(label: "出杆偏线", text: "让杆头沿瞄准线送出。")]
        )
    }

    /// 统一缩到 64×64 RGBA 后取颜色数，避免用 PNG 压缩字节数判断空白；后者会随
    /// Runtime 的字体/图层编码变化。纯底图只有少量颜色，真实文本卡片会远高于阈值。
    @MainActor
    private static func distinctSampleColors(in image: UIImage) -> Int {
        let size = CGSize(width: 64, height: 64)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let sampled = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let cgImage = sampled.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        let byteCount = CFDataGetLength(data)
        guard byteCount >= 4 else { return 0 }
        var colors: Set<UInt32> = []
        for index in stride(from: 0, to: byteCount - 3, by: 4) {
            let value = UInt32(bytes[index]) << 24
                | UInt32(bytes[index + 1]) << 16
                | UInt32(bytes[index + 2]) << 8
                | UInt32(bytes[index + 3])
            colors.insert(value)
        }
        return colors.count
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
