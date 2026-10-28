import Foundation
import SwiftData
import SwiftUI
import SceneKit

@MainActor
final class AimingQuizViewModel: TeachingCameraHost {

    // MARK: - Published state

    /// High-level quiz phase. The 2D aiming quiz uses this to decide whether to show
    /// the bottom action bar (`observing`) or the answer modal (`inputting` / `showingResult`).
    enum QuizPhase {
        case observing
        case inputting
        case showingResult
    }

    @Published var phase: QuizPhase = .observing
    @Published var currentQuestion: AngleQuestion?
    @Published var userInput: String = "" { didSet { saveDraft() } }
    @Published var questionIndex: Int = 0
    @Published var showResult: Bool = false
    @Published var testFinished: Bool = false
    @Published var selectedPocketIndex: Int = -1
    @Published var run = SceneTrainingRun()
    @Published var generationError: String?
    @Published var lastRecord: AnswerRecord?
    @Published var showSettings: Bool = false
    @Published var showAimingAssist: Bool = false
    /// 当前题目标球号（条 6.2：随机球号，避免只会看 8 号）。
    @Published private(set) var targetBallNumber: Int = 8

    var totalQuestions: Int { run.configuration.freePractice ? Int.max : TrainingProject.ordinaryRoundCount }
    var isFreePractice: Bool { run.configuration.freePractice }

    @Published private(set) var sessionResults: [AnswerRecord] = []
    /// 落库失败的可见错误态（nil = 无错误）。禁止静默丢题。
    @Published private(set) var saveErrorMessage: String?
    /// 落库失败但已保留的成绩，供重试；用户答案始终留在 `sessionResults`。
    @Published private(set) var unsavedResults: [AngleTestResult] = []

    struct AnswerRecord {
        let question: AngleQuestion
        let userAngle: Double
        let error: Double
    }

    // MARK: - Scene

    let scene = AngleTrainingScene()
    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2D
    @Published var cameraTransitionBusy = false
    @Published var temporaryTopDownActive = false
    @Published var topDownContentRevision = 0
    var topDownSelectionChanged = false
    var targetNode: SCNNode? { scene.targetBallNodes.first }
    var currentPlayerAim: SCNVector3? {
        guard let cue = scene.cueBallNode, let target = targetNode,
              !cue.isHidden, !target.isHidden, selectedPocketIndex >= 0 else { return nil }
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target.position, pocketIndex: selectedPocketIndex, surfaceY: scene.surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target.position,
            pocket: pocket, ballRadius: AngleSceneCalculator.ballRadius)
        let direction = SCNVector3(ghost.x - cue.position.x, 0, ghost.z - cue.position.z)
        return direction.length() > 0.000001 ? direction.normalized() : nil
    }
    private var pocketMarkers: [SCNNode] = []
    private var resultNodes: [SCNNode] = []

    /// Set by the owning view to tag results as "scene2D" or "scene3D"
    var quizTypeLabel: String = "scene2D"

    // MARK: - Dependencies

    let engine = AdaptiveQuestionEngine()
    let limiter: AngleUsageLimiter
    private var repository: AngleTestRepositoryProtocol?
    #if DEBUG
    var mergeDiagnostic: String {
        let payload: [String: Any] = ["session": run.id.uuidString, "question": run.current?.id.uuidString ?? "",
            "phase": String(describing: phase), "view": cameraMode == .perspective3D ? "3D" : "2D",
            "used": limiter.questionsUsedToday, "answers": run.firstAnswers.count,
            "input": userInput]
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
    #endif
    private var persistence: SceneTrainingPersistence?
    private var restoringCheckpoint = false
    @Published private(set) var presentation = TrainingPresentation(is3D: false)
    @Published private(set) var isSaving = false
    var hasSavedSession: Bool { persistence?.current?.run.current != nil }
    var canAdvance: Bool { !isSaving && unsavedResults.isEmpty }


    init(limiter: AngleUsageLimiter, initial3D: Bool? = nil) {
        self.limiter = limiter
        if let initial3D {
            cameraMode = TablePreferencesStore.shared.beginTraining(.angle, source3D: initial3D) ? .perspective3D : .topDown2D
        }
    }

    func configure(context: ModelContext) {
        repository = LocalAngleTestRepository(context: context)
        do { persistence = try SceneTrainingPersistence(project: .angle, owner: CurrentOwnerContext.shared.ownerKey) }
        catch { saveErrorMessage = error.localizedDescription }
    }

    /// 直接注入仓储（测试用失败仓储覆盖保存失败路径）。
    func configure(repository: AngleTestRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Setup

    /// Build the SceneKit scene used by the quiz.
    /// - Parameters:
    ///   - initialCameraMode: starting camera mode (top-down 2D vs perspective 3D).
    ///   - enhanced: opt into the studio-look pipeline (programmatic IBL,
    ///     ground shadow catcher, 4-light, HDR camera, material enhancers).
    ///     Defaults to `false` so the 2D aiming page keeps its current
    ///     cheap pipeline.
    ///   - autoStart: when `false`, the scene is built but no question is
    ///     generated — the owning view presents the training-settings sheet
    ///     first and calls `startTest()` itself (T-P18-48 entry flow).
    func setupScene(initialCameraMode: AngleTrainingScene.CameraMode,
                    enhanced: Bool = false,
                    mobileRendering: Bool = MobileTableRendering.isEnabled,
                    autoStart: Bool = true) {
        // Both training routes share the teaching diagram and cue presentation.
        // Projection changes the camera only, never the answer/assist content.
        cameraMode = initialCameraMode
        scene.usesAdaptiveDiagramLabels = true
        scene.configureShotAwareCamera()
        scene.setupScene(enhancedRendering: enhanced, mobileRendering: mobileRendering)
        scene.setupVisualizationNodes(usesTrainingAssistStyle: true)
        pocketMarkers = scene.addPocketMarkers()

        configureTeachingCamera()
        scene.setCameraMode(initialCameraMode, animated: false)
        if autoStart { startTest() }
    }

    // MARK: - Test lifecycle

    func startTest(configuration: SceneTrainingConfiguration = .init(), questions: [SceneTrainingQuestion] = []) {
        guard canAdvance, limiter.isPremium || !configuration.freePractice else { return }
        nextQuestion(starting: SceneTrainingRun(configuration: configuration, queue: questions))
    }

    /// Transition: observing → inputting (open answer modal).
    func openAnswerInput() {
        guard phase == .observing, currentQuestion != nil else { return }
        phase = .inputting; saveDraft()
    }

    /// Transition: inputting → observing (cancel modal without submitting).
    func cancelAnswerInput() {
        guard phase == .inputting else { return }
        userInput = ""
        phase = .observing; saveDraft()
    }

    func toggleAimingAssist() {
        defer { saveDraft() }
        guard phase == .observing, currentQuestion != nil else { return }
        showAimingAssist.toggle()
        if showAimingAssist { run.assistance.insert("graphical") }
        topDownContentRevision &+= 1
        if showAimingAssist {
            showAimingAssistVisualization()
        } else {
            scene.hideAllVisualization()
            scene.hideCueStick()
        }
    }

    func submitAnswer() {
        guard phase == .inputting, !run.submitted, !isSaving,
              let q = currentQuestion, let questionID = run.current?.id,
              let userAngle = Double(userInput), (0...90).contains(userAngle),
              limiter.reserve(questionID: questionID, admitted: true) else { return }
        let err = abs(q.actualAngle - userAngle)
        let answer = AnswerRecord(question: q, userAngle: userAngle, error: err)
        var nextRun = run, nextPresentation = presentation
        nextPresentation.current = .init(is3D: cameraMode == .perspective3D)
        nextPresentation.accept(questionID: questionID, at: Date(), premium: limiter.isPremium)
        var metadata = run.metadata(unit: "degrees")
        metadata?.project = .angle; metadata?.view = nextPresentation.current
        metadata?.observedViews = nextPresentation.observed[questionID]
        metadata?.receipt = nextPresentation.receipts[questionID]
        nextRun.record(error: err, signedError: userAngle - q.actualAngle, angle: q.actualAngle)
        let result = AngleTestResult(actualAngle: q.actualAngle, userAngle: userAngle,
            pocketType: q.pocketType.rawValue, quizType: cameraMode == .perspective3D ? "scene3D" : "scene2D",
            ownerKey: CurrentOwnerContext.shared.ownerKey)
        result.trainingMetadataJSON = metadata?.json
        do { try persistence?.save(run: nextRun, presentation: nextPresentation,
            targetNumber: targetBallNumber, input: userInput, accepting: SavedTrainingAnswer(result)) }
        catch { saveErrorMessage = error.localizedDescription; return }
        run = nextRun; presentation = nextPresentation; lastRecord = answer; sessionResults.append(answer)
        if persistence != nil, let receipt = metadata?.receipt { _ = limiter.reconcile(receipt) }
        BTFeedback.quiz(errorDegrees: err)
        showResultVisualization(); showResult = true; phase = .showingResult
        isSaving = true
        Task { await persist(result) }
    }

    /// 重试此前失败的落库；失败仍会重新置错误态。
    func retryFailedSaves() {
        let pending = unsavedResults
        guard !pending.isEmpty else { return }
        unsavedResults = []
        saveErrorMessage = nil; isSaving = true
        Task {
            for result in pending { await persist(result) }
        }
    }

    private func persist(_ result: AngleTestResult) async {
        defer { isSaving = false }
        guard let repository else { return }
        let owner = result.ownerKey
        do {
            try await repository.save(result)
            guard owner == CurrentOwnerContext.shared.ownerKey else { return }
            if let receipt = result.trainingMetadata?.receipt { _ = limiter.reconcile(receipt) }
            try persistence?.acknowledge(result.id)
            unsavedResults.removeAll { $0.id == result.id }; saveErrorMessage = nil
        } catch {
            guard owner == CurrentOwnerContext.shared.ownerKey else { return }
            if !unsavedResults.contains(where: { $0.id == result.id }) { unsavedResults.append(result) }
            saveErrorMessage = AngleResultSaveFailure.message(error)
        }
    }

    /// Transition: showingResult → observing (close modal, advance to next question).
    func advanceToNext() {
        guard phase == .showingResult, canAdvance else { return }
        questionIndex = run.firstAnswers.count
        phase = .observing
        nextQuestion()
    }

    // MARK: - Derived state

    var lastError: Double? { lastRecord?.error }

    var averageError: Double {
        guard !sessionResults.isEmpty else { return 0 }
        return sessionResults.map(\.error).reduce(0, +) / Double(sessionResults.count)
    }

    var accurateCount: Int { sessionResults.filter { $0.error <= 3 }.count }

    var errorRating: ErrorRating {
        guard let e = lastError else { return .accurate }
        if e <= 3 { return .accurate }
        if e <= 10 { return .close }
        return .off
    }

    enum ErrorRating {
        case accurate, close, off
        var label: String {
            switch self { case .accurate: "接近标准"; case .close: "有偏差"; case .off: "偏差较大" }
        }
        var color: Color {
            switch self { case .accurate: .btSuccess; case .close: .btWarning; case .off: .btDestructive }
        }
    }

    // MARK: - Private

    func nextQuestion(starting newRun: SceneTrainingRun? = nil) {
        guard canAdvance else { return }
        var next = newRun ?? run
        guard !next.canFinish, !limiter.isLimitReached, limiter.isPremium || !next.configuration.freePractice else {
            if newRun == nil { finish() }; return
        }
        do {
            let question = try next.next(), number = Int.random(in: 1...15)
            guard let id = next.current?.id, limiter.reserve(questionID: id, replacing: newRun == nil ? nil : run.current?.id) else { generationError = limiter.quotaError ?? "今日题量已用完"; return }
            var installed = false
            defer {
                if !installed {
                    limiter.release(questionID: id)
                    if newRun != nil, let oldID = run.current?.id { _ = limiter.reserve(questionID: oldID, admitted: true) }
                }
            }
            var views = newRun == nil ? presentation : TrainingPresentation(is3D: cameraMode == .perspective3D)
            let mode = views.current; views.observe(mode, questionID: id)
            try persistence?.save(run: next, presentation: views, targetNumber: number)
            if newRun != nil { sessionResults = []; lastRecord = nil }
            installed = true
            run = next; presentation = views; questionIndex = next.firstAnswers.count
            generationError = nil; testFinished = false; endTemporaryTopDown()
            installQuestion(question, number: number)
        } catch { generationError = error.localizedDescription }
    }

    private func installQuestion(_ question: AngleQuestion, number: Int) {
        topDownContentRevision &+= 1; clearResult(); scene.hideCueStick(); showAimingAssist = false
        currentQuestion = question
        let surfaceY = scene.surfaceY
        let targetPos = AngleSceneCalculator.normalizedToScene(point: question.targetBall, surfaceY: surfaceY)
        let cuePos = AngleSceneCalculator.normalizedToScene(point: question.cueBall, surfaceY: surfaceY)

        // 条 6.2：随机球号；applyBallLayout 同步 currentTargetNumber，
        // 进球线取色随球号绑定（修「进球线成默认色」bug 根因：取色依据未更新）。
        targetBallNumber = number
        #if DEBUG || RENDER_QUALITY_VALIDATION
        if RenderQualityFixture.requested { targetBallNumber = 3 }
        #endif
        scene.applyBallLayout(cueBallPosition: cuePos, targetBallNumber: targetBallNumber,
                              targetPosition: targetPos)
        #if DEBUG || RENDER_QUALITY_VALIDATION
        if RenderQualityFixture.requested {
            scene.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)))
        }
        #endif

        // The question carries its `pocketIndex` already aligned with
        // `AngleSceneCalculator.pocketPositions` (set by `AngleCalculator`),
        // so no label-based lookup is needed.
        selectedPocketIndex = question.pocketIndex
        for (i, marker) in pocketMarkers.enumerated() {
            scene.setPocketHighlight(marker, style: i == question.pocketIndex ? .selected : .viable,
                                     confirmsSelection: false)
        }
        // A new question is an event even when its pocket matches the previous one.
        scene.confirmPocketSelection(at: question.pocketIndex)

        showResult = false
        userInput = ""
        phase = .observing
    }


    func markObservation() {
        if phase == .observing && cameraMode == .perspective3D { run.assistance.insert("observation"); saveDraft() }
    }

    func finish() {
        guard canAdvance else { return }
        endTemporaryTopDown(); testFinished = true; saveDraft()
        if !run.submitted, let id = run.current?.id { limiter.release(questionID: id) }
    }

    func saveDraft() {
        guard !restoringCheckpoint, run.current != nil, let persistence else { return }
        do { try persistence.save(run: run, presentation: presentation, targetNumber: targetBallNumber,
            input: userInput, finished: testFinished, inputPhase: String(describing: phase), hintVisible: showAimingAssist) }
        catch { saveErrorMessage = error.localizedDescription }
    }
    @discardableResult func switchTrainingView(to is3D: Bool) -> Bool {
        guard !isSaving, !cameraTransitionBusy, !temporaryTopDownActive else { return false }
        if phase == .inputting { phase = .observing }
        var next = presentation
        next.observe(.init(is3D: cameraMode == .perspective3D), questionID: run.current?.id)
        next.current = .init(is3D: is3D); let mode = next.current; next.observe(mode, questionID: run.current?.id)
        do { try persistence?.save(run: run, presentation: next, targetNumber: targetBallNumber, input: userInput, finished: testFinished, inputPhase: String(describing: phase), hintVisible: showAimingAssist) }
        catch { saveErrorMessage = error.localizedDescription; return false }
        presentation = next; quizTypeLabel = is3D ? "scene3D" : "scene2D"
        setCameraMode(is3D ? .perspective3D : .topDown2D); refreshVisualization()
        return true
    }
    func observeTemporaryView() {
        presentation.observe(.twoD, questionID: run.current?.id); saveDraft()
    }
    func restoreSession() {
        guard let saved = persistence?.current, let question = saved.run.current?.geometry else { return }
        restoringCheckpoint = true
        defer { restoringCheckpoint = false }
        // installQuestion resets transient controls; restore the durable run afterwards.
        installQuestion(question, number: saved.targetNumber)
        run = saved.run; presentation = saved.presentation
        userInput = saved.input; questionIndex = run.firstAnswers.count - (run.submitted ? 1 : 0)
        sessionResults = saved.answers.compactMap { value in
            value.question.map { .init(question: $0, userAngle: value.answer, error: abs(value.actual - value.answer)) }
        }
        lastRecord = sessionResults.last
        setCameraMode(presentation.current.is3D ? .perspective3D : .topDown2D)
        quizTypeLabel = presentation.current.is3D ? "scene3D" : "scene2D"
        testFinished = saved.finished; showResult = run.submitted
        phase = run.submitted ? .showingResult : (saved.inputPhase == "inputting" ? .inputting : .observing)
        showAimingAssist = saved.hintVisible ?? false
        if run.submitted { showResultVisualization() }
        else if let id = run.current?.id { _ = limiter.reserve(questionID: id, admitted: true) }
        for receipt in presentation.receipts.values { _ = limiter.reconcile(receipt) }
        unsavedResults = saved.pending.map(\.result); retryFailedSaves()
    }
    func ownerChanged() {
        if let id = run.current?.id { limiter.release(questionID: id) }
        persistence = nil; run = .init(); currentQuestion = nil; sessionResults = []; lastRecord = nil
        unsavedResults = []; showSettings = true; testFinished = false; clearResult(); scene.hideAllVisualization()
    }

    private func showAimingAssistVisualization() {
        guard let q = currentQuestion,
              let cueBall = scene.cueBallNode else { return }
        let surfaceY = scene.surfaceY
        let targetPos = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: surfaceY)
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: targetPos,
            pocketIndex: q.pocketIndex,
            surfaceY: surfaceY
        )
        // 辅助档（T-P18-48）：瞄准线 / 进球线 / 假想球 / 接触点 / 90° 分离角
        // 短虚线全部走 §1.2 统一语言；仅隐藏数值角弧（数值即答案）。
        scene.updateVisualization(
            cueBall: cueBall.position,
            targetBall: targetPos,
            pocket: aimPoint,
            showAngleAnnotations: false,
            showOverlapMarkers: true,
            showLineLabels: true,
            extendStrikeLineToRail: true
        )
        scene.showAuxiliaryCue()
    }

    private func showResultVisualization() {
        guard let q = currentQuestion else { return }
        topDownContentRevision &+= 1
        showAimingAssist = false
        let surfaceY = scene.surfaceY
        let targetPos = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: surfaceY)
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: targetPos,
            pocketIndex: q.pocketIndex,
            surfaceY: surfaceY
        )

        if let cueBall = scene.cueBallNode {
            let cuePos = cueBall.position
            scene.updateVisualization(
                cueBall: cuePos,
                targetBall: targetPos,
                pocket: aimPoint,
                showLineLabels: true
            )
            scene.showAuxiliaryCue()
        }
    }

    /// Re-issue the currently-displayed visualization. Called when the user
    /// toggles 2D ⇄ 3D so the line-label suppression flag updates.
    func refreshVisualization() {
        if showAimingAssist {
            showAimingAssistVisualization()
        } else if showResult {
            showResultVisualization()
        }
    }

    private func clearResult() {
        scene.hideCueStick()
        scene.clearResultNodes(nodes: &resultNodes)
        scene.hideAllVisualization()
    }
}
