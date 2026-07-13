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
/// `solvedLabel`/`solvedIcon` 可定制非自由态文案（默认「进袋」；翻袋/反射解球页用「求解」，W6）。
struct BTAimModeToggleButton: View {
    /// 当前是否自由模式。
    let isFree: Bool
    var isDisabled: Bool = false
    var solvedLabel: String = "进袋"
    var solvedIcon: String = "circle.circle"
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 5) {
                Image(systemName: isFree ? "scope" : solvedIcon)
                    .font(.system(size: 12, weight: .semibold))
                Text(isFree ? "自由" : solvedLabel)
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
        .accessibilityLabel("瞄准模式：\(isFree ? "自由" : solvedLabel)，点击切换")
    }
}

// MARK: - 文字动作按钮（条 15.5/15.6：去图标只留文字、调小）

struct BTTextActionButton: View {
    enum Role { case primary, plain, destructive }

    let title: String
    var role: Role = .plain
    var isDisabled: Bool = false
    /// 按钮宽度（贴边布局下右侧留白窄，压到 46 以不超出球桌右侧黑边区，G6/G11）。
    var width: CGFloat = 56
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(foreground)
                .frame(width: width, height: 30)
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
    /// 按钮宽度（贴边右柱用窄款，默认 46；见 `ShotStageMetrics.actionColumnWidth`）。
    var buttonWidth: CGFloat = ShotStageMetrics.actionColumnWidth

    var body: some View {
        VStack(spacing: 8) {
            BTTextActionButton(title: strikeTitle, role: .primary,
                               isDisabled: !strikeEnabled, width: buttonWidth, action: onStrike)
            BTTextActionButton(title: "上一杆", isDisabled: !undoEnabled,
                               width: buttonWidth, action: onUndo)
            BTTextActionButton(title: "回放", isDisabled: !playbackEnabled,
                               width: buttonWidth, action: onPlayback)
        }
    }
}

// MARK: - 开球排球图标（G9：三角形内含三个圆圈，示意码球）

/// 开球按钮/胶囊统一图标：等边三角形描边 + 内部三颗球（1 顶 2 底的迷你球堆）。
/// 单点定义，`BTBreakSideButton` 与 `breakModePill` 共用（改一处全局生效）。
struct BreakRackGlyph: View {
    var color: Color
    var size: CGFloat = 15

    var body: some View {
        Canvas { ctx, canvas in
            let w = canvas.width, h = canvas.height
            let inset = w * 0.06
            let apex = CGPoint(x: w / 2, y: inset)
            let bl = CGPoint(x: inset, y: h - inset)
            let br = CGPoint(x: w - inset, y: h - inset)
            var tri = Path()
            tri.move(to: apex); tri.addLine(to: bl); tri.addLine(to: br); tri.closeSubpath()
            ctx.stroke(tri, with: .color(color), lineWidth: max(1, w * 0.08))
            // 三颗球：顶部 1 颗、底部 2 颗（球堆前三排的顶部三角）。
            let r = w * 0.135
            let topBall = CGPoint(x: w / 2, y: h * 0.40)
            let leftBall = CGPoint(x: w * 0.35, y: h * 0.68)
            let rightBall = CGPoint(x: w * 0.65, y: h * 0.68)
            for c in [topBall, leftBall, rightBall] {
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 解球器页共享导航件（V9 条 17：翻袋 / 反射两页同构，抽共享避免双真源）
//
// 两页（翻袋 `BankShotView` / 反射 `DiamondSystemView`）统一到三解页（防守 `SnookerTacticsView`）
// 的标题样式：principal 品牌绿 14pt 标题 + 11pt 副标题承载解描述 / 无解说明（条 17.1/17.2/17.7）；
// 右上三点菜单承载原理说明入口 + 台面网格 Toggle + 恢复默认（条 17.9，G19 口径）。

/// principal 标题 + 副标题（同 `SnookerTacticsView.navStatus`）。副标题承载状态文案
/// （解读数 / 求解中 / 无解 / 自由首碰），替代原球桌左下 overlay pill。
struct BTSolverNavStatus: View {
    let title: String
    var isBusy: Bool = false
    let statusText: String

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.btPrimary)
                .lineLimit(1)
            HStack(spacing: 4) {
                if isBusy { ProgressView().controlSize(.mini).tint(.white) }
                Text(statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
        }
    }
}

/// 右上三点菜单（条 17.9，G19）：原理说明入口 + 台面网格 4×8 Toggle + 恢复默认。
/// 替代原 `info.circle` 直接开原理 sheet 的入口。
struct BTSolverMoreMenu: View {
    let scene: AngleTrainingScene
    let onPrinciple: () -> Void
    let onReset: () -> Void

    var body: some View {
        Menu {
            Section {
                Button("原理说明", systemImage: "info.circle") { onPrinciple() }
            }
            Section("显示") {
                BTTableGridMenuToggle(scene: scene)
            }
            Section {
                Button("恢复默认", systemImage: "arrow.counterclockwise") { onReset() }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.white.opacity(0.9))
        }
        .accessibilityLabel("更多")
    }
}

// MARK: - 开球按钮（固定左侧，条 18.3；无开球场景 = 禁用态）

struct BTBreakSideButton: View {
    var isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BreakRackGlyph(color: isEnabled ? Color.btPrimary : .white.opacity(0.35), size: 16)
                Text("开球")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isEnabled ? Color.btPrimary : .white.opacity(0.35))
            }
            .frame(width: 48, height: 46)
            .btHudGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("break.entry")
        .accessibilityLabel("开球")
    }
}
