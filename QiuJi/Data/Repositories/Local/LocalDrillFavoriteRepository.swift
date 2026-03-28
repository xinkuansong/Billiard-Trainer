import Foundation
import SwiftData

@MainActor
final class LocalDrillFavoriteRepository: DrillFavoriteRepositoryProtocol {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(drillId: String) async throws {
        let alreadyFavorited = try await isFavorited(drillId: drillId)
        guard !alreadyFavorited else { return }
        let favorite = DrillFavorite(drillId: drillId)
        context.insert(favorite)
        try context.save()
    }

    func remove(drillId: String) async throws {
        let predicate = #Predicate<DrillFavorite> { $0.drillId == drillId }
        let descriptor = FetchDescriptor<DrillFavorite>(predicate: predicate)
        let results = try context.fetch(descriptor)
        results.forEach { context.delete($0) }
        try context.save()
    }

    func fetchAll() async throws -> [DrillFavorite] {
        let descriptor = FetchDescriptor<DrillFavorite>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func isFavorited(drillId: String) async throws -> Bool {
        let predicate = #Predicate<DrillFavorite> { $0.drillId == drillId }
        let descriptor = FetchDescriptor<DrillFavorite>(predicate: predicate)
        let count = try context.fetchCount(descriptor)
        return count > 0
    }
}
