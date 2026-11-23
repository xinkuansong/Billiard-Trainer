import Foundation

@MainActor
protocol AngleTestRepositoryProtocol {
    func save(_ result: AngleTestResult) async throws
    func fetchAll() async throws -> [AngleTestResult]
    func fetchInRange(from: Date, to: Date) async throws -> [AngleTestResult]
    func deleteAll() async throws
}
