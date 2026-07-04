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

    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false

    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero
    @State private var banner: String?

    // 「试打」（T-P18-08）：带当前球局快照进自由击球（编排台自由模式）。
    @State private var goFreePlay = false
    @State private var freePlayBoard: BoardSnapshot?

    private static let paletteColumns = 8

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topToolRow
                sceneContainer
                bottomBar
            }
            if let key = draggingKey { dragGhost(key) }
            bannerView
        }
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
        .navigationDestination(isPresented: $goFreePlay) {
            PositionPlayComposerView(initialBoard: freePlayBoard, initialMode: .free)
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
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                solutionRow
                paletteBar
            }
            actionColumn
        }
        .background(Color(white: 0.11))
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    /// 当前解的只读指示行（统一 `ShotControlBar`，T-P18-10）+「试打」入口（T-P18-08）。
    private var solutionRow: some View {
        ShotControlBar(
            spinX: vm.spinX, spinY: vm.spinY,
            power: .readOnly(
                velocity: vm.hasSolutions ? vm.velocity : nil,
                subtitle: vm.currentSolution.map(solutionSubtitle),
                subtitleTint: (vm.currentSolution?.satisfiesConstraint ?? true)
                    ? nil : Color.btDestructive
            )
        ) {
            ShotTryFreePlayButton(isEnabled: !vm.isPlaying && !vm.onTableKeys.isEmpty) {
                freePlayBoard = vm.currentSnapshot()
                goFreePlay = true
            }
        }
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

    // MARK: - Action column

    private var actionColumn: some View {
        VStack(spacing: 6) {
            Button { vm.solve() } label: {
                actionLabel(title: "求解", system: "function",
                            tint: vm.isComputing ? Color.btPrimary.opacity(0.4) : Color.btPrimary)
            }
            .buttonStyle(.plain)
            .disabled(vm.isPlaying || vm.isComputing || !vm.hasConstraint)

            HStack(spacing: 6) {
                smallButton(tint: .white.opacity(0.14), label: "下一解",
                            system: "arrow.triangle.2.circlepath") {
                    vm.nextSolution()
                }
                .disabled(vm.isPlaying || vm.solutions.count < 2)

                smallButton(tint: vm.canStrike ? Color.btPrimary : Color.btPrimary.opacity(0.3),
                            label: "击球", system: "play.fill") {
                    vm.play()
                }
                .disabled(!vm.canStrike)
            }

            #if targetEnvironment(simulator)
            Button { exportSolution() } label: {
                actionLabel(title: "导出", system: "square.and.arrow.up", tint: .white.opacity(0.14))
            }
            .buttonStyle(.plain)
            .disabled(vm.isPlaying || vm.currentSolution == nil)
            #endif
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    private func actionLabel(title: String, system: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: system).font(.system(size: 13, weight: .bold))
            Text(title).font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(width: 92, height: 38)
        .background(tint, in: Capsule())
    }

    @ViewBuilder
    private func smallButton(tint: Color, label: String, system: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 43, height: 38)
                .background(tint, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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

    // MARK: - Export (simulator only)

    #if targetEnvironment(simulator)
    private func exportSolution() {
        guard let sequence = vm.makeExportSequence() else {
            flash("无可导出解")
            return
        }
        do {
            let url = try PositionPlaySequenceArchive.archive(sequence)
            flash("已存入内容库：\(url.lastPathComponent)")
        } catch {
            flash("序列归档失败：\(error.localizedDescription)")
        }
    }
    #endif

    // MARK: - Toolbar menu

    private var moreMenu: some View {
        Menu {
            Section("求解范围") {
                Toggle("允许左右塞", isOn: $vm.allowSideSpin)
                Toggle("仅基础走位（≤1 库）", isOn: $vm.basicPositionOnly)
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
