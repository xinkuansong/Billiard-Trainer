import Foundation
@testable import QiuJi

@MainActor
final class TrainingAnswerRepositoryStub: AngleTestRepositoryProtocol {
    var answers: [UUID: AngleTestResult] = [:]
    func save(_ result: AngleTestResult) async throws { answers[result.id] = result }
    func fetchAll() async throws -> [AngleTestResult] { Array(answers.values) }
    func fetchInRange(from: Date, to: Date) async throws -> [AngleTestResult] {
        answers.values.filter { $0.date >= from && $0.date <= to }
    }
    func deleteAll() async throws { answers = [:] }
}
