import Foundation
import SwiftData

@Model
final class DrillSet {
    var id: UUID
    var setNumber: Int
    var targetBalls: Int
    var madeBalls: Int

    var entry: DrillEntry?

    init(setNumber: Int, targetBalls: Int, madeBalls: Int = 0) {
        self.id = UUID()
        self.setNumber = setNumber
        self.targetBalls = targetBalls
        self.madeBalls = madeBalls
    }
}
