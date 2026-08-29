import SwiftUI

/// 训练计划封面——一卡一图，无彩色罩、无主题水印（v46 DR-080 / DR-081）。
///
/// Bundle 静物 PNG（`AtmosphereCatalog.image(forPlanId:)`）+ 中性暗幕。
/// 缺图时回退为现网纯渐变。卡面禁止再叠系列色罩或「入门 / 准度 / 控力」类大字。
///
/// 复用场景（v28 W2：列表态 / Hero 态参数分离）：
/// - `.list`：网格/计划列表封面；标题由 `BTContentGridCard` 放在封面下。
/// - `.hero`：详情页全宽 Hero；标题仍由调用方叠在左下。
struct BTPlanCover: View {
    enum Mode: Equatable {
        case list
        case hero
    }

    let planId: String
    let targetLevel: String
    var issueNumber: Int = 0
    var mode: Mode = .list
    var corner: CGFloat? = nil

    private var style: CoverPalette.PlanStyle { CoverPalette.PlanStyle.forLevel(targetLevel) }

    private var resolvedCorner: CGFloat {
        corner ?? (mode == .hero ? 0 : BTRadius.md)
    }

    var body: some View {
        ZStack {
            BTAtmosphereLayer(
                image: AtmosphereCatalog.image(forPlanId: planId),
                pair: CoverPalette.Pair(top: style.top, bottom: style.bottom),
                crop: mode == .hero ? .hero : .list,
                showsColorWash: false,
                showsNeutralScrim: true
            )

            if mode == .list {
                VStack {
                    HStack(alignment: .top) {
                        Text("第 \(issueNumber) 期")
                            .font(.system(size: CoverPalette.Glyph.planListAbsoluteSize * 0.095, weight: .semibold))
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
