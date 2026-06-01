import SwiftUI

/// 拟真台球视图：用分层渐变（球面明暗 + 高光斑 + 接触阴影 + 描边）在纯 SwiftUI
/// 下还原与 SceneKit PBR 球一致的质感，供角度训练的文档插图与几何训练页复用。
///
/// 不依赖网络图片或外部资源，矢量渲染，任意直径下清晰；颜色统一走设计 token。
struct BTRealisticBall: View {
    enum Kind {
        /// 母球（白）。
        case cue
        /// 目标球（暖橙，复用 `btBallTarget`）。
        case target
        /// 自定义实色球。
        case solid(Color)
        /// 幽灵球 / 假想球：半透明虚线轮廓，不画高光。
        case ghost

        var baseColor: Color {
            switch self {
            case .cue: return .btBallCue
            case .target: return .btBallTarget
            case .solid(let c): return c
            case .ghost: return .clear
            }
        }
    }

    let kind: Kind
    /// 球的直径（点）。作为 overlay 摆放时由调用方计算后传入。
    let diameter: CGFloat
    /// 可选编号（如台球号码），仅 `cue`/`target`/`solid` 显示。
    var number: Int? = nil
    /// 是否绘制接触投影（小卡片中可关掉以免拥挤）。
    var showsContactShadow: Bool = true

    var body: some View {
        ZStack {
            if showsContactShadow, !isGhost {
                Ellipse()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: diameter * 0.92, height: diameter * 0.26)
                    .blur(radius: diameter * 0.05)
                    .offset(y: diameter * 0.48)
            }

            if isGhost {
                ghostBody
            } else {
                solidBody
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var isGhost: Bool {
        if case .ghost = kind { return true }
        return false
    }

    // MARK: - Solid sphere

    private var solidBody: some View {
        ZStack {
            Circle().fill(kind.baseColor)

            // 球面边缘暗化（从中心向外加深，营造球体体积感）
            Circle().fill(
                RadialGradient(
                    colors: [.clear, .black.opacity(0.46)],
                    center: UnitPoint(x: 0.5, y: 0.52),
                    startRadius: diameter * 0.08,
                    endRadius: diameter * 0.52
                )
            )

            // 左上主光（漫反射亮面）
            Circle().fill(
                RadialGradient(
                    colors: [.white.opacity(0.55), .clear],
                    center: UnitPoint(x: 0.34, y: 0.30),
                    startRadius: 0,
                    endRadius: diameter * 0.55
                )
            )
            .blendMode(.screen)

            if let number {
                numberBadge(number)
            }

            // 镜面高光斑
            Ellipse()
                .fill(Color.white.opacity(0.92))
                .frame(width: diameter * 0.22, height: diameter * 0.15)
                .blur(radius: diameter * 0.015)
                .offset(x: -diameter * 0.17, y: -diameter * 0.20)

            Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: max(0.5, diameter * 0.012))
        }
    }

    private func numberBadge(_ number: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: diameter * 0.46, height: diameter * 0.46)
            Text("\(number)")
                .font(.system(size: diameter * 0.30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.78))
        }
    }

    // MARK: - Ghost ball

    private var ghostBody: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.14))
            Circle().fill(
                RadialGradient(
                    colors: [.white.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.34, y: 0.30),
                    startRadius: 0,
                    endRadius: diameter * 0.55
                )
            )
            Circle().strokeBorder(
                Color.white.opacity(0.75),
                style: StrokeStyle(lineWidth: max(1, diameter * 0.025), dash: [diameter * 0.10, diameter * 0.07])
            )
        }
    }
}

// MARK: - Preview

#Preview("Balls") {
    HStack(spacing: 24) {
        BTRealisticBall(kind: .cue, diameter: 64)
        BTRealisticBall(kind: .target, diameter: 64)
        BTRealisticBall(kind: .target, diameter: 64, number: 8)
        BTRealisticBall(kind: .ghost, diameter: 64)
    }
    .padding(40)
    .background(Color.btTableFelt)
}
