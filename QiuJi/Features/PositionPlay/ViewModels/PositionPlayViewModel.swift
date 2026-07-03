import Foundation
import SceneKit
import SwiftUI

/// 走位编排器 ViewModel（ADR-P11-01 / ADR-P11-03 / ADR-P11-04）。
///
/// 复用 `AngleTrainingScene`（USDZ 真台 + 16 颗现成球节点）与 `AngleSceneView` 的拖球/点选交互。
/// 两种瞄准模式：
/// - **袋口模式**：选目标球 + 袋口，引擎闭环求瞄（进攻球）。
/// - **自由模式**：点击桌面/球/袋口设定瞄准方向，引擎直瞄真实模拟（安全球/推球/纯走位）。
///
/// 状态机（ADR-P11-04，连续击打模型）：击球后**桌面前进为新真相**——进袋球离场回库、
/// 母球停在走位终点，自动选中「距母球最近的目标球 + 距目标球最近的可进袋袋口」继续下一杆；
/// 「重打」才把桌面退回上一杆击打前。录制 = 开关：开启后每次击球自动记为一杆
/// （before + 意图 + after 的 JSON），停止后由 View 导出序列 JSON（离线脚本复现出视频/GIF）。
@MainActor
final class PositionPlayViewModel: ObservableObject {

    // MARK: - Aim mode

    enum AimMode: String, CaseIterable {
        case pocket
        case free
    }

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var pocketMarkers: [SCNNode] = []
    private var trajectoryNodes: [SCNNode] = []
    /// 选中目标球的常驻选中环（独立于轨迹，feasible/computing 都显示）。
    private var selectionNodes: [SCNNode] = []

    // MARK: - Published board / selection

    /// 当前在桌球键（顺序：母球优先，目标球按号）。
    @Published private(set) var onTableKeys: [String] = []
    @Published private(set) var selectedTargetKey: String? {
        didSet { if oldValue != selectedTargetKey { refreshSelectionRing() } }
    }
    @Published var selectedPocketIndex: Int = -1

    /// 球库展示序（#1/#2）：在库球按固定顺序（母球、1…15）排列；
    /// 球上桌即从中消失、后续球补位（向上/向左流动），回库时按号序插回。
    var paletteKeys: [String] {
        PositionPlayBall.allKeys.filter { !onTableKeys.contains($0) }
    }

    /// 瞄准模式。切换时重算。
    @Published var aimMode: AimMode = .pocket {
        didSet {
            guard oldValue != aimMode, !isPlaying else { return }
            if aimMode == .free, freeAimDir == nil { freeAimDir = defaultFreeAim() }
            updatePocketHighlights()
            refreshSelectionRing()
            recompute()
        }
    }
    /// 自由模式瞄准方向（场景 XZ 单位向量）。
    @Published private(set) var freeAimDir: SCNVector3?

    // MARK: - Published shot params

    /// 连续杆头速度 (m/s)。
    @Published var velocity: Double = 3.3 { didSet { onParamEdited() } }
    /// 打点（接触点偏移/R）：spinX +左/−右、spinY +高/−低。
    @Published var spinX: Double = 0 { didSet { onParamEdited() } }
    @Published var spinY: Double = 0 { didSet { onParamEdited() } }

    private func onParamEdited() {
        guard !isPlaying else { return }
        recompute()
    }

    // MARK: - Published state

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    @Published private(set) var isPlaying = false
    @Published private(set) var isComputing = false
    @Published private(set) var isFeasible = false
    @Published private(set) var objectPocketed = false
    @Published private(set) var cuePocketed = false
    @Published private(set) var cutAngleDeg: Double?
    @Published private(set) var statusText: String = "从下方球库摆球，点选目标球与袋口"
    /// 录制开关（#11）：开启后每次击球自动记为序列一杆。
    @Published private(set) var isRecording = false
    /// 是否存在可「重打」回退的上一杆。
    @Published private(set) var canReplay = false

    // MARK: - Sequence (recording)

    @Published private(set) var sequence = PositionPlaySequence(name: "未命名走位")
    /// 已记录的步数（= sequence.steps.count）。
    var stepCount: Int { sequence.steps.count }

    // MARK: - Solved-shot context (ADR-P11-03)

    /// 一次求解的完整上下文：击打前快照 + 作者意图 + 预测。「击球/录制」只消费它。
    struct SolvedShot {
        let before: BoardSnapshot
        let shot: PlannedShot
        let prediction: ShotPrediction
    }

    private(set) var solvedShot: SolvedShot?

    // MARK: - Internals

    private var lastAimDirection: SCNVector3?
    /// 上一杆完整上下文（「重打」回退用，#1/#7）：击打前桌面快照 + 击打参数
    /// （目标球/袋口/速度/打点/瞄准模式与方向），重打时全部恢复。
    private var lastShot: (before: BoardSnapshot, shot: PlannedShot)?
    /// 上一杆是否被自动录入序列（重打时需一并撤回该步）。
    private var lastShotWasRecorded = false
    private let predictQueue = DispatchQueue(label: "com.qiuji.positionplay-predict", qos: .userInitiated)
    private var predictGeneration = 0
    private var pendingPredict: DispatchWorkItem?

    private var surfaceY: Float { scene.surfaceY }

    // MARK: - Ball name mapping (board key ↔ predictor name)

    private func boardKey(forPredName name: String, shot: PlannedShot) -> String {
        if name == ShotInput.cueBallName { return PositionPlayBall.cueKey }
        if !shot.isFree, name == ShotInput.targetBallName { return shot.targetKey }
        return name
    }

    // MARK: - Setup

    func setupScene() {
        scene.setupScene()
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        scene.hideAllBalls()
        scene.hideCueStick()
        // 顶视取景由 AngleSceneView 的 autoFitsRotatedTable 按视口自适应
        //（球桌完整可见 + 双轴居中，ADR-P11-08），此处只复位平移。
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

    /// 以外部球形（如拍照建球形产出的快照）替换当前桌面，并恢复编排求解。
    /// 空快照不改动默认球形（保持开箱可用）。
    func loadBoard(_ snapshot: BoardSnapshot) {
        guard !isPlaying, !snapshot.onTable.isEmpty else { return }
        sequence = PositionPlaySequence(name: sequence.name)
        lastShot = nil
        lastShotWasRecorded = false
        canReplay = false
        applyBoard(snapshot)
    }

    // MARK: - Board queries

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

    /// 可点选的球节点（在桌、非母球）。
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
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
    }

    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        guard !isPlaying else { return }
        let clamped = clampMultiBall(worldPosition, movingNode: node)
        node.position = clamped
        refreshSelectionRing()   // 即时跟随（recompute 有防抖，避免选中环滞后）
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

    // MARK: - Selection / aiming

    func selectTarget(node: SCNNode) {
        guard let key = scene.ballKey(for: node) else { return }
        selectTarget(key: key)
    }

    func selectTarget(key: String) {
        guard !isPlaying, onTableKeys.contains(key) else { return }
        if aimMode == .free {
            // 自由模式：点球 = 朝该球球心瞄准。
            if let node = scene.allBallNodes[key], !node.isHidden {
                setFreeAim(toward: node.position)
            }
            return
        }
        guard !PositionPlayBall.isCue(key) else { return }
        selectedTargetKey = key
        selectBestPocket()
        recompute()
    }

    func selectPocket(at index: Int) {
        guard !isPlaying else { return }
        if aimMode == .free {
            // 自由模式：点袋口 = 朝袋口中心瞄准。
            let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
            guard index >= 0, index < pockets.count else { return }
            setFreeAim(toward: pockets[index])
            return
        }
        selectedPocketIndex = index
        updatePocketHighlights()
        recompute()
    }

    /// 自由模式：点击桌面任意点设定瞄准方向（母球 → 点击点）。袋口模式忽略。
    func handleTableTap(world: SCNVector3) {
        guard aimMode == .free, !isPlaying else { return }
        setFreeAim(toward: world)
    }

    private func setFreeAim(toward world: SCNVector3) {
        guard let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else { return }
        let dx = world.x - cue.position.x
        let dz = world.z - cue.position.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 0.02 else { return }
        freeAimDir = SCNVector3(dx / len, 0, dz / len)
        recompute()
    }

    private func defaultFreeAim() -> SCNVector3? {
        if let aim = lastAimDirection { return aim }
        guard let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else { return nil }
        if let t = selectedTargetKey, let tn = scene.allBallNodes[t], !tn.isHidden {
            let dx = tn.position.x - cue.position.x
            let dz = tn.position.z - cue.position.z
            let len = sqrtf(dx * dx + dz * dz)
            if len > 0.02 { return SCNVector3(dx / len, 0, dz / len) }
        }
        return SCNVector3(1, 0, 0)
    }

    /// 自由瞄准方向的屏幕罗盘角（topDown2DRotated 取景：screen-up = world +X、
    /// screen-right = world +Z；0° = 屏幕正上方，顺时针为正）。nil = 非自由模式 / 方向未定。
    var freeAimBearingDeg: Float? {
        guard aimMode == .free, let d = freeAimDir else { return nil }
        var deg = atan2f(d.z, d.x) * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }

    /// 自由模式微调瞄准角：`delta > 0` = 屏幕上顺时针（向右）旋转，与右侧角度齿轮「往上拖」一致。
    /// 坐标契约：`freeAimDir` 为场景 XZ 单位向量，bearing = atan2(z, x)；
    /// CW（bearing 增）的旋转为 newX = x·cosΔ − z·sinΔ，newZ = x·sinΔ + z·cosΔ。
    func nudgeFreeAim(byDegrees delta: Float) {
        guard aimMode == .free, !isPlaying, abs(delta) > 1e-4 else { return }
        let base = freeAimDir ?? defaultFreeAim() ?? SCNVector3(1, 0, 0)
        let r = delta * .pi / 180
        let nx = base.x * cosf(r) - base.z * sinf(r)
        let nz = base.x * sinf(r) + base.z * cosf(r)
        let len = sqrtf(nx * nx + nz * nz)
        guard len > 1e-5 else { return }
        freeAimDir = SCNVector3(nx / len, 0, nz / len)
        recompute()
    }

    /// 自动选目标（#6）：距母球最近的在桌目标球。
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

    /// 自动选袋（#6）：可进袋（几何可行 + 无障碍球遮挡）的袋口中**距目标球最近**的那个；
    /// 全不可行时退回最近袋口。
    /// 遮挡判定：其余在桌球若挡住「母球→假想球」或「目标球→进球点」任一路径（球心距路径 < 2R）即不可行。
    private func selectBestPocket() {
        guard let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden,
              let targetKey = selectedTargetKey,
              let target = scene.allBallNodes[targetKey], !target.isHidden else { return }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        let obstacles = onTableKeys.compactMap { key -> SCNVector3? in
            guard key != targetKey, !PositionPlayBall.isCue(key),
                  let node = scene.allBallNodes[key], !node.isHidden else { return nil }
            return node.position
        }
        var bestFeasible: (index: Int, dist: Float)?
        var bestAny: (index: Int, dist: Float)?
        for i in 0..<pockets.count {
            let dist = AngleSceneCalculator.horizontalDistance(target.position, pockets[i])
            if bestAny == nil || dist < bestAny!.dist { bestAny = (i, dist) }
            let aim = AngleSceneCalculator.effectivePocketAimPoint(
                targetBall: target.position, pocketIndex: i, surfaceY: surfaceY
            )
            guard AngleSceneCalculator.isFeasible(
                cueBall: cue.position, targetBall: target.position, pocket: aim
            ) else { continue }
            let ghost = AngleSceneCalculator.ghostBallPosition(
                targetBall: target.position, pocket: aim,
                ballRadius: AngleSceneCalculator.ballRadius
            )
            guard !AngleSceneCalculator.isPathBlocked(
                from: cue.position, to: ghost, obstacles: obstacles
            ), !AngleSceneCalculator.isPathBlocked(
                from: target.position, to: aim, obstacles: obstacles
            ) else { continue }
            if bestFeasible == nil || dist < bestFeasible!.dist { bestFeasible = (i, dist) }
        }
        selectedPocketIndex = bestFeasible?.index ?? bestAny?.index ?? 0
        updatePocketHighlights()
    }

    private func updatePocketHighlights() {
        for (i, marker) in pocketMarkers.enumerated() {
            let selected = aimMode == .pocket && i == selectedPocketIndex
            scene.setPocketHighlight(marker, style: selected ? .selected : .viable)
        }
    }

    // MARK: - Compute (background)

    /// 作废一切在途求解（清空等使旧解失效的路径调用）。
    private func invalidatePendingPredict() {
        predictGeneration += 1
        pendingPredict?.cancel()
        pendingPredict = nil
        isComputing = false
    }

    func recompute() {
        guard !isPlaying else { return }

        guard let intent = currentShotIntent() else {
            clearTrajectory()
            isFeasible = false
            solvedShot = nil
            isComputing = false
            scene.hideCueStick()
            statusText = needsSetupHint()
            return
        }
        let before = currentSnapshot()
        let shot = intent
        let y = surfaceY

        predictGeneration += 1
        let gen = predictGeneration
        isComputing = true
        pendingPredict?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let pred = PositionPlayShotSolver.solve(before: before, shot: shot, surfaceY: y) else {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.predictGeneration == gen else { return }
                    self.isComputing = false
                    self.isFeasible = false
                    self.solvedShot = nil
                    self.statusText = self.needsSetupHint()
                }
                return
            }
            DispatchQueue.main.async {
                guard let self, self.predictGeneration == gen, !self.isPlaying else { return }
                self.isComputing = false
                self.solvedShot = SolvedShot(before: before, shot: shot, prediction: pred)
                self.apply(pred)
            }
        }
        pendingPredict = work
        predictQueue.asyncAfter(deadline: .now() + 0.02, execute: work)
    }

    /// 当前 UI 状态 → 作者意图。nil = 信息不全（缺母球/目标/袋口/瞄准方向）。
    private func currentShotIntent() -> PlannedShot? {
        guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden else { return nil }
        switch aimMode {
        case .pocket:
            guard let targetKey = selectedTargetKey,
                  let targetNode = scene.allBallNodes[targetKey], !targetNode.isHidden,
                  selectedPocketIndex >= 0,
                  let pocketId = ShotIntent.pocketId(for: selectedPocketIndex) else { return nil }
            return PlannedShot(targetKey: targetKey, pocket: pocketId,
                               velocity: velocity, spinX: spinX, spinY: spinY)
        case .free:
            guard let dir = freeAimDir else { return nil }
            return PlannedShot(targetKey: "", pocket: "",
                               velocity: velocity, spinX: spinX, spinY: spinY,
                               freeAim: PositionPlayShotSolver.canvasDirection(fromScene: dir))
        }
    }

    private func needsSetupHint() -> String {
        if scene.allBallNodes[PositionPlayBall.cueKey]?.isHidden ?? true { return "请先把母球摆上桌" }
        switch aimMode {
        case .pocket:
            if selectedTargetKey == nil { return "点选一颗目标球" }
            if selectedPocketIndex < 0 { return "点击袋口选择目标袋" }
            return "从下方球库摆球，点选目标球与袋口"
        case .free:
            return "点击桌面 / 球 / 袋口设定瞄准方向"
        }
    }

    private func apply(_ pred: ShotPrediction) {
        isFeasible = pred.feasible
        cutAngleDeg = pred.cutAngleDeg
        refreshSelectionRing()

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
        if let solved = solvedShot, solved.shot.isFree {
            if p.cuePocketed { return "母球进袋（失误）" }
            let potted = p.pocketedBalls.filter { $0 != ShotInput.cueBallName }
            if !potted.isEmpty {
                let labels = potted.map { PositionPlayBall.shortLabel(for: $0) }.joined(separator: "、")
                return "自由球 · \(labels) 号进袋"
            }
            return "自由球轨迹已就绪"
        }
        if p.cuePocketed { return "母球进袋（失误）" }
        if p.objectPocketed { return "进袋 · 母球走位已就绪" }
        if let hint = obstacleBlockHint() { return hint }
        return "未进袋（试试加大力度或换角度更小的袋口）"
    }

    /// 启发式提示（非判定）：进球线 / 瞄准线走廊内有其它球（球心距线 < 2R 必然相撞）时给出原因。
    private func obstacleBlockHint() -> String? {
        guard let solved = solvedShot, !solved.shot.isFree else { return nil }
        let pred = solved.prediction
        guard let cuePt = solved.before.onTable[PositionPlayBall.cueKey],
              let targetPt = solved.before.onTable[solved.shot.targetKey] else { return nil }
        let cue = PositionPlayShotSolver.scenePoint(cuePt, surfaceY: surfaceY)
        let target = PositionPlayShotSolver.scenePoint(targetPt, surfaceY: surfaceY)
        let blockDist = 2 * AngleSceneCalculator.ballRadius
        for (key, pt) in solved.before.onTable
        where key != PositionPlayBall.cueKey && key != solved.shot.targetKey {
            let p = PositionPlayShotSolver.scenePoint(pt, surfaceY: surfaceY)
            let dCueLine = ShotPredictor.segmentPointDistanceXZ(a: cue, b: pred.ghost, p: p)
            let dPotLine = ShotPredictor.segmentPointDistanceXZ(a: target, b: pred.pocketAimPoint, p: p)
            if min(dCueLine, dPotLine) < blockDist {
                return "未进袋 · \(PositionPlayBall.shortLabel(for: key)) 号球挡住线路（已如实模拟）"
            }
        }
        return nil
    }

    // MARK: - Trajectory drawing

    private func drawTrajectory(_ p: ShotPrediction) {
        clearTrajectory()
        addPolyline(p.cuePath, color: TrajectoryStyle.aimColor, radius: TrajectoryStyle.aimRadius)
        // 进球线延长（#8）：进袋时把目标球轨迹末端延伸到袋口圆边缘（jaw/袋弧碰撞已在真实轨迹中）。
        var objPath = p.objectPath
        if p.objectPocketed, let solved = solvedShot, !solved.shot.isFree,
           let pocketIndex = ShotIntent.pocketIndex(for: solved.shot.pocket) {
            objPath = PositionPlayShotSolver.extendPathToPocketRim(
                objPath, pocketIndex: pocketIndex, surfaceY: surfaceY
            )
        }
        // 进球线随目标球球色（黑 8 亮灰，ADR-P11-12）。
        addPolyline(objPath, color: TrajectoryStyle.potColor(for: solvedShot?.shot.targetKey ?? ""),
                    radius: TrajectoryStyle.potRadius)
        // 自由模式：所有被带动的球的真实轨迹，各随其球色（extraBallPaths 键 = 桌面球键）。
        for (key, pts) in p.extraBallPaths {
            addPolyline(pts, color: TrajectoryStyle.potColor(for: key, alpha: 0.85),
                        radius: TrajectoryStyle.potRadius)
        }
        // 假想球：袋口模式显示母球瞄准终点（半透明白，与分离角同语义）。
        if let solved = solvedShot, !solved.shot.isFree, let ghost = scene.ghostBallNode {
            ghost.position = SCNVector3(p.ghost.x, surfaceY + AngleSceneCalculator.ballRadius, p.ghost.z)
            ghost.isHidden = false
        }
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

    /// 点击球库中「已在桌上」的球时，对应桌上球做一次放大→恢复脉冲，提示其位置（#5a）。
    func pulseTableBall(_ key: String) {
        guard !isPlaying, let node = scene.allBallNodes[key], !node.isHidden else { return }
        node.removeAction(forKey: "libraryPulse")
        let up = SCNAction.scale(to: 1.7, duration: 0.18); up.timingMode = .easeOut
        let down = SCNAction.scale(to: 1.0, duration: 0.24); down.timingMode = .easeIn
        node.runAction(SCNAction.sequence([up, down]), forKey: "libraryPulse")
    }

    /// 选中目标球的绿色选中环（袋口模式）。无解 / 计算中也常驻显示，跟随球位。
    func refreshSelectionRing() {
        scene.clearResultNodes(nodes: &selectionNodes)
        guard !isPlaying, aimMode == .pocket,
              let key = selectedTargetKey,
              let node = scene.allBallNodes[key], !node.isHidden else { return }
        selectionNodes.append(scene.addSelectionRing(at: node.position))
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
        scene.updateCueStick(cueBallPosition: strikePosition(cue: cue.position), aimDirection: aim)
    }

    /// 击球时球杆中心位置（含加塞横向偏移）。
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

    // MARK: - Strike (#10 运杆 + 击球)

    func play() {
        guard !isPlaying, !isComputing,
              let solved = solvedShot, solved.prediction.feasible,
              let recorder = solved.prediction.recorder, solved.prediction.duration > 0.05,
              let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = lastAimDirection ?? aimDirection(path: solved.prediction.cuePath, from: cueNode.position)
        else { return }

        lastShot = (solved.before, solved.shot)
        lastShotWasRecorded = false
        canReplay = false
        isPlaying = true
        scene.clearResultNodes(nodes: &selectionNodes)   // 播放时隐藏选中环
        statusText = "运杆…"

        let strikePos = strikePosition(cue: cueNode.position)
        scene.runCueStroke(strikePosition: strikePos, aim: aim, velocity: Float(solved.shot.velocity)) { [weak self] in
            self?.launchBalls(solved: solved, recorder: recorder)
        }
    }

    /// 触球瞬间：收杆、清线，按真实轨迹回放全部球体。
    private func launchBalls(solved: SolvedShot, recorder: TrajectoryRecorder) {
        statusText = "击球中…"
        clearTrajectory()
        // 收杆不在此处：触球后球杆继续减速跟杆 + 停留一拍再消失（由 `runCueStroke` 接管）。

        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let speed: Float = 1.0
        // #11：末段慢速 creep 肉眼不可见，按「感知静止时刻」截断，避免「击球中」状态滞留数秒。
        let settle = playback.perceptibleSettleTime()

        var cueAction: SCNAction?
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let name = PositionPlayShotSolver.predName(boardKey: key, shot: solved.shot)
            let action = playback.action(for: node, ballName: name, speed: speed,
                                         removeOnPocket: false, maxSimTime: settle)
            if key == PositionPlayBall.cueKey {
                cueAction = action
            } else if let action {
                node.runAction(action)
            }
        }

        // 收尾延时：有球进袋时等「沉入 + 停顿 + 淡出」播完再结算（#4/#9），无进袋立即结算。
        let tail: TimeInterval = solved.prediction.pocketedBalls.isEmpty
            ? 0
            : TrajectoryPlayback.pocketSettleDuration + 0.1

        if let cueAction, let cueNode = scene.allBallNodes[PositionPlayBall.cueKey] {
            cueNode.runAction(cueAction) { [weak self] in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(tail * 1_000_000_000))
                    self?.finishStrike()
                }
            }
            // 音效在全部球体动画挂载后起播：避免（首杆冷启动 / 中途开音效）时
            // 音频引擎冷启动阻塞主线程，抢在球体动画挂载之前，使跟杆先于球推进。
            ShotAudioScheduler.shared.play(prediction: solved.prediction)
        } else {
            finishStrike()
        }
    }

    /// 击球动画结束（ADR-P11-04）：桌面**前进为新真相**——进袋球离场回库、母球停在走位终点；
    /// 录制中则自动把这一杆记入序列；随后自动选中下一杆（距母球最近目标球 + 最近可进袋袋口）。
    private func finishStrike() {
        ShotAudioScheduler.shared.cancel()
        guard let solved = solvedShot else {
            isPlaying = false
            return
        }
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let potted = Set(solved.prediction.pocketedBalls.map { boardKey(forPredName: $0, shot: solved.shot) })

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
                let predName = PositionPlayShotSolver.predName(boardKey: key, shot: solved.shot)
                if let p = solved.prediction.finalPositions[predName] {
                    node.position = SCNVector3(p.x, yLevel, p.z)
                }
            }
        }

        refreshOnTableKeys()

        // 录制中自动记一杆（#11），消费 solvedShot 上下文，与 UI 选中态解耦。
        if isRecording {
            appendRecordedStep(solved: solved, potted: potted)
            lastShotWasRecorded = true
        }

        // 打点用完即清（#5）：下一杆默认中心球（趁 isPlaying 仍为 true，didSet 不触发重算）。
        spinX = 0
        spinY = 0

        isPlaying = false
        canReplay = true
        scene.hideCueStick()
        clearTrajectory()

        // 自动选下一杆（#6）：距母球最近的目标球 + 距目标球最近的可进袋袋口。
        selectedTargetKey = nil
        autoSelectTarget()
        recompute()
    }

    // MARK: - Recording (#11)

    /// 开始录制：以当前桌面为开局快照开一条新序列，此后每次击球自动记为一杆。
    func startRecording() {
        guard !isPlaying, !isRecording else { return }
        sequence = PositionPlaySequence(name: sequence.name, initial: currentSnapshot())
        isRecording = true
        lastShotWasRecorded = false
    }

    /// 结束录制。返回录到的序列（无任何击球时返回 nil）。
    func stopRecording() -> PositionPlaySequence? {
        guard isRecording else { return nil }
        isRecording = false
        return sequence.steps.isEmpty ? nil : sequence
    }

    private func appendRecordedStep(solved: SolvedShot, potted: Set<String>) {
        let pred = solved.prediction
        let before = solved.before

        var afterDict: [String: CanvasPoint] = [:]
        for key in before.onTable.keys where !potted.contains(key) {
            let predN = PositionPlayShotSolver.predName(boardKey: key, shot: solved.shot)
            if let p = pred.finalPositions[predN] {
                let n = AngleSceneCalculator.sceneToNormalized(position: p)
                afterDict[key] = CanvasPoint(x: Double(n.x), y: Double(n.y))
            } else {
                afterDict[key] = before.onTable[key]
            }
        }

        let step = SequenceStep(
            before: before, shot: solved.shot, after: BoardSnapshot(onTable: afterDict),
            potted: Array(potted),
            cuePocketed: pred.cuePocketed, objectPocketed: pred.objectPocketed
        )
        sequence.steps.append(step)
        sequence.updatedAt = Date()
    }

    // MARK: - Replay / clear / reset

    /// 重打（#1/#7）：把桌面退回上一杆「击打前」，并恢复该杆的全部击打参数
    /// （目标球/目标袋口/速度/打点/瞄准模式与方向）；录制中一并撤回刚录的那杆。
    func replayCurrent() {
        guard !isPlaying, let last = lastShot else { return }
        if lastShotWasRecorded, !sequence.steps.isEmpty {
            sequence.steps.removeLast()
            sequence.updatedAt = Date()
        }
        lastShotWasRecorded = false
        lastShot = nil
        canReplay = false

        // 先恢复击打参数（#1），再应用桌面快照；applyBoard 见目标球已选中且袋口有效，
        // 不会触发自动重选，最终 recompute 用恢复后的完整状态求解。
        velocity = last.shot.velocity
        spinX = last.shot.spinX
        spinY = last.shot.spinY
        if last.shot.isFree {
            aimMode = .free
            if let canvasAim = last.shot.freeAim {
                freeAimDir = PositionPlayShotSolver.sceneDirection(fromCanvas: canvasAim)
            }
        } else {
            aimMode = .pocket
            selectedTargetKey = last.shot.targetKey
            if let idx = ShotIntent.pocketIndex(for: last.shot.pocket) {
                selectedPocketIndex = idx
            }
        }
        applyBoard(last.before)
        updatePocketHighlights()
    }

    /// 回到上一杆击打前的球形以便**临时再追加一杆**：恢复桌面与该杆参数，但**不删除**已录的那一杆
    /// （区别于 `replayCurrent()` 的「重打＝删末杆＋退回」）。`lastShot`/`canReplay`/`stepCount` 不变，
    /// 退回后再次击球将**追加**新的一杆、与已录的并存（允许从同一局面分叉补打）。
    func restorePreviousBoard() {
        guard !isPlaying, let last = lastShot else { return }
        velocity = last.shot.velocity
        spinX = last.shot.spinX
        spinY = last.shot.spinY
        if last.shot.isFree {
            aimMode = .free
            if let canvasAim = last.shot.freeAim {
                freeAimDir = PositionPlayShotSolver.sceneDirection(fromCanvas: canvasAim)
            }
        } else {
            aimMode = .pocket
            selectedTargetKey = last.shot.targetKey
            if let idx = ShotIntent.pocketIndex(for: last.shot.pocket) {
                selectedPocketIndex = idx
            }
        }
        applyBoard(last.before)
        updatePocketHighlights()
    }

    /// 重置整条序列与桌面（回到默认球形）。录制中则丢弃录制。
    func resetAll() {
        guard !isPlaying else { return }
        isRecording = false
        lastShot = nil
        lastShotWasRecorded = false
        canReplay = false
        sequence = PositionPlaySequence(name: sequence.name)
        scene.hideAllBalls()
        applyDefaultLayout()
    }

    /// 清空桌面（不留任何球），便于从零自由摆球。录制中则丢弃录制。
    func clearTable() {
        guard !isPlaying else { return }
        isRecording = false
        lastShot = nil
        lastShotWasRecorded = false
        canReplay = false
        if !sequence.steps.isEmpty { sequence = PositionPlaySequence(name: sequence.name) }
        invalidatePendingPredict()
        scene.hideAllBalls()
        selectedTargetKey = nil
        selectedPocketIndex = -1
        refreshOnTableKeys()
        clearTrajectory()
        scene.hideCueStick()
        solvedShot = nil
        isFeasible = false
        statusText = needsSetupHint()
    }

    /// 把一个桌面快照应用到场景（隐藏全部 → 显示快照里的球），并恢复编排求解。
    private func applyBoard(_ snapshot: BoardSnapshot) {
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
}
