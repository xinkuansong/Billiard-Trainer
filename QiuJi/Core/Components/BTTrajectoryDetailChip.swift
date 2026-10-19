import SwiftUI

/// 三档轨迹标注切换 chip（线语言 v2，问题集合条 12.5）。
///
/// 全击打页统一的按钮：点击循环「轨迹·全 → 轨迹·双 → 瞄准线」三档，
/// 业务页按显式作用域独立记忆；未接入的内容工具保留旧偏好来源。
/// 位置约定：球桌区域**右上角** overlay（不与顶部 HUD、右缘仪表柱冲突）。
struct BTTrajectoryDetailChip: View {
    @ObservedObject private var prefs = UserPreferences.shared
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    var preferencePage: TablePreferencePage? = nil
    private var detail: TrajectoryDetail {
        preferencePage.map { tablePreferences.snapshot(for: $0).trajectoryDetail } ?? prefs.trajectoryDetail
    }
    /// 档位变化后由宿主触发轨迹重绘（各页重绘入口不同）。
    var onChange: () -> Void

    var body: some View {
        Button {
            if let preferencePage {
                tablePreferences.apply(.trajectory, value: Double(detail.next.rawValue), to: preferencePage)
            } else { prefs.trajectoryDetail = detail.next }
            onChange()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: detail.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(detail.label)
                    .font(HUDStyle.labelFont)
            }
            .foregroundStyle(HUDStyle.chipTextUnselected)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .btHudGlass()
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(BTPressableStyle.capsule)
        .accessibilityLabel("轨迹标注档位")
        .accessibilityValue(detail.label)
    }
}

#Preview {
    ZStack {
        Color.black
        BTTrajectoryDetailChip(onChange: {})
    }
}
