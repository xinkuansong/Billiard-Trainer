import SwiftUI

/// 训练计划「杂志封面」色卡 —— 方向 A：纯排版，无图片。
///
/// 用一种饱和色调 + 一个超大中文字 + 编号小字代替真实封面图。
/// 等动作库素材（15.tutorial_video）到位后，可把渐变层整体替换为图片，结构不变。
///
/// 色值 / 水印规范：`CoverPalette`（与练习页分区封面同一真源，v27 W2 / DR-044）。
///
/// 复用场景：
/// - 列表卡：方形海报，标题由调用方在底部叠加。
/// - 详情页 Hero：280pt 全宽封面，标题由调用方在左下角叠加。
struct BTPlanCover: View {
    let targetLevel: String
    let issueNumber: Int
    /// Absolute glyph size; `nil` = `CoverPalette.Glyph.planListAbsoluteSize` (token; was inline 96).
    var glyphSize: CGFloat? = nil
    var corner: CGFloat = BTRadius.md
    /// 是否显示左上角「期号」标签。全屏 Hero（详情页）下隐藏，避免与状态栏/返回键
    /// 重叠（UR-20260529 U-02）；列表海报保持显示。
    var showIssueLabel: Bool = true

    private var style: CoverPalette.PlanStyle { CoverPalette.PlanStyle.forLevel(targetLevel) }

    private var resolvedGlyphSize: CGFloat {
        glyphSize ?? CoverPalette.Glyph.planListAbsoluteSize
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [style.top, style.bottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(style.glyph)
                .font(.btCoverWatermark(size: resolvedGlyphSize))
                .foregroundStyle(style.glyphColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if showIssueLabel {
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "%02d", issueNumber))
                                .font(.system(size: resolvedGlyphSize * 0.21, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("第 \(issueNumber) 期")
                                .font(.system(size: resolvedGlyphSize * 0.095, weight: .semibold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.white.opacity(0.92))

                        Spacer()
                    }
                    Spacer()
                }
                .padding(Spacing.md)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Covers") {
    let levels = ["L0→L1", "L1", "L1→L2", "L2", "L3", "L3→L4"]
    let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]
    return LazyVGrid(columns: cols, spacing: 12) {
        ForEach(Array(levels.enumerated()), id: \.offset) { idx, lvl in
            BTPlanCover(targetLevel: lvl, issueNumber: idx + 1)
                .aspectRatio(0.85, contentMode: .fit)
        }
    }
    .padding()
    .background(.btBG)
}
