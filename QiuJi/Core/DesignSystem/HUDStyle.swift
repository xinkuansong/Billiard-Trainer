import SwiftUI

/// HUD 视觉风格「仪表玻璃」唯一真源（T-P18-45，设计稿 §1.7）。
///
/// 七分区是骨架、读数胶囊是零件，本文件定皮肤：
/// - 材质配方 `hudGlass`：黑 60% 暗玻璃 + 背景模糊 + 0.5pt 白 12% 发丝描边，**无阴影**（黑场上光效一律禁止）。
/// - 文字三级：label（11pt semibold 白 55%）/ value（15pt bold rounded mono）/ title（14pt semibold 品牌绿）。
/// - 状态语法：未选 = 玻璃底 + 白 75% 字；选中 = 品牌绿实底 + 白字；禁用 = 文字 30%。
/// - 刻度语法：三级刻度白 40/25/15%，当前位置金；瞄准轮与力度柱同族。
enum HUDStyle {
    // MARK: 材质配方
    /// 暗玻璃底色（叠在系统模糊材质之上）。
    static let glassTint = Color.black.opacity(0.6)
    /// 发丝描边（黑场上代替阴影做分层）。
    static let hairline = Color.white.opacity(0.12)
    static let hairlineWidth: CGFloat = 0.5

    // MARK: 场景底栏 / 面板（ADR-P11-09 / SPEC §8.1）
    /// 场景页底栏与控制面板底色。`Color(white: 0.11)` 唯一真源；**禁止**改成常规页 `btBG*`。
    static let panelBackground = Color(white: 0.11)

    // MARK: 尺子家族外壳（F-CL-01）
    /// 瞄准轮 / 力度柱同族圆角。统一为 `BTRadius.md`（12）；原 AimWheel 字面量 10 收编至此。
    static let rulerCornerRadius: CGFloat = BTRadius.md

    // MARK: FAB 渐变（F-GL-07）
    /// `BTSceneFAB` primary 渐变末端（逐位保留原 `Color(red:0, green:0.45, blue:0.25)`）。
    static let fabPrimaryEnd = Color(red: 0.0, green: 0.45, blue: 0.25)

    // MARK: 文字三级
    static let labelFont = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let labelColor = Color.white.opacity(0.55)
    static let valueFont = Font.system(size: 15, weight: .bold, design: .rounded)
    /// 紧凑档（底部条 / 内联读数等竖向空间受限处），式样同族只降字号。
    static let valueFontCompact = Font.system(size: 13, weight: .bold, design: .rounded)
    static let labelFontCompact = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let titleFont = Font.system(size: 14, weight: .semibold, design: .rounded)
    static let titleColor = Color.btPrimary

    // MARK: value 语义色（金=可调/方案量值，白=测量结果，红=失误）
    static let valueMeasured = Color.white
    static let valueAdjustable = Color.btAccent
    static let valueAlert = Color.btDestructive

    // MARK: 状态语法（chip / 按钮）
    static let chipTextUnselected = Color.white.opacity(0.75)
    static let chipTextDisabledOpacity: CGFloat = 0.3

    // MARK: HUD 指标条竖分隔线（v7 C21 / D5）
    /// Unified metric-row separator height — **12** (hit-page baseline; was 12/14 split).
    static let metricSeparatorHeight: CGFloat = 12
    static let metricSeparatorFill = Color.white.opacity(0.18)

    // MARK: 刻度语法（瞄准轮与力度柱同族）
    static let tickMajor = Color.white.opacity(0.40)
    static let tickMid = Color.white.opacity(0.25)
    static let tickMinor = Color.white.opacity(0.15)
    static let tickIndicator = Color.btAccent

    /// 三级刻度取色（瞄准轮/力度柱同族「尺子」共用）。
    static func tickColor(major: Bool, mid: Bool) -> Color {
        major ? tickMajor : (mid ? tickMid : tickMinor)
    }

    /// 力度柱填充水位渐变（§1.5：低→高 = 暗绿→暗金→暗橙，克制暗调禁高饱和）。
    static let powerGradient = [
        Color(red: 0.09, green: 0.28, blue: 0.17),
        Color(red: 0.36, green: 0.29, blue: 0.09),
        Color(red: 0.42, green: 0.20, blue: 0.07),
    ]
}

// MARK: - hudGlass 材质修饰器

private struct HUDGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(HUDStyle.glassTint)
                    .background(shape.fill(.ultraThinMaterial))
                    .environment(\.colorScheme, .dark)
            }
            .overlay(shape.strokeBorder(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
    }
}

extension View {
    /// 仪表玻璃底（唯一材质配方）：黑 60% 暗玻璃 + 模糊 + 发丝描边，无阴影。
    /// 形状语法只允许三种：胶囊（默认）、正圆、圆角矩形。
    func btHudGlass() -> some View {
        modifier(HUDGlassModifier(shape: Capsule()))
    }

    func btHudGlass<S: InsettableShape>(in shape: S) -> some View {
        modifier(HUDGlassModifier(shape: shape))
    }
}

/// HUD 指标条竖分隔线（1×12，白 18%）— v7 C21 / D5 单一真源。
struct BTHudMetricSeparator: View {
    var body: some View {
        Rectangle()
            .fill(HUDStyle.metricSeparatorFill)
            .frame(width: 1, height: HUDStyle.metricSeparatorHeight)
    }
}
