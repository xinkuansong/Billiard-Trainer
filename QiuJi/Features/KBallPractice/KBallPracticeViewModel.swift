import SwiftUI
import SceneKit
import SwiftData

@MainActor
final class KBallPracticeViewModel: ObservableObject, TeachingTableHost {
    enum Phase { case loading, settings, aiming, preparing, playing, result, saveFailed, summary }
    var is3D: Bool { cameraMode == .perspective3D }
    private let initialView3D: Bool
    let scene = AngleTrainingScene()
    let limiter: AngleUsageLimiter
    @Published private(set) var record: KBallPracticeRecord?
    @Published private(set) var phase: Phase = .loading {
        didSet {
            if phase == .result || phase == .summary || phase == .settings { geometryReference.complete() }
            else if phase == .aiming { geometryReference.cancelFreeze() }
        }
    }
    lazy var geometryReference = GeometricReferenceTool(scene: scene) { [weak self] in self?.objectWillChange.send(); self?.scheduleSave() }
    @Published var message: String?
    @Published private(set) var notice: TrainingPracticeNotice?
    @Published var cameraMode: AngleTrainingScene.CameraMode
    @Published var cameraTransitionBusy = false
    @Published var temporaryTopDownActive = false
    @Published var topDownContentRevision = 0
    @Published var topDownSelectionChanged = false
    @Published private(set) var isReplaying = false
    @Published var needsSubscription = false
    @Published private(set) var playsStroke: Bool
    private let defaults: UserDefaults
    private var strokePreferenceKey: String { "kBallPractice.project.playsStroke" }
    func setPlaysStroke(_ enabled: Bool) {
        guard !isBusy else { return }
        playsStroke = enabled
        defaults.set(enabled, forKey: strokePreferenceKey)
    }
    // Like two-ball practice, the neutral baseline is visible only before the first answer.
    // It is not the saved solution and is independent of the learner's current input.
    var shouldShowReference: Bool { record?.current != nil && record?.currentAttempt == nil }
    typealias QuestionPreparer = @Sendable (KBallConfiguration, Set<String>) throws -> KBallQuestionPreparer.Prepared
    private let prepareQuestion: QuestionPreparer
    private struct NextQuestionKey: Equatable {
        let sessionID: UUID, questionID: UUID
        let ownerKey: String
    }
    private final class NextQuestionRequest {
        let key: NextQuestionKey
        let task: Task<KBallQuestionPreparer.Prepared, Error>
        var prepared: KBallQuestionPreparer.Prepared?
        init(key: NextQuestionKey, task: Task<KBallQuestionPreparer.Prepared, Error>) {
            self.key = key; self.task = task
        }
    }
    private var nextQuestionRequest: NextQuestionRequest?
    private var nextQuestionObserver: Task<Void, Never>?
    @Published private(set) var nextQuestionReady = false
    private var teachingActive = false
    private var repository: (any KBallPracticeRepository)?
    private var generation = UUID()
    private var work: Task<Void, Never>?
    private var draftSave: Task<Void, Never>?
    private var builtScene = false
    private var actualNodes: [SCNNode] = []
    private var referenceNodes: [SCNNode] = []
    private var referenceWork: Task<Void, Never>?
    private var referenceQuestionID: UUID?
    private var referenceFailed = false
    private(set) var referenceTrajectory: [SeparationTrajectory.Point]?
    private var objectNodes: [SCNNode] = []
    private var markers: [SCNNode] = []
    private var solvedAim: SCNVector3?
    private var shotPoses: BallPoseSnapshot?
    private var shotCamera: CameraRig.PerspectiveState?
    private var pendingPremium = false
    private var pendingShot: KBallShot?
    private var settingsReturnPhase: Phase?
    private var activeSince: Date?
    private enum UpgradeIntent { case strike, next, restart }
    private var upgradeIntent: UpgradeIntent?
    #if DEBUG
    var diagnostic: String {
        let value: [String: Any] = ["phase": String(describing: phase), "question": record?.current?.id.uuidString ?? "",
            "attempts": record?.attempts.count ?? 0, "successes": record?.successCount ?? 0,
            "referenceVisible": !referenceNodes.isEmpty, "actualVisible": !actualNodes.isEmpty,
            "view": is3D ? "3D" : "2D", "input": [input.spinX, input.spinY, input.velocity],
            "quota": limiter.questionsUsedToday, "primary": primaryTitle]
        return (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
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
    private var replayReturn: (Phase, BallDisplay, BallDisplay, PocketRailSnapshot, BallDisplay)?
    init(is3D: Bool, limiter: AngleUsageLimiter = .kBallTraining, defaults: UserDefaults = .standard,
         prepareQuestion: @escaping QuestionPreparer = { configuration, excluding in
             try KBallQuestionPreparer.prepare(configuration, excluding: excluding)
         }) {
        self.initialView3D = is3D; self.limiter = limiter; self.defaults = defaults
        self.prepareQuestion = prepareQuestion
        playsStroke = defaults.object(forKey: "kBallPractice.project.playsStroke") as? Bool ?? defaults.object(forKey: "kBallPractice.\(is3D ? "3D" : "2D").playsStroke") as? Bool ?? SceneTrainingSettingsDefaults.playsStroke
        cameraMode = is3D ? .perspective3D : .topDown2D
    }
    deinit {
        nextQuestionRequest?.task.cancel()
        nextQuestionObserver?.cancel()
        draftSave?.cancel()
    }
    var route: String { is3D ? "kBallPractice3D" : "kBallPractice2D" }
    var title: String { "K球练习" }
    var preferencePage: TablePreferencePage { is3D ? .kBallPractice3D : .kBallPractice2D }
    var targetNode: SCNNode? { scene.targetBallNodes.first }
    var secondNode: SCNNode? { scene.allBallNodes["_8"] }
    var paletteRoles: [String: BTTeachingBallRole] {
        guard let question = record?.current else { return [:] }
        return ["_\(question.ballNumber)": .current, "_\(question.secondBallNumber)": .next]
    }

    var selectedPocketIndex: Int { record?.current?.board.pocketIndex ?? 0 }
    var selectedTargetKey: String? { record?.current.map { "_\($0.ballNumber)" } }
    var onTableKeys: [String] { [PositionPlayBall.cueKey] + [selectedTargetKey, "_8"].compactMap { $0 } }
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
    var canRetry: Bool { phase == .result && record?.latestShot != nil && !temporaryTopDownActive && !cameraTransitionBusy }
    var canPlayback: Bool { (phase == .result || phase == .aiming) && record?.latestShot != nil && !temporaryTopDownActive && !cameraTransitionBusy }
    var shouldFinish: Bool {
        record.map { $0.status != .active || (!$0.configuration.freePractice && $0.totalProcessed >= 15) } == true
            || limiter.isLimitReached
    }
    var primaryTitle: String {
        if isReplaying { return "停止" }
        switch phase {
        case .saveFailed: return "重试保存"
        case .result: return shouldFinish ? "查看总结" : "下一题"
        case .playing: return "击球中"
        default: return playsStroke ? "击球" : "提交"
        }
    }
    var outcomeText: String { record?.latestShot?.resultText ?? "" }
    private func permitted(newQuestion: Bool = false) -> Bool {
        limiter.refreshDay()
        if !limiter.isPremium && (record?.configuration.freePractice == true || (newQuestion && limiter.isLimitReached)) {
            upgradeIntent = newQuestion ? .next : .strike
            needsSubscription = true; return false
        }
        if !newQuestion, let id = record?.current?.id,
           record?.presentation?.receipts[id] == nil, record?.presentation?.legacyConsumed.contains(id) != true,
           !limiter.reserve(questionID: id, admitted: true) {
            message = limiter.quotaError; return false
        }
        return true
    }
    func attach(context: ModelContext) {
        attach(repository: LocalKBallPracticeRepository(context: context))
    }
    func attach(repository: any KBallPracticeRepository) {
        guard self.repository == nil else { return }
        self.repository = repository
        do {
            record = try repository.resumable(is3D: initialView3D, compatible: { $0.canResumeCurrentTraining })
            let preferred = (defaults === UserDefaults.standard ? TablePreferencesStore.shared : TablePreferencesStore(defaults: defaults)).beginTraining(.kBall, source3D: record?.is3D ?? initialView3D)
            if record?.presentation == nil, record != nil {
                record?.presentation = .init(is3D: record?.is3D ?? preferred, legacyConsumed: Set(record?.consumed.keys.map { $0 } ?? []))
            }
            cameraMode = (record?.presentation?.current.is3D ?? preferred) ? .perspective3D : .topDown2D
            if let record { playsStroke = record.configuration.playsStroke }
            if let id = record?.current?.id, record?.presentation?.receipts[id] == nil,
               record?.presentation?.legacyConsumed.contains(id) != true { _ = limiter.reserve(questionID: id, admitted: true) }
            shotPoses = record.map { decodePoses($0.initialPoses) }
            if let record, !record.isCompatible {
                throw SeparationQuestionGenerator.Failure.incompatible
            }
            if var old = record, !old.canResumeCurrentTraining {
                accountForSavedAttempts()
                old.status = .ended
                try repository.save(old)
                record = nil; shotPoses = nil
                message = "训练题库已更新，旧练习已保留在历史中，请重新开始。"
            }
            phase = record == nil ? .settings : (record?.showingResult == true ? .result : .aiming)
            accountForSavedAttempts(); activeSince = Date()
        } catch { message = error.localizedDescription; phase = .settings }
    }
    func start(_ configuration: KBallConfiguration, prepared: KBallQuestionPreparer.Prepared) {
        guard let repository else { return }
        guard limiter.isPremium || (!configuration.freePractice && !limiter.isLimitReached) else {
            needsSubscription = true; return
        }
        discardNextQuestion()
        do {
            checkpointTime()

            let next = KBallPracticeRecord(ownerKey: repository.ownerKey, is3D: is3D,
                configuration: configuration, prepared: prepared)
            guard let id = next.current?.id, limiter.reserve(questionID: id, replacing: record?.current?.id) else {
                message = limiter.quotaError; needsSubscription = limiter.isLimitReached; return
            }
            var records = [next]
            if var old = record, old.status == .active { old.status = .ended; records.insert(old, at: 0) }
            do { try repository.saveAtomically(records) }
            catch {
                limiter.release(questionID: id)
                if let oldID = record?.current?.id { _ = limiter.reserve(questionID: oldID, admitted: true) }
                throw error
            }
            if let oldID = record?.current?.id { limiter.release(questionID: oldID) }
            invalidate(); record = next; playsStroke = configuration.playsStroke; phase = .aiming; solvedAim = nil
            shotPoses = nil; shotCamera = nil; activeSince = Date(); settingsReturnPhase = nil
            if builtScene { installQuestion() }
        } catch { message = error.localizedDescription }
    }
    func setupScene() {
        guard !builtScene else { resumeTeachingActivity(); return }
        teachingActive = true
        builtScene = true; scene.configureReferenceTableRendering()
        scene.configureShotAwareCamera()
        scene.setupScene(enhancedRendering: false); scene.setupVisualizationNodes()
        markers = scene.addPocketMarkers(); configureTeachingCamera(); installQuestion()
    }
    private func seatBalls() {
        guard let question = record?.current else { return }
        let y = scene.surfaceY + BallPhysics.radius
        scene.applyBallLayout(cueBallPosition: .init(question.board.cue.x, y, question.board.cue.z),
            targetBallNumber: question.ballNumber, targetPosition: .init(question.board.target.x, y, question.board.target.z))
        scene.showBall(key: "_8", scenePosition: .init(question.second.x, y, question.second.z))
        scene.configureBallInstances(["_\(question.ballNumber)", "_8"])
        scene.railInventory.clear()
        if let shotPoses { scene.restoreBallPoses(shotPoses) }
    }
    private func installQuestion() {
        guard let question = record?.current else { return }
        let referenceDraft = record?.geometricReference
        defer { if let referenceDraft { geometryReference.restore(referenceDraft); if phase == .result { geometryReference.complete() } } }
        scene.hideAllVisualization(); scene.setIdealObjectLine(nil); scene.setFreeAimPreviewLine(nil)
        seatBalls(); drawAimingGuides()
        if shotPoses == nil { shotPoses = scene.captureBallPoses() }
        record?.initialPoses = encodePoses(shotPoses ?? [:])
        _ = save()
        scene.setPracticePocketRoles(current: question.board.pocketIndex, next: nil)
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
                let prediction = try KBallQuestionPreparer.solve(layout: question.layout, question: question.source,
                    input: SeparationInput(), surfaceY: surface, profile: profile)
                // A neutral baseline remains useful even when it does not pot A or reach B.
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
                    $0.name = "kBall.reference"
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
                    self.notice = feedback
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
        actualNodes.forEach { $0.name = "kBall.actual" }
        guard showsObjectRoute else { return }
        scene.pocketLineNode?.isHidden = true
        scene.addDashedPolyline(points(record?.latestShot?.objectTrajectory ?? []),
            color: TrajectoryStyle.potColor(forNumber: record?.current?.ballNumber ?? 1),
            placement: .table, into: &objectNodes)
        objectNodes.forEach { $0.name = "kBall.objectActual" }
    }
    func prepareGeometryReference() {
        guard canAdjust, let question = record?.current else { return }
        let y = scene.surfaceY + BallPhysics.radius
        geometryReference.update(identity: question.id.uuidString,
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
        guard canAdjust, permitted(), let question = record?.current else { return }
        pendingPremium = limiter.isPremium
        prepareGeometryReference(); geometryReference.freeze()
        invalidate(preservingCue: true)
        let token = generation, frozen = input, surface = scene.surfaceY, animate = playsStroke
        shotPoses = scene.captureBallPoses(); shotCamera = ShotReplayCamera.capture(in: scene)
        record?.initialPoses = encodePoses(shotPoses ?? [:])
        checkpointTime(); activeSince = nil
        phase = .preparing; message = nil
        work = Task {
            let worker = Task.detached(priority: .userInitiated) { () throws -> KBallShot in
                let prediction = try KBallQuestionPreparer.solve(layout: question.layout, question: question.source, input: frozen,
                    surfaceY: surface, profile: AccuracyTipSelector.renderedProfile())
                return try KBallShot(question: question, input: frozen, prediction: prediction, surfaceY: surface)
            }
            do {
                let shot = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled, token == generation, question.id == record?.current?.id else { return }
                var submission = shot
                submission.playsStroke = animate
                submission.physical.presentation = .init(view: .init(is3D: is3D),
                    observed: record?.presentation?.observed[question.id] ?? [], premium: pendingPremium)
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
        next.geometricReference = geometryReference.snapshot
        next.presentation?.accept(questionID: pendingShot.questionID, at: pendingShot.submittedAt, premium: pendingPremium)
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
        catch LocalKBallPracticeRepository.Failure.oversizedRecord {
            self.pendingShot = nil; phase = .aiming; activeSince = Date()
            message = "本题的轨迹记录过大，请调整打点或力度后重试；尚未扣除题数。"; return
        }
        catch { phase = .saveFailed; message = "未能保存本杆，请重试保存；尚未扣除题数。"; return }
        record = next; self.pendingShot = nil; accountForSavedAttempts()
        refreshNextQuestion()
        if pendingShot.isTrajectoryOnly {
            scene.hideCueStick(); drawActual(); phase = .result; activeSince = Date()
            refreshObservationCameraContext()
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
    private func play(_ shot: KBallShot) {
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
            for (key, name) in [(PositionPlayBall.cueKey, ShotInput.cueBallName), (selectedTargetKey ?? "", ShotInput.targetBallName), ("_8", TwoBallQuestionPreparer.secondBallName)] {
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
            for (node, name) in [(self.scene.cueBallNode, ShotInput.cueBallName), (self.targetNode, ShotInput.targetBallName), (self.secondNode, TwoBallQuestionPreparer.secondBallName)] {
                if let node, let action = playback.action(for: node, ballName: name, removeOnPocket: false,
                                                          maxSimTime: playback.duration) { actions.append((node, action)) }
            }
            guard !actions.isEmpty else { self.completedPlayback(token); return }
            var remaining = actions.count
            for (node, action) in actions {
                node.runAction(action, forKey: "kBall.play") { [weak self] in
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
        _ = save()
    }
    func retry() {
        guard canRetry, permitted(), let shot = record?.latestShot else { return }
        invalidate(); record?.draftInput = shot.input; record?.showingResult = false
        solvedAim = shot.direction.vector; phase = .aiming
        seatBalls(); drawActual(showsObjectRoute: false)
        if let shotCamera { scene.restorePerspectiveView(shotCamera) }
        else if let saved = record?.shotBookmark, let cue = scene.cueBallNode?.position {
            scene.cameraRig?.restoreTrainingBookmark(saved, cue: cue, aim: shot.direction.vector)
        }
        redrawCue(); geometryReference.restore(); _ = save()
    }
    func replayLastShot() {
        guard canPlayback, let shot = record?.latestShot, let cue = scene.cueBallNode, let target = targetNode, let second = secondNode else { return }
        let state = (phase, BallDisplay(cue), BallDisplay(target), scene.railInventory.snapshot(), BallDisplay(second))
        invalidate(); replayReturn = state; replayCamera.begin(in: scene); isReplaying = true
        drawActual(); play(shot)
    }
    func stopPlayback() {
        guard isReplaying else { return }
        invalidate()
        if phase == .aiming { drawActual(showsObjectRoute: false); redrawCue() }
    }
    private func restoreReplay() {
        guard let state = replayReturn else { return }
        state.1.restore(scene.cueBallNode); state.2.restore(targetNode); state.4.restore(secondNode)
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
        guard record.configuration.freePractice || (record.questionNumber < 15 && record.totalProcessed < 15) else { return false }
        if !limiter.isPremium {
            guard !record.configuration.freePractice else { return false }
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
    func next() {
        guard phase == .result else { return }
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
    private func installNextQuestion(_ prepared: KBallQuestionPreparer.Prepared,
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
        var archived: KBallPracticeRecord?
        if segmentFull {
            archived = next; archived?.status = .completed; archived?.updatedAt = Date()
            next = next.continuation(prepared: prepared)
        } else { next.questions.append(prepared.question); next.cursor += 1 }
        next.resetInput(); next.seenContentIDs.insert(prepared.question.contentID)
        next.draftInput = .init()
        next.latestShot = nil; next.showingResult = false; next.updatedAt = Date()
        next.initialPoses = [:]; next.finalPoses = [:]
        next.viewBookmark = nil; next.shotBookmark = nil; next.geometricReference = nil
        guard let id = next.current?.id, limiter.reserve(questionID: id) else {
            throw TrainingQuotaLedger.Failure.unreadable
        }
        let view = next.presentation?.current ?? .init(is3D: is3D)
        next.presentation?.observe(view, questionID: id)
        do { try repository.saveAtomically(archived.map { [$0, next] } ?? [next]) }
        catch { limiter.release(questionID: id); throw error }
        discardNextQuestion()
        record = next; clearReference(); shotPoses = nil; shotCamera = nil; solvedAim = nil; installQuestion()
    }
    func finish() {
        guard !isBusy else { return }
        discardNextQuestion()
        checkpointTime()
        guard var next = record else { return }
        next.status = !next.configuration.freePractice && next.totalProcessed >= 15 ? .completed : .ended
        next.updatedAt = Date()
        do { try repository?.save(next); record = next; if let id = next.current?.id { limiter.release(questionID: id) }; invalidate(); phase = .summary; activeSince = nil }
        catch { message = error.localizedDescription }
    }
    func reviewLastQuestion() {
        if phase == .summary, record?.latestShot != nil { phase = .result; activeSince = Date() }
    }
    func restart() {
        limiter.refreshDay()
        guard limiter.isPremium || !limiter.isLimitReached else {
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
        for (node, name) in [(scene.cueBallNode, ShotInput.cueBallName), (targetNode, ShotInput.targetBallName), (secondNode, TwoBallQuestionPreparer.secondBallName)] {
            if let position = shot.finalPositions[name] { node?.position = position.value }
            node?.isHidden = shot.pocketedBalls.contains(name)
        }
        scene.hideCueStick()
        if let record, !record.finalPoses.isEmpty { scene.restoreBallPoses(decodePoses(record.finalPoses)) }
        // Rebuild the presentation-only pocket rails from the same capture facts.
        // A restored result must not lose the potted ball's visible return-rail resident.
        scene.railInventory.clear()
        if let recorder = shot.prediction().recorder, let railShot = scene.railInventory.beginShot(recorder: recorder) {
            for (node, name) in [(scene.cueBallNode, ShotInput.cueBallName), (targetNode, ShotInput.targetBallName), (secondNode, TwoBallQuestionPreparer.secondBallName)] {
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
        record?.geometricReference = geometryReference.snapshot
        guard let record, let repository else { return false }
        do { try repository.save(record); return true }
        catch { message = "未能保存练习，请稍后重试。"; return false }
    }
    private func scheduleSave() {
        draftSave?.cancel()
        draftSave = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            self?.save()
        }
    }
    private func accountForSavedAttempts() {
        for receipt in record?.presentation?.receipts.values ?? Dictionary<UUID, TrainingConsumptionReceipt>().values {
            if !limiter.reconcile(receipt) { message = limiter.quotaError }
        }
    }
    @discardableResult func switchTrainingView(to is3D: Bool) -> Bool {
        guard !isBusy, !isReplaying, !temporaryTopDownActive, !cameraTransitionBusy else { return false }
        geometryReference.endDrag()
        guard var next = record else { setCameraMode(is3D ? .perspective3D : .topDown2D); return true }
        if self.is3D { next.viewBookmark = scene.cameraRig?.trainingBookmark() }
        let questionID = next.current?.id
        let oldMode = next.presentation?.current ?? .init(is3D: self.is3D)
        next.presentation?.observe(oldMode, questionID: questionID)
        next.presentation?.current = .init(is3D: is3D)
        next.presentation?.observe(.init(is3D: is3D), questionID: questionID)
        next.updatedAt = Date()
        do { try repository?.save(next) } catch { message = error.localizedDescription; return false }
        record = next
        setCameraMode(is3D ? .perspective3D : .topDown2D)
        if is3D, let saved = next.viewBookmark, let cue = scene.cueBallNode?.position, let aim = currentPlayerAim {
            scene.cameraRig?.restoreTrainingBookmark(saved, cue: cue, aim: aim)
        }
        return true
    }
    func trainingObservedTopDown() {
        let id = record?.current?.id
        record?.presentation?.observe(.twoD, questionID: id)
        _ = save()
    }
    private func invalidate(preservingCue: Bool = false) {
        notice = nil
        generation = UUID(); work?.cancel(); work = nil; scene.frameReceipt.cancel()
        // Finish rail cancellation before taking SceneKit's lock: rail callbacks
        // hold their own state lock while updating nodes.
        if let state = replayReturn { scene.railInventory.restore(state.3) }
        // SceneKit can evaluate actions on its render thread. Cancel and restore
        // under the same transaction lock, without implicit position animations.
        SCNTransaction.lock()
        defer { SCNTransaction.unlock() }
        SCNTransaction.begin(); SCNTransaction.disableActions = true
        defer { SCNTransaction.commit() }
        scene.cueBallNode?.removeAllActions(); targetNode?.removeAllActions(); secondNode?.removeAllActions()
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
        prepareReference()
        if phase == .aiming { redrawCue() }
    }
    func layoutEditingChanged(_ editing: Bool) {
        if editing { _ = save(); activeSince = nil }
        else if phase == .aiming || phase == .result { activeSince = Date() }
    }
    func ownerChanged() {
        if let id = record?.current?.id { limiter.release(questionID: id) }
        discardNextQuestion()
        clearReference()
        invalidate(); draftSave?.cancel(); record = nil; pendingShot = nil; phase = .settings
        upgradeIntent = nil; shotPoses = nil; shotCamera = nil; solvedAim = nil
        clearActual()
        scene.hideAllVisualization()
        message = "账号已切换，请重新开始练习。"
    }
    func selectPocket(at index: Int) {}
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
