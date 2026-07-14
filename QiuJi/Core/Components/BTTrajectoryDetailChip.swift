import SwiftUI

/// 三档轨迹标注切换 chip（线语言 v2，问题集合条 12.5）。
///
/// 全击打页统一的按钮：点击循环「轨迹·全 → 轨迹·双 → 瞄准线」三档，
/// 档位持久化在 `UserPreferences.trajectoryDetail`（全局共享，跨页一致）。
/// 位置约定：球桌区域**右上角** overlay（不与顶部 HUD、右缘仪表柱冲突）。
struct BTTrajectoryDetailChip: View {
    @ObservedObject private var prefs = UserPreferences.shared
    /// 档位变化后由宿主触发轨迹重绘（各页重绘入口不同）。
    var onChange: () -> Void

    var body: some View {
        Button {
            prefs.trajectoryDetail = prefs.trajectoryDetail.next
            onChange()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: prefs.trajectoryDetail.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(prefs.trajectoryDetail.label)
                    .font(HUDStyle.labelFont)
            }
            .foregroundStyle(HUDStyle.chipTextUnselected)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .btHudGlass()
        }
        .buttonStyle(BTPressableStyle.capsule)
        .accessibilityLabel("轨迹标注档位")
        .accessibilityValue(prefs.trajectoryDetail.label)
    }
}

#Preview {
    ZStack {
        Color.black
        BTTrajectoryDetailChip(onChange: {})
    }
}
