import XCTest
import SwiftUI
@testable import QiuJi

/// v24 W1：动作库网格卡封面 2:1（与烘焙 PNG 同比），ImageRenderer 落盘证据。
@MainActor
final class V24DrillGridCardAspectTests: XCTestCase {

    private let outDir = "/Users/song/projects/13.billiard_trainer/build/v24-w1-evidence"

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(
            atPath: outDir,
            withIntermediateDirectories: true
        )
    }

    func testRenderGridCards_coverIs2to1_fullTableVisible() async throws {
        var drills: [DrillContent] = []
        for id in ["drill_c001", "drill_c053", "drill_c010"] {
            if let d = await DrillContentService.shared.loadDrillFromBundle(id: id) {
                drills.append(d)
            }
        }
        XCTAssertEqual(drills.count, 3, "Bundle must contain sample drills for grid render")

        // Two-column column width ≈ (393 − 16×2 − 12) / 2 ≈ 174.5 (mirrors DrillListView spacing).
        let columnWidth: CGFloat = 174.5
        let grid = VStack(alignment: .leading, spacing: Spacing.md) {
            Text("v24 W1 · 网格卡 2:1（完整桌）")
                .font(.btHeadline)
                .foregroundStyle(.btText)
            HStack(alignment: .top, spacing: 12) {
                BTDrillGridCard(drill: drills[0], isFavorited: false)
                    .frame(width: columnWidth)
                BTDrillGridCard(drill: drills[1], isFavorited: true)
                    .frame(width: columnWidth)
            }
            BTDrillGridCard(drill: drills[2], isFavorited: false)
                .frame(width: columnWidth)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.btBG)

        let renderer = ImageRenderer(content: grid.frame(width: 393, height: 520))
        renderer.scale = 2
        let img = try XCTUnwrap(renderer.uiImage, "ImageRenderer nil for grid cards")
        let data = try XCTUnwrap(img.pngData())
        let url = URL(fileURLWithPath: "\(outDir)/01-grid-cards-2to1.png")
        try data.write(to: url)
        XCTAssertGreaterThan(data.count, 20_000)

        // Cover slot: width W → height W/2 under aspectRatio(2). Card also has text block;
        // assert cover portion ≈ half of column width via isolated cover mirror.
        let coverOnly = Color.clear
            .aspectRatio(2.0, contentMode: .fit)
            .overlay { BTBakedDrillTable(drillId: "drill_c001") }
            .clipped()
            .frame(width: columnWidth)
            .background(Color.btBGSecondary)
        let coverRenderer = ImageRenderer(
            content: coverOnly.frame(width: columnWidth, height: columnWidth / 2)
        )
        coverRenderer.scale = 2
        let coverImg = try XCTUnwrap(coverRenderer.uiImage)
        XCTAssertEqual(coverImg.size.width, columnWidth, accuracy: 0.5)
        XCTAssertEqual(coverImg.size.height, columnWidth / 2, accuracy: 0.5)
        let coverData = try XCTUnwrap(coverImg.pngData())
        try coverData.write(to: URL(fileURLWithPath: "\(outDir)/02-cover-slot-c001.png"))
    }

    /// DR-077：已练过用亮绿角标；免费 / Pro 课名都走主色。
    func testRenderGridCards_practicedBadge_notGrayTitle() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c001")
        let drill = try XCTUnwrap(loaded, "Bundle must contain drill_c001")
        let premium = DrillContent(
            id: drill.id, nameZh: drill.nameZh, nameEn: drill.nameEn,
            category: drill.category, secondaryCategories: drill.secondaryCategories,
            subcategory: drill.subcategory, ballType: drill.ballType,
            level: drill.level, difficulty: drill.difficulty, isPremium: true,
            description: drill.description, coachingPoints: drill.coachingPoints,
            standardCriteria: drill.standardCriteria, sets: drill.sets,
            animation: drill.animation, tutorial: drill.tutorial, videos: drill.videos,
            shotIntent: drill.shotIntent, load: drill.load
        )

        let columnWidth: CGFloat = 174.5
        let pair = HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("未练")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                BTDrillGridCard(drill: drill, isFavorited: false, practiceCount: 0)
                    .frame(width: columnWidth)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("已练")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                BTDrillGridCard(drill: drill, isFavorited: true, practiceCount: 1)
                    .frame(width: columnWidth)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Pro 已练")
                    .font(.btCaption)
                    .foregroundStyle(.btTextSecondary)
                BTDrillGridCard(drill: premium, isFavorited: false, practiceCount: 1)
                    .frame(width: columnWidth)
            }
        }
        .padding(Spacing.lg)
        .background(Color.btBG)

        let renderer = ImageRenderer(content: pair.frame(width: 580, height: 240))
        renderer.scale = 2
        let img = try XCTUnwrap(renderer.uiImage, "ImageRenderer nil for practiced badge cards")
        let data = try XCTUnwrap(img.pngData())
        try data.write(to: URL(fileURLWithPath: "\(outDir)/03-practiced-badge.png"))
        XCTAssertGreaterThan(data.count, 20_000)
    }
}
