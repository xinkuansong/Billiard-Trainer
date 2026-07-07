import SwiftUI

// MARK: - 页面布局规范 v2（问题集合条 18，优先级最高）
//
// 击打页共享布局件（各击打页复用，保证布局/风格全局一致）：
// - `BTTextActionButton`：文字动作按钮（去图标，条 15.5/15.6）。
// - `BTShotActionColumn`：击球 / 上一杆 / 回放 竖排列（贴右下角袋区，条 18.2）。
// - `BTBreakSideButton`：开球按钮固定左侧（无开球场景显示禁用态，条 18.4）。
//
// 摆放约定：左右两根竖排控件柱底部对齐球桌区下缘（≈ 下角袋橡胶带），
// 左柱 = 瞄准刻度轮（自由模式）+ 开球；右柱 = 打点/力度仪表 + 动作列。

// MARK: - 台面网格设置项（条 16：4x8 网格，入各球桌页设置菜单）

struct BTTableGridMenuToggle: View {
    @ObservedObject private var prefs = UserPreferences.shared
    /// 本页场景；切换后立即应用（其他页面进场时按偏好自动应用）。
    let scene: AngleTrainingScene

    var body: some View {
        Toggle("台面网格 4×8", isOn: Binding(
            get: { prefs.showTableGrid },
            set: { newValue in
                prefs.showTableGrid = newValue
                scene.setTableGridVisible(newValue)
            }
        ))
    }
}

// MARK: - 进袋/自由 单按钮点击切换（条 15.2：全页统一）

/// 瞄准模式切换：单个胶囊按钮，显示当前模式，点击切换到另一模式。
struct BTAimModeToggleButton: View {
    /// 当前是否自由模式。
    let isFree: Bool
    var isDisabled: Bool = false
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 5) {
                Image(systemName: isFree ? "scope" : "circle.circle")
                    .font(.system(size: 12, weight: .semibold))
                Text(isFree ? "自由" : "进袋")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.2.squarepath")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .btHudGlass()
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .accessibilityLabel("瞄准模式：\(isFree ? "自由" : "进袋")，点击切换")
    }
}

// MARK: - 文字动作按钮（条 15.5/15.6：去图标只留文字、调小）

struct BTTextActionButton: View {
    enum Role { case primary, plain, destructive }

    let title: String
    var role: Role = .plain
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(foreground)
                .frame(width: 56, height: 30)
                .background(background, in: Capsule())
                .overlay(Capsule().strokeBorder(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
    }

    private var foreground: Color {
        switch role {
        case .primary: return .white
        case .plain: return .white.opacity(0.85)
        case .destructive: return .btDestructive
        }
    }

    private var background: Color {
        switch role {
        case .primary: return .btPrimary
        case .plain: return .white.opacity(0.12)
        case .destructive: return .btDestructive.opacity(0.16)
        }
    }
}

// MARK: - 击球 / 上一杆 / 回放 动作列（右侧角袋下方竖排，条 18.2）

struct BTShotActionColumn: View {
    var strikeTitle: String = "击球"
    var strikeEnabled: Bool
    var onStrike: () -> Void
    var undoEnabled: Bool
    var onUndo: () -> Void
    var playbackEnabled: Bool
    var onPlayback: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            BTTextActionButton(title: strikeTitle, role: .primary,
                               isDisabled: !strikeEnabled, action: onStrike)
            BTTextActionButton(title: "上一杆", isDisabled: !undoEnabled, action: onUndo)
            BTTextActionButton(title: "回放", isDisabled: !playbackEnabled, action: onPlayback)
        }
    }
}

// MARK: - 开球按钮（固定左侧，条 18.3；无开球场景 = 禁用态）

struct BTBreakSideButton: View {
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: "triangle")
                    .font(.system(size: 12, weight: .semibold))
                Text("开球")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isEnabled ? Color.btPrimary : .white.opacity(0.35))
            .frame(width: 48, height: 46)
            .btHudGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("break.entry")
        .accessibilityLabel("开球")
    }
}
