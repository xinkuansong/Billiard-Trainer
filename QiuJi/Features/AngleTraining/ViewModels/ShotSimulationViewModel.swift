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
        let cueAction = playback.action(for: cueNode, ballName: ShotInput.cueBallName, speed: speed,
                                        removeOnPocket: false, maxSimTime: settle)
        let targetAction = playback.action(for: targetNode, ballName: ShotInput.targetBallName, speed: speed,
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
            statusText = makeStatus(pred)
            drawTrajectory(pred)
            updateCueStickAiming(pred)
        }
    }
}
