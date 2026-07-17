import Foundation
import SceneKit
import SwiftUI
import Combine

/// 思路训练器 ViewModel（走位反解器，ADR-P13-01）。
///
/// 复用 `AngleTrainingScene`（USDZ 真台 + 球节点）与 `AngleSceneView` 摆球/点选交互。
/// 与走位编排台不同：用户不再设塞/力度/瞄准——而是摆「母球 + 目标球 + 袋口」后，用约束工具
/// 画**可行落区**（情形 A）或标 **K 球过点**（情形 B），由 `PositionPlaySolver` 离线反解出
/// 塞与力度。结果默认显示最优解、可「下一解」翻档；塞/力度控件转为**只读指示器**展示当前解。
@MainActor
final class SiluTrainerViewModel: ObservableObject {

    // MARK: - Tools

    enum Tool: Equatable {
        case none
        /// 画落区（情形 A，区域约束）。
        case region
        /// 标落点（情形 A，精确点 + 容差，最小化到点距离）。
        case restPoint
        /// 标 K 球过点（情形 B）。
        case passPoint
    }

    enum RegionShape: String, CaseIterable { case rect = "矩形", circle = "圆" }

    /// 约束草稿（归一化系）。共享定义见 `SolveConstraintDraft`（G17，跨反解页统一口径）。
    typealias Draft = SolveConstraintDraft

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var pocketMarkers: [SCNNode] = []
    private var trajectoryNodes: [SCNNode] = []
    private var constraintNodes: [SCNNode] = []
    private var selectionNodes: [SCNNode] = []

    // MARK: - Published board / selection

    @Published private(set) var onTableKeys: [String] = []
    @Published private(set) var selectedTargetKey: String?
    @Published var selectedPocketIndex: Int = -1

    var paletteKeys: [String] {
        PositionPlayBall.allKeys.filter { !onTableKeys.contains($0) }
    }

    // MARK: - Published tool state

    @Published var activeTool: Tool = .none {
        didSet { if oldValue != activeTool { statusText = toolHint() } }
    }
    @Published var regionShape: RegionShape = .rect
    @Published private(set) var hasConstraint = false
    private var draft: Draft?
    /// 情形 B 过点最小速度（m/s）。
    var passVMin: Double = 0.3
    /// 落点「命中」容差半径（归一化单位，≈0.02→约 5cm）。母球停点落入此半径内即视为命中。
    var pointTolerance: Double = 0.02

    // MARK: - Published solve options (可选收窄；默认 = 完整能力，与原行为一致)

    /// 是否允许左右塞（英式塞）。默认允许（完整能力）；关 → 仅中杆/高低杆（spinX=0，精修锁横塞）。
    /// 竖塞（高低杆）始终全开——它是走位入门核心技术，不做区分。
    @Published var allowSideSpin: Bool = true {
        didSet { if oldValue != allowSideSpin { invalidateSolutions() } }
    }
    /// 是否仅基础走位（吃库 ≤1）。默认否（不限）；开 → 优先 ≤1 库解，无解兜底多库并标「进阶」。
    @Published var basicPositionOnly: Bool = false {
        didSet { if oldValue != basicPositionOnly { invalidateSolutions() } }
    }

    // MARK: - Published shot params (当前解的只读指示)

    @Published private(set) var velocity: Double = 3.0
    @Published private(set) var spinX: Double = 0
    @Published private(set) var spinY: Double = 0

    // MARK: - Published solve state

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    @Published private(set) var isPlaying = false
    @Published private(set) var isComputing = false
    @Published private(set) var solutions: [PositionPlaySolution] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var statusText = "拖动摆球 · 点目标球选中（绿环）· 点袋口选袋，再选工具画约束"

    var currentSolution: PositionPlaySolution? {
        guard solutions.indices.contains(currentIndex) else { return nil }
        return solutions[currentIndex]
    }
    var hasSolutions: Bool { !solutions.isEmpty }
    var canStrike: Bool { !isPlaying && !isComputing && (currentSolution?.prediction.feasible ?? false)
        && (currentSolution?.prediction.duration ?? 0) > 0.05 }

    // MARK: - Internals

    private var lastAimDirection: SCNVector3?
    private let solveQueue = DispatchQueue(label: "com.qiuji.silu-solve", qos: .userInitiated)
    private var solveGeneration = 0
    private var surfaceY: Float { scene.surfaceY }

    // MARK: - Last shot（条 21.3 + G17：上一杆完整恢复 / 回放）

    /// 思路页「上一杆」完整上下文 = 共享求解快照 + 本页选择模型（目标球 + 袋口）。
    /// 上一杆 = 回到击打前**完整状态**（球形 + 约束 + 解 + 打点/力度/瞄准 + 目标/袋口，免重解）；
    /// 回放 = 重播击打动画。
    /// （internal 而非 private：供单测直接验证「快照→恢复」逐字段一致，见 `PositionPlayUndoSnapshotTests`。）
    struct UndoContext {
        var snapshot: SolveShotSnapshot
        var selectedTargetKey: String?
        var selectedPocketIndex: Int
    }
    private var lastShotContext: UndoContext?
    @Published private(set) var canUndoShot = false
    @Published private(set) var canPlayback = false

    // MARK: - Setup

    func setupScene() {
        scene.setupScene()
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        scene.hideAllBalls()
        scene.hideCueStick()
        scene.cameraRig?.topDownPanOffset = .zero
        applyDefaultLayout()
    }

    private func applyDefaultLayout() {
        place(key: PositionPlayBall.cueKey, normalized: CanvasPoint(x: 0.30, y: 0.30))
        place(key: "_1", normalized: CanvasPoint(x: 0.62, y: 0.20))
        refreshOnTableKeys()
        selectedTargetKey = "_1"
        selectBestPocket()
        refreshOverlays()
    }

    /// 载入外部球形（如「拍照建球形」快照）：清场 → 摆入快照球 → 自动选目标/最优袋 → 失效旧解。
    func loadBoard(_ snapshot: BoardSnapshot) {
        guard !isPlaying, !snapshot.onTable.isEmpty else { return }
        scene.hideAllBalls()
        clearConstraint()
        for (key, pt) in snapshot.onTable {
            place(key: key, normalized: pt)
        }
        refreshOnTableKeys()
        selectedTargetKey = nil
        selectedPocketIndex = -1
        autoSelectTarget()
        if selectedTargetKey != nil { selectBestPocket() }
        refreshOverlays()
        invalidateSolutions()
    }

    // MARK: - Board queries

    var draggableBalls: [SCNNode] { onTableKeys.compactMap { scene.allBallNodes[$0] } }
    var selectableBalls: [SCNNode] {
        onTableKeys.filter { !PositionPlayBall.isCue($0) }.compactMap { scene.allBallNodes[$0] }
    }

    func currentSnapshot() -> BoardSnapshot {
        var dict: [String: CanvasPoint] = [:]
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let n = AngleSceneCalculator.sceneToNormalized(position: node.position)
            dict[key] = CanvasPoint(x: Double(n.x), y: Double(n.y))
        }
        return BoardSnapshot(onTable: dict)
    }

    // MARK: - Palette place / remove / drag

    private func refreshOnTableKeys() {
        onTableKeys = PositionPlayBall.allKeys.filter { !(scene.allBallNodes[$0]?.isHidden ?? true) }
    }

    func placeFromPalette(_ key: String) {
        guard !isPlaying else { return }
        place(key: key, normalized: freeNormalizedSlot())
        refreshOnTableKeys()
        if !PositionPlayBall.isCue(key), selectedTargetKey == nil {
            selectedTargetKey = key
            selectBestPocket()
        }
        invalidateSolutions()
    }

    func placeFromPalette(_ key: String, atWorld world: SCNVector3) {
        guard !isPlaying else { return }
        guard let node = scene.allBallNodes[key] else { return }
        let clamped = clampMultiBall(world, movingNode: node)
        let n = AngleSceneCalculator.sceneToNormalized(position: clamped)
        place(key: key, normalized: CanvasPoint(x: Double(n.x), y: Double(n.y)))
        refreshOnTableKeys()
        if !PositionPlayBall.isCue(key), selectedTargetKey == nil {
            selectedTargetKey = key
            selectBestPocket()
        }
        invalidateSolutions()
    }

    func removeFromTable(_ key: String) {
        guard !isPlaying else { return }
        scene.hideBall(key: key)
        if selectedTargetKey == key { selectedTargetKey = nil }
        refreshOnTableKeys()
        if selectedTargetKey == nil { autoSelectTarget() }
        invalidateSolutions()
    }

    private func place(key: String, normalized: CanvasPoint) {
        let scenePos = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: normalized.x, y: normalized.y), surfaceY: surfaceY)
        scene.showBall(key: key, scenePosition: scenePos)
    }

    private func freeNormalizedSlot() -> CanvasPoint {
        let candidates: [CanvasPoint] = stride(from: 0.15, through: 0.85, by: 0.1).flatMap { x in
            stride(from: 0.12, through: 0.40, by: 0.08).map { y in CanvasPoint(x: x, y: y) }
        }
        for c in candidates {
            let scenePos = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: c.x, y: c.y), surfaceY: surfaceY)
            if !overlapsExisting(scenePos, excluding: nil) { return c }
        }
        return CanvasPoint(x: 0.5, y: 0.25)
    }

    private func overlapsExisting(_ pos: SCNVector3, excluding key: String?) -> Bool {
        for k in onTableKeys where k != key {
            guard let node = scene.allBallNodes[k], !node.isHidden else { continue }
            if AngleSceneCalculator.horizontalDistance(pos, node.position) < 2.2 * AngleSceneCalculator.ballRadius {
                return true
            }
        }
        return false
    }

    func dragBegan(node: SCNNode) {
        guard !isPlaying else { return }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
    }

    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        guard !isPlaying else { return }
        node.position = clampMultiBall(worldPosition, movingNode: node)
    }

    func dragEnded(node: SCNNode) {
        guard !isPlaying else { return }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))
        invalidateSolutions()
    }

    private func clampMultiBall(_ pos: SCNVector3, movingNode: SCNNode) -> SCNVector3 {
        var p = AngleSceneCalculator.clampAwayFromPockets(pos, surfaceY: surfaceY)
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let r = AngleSceneCalculator.ballRadius
        let minDist: Float = 2 * r + 0.001
        for _ in 0..<6 {
            var moved = false
            for k in onTableKeys {
                guard let other = scene.allBallNodes[k], other !== movingNode, !other.isHidden else { continue }
                let dx = p.x - other.position.x, dz = p.z - other.position.z
                let dist = sqrtf(dx * dx + dz * dz)
                if dist < minDist {
                    if dist > 0.0001 {
                        p.x = other.position.x + (dx / dist) * minDist
                        p.z = other.position.z + (dz / dist) * minDist
                    } else { p.x += minDist }
                    moved = true
                }
            }
            p.x = max(-halfL + r, min(halfL - r, p.x))
            p.z = max(-halfW + r, min(halfW - r, p.z))
            if !moved { break }
        }
        return SCNVector3(p.x, surfaceY + r, p.z)
    }

    // MARK: - Selection

    func selectTarget(node: SCNNode) {
        guard let key = scene.ballKey(for: node) else { return }
        guard !isPlaying, onTableKeys.contains(key), !PositionPlayBall.isCue(key) else { return }
        selectedTargetKey = key
        selectBestPocket()
        invalidateSolutions()
    }

    func selectPocket(at index: Int) {
        guard !isPlaying else { return }
        selectedPocketIndex = index
        updatePocketHighlights()
        invalidateSolutions()
    }

    private func autoSelectTarget() {
        guard let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else {
            selectedTargetKey = nil
            return
        }
        let candidates = onTableKeys.filter { !PositionPlayBall.isCue($0) }
        selectedTargetKey = candidates.min { a, b in
            distanceToCue(a, cue: cue.position) < distanceToCue(b, cue: cue.position)
        }
        if selectedTargetKey != nil { selectBestPocket() }
    }

    private func distanceToCue(_ key: String, cue: SCNVector3) -> Float {
        guard let node = scene.allBallNodes[key], !node.isHidden else { return .greatestFiniteMagnitude }
        return AngleSceneCalculator.horizontalDistance(cue, node.position)
    }

    private func selectBestPocket() {
        guard let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden,
              let targetKey = selectedTargetKey,
              let target = scene.allBallNodes[targetKey], !target.isHidden else { return }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        var bestFeasible: (index: Int, dist: Float)?
        var bestAny: (index: Int, dist: Float)?
        for i in 0..<pockets.count {
            let dist = AngleSceneCalculator.horizontalDistance(target.position, pockets[i])
            if bestAny == nil || dist < bestAny!.dist { bestAny = (i, dist) }
            let aim = AngleSceneCalculator.effectivePocketAimPoint(
                targetBall: target.position, pocketIndex: i, surfaceY: surfaceY)
            guard AngleSceneCalculator.isFeasible(
                cueBall: cue.position, targetBall: target.position, pocket: aim) else { continue }
            if bestFeasible == nil || dist < bestFeasible!.dist { bestFeasible = (i, dist) }
        }
        selectedPocketIndex = bestFeasible?.index ?? bestAny?.index ?? 0
        updatePocketHighlights()
    }

    private func updatePocketHighlights() {
        for (i, marker) in pocketMarkers.enumerated() {
            scene.setPocketHighlight(marker, style: i == selectedPocketIndex ? .selected : .viable)
        }
    }

    // MARK: - Constraint drawing (table-local normalized points from the view)

    /// 工具拖拽：起点 → 当前点（归一化系）。落区按 `regionShape` 解释；过点工具取当前点。
    func toolDrag(startNormalized start: CanvasPoint, currentNormalized cur: CanvasPoint, ended: Bool) {
        guard !isPlaying else { return }
        switch activeTool {
        case .none:
            return
        case .passPoint:
            draft = .passPoint(cur)
        case .restPoint:
            draft = .restPoint(cur)
        case .region:
            switch regionShape {
            case .rect:
                let cx = (start.x + cur.x) / 2, cy = (start.y + cur.y) / 2
                let hw = max(0.01, abs(cur.x - start.x) / 2)
                let hh = max(0.005, abs(cur.y - start.y) / 2)
                draft = .region(.rect(center: CanvasPoint(x: cx, y: cy), halfWidth: hw, halfHeight: hh))
            case .circle:
                let dx = cur.x - start.x, dy = cur.y - start.y
                let r = max(0.01, (dx * dx + dy * dy).squareRoot())
                draft = .region(.circle(center: start, radius: r))
            }
        }
        hasConstraint = draft != nil
        renderConstraint()
        // 画完不自动求解（用户拍板）：约束就绪后由「求解」按钮显式触发。
        if ended, currentConstraint() != nil { statusText = "已就绪，点「求解」反解走位" }
    }

    func clearConstraint() {
        draft = nil
        hasConstraint = false
        clearConstraintNodes()
        invalidateSolutions()
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

    // MARK: - Solve (background)

    private func invalidateSolutions() {
        solveGeneration += 1
        isComputing = false
        solutions = []
        currentIndex = 0
        clearTrajectory()
        scene.hideCueStick()
        resetParamDisplay()
        refreshOverlays()
        if currentConstraint() != nil { statusText = "已就绪，点「求解」反解走位" } else { statusText = toolHint() }
    }

    private func resetParamDisplay() {
        velocity = 3.0; spinX = 0; spinY = 0
    }

    func solve() {
        guard !isPlaying else { return }
        guard let targetKey = selectedTargetKey, selectedPocketIndex >= 0,
              let pocketId = ShotIntent.pocketId(for: selectedPocketIndex),
              let constraint = currentConstraint() else {
            statusText = needsSetupHint()
            return
        }
        let before = currentSnapshot()
        let y = surfaceY
        let params = searchParams(for: constraint)
        solveGeneration += 1
        let gen = solveGeneration
        isComputing = true
        statusText = "求解中…"
        clearTrajectory()
        scene.hideCueStick()

        solveQueue.async { [weak self] in
            let result = PositionPlaySolver.solve(
                before: before, targetKey: targetKey, pocket: pocketId,
                constraint: constraint, surfaceY: y, params: params)
            DispatchQueue.main.async {
                guard let self, self.solveGeneration == gen, !self.isPlaying else { return }
                self.isComputing = false
                self.solutions = result
                self.currentIndex = 0
                if result.isEmpty {
                    self.statusText = "未找到解（试着放大区域或换目标袋口）"
                    self.resetParamDisplay()
                } else {
                    self.showSolution(at: 0)
                }
            }
        }
    }

    /// 由可选开关构造搜索参数：基底按约束类型取（落区/落点用 `.standard`、过点用 `.passThrough`），
    /// 再叠加「禁左右塞」（E3 塞幅预算 `.vertical`：优先无横塞解——前置剪枝更快；确实无解才
    /// 兜底展示横塞解并标注，绝不因开关给出「无解」）与「仅基础走位」（吃库上限 1）。
    /// 另开启扰动容错分析（E5）：思路训练是教学页，每个解产出容错度供学员取舍。
    private func searchParams(for constraint: SolveConstraint) -> PositionPlaySolver.SearchParams {
        var params: PositionPlaySolver.SearchParams
        switch constraint {
        case .restRegion: params = .standard
        case .passThrough: params = .passThrough
        }
        if !allowSideSpin { params.maxSpinTier = .vertical }
        params.maxCushions = basicPositionOnly ? 1 : nil
        params.robustnessEnabled = true
        return params
    }

    // MARK: - Solution display

    /// 三档轨迹标注切换后重绘当前解（`BTTrajectoryDetailChip` 触发，条 12.5）。
    func redrawTrajectory() {
        guard !isPlaying, let sol = currentSolution else { return }
        drawTrajectory(sol.prediction, shot: sol.shot)
    }

    func nextSolution() {
        guard !solutions.isEmpty else { return }
        currentIndex = (currentIndex + 1) % solutions.count
        showSolution(at: currentIndex)
    }

    /// 微调当前解（条 21.4）：求解完成后用户改打点/力度，按新参数重预测替换当前解
    /// （轨迹/进袋结果如实更新，用户可对照约束自行取舍）。
    func adjustCurrentSolution(velocity v: Double? = nil,
                               spinX sx: Double? = nil, spinY sy: Double? = nil) {
        guard !isPlaying, !isComputing, let sol = currentSolution else { return }
        var shot = sol.shot
        if let v { shot.velocity = v }
        if let sx { shot.spinX = sx }
        if let sy { shot.spinY = sy }
        let before = currentSnapshot()
        let y = surfaceY
        let idx = currentIndex
        solveGeneration += 1
        let gen = solveGeneration
        isComputing = true

        solveQueue.async { [weak self] in
            let pred = PositionPlayShotSolver.solve(before: before, shot: shot, surfaceY: y)
            DispatchQueue.main.async {
                guard let self, self.solveGeneration == gen, !self.isPlaying else { return }
                self.isComputing = false
                guard let pred, self.solutions.indices.contains(idx) else { return }
                self.solutions[idx] = PositionPlaySolution(
                    shot: shot, prediction: pred,
                    cushionCount: pred.cueCushionCount,
                    potted: pred.simObjectPotted,
                    margin: sol.margin,
                    summary: "微调 · " + ShotSpinLabel.text(spinX: shot.spinX, spinY: shot.spinY)
                        + String(format: " · %.1f m/s", shot.velocity),
                    satisfiesConstraint: sol.satisfiesConstraint,
                    beyondCushionBudget: sol.beyondCushionBudget,
                    difficultyScore: DifficultyModel.score(
                        spinX: shot.spinX, spinY: shot.spinY, velocity: shot.velocity,
                        cutAngleDeg: pred.cutAngleDeg),
                    difficultyTier: DifficultyModel.tier(spinX: shot.spinX, spinY: shot.spinY),
                    beyondSpinBudget: sol.beyondSpinBudget
                )
                self.showSolution(at: idx)
            }
        }
    }

    private func showSolution(at index: Int) {
        guard solutions.indices.contains(index) else { return }
        let sol = solutions[index]
        velocity = sol.shot.velocity
        spinX = sol.shot.spinX
        spinY = sol.shot.spinY
        statusText = solutionStatus(sol)
        drawTrajectory(sol.prediction, shot: sol.shot)
        updateCueStickAiming(sol.prediction)
        renderConstraint()
        refreshOverlays()
    }

    private func solutionStatus(_ sol: PositionPlaySolution) -> String {
        let prefix = solutions.count > 1 ? "解 \(currentIndex + 1)/\(solutions.count) · " : ""
        // 「仅基础走位」预算内无解、回退的多库解：标「进阶」（用户拍板兜底语义）。
        var advanced = sol.beyondCushionBudget ? "进阶（超基础走位）· " : ""
        // 「禁左右塞」预算内无解、回退的横塞解（E3 兜底）：如实标注「此走位必须加塞」。
        if sol.beyondSpinBudget { advanced += "进阶（需横塞）· " }
        // 扰动容错度（E5）：小幅执行误差下仍满足约束的比例，教学取舍参考。
        let robust = sol.robustness.map { " · 容错 \(Int(($0 * 100).rounded()))%" } ?? ""
        if !sol.satisfiesConstraint {
            return prefix + advanced + "最接近解（未满足约束）· " + sol.summary + robust
        }
        return prefix + advanced + sol.summary + robust
    }

    // MARK: - Trajectory + constraint rendering

    private func drawTrajectory(_ p: ShotPrediction, shot: PlannedShot) {
        clearTrajectory()
        guard p.feasible else { scene.hideCueStick(); return }
        // 全量口径（C3 / D2）：与 Composer/PlanThree 同 options。
        TrajectoryRenderer.draw(
            prediction: p,
            options: .positionPlay,
            context: .init(
                prediction: p,
                targetKey: shot.targetKey,
                pocket: shot.pocket,
                surfaceY: surfaceY,
                showGhost: true
            ),
            scene: scene,
            into: &trajectoryNodes
        )
    }

    private func clearTrajectory() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
        scene.hideAllVisualization()
    }

    /// 点击球库中「已在桌上」的球时，对应桌上球做一次放大→恢复脉冲提示位置（#5a）。
    func pulseTableBall(_ key: String) {
        guard !isPlaying, let node = scene.allBallNodes[key], !node.isHidden else { return }
        TableBallPulse.pulse(node)
    }

    /// 落区 / 过点叠加（青色，与轨迹区分）。
    private func renderConstraint() {
        clearConstraintNodes()
        let color = BTScenePalette.constraintCyan
        let y = surfaceY + 0.002
        switch draft {
        case .region(let region):
            switch region {
            case let .circle(center, radius):
                let c = AngleSceneCalculator.normalizedToScene(
                    point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                SceneStroke.strokeCircle(center: c, radius: Float(radius) * SolveRegion.sceneScale,
                                         color: color, scene: scene, into: &constraintNodes)
            case let .rect(center, hw, hh):
                let c = AngleSceneCalculator.normalizedToScene(
                    point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                let dx = Float(hw) * SolveRegion.sceneScale
                let dz = Float(hh) * SolveRegion.sceneScale
                SceneStroke.strokeRect(center: c, halfX: dx, halfZ: dz, color: color,
                                       scene: scene, into: &constraintNodes)
            case let .point(center, tol):
                // 落区 draft 一般不携带 .point（落点走 .restPoint 草稿），此处兜底渲染容差环。
                let c = AngleSceneCalculator.normalizedToScene(
                    point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                SceneStroke.strokeCircle(center: c, radius: Float(tol) * SolveRegion.sceneScale,
                                         color: color, scene: scene, into: &constraintNodes)
            case .sector:
                // 扇形仅打三页默认落区，由页内独立路径渲染；思路训练 draft 不进 sector。
                break
            }
        case .passPoint(let pt):
            let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: y)
            SceneStroke.strokeCircle(center: c, radius: AngleSceneCalculator.ballRadius,
                                     color: color, scene: scene, into: &constraintNodes)
            // 十字标记。
            let r = AngleSceneCalculator.ballRadius * 1.6
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                                  to: SCNVector3(c.x + r, c.y, c.z), color: color,
                                                  radius: SceneStroke.lineRadius))
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                                  to: SCNVector3(c.x, c.y, c.z + r), color: color,
                                                  radius: SceneStroke.lineRadius))
        case .restPoint(let pt):
            // 落点：琥珀色十字（目标点）+ 容差环（命中半径），与青色落区/过点区分。
            let amber = UIColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 0.95)
            let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: y)
            SceneStroke.strokeCircle(center: c, radius: Float(pointTolerance) * SolveRegion.sceneScale,
                                     color: amber, scene: scene, into: &constraintNodes)
            let r = AngleSceneCalculator.ballRadius * 1.4
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                                  to: SCNVector3(c.x + r, c.y, c.z), color: amber, radius: 0.0024))
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                                  to: SCNVector3(c.x, c.y, c.z + r), color: amber, radius: 0.0024))
        case nil:
            break
        }
    }

    private func clearConstraintNodes() {
        scene.clearResultNodes(nodes: &constraintNodes)
    }

    // MARK: - Selection feedback + instant geometry preview

    /// 选中反馈（线语言 v2，条 12.3：弃选中环——假想球圈 + 进球线已明确标示选中目标球）：
    /// 无解时叠加几何预览（假想球 + 瞄准线 + 进球线，纯几何即时绘制，不跑物理），
    /// 让「点球选目标 / 点袋选袋」立刻可见，无需先求解。
    private func refreshOverlays() {
        scene.clearResultNodes(nodes: &selectionNodes)
        guard !isPlaying else { return }
        let showingSolution = currentSolution != nil && !isComputing
        guard let tkey = selectedTargetKey,
              let tn = scene.allBallNodes[tkey], !tn.isHidden else {
            if !showingSolution {
                scene.ghostBallNode?.isHidden = true
                scene.hideContactDot()
            }
            return
        }

        // 已有解时由轨迹叠加负责渲染。
        guard !showingSolution, selectedPocketIndex >= 0,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else { return }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        let aim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: tn.position, pocketIndex: selectedPocketIndex, surfaceY: surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: tn.position, pocket: aim, ballRadius: AngleSceneCalculator.ballRadius)
        // 瞄准线（母球→假想球，淡白实线）+ 进球线（目标球→袋口，随球色虚线）。
        selectionNodes.append(scene.addLine(from: cue.position, to: ghost,
                                            color: UIColor.white.withAlphaComponent(0.45),
                                            radius: TrajectoryStyle.aimRadius))
        scene.addDashedPolyline([tn.position, pockets[selectedPocketIndex]],
                                color: TrajectoryStyle.potColor(for: tkey, alpha: 0.55),
                                radius: TrajectoryStyle.aimRadius, into: &selectionNodes)
        if let g = scene.ghostBallNode {
            g.position = SCNVector3(ghost.x, surfaceY + AngleSceneCalculator.ballRadius, ghost.z)
            g.isHidden = false
            // 重叠标注 L0（T-P18-42）：几何预览同样补齐接触点绿点。
            scene.updateContactDot(ghostCenter: g.position, targetCenter: tn.position)
        }
    }

    // MARK: - Cue stick aiming aid

    private func updateCueStickAiming(_ p: ShotPrediction) {
        guard !isPlaying, p.feasible,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden,
              let aim = aimDirection(path: p.cuePath, from: cue.position) else {
            scene.hideCueStick(); lastAimDirection = nil; return
        }
        lastAimDirection = aim
        scene.updateCueStick(cueBallPosition: strikePosition(cue: cue.position), aimDirection: aim)
    }

    private func strikePosition(cue: SCNVector3) -> SCNVector3 {
        guard let aim = lastAimDirection else { return cue }
        return CueStroke.strikePosition(cue: cue, aim: aim, spinX: spinX)
    }

    private func aimDirection(path: [SCNVector3], from cue: SCNVector3) -> SCNVector3? {
        for pt in path {
            let dx = pt.x - cue.x, dz = pt.z - cue.z
            let d = sqrtf(dx * dx + dz * dz)
            if d > 0.02 { return SCNVector3(dx / d, 0, dz / d) }
        }
        return nil
    }

    // MARK: - Strike (运杆 + 回放，复用编排台模型)

    func play() {
        guard canStrike, let sol = currentSolution,
              let recorder = sol.prediction.recorder,
              let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = lastAimDirection ?? aimDirection(path: sol.prediction.cuePath, from: cueNode.position)
        else { return }

        // 记录上一杆上下文（条 21.3 + G17）：击打前完整求解快照 + 本页选择模型，供上一杆完整恢复/回放。
        lastShotContext = makeUndoContext(shot: sol.shot, prediction: sol.prediction)
        canUndoShot = false
        canPlayback = false

        isPlaying = true
        statusText = "运杆…"
        clearConstraintNodes()
        let strikePos = strikePosition(cue: cueNode.position)
        scene.runCueStroke(strikePosition: strikePos, aim: aim, velocity: Float(sol.shot.velocity)) { [weak self] in
            self?.launchBalls(sol: sol, recorder: recorder)
        }
    }

    /// 上一杆（条 21.3 + G17）：回到上次击打前的**完整状态**——球形、目标球/袋口、约束、
    /// 已求出的解（缓存回填，无需重画重求解）、打点/力度/瞄准，均逐字段还原。
    func undoLastShot() {
        guard !isPlaying, canUndoShot, let ctx = lastShotContext else { return }
        restore(from: ctx)
        canUndoShot = false
        canPlayback = false
        lastShotContext = nil
        statusText = ctx.snapshot.solutions.isEmpty
            ? "已退回上一杆击打前"
            : "已退回上一杆击打前 · 球形/约束/解已还原"
    }

    /// 组装当前状态为「上一杆」完整上下文（击打前调用；`play()` 与单测共用同一处捕获逻辑）。
    func makeUndoContext(shot: PlannedShot, prediction: ShotPrediction) -> UndoContext {
        UndoContext(
            snapshot: SolveShotSnapshot(
                before: currentSnapshot(), shot: shot, prediction: prediction,
                solutions: solutions, currentIndex: currentIndex, draft: draft,
                velocity: velocity, spinX: spinX, spinY: spinY,
                allowSideSpin: allowSideSpin, basicPositionOnly: basicPositionOnly),
            selectedTargetKey: selectedTargetKey,
            selectedPocketIndex: selectedPocketIndex)
    }

    /// 把击打前完整快照原样恢复到场景与状态（不重解）。
    func restore(from ctx: UndoContext) {
        let snap = ctx.snapshot
        // 清动画/叠加，摆回击打前球形。
        scene.hideAllBalls()
        clearTrajectory()
        clearConstraintNodes()
        scene.clearResultNodes(nodes: &selectionNodes)
        scene.hideCueStick()
        for (key, pt) in snap.before.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()

        // 求解选项须先于 solutions 恢复：值不变时 didSet 不触发失效；即便用户在击打后改过开关，
        // 这里的失效也会被随后回填的 solutions 覆盖，故顺序保证正确。
        allowSideSpin = snap.allowSideSpin
        basicPositionOnly = snap.basicPositionOnly

        // 选择模型（目标球 + 袋口）。
        selectedTargetKey = ctx.selectedTargetKey
        selectedPocketIndex = ctx.selectedPocketIndex
        updatePocketHighlights()

        // 约束草稿（保留落点/落区/过点的视觉与语义分叉）。
        draft = snap.draft
        hasConstraint = snap.draft != nil
        // 工具复位到可点选态：约束已还原可见，用户可直接再选目标/袋或另画约束。
        activeTool = .none

        // 解回填（「解还在」，免重解）。
        solveGeneration += 1
        isComputing = false
        solutions = snap.solutions
        currentIndex = snap.currentIndex
        velocity = snap.velocity
        spinX = snap.spinX
        spinY = snap.spinY

        if currentSolution != nil {
            showSolution(at: currentIndex)   // 轨迹 + 球杆瞄准 + 约束 + 叠加
        } else {
            renderConstraint()
            refreshOverlays()
        }
    }

    /// 回放上一杆击打过程（条 21.3）：退回击打前重播动画，播完回到击打后局面。
    func replayLastShot() {
        guard !isPlaying, canPlayback, let ctx = lastShotContext else { return }
        let snap = ctx.snapshot
        guard let recorder = snap.prediction.recorder, snap.prediction.duration > 0.05 else { return }
        let after = currentSnapshot()
        isPlaying = true
        clearTrajectory()
        clearConstraintNodes()
        scene.clearResultNodes(nodes: &selectionNodes)
        scene.hideCueStick()
        statusText = "回放上一杆…"

        scene.hideAllBalls()
        for (key, pt) in snap.before.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()

        guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = aimDirection(path: snap.prediction.cuePath, from: cueNode.position) else {
            finishPlayback(after: after)
            return
        }
        let strikePos = CueStroke.strikePosition(cue: cueNode.position, aim: aim, spinX: snap.shot.spinX)
        scene.runCueStroke(strikePosition: strikePos, aim: aim,
                           velocity: Float(snap.shot.velocity)) { [weak self] in
            self?.runPlaybackAnimation(snapshot: snap, recorder: recorder, after: after)
        }
    }

    private func runPlaybackAnimation(
        snapshot ctx: SolveShotSnapshot,
        recorder: TrajectoryRecorder, after: BoardSnapshot
    ) {
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let settle = playback.duration   // G15：播到引擎自然静止（不做感知截断）

        var cueAction: SCNAction?
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let name = PositionPlayShotSolver.predName(boardKey: key, shot: ctx.shot)
            let action = playback.action(for: node, ballName: name, speed: 1.0,
                                         removeOnPocket: false, maxSimTime: settle)
            if key == PositionPlayBall.cueKey { cueAction = action }
            else if let action { node.runAction(action) }
        }
        let tail: TimeInterval = ctx.prediction.pocketedBalls.isEmpty
            ? 0 : TrajectoryPlayback.pocketSettleDuration + 0.1
        if let cueAction, let cueNode = scene.allBallNodes[PositionPlayBall.cueKey] {
            cueNode.runAction(cueAction) { [weak self] in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(tail * 1_000_000_000))
                    self?.finishPlayback(after: after)
                }
            }
            ShotAudioScheduler.shared.play(prediction: ctx.prediction)
        } else {
            finishPlayback(after: after)
        }
    }

    /// 回放收尾：清动画、恢复击打后局面（保留上一杆上下文，可反复回放/退回）。
    private func finishPlayback(after: BoardSnapshot) {
        ShotAudioScheduler.shared.cancel()
        for key in PositionPlayBall.allKeys {
            guard let node = scene.allBallNodes[key] else { continue }
            if node.parent == nil { scene.rootNode.addChildNode(node) }
            node.removeAllActions()
            node.opacity = 1
        }
        isPlaying = false
        scene.hideCueStick()
        let ctx = lastShotContext
        loadBoard(after)
        lastShotContext = ctx   // loadBoard 不动上下文，但显式保底
        canUndoShot = ctx != nil
        canPlayback = ctx != nil
        statusText = "回放结束 · 球停在击打后局面"
    }

    private func launchBalls(sol: PositionPlaySolution, recorder: TrajectoryRecorder) {
        statusText = "击球中…"
        clearTrajectory()
        // 收杆不在此处：触球后球杆继续减速跟杆 + 停留一拍再消失（由 `runCueStroke` 接管）。
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let speed: Float = 1.0
        // G15：播到引擎自然静止（不做 0.07 感知截断），球停止前无最后一跳/瞬移。
        let settle = playback.duration
        var cueAction: SCNAction?
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let name = PositionPlayShotSolver.predName(boardKey: key, shot: sol.shot)
            let action = playback.action(for: node, ballName: name, speed: speed,
                                         removeOnPocket: false, maxSimTime: settle)
            if key == PositionPlayBall.cueKey { cueAction = action }
            else if let action { node.runAction(action) }
        }
        let tail: TimeInterval = sol.prediction.pocketedBalls.isEmpty
            ? 0 : TrajectoryPlayback.pocketSettleDuration + 0.1
        if let cueAction, let cueNode = scene.allBallNodes[PositionPlayBall.cueKey] {
            cueNode.runAction(cueAction) { [weak self] in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(tail * 1_000_000_000))
                    self?.finishStrike(sol: sol)
                }
            }
            // 音效在全部球体动画挂载后起播：避免音频引擎冷启动阻塞主线程时，跟杆先于球推进。
            ShotAudioScheduler.shared.play(prediction: sol.prediction)
        } else {
            finishStrike(sol: sol)
        }
    }

    /// 回放结束：**不复原**——球停在回放终点（用户拍板，真实击球语义）。进袋球移除、母球 scratch
    /// 则隐藏；本杆的解与约束叠加随布局失效，回到「可继续摆球/画约束再求解」态。
    private func finishStrike(sol: PositionPlaySolution) {
        ShotAudioScheduler.shared.cancel()
        for key in onTableKeys {
            scene.allBallNodes[key]?.removeAllActions()
        }
        // 进袋球（含母球 scratch）离场。
        let potted = Set(sol.prediction.pocketedBalls.map { boardKey(forPredName: $0, shot: sol.shot) })
        for key in potted { scene.hideBall(key: key) }
        if sol.prediction.cuePocketed { scene.hideBall(key: PositionPlayBall.cueKey) }

        isPlaying = false
        refreshOnTableKeys()
        if let t = selectedTargetKey, !onTableKeys.contains(t) { selectedTargetKey = nil }
        if selectedTargetKey == nil { autoSelectTarget() } else { selectBestPocket() }

        // 本杆解/约束已对应旧布局，失效清空。
        solveGeneration += 1
        solutions = []
        currentIndex = 0
        draft = nil
        hasConstraint = false
        // 击球后布局已变，回到「摆球/点选」态：用户下一步是重选目标球与目标袋口，
        // 而点选只在 .none 态可用（工具态下绘制层会吞掉点击）。didSet 的 toolHint 会被下方收尾文案覆盖。
        activeTool = .none
        clearTrajectory()
        clearConstraintNodes()
        scene.hideCueStick()
        resetParamDisplay()
        refreshOverlays()

        canUndoShot = lastShotContext != nil
        canPlayback = lastShotContext?.snapshot.prediction.recorder != nil

        let cueGone = scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true
        statusText = cueGone
            ? "母球进袋（scratch）· 重新摆母球或「恢复默认」"
            : "已击打 · 母球停在终点，可继续画约束再求解"
    }

    // MARK: - Reset

    private func boardKey(forPredName name: String, shot: PlannedShot) -> String {
        if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
        if name == ShotInput.targetBallName { return shot.targetKey }
        return name
    }

    func clearTable() {
        guard !isPlaying else { return }
        scene.hideAllBalls()
        selectedTargetKey = nil
        selectedPocketIndex = -1
        refreshOnTableKeys()
        clearConstraint()
        invalidateSolutions()
    }

    func resetAll() {
        guard !isPlaying else { return }
        scene.hideAllBalls()
        clearConstraint()
        applyDefaultLayout()
        invalidateSolutions()
    }

    // MARK: - Hints

    private func toolHint() -> String {
        switch activeTool {
        case .none: return "拖动摆球 · 点目标球选中（绿环）· 点袋口选袋，再选工具画约束"
        case .region: return "在球桌上拖出\(regionShape.rawValue)可行落区"
        case .restPoint: return "点按球桌标出母球期望停的落点（琥珀十字为目标，环为命中容差）"
        case .passPoint: return "点按球桌标出母球需经过的 K 球点"
        }
    }

    private func needsSetupHint() -> String {
        if scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true { return "请先把母球摆上桌" }
        if selectedTargetKey == nil { return "点选一颗目标球" }
        if selectedPocketIndex < 0 { return "点击袋口选择目标袋" }
        if currentConstraint() == nil { return toolHint() }
        return "已就绪，点「求解」反解走位"
    }

    // MARK: - Break flow（T-P18-47：内置开球，替代球形生成器页）

    /// 开球模式 runner。非 nil = 开球模式：约束/求解/摆球交互全部挂起。
    @Published private(set) var breakRunner: BreakFlowRunner?
    var isBreakMode: Bool { breakRunner != nil }
    private var boardBeforeBreak: BoardSnapshot?
    private var breakChangeForwarder: AnyCancellable?

    /// 进入开球模式：存当前桌面 → 清约束与解 → 摆架。
    func startBreakFlow(game: RackGame) {
        guard !isPlaying, breakRunner == nil else { return }
        activeTool = .none
        boardBeforeBreak = currentSnapshot()
        selectedTargetKey = nil
        selectedPocketIndex = -1
        clearConstraint()
        invalidateSolutions()
        scene.clearResultNodes(nodes: &selectionNodes)
        scene.hideAllVisualization()   // 假想球等持久可视化节点不在 selectionNodes 内
        scene.hideCueStick()
        let runner = BreakFlowRunner(scene: scene, game: game)
        // K6 / D-v8-3a：与 FreePlay 对齐——停稳后取消/重开/完成三态，不自动落座。
        runner.autoDeliverOnSettle = false
        breakChangeForwarder = runner.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
        runner.onSettled = { [weak self] board in
            guard let self else { return }
            self.teardownBreakFlow()
            self.loadBoard(board)
        }
        breakRunner = runner
        runner.rackUp()
    }

    /// 取消开球模式并恢复进场前桌面。
    func cancelBreakFlow() {
        guard let runner = breakRunner else { return }
        runner.cancel()
        let restore = boardBeforeBreak
        teardownBreakFlow()
        if let restore, !restore.onTable.isEmpty {
            loadBoard(restore)
        } else {
            clearTable()
        }
    }

    private func teardownBreakFlow() {
        breakRunner = nil
        breakChangeForwarder = nil
        boardBeforeBreak = nil
    }
}
