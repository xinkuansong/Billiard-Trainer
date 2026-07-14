import SwiftUI
import SceneKit

/// 「打一走二想三」走位规划卡。
///
/// 底部角色横排选 ①球/①袋 · ②球/②袋 · ③球（随时改派）；② 自动画白球停球**扇形引导**
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
    @State private var showBreakPicker = false
    @State private var showSpinPad = false

    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false

    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero
    @State private var toast: BTToastMessage?

    private static let paletteColumns = 8
    private static let c1 = Color.btPlanRole1
    private static let c2 = Color.btPlanRole2
    private static let c3 = Color.btPlanRole3
    /// G10：顶栏 / 底栏固定高度 ⇒ scene 区域高度恒定 ⇒ 球桌渲染尺寸锁定。
    private static let topRowHeight: CGFloat = 46
    /// 底栏 = 角色横排 48 + 球库两行 68（G12 后无解摘要行）。
    private static let bottomBarHeight: CGFloat = 116

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
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSpinPad)
        .btToast($toast)
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
                applyUITestHooksIfNeeded()
            }
        }
    }

    /// UITest 确定性场景注入（Q15 截图取证）；生产无对应 launch arg ⇒ 不触发。
    private func applyUITestHooksIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        for s in ["twoBallDimmed", "twoBall", "oneBall", "cleared"] where args.contains("-planThree.\(s)") {
            vm.uiTestConfigure(s)
            return
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
                Text(vm.breakRunner?.statusText ?? vm.statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
        }
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

            // Q15.3：清除键正常尺寸、紧贴「摆球」chip 右侧（不再是行末小图标）。
            BTEraserButton(isEnabled: !vm.isPlaying && vm.hasConstraint) { vm.clearConstraint() }

            Spacer(minLength: 0)
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11 走 ShotStageProxy）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer
            if vm.activeTool != .none { drawingOverlay }

            // G18/V6：开球模式贴边仪表（左瞄准轮 + 右力度柱），共享单一真源。
            if let runner = vm.breakRunner {
                BreakInstrumentsOverlay(runner: runner, proxy: proxy)
            }

            if !vm.isBreakMode && proxy.isValid {
                // G3 轨迹档位 chip：下沿贴球桌上沿、靠屏幕最右。
                BTTrajectoryDetailChip { vm.redrawTrajectory() }
                    .btChipBandPlacement(proxy)
                    .allowsHitTesting(!vm.isPlaying)

                // 左下（条 21.3 + G6）：求解/下一解叠在开球按钮上方，右缘贴球桌左缘、底边齐球桌底线。
                leftColumn
                    .btStageFrame(proxy.bottomLeadingFrame(size: Self.leftColumnSize))

                // G4/G5/G7 打点+力度仪表柱：左缘贴球桌右侧、力度条本体底部对齐。
                instrumentColumn
                    .btStageFrame(proxy.instrumentFrame())

                // 条 18.2：打一/上一杆/回放，右下角底边齐球桌底线。
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
        AngleSceneView(
            scene: vm.scene,
            cameraMode: $vm.cameraMode,
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            onPocketTapped: { if !vm.isBreakMode { vm.selectPocket(at: $0) } },
            // 开球模式：仅母球可拖（限开球区），其余台面交互挂起。
            draggableBallNodes: vm.breakRunner?.draggableCue
                ?? (vm.activeTool == .none ? vm.draggableBalls : []),
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
            selectableBallNodes: (vm.isBreakMode || vm.activeTool != .none) ? [] : vm.selectableBalls,
            onBallTapped: { vm.selectBall(node: $0) },
            // G18/V6：开球模式拖屏调瞄准（G13 相对语义）；非开球模式本页无自由拖瞄，忽略。
            onAimNudged: { if let runner = vm.breakRunner { runner.nudgeAim(byDegrees: $0) } },
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

    // MARK: - Role row (Z6, above palette — T-P18-49)

    /// 角色选择横排（球1→袋→球2→袋→球3 + 清空）：从右侧竖排移入 Z6
    /// 球库行上方，台面恢复全宽。
    private var roleRow: some View {
        HStack(spacing: 6) {
            ForEach(PlanThreeRole.order, id: \.rawValue) { role in
                roleChip(role)
            }
            Button { vm.clearPlan() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 34, height: 40)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(vm.isPlaying)
            .accessibilityLabel("清空计划")
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
    }

    private func roleChip(_ role: PlanThreeRole) -> some View {
        let armed = vm.armedRole == role
        let filled = vm.isFilled(role)
        let accent = roleColor(role)
        return Button { vm.armRole(role) } label: {
            HStack(spacing: 4) {
                Text(roleTitle(role))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                roleContent(role, filled: filled, accent: accent)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(armed ? accent.opacity(0.18) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(armed ? accent : accent.opacity(filled ? 0.5 : 0.22),
                            style: StrokeStyle(lineWidth: armed ? 2 : 1, dash: filled ? [] : [4, 3]))
            )
            .scaleEffect(armed ? 1.03 : 1)
            .animation(BTMotion.springPanel, value: armed)
        }
        .buttonStyle(.plain)
        .disabled(vm.isPlaying)
    }

    @ViewBuilder
    private func roleContent(_ role: PlanThreeRole, filled: Bool, accent: Color) -> some View {
        if role.isBall {
            if let key = vm.ballKey(for: role) {
                PoolBallFace(key: key, diameter: 22)
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.5))
            } else {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.55))
            }
        } else {
            Image(systemName: filled ? "scope" : "circle.dashed")
                .font(.system(size: 15, weight: filled ? .bold : .semibold))
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
            BTBreakSideButton(isEnabled: !vm.isPlaying && !vm.isComputing) {
                showBreakPicker = true
            }
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
            strikeTitle: vm.isPlaying ? "击球中" : "打一",
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

    // MARK: - Bottom bar（G12：删除解摘要行；底部 = 角色横排 + 球库）

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        Group {
            if let runner = vm.breakRunner {
                BreakControlBar(runner: runner, onCancel: { vm.cancelBreakFlow() })
            } else {
                VStack(spacing: 0) {
                    roleRow
                    paletteBar(proxy)
                }
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

    private func flash(_ message: String, tone: BTToastTone = .success) {
        withAnimation(BTMotion.easeChrome) {
            toast = BTToastMessage(message, tone: tone)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + BTToast.defaultDuration) {
            withAnimation(BTMotion.easeChrome) {
                if toast?.text == message { toast = nil }
            }
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
