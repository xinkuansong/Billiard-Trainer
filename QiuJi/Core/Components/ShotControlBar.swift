import SwiftUI

/// 统一击球控制条（P18 B2 T-P18-10，方案 §5.1 / §10-a）：场景页底栏「打点 + 力度」收口。
///
/// 两种形态：
/// - `editable`：打点可点开（打点盘浮层由页面自持）+ 力度滑条 + 读数——
///   A 类可击打页（分离角 / 走位编排台 / 球形生成器）。
/// - `readOnly`：打点只读指示 + 当前解力度读数 + 解摘要副标题——B 类反解页
///   （思路训练器 / 打一走二想三 / 斯诺克战术），塞与力度由引擎反解给出，不可编辑。
///
/// 主操作按钮（击球 / 重置 / 试打等）由 `trailing` 槽位注入；背景、外边距与布局归属
/// 由调用方持有（分离角 = 单行底栏，编排台 / B 类页 = 球库上方控制行），保证换装不动版式。
struct ShotControlBar<Trailing: View>: View {
    enum PowerControl {
        /// 可编辑力度：绑定 + 量程；`step == nil` 为连续滑条。
        case editable(Binding<Double>, range: ClosedRange<Double>, step: Double?)
        /// 只读读数：`velocity == nil` 显示「尚无解」；副标题为解摘要（塞 / 吃库 / 余量）。
        case readOnly(velocity: Double?, subtitle: String?, subtitleTint: Color?)
    }

    let spinX: Double
    let spinY: Double
    /// 非 nil = 打点图标可点（editable 形态弹打点盘）；nil = 只读指示。
    var onSpinTap: (() -> Void)? = nil
    let power: PowerControl
    /// 播放中等整体禁用：打点按钮与滑条一并禁用（trailing 按钮由调用方自管）。
    var isDisabled: Bool = false
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Spacing.sm) {
            spinIndicator
            powerControl
            trailing()
        }
    }

    // MARK: - Spin

    @ViewBuilder
    private var spinIndicator: some View {
        if let onSpinTap {
            Button(action: onSpinTap) {
                BTSpinMiniIcon(spinX: spinX, spinY: spinY, diameter: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打点")
            .disabled(isDisabled)
        } else {
            BTSpinMiniIcon(spinX: spinX, spinY: spinY, diameter: 34)
                .opacity(hasReadOnlyValue ? 1 : 0.35)
        }
    }

    private var hasReadOnlyValue: Bool {
        if case let .readOnly(velocity, _, _) = power { return velocity != nil }
        return true
    }

    // MARK: - Power

    @ViewBuilder
    private var powerControl: some View {
        switch power {
        case let .editable(value, range, step):
            Group {
                if let step {
                    Slider(value: value, in: range, step: step)
                } else {
                    Slider(value: value, in: range)
                }
            }
            .tint(Color.btPrimary)
            .disabled(isDisabled)

            Text("\(PowerDisplay.name(value.wrappedValue)) \(String(format: "%.1f", value.wrappedValue))")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)

        case let .readOnly(velocity, subtitle, subtitleTint):
            VStack(alignment: .leading, spacing: 1) {
                Text(velocity.map { "\(PowerDisplay.name($0)) \(String(format: "%.1f", $0)) m/s" } ?? "尚无解")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleTint ?? .white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// B 类反解页「试打」入口（T-P18-08）：带当前球局快照跳自由击球（编排台自由模式）。
/// 紧凑胶囊，放在 `ShotControlBar` readOnly 形态的 trailing 槽位。
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

#Preview("Editable / ReadOnly") {
    struct Host: View {
        @State var v = 2.4
        var body: some View {
            VStack(spacing: 16) {
                ShotControlBar(
                    spinX: 0.2, spinY: -0.3,
                    onSpinTap: {},
                    power: .editable($v, range: 0.5...6.0, step: 0.1)
                ) {
                    BTSceneFAB(icon: "play.fill", title: "击球", variant: .primary) {}
                }
                ShotControlBar(
                    spinX: 0, spinY: 0.4,
                    power: .readOnly(velocity: 3.1, subtitle: "高杆 · 2 库", subtitleTint: nil)
                ) {
                    ShotTryFreePlayButton {}
                }
                ShotControlBar(
                    spinX: 0, spinY: 0,
                    power: .readOnly(velocity: nil, subtitle: nil, subtitleTint: nil)
                ) {
                    ShotTryFreePlayButton(isEnabled: false) {}
                }
            }
            .padding()
            .background(Color(white: 0.11))
            .environment(\.colorScheme, .dark)
        }
    }
    return Host()
}
