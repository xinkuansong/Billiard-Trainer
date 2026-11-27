import Foundation
import SceneKit

// Input is an ordered numeric representative index, cue, legal own target, and remaining balls.
struct OpeningChoiceInput: Decodable {
    let id: Int
    let points: [[Float]]
}
struct PocketRecord: Encodable {
    let index: Int
    let bestKnown: DefenseAttackAssessment.PipeRoute?
    let estimated: DefenseAttackAssessment.PipeRoute?
    let closed: Bool
}
struct Decision: Encodable {
    let id: Int
    let snookered: Bool
    let reliable: Bool
    let pockets: [PocketRecord]
}

func evaluate(_ item: OpeningChoiceInput) throws -> Decision {
    typealias P = DefenseAttackAssessment.P
    let pts = item.points.map { SCNVector3($0[0], 0, $0[1]) }
    let blockers = Array(pts.dropFirst(2))
    if DefenseEffect.fullyBlocked(pts[0], pts[1], blockers) {
        return Decision(id: item.id, snookered: true, reliable: true, pockets: [])
    }
    func coord(_ p: SCNVector3) -> P { P(Double(p.x), Double(p.z)) }
    var assessment = DefenseAttackAssessment()
    let attack = try assessment.pipeAttack(coord(pts[0]), coord(pts[1]), blockers.map(coord))
    let pockets = (0..<6).map { n in
        let routes = attack.routes.filter { $0.pocket == n }
        return PocketRecord(index: n,
                            bestKnown: routes.filter { $0.zeroWidthEstimate != true }.min { $0.score < $1.score },
                            estimated: routes.filter { $0.zeroWidthEstimate == true }.min { $0.score < $1.score },
                            closed: attack.confirmedClosedPockets.contains(n))
    }
    return Decision(id: item.id, snookered: false,
                    reliable: assessment.edges == 0 && assessment.windowDiff <= 0.001 && !assessment.incompleteComfort,
                    pockets: pockets)
}

let args = CommandLine.arguments
let inputs = try JSONDecoder().decode([OpeningChoiceInput].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let encoder = JSONEncoder()
var output = Data()
for item in inputs {
    try autoreleasepool {
        output.append(try encoder.encode(evaluate(item)))
        output.append(10)
    }
}
try output.write(to: URL(fileURLWithPath: args[2]), options: .atomic)
