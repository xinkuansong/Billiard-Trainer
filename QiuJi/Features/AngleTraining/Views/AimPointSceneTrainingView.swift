import SwiftUI
import SwiftData
import SceneKit

// MARK: - 2D/3D 瞄准点训练（问题集合 v3 批次 S3：G1 口径）
//
// 瞄准训练最终版：给定母球/目标球/袋口并**展示进球线**（虚线，绿色球用白线增强对比，其余绑目标球色）；
// 瞄准线初始 = 两球心连线；手指粗调 + 刻度轮微调。
// G1 口径：瞄准点 = 瞄准线与「过目标球心且垂直于瞄准线的直线」的交点（垂足）；
// 辅助线（白色细虚线）随用户瞄准线旋转、恒与其垂直。误差 = 用户瞄准点与正确瞄准点
// 相对目标球心的有符号偏移之差（mm，偏大为正 = 瞄薄）；正确瞄准点提交后以青蓝小点
// 标注；1.5 秒后物理击球验证（DR-031：|误差|≤2mm 用几何正解线，否则用户线；杆速中等），然后下一题。

@MainActor
final class AimPointSceneQuizViewModel: TeachingCameraHost {

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
    /// 落库失败的可见错误态（nil = 无错误）。禁止静默丢题。
    @Published private(set) var saveErrorMessage: String?
    @Published private(set) var verificationErrorMessage: String?
    /// 落库失败但已保留的成绩，供重试；用户答案始终留在 `sessionResults`。
    @Published private(set) var unsavedResults: [AngleTestResult] = []

    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2D
    @Published var cameraTransitionBusy = false
    @Published var temporaryTopDownActive = false
    @Published var topDownContentRevision = 0
    var topDownSelectionChanged = false
    var targetNode: SCNNode? { scene.targetBallNodes.first }
    var selectedPocketIndex: Int { question?.pocketIndex ?? -1 }
    var currentPlayerAim: SCNVector3? { question == nil ? nil : aimDir }
    private var isActive = true
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
    private lazy var closeupGate: AimCloseupGate = {
        let gate = AimCloseupGate()
        gate.onSnapshotChange = { [weak self] in self?.closeupSnapshot = $0 }
        return gate
    }()

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
        isActive = true
        self.cameraMode = cameraMode
        scene.configureReferenceTableRendering()
        if cameraMode == .perspective3D { scene.configureShotAwareCamera() }
        scene.setupScene(enhancedRendering: false)
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        if cameraMode == .perspective3D { configureTeachingCamera() }
        scene.setCameraMode(cameraMode, animated: false)
        nextQuestion()
    }

    // MARK: - Question lifecycle

    func nextQuestion() {
        guard isActive else { return }
        endTemporaryTopDown()
        strikeTask?.cancel()
        verificationErrorMessage = nil
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

        scene.confirmPocketSelection(at: q.pocketIndex)

        // 条 9.4：瞄准线初始 = 母球-目标球中心连线。
        aimDir = normalizedXZ(from: cuePos, to: targetPos)
        pendingStrikeDir = aimDir
        lastErrorMM = nil
        verifyUsesGeometricAim = false
        proximityWasNear = false
        closeupGate.reset()
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
        closeupGate.noteAimChanged()
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

    func setAimWheelDragging(_ active: Bool) {
        closeupGate.setDragging(active)
    }

    func setAimTableDragging(_ active: Bool) {
        closeupGate.setDragging(active, source: .table)
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

    func retryVerification() {
        guard verificationErrorMessage != nil, phase == .showingResult else { return }
        strike()
    }

    @discardableResult
    func acceptVerificationPrediction(_ prediction: ShotPrediction) -> Bool {
        guard prediction.hasFinalTableState, prediction.recorder != nil, prediction.duration > 0.05 else {
            strikeTask?.cancel()
            phase = .showingResult
            verificationErrorMessage = "击球验证未完成，已保留本题答案。可以重试验证或继续下一题。"
            return false
        }
        verificationErrorMessage = nil
        return true
    }

    private func strike() {
        guard isActive else { return }
        endTemporaryTopDown()
        guard phase == .showingResult,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        verificationErrorMessage = nil

        let surfaceY = scene.surfaceY
        let velocity = ShotTuning.aimPointVerifyVelocity
        let strikeAim = pendingStrikeDir
        let prediction = ShotPredictor.simulateFree(
            cueBall: cue.position, aimDir: strikeAim,
            velocity: velocity, spinX: 0, spinY: 0,
            surfaceY: surfaceY,
            balls: [ObstacleBall(name: "object", position: target.position)]
        )
        guard acceptVerificationPrediction(prediction), let recorder = prediction.recorder else { return }
        phase = .striking
        clearLines()

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
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: yLevel, railInventory: scene.railInventory)
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
        strikeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.nextQuestion()
        }
    }

    // MARK: - Line drawing

    private func redrawLines(correctDir: SCNVector3? = nil) {
        defer { topDownContentRevision &+= 1 }
        clearLines()
        guard let q = question,
              let cue = scene.cueBallNode, let target = scene.targetBallNodes.first else { return }
        let surfaceY = scene.surfaceY
        let y = surfaceY + AngleSceneCalculator.ballRadius

        // 进球线（条 9.2）：目标球 → 有效入袋点，绿色球用白线，其余保留球色虚线。
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target.position, pocketIndex: q.pocketIndex, surfaceY: surfaceY
        )
        lineNodes.append(scene.addDashedLine(
            from: SCNVector3(target.position.x, y, target.position.z),
            to: SCNVector3(aimPoint.x, y, aimPoint.z),
            color: TrajectoryStyle.TrainingAssist.potColor(forNumber: targetBallNumber), placement: .table
        ))

        // 辅助线（G1）：过目标球心、垂直于**用户瞄准线**，随瞄准旋转，白色细虚线。
        // 它与瞄准线的交点即 G1 瞄准点（垂足）。
        let n = SCNVector3(-aimDir.z, 0, aimDir.x)
        let auxHalf = AngleSceneCalculator.ballRadius * 7
        lineNodes.append(scene.addDashedLine(
            from: SCNVector3(target.position.x - n.x * auxHalf, y, target.position.z - n.z * auxHalf),
            to: SCNVector3(target.position.x + n.x * auxHalf, y, target.position.z + n.z * auxHalf),
            color: TrajectoryStyle.hintColor, radius: 0.0016, dash: TrajectoryStyle.hintDash, gap: TrajectoryStyle.hintGap, placement: .table
        ))

        // 用户瞄准线（Q7.1）：白色实线。未接触目标球 → 延伸库边；接触（垂距 < R）→ 停在
        // 射线与球面第一交点（接触点）；垂足用青蓝小点、接触点用橙黄小点。
        let userRes = aimLineResolution(cue: cue.position, target: target.position, dir: aimDir)
        lineNodes.append(scene.addLine(
            from: SCNVector3(cue.position.x, y, cue.position.z),
            to: scenePoint(userRes.lineEnd, y: y),
            color: TrajectoryStyle.TrainingAssist.aimLine, placement: .table
        ))
        if userRes.touchesBall {
            lineNodes.append(scene.addAimPointMarker(at: scenePoint(userRes.aimPoint, y: y),
                                                     color: TrajectoryStyle.TrainingAssist.aimPoint,
                                                     radius: TrajectoryStyle.TrainingAssist.aimPointRadius, isOverlay: true))
            if let contact = userRes.contactPoint {
                lineNodes.append(scene.addAimPointMarker(at: scenePoint(contact, y: y),
                                                         color: TrajectoryStyle.TrainingAssist.contactPoint,
                                                         radius: TrajectoryStyle.TrainingAssist.aimPointRadius, isOverlay: true))
            }
        }

        // 提交后：正确瞄准线用白色虚线区别于用户实线，瞄准点仍为青蓝。
        if let correctDir {
            let correctRes = aimLineResolution(cue: cue.position, target: target.position, dir: correctDir)
            lineNodes.append(scene.addDashedLine(
                from: SCNVector3(cue.position.x, y, cue.position.z),
                to: scenePoint(correctRes.lineEnd, y: y),
                color: TrajectoryStyle.TrainingAssist.aimLine, placement: .table
            ))
            let foot = AimPointGeometry.aimPoint(
                lineOrigin: xzPoint(cue.position), direction: xzPoint(correctDir),
                targetCenter: xzPoint(target.position))
            lineNodes.append(scene.addAimPointMarker(
                at: scenePoint(foot, y: y),
                color: TrajectoryStyle.TrainingAssist.aimPoint,
                radius: TrajectoryStyle.TrainingAssist.aimPointRadius, isOverlay: true
            ))
        }

        // C5 / D-v19-1：瞄准及结果停留阶段同现球杆；沿用户 aim，spinX:0 与出杆一致。
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
            closeupGate.reset()
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
            closeupGate.update(.init(snapshot: nil, isNear: false))
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
            usesTrainingAssistStyle: true,
            focusNorm: focusNorm,
            // D-v23-5.1：进球线/袋口 + 瞄准线避让；方位走空象限。
            sightKeepout: .fromWorld(
                object: targetP, pocket: potEndP,
                halfLength: halfL, halfWidth: halfW,
                cue: cueP, aimEnd: userRes.lineEnd)
        )
        closeupGate.update(.init(snapshot: snap, isNear: true))
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

    func applyAimingPoseIfNeeded() {
        guard cameraMode == .perspective3D else { return }
        requestPlayerView(scene.cameraRig?.twoViewMode ?? .thirdPerson, animated: false)
    }

    func stopTraining() {
        isActive = false
        strikeTask?.cancel()
        endTemporaryTopDown()
        closeupGate.reset()
    }

    // MARK: - Stats

    var sessionMeanAbsMM: Double {
        guard !sessionResults.isEmpty else { return 0 }
        return sessionResults.map { abs($0.errorMM) }.reduce(0, +) / Double(sessionResults.count)
    }
}

// MARK: - View

struct AimPointSceneTrainingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var vm = AimPointSceneQuizViewModel(limiter: .shared)
    @StateObject private var fps = TableFPSReadoutState()
    @ObservedObject private var preferences = UserPreferences.shared
    @State private var hasAppeared = false
    @State private var scenePrepared = false
    @State private var showSubscription = false
    @State private var showMenu = false
    @State private var portrait = false
    @State private var cameraReadableFrame: CGRect?
    @State private var windowControls = UIEdgeInsets.zero
    @State private var windowSafeArea = UIEdgeInsets.zero
    @State private var systemStatusVisible = false
    private let routeCameraMode: AngleTrainingScene.CameraMode

    init(initialCameraMode: AngleTrainingScene.CameraMode) { routeCameraMode = initialCameraMode }
    private var is3D: Bool { routeCameraMode == .perspective3D }
    private var cameraMode: AngleTrainingScene.CameraMode {
        is3D ? .perspective3D : (portrait ? .topDown2DRotated : .topDown2D)
    }
    private var title: String { is3D ? "3D瞄准点" : "2D瞄准点" }
    private var canAim: Bool { vm.phase == .aiming && !vm.limiter.isLimitReached && !showMenu }

    var body: some View {
        GeometryReader { geo in
            let extraTop = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.top - geo.safeAreaInsets.top) : 0
            let extraBottom = UIDevice.current.userInterfaceIdiom == .pad ? max(0, windowSafeArea.bottom - geo.safeAreaInsets.bottom) : 0
            let size = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: max(0, geo.size.height - extraTop - extraBottom))
            tableTemplate(size: size, safe: max(geo.safeAreaInsets.leading, geo.safeAreaInsets.trailing))
                .frame(width: geo.size.width + geo.safeAreaInsets.trailing, alignment: .leading)
                .padding(.top, extraTop).padding(.bottom, extraBottom)
                .offset(x: -geo.safeAreaInsets.leading)
                .ignoresSafeArea(.container, edges: .trailing)
        }
        .angleSaveErrorBanner(message: vm.saveErrorMessage) { vm.retryFailedSaves() }
        .alert("击球验证未完成", isPresented: Binding(get: { vm.verificationErrorMessage != nil }, set: { _ in })) {
            Button("重试验证") { vm.retryVerification() }
            Button("下一题") { vm.nextQuestion() }
        } message: { Text(vm.verificationErrorMessage ?? "") }
        .trainingBackgroundMusic()
        .btDarkToolChrome(title)
        .background { DailyTableOrientation(landscape: true, allowsTabletRotation: true) }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(UIDevice.current.userInterfaceIdiom != .pad)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            vm.quizTypeLabel = is3D ? "aimPoint3D" : "aimPoint2D"
            vm.configure(context: modelContext)
            vm.setupScene(cameraMode: cameraMode)
            scenePrepared = true
        }
        .onDisappear { vm.stopTraining() }
        .onReceive(subscriptionManager.$isPremium) { vm.limiter.isPremium = $0 }
        .sheet(isPresented: $showSubscription) { SubscriptionView().environmentObject(subscriptionManager) }
    }

    private func tableTemplate(size: CGSize, safe: CGFloat) -> some View {
        let side = max(4, safe)
        let keys = PositionPlayBall.allKeys.filter { !PositionPlayBall.isCue($0) }
        let halfL = vm.scene.cameraRig?.tableOuterHalfLength ?? CameraRig.defaultTableOuterHalfLength
        let halfW = vm.scene.cameraRig?.tableOuterHalfWidth ?? CameraRig.defaultTableOuterHalfWidth
        let reservation = DailyLayoutMetrics.FoundationReservation(width: size.width - 2 * side,
            targetCount: keys.count, chineseEightBall: true, titleWidth: 92, actionWidth: 138,
            prefersSeparateRow: size.height > size.width || size.height >= 600,
            separateWidth: size.width > size.height && size.height < 600 ? size.width - 2 * (side + 68) : nil)
        let f = DailyLayoutMetrics.Foundation(size: size, leadingSafeArea: safe, trailingSafeArea: safe,
            halfLength: halfL, halfWidth: halfW,
            instrumentHeight: DailyLayoutMetrics.Controls.initialInstrumentHeight, palette: reservation)
        let plan = DailyLayoutMetrics.Palette(size: size, sideInset: side, table: f.table,
            targetCount: keys.count, chineseEightBall: true, obstacles: [
                CGRect(x: side + windowControls.left, y: 0, width: 44, height: 44),
                CGRect(x: side + windowControls.left + 32, y: 5, width: 60, height: 34),
                CGRect(x: size.width - side - windowControls.right - 44, y: 0, width: 44, height: 44), f.left, f.right])
        let ppm = f.table.height / CGFloat(2 * (f.rotated ? halfL : halfW))
        let instruments = BTTeachingInstrumentLayout(foundation: f)
        let teachingLayout = BTTeachingPageLayout(stageSize: f.stage.size, rotated: f.rotated,
            pointsPerMetre: ppm, instruments: instruments, spinPadPresented: false)
        return ZStack(alignment: .topLeading) {
            DailyTemplateHeader(size: size, safe: safe, foundation: f, plan: plan,
                targets: keys, chineseEightBall: true, titleWidth: 60, titleHeight: 34,
                windowControlInsets: windowControls, fps: fps, showsDeviceStatus: !systemStatusVisible,
                title: {
                    HStack(spacing: -12) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").font(.btTitle2)
                                .frame(width: 44, height: 44).contentShape(Rectangle())
                        }.accessibilityLabel("返回").accessibilityIdentifier("aimPointTraining.back")
                        BTTrainingPageTitle(text: title)
                    }.fixedSize(horizontal: true, vertical: false)
                }, actions: {
                    Button { showMenu = true } label: {
                        Image(systemName: BTIcon.menuCircle).font(.btTitle2).frame(width: 44, height: 44)
                            .background { BTHUDControlBackground(shape: Circle()) }
                    }.accessibilityLabel("更多").accessibilityIdentifier("aimPointTraining.settings")
                }, ball: { key, diameter, height in
                    let selected = PositionPlayBall.number(for: key) == vm.targetBallNumber
                    PoolBallFace(key: key, diameter: diameter).opacity(selected ? 1 : 0.25)
                        .overlay(Circle().stroke(selected ? HUDStyle.accent : .clear, lineWidth: 1))
                        .frame(width: diameter + 2, height: height)
                        .accessibilityLabel("\(PositionPlayBall.shortLabel(for: key))号球")
                        .accessibilityValue(selected ? "当前目标球" : "参考球")
                        .accessibilityIdentifier("aimPointTraining.ball." + key)
                }, paletteMarker: { Color.clear.accessibilityElement().accessibilityIdentifier("aimPointTraining.palette") })
                .background(DailyWindowControlInsets { controls, window, visible in
                    windowControls = controls; windowSafeArea = window; systemStatusVisible = visible
                }.allowsHitTesting(false))
            Color.clear.accessibilityElement().accessibilityIdentifier("aimPointTraining.stage")
                .frame(width: f.stage.width, height: f.stage.height)
                .background(GeometryReader { g in
                    Color.clear.preference(key: AimPointReadableFrame.self, value: g.frame(in: .global))
                })
                .position(x: f.stage.midX, y: f.stage.midY).allowsHitTesting(false)
            VStack(spacing: instruments.groupSpacing) {
                questionInformation.frame(height: instruments.topDiameter + 14)
                BTTeachingAimRuler(layout: instruments,
                    enabled: canAim && !vm.temporaryTopDownActive,
                    onNudge: { vm.nudgeAim(byDegrees: $0) }, degreesPerPoint: vm.aimWheelDegreesPerPoint,
                    onDragActiveChanged: { vm.setAimWheelDragging($0) })
                    .accessibilityIdentifier("aimPointTraining.aimWheel")
                if !vm.limiter.isPremium {
                    Text("剩余 \(vm.limiter.remainingToday)").font(.btCaption)
                        .foregroundStyle(HUDStyle.labelColor)
                        .accessibilityIdentifier("aimPointTraining.remaining")
                }
            }.frame(width: f.left.width, height: f.left.height, alignment: .top)
                .position(x: f.left.midX, y: f.left.midY)
            BTTeachingInformationLayer(items: verificationInformation)
                .environment(\.teachingTableLayout, teachingLayout)
                .frame(width: f.stage.width, height: f.stage.height)
                .position(x: f.stage.midX, y: f.stage.midY)
            if is3D {
                observationColumn.position(x: f.right.minX - 26, y: f.table.midY)
            }
            VStack {
                Spacer(minLength: 0)
                if vm.phase == .aiming {
                    Button { vm.submit() } label: {
                        Text("提交").font(.btSubheadlineSemibold).frame(width: 52, height: 52)
                    }.buttonStyle(DailyStrikeButtonStyle()).disabled(!canAim)
                        .accessibilityIdentifier("aimPointTraining.submit")
                } else if vm.phase == .striking {
                    ProgressView().tint(HUDStyle.labelColor).accessibilityLabel("击球验证中")
                }
            }.frame(width: 60, height: min(200, f.stage.height))
                .padding(.vertical, Spacing.sm).position(x: f.right.midX, y: f.table.midY)
            GeometryReader { stage in
                BTAimCloseupOverlay(snapshot: vm.temporaryTopDownActive ? nil : vm.closeupSnapshot,
                    sceneSize: stage.size, scene: vm.scene, blockedSide: nil,
                    protectsDailySight: true, frameInWindow: stage.frame(in: .global),
                    placementBounds: playingRect(size: stage.size, halfL: halfL, halfW: halfW, rotated: f.rotated))
            }.frame(width: f.stage.width, height: f.stage.height)
                .position(x: f.stage.midX, y: f.stage.midY).allowsHitTesting(false)
            if vm.limiter.isLimitReached {
                BTDailyLimitGate(compact: vm.phase != .aiming) { showSubscription = true }
                    .frame(width: min(400, f.stage.width)).position(x: f.stage.midX, y: f.stage.midY)
            }
            if showMenu {
                Button { showMenu = false } label: { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("关闭菜单").accessibilityIdentifier("aimPointTraining.dismissMenu")
                DailyHUDMenuPanel(title: nil, items: settingsItems,
                    availableSize: CGSize(width: size.width - 2 * side, height: size.height - DailyLayoutMetrics.Panels.top - 8),
                    onBack: { showMenu = false }, onClose: { showMenu = false })
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, DailyLayoutMetrics.Panels.top).padding(.trailing, side + windowControls.right)
            }
        }
        .frame(width: size.width, height: size.height)
        .background {
            GeometryReader { viewport in
                let fullFrame = viewport.frame(in: .global)
                let renderFrame = is3D ? fullFrame : (cameraReadableFrame ?? fullFrame)
                sceneFullscreen.frame(width: renderFrame.width, height: renderFrame.height)
                    .position(x: renderFrame.midX - fullFrame.minX, y: renderFrame.midY - fullFrame.minY)
                    .opacity(is3D || cameraReadableFrame != nil ? 1 : 0).allowsHitTesting(!showMenu)
            }.ignoresSafeArea()
        }
        .background { DailyCarpetBackground(style: preferences.roomStyle, pointsPerMetre: ppm).ignoresSafeArea() }
        .environment(\.colorScheme, .dark).environment(\.dailyHUDControls, true)
        .onChange(of: size.height > size.width, initial: true) { _, rotated in
            portrait = rotated
            if !is3D, scenePrepared { vm.setCameraMode(rotated ? .topDown2DRotated : .topDown2D) }
            showMenu = false
        }
        .onPreferenceChange(AimPointReadableFrame.self) { cameraReadableFrame = $0 }
    }

    @ViewBuilder private var sceneFullscreen: some View {
        if scenePrepared {
            AngleSceneView(scene: vm.scene, cameraMode: .constant(cameraMode),
                interactionMode: canAim ? (is3D ? .cameraControl : .tapsOnly) : .none,
                autoFitsLandscapeTable: !is3D, backgroundColor: is3D ? .black : .clear,
                onPocketTapped: nil,
                onTableTapped: is3D ? { vm.aimToward(worldPoint: $0) } : nil,
                onAimNudged: is3D ? nil : { vm.nudgeAim(byDegrees: $0) },
                onAimDragActiveChanged: { vm.setAimTableDragging($0) },
                contentIsAnimating: vm.cameraTransitionBusy || vm.phase == .striking,
                fpsReadoutState: fps, twoViewReadableFrameInWindow: is3D ? cameraReadableFrame : nil,
                onCameraObservationBegan: { vm.beginCameraObservation() },
                onCameraObservationEnded: { vm.endCameraObservation() },
                onTemporaryTopDownDismiss: { vm.endTemporaryTopDown() },
                topDownContentRevision: vm.topDownContentRevision, usesStandardTemporaryTable: is3D)
                .clipped().accessibilityIdentifier("aimPointTraining.scene")
        }
    }

    @ViewBuilder private var observationColumn: some View {
        if let rig = vm.scene.cameraRig {
            ShotPlayerCameraButtons(controlSpacing: 4, rig: rig,
                isEnabled: vm.phase != .striking && !showMenu && !vm.limiter.isLimitReached,
                onWholeTable: { vm.requestSurfaceOverview() }, usesTwoViewControls: rig.usesTwoViewCameraControls,
                temporaryTopDownActive: vm.temporaryTopDownActive,
                onTemporaryTopDownBegan: { vm.beginTemporaryTopDown() },
                onTemporaryTopDownEnded: { vm.endTemporaryTopDown() },
                onSelect: { vm.requestPlayerView($0) })
        }
    }

    private var settingsItems: [DailyHUDMenuItem] {
        [.init(id: "aimPointTraining.display", title: "显示"),
         .init(id: "menu.tableGrid", title: "台面网格 4×8", selected: preferences.showTableGrid, action: {
             preferences.showTableGrid.toggle(); vm.scene.setTableGridVisible(preferences.showTableGrid); showMenu = false
         }),
         .init(id: "menu.aimCloseup", title: "瞄准特写", selected: preferences.showAimCloseup, action: {
             preferences.showAimCloseup.toggle(); showMenu = false
         })]
    }

    private var verificationInformation: [BTTeachingInformation] {
        switch vm.phase {
        case .aiming: return []
        case .showingResult: return [.init(text: "即将验证", identifier: "aimPointTraining.verificationInfo")]
        case .striking: return [.init(text: "验证中", identifier: "aimPointTraining.verificationInfo")]
        }
    }

    private var questionInformation: some View {
        VStack(spacing: 2) {
            if let error = vm.lastErrorMM, vm.phase != .aiming {
                Text("误差").foregroundStyle(HUDStyle.labelColor)
                Text(String(format: "%+.1f", error) + "mm")
                    .foregroundStyle(abs(error) <= 2 ? Color.btSuccess : abs(error) <= 6 ? .btWarning : .btDestructive)
                Text(error >= 0 ? "偏薄" : "偏厚").foregroundStyle(HUDStyle.labelColor)
            } else {
                Text("题目").foregroundStyle(HUDStyle.labelColor)
                Text("\(vm.sessionResults.count + 1)")
                Text("平均误差").foregroundStyle(HUDStyle.labelColor)
                Text(vm.sessionResults.isEmpty ? "—" : String(format: "%.1fmm", vm.sessionMeanAbsMM))
            }
        }.font(.btCaption).monospacedDigit().foregroundStyle(.white)
            .accessibilityElement(children: .combine).accessibilityIdentifier("aimPointTraining.questionInfo")
    }

    private func playingRect(size: CGSize, halfL: Double, halfW: Double, rotated: Bool) -> CGRect {
        guard let scale = CameraRig.landscapeOrthographicScale(viewSize: size,
            halfLength: rotated ? halfW : halfL, halfWidth: rotated ? halfL : halfW) else { return .zero }
        let points = size.height / CGFloat(2 * scale)
        let width = CGFloat(rotated ? AngleSceneCalculator.innerWidth : AngleSceneCalculator.innerLength) * points
        let height = CGFloat(rotated ? AngleSceneCalculator.innerLength : AngleSceneCalculator.innerWidth) * points
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }
}

private struct AimPointReadableFrame: PreferenceKey {
    static let defaultValue: CGRect? = nil
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) { value = nextValue() ?? value }
}

#Preview("2D · Light") {
    NavigationStack { AimPointSceneTrainingView(initialCameraMode: .topDown2D)
        .modelContainer(ModelContainerFactory.makeInMemoryContainer()).environmentObject(SubscriptionManager.shared) }
        .preferredColorScheme(.light)
}
#Preview("3D · Dark") {
    NavigationStack { AimPointSceneTrainingView(initialCameraMode: .perspective3D)
        .modelContainer(ModelContainerFactory.makeInMemoryContainer()).environmentObject(SubscriptionManager.shared) }
        .preferredColorScheme(.dark)
}
