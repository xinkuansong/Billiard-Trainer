import Foundation
import SwiftData
import SwiftUI

@MainActor
final class AngleTestViewModel: ObservableObject {

    // MARK: - Published state

    @Published var currentQuestion: AngleQuestion?
    @Published var userInput: String = ""
    @Published var questionIndex: Int = 0
    @Published var showResult: Bool = false
    @Published var testFinished: Bool = false

    let totalQuestions = 20

    /// Every answered question in this session.
    @Published private(set) var sessionResults: [AnswerRecord] = []

    struct AnswerRecord {
        let question: AngleQuestion
        let userAngle: Double
        let error: Double
    }

    // MARK: - Dependencies

    let engine  = AdaptiveQuestionEngine()
    let limiter: AngleUsageLimiter
    private var repository: AngleTestRepositoryProtocol?

    // MARK: - Init

    init(limiter: AngleUsageLimiter) {
        self.limiter = limiter
    }

    func configure(context: ModelContext) {
        repository = LocalAngleTestRepository(context: context)
    }

    // MARK: - Test lifecycle

    func startTest() {
        questionIndex   = 0
        sessionResults  = []
        testFinished    = false
        showResult      = false
        userInput       = ""
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

        Task {
            let result = AngleTestResult(actualAngle: q.actualAngle,
                                         userAngle: userAngle,
                                         pocketType: q.pocketType.rawValue)
            try? await repository?.save(result)
        }

        showResult = true
    }

    func advanceToNext() {
        questionIndex += 1
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
        if e <= 3  { return .accurate }
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
        guard questionIndex < totalQuestions, !limiter.isLimitReached else {
            testFinished = true
            return
        }
        let pt = engine.selectPocketType()
        let angle = engine.selectAngle(for: pt)
        currentQuestion = AngleCalculator.generateQuestion(angle: angle, pocketType: pt)
        showResult = false
        userInput  = ""
    }
}
