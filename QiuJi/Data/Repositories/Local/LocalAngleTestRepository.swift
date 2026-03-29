import Foundation
import SwiftData

@MainActor
final class LocalAngleTestRepository: AngleTestRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ result: AngleTestResult) async throws {
        context.insert(result)
        try context.save()
        SyncQueueManager.shared.enqueue(entityType: "AngleTestResult", entityId: result.id, operation: "create")
    }

    func fetchAll() async throws -> [AngleTestResult] {
        let descriptor = FetchDescriptor<AngleTestResult>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchInRange(from: Date, to: Date) async throws -> [AngleTestResult] {
        let predicate = #Predicate<AngleTestResult> { result in
            result.date >= from && result.date <= to
        }
        let descriptor = FetchDescriptor<AngleTestResult>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func deleteAll() async throws {
        let all = try await fetchAll()
        all.forEach { context.delete($0) }
        try context.save()
    }
}
