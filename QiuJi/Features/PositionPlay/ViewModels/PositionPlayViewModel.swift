import Foundation
import SceneKit
import SwiftUI

/// 走位编排器 ViewModel（ADR-P11-01）。
///
/// 复用 `AngleTrainingScene`（USDZ 真台 + 16 颗现成球节点）与 `AngleSceneView` 的拖球/点选交互。
/// 自由摆球（母球 + 任意子集 1–15 号）→ 选目标球 + 袋口 → 调连续力度/打点 →
/// `ShotPredictor`（带 `obstacles`）**后台真实求解**单杆轨迹与母球走位 → 逐杆串成序列。
/// 进袋球离场回球库；母球 scratch 同样离场；任意 Step 可改摆并截断重录。
@MainActor
final class PositionPlayViewModel: ObservableObject {

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var pocketMarkers: [SCNNode] = []
    private var trajectoryNodes: [SCNNode] = []

    // MARK: - Published board / selection

    /// 当前在桌球键（顺序：母球优先，目标球按号）。
    @Published private(set) var onTableKeys: [String] = []
    @Published private(set) var selectedTargetKey: String?
    @Published var selectedPocketIndex: Int = -1

    // MARK: - Published shot params

    /// 连续杆头速度 (m/s)。
    @Published var velocity: Double = 3.3 { didSet { onParamEdited() } }
    /// 打点（接触点偏移/R）：spinX +左/−右、spinY +高/−低。
    @Published var spinX: Double = 0 { didSet { onParamEdited() } }
    @Published var spinY: Double = 0 { didSet { onParamEdited() } }

    /// 调参入口：击球后改参先软回退到「击打前」再重算，避免从终局二次求解。
    private func onParamEdited() {
        guard !isPlaying else { return }
        if hasStruck { restorePendingBefore() } else { recompute() }
    }

    // MARK: - Published state

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    @Published private(set) var isPlaying = false
    /// 已击球但尚未记录：桌面停在「击打后」终局，编辑前需软回退到 `pendingBefore`。
    @Published private(set) var hasStruck = false
    @Published private(set) var isComputing = false
    @Published private(set) var isFeasible = false
    @Published private(set) var objectPocketed = false
    @Published private(set) var cuePocketed = false
    @Published private(set) var cutAngleDeg: Double?
    @Published private(set) var statusText: String = "从下方球库摆球，点选目标球与袋口"

    // MARK: - Sequence

    @Published private(set) var sequence = PositionPlaySequence(name: "未命名走位")
    /// 已记录的步数（= sequence.steps.count）。
    var stepCount: Int { sequence.steps.count }

    // MARK: - Internals

    private var lastPrediction: ShotPrediction?
    private var lastAimDirection: SCNVector3?
    /// 当前未记录这一杆的「击打前」桌面快照（未击球时与桌面同步刷新）。
    private var pendingBefore: BoardSnapshot?
    private let predictQueue = DispatchQueue(label: "com.qiuji.positionplay-predict", qos: .userInitiated)
    private var predictGeneration = 0
    private var pendingPredict: DispatchWorkItem?

    private var surfaceY: Float { scene.surfaceY }

    // MARK: - Ball name mapping (board key ↔ predictor name)

    private func predName(forBoardKey key: String) -> String {
        if key == PositionPlayBall.cueKey { return ShotInput.cueBallName }
        if key == selectedTargetKey { return ShotInput.targetBallName }
        return key
    }

    private func boardKey(forPredName name: String) -> String {
        if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
        if name == ShotInput.targetBallName { return selectedTargetKey ?? name }
        return name
    }

    // MARK: - Setup

    func setupScene() {
        scene.setupScene()
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        scene.hideAllBalls()
        scene.hideCueStick()
        // 顶视取景：球桌尽量占满场景区、仅留极小余量（球库已独立成底栏不再压桌）。
        scene.cameraRig?.topDownOrthographicScale = Double(AngleSceneCalculator.innerLength) * 0.54
        scene.cameraRig?.topDownPanOffset = .zero
        applyDefaultLayout()
    }

    /// 开箱默认球形：母球 + 1、2 号，便于立刻上手；用户可自由增删。
    private func applyDefaultLayout() {
        place(key: PositionPlayBall.cueKey, normalized: CanvasPoint(x: 0.30, y: 0.30))
        place(key: "_1", normalized: CanvasPoint(x: 0.62, y: 0.20))
        place(key: "_2", normalized: CanvasPoint(x: 0.78, y: 0.34))
        refreshOnTableKeys()
        selectedTargetKey = "_1"
        selectBestPocket()
        recompute()
    }

    // MARK: - Board queries

    /// 在库球键（按号，母球优先）。
    var offTableKeys: [String] {
        PositionPlayBall.allKeys.filter { scene.allBallNodes[$0]?.isHidden ?? true }
    }

    /// 当前桌面快照（从场景节点读取，单一真相）。
    func currentSnapshot() -> BoardSnapshot {
        var dict: [String: CanvasPoint] = [:]
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let n = AngleSceneCalculator.sceneToNormalized(position: node.position)
            dict[key] = CanvasPoint(x: Double(n.x), y: Double(n.y))
        }
        return BoardSnapshot(onTable: dict)
    }

    /// 可拖动的球节点（在桌全部）。
    var draggableBalls: [SCNNode] {
        onTableKeys.compactMap { scene.allBallNodes[$0] }
    }

    /// 可点选为目标的球节点（在桌、非母球）。
    var selectableBalls: [SCNNode] {
        onTableKeys
            .filter { !PositionPlayBall.isCue($0) }
            .compactMap { scene.allBallNodes[$0] }
    }

    // MARK: - Palette (place / remove)

    private func refreshOnTableKeys() {
        onTableKeys = PositionPlayBall.allKeys.filter { !(scene.allBallNodes[$0]?.isHidden ?? true) }
    }

    /// 从球库把一颗球放上桌（自动找一个空位）。
    func placeFromPalette(_ key: String) {
        guard !isPlaying else { return }
        if hasStruck { restorePendingBefore() }
        let pos = freeNormalizedSlot()
        place(key: key, normalized: pos)
        refreshOnTableKeys()
        if !PositionPlayBall.isCue(key), selectedTargetKey == nil {
            selectedTargetKey = key
            selectBestPocket()
        }
        recompute()
    }

    /// 从球库把一颗球放到指定世界坐标（拖拽落点）。落点会被钳制在台面且不与其它球重叠。
    func placeFromPalette(_ key: String, atWorld world: SCNVector3) {
        guard !isPlaying else { return }
        if hasStruck { restorePendingBefore() }
        guard let node = scene.allBallNodes[key] else { return }
        let clamped = clampMultiBall(world, movingNode: node)
        let n = AngleSceneCalculator.sceneToNormalized(position: clamped)
        place(key: key, normalized: CanvasPoint(x: Double(n.x), y: Double(n.y)))
        refreshOnTableKeys()
        if !PositionPlayBall.isCue(key), selectedTargetKey == nil {
            selectedTargetKey = key
            selectBestPocket()
        }
        recompute()
    }

    /// 把一颗在桌球撤下回库。
    func removeFromTable(_ key: String) {
        guard !isPlaying else { return }
        if hasStruck { restorePendingBefore() }
        scene.hideBall(key: key)
        if selectedTargetKey == key { selectedTargetKey = nil }
        refreshOnTableKeys()
        if selectedTargetKey == nil { autoSelectTarget() }
        recompute()
    }

    private func place(key: String, normalized: CanvasPoint) {
        let scenePos = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: normalized.x, y: normalized.y), surfaceY: surfaceY
        )
        scene.showBall(key: key, scenePosition: scenePos)
    }

    /// 在台面网格上找一个不与现有球重叠的归一化空位。
    private func freeNormalizedSlot() -> CanvasPoint {
        let candidates: [CanvasPoint] = stride(from: 0.15, through: 0.85, by: 0.1).flatMap { x in
            stride(from: 0.12, through: 0.40, by: 0.08).map { y in CanvasPoint(x: x, y: y) }
        }
        for c in candidates {
            let scenePos = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: c.x, y: c.y), surfaceY: surfaceY
            )
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

    // MARK: - Drag

    func dragBegan(node: SCNNode) {
        guard !isPlaying else { return }
        if hasStruck { restorePendingBefore() }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
    }

    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        guard !isPlaying else { return }
        let clamped = clampMultiBall(worldPosition, movingNode: node)
        node.position = clamped
        recompute()
    }

    func dragEnded(node: SCNNode) {
        guard !isPlaying else { return }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))
        recompute()
    }

    /// 多球摆位钳制：库内 + 远离袋口 + 不与任意其他在桌球重叠。
    private func clampMultiBall(_ pos: SCNVector3, movingNode: SCNNode) -> SCNVector3 {
        var p = AngleSceneCalculator.clampAwayFromPockets(pos, surfaceY: surfaceY)
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let r = AngleSceneCalculator.ballRadius
        let minDist: Float = 2 * r + 0.001
        // 迭代推开（最多几次），处理多球拥挤。
        for _ in 0..<6 {
            var moved = false
            for k in onTableKeys {
                guard let other = scene.allBallNodes[k], other !== movingNode, !other.isHidden else { continue }
                let dx = p.x - other.position.x
                let dz = p.z - other.position.z
                let dist = sqrtf(dx * dx + dz * dz)
                if dist < minDist {
                    if dist > 0.0001 {
                        p.x = other.position.x + (dx / dist) * minDist
                        p.z = other.position.z + (dz / dist) * minDist
                    } else {
                        p.x += minDist
                    }
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
        selectTarget(key: key)
    }

    func selectTarget(key: String) {
        guard !isPlaying, !PositionPlayBall.isCue(key), onTableKeys.contains(key) else { return }
        if hasStruck { restorePendingBefore() }
        selectedTargetKey = key
        selectBestPocket()
        recompute()
    }

    func selectPocket(at index: Int) {
        guard !isPlaying else { return }
        if hasStruck { restorePendingBefore() }
        selectedPocketIndex = index
        updatePocketHighlights()
        recompute()
    }

    private func autoSelectTarget() {
        let candidates = onTableKeys.filter { !PositionPlayBall.isCue($0) }
        selectedTargetKey = candidates.sorted {
            (PositionPlayBall.number(for: $0) ?? 99) < (PositionPlayBall.number(for: $1) ?? 99)
        }.first
        if selectedTargetKey != nil { selectBestPocket() }
    }

    private func selectBestPocket() {
        guard let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden,
              let targetKey = selectedTargetKey,
              let target = scene.allBallNodes[targetKey], !target.isHidden else { return }
        let count = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY).count
        var best = 0
        var bestAngle = Double.greatestFiniteMagnitude
        for i in 0..<count {
            let aim = AngleSceneCalculator.effectivePocketAimPoint(
                targetBall: target.position, pocketIndex: i, surfaceY: surfaceY
            )
            guard AngleSceneCalculator.isFeasible(
                cueBall: cue.position, targetBall: target.position, pocket: aim
            ) else { continue }
            let angle = AngleSceneCalculator.cutAngle(
                cueBall: cue.position, targetBall: target.position, pocket: aim
            )
            if angle < bestAngle { bestAngle = angle; best = i }
        }
        selectedPocketIndex = best
        updatePocketHighlights()
    }

    private func updatePocketHighlights() {
        for (i, marker) in pocketMarkers.enumerated() {
            scene.setPocketHighlight(marker, style: i == selectedPocketIndex ? .selected : .viable)
        }
    }

    // MARK: - Compute (background)

    func recompute() {
        // 未击球状态下，桌面即「击打前」真相：保持 pendingBefore 与桌面同步。
        if !hasStruck && !isPlaying { pendingBefore = currentSnapshot() }
        guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let targetKey = selectedTargetKey,
              let targetNode = scene.allBallNodes[targetKey], !targetNode.isHidden,
              selectedPocketIndex >= 0 else {
            clearTrajectory()
            isFeasible = false
            lastPrediction = nil
            statusText = needsSetupHint()
            return
        }

        let obstacles: [ObstacleBall] = onTableKeys.compactMap { key in
            guard key != PositionPlayBall.cueKey, key != targetKey,
                  let node = scene.allBallNodes[key], !node.isHidden else { return nil }
            return ObstacleBall(name: key, position: node.position)
        }

        let input = ShotInput(
            cueBall: cueNode.position,
            targetBall: targetNode.position,
            pocketIndex: selectedPocketIndex,
            velocity: Float(velocity),
            spinX: Float(spinX),
            spinY: Float(spinY),
            surfaceY: surfaceY,
            obstacles: obstacles
        )

        predictGeneration += 1
        let gen = predictGeneration
        isComputing = true
        pendingPredict?.cancel()
        let work = DispatchWorkItem { [weak self] in
            let pred = ShotPredictor.predict(input)
            DispatchQueue.main.async {
                guard let self, self.predictGeneration == gen, !self.isPlaying else { return }
                self.isComputing = false
                self.apply(pred)
            }
        }
        pendingPredict = work
        predictQueue.asyncAfter(deadline: .now() + 0.02, execute: work)
    }

    private func needsSetupHint() -> String {
        if scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true { return "请先把母球摆上桌" }
        if selectedTargetKey == nil { return "点选一颗目标球" }
        if selectedPocketIndex < 0 { return "点击袋口选择目标袋" }
        return "从下方球库摆球，点选目标球与袋口"
    }

    private func apply(_ pred: ShotPrediction) {
        lastPrediction = pred
        isFeasible = pred.feasible
        cutAngleDeg = pred.cutAngleDeg

        guard pred.feasible else {
            objectPocketed = false
            cuePocketed = false
            statusText = pred.infeasibleReason.isEmpty ? "当前角度无法进袋" : pred.infeasibleReason
            clearTrajectory()
            scene.hideCueStick()
            lastAimDirection = nil
            return
        }

        objectPocketed = pred.objectPocketed
        cuePocketed = pred.cuePocketed
        statusText = makeStatus(pred)
        drawTrajectory(pred)
        updateCueStickAiming(pred)
    }

    private func makeStatus(_ p: ShotPrediction) -> String {
        if p.cuePocketed { return "母球进袋（失误）" }
        if p.objectPocketed { return "进袋 · 母球走位已就绪" }
        return "未进袋（试试加大力度或换角度更小的袋口）"
    }

    // MARK: - Trajectory drawing

    private func drawTrajectory(_ p: ShotPrediction) {
        clearTrajectory()
        addPolyline(p.cuePath, color: UIColor.white.withAlphaComponent(0.95), radius: 0.0035)
        addPolyline(p.objectPath,
                    color: UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 0.95), radius: 0.0035)
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

    // MARK: - Cue stick aiming aid

    private func updateCueStickAiming(_ p: ShotPrediction) {
        guard !isPlaying, p.feasible,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden,
              let aim = aimDirection(path: p.cuePath, from: cue.position) else {
            scene.hideCueStick()
            lastAimDirection = nil
            return
        }
        lastAimDirection = aim
        let r = AngleSceneCalculator.ballRadius
        let perp = SCNVector3(-aim.z, 0, aim.x)
        let lateral = Float(spinX) * r
        let pos = SCNVector3(cue.position.x + perp.x * lateral,
                             cue.position.y,
                             cue.position.z + perp.z * lateral)
        scene.updateCueStick(cueBallPosition: pos, aimDirection: aim)
    }

    private func aimDirection(path: [SCNVector3], from cue: SCNVector3) -> SCNVector3? {
        for pt in path {
            let dx = pt.x - cue.x, dz = pt.z - cue.z
            let d = sqrtf(dx * dx + dz * dz)
            if d > 0.02 { return SCNVector3(dx / d, 0, dz / d) }
        }
        return nil
    }

    // MARK: - Playback (preview, multi-ball)

    func play() {
        guard !isPlaying, !hasStruck, let pred = lastPrediction, pred.feasible,
              let recorder = pred.recorder, pred.duration > 0.05 else { return }

        // 记录本杆击打前球形（终局回退用）。
        pendingBefore = currentSnapshot()

        isPlaying = true
        statusText = "击球中…"
        clearTrajectory()

        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let speed: Float = 1.4

        scene.hideCueStick()

        var cueAction: SCNAction?
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let name = predName(forBoardKey: key)
            let action = playback.action(for: node, ballName: name, speed: speed, removeOnPocket: false)
            if key == PositionPlayBall.cueKey {
                cueAction = action
            } else if let action {
                node.runAction(action)
            }
        }

        if let cueAction, let cueNode = scene.allBallNodes[PositionPlayBall.cueKey] {
            cueNode.runAction(cueAction) { [weak self] in
                Task { @MainActor in self?.finishStrike() }
            }
        } else {
            finishStrike()
        }
    }

    /// 击球动画结束：球停在「击打后」终局（进袋离场），等待用户「记录」或「重打」。
    private func finishStrike() {
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let potted: Set<String> = Set((lastPrediction?.pocketedBalls ?? []).map { boardKey(forPredName: $0) })

        for key in onTableKeys {
            guard let node = scene.allBallNodes[key] else { continue }
            if node.parent == nil { scene.rootNode.addChildNode(node) }
            node.removeAllActions()
            if potted.contains(key) {
                node.isHidden = true
                node.opacity = 1
            } else {
                node.isHidden = false
                node.opacity = 1
                if let p = lastPrediction?.finalPositions[predName(forBoardKey: key)] {
                    node.position = SCNVector3(p.x, yLevel, p.z)
                }
            }
        }

        refreshOnTableKeys()
        if let t = selectedTargetKey, potted.contains(t) { selectedTargetKey = nil }

        isPlaying = false
        hasStruck = true
        scene.hideCueStick()
        clearTrajectory()
        statusText = lastPrediction?.cuePocketed == true
            ? "母球进袋（失误）· 重打或调整"
            : "已击球 · 点「记录」存为一杆，或「重打」重来"
    }

    /// 软回退：把桌面恢复到本杆「击打前」，清除已击球状态（不触动已记录的步）。
    private func restorePendingBefore() {
        guard let before = pendingBefore else { hasStruck = false; return }
        hasStruck = false
        applyBoard(before)
    }

    // MARK: - Sequence: record / edit (ADR-P11-01)

    /// 把当前已求解的一杆记录为序列的一步，并把桌面推进到「击打后」状态（进袋离场回库）。
    func recordStep() {
        guard !isPlaying, let pred = lastPrediction, pred.feasible,
              let targetKey = selectedTargetKey,
              let pocketId = ShotIntent.pocketId(for: selectedPocketIndex) else { return }

        let before = pendingBefore ?? currentSnapshot()
        let shot = PlannedShot(
            targetKey: targetKey, pocket: pocketId,
            velocity: velocity, spinX: spinX, spinY: spinY
        )

        // 后快照：从 finalPositions 取每颗在桌球末位，进袋球离场。
        let potted = Set(pred.pocketedBalls.map { boardKey(forPredName: $0) })
        var afterDict: [String: CanvasPoint] = [:]
        for key in before.onTable.keys where !potted.contains(key) {
            let predN = predName(forBoardKey: key)
            if let p = pred.finalPositions[predN] {
                let n = AngleSceneCalculator.sceneToNormalized(position: p)
                afterDict[key] = CanvasPoint(x: Double(n.x), y: Double(n.y))
            } else {
                afterDict[key] = before.onTable[key]
            }
        }
        let after = BoardSnapshot(onTable: afterDict)

        let step = SequenceStep(
            before: before, shot: shot, after: after,
            potted: Array(potted),
            cuePocketed: pred.cuePocketed, objectPocketed: pred.objectPocketed
        )
        if sequence.steps.isEmpty { sequence.initial = before }
        sequence.steps.append(step)
        sequence.updatedAt = Date()

        applyBoard(after)
    }

    /// 把序列回退到某一步之前（截断重录）：删除该步及其后所有步，桌面恢复到该步 before。
    func revertToBefore(stepIndex: Int) {
        guard !isPlaying, stepIndex >= 0, stepIndex < sequence.steps.count else { return }
        let target = sequence.steps[stepIndex].before
        sequence.steps = Array(sequence.steps.prefix(stepIndex))
        sequence.updatedAt = Date()
        applyBoard(target)
    }

    /// 跳到某一步之后的桌面（仅查看，不改序列）。
    func previewBoard(afterStep stepIndex: Int) {
        guard !isPlaying, stepIndex >= 0, stepIndex < sequence.steps.count else { return }
        applyBoard(sequence.steps[stepIndex].after)
    }

    /// 随机球形：随机摆 `objectCount` 颗目标球（球号随机不重复、位置随机且分散，避开袋口区）。
    /// 母球为自由球——若已在桌则保留其位置，否则不放（由用户自行摆）。
    func randomLayout(objectCount: Int) {
        guard !isPlaying else { return }
        let count = max(1, min(15, objectCount))
        let cuePoint = onTableKeys.contains(PositionPlayBall.cueKey)
            ? currentSnapshot().onTable[PositionPlayBall.cueKey] : nil

        let numbers = Array(1...15).shuffled().prefix(count)
        let positions = randomSpreadPositions(count: count, avoid: cuePoint)

        var dict: [String: CanvasPoint] = [:]
        if let cuePoint { dict[PositionPlayBall.cueKey] = cuePoint }
        for (i, n) in numbers.enumerated() where i < positions.count {
            dict["_\(n)"] = positions[i]
        }

        selectedTargetKey = nil
        applyBoard(BoardSnapshot(onTable: dict))
    }

    /// 在台面安全内区随机采样互相分散的归一化点（避开袋口/库边）。
    private func randomSpreadPositions(count: Int, avoid cue: CanvasPoint?) -> [CanvasPoint] {
        let xRange = 0.14...0.86
        let yRange = 0.12...0.40
        // 按数量自适应最小间距：球越多间距越小，但保底/封顶保证分散与可放下。
        let area = (xRange.upperBound - xRange.lowerBound) * (yRange.upperBound - yRange.lowerBound)
        var minSep = max(0.085, min(0.18, 0.9 * (area / Double(count)).squareRoot()))

        var occupied: [CanvasPoint] = []
        if let cue { occupied.append(cue) }
        var result: [CanvasPoint] = []

        var relaxTries = 0
        while result.count < count && relaxTries < 6 {
            var attempts = 0
            while result.count < count && attempts < count * 400 {
                attempts += 1
                let p = CanvasPoint(x: Double.random(in: xRange), y: Double.random(in: yRange))
                if occupied.allSatisfy({ hypot($0.x - p.x, $0.y - p.y) >= minSep }) {
                    occupied.append(p)
                    result.append(p)
                }
            }
            if result.count < count { minSep *= 0.8; relaxTries += 1 }
        }
        return result
    }

    /// 重打：把桌面退回本杆「击打前」，重新瞄准（不删除已记录的杆）。
    func replayCurrent() {
        guard !isPlaying else { return }
        if let before = pendingBefore {
            hasStruck = false
            applyBoard(before)
        } else {
            recompute()
        }
    }

    /// 重置整条序列与桌面（回到默认球形）。
    func resetAll() {
        guard !isPlaying else { return }
        hasStruck = false
        pendingBefore = nil
        sequence = PositionPlaySequence(name: sequence.name)
        scene.hideAllBalls()
        applyDefaultLayout()
    }

    /// 清空桌面（不留任何球），便于从零自由摆球。
    func clearTable() {
        guard !isPlaying else { return }
        hasStruck = false
        pendingBefore = nil
        scene.hideAllBalls()
        selectedTargetKey = nil
        selectedPocketIndex = -1
        refreshOnTableKeys()
        clearTrajectory()
        scene.hideCueStick()
        statusText = needsSetupHint()
    }

    /// 把一个桌面快照应用到场景（隐藏全部 → 显示快照里的球）。
    private func applyBoard(_ snapshot: BoardSnapshot) {
        hasStruck = false
        scene.hideAllBalls()
        for (key, pt) in snapshot.onTable {
            place(key: key, normalized: pt)
        }
        refreshOnTableKeys()
        if let t = selectedTargetKey, snapshot.onTable[t] == nil { selectedTargetKey = nil }
        if selectedTargetKey == nil { autoSelectTarget() }
        if selectedTargetKey != nil, selectedPocketIndex < 0 { selectBestPocket() }
        recompute()
    }

    func renameSequence(_ name: String) {
        sequence.name = name.isEmpty ? "未命名走位" : name
        sequence.updatedAt = Date()
    }

    /// 载入一条已有序列进行编辑。
    func load(sequence loaded: PositionPlaySequence) {
        guard !isPlaying else { return }
        sequence = loaded
        applyBoard(loaded.currentBoard)
    }
}
