import Foundation
import SceneKit

enum KBallJudgement {
    enum Failure: String, Codable {
        case incomplete = "击球计算未完成"
        case firstContact = "未先碰第一球"
        case pocket = "第一球未进指定袋"
        case missingK = "未K到第二球"
        case rail = "K球库次不符"
        case railFacts = "无法确认K球库次"
    }

    /// Use the ordered physics events, never a distance-to-reference-trajectory score.
    static func failure(events: [ShotEvent], complete: Bool, pocket: Int,
                        secondName: String = TwoBallQuestionPreparer.secondBallName) -> Failure? {
        guard complete else { return .incomplete }
        let cue = ShotInput.cueBallName, target = ShotInput.targetBallName
        let contacts = events.compactMap { event -> String? in
            guard case let .ballBall(a, b) = event.kind else { return nil }
            if a == cue { return b }
            if b == cue { return a }
            return nil
        }
        guard contacts.first == target else { return .firstContact }
        guard events.contains(where: {
            if case let .pocket(ball, id) = $0.kind { return ball == target && id == "pocket_\(pocket)" }
            return false
        }) else { return .pocket }
        guard contacts.dropFirst().contains(secondName) else { return .missingK }
        // Scratch, B's destination and the time of A's pot relative to K are intentionally unrestricted.
        return nil
    }

    /// Observed rail ordinal: approaching rail N before impact or leaving rail N after impact.
    /// World X–Z metres; production cushion normals point inward. No stored route/timing matching.
    static func observedRail(_ prediction: ShotPrediction, railID: Int) -> Int? {
        let cue = ShotInput.cueBallName, a = ShotInput.targetBallName
        let b = TwoBallQuestionPreparer.secondBallName
        func isContact(_ event: ShotEvent, _ other: String) -> Bool {
            guard case let .ballBall(x, y) = event.kind else { return false }
            return (x == cue && y == other) || (y == cue && x == other)
        }
        guard (0..<6).contains(railID),
              let firstA = prediction.events.firstIndex(where: { isContact($0, a) }),
              let firstB = prediction.events.firstIndex(where: { isContact($0, b) }), firstA < firstB,
              let contact = prediction.recorder?.firstBallContacts[b], contact.other.name == cue,
              abs(contact.time - prediction.events[firstB].time) < 0.00001 else { return nil }
        // B's first-contact snapshot contains the cue's exact incoming state.
        // If B was moved by another ball first, these facts cannot certify the later K.
        let velocity = contact.other.velocity
        guard velocity.x.isFinite, velocity.z.isFinite,
              velocity.x * velocity.x + velocity.z * velocity.z > 0 else { return nil }
        let cushions = TableGeometry.chineseEightBallCushions(y: 0).linear
        let normal = cushions[railID].normal
        var rails: [Int] = []
        for event in prediction.events[(firstA + 1)..<firstB] {
            guard case let .ballCushion(ball) = event.kind, ball == cue else { continue }
            guard let index = event.cushionIndex, index >= 0 else { return nil }
            if index < 6 { rails.append(index) } // Pocket jaws/arcs are not main cushions.
        }
        if velocity.x * normal.x + velocity.z * normal.z < 0 { return rails.count + 1 }
        // The two halves of a long rail share a normal and belong to the same physical wall.
        guard let last = rails.last, cushions[last].normal.dot(normal) > 0.99 else { return 0 }
        return rails.count
    }

    static func failure(_ prediction: ShotPrediction, pocket: Int, question: KBallBankQuestion) -> Failure? {
        if let failure = failure(events: prediction.events, complete: prediction.hasFinalTableState, pocket: pocket) {
            return failure
        }
        guard let rail = observedRail(prediction, railID: question.railID) else { return .railFacts }
        return rail == question.rail ? nil : .rail
    }
}

/// K-specific task and judgement, sharing only the existing three-ball physical shot solver.
enum KBallQuestionPreparer {
    static func board(_ layout: KBallBankLayout) throws -> TrainingBankBoard {
        try KBallBankStore.validate(layout, radius: Double(BallPhysics.radius))
        let grid = try TrainingBankStore.load()
        guard let base = grid.board(id: layout.id), base.pocketIndex == layout.board.pocket,
              abs(Double(base.cue.x)-layout.board.cue[0]) < 1e-5,
              abs(Double(base.cue.z)-layout.board.cue[1]) < 1e-5,
              abs(Double(base.target.x)-layout.board.object[0]) < 1e-5,
              abs(Double(base.target.z)-layout.board.object[1]) < 1e-5 else {
            throw KBallBankStore.Failure.invalid("原球形不匹配")
        }
        let target = SCNVector3(Float(layout.board.object[0]), 0, Float(layout.board.object[1]))
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target,
            pocketIndex: layout.board.pocket, surfaceY: 0)
        return .init(gridID: layout.id, seed: base.seed,
            cue: .init(Float(layout.board.cue[0]), 0, Float(layout.board.cue[1])), target: target,
            aim: aim, pocket: layout.board.pocket, angle: base.angle, side: base.side,
            cueBand: base.cueBand, pocketBand: base.pocketBand,
            combinationID: base.combinationID ?? "", qualification: base.qualification ?? "",
            generationAngle: layout.board.angle)
    }

    static func solve(layout: KBallBankLayout, question: KBallBankQuestion, input: SeparationInput,
                      surfaceY: Float, profile: [CueSection], reference: Bool = false) throws -> ShotPrediction {
        guard layout.questions.contains(question) else {
            throw KBallBankStore.Failure.invalid("题目不属于球形")
        }
        let board = try board(layout)
        // Reference reconstruction consumes the exact saved direction, not a new aim search.
        let direction: SCNVector3? = reference ? .init(Float(question.dir[0]), 0, Float(question.dir[1])) : nil
        let stroke = reference ? SeparationInput(spinX: Float(question.sx), spinY: Float(question.sy), velocity: Float(question.v)) : input
        return try TwoBallQuestionPreparer.solve(board: board,
            second: .init(.init(Float(question.b[0]), 0, Float(question.b[1]))), input: stroke,
            surfaceY: surfaceY, profile: profile, direction: direction)
    }
}

extension KBallQuestionPreparer {
    struct Prepared {
        let fingerprint: String
        let question: KBallQuestion
    }
    /// Randomize formations and their saved routes, without storing or solving a reference on admission.
    static func prepare(_ configuration: KBallConfiguration, excluding: Set<String> = [],
                        seed: UInt64 = .random(in: 0...UInt64.max)) throws -> Prepared {
        let bank = try KBallBankStore.load()
        #if DEBUG
        let seed = ProcessInfo.processInfo.arguments.contains("-kBall.fixedSeed") ? UInt64(29) : seed
        #endif
        var random = SceneTrainingGenerator.SeededRandom(state: seed)
        for entry in bank.index.layouts.shuffled(using: &random) {
            try Task.checkCancellation()
            let layout = try bank.layout(entry)
            let candidates = layout.questions.filter {
                !excluding.contains($0.id) && configuration.filter.accepts($0, pocketIndex: layout.board.pocket)
            }
            guard let source = candidates.randomElement(using: &random) else { continue }
            // Persist just the selected route, not the other questions from this formation.
            let selected = KBallBankLayout(id: layout.id, board: layout.board, questions: [source])
            return .init(fingerprint: bank.index.fingerprint,
                         question: .init(id: UUID(), layout: selected, source: source, board: try board(selected)))
        }
        throw KBallBankStore.Failure.invalid("这些条件下暂无未练题目，请调整筛选条件")
    }
}
