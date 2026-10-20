import Foundation
import SceneKit

/// Exact cue-disc coordinates, in ball radii. Legacy nine-way categories remain
/// available for summaries; they must never replace these coordinates in a shot.
struct AccuracyTip: Codable, Equatable {
    let x: Float
    let y: Float
    var raisedForClearance = false
    static let center = AccuracyTip(x: 0, y: 0)
    init(x: Float, y: Float, raisedForClearance: Bool = false) {
        self.x = x; self.y = y; self.raisedForClearance = raisedForClearance
    }
    init(legacy: TrainingFixedTip) { self.init(x: legacy.x, y: legacy.y) }
    var category: TrainingFixedTip {
        if y > 0 { return x > 0 ? .highLeft : (x < 0 ? .highRight : .high) }
        if y < 0 { return x > 0 ? .lowLeft : (x < 0 ? .lowRight : .low) }
        return x > 0 ? .left : (x < 0 ? .right : .center)
    }
    var label: String { category.label + (raisedForClearance ? "（避让）" : "") }
}

enum AccuracyTipSelector {
    /// Same cloned cue asset/style and measured envelope as AngleTrainingScene.
    /// Only value geometry escapes this scope, never live SceneKit nodes.
    static func renderedProfile() -> [CueSection] {
        if let model = TableModelLoader.loadTable(includeVisual: false), let node = model.cueStickNode {
            return CueStick(modelCueStickNode: node).clearanceProfile
        }
        return CueSection.fallback
    }
    static func referenceDirection(_ board: TrainingBankBoard) -> SCNVector3 {
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: board.target.vector,
            pocket: board.effectiveAim.vector, ballRadius: BallPhysics.radius)
        return CueClearance.normalizeFlat(ghost - board.cue.vector)
    }
    static func access(_ board: TrainingBankBoard, profile: [CueSection]) -> CueStrikeAccess {
        // Use the live scene's height, including Float precision at that height.
        let y = BTTablePhysics.surfaceY + BallPhysics.radius
        return .init(cue: SCNVector3(board.cue.x, y, board.cue.z), aim: referenceDirection(board),
                     obstacles: [SCNVector3(board.target.x, y, board.target.z)],
                     surfaceY: BTTablePhysics.surfaceY, profile: profile)
    }
    static func select<R: RandomNumberGenerator>(board: TrainingBankBoard,
        configuration: SceneTrainingConfiguration, profile: [CueSection], random: inout R) -> AccuracyTip? {
        select(access: access(board, profile: profile), vertical: configuration.allowsVerticalSpin,
               lateral: configuration.allowsSideSpin, random: &random)
    }
    static func select<R: RandomNumberGenerator>(access: CueStrikeAccess, vertical: Bool,
        lateral: Bool, random: inout R) -> AccuracyTip? {
        let limit = min(CuePhysics.miscueLimitFraction, CuePhysics.tipContactRadius / CuePhysics.tipCurvatureRadius)
        func valid(_ x: Float, _ y: Float) -> Bool {
            access.isAvailable(spinX: Double(x), spinY: Double(y))
                && access.resolvedPose(spinX: Double(x), spinY: Double(y)) != nil
        }
        if !vertical && !lateral {
            if valid(0, 0) { return .center }
            // Scan first: a feasible interval need not extend to the top of the disc.
            var lower: Float = 0
            for index in 1...64 {
                let upper = limit * Float(index) / 64
                if valid(0, upper) {
                    var lo = lower, hi = upper
                    for _ in 0..<18 {
                        let middle = (lo + hi) / 2
                        if valid(0, middle) { hi = middle } else { lo = middle }
                    }
                    let reserve = min(limit, hi + 0.00035)
                    let selected = valid(0, reserve) ? reserve : upper
                    return .init(x: 0, y: selected, raisedForClearance: true)
                }
                lower = upper
            }
            return nil
        }
        // Rejection sampling is uniform over the enabled axis/area and the
        // finite feasible subset; never alter a disabled axis to satisfy a quota.
        for _ in 0..<128 {
            let x = lateral ? Float.random(in: -limit...limit, using: &random) : 0
            let y = vertical ? Float.random(in: -limit...limit, using: &random) : 0
            if x*x+y*y <= limit*limit && valid(x, y) { return .init(x: x, y: y) }
        }
        // Bounded narrow-region fallback, still random among feasible samples.
        var candidates: [AccuracyTip] = []
        let xs = lateral ? Array(-16...16).map { Float($0)*limit/16 } : [0]
        let ys = vertical ? Array(-16...16).map { Float($0)*limit/16 } : [0]
        for x in xs { for y in ys where x*x+y*y <= limit*limit {
            if valid(x, y) { candidates.append(.init(x: x, y: y)) }
        } }
        return candidates.randomElement(using: &random)
    }
}
