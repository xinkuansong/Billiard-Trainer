import Foundation

// Rank each physical solution by how many of its five scores used an estimate,
// whether the four probes kept the rail order, and how easy the stroke was.
func evidenceRank(_ route: Row) -> [Double] {
    let probes = route["probes"] as! [Row]
    let attempts = [route] + probes
    let estimated = attempts.filter { attempt in
        let effect = attempt["effect"] as! Row
        return effect["estimateReason"] is String || (effect["pipeRoute"] as? Row)?["zeroWidthEstimate"] as? Bool == true
    }.count
    let sequences = route["railSequences"] as! [String:[Int]]
    let changed = probes.filter { probe in
        let events = probe["events"] as! [Row]
        for (name, ball) in [("cue", cueKey), ("target", eightKey)] {
            let rails = events.filter { $0["ball"] as? String == ball && $0["kind"] as? String == "cushion" }
                .compactMap { $0["index"] as? Int }
            if rails != sequences[name] { return true }
        }
        return false
    }.count
    let shot = route["shot"] as! Row
    let speed = shot["speed"] as! Double
    let spinX = shot["spinX"] as! Double, spinY = shot["spinY"] as! Double
    let effort = DifficultyModel.executionEffort(spinX:spinX,spinY:spinY,velocity:speed)
    let lowest = attempts.map { ($0["effect"] as! Row)["score"] as! Double }.min()!
    return [Double(estimated),Double(changed),effort,speed,Double(sequences.values.map(\.count).reduce(0,+)),-lowest]
}
