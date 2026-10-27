import Foundation
import SceneKit

/// A new identity represents a user action, even when its short text repeats.
struct TrainingPracticeNotice: Equatable {
    let id = UUID()
    let text: String
    static let cannotPot = "0分，无法进指定袋，请重打"
    static let noDirectRoute = "无法进指定袋"

    static func recoverable(_ error: Error, reference: Bool = false) -> Self? {
        guard let failure = error as? SeparationQuestionGenerator.Failure else { return nil }
        switch failure {
        case .inaccessible:
            return .init(text: reference ? "中杆参考不可用，可调整打点后击球" : failure.localizedDescription)
        case .noDirectRoute:
            return .init(text: reference ? "中杆参考线路不可用" : "当前线路无法进指定袋，请重打")
        case .unavailable, .incomplete, .incompatible:
            return nil
        }
    }
}

/// All positions are SceneKit X/Z metres. Y comes from the live table, never a screen projection.
enum SeparationQuestionGenerator {
    static let version = "separation-planar-v1"
    static let speedRange = ShotTuning.velocityRange.lowerBound...4.5
    // Question sampling stays independent of the player's initial shot speed.
    static let defaultSpeed = 2.5
    static let scanStep: Float = 0.01
    static let fineStep: Float = 0.0025
    enum Failure: LocalizedError {
        case unavailable, inaccessible, incomplete, incompatible, noDirectRoute
        var errorDescription: String? {
            switch self {
            case .unavailable: "当前条件下未找到可用的目标轨迹，请重试或调整训练条件。"
            case .inaccessible: "当前打点受库边或球遮挡，请调整打点后击球。"
            case .incomplete: "本杆未能完成模拟，请重试；本次没有计入题数。"
            case .incompatible: "练习规则已更新，原记录已保留，请重新开始练习。"
            case .noDirectRoute: "当前线路无法进指定袋，请重打"
            }
        }
    }
    struct Prepared {
        let fingerprint: String
        let question: SeparationQuestion
        static func prepare(_ configuration: SceneTrainingConfiguration) throws -> Self {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-separation.fixedSeed") {
                return try SeparationQuestionGenerator.prepare(configuration, seed: 20261022)
            }
            #endif
            return try SeparationQuestionGenerator.prepare(configuration)
        }
    }
    struct Audit: Codable {
        var centerSimulations = 0
        var sampledInputs: [SeparationInput] = []
        var rejectedInputs = 0
        var elapsedSeconds: Double = 0
    }
    static func prepare(_ configuration: SceneTrainingConfiguration, excluding: Set<String> = [],
                        seed: UInt64 = .random(in: 0...UInt64.max)) throws -> Prepared {
        let bank = try TrainingBankStore.load()
        let boards = try bank.draw(configuration, seed: seed, excluding: excluding).boards
        let profile = AccuracyTipSelector.renderedProfile()
        var random = SceneTrainingGenerator.SeededRandom(state: seed)
        for board in boards {
            try Task.checkCancellation()
            if let question = try generate(board: board, configuration: configuration,
                                           profile: profile, random: &random) {
                return .init(fingerprint: bank.sourceFingerprint, question: question)
            }
        }
        throw Failure.unavailable
    }
    static func sample<R: RandomNumberGenerator>(minimum: Float, vertical: Bool, lateral: Bool,
                                                 random: inout R) -> SeparationInput? {
        guard minimum.isFinite, minimum <= Float(speedRange.upperBound) else { return nil }
        func normal(_ random: inout R) -> Double {
            sqrt(-2 * log(Double.random(in: Double.leastNonzeroMagnitude..<1, using: &random)))
                * cos(2 * .pi * Double.random(in: 0..<1, using: &random))
        }
        let limit = min(CuePhysics.miscueLimitFraction, CuePhysics.tipContactRadius / CuePhysics.tipCurvatureRadius)
        // Rejection, not boundary clamping. Disabled axes remain exactly zero.
        for _ in 0..<4096 {
            let x = lateral ? Float(normal(&random) * 0.18) : 0
            let y = vertical ? Float(normal(&random) * 0.18) : 0
            let v = Float(defaultSpeed + normal(&random) * 0.75)
            if x*x+y*y <= limit*limit, v >= minimum, speedRange.contains(Double(v)) {
                return .init(spinX: x, spinY: y, velocity: v)
            }
        }
        return nil
    }
    /// Every candidate is solved independently at its exact input, then checked against the rendered cue envelope.
    static func solve(board: TrainingBankBoard, input: SeparationInput, surfaceY: Float,
                      profile: [CueSection]) throws -> ShotPrediction {
        try Task.checkCancellation()
        // This recording version stores the analytical planar states. A future engine
        // switch must add its spatial segments to the durable format before use here.
        guard EventDrivenEngine.SimulationModel.appDefault == .planarReference else { throw Failure.incompatible }
        guard input.isValid else { throw Failure.inaccessible }
        let prediction = ShotPredictor.predict(.init(cueBall: board.cue.vector, targetBall: board.target.vector,
            pocketIndex: board.pocketIndex, velocity: input.velocity, spinX: input.spinX, spinY: input.spinY,
            surfaceY: surfaceY, pocketAimOverride: board.effectiveAim.vector), maxEvents: 1500, maxTime: 60)
        try Task.checkCancellation()
        // Geometry rejection is an ordinary unavailable route, not a failed simulation.
        if !prediction.feasible { throw Failure.noDirectRoute }
        guard let direction = prediction.strikeDirection, direction.x.isFinite, direction.z.isFinite else {
            throw Failure.incomplete
        }
        let y = surfaceY + BallPhysics.radius
        let access = CueStrikeAccess(cue: .init(board.cue.x, y, board.cue.z), aim: direction,
            obstacles: [.init(board.target.x, y, board.target.z)], surfaceY: surfaceY, profile: profile)
        guard access.isAvailable(spinX: Double(input.spinX), spinY: Double(input.spinY)),
              access.resolvedPose(spinX: Double(input.spinX), spinY: Double(input.spinY)) != nil else {
            throw Failure.inaccessible
        }
        guard prediction.hasFinalTableState, prediction.recorder != nil,
              prediction.finalPositions.values.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
            throw Failure.incomplete
        }
        return prediction
    }
    static func potsSpecifiedPocket(_ prediction: ShotPrediction, pocket: Int) -> Bool {
        prediction.hasFinalTableState && prediction.events.contains {
            if case let .pocket(ball, id) = $0.kind { return ball == ShotInput.targetBallName && id == "pocket_\(pocket)" }
            return false
        }
    }
    /// Admission policy for generated answers only; never changes a player's shot or score.
    /// Resolve recorded collision IDs against the same production geometry used by ShotPredictor.
    static func hasCueJawContact(_ prediction: ShotPrediction) -> Bool {
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY)
        return prediction.events.contains { event in
            guard case .ballCushion(let ball) = event.kind, ball == ShotInput.cueBallName else { return false }
            // An unidentified collision cannot certify a jaw-free answer.
            guard let index = event.cushionIndex, index >= 0 else { return true }
            if geometry.linearCushions.indices.contains(index) {
                return geometry.linearCushions[index].soundSurface == .jaw
            }
            // All production circular cushions are corner/side pocket nose fillets.
            return true
        }
    }
    static func generate<R: RandomNumberGenerator>(board: TrainingBankBoard, configuration: SceneTrainingConfiguration,
        profile: [CueSection], random: inout R) throws -> SeparationQuestion? {
        let start = Date()
        var audit = Audit()
        let surfaceY = BTTablePhysics.surfaceY
        var minimum: Float?
        func center(_ speed: Float) throws -> Bool {
            try Task.checkCancellation()
            audit.centerSimulations += 1
            do {
                let result = try solve(board: board, input: .init(spinX: 0, spinY: 0, velocity: speed),
                                       surfaceY: surfaceY, profile: profile)
                return potsSpecifiedPocket(result, pocket: board.pocketIndex)
            } catch is CancellationError { throw CancellationError() }
            catch { return false }
        }
        let lower = Float(speedRange.lowerBound)
        // A 0.05 scan missed a verified narrow interval (2.01 vs 2.23 m/s).
        // Scan the entire preceding range at 0.01, then refine the first witness.
        for index in 0...Int(((Float(speedRange.upperBound)-lower)/scanStep).rounded()) {
            let speed = lower + Float(index) * scanStep
            if try center(speed) {
                let lo = max(lower, speed-scanStep)
                minimum = speed
                for fine in 0...Int(((speed-lo)/fineStep).rounded()) {
                    let candidate = lo + Float(fine)*fineStep
                    if try center(candidate) { minimum = candidate; break }
                }
                break
            }
        }
        guard let minimum else { return nil }
        for _ in 0..<48 {
            try Task.checkCancellation()
            guard let input = sample(minimum: minimum, vertical: configuration.allowsVerticalSpin,
                                     lateral: configuration.allowsSideSpin, random: &random) else { break }
            audit.sampledInputs.append(input)
            do {
                let prediction = try solve(board: board, input: input, surfaceY: surfaceY, profile: profile)
                guard AccuracyShotJudgement.evaluate(prediction, pocketIndex: board.pocketIndex) == .success,
                      !hasCueJawContact(prediction) else {
                    audit.rejectedInputs += 1; continue
                }
                let line = try SeparationTrajectory.extract(prediction)
                guard !line.isEmpty else { audit.rejectedInputs += 1; continue }
                audit.elapsedSeconds = Date().timeIntervalSince(start)
                return .init(id: UUID(), board: board, minimumCenterSpeed: minimum, answer: input,
                    answerDirection: .init(prediction.strikeDirection!), target: line, audit: audit)
            } catch is CancellationError { throw CancellationError() }
            catch { audit.rejectedInputs += 1 }
        }
        return nil
    }
}

struct SeparationInput: Codable, Equatable {
    var spinX: Float = 0
    var spinY: Float = 0
    var velocity: Float = Float(ShotTuning.defaultVelocity)
    var isValid: Bool {
        let limit = min(CuePhysics.miscueLimitFraction, CuePhysics.tipContactRadius / CuePhysics.tipCurvatureRadius)
        return spinX.isFinite && spinY.isFinite && velocity.isFinite
            && spinX*spinX+spinY*spinY <= limit*limit + 1e-7
            && ShotTuning.velocityRange.contains(Double(velocity))
    }
}
struct SeparationQuestion: Codable, Identifiable {
    let id: UUID
    let board: TrainingBankBoard
    let minimumCenterSpeed: Float
    let answer: SeparationInput
    let answerDirection: TrainingBankPoint
    let target: [SeparationTrajectory.Point]
    let audit: SeparationQuestionGenerator.Audit
    var ballNumber: Int { Int(board.seed % 15) + 1 }
}
enum SeparationTrajectory {
    struct Point: Codable {
        let time: Float
        let position: TrainingBankPoint
        var isEvent: Bool? = nil
    }
    /// Raw physical frames only: never the collecting/fading tail installed by TrajectoryPlayback.
    static func extract(_ prediction: ShotPrediction) throws -> [Point] {
        guard prediction.hasFinalTableState, let recorder = prediction.recorder else {
            throw SeparationQuestionGenerator.Failure.incomplete
        }
        guard let contact = recorder.firstBallContacts[ShotInput.cueBallName],
              contact.other.name == ShotInput.targetBallName else { return [] }
        return try extract(prediction, ballName: ShotInput.cueBallName,
            startTime: contact.time, startPosition: contact.incoming.position)
    }

    /// Full object-ball motion, ending at rest or the physical capture, never a pocket-centre extension.
    static func extractObject(_ prediction: ShotPrediction) throws -> [Point] {
        guard prediction.hasFinalTableState, let recorder = prediction.recorder else {
            throw SeparationQuestionGenerator.Failure.incomplete
        }
        guard let first = recorder.framesByBallName[ShotInput.targetBallName]?.first else { return [] }
        return try extract(prediction, ballName: ShotInput.targetBallName,
            startTime: first.time, startPosition: first.position)
    }

    private static func extract(_ prediction: ShotPrediction, ballName: String,
                                startTime: Float, startPosition: SCNVector3) throws -> [Point] {
        guard let recorder = prediction.recorder else { throw SeparationQuestionGenerator.Failure.incomplete }
        let capture = recorder.pocketEntries.first { $0.ball.name == ballName }
        let frames = recorder.framesByBallName[ballName] ?? []
        let lastMoving = frames.last { $0.state != .stationary && $0.state != .pocketed }?.time ?? startTime
        let restingTime = frames.first { $0.time >= lastMoving && $0.state == .stationary }?.time
        let end = capture?.time ?? restingTime ?? prediction.duration
        var result: [Point] = [.init(time: 0, position: .init(startPosition), isEvent: true)]
        let eventTimes = prediction.events.filter { event in
            switch event.kind {
            case .ballBall(let a, let b): return a == ballName || b == ballName
            case .ballCushion(let ball), .pocket(let ball, _): return ball == ballName
            }
        }.map(\.time)
        // Event frames alone would turn a curved sliding segment into a chord.
        // Evolve the raw state between events; include every event endpoint exactly.
        for (index, frame) in frames.enumerated() where frame.time <= end && frame.state != .pocketed {
            guard frame.time.isFinite, frame.position.x.isFinite, frame.position.z.isFinite else {
                throw SeparationQuestionGenerator.Failure.incomplete
            }
            let next = min(end, index+1 < frames.count ? frames[index+1].time : end)
            guard next >= startTime else { continue }
            let begin = max(frame.time, startTime)
            let count = max(1, Int(ceil((next-begin)*120)))
            for sample in 0...count {
                let time = begin + (next-begin)*Float(sample)/Float(count)
                guard time > startTime, time > (result.last?.time ?? 0) + startTime else { continue }
                let dt = time-frame.time
                let omega = SCNVector3(frame.angularVelocity.x, frame.angularVelocity.y, frame.angularVelocity.z)
                let position: SCNVector3
                switch frame.state {
                case .sliding:
                    position = AnalyticalMotion.evolveSliding(position: frame.position, velocity: frame.velocity,
                        angularVelocity: omega, dt: dt).position
                case .rolling:
                    position = AnalyticalMotion.evolveRolling(position: frame.position, velocity: frame.velocity,
                        angularVelocity: omega, dt: dt).position
                case .stationary, .spinning, .pocketed: position = frame.position
                }
                guard position.x.isFinite, position.z.isFinite else { throw SeparationQuestionGenerator.Failure.incomplete }
                result.append(.init(time: time-startTime, position: .init(position),
                    isEvent: eventTimes.contains { abs($0-time) < 0.000001 }))
            }
        }
        if let capture {
            let time = capture.time-startTime
            if result.last?.time == time { result.removeLast() }
            result.append(.init(time: time, position: .init(capture.ball.position), isEvent: true))
        }
        return result
    }
}
