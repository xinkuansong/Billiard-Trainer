import SceneKit

/// Production uses only the recorded strike. Authoring intent is retained for
/// editing, ball-name mapping and result labels, never for re-aiming.
enum SequenceReplayResolver {
    static func solve(step: SequenceStep, before: BoardSnapshot? = nil,
                      surfaceY: Float) -> ShotPrediction? {
        guard let saved = step.recordedDirection, saved.isValid else {
            var failure = ShotPrediction()
            failure.feasible = false
            failure.infeasibleReason = "该杆缺少有效的录制方向，请重新保存序列"
            return failure
        }
        let board = before ?? step.before
        let shot = step.shot
        guard let cuePoint = board.onTable[PositionPlayBall.cueKey] else { return nil }
        let cue = PositionPlayShotSolver.scenePoint(cuePoint, surfaceY: surfaceY)
        let direction = SCNVector3(saved.x, 0, saved.z)
        if shot.isFree {
            let balls = board.onTable.compactMap { key, point -> ObstacleBall? in
                guard key != PositionPlayBall.cueKey else { return nil }
                return ObstacleBall(name: key, position: PositionPlayShotSolver.scenePoint(point, surfaceY: surfaceY))
            }
            return ShotPredictor.simulateFree(cueBall: cue, aimDir: direction,
                velocity: Float(shot.velocity), spinX: Float(shot.spinX), spinY: Float(shot.spinY),
                surfaceY: surfaceY, balls: balls, recordedStrikeDirection: direction)
        }
        guard let targetPoint = board.onTable[shot.targetKey],
              let pocketIndex = ShotIntent.pocketIndex(for: shot.pocket) else { return nil }
        let target = PositionPlayShotSolver.scenePoint(targetPoint, surfaceY: surfaceY)
        let obstacles = board.onTable.compactMap { key, point -> ObstacleBall? in
            guard key != PositionPlayBall.cueKey, key != shot.targetKey else { return nil }
            return ObstacleBall(name: key, position: PositionPlayShotSolver.scenePoint(point, surfaceY: surfaceY))
        }
        let input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
            velocity: Float(shot.velocity), spinX: Float(shot.spinX), spinY: Float(shot.spinY),
            surfaceY: surfaceY, obstacles: obstacles)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)[pocketIndex]
        let ghost = ShotPredictor.ghostAlongFinalAim(cue: cue, target: target,
            aim: direction, ballRadius: BallPhysics.radius) ?? target
        let context = ShotPredictor.AimContext(aimPoint: pocket, ghost: ghost, aimDir: direction,
            geometry: TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY), pocketCenter: pocket)
        var seed = ShotPrediction()
        seed.pocketAimPoint = pocket
        seed.ghost = ghost
        return ShotPredictor.buildPrediction(finalAim: direction, context: context, input: input,
            result: seed, maxEvents: 500, maxTime: 15)
    }
}
