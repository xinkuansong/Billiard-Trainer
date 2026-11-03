import Foundation
import SceneKit

/// Evaluates target-ball events, independently of the cue-ball kick rules.
enum BankJudgement {
    enum Failure: String, Codable {
        case incomplete = "击球计算未完成"
        case scratch = "母球落袋"
        case firstContact = "未直接击中目标球"
        case secondContact = "再次撞击目标球"
        case jaw = "中途碰到袋角"
        case railCount = "碰库次数不符"
        case railOrder = "碰库顺序不符"
        case pocket = "未进指定袋"
    }
    struct Result: Codable {
        let failures: [Failure]
        let actualSegments: [Int]
        let actualPocket: String?
    }
    static func evaluate(_ prediction: ShotPrediction, question: BankPracticeBankQuestion,
                         surfaceY: Float) -> Result {
        let events = prediction.events
        let cue = ShotInput.cueBallName, target = ShotInput.targetBallName
        guard prediction.hasFinalTableState, let recorder = prediction.recorder else {
            return .init(failures: [.incomplete], actualSegments: [], actualPocket: nil)
        }
        var failures: [Failure] = []
        if prediction.cuePocketed || prediction.pocketedBalls.contains(cue)
            || events.contains(where: { if case .pocket(let b, _) = $0.kind { return b == cue }; return false }) {
            failures.append(.scratch)
        }
        let contact = events.firstIndex { if case .ballBall = $0.kind { return true }; return false }
        let direct = contact.map { index -> Bool in
            guard case .ballBall(let a, let b) = events[index].kind,
                  Set([a, b]) == Set([cue, target]) else { return false }
            return !events[..<index].contains { if case .ballCushion(let ball) = $0.kind { return ball == cue }; return false }
        } ?? false
        if !direct { failures.append(.firstContact) }
        let potIndex = events.firstIndex { if case .pocket(let ball, _) = $0.kind { return ball == target }; return false }
        let pocket: String? = potIndex.flatMap { index in
            if case .pocket(_, let id) = events[index].kind { return id }; return nil
        }
        let route = events.enumerated().filter { index, _ in index > (contact ?? events.count) && index < (potIndex ?? events.count) }.map(\.element)
        if route.contains(where: { if case .ballBall = $0.kind { return true }; return false }) { failures.append(.secondContact) }
        let cushions = route.filter { if case .ballCushion(let ball) = $0.kind { return ball == target }; return false }
        let main = cushions.filter { (0..<6).contains($0.cushionIndex ?? -1) }
        let segments = main.compactMap(\.cushionIndex)
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY)
        let intended = geometry.pockets[question.pocket]
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: surfaceY + BallPhysics.radius)
        let invalidJaw = cushions.contains { event in
            guard !(0..<6).contains(event.cushionIndex ?? -1) else { return false }
            // Same terminal-entry contract as the audited research sample.
            guard let last = main.last, event.time >= last.time, pocket == intended.id,
                  let state = playback.stateAt(ballName: target, time: event.time) else { return true }
            return state.position.distanceXZ(to: intended.center) >= 0.18
        }
        if invalidJaw { failures.append(.jaw) }
        if segments.count != question.railSegments.count { failures.append(.railCount) }
        else if segments != question.railSegments { failures.append(.railOrder) }
        if pocket != intended.id { failures.append(.pocket) }
        return .init(failures: failures, actualSegments: segments, actualPocket: pocket)
    }
}
