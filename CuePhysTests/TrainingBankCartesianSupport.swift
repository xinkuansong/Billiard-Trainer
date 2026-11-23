import Foundation
import SceneKit
@testable import QiuJi

/// Offline inventory cells, independent of presentation probabilities.
struct TrainingInventoryCell: Codable, Hashable {
    let angleIndex: Int
    let pocketType: Int
    let cueIndex: Int
    let objectIndex: Int
    let railIndex: Int
    static let angles = [0...10, 11...30, 31...50, 51...70, 71...85]
    static let distances: [SceneTrainingConfiguration.Distance] = [.short, .middle, .long]
    static var all: [Self] {
        (0..<5).flatMap { a in (0..<2).flatMap { p in (0..<3).flatMap { c in
            (0..<3).flatMap { o in (0..<3).map { r in
                Self(angleIndex: a, pocketType: p, cueIndex: c, objectIndex: o, railIndex: r)
            }}
        }}}
    }
    var id: String { "a\(angleIndex)-p\(pocketType)-c\(cueIndex)-o\(objectIndex)-r\(railIndex)" }
    var cueBand: SceneTrainingConfiguration.Distance { Self.distances[cueIndex] }
    var pocketBand: SceneTrainingConfiguration.Distance { Self.distances[objectIndex] }
    var railSelection: Set<SceneTrainingConfiguration.RailDistance> {
        railIndex == 2 ? [.frozen] : railIndex == 1 ? [.near] : [.mixed]
    }
    func contains(_ board: TrainingBankBoard) -> Bool {
        Self.angles[angleIndex].contains(Int(board.angle.rounded()))
            && (board.pocketIndex < 4 ? 0 : 1) == pocketType
            && board.cueBand == cueBand && board.pocketBand == pocketBand
            && TrainingLayoutFeatures.railClass(Double(SceneTrainingRailGeometry.clearance(board.target.vector))) == railIndex
    }
}

/// v1 thresholds are reviewable sampling choices, not physical laws.
/// Speed, tip, source seed and solver result are intentionally absent.
struct TrainingLayoutFeatures: Codable {
    static let version = "aim-layout-family-v1"
    let pocketIndex: Int
    let cueX: Double
    let cueZ: Double
    let targetX: Double
    let targetZ: Double
    let signedCut: Double
    let entryBearing: Double
    let cueDistance: Double
    let objectDistance: Double
    let targetGap: Double
    let cueGap: Double
    let targetRail: Int
    let cueRail: Int

    static func railClass(_ gap: Double) -> Int {
        abs(gap) <= Double(SceneTrainingRailGeometry.contactRoundoff) ? 2 :
            gap <= Double(SceneTrainingRailGeometry.nearLimit + SceneTrainingRailGeometry.contactRoundoff) ? 1 : 0
    }
    static func nearestRail(_ point: SCNVector3) -> Int {
        let rails = TableGeometry.chineseEightBallQiuJi(surfaceY: 0).linearCushions.prefix(6)
        return rails.enumerated().min { lhs, rhs in
            func distance(_ rail: LinearCushionSegment) -> Float {
                let d = rail.end - rail.start
                let t = max(0, min(1, ((point.x-rail.start.x)*d.x + (point.z-rail.start.z)*d.z) / (d.x*d.x+d.z*d.z)))
                let closest = rail.start + d*t
                return hypot(point.x-closest.x, point.z-closest.z)
            }
            return distance(lhs.element) < distance(rhs.element)
        }!.offset
    }
    init(_ board: TrainingBankBoard, sx: Float = 1, sz: Float = 1) {
        func reflected(_ point: TrainingBankPoint) -> SCNVector3 { SCNVector3(point.x*sx, 0, point.z*sz) }
        let cue = reflected(board.cue), target = reflected(board.target), aim = reflected(board.effectiveAim)
        let pockets = TableGeometry.chineseEightBallQiuJi(surfaceY: 0).pockets
        let old = pockets[board.pocketIndex].center
        pocketIndex = pockets.indices.min {
            hypot(pockets[$0].center.x-old.x*sx, pockets[$0].center.z-old.z*sz)
                < hypot(pockets[$1].center.x-old.x*sx, pockets[$1].center.z-old.z*sz)
        }!
        cueX = Double(cue.x); cueZ = Double(cue.z)
        targetX = Double(target.x); targetZ = Double(target.z)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: BallPhysics.radius)
        let incoming = ghost-cue, outgoing = aim-target
        signedCut = atan2(Double(incoming.x*outgoing.z-incoming.z*outgoing.x),
                          Double(incoming.x*outgoing.x+incoming.z*outgoing.z)) * 180 / .pi
        entryBearing = atan2(Double(outgoing.z), Double(outgoing.x)) * 180 / .pi
        cueDistance = Double(hypot(cue.x-target.x, cue.z-target.z))
        objectDistance = Double(hypot(aim.x-target.x, aim.z-target.z))
        targetGap = Double(SceneTrainingRailGeometry.clearance(target))
        cueGap = Double(SceneTrainingRailGeometry.clearance(cue))
        targetRail = Self.nearestRail(target); cueRail = Self.nearestRail(cue)
    }
    static func angleDistance(_ a: Double, _ b: Double) -> Double {
        abs(atan2(sin((a-b) * .pi / 180), cos((a-b) * .pi / 180)) * 180 / .pi)
    }
    func isNear(_ other: Self) -> Bool {
        guard pocketIndex == other.pocketIndex,
              Self.railClass(targetGap) == Self.railClass(other.targetGap),
              Self.railClass(cueGap) == Self.railClass(other.cueGap) else { return false }
        let cutLimit = max(abs(signedCut), abs(other.signedCut)) >= 71 ? 0.35 : 0.75
        guard Self.angleDistance(signedCut, other.signedCut) <= cutLimit,
              Self.angleDistance(entryBearing, other.entryBearing) <= 1,
              abs(cueDistance-other.cueDistance) <= min(0.03, 0.03*min(cueDistance, other.cueDistance)),
              abs(objectDistance-other.objectDistance) <= min(0.03, 0.03*min(objectDistance, other.objectDistance)),
              hypot(cueX-other.cueX, cueZ-other.cueZ) <= 0.04,
              hypot(targetX-other.targetX, targetZ-other.targetZ) <= 0.04 else { return false }
        if Self.railClass(targetGap) != 0,
           (targetRail != other.targetRail || abs(targetGap-other.targetGap) > 0.01) { return false }
        if Self.railClass(cueGap) != 0,
           (cueRail != other.cueRail || abs(cueGap-other.cueGap) > 0.015) { return false }
        return true
    }
}

/// Single-writer, global cross-cell index. Compare against retained representatives
/// only: A~B and B~C must not transitively merge a distinct A/C pair.
final class TrainingLayoutFamilyIndex {
    struct Key: Hashable { let pocket: Int; let x: Int; let z: Int }
    private var buckets: [Key: [(String, TrainingLayoutFeatures)]] = [:]
    private func key(_ f: TrainingLayoutFeatures, dx: Int = 0, dz: Int = 0) -> Key {
        .init(pocket: f.pocketIndex, x: Int(floor(f.targetX/0.04))+dx, z: Int(floor(f.targetZ/0.04))+dz)
    }
    func duplicate(of board: TrainingBankBoard) -> String? {
        for (sx, sz): (Float, Float) in [(1,1),(-1,1),(1,-1),(-1,-1)] {
            let f = TrainingLayoutFeatures(board, sx: sx, sz: sz)
            for dx in -1...1 { for dz in -1...1 {
                for (id, old) in buckets[key(f, dx: dx, dz: dz), default: []] where f.isNear(old) { return id }
            }}
        }
        return nil
    }
    func insert(_ board: TrainingBankBoard) {
        let f = TrainingLayoutFeatures(board)
        buckets[key(f), default: []].append((board.id, f))
    }
}
