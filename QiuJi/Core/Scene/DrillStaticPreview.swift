import SceneKit
import UIKit

/// Shared “static preview frame” for drill thumbnails + detail first frame.
///
/// Contract (2026-07-29):
/// - Source = representative formation (A1 / difficulty #1 / legacy single), first shot only
/// - Frame = real ball keys + rest cue + line-language v2 + ghost/contact (export-cover parity)
/// - Cue-ball pose pinned to identity for reproducible pixels
/// - Multi-formation drills still expose one list PNG (`drillId.png`)
enum DrillStaticPreview {

    /// Resolved board + first-shot intent for a drill’s list/detail door frame.
    struct Source {
        var board: BoardSnapshot
        var shot: PlannedShot
        /// Formation token (`A1`, `manual01`, or `""` for legacy single-file).
        var token: String
        var kind: Kind

        enum Kind: String {
            case boardSequence
            case shotIntent
            case animation
        }
    }

    struct Applied {
        var source: Source
        var prediction: ShotPrediction?
        var trajectoryNodes: [SCNNode]
        var cueShown: Bool
        /// Overlay inputs (detail page).
        var spinX: Double
        var spinY: Double
        var velocity: Double
    }

    struct Options {
        /// Visual ball scale vs USDZ model.
        /// - List PNG (`thumbnail`): 1.8 for card readability (v24 D-v24-2).
        /// - Detail live (`detail`): 1.0 true size — detail top bar does **not** consume list PNGs.
        var ballScale: Float
        /// Orthographic half-height (scene units). Thumbnail default 0.86; detail 0.77.
        var orthoScale: Double
        var showCue: Bool
        var showGhost: Bool
        /// Force line-language full detail (ignore user preference).
        var trajectoryDetail: TrajectoryDetail

        static let thumbnail = Options(
            ballScale: 1.8, orthoScale: 0.86, showCue: true, showGhost: true,
            trajectoryDetail: .full
        )
        static let detail = Options(
            ballScale: 1.0, orthoScale: 0.77, showCue: true, showGhost: true,
            trajectoryDetail: .full
        )
    }

    // MARK: - Source resolution

    /// Pick representative formation + first-shot intent.
    /// Prefer DrillBoards token `A1` / legacy single / lowest `A*`; never pick
    /// `manual*` / `Snipaste*` when an `A*` or legacy file exists.
    static func resolveSource(for drill: DrillContent, bundle: Bundle = .main) -> Source? {
        let formations = DrillTryoutBoardStore.formations(for: drill.id, bundle: bundle)
        if let formation = DrillTryoutBoardStore.representative(from: formations) {
            let board = formation.steps.first?.before ?? formation.initial
            if let shot = formation.firstShot {
                return Source(board: board, shot: shot, token: formation.token, kind: .boardSequence)
            }
            if let planned = plannedShot(fromIntent: drill, board: board) {
                return Source(board: board, shot: planned, token: formation.token, kind: .boardSequence)
            }
            if let planned = plannedShot(fromAnimation: drill.animation, board: board) {
                return Source(board: board, shot: planned, token: formation.token, kind: .boardSequence)
            }
            // Board-only (no pocket) — still useful for placing balls; lines skipped later.
            let fallback = PlannedShot(
                targetKey: board.targetCandidates.first ?? DrillBoardBuilder.targetKey,
                pocket: drill.animation.pocket,
                velocity: Double(DrillShotResolver.defaultVelocity)
            )
            return Source(board: board, shot: fallback, token: formation.token, kind: .boardSequence)
        }

        if let board = DrillBoardBuilder.board(for: drill),
           let planned = plannedShot(fromIntent: drill, board: board) {
            return Source(board: board, shot: planned, token: "", kind: .shotIntent)
        }
        if let board = DrillBoardBuilder.board(for: drill),
           let planned = plannedShot(fromAnimation: drill.animation, board: board) {
            return Source(board: board, shot: planned, token: "", kind: .animation)
        }
        return nil
    }

    // MARK: - Apply to scene

    /// Place balls, draw aim/pot lines + ghost, show rest cue. Caller owns scene lifetime.
    /// Pass `prediction` when already solved (detail page) to avoid a second simulate.
    /// Set `placeBalls` false when balls are already seated (e.g. detail replay reset) so
    /// `ballScale` is not applied repeatedly.
    @MainActor
    @discardableResult
    static func apply(
        source: Source,
        to scene: AngleTrainingScene,
        options: Options,
        prediction precomputed: ShotPrediction? = nil,
        placeBalls: Bool = true
    ) -> Applied {
        scene.setupVisualizationNodes()
        scene.hideAllVisualization()
        scene.hideCueStick()

        if placeBalls {
            scene.hideAllBalls()
            placeBoard(source.board, on: scene, ballScale: options.ballScale)
        }
        scene.setCueBallHomeOrientation(BallSpinIntegrator.identityOrientation, apply: true)

        if let rig = scene.cameraRig {
            rig.topDownOrthographicScale = options.orthoScale
            rig.topDownPanOffset = .zero
            rig.applyTopDown2D()
        }

        var nodes: [SCNNode] = []
        let prediction = precomputed ?? PositionPlayShotSolver.solve(
            before: source.board, shot: source.shot, surfaceY: scene.surfaceY
        )

        if let pred = prediction, pred.feasible {
            TrajectoryRenderer.draw(
                prediction: pred,
                options: .positionPlay,
                context: TrajectoryRenderer.Context(
                    prediction: pred,
                    targetKey: source.shot.targetKey,
                    pocket: source.shot.isFree ? nil : source.shot.pocket,
                    surfaceY: scene.surfaceY,
                    showGhost: options.showGhost && !source.shot.isFree
                ),
                scene: scene,
                into: &nodes,
                detailOverride: options.trajectoryDetail
            )
        }

        var cueShown = false
        if options.showCue, let pred = prediction, pred.feasible {
            cueShown = showCueAtRest(
                scene: scene, shot: source.shot, prediction: pred
            )
        }

        return Applied(
            source: source,
            prediction: prediction,
            trajectoryNodes: nodes,
            cueShown: cueShown,
            spinX: source.shot.spinX,
            spinY: source.shot.spinY,
            velocity: source.shot.velocity
        )
    }

    /// Convenience: resolve + apply.
    @MainActor
    static func apply(
        drill: DrillContent,
        to scene: AngleTrainingScene,
        options: Options,
        bundle: Bundle = .main
    ) -> Applied? {
        guard let source = resolveSource(for: drill, bundle: bundle) else { return nil }
        return apply(source: source, to: scene, options: options)
    }

    // MARK: - Cue at rest (export `showCueAtRest` parity)

    @MainActor
    @discardableResult
    static func showCueAtRest(
        scene: AngleTrainingScene,
        shot: PlannedShot,
        prediction: ShotPrediction
    ) -> Bool {
        guard let cueNode = scene.allBallNodes[PositionPlayBall.cueKey], !cueNode.isHidden,
              let aim = aimDirection(path: prediction.cuePath, from: cueNode.position)
        else {
            scene.hideCueStick()
            return false
        }
        let strikePos = CueStroke.strikePosition(
            cue: cueNode.position, aim: aim, spinX: shot.spinX
        )
        let obstacles = scene.cueObstacleCenters(excludingStrikeNear: strikePos)
        switch CueStick.requiredElevation(
            cueBallPosition: strikePos, aimDirection: aim, obstacleCenters: obstacles
        ) {
        case .blocked:
            scene.hideCueStick()
            return false
        case .angle(let elev):
            scene.updateCueStick(
                cueBallPosition: strikePos, aimDirection: aim, pullBack: 0,
                elevationOverride: elev
            )
            return true
        }
    }

    static func aimDirection(path: [SCNVector3], from cue: SCNVector3) -> SCNVector3? {
        for pt in path {
            let dx = pt.x - cue.x, dz = pt.z - cue.z
            let d = sqrtf(dx * dx + dz * dz)
            if d > 0.02 { return SCNVector3(dx / d, 0, dz / d) }
        }
        return nil
    }

    // MARK: - Board helpers

    @MainActor
    static func placeBoard(_ board: BoardSnapshot, on scene: AngleTrainingScene, ballScale: Float) {
        for (key, pt) in board.onTable {
            let p = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: pt.x, y: pt.y), surfaceY: scene.surfaceY
            )
            scene.showBall(
                key: key, scenePosition: p,
                cuePose: PositionPlayBall.isCue(key) ? .home : .home
            )
            if ballScale != 1, let node = scene.allBallNodes[key] {
                node.scale = SCNVector3(
                    node.scale.x * ballScale,
                    node.scale.y * ballScale,
                    node.scale.z * ballScale
                )
            }
        }
        if ballScale != 1, let ghost = scene.ghostBallNode {
            ghost.scale = SCNVector3(
                ghost.scale.x * ballScale,
                ghost.scale.y * ballScale,
                ghost.scale.z * ballScale
            )
        }
    }

    // MARK: - Intent → PlannedShot

    private static func plannedShot(fromIntent drill: DrillContent, board: BoardSnapshot) -> PlannedShot? {
        guard let shot = drill.shotIntent?.shots.first else { return nil }
        let targetKey = nearestObjectKey(to: shot.target, in: board)
            ?? board.targetCandidates.first
            ?? DrillBoardBuilder.targetKey
        let spin = shot.spin
        return PlannedShot(
            targetKey: targetKey,
            pocket: shot.pocket,
            velocity: shot.velocity,
            spinX: spin?.x ?? 0,
            spinY: spin?.y ?? 0
        )
    }

    private static func plannedShot(fromAnimation animation: DrillAnimation,
                                    board: BoardSnapshot) -> PlannedShot? {
        guard ShotIntent.pocketIndex(for: animation.pocket) != nil else { return nil }
        let targetKey = nearestObjectKey(to: animation.targetBall.start, in: board)
            ?? board.targetCandidates.first
            ?? DrillBoardBuilder.targetKey
        return PlannedShot(
            targetKey: targetKey,
            pocket: animation.pocket,
            velocity: Double(DrillShotResolver.defaultVelocity)
        )
    }

    private static func nearestObjectKey(to point: CanvasPoint, in board: BoardSnapshot) -> String? {
        var best: (String, Double)?
        for (key, pt) in board.onTable where !PositionPlayBall.isCue(key) {
            let dx = pt.x - point.x, dy = pt.y - point.y
            let d = dx * dx + dy * dy
            if best == nil || d < best!.1 { best = (key, d) }
        }
        return best?.0
    }
}
