import SwiftUI

/// 标准台球「俯视球面」矢量视图：用分层渐变还原球体明暗 + 高光，号码画在中心白圈里。
///
/// 替代走位编排台早期的 USDZ 离屏渲染缩略图（`BallFaceRenderer`）：
/// USDZ 各球贴图 UV 布局不一致，单一姿态没法让所有号码正立 → 只能靠号码角标兜底。
/// 2D 矢量直接绘制号码天生正立、颜色精确（标准球色板）、任意直径清晰、零外部资源依赖。
///
/// 球号语义（标准花式九球/斯诺无关，按美式台球约定）：
/// - 1..8 单色球（solid）；9..15 花色球（stripe，白底 + 彩色环带）；母球纯白无号。
struct PoolBallFace: View {
    /// 球键：母球 `"cueBall"`，目标球 `"_1"`..`"_15"`（与 `PositionPlayBall` 一致）。
    let key: String
    /// 球直径（点）。
    let diameter: CGFloat

    var body: some View {
        let style = PoolBallStyle.style(for: key)
        ZStack {
            // 底：单色球填满，花色球以白为底、彩带居中横贯。
            Circle().fill(style.isStripe ? Color.white : style.color)

            if style.isStripe {
                stripeBand(style.color)
            }

            // 球面边缘暗化（体积感）。母球用更轻的暗化，避免纯白被压成灰。
            Circle().fill(
                RadialGradient(
                    colors: [.clear, .black.opacity(style.isCue ? 0.2 : 0.42)],
                    center: UnitPoint(x: 0.5, y: 0.52),
                    startRadius: diameter * 0.08,
                    endRadius: diameter * 0.52
                )
            )

            // 左上主光（漫反射亮面）。
            Circle().fill(
                RadialGradient(
                    colors: [.white.opacity(0.5), .clear],
                    center: UnitPoint(x: 0.34, y: 0.30),
                    startRadius: 0,
                    endRadius: diameter * 0.55
                )
            )
            .blendMode(.screen)

            if let number = style.number {
                numberBadge(number)
            }

            // 母球中心红点（标准训练母球标记）。
            if style.isCue {
                Circle()
                    .fill(Color(red: 0.85, green: 0.16, blue: 0.16))
                    .frame(width: diameter * 0.16, height: diameter * 0.16)
            }

            // 镜面高光斑。
            Ellipse()
                .fill(Color.white.opacity(0.9))
                .frame(width: diameter * 0.2, height: diameter * 0.14)
                .blur(radius: diameter * 0.015)
                .offset(x: -diameter * 0.17, y: -diameter * 0.20)

            Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: max(0.5, diameter * 0.012))
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }

    /// 花色环带：横贯球面的彩色带，上下留白还原标准花色球外观。
    /// 带宽内嵌于 ZStack（宽=直径），外层 `.clipShape(Circle())` 自动把带端裁成弧形。
    private func stripeBand(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: diameter, height: diameter * 0.62)
    }

    private func numberBadge(_ number: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: diameter * 0.5, height: diameter * 0.5)
            Text("\(number)")
                .font(.system(size: diameter * 0.3, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.82))
        }
    }
}

// MARK: - Standard pool ball color palette

/// 标准美式台球色板（钉死的领域契约）：1黄 2蓝 3红 4紫 5橙 6绿 7栗 8黑；
/// 9..15 复用 1..7 色作花色（白底彩带）；母球纯白。
enum PoolBallStyle {
    struct Spec {
        let color: Color
        let number: Int?
        let isStripe: Bool
        var isCue: Bool = false
    }

    /// 球号 → 单色色值（1..7；8 为黑，单列）。
    private static func solidColor(_ n: Int) -> Color {
        switch n {
        case 1: return Color(red: 0.96, green: 0.78, blue: 0.10)   // 黄
        case 2: return Color(red: 0.10, green: 0.32, blue: 0.72)   // 蓝
        case 3: return Color(red: 0.84, green: 0.16, blue: 0.14)   // 红
        case 4: return Color(red: 0.40, green: 0.20, blue: 0.55)   // 紫
        case 5: return Color(red: 0.92, green: 0.45, blue: 0.08)   // 橙
        case 6: return Color(red: 0.10, green: 0.52, blue: 0.30)   // 绿
        case 7: return Color(red: 0.55, green: 0.13, blue: 0.13)   // 栗（暗红）
        case 8: return Color(white: 0.10)                          // 黑
        default: return Color(white: 0.5)
        }
    }

    static func style(for key: String) -> Spec {
        if PositionPlayBall.isCue(key) {
            return Spec(color: .white, number: nil, isStripe: false, isCue: true)
        }
        guard let n = PositionPlayBall.number(for: key) else {
            return Spec(color: Color(white: 0.5), number: nil, isStripe: false)
        }
        if n <= 8 {
            return Spec(color: solidColor(n), number: n, isStripe: false)
        }
        // 9..15 花色：复用 1..7 的色（9→1黄, 10→2蓝, …, 15→7栗）。
        return Spec(color: solidColor(n - 8), number: n, isStripe: true)
    }
}

// MARK: - Preview

#Preview("Pool balls") {
    let cols = [GridItem(.adaptive(minimum: 56), spacing: 12)]
    return ScrollView {
        LazyVGrid(columns: cols, spacing: 12) {
            ForEach(PositionPlayBall.allKeys, id: \.self) { key in
                PoolBallFace(key: key, diameter: 56)
            }
        }
        .padding(24)
    }
    .background(Color.btTableFelt)
}
