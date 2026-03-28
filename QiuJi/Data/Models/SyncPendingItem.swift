import Foundation
import SwiftData

@Model
final class SyncPendingItem {
    var id: UUID
    var entityType: String
    var entityId: UUID
    var operation: String
    var createdAt: Date

    init(entityType: String, entityId: UUID, operation: String) {
        self.id = UUID()
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.createdAt = Date()
    }
}
