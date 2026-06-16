import Foundation
import SceneKit
import SwiftUI

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

    /// 约束草稿（归一化系）。
    enum Draft {
        case region(SolveRegion)
        case restPoint(CanvasPoint)
        case passPoint(CanvasPoint)
    }

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
    /// 再叠加「禁左右塞」（spinX 降为单值 0，精修自动锁横塞）与「仅基础走位」（吃库上限 1）。
    /// 默认两开关均放开 ⇒ 与基底完全一致（零行为变化）。
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

    // MARK: - Solution display

    func nextSolution() {
        guard !solutions.isEmpty else { return }
        currentIndex = (currentIndex + 1) % solutions.count
        showSolution(at: currentIndex)
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
        let advanced = sol.beyondCushionBudget ? "进阶（超基础走位）· " : ""
        if !sol.satisfiesConstraint {
            return prefix + advanced + "最接近解（未满足约束）· " + sol.summary
        }
        return prefix + advanced + sol.summary
    }

    // MARK: - Trajectory + constraint rendering

    private func drawTrajectory(_ p: ShotPrediction, shot: PlannedShot) {
        clearTrajectory()
        guard p.feasible else { scene.hideCueStick(); return }
        addPolyline(p.cuePath, color: TrajectoryStyle.aimColor, radius: TrajectoryStyle.aimRadius)
        var objPath = p.objectPath
        if p.objectPocketed, let pocketIndex = ShotIntent.pocketIndex(for: shot.pocket) {
            objPath = PositionPlayShotSolver.extendPathToPocketRim(objPath, pocketIndex: pocketIndex, surfaceY: surfaceY)
        }
        addPolyline(objPath, color: TrajectoryStyle.potColor(for: shot.targetKey), radius: TrajectoryStyle.potRadius)
        for (key, pts) in p.extraBallPaths {
            addPolyline(pts, color: TrajectoryStyle.potColor(for: key, alpha: 0.85), radius: TrajectoryStyle.potRadius)
        }
        if let ghost = scene.ghostBallNode {
            ghost.position = SCNVector3(p.ghost.x, surfaceY + AngleSceneCalculator.ballRadius, p.ghost.z)
            ghost.isHidden = false
        }
    }

    private func addPolyline(_ pts: [SCNVector3], color: UIColor, radius: Float) {
        guard pts.count >= 2 else { return }
        for i in 0..<(pts.count - 1) {
            trajectoryNodes.append(scene.addLine(from: pts[i], to: pts[i + 1], color: color, radius: radius))
        }
    }

    private func clearTrajectory() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
        scene.hideAllVisualization()
    }

    /// 落区 / 过点叠加（青色，与轨迹区分）。
    private func renderConstraint() {
        clearConstraintNodes()
        let color = UIColor(red: 0.2, green: 0.85, blue: 0.95, alpha: 0.95)
        let y = surfaceY + 0.002
        switch draft {
        case .region(let region):
            switch region {
            case let .circle(center, radius):
                let c = AngleSceneCalculator.normalizedToScene(
                    point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                strokeCircle(center: c, radius: Float(radius) * SolveRegion.sceneScale,
                             color: color, into: &constraintNodes)
            case let .rect(center, hw, hh):
                let c = AngleSceneCalculator.normalizedToScene(
                    point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                let dx = Float(hw) * SolveRegion.sceneScale
                let dz = Float(hh) * SolveRegion.sceneScale
                strokeRect(center: c, halfX: dx, halfZ: dz, color: color, into: &constraintNodes)
            case let .point(center, tol):
                // 落区 draft 一般不携带 .point（落点走 .restPoint 草稿），此处兜底渲染容差环。
                let c = AngleSceneCalculator.normalizedToScene(
                    point: CGPoint(x: center.x, y: center.y), surfaceY: y)
                strokeCircle(center: c, radius: Float(tol) * SolveRegion.sceneScale,
                             color: color, into: &constraintNodes)
            }
        case .passPoint(let pt):
            let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: y)
            strokeCircle(center: c, radius: AngleSceneCalculator.ballRadius, color: color, into: &constraintNodes)
            // 十字标记。
            let r = AngleSceneCalculator.ballRadius * 1.6
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                                  to: SCNVector3(c.x + r, c.y, c.z), color: color, radius: 0.0022))
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                                  to: SCNVector3(c.x, c.y, c.z + r), color: color, radius: 0.0022))
        case .restPoint(let pt):
            // 落点：琥珀色十字（目标点）+ 容差环（命中半径），与青色落区/过点区分。
            let amber = UIColor(red: 1.0, green: 0.78, blue: 0.28, alpha: 0.95)
            let c = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: y)
            strokeCircle(center: c, radius: Float(pointTolerance) * SolveRegion.sceneScale,
                         color: amber, into: &constraintNodes)
            let r = AngleSceneCalculator.ballRadius * 1.4
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x - r, c.y, c.z),
                                                  to: SCNVector3(c.x + r, c.y, c.z), color: amber, radius: 0.0024))
            constraintNodes.append(scene.addLine(from: SCNVector3(c.x, c.y, c.z - r),
                                                  to: SCNVector3(c.x, c.y, c.z + r), color: amber, radius: 0.0024))
        case nil:
            break
        }
    }

    private func strokeCircle(center: SCNVector3, radius: Float, color: UIColor, into nodes: inout [SCNNode]) {
        let segments = 36
        var prev: SCNVector3?
        for i in 0...segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            let p = SCNVector3(center.x + radius * cosf(a), center.y, center.z + radius * sinf(a))
            if let pr = prev { nodes.append(scene.addLine(from: pr, to: p, color: color, radius: 0.0022)) }
            prev = p
        }
    }

    private func strokeRect(center: SCNVector3, halfX: Float, halfZ: Float, color: UIColor, into nodes: inout [SCNNode]) {
        let c = center
        let corners = [
            SCNVector3(c.x - halfX, c.y, c.z - halfZ), SCNVector3(c.x + halfX, c.y, c.z - halfZ),
            SCNVector3(c.x + halfX, c.y, c.z + halfZ), SCNVector3(c.x - halfX, c.y, c.z + halfZ)
        ]
        for i in 0..<4 {
            nodes.append(scene.addLine(from: corners[i], to: corners[(i + 1) % 4], color: color, radius: 0.0022))
        }
    }

    private func clearConstraintNodes() {
        scene.clearResultNodes(nodes: &constraintNodes)
    }

    // MARK: - Selection feedback + instant geometry preview

    /// 选中反馈：目标球绿色选中环（常驻）；无解时再叠加几何预览（假想球 + 瞄准线 + 进球线，
    /// 纯几何即时绘制，不跑物理），让「点球选目标 / 点袋选袋」立刻可见，无需先求解。
    private func refreshOverlays() {
        scene.clearResultNodes(nodes: &selectionNodes)
        guard !isPlaying else { return }
        let showingSolution = currentSolution != nil && !isComputing
        guard let tkey = selectedTargetKey,
              let tn = scene.allBallNodes[tkey], !tn.isHidden else {
            if !showingSolution { scene.ghostBallNode?.isHidden = true }
            return
        }
        // 目标球选中环（亮绿）。
        let ringColor = UIColor(red: 0.36, green: 0.92, blue: 0.55, alpha: 0.95)
        strokeCircle(center: tn.position, radius: AngleSceneCalculator.ballRadius * 1.75,
                     color: ringColor, into: &selectionNodes)

        // 已有解时由轨迹叠加负责其余渲染，这里只保留选中环。
        guard !showingSolution, selectedPocketIndex >= 0,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else { return }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        let aim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: tn.position, pocketIndex: selectedPocketIndex, surfaceY: surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: tn.position, pocket: aim, ballRadius: AngleSceneCalculator.ballRadius)
        // 瞄准线（母球→假想球，淡白）+ 进球线（目标球→袋口，随球色）。
        selectionNodes.append(scene.addLine(from: cue.position, to: ghost,
                                            color: UIColor.white.withAlphaComponent(0.45),
                                            radius: TrajectoryStyle.aimRadius))
        selectionNodes.append(scene.addLine(from: tn.position, to: pockets[selectedPocketIndex],
                                            color: TrajectoryStyle.potColor(for: tkey, alpha: 0.55),
                                            radius: TrajectoryStyle.aimRadius))
        if let g = scene.ghostBallNode {
            g.position = SCNVector3(ghost.x, surfaceY + AngleSceneCalculator.ballRadius, ghost.z)
            g.isHidden = false
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
        let r = AngleSceneCalculator.ballRadius
        guard let aim = lastAimDirection else { return cue }
        let perp = SCNVector3(-aim.z, 0, aim.x)
        let lateral = Float(spinX) * r
        return SCNVector3(cue.x + perp.x * lateral, cue.y, cue.z + perp.z * lateral)
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

    private enum Stroke {
        static let basePullBack: Float = 0.05
        static let pullBackPerSpeed: Float = 0.035
        static let backswingDuration: TimeInterval = 0.5
        static let pauseDuration: TimeInterval = 0.12
    }

    func play() {
        guard canStrike, let sol = currentSolution,
              let recorder = sol.prediction.recorder,
              let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = lastAimDirection ?? aimDirection(path: sol.prediction.cuePath, from: cueNode.position)
        else { return }

        isPlaying = true
        statusText = "运杆…"
        clearConstraintNodes()
        runStrokeAnimation(aim: aim, cue: cueNode.position, velocity: Float(sol.shot.velocity)) { [weak self] in
            self?.launchBalls(sol: sol, recorder: recorder)
        }
    }

    private func runStrokeAnimation(aim: SCNVector3, cue: SCNVector3,
                                    velocity: Float, completion: @escaping () -> Void) {
        guard let stickNode = scene.cueStick?.rootNode else { completion(); return }
        let strikePos = strikePosition(cue: cue)
        let v = max(0.3, velocity)
        let d = Stroke.basePullBack + Stroke.pullBackPerSpeed * v
        let accel = v * v / (2 * d)
        let forwardTime = TimeInterval(2 * d / v)
        let total = Stroke.backswingDuration + Stroke.pauseDuration + forwardTime
        let scene = self.scene
        scene.updateCueStick(cueBallPosition: strikePos, aimDirection: aim, pullBack: 0)
        let backswing = Stroke.backswingDuration
        let pause = Stroke.pauseDuration
        let stroke = SCNAction.customAction(duration: total) { _, elapsed in
            let t = TimeInterval(elapsed)
            let pull: Float
            if t < backswing {
                let u = Float(t / backswing)
                pull = d * (u * u * (3 - 2 * u))
            } else if t < backswing + pause {
                pull = d
            } else {
                let dt = Float(t - backswing - pause)
                pull = max(0, d - 0.5 * accel * dt * dt)
            }
            scene.updateCueStick(cueBallPosition: strikePos, aimDirection: aim, pullBack: pull)
        }
        stickNode.runAction(stroke, forKey: "strokeAnim") {
            Task { @MainActor in completion() }
        }
    }

    private func launchBalls(sol: PositionPlaySolution, recorder: TrajectoryRecorder) {
        statusText = "击球中…"
        clearTrajectory()
        scene.hideCueStick()
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let speed: Float = 1.0
        ShotAudioScheduler.shared.play(prediction: sol.prediction)
        var cueAction: SCNAction?
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let name = PositionPlayShotSolver.predName(boardKey: key, shot: sol.shot)
            let action = playback.action(for: node, ballName: name, speed: speed, removeOnPocket: false)
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
        clearTrajectory()
        clearConstraintNodes()
        scene.hideCueStick()
        resetParamDisplay()
        refreshOverlays()

        let cueGone = scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true
        statusText = cueGone
            ? "母球进袋（scratch）· 重新摆母球或「恢复默认」"
            : "已击打 · 母球停在终点，可继续画约束再求解"
    }

    // MARK: - Export (单步序列送生产管线，模拟器限定)

    /// 把当前解组装成单步走位序列。nil = 无可导出解。
    func makeExportSequence() -> PositionPlaySequence? {
        guard let sol = currentSolution, sol.prediction.feasible else { return nil }
        let before = currentSnapshot()
        let potted = Set(sol.prediction.pocketedBalls.map { boardKey(forPredName: $0, shot: sol.shot) })
        var afterDict: [String: CanvasPoint] = [:]
        for key in before.onTable.keys where !potted.contains(key) {
            let predN = PositionPlayShotSolver.predName(boardKey: key, shot: sol.shot)
            if let p = sol.prediction.finalPositions[predN] {
                let n = AngleSceneCalculator.sceneToNormalized(position: p)
                afterDict[key] = CanvasPoint(x: Double(n.x), y: Double(n.y))
            } else {
                afterDict[key] = before.onTable[key]
            }
        }
        let step = SequenceStep(
            before: before, shot: sol.shot, after: BoardSnapshot(onTable: afterDict),
            potted: Array(potted), cuePocketed: sol.prediction.cuePocketed,
            objectPocketed: sol.prediction.objectPocketed,
            note: sol.summary)
        return PositionPlaySequence(name: "思路训练-\(PositionPlayBall.shortLabel(for: sol.shot.targetKey))号",
                                    initial: before, steps: [step])
    }

    private func boardKey(forPredName name: String, shot: PlannedShot) -> String {
        if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
        if name == ShotInput.targetBallName { return shot.targetKey }
        return name
    }

    // MARK: - Reset

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
}
