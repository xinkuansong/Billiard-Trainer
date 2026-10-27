import Foundation
import SceneKit

enum ThreeBallQuestionPreparer {
    static let secondBallName = "threeBallNext"
    static let thirdBallName = "threeBallThird"
    struct Prepared {
        let fingerprint: String
        let question: ThreeBallQuestion
        static func prepare(_ configuration: SceneTrainingConfiguration) throws -> Self {
            try ThreeBallQuestionPreparer.prepare(configuration)
        }
    }
    static func prepare(_ configuration: SceneTrainingConfiguration, excluding: Set<String> = []) throws -> Prepared {
        let bank = try ThreeBallBank.load()
        return .init(fingerprint: bank.fingerprint, question: try bank.draw(configuration, excluding: excluding))
    }
    static func board(id: String, cue: SCNVector3, target: SCNVector3, pocket: Int) -> TrainingBankBoard {
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocket, surfaceY: 0)
        let angle = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: aim)
        func band(_ distance: Double) -> SceneTrainingConfiguration.Distance {
            distance <= 0.6 ? .short : distance <= 1.2 ? .middle : .long
        }
        return .init(gridID: id, seed: 1, cue: cue, target: target, aim: aim, pocket: pocket,
            angle: angle, side: 1, cueBand: band(Double(AngleSceneCalculator.horizontalDistance(cue, target))),
            pocketBand: band(Double(AngleSceneCalculator.horizontalDistance(target, aim))),
            combinationID: id, qualification: "actual-stop", generationAngle: angle)
    }
    static func solve(question: ThreeBallQuestion, input: SeparationInput,
                      surfaceY: Float, profile: [CueSection]) throws -> ShotPrediction {
        let board = question.board
        let aim = try SeparationQuestionGenerator.solve(board: board, input: input, surfaceY: surfaceY, profile: profile)
        guard let direction = aim.strikeDirection else { throw SeparationQuestionGenerator.Failure.incomplete }
        let y = surfaceY + BallPhysics.radius
        let obstacles = [board.target, question.second] + [question.third].compactMap { $0 }
        let access = CueStrikeAccess(cue: .init(board.cue.x,y,board.cue.z), aim: direction,
            obstacles: obstacles.map { .init($0.x,y,$0.z) }, surfaceY: surfaceY, profile: profile)
        guard access.isAvailable(spinX: Double(input.spinX), spinY: Double(input.spinY)),
              access.resolvedPose(spinX: Double(input.spinX), spinY: Double(input.spinY)) != nil else {
            throw SeparationQuestionGenerator.Failure.inaccessible
        }
        var balls = [ObstacleBall(name: ShotInput.targetBallName, position: board.target.vector),
                     .init(name: secondBallName, position: question.second.vector)]
        if let third = question.third { balls.append(.init(name: thirdBallName, position: third.vector)) }
        let prediction = ShotPredictor.simulateFree(cueBall: board.cue.vector, aimDir: direction,
            velocity: input.velocity, spinX: input.spinX, spinY: input.spinY, surfaceY: surfaceY,
            balls: balls, maxEvents: 1500, maxTime: 60, recordedStrikeDirection: direction)
        try Task.checkCancellation()
        guard prediction.hasFinalTableState, prediction.recorder != nil,
              prediction.finalPositions.values.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
            throw SeparationQuestionGenerator.Failure.incomplete
        }
        return prediction
    }
    static func failure(_ prediction: ShotPrediction, pocket: Int) -> String? {
        if prediction.pocketedBalls.contains(ShotInput.cueBallName) { return "母球落袋" }
        if prediction.pocketedBalls.contains(secondBallName) || prediction.pocketedBalls.contains(thirdBallName) { return "后续目标球提前落袋" }
        guard prediction.recorder?.firstBallContacts[ShotInput.cueBallName]?.other.name == ShotInput.targetBallName else { return "未先碰当前目标球" }
        if !SeparationQuestionGenerator.potsSpecifiedPocket(prediction, pocket: pocket) { return "目标球未进指定袋" }
        return nil
    }
    static func score(cue: SCNVector3, target: SCNVector3, pocket: Int, obstacle: SCNVector3?, surfaceY: Float) -> Double {
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocket, surfaceY: surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: BallPhysics.radius)
        if let obstacle,
           AngleSceneCalculator.isPathBlocked(from: cue, to: ghost, obstacles: [obstacle], clearance: 2 * BallPhysics.radius)
            || AngleSceneCalculator.isPathBlocked(from: target, to: aim, obstacles: [obstacle], clearance: 2 * BallPhysics.radius) { return 0 }
        return TwoBallComfortScore.evaluateFreePosition(cue: (Double(cue.x),Double(cue.z)),
            ball: (Double(target.x),Double(target.z)), pocket: pocket)?.total ?? 0
    }

    /// Use the same geometric admission as the next stroke, before attempting its reference.
    static func canContinue(cue: SCNVector3, target: SCNVector3, pocket: Int,
                            obstacle: SCNVector3?, surfaceY: Float) -> Bool {
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocket, surfaceY: surfaceY)
        guard AngleSceneCalculator.isFeasible(cueBall: cue, targetBall: target, pocket: aim) else { return false }
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: BallPhysics.radius)
        guard let obstacle else { return true }
        return !AngleSceneCalculator.isPathBlocked(from: cue, to: ghost, obstacles: [obstacle], clearance: 2 * BallPhysics.radius)
            && !AngleSceneCalculator.isPathBlocked(from: target, to: aim, obstacles: [obstacle], clearance: 2 * BallPhysics.radius)
    }
}
