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
    @State private var banner: String?

    private static let paletteColumns = 8
    /// G10：顶栏 / 底栏固定高度 ⇒ scene 区域高度恒定 ⇒ 球桌渲染尺寸锁定。
    private static let topRowHeight: CGFloat = 46
    /// 底栏 = 球库两行（G12 后无解摘要行）。
    private static let bottomBarHeight: CGFloat = 78

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
                if let key = draggingKey { dragGhost(key) }
                bannerView
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSpinPad)
        .coordinateSpace(name: "snooker")
        .onPreferenceChange(SnookerFramePreference.self) { frames in
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
            ToolbarItem(placement: .principal) { navStatus }
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

    // MARK: - Nav status

    private var navStatus: some View {
        VStack(spacing: 1) {
            Text("防守")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.btPrimary)
                .lineLimit(1)
            HStack(spacing: 4) {
                if vm.isComputing { ProgressView().controlSize(.mini).tint(.white) }
                Text(vm.statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
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

                // 左下（条 21.3 + G6）：求解/下一解叠在开球按钮（禁用态）上方，
                // 右缘贴球桌左缘、底边齐球桌底线。
                leftColumn
                    .btStageFrame(proxy.bottomLeadingFrame(size: Self.leftColumnSize))

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

    /// 左下控件叠尺寸：求解 30 + 8 + 下一解 30 + 8 + 开球 46。
    private static let leftColumnSize = CGSize(width: 48, height: 122)

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
        VStack(spacing: 8) {
            BTTextActionButton(title: "求解", role: .primary,
                               isDisabled: vm.isPlaying || vm.isComputing || !vm.canSolve,
                               width: 46) {
                vm.solve()
            }
            BTTextActionButton(title: "下一解",
                               isDisabled: vm.isPlaying || vm.solutions.count < 2,
                               width: 46) {
                vm.nextSolution()
            }
            // 本页无开球——按条 18.4 显示禁用态。
            BTBreakSideButton(isEnabled: false) {}
        }
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
            strikeTitle: vm.isPlaying ? "击球中" : "击球",
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
        // #5a：球库常显全部 16 颗；在桌球变暗、不可拖，点击在桌球 = 桌上对应球放大脉冲提示位置。
        // G8：排球总宽 = 球桌宽、居中，两侧留白。
        let all = PositionPlayBall.allKeys
        let row1 = Array(all.prefix(Self.paletteColumns))
        let row2 = Array(all.dropFirst(Self.paletteColumns))
        let libraryWidth = proxy.isValid ? proxy.libraryWidth : proxy.sceneSize.width
        let columnWidth = max(libraryWidth / CGFloat(Self.paletteColumns), 1)
        return VStack(spacing: 4) {
            paletteRow(row1, columnWidth: columnWidth)
            paletteRow(row2, columnWidth: columnWidth)
        }
        .frame(maxWidth: .infinity)
    }

    private func paletteRow(_ keys: [String], columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.paletteColumns, id: \.self) { i in
                Group {
                    if i < keys.count { ballToken(keys[i]) } else { Color.clear }
                }
                .frame(width: columnWidth, height: 32)
            }
        }
    }

    private func ballToken(_ key: String) -> some View {
        let onTable = vm.onTableKeys.contains(key)
        return PoolBallFace(key: key, diameter: 30)
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .opacity(draggingKey == key ? 0.3 : (onTable ? 0.3 : 1))
            .onTapGesture {
                if onTable { vm.pulseTableBall(key) } else { vm.placeFromPalette(key) }
            }
            .gesture(paletteDrag(key), including: onTable ? .subviews : .all)
    }

    private func paletteDrag(_ key: String) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named("snooker"))
            .onChanged { value in
                guard !vm.isPlaying else { return }
                draggingKey = key
                dragLocation = value.location
                dragOverTable = sceneFrame.contains(value.location)
            }
            .onEnded { value in
                let loc = value.location
                defer { draggingKey = nil; dragOverTable = false }
                guard !vm.isPlaying, sceneFrame.contains(loc) else { return }
                let local = CGPoint(x: loc.x - sceneFrame.minX, y: loc.y - sceneFrame.minY)
                if let world = projector.unproject?(local) {
                    vm.placeFromPalette(key, atWorld: world)
                } else {
                    vm.placeFromPalette(key)
                }
            }
    }

    @ViewBuilder
    private func dragGhost(_ key: String) -> some View {
        PoolBallFace(key: key, diameter: 42)
            .overlay(Circle().stroke(dragOverTable ? Color.btSuccess : .white.opacity(0.4),
                                     lineWidth: dragOverTable ? 2.5 : 1))
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            .position(dragLocation)
            .allowsHitTesting(false)
    }

    private func handleTableDragEnd(node: SCNNode, localPoint: CGPoint) {
        guard sceneFrame != .zero, paletteFrame != .zero else { return }
        let composerPoint = CGPoint(x: localPoint.x + sceneFrame.minX, y: localPoint.y + sceneFrame.minY)
        guard paletteFrame.contains(composerPoint), let key = vm.scene.ballKey(for: node) else { return }
        vm.removeFromTable(key)
        flash("已移回球库")
    }

    // MARK: - Toolbar menu

    /// 条 21.6 同规范：齿轮与三点菜单合并为单个省略号菜单，标题居中。
    private var moreMenu: some View {
        Menu {
            Section("求解范围") {
                Toggle("允许左右塞", isOn: $vm.allowSideSpin)
                Toggle("仅基础走位（≤1 库）", isOn: $vm.basicPositionOnly)
            }
            Section("显示") {
                BTTableGridMenuToggle(scene: vm.scene)
            }
            Section {
                Button("清空桌面", systemImage: "trash") { vm.clearTable() }
                Button("恢复默认", systemImage: "arrow.counterclockwise") { vm.resetAll() }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Banner

    @ViewBuilder
    private var bannerView: some View {
        if let banner {
            VStack {
                Text(banner)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm)
                    .background(Color.btSuccess, in: Capsule())
                    .padding(.top, 60)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func flash(_ message: String) {
        withAnimation { banner = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { banner = nil }
        }
    }

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: SnookerFramePreference.self,
                                   value: [id: geo.frame(in: .named("snooker"))])
        }
    }
}

// MARK: - Frame preference

private struct SnookerFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

#Preview("Dark") {
    NavigationStack { SnookerTacticsView() }
        .preferredColorScheme(.dark)
}
