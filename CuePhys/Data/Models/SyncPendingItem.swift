import Foundation
import SwiftData

/// `SyncPendingItem.operation` 的取值。存字符串是既有落库格式，这里只是收敛字面量。
enum SyncOperation {
    static let create = "create"
    static let update = "update"
    static let delete = "delete"
}

/// `SyncPendingItem.entityType` 的取值。
enum SyncEntityType {
    static let trainingSession = "TrainingSession"
    static let angleTestResult = "AngleTestResult"
}

@Model
final class SyncPendingItem {
    var ownerKey: String = OwnerKey.unassigned
    var id: UUID
    var entityType: String
    var entityId: UUID
    var operation: String
    var createdAt: Date

    init(entityType: String, entityId: UUID, operation: String,
         ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        precondition(!ownerKey.isEmpty && ownerKey != OwnerKey.unassigned)
        self.ownerKey = ownerKey
        self.id = UUID()
        self.entityType = entityType
        self.entityId = entityId
        self.operation = operation
        self.createdAt = Date()
    }
}
