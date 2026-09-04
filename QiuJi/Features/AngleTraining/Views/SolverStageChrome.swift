import SwiftUI
import SceneKit

// MARK: - Hosting protocol (Bank / Diamond VMs; no VM file changes — conform via extension)

/// Shared surface for bank / kick solver page chrome (C18 / W5).
/// Both `BankShotViewModel` and `DiamondSystemViewModel` already expose this API;
/// conformance is declared here so VM source files stay untouched.
@MainActor
protocol SolverStageHosting: ObservableObject {
    var scene: AngleTrainingScene { get }
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
    func setAimWheelDragging(_ active: Bool)

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

extension BankShotViewModel: SolverStageHosting {}
extension DiamondSystemViewModel: SolverStageHosting {}

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

// MARK: - Shared stage chrome

/// File-level constants (generic `SolverStageChrome` cannot hold static stored properties).
private enum SolverStageChromeMetrics {
    /// G10：顶栏 / 底栏固定高度 ⇒ scene 区域高度恒定 ⇒ 球桌渲染尺寸锁定。
    static let topRowHeight = ShotStageMetrics.topRowHeight
    static let bottomBarHeight = ShotStageMetrics.BottomBarHeight.composer.rawValue

    /// 固定在桌球（母球 / 黑 8 目标球）：球库位灰显、不可拖、点击脉冲提示（条 17.8）。
    static func isFixedBall(_ key: String) -> Bool {
        key == PositionPlayBall.cueKey || key == "_8"
    }
}

/// BankShot / Diamond 同构壳：topRow、stage（仪表柱 / 瞄准轮 / 动作列）、球库拖拽、
/// 恢复 / 下一解、FramePreference。差异经参数注入（VM、标题、coordinateSpace、袋口、Info）。
struct SolverStageChrome<VM: SolverStageHosting>: View {
    @ObservedObject var vm: VM

    let title: String
    let coordinateSpaceName: String
    /// BankShot only: pocket tap → select pocket. Diamond passes nil.
    var onPocketTapped: ((Int) -> Void)? = nil
    let infoTitle: String
    let infoBlocks: [PrincipleBlock]

    @State private var showInfo = false
    @State private var hasAppeared = false
    @State private var showSpinPad = false

    @State private var projector = TableProjector()

    // 球库拖拽状态（coordinateSpaceName 坐标空间，编排台同款交互）。
    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false
    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            let sceneH = max(geo.size.height - SolverStageChromeMetrics.topRowHeight - SolverStageChromeMetrics.bottomBarHeight, 1)
            let proxy = ShotStageProxy(
                sceneSize: CGSize(width: geo.size.width, height: sceneH)
            )
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    topRow
                        .frame(height: SolverStageChromeMetrics.topRowHeight)
                    stage(proxy)
                        .frame(height: sceneH)
                    bottomBar(proxy)
                        .frame(height: SolverStageChromeMetrics.bottomBarHeight)
                }
                if let key = draggingKey {
                    BTBallPaletteDragGhost(key: key, location: dragLocation, overTable: dragOverTable)
                }
            }
        }
        .coordinateSpace(name: coordinateSpaceName)
        .onPreferenceChange(BTShotPageFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .btDarkToolChrome(title)
        .toolbar {
            // 条 17.1/17.2/17.7：principal 品牌绿标题 + 副标题承载解描述 / 无解说明（同三解页）。
            ToolbarItem(placement: .principal) {
                BTSolverNavStatus(title: title, isBusy: vm.isSolving, statusText: vm.statusText)
            }
            // 条 17.9（G19）：i → 三点菜单（原理说明 + 台面网格 + 恢复默认）。
            ToolbarItem(placement: .topBarTrailing) {
                BTSolverMoreMenu(scene: vm.scene,
                                 onPrinciple: { showInfo = true },
                                 onReset: { vm.reset() },
                                 showsAimCloseupToggle: true)
                    .disabled(vm.isPlaying)
            }
        }
        .sheet(isPresented: $showInfo) {
            PrincipleInfoSheet(title: infoTitle, blocks: infoBlocks)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
            }
        }
    }

    // MARK: - Top row（SPEC §8.4：1 行 = 模式切换 + 库数 chip；自由模式库数隐藏，§1.3）

    private var topRow: some View {
        HStack(spacing: Spacing.sm) {
            BTAimModeToggleButton(isFree: vm.mode == .free,
                                  solvedLabel: "求解", solvedIcon: "target") {
                vm.toggleMode()
            }
            .accessibilityIdentifier("solver.mode")
            if vm.mode == .solve {
                cushionPicker
                    .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .animation(BTMotion.easeInOutFast, value: vm.currentIndex)
        .animation(BTMotion.easeInOutFast, value: vm.mode)   // §1.3 顶部行过渡。
        .disabled(vm.isPlaying)          // 演示/击球中锁顶部控件（W5/W6）。
        .opacity(vm.isPlaying ? 0.42 : 1)
    }

    private var cushionPicker: some View {
        BTChipRow(
            options: ["自动"] + vm.cushionOptions.map { "\($0)库" },
            selection: Binding(
                get: { vm.selectedCushions ?? 0 },
                set: { vm.selectCushions($0 == 0 ? nil : $0) }
            ),
            scrollable: false
        )
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11 走 ShotStageProxy）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer

            if proxy.isValid {
                // G3 轨迹档位 chip（C28 / D15）：与 FreePlay/ShotSim 同带区。
                BTTrajectoryDetailChip {
                    if vm.mode == .free { vm.refreshFreeAim() }
                    else { vm.recompute() }
                }
                .btChipBandPlacement(proxy)
                .allowsHitTesting(!vm.isPlaying)

                // 左缘瞄准刻度轮（W6 自由模式细调，T-P18-43）。
                if vm.mode == .free {
                    BTAimWheel(
                        onNudge: { vm.nudgeFreeAim(byDegrees: $0) },
                        degreesPerPoint: vm.aimWheelDegreesPerPoint,
                        degreeHapticEnabled: false,
                        onDragActiveChanged: { vm.setAimWheelDragging($0) }
                    )
                        .btStageFrame(proxy.aimWheelFrame())
                        .allowsHitTesting(!vm.isPlaying)
                }

                // 右缘仪表柱：求解有解 = 打点盘+力度（微调走草稿层，D-v8-5b）；
                // 求解无解 = 纯力度柱（力度 = 反解输入）；自由 = 完整仪表柱。
                BTShotInstrumentColumn(
                    spinX: vm.spinX, spinY: vm.spinY,
                    onSpinTap: showsSpinSlot ? { showSpinPad = true } : nil,
                    velocity: powerBinding,
                    range: Double(CushionReflectionSettings.minPower)
                        ... Double(CushionReflectionSettings.maxPower),
                    // 击球/演示中打点位与力度条一起禁用灰化，不从仪表柱上消失。
                    spinTapEnabled: !vm.isPlaying
                )
                .btStageFrame(proxy.instrumentFrame())
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("solver.power")
                .disabled(vm.isPlaying)
                .opacity(vm.isPlaying ? 0.42 : 1)

                // 右下贴边动作列：求解 = 击打/上一杆/回放；自由 = 击球/上一杆/回放（G6 actionColumnFrame）。
                actionColumn
                    .btStageFrame(proxy.actionColumnFrame())

                // Slot L1：自由 = 「恢复球形」；求解 = 「下一解」（G24 外形 = breakButtonSize）。
                if vm.mode == .free {
                    restoreButton
                        .btStageFrame(proxy.bottomLeadingFrame(size: ShotStageMetrics.breakButtonSize))
                } else {
                    nextSolutionButton
                        .btStageFrame(proxy.bottomLeadingFrame(size: ShotStageMetrics.breakButtonSize))
                }
            }

            // v23 W3：近区瞄准特写（自由模式；三点菜单可关）。
            BTAimCloseupOverlay(snapshot: vm.closeupSnapshot, sceneSize: proxy.sceneSize)

            // 打点盘浮层（自由 / 求解有解；求解微调走草稿层，编排台同款 ADR-P11-09）。
            if showSpinPad {
                BTSpinPadOverlay(spinX: spinXBinding, spinY: spinYBinding,
                                 tableWidth: proxy.playingRect.width,
                                 bottomPadding: proxy.spinPadBottomPadding,
                                 onClose: { showSpinPad = false })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(20)
                    .accessibilityIdentifier("solver.spinPad")
            }
        }
        .animation(BTMotion.springLayout, value: vm.solutionCount)
        .animation(BTMotion.springLayout, value: vm.hasSolution)
        .animation(BTMotion.springLayout, value: vm.mode)   // §1.3 过渡。
        .animation(BTMotion.springPanel, value: showSpinPad)
        .environment(\.colorScheme, .dark)
    }

    /// 打点位是否**存在**（结构性条件）：自由模式或求解有解；求解无解 = 纯力度柱。
    /// 击球/演示中的不可用态走 `spinTapEnabled`（禁用灰化），不得让打点盘从仪表柱上消失。
    private var showsSpinSlot: Bool {
        vm.mode == .free || (vm.mode == .solve && vm.hasSolution)
    }

    /// 求解有解：力度写入草稿层；否则写 `reflectionPower`（触发全量反解 / 自由持久化）。
    private var powerBinding: Binding<Double> {
        Binding(
            get: { vm.reflectionPower },
            set: { newVal in
                if vm.mode == .solve && vm.hasSolution {
                    vm.adjustCurrentSolution(velocity: newVal, spinX: nil, spinY: nil)
                } else {
                    vm.reflectionPower = newVal
                }
            }
        )
    }

    private var spinXBinding: Binding<Double> {
        Binding(
            get: { vm.spinX },
            set: { newVal in
                if vm.mode == .solve && vm.hasSolution {
                    vm.adjustCurrentSolution(velocity: nil, spinX: newVal, spinY: nil)
                } else {
                    vm.spinX = newVal
                }
            }
        )
    }

    private var spinYBinding: Binding<Double> {
        Binding(
            get: { vm.spinY },
            set: { newVal in
                if vm.mode == .solve && vm.hasSolution {
                    vm.adjustCurrentSolution(velocity: nil, spinX: nil, spinY: newVal)
                } else {
                    vm.spinY = newVal
                }
            }
        )
    }

    /// Slot L1「恢复球形」（W6）：回最近求解快照，切回求解命中缓存直显。
    private var restoreButton: some View {
        BTSlotL1Button(
            title: "恢复球形",
            systemImage: "arrow.counterclockwise",
            isEnabled: vm.canRestoreSnapshot && !vm.isPlaying,
            accessibilityId: "solver.restore"
        ) {
            vm.restoreSolveSnapshot()
        }
    }

    /// 贴边动作列（条 17.5：求解态收敛为 击打/上一杆/回放，与自由态、其他击打页同规范）。
    /// 条 17.3：删演示中「停止」与「重置」（演示不可中断；重置移入三点菜单「恢复默认」）。
    /// 求解态「上一杆」按 G17 全量恢复（球形 + 袋口 + 库数 + 解集 + 档位 + 力度）。
    @ViewBuilder
    private var actionColumn: some View {
        if vm.mode == .free {
            BTShotActionColumn(
                strikeTitle: vm.isPlaying ? BTStrikeTitle.freePlayBusy : BTStrikeTitle.freePlay,
                strikeEnabled: vm.canFreeStrike,
                onStrike: { vm.freeStrike() },
                undoEnabled: !vm.isPlaying && vm.canUndoShot,
                onUndo: { vm.undoLastShot() },
                playbackEnabled: !vm.isPlaying && vm.canPlaybackShot,
                onPlayback: { vm.replayLastShot() }
            )
        } else {
            BTShotActionColumn(
                strikeTitle: vm.isPlaying ? BTStrikeTitle.freePlayBusy : BTStrikeTitle.solutionDemo,
                strikeEnabled: vm.canStrike,
                onStrike: { vm.strike() },
                undoEnabled: !vm.isPlaying && vm.canUndoSolve,
                onUndo: { vm.undoSolveShot() },
                playbackEnabled: !vm.isPlaying && vm.canReplaySolve,
                onPlayback: { vm.replaySolveShot() }
            )
        }
    }

    /// Slot L1「下一解」（条 17.4）：求解态切换多解；单解禁用。
    private var nextSolutionButton: some View {
        BTSlotL1Button(
            title: "下一解",
            systemImage: "arrow.triangle.2.circlepath",
            isEnabled: vm.solutionCount > 1 && !vm.isPlaying,
            accessibilityId: "solver.nextSolution"
        ) {
            vm.nextSolution()
        }
    }

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: .constant(.topDown2DRotated),
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            onPocketTapped: onPocketTapped,
            draggableBallNodes: vm.draggableNodes,
            onDragBegan: { node in vm.dragBegan(node: node) },
            onDragMoved: { node, world in vm.handleDrag(node: node, to: world) },
            onDragEnded: { node in vm.dragEnded(node: node) },
            onDragEndedAt: { node, localPoint in
                handleTableDragEnd(node: node, localPoint: localPoint)
            },
            onAimNudged: { vm.nudgeFreeAim(byDegrees: $0) },   // 自由模式瞄准相对调整（G13）。
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(frameReader(id: "scene"))
        .clipped()
    }

    // MARK: - Bottom bar（球库带：拖入 = 障碍球真实碰撞体；G21 BTBallPaletteBar）

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        let libraryWidth = proxy.isValid ? proxy.libraryWidth : proxy.sceneSize.width
        return BTBallPaletteBar(
            coordinateSpace: coordinateSpaceName,
            ballDiameter: proxy.paletteBallDiameter,
            isPlaying: vm.isPlaying,
            libraryWidth: libraryWidth,
            isOnTable: { key in
                SolverStageChromeMetrics.isFixedBall(key) || vm.onTableObstacleKeys.contains(key)
            },
            allowsDrag: { key in
                !SolverStageChromeMetrics.isFixedBall(key) && !vm.onTableObstacleKeys.contains(key)
            },
            sceneFrame: sceneFrame,
            unproject: { projector.unproject?($0) },
            onTap: { key in
                if SolverStageChromeMetrics.isFixedBall(key) { vm.pulsePaletteBall(key) }
                else if vm.onTableObstacleKeys.contains(key) { vm.pulseTableBall(key) }
                else { vm.placeObstacle(key, atWorld: nil) }
            },
            onPlace: { key, world in vm.placeObstacle(key, atWorld: world) },
            draggingKey: $draggingKey,
            dragLocation: $dragLocation,
            dragOverTable: $dragOverTable
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HUDStyle.panelBackground)
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
        .disabled(vm.isPlaying)
        .opacity(vm.isPlaying ? 0.55 : 1)
    }

    // 在桌障碍球拖回球库带 → 移除（编排台同款）。
    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard BTBallPaletteDragBack.hitPalette(localPoint: localPoint,
                                               sceneFrame: sceneFrame,
                                               paletteFrame: paletteFrame),
              let key = vm.scene.ballKey(for: node),
              vm.onTableObstacleKeys.contains(key) else { return }
        vm.removeObstacle(key)
    }

    // MARK: - Frame reader

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: BTShotPageFramePreference.self,
                                   value: [id: geo.frame(in: .named(coordinateSpaceName))])
        }
    }
}
