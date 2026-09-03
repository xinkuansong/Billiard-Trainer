import Foundation
import SwiftData

@Model
final class DrillFavorite {
    var ownerKey: String = OwnerKey.unassigned
    var drillId: String
    var addedAt: Date

    init(drillId: String, ownerKey: String = DeviceGuestIdentity.ownerKey()) {
        precondition(!ownerKey.isEmpty && ownerKey != OwnerKey.unassigned)
        self.ownerKey = ownerKey
        self.drillId = drillId
        self.addedAt = Date()
    }
}
