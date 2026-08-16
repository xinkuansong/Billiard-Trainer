import SwiftUI

/// 训练计划「杂志封面」色卡 —— 方向 A：纯排版，无图片。
///
/// 用一种饱和色调 + 课程主题水印 + 编号小字代替真实封面图。
/// 等动作库素材（15.tutorial_video）到位后，可把渐变层整体替换为图片，结构不变。
///
/// 色值 / 水印规范：`CoverPalette`（与练习页分区封面同一真源，v27 W2 / DR-044）。
///
/// 复用场景（v28 W2：列表态 / Hero 态参数分离）：
/// - `.list`：网格/计划列表封面；期号可见；标题由 `BTContentGridCard` 放在封面下。
/// - `.hero`：详情页全宽 Hero；隐藏期号；大字水印；标题仍由调用方叠在左下。
struct BTPlanCover: View {
    enum Mode: Equatable {
        case list
        case hero
    }

    let planId: String
    let targetLevel: String
    let issueNumber: Int
    var mode: Mode = .list
    /// Absolute glyph size override; `nil` resolves from `mode`.
    var glyphSize: CGFloat? = nil
    var corner: CGFloat? = nil
    /// Explicit override; `nil` resolves from `mode` (list=true, hero=false).
    var showIssueLabel: Bool? = nil

    private var style: CoverPalette.PlanStyle { CoverPalette.PlanStyle.forLevel(targetLevel) }
    private var label: String { PlanCoverLabel.text(for: planId) }
    private var displayLabel: String { PlanCoverLabel.displayText(for: planId) }

    private var resolvedBaseGlyphSize: CGFloat {
        if let glyphSize { return glyphSize }
        switch mode {
        case .list: return CoverPalette.Glyph.planListAbsoluteSize
        case .hero: return CoverPalette.Glyph.planHeroAbsoluteSize
        }
    }

    private var resolvedLabelSize: CGFloat {
        // Single-line (1–3 chars) ≈ 2/3 of DR-049 scales; 4-char two-line keeps 0.40 (DR-056).
        let scale: CGFloat
        switch label.count {
        case ...2: scale = 0.40
        case 3: scale = 0.32
        default: scale = 0.40
        }
        return resolvedBaseGlyphSize * scale
    }

    private var resolvedLabelVerticalOffset: CGFloat {
        resolvedBaseGlyphSize * 0.06
    }

    private var resolvedCorner: CGFloat {
        corner ?? (mode == .hero ? 0 : BTRadius.md)
    }

    private var resolvedShowIssueLabel: Bool {
        showIssueLabel ?? (mode == .list)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [style.top, style.bottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(displayLabel)
                .font(.btCoverWatermark(size: resolvedLabelSize))
                .foregroundStyle(style.glyphColor)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .lineLimit(label.count == 4 ? 2 : 1)
                .padding(.horizontal, Spacing.xl)
                .offset(y: resolvedLabelVerticalOffset)

            if resolvedShowIssueLabel {
                VStack {
                    HStack(alignment: .top) {
                        Text("第 \(issueNumber) 期")
                            .font(.system(size: resolvedBaseGlyphSize * 0.095, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.92))

                        Spacer()
                    }
                    Spacer()
                }
                .padding(Spacing.md)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: resolvedCorner))
        .accessibilityHidden(true)
    }
}

enum PlanCoverLabel {
    static func text(for planId: String) -> String {
        switch planId {
        case "plan_beginner": return "入门"
        case "plan_cueball": return "杆法"
        case "plan_accuracy": return "准度"
        case "plan_force": return "控力"
        case "plan_separation": return "分离角"
        case "plan_english": return "加塞"
        case "plan_positioning": return "走位Ⅰ"
        case "plan_positioning2": return "走位Ⅱ"
        case "plan_intermediate": return "准度Ⅱ"
        case "plan_accuracy3": return "准度Ⅲ"
        case "plan_advanced": return "特殊球"
        case "plan_fullskill": return "全能综合"
        default: return "训练"
        }
    }

    static func displayText(for planId: String) -> String {
        let label = text(for: planId)
        guard label.count == 4 else { return label }
        let split = label.index(label.startIndex, offsetBy: 2)
        return "\(label[..<split])\n\(label[split...])"
    }
}

// MARK: - Previews

#Preview("Covers") {
    let samples = [
        ("plan_beginner", "L0→L1"),
        ("plan_cueball", "L1"),
        ("plan_positioning", "L1→L2"),
        ("plan_intermediate", "L2"),
        ("plan_advanced", "L3"),
        ("plan_fullskill", "L3→L4"),
    ]
    let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]
    return LazyVGrid(columns: cols, spacing: 12) {
        ForEach(Array(samples.enumerated()), id: \.offset) { idx, sample in
            BTPlanCover(planId: sample.0, targetLevel: sample.1, issueNumber: idx + 1)
                .aspectRatio(0.85, contentMode: .fit)
        }
    }
    .padding()
    .background(.btBG)
}
