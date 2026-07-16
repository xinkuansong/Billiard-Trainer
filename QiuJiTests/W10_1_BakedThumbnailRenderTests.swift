import XCTest
import SwiftUI
@testable import QiuJi

/// v10 W1：用 ImageRenderer 落盘三处缩略图接线证据（同生产尺寸与组件调用）。
@MainActor
final class W10_1_BakedThumbnailRenderTests: XCTestCase {

    private var outDir: String {
        "/Users/song/projects/13.billiard_trainer/build/w10-1-screenshots"
    }

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(
            atPath: outDir,
            withIntermediateDirectories: true
        )
    }

    private func render<V: View>(_ view: V, name: String, size: CGSize) throws {
        let wrapped = view
            .frame(width: size.width, height: size.height)
            .background(Color.btBG)
        let renderer = ImageRenderer(content: wrapped)
        renderer.scale = 2
        let img = try XCTUnwrap(renderer.uiImage, "ImageRenderer nil for \(name)")
        let data = try XCTUnwrap(img.pngData())
        let url = URL(fileURLWithPath: "\(outDir)/\(name).png")
        try data.write(to: url)
        XCTAssertGreaterThan(data.count, 8_000, "\(name) should be a non-trivial PNG")
    }

    /// 标准 1：训练总结 drill 卡缩略图（48×48，与 TrainingSummaryView.drillThumbnail 一致）
    /// 注：完整 TrainingSummaryView 含 ScrollView，ImageRenderer 只会渲到底栏；故渲明细卡接线镜像。
    func testRenderTrainingSummaryPage() throws {
        let cards = VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("训练总结 · 烘焙缩略图")
                .font(.btHeadline)
                .foregroundStyle(.btText)
            summaryStyleCard(drillId: "drill_c001", name: "定点红球进袋", rate: "77%", meta: "2 组 · 31/40 球")
            summaryStyleCard(drillId: "drill_c002", name: "斯诺克直线进袋", rate: "93%", meta: "2 组 · 28/30 球")
            summaryStyleCard(drillId: "drill_c003", name: "走位练习 A", rate: "60%", meta: "2 组 · 18/30 球")
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        try render(cards, name: "01-training-summary-baked-thumbs", size: CGSize(width: 393, height: 520))
    }

    /// 标准 2：历史详情 drill 卡缩略图接线（40×40，与 TrainingDetailView.drillCard 一致）
    func testRenderHistoryDetailStyleCards() throws {
        let cards = VStack(alignment: .leading, spacing: Spacing.md) {
            Text("历史训练详情 · 烘焙缩略图")
                .font(.btHeadline)
                .foregroundStyle(.btText)
            historyStyleCard(drillId: "drill_c001", name: "定点红球进袋", made: 8, target: 10)
            historyStyleCard(drillId: "drill_c010", name: "中杆定杆", made: 7, target: 10)
            historyStyleCard(drillId: "drill_c020", name: "走位练习", made: 6, target: 10)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        try render(cards, name: "02-history-detail-baked-thumbs", size: CGSize(width: 393, height: 600))
    }

    /// 标准 3：自定义计划构建器行缩略图接线（56×56，与 CustomPlanBuilderView.drillRow 一致）
    func testRenderCustomPlanBuilderStyleRows() throws {
        let rows = VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("自定义计划 · 烘焙缩略图")
                .font(.btHeadline)
                .foregroundStyle(.btText)
            planStyleRow(drillId: "drill_c001", name: "定点红球进袋", sets: 4, balls: 40)
            planStyleRow(drillId: "drill_c010", name: "中杆定杆", sets: 3, balls: 30)
            planStyleRow(drillId: "drill_c020", name: "走位练习", sets: 2, balls: 20)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        try render(rows, name: "03-custom-plan-builder-baked-thumbs", size: CGSize(width: 393, height: 520))
    }

    /// 标准 4：缺 PNG 走 BTBakedDrillTable 内置台呢占位（非空白）
    func testRenderMissingPNGFallback() throws {
        let panel = VStack(spacing: Spacing.lg) {
            Text("缺图占位（fake_missing_drill_id）")
                .font(.btHeadline)
                .foregroundStyle(.btText)
            HStack(spacing: Spacing.lg) {
                BTBakedDrillTable(drillId: "fake_missing_drill_id")
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                BTBakedDrillTable(drillId: "drill_c001")
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
            }
            Text("左=占位　右=真实烘焙图")
                .font(.btCaption)
                .foregroundStyle(.btTextSecondary)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        try render(panel, name: "04-missing-png-fallback", size: CGSize(width: 393, height: 280))

        XCTAssertNil(
            DrillThumbnailStore.image(for: "fake_missing_drill_id"),
            "Store must miss fake id so View uses built-in fallback"
        )
        XCTAssertNotNil(
            DrillThumbnailStore.image(for: "drill_c001"),
            "Known drill must resolve a Bundle PNG"
        )
    }

    // MARK: - Layout mirrors (production call sites)

    private func summaryStyleCard(drillId: String, name: String, rate: String, meta: String) -> some View {
        HStack(spacing: Spacing.md) {
            BTBakedDrillTable(drillId: drillId)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: BTRadius.sm)
                        .stroke(Color.btSeparator, lineWidth: 0.5)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.btSubheadlineMedium).fontWeight(.bold)
                    .foregroundStyle(.btText)
                    .lineLimit(1)
                Text(meta)
                    .font(.btCaption)
                    .foregroundStyle(.btTextTertiary)
            }
            Spacer()
            Text(rate)
                .font(.btHeadline).fontWeight(.bold)
                .foregroundStyle(.btPrimary)
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.lg))
    }

    private func historyStyleCard(drillId: String, name: String, made: Int, target: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                BTBakedDrillTable(drillId: drillId)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: BTRadius.xxs))
                Text(name)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Spacer()
                Text("\(made)/\(target)")
                    .font(.btSubheadline)
                    .foregroundStyle(.btText)
            }
            Text("第1组  \(made)/\(target)")
                .font(.btSubheadline)
                .foregroundStyle(.btTextSecondary)
                .padding(.leading, 52)
        }
        .padding(Spacing.lg)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }

    private func planStyleRow(drillId: String, name: String, sets: Int, balls: Int) -> some View {
        HStack(spacing: Spacing.lg) {
            BTBakedDrillTable(drillId: drillId)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: BTRadius.xs))
                .overlay(
                    RoundedRectangle(cornerRadius: BTRadius.xs)
                        .stroke(Color.btSeparator, lineWidth: 0.5)
                )
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(name)
                    .font(.btHeadline)
                    .foregroundStyle(.btText)
                Text("\(sets) 组 · \(balls) 球")
                    .font(.btFootnote)
                    .foregroundStyle(.btTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color.btBGSecondary)
        .clipShape(RoundedRectangle(cornerRadius: BTRadius.md))
    }
}
