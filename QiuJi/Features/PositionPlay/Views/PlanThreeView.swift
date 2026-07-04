import SwiftUI
import SceneKit

/// 「打一走二想三」走位规划卡。
///
/// 右侧角色轨选 ①球/①袋 · ②球/②袋 · ③球（随时改派）；② 自动画白球停球**扇形引导**
/// （无③两侧、有③单侧）。上方工具画真正的**落区/落点/过点**约束，`PositionPlaySolver`
/// 反解「打一」的塞与力度，可「下一解」翻档、击球。打进①后窗口前滑续打。
struct PlanThreeView: View {
    /// 可选初始球形（球形生成器 / 拍照建球形交付的散开快照）。nil = 默认开箱球形。
    let initialBoard: BoardSnapshot?

    init(initialBoard: BoardSnapshot? = nil) {
        self.initialBoard = initialBoard
    }

    @StateObject private var vm = PlanThreeViewModel()
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
    private static let c1 = Color(red: 0.36, green: 0.92, blue: 0.55)
    private static let c2 = Color(red: 0.20, green: 0.85, blue: 0.95)
    private static let c3 = Color(red: 1.0, green: 0.78, blue: 0.28)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topToolRow
                HStack(spacing: 0) {
                    ZStack {
                        sceneContainer
                        if vm.activeTool != .none { drawingOverlay }
                    }
                    roleRail
                }
                bottomBar
            }
            if let key = draggingKey { dragGhost(key) }
            bannerView
        }
        .coordinateSpace(name: "planthree")
        .onPreferenceChange(PlanThreeFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .navigationTitle("打一走二想三")
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
            Text("打一走二想三")
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

            if vm.activeTool == .region {
                BTChipRow(
                    options: PlanThreeViewModel.RegionShape.allCases.map { $0.rawValue },
                    selection: Binding(
                        get: { vm.regionShape == .rect ? 0 : 1 },
                        set: { vm.regionShape = $0 == 0 ? .rect : .circle }
                    ),
                    scrollable: false
                )
                .disabled(vm.isPlaying)
            }

            Spacer(minLength: 0)

            Button { vm.clearConstraint() } label: {
                Image(systemName: "eraser")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(vm.hasConstraint ? 0.8 : 0.3))
            }
            .disabled(vm.isPlaying || !vm.hasConstraint)
            .accessibilityLabel("清除约束")
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Scene

    private var sceneContainer: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            onPocketTapped: { vm.selectPocket(at: $0) },
            draggableBallNodes: vm.activeTool == .none ? vm.draggableBalls : [],
            onDragBegan: { vm.dragBegan(node: $0) },
            onDragMoved: { vm.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { vm.dragEnded(node: $0) },
            onDragEndedAt: { node, localPoint in handleTableDragEnd(node: node, localPoint: localPoint) },
            selectableBallNodes: vm.activeTool == .none ? vm.selectableBalls : [],
            onBallTapped: { vm.selectBall(node: $0) },
            projector: projector
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(frameReader(id: "scene"))
        .clipped()
    }

    private var drawingOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("planthree"))
                    .onChanged { value in handleDraw(start: value.startLocation, current: value.location, ended: false) }
                    .onEnded { value in handleDraw(start: value.startLocation, current: value.location, ended: true) }
            )
    }

    private func handleDraw(start: CGPoint, current: CGPoint, ended: Bool) {
        guard sceneFrame != .zero,
              let s = normalized(fromComposer: start),
              let c = normalized(fromComposer: current) else { return }
        vm.toolDrag(startNormalized: s, currentNormalized: c, ended: ended)
    }

    private func normalized(fromComposer point: CGPoint) -> CanvasPoint? {
        let local = CGPoint(x: point.x - sceneFrame.minX, y: point.y - sceneFrame.minY)
        guard let world = projector.unproject?(local) else { return nil }
        let n = AngleSceneCalculator.sceneToNormalized(position: world)
        return CanvasPoint(x: Double(n.x), y: Double(n.y))
    }

    // MARK: - Role rail (right)

    private var roleRail: some View {
        VStack(spacing: 8) {
            ForEach(PlanThreeRole.order, id: \.rawValue) { role in
                roleChip(role)
            }
            Button { vm.clearPlan() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 52, height: 30)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(vm.isPlaying)
            .accessibilityLabel("清空计划")
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, 6)
        .frame(width: 70)
        .background(Color(white: 0.08))
        .environment(\.colorScheme, .dark)
    }

    private func roleChip(_ role: PlanThreeRole) -> some View {
        let armed = vm.armedRole == role
        let filled = vm.isFilled(role)
        let accent = roleColor(role)
        return Button { vm.armRole(role) } label: {
            VStack(spacing: 3) {
                Text(roleTitle(role))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                roleContent(role, filled: filled, accent: accent)
            }
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(armed ? accent.opacity(0.18) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(armed ? accent : accent.opacity(filled ? 0.5 : 0.22),
                            style: StrokeStyle(lineWidth: armed ? 2 : 1, dash: filled ? [] : [4, 3]))
            )
            .scaleEffect(armed ? 1.04 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: armed)
        }
        .buttonStyle(.plain)
        .disabled(vm.isPlaying)
    }

    @ViewBuilder
    private func roleContent(_ role: PlanThreeRole, filled: Bool, accent: Color) -> some View {
        if role.isBall {
            if let key = vm.ballKey(for: role) {
                PoolBallFace(key: key, diameter: 26)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.5))
            } else {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.55))
            }
        } else {
            Image(systemName: filled ? "scope" : "circle.dashed")
                .font(.system(size: 18, weight: filled ? .bold : .semibold))
                .foregroundStyle(filled ? accent : accent.opacity(0.55))
        }
    }

    private func roleColor(_ role: PlanThreeRole) -> Color {
        switch role {
        case .ball1, .pocket1: return Self.c1
        case .ball2, .pocket2: return Self.c2
        case .ball3: return Self.c3
        }
    }

    private func roleTitle(_ role: PlanThreeRole) -> String {
        switch role {
        case .ball1: return "①球"
        case .pocket1: return "①袋"
        case .ball2: return "②球"
        case .pocket2: return "②袋"
        case .ball3: return "③球"
        }
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
        if !sol.satisfiesConstraint { return "\(advanced)最接近解 · \(spin) · \(cushion)" }
        return "\(advanced)\(spin) · \(cushion)"
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
                            system: "arrow.triangle.2.circlepath") { vm.nextSolution() }
                    .disabled(vm.isPlaying || vm.solutions.count < 2)
                smallButton(tint: vm.canStrike ? Color.btPrimary : Color.btPrimary.opacity(0.3),
                            label: "打一", system: "play.fill") { vm.play() }
                    .disabled(!vm.canStrike)
            }
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
        DragGesture(minimumDistance: 10, coordinateSpace: .named("planthree"))
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
        let p = CGPoint(x: localPoint.x + sceneFrame.minX, y: localPoint.y + sceneFrame.minY)
        guard paletteFrame.contains(p), let key = vm.scene.ballKey(for: node) else { return }
        vm.removeFromTable(key)
        flash("已移回球库")
    }

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
            Color.clear.preference(key: PlanThreeFramePreference.self,
                                   value: [id: geo.frame(in: .named("planthree"))])
        }
    }
}

private struct PlanThreeFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

#Preview("Dark") {
    NavigationStack { PlanThreeView() }
        .preferredColorScheme(.dark)
}
