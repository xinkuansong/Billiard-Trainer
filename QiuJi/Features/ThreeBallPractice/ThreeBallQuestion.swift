import Foundation
import SceneKit

/// Two distinct balls from one group, followed by black eight.
/// The original field names and missing secondInGroup decode old history without changing its ball keys.
struct ThreeBallBallIdentity: Codable, Equatable {
    let solid: Int
    let stripedFirst: Bool
    var secondInGroup: Int? = nil
    static func random() -> Self {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }
    static func random<R: RandomNumberGenerator>(using generator: inout R) -> Self {
        let first = Int.random(in: 1...7, using: &generator)
        let other = Int.random(in: 1...6, using: &generator)
        return .init(solid: first, stripedFirst: Bool.random(using: &generator),
                     secondInGroup: other >= first ? other + 1 : other)
    }
    var first: Int { stripedFirst ? solid + 8 : solid }
    var second: Int {
        if let secondInGroup { return secondInGroup + (stripedFirst ? 8 : 0) }
        return stripedFirst ? solid : solid + 8 // Historical matching-colour pair only.
    }
    var isValid: Bool {
        (1...7).contains(solid) && (secondInGroup.map { (1...7).contains($0) && $0 != solid } ?? true)
    }
}

/// World X/Z metres, Y up. Pocket choices are user intent, independent of bank screening metadata.
struct ThreeBallQuestion: Codable, Identifiable {
    let id: UUID
    let contentID: String
    var board: TrainingBankBoard
    var second: TrainingBankPoint
    var third: TrainingBankPoint?
    var stage = 0
    var plannedPocket: Int?
    var secondPocket: Int { plannedPocket ?? -1 }
    // Nil is retained only when decoding an early development record (1/2/3).
    var identity: ThreeBallBallIdentity? = .random()
    var ballNumber: Int { stage == 0 ? (identity?.first ?? 1) : (identity?.second ?? 2) }
    var secondBallNumber: Int { stage == 0 ? (identity?.second ?? 2) : thirdBallNumber }
    var thirdBallNumber: Int { identity == nil ? 3 : 8 }
    var secondKey: String { "_\(secondBallNumber)" }
    var thirdKey: String { "_\(thirdBallNumber)" }
    var paletteKeys: [String] { [identity?.first ?? 1, identity?.second ?? 2, thirdBallNumber].map { "_\($0)" } }
    var separation: SeparationQuestion {
        .init(id: id, board: board, minimumCenterSpeed: 0, answer: .init(),
              answerDirection: .init(AccuracyTipSelector.referenceDirection(board)), target: [], audit: .init())
    }
}

@dynamicMemberLookup
struct ThreeBallShot: Codable, Identifiable {
    var physical: SeparationShot
    let stage: Int
    let secondPocket: Int
    let failure: String?
    let freeScore: Double
    let comfortVersion: String
    var id: UUID { physical.id }
    subscript<T>(dynamicMember key: KeyPath<SeparationShot, T>) -> T { physical[keyPath: key] }
    var playsStroke: Bool? {
        get { physical.playsStroke }
        set { physical.playsStroke = newValue }
    }
    init(question: ThreeBallQuestion, input: SeparationInput, prediction: ShotPrediction, surfaceY: Float) throws {
        guard let pocket = question.plannedPocket, (0..<6).contains(pocket) else {
            throw ThreeBallBank.Failure.missingPocket
        }
        physical = try .init(question: question.separation, input: input, prediction: prediction,
                             surfaceY: surfaceY, scoresTrajectory: false)
        stage = question.stage; secondPocket = pocket
        comfortVersion = TwoBallComfortScore.freePositionVersion
        let shotFailure = ThreeBallQuestionPreparer.failure(prediction, pocket: question.board.pocketIndex)
        if shotFailure == nil, let cue = prediction.finalPositions[ShotInput.cueBallName],
           let next = prediction.finalPositions[ThreeBallQuestionPreparer.secondBallName] {
            let blocked = question.third.flatMap { _ in prediction.finalPositions[ThreeBallQuestionPreparer.thirdBallName] }
            let available = ThreeBallQuestionPreparer.canContinue(cue: cue, target: next, pocket: pocket,
                obstacle: blocked, surfaceY: surfaceY)
            failure = available ? nil : TrainingPracticeNotice.noDirectRoute
            freeScore = available ? ThreeBallQuestionPreparer.score(cue: cue, target: next, pocket: pocket,
                                                        obstacle: blocked, surfaceY: surfaceY) : 0
        } else { failure = shotFailure; freeScore = 0 }
    }
    func prediction() -> ShotPrediction { physical.prediction() }
    var resultText: String {
        if failure == TrainingPracticeNotice.noDirectRoute || failure == "目标球未进指定袋" {
            return TrainingPracticeNotice.cannotPot
        }
        return String(format: "第%d杆走位 %.1f 分", stage + 1, freeScore) + (failure.map { " · " + $0 } ?? "")
    }
}
