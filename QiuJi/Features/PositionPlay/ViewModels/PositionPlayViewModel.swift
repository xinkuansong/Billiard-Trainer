import Foundation
import SceneKit
import SwiftUI
import Combine

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

    /// 进袋 ⇄ 自由 单按钮切换（条 15.2/15.3）：切自由时保留进袋模式下的瞄准方向
    /// （母球→假想球），而非退回默认瞄准。
    func toggleAimMode() {
        guard !isPlaying else { return }
        if aimMode == .pocket {
            if let solved = solvedShot, !solved.shot.isFree {
                freeAimDir = solved.prediction.aimDirection
            }
            aimMode = .free
        } else {
            aimMode = .pocket
        }
    }

    /// 自由模式首碰预览（P18 B2 T-P18-06/08，纯几何、主线程逐帧）：
    /// 沿瞄准射线的第一颗被碰球 + 假想球 + 切球角。
    /// nil = 当前方向打不到任何球（空杆 / 直奔库边）。
    @Published private(set) var freeAimContact: AngleSceneCalculator.FreeAimContact?

    // MARK: - Published shot params

    /// 连续杆头速度 (m/s)。默认 1.5（条 13.2：低速走位是常态）。
    @Published var velocity: Double = ShotTuning.defaultVelocity { didSet { onParamEdited() } }
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

    /// 每杆停稳后的物理事实回调（条 15.10：自由击球页把它喂给规则引擎裁决）。
    var onShotSettled: ((ShotFacts) -> Void)?

    /// 桌面目标球数量上限（条 17.4：分离角与走位强制最多 2 颗，让玩家专注感受
    /// 角度/力度/打点对母球轨迹的影响）。nil = 不限。
    var maxTargetBalls: Int?

    /// 目标球上限校验：超限时提示并拒绝摆球。
    private func withinTargetBallCap(adding key: String) -> Bool {
        guard !PositionPlayBall.isCue(key), let cap = maxTargetBalls else { return true }
        let count = onTableKeys.filter { !PositionPlayBall.isCue($0) }.count
        guard count >= cap, !onTableKeys.contains(key) else { return true }
        statusText = "本页最多摆 \(cap) 颗目标球"
        return false
    }

    // MARK: - Internals

    private var lastAimDirection: SCNVector3?
    /// 上一杆完整上下文（「重打」回退用，#1/#7）：击打前桌面快照 + 击打参数
    /// （目标球/袋口/速度/打点/瞄准模式与方向），重打时全部恢复。
    private var lastShot: (before: BoardSnapshot, shot: PlannedShot)?
    /// 上一杆是否被自动录入序列（重打时需一并撤回该步）。
    private var lastShotWasRecorded = false
    private let predictQueue = DispatchQueue(label: "com.qiuji.positionplay-predict", qos: .userInitiated)
    private var predictGeneration = 0
    /// 求解触发去抖调度（G14）：交互态（拖瞄准线/拖球/刻度轮）挂起求解、停 0.5s 才触发；
    /// 离散态（点选/参数）按原 ~20ms 快速触发。
    private let solveScheduler = SolveDebounceScheduler()
    /// 单飞标志（P3 在途合并）：true = 后台正有一次求解在跑。主线程读写。
    private var predictInFlight = false
    /// 末班车标记（P3）：在途期间来过新请求 ⇒ 收尾时用最新 UI 状态补跑一次（丢弃中间态）。
    private var predictRerunWanted = false

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
        canPlayback = false
        lastPlaybackContext = nil
        applyBoard(snapshot)
    }

    /// 载入一条已存序列并进入「续接编辑」态（存档 + 在原有基础上修改）。
    ///
    /// **不信任存档里的 `after`/`potted`**（物理引擎可能已变）：只取 `initial` 开局与每一杆的
    /// 作者意图 `shot`，用**当前引擎**逐杆无动画重放，重建 `after`；一旦某杆在新引擎下不可行
    /// 即停在该杆之前，把桌面留给作者从这里修。重放完开启录制续接，末杆可「重打」删除重编。
    /// - Returns: (成功重放杆数, 存档总杆数)；`replayed < total` 表示第 `replayed+1` 杆已崩、需人工修。
    @discardableResult
    func loadSequenceForEditing(_ archived: PositionPlaySequence) -> (replayed: Int, total: Int) {
        guard !isPlaying else { return (0, archived.steps.count) }
        invalidatePendingPredict()
        isRecording = false
        lastShot = nil
        lastShotWasRecorded = false
        canReplay = false
        canPlayback = false
        lastPlaybackContext = nil

        var rebuilt = PositionPlaySequence(
            id: archived.id, name: archived.name,
            initial: archived.initial, steps: [],
            createdAt: archived.createdAt, updatedAt: Date()
        )
        // 每杆以**存档里该杆自己的 `before`** 为输入（作者确认过的局面，含击打间的手动摆球
        // 调整），只用当前引擎重建 `after`/`potted`。不能从 initial 链式推进：那会把作者在
        // 杆与杆之间挪过球的修正全部丢掉（重放结果 ≠ 存档，保存后再进看似「没更新」）。
        var landing = archived.initial          // 重放结束后呈现给作者的桌面
        var brokenShot: PlannedShot?            // 新物理下不可行的那杆（停在其击打前）
        for step in archived.steps {
            let before = step.before
            guard let pred = PositionPlayShotSolver.solve(before: before, shot: step.shot, surfaceY: surfaceY),
                  pred.feasible else {
                landing = before
                brokenShot = step.shot
                break
            }
            let potted = Set(pred.pocketedBalls.map { boardKey(forPredName: $0, shot: step.shot) })
            var afterDict: [String: CanvasPoint] = [:]
            for key in before.onTable.keys where !potted.contains(key) {
                let predN = PositionPlayShotSolver.predName(boardKey: key, shot: step.shot)
                if let p = pred.finalPositions[predN] {
                    let n = AngleSceneCalculator.sceneToNormalized(position: p)
                    afterDict[key] = CanvasPoint(x: Double(n.x), y: Double(n.y))
                } else {
                    afterDict[key] = before.onTable[key]
                }
            }
            let after = BoardSnapshot(onTable: afterDict)
            rebuilt.steps.append(SequenceStep(
                before: before, shot: step.shot, after: after,
                potted: Array(potted),
                cuePocketed: pred.cuePocketed, objectPocketed: pred.objectPocketed,
                note: step.note
            ))
            landing = after
        }

        sequence = rebuilt
        isRecording = true
        // 末杆可「重打」：删掉重放出的最后一杆并退回其击打前，供作者重编（与真实击球后一致）。
        if let last = rebuilt.steps.last {
            lastShot = (last.before, last.shot)
            lastShotWasRecorded = true
            canReplay = true
        }
        // 停在崩掉那杆的击打前时，恢复该杆原击打参数，作者以原意图为起点修。
        if let shot = brokenShot { restoreShotParams(shot) }
        applyBoard(landing)
        return (rebuilt.steps.count, archived.steps.count)
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

    /// 仅母球可拖（自由击球页 P10.1：禁止摆球，母球仍可拖用于自由球/走位微调）。
    var draggableCueOnly: [SCNNode] {
        guard let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden else { return [] }
        return [cue]
    }

    /// 球桌外框实测半尺寸（世界 X/Z）；供屏幕布局对齐球桌矩形（ShotStageProxy）。
    /// 装桌前 cameraRig 尚未回填时用 USDZ 兜底常量。
    var tableOuterHalfExtents: (length: Double, width: Double) {
        if let rig = scene.cameraRig {
            return (rig.tableOuterHalfLength, rig.tableOuterHalfWidth)
        }
        return (ShotTableLayout.defaultHalfLength, ShotTableLayout.defaultHalfWidth)
    }

    // MARK: - Palette (place / remove)

    private func refreshOnTableKeys() {
        onTableKeys = PositionPlayBall.allKeys.filter { !(scene.allBallNodes[$0]?.isHidden ?? true) }
    }

    /// 从球库把一颗球放上桌（自动找一个空位）。
    func placeFromPalette(_ key: String) {
        guard !isPlaying, !isSequenceMode, withinTargetBallCap(adding: key) else { return }
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
        guard !isPlaying, !isSequenceMode, withinTargetBallCap(adding: key) else { return }
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
        refreshSelectionRing()   // 即时跟随（选中环无防抖，避免滞后）
        recompute(interactive: true)   // G14：拖球期间不求解，仅几何预览
    }

    func dragEnded(node: SCNNode) {
        guard !isPlaying else { return }
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))
        recompute(interactive: true)   // G14：拖球结束后按 idle 0.5s（无新输入）触发求解
    }

    /// 摆球精调：按屏幕方向移动一颗在桌球一步（默认 0.5mm），经 `clampMultiBall` 钳制。
    /// 返回是否真的发生了位移（撞库/叠球撞墙时为 false，供长按连发停住）。
    @discardableResult
    func nudgeBall(key: String,
                   direction: BallNudgeDirection,
                   stepMeters: Float = BallNudgeMath.fineStepMeters) -> Bool {
        guard !isPlaying, onTableKeys.contains(key),
              let node = scene.allBallNodes[key], !node.isHidden else { return false }
        let d = BallNudgeMath.delta(for: direction, stepMeters: stepMeters)
        let target = SCNVector3(node.position.x + d.dx, node.position.y, node.position.z + d.dz)
        let clamped = clampMultiBall(target, movingNode: node)
        let moved = abs(clamped.x - node.position.x) > 1e-7
            || abs(clamped.z - node.position.z) > 1e-7
        guard moved else { return false }
        node.position = clamped
        refreshSelectionRing()
        recompute(interactive: true)
        return true
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

    /// 自由瞄准方向的屏幕罗盘角（坐标契约见 `AngleSceneCalculator.bearingDeg`）。
    /// nil = 非自由模式 / 方向未定。
    var freeAimBearingDeg: Float? {
        guard aimMode == .free, let d = freeAimDir else { return nil }
        return AngleSceneCalculator.bearingDeg(of: d)
    }

    /// 自由模式微调瞄准角：`delta > 0` = 屏幕上顺时针（向右）旋转，与右侧角度齿轮「往上拖」一致。
    /// 自由模式瞄准相对调整（G13）：`delta > 0` = 屏幕顺时针（向右）旋转，同刻度齿轮「往上拖」。
    /// 台面空白处拖动（`onAimNudged`）与左缘刻度齿轮（`BTAimWheel`）共用本入口——均为对**当前**
    /// 瞄准方向的增量旋转（第一落点只选中不转向由手势层保证）；G14：微调期间不求解、停 0.5s 才求解。
    func nudgeFreeAim(byDegrees delta: Float) {
        guard aimMode == .free, !isPlaying, abs(delta) > 1e-4 else { return }
        let base = freeAimDir ?? defaultFreeAim() ?? SCNVector3(1, 0, 0)
        freeAimDir = AngleSceneCalculator.rotatedAim(base, byDegrees: delta)
        recompute(interactive: true)
    }

    // MARK: - Free-aim overlay (T-P18-06/08：假想球 + 切角，纯几何逐帧)

    /// 刷新自由瞄准覆盖层：首碰预览（假想球贴目标球滑动）。
    /// 非自由模式 / 播放中 / 缺母球或方向时全部隐藏。轨迹线仍由后台 `simulateFree` 异步补齐。
    private func refreshFreeAimOverlay() {
        let r = AngleSceneCalculator.ballRadius
        guard aimMode == .free, !isPlaying,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden,
              let dir = freeAimDir else {
            freeAimContact = nil
            if aimMode == .free {
                scene.ghostBallNode?.isHidden = true
                scene.hideContactDot()
            }
            return
        }

        let balls: [(key: String, pos: SCNVector3)] = onTableKeys.compactMap { key in
            guard !PositionPlayBall.isCue(key),
                  let node = scene.allBallNodes[key], !node.isHidden else { return nil }
            return (key, node.position)
        }
        freeAimContact = AngleSceneCalculator.freeAimFirstContact(cue: cue.position, dir: dir, balls: balls)

        if let contact = freeAimContact, let ghost = scene.ghostBallNode,
           let targetNode = scene.allBallNodes[contact.targetKey] {
            ghost.position = SCNVector3(contact.ghost.x, surfaceY + r, contact.ghost.z)
            ghost.isHidden = false
            // 重叠标注 L0（T-P18-42）：假想球圈 + 接触点绿点成对出现。
            scene.updateContactDot(ghostCenter: ghost.position, targetCenter: targetNode.position)
        } else {
            scene.ghostBallNode?.isHidden = true
            scene.hideContactDot()
        }
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
        solveScheduler.cancel()
        predictRerunWanted = false
        isComputing = false
    }

    /// 预测调度 =「去抖 + 单飞 + 末班车」（瞄准预测性能优化 P3 + 求解去抖 G14）：
    /// 去抖窗口内只保留最新意图；在途任务跑完后若期间有过新请求，只用**最新** UI 状态补跑一次
    /// （丢弃中间态）。一致性红线：`predictGeneration` 代际检查保留——任何最终上屏的解必对应最新一次
    /// intent，绝不展示旧解。
    ///
    /// - Parameter interactive: G14 语义。`true` = 连续交互（拖瞄准线/拖球/刻度轮微调）——拖动过程中
    ///   **不求解**，只保留纯几何预览（假想球/首碰点/瞄准线），停 0.5s（无新输入）后才触发求解；
    ///   `false` = 离散变更（点选目标/袋口、参数微调），按 ~20ms 快速触发（原手感）。
    func recompute(interactive: Bool = false) {
        // 序列模式（Q19.2④）：不做自由/袋口求解——逐杆预览与播放走专用状态机。
        guard !isPlaying, !isSequenceMode else { return }
        refreshFreeAimOverlay()

        guard currentShotIntent() != nil else {
            // 信息不全 ⇒ 作废在途/待跑求解（红线：清空后绝不让旧解回填上屏）。
            invalidatePendingPredict()
            clearTrajectory()
            isFeasible = false
            solvedShot = nil
            scene.hideCueStick()
            statusText = needsSetupHint()
            return
        }

        predictGeneration += 1
        if interactive {
            // 拖动中只做纯几何预览：清掉上一次求解的物理轨迹，避免与实时预览方向不一致的残影。
            isComputing = false
            showGeometryPreviewOnly()
        } else {
            isComputing = true
        }
        solveScheduler.schedule(interactive: interactive) { [weak self] in self?.launchSolveIfIdle() }
    }

    /// G14 拖动中的纯几何预览：保留 `refreshFreeAimOverlay` 刚刷新的假想球/接触点，
    /// 自由模式补一条闭式瞄准线（cue→假想球，空杆延伸到库边）并同步摆杆（C4）；清掉待物理求解的旧轨迹。
    private func showGeometryPreviewOnly() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
        if aimMode == .free {
            drawFreeAimPreviewLine()
        } else {
            // 袋口模式无闭式预览：拖动中隐藏残留假想球/接触点，球位实时跟随即为反馈。
            // C1：无线 ⇒ 藏杆。
            scene.ghostBallNode?.isHidden = true
            scene.hideContactDot()
            scene.hideCueStick()
        }
    }

    /// 自由模式闭式瞄准线预览（纯几何，逐帧）：母球 → 首碰假想球（无碰则延伸到库内边界）+ 球杆跟手。
    private func drawFreeAimPreviewLine() {
        guard aimMode == .free,
              let cue = scene.allBallNodes[PositionPlayBall.cueKey], !cue.isHidden,
              let dir = freeAimDir else {
            scene.hideCueStick()
            return
        }
        let end: SCNVector3
        if let contact = freeAimContact {
            end = SCNVector3(contact.ghost.x, cue.position.y, contact.ghost.z)
        } else {
            end = AngleSceneCalculator.rayToInnerRail(from: cue.position, dir: dir)
        }
        trajectoryNodes.append(scene.addLine(from: cue.position, to: end,
                                             color: .white, radius: TrajectoryStyle.aimRadius))
        // C4 / D-v19-3：预览线同现杆，实时跟随 `freeAimDir`。
        lastAimDirection = dir
        scene.updateCueStick(
            cueBallPosition: CueStroke.strikePosition(cue: cue.position, aim: dir, spinX: spinX),
            aimDirection: dir
        )
    }

    /// 去抖到期后的发射口（主线程）：空闲即按**当前**UI 状态起后台求解；在途则只记「末班车」标记。
    private func launchSolveIfIdle() {
        guard !isPlaying else { return }
        if predictInFlight {
            predictRerunWanted = true
            return
        }
        guard let intent = currentShotIntent() else { return }
        let before = currentSnapshot()
        let shot = intent
        let y = surfaceY
        let gen = predictGeneration
        predictInFlight = true
        isComputing = true   // 交互 idle 触发路径：求解真正开始时才亮出计算态（拖动预览期为 false）
        predictQueue.async { [weak self] in
            let pred = PositionPlayShotSolver.solve(before: before, shot: shot, surfaceY: y)
            DispatchQueue.main.async {
                guard let self else { return }
                self.predictInFlight = false
                // 末班车：在途期间来过新请求 ⇒ 用最新状态补跑（本结果 gen 已过期，下方代际检查自然丢弃）。
                if self.predictRerunWanted {
                    self.predictRerunWanted = false
                    self.launchSolveIfIdle()
                }
                guard self.predictGeneration == gen, !self.isPlaying else { return }
                self.isComputing = false
                guard let pred else {
                    self.isFeasible = false
                    self.solvedShot = nil
                    self.statusText = self.needsSetupHint()
                    return
                }
                self.solvedShot = SolvedShot(before: before, shot: shot, prediction: pred)
                self.apply(pred)
            }
        }
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
        // 轨迹重绘会先 hideAllVisualization（连带假想球）；自由模式重新亮出首碰覆盖层。
        if aimMode == .free { refreshFreeAimOverlay() }
    }

    /// Z1 副标题保持中性（T-P18-49 失误态去重）：母球进袋由 Z2 红 pill
    /// （`scratchPill`）唯一承担，副标题只描述轨迹/进球事实，状态不出现两次。
    private func makeStatus(_ p: ShotPrediction) -> String {
        if let solved = solvedShot, solved.shot.isFree {
            let potted = p.pocketedBalls.filter { $0 != ShotInput.cueBallName }
            if !potted.isEmpty {
                let labels = potted.map { PositionPlayBall.shortLabel(for: $0) }.joined(separator: "、")
                return "自由球 · \(labels) 号进袋"
            }
            return "自由球轨迹已就绪"
        }
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
        let shot = solvedShot?.shot
        // 全量口径（C3 / D2）：objectPath + rim extend + ghost←`.ghost`。
        // 自由球不显示假想球（与改前一致）。
        TrajectoryRenderer.draw(
            prediction: p,
            options: .positionPlay,
            context: .init(
                prediction: p,
                targetKey: shot?.targetKey ?? "",
                pocket: (shot?.isFree == false) ? shot?.pocket : nil,
                surfaceY: surfaceY,
                showGhost: shot.map { !$0.isFree } ?? false
            ),
            scene: scene,
            into: &trajectoryNodes
        )
    }

    private func clearTrajectory() {
        scene.clearResultNodes(nodes: &trajectoryNodes)
        scene.hideAllVisualization()
    }

    /// 点击球库中「已在桌上」的球时，对应桌上球做一次放大→恢复脉冲，提示其位置（#5a）。
    func pulseTableBall(_ key: String) {
        guard !isPlaying, let node = scene.allBallNodes[key], !node.isHidden else { return }
        TableBallPulse.pulse(node)
    }

    /// 选中环已移除（线语言 v2，条 12.3）：假想球圈 + 进球线已明确标示选中目标球，
    /// 绿色选中环属重复信息。保留方法名兜底清理历史节点，避免调用点大改。
    func refreshSelectionRing() {
        scene.clearResultNodes(nodes: &selectionNodes)
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
        lastPlaybackContext = (solved.before, solved.shot, solved.prediction)
        canPlayback = false
        lastShotWasRecorded = false
        canReplay = false
        isPlaying = true
        scene.clearResultNodes(nodes: &selectionNodes)   // 播放时隐藏选中环
        refreshFreeAimOverlay()                          // 播放时隐藏瞄准手柄/首碰预览
        statusText = "运杆…"

        let strikePos = strikePosition(cue: cueNode.position)
        let clearancePlayback = TrajectoryPlayback(
            recorder: recorder, surfaceY: surfaceY + AngleSceneCalculator.ballRadius
        )
        scene.runCueStroke(
            strikePosition: strikePos, aim: aim, velocity: Float(solved.shot.velocity),
            clearanceProbe: { clearancePlayback.allBallCentersByName(at: Float($0)) }
        ) { [weak self] in
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
        // G15：播到引擎自然静止（不做 0.07 感知截断），球停止前无最后一跳/瞬移。
        let settle = playback.duration

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
        canPlayback = true
        scene.hideCueStick()
        clearTrajectory()

        // 规则裁决（条 15.10）：把本杆物理事实交给宿主（自由击球页喂规则引擎）。
        onShotSettled?(makeShotFacts(solved: solved, potted: potted))

        // 自动选下一杆（#6）：距母球最近的目标球 + 距目标球最近的可进袋袋口。
        selectedTargetKey = nil
        autoSelectTarget()
        recompute()
    }

    /// 从预测结果提取规则引擎所需的物理事实（球名统一映射回桌面球键）。
    private func makeShotFacts(solved: SolvedShot, potted: Set<String>) -> ShotFacts {
        let events = solved.prediction.events
        let cueName = ShotInput.cueBallName

        var firstContactKey: String?
        var firstContactTime: Float?
        for e in events {
            if case .ballBall(let a, let b) = e.kind, a == cueName || b == cueName {
                firstContactKey = boardKey(forPredName: a == cueName ? b : a, shot: solved.shot)
                firstContactTime = e.time
                break
            }
        }

        var railOrPocketAfter = false
        if let t = firstContactTime {
            railOrPocketAfter = events.contains { e in
                guard e.time >= t else { return false }
                switch e.kind {
                case .ballCushion, .pocket: return true
                case .ballBall: return false
                }
            }
        }

        // 进球序列按落袋事件时间序；events 为空时退化为无序集合（predict/simulateFree 均填充 events）。
        var pocketedOrdered: [String] = []
        for e in events {
            if case .pocket(let ball, _) = e.kind {
                let key = boardKey(forPredName: ball, shot: solved.shot)
                if key != PositionPlayBall.cueKey, !pocketedOrdered.contains(key) {
                    pocketedOrdered.append(key)
                }
            }
        }
        if pocketedOrdered.isEmpty {
            pocketedOrdered = potted.filter { $0 != PositionPlayBall.cueKey }.sorted()
        }

        return ShotFacts(
            firstContactKey: firstContactKey,
            pocketedKeys: pocketedOrdered,
            cuePocketed: potted.contains(PositionPlayBall.cueKey),
            railOrPocketAfterContact: railOrPocketAfter,
            tableKeysBefore: Set(solved.before.onTable.keys)
                .subtracting([PositionPlayBall.cueKey])
        )
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
    ///
    /// **可连续点击逐杆回退**：录制中每次撤回序列末杆并退到其击打前；只要序列里还有杆，
    /// `canReplay` 保持 true，可一路退回到第一杆击打前（= 开局球形）。
    func replayCurrent() {
        guard !isPlaying else { return }
        if isRecording, let last = sequence.steps.last {
            sequence.steps.removeLast()
            sequence.updatedAt = Date()
            // 回退后「上一杆」变为序列新末杆（供再次重打 / 回上一杆球形）。
            lastShot = sequence.steps.last.map { ($0.before, $0.shot) }
            lastShotWasRecorded = lastShot != nil
            canReplay = !sequence.steps.isEmpty
            restoreShotParams(last.shot)
            applyBoard(last.before)
            updatePocketHighlights()
            return
        }
        // 未录制：单级回退（lastShot 一杆缓存）。
        guard let last = lastShot else { return }
        lastShotWasRecorded = false
        lastShot = nil
        canReplay = false
        canPlayback = false
        lastPlaybackContext = nil
        restoreShotParams(last.shot)
        applyBoard(last.before)
        updatePocketHighlights()
    }

    // MARK: - Playback（回放上一杆，布局规范 v2 条 18 / 条 15.7）

    /// 上一杆完整回放上下文。与「重打」不同：回放**不改变**桌面真相——退回击打前重播动画，
    /// 播完回到当前局面（after），参数/选中态/序列都不动。
    private var lastPlaybackContext: (before: BoardSnapshot, shot: PlannedShot, prediction: ShotPrediction)?
    @Published private(set) var canPlayback = false

    /// 回放上一杆击打过程（复用 `TrajectoryPlayback`，画面=物理）。
    func replayLastShot() {
        guard !isPlaying, !isBreakMode,
              let ctx = lastPlaybackContext,
              let recorder = ctx.prediction.recorder, ctx.prediction.duration > 0.05 else { return }
        let after = currentSnapshot()
        isPlaying = true
        scene.clearResultNodes(nodes: &selectionNodes)
        refreshFreeAimOverlay()
        clearTrajectory()
        statusText = "回放上一杆…"

        // 摆回击打前（不动选中态/参数——isPlaying 下 place/recompute 的求解结果会被丢弃）。
        scene.hideAllBalls()
        for (key, pt) in ctx.before.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()

        guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = aimDirection(path: ctx.prediction.cuePath, from: cueNode.position) else {
            finishPlayback(after: after)
            return
        }
        let strikePos = CueStroke.strikePosition(cue: cueNode.position, aim: aim, spinX: ctx.shot.spinX)
        let clearancePlayback = TrajectoryPlayback(
            recorder: recorder, surfaceY: surfaceY + AngleSceneCalculator.ballRadius
        )
        // C7：静止瞄准短定格（0～0.2s）后直接运杆；禁止出杆前 `hideCueStick` 闪帧。
        lastAimDirection = aim
        scene.updateCueStick(cueBallPosition: strikePos, aimDirection: aim)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard let self, self.isPlaying else { return }
            self.scene.runCueStroke(
                strikePosition: strikePos, aim: aim, velocity: Float(ctx.shot.velocity),
                clearanceProbe: { clearancePlayback.allBallCentersByName(at: Float($0)) }
            ) { [weak self] in
                self?.runPlaybackAnimation(ctx: ctx, recorder: recorder, after: after)
            }
        }
    }

    private func runPlaybackAnimation(
        ctx: (before: BoardSnapshot, shot: PlannedShot, prediction: ShotPrediction),
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
            if key == PositionPlayBall.cueKey {
                cueAction = action
            } else if let action {
                node.runAction(action)
            }
        }
        let tail: TimeInterval = ctx.prediction.pocketedBalls.isEmpty
            ? 0
            : TrajectoryPlayback.pocketSettleDuration + 0.1
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

    /// 回放收尾：清动画、恢复当前局面（after），重新求解。
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
        applyBoard(after)
        updatePocketHighlights()
    }

    /// 回到上一杆击打前的球形以便**临时再追加一杆**：恢复桌面与该杆参数，但**不删除**已录的那一杆
    /// （区别于 `replayCurrent()` 的「重打＝删末杆＋退回」）。`lastShot`/`canReplay`/`stepCount` 不变，
    /// 退回后再次击球将**追加**新的一杆、与已录的并存（允许从同一局面分叉补打）。
    func restorePreviousBoard() {
        guard !isPlaying, let last = lastShot else { return }
        restoreShotParams(last.shot)
        applyBoard(last.before)
        updatePocketHighlights()
    }

    /// 恢复一杆的全部击打参数（速度/打点/瞄准模式与方向或目标球+袋口）。
    /// 先恢复参数再 `applyBoard`：applyBoard 见目标球已选中且袋口有效不会触发自动重选，
    /// 最终 recompute 用恢复后的完整状态求解。
    private func restoreShotParams(_ shot: PlannedShot) {
        velocity = shot.velocity
        spinX = shot.spinX
        spinY = shot.spinY
        if shot.isFree {
            aimMode = .free
            if let canvasAim = shot.freeAim {
                freeAimDir = PositionPlayShotSolver.sceneDirection(fromCanvas: canvasAim)
            }
        } else {
            aimMode = .pocket
            selectedTargetKey = shot.targetKey
            if let idx = ShotIntent.pocketIndex(for: shot.pocket) {
                selectedPocketIndex = idx
            }
        }
    }

    /// 重置整条序列与桌面（回到默认球形）。录制中则丢弃录制。
    func resetAll() {
        guard !isPlaying else { return }
        isRecording = false
        lastShot = nil
        lastShotWasRecorded = false
        canReplay = false
        canPlayback = false
        lastPlaybackContext = nil
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
        canPlayback = false
        lastPlaybackContext = nil
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

    // MARK: - Sequence tryout mode（Q19.2④：动作库试打「序列」模式）

    /// 试打序列模式：按 drill 出片序列 `steps` 逐杆演示（隐藏打点/力度/瞄准控件，
    /// 点「击打」走完整序列，杆间停顿）。复用既有单杆回放骨架
    /// （`PositionPlayShotSolver.solve` + `scene.runCueStroke` + `TrajectoryPlayback`），不另造播放器。

    /// 逐杆信息（供 View 渲染当前杆的目标/袋口/打点/力度）。
    struct SequenceStepInfo {
        let index: Int          // 0-based
        let total: Int
        let isFree: Bool
        let targetLabel: String?
        let pocketName: String?
        let spinPhrase: String
        let powerPhrase: String
    }

    /// 序列模式激活标志（进袋/自由/序列三选一里的「序列」）。
    @Published private(set) var isSequenceMode = false
    /// 当前正在逐杆演示（一次「击打」走完整条序列）。
    @Published private(set) var isSequencePlaying = false
    /// 当前呈现/播放的杆序（0-based）。
    @Published private(set) var sequenceStepIndex = 0
    /// 演示是否已走完整条序列（终帧提示 + 「重摆球形」重来）。
    @Published private(set) var sequenceFinished = false

    private var sequenceSteps: [SequenceStep] = []
    /// 杆间停顿（秒）。
    private static let sequenceInterShotPause: TimeInterval = 0.7

    /// 该 drill 是否具备可逐杆播放的序列（≥1 杆）。
    var hasSequence: Bool { !sequenceSteps.isEmpty }

    /// 注入试打序列（View onAppear 调用一次）。
    func configureSequence(_ steps: [SequenceStep]) {
        sequenceSteps = steps
    }

    /// 当前杆结构化信息（无有效杆返回 nil）。
    var currentSequenceInfo: SequenceStepInfo? {
        guard sequenceStepIndex >= 0, sequenceStepIndex < sequenceSteps.count else { return nil }
        let step = sequenceSteps[sequenceStepIndex]
        return SequenceStepInfo(
            index: sequenceStepIndex,
            total: sequenceSteps.count,
            isFree: step.shot.isFree,
            targetLabel: step.shot.isFree ? nil : PositionPlayBall.shortLabel(for: step.shot.targetKey),
            pocketName: step.shot.isFree ? nil : PocketDisplay.name(id: step.shot.pocket),
            spinPhrase: DrillTryoutBrief.spinPhrase(x: step.shot.spinX, y: step.shot.spinY),
            powerPhrase: DrillTryoutBrief.powerPhrase(step.shot.velocity)
        )
    }

    /// 进入序列模式：复位到第 0 杆击打前并预览该杆轨迹。
    func enterSequenceMode() {
        guard hasSequence, !isPlaying, !isSequencePlaying else { return }
        invalidatePendingPredict()
        isSequenceMode = true
        isSequencePlaying = false
        sequenceFinished = false
        sequenceStepIndex = 0
        presentSequenceStep(0)
    }

    /// 退出序列模式（切到进袋/自由）：清预览态，交由宿主 `loadBoard(initial)` 恢复正常求解。
    func exitSequenceMode() {
        guard isSequenceMode else { return }
        isSequencePlaying = false
        isSequenceMode = false
        sequenceFinished = false
        clearTrajectory()
        scene.hideCueStick()
    }

    /// 「重摆球形」在序列模式下 = 从头重演（复位到第 0 杆）。
    func restartSequence() {
        guard isSequenceMode, !isPlaying, !isSequencePlaying else { return }
        sequenceFinished = false
        sequenceStepIndex = 0
        presentSequenceStep(0)
    }

    /// 呈现第 i 杆击打前局面 + 预览轨迹/瞄准（静态，不播放）。
    private func presentSequenceStep(_ i: Int) {
        guard i >= 0, i < sequenceSteps.count else { return }
        sequenceStepIndex = i
        let step = sequenceSteps[i]
        scene.hideAllBalls()
        for (key, pt) in step.before.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()
        // 恢复该杆参数供假想球/瞄准线绘制（didSet 的 recompute 已被 isSequenceMode 拦截）。
        restoreShotParams(step.shot)
        if let pred = PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: surfaceY),
           pred.feasible {
            solvedShot = SolvedShot(before: step.before, shot: step.shot, prediction: pred)
            apply(pred)
        } else {
            solvedShot = nil
            clearTrajectory()
            scene.hideCueStick()
        }
        statusText = sequenceStatusText(i)
    }

    /// 一次「击打」从当前呈现杆走完整条序列（逐杆播放、杆间停顿）。
    func playSequence() {
        guard isSequenceMode, hasSequence, !isPlaying, !isSequencePlaying else { return }
        isSequencePlaying = true
        sequenceFinished = false
        runSequenceStep(sequenceFinished ? 0 : sequenceStepIndex)
    }

    private func runSequenceStep(_ i: Int) {
        guard isSequencePlaying, i < sequenceSteps.count else {
            finishSequencePlayback()
            return
        }
        sequenceStepIndex = i
        let step = sequenceSteps[i]
        // 摆回该杆击打前。
        scene.hideAllBalls()
        for (key, pt) in step.before.onTable { place(key: key, normalized: pt) }
        refreshOnTableKeys()
        restoreShotParams(step.shot)

        guard let pred = PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: surfaceY),
              pred.feasible, let recorder = pred.recorder, pred.duration > 0.05,
              let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = aimDirection(path: pred.cuePath, from: cueNode.position) else {
            // 本杆不可行：直接落到该杆结果并推进（不阻断整条演示）。
            clearTrajectory()
            scene.hideCueStick()
            applySequenceRest(step: step, prediction: nil)
            scheduleNextSequenceStep(after: i)
            return
        }

        // C7：预告线 + 杆同现 → 静止瞄准定格 0.3～0.5s → 直接运杆（出杆前不 hide）。
        apply(pred)
        let strikePos = CueStroke.strikePosition(cue: cueNode.position, aim: aim, spinX: step.shot.spinX)
        lastAimDirection = aim
        scene.updateCueStick(cueBallPosition: strikePos, aimDirection: aim)
        isPlaying = true
        statusText = sequenceStatusText(i) + " · 瞄准…"
        let clearancePlayback = TrajectoryPlayback(
            recorder: recorder, surfaceY: surfaceY + AngleSceneCalculator.ballRadius
        )
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, self.isSequencePlaying, self.isPlaying else { return }
            self.statusText = self.sequenceStatusText(i) + " · 运杆…"
            self.scene.runCueStroke(
                strikePosition: strikePos, aim: aim, velocity: Float(step.shot.velocity),
                clearanceProbe: { clearancePlayback.allBallCentersByName(at: Float($0)) }
            ) { [weak self] in
                self?.runSequencePlayback(step: step, prediction: pred, recorder: recorder, index: i)
            }
        }
    }

    /// 触球瞬间：收杆、按真实轨迹回放球体（复用 `TrajectoryPlayback` 骨架）。
    private func runSequencePlayback(step: SequenceStep, prediction: ShotPrediction,
                                     recorder: TrajectoryRecorder, index i: Int) {
        statusText = sequenceStatusText(i) + " · 击球中…"
        clearTrajectory()
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let settle = playback.duration   // G15：播到引擎自然静止

        var cueAction: SCNAction?
        for key in onTableKeys {
            guard let node = scene.allBallNodes[key], !node.isHidden else { continue }
            let name = PositionPlayShotSolver.predName(boardKey: key, shot: step.shot)
            let action = playback.action(for: node, ballName: name, speed: 1.0,
                                         removeOnPocket: false, maxSimTime: settle)
            if key == PositionPlayBall.cueKey {
                cueAction = action
            } else if let action {
                node.runAction(action)
            }
        }
        let tail: TimeInterval = prediction.pocketedBalls.isEmpty
            ? 0
            : TrajectoryPlayback.pocketSettleDuration + 0.1
        if let cueAction, let cueNode = scene.allBallNodes[PositionPlayBall.cueKey] {
            cueNode.runAction(cueAction) { [weak self] in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(tail * 1_000_000_000))
                    guard let self else { return }
                    self.applySequenceRest(step: step, prediction: prediction)
                    self.scheduleNextSequenceStep(after: i)
                }
            }
            ShotAudioScheduler.shared.play(prediction: prediction)
        } else {
            applySequenceRest(step: step, prediction: prediction)
            scheduleNextSequenceStep(after: i)
        }
    }

    /// 一杆演示收尾：把球体落到静止位（有预测用引擎终位，否则用录制 after），清动画。
    private func applySequenceRest(step: SequenceStep, prediction: ShotPrediction?) {
        ShotAudioScheduler.shared.cancel()
        let yLevel = surfaceY + AngleSceneCalculator.ballRadius
        if let pred = prediction {
            let potted = Set(pred.pocketedBalls.map { boardKey(forPredName: $0, shot: step.shot) })
            for key in onTableKeys {
                guard let node = scene.allBallNodes[key] else { continue }
                if node.parent == nil { scene.rootNode.addChildNode(node) }
                node.removeAllActions()
                node.opacity = 1
                if potted.contains(key) {
                    node.isHidden = true
                } else {
                    node.isHidden = false
                    let predName = PositionPlayShotSolver.predName(boardKey: key, shot: step.shot)
                    if let p = pred.finalPositions[predName] {
                        node.position = SCNVector3(p.x, yLevel, p.z)
                    }
                }
            }
        } else {
            scene.hideAllBalls()
            for (key, pt) in step.after.onTable { place(key: key, normalized: pt) }
        }
        refreshOnTableKeys()
        isPlaying = false
        scene.hideCueStick()
        clearTrajectory()
    }

    private func scheduleNextSequenceStep(after i: Int) {
        guard isSequencePlaying else { return }
        let next = i + 1
        guard next < sequenceSteps.count else {
            finishSequencePlayback()
            return
        }
        statusText = sequenceStatusText(next) + " ·（衔接下一杆…）"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.sequenceInterShotPause * 1_000_000_000))
            guard self.isSequencePlaying else { return }
            self.runSequenceStep(next)
        }
    }

    private func finishSequencePlayback() {
        isSequencePlaying = false
        isPlaying = false
        sequenceFinished = true
        scene.hideCueStick()
        statusText = "序列演示完成 · 点「重摆球形」再看一遍"
    }

    /// 序列模式副标题：第 n/N 杆 · 打 X 号 → 袋口 · 打点 · 力度。
    private func sequenceStatusText(_ i: Int) -> String {
        guard i >= 0, i < sequenceSteps.count else { return "序列演示完成" }
        let step = sequenceSteps[i]
        var parts = ["第 \(i + 1)/\(sequenceSteps.count) 杆"]
        if step.shot.isFree {
            parts.append("自由球")
        } else {
            let target = PositionPlayBall.shortLabel(for: step.shot.targetKey)
            let pocket = PocketDisplay.name(id: step.shot.pocket)
            parts.append(pocket == "—" ? "打 \(target) 号" : "打 \(target) 号 → \(pocket)")
        }
        parts.append(DrillTryoutBrief.spinPhrase(x: step.shot.spinX, y: step.shot.spinY))
        parts.append(DrillTryoutBrief.powerPhrase(step.shot.velocity))
        return parts.joined(separator: " · ")
    }

    // MARK: - Break flow（T-P18-47：内置开球，替代球形生成器页）

    /// 开球模式 runner。非 nil = 开球模式：台面交互与求解全部挂起，
    /// 拖拽路由到 runner（母球限开球区），停稳散局落座为新真相。
    @Published private(set) var breakRunner: BreakFlowRunner?
    var isBreakMode: Bool { breakRunner != nil }
    /// 进开球模式前的桌面（取消开球时恢复）。
    private var boardBeforeBreak: BoardSnapshot?
    private var breakChangeForwarder: AnyCancellable?

    /// 进入开球模式：保存当前桌面 → 挂起求解与可视化 → 摆架。
    /// `manualDeliver`（K6 / D-v8-3a）：停稳后不自动落座，由「取消/重开/完成」
    /// 三态决定何时交付击打阶段。默认 true（自由击球 + Composer 统一手动交付）。
    func startBreakFlow(game: RackGame, manualDeliver: Bool = true) {
        guard !isPlaying, !isRecording, breakRunner == nil else { return }
        invalidatePendingPredict()
        clearTrajectory()
        scene.clearResultNodes(nodes: &selectionNodes)
        scene.hideCueStick()
        boardBeforeBreak = currentSnapshot()
        let runner = BreakFlowRunner(scene: scene, game: game)
        runner.autoDeliverOnSettle = !manualDeliver
        // 嵌套 ObservableObject 的变化上抛，驱动宿主视图刷新。
        breakChangeForwarder = runner.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
        runner.onSettled = { [weak self] board in
            guard let self else { return }
            self.teardownBreakFlow()
            self.loadBoard(board)
            self.statusText = "开球散局已落座 · 可直接编排击打"
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

// MARK: - Solve trigger debounce (G14)

/// 求解触发去抖调度（问题集合 v5 · G14）：把「何时真正发起求解」与求解本身解耦，便于单测时序而
/// 不触真实求解。
/// - **交互态**（拖瞄准线 / 拖球 / 刻度轮微调）：每次输入都取消上一次待跑并按 `idleInterval` 重排，
///   故拖动过程中持续输入 ⇒ 永不触发；停止输入（无新调用）满 `idleInterval` 后才触发一次。
/// - **离散态**（点选目标/袋口、参数微调）：按 `fastInterval` 触发（保留原 ~20ms 手感）。
@MainActor
final class SolveDebounceScheduler {
    /// G14 规范：拖动/连续调节停止后，停 0.5s（无新输入）才触发求解。
    static let defaultIdleInterval: TimeInterval = 0.5
    /// 离散变更的快速去抖（原 `recompute` 20ms）。
    static let defaultFastInterval: TimeInterval = 0.02

    var idleInterval: TimeInterval
    var fastInterval: TimeInterval

    /// 延时执行注入点（默认主队列 asyncAfter）；单测替换为可控实现，断言时序而不等待真实时间。
    var scheduleAfter: (TimeInterval, DispatchWorkItem) -> Void = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private(set) var pending: DispatchWorkItem?
    /// 最近一次排程使用的延时（单测断言：交互态 == idleInterval、离散态 == fastInterval）。
    private(set) var lastScheduledDelay: TimeInterval?

    init(idleInterval: TimeInterval = SolveDebounceScheduler.defaultIdleInterval,
         fastInterval: TimeInterval = SolveDebounceScheduler.defaultFastInterval) {
        self.idleInterval = idleInterval
        self.fastInterval = fastInterval
    }

    /// 排一次求解触发；重复调用取消上一次待跑（拖动中每帧调用 ⇒ 只留最后一次）。
    func schedule(interactive: Bool, _ fire: @escaping () -> Void) {
        pending?.cancel()
        let work = DispatchWorkItem(block: fire)
        pending = work
        let delay = interactive ? idleInterval : fastInterval
        lastScheduledDelay = delay
        scheduleAfter(delay, work)
    }

    func cancel() {
        pending?.cancel()
        pending = nil
        lastScheduledDelay = nil
    }

    /// 是否有未取消的待跑求解（单测辅助）。
    var hasPending: Bool { pending.map { !$0.isCancelled } ?? false }
}
