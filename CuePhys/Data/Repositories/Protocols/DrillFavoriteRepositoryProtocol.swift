import Foundation

@MainActor
protocol DrillFavoriteRepositoryProtocol {
    func add(drillId: String) async throws
    func remove(drillId: String) async throws
    func fetchAll() async throws -> [DrillFavorite]
    func isFavorited(drillId: String) async throws -> Bool
}
