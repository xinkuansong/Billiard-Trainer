import Foundation
import SwiftData
import SwiftUI
import SceneKit

@MainActor
final class AimingQuizViewModel: ObservableObject {

    // MARK: - Training Types

    enum TrainingType: String, CaseIterable, Identifiable {
        case random = "随机模式"
        case nearStraight = "近台直球"
        case nearSmallAngle = "近台小角度"
        case midStraight = "中台直球"
        case midSmallAngle = "中台小角度"
        case farMedium = "远台中角度"
        case farLarge = "远台大角度"
        case sidePocket = "中袋专项"
        case cornerPocket = "角袋专项"

        var id: String { rawValue }

        var pocketFilter: PocketType? {
            switch self {
            case .sidePocket: return .side
            case .cornerPocket: return .corner
            default: return nil
            }
        }

        var angleRange: ClosedRange<Double> {
            switch self {
            case .random: return 5...85
            case .nearStraight, .midStraight: return 5...20
            case .nearSmallAngle, .midSmallAngle: return 15...40
            case .farMedium: return 25...55
            case .farLarge: return 45...80
            case .sidePocket: return 15...60
            case .cornerPocket: return 5...85
            }
        }

        /// Target ball → pocket distance range in normalised table-length units.
        /// 1.0 means one full table length (2.54m). These ranges make "近台 / 中台 / 远台"
        /// materially affect question generation instead of only changing angle range.
        var targetPocketDistanceRange: ClosedRange<Double> {
            switch self {
            case .nearStraight, .nearSmallAngle:
                return 0.12...0.28
            case .midStraight, .midSmallAngle:
                return 0.28...0.45
            case .farMedium, .farLarge:
                return 0.45...0.65
            case .random, .sidePocket, .cornerPocket:
                return 0.12...0.65
            }
        }
    }

    enum PracticeMode: String, CaseIterable, Identifiable {
        case twentyQuestions = "20 题模式"
        case freePractice = "自由练习"
        var id: String { rawValue }
    }

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
    @Published var userInput: String = ""
    @Published var questionIndex: Int = 0
    @Published var showResult: Bool = false
    @Published var testFinished: Bool = false
    @Published var selectedPocketIndex: Int = -1
    @Published var trainingType: TrainingType = .random
    @Published var practiceMode: PracticeMode = .twentyQuestions
    @Published var showSettings: Bool = false
    @Published var showAimingAssist: Bool = false
    /// 当前题目标球号（条 6.2：随机球号，避免只会看 8 号）。
    @Published private(set) var targetBallNumber: Int = 8

    var totalQuestions: Int { practiceMode == .twentyQuestions ? 20 : Int.max }
    var isFreePractice: Bool { practiceMode == .freePractice }

    @Published private(set) var sessionResults: [AnswerRecord] = []

    struct AnswerRecord {
        let question: AngleQuestion
        let userAngle: Double
        let error: Double
    }

    // MARK: - Scene

    let scene = AngleTrainingScene()
    private var pocketMarkers: [SCNNode] = []
    private var resultNodes: [SCNNode] = []

    /// Set by the owning view to tag results as "scene2D" or "scene3D"
    var quizTypeLabel: String = "scene2D"

    // MARK: - Dependencies

    let engine = AdaptiveQuestionEngine()
    let limiter: AngleUsageLimiter
    private var repository: AngleTestRepositoryProtocol?

    init(limiter: AngleUsageLimiter) {
        self.limiter = limiter
    }

    func configure(context: ModelContext) {
        repository = LocalAngleTestRepository(context: context)
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
                    autoStart: Bool = true) {
        scene.setupScene(enhancedRendering: enhanced)
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()

        scene.setCameraMode(initialCameraMode, animated: false)
        if autoStart { startTest() }
    }

    // MARK: - Test lifecycle

    func startTest() {
        questionIndex = 0
        sessionResults = []
        testFinished = false
        showResult = false
        userInput = ""
        phase = .observing
        nextQuestion()
    }

    /// Transition: observing → inputting (open answer modal).
    func openAnswerInput() {
        guard phase == .observing, currentQuestion != nil else { return }
        userInput = ""
        phase = .inputting
    }

    /// Transition: inputting → observing (cancel modal without submitting).
    func cancelAnswerInput() {
        guard phase == .inputting else { return }
        userInput = ""
        phase = .observing
    }

    func toggleAimingAssist() {
        guard phase == .observing, currentQuestion != nil else { return }
        showAimingAssist.toggle()
        if showAimingAssist {
            showAimingAssistVisualization()
        } else {
            scene.hideAllVisualization()
        }
    }

    func submitAnswer() {
        guard let q = currentQuestion,
              let userAngle = Double(userInput),
              userAngle >= 0, userAngle <= 90 else { return }

        let err = abs(q.actualAngle - userAngle)
        sessionResults.append(AnswerRecord(question: q, userAngle: userAngle, error: err))

        engine.recordResult(angle: q.actualAngle, error: err, pocketType: q.pocketType)
        limiter.recordQuestion()

        Task {
            let result = AngleTestResult(
                actualAngle: q.actualAngle,
                userAngle: userAngle,
                pocketType: q.pocketType.rawValue,
                quizType: quizTypeLabel
            )
            try? await repository?.save(result)
        }

        showResultVisualization()
        showResult = true
        phase = .showingResult
    }

    /// Transition: showingResult → observing (close modal, advance to next question).
    func advanceToNext() {
        questionIndex += 1
        phase = .observing
        nextQuestion()
    }

    // MARK: - Derived state

    var lastError: Double? { sessionResults.last?.error }

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
            switch self { case .accurate: "精准"; case .close: "接近"; case .off: "偏差较大" }
        }
        var color: Color {
            switch self { case .accurate: .btSuccess; case .close: .btWarning; case .off: .btDestructive }
        }
    }

    // MARK: - Private

    private func nextQuestion() {
        let limit = isFreePractice ? Int.max : totalQuestions
        guard questionIndex < limit, !limiter.isLimitReached else {
            testFinished = !isFreePractice
            return
        }

        clearResult()
        scene.hideCueStick()
        showAimingAssist = false

        let pt = trainingType.pocketFilter

        let range = trainingType.angleRange
        let angle = Double(Int.random(in: Int(range.lowerBound)...Int(range.upperBound)) / 5 * 5)
        let clampedAngle = max(range.lowerBound, min(range.upperBound, angle == 0 ? 5 : angle))
        let question = AngleCalculator.generateQuestion(
            angle: clampedAngle,
            pocketType: pt,
            targetPocketDistanceRange: trainingType.targetPocketDistanceRange
        )
        currentQuestion = question

        let surfaceY = scene.surfaceY
        let targetPos = AngleSceneCalculator.normalizedToScene(point: question.targetBall, surfaceY: surfaceY)
        let cuePos = AngleSceneCalculator.normalizedToScene(point: question.cueBall, surfaceY: surfaceY)

        // 条 6.2：随机球号；applyBallLayout 同步 currentTargetNumber，
        // 进球线取色随球号绑定（修「进球线成默认色」bug 根因：取色依据未更新）。
        targetBallNumber = Int.random(in: 1...15)
        scene.applyBallLayout(cueBallPosition: cuePos, targetBallNumber: targetBallNumber,
                              targetPosition: targetPos)

        // The question carries its `pocketIndex` already aligned with
        // `AngleSceneCalculator.pocketPositions` (set by `AngleCalculator`),
        // so no label-based lookup is needed.
        selectedPocketIndex = question.pocketIndex
        for (i, marker) in pocketMarkers.enumerated() {
            scene.highlightPocket(marker, highlighted: i == question.pocketIndex)
        }

        showResult = false
        userInput = ""
        phase = .observing
    }

    /// Inline 瞄准线 / 进球线 text labels lie flat on the cloth — readable
    /// in the 2D rotated top-down view but illegible in 3D perspective.
    /// Hide them when the scene is currently rendering in `.perspective3D`.
    private var shouldShowLineLabels: Bool {
        scene.currentCameraMode != .perspective3D
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
            showLineLabels: shouldShowLineLabels
        )
        scene.hideCueStick()
    }

    private func showResultVisualization() {
        guard let q = currentQuestion else { return }
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
                showLineLabels: shouldShowLineLabels
            )
            scene.hideCueStick()
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
        scene.clearResultNodes(nodes: &resultNodes)
        scene.hideAllVisualization()
    }
}
