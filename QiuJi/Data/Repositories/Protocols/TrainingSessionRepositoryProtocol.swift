import Foundation

@MainActor
protocol TrainingSessionRepositoryProtocol {
    func create(ballType: String) async throws -> TrainingSession
    func fetchAll() async throws -> [TrainingSession]
    func fetchByDate(from: Date, to: Date) async throws -> [TrainingSession]
    func update(_ session: TrainingSession) async throws
    func delete(_ session: TrainingSession) async throws
}
