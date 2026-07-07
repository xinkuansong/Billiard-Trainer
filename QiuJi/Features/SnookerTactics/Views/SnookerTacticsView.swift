import SwiftUI
import SceneKit

/// 做斯诺克战术工具（安全球反解，ADR-P16-01）。
///
/// 独立页面、布局参考思路训练器：顶部工具行（目标/障碍/摆球）→ 球桌 → 底部条（解指示 + 球库 + 操作列）。
/// 选目标球（青环）+ 障碍球（红环）后点「求解」，由 `PositionPlaySolver.solveSnooker` 反解出令母球
/// 合法首触目标球、不进袋、并停在被障碍球完全挡死位置的塞/力度/瞄准。
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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topToolRow
                ZStack(alignment: .bottom) {
                    sceneContainer
                    leftColumn
                    rightColumn
                    if showSpinPad {
                        BTSpinPadOverlay(spinX: spinXBinding, spinY: spinYBinding,
                                         onClose: { showSpinPad = false })
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                bottomBar
            }
            if let key = draggingKey { dragGhost(key) }
            bannerView
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSpinPad)
        .coordinateSpace(name: "snooker")
        .onPreferenceChange(SnookerFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .navigationTitle("做斯诺克")
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
            }
        }
    }

    // MARK: - Nav status

    private var navStatus: some View {
        VStack(spacing: 1) {
            Text("做斯诺克")
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
                options: ["目标球", "障碍球", "摆球"],
                selection: Binding(
                    get: {
                        switch vm.activeTool {
                        case .selectTarget: return 0
                        case .selectBlocker: return 1
                        case .none: return 2
                        }
                    },
                    set: {
                        switch $0 {
                        case 0: vm.activeTool = .selectTarget
                        case 1: vm.activeTool = .selectBlocker
                        default: vm.activeTool = .none
                        }
                    }
                ),
                scrollable: false
            )
            .disabled(vm.isPlaying)

            Spacer(minLength: 0)

            // 常驻（#9）：无选择时变灰禁用，不增删避免布局跳变。
            let hasSelection = vm.selectedTargetKey != nil || vm.selectedBlockerKey != nil
            Button { vm.clearSelection() } label: {
                Image(systemName: "eraser")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(hasSelection ? 0.8 : 0.3))
            }
            .disabled(vm.isPlaying || !hasSelection)
            .accessibilityLabel("清除角色选择")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Scene

    private var sceneContainer: some View {
        let selectable: [SCNNode] = (vm.activeTool == .selectTarget || vm.activeTool == .selectBlocker)
            ? vm.selectableBalls : []
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
        // 三档轨迹标注切换（条 12.5）：全击打页统一放球桌区右上角。
        .overlay(alignment: .topTrailing) {
            BTTrajectoryDetailChip { vm.redrawTrajectory() }
                .padding(Spacing.sm)
        }
    }

    // MARK: - Side columns（条 21.3 + 条 18 同规范）

    private var leftColumn: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            BTTextActionButton(title: "求解", role: .primary,
                               isDisabled: vm.isPlaying || vm.isComputing || !vm.hasConstraint) {
                vm.solve()
            }
            BTTextActionButton(title: "下一解",
                               isDisabled: vm.isPlaying || vm.solutions.count < 2) {
                vm.nextSolution()
            }
            // 本页无开球——按条 18.4 显示禁用态。
            BTBreakSideButton(isEnabled: false) {}
        }
        .padding(.leading, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private var rightColumn: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            BTShotInstrumentColumn(
                spinX: vm.spinX, spinY: vm.spinY,
                onSpinTap: { if vm.hasSolutions { showSpinPad = true } },
                velocity: velocityBinding,
                range: ShotTuning.velocityRange,
                isDisabled: vm.isPlaying || !vm.hasSolutions
            )
            .frame(width: 36, height: 220)
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
        .padding(.trailing, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            solutionRow
            paletteBar
        }
        .background(Color(white: 0.11))
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    /// 当前解摘要行（统一 `ShotControlBar`，T-P18-10）。
    private var solutionRow: some View {
        ShotControlBar(
            spinX: vm.spinX, spinY: vm.spinY,
            velocity: vm.hasSolutions ? vm.velocity : nil,
            subtitle: vm.currentSolution.map(solutionSubtitle),
            subtitleTint: (vm.currentSolution?.satisfiesConstraint ?? true)
                ? nil : Color.btDestructive
        ) { EmptyView() }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 5)
    }

    private func solutionSubtitle(_ sol: PositionPlaySolution) -> String {
        let cushion = sol.cushionCount == 0 ? "不吃库" : "\(sol.cushionCount) 库"
        let spin = SiluSpinLabel.text(spinX: sol.shot.spinX, spinY: sol.shot.spinY)
        let advanced = sol.beyondCushionBudget ? "进阶 · " : ""
        if !sol.satisfiesConstraint {
            return "\(advanced)半斯诺克 · \(spin) · \(cushion)"
        }
        return "\(advanced)完全斯诺克 · 余量 \(Int(sol.margin.rounded()))° · \(spin) · \(cushion)"
    }

    // MARK: - Palette

    private var paletteBar: some View {
        // #5a：球库常显全部 16 颗；在桌球变暗、不可拖，点击在桌球 = 桌上对应球放大脉冲提示位置。
        let all = PositionPlayBall.allKeys
        let row1 = Array(all.prefix(Self.paletteColumns))
        let row2 = Array(all.dropFirst(Self.paletteColumns))
        return VStack(spacing: 4) {
            paletteRow(row1)
            paletteRow(row2)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
    }

    private func paletteRow(_ keys: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Self.paletteColumns, id: \.self) { i in
                Group {
                    if i < keys.count { ballToken(keys[i]) } else { Color.clear }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 32)
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
