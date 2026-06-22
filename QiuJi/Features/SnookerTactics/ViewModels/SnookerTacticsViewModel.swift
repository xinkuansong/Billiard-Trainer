import Foundation
import SceneKit
import SwiftUI

/// 做斯诺克战术工具 ViewModel（安全球反解，ADR-P16-01）。
///
/// 独立页面、布局参考思路训练器（`SiluTrainerViewModel`），但语义是**防守/安全球**：摆球后选一颗
/// **目标球**（这一杆要合法首触、且要把对手困住的球）+ 一颗**指定障碍球**，由 `PositionPlaySolver.solveSnooker`
/// 反解出塞/力度/瞄准，使击球后母球合法碰到目标球、不进袋，并停在「从母球看目标球的视线被障碍球完全挡死」
/// 的位置。结果默认显示最优解、可「下一解」翻档；塞/力度控件为只读指示器。
///
/// 坐标契约：摆球快照为归一化系（x∈[0,1]、y∈[0,0.5]）；几何遮挡判定在 SceneKit 世界系 X–Z（见
/// `AngleSceneCalculator.snookerCoverage`）。自由球命名沿用 board key（母球 `cueBall`），与 `predName` 一致。
@MainActor
final class SnookerTacticsViewModel: ObservableObject {

    // MARK: - Tools

    enum Tool: Equatable {
        /// 摆球（拖动 / 球库增删）。
        case none
        /// 点选目标球（首触 + 被困）。
        case selectTarget
        /// 点选障碍球（指定遮挡）。
        case selectBlocker
    }

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var trajectoryNodes: [SCNNode] = []
    private var overlayNodes: [SCNNode] = []

    // MARK: - Published board / selection

    @Published private(set) var onTableKeys: [String] = []
    @Published private(set) var selectedTargetKey: String?
    @Published private(set) var selectedBlockerKey: String?

    var paletteKeys: [String] {
        PositionPlayBall.allKeys.filter { !onTableKeys.contains($0) }
    }

    // MARK: - Published tool state

    @Published var activeTool: Tool = .none {
        didSet { if oldValue != activeTool { statusText = toolHint() } }
    }

    /// 两颗角色球都选齐才能求解。
    var hasConstraint: Bool { selectedTargetKey != nil && selectedBlockerKey != nil }

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
    @Published private(set) var statusText = "拖动摆球 · 选「目标球」（青环）与「障碍球」（红环），再点求解"

    var currentSolution: PositionPlaySolution? {
        guard solutions.indices.contains(currentIndex) else { return nil }
        return solutions[currentIndex]
    }
    var hasSolutions: Bool { !solutions.isEmpty }
    var canStrike: Bool {
        !isPlaying && !isComputing && (currentSolution?.prediction.feasible ?? false)
            && (currentSolution?.prediction.duration ?? 0) > 0.05
    }

    // MARK: - Internals

    private var lastAimDirection: SCNVector3?
    private let solveQueue = DispatchQueue(label: "com.qiuji.snooker-solve", qos: .userInitiated)
    private var solveGeneration = 0
    private var surfaceY: Float { scene.surfaceY }

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
        place(key: PositionPlayBall.cueKey, normalized: CanvasPoint(x: 0.24, y: 0.32))
        place(key: "_1", normalized: CanvasPoint(x: 0.74, y: 0.17))
        place(key: "_8", normalized: CanvasPoint(x: 0.52, y: 0.27))
        refreshOnTableKeys()
        selectedTargetKey = "_1"
        selectedBlockerKey = "_8"
        refreshOverlays()
    }

    /// 载入外部球形（如「拍照建球形」快照）。
    func loadBoard(_ snapshot: BoardSnapshot) {
        guard !isPlaying, !snapshot.onTable.isEmpty else { return }
        scene.hideAllBalls()
        for (key, pt) in snapshot.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()
        selectedTargetKey = nil
        selectedBlockerKey = nil
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
        assignDefaultRoleIfNeeded(key)
        invalidateSolutions()
    }

    func placeFromPalette(_ key: String, atWorld world: SCNVector3) {
        guard !isPlaying, let node = scene.allBallNodes[key] else { return }
        let clamped = clampMultiBall(world, movingNode: node)
        let n = AngleSceneCalculator.sceneToNormalized(position: clamped)
        place(key: key, normalized: CanvasPoint(x: Double(n.x), y: Double(n.y)))
        refreshOnTableKeys()
        assignDefaultRoleIfNeeded(key)
        invalidateSolutions()
    }

    /// 新摆上的非母球：若目标/障碍尚缺，自动补位（先目标后障碍），降低首用门槛。
    private func assignDefaultRoleIfNeeded(_ key: String) {
        guard !PositionPlayBall.isCue(key) else { return }
        if selectedTargetKey == nil, key != selectedBlockerKey {
            selectedTargetKey = key
        } else if selectedBlockerKey == nil, key != selectedTargetKey {
            selectedBlockerKey = key
        }
    }

    func removeFromTable(_ key: String) {
        guard !isPlaying else { return }
        scene.hideBall(key: key)
        if selectedTargetKey == key { selectedTargetKey = nil }
        if selectedBlockerKey == key { selectedBlockerKey = nil }
        refreshOnTableKeys()
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

    /// 点球：按当前工具设为目标 / 障碍。同一颗不能既是目标又是障碍（自动让位）。
    func selectBall(node: SCNNode) {
        guard let key = scene.ballKey(for: node) else { return }
        guard !isPlaying, onTableKeys.contains(key), !PositionPlayBall.isCue(key) else { return }
        switch activeTool {
        case .selectTarget:
            selectedTargetKey = key
            if selectedBlockerKey == key { selectedBlockerKey = nil }
        case .selectBlocker:
            selectedBlockerKey = key
            if selectedTargetKey == key { selectedTargetKey = nil }
        case .none:
            return
        }
        refreshOverlays()
        invalidateSolutions()
    }

    func clearSelection() {
        selectedTargetKey = nil
        selectedBlockerKey = nil
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
        statusText = hasConstraint ? "已就绪，点「求解」反解做斯诺克" : toolHint()
    }

    private func resetParamDisplay() {
        velocity = 2.5; spinX = 0; spinY = 0
    }

    func solve() {
        guard !isPlaying else { return }
        guard let targetKey = selectedTargetKey, let blockerKey = selectedBlockerKey else {
            statusText = needsSetupHint()
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
                before: before, targetKey: targetKey, blockerKey: blockerKey,
                surfaceY: y, params: params)
            DispatchQueue.main.async {
                guard let self, self.solveGeneration == gen, !self.isPlaying else { return }
                self.isComputing = false
                self.solutions = result
                self.currentIndex = 0
                if result.isEmpty {
                    self.statusText = "未找到斯诺克解（试着移动障碍球到母球与目标球之间，或换障碍球）"
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

    private func solutionStatus(_ sol: PositionPlaySolution) -> String {
        let prefix = solutions.count > 1 ? "解 \(currentIndex + 1)/\(solutions.count) · " : ""
        let advanced = sol.beyondCushionBudget ? "进阶（超基础走位）· " : ""
        if !sol.satisfiesConstraint {
            return prefix + advanced + "最接近解（未完全挡死）· " + sol.summary
        }
        return prefix + advanced + sol.summary
    }

    // MARK: - Trajectory + overlay rendering

    private func drawTrajectory(_ p: ShotPrediction, shot: PlannedShot) {
        clearTrajectory()
        guard p.feasible else { scene.hideCueStick(); return }
        addPolyline(p.cuePath, color: TrajectoryStyle.aimColor, radius: TrajectoryStyle.aimRadius)
        for (key, pts) in p.extraBallPaths {
            addPolyline(pts, color: TrajectoryStyle.potColor(for: key, alpha: 0.85), radius: TrajectoryStyle.potRadius)
        }
        scene.ghostBallNode?.isHidden = true
        if UserPreferences.shared.showSeparationAngle {
            scene.addSeparationAngleLine(for: p, into: &trajectoryNodes)
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

    /// 点击球库中「已在桌上」的球时，对应桌上球做一次放大→恢复脉冲提示位置（#5a）。
    func pulseTableBall(_ key: String) {
        guard !isPlaying, let node = scene.allBallNodes[key], !node.isHidden else { return }
        node.removeAction(forKey: "libraryPulse")
        let up = SCNAction.scale(to: 1.7, duration: 0.18); up.timingMode = .easeOut
        let down = SCNAction.scale(to: 1.0, duration: 0.24); down.timingMode = .easeIn
        node.runAction(SCNAction.sequence([up, down]), forKey: "libraryPulse")
    }

    /// 角色环 + 斯诺克遮挡可视化。无解时画当前摆位的角色环；有解时画三球**终位**的遮挡视线
    /// （完全挡死 = 灰视线，半斯诺克 = 红视线）+ 障碍球终位红环 + 母球终位白环。
    private func refreshOverlays() {
        scene.clearResultNodes(nodes: &overlayNodes)
        guard !isPlaying else { return }
        let cyan = UIColor(red: 0.2, green: 0.85, blue: 0.95, alpha: 0.95)
        let red = UIColor(red: 0.98, green: 0.36, blue: 0.34, alpha: 0.95)
        let r = AngleSceneCalculator.ballRadius

        if let sol = currentSolution, sol.prediction.feasible, !isComputing,
           let finalC = sol.prediction.finalPositions[ShotInput.cueBallName],
           let tkey = selectedTargetKey, let bkey = selectedBlockerKey,
           let finalT = sol.prediction.finalPositions[tkey],
           let finalB = sol.prediction.finalPositions[bkey] {
            // 终位遮挡视线。
            let lineColor = sol.satisfiesConstraint
                ? UIColor(white: 0.7, alpha: 0.85) : red
            overlayNodes.append(scene.addLine(from: finalC, to: finalT, color: lineColor,
                                              radius: TrajectoryStyle.aimRadius))
            strokeCircle(center: finalB, radius: r * 1.55, color: red)        // 障碍终位
            strokeCircle(center: finalT, radius: r * 1.55, color: cyan)       // 目标终位
            strokeCircle(center: finalC, radius: r * 1.4, color: UIColor(white: 0.92, alpha: 0.9)) // 母球终位
            return
        }

        // 无解 / 编辑态：画当前摆位的角色环。
        if let tkey = selectedTargetKey, let tn = scene.allBallNodes[tkey], !tn.isHidden {
            strokeCircle(center: tn.position, radius: r * 1.75, color: cyan)
        }
        if let bkey = selectedBlockerKey, let bn = scene.allBallNodes[bkey], !bn.isHidden {
            strokeCircle(center: bn.position, radius: r * 1.75, color: red)
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
        isPlaying = true
        statusText = "运杆…"
        scene.clearResultNodes(nodes: &overlayNodes)
        let strikePos = strikePosition(cue: cueNode.position)
        scene.runCueStroke(strikePosition: strikePos, aim: aim, velocity: Float(sol.shot.velocity)) { [weak self] in
            self?.launchBalls(sol: sol, recorder: recorder)
        }
    }

    private func launchBalls(sol: PositionPlaySolution, recorder: TrajectoryRecorder) {
        statusText = "击球中…"
        clearTrajectory()
        // 收杆不在此处：触球后球杆继续减速跟杆 + 停留一拍再消失（由 `runCueStroke` 接管）。
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        // #11：按「感知静止时刻」截断，避免击球态在球看着停后仍滞留数秒。
        let settle = playback.perceptibleSettleTime()
        ShotAudioScheduler.shared.play(prediction: sol.prediction)
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
        if let b = selectedBlockerKey, !onTableKeys.contains(b) { selectedBlockerKey = nil }

        solveGeneration += 1
        solutions = []
        currentIndex = 0
        clearTrajectory()
        scene.hideCueStick()
        resetParamDisplay()
        refreshOverlays()

        let cueGone = scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true
        statusText = cueGone
            ? "母球进袋（scratch）· 重新摆母球或「恢复默认」"
            : "已击打 · 母球停在终点，可重选角色再求解"
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
        return PositionPlaySequence(name: "做斯诺克-\(label)号", initial: before, steps: [step])
    }

    // MARK: - Reset

    func clearTable() {
        guard !isPlaying else { return }
        scene.hideAllBalls()
        selectedTargetKey = nil
        selectedBlockerKey = nil
        refreshOnTableKeys()
        invalidateSolutions()
    }

    func resetAll() {
        guard !isPlaying else { return }
        scene.hideAllBalls()
        applyDefaultLayout()
        invalidateSolutions()
    }

    // MARK: - Hints

    private func toolHint() -> String {
        switch activeTool {
        case .none: return "拖动摆球 · 选「目标球」（青环）与「障碍球」（红环），再点求解"
        case .selectTarget: return "点选一颗目标球（这一杆要碰、且要困住对手的球）"
        case .selectBlocker: return "点选一颗障碍球（用它把目标球挡住）"
        }
    }

    private func needsSetupHint() -> String {
        if scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true { return "请先把母球摆上桌" }
        if selectedTargetKey == nil { return "用「目标球」工具点选一颗目标球" }
        if selectedBlockerKey == nil { return "用「障碍球」工具点选一颗障碍球" }
        return "已就绪，点「求解」反解做斯诺克"
    }
}
