import ActivityKit
import Foundation

struct RestTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endDate: Date
        var totalSeconds: Int
    }

    var drillName: String
}
