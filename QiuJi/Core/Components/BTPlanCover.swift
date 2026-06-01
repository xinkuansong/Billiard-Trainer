import SwiftUI

/// 训练计划「杂志封面」色卡 —— 方向 A：纯排版，无图片。
///
/// 用一种饱和色调 + 一个超大中文字 + 编号小字代替真实封面图。
/// 等动作库素材（15.tutorial_video）到位后，可把渐变层整体替换为图片，结构不变。
///
/// 复用场景：
/// - 列表卡：方形海报，标题由调用方在底部叠加。
/// - 详情页 Hero：280pt 全宽封面，标题由调用方在左下角叠加。
struct BTPlanCover: View {
    let targetLevel: String
    let issueNumber: Int
    var glyphSize: CGFloat = 96
    var corner: CGFloat = BTRadius.md
    /// 是否显示左上角「期号」标签。全屏 Hero（详情页）下隐藏，避免与状态栏/返回键
    /// 重叠（UR-20260529 U-02）；列表海报保持显示。
    var showIssueLabel: Bool = true

    private var style: CoverStyle { CoverStyle.forLevel(targetLevel) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [style.top, style.bottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(style.glyph)
                .font(.system(size: glyphSize, weight: .black, design: .rounded))
                .foregroundStyle(style.glyphColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if showIssueLabel {
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(String(format: "%02d", issueNumber))
                                .font(.system(size: glyphSize * 0.21, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("第 \(issueNumber) 期")
                                .font(.system(size: glyphSize * 0.095, weight: .semibold))
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

// MARK: - Cover Palette（装饰性饱和色板，Light/Dark 通用，白/金文字）

private struct CoverStyle {
    let top: Color
    let bottom: Color
    let glyph: String
    let glyphColor: Color

    static func forLevel(_ level: String) -> CoverStyle {
        switch level {
        case "L0→L1":
            return .init(top: Color(red: 0.16, green: 0.55, blue: 0.34),
                         bottom: Color(red: 0.09, green: 0.34, blue: 0.21),
                         glyph: "入", glyphColor: .white.opacity(0.16))
        case "L1":
            return .init(top: Color(red: 0.11, green: 0.46, blue: 0.95),
                         bottom: Color(red: 0.05, green: 0.24, blue: 0.58),
                         glyph: "初", glyphColor: .white.opacity(0.16))
        case "L1→L2":
            return .init(top: Color(red: 0.0, green: 0.60, blue: 0.60),
                         bottom: Color(red: 0.0, green: 0.36, blue: 0.40),
                         glyph: "进", glyphColor: .white.opacity(0.16))
        case "L2":
            return .init(top: Color(red: 0.18, green: 0.18, blue: 0.20),
                         bottom: Color(red: 0.07, green: 0.07, blue: 0.08),
                         glyph: "中", glyphColor: Color(red: 0.84, green: 0.65, blue: 0.20).opacity(0.55))
        case "L3":
            return .init(top: Color(red: 0.55, green: 0.32, blue: 0.05),
                         bottom: Color(red: 0.33, green: 0.18, blue: 0.02),
                         glyph: "高", glyphColor: .white.opacity(0.17))
        case "L3→L4":
            return .init(top: Color(red: 0.62, green: 0.14, blue: 0.14),
                         bottom: Color(red: 0.36, green: 0.06, blue: 0.06),
                         glyph: "专", glyphColor: .white.opacity(0.18))
        default:
            return .init(top: Color(red: 0.16, green: 0.55, blue: 0.34),
                         bottom: Color(red: 0.09, green: 0.34, blue: 0.21),
                         glyph: "球", glyphColor: .white.opacity(0.16))
        }
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
