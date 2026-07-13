//
//  BatchAuthoringView.swift
//  QiuJi
//
//  批量出片台 · 编排求解二合一（仅模拟器，内容生产工具）。
//
//  把「走位编排台」（摆球 + 手动设打点/力度 + 连续击打 + 录制成序列）与「思路训练器」
//  （画落区/落点反解出打点与力度）合到一页：
//  - 引擎复用 `PositionPlayViewModel`（已验证的录制状态机：摆球→击球→桌面前进→记一杆）；
//  - 反解复用 `PositionPlaySolver`（思路训练器同一求解器）：画约束 → 求出最优解 →
//    把解的塞/力度写回编排引擎的参数（target/pocket 已选中），再由「击球」记入序列。
//  默认「求解」（落区工具激活），可切「摆球」调整导入球形（拖球 / 球库增删）+ 手动设打点
//  力度；序列按 **drill_cNNN** 稳定键直写内容库，供 `make position-export` 出片并接入精讲页。
//

#if targetEnvironment(simulator)
import SwiftUI
import SceneKit

// MARK: - 反解层（在编排引擎之上叠加思路训练器的约束求解）

/// 操作传入的 `PositionPlayViewModel` 与其场景：画约束 → 反解 → 把最优解写回编排参数。
@MainActor
final class BatchShotSolver: ObservableObject {

    /// 摆球（arrange）= 调整球形（拖球 / 球库增删）+ 手动设打点力度；
    /// 自由（free）= 不选目标球/袋口，点桌面/球/袋口直瞄母球方向（安全球 / 解球 / 纯走位）；
    /// 其余为反解约束工具。
    enum Tool: Equatable { case arrange, free, region, restPoint, passPoint }

    @Published var activeTool: Tool = .region
    @Published var regionShape: SiluTrainerViewModel.RegionShape = .rect
    @Published var allowSideSpin = true
    @Published var basicPositionOnly = false
    @Published private(set) var hasConstraint = false
    @Published private(set) var isComputing = false
    @Published private(set) var solutions: [PositionPlaySolution] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var statusText =
        "默认求解：画落区/落点后点「求解」；或切「摆球」调整球形 + 手动设打点力度"

    /// 反解约束工具（落区/落点/过点）才覆盖绘制层并禁拖球；摆球不属此列。
    var isSolvingTool: Bool {
        activeTool == .region || activeTool == .restPoint || activeTool == .passPoint
    }

    var pointTolerance: Double = 0.02
    var passVMin: Double = 0.3

    private var draft: SiluTrainerViewModel.Draft?
    private var constraintNodes: [SCNNode] = []
    private let solveQueue = DispatchQueue(label: "com.qiuji.batch-solve", qos: .userInitiated)
    private var solveGeneration = 0

    var currentSolution: PositionPlaySolution? {
        solutions.indices.contains(currentIndex) ? solutions[currentIndex] : nil
    }
    var hasSolutions: Bool { !solutions.isEmpty }

    // MARK: 击球后/换杆：清掉上一杆的约束与解

    func resetForNextShot(scene: AngleTrainingScene) {
        draft = nil
        hasConstraint = false
        solutions = []
        currentIndex = 0
        clearConstraintNodes(scene: scene)
        if isSolvingTool {
            statusText = toolHint()
        }
    }

    // MARK: 约束绘制（归一化系）

    func toolDrag(start: CanvasPoint, current: CanvasPoint, ended: Bool,
                  scene: AngleTrainingScene, surfaceY: Float) {
        switch activeTool {
        case .arrange, .free:
            return
        case .passPoint:
            draft = .passPoint(current)
        case .restPoint:
            draft = .restPoint(current)
        case .region:
            switch regionShape {
            case .rect:
                let cx = (start.x + current.x) / 2, cy = (start.y + current.y) / 2
                let hw = max(0.01, abs(current.x - start.x) / 2)
                let hh = max(0.005, abs(current.y - start.y) / 2)
                draft = .region(.rect(center: CanvasPoint(x: cx, y: cy), halfWidth: hw, halfHeight: hh))
            case .circle:
                let dx = current.x - start.x, dy = current.y - start.y
                let r = max(0.01, (dx * dx + dy * dy).squareRoot())
                draft = .region(.circle(center: start, radius: r))
            }
        }
        hasConstraint = draft != nil
        renderConstraint(scene: scene, surfaceY: surfaceY)
        if ended, currentConstraint() != nil { statusText = "已就绪，点「求解」反解走位" }
    }

    func clearConstraint(scene: AngleTrainingScene) {
        draft = nil
        hasConstraint = false
        solutions = []
        currentIndex = 0
        clearConstraintNodes(scene: scene)
        statusText = toolHint()
    }

    private func currentConstraint() -> SolveConstraint? {
        switch draft {
        case .region(let r): return .restRegion(r)
        case .restPoint(let p): return .restRegion(.point(center: p, tolerance: pointTolerance))
        case .passPoint(let p): return .passThrough(point: p, vMin: passVMin)
        case nil: return nil
        }
    }

    // MARK: 反解（后台），结果把最优解的塞/力度写回编排引擎

    func solve(composer: PositionPlayViewModel, apply: @escaping (PlannedShot) -> Void) {
        guard let targetKey = composer.selectedTargetKey,
              composer.selectedPocketIndex >= 0,
              let pocketId = ShotIntent.pocketId(for: composer.selectedPocketIndex),
              let constraint = currentConstraint() else {
            statusText = "请先选目标球 + 袋口，并画一个约束"
            return
        }
        let before = composer.currentSnapshot()
        let y = composer.scene.surfaceY
        let params = searchParams(for: constraint)
        solveGeneration += 1
        let gen = solveGeneration
        isComputing = true
        statusText = "求解中…"

        solveQueue.async { [weak self] in
            let result = PositionPlaySolver.solve(
                before: before, targetKey: targetKey, pocket: pocketId,
                constraint: constraint, surfaceY: y, params: params)
            DispatchQueue.main.async {
                guard let self, self.solveGeneration == gen else { return }
                self.isComputing = false
                self.solutions = result
                self.currentIndex = 0
                if let best = result.first {
                    self.statusText = self.solutionStatus(best)
                    apply(best.shot)
                } else {
                    self.statusText = "未找到解（放大落区或换目标袋口）"
                }
            }
        }
    }

    func nextSolution(apply: (PlannedShot) -> Void) {
        guard !solutions.isEmpty else { return }
        currentIndex = (currentIndex + 1) % solutions.count
        let sol = solutions[currentIndex]
        statusText = solutionStatus(sol)
        apply(sol.shot)
    }

    private func searchParams(for constraint: SolveConstraint) -> PositionPlaySolver.SearchParams {
        var params: PositionPlaySolver.SearchParams
        switch constraint {
        case .restRegion: params = .standard
        case .passThrough: params = .passThrough
        }
        if !allowSideSpin { params.spinXValues = [0] }
        params.maxCushions = basicPositionOnly ? 1 : nil
        return params
    }

    private func solutionStatus(_ sol: PositionPlaySolution) -> String {
        let prefix = solutions.count > 1 ? "解 \(currentIndex + 1)/\(solutions.count) · " : ""
        let advanced = sol.beyondCushionBudget ? "进阶 · " : ""
        if !sol.satisfiesConstraint { return prefix + advanced + "最接近解 · " + sol.summary }
        return prefix + advanced + sol.summary
    }

    func toolHint() -> String {
        switch activeTool {
        case .arrange: return "摆球：拖动球调位 / 球库拖入增球、拖回删球；下方设打点 + 力度点「击球」"
        case .free: return "自由瞄：点桌面 / 球 / 袋口设定母球方向，下方设打点 + 力度点「击球」（不进球的安全球 / 走位）"
        case .region: return "在球桌上拖出\(regionShape.rawValue)可行落区，点「求解」"
        case .restPoint: return "点按球桌标出母球期望停的落点，点「求解」"
        case .passPoint: return "点按球桌标出母球需经过的 K 球点，点「求解」"
        }
    }

    // MARK: 约束渲染（青色落区 / 琥珀落点 / 青色过点十字）

    private func renderConstraint(scene: AngleTrainingScene, surfaceY: Float) {
        clearConstraintNodes(scene: scene)
        let cyan = UIColor(red: 0.2, green: 0.85, blue: 0.95, alpha: 0.95)
        let amber = UIColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 0.95)
        let y = surfaceY + 0.002
        switch draft {
        case .region(let region):
            switch region {
            case let .circle(center, radius):
                strokeCircle(center: scenePoint(center, y: y), radius: Float(radius) * SolveRegion.sceneScale,
                             color: cyan, scene: scene)
            case let .rect(center, hw, hh):
                strokeRect(center: scenePoint(center, y: y),
                           halfX: Float(hw) * SolveRegion.sceneScale,
                           halfZ: Float(hh) * SolveRegion.sceneScale, color: cyan, scene: scene)
            case let .point(center, tol):
                strokeCircle(center: scenePoint(center, y: y), radius: Float(tol) * SolveRegion.sceneScale,
                             color: cyan, scene: scene)
            case .sector:
                // 批量台 draft 不进 sector；穷尽分支。
                break
            }
        case .restPoint(let pt):
            let c = scenePoint(pt, y: y)
            strokeCircle(center: c, radius: Float(pointTolerance) * SolveRegion.sceneScale, color: amber, scene: scene)
            strokeCross(center: c, arm: AngleSceneCalculator.ballRadius * 1.4, color: amber, scene: scene)
        case .passPoint(let pt):
            let c = scenePoint(pt, y: y)
            strokeCircle(center: c, radius: AngleSceneCalculator.ballRadius, color: cyan, scene: scene)
            strokeCross(center: c, arm: AngleSceneCalculator.ballRadius * 1.6, color: cyan, scene: scene)
        case nil:
            break
        }
    }

    private func scenePoint(_ p: CanvasPoint, y: Float) -> SCNVector3 {
        AngleSceneCalculator.normalizedToScene(point: CGPoint(x: p.x, y: p.y), surfaceY: y)
    }

    private func strokeCircle(center: SCNVector3, radius: Float, color: UIColor, scene: AngleTrainingScene) {
        let segments = 36
        var prev: SCNVector3?
        for i in 0...segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            let p = SCNVector3(center.x + radius * cosf(a), center.y, center.z + radius * sinf(a))
            if let pr = prev { constraintNodes.append(scene.addLine(from: pr, to: p, color: color, radius: 0.0022)) }
            prev = p
        }
    }

    private func strokeRect(center c: SCNVector3, halfX: Float, halfZ: Float, color: UIColor, scene: AngleTrainingScene) {
        let corners = [
            SCNVector3(c.x - halfX, c.y, c.z - halfZ), SCNVector3(c.x + halfX, c.y, c.z - halfZ),
            SCNVector3(c.x + halfX, c.y, c.z + halfZ), SCNVector3(c.x - halfX, c.y, c.z + halfZ)
        ]
        for i in 0..<4 {
            constraintNodes.append(scene.addLine(from: corners[i], to: corners[(i + 1) % 4], color: color, radius: 0.0022))
        }
    }

    private func strokeCross(center c: SCNVector3, arm r: Float, color: UIColor, scene: AngleTrainingScene) {
        constraintNodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                             to: SCNVector3(c.x + r, c.y, c.z), color: color, radius: 0.0024))
        constraintNodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                             to: SCNVector3(c.x, c.y, c.z + r), color: color, radius: 0.0024))
    }

    private func clearConstraintNodes(scene: AngleTrainingScene) {
        scene.clearResultNodes(nodes: &constraintNodes)
    }
}

// MARK: - 编排求解二合一视图

struct BatchAuthoringView: View {
    @ObservedObject var context: BatchAuthoringContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var composer = PositionPlayViewModel()
    @StateObject private var solver = BatchShotSolver()

    @State private var hasAppeared = false
    @State private var showSpinPad = false
    @State private var projector = TableProjector()

    @State private var draggingKey: String?
    @State private var dragLocation: CGPoint = .zero
    @State private var dragOverTable = false
    @State private var sceneFrame: CGRect = .zero
    @State private var paletteFrame: CGRect = .zero
    @State private var banner: String?

    // 点换（条 20.3）：激活后点桌上另一颗球，与母球交换位置。
    @State private var swapMode = false

    // 辅助线（条 20.4–20.9）：两步确认起/终点，±10° 吸附水平/垂直，白色；
    // 在线上的球自动均分；不进 JSON（仅场景节点）；击球时隐藏。
    @StateObject private var guide = BatchGuideLine()

    private static let paletteColumns = 8
    /// G10：顶栏 / 底栏固定高度 ⇒ scene 区域高度恒定 ⇒ 球桌渲染尺寸锁定。
    /// 顶部工具行含条件性的求解状态行，取两行高度上限常显。
    private static let topRowHeight: CGFloat = 72
    /// 底栏 = 保存横排 33 + 球库两行 68。
    private static let bottomBarHeight: CGFloat = 101

    private var drill: BatchDrill? { context.current }

    var body: some View {
        GeometryReader { geo in
            let extents = composer.tableOuterHalfExtents
            let sceneH = max(geo.size.height - Self.topRowHeight - Self.bottomBarHeight, 1)
            let proxy = ShotStageProxy(
                sceneSize: CGSize(width: geo.size.width, height: sceneH),
                halfLength: extents.length, halfWidth: extents.width
            )
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    solverToolRow
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
        .coordinateSpace(name: "batchAuthor")
        .onPreferenceChange(BatchAuthorFramePreference.self) { frames in
            if let s = frames["scene"] { sceneFrame = s }
            if let p = frames["palette"] { paletteFrame = p }
        }
        .navigationTitle(drill.map { "编排求解 · \($0.drillId)" } ?? "编排求解")
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
                composer.setupScene()
                if let editing = context.editingSequence {
                    // 存档 + 在原有基础上修改：用当前引擎重放重建，跳过拍照建球形。
                    let result = composer.loadSequenceForEditing(editing)
                    context.editingSequence = nil
                    if result.replayed < result.total {
                        flash("已重放 \(result.replayed)/\(result.total) 杆 · 第 \(result.replayed + 1) 杆在新物理下不可行，从此处修")
                    } else {
                        flash("存档已载入 · \(result.total) 杆（末杆可「重打」重编）")
                    }
                } else {
                    if let board = context.confirmedBoard { composer.loadBoard(board) }
                    if let drill {
                        composer.renameSequence(
                            context.defaultSequenceName(for: drill, imageURL: context.sourceImageURL))
                    }
                    composer.startRecording()
                }
            }
        }
    }

    // MARK: - Nav status

    private var navStatus: some View {
        VStack(spacing: 1) {
            Text(drill?.drillId ?? "编排求解")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.btPrimary)
                .lineLimit(1)
            Text(composer.isComputing ? "求解中…" : composer.statusText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
        }
    }

    // MARK: - Solver tool row

    private var solverToolRow: some View {
        VStack(spacing: 4) {
            HStack(spacing: Spacing.sm) {
                BTChipRow(
                    options: ["落区", "落点", "过点", "摆球", "自由"],
                    selection: Binding(
                        get: {
                            switch solver.activeTool {
                            case .region: return 0
                            case .restPoint: return 1
                            case .passPoint: return 2
                            case .arrange: return 3
                            case .free: return 4
                            }
                        },
                        set: {
                            switch $0 {
                            case 0: solver.activeTool = .region
                            case 1: solver.activeTool = .restPoint
                            case 2: solver.activeTool = .passPoint
                            case 3: solver.activeTool = .arrange
                            default: solver.activeTool = .free
                            }
                            // 自由 → 母球直瞄方向；其余（摆球 / 反解约束）→ 袋口模式。
                            composer.aimMode = solver.activeTool == .free ? .free : .pocket
                            solver.clearConstraint(scene: composer.scene)
                        }
                    ),
                    scrollable: true
                )
                .disabled(composer.isPlaying)

                if solver.activeTool == .region {
                    BTChipRow(
                        options: SiluTrainerViewModel.RegionShape.allCases.map { $0.rawValue },
                        selection: Binding(
                            get: { solver.regionShape == .rect ? 0 : 1 },
                            set: { solver.regionShape = $0 == 0 ? .rect : .circle }
                        ),
                        scrollable: false
                    )
                    .disabled(composer.isPlaying)
                }

                Spacer(minLength: 0)

                Button { solver.clearConstraint(scene: composer.scene) } label: {
                    Image(systemName: "eraser")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(solver.hasConstraint ? 0.8 : 0.3))
                }
                .disabled(composer.isPlaying || !solver.hasConstraint)
            }

            if solver.isSolvingTool {
                HStack(spacing: 8) {
                    Text(solver.statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if solver.isComputing { ProgressView().controlSize(.mini).tint(.white) }
                    Button { solver.nextSolution(apply: applyShot) } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(solver.solutions.count > 1 ? 0.9 : 0.3))
                    }
                    .disabled(composer.isPlaying || solver.solutions.count < 2)
                    Button { solver.solve(composer: composer, apply: applyShot) } label: {
                        Text("求解")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(height: 28)
                            .background(solver.hasConstraint ? Color.btAccent : Color.btAccent.opacity(0.3),
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(composer.isPlaying || solver.isComputing || !solver.hasConstraint)
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }

    /// 把反解出的解写回编排引擎（target/pocket 已选中，只需设塞与力度）。
    private func applyShot(_ shot: PlannedShot) {
        composer.aimMode = .pocket
        composer.velocity = shot.velocity
        composer.spinX = shot.spinX
        composer.spinY = shot.spinY
    }

    // MARK: - Stage（scene + 贴边控件，G3–G11 走 ShotStageProxy）

    private func stage(_ proxy: ShotStageProxy) -> some View {
        ZStack(alignment: .topLeading) {
            sceneContainer
            if solver.isSolvingTool { drawingOverlay }
            if guide.isPicking { guideOverlay }

            if proxy.isValid {
                // G3 轨迹档位 chip：下沿贴球桌上沿、靠屏幕最右。
                BTTrajectoryDetailChip { composer.recompute() }
                    .btChipBandPlacement(proxy)
                    .allowsHitTesting(!composer.isPlaying)

                // 条 20.1/20.5 左柱：辅助线按钮（刻度轮/开球上方）+ 刻度轮（自由）+ 开球禁用态。
                if composer.aimMode == .free {
                    BTAimWheel(onNudge: { composer.nudgeFreeAim(byDegrees: $0) })
                        .btStageFrame(proxy.aimWheelFrame())
                        .allowsHitTesting(!composer.isPlaying)
                }
                BTTextActionButton(title: guide.phase == .off ? "辅助线" : "清除线",
                                   isDisabled: composer.isPlaying, width: 46) {
                    guideButtonTapped()
                }
                .btStageFrame(guideButtonRect(proxy))

                BTBreakSideButton(isEnabled: false) {}
                    .btStageFrame(proxy.breakButtonFrame())

                // 右柱：点换（仪表柱上方）+ 打点/力度柱 + 击球/上一杆/回放列。
                BTTextActionButton(title: "点换",
                                   role: swapMode ? .primary : .plain,
                                   isDisabled: composer.isPlaying, width: 46) {
                    toggleSwapMode()
                }
                .btStageFrame(swapButtonRect(proxy))

                BTShotInstrumentColumn(
                    spinX: composer.spinX, spinY: composer.spinY,
                    onSpinTap: { showSpinPad = true },
                    velocity: $composer.velocity,
                    range: ShotTuning.velocityRange,
                    isDisabled: composer.isPlaying
                )
                .btStageFrame(proxy.instrumentFrame())

                BTShotActionColumn(
                    strikeTitle: composer.isPlaying ? "击球中" : "击球",
                    strikeEnabled: strikeEnabled,
                    onStrike: { strike() },
                    undoEnabled: !composer.isPlaying && composer.canReplay,
                    onUndo: { composer.replayCurrent() },
                    playbackEnabled: !composer.isPlaying && composer.canPlayback,
                    onPlayback: { composer.replayLastShot() }
                )
                .btStageFrame(proxy.actionColumnFrame())
            }

            if showSpinPad {
                BTSpinPadOverlay(spinX: $composer.spinX, spinY: $composer.spinY,
                                 onClose: { showSpinPad = false })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    /// 辅助线按钮：贴左缘、位于刻度轮（自由模式）或开球按钮上方 8pt。
    private func guideButtonRect(_ proxy: ShotStageProxy) -> CGRect {
        let above = composer.aimMode == .free
            ? proxy.aimWheelFrame().minY : proxy.breakButtonFrame().minY
        return CGRect(x: proxy.tableRect.minX - 46, y: above - 8 - 30, width: 46, height: 30)
    }

    /// 点换按钮：贴右缘、位于仪表柱上方 8pt。
    private func swapButtonRect(_ proxy: ShotStageProxy) -> CGRect {
        CGRect(x: proxy.tableRect.maxX, y: proxy.instrumentFrame().minY - 8 - 30,
               width: 46, height: 30)
    }

    // MARK: - Scene

    private var sceneContainer: some View {
        AngleSceneView(
            scene: composer.scene,
            cameraMode: $composer.cameraMode,
            interactionMode: .tapsOnly,
            autoFitsRotatedTable: true,
            onPocketTapped: { composer.selectPocket(at: $0) },
            draggableBallNodes: solver.activeTool == .arrange ? composer.draggableBalls : [],
            onDragBegan: { composer.dragBegan(node: $0) },
            onDragMoved: { composer.dragMoved(node: $0, worldPosition: $1) },
            onDragEnded: { node in
                composer.dragEnded(node: node)
                redistributeGuideBalls()   // 拖球落在辅助线上 → 自动均分（条 20.6）
            },
            onDragEndedAt: { node, localPoint in handleTableDragEnd(node: node, localPoint: localPoint) },
            selectableBallNodes: composer.selectableBalls,
            onBallTapped: { handleBallTapped($0) },
            onTableTapped: { composer.handleTableTap(world: $0) },
            onAimNudged: { composer.nudgeFreeAim(byDegrees: $0) },
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
                DragGesture(minimumDistance: 0, coordinateSpace: .named("batchAuthor"))
                    .onChanged { handleDraw(start: $0.startLocation, current: $0.location, ended: false) }
                    .onEnded { handleDraw(start: $0.startLocation, current: $0.location, ended: true) }
            )
    }

    private func handleDraw(start: CGPoint, current: CGPoint, ended: Bool) {
        guard sceneFrame != .zero,
              let s = normalized(start), let c = normalized(current) else { return }
        solver.toolDrag(start: s, current: c, ended: ended,
                        scene: composer.scene, surfaceY: composer.scene.surfaceY)
    }

    private func normalized(_ point: CGPoint) -> CanvasPoint? {
        let local = CGPoint(x: point.x - sceneFrame.minX, y: point.y - sceneFrame.minY)
        guard let world = projector.unproject?(local) else { return nil }
        let n = AngleSceneCalculator.sceneToNormalized(position: world)
        return CanvasPoint(x: Double(n.x), y: Double(n.y))
    }

    // MARK: - Bottom bar（条 20.2：原球库右侧按键上移，两排球上方一字排开）

    private func bottomBar(_ proxy: ShotStageProxy) -> some View {
        VStack(spacing: 4) {
            saveRow
            paletteBar(proxy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.11))
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    /// 保存/序列操作横排（条 20.2）：杆数 + 回上一杆球形 + 两个保存去向。
    private var saveRow: some View {
        HStack(spacing: 8) {
            Text("\(composer.stepCount) 杆")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 56, height: 28)
                .background(.white.opacity(0.08), in: Capsule())

            Button { composer.restorePreviousBoard() } label: {
                actionPill(title: "回上一杆球形", system: "clock.arrow.circlepath",
                           tint: .white.opacity(0.14))
            }
            .buttonStyle(.plain)
            .disabled(composer.isPlaying || !composer.canReplay)

            Spacer(minLength: 0)

            Button { save(mode: .stay) } label: {
                actionPill(title: "保存·选下张图", system: "square.and.arrow.down",
                           tint: .white.opacity(0.16))
            }
            .buttonStyle(.plain)
            .disabled(composer.isPlaying)

            Button { save(mode: .nextDrill) } label: {
                actionPill(title: "保存·下个drill", system: "arrow.right.circle", tint: Color.btAccent)
            }
            .buttonStyle(.plain)
            .disabled(composer.isPlaying)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, 5)
    }

    private func actionPill(title: String, system: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: system).font(.system(size: 12, weight: .bold))
            Text(title).font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(tint, in: Capsule())
    }

    private var strikeEnabled: Bool {
        !composer.isPlaying && !composer.isComputing && composer.isFeasible
    }

    // MARK: - 点换（条 20.3）

    private func toggleSwapMode() {
        swapMode.toggle()
        if swapMode {
            guard composer.onTableKeys.contains(PositionPlayBall.cueKey) else {
                swapMode = false
                flash("桌面无母球，无法点换")
                return
            }
            flash("点换：点击桌上另一颗球，与母球交换位置")
        }
    }

    /// 点球分流：点换模式 = 与母球交换位置；其余 = 原目标球选择。
    private func handleBallTapped(_ node: SCNNode) {
        if swapMode {
            performSwap(node)
        } else {
            composer.selectTarget(node: node)
        }
    }

    private func performSwap(_ node: SCNNode) {
        swapMode = false
        guard let key = composer.scene.ballKey(for: node),
              key != PositionPlayBall.cueKey,
              let cue = composer.scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else {
            flash("请点击桌上一颗非母球")
            return
        }
        let cuePos = cue.position
        cue.position = node.position
        node.position = cuePos
        composer.recompute()
        flash("已交换母球与 \(PositionPlayBall.shortLabel(for: key)) 的位置")
    }

    // MARK: - 辅助线（条 20.4–20.9）

    private func guideButtonTapped() {
        if guide.phase == .off {
            guide.begin()
        } else {
            guide.clear(scene: composer.scene)
        }
    }

    /// 辅助线取点覆盖层：拖/点选起点或终点（世界坐标经 projector 反投影）。
    private var guideOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("batchAuthor"))
                    .onChanged { setGuidePoint(at: $0.location) }
                    .onEnded { setGuidePoint(at: $0.location) }
            )
            .overlay(alignment: .top) { guideControls }
    }

    private func setGuidePoint(at location: CGPoint) {
        guard sceneFrame != .zero else { return }
        let local = CGPoint(x: location.x - sceneFrame.minX, y: location.y - sceneFrame.minY)
        guard let world = projector.unproject?(local) else { return }
        guide.setPoint(world, scene: composer.scene)
    }

    /// 辅助线阶段提示 + 确认/取消（两步确认，条 20.5）。
    private var guideControls: some View {
        HStack(spacing: Spacing.sm) {
            if let hint = guide.hint {
                Text(hint)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            Button {
                if guide.confirm(scene: composer.scene) {
                    redistributeGuideBalls()
                }
            } label: {
                Text("确认")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(height: 26)
                    .background(guide.hasCurrentPoint ? Color.btPrimary : Color.btPrimary.opacity(0.3),
                                in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!guide.hasCurrentPoint)
            Button {
                guide.clear(scene: composer.scene)
            } label: {
                Text("取消")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 12).frame(height: 26)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 6)
        .btHudGlass()
        .padding(.top, Spacing.sm)
    }

    /// 均分摆球（条 20.6）：把落在辅助线上的球调整到均分位置（1 球中点、2 球 1/3 与 2/3，
    /// 端点不放球），然后触发重算。
    private func redistributeGuideBalls() {
        if guide.redistribute(keys: composer.onTableKeys, scene: composer.scene) {
            composer.recompute()
            flash("在线球已均分排布")
        }
    }

    /// 击球：消费编排引擎的当前解推演并记一杆；完成后清掉本杆约束/解，准备下一杆。
    /// 辅助线在击球时隐藏（条 20.8）。
    private func strike() {
        guide.clear(scene: composer.scene)
        composer.play()
        // 击球后桌面前进、自动选下一杆（由 composer 处理）；清掉求解层上一杆约束。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            solver.resetForNextShot(scene: composer.scene)
        }
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
        let onTable = composer.onTableKeys.contains(key)
        return PoolBallFace(key: key, diameter: 30)
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .opacity(draggingKey == key ? 0.3 : (onTable ? 0.3 : 1))
            .onTapGesture {
                if onTable { composer.pulseTableBall(key) } else { composer.placeFromPalette(key) }
            }
            .gesture(paletteDrag(key), including: onTable ? .subviews : .all)
    }

    private func paletteDrag(_ key: String) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named("batchAuthor"))
            .onChanged { value in
                guard !composer.isPlaying else { return }
                draggingKey = key
                dragLocation = value.location
                dragOverTable = sceneFrame.contains(value.location)
            }
            .onEnded { value in
                let loc = value.location
                defer { draggingKey = nil; dragOverTable = false }
                guard !composer.isPlaying, sceneFrame.contains(loc) else { return }
                let local = CGPoint(x: loc.x - sceneFrame.minX, y: loc.y - sceneFrame.minY)
                if let world = projector.unproject?(local) {
                    composer.placeFromPalette(key, atWorld: world)
                } else {
                    composer.placeFromPalette(key)
                }
                redistributeGuideBalls()   // 新球落在辅助线上 → 自动均分（条 20.6）
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
        guard paletteFrame.contains(p), let key = composer.scene.ballKey(for: node) else { return }
        composer.removeFromTable(key)
        flash("已移回球库")
    }

    // MARK: - More menu

    private var moreMenu: some View {
        Menu {
            Section("求解范围") {
                Toggle("允许左右塞", isOn: $solver.allowSideSpin)
                Toggle("仅基础走位（≤1 库）", isOn: $solver.basicPositionOnly)
            }
            Section {
                Button("重打", systemImage: "arrow.uturn.backward") { composer.replayCurrent() }
                    .disabled(!composer.canReplay)
            }
            Section("显示") {
                BTTableGridMenuToggle(scene: composer.scene)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Save / advance

    /// 保存后的去向：`stay` 留在本 drill 回选图栅格挑下一张图（= 下一个球形）；
    /// `nextDrill` 跳到下一个还没有任何球形的 drill。
    private enum SaveMode { case stay, nextDrill }

    private func save(mode: SaveMode) {
        guard let drill = context.current else { return }
        var seq = composer.sequence
        guard !seq.steps.isEmpty else {
            flash("尚无击打：先「击球」记录至少一杆")
            return
        }
        let imageURL = context.sourceImageURL
        // 球形 token 绑定来源截图：同图覆盖、异图并存（无来源时退回 drillId 单键）。
        let stem = imageURL?.deletingPathExtension().lastPathComponent ?? drill.drillId
        // 旧版存档编辑：保留原序列名（未绑定截图，defaultSequenceName 的「球形K」不适用）。
        if !context.editingLegacyArchive {
            seq.name = context.defaultSequenceName(for: drill, imageURL: imageURL)
        }
        seq.updatedAt = Date()
        do {
            _ = try BatchSequenceArchive.archive(seq, drillId: drill.drillId, imageStem: stem,
                                                 legacy: context.editingLegacyArchive)
            context.editingLegacyArchive = false
            context.refreshSaved()
            switch mode {
            case .stay:
                // 回拍照建球形选图栅格（同 drill），已存图打勾，自由挑下一张或跳过。
                context.confirmedBoard = nil
                context.sourceImageURL = nil
                context.pickerResetToken = UUID()
                dismiss()
            case .nextDrill:
                if context.advanceToNextUnsaved() {
                    dismiss()   // drillId 变 → 拍照页 onChange 重置到下一 drill 的选图
                } else {
                    flash("全部 drill 均已开工（≥1 球形）🎉")
                }
            }
        } catch {
            flash("保存失败：\(error.localizedDescription)")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { banner = nil }
        }
    }

    private func frameReader(id: String) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: BatchAuthorFramePreference.self,
                                   value: [id: geo.frame(in: .named("batchAuthor"))])
        }
    }
}

// MARK: - 辅助线（条 20.4–20.9）

/// 出片台辅助线状态机：起点/终点两步确认；终点与水平/垂直夹角 < 10° 自动吸附
/// （SceneKit X–Z 台面系：吸附 = 对齐 X 轴向或 Z 轴向）；白色；只存在于场景节点
/// （不进 JSON）；击球时由宿主 `clear` 隐藏。
@MainActor
final class BatchGuideLine: ObservableObject {
    enum Phase: Equatable { case off, pickStart, pickEnd, placed }

    @Published private(set) var phase: Phase = .off
    // P12.1：必须 @Published——「确认」按钮 enabled 依赖 `hasCurrentPoint`，
    // 选点只改这两个属性不改 phase，非 @Published 时视图不重渲、按钮永远禁用。
    @Published private(set) var startPoint: SCNVector3?
    @Published private(set) var endPoint: SCNVector3?
    private var nodes: [SCNNode] = []

    /// 吸附阈值（度）：与水平/垂直夹角小于该值时归为轴向线（条 20.4）。
    static let snapDeg: Float = 10

    var isPicking: Bool { phase == .pickStart || phase == .pickEnd }

    /// 当前阶段是否已有可确认的点。
    var hasCurrentPoint: Bool {
        switch phase {
        case .pickStart: return startPoint != nil
        case .pickEnd: return endPoint != nil
        default: return false
        }
    }

    var hint: String? {
        switch phase {
        case .off, .placed: return nil
        case .pickStart: return startPoint == nil ? "点按球桌选起点" : "可拖动微调起点"
        case .pickEnd: return endPoint == nil ? "点按球桌选终点" : "±10° 自动吸附水平/垂直"
        }
    }

    func begin() {
        startPoint = nil
        endPoint = nil
        phase = .pickStart
    }

    /// 取点（世界坐标）：pickStart 设起点，pickEnd 设终点（带轴向吸附）。
    func setPoint(_ world: SCNVector3, scene: AngleTrainingScene) {
        let y = scene.surfaceY + 0.003
        let p = SCNVector3(world.x, y, world.z)
        switch phase {
        case .pickStart:
            startPoint = p
        case .pickEnd:
            guard let a = startPoint else { return }
            endPoint = snapped(end: p, from: a)
        default:
            return
        }
        render(scene: scene)
    }

    /// 确认当前点：起点 → 进入终点阶段；终点 → 定线。返回 true = 辅助线已就位
    /// （宿主随即做一次均分摆球）。
    @discardableResult
    func confirm(scene: AngleTrainingScene) -> Bool {
        switch phase {
        case .pickStart where startPoint != nil:
            phase = .pickEnd
            return false
        case .pickEnd where endPoint != nil:
            phase = .placed
            render(scene: scene)
            return true
        default:
            return false
        }
    }

    func clear(scene: AngleTrainingScene) {
        scene.clearResultNodes(nodes: &nodes)
        startPoint = nil
        endPoint = nil
        phase = .off
    }

    /// 终点吸附：与 X 轴向夹角 < 10° → 对齐起点 Z（水平）；与 Z 轴向夹角 < 10° →
    /// 对齐起点 X（垂直）；其余保留原始终点（条 20.4）。
    private func snapped(end: SCNVector3, from start: SCNVector3) -> SCNVector3 {
        let dx = abs(end.x - start.x)
        let dz = abs(end.z - start.z)
        guard dx > 1e-5 || dz > 1e-5 else { return end }
        let angleToXAxis = atan2f(dz, dx) * 180 / .pi
        if angleToXAxis < Self.snapDeg { return SCNVector3(end.x, end.y, start.z) }
        if angleToXAxis > 90 - Self.snapDeg { return SCNVector3(start.x, end.y, end.z) }
        return end
    }

    /// 渲染：白色细线 + 起/终点小十字（条 20.9）。
    private func render(scene: AngleTrainingScene) {
        scene.clearResultNodes(nodes: &nodes)
        let white = UIColor.white.withAlphaComponent(0.9)
        func cross(_ c: SCNVector3) {
            let r: Float = 0.018
            nodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                       to: SCNVector3(c.x + r, c.y, c.z), color: white, radius: 0.0022))
            nodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                       to: SCNVector3(c.x, c.y, c.z + r), color: white, radius: 0.0022))
        }
        if let a = startPoint { cross(a) }
        if let b = endPoint { cross(b) }
        if let a = startPoint, let b = endPoint {
            nodes.append(scene.addLine(from: a, to: b, color: white, radius: 0.0018))
        }
    }

    /// 均分摆球（条 20.6）：统计球心落在线上（距线段 < 1.2R 且不在端点）的在桌球，
    /// 按沿线投影排序后摆到 i/(n+1) 等分点（端点不放球）。返回 true = 有球被调整。
    func redistribute(keys: [String], scene: AngleTrainingScene) -> Bool {
        guard phase == .placed, let a = startPoint, let b = endPoint else { return false }
        let abx = b.x - a.x, abz = b.z - a.z
        let len2 = abx * abx + abz * abz
        guard len2 > 1e-6 else { return false }
        let r = AngleSceneCalculator.ballRadius

        var onLine: [(key: String, t: Float)] = []
        for key in keys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let px = node.position.x - a.x, pz = node.position.z - a.z
            let t = (px * abx + pz * abz) / len2
            guard t > 0.02, t < 0.98 else { continue }        // 端点不算
            let cx = a.x + abx * t, cz = a.z + abz * t
            let dx = node.position.x - cx, dz = node.position.z - cz
            if sqrtf(dx * dx + dz * dz) < r * 1.2 { onLine.append((key, t)) }
        }
        guard !onLine.isEmpty else { return false }

        onLine.sort { $0.t < $1.t }
        let n = onLine.count
        let y = scene.surfaceY + r
        for (i, item) in onLine.enumerated() {
            let f = Float(i + 1) / Float(n + 1)
            scene.allBallNodes[item.key]?.position =
                SCNVector3(a.x + abx * f, y, a.z + abz * f)
        }
        return true
    }
}

private struct BatchAuthorFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// 注：自由瞄准角度齿轮 `BTAimWheel` 已下沉至 `Core/Components/BTAimWheel.swift`（P18 B2 T-P18-05），
// 本文件直接引用共享版。
#endif
