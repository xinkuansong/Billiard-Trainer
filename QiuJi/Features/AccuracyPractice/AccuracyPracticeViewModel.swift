import SwiftUI
import SceneKit
import SwiftData

struct AccuracyPreparedRound {
    let fingerprint: String
    let questions: [AccuracyPracticeQuestion]
    var reusedPool = false
    static func prepare(_ configuration: SceneTrainingConfiguration) throws -> Self {
        try prepare(configuration, excluding: [])
    }
    static func prepare(_ configuration: SceneTrainingConfiguration, excluding used: Set<String>,
                        seed: UInt64 = UInt64.random(in: 0...UInt64.max)) throws -> Self {
        let bank = try TrainingBankStore.load()
        let profile = AccuracyTipSelector.renderedProfile()
        var tips: [String: AccuracyTip] = [:]
        var random = SceneTrainingGenerator.SeededRandom(state: seed ^ 0xa0761d6478bd642f)
        func draw(excluding: Set<String>) throws -> TrainingGridBank.Draw {
            tips.removeAll()
            return try bank.draw(configuration, seed: seed, excluding: excluding, count: TrainingProject.ordinaryRoundCount, accepting: { board in
                guard let tip = AccuracyTipSelector.select(board: board, configuration: configuration,
                                                          profile: profile, random: &random) else { return false }
                tips[board.id] = tip
                return true
            })
        }
        let batch: TrainingGridBank.Draw
        var reused = false
        do { batch = try draw(excluding: used) }
        catch TrainingQuestionBank.Failure.coverage where !used.isEmpty {
            batch = try draw(excluding: [])
            reused = true
        }
        let questions = try batch.boards.map { board -> AccuracyPracticeQuestion in
            guard let tip = tips[board.id] else { throw TrainingQuestionBank.Failure.invalid("Missing feasible tip") }
            return .init(board: board, selectedTip: tip)
        }
        // Coverage is rebalanced within the selected conditions without interrupting practice.
        return .init(fingerprint: bank.sourceFingerprint, questions: questions,
                     reusedPool: reused)
    }
}

@MainActor
final class AccuracyPracticeViewModel: ObservableObject, TeachingTableHost {
    enum Phase { case loading, settings, aiming, computing, playing, result, saveFailed, summary }
    var is3D: Bool { cameraMode == .perspective3D }
    let scene = AngleTrainingScene()
    let limiter: AngleUsageLimiter
    private let initialView3D: Bool
    @Published private(set) var record: AccuracyPracticeRecord?
    @Published private(set) var phase: Phase = .loading
    @Published var message: String?
    @Published private(set) var notice: TrainingPracticeNotice?
    @Published var cameraMode: AngleTrainingScene.CameraMode
    @Published var cameraTransitionBusy = false
    @Published var temporaryTopDownActive = false
    @Published var topDownContentRevision = 0
    @Published var topDownSelectionChanged = false
    private var repository: LocalAccuracyPracticeRepository?
    private var builtScene = false
    private var pocketMarkers: [SCNNode] = []
    private var highlightedQuestionID: UUID?
    private var generation = UUID()
    private var calculation: Task<Void, Never>?
    private var cancellation: PredictionCancellation?
    private var draftSave: Task<Void, Never>?
    private(set) var lastPrediction: ShotPrediction?
    @Published private(set) var closeupSnapshot: AimCloseupSnapshot?
    private var closeupWasNear = false
    private struct RecordedShot {
        let questionID: UUID
        let attempt: AccuracyPracticeAttempt
        let prediction: ShotPrediction
        let poses: BallPoseSnapshot
        let camera: CameraRig.PerspectiveState?
    }
    private struct BallDisplay {
        let position: SCNVector3
        let orientation: simd_quatf
        let hidden: Bool
        let opacity: CGFloat
        init(_ node: SCNNode) {
            position = node.position; orientation = node.simdOrientation
            hidden = node.isHidden; opacity = node.opacity
        }
        func restore(_ node: SCNNode?) {
            node?.position = position
            if let node { BallSpinIntegrator.applyPose(node, orientation) }
            node?.isHidden = hidden; node?.opacity = opacity
        }
    }
    private var recordedShot: RecordedShot?
    private var replayReturn: (phase: Phase, cue: BallDisplay, target: BallDisplay, rails: PocketRailSnapshot)?
    private var replayCamera = ShotReplayCamera()
    @Published private(set) var isReplaying = false
    @Published private(set) var isRetrying = false
    private var practiceAttempt: AccuracyPracticeAttempt?
    private var aimLine: SCNNode?
    private var centerReferenceLine: SCNNode?
    var potRate: String {
        SceneTrainingMetrics.percentage(record?.successCount ?? 0, of: record?.validAttempts.count ?? 0)
    }
    private var settingsReturnPhase: Phase?

    init(is3D: Bool, limiter: AngleUsageLimiter = .accuracyTraining) {
        self.limiter = limiter; initialView3D = is3D
        cameraMode = is3D ? .perspective3D : .topDown2D
    }
    var route: String { is3D ? "accuracy3D" : "accuracy2D" }
    var preferencePage: TablePreferencePage { is3D ? .accuracy3D : .accuracy2D }
    var title: String { TrainingProject.accuracy.title }
    @discardableResult func switchTrainingView(to is3D: Bool) -> Bool {
        guard !isBusy, !temporaryTopDownActive, !cameraTransitionBusy, var next = record else { return false }
        if self.is3D { next.viewBookmark = scene.cameraRig?.trainingBookmark() }
        let questionID = next.current?.id
        if phase == .aiming { next.presentation?.observe(.init(is3D: self.is3D), questionID: questionID) }
        next.presentation?.current = .init(is3D: is3D)
        if phase == .aiming { next.presentation?.observe(.init(is3D: is3D), questionID: questionID) }
        next.updatedAt = Date()
        do { try repository?.save(next) }
        catch { message = error.localizedDescription; return false }
        record = next
        setCameraMode(is3D ? .perspective3D : .topDown2D)
        restoreViewBookmark()
        return true
    }
    var targetNode: SCNNode? { scene.targetBallNodes.first }
    var selectedPocketIndex: Int { record?.current?.board.pocketIndex ?? 0 }
    var selectedTargetKey: String? { record?.current.map { "_\($0.ballNumber)" } }
    var onTableKeys: [String] { [PositionPlayBall.cueKey] + [selectedTargetKey].compactMap { $0 } }
    var draggableBalls: [SCNNode] { [] }
    var selectableBalls: [SCNNode] { [] }
    var isDragging: Bool { false }
    var currentPlayerAim: SCNVector3? { record?.draftDirection.vector }
    var allowsVerticalSpinEditing: Bool { record?.configuration.allowsManualVerticalSpin == true }
    var allowsSideSpinEditing: Bool { record?.configuration.allowsManualSideSpin == true }
    var tip: AccuracyTip {
        if isReplaying, let shot = recordedShot { return shot.attempt.fixedTip }
        if phase != .aiming, let attempt = practiceAttempt ?? record?.currentAttempt { return attempt.fixedTip }
        return record?.currentTip ?? .center
    }
    var tipInstruction: String {
        let base = record?.current?.fixedTip ?? .center
        if allowsVerticalSpinEditing && allowsSideSpinEditing { return "打点可调" }
        if allowsVerticalSpinEditing {
            let fixed = base.x == 0 ? "无侧塞" : SpinDisplay.readout(spinX: Double(base.x), spinY: 0) + "固定"
            return "高低杆可调 · \(fixed)"
        }
        if allowsSideSpinEditing {
            let fixed = base.y == 0 ? "中杆" : SpinDisplay.readout(spinX: 0, spinY: Double(base.y)) + "固定"
            return "左右塞可调 · \(fixed)"
        }
        return "指定\(base.label)"
    }
    func updateSpin(_ x: Double, _ y: Double) {
        guard canAim, allowsVerticalSpinEditing || allowsSideSpinEditing,
              let requested = record?.constrainedTip(x: x, y: y),
              let access = scene.cueAccessSnapshot,
              let corrected = access.constrained(spinX: Double(requested.x), spinY: Double(requested.y),
                                                 allowSideAdjustment: allowsSideSpinEditing) else { return }
        // Clearance correction cannot override a prescribed axis.
        let base = record?.current?.fixedTip ?? .center
        guard allowsSideSpinEditing || corrected.x == Double(base.x),
              allowsVerticalSpinEditing || corrected.y == Double(base.y) else { return }
        record?.draftTip = .init(x: Float(corrected.x), y: Float(corrected.y),
                                raisedForClearance: requested.raisedForClearance)
        redrawAim(); scheduleDraftSave()
    }
    var velocity: Double {
        get { record?.draftVelocity ?? ShotTuning.defaultVelocity }
        set {
            guard phase == .aiming, newValue.isFinite else { return }
            record?.draftVelocity = min(ShotTuning.velocityRange.upperBound, max(ShotTuning.velocityRange.lowerBound, newValue))
            scheduleDraftSave()
        }
    }
    var isBusy: Bool { phase == .computing || phase == .playing || phase == .saveFailed }
    var canAim: Bool { phase == .aiming && !temporaryTopDownActive && !cameraTransitionBusy }
    var canRetry: Bool {
        phase == .result && record?.currentAttempt?.result?.countsAsAttempt == true
            && !temporaryTopDownActive && !cameraTransitionBusy
    }
    var canPlayback: Bool {
        (phase == .aiming || phase == .result) && recordedShot?.questionID == record?.current?.id
            && recordedShot != nil && !temporaryTopDownActive && !cameraTransitionBusy
    }
    var shouldFinish: Bool {
        record.map { $0.status != .active || (!$0.configuration.freePractice && $0.validAttempts.count >= TrainingProject.ordinaryRoundCount) } == true
            || limiter.isLimitReached
    }
    var primaryTitle: String {
        if isReplaying { return "停止" }
        return switch phase {
        case .computing: "计算中"; case .playing: "击球中"; case .saveFailed: "重试保存"
        case .result: record?.currentAttempt?.result?.countsAsAttempt == true ? (shouldFinish ? "查看总结" : "下一题") : "重试"
        default: "击球"
        }
    }
    var outcomeText: String {
        guard let result = (isRetrying ? practiceAttempt : record?.currentAttempt)?.result else { return "" }
        switch result.outcome {
        case .success: return "完成：指定袋进球"
        case .missed: return "未进指定袋"
        case .wrongPocket: return "进错袋口"
        case .scratch: return "母球落袋"
        case .indirect: return "本题需要直接进袋"
        case .technicalFailure: return "本杆计算未完成，未计入成绩"
        }
    }
    func attach(context: ModelContext) {
        guard repository == nil else { return }
        repository = LocalAccuracyPracticeRepository(context: context)
        do {
            record = try repository?.resumable(is3D: is3D)
            let preferred = TablePreferencesStore.shared.beginTraining(.accuracy, source3D: record?.is3D ?? initialView3D)
            cameraMode = preferred ? .perspective3D : .topDown2D
            if var restored = record {
                if restored.presentation == nil {
                    restored.presentation = .init(is3D: restored.is3D, legacyConsumed: Set(restored.validAttempts.map(\.questionID)))
                }
                record = restored
                cameraMode = restored.presentation?.current.is3D == true ? .perspective3D : .topDown2D
                if let id = restored.current?.id, restored.currentAttempt?.result?.countsAsAttempt != true {
                    guard limiter.reserve(questionID: id, admitted: true) else { phase = .settings; message = limiter.quotaError; return }
                }
            }
            phase = record == nil ? .settings : (record?.currentAttempt == nil ? .aiming : .result)
            if let record, record.bankFingerprint != (try TrainingBankStore.load()).sourceFingerprint,
               record.currentAttempt?.result?.countsAsAttempt != true {
                phase = .settings
                message = "练习题库已更新，旧记录已保留，请重新开始。"
            }
            if record?.current?.exactTip == nil, phase == .aiming {
                phase = .settings
                message = "出题打点规则已更新，旧成绩已保留，请重新开始练习。"
            }
            accountForSavedAttempts()
        } catch { message = error.localizedDescription; phase = .settings }
    }
    func start(_ configuration: SceneTrainingConfiguration, prepared: AccuracyPreparedRound) {
        guard let repository, let first = prepared.questions.first,
              limiter.isPremium || !configuration.freePractice,
              limiter.reserve(questionID: first.id, replacing: record?.current?.id) else { message = limiter.quotaError ?? "今日题量已用完，可查看已完成的练习。"; return }
        do {
            let next = try AccuracyPracticeRecord(ownerKey: repository.ownerKey, is3D: is3D,
                configuration: configuration, bankFingerprint: prepared.fingerprint, questions: prepared.questions)
            var records = [next]
            if var previous = record, previous.status == .active {
                previous.status = .ended; previous.endedAt = Date(); previous.updatedAt = Date()
                records.insert(previous, at: 0)
            }
            do { try repository.saveAtomically(records) }
            catch {
                limiter.release(questionID: first.id)
                if let id = record?.current?.id { _ = limiter.reserve(questionID: id, admitted: true) }
                throw error
            }
            if let id = record?.current?.id { limiter.release(questionID: id) }
            invalidate()
            record = next; lastPrediction = nil; recordedShot = nil; isRetrying = false; practiceAttempt = nil; phase = .aiming; message = nil
            if builtScene { installQuestion() }
        } catch { message = error.localizedDescription }
    }
    func setupScene() {
        // A new SwiftUI host (for example after cancelling settings) must not
        // reinstall the question or replace the restored business phase.
        guard !builtScene else { resumeTeachingActivity(); return }
        builtScene = true
        scene.configureReferenceTableRendering()
        scene.configureShotAwareCamera()
        scene.setupScene(enhancedRendering: false)
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()
        configureTeachingCamera()
        installQuestion()
    }
    private func installQuestion() {
        guard let question = record?.current else { return }
        if question.exactTip == nil, record?.currentAttempt == nil {
            phase = .settings
            message = "出题打点规则已更新，旧成绩已保留，请重新开始练习。"
            return
        }
        scene.hideAllVisualization(); scene.setIdealObjectLine(nil)
        scene.setFreeAimPreviewLine(nil); scene.railInventory.clear()
        let y = scene.surfaceY + BallPhysics.radius
        scene.applyBallLayout(cueBallPosition: SCNVector3(question.board.cue.x, y, question.board.cue.z),
            targetBallNumber: question.ballNumber, targetPosition: SCNVector3(question.board.target.x, y, question.board.target.z))
        for (index, marker) in pocketMarkers.enumerated() {
            scene.setPocketHighlight(marker, style: index == selectedPocketIndex ? .selected : .viable, confirmsSelection: false)
        }
        if highlightedQuestionID != question.id {
            highlightedQuestionID = question.id
            scene.confirmPocketSelection(at: selectedPocketIndex)
        }
        topDownContentRevision += 1
        if isRetrying { phase = .aiming; redrawAim() }
        else if record?.currentAttempt?.result?.countsAsAttempt == true {
            showSavedFinalPositions(); phase = .result
        } else if record?.currentAttempt != nil {
            phase = .result
            if record?.currentAttempt?.result == nil {
                let questionID = question.id
                Task { @MainActor in
                    guard self.record?.current?.id == questionID, self.phase == .result else { return }
                    self.strike()
                }
            }
        } else { phase = .aiming; redrawAim() }
        refreshObservationCameraContext()
        if is3D && phase == .aiming { requestPlayerView(.thirdPerson, animated: false) }
        restoreViewBookmark()
    }
    private func restoreViewBookmark() {
        if is3D, let bookmark = record?.viewBookmark, let cue = scene.cueBallNode?.position,
           let aim = currentPlayerAim {
            scene.cameraRig?.restoreTrainingBookmark(bookmark, cue: cue, aim: aim)
        }
    }
    func nudgeAim(_ degrees: Float) {
        guard canAim, degrees.isFinite, let current = record?.draftDirection else { return }
        let moved = current.vector.rotatedY(degrees * .pi / 180)
        let norm = hypot(moved.x, moved.z)
        record?.draftDirection = .init(SCNVector3(moved.x / norm, 0, moved.z / norm))
        redrawAim(); scheduleDraftSave()
        if is3D { requestPlayerView(scene.cameraRig?.twoViewMode ?? .thirdPerson, animated: false) }
    }
    private func redrawAim() {
        guard phase == .aiming, let cue = scene.cueBallNode, let aim = currentPlayerAim else { return }
        scene.hideAllVisualization(); scene.setIdealObjectLine(nil)
        aimLine?.removeFromParentNode()
        centerReferenceLine?.removeFromParentNode()
        scene.setFreeAimPreviewLine(nil)
        guard let target = targetNode else { return }
        let rail = AngleSceneCalculator.rayToInnerRail(from: cue.position, dir: aim)
        func point(_ v: SCNVector3) -> CGPoint { CGPoint(x: CGFloat(v.x), y: CGFloat(v.z)) }
        let resolution = AimLineGeometry.resolve(cue: point(cue.position), dir: point(aim),
            target: point(target.position), ballRadius: CGFloat(AngleSceneCalculator.ballRadius), railEnd: point(rail))
        let closeup = AimCloseupBuilder.currentAim(cue: point(cue.position), direction: point(aim),
            target: point(target.position), number: record?.current?.ballNumber,
            ballRadius: CGFloat(BallPhysics.radius), railEnd: point(rail), previouslyNear: closeupWasNear)
        closeupWasNear = closeup.isNear
        closeupSnapshot = closeup.snapshot
        let y = scene.surfaceY + BallPhysics.radius
        centerReferenceLine = scene.addLine(from: SCNVector3(cue.position.x, y, cue.position.z),
            to: SCNVector3(target.position.x, y, target.position.z),
            color: TrajectoryStyle.TrainingAssist.centerReference, radius: 0.001, placement: .table, layer: .reference)
        centerReferenceLine?.name = "accuracy.centerReferenceLine"
        aimLine = scene.addLine(from: SCNVector3(cue.position.x, y, cue.position.z),
            to: SCNVector3(Float(resolution.lineEnd.x), y, Float(resolution.lineEnd.y)),
            color: TrajectoryStyle.TrainingAssist.aimLine, placement: .table)
        aimLine?.name = "accuracy.aimLine"
        scene.updateCueStick(cueBallPosition: CueStroke.strikePosition(cue: cue.position, aim: aim,
            spinX: Double(tip.x), spinY: Double(tip.y)), aimDirection: aim)
    }
    func trainingObservedTopDown() { markObservation("topDown") }
    func markObservation(_ name: String) {
        guard phase == .aiming, record?.observations.contains(name) == false else { return }
        record?.observations.insert(name)
        if name == "topDown" { let id = record?.current?.id; record?.presentation?.observe(.twoD, questionID: id) }
        scheduleDraftSave()
    }
    func strike() {
        guard phase == .aiming || (phase == .result && record?.currentAttempt?.result?.countsAsAttempt != true),
              let question = record?.current, let repository else { return }
        guard usesCurrentBank() else { return }
        if isRetrying || record?.currentAttempt == nil {
            guard isRetrying || limiter.reserve(questionID: question.id, admitted: true) else { message = limiter.quotaError; return }
            guard let aim = currentPlayerAim, scene.permitsCueStrike(aim: aim, spinX: Double(tip.x), spinY: Double(tip.y)) else {
                notice = .init(text: "当前方向受库边或球遮挡，请调整瞄准方向。"); return
            }
        }
        do {
            guard var next = record else { return }
            if isRetrying {
                let attempt = try next.practiceAttempt()
                practiceAttempt = attempt
                calculate(question: question, attempt: attempt, isPractice: true)
                return
            }
            var attempt = try next.freezeAttempt()
            if attempt.wasPremium == nil {
                attempt.wasPremium = limiter.isPremium
                attempt.presentation = .init(view: .init(is3D: is3D), observed: next.presentation?.observed[question.id] ?? [], premium: limiter.isPremium)
                if let index = next.attempts.firstIndex(where: { $0.id == attempt.id }) { next.attempts[index] = attempt }
                next.presentation?.observe(.init(is3D: is3D), questionID: question.id)
                next.presentation?.submitted[question.id] = .init(is3D: is3D)
            }
            try repository.save(next) // Input is durable before calculation starts.
            record = next
            calculate(question: question, attempt: attempt, isPractice: false)
        } catch { message = error.localizedDescription }
    }
    private func calculate(question: AccuracyPracticeQuestion, attempt: AccuracyPracticeAttempt, isPractice: Bool) {
        invalidate()
        let poses = scene.captureBallPoses(), camera = ShotReplayCamera.capture(in: scene)
        // Both planar motion and pocket descent use the displayed table's world height.
        let surfaceY = scene.surfaceY
        let token = generation, cancel = PredictionCancellation()
        cancellation = cancel; phase = .computing; message = nil
        calculation = Task {
            let result = await Task.detached(priority: .userInitiated) {
                ShotPredictor.simulateFree(cueBall: question.board.cue.vector, aimDir: attempt.direction.vector,
                    velocity: attempt.velocity, spinX: attempt.fixedTip.x, spinY: attempt.fixedTip.y, surfaceY: surfaceY,
                    balls: [.init(name: ShotInput.targetBallName, position: question.board.target.vector)],
                    cancellation: cancel, recordedStrikeDirection: attempt.direction.vector)
            }.value
            guard !Task.isCancelled, generation == token, record?.current?.id == question.id else { return }
            calculation = nil; cancellation = nil
            lastPrediction = result
            let judged = AccuracyPracticeAttempt.Result(prediction: result, pocketIndex: question.board.pocketIndex)
            if result.hasFinalTableState, result.recorder != nil {
                recordedShot = .init(questionID: question.id, attempt: attempt, prediction: result, poses: poses, camera: camera)
            }
            if isPractice { practiceAttempt?.result = judged }
            else {
                _ = record?.accept(judged, attemptID: attempt.id)
                if judged.countsAsAttempt {
                    record?.presentation?.accept(questionID: question.id, at: Date(), premium: attempt.wasPremium ?? true)
                }
                guard save() else { phase = .saveFailed; return }
                accountForSavedAttempts()
            }
            guard result.hasFinalTableState else { phase = .result; message = "本杆计算未完成，可重试同一杆。"; return }
            play(result)
        }
    }
    private func play(_ prediction: ShotPrediction, replaying shot: RecordedShot? = nil) {
        guard let question = record?.current, let attempt = shot?.attempt ?? practiceAttempt ?? record?.currentAttempt,
              let recorder = prediction.recorder else { phase = .result; return }
        if shot == nil { installQuestion() }
        phase = .playing
        aimLine?.removeFromParentNode()
        centerReferenceLine?.removeFromParentNode()
        let token = generation
        scene.setFreeAimPreviewLine(nil); scene.hideAllVisualization()
        let y = scene.surfaceY + BallPhysics.radius
        scene.applyBallLayout(cueBallPosition: SCNVector3(question.board.cue.x, y, question.board.cue.z),
            targetBallNumber: question.ballNumber, targetPosition: SCNVector3(question.board.target.x, y, question.board.target.z))
        scene.railInventory.clear()
        if let context = shot ?? recordedShot { scene.restoreBallPoses(context.poses) }
        if let shot { replayCamera.showShot(shot.camera, in: scene, aim: attempt.direction.vector) }
        else if let camera = recordedShot?.camera { scene.restorePerspectiveView(camera) }
        guard let cue = scene.cueBallNode else { phase = .result; return }
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: y, railInventory: scene.railInventory)
        let strike = CueStroke.strikePosition(cue: cue.position, aim: attempt.direction.vector,
            spinX: Double(attempt.fixedTip.x), spinY: Double(attempt.fixedTip.y))
        scene.updateCueStick(cueBallPosition: strike, aimDirection: attempt.direction.vector)
        scene.runCueStroke(strikePosition: strike, aim: attempt.direction.vector, velocity: attempt.velocity,
            rehearsalEnabled: false, clearanceProbe: { playback.allBallCentersByName(at: Float($0)) }) { [weak self] in
            guard let self, self.generation == token, self.phase == .playing else { return }
            var duration: TimeInterval = 0
            for (node, name) in [(self.scene.cueBallNode, ShotInput.cueBallName), (self.targetNode, ShotInput.targetBallName)] {
                guard let node, let action = playback.action(for: node, ballName: name, removeOnPocket: false,
                    maxSimTime: playback.duration) else { continue }
                duration = max(duration, action.duration); node.runAction(action, forKey: "accuracy.play")
            }
            ShotAudioScheduler.shared.play(prediction: prediction)
            self.scene.rootNode.runAction(.sequence([.wait(duration: duration + 0.2), .run { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    if self.isReplaying { self.stopPlayback(); return }
                    // Keep the final answer available for review/retry. The
                    // explicit primary action opens the summary via next().
                    self.phase = .result; self.scene.hideCueStick()
                }
            }]), forKey: "accuracy.clock")
        }
    }
    /// Restore the original layout with the most recent strike's aim, power and tip.
    /// The persisted first attempt remains the scoring source.
    func retry() {
        guard canRetry else { return }
        let previousAttempt = practiceAttempt ?? record?.currentAttempt
        invalidate(); isRetrying = true; practiceAttempt = nil; lastPrediction = nil
        if let attempt = previousAttempt {
            record?.draftDirection = attempt.direction
            record?.draftVelocity = Double(attempt.velocity)
            record?.draftTip = attempt.fixedTip
        }
        installQuestion()
    }
    /// Replay the recorded trajectory without submitting, judging or saving another attempt.
    func replayLastShot() {
        guard canPlayback, let shot = recordedShot,
              let cue = scene.cueBallNode, let target = targetNode else { return }
        let state = (phase: phase, cue: BallDisplay(cue), target: BallDisplay(target), rails: scene.railInventory.snapshot())
        invalidate()
        replayReturn = state
        replayCamera.begin(in: scene)
        isReplaying = true
        play(shot.prediction, replaying: shot)
    }
    func stopPlayback() {
        guard isReplaying else { return }
        invalidate()
        if phase == .aiming { redrawAim() }
    }
    private func restoreReplay() {
        guard let state = replayReturn else { return }
        state.cue.restore(scene.cueBallNode); state.target.restore(targetNode)
        scene.railInventory.restore(state.rails)
        replayCamera.finish(in: scene)
        replayReturn = nil; isReplaying = false; phase = state.phase
    }
    func retrySave() {
        guard phase == .saveFailed, save() else { return }
        accountForSavedAttempts()
        if let lastPrediction, lastPrediction.hasFinalTableState { play(lastPrediction) }
        else { phase = .result }
    }
    func next() {
        guard phase == .result, record?.currentAttempt?.result?.countsAsAttempt == true else { return }
        guard usesCurrentBank() else { finish(); return }
        if shouldFinish { finish(); return }
        do {
            guard var next = record else { return }
            var reusedPool = false
            if next.cursor + 1 == next.questions.count {
                let prepared = try AccuracyPreparedRound.prepare(next.configuration, excluding: Set(next.questions.map { $0.board.id }))
                next.questions += prepared.questions
                reusedPool = prepared.reusedPool
            }
            try next.advance()
            guard let questionID = next.current?.id, limiter.isPremium || !next.configuration.freePractice,
                  limiter.reserve(questionID: questionID) else { message = limiter.quotaError ?? "今日题量已用完，请查看本轮总结。"; return }
            do { try repository?.save(next) }
            catch { limiter.release(questionID: questionID); throw error }
            invalidate(); record = next; lastPrediction = nil; recordedShot = nil; isRetrying = false; practiceAttempt = nil
            notice = reusedPool ? .init(text: "已从当前题库重新抽取下一组") : nil
            installQuestion()
        } catch { message = error.localizedDescription }
    }
    func finish() {
        guard !isBusy, var next = record else { return }
        next.status = !next.configuration.freePractice && next.validAttempts.count >= TrainingProject.ordinaryRoundCount ? .completed : .ended
        next.endedAt = Date(); next.updatedAt = Date()
        do {
            try repository?.save(next)
            if next.currentAttempt?.result?.countsAsAttempt != true, let id = next.current?.id { limiter.release(questionID: id) }
            invalidate(); record = next; phase = .summary
        } catch { message = error.localizedDescription }
    }
    func reviewLastQuestion() {
        guard phase == .summary, record?.currentAttempt?.result?.countsAsAttempt == true else { return }
        phase = .result
    }
    func openSettings() {
        guard !isBusy else { return }
        settingsReturnPhase = record == nil ? nil : phase
        phase = .settings
    }
    @discardableResult func cancelSettings() -> Bool {
        guard let previous = settingsReturnPhase else { return false }
        phase = previous; settingsReturnPhase = nil
        return true
    }
    private func showSavedFinalPositions() {
        scene.setFreeAimPreviewLine(nil); scene.hideCueStick()
        guard let result = record?.currentAttempt?.result else { return }
        for (node, name) in [(scene.cueBallNode, ShotInput.cueBallName), (targetNode, ShotInput.targetBallName)] {
            if let point = result.finalPositions[name] { node?.position = SCNVector3(point.x, scene.surfaceY + BallPhysics.radius, point.z) }
            node?.isHidden = result.pocketedBalls.contains(name)
        }
    }
    @discardableResult private func save() -> Bool {
        draftSave?.cancel()
        if is3D, !temporaryTopDownActive { record?.viewBookmark = scene.cameraRig?.trainingBookmark() }
        guard let record, let repository else { return false }
        do { try repository.save(record); return true }
        catch { message = error.localizedDescription; return false }
    }
    private func scheduleDraftSave() {
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
    private func usesCurrentBank() -> Bool {
        do {
            guard record?.bankFingerprint == (try TrainingBankStore.load()).sourceFingerprint else {
                message = "练习题库已更新，已保存的成绩不会改算。请重新开始练习。"
                return false
            }
            return true
        } catch { message = error.localizedDescription; return false }
    }
    private func invalidate() {
        notice = nil
        generation = UUID(); cancellation?.cancel(); calculation?.cancel(); calculation = nil
        closeupSnapshot = nil; closeupWasNear = false
        aimLine?.removeFromParentNode()
        centerReferenceLine?.removeFromParentNode()
        scene.rootNode.removeAction(forKey: "accuracy.clock")
        scene.cueBallNode?.removeAction(forKey: "accuracy.play")
        targetNode?.removeAction(forKey: "accuracy.play")
        scene.hideCueStick(); ShotAudioScheduler.shared.cancel()
        restoreReplay()
    }
    func suspendTeachingActivity() {
        scene.cancelPocketSelectionFeedback()
        invalidate(); _ = save()
        if phase == .playing || phase == .computing { phase = .result; showSavedFinalPositions() }
    }
    func resumeTeachingActivity() {
        guard builtScene else { return }
        scene.isPaused = false
        // Suspension removes transient aim visuals, not the question/draft.
        // Results and summaries retain their displayed table and business phase.
        if phase == .aiming { redrawAim() }
    }
    func ownerChanged() {
        if let id = record?.current?.id { limiter.release(questionID: id) }
        invalidate(); draftSave?.cancel(); record = nil; lastPrediction = nil; recordedShot = nil; isRetrying = false; practiceAttempt = nil; phase = .settings
        message = "账号已切换，请重新开始练习。"
    }
    // Question ownership excludes all editor operations.
    func selectPocket(at index: Int) {}
    func selectTarget(key: String) {}
    func placeFromPalette(_ key: String) {}
    func palettePlacement(_ key: String, atWorld world: SCNVector3) -> SCNVector3? { nil }
    func removeFromTable(_ key: String) {}
    func dragBegan(node: SCNNode) {}
    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {}
    func dragEnded(node: SCNNode) {}
}
