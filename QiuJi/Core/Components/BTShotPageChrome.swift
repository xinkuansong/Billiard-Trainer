import SwiftUI

/// Shared bridge from Light content pages into the fixed dark billiards workspace.
/// The stage stays black; only its navigation contract is centralized so every
/// tool keeps the same inline title, dark chrome and hidden content Tab bar.
private struct BTDarkToolChromeModifier: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

extension View {
    func btDarkToolChrome(_ title: String) -> some View {
        modifier(BTDarkToolChromeModifier(title: title))
    }
}

// MARK: - 页面布局规范 v2（问题集合条 18，优先级最高）
//
// 击打页共享布局件（各击打页复用，保证布局/风格全局一致）：
// - `BTTextActionButton`：文字动作按钮（去图标，条 15.5/15.6）。
// - `BTShotActionColumn`：击球 / 上一杆 / 回放 竖排列（贴右下角袋区，条 18.2）。
// - `BTBreakSideButton`：开球按钮固定左侧（可达宿主可点；无开球页按 D14 **不显示**占位）。
// - `BTSolverLeftColumn`：反解页「求解 / 下一解」竖叠（G24 / C26）。
// - Slot L1（贴底）外形统一 `ShotStageMetrics.breakButtonSize`（48×46）。
//
// 摆放约定：左右两根竖排控件柱底部对齐球桌区下缘（≈ 下角袋橡胶带），
// 左柱 = 瞄准刻度轮（自由模式）+ Slot L1；右柱 = 打点/力度仪表 + 动作列。

// MARK: - 主击钮文案字典（G24 / C25 / D13）

/// `BTShotActionColumn.strikeTitle` 合法取值（v7 W9a）。
/// 自由试打 →「击球」；解演示 →「击打」；PlanThree →「打一」（D13）；忙碌态见下。
enum BTStrikeTitle {
    /// 自由试打页主击（FreePlay / ShotSim / Composer 自由 / Silu / Snooker / Batch / Bank·自由）。
    static let freePlay = "击球"
    /// 解演示主击（Bank/Diamond 求解态、Composer 序列模式）。
    static let solutionDemo = "击打"
    /// PlanThree 主击（D13 保留）。
    static let planThree = "打一"
    /// 击球进行中（自由试打 / 反解打出）。
    static let freePlayBusy = "击球中"
    /// 序列演示进行中，点击请求「打完当前杆后停」（v28 Q1：演示可暂停，故不再用只读的「演示中」）。
    static let sequencePause = "暂停"
    /// 序列演示已暂停，点击从下一杆继续。
    static let sequenceResume = "继续"

    /// 全量合法值（grep / 审查用）。
    static let allLegal: Set<String> = [
        freePlay, solutionDemo, planThree, freePlayBusy,
        sequencePause, sequenceResume
    ]
}

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

/// 近球瞄准特写 HUD 开关（v23 E3）。默认开启；关闭后近区拖轮不再浮出特写，
/// 毫米级精调增益不受影响（两者可独立取舍）。
struct BTAimCloseupMenuToggle: View {
    @ObservedObject private var prefs = UserPreferences.shared

    var body: some View {
        Toggle("瞄准特写", isOn: Binding(
            get: { prefs.showAimCloseup },
            set: { prefs.showAimCloseup = $0 }
        ))
        .accessibilityIdentifier("menu.aimCloseup")
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
        .buttonStyle(BTPressableStyle.capsule)
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
    var height: CGFloat = 30
    var fontSize: CGFloat = 13
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(foreground)
                .frame(width: width, height: height)
                .background(background, in: Capsule())
                .overlay(Capsule().strokeBorder(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }
        .buttonStyle(BTPressableStyle.capsule)
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
    /// 主击文案：必须取自 `BTStrikeTitle` 合法值（G24 / C25）。
    var strikeTitle: String = BTStrikeTitle.freePlay
    var strikeEnabled: Bool
    var onStrike: () -> Void
    /// 中钮文案：真 `undoLastShot` 页用「上一杆」；`replayCurrent`（重打）页传「重打」（v7 C5/D4）。
    var undoTitle: String = "上一杆"
    var undoEnabled: Bool
    var onUndo: () -> Void
    /// 下钮文案：默认「回放」；序列演示模式传「重播本杆」。
    var playbackTitle: String = "回放"
    var playbackEnabled: Bool
    var onPlayback: () -> Void
    /// 按钮宽度（贴边右柱用窄款，默认 46；见 `ShotStageMetrics.actionColumnWidth`）。
    var buttonWidth: CGFloat = ShotStageMetrics.actionColumnWidth

    var body: some View {
        VStack(spacing: 8) {
            BTTextActionButton(title: strikeTitle, role: .primary,
                               isDisabled: !strikeEnabled, width: buttonWidth, action: onStrike)
            BTTextActionButton(title: undoTitle, isDisabled: !undoEnabled,
                               width: buttonWidth, action: onUndo)
            BTTextActionButton(title: playbackTitle, isDisabled: !playbackEnabled,
                               width: buttonWidth, action: onPlayback)
        }
    }
}

// MARK: - 反解「求解 / 下一解」竖叠（G24 / C26）

/// Silu / PlanThree / Snooker 左下求解柱。Slot L1（开球等）由宿主叠在下方，外形见 `BTSlotL1Button`。
struct BTSolverLeftColumn: View {
    var canSolve: Bool
    var onSolve: () -> Void
    var canNext: Bool
    var onNext: () -> Void
    var buttonWidth: CGFloat = ShotStageMetrics.actionColumnWidth

    /// 仅求解柱：30 + 8 + 30。
    static let stackSize = CGSize(width: 48, height: 68)
    /// 求解柱 + 间距 + Slot L1（开球 46）：与历史 Silu 族 122 对齐。
    static let stackWithSlotL1Size = CGSize(
        width: 48,
        height: stackSize.height + 8 + ShotStageMetrics.breakButtonSize.height
    )

    var body: some View {
        VStack(spacing: 8) {
            BTTextActionButton(title: "求解", role: .primary,
                               isDisabled: !canSolve, width: buttonWidth, action: onSolve)
            BTTextActionButton(title: "下一解",
                               isDisabled: !canNext, width: buttonWidth, action: onNext)
        }
    }
}

// MARK: - Slot L1 贴底角钮（G24：开球 | 禁用开球 | 下一解 | 恢复球形 | 重摆球形）

/// 与 `BTBreakSideButton` 同外形尺寸（48×46 玻璃卡）。开球专用 glyph 仍用 `BTBreakSideButton`。
struct BTSlotL1Button: View {
    let title: String
    let systemImage: String
    var isEnabled: Bool
    var accessibilityId: String
    var accessibilityName: String? = nil
    let action: () -> Void

    private var size: CGSize { ShotStageMetrics.breakButtonSize }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isEnabled ? Color.btPrimary : .white.opacity(0.35))
            .frame(width: size.width, height: size.height)
            .btHudGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(accessibilityId)
        .accessibilityLabel(accessibilityName ?? title)
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

/// principal 标题 + 可选副标题（G20 / SPEC §8.3）。副标题承载状态文案
/// （解读数 / 求解中 / 无解 / 自由首碰）；测验等无状态页传 `statusText: nil` 仅显品牌绿标题。
struct BTSolverNavStatus: View {
    let title: String
    var isBusy: Bool = false
    /// `nil` 且非 busy 时隐藏副行（暗色测验页简化形态，组件同源）。
    var statusText: String? = nil

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.btPrimary)
                .lineLimit(1)
            if isBusy || statusText != nil {
                HStack(spacing: 4) {
                    if isBusy { ProgressView().controlSize(.mini).tint(.white) }
                    if let statusText {
                        Text(statusText)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .allowsTightening(true)
                            .accessibilityIdentifier("navStatus.subtitle")
                            .accessibilityLabel(statusText)
                    }
                }
            }
        }
    }
}

// MARK: - Shot page frame preference（G20 / C9）

/// Shared PreferenceKey for scene / palette frame reporting on shot pages.
/// Replaces 9 private `*FramePreference` copies; `SolverFramePreference` is a migration alias.
struct BTShotPageFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Migration alias for Bank/Diamond (and any leftover call sites). Prefer `BTShotPageFramePreference`.
typealias SolverFramePreference = BTShotPageFramePreference

/// 右上三点菜单（G19 图标 + G25 内容模板）。
///
/// 固定顺序：原理说明（可选）→ Section「求解范围」（可选）→ Section「显示」网格
/// → 页特有项（`pageExtras`）→ 清空桌面（可选）→ 恢复默认（可选）。
///
/// 三套模板用法：
/// - **解球器**：`onPrinciple` + `onReset`（Bank/Diamond / `SolverStageChrome`）
/// - **反解训练**：`solveRange` + `onClearTable` + `onReset`（Silu / PlanThree / Snooker）
/// - **自由击打**：`pageExtras` ± `onClearTable`/`onReset`（Composer / FreePlay / ShotSim）
struct BTSolverMoreMenu<SolveRange: View, PageExtras: View>: View {
    let scene: AngleTrainingScene
    var onPrinciple: (() -> Void)? = nil
    var onClearTable: (() -> Void)? = nil
    var clearTableRole: ButtonRole? = nil
    var onReset: (() -> Void)? = nil
    var labelOpacity: Double = 0.9
    var accessibilityId: String? = nil
    /// 页内有近球瞄准特写时并入「显示」Section（v23 E3；目前仅瞄准点场景训练）。
    var showsAimCloseupToggle: Bool = false
    @ViewBuilder var solveRange: () -> SolveRange
    @ViewBuilder var pageExtras: () -> PageExtras

    var body: some View {
        Menu {
            if let onPrinciple {
                Section {
                    Button("原理说明", systemImage: "info.circle") { onPrinciple() }
                }
            }
            if hasSolveRange {
                Section("求解范围") { solveRange() }
            }
            Section("显示") {
                BTTableGridMenuToggle(scene: scene)
                if showsAimCloseupToggle {
                    BTAimCloseupMenuToggle()
                }
            }
            pageExtras()
            if onClearTable != nil || onReset != nil {
                Section {
                    if let onClearTable {
                        Button("清空桌面", systemImage: "trash", role: clearTableRole) {
                            onClearTable()
                        }
                    }
                    if let onReset {
                        Button("恢复默认", systemImage: "arrow.counterclockwise") {
                            onReset()
                        }
                    }
                }
            }
        } label: {
            Image(systemName: BTIcon.menuCircle)
                .foregroundStyle(.white.opacity(labelOpacity))
        }
        .accessibilityLabel("更多")
        .modifier(OptionalAccessibilityIdentifier(accessibilityId))
    }

    /// `EmptyView` 不渲染「求解范围」Section（反解三页传 Toggle；其余默认空）。
    private var hasSolveRange: Bool { !(SolveRange.self == EmptyView.self) }
}

extension BTSolverMoreMenu where SolveRange == EmptyView, PageExtras == EmptyView {
    /// 解球器模板 / 仅显示网格（测验页）。
    init(scene: AngleTrainingScene,
         onPrinciple: (() -> Void)? = nil,
         onReset: (() -> Void)? = nil,
         labelOpacity: Double = 0.9,
         accessibilityId: String? = nil,
         showsAimCloseupToggle: Bool = false) {
        self.init(
            scene: scene,
            onPrinciple: onPrinciple,
            onClearTable: nil,
            clearTableRole: nil,
            onReset: onReset,
            labelOpacity: labelOpacity,
            accessibilityId: accessibilityId,
            showsAimCloseupToggle: showsAimCloseupToggle,
            solveRange: { EmptyView() },
            pageExtras: { EmptyView() }
        )
    }
}

extension BTSolverMoreMenu where PageExtras == EmptyView {
    /// 反解训练模板：求解范围 + 显示 + 清空/恢复默认。
    init(scene: AngleTrainingScene,
         onClearTable: (() -> Void)? = nil,
         clearTableRole: ButtonRole? = nil,
         onReset: (() -> Void)? = nil,
         labelOpacity: Double = 0.9,
         accessibilityId: String? = nil,
         @ViewBuilder solveRange: @escaping () -> SolveRange) {
        self.init(
            scene: scene,
            onPrinciple: nil,
            onClearTable: onClearTable,
            clearTableRole: clearTableRole,
            onReset: onReset,
            labelOpacity: labelOpacity,
            accessibilityId: accessibilityId,
            solveRange: solveRange,
            pageExtras: { EmptyView() }
        )
    }
}

extension BTSolverMoreMenu where SolveRange == EmptyView {
    /// 自由击打模板：显示 + 页特有 ± 清空/恢复默认。
    init(scene: AngleTrainingScene,
         onClearTable: (() -> Void)? = nil,
         clearTableRole: ButtonRole? = nil,
         onReset: (() -> Void)? = nil,
         labelOpacity: Double = 0.9,
         accessibilityId: String? = nil,
         showsAimCloseupToggle: Bool = false,
         @ViewBuilder pageExtras: @escaping () -> PageExtras) {
        self.init(
            scene: scene,
            onPrinciple: nil,
            onClearTable: onClearTable,
            clearTableRole: clearTableRole,
            onReset: onReset,
            labelOpacity: labelOpacity,
            accessibilityId: accessibilityId,
            showsAimCloseupToggle: showsAimCloseupToggle,
            solveRange: { EmptyView() },
            pageExtras: pageExtras
        )
    }
}

/// Applies `accessibilityIdentifier` only when non-nil（避免空串污染 AX 树）。
private struct OptionalAccessibilityIdentifier: ViewModifier {
    let id: String?
    init(_ id: String?) { self.id = id }
    func body(content: Content) -> some View {
        if let id { content.accessibilityIdentifier(id) }
        else { content }
    }
}

// MARK: - 开球按钮（Slot L1 · 开球 / 禁用开球；条 18.3）
//
// D14：无开球页**不显示**禁用占位；可达开球宿主（FreePlay / Silu / PlanThree / Composer）
// 渲染本按钮。外形尺寸 = `ShotStageMetrics.breakButtonSize`。

struct BTBreakSideButton: View {
    var isEnabled: Bool
    var action: () -> Void

    private var size: CGSize { ShotStageMetrics.breakButtonSize }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                BreakRackGlyph(color: isEnabled ? Color.btPrimary : .white.opacity(0.35), size: 16)
                Text("开球")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isEnabled ? Color.btPrimary : .white.opacity(0.35))
            }
            .frame(width: size.width, height: size.height)
            .btHudGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("break.entry")
        .accessibilityLabel("开球")
    }
}
