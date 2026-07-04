import Foundation
import SceneKit
import SwiftUI

/// 分离角 / 轨迹模拟页的 ViewModel。
/// 复用 `AngleTrainingScene` 渲染与 `AngleSceneView` 拖球/点袋交互；
/// 参数（袋口 / 力度 / 塞）变化时在**后台线程**调用 `ShotPredictor` 预测（避免主线程卡顿），
/// 主线程绘制轨迹；点「播放」用 `TrajectoryRecorder` 的 `SCNAction` 序列让球沿轨迹运动，
/// 播放结束后复位球并重新显示原轨迹。
@MainActor
final class ShotSimulationViewModel: ObservableObject {

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var pocketMarkers: [SCNNode] = []
    private var trajectoryNodes: [SCNNode] = []

    // MARK: - Aim mode (P18 B2 T-P18-09)

    /// 瞄准模式：`auto` = 引擎闭环求瞄（原行为）；`manual` = 用户手动定方向、
    /// `simulateFree` 如实模拟（进不进如实展示），并叠加自动解虚线对比。
    enum AimMode: String, CaseIterable {
        case auto
        case manual
    }

    @Published var aimMode: AimMode = .auto {
        didSet {
            guard oldValue != aimMode, !isPlaying else { return }
            // 切手动时以当前自动解方向为初值，用户从「正确答案」出发微调。
            if aimMode == .manual, freeAimDir == nil { freeAimDir = lastAimDirection }
            recompute()
        }
    }

    /// 手动模式瞄准方向（场景 XZ 单位向量）。
    @Published private(set) var freeAimDir: SCNVector3?
    /// 手动模式首碰预览（纯几何逐帧）：首碰球 + 假想球 + 切球角。nil = 空杆。
    @Published private(set) var freeAimContact: AngleSceneCalculator.FreeAimContact?
    /// 瞄准手柄离母球的期望距离（米），拖动手柄时跟随手指径向距离。
    private var freeAimHandleDist: Float = 0.38
    /// 手动模拟里目标球在引擎中的球名（用真实球键 `_8`，进球线随球色）。
    private let manualTargetName = "_8"

    // MARK: - Published params

    @Published var selectedPocketIndex: Int = -1
    /// 连续杆头速度 (m/s)，与走位编排台同一滑条交互（ADR-P11-09）；默认中等力度 3.3。
    @Published var velocity: Double = 3.3 { didSet { if !isPlaying { recompute() } } }
    @Published var spinX: Double = 0 { didSet { if !isPlaying { recompute() } } }
    @Published var spinY: Double = 0 { didSet { if !isPlaying { recompute() } } }

    // MARK: - Published state

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    @Published private(set) var isDragging = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isComputing = false
    @Published private(set) var isFeasible = true
    /// 瞄准线与进球线的夹角（切球角 α），替代旧「分离角」展示。
    @Published private(set) var cutAngleDeg: Double?
    @Published private(set) var objectPocketed = false
    @Published private(set) var cuePocketed = false
    /// 贴库困难球软提示：进球点偏离袋口标记较远（与「角度与打点」页同一判据），可进但建议换袋口。
    @Published private(set) var nearCushionHint = false
    @Published private(set) var statusText: String = "点击袋口选择目标袋"

    private var lastPrediction: ShotPrediction?
    /// 瞄准/调整阶段球杆指向的单位方向（母球→假想球，取自真实轨迹首段），击打动画沿此方向出杆。
    private var lastAimDirection: SCNVector3?
    /// 手动模式的自动解对比缓存：自动解只随「球位/袋口/力度/塞」变化、与手动方向无关，
    /// 按输入键缓存后拖瞄准手柄时零重复求解。
    private var autoCompareKey: String?
    private var autoComparePred: ShotPrediction?

    // MARK: - Background prediction

    private let predictQueue = DispatchQueue(label: "com.qiuji.shot-predict", qos: .userInitiated)
    private var predictGeneration = 0
    /// 防抖/合并：拖动时每帧都会触发 recompute，用一个可取消的 work item 合并为最后一次，
    /// 避免在串行队列上堆积陈旧的求解任务（卡顿主因之一）。
    private var pendingPredict: DispatchWorkItem?

    var draggableBalls: [SCNNode] {
        [scene.cueBallNode, scene.targetBallNodes.first].compactMap { $0 }
    }

    // MARK: - Setup

    func setupScene() {
        scene.setupScene()
        // 复用「角度与打点」的教学可视化节点（假想球 / 打点 / 切球角弧线）。
        scene.setupVisualizationNodes()
        scene.setupAimHandle()
        pocketMarkers = scene.addPocketMarkers()
        placeBallsAtDefaults()
        selectBestPocket()
        recompute()
    }

    /// 默认摆一个清晰可进的中等角度球（目标球靠近右上角袋，母球在左下方）。
    private func placeBallsAtDefaults() {
        let surfaceY = scene.surfaceY
        let r = AngleSceneCalculator.ballRadius
        let cuePos = SCNVector3(-0.35, surfaceY + r, 0.22)
        let targetPos = SCNVector3(0.55, surfaceY + r, -0.18)
        scene.applyBallLayout(cueBallPosition: cuePos, targetBallNumber: 8, targetPosition: targetPos)
        scene.hideCueStick()
    }

    func reset() {
        guard !isPlaying else { return }
        clearTrajectory()
        placeBallsAtDefaults()
        selectBestPocket()
        // 手动方向随球位失效：清空后由默认方向（自动解）重新出发。
        freeAimDir = nil
        lastAimDirection = nil
        autoCompareKey = nil
        autoComparePred = nil
        recompute()
    }

    // MARK: - Drag

    func dragBegan(node: SCNNode) {
        guard !isPlaying else { return }
        isDragging = true
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.15, duration: 0.1), forKey: "dragPulse")
    }

    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        guard !isPlaying else { return }
        let cue = scene.cueBallNode
        let target = scene.targetBallNodes.first
        let other = (node === cue) ? target : cue
        guard let other else { return }
        var clamped = AngleSceneCalculator.clampBallPosition(
            worldPosition, otherBall: other.position, surfaceY: scene.surfaceY
        )
        clamped = AngleSceneCalculator.clampAwayFromPockets(clamped, surfaceY: scene.surfaceY)
        node.position = clamped
        recompute()
    }

    func dragEnded(node: SCNNode) {
        guard !isPlaying else { return }
        isDragging = false
        node.removeAction(forKey: "dragPulse")
        node.runAction(SCNAction.scale(by: 1.0 / 1.15, duration: 0.15))
        recompute()
    }

    // MARK: - Manual aim (P18 B2 T-P18-09)

    /// 场景瞄准手柄拖动：手指落点 → 新瞄准方向（母球 → 落点），
    /// 并记住手指径向距离让手柄跟手（离球远 = 粗调，离球近 = 细调）。
    func handleAimHandleDrag(world: SCNVector3) {
        guard aimMode == .manual, !isPlaying, let cue = scene.cueBallNode else { return }
        let dist = AngleSceneCalculator.horizontalDistance(cue.position, world)
        if dist > 0.02 { freeAimHandleDist = max(0.15, min(1.2, dist)) }
        let dx = world.x - cue.position.x
        let dz = world.z - cue.position.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 0.02 else { return }
        freeAimDir = SCNVector3(dx / len, 0, dz / len)
        recompute()
    }

    /// 手动瞄准方向的屏幕罗盘角（坐标契约见 `AngleSceneCalculator.bearingDeg`）。
    var freeAimBearingDeg: Float? {
        guard aimMode == .manual, let d = freeAimDir else { return nil }
        return AngleSceneCalculator.bearingDeg(of: d)
    }

    /// 角度齿轮微调：`delta > 0` = 屏幕顺时针，与编排台自由模式同语义。
    func nudgeFreeAim(byDegrees delta: Float) {
        guard aimMode == .manual, !isPlaying, abs(delta) > 1e-4 else { return }
        let base = freeAimDir ?? defaultManualAim()
        freeAimDir = AngleSceneCalculator.rotatedAim(base, byDegrees: delta)
        recompute()
    }

    /// 手动模式默认方向：自动解瞄准方向（从正确答案出发微调）→ 退化为指向目标球。
    private func defaultManualAim() -> SCNVector3 {
        if let aim = lastAimDirection { return aim }
        if let cue = scene.cueBallNode, let target = scene.targetBallNodes.first {
            let dx = target.position.x - cue.position.x
            let dz = target.position.z - cue.position.z
            let len = sqrtf(dx * dx + dz * dz)
            if len > 0.02 { return SCNVector3(dx / len, 0, dz / len) }
        }
        return SCNVector3(1, 0, 0)
    }

    /// 刷新手动瞄准覆盖层：首碰预览（假想球贴目标球滑动）+ 手柄位置。
    /// 非手动模式 / 播放中全部隐藏。轨迹线仍由后台 `simulateFree` 异步补齐。
    private func refreshManualOverlay() {
        let r = AngleSceneCalculator.ballRadius
        guard aimMode == .manual, !isPlaying,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first,
              let dir = freeAimDir else {
            freeAimContact = nil
            scene.updateAimHandle(position: nil)
            if aimMode == .manual { scene.ghostBallNode?.isHidden = true }
            return
        }
        freeAimContact = AngleSceneCalculator.freeAimFirstContact(
            cue: cue.position, dir: dir, balls: [(manualTargetName, target.position)]
        )
        if let contact = freeAimContact, let ghost = scene.ghostBallNode {
            ghost.position = SCNVector3(contact.ghost.x, scene.surfaceY + r, contact.ghost.z)
            ghost.isHidden = false
        } else {
            scene.ghostBallNode?.isHidden = true
        }

        // 手柄：瞄准射线上、库边以内；有首碰时收在假想球之前，避免视觉重叠。
        var handleT = freeAimHandleDist
        if let contact = freeAimContact {
            let toGhost = AngleSceneCalculator.horizontalDistance(cue.position, contact.ghost)
            handleT = min(handleT, max(0.12, toGhost - 0.10))
        }
        handleT = min(handleT, AngleSceneCalculator.rayDistanceToCushion(from: cue.position, dir: dir))
        scene.updateAimHandle(position: SCNVector3(
            cue.position.x + dir.x * handleT, scene.surfaceY + 0.008, cue.position.z + dir.z * handleT
        ))
    }

    // MARK: - Pocket selection

    func selectPocket(at index: Int) {
        guard !isPlaying else { return }
        selectedPocketIndex = index
        updatePocketHighlights()
        recompute()
    }

    private func selectBestPocket() {
        guard let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let count = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY).count
        var best = 0
        var bestAngle = Double.greatestFiniteMagnitude
        for i in 0..<count {
            let aim = AngleSceneCalculator.effectivePocketAimPoint(
                targetBall: target.position, pocketIndex: i, surfaceY: scene.surfaceY
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

    // MARK: - Compute (background) & draw

    func recompute() {
        refreshManualOverlay()   // 手动模式逐帧覆盖层；非手动模式即隐藏手柄/首碰预览
        guard let cue = scene.cueBallNode, let target = scene.targetBallNodes.first,
              selectedPocketIndex >= 0 else {
            clearTrajectory()
            statusText = "点击袋口选择目标袋"
            return
        }

        let input = ShotInput(
            cueBall: cue.position,
            targetBall: target.position,
            pocketIndex: selectedPocketIndex,
            velocity: Float(velocity),
            spinX: Float(spinX),
            spinY: Float(spinY),
            surfaceY: scene.surfaceY
        )

        if aimMode == .manual {
            recomputeManual(input: input, cuePos: cue.position, targetPos: target.position)
            return
        }

        predictGeneration += 1
        let gen = predictGeneration
        isComputing = true

        // 合并连续触发：取消上一个尚未开始的求解，12ms 防抖后再跑。配合 Han 闭式库边
        // 模型（单次预测降到几十毫秒），拖动时只对最后一帧求解，UI 即时刷新不堆积。
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
        predictQueue.asyncAfter(deadline: .now() + 0.012, execute: work)
    }

    /// 手动模式求解（T-P18-09）：用户方向 `simulateFree` 如实模拟（不求瞄、恒 feasible），
    /// 并求一次自动解（按输入键缓存——与手动方向无关，拖手柄时零重复求解）作虚线对照。
    private func recomputeManual(input: ShotInput, cuePos: SCNVector3, targetPos: SCNVector3) {
        let dir: SCNVector3
        if let d = freeAimDir {
            dir = d
        } else {
            // 尚无方向（如刚切手动且自动解未就绪）：从默认方向出发。
            let d = defaultManualAim()
            freeAimDir = d
            dir = d
            refreshManualOverlay()
        }

        predictGeneration += 1
        let gen = predictGeneration
        isComputing = true

        let autoKey = "\(cuePos.x),\(cuePos.z)|\(targetPos.x),\(targetPos.z)|" +
                      "\(selectedPocketIndex)|\(velocity)|\(spinX)|\(spinY)"
        let cachedAuto = autoCompareKey == autoKey ? autoComparePred : nil
        let targetName = manualTargetName
        let y = scene.surfaceY

        pendingPredict?.cancel()
        let work = DispatchWorkItem { [weak self] in
            let pred = ShotPredictor.simulateFree(
                cueBall: cuePos, aimDir: dir,
                velocity: input.velocity, spinX: input.spinX, spinY: input.spinY,
                surfaceY: y, balls: [ObstacleBall(name: targetName, position: targetPos)]
            )
            let auto = cachedAuto ?? ShotPredictor.predict(input)
            DispatchQueue.main.async {
                guard let self, self.predictGeneration == gen, !self.isPlaying else { return }
                self.isComputing = false
                self.autoCompareKey = autoKey
                self.autoComparePred = auto
                self.applyManual(pred, auto: auto)
            }
        }
        pendingPredict = work
        predictQueue.asyncAfter(deadline: .now() + 0.012, execute: work)
    }

    private func apply(_ pred: ShotPrediction) {
        lastPrediction = pred
        isFeasible = pred.feasible

        guard pred.feasible else {
            cutAngleDeg = pred.cutAngleDeg
            objectPocketed = false
            cuePocketed = false
            nearCushionHint = false
            statusText = pred.infeasibleReason.isEmpty ? "当前角度无法进袋" : pred.infeasibleReason
            clearTrajectory()
            scene.hideCueStick()
            lastAimDirection = nil
            return
        }

        cutAngleDeg = pred.cutAngleDeg
        objectPocketed = pred.objectPocketed
        cuePocketed = pred.cuePocketed
        // 贴库软提示：与「角度与打点」页同一判据（进球点偏离袋口标记 > 1.5×R）。
        if let target = scene.targetBallNodes.first {
            nearCushionHint = !AngleSceneCalculator.isPocketReachable(
                target: target.position, pocketIndex: selectedPocketIndex, surfaceY: scene.surfaceY
            )
        }
        statusText = makeStatus(pred)
        drawTrajectory(pred)
        updateCueStickAiming(pred)
    }

    /// 手动模式上屏（T-P18-09）：如实展示用户方向的模拟结局 + 自动解虚线对照。
    private func applyManual(_ pred: ShotPrediction, auto: ShotPrediction) {
        lastPrediction = pred
        isFeasible = true                       // simulateFree 恒可模拟；进不进由结局说话
        cutAngleDeg = freeAimContact?.cutAngleDeg
        objectPocketed = pred.objectPocketed
        cuePocketed = pred.cuePocketed
        nearCushionHint = false
        lastAimDirection = freeAimDir

        if pred.cuePocketed {
            statusText = "母球进袋（失误）"
        } else if pred.objectPocketed {
            statusText = "进袋（手动瞄准）"
        } else if freeAimContact == nil {
            statusText = "空杆 · 当前方向碰不到目标球"
        } else {
            statusText = "未进袋 · 微调方向或对照虚线"
        }
        drawManualTrajectory(pred, auto: auto)
        updateManualCueStick()
    }

    /// 进袋判定取自**真实模拟**（画面=物理）：不同角度/力度/塞会真实影响能否进袋。
    private func makeStatus(_ p: ShotPrediction) -> String {
        if p.cuePocketed { return "母球进袋（失误）" }
        if p.objectPocketed {
            return nearCushionHint ? "进袋（贴库球）" : "进袋"
        }
        // 几何可行但真实模拟未落袋：多为切角过薄或力度不足导致擦喉口/能量不够。
        return "未进袋（试试加大力度或选角度更小的袋口）"
    }

    // MARK: - Trajectory drawing

    private func drawTrajectory(_ p: ShotPrediction) {
        clearTrajectory()
        // 母球轨迹（白）：取自真实模拟，起始段即「瞄准线」，碰后展示走位（分离角/跟缩/吃库）。
        addPolyline(p.cuePath, color: TrajectoryStyle.aimColor, radius: TrajectoryStyle.aimRadius)
        // 目标球轨迹：随目标球球色（本页目标球为黑 8 → 亮灰，ADR-P11-12）。
        addPolyline(p.objectPath, color: TrajectoryStyle.potColor(for: "_8"),
                    radius: TrajectoryStyle.potRadius)
        drawPottingPerpendicular(p)
        if UserPreferences.shared.showSeparationAngle {
            scene.addSeparationAngleLine(for: p, into: &trajectoryNodes)
        }
        showTeachingAnnotations(p)
    }

    /// 教学标注：复用 `AngleTrainingScene` 的假想球（黄）、打点（黄）与切球角弧线 + α° 数字，
    /// 与「角度与打点」页保持一致的视觉语言。本页已自绘瞄准线（白）/进球线（橙）/进球垂线（青），
    /// 故隐藏 `updateVisualization` 中重复的撞击线 / 进球线 / 垂线，仅保留教学性的假想球、打点、角弧。
    private func showTeachingAnnotations(_ p: ShotPrediction) {
        guard let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        scene.updateVisualization(
            cueBall: cue.position, targetBall: target.position, pocket: p.pocketAimPoint,
            showAngleAnnotations: true, showLineLabels: false
        )
        scene.strikeLineNode?.isHidden = true
        scene.pocketLineNode?.isHidden = true
        scene.perpLineNode?.isHidden = true
    }

    /// 手动模式绘制：自动解（浅蓝虚线，母球+目标球）打底 + 用户方向真实轨迹实线覆盖。
    private func drawManualTrajectory(_ p: ShotPrediction, auto: ShotPrediction) {
        clearTrajectory()
        if auto.feasible {
            let idealBlue = UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 0.8)
            addDashedPath(auto.cuePath, color: idealBlue)
            addDashedPath(auto.objectPath, color: idealBlue)
        }
        addPolyline(p.cuePath, color: TrajectoryStyle.aimColor, radius: TrajectoryStyle.aimRadius)
        for (key, pts) in p.extraBallPaths {
            addPolyline(pts, color: TrajectoryStyle.potColor(for: key),
                        radius: TrajectoryStyle.potRadius)
        }
        if UserPreferences.shared.showSeparationAngle {
            scene.addSeparationAngleLine(for: p, into: &trajectoryNodes)
        }
        // clearTrajectory 的 hideAllVisualization 连带藏了假想球——重亮首碰覆盖层。
        refreshManualOverlay()
    }

    /// 沿折线按弧长铺虚线（dash 3cm / gap 2.2cm）：真实轨迹采样点很密，逐段 `addDashedLine`
    /// 会退化成实线；这里按累计弧长切换 on/off 再落段。
    private func addDashedPath(_ pts: [SCNVector3], color: UIColor,
                               radius: Float = 0.0026, dash: Float = 0.03, gap: Float = 0.022) {
        guard pts.count >= 2 else { return }
        let period = dash + gap
        var arc: Float = 0
        var segStart: SCNVector3?
        func lerp(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
            SCNVector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
        }
        for i in 0..<(pts.count - 1) {
            let a = pts[i], b = pts[i + 1]
            let len = AngleSceneCalculator.horizontalDistance(a, b)
            guard len > 1e-6 else { continue }
            var t: Float = 0
            while t < len {
                let phase = (arc + t).truncatingRemainder(dividingBy: period)
                if phase < dash {
                    // on 段：起点（若尚未开段）→ 本段 on 剩余长度与折线段剩余长度的较小者
                    if segStart == nil { segStart = lerp(a, b, t / len) }
                    let step = min(dash - phase, len - t)
                    t += step
                    if (arc + t).truncatingRemainder(dividingBy: period) >= dash || t >= len {
                        let end = lerp(a, b, t / len)
                        if let s = segStart {
                            trajectoryNodes.append(scene.addLine(from: s, to: end,
                                                                 color: color, radius: radius))
                        }
                        // 段收口：跨折线顶点的 on 段在顶点处断开（视觉无感），避免跨段插值。
                        segStart = nil
                    }
                } else {
                    t += min(period - phase, len - t)
                }
            }
            arc += len
        }
    }

    /// 手动模式球杆：沿用户方向摆杆（侧塞横移与自动模式同口径）。
    private func updateManualCueStick() {
        guard !isPlaying, let cue = scene.cueBallNode, let aim = freeAimDir else {
            scene.hideCueStick()
            return
        }
        let r = AngleSceneCalculator.ballRadius
        let perp = SCNVector3(-aim.z, 0, aim.x)
        let lateral = Float(spinX) * r
        let pos = SCNVector3(cue.position.x + perp.x * lateral,
                             cue.position.y,
                             cue.position.z + perp.z * lateral)
        scene.updateCueStick(cueBallPosition: pos, aimDirection: aim)
    }

    /// 画一条与进球线（目标球→袋口）垂直的虚线，过目标球中心，作为「加杆法」参考：
    /// 定杆时母球沿此线离开（90° 法则）、高杆偏前、低杆偏后。
    private func drawPottingPerpendicular(_ p: ShotPrediction) {
        guard let target = scene.targetBallNodes.first else { return }
        let t = target.position
        let dx = p.pocketAimPoint.x - t.x
        let dz = p.pocketAimPoint.z - t.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 0.001 else { return }
        let px = -dz / len, pz = dx / len           // 垂直于进球线的单位向量
        let half: Float = 0.32
        let a = SCNVector3(t.x - px * half, t.y, t.z - pz * half)
        let b = SCNVector3(t.x + px * half, t.y, t.z + pz * half)
        let node = scene.addDashedLine(
            from: a, to: b,
            color: UIColor(red: 0.30, green: 0.85, blue: 0.95, alpha: 0.9),
            radius: 0.0028, dash: 0.026, gap: 0.020
        )
        trajectoryNodes.append(node)
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

    // MARK: - Cue stick (aiming aid)

    /// 瞄准/调整阶段在母球后方显示球杆：
    /// - 方向对准假想球——取真实母球轨迹首段方向（即瞄准线），与教学可视化一致；
    /// - 侧塞（左右）把球杆横移到真实接触点，直观对应打点盘；高/低塞在俯视 2D 不可见，故不表现。
    /// 击打中 / 不可行时不显示（由 `play` 的出杆动画接管或 `hideCueStick`）。
    private func updateCueStickAiming(_ p: ShotPrediction) {
        guard !isPlaying, p.feasible, let cue = scene.cueBallNode,
              let aim = aimDirection(path: p.cuePath, from: cue.position) else {
            scene.hideCueStick()
            lastAimDirection = nil
            return
        }
        lastAimDirection = aim
        // 侧塞接触点横移：spinX 已是「接触点偏移 / R」(≤0.5)，乘以球半径得真实横移量。
        let r = AngleSceneCalculator.ballRadius
        let perp = SCNVector3(-aim.z, 0, aim.x)
        let lateral = Float(spinX) * r
        let pos = SCNVector3(cue.position.x + perp.x * lateral,
                             cue.position.y,
                             cue.position.z + perp.z * lateral)
        scene.updateCueStick(cueBallPosition: pos, aimDirection: aim)
    }

    /// 从母球出发，取轨迹上第一个明显偏离（>2cm）的点，得到单位瞄准方向。
    private func aimDirection(path: [SCNVector3], from cue: SCNVector3) -> SCNVector3? {
        for pt in path {
            let dx = pt.x - cue.x, dz = pt.z - cue.z
            let d = sqrtf(dx * dx + dz * dz)
            if d > 0.02 { return SCNVector3(dx / d, 0, dz / d) }
        }
        return nil
    }

    // MARK: - Playback

    func play() {
        guard !isPlaying, let pred = lastPrediction, pred.feasible,
              let recorder = pred.recorder,
              let cueNode = scene.cueBallNode, let targetNode = scene.targetBallNodes.first,
              pred.duration > 0.05 else { return }

        isPlaying = true
        statusText = "运杆…"
        clearTrajectory()
        refreshManualOverlay()   // 播放中隐藏瞄准手柄/首碰预览

        let cueStart = cueNode.position
        let targetStart = targetNode.position

        // 运杆 / 出杆动画（#10，单一权威 `CueStroke`，与编排台/思路/斯诺克/出片同源）：
        // 回杆 → 蓄力 → 匀加速出杆，触球瞬间杆速 = 目标速度，收杆后启动球体回放。
        // 无球杆或瞄准方向缺失时直接发球。
        guard let aim = lastAimDirection else {
            scene.hideCueStick()
            launchBalls(cueNode: cueNode, targetNode: targetNode, recorder: recorder,
                        cueStart: cueStart, targetStart: targetStart)
            return
        }
        let strikePos = CueStroke.strikePosition(cue: cueNode.position, aim: aim, spinX: spinX)
        scene.runCueStroke(strikePosition: strikePos, aim: aim, velocity: Float(velocity)) { [weak self] in
            guard let self else { return }
            self.statusText = "击球中…"
            // 收杆不在此处：触球后球杆继续减速跟杆 + 停留一拍再消失（由 `runCueStroke` 接管）。
            self.launchBalls(cueNode: cueNode, targetNode: targetNode, recorder: recorder,
                             cueStart: cueStart, targetStart: targetStart)
        }
    }

    /// 沿真实轨迹播放两球运动（出杆动画结束后调用）。
    private func launchBalls(cueNode: SCNNode, targetNode: SCNNode, recorder: TrajectoryRecorder,
                             cueStart: SCNVector3, targetStart: SCNVector3) {
        let yLevel = scene.surfaceY + AngleSceneCalculator.ballRadius

        // 原速回放（与真实物理时间一致），保证音效与画面同步、观感真实。
        // 用 TrajectoryPlayback 按固定帧率重采样（事件间用解析运动插值），
        // 避免只在事件处采样 + 线性插值导致的卡顿感；动画与所绘轨迹同源、完全吻合。
        let speed: Float = 1.0
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        // #11：按「感知静止时刻」截断，避免「击球中」状态在球看着停后仍滞留数秒。
        let settle = playback.perceptibleSettleTime()
        // removeOnPocket:false——本页播放后要复位重显两球，绝不能让进袋球被移出父节点
        // （否则与 finishPlayback 复位竞态 → 目标球进袋后永久消失，reset/拖动都救不回）。
        // 手动模式的模拟里目标球用真实球键（`manualTargetName`），自动模式用具名 `object`。
        let targetBallName = aimMode == .manual ? manualTargetName : ShotInput.targetBallName
        let cueAction = playback.action(for: cueNode, ballName: ShotInput.cueBallName, speed: speed,
                                        removeOnPocket: false, maxSimTime: settle)
        let targetAction = playback.action(for: targetNode, ballName: targetBallName, speed: speed,
                                           removeOnPocket: false, maxSimTime: settle)

        if let targetAction { targetNode.runAction(targetAction) }
        if let cueAction {
            cueNode.runAction(cueAction) { [weak self] in
                Task { @MainActor in self?.finishPlayback(cueStart: cueStart, targetStart: targetStart) }
            }
            // 音效在球体动画挂载后起播：避免音频引擎冷启动阻塞主线程时，跟杆先于球推进。
            // 事件按真实时刻调度、原速回放无需换算，仍与球体动画同刻起播。
            if let pred = lastPrediction { ShotAudioScheduler.shared.play(prediction: pred) }
        } else {
            finishPlayback(cueStart: cueStart, targetStart: targetStart)
        }
    }

    /// 播放结束：把两球复位到击球前位置，并重新显示原轨迹（不重新求解，瞬时）。
    private func finishPlayback(cueStart: SCNVector3, targetStart: SCNVector3) {
        ShotAudioScheduler.shared.cancel()   // 清掉尾段未触发的音效（提前复位时尤需）
        let r = AngleSceneCalculator.ballRadius
        let yLevel = scene.surfaceY + r

        if let cue = scene.cueBallNode {
            if cue.parent == nil { scene.rootNode.addChildNode(cue) }
            cue.removeAllActions()
            cue.opacity = 1
            cue.position = SCNVector3(cueStart.x, yLevel, cueStart.z)
        }
        if let target = scene.targetBallNodes.first {
            if target.parent == nil { scene.rootNode.addChildNode(target) }
            target.removeAllActions()
            target.opacity = 1
            target.position = SCNVector3(targetStart.x, yLevel, targetStart.z)
        }

        isPlaying = false
        if let pred = lastPrediction, pred.feasible {
            if aimMode == .manual {
                if let auto = autoComparePred {
                    applyManual(pred, auto: auto)
                } else {
                    recompute()
                }
            } else {
                statusText = makeStatus(pred)
                drawTrajectory(pred)
                updateCueStickAiming(pred)
            }
        }
    }
}
