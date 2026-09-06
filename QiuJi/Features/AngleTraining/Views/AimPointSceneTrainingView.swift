import SwiftUI
import SwiftData
import SceneKit

// MARK: - 2D/3D 瞄准点训练（问题集合 v3 批次 S3：G1 口径）
//
// 瞄准训练最终版：给定母球/目标球/袋口并**展示进球线**（虚线，绑目标球色）；
// 瞄准线初始 = 两球心连线；手指粗调 + 刻度轮微调。
// G1 口径：瞄准点 = 瞄准线与「过目标球心且垂直于瞄准线的直线」的交点（垂足）；
// 辅助线（白色细虚线）随用户瞄准线旋转、恒与其垂直。误差 = 用户瞄准点与正确瞄准点
// 相对目标球心的有符号偏移之差（mm，偏大为正 = 瞄薄）；正确瞄准点提交后以红色小点
// 标注；1.5 秒后物理击球验证（DR-031：|误差|≤2mm 用几何正解线，否则用户线；杆速中等），然后下一题。

@MainActor
final class AimPointSceneQuizViewModel: ObservableObject {

    enum Phase { case aiming, showingResult, striking }

    struct RoundResult {
        let errorMM: Double
    }

    // MARK: - Published

    @Published private(set) var phase: Phase = .aiming
    @Published private(set) var question: AngleQuestion?
    @Published private(set) var targetBallNumber: Int = 8
    @Published private(set) var sessionResults: [RoundResult] = []
    @Published private(set) var lastErrorMM: Double?
    /// 本轮验证是否走几何正解瞄准（与 `BTFeedback` mm success 档同口径，≤2mm）。
    @Published private(set) var verifyUsesGeometricAim = false
    /// v23：毫米口径轮增益（°/pt）；默认旧值，redraw 后刷新。
    @Published private(set) var aimWheelDegreesPerPoint: Float = AimWheelGain.defaultDegreesPerPoint
    /// v23：近区 ∧ 正在改瞄准时非 nil → 显示特写 HUD。
    @Published private(set) var closeupSnapshot: AimCloseupSnapshot?
    /// v23.4：特写粗角位（chrome 让位 / 动画键）。
    @Published private(set) var closeupCorner: AimCloseupPlacement.Corner = .topTrailing
    /// 瞄准轮 / 台面拖瞄手势进行中（含松手短延迟）。
    @Published private(set) var isAimGestureActive = false
    /// 落库失败的可见错误态（nil = 无错误）。禁止静默丢题。
    @Published private(set) var saveErrorMessage: String?
    /// 落库失败但已保留的成绩，供重试；用户答案始终留在 `sessionResults`。
    @Published private(set) var unsavedResults: [AngleTestResult] = []

    let scene = AngleTrainingScene()
    let limiter: AngleUsageLimiter
    /// "aimPoint2D" / "aimPoint3D"
    var quizTypeLabel = "aimPoint2D"

    private var pocketMarkers: [SCNNode] = []
    private var lineNodes: [SCNNode] = []
    private var repository: AngleTestRepositoryProtocol?
    /// 用户瞄准方向（XZ 单位向量）。
    private var aimDir = SCNVector3(1, 0, 0)
    /// 提交后锁定的验证出杆方向（容差内 = 几何正解，否则 = 用户线）。
    private var pendingStrikeDir = SCNVector3(1, 0, 0)
    private var strikeTask: Task<Void, Never>?
    private var proximityWasNear = false
    private var aimGestureClearTask: Task<Void, Never>?
    /// Last near-band snapshot; HUD shows it only while `isAimGestureActive`.
    private var pendingCloseupSnapshot: AimCloseupSnapshot?

    init(limiter: AngleUsageLimiter) {
        self.limiter = limiter
    }

    func configure(context: ModelContext) {
        repository = LocalAngleTestRepository(context: context)
    }

    /// 直接注入仓储（测试用失败仓储覆盖保存失败路径）。
    func configure(repository: AngleTestRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Setup

    func setupScene(cameraMode: AngleTrainingScene.CameraMode) {
        scene.setupScene(enhancedRendering: false)
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        scene.setCameraMode(cameraMode, animated: false)
        nextQuestion()
    }

    // MARK: - Question lifecycle

    func nextQuestion() {
        strikeTask?.cancel()
        guard !limiter.isLimitReached else {
            // C23：击球验证结束后若已满额，回到 aiming 以展示 full 主卡（避免卡在 striking）。
            phase = .aiming
            return
        }
        clearLines()
        scene.hideCueStick()
        scene.hideAllVisualization()

        let angle = Double(Int.random(in: 2...16) * 5) // 10°–80°
        let q = AngleCalculator.generateQuestion(
            angle: angle, pocketType: nil,
            targetPocketDistanceRange: 0.15...0.55
        )
        question = q
        targetBallNumber = Int.random(in: 1...15)

        let surfaceY = scene.surfaceY
        let cuePos = AngleSceneCalculator.normalizedToScene(point: q.cueBall, surfaceY: surfaceY)
        let targetPos = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: surfaceY)
        scene.applyBallLayout(cueBallPosition: cuePos, targetBallNumber: targetBallNumber,
                              targetPosition: targetPos)

        for (i, marker) in pocketMarkers.enumerated() {
            scene.highlightPocket(marker, highlighted: i == q.pocketIndex)
        }

        // 条 9.4：瞄准线初始 = 母球-目标球中心连线。
        aimDir = normalizedXZ(from: cuePos, to: targetPos)
        pendingStrikeDir = aimDir
        lastErrorMM = nil
        verifyUsesGeometricAim = false
        proximityWasNear = false
        pendingCloseupSnapshot = nil
        closeupSnapshot = nil
        isAimGestureActive = false
        aimGestureClearTask?.cancel()
        phase = .aiming
        redrawLines()
        applyAimingPoseIfNeeded()
    }

    // MARK: - Aiming input

    /// 手指粗调：朝台面世界点瞄准（条 9.3 / §1.5 指哪打哪）。
    func aimToward(worldPoint: SCNVector3) {
        guard phase == .aiming, let cue = scene.cueBallNode else { return }
        let dir = normalizedXZ(from: cue.position, to: worldPoint)
        guard dir.x != 0 || dir.z != 0 else { return }
        aimDir = dir
        markAimGestureActive(sticky: true)
        redrawLines()
    }

    /// 刻度轮微调（度）。
    func nudgeAim(byDegrees delta: Float) {
        guard phase == .aiming else { return }
        let rad = delta * .pi / 180
        let cosD = cosf(rad), sinD = sinf(rad)
        aimDir = SCNVector3(aimDir.x * cosD - aimDir.z * sinD, 0,
                            aimDir.x * sinD + aimDir.z * cosD)
        redrawLines()
    }

    /// 瞄准轮拖动手势生命周期（近区 HUD 门控）。
    func setAimWheelDragging(_ active: Bool) {
        if active {
            markAimGestureActive(sticky: false)
        } else {
            scheduleAimGestureClear()
        }
    }

    /// 2D 台面拖瞄：无轮 `onDragActiveChanged`，用短延迟粘性门控 HUD。
    func noteTableAimDrag() {
        markAimGestureActive(sticky: true)
    }

    private func markAimGestureActive(sticky: Bool) {
        aimGestureClearTask?.cancel()
        isAimGestureActive = true
        refreshCloseupVisibility()
        if sticky { scheduleAimGestureClear() }
    }

    private func scheduleAimGestureClear() {
        aimGestureClearTask?.cancel()
        aimGestureClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.isAimGestureActive = false
                self?.refreshCloseupVisibility()
            }
        }
    }

    // MARK: - Submit（条 9.6/9.7，G1 口径）

    func submit() {
        guard phase == .aiming, let q = question,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let surfaceY = scene.surfaceY

        // 正确瞄准方向：母球 → 假想球（有效入袋点模型）。
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target.position, pocketIndex: q.pocketIndex, surfaceY: surfaceY
        )
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: target.position, pocket: aimPoint,
            ballRadius: AngleSceneCalculator.ballRadius
        )
        let correctDir = normalizedXZ(from: cue.position, to: ghost)

        // G1 瞄准点：目标球心到各瞄准线的垂足（XZ 平面，AimPointGeometry 唯一真源）。
        let cueP = xzPoint(cue.position)
        let targetP = xzPoint(target.position)
        let userFoot = AimPointGeometry.aimPoint(
            lineOrigin: cueP, direction: xzPoint(aimDir), targetCenter: targetP)
        let correctFoot = AimPointGeometry.aimPoint(
            lineOrigin: cueP, direction: xzPoint(correctDir), targetCenter: targetP)

        // 参考法向 = 目标球心 → 正确瞄准点（正确解所在侧为正，可区分瞄错侧）。
        // 直球退化（正确垂距 ≈ 0）时以用户侧为正，误差 = 用户垂距（恒偏大）。
        var normal = CGPoint(x: correctFoot.x - targetP.x, y: correctFoot.y - targetP.y)
        if hypot(normal.x, normal.y) < 1e-6 {
            normal = CGPoint(x: userFoot.x - targetP.x, y: userFoot.y - targetP.y)
        }
        let sCorrect = Double(hypot(correctFoot.x - targetP.x, correctFoot.y - targetP.y))
        let sUser = hypot(normal.x, normal.y) < 1e-9
            ? 0
            : Double(AimPointGeometry.signedOffset(
                lineOrigin: cueP, direction: xzPoint(aimDir),
                targetCenter: targetP, positiveNormal: normal))
        // 偏大为正（= 瞄薄，与瞄准点训练同约定）。
        let errorMM = (sUser - sCorrect) * 1000

        lastErrorMM = errorMM
        // DR-031：success 档（≤2mm，与 `BTFeedback.quiz(errorMM:)` 同口径）用几何正解验证，
        // 避免「几何已对但仍按用户微偏线 + 软力打」导致进袋反馈失真；偏了仍打用户线。
        verifyUsesGeometricAim = BTFeedback.outcome(forMM: abs(errorMM)) == .correct
        pendingStrikeDir = verifyUsesGeometricAim ? correctDir : aimDir
        sessionResults.append(RoundResult(errorMM: errorMM))
        limiter.recordQuestion()
        BTFeedback.quiz(errorMM: errorMM)

        phase = .showingResult
        redrawLines(correctDir: correctDir)

        Task {
            let result = AngleTestResult(
                actualAngle: sCorrect * 1000,
                userAngle: sUser * 1000,
                pocketType: q.pocketType.rawValue,
                quizType: quizTypeLabel,
                errorMM: errorMM
            )
            await persist(result)
        }

        // 条 9.8 / Q7.3：停留 1.5 秒 → 物理击球验证（含运杆动画）→ 下一题。
        strikeTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.strike()
        }
    }

    /// 重试此前失败的落库；失败仍会重新置错误态。
    func retryFailedSaves() {
        let pending = unsavedResults
        guard !pending.isEmpty else { return }
        unsavedResults = []
        saveErrorMessage = nil
        Task {
            for result in pending { await persist(result) }
        }
    }

    private func persist(_ result: AngleTestResult) async {
        guard let repository else { return }
        do {
            try await repository.save(result)
        } catch {
            unsavedResults.append(result)
            saveErrorMessage = AngleResultSaveFailure.message(error)
        }
    }

    // MARK: - Strike（物理击球）

    private func strike() {
        guard phase == .showingResult,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        phase = .striking
        clearLines()

        let surfaceY = scene.surfaceY
        let velocity = ShotTuning.aimPointVerifyVelocity
        let strikeAim = pendingStrikeDir
        let prediction = ShotPredictor.simulateFree(
            cueBall: cue.position, aimDir: strikeAim,
            velocity: velocity, spinX: 0, spinY: 0,
            surfaceY: surfaceY,
            balls: [ObstacleBall(name: "object", position: target.position)]
        )
        guard let recorder = prediction.recorder, prediction.duration > 0.05 else {
            advanceAfterStrike()
            return
        }

        // Q7.4：验证击球走单一权威运杆链路（运杆→出杆→触球起播），与其他击打页
        // （`PositionPlayViewModel`/`SiluTrainerViewModel` 等）同口径 `AngleTrainingScene.runCueStroke`。
        let strikePos = CueStroke.strikePosition(cue: cue.position, aim: strikeAim, spinX: 0)
        scene.runCueStroke(strikePosition: strikePos, aim: strikeAim, velocity: velocity) { [weak self] in
            self?.launchStrikePlayback(cue: cue, target: target, recorder: recorder)
        }
    }

    /// 触球瞬间起播球体轨迹（收杆由 `runCueStroke` 的跟杆序列接管，勿在此 hideCueStick）。
    private func launchStrikePlayback(cue: SCNNode, target: SCNNode, recorder: TrajectoryRecorder) {
        let yLevel = scene.surfaceY + AngleSceneCalculator.ballRadius
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel)
        let settle = playback.duration   // G15：播到引擎自然静止（不做感知截断）

        if let targetAction = playback.action(for: target, ballName: "object",
                                              removeOnPocket: false, maxSimTime: settle) {
            target.runAction(targetAction)
        }

        if let cueAction = playback.action(for: cue, ballName: ShotInput.cueBallName,
                                           removeOnPocket: false, maxSimTime: settle) {
            cue.runAction(cueAction) { [weak self] in
                Task { @MainActor in self?.advanceAfterStrike() }
            }
        } else {
            advanceAfterStrike()
        }
    }

    private func advanceAfterStrike() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            self?.nextQuestion()
        }
    }

    // MARK: - Line drawing

    private func redrawLines(correctDir: SCNVector3? = nil) {
        clearLines()
        guard let q = question,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let surfaceY = scene.surfaceY
        let y = surfaceY + AngleSceneCalculator.ballRadius

        // 进球线（条 9.2）：目标球 → 有效入袋点，绑球色虚线。
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target.position, pocketIndex: q.pocketIndex, surfaceY: surfaceY
        )
        lineNodes.append(scene.addDashedLine(
            from: SCNVector3(target.position.x, y, target.position.z),
            to: SCNVector3(aimPoint.x, y, aimPoint.z),
            color: TrajectoryStyle.potColor(forNumber: targetBallNumber)
        ))

        // 辅助线（G1）：过目标球心、垂直于**用户瞄准线**，随瞄准旋转，白色细虚线。
        // 它与瞄准线的交点即 G1 瞄准点（垂足）。
        let n = SCNVector3(-aimDir.z, 0, aimDir.x)
        let auxHalf = AngleSceneCalculator.ballRadius * 7
        lineNodes.append(scene.addDashedLine(
            from: SCNVector3(target.position.x - n.x * auxHalf, y, target.position.z - n.z * auxHalf),
            to: SCNVector3(target.position.x + n.x * auxHalf, y, target.position.z + n.z * auxHalf),
            color: TrajectoryStyle.hintColor, radius: 0.0016, dash: 0.018, gap: 0.014
        ))

        // 用户瞄准线（Q7.1）：白实线。未接触目标球 → 延伸库边；接触（垂距 < R）→ 停在
        // 射线与球面第一交点（接触点），并在垂足（瞄准点）+ 接触点各画一枚红点。
        let userRes = aimLineResolution(cue: cue.position, target: target.position, dir: aimDir)
        lineNodes.append(scene.addLine(
            from: SCNVector3(cue.position.x, y, cue.position.z),
            to: scenePoint(userRes.lineEnd, y: y),
            color: .white
        ))
        if userRes.touchesBall {
            lineNodes.append(scene.addAimPointMarker(at: scenePoint(userRes.aimPoint, y: y),
                                                     color: TrajectoryStyle.aimPointColor))
            if let contact = userRes.contactPoint {
                lineNodes.append(scene.addAimPointMarker(at: scenePoint(contact, y: y),
                                                         color: TrajectoryStyle.aimPointColor))
            }
        }

        // 提交后：正确瞄准线（红）+ 正确瞄准点红色小点（G1 垂足，恒显）。
        if let correctDir {
            let correctRes = aimLineResolution(cue: cue.position, target: target.position, dir: correctDir)
            lineNodes.append(scene.addLine(
                from: SCNVector3(cue.position.x, y, cue.position.z),
                to: scenePoint(correctRes.lineEnd, y: y),
                color: TrajectoryStyle.aimPointColor
            ))
            let foot = AimPointGeometry.aimPoint(
                lineOrigin: xzPoint(cue.position), direction: xzPoint(correctDir),
                targetCenter: xzPoint(target.position))
            lineNodes.append(scene.addAimPointMarker(
                at: scenePoint(foot, y: y),
                color: TrajectoryStyle.aimPointColor
            ))
        }

        // C5 / D-v19-1：瞄准（及结果停留）阶段用户白线同现杆；沿用户 aim，spinX:0 与出杆一致。
        if phase == .aiming || phase == .showingResult {
            scene.updateCueStick(
                cueBallPosition: CueStroke.strikePosition(cue: cue.position, aim: aimDir, spinX: 0),
                aimDirection: aimDir
            )
        }

        if phase == .aiming {
            updateAimAssistState(cue: cue.position, target: target.position)
        } else {
            proximityWasNear = false
            closeupSnapshot = nil
            aimWheelDegreesPerPoint = AimWheelGain.defaultDegreesPerPoint
        }
    }

    /// v23 / v23.4：毫米增益 + 近区特写（与 `redrawLines` **同源用户层**，紧取景放大）。
    private func updateAimAssistState(cue: SCNVector3, target: SCNVector3) {
        let cueP = xzPoint(cue)
        let targetP = xzPoint(target)
        let dirP = xzPoint(aimDir)
        let r = CGFloat(AngleSceneCalculator.ballRadius)
        let sample = AimProximityMath.advance(
            cue: cueP, direction: dirP, target: targetP,
            ballRadius: r, previouslyNear: proximityWasNear)
        proximityWasNear = sample.isNear

        let d = hypotf(target.x - cue.x, target.z - cue.z)
        aimWheelDegreesPerPoint = AimWheelGain.degreesPerPoint(distanceMeters: d)

        guard sample.isNear, let q = question else {
            pendingCloseupSnapshot = nil
            closeupSnapshot = nil
            return
        }

        let userRes = aimLineResolution(cue: cue, target: target, dir: aimDir)
        // AimPoint 场景瞄准态不画假想球圈（仅线 + 垂线 + 触球标记）⇒ HUD 同步不发明 ghost。
        let potEnd = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: q.pocketIndex, surfaceY: scene.surfaceY)
        let potEndP = xzPoint(potEnd)
        let n = CGPoint(x: -dirP.y, y: dirP.x) // ⊥ aim in XZ plane (x→X, y→Z)
        let nLen = hypot(n.x, n.y)
        let auxHalf = r * 3.2
        let aux: AimCloseupSegment? = nLen > 1e-9
            ? AimCloseupSegment(
                start: CGPoint(x: targetP.x - n.x / nLen * auxHalf,
                               y: targetP.y - n.y / nLen * auxHalf),
                end: CGPoint(x: targetP.x + n.x / nLen * auxHalf,
                             y: targetP.y + n.y / nLen * auxHalf))
            : nil

        let halfL = CGFloat(scene.cameraRig?.tableOuterHalfLength
                            ?? ShotTableLayout.defaultHalfLength)
        let halfW = CGFloat(scene.cameraRig?.tableOuterHalfWidth
                            ?? ShotTableLayout.defaultHalfWidth)
        let focusNorm = AimCloseupPlacement.focusNormInRotatedTopDown(
            worldXZ: targetP, halfLength: halfL, halfWidth: halfW)
        // Fresh pick when HUD was hidden — default corner + hysteresis otherwise
        // pins the loupe on the object ball (FL-028). Leading column blocked by
        // the aim wheel / thumb. Center is offset from the focus (D-v23-5‴),
        // not pinned to a screen corner.
        closeupCorner = AimCloseupPlacement.corner(
            focusNorm: focusNorm,
            previous: closeupSnapshot != nil ? closeupCorner : nil,
            blockedSide: .leading)

        let cueInFrame = hypot(cueP.x - targetP.x, cueP.y - targetP.y) < r * 3.2 * 1.35
        let snap = AimCloseupSnapshot(
            band: sample.band,
            focus: targetP,
            ballRadius: r,
            halfWorld: r * 3.2,
            showsTargetBall: true,
            targetBallNumber: targetBallNumber,
            cue: cueInFrame ? cueP : nil,
            aimLine: AimCloseupSegment(start: cueP, end: userRes.lineEnd),
            potLine: AimCloseupSegment(start: targetP, end: potEndP),
            auxLine: aux,
            ghost: nil,
            aimPointMarker: userRes.touchesBall ? userRes.aimPoint : nil,
            contactMarker: userRes.touchesBall ? userRes.contactPoint : nil,
            showMissCaption: sample.band == .skim,
            focusNorm: focusNorm,
            // D-v23-5.1：进球线/袋口 + 瞄准线避让；方位走空象限。
            sightKeepout: .fromWorld(
                object: targetP, pocket: potEndP,
                halfLength: halfL, halfWidth: halfW,
                cue: cueP, aimEnd: userRes.lineEnd)
        )
        pendingCloseupSnapshot = snap
        closeupSnapshot = isAimGestureActive ? snap : nil
    }

    private func refreshCloseupVisibility() {
        guard phase == .aiming, isAimGestureActive, let snap = pendingCloseupSnapshot else {
            closeupSnapshot = nil
            return
        }
        closeupSnapshot = snap
    }

    private func clearLines() {
        for node in lineNodes { node.removeFromParentNode() }
        lineNodes.removeAll()
    }

    // MARK: - Geometry helpers

    private func normalizedXZ(from a: SCNVector3, to b: SCNVector3) -> SCNVector3 {
        let dx = b.x - a.x, dz = b.z - a.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 1e-5 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(dx / len, 0, dz / len)
    }

    /// 用户/正确瞄准线的白线终点 + 红点解析（Q7.1，纯几何真源 `AimLineGeometry`）。
    /// 未接触目标球时延伸的库边终点用 `rayToInnerRail`（V1 共享，各方向缩一颗球半径）。
    private func aimLineResolution(cue: SCNVector3, target: SCNVector3,
                                   dir: SCNVector3) -> AimLineGeometry.Resolution {
        let railEnd = AngleSceneCalculator.rayToInnerRail(from: cue, dir: dir)
        return AimLineGeometry.resolve(
            cue: xzPoint(cue), dir: xzPoint(dir), target: xzPoint(target),
            ballRadius: CGFloat(AngleSceneCalculator.ballRadius),
            railEnd: xzPoint(railEnd))
    }

    /// SceneKit 水平面 XZ → 平面点（AimPointGeometry 入参约定：x→x，z→y）。
    private func xzPoint(_ v: SCNVector3) -> CGPoint {
        CGPoint(x: CGFloat(v.x), y: CGFloat(v.z))
    }

    /// 平面点（x→X，y→Z）→ SceneKit 世界点（贴台面高度 `y`）。`xzPoint` 的逆。
    private func scenePoint(_ p: CGPoint, y: Float) -> SCNVector3 {
        SCNVector3(Float(p.x), y, Float(p.y))
    }

    // MARK: - Camera（3D 站位视角随题取景）

    private func applyAimingPoseIfNeeded() {
        guard scene.currentCameraMode == .perspective3D else {
            #if DEBUG
            print("[AimPointScene.applyAimingPose] skip (not perspective3D)")
            #endif
            return
        }
        guard let cue = scene.cueBallNode else {
            #if DEBUG
            print("[AimPointScene.applyAimingPose] EARLY_RETURN cueBallNode==nil zoom=\(scene.cameraRig?.zoom ?? -1)")
            #endif
            return
        }
        #if DEBUG
        print(String(format:
            "[AimPointScene.applyAimingPose] ENTER cue=(%.3f,%.3f,%.3f) prevZoom=%.2f",
            cue.position.x, cue.position.y, cue.position.z,
            scene.cameraRig?.zoom ?? -1))
        #endif
        scene.cameraRig?.enterAiming(cueBallPosition: cue.position, targetDirection: aimDir)
    }

    // MARK: - Stats

    var sessionMeanAbsMM: Double {
        guard !sessionResults.isEmpty else { return 0 }
        return sessionResults.map { abs($0.errorMM) }.reduce(0, +) / Double(sessionResults.count)
    }
}

// MARK: - View

struct AimPointSceneTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm = AimPointSceneQuizViewModel(limiter: .shared)
    @State private var hasAppeared = false
    @State private var showSubscription = false

    private let cameraMode: AngleTrainingScene.CameraMode

    init(initialCameraMode: AngleTrainingScene.CameraMode) {
        self.cameraMode = initialCameraMode
    }

    private var is3D: Bool { cameraMode == .perspective3D }

    /// G10：顶栏 / 底栏定高锁桌（C11 → `ShotStageMetrics`）；2D 底栏 = 装饰球库。
    private static let topRowHeight = ShotStageMetrics.topRowHeight
    private static let bottomBarHeight = ShotStageMetrics.BottomBarHeight.composer.rawValue
    /// 「提交」按钮高（贴球桌右下角），特写落底角时需为它让位。
    private static let submitButtonHeight: CGFloat = 30

    /// 球桌外框实测半尺寸（装桌前 USDZ 兜底），供 `ShotStageProxy` 对齐球桌矩形。
    private var tableExtents: (length: Double, width: Double) {
        if let rig = vm.scene.cameraRig {
            return (rig.tableOuterHalfLength, rig.tableOuterHalfWidth)
        }
        return (ShotTableLayout.defaultHalfLength, ShotTableLayout.defaultHalfWidth)
    }

    var body: some View {
        GeometryReader { geo in
            let extents = tableExtents
            let bottomH: CGFloat = is3D ? 0 : Self.bottomBarHeight
            let sceneH = max(geo.size.height - Self.topRowHeight - bottomH, 1)
            let proxy = ShotStageProxy(
                sceneSize: CGSize(width: geo.size.width, height: sceneH),
                halfLength: extents.length, halfWidth: extents.width
            )
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    topInset
                        .frame(height: Self.topRowHeight)
                    ZStack {
                        sceneFullscreen
                        controlOverlay(proxy)
                        BTAimCloseupOverlay(
                            snapshot: vm.closeupSnapshot,
                            sceneSize: CGSize(width: geo.size.width, height: sceneH))
                    }
                    .frame(height: sceneH)
                    if !is3D {
                        decorativePalette(proxy)
                            .frame(height: Self.bottomBarHeight)
                    }
                }
                if vm.limiter.isLimitReached {
                    if vm.phase == .showingResult || vm.phase == .striking {
                        // C23：结果/击球验证态用 compact（对齐 Geometric 结果区）。
                        VStack {
                            Spacer()
                            BTDailyLimitGate(compact: true) { showSubscription = true }
                                .padding(.horizontal, Spacing.xl)
                                .padding(.bottom, Spacing.xl + 40)
                        }
                        .transition(.opacity)
                    } else if vm.phase == .aiming {
                        // C23：满额主卡（full）；取消原先撑满全屏的遮罩形态。
                        limitCard
                            .transition(.opacity)
                    }
                }
            }
            .animation(BTMotion.easeChrome, value: vm.limiter.isLimitReached)
            .animation(BTMotion.easeChrome, value: vm.phase)
        }
        .angleSaveErrorBanner(message: vm.saveErrorMessage) { vm.retryFailedSaves() }
        .btDarkToolChrome(is3D ? "3D 瞄准点训练" : "2D 瞄准点训练")
        .toolbar {
            ToolbarItem(placement: .principal) {
                BTSolverNavStatus(title: is3D ? "3D 瞄准点训练" : "2D 瞄准点训练")
            }
            // C31 / G25：有台面场景 → 三点入口至少网格开关。
            ToolbarItem(placement: .topBarTrailing) {
                BTSolverMoreMenu(scene: vm.scene, labelOpacity: 0.7, showsAimCloseupToggle: true)
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                vm.quizTypeLabel = is3D ? "aimPoint3D" : "aimPoint2D"
                vm.configure(context: modelContext)
                vm.setupScene(cameraMode: cameraMode)
            }
        }
        .onReceive(subscriptionManager.$isPremium) { premium in
            vm.limiter.isPremium = premium
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView().environmentObject(subscriptionManager)
        }
    }

    // MARK: - Scene

    /// Q9：3D 模式下滑屏改为**控制摄像机**（横滑 yaw、竖滑 zoom 梯，同 3D 角度训练的
    /// `.cameraControl` 分支）；瞄准调整由 `BTAimWheel` + 点击台面（绝对指向，G13 保留 tap 语义）承担。
    /// 2D 模式保留拖动瞄准的 **G13 相对调整**（`onAimNudged`），不回退为「点哪指哪」。
    private var sceneFullscreen: some View {
        AngleSceneView(
            scene: vm.scene,
            cameraMode: .constant(cameraMode),
            interactionMode: sceneInteractionMode,
            locksCueBallScreenAnchor: is3D,
            // 2D 走统一自适应取景，使 ShotStageProxy 的球桌矩形与实际渲染对齐（Q7.2）。
            autoFitsRotatedTable: !is3D,
            onPocketTapped: { _ in /* 袋口由题目固定 */ },
            onTableTapped: tapAimHandler,
            onAimNudged: dragAimHandler
        )
        .clipped()
    }

    /// 3D：点击台面 = 绝对指向瞄准（G13 保留 tap 语义）；2D：nil（2D 不用 tap 瞄准，走拖动）。
    private var tapAimHandler: ((SCNVector3) -> Void)? {
        guard is3D else { return nil }
        return { [vm] world in vm.aimToward(worldPoint: world) }
    }

    /// 2D：拖动 = G13 相对瞄准调整；3D：nil（滑屏让位给相机控制）。
    private var dragAimHandler: ((Float) -> Void)? {
        guard !is3D else { return nil }
        return { [vm] delta in
            vm.nudgeAim(byDegrees: delta)
            vm.noteTableAimDrag()
        }
    }

    /// 瞄准态：3D 用相机控制（滑屏调机位）、2D 用 tapsOnly（拖动=相对瞄准，拖球不适用）；
    /// 结果/击球态锁死手势。
    private var sceneInteractionMode: AngleSceneView.InteractionMode {
        guard vm.phase == .aiming else { return .none }
        return is3D ? .cameraControl : .tapsOnly
    }

    // MARK: - Top inset

    @ViewBuilder
    private var topInset: some View {
        HStack(spacing: Spacing.sm) {
            if vm.phase == .showingResult, let err = vm.lastErrorMM {
                resultHUD(errorMM: err)
            } else if vm.phase == .striking {
                // F-SA-03：击球进行时 chrome；不延长物理、不改自动下一题。
                strikingPill
            } else {
                statsPill
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxHeight: .infinity, alignment: .center)
        .background(Color.black)
        .animation(BTMotion.easeInOutFast, value: vm.phase)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - 装饰性球库（C14：BTDecorativeBallPalette）

    private func decorativePalette(_ proxy: ShotStageProxy) -> some View {
        let libraryWidth = proxy.libraryWidth
        return BTDecorativeBallPalette(
            ballDiameter: proxy.paletteBallDiameter,
            libraryWidth: libraryWidth,
            opacityForKey: { key in
                PositionPlayBall.number(for: key) == vm.targetBallNumber ? 1 : 0.25
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HUDStyle.panelBackground)
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.08)) }
        .environment(\.colorScheme, .dark)
    }

    private var statsPill: some View {
        HStack(spacing: Spacing.md) {
            BTReadout(label: "题", value: "\(vm.sessionResults.count)")
            divider
            BTReadout(label: "均差",
                      value: vm.sessionResults.isEmpty
                          ? "—" : String(format: "%.1fmm", vm.sessionMeanAbsMM))
            if !vm.limiter.isPremium {
                divider
                BTReadout(label: "剩余", value: "\(vm.limiter.remainingToday)",
                          emphasis: .adjustable, size: .compact)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .btHudGlass()
    }

    private var strikingPill: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.mini)
                .tint(.white)
            Text("击球验证中…")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .btHudGlass()
    }

    private func resultHUD(errorMM: Double) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle().fill(ratingColor(abs(errorMM))).frame(width: 7, height: 7)
            Text(String(format: "误差 %@%.1f mm", errorMM >= 0 ? "+" : "", errorMM))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(errorMM >= 0 ? "偏薄" : "偏厚")
                .font(.btCaption)
                .foregroundStyle(.white.opacity(0.6))
            divider
            Text(vm.verifyUsesGeometricAim
                 ? "1.5 秒后几何瞄准验证"
                 : "1.5 秒后按你的瞄准验证")
                .font(.btCaption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .btHudGlass()
    }

    private var divider: some View {
        BTHudMetricSeparator()
    }

    private func ratingColor(_ absMM: Double) -> Color {
        if absMM <= 2 { return .btSuccess }
        if absMM <= 6 { return .btWarning }
        return .btDestructive
    }

    // MARK: - Controls（瞄准刻度轮 + 提交）
    //
    // Q7.2：2D 走 ShotStageProxy 贴边——刻度轮右缘贴球桌左缘（G4），提交按钮左缘贴球桌右缘、
    // 底边齐球桌底线（G6，参考 SceneAimingView/FreePlayView）；3D 透视无球桌矩形，保持浮动。

    @ViewBuilder
    private func controlOverlay(_ proxy: ShotStageProxy) -> some View {
        if vm.phase == .aiming, !vm.limiter.isLimitReached {
            if !is3D, proxy.isValid {
                ZStack(alignment: .topLeading) {
                    Color.clear
                    aimWheel
                        .btStageFrame(proxy.aimWheelFrame())
                    BTTextActionButton(title: "提交", role: .primary,
                                       width: ShotStageMetrics.actionColumnWidth) {
                        vm.submit()
                    }
                    .btStageFrame(proxy.bottomTrailingFrame(
                        size: CGSize(width: ShotStageMetrics.actionColumnWidth,
                                     height: Self.submitButtonHeight)))
                }
                .transition(.opacity)
                .animation(BTMotion.easeInOutChrome, value: vm.phase)
            } else {
                ZStack(alignment: .bottomTrailing) {
                    Color.clear
                    VStack(spacing: Spacing.md) {
                        aimWheel
                            .frame(width: ShotStageMetrics.aimWheelWidth,
                                   height: ShotStageMetrics.aimWheelFloatingHeight)
                        BTTextActionButton(title: "提交", role: .primary) {
                            vm.submit()
                        }
                    }
                    .padding(.trailing, Spacing.lg)
                    .padding(.bottom, Spacing.xl + 40)
                    .transition(.opacity)
                }
                .animation(BTMotion.easeInOutChrome, value: vm.phase)
            }
        }
    }

    /// v23：连续毫米增益 + 关闭整度触感（D-v23-4=B / D-v23-6）。
    private var aimWheel: some View {
        BTAimWheel(
            onNudge: { delta in vm.nudgeAim(byDegrees: delta) },
            degreesPerPoint: vm.aimWheelDegreesPerPoint,
            degreeHapticEnabled: false,
            onDragActiveChanged: { active in vm.setAimWheelDragging(active) }
        )
    }

    private var limitCard: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
            BTDailyLimitGate { showSubscription = true }
                .padding(.horizontal, Spacing.lg)
        }
    }
}

#Preview("2D") {
    NavigationStack {
        AimPointSceneTrainingView(initialCameraMode: .topDown2DRotated)
            .modelContainer(ModelContainerFactory.makeInMemoryContainer())
            .environmentObject(SubscriptionManager.shared)
    }
    .preferredColorScheme(.dark)
}
