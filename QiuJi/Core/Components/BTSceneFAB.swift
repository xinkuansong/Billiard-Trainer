import SwiftUI

/// 暗色场景页统一圆形浮动按钮（统一设计语言，ADR-P11-08）。
///
/// 全部 2D 球桌页（分离角/反射/翻袋/2D 瞄准）右下角的浮动操作一律使用本组件：
/// - `primary`：品牌绿渐变实底——页面的主操作（击球 / 答题 / 下一解）。
/// - `neutral`：半透明深色——次操作（重置 / 调整 / 辅助）。
/// 统一尺寸 56pt、图标 19pt + 10pt 标签、阴影与描边一致。
struct BTSceneFAB: View {
    enum Variant {
        case primary
        case neutral
    }

    let icon: String
    let title: String
    var variant: Variant = .neutral
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(background, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var background: AnyShapeStyle {
        switch variant {
        case .primary:
            AnyShapeStyle(LinearGradient(
                colors: [.btPrimary, Color(red: 0.0, green: 0.45, blue: 0.25)],
                startPoint: .top, endPoint: .bottom
            ))
        case .neutral:
            AnyShapeStyle(Color.white.opacity(0.16))
        }
    }
}

#Preview("Variants") {
    HStack(spacing: 20) {
        BTSceneFAB(icon: "play.fill", title: "击球", variant: .primary) {}
        BTSceneFAB(icon: "arrow.counterclockwise", title: "重置") {}
        BTSceneFAB(icon: "slider.horizontal.3", title: "调整") {}
    }
    .padding(40)
    .background(Color.black)
}
