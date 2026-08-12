import XCTest
@testable import QiuJi

/// 精讲配图发布链路的 Bundle 侧同位检查（v25 W4 / D-v25-2 / D-v25-10）。
///
/// `publish_tutorial_figures.py --check` 看守的是**仓库磁盘**上的发布集与新鲜度；
/// 本测试看守**构建产物**——包里真的有这些 HEIC、且 `DrillTutorialImageStore` 真能解出
/// `UIImage`。二者缺一不可：磁盘对了但 folder reference 配错，App 里依旧满屏缺图占位。
final class TutorialFiguresBundleTests: XCTestCase {

    private var referencedImageNames: [(drillId: String, image: String)] = []

    override func setUp() async throws {
        try await super.setUp()
        let drills = await DrillContentService.shared.loadFallbackDrills()
        referencedImageNames = drills.flatMap { drill -> [(String, String)] in
            guard let tutorial = drill.tutorial else { return [] }
            var sections = tutorial.sections ?? []
            for formation in tutorial.formations ?? [] {
                sections.append(contentsOf: formation.sections)
            }
            return sections.compactMap { section in
                section.image.map { (drill.id, $0) }
            }
        }
    }

    func test_referencedTutorialImages_allResolveFromBundle() {
        XCTAssertFalse(referencedImageNames.isEmpty, "精讲配图引用为空，说明 drill 内容没加载起来")
        let unresolved = referencedImageNames.filter {
            DrillTutorialImageStore.image(named: $0.image) == nil
        }
        guard !unresolved.isEmpty else { return }
        let detail = unresolved.prefix(20).map { "\($0.drillId): \($0.image)" }.joined(separator: "\n")
        XCTFail("""
        \(unresolved.count)/\(referencedImageNames.count) 张精讲配图在包内解不出来。
        先跑 `make tutorial-figures`；仍失败则查 project.yml 的 \
        Resources/\(TutorialAssets.bundleSubdirectory) folder reference。
        \(detail)
        """)
    }

    /// D-v25-10：孤儿帧不进包。发布目录里出现 PNG ⇒ 母版被误打包，包体会从 285 MB 回涨到 5 GB。
    func test_bundleTutorialFigures_containsNoPNGMasters() {
        let pngs = Bundle.main.urls(forResourcesWithExtension: "png",
                                    subdirectory: TutorialAssets.bundleSubdirectory) ?? []
        XCTAssertTrue(pngs.isEmpty,
                      "打包目录混入 \(pngs.count) 个 PNG 母版（D-v25-10 只许发布被引用的 HEIC）")
    }

    /// 只发被引用者：包内 HEIC 数量应等于精讲引用去重数，不多也不少。
    func test_bundleTutorialFigures_countMatchesReferencedSet() {
        let heics = Bundle.main.urls(forResourcesWithExtension: "heic",
                                     subdirectory: TutorialAssets.bundleSubdirectory) ?? []
        let referenced = Set(referencedImageNames.map(\.image))
        XCTAssertEqual(heics.count, referenced.count,
                       "包内 HEIC \(heics.count) 张 vs 精讲引用 \(referenced.count) 张，发布集不同步")
    }

    /// HEIC 要能真的解码成原始像素尺寸——只检查文件存在会漏掉「文件在但解码失败」。
    func test_publishedFigure_decodesAtSourceResolution() throws {
        let sample = try XCTUnwrap(referencedImageNames.first?.image)
        let image = try XCTUnwrap(DrillTutorialImageStore.image(named: sample),
                                  "样本配图 \(sample) 解码失败")
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
        // 出片分辨率 1440×2720（保持原始像素尺寸，v25 W4 明确不降分辨率）
        XCTAssertEqual(image.size.width, 1440, accuracy: 1,
                       "配图宽度偏离出片分辨率，全屏查看会糊")
    }
}
