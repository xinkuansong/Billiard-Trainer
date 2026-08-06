import Foundation
import SwiftData
import SwiftUI

@MainActor
final class GeometricAngleViewModel: ObservableObject {

    // MARK: - Published state

    @Published var currentAngle: Double = 0
    /// 题面摆向：竖直 0° 的左/右一侧（答题仍用无符号度数）。
    @Published var currentSide: AnglePredictionSide = .right
    @Published var userInput: String = ""
    @Published var showResult: Bool = false
    @Published var showReferenceGrid: Bool = false
    @Published private(set) var sessionResults: [AnswerRecord] = []
    /// 落库失败的可见错误态（nil = 无错误）。禁止静默丢题。
    @Published private(set) var saveErrorMessage: String?
    /// 落库失败但已保留的成绩，供重试；用户答案始终留在 `sessionResults`。
    @Published private(set) var unsavedResults: [AngleTestResult] = []

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

    /// 直接注入仓储（测试用失败仓储覆盖保存失败路径）。
    func configure(repository: AngleTestRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Actions

    func generateRandomAngle() {
        currentAngle = Double.random(in: 1..<90)
        currentSide = Bool.random() ? .left : .right
        showResult = false
        userInput = ""
    }

    func submitAnswer() {
        guard let userAngle = Double(userInput),
              userAngle >= 0, userAngle <= 90 else { return }

        let err = abs(currentAngle - userAngle)
        sessionResults.append(AnswerRecord(actualAngle: currentAngle, userAngle: userAngle, error: err))
        limiter.recordQuestion()
        BTFeedback.quiz(errorDegrees: err)

        Task {
            let result = AngleTestResult(
                actualAngle: currentAngle,
                userAngle: userAngle,
                pocketType: "geometric",
                quizType: "geometric"
            )
            await persist(result)
        }

        showResult = true
    }

    /// 重试此前失败的落库；失败仍会重新置错误态。
    func retryFailedSaves() {
        let pending = unsavedResults
        guard !pending.isEmpty else { return }
        unsavedResults = []
        saveErrorMessage = nil
        Task {
            for result in pending { await persist(result) }
        }
    }

    private func persist(_ result: AngleTestResult) async {
        guard let repository else { return }
        do {
            try await repository.save(result)
        } catch {
            unsavedResults.append(result)
            saveErrorMessage = AngleResultSaveFailure.message(error)
        }
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
