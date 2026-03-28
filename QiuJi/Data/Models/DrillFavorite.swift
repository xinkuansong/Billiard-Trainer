import Foundation
import SwiftData

@Model
final class DrillFavorite {
    var drillId: String
    var addedAt: Date

    init(drillId: String) {
        self.drillId = drillId
        self.addedAt = Date()
    }
}
