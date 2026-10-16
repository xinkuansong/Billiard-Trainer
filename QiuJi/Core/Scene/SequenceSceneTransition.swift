import SceneKit
import UIKit

/// Shared inter-shot rules for drill detail and guided tryout playback.
@MainActor
enum SequenceSceneTransition {
    static let boardActionKey = "sequence.boardChange"
    static let resultHold: TimeInterval = 0.7

    /// Count actual node completions on the main actor, never a parallel timer.
    @MainActor private final class ArrangementCompletion {
        private var remaining: Int
        private let completion: @MainActor () -> Void

        init(count: Int, completion: @escaping @MainActor () -> Void) {
            remaining = count
            self.completion = completion
        }

        func finishedNode() {
            guard remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 { completion() }
        }
    }

    static func cancelArrangement(in scene: AngleTrainingScene) {
        for node in scene.allBallNodes.values { node.removeAction(forKey: boardActionKey) }
    }

    /// Authored board changes are distinct from differences caused by live physics.
    static func requiresBoardChange(after: BoardSnapshot, before: BoardSnapshot) -> Bool {
        guard Set(after.onTable.keys) == Set(before.onTable.keys) else { return true }
        let tolerance = 0.0001 / Double(AngleSceneCalculator.innerLength)
        return before.onTable.contains { key, next in
            guard let previous = after.onTable[key] else { return true }
            return abs(next.x - previous.x) > tolerance || abs(next.y - previous.y) > tolerance
        }
    }

    static func freezeCamera(in scene: AngleTrainingScene) {
        guard let rig = scene.cameraRig else { return }
        rig.restorePerspectiveState(rig.capturePerspectiveState())
    }

    @discardableResult
    static func enterThirdPerson(in scene: AngleTrainingScene, cue: SCNVector3,
                                 aim: SCNVector3, animated: Bool) -> Bool {
        scene.discardSavedPerspectiveView()
        return scene.cameraRig?.enterPlayerView(.thirdPerson, cue: cue, aim: aim,
                                                duration: animated ? 0.95 : 0) == true
    }

    /// Caller owns cancellation/generation checks; finishing must precede camera entry.
    static func arrange(_ board: BoardSnapshot, in scene: AngleTrainingScene,
                        completion: @escaping @MainActor () -> Void) {
        let duration: TimeInterval = UIAccessibility.isReduceMotionEnabled ? 0 : 0.45
        for node in scene.allBallNodes.values { node.removeAllActions() }
        // Hidden/detached balls absent from the next board have no animation to
        // await; an action on a detached node would never receive renderer ticks.
        let nodes = scene.allBallNodes.filter {
            board.onTable[$0.key] != nil || ($0.value.parent != nil && !$0.value.isHidden)
        }
        guard !nodes.isEmpty else { completion(); return }
        let barrier = ArrangementCompletion(count: nodes.count, completion: completion)
        for (key, node) in nodes {
            let action: SCNAction
            if let destination = board.onTable[key] {
                let position = PositionPlayShotSolver.scenePoint(destination, surfaceY: scene.surfaceY)
                if node.isHidden || node.parent == nil || node.opacity < 0.01 {
                    scene.showBall(key: key, scenePosition: position, cuePose: .home)
                    scene.railInventory.reconcile(animated: duration > 0)
                    node.opacity = 0
                }
                let move = SCNAction.move(to: position, duration: duration)
                move.timingMode = .easeInEaseOut
                // Commit the authored arrangement endpoint on the animation thread
                // before its completion can be consumed by the main actor. This is
                // a board change, not a correction of a continuous shot's rest pose.
                action = .sequence([.group([move, .fadeIn(duration: duration)]), .run { node in
                    node.position = position
                    node.opacity = 1
                }])
            } else {
                action = .sequence([.fadeOut(duration: node.isHidden ? 0 : duration), .run { node in
                    node.isHidden = true
                }])
            }
            node.runAction(action, forKey: boardActionKey) {
                Task { @MainActor in barrier.finishedNode() }
            }
        }
    }

    static func finishArrangement(_ board: BoardSnapshot, in scene: AngleTrainingScene) {
        for (key, node) in scene.allBallNodes {
            node.isHidden = board.onTable[key] == nil
            node.opacity = 1
        }
    }
}
