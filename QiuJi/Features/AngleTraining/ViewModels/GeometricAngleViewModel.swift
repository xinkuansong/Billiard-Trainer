import Foundation
import SwiftData
import SwiftUI

@MainActor
final class GeometricAngleViewModel: ObservableObject {

    // MARK: - Published state

    @Published var currentAngle: Double = 0
    @Published var userInput: String = ""
    @Published var showResult: Bool = false
    @Published var showReferenceGrid: Bool = false
    @Published private(set) var sessionResults: [AnswerRecord] = []

    struct AnswerRecord {
        let actualAngle: Double
        let userAngle: Double
        let error: Double
    }

    // MARK: - Dependencies

    let limiter: AngleUsageLimiter
    private var repository: AngleTestRepositoryProtocol?

    init(limiter: AngleUsageLimiter) {
        self.limiter = limiter
    }

    func configure(context: ModelContext) {
        repository = LocalAngleTestRepository(context: context)
    }

    // MARK: - Actions

    func generateRandomAngle() {
        currentAngle = Double.random(in: 1..<90)
        showResult = false
        userInput = ""
    }

    func submitAnswer() {
        guard let userAngle = Double(userInput),
              userAngle >= 0, userAngle <= 90 else { return }

        let err = abs(currentAngle - userAngle)
        sessionResults.append(AnswerRecord(actualAngle: currentAngle, userAngle: userAngle, error: err))
        limiter.recordQuestion()

        Task {
            let result = AngleTestResult(
                actualAngle: currentAngle,
                userAngle: userAngle,
                pocketType: "geometric",
                quizType: "geometric"
            )
            try? await repository?.save(result)
        }

        showResult = true
    }

    func nextQuestion() {
        generateRandomAngle()
    }

    func resetStatistics() {
        sessionResults.removeAll()
    }

    // MARK: - Derived state

    var practiceCount: Int { sessionResults.count }
    var accurateCount: Int { sessionResults.filter { $0.error <= 3 }.count }
    var accuracyRate: Double {
        guard !sessionResults.isEmpty else { return 0 }
        return Double(accurateCount) / Double(sessionResults.count) * 100
    }
    var averageError: Double {
        guard !sessionResults.isEmpty else { return 0 }
        return sessionResults.map(\.error).reduce(0, +) / Double(sessionResults.count)
    }

    var lastErrorRating: ErrorRating {
        guard let last = sessionResults.last else { return .accurate }
        if last.error <= 3 { return .accurate }
        if last.error <= 10 { return .close }
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
}
