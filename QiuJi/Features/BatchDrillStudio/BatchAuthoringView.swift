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

    private static let paletteColumns = 8

    private var drill: BatchDrill? { context.current }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                solverToolRow
                ZStack(alignment: .bottom) {
                    sceneContainer
                    if solver.isSolvingTool { drawingOverlay }
                    if composer.aimMode == .free {
                        BTAimWheel(
                            bearing: Double(composer.freeAimBearingDeg ?? 0),
                            onNudge: { composer.nudgeFreeAim(byDegrees: $0) }
                        )
                        .frame(width: 46, height: 240)
                        .padding(.trailing, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .allowsHitTesting(!composer.isPlaying)
                    }
                    if showSpinPad {
                        BTSpinPadCard(spinX: $composer.spinX, spinY: $composer.spinY,
                                      onClose: { showSpinPad = false })
                            .frame(maxWidth: 264)
                            .padding(.bottom, 80)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                bottomBar
            }
            if let key = draggingKey { dragGhost(key) }
            bannerView
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
                if let board = context.confirmedBoard { composer.loadBoard(board) }
                if let drill {
                    composer.renameSequence(
                        context.defaultSequenceName(for: drill, imageURL: context.sourceImageURL))
                }
                composer.startRecording()
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
        .padding(.vertical, Spacing.xs)
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
            onDragEnded: { composer.dragEnded(node: $0) },
            onDragEndedAt: { node, localPoint in handleTableDragEnd(node: node, localPoint: localPoint) },
            selectableBallNodes: composer.selectableBalls,
            onBallTapped: { composer.selectTarget(node: $0) },
            onTableTapped: { composer.handleTableTap(world: $0) },
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

    // MARK: - Bottom bar (composer control row + palette + actions)

    private var bottomBar: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                controlRow
                paletteBar
            }
            actionColumn
        }
        .background(Color(white: 0.11))
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .background(frameReader(id: "palette"))
        .environment(\.colorScheme, .dark)
    }

    private var controlRow: some View {
        HStack(spacing: Spacing.sm) {
            Button { showSpinPad = true } label: {
                BTSpinMiniIcon(spinX: composer.spinX, spinY: composer.spinY, diameter: 34)
            }
            .buttonStyle(.plain)
            .disabled(composer.isPlaying)

            Slider(value: $composer.velocity, in: 0.5...6.0, step: 0.1)
                .tint(Color.btPrimary)
                .disabled(composer.isPlaying)

            Text("\(PowerDisplay.name(composer.velocity)) \(String(format: "%.1f", composer.velocity))")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 4)
    }

    private var actionColumn: some View {
        VStack(spacing: 6) {
            Button { strike() } label: {
                HStack(spacing: 5) {
                    CueStickShape().frame(width: 15, height: 15).foregroundStyle(.white)
                    Text(composer.isPlaying ? "击球中" : "击球")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 96, height: 40)
                .background(strikeEnabled ? Color.btPrimary : Color.btPrimary.opacity(0.3), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!strikeEnabled)

            HStack(spacing: 6) {
                smallButton(system: "arrow.uturn.backward", label: "重打（删末杆并退回）",
                            tint: .white.opacity(0.14)) { composer.replayCurrent() }
                    .disabled(composer.isPlaying || !composer.canReplay)
                smallButton(system: "clock.arrow.circlepath", label: "回上一杆球形（保留记录，可再追加）",
                            tint: .white.opacity(0.14)) { composer.restorePreviousBoard() }
                    .disabled(composer.isPlaying || !composer.canReplay)
            }

            Text("\(composer.stepCount) 杆")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 96, height: 22)
                .background(.white.opacity(0.08), in: Capsule())

            Button { save(mode: .stay) } label: {
                actionPill(title: "保存·选下张图", system: "square.and.arrow.down", tint: .white.opacity(0.16))
            }
            .buttonStyle(.plain)
            .disabled(composer.isPlaying)

            Button { save(mode: .nextDrill) } label: {
                actionPill(title: "保存·下个drill", system: "arrow.right.circle", tint: Color.btAccent)
            }
            .buttonStyle(.plain)
            .disabled(composer.isPlaying)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }

    private func actionPill(title: String, system: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: system).font(.system(size: 12, weight: .bold))
            Text(title).font(.system(size: 12, weight: .bold, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .frame(width: 96, height: 34)
        .background(tint, in: Capsule())
    }

    private var strikeEnabled: Bool {
        !composer.isPlaying && !composer.isComputing && composer.isFeasible
    }

    @ViewBuilder
    private func smallButton(system: String, label: String, tint: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 43, height: 40)
                .background(tint, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// 击球：消费编排引擎的当前解推演并记一杆；完成后清掉本杆约束/解，准备下一杆。
    private func strike() {
        composer.play()
        // 击球后桌面前进、自动选下一杆（由 composer 处理）；清掉求解层上一杆约束。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            solver.resetForNextShot(scene: composer.scene)
        }
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
        seq.name = context.defaultSequenceName(for: drill, imageURL: imageURL)
        seq.updatedAt = Date()
        do {
            _ = try BatchSequenceArchive.archive(seq, drillId: drill.drillId, imageStem: stem)
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

private struct BatchAuthorFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - 自由瞄准角度齿轮（竖向棘轮标尺，仅自由模式显示）

/// 贴球桌右缘的竖向刻度齿轮：拖动微调自由瞄准方向。内容跟手——往上拖刻度上滚、读数递增
/// （= 屏幕顺时针/向右），灵敏度 0.3°/pt（刻度 1:1 随指 ≈3.33pt/°），越过整度给一次轻震。
/// `bearing` 由 `PositionPlayViewModel.freeAimBearingDeg` 喂入（0°=屏幕正上、顺时针增）。
private struct BTAimWheel: View {
    let bearing: Double
    let onNudge: (Float) -> Void

    private let degreesPerPoint: Float = 0.3
    private var pointsPerDegree: CGFloat { CGFloat(1 / degreesPerPoint) }

    @State private var lastHeight: CGFloat = 0
    @State private var lastTick: Int = .min
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let mid = h / 2
            let ppd = pointsPerDegree
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.5))

                Canvas { ctx, size in
                    let w = size.width
                    let span = Double(h / ppd)
                    let from = Int((bearing - span / 2 - 2).rounded(.down))
                    let to = Int((bearing + span / 2 + 2).rounded(.up))
                    for d in from...to {
                        let y = mid + CGFloat(Double(d) - bearing) * ppd
                        guard y >= -2, y <= h + 2 else { continue }
                        let norm = ((d % 360) + 360) % 360
                        let isMajor = norm % 10 == 0
                        let isMed = norm % 5 == 0
                        let len: CGFloat = isMajor ? w * 0.5 : (isMed ? w * 0.34 : w * 0.2)
                        var p = Path()
                        p.move(to: CGPoint(x: w - len, y: y))
                        p.addLine(to: CGPoint(x: w - 4, y: y))
                        ctx.stroke(p, with: .color(.white.opacity(isMajor ? 0.85 : (isMed ? 0.5 : 0.28))),
                                   lineWidth: isMajor ? 1.4 : 0.8)
                        if isMajor {
                            let t = Text("\(norm)")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                            ctx.draw(t, at: CGPoint(x: w - len - 8, y: y), anchor: .trailing)
                        }
                    }
                }

                Rectangle()
                    .fill(Color.btAccent)
                    .frame(height: 1.5)

                Text("\(((Int(bearing.rounded()) % 360) + 360) % 360)°")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.btAccent, in: Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 3)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let dy = v.translation.height - lastHeight
                        lastHeight = v.translation.height
                        onNudge(Float(-dy) * degreesPerPoint)
                        let t = Int(bearing.rounded())
                        if t != lastTick {
                            haptic.impactOccurred(intensity: 0.5)
                            lastTick = t
                        }
                    }
                    .onEnded { _ in lastHeight = 0 }
            )
        }
    }
}
#endif
