import Foundation

enum SpatialCueElevation {
    typealias Record = SpatialPracticeRecord
    static func resolve(_ input:Record.Input, access:CueStrikeAccess?, forNewTarget:Bool = false)->Record.Input {
        let requested = forNewTarget ? Double(CueStick.minElevationRadians) * 180 / .pi
                                     : input.preferredElevation ?? input.elevation
        guard requested.isFinite, var geometry = access else { return input }
        let maximum = Record.Input.maximumPracticeElevation
        func clears(at degrees: Double) -> Bool {
            geometry.fixedElevation = Float(degrees * .pi / 180)
            return geometry.isAvailable(spinX: input.spinX, spinY: input.spinY)
        }
        // Test the exact requested pose first. The automatic shared solver uses a
        // different cue envelope, so validate every candidate with the actual fixed pose.
        func firstClearAngle(toward limit: Double) -> Double? {
            let step = limit > requested ? 0.5 : -0.5
            var blocked = requested
            while blocked != limit {
                var clear = step > 0 ? min(limit, blocked + step) : max(limit, blocked + step)
                if clears(at: clear) {
                    while abs(clear - blocked) > 0.01 {
                        let middle = (clear + blocked) / 2
                        if clears(at: middle) { clear = middle } else { blocked = middle }
                    }
                    return clear
                }
                blocked = clear
            }
            return nil
        }
        let effective = clears(at: requested) ? requested
            : firstClearAngle(toward: maximum) ?? firstClearAngle(toward: 0) ?? requested
        var resolved = input
        resolved.elevation = effective
        resolved.preferredElevation = effective == requested ? nil : requested
        return resolved
    }
}
