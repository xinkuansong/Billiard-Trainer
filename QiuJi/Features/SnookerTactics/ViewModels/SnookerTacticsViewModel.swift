import Foundation
import SceneKit
import SwiftUI

/// 防守战术工具 ViewModel（安全球反解，ADR-P16-01；V8 中八语义重做）。
///
/// 独立页面、布局参考思路训练器（`SiluTrainerViewModel`），语义是**防守/安全球**：摆球后只选一颗
/// **目标球**（我方将合法首触的球），系统按**中八规则**推断防守对象——击打目标球后让**对方球组**
/// （目标全色 1–7 则对方=花色 9–15，反之；对方组清空只剩 8 号则防 8 号）全部/尽量不可见。
/// 由 `PositionPlaySolver.solveSnooker` 反解出塞/力度/瞄准，使击球后母球合法碰到目标球、不进袋、
/// 并停在「对方球组视线被其它球挡死（完全斯诺克）或只剩长台/大切角（高难度可行解）」的位置。
/// 结果默认显示最优解、可「下一解」翻档；塞/力度控件为只读指示器。
///
/// 规则：台面同时存在全色与花色时**不得以 8 号为目标球**（选球拦截 + 提示，对齐
/// `BilliardRulesEngine.legalTargetKeys` 中八首触语义）。
///
/// 坐标契约：摆球快照为归一化系（x∈[0,1]、y∈[0,0.5]）；几何遮挡/可见性判定在 SceneKit 世界系
/// X–Z 平面、Y 朝上、单位米（见 `AngleSceneCalculator.defenseCoverage`/`snookerCoverage`）。
/// 自由球命名沿用 board key（母球 `cueBall`），与 `predName` 一致。
@MainActor
final class SnookerTacticsViewModel: ObservableObject {

    // MARK: - Tools

    enum Tool: Equatable {
        /// 摆球（拖动 / 球库增删）。
        case none
        /// 点选目标球（我方将合法首触的球）。
        case selectTarget
    }

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var trajectoryNodes: [SCNNode] = []
    private var overlayNodes: [SCNNode] = []

    // MARK: - Published board / selection

    @Published private(set) var onTableKeys: [String] = []
    @Published private(set) var selectedTargetKey: String?

    var paletteKeys: [String] {
        PositionPlayBall.allKeys.filter { !onTableKeys.contains($0) }
    }

    // MARK: - 中八规则：对方球组推断 + 8 号目标拦截（对齐 legalTargetKeys 语义）

    /// 目标球所属组的**对方球组**在桌球键（中八）：
    /// - 目标全色（1–7）→ 对方 = 在桌花色（9–15）；花色已清空 → 只剩 8 号则防 8 号；
    /// - 目标花色 → 对方 = 在桌全色；全色已清空 → 只剩 8 号则防 8 号；
    /// - 目标 8 号（仅单组在桌时合法）→ 对方 = 在桌的那一组。
    var opponentKeys: [String] {
        guard let t = selectedTargetKey else { return [] }
        return Self.opponentKeys(for: t, onTable: onTableKeys)
    }

    nonisolated static func opponentKeys(for targetKey: String, onTable: [String]) -> [String] {
        let solids = onTable.filter { BallGroup.of($0) == .solid }.sorted()
        let stripes = onTable.filter { BallGroup.of($0) == .stripe }.sorted()
        let hasEight = onTable.contains("_8")
        switch BallGroup.of(targetKey) {
        case .solid:  return stripes.isEmpty ? (hasEight ? ["_8"] : []) : stripes
        case .stripe: return solids.isEmpty ? (hasEight ? ["_8"] : []) : solids
        case .eight:
            if !solids.isEmpty { return solids }
            if !stripes.isEmpty { return stripes }
            return []
        case .none:   return []
        }
    }

    /// 该球是否可作目标球（中八首触合法性拦截，对齐 `legalTargetKeys`）：
    /// 母球/非法键不可；台面**同时**存在全色与花色时 8 号不可（须先清本方组）。
    nonisolated static func canTarget(_ key: String, onTable: [String]) -> Bool {
        guard !PositionPlayBall.isCue(key), BallGroup.of(key) != nil else { return false }
        if BallGroup.of(key) == .eight {
            let hasSolid = onTable.contains { BallGroup.of($0) == .solid }
            let hasStripe = onTable.contains { BallGroup.of($0) == .stripe }
            return !(hasSolid && hasStripe)
        }
        return true
    }

    /// 目标球已选、且推断出至少一颗对方球，方可求解。
    var canSolve: Bool { selectedTargetKey != nil && !opponentKeys.isEmpty }

    // MARK: - Published solve options（与思路训练器同口径，默认完整能力）

    @Published var allowSideSpin: Bool = true {
        didSet { if oldValue != allowSideSpin { invalidateSolutions() } }
    }
    @Published var basicPositionOnly: Bool = false {
        didSet { if oldValue != basicPositionOnly { invalidateSolutions() } }
    }

    // MARK: - Published shot params（当前解的只读指示）

    @Published private(set) var velocity: Double = 2.5
    @Published private(set) var spinX: Double = 0
    @Published private(set) var spinY: Double = 0

    // MARK: - Published solve state

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    @Published private(set) var isPlaying = false
    @Published private(set) var isComputing = false
    @Published private(set) var solutions: [PositionPlaySolution] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var statusText = "拖动摆球 · 选一颗「目标球」（我方要打的球），再点求解"

    var currentSolution: PositionPlaySolution? {
        guard solutions.indices.contains(currentIndex) else { return nil }
        return solutions[currentIndex]
    }
    var hasSolutions: Bool { !solutions.isEmpty }
    var canStrike: Bool {
        !isPlaying && !isComputing && (currentSolution?.prediction.feasible ?? false)
            && (currentSolution?.prediction.duration ?? 0) > 0.05
    }

    // MARK: - Published tool state

    @Published var activeTool: Tool = .none {
        didSet { if oldValue != activeTool { statusText = toolHint() } }
    }

    // MARK: - Internals

    private var lastAimDirection: SCNVector3?
    private let solveQueue = DispatchQueue(label: "com.qiuji.snooker-solve", qos: .userInitiated)
    private var solveGeneration = 0
    private var surfaceY: Float { scene.surfaceY }

    // MARK: - Last shot（G17：上一杆完整恢复 / 回放）

    /// 防守页「上一杆」完整上下文 = 共享求解快照（`SolveShotSnapshot`，V3 落地）+ 本页选择模型（目标球）。
    /// 上一杆 = 回到击打前**完整状态**（球形 + 目标球 + 解集缓存 + 打点/力度/瞄准 + 求解选项，免重解）。
    /// （internal：供单测直接验证「快照→恢复」逐字段一致。）
    struct UndoContext {
        var snapshot: SolveShotSnapshot
        var selectedTargetKey: String?
    }
    private var lastShotContext: UndoContext?
    @Published private(set) var canUndoShot = false
    @Published private(set) var canPlayback = false

    // MARK: - Setup

    func setupScene() {
        scene.setupScene()
        scene.setupVisualizationNodes()
        _ = scene.addPocketMarkers()
        scene.hideAllBalls()
        scene.hideCueStick()
        scene.cameraRig?.topDownPanOffset = .zero
        applyDefaultLayout()
    }

    private func applyDefaultLayout() {
        // 双组在桌的示例局：全色 _1/_2 + 花色 _9/_10。默认目标 = _1（全色）⇒ 防花色组。
        place(key: PositionPlayBall.cueKey, normalized: CanvasPoint(x: 0.22, y: 0.30))
        place(key: "_1", normalized: CanvasPoint(x: 0.54, y: 0.20))
        place(key: "_2", normalized: CanvasPoint(x: 0.40, y: 0.35))
        place(key: "_9", normalized: CanvasPoint(x: 0.72, y: 0.16))
        place(key: "_10", normalized: CanvasPoint(x: 0.80, y: 0.32))
        refreshOnTableKeys()
        selectedTargetKey = "_1"
        refreshOverlays()
    }

    /// 载入外部球形（如「拍照建球形」快照）。
    func loadBoard(_ snapshot: BoardSnapshot) {
        guard !isPlaying, !snapshot.onTable.isEmpty else { return }
        scene.hideAllBalls()
        for (key, pt) in snapshot.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()
        selectedTargetKey = nil
        autoSelectTarget()
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
        assignTargetIfNeeded(key)
        invalidateSolutions()
    }

    func placeFromPalette(_ key: String, atWorld world: SCNVector3) {
        guard !isPlaying, let node = scene.allBallNodes[key] else { return }
        let clamped = clampMultiBall(world, movingNode: node)
        let n = AngleSceneCalculator.sceneToNormalized(position: clamped)
        place(key: key, normalized: CanvasPoint(x: Double(n.x), y: Double(n.y)))
        refreshOnTableKeys()
        assignTargetIfNeeded(key)
        invalidateSolutions()
    }

    /// 新摆上的球：若尚无目标球且该球可作合法目标（非母球、非双组在桌的 8 号），自动补为目标球。
    private func assignTargetIfNeeded(_ key: String) {
        guard selectedTargetKey == nil, Self.canTarget(key, onTable: onTableKeys) else { return }
        selectedTargetKey = key
    }

    func removeFromTable(_ key: String) {
        guard !isPlaying else { return }
        scene.hideBall(key: key)
        if selectedTargetKey == key { selectedTargetKey = nil }
        refreshOnTableKeys()
        // 目标球若非法（双组在桌残留 8 号目标）则清除。
        if let t = selectedTargetKey, !Self.canTarget(t, onTable: onTableKeys) { selectedTargetKey = nil }
        if selectedTargetKey == nil { autoSelectTarget() }
        invalidateSolutions()
    }

    private func place(key: String, normalized: CanvasPoint) {
        let scenePos = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: normalized.x, y: normalized.y), surfaceY: surfaceY)
        scene.showBall(key: key, scenePosition: scenePos)
    }

    /// 无目标球时自动选一颗合法目标（离母球最近者）。
    private func autoSelectTarget() {
        guard let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else {
            selectedTargetKey = nil
            return
        }
        let candidates = onTableKeys.filter { Self.canTarget($0, onTable: onTableKeys) }
        selectedTargetKey = candidates.min { a, b in
            distanceToCue(a, cue: cue.position) < distanceToCue(b, cue: cue.position)
        }
    }

    private func distanceToCue(_ key: String, cue: SCNVector3) -> Float {
        guard let node = scene.allBallNodes[key], !node.isHidden else { return .greatestFiniteMagnitude }
        return AngleSceneCalculator.horizontalDistance(cue, node.position)
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

    /// 点球：设为目标球。8 号在双组在桌时不可作目标（拦截 + 提示，对齐中八首触规则）。
    func selectBall(node: SCNNode) {
        guard let key = scene.ballKey(for: node) else { return }
        guard !isPlaying, onTableKeys.contains(key), !PositionPlayBall.isCue(key) else { return }
        guard activeTool == .selectTarget else { return }
        guard Self.canTarget(key, onTable: onTableKeys) else {
            statusText = "台面同时有全色与花色，不能选 8 号做目标球（须先清完本方组）"
            return
        }
        selectedTargetKey = key
        refreshOverlays()
        invalidateSolutions()
    }

    func clearSelection() {
        selectedTargetKey = nil
        refreshOverlays()
        invalidateSolutions()
        statusText = toolHint()
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
        statusText = canSolve ? readyHint() : toolHint()
    }

    private func resetParamDisplay() {
        velocity = 2.5; spinX = 0; spinY = 0
    }

    func solve() {
        guard !isPlaying else { return }
        guard let targetKey = selectedTargetKey else {
            statusText = needsSetupHint()
            return
        }
        let opponents = opponentKeys
        guard !opponents.isEmpty else {
            statusText = "没有需要隐藏的对方球（对方球组已空）"
            return
        }
        let before = currentSnapshot()
        let y = surfaceY
        var params = PositionPlaySolver.SnookerParams.standard
        if !allowSideSpin { params.spinXValues = [0] }
        params.maxCushions = basicPositionOnly ? 1 : nil
        solveGeneration += 1
        let gen = solveGeneration
        isComputing = true
        statusText = "求解中…"
        clearTrajectory()
        scene.hideCueStick()

        solveQueue.async { [weak self] in
            let result = PositionPlaySolver.solveSnooker(
                before: before, targetKey: targetKey, opponentKeys: opponents,
                surfaceY: y, params: params)
            DispatchQueue.main.async {
                guard let self, self.solveGeneration == gen, !self.isPlaying else { return }
                self.isComputing = false
                self.solutions = result
                self.currentIndex = 0
                if result.isEmpty {
                    self.statusText = "未找到可行防守解（母球难以合法碰目标球并停稳；试着移动母球/目标球）"
                    self.resetParamDisplay()
                    self.refreshOverlays()
                } else {
                    self.showSolution(at: 0)
                }
            }
        }
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
        refreshOverlays()
    }

    /// 三档轨迹标注切换后重绘当前解（`BTTrajectoryDetailChip` 触发，条 12.5）。
    func redrawTrajectory() {
        guard !isPlaying, let sol = currentSolution else { return }
        drawTrajectory(sol.prediction, shot: sol.shot)
    }

    private func solutionStatus(_ sol: PositionPlaySolution) -> String {
        let prefix = solutions.count > 1 ? "解 \(currentIndex + 1)/\(solutions.count) · " : ""
        let advanced = sol.beyondCushionBudget ? "进阶（超基础走位）· " : ""
        if !sol.satisfiesConstraint {
            return prefix + advanced + "高难度可行解（未完全斯诺克）· " + sol.summary
        }
        return prefix + advanced + sol.summary
    }

    // MARK: - Trajectory + overlay rendering

    private func drawTrajectory(_ p: ShotPrediction, shot: PlannedShot) {
        clearTrajectory()
        guard p.feasible else { scene.hideCueStick(); return }
        let detail = UserPreferences.shared.trajectoryDetail
        scene.addCueTrajectory(p.cuePath, contact: p.firstContact, detail: detail,
                               into: &trajectoryNodes)
        if detail != .minimal {
            for (key, pts) in p.extraBallPaths {
                if detail == .core, key != shot.targetKey { continue }
                scene.addObjectTrajectory(pts, ballKey: key, into: &trajectoryNodes)
            }
        }
        if let ghostCenter = p.firstContact, let ghost = scene.ghostBallNode,
           let target = scene.allBallNodes[shot.targetKey], !target.isHidden {
            ghost.position = SCNVector3(ghostCenter.x,
                                        surfaceY + AngleSceneCalculator.ballRadius,
                                        ghostCenter.z)
            ghost.isHidden = false
            scene.updateContactDot(ghostCenter: ghost.position, targetCenter: target.position)
        } else {
            scene.ghostBallNode?.isHidden = true
        }
        if UserPreferences.shared.showSeparationAngle {
            scene.addSeparationAngleLine(for: p, into: &trajectoryNodes)
        }
    }

    private func clearTrajectory() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
        scene.hideAllVisualization()
    }

    /// 点击球库中「已在桌上」的球时，对应桌上球做一次放大→恢复脉冲提示位置（#5a）。
    func pulseTableBall(_ key: String) {
        guard !isPlaying, let node = scene.allBallNodes[key], !node.isHidden else { return }
        node.removeAction(forKey: "libraryPulse")
        let up = SCNAction.scale(to: 1.7, duration: 0.18); up.timingMode = .easeOut
        let down = SCNAction.scale(to: 1.0, duration: 0.24); down.timingMode = .easeIn
        node.runAction(SCNAction.sequence([up, down]), forKey: "libraryPulse")
    }

    /// 角色环 + 防守可见性可视化。
    /// - 有解时：画母球终位（白环）+ 目标球终位（青环）+ 对每颗对方球终位画视线——
    ///   被挡死 = 灰视线 + 灰环；仍可见 = 红视线 + 红环。
    /// - 编辑态：目标球青环 + 对方球组红环（提示要隐藏谁）。
    private func refreshOverlays() {
        scene.clearResultNodes(nodes: &overlayNodes)
        guard !isPlaying else { return }
        let cyan = UIColor(red: 0.2, green: 0.85, blue: 0.95, alpha: 0.95)
        let red = UIColor(red: 0.98, green: 0.36, blue: 0.34, alpha: 0.95)
        let gray = UIColor(white: 0.7, alpha: 0.85)
        let r = AngleSceneCalculator.ballRadius

        if let sol = currentSolution, sol.prediction.feasible, !isComputing,
           let finalC = sol.prediction.finalPositions[ShotInput.cueBallName] {
            // 击球后的对方球终位（剔除进袋球）+ 全部非母球终位（互相遮挡候选）。
            let potted = Set(sol.prediction.pocketedBalls)
            var finalNonCue: [(key: String, pos: SCNVector3)] = []
            for (name, pos) in sol.prediction.finalPositions
            where name != ShotInput.cueBallName && !potted.contains(name) {
                finalNonCue.append((name, pos))
            }
            let opponents = opponentKeys.compactMap { key -> (key: String, pos: SCNVector3)? in
                guard let hit = finalNonCue.first(where: { $0.key == key }) else { return nil }
                return (key, hit.pos)
            }
            let coverage = AngleSceneCalculator.defenseCoverage(
                cueFinal: finalC, opponents: opponents, nonCueBalls: finalNonCue, surfaceY: surfaceY)
            for c in coverage {
                guard let opp = opponents.first(where: { $0.key == c.key }) else { continue }
                let color = c.blocked ? gray : red
                overlayNodes.append(scene.addLine(from: finalC, to: opp.pos, color: color,
                                                  radius: TrajectoryStyle.aimRadius))
                strokeCircle(center: opp.pos, radius: r * 1.5, color: color)
            }
            if let tkey = selectedTargetKey, let finalT = finalNonCue.first(where: { $0.key == tkey })?.pos {
                strokeCircle(center: finalT, radius: r * 1.55, color: cyan)   // 目标球终位
            }
            strokeCircle(center: finalC, radius: r * 1.4, color: UIColor(white: 0.92, alpha: 0.9)) // 母球终位
            return
        }

        // 无解 / 编辑态：目标球青环 + 对方球组红环。
        if let tkey = selectedTargetKey, let tn = scene.allBallNodes[tkey], !tn.isHidden {
            strokeCircle(center: tn.position, radius: r * 1.75, color: cyan)
        }
        for okey in opponentKeys {
            guard let on = scene.allBallNodes[okey], !on.isHidden else { continue }
            strokeCircle(center: on.position, radius: r * 1.5, color: red)
        }
    }

    private func strokeCircle(center: SCNVector3, radius: Float, color: UIColor) {
        let segments = 36
        let y = surfaceY + 0.002
        var prev: SCNVector3?
        for i in 0...segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            let p = SCNVector3(center.x + radius * cosf(a), y, center.z + radius * sinf(a))
            if let pr = prev { overlayNodes.append(scene.addLine(from: pr, to: p, color: color, radius: 0.0022)) }
            prev = p
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

    // MARK: - Strike (运杆 + 回放，复用思路训练器模型)

    func play() {
        guard canStrike, let sol = currentSolution,
              let recorder = sol.prediction.recorder,
              let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = lastAimDirection ?? aimDirection(path: sol.prediction.cuePath, from: cueNode.position)
        else { return }
        // 记录上一杆上下文（G17）：击打前完整求解快照 + 本页选择模型（目标球），供上一杆完整恢复/回放。
        lastShotContext = makeUndoContext(shot: sol.shot, prediction: sol.prediction)
        canUndoShot = false
        canPlayback = false

        isPlaying = true
        statusText = "运杆…"
        scene.clearResultNodes(nodes: &overlayNodes)
        let strikePos = strikePosition(cue: cueNode.position)
        scene.runCueStroke(strikePosition: strikePos, aim: aim, velocity: Float(sol.shot.velocity)) { [weak self] in
            self?.launchBalls(sol: sol, recorder: recorder)
        }
    }

    /// 微调当前解（条 21.4 同规范）：改打点/力度后按新参数重预测替换当前解。
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
                    summary: "微调 · " + SiluSpinLabel.text(spinX: shot.spinX, spinY: shot.spinY)
                        + String(format: " · %.1f m/s", shot.velocity),
                    satisfiesConstraint: sol.satisfiesConstraint,
                    beyondCushionBudget: sol.beyondCushionBudget,
                    difficultyScore: DifficultyModel.score(
                        spinX: shot.spinX, spinY: shot.spinY, velocity: shot.velocity),
                    difficultyTier: DifficultyModel.tier(spinX: shot.spinX, spinY: shot.spinY),
                    beyondSpinBudget: sol.beyondSpinBudget
                )
                self.showSolution(at: idx)
            }
        }
    }

    /// 组装当前状态为「上一杆」完整上下文（击打前调用；`play()` 与单测共用同一处捕获逻辑）。
    func makeUndoContext(shot: PlannedShot, prediction: ShotPrediction) -> UndoContext {
        UndoContext(
            snapshot: SolveShotSnapshot(
                before: currentSnapshot(), shot: shot, prediction: prediction,
                solutions: solutions, currentIndex: currentIndex, draft: nil,
                velocity: velocity, spinX: spinX, spinY: spinY,
                allowSideSpin: allowSideSpin, basicPositionOnly: basicPositionOnly),
            selectedTargetKey: selectedTargetKey)
    }

    /// 把击打前完整快照原样恢复到场景与状态（G17，不重解）。
    func restore(from ctx: UndoContext) {
        let snap = ctx.snapshot
        scene.hideAllBalls()
        clearTrajectory()
        scene.clearResultNodes(nodes: &overlayNodes)
        scene.hideCueStick()
        for (key, pt) in snap.before.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()

        // 求解选项须先于 solutions 恢复（值不变时 didSet 不触发失效；随后回填的 solutions 覆盖任何失效）。
        allowSideSpin = snap.allowSideSpin
        basicPositionOnly = snap.basicPositionOnly

        // 选择模型（目标球）。
        selectedTargetKey = ctx.selectedTargetKey
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
            showSolution(at: currentIndex)   // 轨迹 + 球杆瞄准 + 防守叠加
        } else {
            refreshOverlays()
        }
    }

    /// 上一杆（G17）：回到上次击打前的**完整状态**——球形、目标球、已求出的解（缓存回填）、
    /// 打点/力度/瞄准、求解选项，均逐字段还原（无需重选、无需重求解）。
    func undoLastShot() {
        guard !isPlaying, canUndoShot, let ctx = lastShotContext else { return }
        restore(from: ctx)
        canUndoShot = false
        canPlayback = false
        lastShotContext = nil
        statusText = ctx.snapshot.solutions.isEmpty
            ? "已退回上一杆击打前 · 重选目标球"
            : "已退回上一杆击打前 · 球形/目标/解已还原"
    }

    /// 回放上一杆击打过程：退回击打前重播动画，播完回到击打后局面。
    func replayLastShot() {
        guard !isPlaying, canPlayback, let ctx = lastShotContext else { return }
        let snap = ctx.snapshot
        guard let recorder = snap.prediction.recorder, snap.prediction.duration > 0.05 else { return }
        let after = currentSnapshot()
        isPlaying = true
        clearTrajectory()
        scene.clearResultNodes(nodes: &overlayNodes)
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
        snapshot snap: SolveShotSnapshot,
        recorder: TrajectoryRecorder, after: BoardSnapshot
    ) {
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let settle = playback.duration   // G15：播到引擎自然静止（不做感知截断）

        var cueAction: SCNAction?
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let action = playback.action(for: node, ballName: predName(boardKey: key), speed: 1.0,
                                         removeOnPocket: false, maxSimTime: settle)
            if key == PositionPlayBall.cueKey { cueAction = action }
            else if let action { node.runAction(action) }
        }
        let tail: TimeInterval = snap.prediction.pocketedBalls.isEmpty
            ? 0 : TrajectoryPlayback.pocketSettleDuration + 0.1
        if let cueAction, let cueNode = scene.allBallNodes[PositionPlayBall.cueKey] {
            cueNode.runAction(cueAction) { [weak self] in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(tail * 1_000_000_000))
                    self?.finishPlayback(after: after)
                }
            }
            ShotAudioScheduler.shared.play(prediction: snap.prediction)
        } else {
            finishPlayback(after: after)
        }
    }

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
        lastShotContext = ctx
        canUndoShot = ctx != nil
        canPlayback = ctx != nil
        statusText = "回放结束 · 球停在击打后局面"
    }

    private func launchBalls(sol: PositionPlaySolution, recorder: TrajectoryRecorder) {
        statusText = "击球中…"
        clearTrajectory()
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        // G15：播到引擎自然静止（不做 0.07 感知截断），球停止前无最后一跳/瞬移。
        let settle = playback.duration
        var cueAction: SCNAction?
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let name = predName(boardKey: key)
            let action = playback.action(for: node, ballName: name, speed: 1.0,
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
            ShotAudioScheduler.shared.play(prediction: sol.prediction)
        } else {
            finishStrike(sol: sol)
        }
    }

    /// 自由球命名：母球 → 引擎母球名，其余 → board key（与 `simulateFree` / `PositionPlayShotSolver.predName` 一致）。
    private func predName(boardKey: String) -> String {
        boardKey == PositionPlayBall.cueKey ? ShotInput.cueBallName : boardKey
    }

    private func finishStrike(sol: PositionPlaySolution) {
        ShotAudioScheduler.shared.cancel()
        for key in onTableKeys { scene.allBallNodes[key]?.removeAllActions() }
        let potted = Set(sol.prediction.pocketedBalls.map { boardKey(forPredName: $0) })
        for key in potted { scene.hideBall(key: key) }
        if sol.prediction.cuePocketed { scene.hideBall(key: PositionPlayBall.cueKey) }

        isPlaying = false
        refreshOnTableKeys()
        if let t = selectedTargetKey, !onTableKeys.contains(t) { selectedTargetKey = nil }
        if let t = selectedTargetKey, !Self.canTarget(t, onTable: onTableKeys) { selectedTargetKey = nil }
        if selectedTargetKey == nil { autoSelectTarget() }

        solveGeneration += 1
        solutions = []
        currentIndex = 0
        clearTrajectory()
        scene.hideCueStick()
        resetParamDisplay()
        refreshOverlays()

        canUndoShot = lastShotContext != nil
        canPlayback = lastShotContext?.snapshot.prediction.recorder != nil

        let cueGone = scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true
        statusText = cueGone
            ? "母球进袋（scratch）· 重新摆母球或「恢复默认」"
            : "已击打 · 母球停在终点，可重选目标球再求解"
    }

    private func boardKey(forPredName name: String) -> String {
        name == ShotInput.cueBallName ? PositionPlayBall.cueKey : name
    }

    // MARK: - Export (单步序列送生产管线，模拟器限定)

    func makeExportSequence() -> PositionPlaySequence? {
        guard let sol = currentSolution, sol.prediction.feasible else { return nil }
        let before = currentSnapshot()
        let potted = Set(sol.prediction.pocketedBalls.map { boardKey(forPredName: $0) })
        var afterDict: [String: CanvasPoint] = [:]
        for key in before.onTable.keys where !potted.contains(key) {
            let predN = predName(boardKey: key)
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
            objectPocketed: sol.prediction.objectPocketed, note: sol.summary)
        let label = selectedTargetKey.map { PositionPlayBall.shortLabel(for: $0) } ?? "?"
        return PositionPlaySequence(name: "防守-\(label)号", initial: before, steps: [step])
    }

    // MARK: - Reset

    func clearTable() {
        guard !isPlaying else { return }
        scene.hideAllBalls()
        selectedTargetKey = nil
        refreshOnTableKeys()
        invalidateSolutions()
    }

    func resetAll() {
        guard !isPlaying else { return }
        scene.hideAllBalls()
        applyDefaultLayout()
        invalidateSolutions()
    }

    // MARK: - UITest 取证钩子（仅 launch arg 触发；生产不调用）

    /// 注入确定性盘面并求解，供 V8 三态截图取证（完全斯诺克 / 高难度可行解 / 诚实无解）。
    /// 盘面经 `SnookerSolverTests` 探针实测确认状态（`test_probe_scenarioBoards`，已删除）。
    func uiTestConfigure(_ scenario: String) {
        guard !isPlaying else { return }
        func setBoard(_ pts: [String: CanvasPoint], target: String) {
            scene.hideAllBalls()
            for (k, pt) in pts { place(key: k, normalized: pt) }
            refreshOnTableKeys()
            selectedTargetKey = target
            refreshOverlays()
            invalidateSolutions()
        }
        switch scenario {
        case "full":   // 完全斯诺克（对方花色 _9 全挡死）。
            setBoard([PositionPlayBall.cueKey: CanvasPoint(x: 0.30, y: 0.25),
                      "_1": CanvasPoint(x: 0.55, y: 0.25),
                      "_2": CanvasPoint(x: 0.50, y: 0.22),
                      "_9": CanvasPoint(x: 0.46, y: 0.19)], target: "_1")
            solve()
        case "partial":  // 无完全解 ⇒ 高难度可行解（三颗花色分散，挡死 2/3）。
            setBoard([PositionPlayBall.cueKey: CanvasPoint(x: 0.50, y: 0.08),
                      "_1": CanvasPoint(x: 0.50, y: 0.28),
                      "_9": CanvasPoint(x: 0.06, y: 0.40),
                      "_10": CanvasPoint(x: 0.94, y: 0.40),
                      "_11": CanvasPoint(x: 0.50, y: 0.46)], target: "_1")
            solve()
        case "none":   // 诚实无解：同伴球 _2 全遮目标球首触线，母球无法合法首触 _1。
            setBoard([PositionPlayBall.cueKey: CanvasPoint(x: 0.18, y: 0.25),
                      "_2": CanvasPoint(x: 0.28, y: 0.25),
                      "_1": CanvasPoint(x: 0.82, y: 0.25),
                      "_9": CanvasPoint(x: 0.60, y: 0.42)], target: "_1")
            solve()
        default:
            break   // clearkey / undo：保留默认球形。
        }
    }

    // MARK: - Hints

    private func toolHint() -> String {
        switch activeTool {
        case .none: return "拖动摆球 · 选一颗「目标球」（我方要打的球），再点求解"
        case .selectTarget: return "点选一颗目标球（我方将合法首触的球，系统按中八规则推断防守对方球组）"
        }
    }

    private func readyHint() -> String {
        let n = opponentKeys.count
        return "已就绪 · 将让对方 \(n) 球尽量看不到，点「求解」反解防守"
    }

    private func needsSetupHint() -> String {
        if scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true { return "请先把母球摆上桌" }
        if selectedTargetKey == nil { return "用「目标球」工具点选一颗目标球" }
        if opponentKeys.isEmpty { return "没有需要隐藏的对方球（对方球组已空）" }
        return readyHint()
    }
}
