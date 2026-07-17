import SwiftUI
import SceneKit

/// 防守战术工具（安全球反解，ADR-P16-01；V8 中八语义重做）。
///
/// 独立页面、布局参考思路训练器：顶部工具行（目标/摆球 + 清除键）→ 球桌 → 底部条（解指示 + 球库 + 操作列）。
/// 只选一颗目标球（青环，我方要打的球），系统按中八规则推断对方球组，由
/// `PositionPlaySolver.solveSnooker` 反解出令母球合法首触目标球、不进袋、并停在让对方球组
/// 完全斯诺克（或只剩长台/大切角高难度球）的塞/力度/瞄准。
struct SnookerTacticsView: View {
    /// 可选初始球形（如「拍照建球形」产出的快照）。nil = 默认开箱球形。
    let initialBoard: BoardSnapshot?

    init(initialBoard: BoardSnapshot? = nil) {
        self.initialBoard = initialBoard
    }

    @StateObject private var vm = SnookerTacticsViewModel()
    @State private var hasAppeared = false
    @State private var projector = TableProjector()
    @State private var showSpinPad = false

    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false

    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero
    @State private var toast: BTToastMessage?

    /// G10：顶栏 / 底栏固定高度 ⇒ scene 区域高度恒定 ⇒ 球桌渲染尺寸锁定。
    private static let topRowHeight = ShotStageMetrics.topRowHeight
    /// 底栏 = 球库两行 regular 36（与 Composer 同档；G12 后无解摘要行）。
    private static let bottomBarHeight = ShotStageMetrics.BottomBarHeight.composer.rawValue

    var body: some View {
        GeometryReader { geo in
            let rig = vm.scene.cameraRig
            let sceneH = max(geo.size.height - Self.topRowHeight - Self.bottomBarHeight, 1)
            let proxy = ShotStageProxy(
                sceneSize: CGSize(width: geo.size.width, height: sceneH),
                halfLength: rig?.tableOuterHalfLength ?? ShotTableLayout.defaultHalfLength,
                halfWidth: rig?.tableOuterHalfWidth ?? ShotTableLayout.defaultHalfWidth
            )
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    topToolRow
                        .frame(height: Self.topRowHeight)
                    stage(proxy)
                        .frame(height: sceneH)
                    bottomBar(proxy)
                        .frame(height: Self.bottomBarHeight)
                }
                if let key = draggingKey {
                    BTBallPaletteDragGhost(key: key, location: dragLocation, overTable: dragOverTable)
                }
            }
        }
        .animation(BTMotion.springPanel, value: showSpinPad)
        .btToast($toast)
        .coordinateSpace(name: "snooker")
        .onPreferenceChange(BTShotPageFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .navigationTitle("防守")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BTSolverNavStatus(
                    title: "防守",
                    isBusy: vm.isComputing,
                    statusText: vm.statusText
                )
            }
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
                if let initialBoard { vm.loadBoard(initialBoard) }
                // UITest 取证钩子（仅 launch arg 触发；生产无这些 arg ⇒ 不注入）。
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-snooker.full") { vm.uiTestConfigure("full") }
                else if args.contains("-snooker.partial") { vm.uiTestConfigure("partial") }
                else if args.contains("-snooker.none") { vm.uiTestConfigure("none") }
            }
        }
    }

    // MARK: - Top tool row

    private var topToolRow: some View {
        HStack(spacing: Spacing.sm) {
            BTChipRow(
                options: ["目标球", "摆球"],
                selection: Binding(
                    get: {
                        switch vm.activeTool {
                        case .selectTarget: return 0
                        case .none: return 1
                        }
                    },
                    set: {
                        switch $0 {
                        case 0: vm.activeTool = .selectTarget
                        default: vm.activeTool = .none
                        }
                    }
                ),
                scrollable: false
            )
            .disabled(vm.isPlaying)

            // Q15.3：清除键正常尺寸（BTEraserButton 42×32）、紧贴「摆球」chip 右侧（与打三/思路同布局）。
            BTEraserButton(isEnabled: !vm.isPlaying && vm.selectedTargetKey != nil) { vm.clearSelection() }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11 走 ShotStageProxy）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer

            if proxy.isValid {
                // G3 轨迹档位 chip：下沿贴球桌上沿、靠屏幕最右。
                BTTrajectoryDetailChip { vm.redrawTrajectory() }
                    .btChipBandPlacement(proxy)
                    .allowsHitTesting(!vm.isPlaying)

                // 左下（G24 / D14）：BTSolverLeftColumn；无开球不占位，Slot L1 = 下一解在柱底。
                leftColumn
                    .btStageFrame(proxy.bottomLeadingFrame(size: BTSolverLeftColumn.stackSize))

                // G4/G5/G7 打点+力度仪表柱：左缘贴球桌右侧、力度条本体底部对齐。
                instrumentColumn
                    .btStageFrame(proxy.instrumentFrame())

                // 条 18.2：击球/上一杆/回放，右下角底边齐球桌底线。
                actionColumn
                    .btStageFrame(proxy.actionColumnFrame())
            }

            if showSpinPad {
                BTSpinPadOverlay(spinX: spinXBinding, spinY: spinYBinding,
                                 onClose: { showSpinPad = false })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    // MARK: - Scene

    private var sceneContainer: some View {
        let selectable: [SCNNode] = vm.activeTool == .selectTarget ? vm.selectableBalls : []
        return AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            draggableBallNodes: vm.activeTool == .none ? vm.draggableBalls : [],
            onDragBegan: { vm.dragBegan(node: $0) },
            onDragMoved: { vm.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { vm.dragEnded(node: $0) },
            onDragEndedAt: { node, localPoint in handleTableDragEnd(node: node, localPoint: localPoint) },
            selectableBallNodes: selectable,
            onBallTapped: { vm.selectBall(node: $0) },
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(frameReader(id: "scene"))
        .clipped()
    }

    // MARK: - Side columns（条 21.3 + 条 18 同规范）

    private var leftColumn: some View {
        BTSolverLeftColumn(
            canSolve: !vm.isPlaying && !vm.isComputing && vm.canSolve,
            onSolve: { vm.solve() },
            canNext: !vm.isPlaying && vm.solutions.count >= 2,
            onNext: { vm.nextSolution() }
        )
    }

    private var instrumentColumn: some View {
        BTShotInstrumentColumn(
            spinX: vm.spinX, spinY: vm.spinY,
            onSpinTap: { if vm.hasSolutions { showSpinPad = true } },
            velocity: velocityBinding,
            range: ShotTuning.velocityRange,
            isDisabled: vm.isPlaying || !vm.hasSolutions
        )
    }

    private var actionColumn: some View {
        BTShotActionColumn(
            strikeTitle: vm.isPlaying ? BTStrikeTitle.freePlayBusy : BTStrikeTitle.freePlay,
            strikeEnabled: vm.canStrike,
            onStrike: { vm.play() },
            undoEnabled: !vm.isPlaying && vm.canUndoShot,
            onUndo: { vm.undoLastShot() },
            playbackEnabled: !vm.isPlaying && vm.canPlayback,
            onPlayback: { vm.replayLastShot() }
        )
    }

    private var velocityBinding: Binding<Double> {
        Binding(get: { vm.velocity }, set: { vm.adjustCurrentSolution(velocity: $0) })
    }

    private var spinXBinding: Binding<Double> {
        Binding(get: { vm.spinX }, set: { vm.adjustCurrentSolution(spinX: $0) })
    }

    private var spinYBinding: Binding<Double> {
        Binding(get: { vm.spinY }, set: { vm.adjustCurrentSolution(spinY: $0) })
    }

    // MARK: - Bottom bar（G12：删除解摘要行，底部只留球库；解读数入口 = 右柱打点/力度）

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        paletteBar(proxy)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HUDStyle.panelBackground)
            .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
            .background(frameReader(id: "palette"))
            .environment(\.colorScheme, .dark)
    }

    // MARK: - Palette

    private func paletteBar(_ proxy: ShotStageProxy) -> some View {
        let libraryWidth = proxy.isValid ? proxy.libraryWidth : proxy.sceneSize.width
        return BTBallPaletteBar(
            coordinateSpace: "snooker",
            ballDiameter: BTBallPaletteMetrics.regularDiameter,
            isPlaying: vm.isPlaying,
            libraryWidth: libraryWidth,
            isOnTable: { vm.onTableKeys.contains($0) },
            sceneFrame: sceneFrame,
            unproject: { projector.unproject?($0) },
            onTap: { key in
                if vm.onTableKeys.contains(key) { vm.pulseTableBall(key) }
                else { vm.placeFromPalette(key) }
            },
            onPlace: { key, world in
                if let world { vm.placeFromPalette(key, atWorld: world) }
                else { vm.placeFromPalette(key) }
            },
            draggingKey: $draggingKey,
            dragLocation: $dragLocation,
            dragOverTable: $dragOverTable
        )
    }

    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard BTBallPaletteDragBack.hitPalette(localPoint: localPoint,
                                               sceneFrame: sceneFrame,
                                               paletteFrame: paletteFrame),
              let key = vm.scene.ballKey(for: node) else { return }
        vm.removeFromTable(key)
        flash("已移回球库")
    }

    // MARK: - Toolbar menu

    /// 条 21.6 / G25：反解训练三点菜单模板（求解范围 → 显示 → 清空/恢复默认）。
    private var moreMenu: some View {
        BTSolverMoreMenu(
            scene: vm.scene,
            onClearTable: { vm.clearTable() },
            onReset: { vm.resetAll() },
            solveRange: {
                Toggle("允许左右塞", isOn: $vm.allowSideSpin)
                Toggle("仅基础走位（≤1 库）", isOn: $vm.basicPositionOnly)
            }
        )
    }

    // MARK: - Banner

    private func flash(_ message: String, tone: BTToastTone = .success) {
        BTToast.present(message, tone: tone) { toast = $0 }
    }

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: BTShotPageFramePreference.self,
                                   value: [id: geo.frame(in: .named("snooker"))])
        }
    }
}


#Preview("Dark") {
    NavigationStack { SnookerTacticsView() }
        .preferredColorScheme(.dark)
}
