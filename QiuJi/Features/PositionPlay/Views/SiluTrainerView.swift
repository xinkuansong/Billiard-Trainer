import SwiftUI
import SceneKit

/// 思路训练（走位反解器，ADR-P13-01；条 21 布局 v2）。
///
/// 摆母球/目标球/袋口，用工具画**可行落区**（情形 A，仅矩形）或标 **K 球过点**（情形 B），
/// 由 `PositionPlaySolver` 离线反解出塞与力度。条 18 布局：求解/下一解 + 开球在左侧竖排，
/// 力度/打点（求解后可微调重预测）+ 击球/上一杆/回放在右侧竖排，底部只留解摘要与球库。
struct SiluTrainerView: View {
    /// 可选初始球形（如「拍照建球形」产出的快照）。nil = 默认开箱球形。
    let initialBoard: BoardSnapshot?

    init(initialBoard: BoardSnapshot? = nil) {
        self.initialBoard = initialBoard
    }

    @StateObject private var vm = SiluTrainerViewModel()
    private var is3D: Bool { vm.cameraMode == .perspective3D }
    @State private var hasAppeared = false
    @State private var projector = TableProjector()
    @State private var showBreakPicker = false
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
            let bottomHeight = is3D && !vm.isBreakMode ? Self.topRowHeight : Self.bottomBarHeight
            let sceneH = max(geo.size.height - Self.topRowHeight - bottomHeight, 1)
            let proxy = ShotStageProxy(
                sceneSize: CGSize(width: geo.size.width, height: sceneH),
                halfLength: rig?.tableOuterHalfLength ?? ShotTableLayout.defaultHalfLength,
                halfWidth: rig?.tableOuterHalfWidth ?? ShotTableLayout.defaultHalfWidth
            )
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    topToolRow
                        .disabled(is3D)
                        .frame(height: Self.topRowHeight)
                    stage(proxy)
                        .frame(height: sceneH)
                    bottomBar(proxy)
                        .frame(height: bottomHeight)
                }
                if let key = draggingKey {
                    BTBallPaletteDragGhost(key: key, location: dragLocation, overTable: dragOverTable)
                }
            }
        }
        .animation(BTMotion.springPanel, value: showSpinPad)
        .btToast($toast)
        .coordinateSpace(name: "silu")
        .onPreferenceChange(BTShotPageFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .trainingBackgroundMusic()
        .btDarkToolChrome("思路训练")
        .toolbar {
            ToolbarItem(placement: .principal) {
                BTSolverNavStatus(
                    title: "思路训练",
                    isBusy: vm.isComputing,
                    statusText: vm.breakRunner?.statusText(isPerspective: is3D) ?? vm.statusText
                )
            }
            ToolbarItem(placement: .topBarTrailing) { cameraToggle }
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
        }
        .sheet(isPresented: $showBreakPicker) {
            BreakGamePickerSheet { vm.startBreakFlow(game: $0) }
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.setupScene()
                if let initialBoard { vm.loadBoard(initialBoard) }
            }
        }
    }

    private var cameraToggle: some View {
        Button(is3D ? "3D" : "2D") {
            showSpinPad = false
            let needsOverview = !vm.scene.hasPerspectiveView
            vm.cameraMode = is3D ? .topDown2DRotated : .perspective3D
            vm.scene.setCameraMode(vm.cameraMode, animated: false)
            if is3D && needsOverview { _ = vm.scene.cameraRig?.observeWholeTable() }
        }
        .font(.btSubheadlineSemibold)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(is3D ? "切换到2D俯视" : "切换到3D视角")
        .accessibilityValue(is3D ? "3D" : "2D")
        .accessibilityIdentifier("silu.cameraMode")
    }

    // MARK: - Top tool row

    private var topToolRow: some View {
        HStack(spacing: Spacing.sm) {
            if vm.isBreakMode {
                breakModePill
                Spacer(minLength: 0)
            } else {
                toolChips
            }
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    /// 开球模式标识胶囊（T-P18-47；G9：摆架图形与开球按钮同源）。
    private var breakModePill: some View {
        HStack(spacing: 4) {
            BreakRackGlyph(color: .btPrimary, size: 13)
            Text("开球 · \(vm.breakRunner.map { BreakFlowRunner.title(for: $0.game) } ?? "")")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .btHudGlass()
    }

    @ViewBuilder
    private var toolChips: some View {
            BTChipRow(
                options: ["落区", "落点", "过点", "摆球"],
                selection: Binding(
                    get: {
                        switch vm.activeTool {
                        case .region: return 0
                        case .restPoint: return 1
                        case .passPoint: return 2
                        case .none: return 3
                        }
                    },
                    set: {
                        switch $0 {
                        case 0: vm.activeTool = .region
                        case 1: vm.activeTool = .restPoint
                        case 2: vm.activeTool = .passPoint
                        default: vm.activeTool = .none
                        }
                    }
                ),
                scrollable: false
            )
            .disabled(vm.isPlaying)

            // Q15.3：清除键正常尺寸、紧贴「摆球」chip 右侧（常驻，无约束时灰禁不增删避免布局跳变）。
            BTEraserButton(isEnabled: !vm.isPlaying && vm.hasConstraint) { vm.clearConstraint() }

            Spacer(minLength: 0)
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11 走 ShotStageProxy）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer
            if !is3D && !vm.isBreakMode && vm.activeTool != .none {
                SolveConstraintDrawingOverlay(
                    coordinateSpaceName: "silu",
                    sceneFrame: sceneFrame,
                    unproject: { projector.unproject?($0) },
                    onDrag: { start, current, ended in
                        vm.toolDrag(startNormalized: start, currentNormalized: current, ended: ended)
                    }
                )
            }

            // G18/V6：开球模式贴边仪表（左瞄准轮 + 右力度柱），共享单一真源。
            if let runner = vm.breakRunner {
                BreakInstrumentsOverlay(runner: runner, proxy: proxy, isPerspective: is3D)
            }

            if !vm.isBreakMode && proxy.isValid {
                // G3 轨迹档位 chip：下沿贴球桌上沿、靠屏幕最右。
                BTTrajectoryDetailChip { vm.redrawTrajectory() }
                    .btChipBandPlacement(proxy)
                    .allowsHitTesting(!vm.isPlaying)

                // 左下（G24）：BTSolverLeftColumn + Slot L1 开球。
                leftColumn
                    .btStageFrame(is3D ? ShotPerspectiveLayout(sceneSize: proxy.sceneSize).bottomLeadingFrame(size: BTSolverLeftColumn.stackWithSlotL1Size) : proxy.bottomLeadingFrame(size: BTSolverLeftColumn.stackWithSlotL1Size))

                // G4/G5/G7 打点+力度仪表柱：左缘贴球桌右侧、力度条本体底部对齐。
                instrumentColumn
                    .btStageFrame(is3D ? ShotPerspectiveLayout(sceneSize: proxy.sceneSize).instrumentFrame : proxy.instrumentFrame())

                // 条 18.2：击球/上一杆/回放，右下角底边齐球桌底线。
                actionColumn
                    .btStageFrame(is3D ? ShotPerspectiveLayout(sceneSize: proxy.sceneSize).actionFrame : proxy.actionColumnFrame())
            }

            if showSpinPad {
                BTSpinPadOverlay(spinX: spinXBinding, spinY: spinYBinding,
                                 tableWidth: is3D ? proxy.sceneSize.width - Spacing.lg * 2 : proxy.playingRect.width,
                                 bottomPadding: is3D ? Spacing.sm : proxy.spinPadBottomPadding,
                                 usesCompactLayout: is3D,
                                 onClose: { showSpinPad = false })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(20)
            }
        }
    }

    // MARK: - Scene

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: is3D ? .cameraControl : .tapsOnly,
            autoFitsRotatedTable: !is3D,
            onPocketTapped: is3D || vm.isBreakMode || vm.isPlaying ? nil : { vm.selectPocket(at: $0) },
            // 开球模式：仅母球可拖（限开球区），其余台面交互挂起。
            draggableBallNodes: vm.isPlaying ? [] : (vm.breakRunner?.draggableCue
                ?? (is3D || vm.activeTool == .none ? vm.draggableBalls : [])),
            onDragBegan: { node in
                if let runner = vm.breakRunner { runner.dragBegan(node: node) }
                else { vm.dragBegan(node: node) }
            },
            onDragMoved: { node, world in
                if let runner = vm.breakRunner { runner.dragMoved(node: node, worldPosition: world) }
                else { vm.dragMoved(node: node, worldPosition: world) }
            },
            onDragEnded: { node in
                if let runner = vm.breakRunner { runner.dragEnded(node: node) }
                else { vm.dragEnded(node: node) }
            },
            onDragEndedAt: { node, localPoint in
                guard !vm.isBreakMode else { return }
                handleTableDragEnd(node: node, localPoint: localPoint)
            },
            selectableBallNodes: (is3D || vm.isBreakMode || vm.activeTool != .none) ? [] : vm.selectableBalls,
            onBallTapped: { vm.selectTarget(node: $0) },
            // G18/V6：开球模式拖屏调瞄准（G13 相对语义）；非开球模式本页无自由拖瞄，忽略。
            onAimNudged: is3D ? nil : { if let runner = vm.breakRunner { runner.nudgeAim(byDegrees: $0) } },
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(frameReader(id: "scene"))
        .clipped()
    }

    // MARK: - Side columns（条 21.3 + 条 18：求解/下一解/开球在左，力度打点/击球/上一杆/回放在右）

    private var leftColumn: some View {
        VStack(spacing: 8) {
            BTSolverLeftColumn(
                canSolve: !vm.isPlaying && !vm.isComputing && vm.hasConstraint,
                onSolve: { vm.solve() },
                canNext: !vm.isPlaying && vm.solutions.count >= 2,
                onNext: { vm.nextSolution() }
            )
            BTBreakSideButton(isEnabled: !vm.isPlaying && !vm.isComputing) {
                showBreakPicker = true
            }
        }
    }

    /// 条 21.4：求解完成后力度/打点可微调——改动即按新参数重预测当前解。
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

    /// 力度微调绑定：读当前解速度，写 → 重预测当前解（条 21.4）。
    private var velocityBinding: Binding<Double> {
        Binding(
            get: { vm.velocity },
            set: { vm.adjustCurrentSolution(velocity: $0) }
        )
    }

    private var spinXBinding: Binding<Double> {
        Binding(get: { vm.spinX }, set: { vm.adjustCurrentSolution(spinX: $0) })
    }

    private var spinYBinding: Binding<Double> {
        Binding(get: { vm.spinY }, set: { vm.adjustCurrentSolution(spinY: $0) })
    }

    // MARK: - Bottom bar（G12：删除解摘要行，底部只留球库；解读数入口 = 右柱打点/力度）

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        Group {
            if let runner = vm.breakRunner {
                BreakControlBar(runner: runner, onCancel: { vm.cancelBreakFlow() })
            } else if is3D {
                HStack {
                    BTSceneObservationMenu(
                        scene: vm.scene,
                        targetNode: vm.selectedTargetKey.flatMap { vm.scene.allBallNodes[$0] },
                        pocketIndex: vm.selectedPocketIndex,
                        identifierPrefix: "silu",
                        canReturnToAim: vm.canObserveCurrentAim,
                        onReturnToAim: vm.observeCurrentAim
                    )
                    .disabled(vm.isPlaying)
                    Spacer(minLength: 0)
                    Text("拖球摆位 · 空白处转视角").foregroundStyle(Color.btTextSecondary)
                }
                .font(.btFootnote)
                .padding(.horizontal, Spacing.sm)
            } else {
                paletteBar(proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HUDStyle.panelBackground)
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Palette

    private func paletteBar(_ proxy: ShotStageProxy) -> some View {
        let libraryWidth = proxy.libraryWidth
        return BTBallPaletteBar(
            coordinateSpace: "silu",
            ballDiameter: proxy.paletteBallDiameter,
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
        guard !is3D else { return } // The palette is hidden in perspective mode.
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
                                   value: [id: geo.frame(in: .named("silu"))])
        }
    }
}

#Preview("Dark") {
    NavigationStack { SiluTrainerView() }
        .preferredColorScheme(.dark)
}
