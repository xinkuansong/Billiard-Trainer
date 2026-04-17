import Foundation
import SwiftData
import SwiftUI
import SceneKit

@MainActor
final class SceneAngleViewModel: ObservableObject {

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
    }

    enum PracticeMode: String, CaseIterable, Identifiable {
        case twentyQuestions = "20 题模式"
        case freePractice = "自由练习"
        var id: String { rawValue }
    }

    // MARK: - Published state

    @Published var currentQuestion: AngleQuestion?
    @Published var userInput: String = ""
    @Published var questionIndex: Int = 0
    @Published var showResult: Bool = false
    @Published var testFinished: Bool = false
    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2D
    @Published var selectedPocketIndex: Int = -1
    @Published var trainingType: TrainingType = .random
    @Published var practiceMode: PracticeMode = .twentyQuestions
    @Published var showSettings: Bool = false

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
    private var cueBallNode: SCNNode?
    private var targetBallNode: SCNNode?
    private var pocketMarkers: [SCNNode] = []
    private var resultNodes: [SCNNode] = []

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

    func setupScene() {
        scene.setupScene()
        pocketMarkers = scene.addPocketMarkers()
        startTest()
    }

    // MARK: - Test lifecycle

    func startTest() {
        questionIndex = 0
        sessionResults = []
        testFinished = false
        showResult = false
        userInput = ""
        nextQuestion()
    }

    func submitAnswer() {
        guard let q = currentQuestion,
              let userAngle = Double(userInput),
              userAngle >= 0, userAngle <= 90 else { return }

        let err = abs(q.actualAngle - userAngle)
        sessionResults.append(AnswerRecord(question: q, userAngle: userAngle, error: err))

        engine.recordResult(angle: q.actualAngle, error: err, pocketType: q.pocketType)
        limiter.recordQuestion()

        let quizType = cameraMode == .topDown2D ? "scene2D" : "scene3D"
        Task {
            let result = AngleTestResult(
                actualAngle: q.actualAngle,
                userAngle: userAngle,
                pocketType: q.pocketType.rawValue,
                quizType: quizType
            )
            try? await repository?.save(result)
        }

        showResultVisualization()
        showResult = true
    }

    func advanceToNext() {
        questionIndex += 1
        nextQuestion()
    }

    // MARK: - Camera

    func toggleCameraMode() {
        let newMode: AngleTrainingScene.CameraMode = cameraMode == .topDown2D ? .perspective3D : .topDown2D
        cameraMode = newMode
        scene.setCameraMode(newMode, animated: true)
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

        let pt: PocketType
        if let filter = trainingType.pocketFilter {
            pt = filter
        } else {
            pt = engine.selectPocketType()
        }

        let range = trainingType.angleRange
        let angle = Double(Int.random(in: Int(range.lowerBound)...Int(range.upperBound)) / 5 * 5)
        let clampedAngle = max(range.lowerBound, min(range.upperBound, angle == 0 ? 5 : angle))
        let question = AngleCalculator.generateQuestion(angle: clampedAngle, pocketType: pt)
        currentQuestion = question

        let surfaceY = scene.surfaceY

        // Remove old balls
        if let old = cueBallNode { scene.removeBall(old) }
        if let old = targetBallNode { scene.removeBall(old) }

        // Place new balls
        let targetPos = AngleSceneCalculator.normalizedToScene(point: question.targetBall, surfaceY: surfaceY)
        let cuePos = AngleSceneCalculator.normalizedToScene(point: question.cueBall, surfaceY: surfaceY)

        targetBallNode = scene.addBall(at: targetPos, color: UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1))
        cueBallNode = scene.addBall(at: cuePos, color: .white)

        // Highlight target pocket
        let pocketIndex = pocketIndexFor(question.pocket)
        selectedPocketIndex = pocketIndex
        for (i, marker) in pocketMarkers.enumerated() {
            scene.highlightPocket(marker, highlighted: i == pocketIndex)
        }

        showResult = false
        userInput = ""
    }

    private func showResultVisualization() {
        guard let q = currentQuestion else { return }
        let surfaceY = scene.surfaceY
        let targetPos = AngleSceneCalculator.normalizedToScene(point: q.targetBall, surfaceY: surfaceY)
        let pocketPos = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: q.pocket.x, y: q.pocket.y), surfaceY: surfaceY
        )

        // Correct path: target → pocket (green line)
        let correctLine = scene.addLine(from: targetPos, to: pocketPos,
                                        color: UIColor.systemGreen, radius: 0.004)
        resultNodes.append(correctLine)

        // Ghost ball (translucent yellow)
        let ghostPos = AngleSceneCalculator.ghostBallPosition(
            targetBall: targetPos, pocket: pocketPos, ballRadius: AngleSceneCalculator.ballRadius
        )
        let ghostNode = scene.addBall(at: ghostPos, color: UIColor.yellow.withAlphaComponent(0.3))
        resultNodes.append(ghostNode)

        // Aiming line: cue → ghost (blue translucent)
        if let cuePos = cueBallNode?.position {
            let aimLine = scene.addLine(from: cuePos, to: ghostPos,
                                        color: UIColor.cyan.withAlphaComponent(0.5), radius: 0.003)
            resultNodes.append(aimLine)

            // Contact point (red dot)
            let dx = cuePos.x - targetPos.x
            let dz = cuePos.z - targetPos.z
            let dist = sqrtf(dx * dx + dz * dz)
            if dist > 0.001 {
                let contactX = targetPos.x + AngleSceneCalculator.ballRadius * (dx / dist)
                let contactZ = targetPos.z + AngleSceneCalculator.ballRadius * (dz / dist)
                let contactPos = SCNVector3(contactX, surfaceY + AngleSceneCalculator.ballRadius, contactZ)
                let contactNode = scene.addBall(at: contactPos, color: .red, radius: 0.008)
                resultNodes.append(contactNode)
            }
        }
    }

    private func clearResult() {
        scene.clearResultNodes(nodes: &resultNodes)
    }

    private func pocketIndexFor(_ pocket: PocketPosition) -> Int {
        let allPockets = AngleCalculator.pockets
        return allPockets.firstIndex(where: { $0.label == pocket.label }) ?? 0
    }
}
