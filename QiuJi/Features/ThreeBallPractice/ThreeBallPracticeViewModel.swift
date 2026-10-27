import SwiftUI
import SceneKit
import SwiftData

@MainActor
final class ThreeBallPracticeViewModel: ObservableObject, TeachingTableHost {
    enum Phase { case loading, settings, aiming, preparing, playing, result, saveFailed, summary }
    let is3D: Bool
    let scene = AngleTrainingScene()
    let limiter: AngleUsageLimiter
    @Published private(set) var record: ThreeBallPracticeRecord?
    @Published private(set) var phase: Phase = .loading {
        didSet {
            if phase == .result || phase == .summary || phase == .settings { geometryReference.complete() }
            else if phase == .aiming { geometryReference.cancelFreeze() }
        }
    }
    lazy var geometryReference = GeometricReferenceTool(scene: scene) { [weak self] in self?.objectWillChange.send() }
    @Published var message: String?
    @Published private(set) var notice: TrainingPracticeNotice?
    @Published private(set) var pocketRequestID: UUID?
    @Published var cameraMode: AngleTrainingScene.CameraMode
    @Published var cameraTransitionBusy = false
    @Published var temporaryTopDownActive = false
    @Published var topDownContentRevision = 0
    @Published var topDownSelectionChanged = false
    @Published private(set) var isReplaying = false
    @Published var needsSubscription = false
    @Published private(set) var playsStroke: Bool
    @Published private(set) var showsReference: Bool
    private let defaults: UserDefaults
    private var strokePreferenceKey: String { "threeBallPractice.\(is3D ? "3D" : "2D").playsStroke" }
    func setPlaysStroke(_ enabled: Bool) {
        guard !isBusy else { return }
        playsStroke = enabled
        defaults.set(enabled, forKey: strokePreferenceKey)
    }
    // The preference now controls retention after a submission; the first-shot baseline is unconditional.
    private var referencePreferenceKey: String { "threeBallPractice.\(is3D ? "3D" : "2D").keepsReferenceAfterSubmission" }
    var shouldShowReference: Bool { record?.current != nil && (showsReference || record?.latestShot == nil) }
    func setShowsReference(_ enabled: Bool) {
        guard !isBusy else { return }
        showsReference = enabled
        defaults.set(enabled, forKey: referencePreferenceKey)
        if phase != .settings { prepareReference() }
    }
    typealias QuestionPreparer = @Sendable (SceneTrainingConfiguration, Set<String>) throws -> ThreeBallQuestionPreparer.Prepared
    private let prepareQuestion: QuestionPreparer
    private struct NextQuestionKey: Equatable {
        let sessionID: UUID, questionID: UUID
        let ownerKey: String
    }
    private final class NextQuestionRequest {
        let key: NextQuestionKey
        let task: Task<ThreeBallQuestionPreparer.Prepared, Error>
        var prepared: ThreeBallQuestionPreparer.Prepared?
        init(key: NextQuestionKey, task: Task<ThreeBallQuestionPreparer.Prepared, Error>) {
            self.key = key; self.task = task
        }
    }
    private var nextQuestionRequest: NextQuestionRequest?
    private var nextQuestionObserver: Task<Void, Never>?
    @Published private(set) var nextQuestionReady = false
    private var teachingActive = false
    private var repository: (any ThreeBallPracticeRepository)?
    private var generation = UUID()
    private var work: Task<Void, Never>?
    private var draftSave: Task<Void, Never>?
    private var builtScene = false
    private var targetNodes: [SCNNode] = []
    private var actualNodes: [SCNNode] = []
    private var referenceNodes: [SCNNode] = []
    private var referenceWork: Task<Void, Never>?
    private var referenceQuestionID: UUID?
    private var referenceFailed = false
    private(set) var referenceTrajectory: [SeparationTrajectory.Point]?
    private var objectNodes: [SCNNode] = []
    private var markers: [SCNNode] = []
    private var highlightedQuestionID: UUID?
    private var solvedAim: SCNVector3?
    private var shotPoses: BallPoseSnapshot?
    private var shotCamera: CameraRig.PerspectiveState?
    private var pendingShot: ThreeBallShot?
    private var settingsReturnPhase: Phase?
    private var activeSince: Date?
    private enum UpgradeIntent { case strike, next, restart }
    private var upgradeIntent: UpgradeIntent?
    #if DEBUG
    var diagnostic: String {
        let data: [String: Any] = ["pocketStyles": Dictionary(uniqueKeysWithValues: markers.compactMap { $0 as? PocketLeatherMarker }.map { (String($0.pocketIndex), String(describing: $0.style)) }), "phase": String(describing: phase), "stage": record?.current?.stage ?? -1,
            "plannedPocket": record?.current?.plannedPocket ?? -1, "currentPocket": selectedPocketIndex,
            "question": record?.current?.id.uuidString ?? "", "quota": limiter.questionsUsedToday,
            "score": record?.latestShot?.freeScore ?? -1, "average": record?.questionAverage ?? -1,
            "locked": record?.plannedPocketLocked ?? false, "attempts": record?.attempts.count ?? 0,
            "isReplaying": isReplaying, "geometry": geometryReference.diagnostic, "playsStroke": playsStroke, "cameraBusy": cameraTransitionBusy,
            "temporaryTopDown": temporaryTopDownActive,
            "ballNumber": record?.current?.ballNumber ?? -1, "nextBallNumber": record?.current?.secondBallNumber ?? -1,
            "thirdBallNumber": record?.current?.thirdBallNumber ?? -1, "onTableKeys": onTableKeys,
            "firstScore": record?.firstStageScore ?? -1, "paletteKeys": paletteKeys,
            "paletteRoles": paletteRoles.mapValues(\.rawValue), "bankCount": ThreeBallBank.loadedCount,
            "positions": scene.allBallNodes.mapValues { [$0.position.x, $0.position.z] }]
        do { return String(decoding: try JSONSerialization.data(withJSONObject: data, options: .sortedKeys), as: UTF8.self) }
        catch { return "diagnostic encoding failed" }
    }
    #endif
    private var replayCamera = ShotReplayCamera()
    private struct BallDisplay {
        let position: SCNVector3, scale: SCNVector3
        let orientation: simd_quatf
        let hidden: Bool
        let opacity: CGFloat
        init(_ node: SCNNode) {
            position = node.position; scale = node.scale; orientation = node.simdOrientation
            hidden = node.isHidden; opacity = node.opacity
        }
        func restore(_ node: SCNNode?) {
            guard let node else { return }
            node.position = position; node.scale = scale; node.isHidden = hidden; node.opacity = opacity
            BallSpinIntegrator.applyPose(node, orientation)
        }
    }
    private var replayReturn: (Phase, [String: BallDisplay], PocketRailSnapshot)?
    private var replayStageReturn: (ThreeBallPracticeRecord, BallPoseSnapshot?, CameraRig.PerspectiveState?, SCNVector3?)?
    init(is3D: Bool, limiter: AngleUsageLimiter = .threeBallTraining, defaults: UserDefaults = .standard,
         prepareQuestion: @escaping QuestionPreparer = { configuration, excluding in
             try ThreeBallQuestionPreparer.prepare(configuration, excluding: excluding)
         }) {
        self.is3D = is3D; self.limiter = limiter; self.defaults = defaults
        self.prepareQuestion = prepareQuestion
        playsStroke = defaults.object(forKey: "threeBallPractice.\(is3D ? "3D" : "2D").playsStroke") as? Bool ?? SceneTrainingSettingsDefaults.playsStroke
        showsReference = defaults.object(forKey: "threeBallPractice.\(is3D ? "3D" : "2D").keepsReferenceAfterSubmission") as? Bool ?? SceneTrainingSettingsDefaults.showsReference
        cameraMode = is3D ? .perspective3D : .topDown2D
    }
    deinit {
        nextQuestionRequest?.task.cancel()
        nextQuestionObserver?.cancel()
    }
    var route: String { is3D ? "threeBallPractice3D" : "threeBallPractice2D" }
    var title: String { is3D ? "3D三球走位" : "2D三球走位" }
    var preferencePage: TablePreferencePage { is3D ? .threeBallPractice3D : .threeBallPractice2D }
    var targetNode: SCNNode? { scene.targetBallNodes.first }
    var secondNode: SCNNode? { record?.current.flatMap { scene.allBallNodes[$0.secondKey] } }
    var thirdNode: SCNNode? { record?.current.flatMap { $0.third == nil ? nil : scene.allBallNodes[$0.thirdKey] } }
    private var playbackNodes: [(SCNNode?, String)] {
        [(scene.cueBallNode, ShotInput.cueBallName), (targetNode, ShotInput.targetBallName),
         (secondNode, ThreeBallQuestionPreparer.secondBallName), (thirdNode, ThreeBallQuestionPreparer.thirdBallName)]
    }
    var canSelectPocket: Bool { phase == .aiming && !cameraTransitionBusy && record?.plannedPocketLocked == false }
    var needsPocket: Bool { phase == .aiming && record?.current?.plannedPocket == nil }
    var canSubmit: Bool { canAdjust && record?.current?.plannedPocket != nil }
    var paletteKeys: [String] { record?.current?.paletteKeys ?? [] }
    var paletteRoles: [String: BTTeachingBallRole] {
        guard let q = record?.current else { return [:] }
        var result: [String: BTTeachingBallRole] = Dictionary(uniqueKeysWithValues: q.paletteKeys.map { ($0, .upcoming) })
        if q.stage == 1, let first = q.paletteKeys.first { result[first] = .completed }
        result["_\(q.ballNumber)"] = .current
        result[q.secondKey] = .next
        return result
    }
    var feedbackShot: ThreeBallShot? {
        if phase == .result { return record?.latestShot }
        if phase == .aiming, record?.canRetryPreviousStage == true { return record?.firstStageCheckpoint?.shot }
        return nil
    }

    var selectedPocketIndex: Int { record?.current?.board.pocketIndex ?? 0 }
    var selectedTargetKey: String? { record?.current.map { "_\($0.ballNumber)" } }
    var onTableKeys: [String] { [PositionPlayBall.cueKey] + [selectedTargetKey, record?.current?.secondKey, record?.current?.third == nil ? nil : record?.current?.thirdKey].compactMap { $0 } }
    var draggableBalls: [SCNNode] { canAdjust ? geometryReference.draggableNodes : [] }
    var selectableBalls: [SCNNode] { [] }
    var isDragging: Bool { geometryReference.dragging }
    var currentPlayerAim: SCNVector3? { solvedAim ?? record?.current.map { AccuracyTipSelector.referenceDirection($0.board) } }
    var input: SeparationInput { record?.draftInput ?? .init() }
    var velocity: Double {
        get { Double(input.velocity) }
        set {
            guard canAdjust, newValue.isFinite else { return }
            record?.draftInput.velocity = Float(min(ShotTuning.velocityRange.upperBound,
                max(ShotTuning.velocityRange.lowerBound, newValue)))
            scheduleSave()
        }
    }
    func setSpin(_ x: Double, _ y: Double) {
        guard canAdjust else { return }
        var next = input; next.spinX = Float(x); next.spinY = Float(y)
        guard next.isValid else { return }
        record?.draftInput = next; redrawCue(); scheduleSave()
    }
    var isBusy: Bool { [.preparing, .playing, .saveFailed].contains(phase) }
    var canAdjust: Bool { phase == .aiming && !temporaryTopDownActive && !cameraTransitionBusy }
    var canRetry: Bool { ((phase == .result && record?.latestShot != nil) || (phase == .aiming && record?.canRetryPreviousStage == true)) && !temporaryTopDownActive && !cameraTransitionBusy }
    var canPlayback: Bool { (phase == .result || phase == .aiming) && (record?.latestShot != nil || record?.canRetryPreviousStage == true) && !temporaryTopDownActive && !cameraTransitionBusy }
    var shouldFinish: Bool {
        record.map { $0.status != .active || (!$0.configuration.freePractice && $0.totalProcessed >= 20) } == true
            || (!is3D && limiter.isLimitReached)
    }
    var primaryTitle: String {
        if isReplaying { return playsStroke ? "停止回放" : "停止击球" }
        switch phase {
        case .saveFailed: return "重试保存"
        case .result: return record?.canAdvanceStage == true ? "下一杆" : shouldFinish ? "查看总结" : "下一题"
        case .playing: return "击球中"
        default: return playsStroke ? "击球" : "提交"
        }
    }
    var outcomeText: String { record?.latestShot?.resultText ?? "" }
    private func permitted(newQuestion: Bool = false) -> Bool {
        limiter.refreshDay()
        if !limiter.isPremium && (is3D || record?.configuration.freePractice == true
            || (!is3D && limiter.isLimitReached && (newQuestion || record?.currentConsumed != true))) {
            upgradeIntent = newQuestion ? .next : .strike
            needsSubscription = true; return false
        }
        return true
    }
    func attach(context: ModelContext) {
        attach(repository: LocalThreeBallPracticeRepository(context: context))
    }
    func attach(repository: any ThreeBallPracticeRepository) {
        guard self.repository == nil else { return }
        self.repository = repository
        do {
            record = try repository.resumable(is3D: is3D)
            if var saved = record, saved.bankFingerprint != (try ThreeBallBank.currentFingerprint()) {
                saved.status = .ended
                try repository.save(saved)
                record = nil
                message = "三球题库已更新，请重新开始；已有训练记录已保留。"
            }
            shotPoses = record.map { decodePoses($0.initialPoses) }
            if let record, !record.isCompatible {
                throw SeparationQuestionGenerator.Failure.incompatible
            }
            phase = record == nil ? .settings : (record?.showingResult == true ? .result : .aiming)
            accountForSavedAttempts(); activeSince = Date()
        } catch { message = error.localizedDescription; phase = .settings }
    }
    func start(_ configuration: SceneTrainingConfiguration, prepared: ThreeBallQuestionPreparer.Prepared) {
        guard let repository else { return }
        guard limiter.isPremium || (!is3D && !configuration.freePractice && !limiter.isLimitReached) else {
            needsSubscription = true; return
        }
        discardNextQuestion()
        do {
            checkpointTime()
            if var old = record, old.status == .active { old.status = .ended; try repository.save(old) }
            let next = ThreeBallPracticeRecord(ownerKey: repository.ownerKey, is3D: is3D,
                configuration: configuration, prepared: prepared)
            try repository.save(next)
            invalidate(); record = next; phase = .aiming; solvedAim = nil
            shotPoses = nil; shotCamera = nil; activeSince = Date(); settingsReturnPhase = nil
            if builtScene { installQuestion() }
        } catch { message = error.localizedDescription }
    }
    func setupScene() {
        guard !builtScene else { resumeTeachingActivity(); return }
        teachingActive = true
        builtScene = true; scene.configureReferenceTableRendering()
        if is3D { scene.configureShotAwareCamera() }
        scene.setupScene(enhancedRendering: false); scene.setupVisualizationNodes()
        markers = scene.addPocketMarkers(); configureTeachingCamera(); installQuestion()
    }
    private func seatBalls() {
        guard let question = record?.current else { return }
        let y = scene.surfaceY + BallPhysics.radius
        scene.applyBallLayout(cueBallPosition: .init(question.board.cue.x, y, question.board.cue.z),
            targetBallNumber: question.ballNumber, targetPosition: .init(question.board.target.x, y, question.board.target.z))
        scene.showBall(key: question.secondKey, scenePosition: .init(question.second.x, y, question.second.z))
        if let third = question.third { scene.showBall(key: question.thirdKey, scenePosition: .init(third.x, y, third.z)) }
        scene.configureBallInstances(["_\(question.ballNumber)", question.secondKey] + (question.third == nil ? [] : [question.thirdKey]))
        scene.railInventory.clear()
        if let shotPoses { scene.restoreBallPoses(shotPoses) }
    }
    private func installQuestion() {
        guard let question = record?.current else { return }
        scene.hideAllVisualization(); scene.setIdealObjectLine(nil); scene.setFreeAimPreviewLine(nil)
        seatBalls(); drawAimingGuides()
        if shotPoses == nil { shotPoses = scene.captureBallPoses() }
        record?.initialPoses = encodePoses(shotPoses ?? [:])
        _ = save()
        scene.setPracticePocketRoles(current: question.board.pocketIndex, next: question.plannedPocket)
        highlightedQuestionID = question.id
        topDownContentRevision += 1
        clearActual(); prepareReference()
        if record?.showingResult == true { showFinal(); drawActual(); phase = .result }
        else { phase = .aiming; drawActual(showsObjectRoute: false); redrawCue() }
        refreshObservationCameraContext()
        if is3D {
            requestPlayerView(.thirdPerson, animated: false)
            if let saved = record?.viewBookmark, let cue = scene.cueBallNode?.position, let aim = currentPlayerAim {
                scene.cameraRig?.restoreTrainingBookmark(saved, cue: cue, aim: aim)
            }
        }
        activeSince = Date(); refreshNextQuestion()
        if record?.canAdvanceStage == true { advanceStage() }
    }
    /// Fixed geometric references belong to the question, like its target route.
    /// They do not predict a new shot or reveal the answer's tip / speed.
    var cutAngleDegrees: Double? {
        guard let board = record?.current?.board else { return nil }
        let y = scene.surfaceY + BallPhysics.radius
        let cue = SCNVector3(board.cue.x, y, board.cue.z)
        let target = SCNVector3(board.target.x, y, board.target.z)
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: board.pocketIndex, surfaceY: scene.surfaceY)
        return AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: pocket)
    }
    var latestScoreTitle: String {
        record?.latestShot != nil && record?.showingResult == false && !isBusy ? "上杆得分" : "本杆得分"
    }
    private func drawAimingGuides() {
        guard let question = record?.current else { scene.hideAllVisualization(); return }
        let y = scene.surfaceY + BallPhysics.radius
        let cue = SCNVector3(question.board.cue.x, y, question.board.cue.z)
        let target = SCNVector3(question.board.target.x, y, question.board.target.z)
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: question.board.pocketIndex, surfaceY: scene.surfaceY)
        scene.updateVisualization(cueBall: cue, targetBall: target, pocket: pocket,
            showAngleAnnotations: false, showOverlapMarkers: false, showLineLabels: false,
            showStrikeLine: true, showPocketLine: true, showDiagramAngle: false, showGhostBall: true)
    }
    private func points(_ line: [SeparationTrajectory.Point]) -> [SCNVector3] {
        line.map { .init($0.position.x, scene.surfaceY + BallPhysics.radius, $0.position.z) }
    }
    /// A question-scoped baseline; never consumes player input, a submission, or an attempt.
    private func prepareReference() {
        guard shouldShowReference else {
            clearReference(); topDownContentRevision += 1; return
        }
        guard builtScene, teachingActive, let question = record?.current else { return }
        if referenceQuestionID != question.id {
            clearReference()
            referenceQuestionID = question.id
        }
        guard referenceTrajectory == nil, referenceWork == nil, !referenceFailed else { return }
        let surface = scene.surfaceY, profile = AccuracyTipSelector.renderedProfile()
        referenceWork = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                let prediction = try ThreeBallQuestionPreparer.solve(question: question, input: SeparationInput(), surfaceY: surface, profile: profile)
                // Keep the real route even when this fixed speed cannot pot the object ball.
                return try SeparationTrajectory.extract(prediction)
            }
            do {
                let line = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard let self, !Task.isCancelled, self.record?.current?.id == question.id,
                      self.shouldShowReference, self.referenceQuestionID == question.id else { return }
                self.referenceTrajectory = line
                self.scene.addDashedPolyline(self.points(line), color: SeparationRouteStyle.reference,
                    placement: .table, into: &self.referenceNodes)
                self.referenceNodes.forEach {
                    $0.name = "threeBall.reference"
                    // Actual / target paths stay legible when they coincide with the baseline.
                    $0.renderingOrder -= 1
                }
                self.topDownContentRevision += 1
                self.referenceWork = nil
            } catch is CancellationError {
                // The owner of cancellation resets referenceWork; no stale callback may replace it.
            } catch {
                guard let self, !Task.isCancelled, self.record?.current?.id == question.id,
                      self.shouldShowReference, self.referenceQuestionID == question.id else { return }
                self.referenceWork = nil
                self.referenceFailed = true
                if let feedback = TrainingPracticeNotice.recoverable(error, reference: true) {
                    // Resume an older second-stage draft without misreporting a reference as a new shot.
                    if case SeparationQuestionGenerator.Failure.noDirectRoute = error,
                       self.record?.canRetryPreviousStage == true,
                       self.record?.firstStageScore == 0 {
                        self.notice = .init(text: TrainingPracticeNotice.cannotPot)
                    } else { self.notice = feedback }
                } else {
                    self.message = "中杆参考轨迹未能生成：" + error.localizedDescription
                }
            }
        }
    }
    private func clearReference() {
        referenceWork?.cancel(); referenceWork = nil
        referenceNodes.forEach { $0.removeFromParentNode() }; referenceNodes = []
        referenceTrajectory = nil; referenceQuestionID = nil; referenceFailed = false
    }
    private func clearActual() {
        actualNodes.forEach { $0.removeFromParentNode() }; actualNodes = []
        objectNodes.forEach { $0.removeFromParentNode() }; objectNodes = []
        drawAimingGuides()
    }
    private func drawActual(showsObjectRoute: Bool = true) {
        prepareReference()
        clearActual()
        topDownContentRevision += 1
        guard record?.latestShot != nil else { return }
        scene.addDashedPolyline(points(record?.latestShot?.trajectory ?? []), color: SeparationRouteStyle.actual,
            placement: .table, into: &actualNodes)
        actualNodes.forEach { $0.name = "threeBall.actual" }
        guard showsObjectRoute else { return }
        scene.pocketLineNode?.isHidden = true
        scene.addDashedPolyline(points(record?.latestShot?.objectTrajectory ?? []),
            color: TrajectoryStyle.potColor(forNumber: record?.current?.ballNumber ?? 1),
            placement: .table, into: &objectNodes)
        objectNodes.forEach { $0.name = "threeBall.objectActual" }
    }
    func prepareGeometryReference() {
        guard canAdjust, let question = record?.current else { return }
        let y = scene.surfaceY + BallPhysics.radius
        geometryReference.update(identity: "\(question.id):\(question.stage)",
            cue: .init(question.board.cue.x, y, question.board.cue.z),
            target: .init(question.board.target.x, y, question.board.target.z),
            pocketIndex: selectedPocketIndex)
    }
    private func redrawCue() {
        prepareGeometryReference()
        guard phase == .aiming, let cue = scene.cueBallNode, let aim = currentPlayerAim else { return }
        scene.updateCueStick(cueBallPosition: CueStroke.strikePosition(cue: cue.position, aim: aim,
            spinX: Double(input.spinX), spinY: Double(input.spinY)), aimDirection: aim)
    }
    func strike() {
        guard canAdjust, let question = record?.current else { return }
        guard question.plannedPocket != nil else { pocketRequestID = UUID(); return }
        guard permitted() else { return }
        pocketRequestID = nil
        prepareGeometryReference(); geometryReference.freeze()
        invalidate(preservingCue: true)
        let token = generation, frozen = input, surface = scene.surfaceY, animate = playsStroke
        shotPoses = scene.captureBallPoses(); shotCamera = ShotReplayCamera.capture(in: scene)
        record?.initialPoses = encodePoses(shotPoses ?? [:])
        checkpointTime(); activeSince = nil
        phase = .preparing; message = nil
        work = Task {
            let worker = Task.detached(priority: .userInitiated) { () throws -> ThreeBallShot in
                let prediction = try ThreeBallQuestionPreparer.solve(question: question, input: frozen,
                    surfaceY: surface, profile: AccuracyTipSelector.renderedProfile())
                return try ThreeBallShot(question: question, input: frozen, prediction: prediction, surfaceY: surface)
            }
            do {
                let shot = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled, token == generation, question.id == record?.current?.id else { return }
                var submission = shot
                submission.playsStroke = animate
                pendingShot = submission
                commitAndPlay()
            } catch {
                guard token == generation, !Task.isCancelled else { return }
                phase = .aiming; activeSince = Date()
                if let feedback = TrainingPracticeNotice.recoverable(error) { notice = feedback }
                else { message = error.localizedDescription }
                redrawCue()
            }
        }
    }
    private func commitAndPlay() {
        guard let pendingShot, var next = record, let repository else { return }
        checkpointTime(); next.activeSeconds = record?.activeSeconds ?? next.activeSeconds
        next.accept(pendingShot); next.showingResult = true
        next.finalPoses = [:]
        solvedAim = pendingShot.direction.vector
        if is3D, scene.cameraRig?.overviewControlSelected != true {
            // Keep the selected first/third-person mode; prepare the selected camera before the stroke.
            requestPlayerView(scene.cameraRig?.twoViewMode ?? .thirdPerson, animated: false)
        }
        shotCamera = ShotReplayCamera.capture(in: scene)
        if is3D { next.shotBookmark = scene.cameraRig?.trainingBookmark() }
        do { try repository.save(next) }
        catch LocalThreeBallPracticeRepository.Failure.oversizedRecord {
            self.pendingShot = nil; phase = .aiming; activeSince = Date()
            message = "本题的轨迹记录过大，请调整打点或力度后重试；尚未扣除题数。"; return
        }
        catch { phase = .saveFailed; message = "未能保存本杆，请重试保存；尚未扣除题数。"; return }
        record = next; self.pendingShot = nil; accountForSavedAttempts()
        refreshNextQuestion()
        if pendingShot.isTrajectoryOnly {
            scene.hideCueStick(); drawActual(); phase = .result; activeSince = Date()
            refreshObservationCameraContext()
            if record?.canAdvanceStage == true { advanceStage() }
            return
        }
        // Establish the compensated address and directly start the ordinary cue stroke.
        if let cue = scene.cueBallNode {
            scene.updateCueStick(cueBallPosition: CueStroke.strikePosition(cue: cue.position, aim: pendingShot.direction.vector,
                spinX: Double(pendingShot.input.spinX), spinY: Double(pendingShot.input.spinY)),
                aimDirection: pendingShot.direction.vector)
        }
        drawActual(); scene.isPaused = false
        play(pendingShot)
    }
    func retrySave() { guard phase == .saveFailed else { return }; commitAndPlay() }
    private func play(_ shot: ThreeBallShot) {
        checkpointTime(); activeSince = nil
        phase = .playing
        if !isReplaying { record?.showingResult = true; _ = save() }
        if isReplaying { seatBalls() }
        solvedAim = shot.direction.vector
        if isReplaying {
            if shotCamera == nil, let saved = record?.shotBookmark, let cue = scene.cueBallNode?.position {
                scene.cameraRig?.restoreTrainingBookmark(saved, cue: cue, aim: shot.direction.vector)
            } else { replayCamera.showShot(shotCamera, in: scene, aim: shot.direction.vector) }
        }
        guard let cue = scene.cueBallNode else { phase = .result; return }
        let prediction = shot.prediction()
        guard let recorder = prediction.recorder else { phase = .result; return }
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: scene.surfaceY + BallPhysics.radius,
                                          railInventory: scene.railInventory)
        if !isReplaying {
            var terminal = shotPoses ?? [:]
            for (key, name) in playbackNodes.compactMap({ node, name in node.map { ($0.name ?? "", name) } }) {
                let node = SCNNode()
                node.simdOrientation = terminal[key] ?? BallSpinIntegrator.identityOrientation
                let end = shot.captures.first { $0.name == name }?.frame.time ?? shot.duration
                let steps = max(1, Int(ceil(end * 240)))
                var previous = playback.stateAt(ballName: name, time: 0)?.angularVelocity ?? SCNVector3Zero
                for index in 1...steps {
                    let now = Float(index)*end/Float(steps)
                    let omega = playback.stateAt(ballName: name, time: now)?.angularVelocity ?? SCNVector3Zero
                    BallSpinIntegrator.advance(node: node, from: previous, to: omega, dt: end/Float(steps))
                    previous = omega
                }
                terminal[key] = node.simdOrientation
            }
            record?.finalPoses = encodePoses(terminal); _ = save()
        }
        let strike = CueStroke.strikePosition(cue: cue.position, aim: shot.direction.vector,
            spinX: Double(shot.input.spinX), spinY: Double(shot.input.spinY))
        scene.updateCueStick(cueBallPosition: strike, aimDirection: shot.direction.vector)
        let token = generation
        scene.runCueStroke(strikePosition: strike, aim: shot.direction.vector, velocity: shot.input.velocity,
            rehearsalEnabled: false,
            clearanceProbe: { playback.allBallCentersByName(at: Float($0)) }) { [weak self] in
            guard let self, self.generation == token, self.phase == .playing else { return }
            var actions: [(SCNNode, SCNAction)] = []
            for (node, name) in self.playbackNodes {
                if let node, let action = playback.action(for: node, ballName: name, removeOnPocket: false,
                                                          maxSimTime: playback.duration) { actions.append((node, action)) }
            }
            guard !actions.isEmpty else { self.completedPlayback(token); return }
            var remaining = actions.count
            for (node, action) in actions {
                node.runAction(action, forKey: "threeBall.play") { [weak self] in
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        remaining -= 1
                        if remaining == 0 { self.completedPlayback(token) }
                    }
                }
            }
            ShotAudioScheduler.shared.play(prediction: prediction)
        }
    }
    private func completedPlayback(_ token: UUID) {
        guard token == generation else { return }
        if isReplaying { stopPlayback(); return }
        scene.railInventory.finishPlayback()
        scene.hideCueStick(); phase = .result; activeSince = Date(); refreshObservationCameraContext()
        record?.finalPoses = encodePoses(scene.captureBallPoses())
        if save(), record?.canAdvanceStage == true { advanceStage() }
    }
    func retry() {
        guard canRetry, permitted(), var next = record, let repository else { return }
        checkpointTime(); next.activeSeconds = record?.activeSeconds ?? next.activeSeconds
        next.retryLastStroke()
        guard let shot = next.latestShot else { return }
        do { try repository.save(next) }
        catch { message = "未能恢复本杆，请重试。"; return }
        invalidate(); clearReference(); record = next; pocketRequestID = nil
        shotPoses = decodePoses(next.initialPoses); shotCamera = nil
        solvedAim = shot.direction.vector; phase = .aiming
        installQuestion()
        if let saved = record?.shotBookmark, let cue = scene.cueBallNode?.position {
            scene.cameraRig?.restoreTrainingBookmark(saved, cue: cue, aim: shot.direction.vector)
        }
        redrawCue(); geometryReference.restore(); _ = save()
    }
    func replayLastShot() {
        guard canPlayback, save(), var replayRecord = record else { return }
        let state = (phase, scene.allBallNodes.mapValues(BallDisplay.init), scene.railInventory.snapshot())
        invalidate(); replayReturn = state; replayCamera.begin(in: scene)
        if replayRecord.canRetryPreviousStage {
            clearReference()
            replayStageReturn = (replayRecord, shotPoses, shotCamera, solvedAim)
            replayRecord.retryLastStroke(); record = replayRecord
            shotPoses = decodePoses(replayRecord.initialPoses); shotCamera = nil
            seatBalls()
            scene.setPracticePocketRoles(current: selectedPocketIndex, next: replayRecord.current?.plannedPocket)
        }
        guard let shot = replayRecord.latestShot else { return }
        isReplaying = true
        drawActual(); play(shot)
    }
    func stopPlayback() {
        guard isReplaying else { return }
        invalidate()
        if phase == .aiming { drawActual(showsObjectRoute: false); redrawCue() }
    }
    private func restoreReplay() {
        guard let state = replayReturn else { return }
        if let stage = replayStageReturn {
            clearReference()
            record = stage.0; shotPoses = stage.1; shotCamera = stage.2; replayStageReturn = nil
            seatBalls()
            solvedAim = stage.3
            scene.setPracticePocketRoles(current: selectedPocketIndex, next: record?.current?.plannedPocket)
        }
        for (key, display) in state.1 { display.restore(scene.allBallNodes[key]) }
        replayCamera.finish(in: scene); phase = state.0; activeSince = Date(); record?.showingResult = state.0 == .result
        replayReturn = nil; isReplaying = false
        if phase == .aiming { drawActual(showsObjectRoute: false) }
    }
    private var nextQuestionKey: NextQuestionKey? {
        guard let record, let question = record.current, let repository,
              repository.ownerKey == record.ownerKey else { return nil }
        return .init(sessionID: record.id, questionID: question.id, ownerKey: record.ownerKey)
    }
    private var canPrepareNextQuestion: Bool {
        guard teachingActive, phase != .settings, phase != .summary, phase != .loading,
              let record, record.status == .active, nextQuestionKey != nil else { return false }
        // Reserve the current unanswered question before speculating on another free question.
        guard record.configuration.freePractice || (record.questionNumber < 20 && record.totalProcessed < 20) else { return false }
        if !limiter.isPremium {
            guard !is3D, !record.configuration.freePractice else { return false }
            return limiter.remainingToday > (!record.currentConsumed ? 1 : 0)
        }
        return true
    }
    private func discardNextQuestion() {
        nextQuestionObserver?.cancel(); nextQuestionObserver = nil
        nextQuestionRequest?.task.cancel(); nextQuestionRequest = nil
        nextQuestionReady = false
    }
    /// A single speculative slot, never a recorded/charged question. Also called when rights change.
    func refreshNextQuestion() {
        guard canPrepareNextQuestion, let key = nextQuestionKey, let record else {
            discardNextQuestion(); return
        }
        if nextQuestionRequest?.key == key { return }
        discardNextQuestion()
        let configuration = record.configuration, excluded = record.seenContentIDs
        let prepare = prepareQuestion
        let worker = Task.detached(priority: .utility) { try prepare(configuration, excluded) }
        let request = NextQuestionRequest(key: key, task: worker)
        nextQuestionRequest = request
        nextQuestionObserver = Task { [weak self] in
            do {
                let prepared = try await worker.value
                guard !Task.isCancelled, let self, self.nextQuestionRequest === request else { return }
                guard self.nextQuestionKey == key, self.canPrepareNextQuestion else {
                    self.discardNextQuestion(); return
                }
                guard prepared.fingerprint == self.record?.bankFingerprint,
                      !excluded.contains(prepared.question.contentID) else {
                    self.discardNextQuestion(); return
                }
                request.prepared = prepared; self.nextQuestionReady = true
            } catch {
                // Speculation is silent; a foreground Next may retry and surface its own failure.
                guard !Task.isCancelled, let self, self.nextQuestionRequest === request else { return }
                self.discardNextQuestion()
            }
        }
    }
    private func advanceStage() {
        checkpointTime()
        guard var next = record, let repository else { return }
        do {
            try next.advanceStage()
            try repository.save(next)
            invalidate(); clearReference(); record = next
            shotPoses = decodePoses(next.initialPoses); shotCamera = nil; solvedAim = nil; highlightedQuestionID = nil
            installQuestion()
        } catch { message = error.localizedDescription }
    }
    func next() {
        guard phase == .result else { return }
        if record?.canAdvanceStage == true { advanceStage(); return }
        limiter.refreshDay()
        if shouldFinish { finish(); return }
        guard permitted(newQuestion: true) else { discardNextQuestion(); return }
        refreshNextQuestion()
        guard let request = nextQuestionRequest else { return }
        checkpointTime(); activeSince = nil
        invalidate(); let token = generation; phase = .preparing; message = nil
        if let prepared = request.prepared {
            // Ready questions advance synchronously: no second solver and no loading-frame round trip.
            do { try installNextQuestion(prepared, request: request, token: token) }
            catch { phase = .result; activeSince = Date(); message = error.localizedDescription }
        } else {
            work = Task { [weak self] in
                do {
                    let prepared = try await request.task.value
                    guard !Task.isCancelled, let self, self.generation == token else { return }
                    try self.installNextQuestion(prepared, request: request, token: token)
                } catch {
                    guard !Task.isCancelled, let self, self.generation == token else { return }
                    self.phase = .result; self.activeSince = Date()
                    if self.shouldFinish { self.finish(); return }
                    guard self.permitted(newQuestion: true) else { self.discardNextQuestion(); return }
                    if !(error is CancellationError) { self.message = error.localizedDescription }
                }
            }
        }
    }
    private func installNextQuestion(_ prepared: ThreeBallQuestionPreparer.Prepared,
                                     request: NextQuestionRequest, token: UUID) throws {
        guard generation == token, nextQuestionKey == request.key else { return }
        // Recheck after awaiting: quota, subscription and owner may change while generating.
        limiter.refreshDay()
        if shouldFinish { phase = .result; finish(); return }
        guard permitted(newQuestion: true), teachingActive else {
            discardNextQuestion(); phase = .result; return
        }
        guard var next = record, let repository else { return }
        guard prepared.fingerprint == next.bankFingerprint,
              !next.seenContentIDs.contains(prepared.question.contentID) else {
            discardNextQuestion(); throw SeparationQuestionGenerator.Failure.incompatible
        }
        // A revoked and later restored entitlement can create a new request for the same key.
        // Never resurrect the cancelled request simply because the question still matches.
        guard nextQuestionRequest === request, !request.task.isCancelled else { phase = .result; return }
        // Keep a valid result for a save retry; consume the slot only after the atomic save succeeds.
        request.prepared = prepared; nextQuestionRequest = request; nextQuestionReady = true
        checkpointTime(); next.activeSeconds = record?.activeSeconds ?? next.activeSeconds
        let payloadSize = try next.encodedPayload().count
        let segmentFull = next.configuration.freePractice && (next.consumed.count >= 10 || payloadSize >= 512_000)
        var archived: ThreeBallPracticeRecord?
        if segmentFull {
            archived = next; archived?.status = .completed; archived?.updatedAt = Date()
            next = next.continuation(prepared: prepared)
        } else { next.questions.append(prepared.question); next.cursor += 1 }
        next.resetInput(); next.firstStageScore = nil; next.firstStageCheckpoint = nil; next.seenContentIDs.insert(prepared.question.contentID)
        next.draftInput = .init()
        next.latestShot = nil; next.showingResult = false; next.updatedAt = Date()
        next.initialPoses = [:]; next.finalPoses = [:]
        next.viewBookmark = nil; next.shotBookmark = nil
        try repository.saveAtomically(archived.map { [$0, next] } ?? [next])
        discardNextQuestion()
        record = next; shotPoses = nil; shotCamera = nil; solvedAim = nil; installQuestion()
    }
    func finish() {
        guard !isBusy else { return }
        discardNextQuestion()
        checkpointTime()
        guard var next = record else { return }
        next.status = !next.configuration.freePractice && next.totalProcessed >= 20 ? .completed : .ended
        next.updatedAt = Date()
        do { try repository?.save(next); record = next; invalidate(); phase = .summary; activeSince = nil }
        catch { message = error.localizedDescription }
    }
    func reviewLastQuestion() {
        if phase == .summary, record?.latestShot != nil { phase = .result; activeSince = Date() }
    }
    func restart() {
        limiter.refreshDay()
        guard limiter.isPremium || (!is3D && !limiter.isLimitReached) else {
            upgradeIntent = .restart; needsSubscription = true; return
        }
        openSettings()
    }
    func subscriptionDismissed() {
        let intent = upgradeIntent; upgradeIntent = nil
        guard limiter.isPremium else { return }
        switch intent {
        case .strike: strike()
        case .next: next()
        case .restart: openSettings()
        case nil: break
        }
    }
    func openSettings() {
        guard !isBusy else { return }
        discardNextQuestion()
        checkpointTime(); activeSince = nil
        settingsReturnPhase = record == nil ? nil : phase; phase = .settings
    }
    func cancelSettings() -> Bool {
        guard let previous = settingsReturnPhase else { return false }
        phase = previous; activeSince = Date(); settingsReturnPhase = nil; refreshNextQuestion(); return true
    }
    private func showFinal() {
        guard let shot = record?.latestShot else { return }
        if shot.isTrajectoryOnly {
            seatBalls(); scene.hideCueStick()
            return
        }
        for (node, name) in playbackNodes {
            if let position = shot.finalPositions[name] { node?.position = position.value }
            node?.isHidden = shot.pocketedBalls.contains(name)
        }
        scene.hideCueStick()
        if let record, !record.finalPoses.isEmpty { scene.restoreBallPoses(decodePoses(record.finalPoses)) }
        // Rebuild the presentation-only pocket rails from the same capture facts.
        // A restored result must not lose the potted ball's visible return-rail resident.
        scene.railInventory.clear()
        if let recorder = shot.prediction().recorder, let railShot = scene.railInventory.beginShot(recorder: recorder) {
            for (node, name) in playbackNodes {
                if let node, shot.pocketedBalls.contains(name) {
                    scene.railInventory.bind(node, alias: name, to: railShot)
                    scene.railInventory.beginTail(alias: name, source: node, shot: railShot)
                }
            }
            scene.railInventory.finishPlayback()
        }
    }
    private func encodePoses(_ poses: BallPoseSnapshot) -> [String: [Float]] {
        poses.mapValues { [$0.vector.x, $0.vector.y, $0.vector.z, $0.vector.w] }
    }
    private func decodePoses(_ poses: [String: [Float]]) -> BallPoseSnapshot {
        poses.compactMapValues { value in
            guard value.count == 4, value.allSatisfy(\.isFinite) else { return nil }
            return simd_quatf(vector: .init(value[0], value[1], value[2], value[3]))
        }
    }
    private func checkpointTime() {
        if let activeSince { record?.activeSeconds += max(0, Date().timeIntervalSince(activeSince)); self.activeSince = Date() }
    }
    @discardableResult private func save() -> Bool {
        draftSave?.cancel(); checkpointTime()
        guard let record, let repository else { return false }
        do { try repository.save(record); return true }
        catch { message = "未能保存练习，请稍后重试。"; return false }
    }
    private func scheduleSave() {
        draftSave?.cancel()
        draftSave = Task { try? await Task.sleep(for: .milliseconds(300)); if !Task.isCancelled { save() } }
    }
    private func accountForSavedAttempts() {
        guard !is3D else { return }
        for (id, date) in record?.consumed ?? [:] { limiter.recordQuestion(attemptID: id, submittedAt: date) }
    }
    private func invalidate(preservingCue: Bool = false) {
        notice = nil
        generation = UUID(); work?.cancel(); work = nil; scene.frameReceipt.cancel()
        // Finish rail cancellation before taking SceneKit's lock: rail callbacks
        // hold their own state lock while updating nodes.
        if let state = replayReturn { scene.railInventory.restore(state.2) }
        // SceneKit can evaluate actions on its render thread. Cancel and restore
        // under the same transaction lock, without implicit position animations.
        SCNTransaction.lock()
        defer { SCNTransaction.unlock() }
        SCNTransaction.begin(); SCNTransaction.disableActions = true
        defer { SCNTransaction.commit() }
        for (node, _) in playbackNodes { node?.removeAllActions() }
        if preservingCue { scene.cueStick?.cancelAnimations() }
        else { scene.hideCueStick() }
        ShotAudioScheduler.shared.cancel(); restoreReplay()
    }
    func suspendTeachingActivity() {
        scene.cancelPocketSelectionFeedback()
        teachingActive = false; discardNextQuestion()
        referenceWork?.cancel(); referenceWork = nil
        if is3D, !isReplaying, !temporaryTopDownActive { record?.viewBookmark = scene.cameraRig?.trainingBookmark() }
        let wasPlaying = phase == .playing && !isReplaying
        invalidate()
        if wasPlaying { phase = .result; record?.showingResult = true; showFinal() }
        else if phase == .preparing {
            phase = record?.showingResult == true ? .result : .aiming
            if phase == .aiming { seatBalls(); drawActual(showsObjectRoute: false); record?.showingResult = false }
            else { showFinal(); drawActual() }
        }
        _ = save(); activeSince = nil
    }
    func resumeTeachingActivity() {
        teachingActive = true
        refreshNextQuestion()
        if phase == .aiming || phase == .result { activeSince = Date() }
        limiter.refreshDay()
        guard builtScene else { return }
        scene.isPaused = false
        if phase == .result, record?.canAdvanceStage == true { advanceStage(); return }
        prepareReference()
        if phase == .aiming { redrawCue() }
    }
    func layoutEditingChanged(_ editing: Bool) {
        if editing { _ = save(); activeSince = nil }
        else if phase == .aiming || phase == .result { activeSince = Date() }
    }
    func ownerChanged() {
        discardNextQuestion()
        clearReference()
        invalidate(); draftSave?.cancel(); record = nil; pendingShot = nil; phase = .settings
        upgradeIntent = nil; shotPoses = nil; shotCamera = nil; solvedAim = nil
        targetNodes.forEach { $0.removeFromParentNode() }; targetNodes = []; clearActual()
        scene.hideAllVisualization()
        message = "账号已切换，请重新开始练习。"
    }
    func selectPocket(at index: Int) {
        guard canSelectPocket, (0..<6).contains(index), var next = record else { return }
        next.selectPocket(index)
        do {
            try repository?.save(next); record = next
            pocketRequestID = nil
            scene.setPracticePocketRoles(current: selectedPocketIndex, next: index)
            scene.confirmRolePocketSelection(at: index)
            topDownContentRevision += 1
        } catch { message = error.localizedDescription }
    }
    func selectTarget(key: String) {}
    func placeFromPalette(_ key: String) {}
    func palettePlacement(_ key: String, atWorld world: SCNVector3) -> SCNVector3? { nil }
    func removeFromTable(_ key: String) {}
    func dragBegan(node: SCNNode) { if node === geometryReference.handle { geometryReference.beginDrag() } }
    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        if canAdjust, node === geometryReference.handle { geometryReference.drag(to: worldPosition) }
    }
    func dragEnded(node: SCNNode) { if node === geometryReference.handle { geometryReference.endDrag() } }
}
