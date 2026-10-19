import SwiftUI
import SceneKit

// MARK: - Hosting protocol (Bank / Diamond VMs)

/// Shared surface for bank / kick solver page chrome (C18 / W5).
/// Camera observation shares the chrome without touching either solver state machine.
@MainActor
protocol SolverStageHosting: TeachingTableHost {
    var scene: AngleTrainingScene { get }
    var cameraMode: AngleTrainingScene.CameraMode { get set }
    var observationAim: SCNVector3? { get }
    var observationPocket: Int? { get }
    var mode: BankKickPageMode { get }
    var isSolving: Bool { get }
    var isAdjustingSolution: Bool { get }
    var statusText: String { get }
    var tableStatusText: String? { get }
    var tableStatusIsReadout: Bool { get }
    var isPlaying: Bool { get }
    var currentIndex: Int { get }
    var cushionOptions: [Int] { get }
    var selectedCushions: Int? { get }
    var spinX: Double { get set }
    var spinY: Double { get set }
    var reflectionPower: Double { get set }
    var solutionCount: Int { get }
    var hasSolution: Bool { get }
    var canRestoreSnapshot: Bool { get }
    var canFreeStrike: Bool { get }
    var canUndoShot: Bool { get }
    var canPlaybackShot: Bool { get }
    var canStrike: Bool { get }
    var canUndoSolve: Bool { get }
    var canReplaySolve: Bool { get }
    var onTableObstacleKeys: [String] { get }
    var draggableNodes: [SCNNode] { get }
    /// v23 W2：瞄准轮毫米口径增益（°/pt）。
    var aimWheelDegreesPerPoint: Float { get }
    /// v23 W3：近区特写快照（自由模式；nil = 不显示）。
    var closeupSnapshot: AimCloseupSnapshot? { get }
    func updateFreeSpin(x: Double, y: Double)
    /// v23 W3：瞄准轮拖动生命周期（特写显隐门）。
    func setAimTableDragging(_ active: Bool)
    func setAimWheelDragging(_ active: Bool)

    var hides3DShotAssists: Bool { get set }
    func refreshShotAssistVisibility()
    func stopForDismissal()
    func toggleMode()
    func selectCushions(_ n: Int?)
    func nudgeFreeAim(byDegrees delta: Float)
    func restoreSolveSnapshot()
    func freeStrike()
    func undoLastShot()
    func replayLastShot()
    func strike()
    func undoSolveShot()
    func replaySolveShot()
    func selectSolution(at index: Int)
    func nextSolution()
    func reset()
    func setupScene()
    func recompute()
    func refreshFreeAim()
    func dragBegan(node: SCNNode)
    func handleDrag(node: SCNNode, to worldPos: SCNVector3)
    func dragEnded(node: SCNNode)
    func placeObstacle(_ key: String, atWorld world: SCNVector3?)
    func removeObstacle(_ key: String)
    func pulseTableBall(_ key: String)
    func pulsePaletteBall(_ key: String)
    /// K11：求解模式微调（草稿层）；自由模式不走此路径。
    func adjustCurrentSolution(velocity: Double?, spinX: Double?, spinY: Double?)
}

extension SolverStageHosting {
    var selectedTargetKey: String? { "_8" }
    var selectedPocketIndex: Int { observationPocket ?? -1 }
    var targetNode: SCNNode? { scene.targetBallNodes.first }
    var currentPlayerAim: SCNVector3? {
        if let observationAim { return observationAim }
        guard let cue = scene.cueBallNode, !cue.isHidden, let targetNode, !targetNode.isHidden else { return nil }
        let dx = targetNode.position.x - cue.position.x, dz = targetNode.position.z - cue.position.z
        let length = sqrtf(dx * dx + dz * dz)
        return length > 0.0001 ? SCNVector3(dx / length, 0, dz / length) : nil
    }
    var onTableKeys: [String] {
        PositionPlayBall.allKeys.filter { scene.allBallNodes[$0]?.isHidden == false }
    }
    var draggableBalls: [SCNNode] { draggableNodes }
    var selectableBalls: [SCNNode] { [] }
    func selectTarget(key: String) { pulseTableBall(key) }
    func placeFromPalette(_ key: String) { placeObstacle(key, atWorld: nil) }
    func removeFromTable(_ key: String) {
        guard key != "_8", !PositionPlayBall.isCue(key) else { return }
        removeObstacle(key)
    }
    func dragMoved(node: SCNNode, worldPosition: SCNVector3) { handleDrag(node: node, to: worldPosition) }

    /// Cue scratches remain a shot fact; return only the cue to a vacant playable position.
    func respotScratchedCue() {
        guard let cue = scene.cueBallNode, cue.isHidden else { return }
        let occupied = scene.allBallNodes.values.filter { $0 !== cue && !$0.isHidden }
        for x in stride(from: 0.15, through: 0.85, by: 0.1) {
            for z in stride(from: 0.12, through: 0.40, by: 0.08) {
                let point = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: x, y: z), surfaceY: scene.surfaceY)
                if occupied.allSatisfy({ AngleSceneCalculator.horizontalDistance(point, $0.position) >= 2.2 * AngleSceneCalculator.ballRadius }) {
                    cue.position = point
                    cue.isHidden = false
                    cue.opacity = 1
                    return
                }
            }
        }
    }
}

extension BankShotViewModel: SolverStageHosting {
    func selectPocket(at index: Int) { selectPocket(index) }
}
extension DiamondSystemViewModel: SolverStageHosting {
    func selectPocket(at index: Int) {}
}

// MARK: - Principle info sheet template

struct PrincipleBlock: Hashable {
    let title: String
    let body: String
}

/// Shared dark principle sheet for bank / kick solvers (replaces two isomorphic private sheets).
struct PrincipleInfoSheet: View {
    let title: String
    let blocks: [PrincipleBlock]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(blocks, id: \.self) { block in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(block.title).font(.btHeadline).foregroundStyle(.btText)
                            Text(block.body).font(.btSubheadline).foregroundStyle(.btTextSecondary)
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        // §1.6：Z7 浮出层统一暗材质（T-P18-49）。
        .preferredColorScheme(.dark)
    }
}

// MARK: - Shared daily-template shell

struct SolverStageChrome<VM: SolverStageHosting>: View {
    @ObservedObject var vm: VM
    let title: String
    let coordinateSpaceName: String
    let preferencePage: TablePreferencePage
    var onPocketTapped: ((Int) -> Void)? = nil
    let infoTitle: String
    let infoBlocks: [PrincipleBlock]
    @State private var showInfo = false
    @ObservedObject private var tablePreferences = TablePreferencesStore.shared
    private var spinTransparency: Double {
        get { tablePreferences.snapshot(for: preferencePage)[.transparency] }
        nonmutating set { tablePreferences.apply(.transparency, value: newValue, to: preferencePage) }
    }
    private var hides3DAssists: Bool { !tablePreferences.snapshot(for: preferencePage).enabled(.shows3DTrajectory) }
    private var free: Bool { vm.mode == .free }
    private var is3D: Bool { vm.cameraMode == .perspective3D }

    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: title, identifier: coordinateSpaceName, preferencePage: preferencePage,
            velocity: powerBinding, planning: controls,
            information: vm.tableStatusText.map { [.init(text: $0, kind: .readout, symbol: vm.tableStatusIsReadout ? nil : "info.circle", identifier: "solver.status")] } ?? [], usesStandardTitle: true,
            pairedLeftContent: free ? { AnyView(freeControls($0)) } : nil,
            title: { EmptyView() },
            leftContent: { leftControls($0) }, status: { EmptyView() }, onPalettePlace: { vm.placeObstacle($0, atWorld: $1) })
            #if DEBUG
            .overlay(alignment: .bottom) {
                if DailyLayoutProbe.enabled {
                    Color.clear.frame(width: 1, height: 1).allowsHitTesting(false)
                        .accessibilityElement().accessibilityIdentifier(coordinateSpaceName + ".layoutState")
                        .accessibilityValue("target=\(vm.selectedTargetKey ?? "none") pocket=\(vm.selectedPocketIndex) mode=\(vm.mode) cushions=\(vm.selectedCushions ?? -1) solutions=\(vm.solutionCount) index=\(vm.currentIndex) spinX=\(vm.spinX) spinY=\(vm.spinY) velocity=\(vm.reflectionPower) obstacles=\(vm.onTableObstacleKeys.sorted().joined(separator: ",")) status=\(vm.statusText)")
                }
            }
            #endif
            .sheet(isPresented: $showInfo) {
                PrincipleInfoSheet(title: infoTitle, blocks: infoBlocks)
                    .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
    }

    private var controls: BTTablePlanningControls {
        BTTablePlanningControls(spinX: spinXBinding, spinY: spinYBinding,
            transparency: Binding(get: { spinTransparency }, set: { spinTransparency = $0 }),
            hides3DAssists: Binding(get: { hides3DAssists }, set: { tablePreferences.apply(.shows3DTrajectory, value: $0 ? 0 : 1, to: preferencePage) }),
            velocityRange: Double(CushionReflectionSettings.minPower)...Double(CushionReflectionSettings.maxPower),
            instrumentsEnabled: !vm.isPlaying && (!vm.isSolving || vm.isAdjustingSolution), showsSpinSlot: free || vm.solutionCount > 0,
            isAnimating: vm.isPlaying || vm.isSolving, paletteEnabled: !vm.isPlaying,
            allowsPocketSelection: onPocketTapped != nil,
            primaryTitle: vm.isPlaying ? "击球中" : (free ? "击球" : "击打"),
            primaryEnabled: free ? vm.canFreeStrike : vm.canStrike,
            onPrimary: { if free { vm.freeStrike() } else { vm.strike() } },
            onPaletteTap: { key in
                if key == "_8" { vm.pulsePaletteBall(key) }
                else if vm.onTableKeys.contains(key) { vm.pulseTableBall(key) }
                else { vm.placeObstacle(key, atWorld: nil) }
            }, menuItems: solverMenuItems, refreshTrajectory: { vm.refreshShotAssistVisibility() },
            applyPreferences: { vm.hides3DShotAssists = !$0.enabled(.shows3DTrajectory) },
            onSetup: { vm.hides3DShotAssists = hides3DAssists },
            onDisappear: { vm.stopForDismissal() },
            layoutEditingBlocked: showInfo,
            onAimNudged: free && !is3D ? { vm.nudgeFreeAim(byDegrees: $0) } : nil,
            onAimDragActiveChanged: { vm.setAimTableDragging($0) },
            closeupSnapshot: vm.closeupSnapshot,
            onSpinChange: { x, y in
                if !free && vm.solutionCount > 0 { vm.adjustCurrentSolution(velocity: nil, spinX: x, spinY: y) }
                else { vm.updateFreeSpin(x: x, y: y) }
            })
    }
    private var solverMenuItems: [DailyHUDMenuItem] {
        var items: [DailyHUDMenuItem] = [.init(id: "solver.info", title: "原理说明", disclosure: true, action: { showInfo = true })]
        if free {
            items.append(.init(id: "solver.restore", title: "恢复球形", disabled: vm.isPlaying || !vm.canRestoreSnapshot,
                action: { vm.restoreSolveSnapshot() }))
        }
        items.append(.init(id: "solver.reset", title: "恢复默认", disabled: vm.isPlaying, action: { vm.reset() }))
        return items
    }

    private func auxiliaryAction(_ title: String, _ icon: String, _ id: String, size: CGFloat,
                                 enabled: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 1) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 10))
            }.frame(width: size, height: size)
                .background { BTHUDControlBackground(shape: Circle()) }
        }.buttonStyle(BTHUDPressStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.3)
            .accessibilityLabel(title).accessibilityIdentifier(id)
            .freeControlItem(id == "solver.undo" ? "shot.undo" : "shot.replay", name: title)
    }

    private func freeControls(_ metrics: BTTeachingInstrumentLayout) -> some View {
        VStack(spacing: metrics.groupSpacing) {
            BTTeachingInstrumentEntry(layout: metrics, label: "自由") {
                Button { vm.toggleMode() } label: {
                    Image(systemName: "scope").font(.system(size: 22)).foregroundStyle(.white)
                        .frame(width: metrics.topDiameter, height: metrics.topDiameter)
                        .background { BTHUDControlBackground(shape: Circle()) }
                }.buttonStyle(BTHUDPressStyle()).disabled(vm.isPlaying).opacity(vm.isPlaying ? 0.3 : 1).accessibilityLabel("切换求解")
                    .accessibilityIdentifier("solver.mode").accessibilityValue("自由")
            }
            .freeControlItem("solver.mode", name: "求解或自由")
            BTTeachingAimRuler(layout: metrics, enabled: !vm.isPlaying && !vm.temporaryTopDownActive,
                onNudge: { vm.nudgeFreeAim(byDegrees: $0) }, degreesPerPoint: vm.aimWheelDegreesPerPoint,
                onDragActiveChanged: { vm.setAimWheelDragging($0) })
            let actions = metrics.horizontalActions
                ? AnyLayout(HStackLayout(spacing: metrics.groupSpacing))
                : AnyLayout(VStackLayout(spacing: metrics.groupSpacing))
            actions {
                auxiliaryAction("重打", "arrow.uturn.backward", "solver.undo", size: metrics.auxiliarySize,
                    enabled: !vm.isPlaying && !vm.temporaryTopDownActive && vm.canUndoShot) { vm.undoLastShot() }
                auxiliaryAction("回放", "play.rectangle", "solver.replay", size: metrics.auxiliarySize,
                    enabled: !vm.isPlaying && !vm.temporaryTopDownActive && vm.canPlaybackShot) { vm.replayLastShot() }
            }
            .frame(width: metrics.horizontalActions ? metrics.auxiliarySize * 2 + metrics.groupSpacing : metrics.auxiliarySize)
            .frame(width: metrics.columnWidth, alignment: metrics.horizontalActions ? .trailing : .center)
        }
    }

    private func leftControls(_ size: CGSize) -> some View {
        FreeControlColumn {
            VStack(spacing: 4) {
                action(free ? "自由" : "求解", free ? "scope" : TeachingSolverSymbols.solve, "solver.mode", enabled: !vm.isPlaying) { vm.toggleMode() }
                    .accessibilityValue(free ? "自由" : "求解")
                    .freeControlItem("solver.mode", name: "求解或自由")
                if !free {
                    Menu {
                        Button("自动") { vm.selectCushions(nil) }
                        ForEach(vm.cushionOptions, id: \.self) { n in Button("\(n)库") { vm.selectCushions(n) } }
                    } label: {
                        Text(vm.selectedCushions.map { "\($0)库" } ?? "自动").font(.btCaption).foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                    }.overlay(alignment: .topTrailing) { TeachingMenuIndicator() }.disabled(vm.isPlaying).accessibilityIdentifier("solver.cushions")
                        .freeControlItem("solver.cushions", name: "库数")
                    TeachingSolutionButton(count: vm.solutionCount, currentIndex: vm.currentIndex, enabled: !vm.isPlaying && !vm.isSolving, next: { vm.nextSolution() })
                        .freeControlItem("planning.nextSolution", name: "下一解")
                }
                action("重打", "arrow.uturn.backward", "solver.undo", enabled: !vm.isPlaying && !vm.temporaryTopDownActive && (free ? vm.canUndoShot : vm.canUndoSolve)) {
                    if free { vm.undoLastShot() } else { vm.undoSolveShot() }
                }
                .freeControlItem("shot.undo", name: "重打")
                action("回放", "play.rectangle", "solver.replay", enabled: !vm.isPlaying && !vm.temporaryTopDownActive && (free ? vm.canPlaybackShot : vm.canReplaySolve)) {
                    if free { vm.replayLastShot() } else { vm.replaySolveShot() }
                }
                .freeControlItem("shot.replay", name: "回放")
            }.frame(maxWidth: .infinity)
        }.frame(width: size.width, height: min(size.height, free ? 366 : 236), alignment: .top)
    }
    private func action(_ label: String, _ icon: String, _ id: String, enabled: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 1) { Image(systemName: icon).font(.system(size: 17)); Text(label).font(.system(size: 10)) }
                .frame(width: 44, height: 44).background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }.buttonStyle(BTHUDPressStyle()).disabled(!enabled)
            .opacity(enabled ? 1 : 0.4).accessibilityLabel(label).accessibilityIdentifier(id)
    }
    private var powerBinding: Binding<Double> {
        Binding(get: { vm.reflectionPower }, set: {
            if !free && vm.solutionCount > 0 { vm.adjustCurrentSolution(velocity: $0, spinX: nil, spinY: nil) }
            else { vm.reflectionPower = $0 }
        })
    }
    private var spinXBinding: Binding<Double> {
        Binding(get: { vm.spinX }, set: {
            if !free && vm.solutionCount > 0 { vm.adjustCurrentSolution(velocity: nil, spinX: $0, spinY: nil) }
            else { vm.spinX = $0 }
        })
    }
    private var spinYBinding: Binding<Double> {
        Binding(get: { vm.spinY }, set: {
            if !free && vm.solutionCount > 0 { vm.adjustCurrentSolution(velocity: nil, spinX: nil, spinY: $0) }
            else { vm.spinY = $0 }
        })
    }
}

/// The mark describes an actual menu/long-press capability, and never intercepts input.
struct TeachingMenuIndicator: View {
    var body: some View {
        Image(systemName: "ellipsis").font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white.opacity(0.75)).padding(4).allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

enum TeachingSolverSymbols {
    static let solve = "point.topleft.down.to.point.bottomright.curvepath"
}

struct TeachingSolutionButton: View {
    let count: Int
    let currentIndex: Int
    let enabled: Bool
    let next: () -> Void
    var isModified = false
    private var available: Bool { enabled && count > 1 }
    private var title: String { count > 0 ? "解\(currentIndex + 1)/\(count)" : "解" }
    var body: some View {
        Button(action: next) {
            VStack(spacing: 1) {
                Image(systemName: "arrow.right").font(.system(size: 17))
                Text(title).font(.system(size: 10)).monospacedDigit()
                if isModified { Text("微调").font(.system(size: 9)) }
            }.frame(width: 44, height: 44)
                .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
        }.buttonStyle(BTHUDPressStyle()).disabled(!available)
            .opacity(enabled && count > 0 ? 1 : 0.4)
            .accessibilityLabel(title)
            .accessibilityHint(count > 1 ? "轻点切换下一解，末解后回到第一解" : "")
            .accessibilityValue(count > 0 ? title + (isModified ? "，微调" : "") : "暂无可切换的解")
            .accessibilityIdentifier("solver.nextSolution")
    }
}

/// Presentation-only summary. Solver order, stored diagnostics and fallback facts are unchanged.
enum TeachingSolutionSummary {
    static func text(_ solution: PositionPlaySolution, index: Int, count: Int, defense: Bool) -> String {
        var parts = ["解 \(index + 1)/\(count)"]
        if solution.summary.hasPrefix("微调") { parts.append("微调") }
        if solution.summary.hasPrefix("翻袋备选") { parts.append("翻袋备选") }
        if !solution.satisfiesConstraint {
            parts.append(defense ? "未完全斯诺克" : "未满足约束")
        }
        if solution.beyondCushionBudget { parts.append("进阶") }
        if solution.beyondSpinBudget { parts.append("需横塞") }
        parts.append(ShotSpinLabel.text(spinX: solution.shot.spinX, spinY: solution.shot.spinY))
        parts.append(solution.cushionCount == 0 ? "不吃库" : "\(solution.cushionCount)库")
        return parts.joined(separator: " · ")
    }
}

/// Events carry identity so an old feedback timer cannot remove a newer error.
struct PlanningInformationEvent: Equatable {
    enum Kind: Equatable { case context, busy, solution, failure, feedback, completion }
    let id = UUID()
    let kind: Kind
    let text: String
}

enum PlanningPanel: String, Identifiable {
    case help
    var id: String { rawValue }
}

struct PlanningInformationOverlay: View {
    let page: String
    let event: PlanningInformationEvent
    let prompt: String?
    let solution: PositionPlaySolution?
    let defense: Bool
    let busy: Bool
    let setupComplete: Bool
    let introduction: String
    @AppStorage private var learned: Bool
    private struct NoticeKey: Equatable {
        let event: UUID
        let prompt: String?
    }
    private var noticeKey: NoticeKey { .init(event: event.id, prompt: prompt) }
    @State private var expiredNotice: NoticeKey?
    @AccessibilityFocusState private var noticeFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    init(page: String, event: PlanningInformationEvent, prompt: String?, solution: PositionPlaySolution?,
         defense: Bool = false, busy: Bool, setupComplete: Bool, introduction: String) {
        self.page = page; self.event = event; self.prompt = prompt; self.solution = solution
        self.defense = defense; self.busy = busy; self.setupComplete = setupComplete; self.introduction = introduction
        _learned = AppStorage(wrappedValue: false, page + ".informationLearned")
    }

    private var message: (String, Bool, Bool)? {
        if event.kind == .failure { return (event.text, true, false) }
        if busy { return nil }
        if event.kind == .completion { return (event.text, true, false) }
        let caution = PlanningSolutionDetails.cautions(solution, defense: defense)
        if !caution.isEmpty { return (caution, true, false) }
        // A completed action owns a brief feedback interval; selecting a tool/role
        // produces a new context event and immediately hands back to that step.
        if event.kind == .feedback, expiredNotice != noticeKey, !event.text.isEmpty {
            return (event.text, false, true)
        }
        if let prompt, !prompt.isEmpty, expiredNotice != noticeKey { return (prompt, false, true) }
        if !learned && expiredNotice != noticeKey && !setupComplete { return (introduction, false, true) }
        return nil
    }

    var body: some View {
        Group {
            if busy && event.kind == .busy {
                Text(event.text).font(.caption).foregroundStyle(.clear).frame(width: 1, height: 1)
                    .accessibilityLabel(event.text)
            }
            if let (text, persistent, _) = message {
                BTTeachingInformationLayer(items: [.init(text: text, kind: persistent ? .readout : .notice,
                    symbol: "info.circle", identifier: page + ".status")])
                .accessibilityFocused($noticeFocused)
            }
        }
        .task(id: noticeKey) {
            guard let (_, persistent, _) = message, !persistent else { return }
            let key = noticeKey
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled, !voiceOver, !noticeFocused else { return }
            expiredNotice = key
            learned = true
        }
        .onChange(of: setupComplete, initial: true) { _, complete in if complete { learned = true } }
    }
}

enum PlanningSolutionDetails {
    static func cautions(_ solution: PositionPlaySolution?, defense: Bool) -> String {
        guard let solution else { return "" }
        var tags: [String] = []
        if solution.isBankFallback { tags.append("翻袋备选") }
        if !solution.satisfiesConstraint { tags.append(defense ? "未完全斯诺克" : "未满足约束") }
        if solution.beyondCushionBudget { tags.append("进阶") }
        if solution.beyondSpinBudget { tags.append("需横塞") }
        return tags.joined(separator: " · ")
    }

}

struct PlanningInformationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let panel: PlanningPanel
    let sections: [(String, String)]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(sections.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(sections[index].0).font(.headline)
                            Text(sections[index].1).font(.body).fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(Spacing.lg)
            }.accessibilityIdentifier("planning." + panel.rawValue)
                .navigationTitle("操作说明")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }.accessibilityIdentifier("planning.close")
                } }
        }
    }
}
