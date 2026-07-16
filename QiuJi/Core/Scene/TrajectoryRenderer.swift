import SceneKit

/// Shared prediction trajectory drawing (C3 / D2).
/// Composer / Silu / PlanThree use `.positionPlay`; Snooker uses `.snookerDefense`
/// so defense semantics stay intentional but are no longer an implicit fork.
enum TrajectoryRenderer {

    enum GhostSource: Equatable {
        /// Ideal ghost-ball center (`ShotPrediction.ghost`).
        case ghost
        /// Cue ball position at first contact (`ShotPrediction.firstContact`).
        case firstContact
    }

    /// How `extraBallPaths` are filtered against `TrajectoryDetail`.
    enum ExtraBallMode: Equatable {
        /// Only when detail == `.full` (Composer / Silu / PlanThree).
        case fullOnly
        /// `.core` → target key only; `.full` → all; `.minimal` → none (Snooker).
        case coreTargetAndFull
    }

    struct Options {
        var includeObjectPath: Bool
        var extendToPocketRim: Bool
        var ghostSource: GhostSource
        var extraBallMode: ExtraBallMode
        /// When true, ghost is hidden unless the target ball node is visible (Snooker).
        var requireVisibleTargetForGhost: Bool

        /// Full potting semantics: object path + rim extend + ghost from `.ghost`.
        static let positionPlay = Options(
            includeObjectPath: true,
            extendToPocketRim: true,
            ghostSource: .ghost,
            extraBallMode: .fullOnly,
            requireVisibleTargetForGhost: false
        )

        /// Defense semantics (D2): no object path, ghost at first contact.
        static let snookerDefense = Options(
            includeObjectPath: false,
            extendToPocketRim: false,
            ghostSource: .firstContact,
            extraBallMode: .coreTargetAndFull,
            requireVisibleTargetForGhost: true
        )
    }

    struct Context {
        let prediction: ShotPrediction
        let targetKey: String
        let pocket: String?
        let surfaceY: Float
        /// When false, skip ghost placement (e.g. Composer free-ball aim).
        var showGhost: Bool = true
    }

    @MainActor
    static func draw(
        prediction p: ShotPrediction,
        options: Options,
        context: Context,
        scene: AngleTrainingScene,
        into nodes: inout [SCNNode]
    ) {
        let detail = UserPreferences.shared.trajectoryDetail
        scene.addCueTrajectory(p.cuePath, contact: p.firstContact, detail: detail, into: &nodes)

        if options.includeObjectPath, detail != .minimal {
            var objPath = p.objectPath
            if options.extendToPocketRim, p.objectPocketed,
               let pocket = context.pocket,
               let pocketIndex = ShotIntent.pocketIndex(for: pocket) {
                objPath = PositionPlayShotSolver.extendPathToPocketRim(
                    objPath, pocketIndex: pocketIndex, surfaceY: context.surfaceY
                )
            }
            scene.addObjectTrajectory(objPath, ballKey: context.targetKey, into: &nodes)
        }

        appendExtraBallPaths(
            p.extraBallPaths, detail: detail, mode: options.extraBallMode,
            targetKey: context.targetKey, scene: scene, into: &nodes
        )

        placeGhost(
            prediction: p, options: options, context: context, scene: scene
        )

        if UserPreferences.shared.showSeparationAngle {
            scene.addSeparationAngleLine(for: p, into: &nodes)
        }
    }

    // MARK: - Internals

    private static func appendExtraBallPaths(
        _ paths: [String: [SCNVector3]],
        detail: TrajectoryDetail,
        mode: ExtraBallMode,
        targetKey: String,
        scene: AngleTrainingScene,
        into nodes: inout [SCNNode]
    ) {
        switch mode {
        case .fullOnly:
            guard detail == .full else { return }
            for (key, pts) in paths {
                scene.addObjectTrajectory(pts, ballKey: key, into: &nodes)
            }
        case .coreTargetAndFull:
            guard detail != .minimal else { return }
            for (key, pts) in paths {
                if detail == .core, key != targetKey { continue }
                scene.addObjectTrajectory(pts, ballKey: key, into: &nodes)
            }
        }
    }

    private static func placeGhost(
        prediction p: ShotPrediction,
        options: Options,
        context: Context,
        scene: AngleTrainingScene
    ) {
        guard context.showGhost, let ghost = scene.ghostBallNode else {
            scene.ghostBallNode?.isHidden = true
            return
        }
        let ghostCenter: SCNVector3
        switch options.ghostSource {
        case .ghost:
            ghostCenter = p.ghost
        case .firstContact:
            guard let contact = p.firstContact else {
                ghost.isHidden = true
                return
            }
            ghostCenter = contact
        }
        let target = scene.allBallNodes[context.targetKey]
        let targetVisible = target.map { !$0.isHidden } ?? false
        if options.requireVisibleTargetForGhost, !targetVisible {
            ghost.isHidden = true
            return
        }
        ghost.position = SCNVector3(
            ghostCenter.x,
            context.surfaceY + AngleSceneCalculator.ballRadius,
            ghostCenter.z
        )
        ghost.isHidden = false
        if let target, targetVisible {
            scene.updateContactDot(ghostCenter: ghost.position, targetCenter: target.position)
        }
    }
}
