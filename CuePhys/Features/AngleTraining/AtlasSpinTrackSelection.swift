import Foundation
import SceneKit

/// Shared 8-track toggle for atlas pages (高低杆 / 左右塞).
/// Default: all on. Turning off the last remaining track is a no-op.
enum AtlasSpinTrackSelection {
    static let trackCount = 8
    static let allEnabled: Set<Int> = Set(0..<trackCount)

    /// Toggle `index` in `current`. Out-of-range is a no-op.
    static func toggle(_ current: Set<Int>, index: Int, count: Int = trackCount) -> Set<Int> {
        guard (0..<count).contains(index) else { return current }
        if current.contains(index) {
            if current.count <= 1 { return current }
            var next = current
            next.remove(index)
            return next
        }
        var next = current
        next.insert(index)
        return next
    }
}

/// Display-only limits shared by both atlases; hidden colour tracks still count.
struct AtlasCushionSelection {
    private(set) var selected = 1
    private(set) var maximum = 0

    mutating func update(maximum: Int) {
        self.maximum = min(4, max(0, maximum))
        selected = self.maximum == 0 ? 1 : min(selected, self.maximum)
    }

    mutating func select(_ count: Int) {
        guard (1...4).contains(count), count <= maximum else { return }
        selected = count
    }
}

/// Time-ordered display samples. Never locate a cushion by nearest position:
/// a multi-rail path may cross itself or revisit the same point.
struct AtlasCushionTrack {
    let cushionCount: Int
    let beforeFirstCushion: [SCNVector3]
    private let contactPaths: [[SCNVector3]]
    private let cushionPaths: [[SCNVector3]]

    func afterContact(limit: Int) -> [SCNVector3] {
        contactPaths[min(4, max(1, limit)) - 1]
    }

    func afterFirstCushion(limit: Int) -> [SCNVector3] {
        cushionPaths[min(4, max(1, limit)) - 1]
    }

    /// The old atlas needed only a short first-rail slice. A four-rail menu
    /// needs either four observed contacts or the cue's complete trajectory.
    static func predict(cueBall: SCNVector3, aimDir: SCNVector3, velocity: Float,
                        spinX: Float, spinY: Float, surfaceY: Float, balls: [ObstacleBall]) -> AtlasCushionTrack? {
        let initial = ShotPredictor.simulateFree(cueBall: cueBall, aimDir: aimDir, velocity: velocity,
            spinX: spinX, spinY: spinY, surfaceY: surfaceY, balls: balls)
        if let track = AtlasCushionTrack(initial, surfaceY: surfaceY) { return track }
        // Retry only a genuinely incomplete display slice, using the same
        // engine/initial state with a larger bounded observation budget.
        let completed = ShotPredictor.simulateFree(cueBall: cueBall, aimDir: aimDir, velocity: velocity,
            spinX: spinX, spinY: spinY, surfaceY: surfaceY, balls: balls, maxEvents: 2000, maxTime: 60)
        return AtlasCushionTrack(completed, surfaceY: surfaceY)
    }

    init?(_ prediction: ShotPrediction, surfaceY: Float) {
        let cue = ShotInput.cueBallName
        guard let recorder = prediction.recorder else { return nil }
        let contactTime = prediction.events.first(where: {
                  if case let .ballBall(a, b) = $0.kind { return a == cue || b == cue }
                  return false
              })?.time ?? 0
        let cushions = prediction.events.filter {
            guard $0.time > contactTime else { return false }
            if case .ballCushion(let ball) = $0.kind { return ball == cue }
            return false
        }
        let pocketTime = prediction.events.first {
            if case .pocket(let ball, _) = $0.kind { return ball == cue }
            return false
        }?.time
        // A pocketed cue is complete even if another ball exhausts the budget.
        // Otherwise a partial run suffices only when all four limits are observed.
        guard pocketTime != nil || prediction.hasFinalTableState || (prediction.termination != nil && cushions.count >= 4) else { return nil }
        cushionCount = cushions.count
        let end = min(pocketTime ?? prediction.duration,
                      pocketTime != nil || prediction.hasFinalTableState ? prediction.duration : cushions[3].time)
        guard end >= contactTime, end.isFinite else { return nil }
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: surfaceY + BallPhysics.radius)
        // Match the predictor's 120 Hz display sampling, retaining exact event
        // endpoints as well as all direction-changing contacts.
        var times = Set((0...Int(ceil(end * 120))).map { min(Float($0) / 120, end) })
        times.formUnion(prediction.events.map(\.time).filter { $0 >= 0 && $0 <= end })
        times.insert(contactTime)
        let samples = times.sorted().compactMap { time -> (Float, SCNVector3)? in
            playback.stateAt(ballName: cue, time: time).map { (time, $0.position) }
        }
        func path(from start: Float, through stop: Float) -> [SCNVector3] {
            guard stop > start else { return [] }
            let breaks = Set([start, stop] + prediction.events.map(\.time).filter { $0 > start && $0 < stop }).sorted()
            var result: [SCNVector3] = []
            for (from, to) in zip(breaks, breaks.dropFirst()) {
                let segment = Self.simplifyDisplay(samples.filter { $0.0 >= from && $0.0 <= to }.map(\.1))
                result.append(contentsOf: result.isEmpty ? segment[...] : segment.dropFirst())
            }
            return result
        }
        let first = cushions.first?.time ?? end
        beforeFirstCushion = path(from: 0, through: first)
        contactPaths = (1...4).map { count in
            path(from: contactTime, through: count <= cushions.count ? cushions[count - 1].time : end)
        }
        cushionPaths = (1...4).map { count in
            path(from: first, through: count <= cushions.count ? cushions[count - 1].time : end)
        }
    }

    // Display-only decimation matching the predictor’s existing 120 Hz
    // polyline appearance. Physics and its validated bank fingerprint stay unchanged.
    private static func simplifyDisplay(_ pts: [SCNVector3]) -> [SCNVector3] {
        guard pts.count > 2 else { return pts }
        var out: [SCNVector3] = [pts[0]]
        var anchor = pts[0]
        let turnThreshold: Float = 0.045   // rad ≈ 2.6°
        let maxSegment: Float = 0.12       // m
        for i in 1..<(pts.count - 1) {
            let a = SCNVector3(pts[i].x - anchor.x, 0, pts[i].z - anchor.z)
            let b = SCNVector3(pts[i + 1].x - pts[i].x, 0, pts[i + 1].z - pts[i].z)
            let la = sqrtf(a.x * a.x + a.z * a.z)
            let lb = sqrtf(b.x * b.x + b.z * b.z)
            guard la > 1e-5, lb > 1e-5 else { continue }
            let dot = max(-1, min(1, (a.x * b.x + a.z * b.z) / (la * lb)))
            let turn = acosf(dot)
            if turn > turnThreshold || la > maxSegment {
                out.append(pts[i])
                anchor = pts[i]
            }
        }
        out.append(pts[pts.count - 1])
        return out
    }

}
