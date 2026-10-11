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
    var statusText: String { get }
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
    var onPocketTapped: ((Int) -> Void)? = nil
    let infoTitle: String
    let infoBlocks: [PrincipleBlock]
    @State private var showInfo = false
    @AppStorage("bankKick.spinTransparency") private var spinTransparency = 0.5
    @AppStorage("bankKick.hides3DAssists") private var hides3DAssists = false
    private var free: Bool { vm.mode == .free }
    private var is3D: Bool { vm.cameraMode == .perspective3D }

    var body: some View {
        BTTeachingTablePage(vm: vm, titleLabel: title, identifier: coordinateSpaceName,
            velocity: powerBinding, planning: controls,
            information: [.init(text: vm.statusText, identifier: "solver.status")], usesStandardTitle: true,
            pairedLeftContent: free ? { AnyView(freeControls($0)) } : nil,
            title: { EmptyView() },
            leftContent: { leftControls($0) }, status: { EmptyView() }, onPalettePlace: { vm.placeObstacle($0, atWorld: $1) })
            .sheet(isPresented: $showInfo) {
                PrincipleInfoSheet(title: infoTitle, blocks: infoBlocks)
                    .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
    }

    private var controls: BTTablePlanningControls {
        BTTablePlanningControls(spinX: spinXBinding, spinY: spinYBinding,
            transparency: $spinTransparency,
            hides3DAssists: Binding(get: { hides3DAssists }, set: { hides3DAssists = $0; vm.hides3DShotAssists = $0 }),
            velocityRange: Double(CushionReflectionSettings.minPower)...Double(CushionReflectionSettings.maxPower),
            instrumentsEnabled: !vm.isPlaying, showsSpinSlot: free || vm.hasSolution,
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
            onSetup: { vm.hides3DShotAssists = hides3DAssists },
            onDisappear: { vm.stopForDismissal() },
            onAimNudged: free && !is3D ? { vm.nudgeFreeAim(byDegrees: $0) } : nil,
            onAimDragActiveChanged: { vm.setAimTableDragging($0) },
            closeupSnapshot: vm.closeupSnapshot)
    }
    private var solverMenuItems: [DailyHUDMenuItem] {
        var items: [DailyHUDMenuItem] = [.init(id: "solver.info", title: "原理说明", action: { showInfo = true })]
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
        ScrollView(.vertical) {
            VStack(spacing: 4) {
                action(free ? "自由" : "求解", free ? "scope" : "function", "solver.mode", enabled: !vm.isPlaying) { vm.toggleMode() }
                    .accessibilityValue(free ? "自由" : "求解")
                if !free {
                    Menu {
                        Button("自动") { vm.selectCushions(nil) }
                        ForEach(vm.cushionOptions, id: \.self) { n in Button("\(n)库") { vm.selectCushions(n) } }
                    } label: {
                        Text(vm.selectedCushions.map { "\($0)库" } ?? "自动").font(.btCaption).foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                    }.overlay(alignment: .topTrailing) { TeachingMenuIndicator() }.disabled(vm.isPlaying).accessibilityIdentifier("solver.cushions")
                    TeachingSolutionButton(count: vm.solutionCount, currentIndex: vm.currentIndex, enabled: !vm.isPlaying && !vm.isSolving, next: { vm.nextSolution() }, select: { vm.selectSolution(at: $0) })
                }
                action("重打", "arrow.uturn.backward", "solver.undo", enabled: !vm.isPlaying && !vm.temporaryTopDownActive && (free ? vm.canUndoShot : vm.canUndoSolve)) {
                    if free { vm.undoLastShot() } else { vm.undoSolveShot() }
                }
                action("回放", "play.rectangle", "solver.replay", enabled: !vm.isPlaying && !vm.temporaryTopDownActive && (free ? vm.canPlaybackShot : vm.canReplaySolve)) {
                    if free { vm.replayLastShot() } else { vm.replaySolveShot() }
                }
            }.frame(maxWidth: .infinity)
        }.scrollIndicators(.hidden).frame(width: size.width, height: min(size.height, free ? 366 : 236))
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
            if !free && vm.hasSolution { vm.adjustCurrentSolution(velocity: $0, spinX: nil, spinY: nil) }
            else { vm.reflectionPower = $0 }
        })
    }
    private var spinXBinding: Binding<Double> {
        Binding(get: { vm.spinX }, set: {
            if !free && vm.hasSolution { vm.adjustCurrentSolution(velocity: nil, spinX: $0, spinY: nil) }
            else { vm.spinX = $0 }
        })
    }
    private var spinYBinding: Binding<Double> {
        Binding(get: { vm.spinY }, set: {
            if !free && vm.hasSolution { vm.adjustCurrentSolution(velocity: nil, spinX: nil, spinY: $0) }
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

struct TeachingSolutionButton: View {
    let count: Int
    let currentIndex: Int
    let enabled: Bool
    let next: () -> Void
    let select: (Int) -> Void
    var body: some View {
        Button(action: next) {
            VStack(spacing: 1) {
                Image(systemName: "arrow.right").font(.system(size: 17))
                Text("下一解").font(.system(size: 10))
            }.frame(width: 44, height: 44)
                .background { BTHUDControlBackground(shape: RoundedRectangle(cornerRadius: 12)) }
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(HUDStyle.hairline, lineWidth: HUDStyle.hairlineWidth))
                .overlay(alignment: .topTrailing) { TeachingMenuIndicator() }
        }.buttonStyle(BTHUDPressStyle()).disabled(!enabled || count < 2)
            .opacity(enabled && count >= 2 ? 1 : 0.4)
            .contextMenu {
                ForEach(0..<count, id: \.self) { index in
                    Button { select(index) } label: {
                        Label("解 \(index + 1)/\(count)", systemImage: index == currentIndex ? "checkmark" : "circle")
                    }.accessibilityIdentifier("solver.selectSolution.\(index)")
                }
            }
            .accessibilityLabel("下一解").accessibilityHint("轻点下一解，长按选择解")
            .accessibilityValue("解 \(currentIndex + 1)/\(count)")
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
