import SwiftUI
import SceneKit
import SwiftData

struct AccuracyPreparedRound {
    let fingerprint: String
    let questions: [AccuracyPracticeQuestion]
    var reusedPool = false
    var samplingNotice: String? = nil
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
            return try bank.draw(configuration, seed: seed, excluding: excluding, accepting: { board in
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
        let notice = batch.inaccessibleCombinations.isEmpty ? batch.distribution.notice
            : "部分组合未找到允许的可用打点，本轮已在所选条件内重新分配比例。"
        return .init(fingerprint: bank.sourceFingerprint, questions: questions,
                     reusedPool: reused, samplingNotice: notice)
    }
}

@MainActor
final class AccuracyPracticeViewModel: ObservableObject, TeachingTableHost {
    enum Phase { case loading, settings, aiming, computing, playing, result, saveFailed, summary }
    let is3D: Bool
    let scene = AngleTrainingScene()
    let limiter = AngleUsageLimiter.accuracyTraining
    @Published private(set) var record: AccuracyPracticeRecord?
    @Published private(set) var phase: Phase = .loading
    @Published var message: String?
    @Published var cameraMode: AngleTrainingScene.CameraMode
    @Published var cameraTransitionBusy = false
    @Published var temporaryTopDownActive = false
    @Published var topDownContentRevision = 0
    @Published var topDownSelectionChanged = false
    private var repository: LocalAccuracyPracticeRepository?
    private var builtScene = false
    private var pocketMarkers: [SCNNode] = []
    private var generation = UUID()
    private var calculation: Task<Void, Never>?
    private var cancellation: PredictionCancellation?
    private var draftSave: Task<Void, Never>?
    private var lastPrediction: ShotPrediction?
    @Published private(set) var isRetrying = false
    private var practiceAttempt: AccuracyPracticeAttempt?
    private var aimLine: SCNNode?
    var potRate: String {
        SceneTrainingMetrics.percentage(record?.successCount ?? 0, of: record?.validAttempts.count ?? 0)
    }
    private var settingsReturnPhase: Phase?

    init(is3D: Bool) {
        self.is3D = is3D
        cameraMode = is3D ? .perspective3D : .topDown2D
    }
    var route: String { is3D ? "accuracy3D" : "accuracy2D" }
    var preferencePage: TablePreferencePage { is3D ? .accuracy3D : .accuracy2D }
    var title: String { is3D ? "3D准度" : "2D准度" }
    var targetNode: SCNNode? { scene.targetBallNodes.first }
    var selectedPocketIndex: Int { record?.current?.board.pocketIndex ?? 0 }
    var selectedTargetKey: String? { record?.current.map { "_\($0.ballNumber)" } }
    var onTableKeys: [String] { [PositionPlayBall.cueKey] + [selectedTargetKey].compactMap { $0 } }
    var draggableBalls: [SCNNode] { [] }
    var selectableBalls: [SCNNode] { [] }
    var isDragging: Bool { false }
    var currentPlayerAim: SCNVector3? { record?.draftDirection.vector }
    var tip: AccuracyTip { record?.current?.fixedTip ?? .center }
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
    var shouldFinish: Bool {
        record.map { $0.status != .active || (!$0.configuration.freePractice && $0.validAttempts.count >= 20) } == true
            || (!is3D && limiter.isLimitReached)
    }
    var primaryTitle: String {
        switch phase {
        case .computing: "计算中"; case .playing: "击球中"; case .saveFailed: "重试保存"
        case .result: record?.currentAttempt?.result?.countsAsAttempt == true ? (shouldFinish ? "查看总结" : "下一题") : "重试"
        default: !isRetrying && !is3D && limiter.isLimitReached ? "解锁Pro" : "击球"
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
        guard let repository else { return }
        do {
            if var previous = record, previous.status == .active {
                previous.status = .ended; previous.endedAt = Date(); previous.updatedAt = Date()
                try repository.save(previous); record = previous; settingsReturnPhase = .summary
            }
            let next = try AccuracyPracticeRecord(ownerKey: repository.ownerKey, is3D: is3D,
                configuration: configuration, bankFingerprint: prepared.fingerprint, questions: prepared.questions)
            try repository.save(next)
            invalidate()
            record = next; lastPrediction = nil; isRetrying = false; practiceAttempt = nil; phase = .aiming; message = prepared.samplingNotice
            if builtScene { installQuestion() }
        } catch { message = error.localizedDescription }
    }
    func setupScene() {
        guard !builtScene else { installQuestion(); return }
        builtScene = true
        scene.configureReferenceTableRendering()
        if is3D { scene.configureShotAwareCamera() }
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
        for (index, marker) in pocketMarkers.enumerated() { scene.highlightPocket(marker, highlighted: index == selectedPocketIndex) }
        scene.confirmPocketSelection(at: selectedPocketIndex)
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
        scene.setFreeAimPreviewLine(nil)
        guard let target = targetNode else { return }
        let rail = AngleSceneCalculator.rayToInnerRail(from: cue.position, dir: aim)
        func point(_ v: SCNVector3) -> CGPoint { CGPoint(x: CGFloat(v.x), y: CGFloat(v.z)) }
        let resolution = AimLineGeometry.resolve(cue: point(cue.position), dir: point(aim),
            target: point(target.position), ballRadius: CGFloat(AngleSceneCalculator.ballRadius), railEnd: point(rail))
        let y = scene.surfaceY + BallPhysics.radius
        aimLine = scene.addLine(from: SCNVector3(cue.position.x, y, cue.position.z),
            to: SCNVector3(Float(resolution.lineEnd.x), y, Float(resolution.lineEnd.y)),
            color: TrajectoryStyle.TrainingAssist.aimLine, placement: .table)
        scene.updateCueStick(cueBallPosition: CueStroke.strikePosition(cue: cue.position, aim: aim,
            spinX: Double(tip.x), spinY: Double(tip.y)), aimDirection: aim)
    }
    func markObservation(_ name: String) {
        guard phase == .aiming, record?.observations.contains(name) == false else { return }
        record?.observations.insert(name); scheduleDraftSave()
    }
    func strike() {
        guard phase == .aiming || (phase == .result && record?.currentAttempt?.result?.countsAsAttempt != true),
              let question = record?.current, let repository else { return }
        guard usesCurrentBank() else { return }
        if isRetrying || record?.currentAttempt == nil {
            guard isRetrying || is3D || !limiter.isLimitReached else { return }
            guard let aim = currentPlayerAim, scene.permitsCueStrike(aim: aim, spinX: Double(tip.x), spinY: Double(tip.y)) else {
                message = "当前方向受库边或球遮挡，请调整瞄准方向。"; return
            }
        }
        do {
            guard var next = record else { return }
            if isRetrying {
                let attempt = try next.practiceAttempt()
                practiceAttempt = attempt
                calculate(question: question, attempt: attempt, replay: true)
                return
            }
            let attempt = try next.freezeAttempt()
            try repository.save(next) // Input is durable before calculation starts.
            record = next
            calculate(question: question, attempt: attempt, replay: false)
        } catch { message = error.localizedDescription }
    }
    private func calculate(question: AccuracyPracticeQuestion, attempt: AccuracyPracticeAttempt, replay: Bool) {
        invalidate()
        let token = generation, cancel = PredictionCancellation()
        cancellation = cancel; phase = .computing; message = nil
        calculation = Task {
            let result = await Task.detached(priority: .userInitiated) {
                ShotPredictor.simulateFree(cueBall: question.board.cue.vector, aimDir: attempt.direction.vector,
                    velocity: attempt.velocity, spinX: attempt.fixedTip.x, spinY: attempt.fixedTip.y, surfaceY: 0,
                    balls: [.init(name: ShotInput.targetBallName, position: question.board.target.vector)],
                    cancellation: cancel, recordedStrikeDirection: attempt.direction.vector)
            }.value
            guard !Task.isCancelled, generation == token, record?.current?.id == question.id else { return }
            calculation = nil; cancellation = nil
            lastPrediction = result
            let judged = AccuracyPracticeAttempt.Result(prediction: result, pocketIndex: question.board.pocketIndex)
            if replay { practiceAttempt?.result = judged }
            else {
                _ = record?.accept(judged, attemptID: attempt.id)
                guard save() else { phase = .saveFailed; return }
                accountForSavedAttempts()
            }
            guard result.hasFinalTableState else { phase = .result; message = "本杆计算未完成，可重试同一杆。"; return }
            play(result)
        }
    }
    private func play(_ prediction: ShotPrediction) {
        guard let question = record?.current, let attempt = practiceAttempt ?? record?.currentAttempt,
              let recorder = prediction.recorder else { phase = .result; return }
        installQuestion()
        phase = .playing
        aimLine?.removeFromParentNode()
        let token = generation
        scene.setFreeAimPreviewLine(nil); scene.hideAllVisualization()
        let y = scene.surfaceY + BallPhysics.radius
        scene.applyBallLayout(cueBallPosition: SCNVector3(question.board.cue.x, y, question.board.cue.z),
            targetBallNumber: question.ballNumber, targetPosition: SCNVector3(question.board.target.x, y, question.board.target.z))
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
                    self.phase = .result; self.scene.hideCueStick()
                    if self.shouldFinish && !self.isRetrying { self.finish() }
                }
            }]), forKey: "accuracy.clock")
        }
    }
    /// Restore the original layout; the persisted first attempt is never replaced.
    func retry() {
        guard phase == .result, record?.currentAttempt?.result?.countsAsAttempt == true else { return }
        invalidate(); isRetrying = true; practiceAttempt = nil; lastPrediction = nil
        if let attempt = record?.currentAttempt {
            record?.draftDirection = attempt.direction
            record?.draftVelocity = Double(attempt.velocity)
        }
        installQuestion()
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
            var samplingNotice: String?
            if next.cursor + 1 == next.questions.count {
                let prepared = try AccuracyPreparedRound.prepare(next.configuration, excluding: Set(next.questions.map { $0.board.id }))
                next.questions += prepared.questions
                reusedPool = prepared.reusedPool
                samplingNotice = prepared.samplingNotice
            }
            try next.advance()
            try repository?.save(next)
            invalidate(); record = next; lastPrediction = nil; isRetrying = false; practiceAttempt = nil
            message = reusedPool ? "当前条件下未练过的球形不足20题，已从当前题库重新抽取下一组。" : samplingNotice
            installQuestion()
        } catch { message = error.localizedDescription }
    }
    func finish() {
        guard !isBusy, var next = record else { return }
        next.status = !next.configuration.freePractice && next.validAttempts.count == 20 ? .completed : .ended
        next.endedAt = Date(); next.updatedAt = Date()
        do {
            try repository?.save(next); invalidate(); record = next; phase = .summary
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
        guard let record, let repository else { return false }
        do { try repository.save(record); return true }
        catch { message = error.localizedDescription; return false }
    }
    private func scheduleDraftSave() {
        draftSave?.cancel()
        draftSave = Task { try? await Task.sleep(for: .milliseconds(300)); guard !Task.isCancelled else { return }; save() }
    }
    private func accountForSavedAttempts() {
        guard !is3D else { return }
        for attempt in record?.validAttempts ?? [] { limiter.recordQuestion(attemptID: attempt.id, submittedAt: attempt.submittedAt) }
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
        generation = UUID(); cancellation?.cancel(); calculation?.cancel(); calculation = nil
        aimLine?.removeFromParentNode()
        scene.rootNode.removeAction(forKey: "accuracy.clock")
        scene.cueBallNode?.removeAction(forKey: "accuracy.play")
        targetNode?.removeAction(forKey: "accuracy.play")
        scene.hideCueStick(); ShotAudioScheduler.shared.cancel()
    }
    func suspendTeachingActivity() {
        invalidate(); _ = save()
        if phase == .playing || phase == .computing { phase = .result; showSavedFinalPositions() }
    }
    func resumeTeachingActivity() {
        if builtScene { scene.isPaused = false }
    }
    func ownerChanged() {
        invalidate(); draftSave?.cancel(); record = nil; lastPrediction = nil; isRetrying = false; practiceAttempt = nil; phase = .settings
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
