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

    func setupScene(initialCameraMode: AngleTrainingScene.CameraMode) {
        scene.setupScene()
        scene.setupVisualizationNodes()
        pocketMarkers = scene.addPocketMarkers()

        scene.setCameraMode(initialCameraMode, animated: false)
        startTest()
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

        scene.applyBallLayout(cueBallPosition: cuePos, targetBallNumber: 8, targetPosition: targetPos)

        let pocketIndex = pocketIndexFor(question.pocket)
        selectedPocketIndex = pocketIndex
        for (i, marker) in pocketMarkers.enumerated() {
            scene.highlightPocket(marker, highlighted: i == pocketIndex)
        }

        showResult = false
        userInput = ""
        phase = .observing
    }

    private func showAimingAssistVisualization() {
        guard let q = currentQuestion,
              let cueBall = scene.cueBallNode else { return }
        let surfaceY = scene.surfaceY
        let targetPos = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: surfaceY)
        let pocketIndex = pocketIndexFor(q.pocket)
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: targetPos,
            pocketIndex: pocketIndex,
            surfaceY: surfaceY
        )
        scene.updateVisualization(
            cueBall: cueBall.position,
            targetBall: targetPos,
            pocket: aimPoint,
            showAngleAnnotations: false
        )
        scene.hideCueStick()
    }

    private func showResultVisualization() {
        guard let q = currentQuestion else { return }
        showAimingAssist = false
        let surfaceY = scene.surfaceY
        let targetPos = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: surfaceY)
        let pocketIndex = pocketIndexFor(q.pocket)
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: targetPos,
            pocketIndex: pocketIndex,
            surfaceY: surfaceY
        )

        if let cueBall = scene.cueBallNode {
            let cuePos = cueBall.position
            scene.updateVisualization(
                cueBall: cuePos,
                targetBall: targetPos,
                pocket: aimPoint
            )
            scene.hideCueStick()
        }
    }

    private func clearResult() {
        scene.clearResultNodes(nodes: &resultNodes)
        scene.hideAllVisualization()
    }

    private func pocketIndexFor(_ pocket: PocketPosition) -> Int {
        let allPockets = AngleCalculator.pockets
        return allPockets.firstIndex(where: { $0.label == pocket.label }) ?? 0
    }
}
