import SwiftUI

/// 统一击球控制条 v2（T-P18-10 立、T-P18-44 简化）：B 类反解页底栏「解读数 + 试打」收口。
///
/// v2 变更（设计稿 §1.5）：A 类可击打页的「打点 + 力度」编辑控件整体移到贴桌右缘的
/// `BTShotInstrumentColumn` 仪表柱，本组件删除 editable 形态——底部条只剩执行动作与解读数：
/// - `readOnly`：打点只读指示 + 当前解力度读数 + 解摘要副标题——B 类反解页
///   （思路训练器 / 打一走二想三 / 斯诺克战术），塞与力度由引擎反解给出，不可编辑。
///
/// 主操作按钮（求解 / 试打等）由 `trailing` 槽位注入；背景、外边距与布局归属由调用方持有。
struct ShotControlBar<Trailing: View>: View {
    let spinX: Double
    let spinY: Double
    /// 只读读数：`velocity == nil` 显示「尚无解」；副标题为解摘要（塞 / 吃库 / 余量）。
    let velocity: Double?
    var subtitle: String? = nil
    var subtitleTint: Color? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Spacing.sm) {
            BTSpinMiniIcon(spinX: spinX, spinY: spinY, diameter: 34)
                .opacity(velocity != nil ? 1 : 0.35)

            VStack(alignment: .leading, spacing: 1) {
                // 引擎反解力度 = 方案量值 → 金；「尚无解」为状态文案保持白。
                Text(velocity.map { "\(PowerDisplay.name($0)) \(String(format: "%.1f", $0)) m/s" } ?? "尚无解")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(velocity != nil ? HUDStyle.valueAdjustable : .white)
                    .monospacedDigit()
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleTint ?? .white.opacity(0.7))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)

            trailing()
        }
    }
}

/// B 类反解页「试打」入口（T-P18-08）：带当前球局快照跳自由击球（编排台自由模式）。
/// 紧凑胶囊，放在 `ShotControlBar` trailing 槽位。
struct ShotTryFreePlayButton: View {
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "scope")
                    .font(.system(size: 11, weight: .bold))
                Text("试打")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(isEnabled ? Color.btAccent : .white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("试打")
        .disabled(!isEnabled)
    }
}

#Preview("ReadOnly") {
    VStack(spacing: 16) {
        ShotControlBar(spinX: 0, spinY: 0.4, velocity: 3.1, subtitle: "高杆 · 2 库") {
            ShotTryFreePlayButton {}
        }
        ShotControlBar(spinX: 0, spinY: 0, velocity: nil) {
            ShotTryFreePlayButton(isEnabled: false) {}
        }
    }
    .padding()
    .background(Color(white: 0.11))
    .environment(\.colorScheme, .dark)
}
