import SwiftUI

/// 约束清除键（Q15.3）：正常按钮尺寸的橡皮擦，放在「摆球」chip 右侧。
/// 思路训练 / 打一走二想三共用同一口径（防守页随 V8 接入）。
/// 常驻显示——禁用时降透明度而非移除，避免行内布局跳变。
struct BTEraserButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "eraser")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(isEnabled ? 0.9 : 0.32))
                .frame(width: 42, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(isEnabled ? 0.10 : 0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(isEnabled ? 0.18 : 0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("清除约束")
    }
}
