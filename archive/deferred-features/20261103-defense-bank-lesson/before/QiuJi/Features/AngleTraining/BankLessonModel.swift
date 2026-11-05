import Foundation
import SceneKit

/// One fixed teaching shot. World X–Z, metres, +X right / +Z down in the figures.
/// The mirrored point is a construction aid; live trajectories come from the engine.
enum BankLessonModel {
    static let cue = SIMD2<Float>(-0.6308422684669495, -0.3993084728717804)
    static let target = SIMD2<Float>(-0.560308575630188, 0.17696984112262726)
    static let direction = SIMD2<Float>(0.10153273493, 0.994832277298)
    static var pocket: SIMD2<Float> { [0, -TablePhysics.sidePocketCenterOffsetZ] }
    static var rail: Float { TablePhysics.innerWidth / 2 - BallPhysics.radius }

    struct Geometry {
        let mirror: SIMD2<Float>
        let bounce: SIMD2<Float>
        let ghost: SIMD2<Float>
    }

    static func geometry(target: SIMD2<Float> = BankLessonModel.target) -> Geometry {
        let mirror = SIMD2(target.x, 2 * rail - target.y)
        let fraction = (rail - pocket.y) / (mirror.y - pocket.y)
        let bounce = pocket + (mirror - pocket) * fraction
        let ghost = target - simd_normalize(bounce - target) * (2 * BallPhysics.radius)
        return Geometry(mirror: mirror, bounce: bounce, ghost: ghost)
    }

    static func trial(degrees: Double) -> (end: SIMD2<Float>, missMM: Float) {
        let delta = geometry().ghost - cue
        let angle = atan2(delta.y, delta.x) + Float(degrees) * .pi / 180
        let aim = SIMD2<Float>(cos(angle), sin(angle))
        return (cue + aim * simd_length(delta), abs(aim.x * delta.y - aim.y * delta.x) * 1000)
    }

    struct Sample: Sendable {
        let time: Float
        let point: SIMD2<Float>
    }

    struct Shot: Sendable {
        let speedIndex: Int
        let cue: [Sample]
        let object: [Sample]
        let contactTime: Float?
        let cushionTimes: [Float]
        let mainCushions: Int
        let jawContacts: Int
        let objectPocket: String?
        let objectPocketTime: Float?
        let cuePocketTime: Float?

        var duration: Float { max(cue.last?.time ?? 0, object.last?.time ?? 0) }
        var isOneBank: Bool { objectPocket == "pocket_4" && mainCushions == 1 && cuePocketTime == nil }
        var result: String {
            let primary: String
            if let pocket = objectPocket {
                if pocket != "pocket_4" {
                    primary = "目标球进入另一只球袋，未完成指定路线。"
                } else if mainCushions == 1 {
                    primary = "一库进入指定中袋。"
                } else {
                    primary = "目标球经 \(mainCushions) 次碰库进入指定中袋，已不是一库翻袋。"
                }
            } else if contactTime == nil {
                primary = "母球停在目标球之前，未碰到目标球。"
            } else if cushionTimes.isEmpty {
                primary = "目标球尚未到库边便已停下。"
            } else if mainCushions == 1 && jawContacts == 0 {
                primary = "力度不足，目标球反弹后停在袋前。"
            } else {
                primary = "目标球未进指定中袋；黄色虚线展示反弹后直至停止的路线。"
            }
            return primary + (jawContacts > 0 ? " 途中有袋角或喉壁碰撞。" : "")
                + (cuePocketTime != nil ? " 母球也落袋。" : "")
        }

        func position(in samples: [Sample], at time: Float) -> SIMD2<Float>? {
            guard let first = samples.first else { return nil }
            if time <= first.time { return first.point }
            for pair in zip(samples, samples.dropFirst()) where time <= pair.1.time {
                let fraction = (time - pair.0.time) / (pair.1.time - pair.0.time)
                return pair.0.point + (pair.1.point - pair.0.point) * fraction
            }
            return samples.last?.point
        }
    }

    enum SimulationError: Error { case incomplete, missingTrack }

    /// Fixed direction, centre hit, no sidespin. Each speed is independently simulated.
    static func simulate(speedIndex: Int) throws -> Shot {
        precondition((6...40).contains(speedIndex))
        let surface = BTTablePhysics.surfaceY
        let y = surface + BallPhysics.radius
        let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: surface))
        let strike = CueBallStrike.executeStrike(
            aimDirection: SCNVector3(direction.x, 0, direction.y),
            velocity: Float(speedIndex) / 10, spinX: 0, spinY: 0, elevation: 0)
        engine.setBall(BallState(position: SCNVector3(cue.x, y, cue.y), velocity: strike.velocity,
                                 angularVelocity: strike.angularVelocity, state: .sliding, name: "cueBall"))
        engine.setBall(BallState(position: SCNVector3(target.x, y, target.y), velocity: SCNVector3Zero,
                                 angularVelocity: SCNVector3Zero, state: .stationary, name: "object"))
        guard engine.simulatePrediction(model: .appDefault, maxEvents: 3000, maxTime: 60,
                                        highFidelityBounds: true) == .settled else {
            throw SimulationError.incomplete
        }
        var contact: Float?, objectPocket: String?, objectPot: Float?, cuePot: Float?
        var cushionTimes: [Float] = [], main = 0, jaws = 0
        for (event, time) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
            switch event {
            case .ballBall: if contact == nil { contact = time }
            case let .ballCushion(ball, index, _) where ball == "object":
                cushionTimes.append(time)
                if (0..<6).contains(index) { main += 1 } else { jaws += 1 }
            case let .pocket(ball, id):
                if ball == "object" { objectPocket = id; objectPot = time }
                if ball == "cueBall" { cuePot = time }
            default: break
            }
        }
        let recorder = engine.getTrajectoryRecorder()
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: y)
        func track(_ name: String, potTime: Float?) -> [Sample] {
            let finish = potTime ?? (recorder.framesByBallName[name]?.last?.time ?? 0)
            var times = Set((0...Int(ceil(finish * 30))).map { min(finish, Float($0) / 30) })
            times.formUnion(engine.resolvedEventTimes.filter { $0 <= finish })
            return times.sorted().compactMap { time in
                guard let state = playback.stateAt(ballName: name, time: time) else { return nil }
                return Sample(time: time, point: [state.position.x, state.position.z])
            }
        }
        let cueTrack = track("cueBall", potTime: cuePot), objectTrack = track("object", potTime: objectPot)
        guard !cueTrack.isEmpty, !objectTrack.isEmpty else { throw SimulationError.missingTrack }
        return Shot(speedIndex: speedIndex, cue: cueTrack, object: objectTrack, contactTime: contact,
                    cushionTimes: cushionTimes, mainCushions: main, jawContacts: jaws,
                    objectPocket: objectPocket, objectPocketTime: objectPot, cuePocketTime: cuePot)
    }
}

/// Page-owned, bounded cache. Actor isolation serializes physics work off the UI actor.
actor BankLessonSimulation {
    private var cache: [Int: BankLessonModel.Shot] = [:]

    func shot(speedIndex: Int) throws -> BankLessonModel.Shot {
        try Task.checkCancellation()
        if let shot = cache[speedIndex] { return shot }
        let shot = try BankLessonModel.simulate(speedIndex: speedIndex)
        cache[speedIndex] = shot
        return shot
    }
}
