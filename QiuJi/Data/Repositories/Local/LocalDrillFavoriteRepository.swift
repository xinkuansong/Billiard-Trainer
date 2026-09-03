import Foundation
import SwiftData

@MainActor
final class LocalDrillFavoriteRepository: DrillFavoriteRepositoryProtocol {
    private let context: ModelContext
    private let ownerContext: CurrentOwnerContext

    init(context: ModelContext, ownerContext: CurrentOwnerContext? = nil) {
        self.context = context
        self.ownerContext = ownerContext ?? .shared
    }

    func add(drillId: String) async throws {
        let alreadyFavorited = try await isFavorited(drillId: drillId)
        guard !alreadyFavorited else { return }
        let favorite = DrillFavorite(drillId: drillId, ownerKey: ownerContext.ownerKey)
        context.insert(favorite)
        try context.save()
    }

    func remove(drillId: String) async throws {
        let ownerKey = ownerContext.ownerKey
        let predicate = #Predicate<DrillFavorite> {
            $0.ownerKey == ownerKey && $0.drillId == drillId
        }
        let descriptor = FetchDescriptor<DrillFavorite>(predicate: predicate)
        let results = try context.fetch(descriptor)
        results.forEach { context.delete($0) }
        try context.save()
    }

    func fetchAll() async throws -> [DrillFavorite] {
        let ownerKey = ownerContext.ownerKey
        let descriptor = FetchDescriptor<DrillFavorite>(
            predicate: #Predicate { $0.ownerKey == ownerKey },
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func isFavorited(drillId: String) async throws -> Bool {
        let ownerKey = ownerContext.ownerKey
        let predicate = #Predicate<DrillFavorite> {
            $0.ownerKey == ownerKey && $0.drillId == drillId
        }
        let descriptor = FetchDescriptor<DrillFavorite>(predicate: predicate)
        let count = try context.fetchCount(descriptor)
        return count > 0
    }
}
