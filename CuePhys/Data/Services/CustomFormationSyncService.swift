import Foundation

struct FormationMutationResponse: Decodable {
    let conflict: Bool
    let record: FormationRemoteRecord?
}
struct FormationChangePage: Decodable {
    let records: [FormationRemoteRecord]
    let next: Int
    let through: Int
    let hasMore: Bool
}
@MainActor
protocol CustomFormationSyncBackend {
    func mutate(_ operation: FormationMutation, userID: String) async throws -> FormationMutationResponse
    func changes(after: Int, through: Int?, userID: String) async throws -> FormationChangePage
}
@MainActor
struct FormationRESTBackend: CustomFormationSyncBackend {
    let client: APIClient
    init(client: APIClient = .shared) { self.client = client }
    func mutate(_ operation: FormationMutation, userID: String) async throws -> FormationMutationResponse {
        try await client.request(Endpoint(operation.deleted ? .delete : .put,
            "/custom-formations/\(operation.clientId.uuidString)", body: operation, expectedAccountID: userID))
    }
    func changes(after: Int, through: Int?, userID: String) async throws -> FormationChangePage {
        var query = [URLQueryItem(name: "after", value: String(after))]
        if let through { query.append(.init(name: "through", value: String(through))) }
        return try await client.request(Endpoint(.get, "/custom-formations", query: query, expectedAccountID: userID))
    }
}
@MainActor
final class CustomFormationSyncService {
    static let shared = CustomFormationSyncService()
    struct Summary { var uploaded = 0; var downloaded = 0; var failed = false }
    private let backend: any CustomFormationSyncBackend
    init(backend: (any CustomFormationSyncBackend)? = nil) { self.backend = backend ?? FormationRESTBackend() }

    func sync(userID: String, repository: CustomFormationRepository, full: Bool = false,
              shouldContinue: () -> Bool) async -> Summary {
        var summary = Summary()
        do {
            guard shouldContinue() else { return summary }
            let archive = try repository.load()
            let ids = archive.metadata.filter { $0.value.dirty }.keys.compactMap(UUID.init(uuidString:))
            for id in ids {
                guard shouldContinue() else { return summary }
                do {
                    guard let operation = try repository.nextOperation(id) else { continue }
                    let response = try await backend.mutate(operation, userID: userID)
                    guard shouldContinue() else { return summary }
                    guard let record = response.record else { throw CustomFormationError.invalid("同步应答缺少模板，本机修改已保留") }
                    try repository.acknowledge(operation, record: record, conflict: response.conflict)
                    summary.uploaded += 1
                } catch {
                    guard shouldContinue() else { return summary }
                    summary.failed = true
                }
            }
            guard shouldContinue() else { return summary }
            // Full replay does not erase the local cursor until valid data has been applied.
            var after = full ? 0 : try repository.load().cursor
            var through: Int?
            while true {
                guard shouldContinue() else { return summary }
                let page = try await backend.changes(after: after, through: through, userID: userID)
                guard shouldContinue() else { return summary }
                guard page.next >= after, page.next <= page.through,
                      through == nil || through == page.through,
                      page.hasMore ? page.next > after && page.next < page.through : page.next == page.through else {
                    throw CustomFormationError.invalid("同步分页无效，本机模板已保留")
                }
                let currentCursor = try repository.load().cursor
                try repository.apply(page.records, cursor: max(page.next, currentCursor))
                summary.downloaded += page.records.count
                after = page.next; through = page.through
                if !page.hasMore { break }
            }
            let remaining = try repository.load().pendingCount
            // Newly edited generations and conflict copies are sent on the coalesced retry.
            if remaining > 0 { summary.failed = true }
            _ = try repository.transaction {
                $0.syncError = summary.failed ? "同步未完成，本机模板已保留" : nil
            }
        } catch {
            summary.failed = true
            guard shouldContinue() else { return summary }
            do { _ = try repository.transaction { $0.syncError = "同步未完成，本机模板已保留" } }
            catch { NSLog("Formation sync could not persist status: %@", String(describing: type(of: error))) }
        }
        return summary
    }
}
