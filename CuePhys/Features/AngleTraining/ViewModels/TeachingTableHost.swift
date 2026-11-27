import SwiftUI
import Combine
import SceneKit

/// Geometry that can give a teaching page a new viewing direction after a temporary table edit.
struct TeachingTableCameraReference: Equatable {
    let cue: SIMD3<Float>?
    let target: ObjectIdentifier?
    let targetPosition: SIMD3<Float>?
    let pocket: Int
    let aim: SIMD3<Float>?
}

/// Shared host contract for editable teaching diagrams. Geometry and simulation
/// remain in each model; camera transitions use the daily production rig.
@MainActor
protocol TeachingCameraHost: ObservableObject {
    var scene: AngleTrainingScene { get }
    var cameraMode: AngleTrainingScene.CameraMode { get set }
    var cameraTransitionBusy: Bool { get set }
    var temporaryTopDownActive: Bool { get set }
    var topDownContentRevision: Int { get set }
    var topDownSelectionChanged: Bool { get set }
    var currentPlayerAim: SCNVector3? { get }
    var permitsFirstPersonAddress: Bool { get }
    var usesTeachingObjectObservation: Bool { get }
    var permitsTemporaryTopDown: Bool { get }
    var targetNode: SCNNode? { get }
    var selectedPocketIndex: Int { get }
    func teachingTopDownDidEnd(contentChanged: Bool)
    func trainingObservedTopDown()
}

/// Editing is separate from the shared camera contract so read-only quizzes reuse it.
@MainActor
protocol TeachingTableHost: TeachingCameraHost {
    var selectedTargetKey: String? { get }
    var onTableKeys: [String] { get }
    var draggableBalls: [SCNNode] { get }
    var selectableBalls: [SCNNode] { get }
    var isDragging: Bool { get }
    func suspendTeachingActivity()
    func resumeTeachingActivity()
    func setupScene()
    func selectPocket(at index: Int)
    func selectTarget(key: String)
    func placeFromPalette(_ key: String)
    func palettePlacement(_ key: String, atWorld world: SCNVector3) -> SCNVector3?
    func removeFromTable(_ key: String)
    func dragBegan(node: SCNNode)
    func dragMoved(node: SCNNode, worldPosition: SCNVector3)
    func dragEnded(node: SCNNode)
}

extension TeachingTableHost {
    func beginTableBallDrag(_ node: SCNNode) {
        if node === scene.cueBallNode, cameraMode == .perspective3D {
            scene.cameraRig?.beginP01CueDrag(at: node.simdPosition)
        }
        dragBegan(node: node)
    }

    func endTableBallDrag(_ node: SCNNode) {
        // Finish the page's placement first so the camera uses its legal drop and final shaft.
        dragEnded(node: node)
        if node === scene.cueBallNode {
            scene.cameraRig?.endP01CueDrag(at: node.simdPosition, animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }

    func suspendTeachingActivity() {}
    func resumeTeachingActivity() {}
    /// Reads the exact contact currently rendered by the page's own predictor.
    func solvedContactCloseup(for prediction: ShotPrediction) -> AimCloseupSnapshot? {
        guard let cue = scene.cueBallNode, !cue.isHidden,
              let target = targetNode, !target.isHidden,
              let ghost = scene.ghostBallNode, !ghost.isHidden else { return nil }
        let contact = prediction.firstContact ?? ghost.position
        let points = prediction.cuePath
        // Use the incoming recorded segment, including after a cushion. The
        // original cue-to-contact chord can point in the opposite direction.
        let nearest = points.indices.min { a, b in
            hypotf(points[a].x - contact.x, points[a].z - contact.z)
                < hypotf(points[b].x - contact.x, points[b].z - contact.z)
        }
        let start = nearest.flatMap { $0 > 0 ? points[$0 - 1] : nil } ?? cue.position
        let incoming = AimCloseupSegment(
            start: CGPoint(x: CGFloat(start.x), y: CGFloat(start.z)),
            end: CGPoint(x: CGFloat(contact.x), y: CGFloat(contact.z)))
        return AimCloseupBuilder.solvedContact(
            cue: CGPoint(x: CGFloat(cue.position.x), y: CGFloat(cue.position.z)),
            target: CGPoint(x: CGFloat(target.position.x), y: CGFloat(target.position.z)),
            ghost: CGPoint(x: CGFloat(ghost.position.x), y: CGFloat(ghost.position.z)),
            number: selectedTargetKey.flatMap { PositionPlayBall.number(for: $0) },
            ballRadius: CGFloat(AngleSceneCalculator.ballRadius), incoming: incoming)
    }
}

extension TeachingCameraHost {
    var permitsFirstPersonAddress: Bool { currentPlayerAim != nil }
    var usesTeachingObjectObservation: Bool { false }
    var permitsTemporaryTopDown: Bool { true }
    var permitsTeachingPlayerView: Bool {
        guard let rig = scene.cameraRig else { return false }
        return !rig.p01ShotFrozen || rig.p01RollingShot != nil
    }
    func trainingObservedTopDown() {}
    func teachingTopDownDidEnd(contentChanged: Bool) {
        guard contentChanged, scene.cameraRig?.p01AnchoredTransitions == true else { return }
        selectionCameraChanged()
    }
    func configureTeachingCamera(policy: ShotCameraPolicy = .legacy) {
        scene.cameraRig?.configurePlayerCameraControls(daily: true, policy: policy,
                                                      anchoredP01Transitions: policy == .p01Replayable)
        scene.cameraRig?.setTwoViewViewingContext(UUID())
        scene.cameraRig?.onPlayerTransitionEnded = { [weak self] in self?.cameraTransitionBusy = false }
        scene.cameraRig?.onManualCameraControl = { [weak self] in self?.cameraTransitionBusy = false }
    }

    var isTeachingShotRolling: Bool { scene.cameraRig?.p01RollingShot != nil }

    func updateTeachingStrokeCamera(locked: Bool) {
        guard let rig = scene.cameraRig, rig.p01AnchoredTransitions else { return }
        rig.p01ShotFrozen = locked
        guard !locked, rig.p01RollingShot != nil else { return }
        rig.endP01RollingShot()
        settleTeachingCamera(frameRecommendedTarget: false)
    }

    func beginTeachingRollingCamera(aim: SCNVector3, replaying: Bool, allowsReplayObservation: Bool = false) {
        guard (!replaying || allowsReplayObservation), let rig = scene.cameraRig, rig.p01ShotFrozen,
              let cue = scene.cueBallNode, !cue.isHidden else { return }
        rig.beginP01RollingShot(cue: cue.position, aim: aim)
        // Contact does not change the page's playing phase. Notify the layout
        // so the camera buttons and scene can open only their observation path.
        if rig.p01RollingShot != nil { (objectWillChange as? ObservableObjectPublisher)?.send() }
    }

    func followTeachingAim(spinX: Double, spinY: Double, updateCue: () -> Void) {
        guard cameraMode == .perspective3D, let rig = scene.cameraRig,
              let cue = scene.cueBallNode, !cue.isHidden, let aim = currentPlayerAim else {
            updateCue()
            return
        }
        rig.followP01TableAim(cue: cue.position, aim: aim, fallbackStrike: {
            CueStroke.strikePosition(cue: cue.position, aim: aim, spinX: spinX, spinY: spinY)
        }, updateCue: updateCue)
    }

    func setCameraMode(_ mode: AngleTrainingScene.CameraMode) {
        guard !temporaryTopDownActive else { return }
        let initializesSurface = mode == .perspective3D && !scene.hasPerspectiveView
        cameraMode = mode
        scene.setCameraMode(mode, animated: false, initializePerspective: {
            guard initializesSurface else { return false }
            if self.usesTeachingObjectObservation, self.requestTeachingObjectObservation(animated: false) { return true }
            if self.requestPlayerView(.thirdPerson, animated: false, resetThirdPerson: true) || self.scene.cameraRig?.thirdPersonEntryAwaitsLayout == true { return true }
            self.requestSurfaceOverview()
            return true
        })
    }

    func refreshObservationCameraContext() {
        let cue = scene.cueBallNode.flatMap { $0.isHidden ? nil : $0.position }
        let target = targetNode.flatMap { $0.isHidden ? nil : $0.position }
        scene.cameraRig?.observationCandidates = [cue, target].compactMap { $0 }
        let pockets = AngleSceneCalculator.pocketMarkerPositions(surfaceY: scene.surfaceY)
        scene.cameraRig?.observationPocket = target != nil && pockets.indices.contains(selectedPocketIndex)
            ? (selectedPocketIndex, pockets[selectedPocketIndex]) : nil
    }

    @discardableResult
    func requestPlayerView(_ view: CameraRig.PlayerView, animated: Bool = true,
                           resetThirdPerson: Bool = false, turnPace: P01CameraMotion.TurnPace? = nil) -> Bool {
        let rig = scene.cameraRig
        guard cameraMode == .perspective3D, !temporaryTopDownActive else { return false }
        if let rig, rig.p01RollingShot != nil {
            return rig.selectP01RollingView(view == .firstPerson ? .firstPerson : .thirdPerson,
                animated: animated && !UIAccessibility.isReduceMotionEnabled, resetThirdPerson: resetThirdPerson)
        }
        guard permitsTeachingPlayerView, view != .firstPerson || permitsFirstPersonAddress,
              let cue = scene.cueBallNode, !cue.isHidden, let aim = currentPlayerAim else { return false }
        scene.discardSavedPerspectiveView()
        refreshObservationCameraContext()
        let duration: Float = animated ? (UIAccessibility.isReduceMotionEnabled ? 0.1 : 0.95) : 0
        let accepted = scene.cameraRig?.enterPlayerView(view, cue: cue.position, aim: aim,
            duration: duration, surfaceTravel: 0.5, resetThirdPerson: resetThirdPerson,
            strikeOverride: rig?.usesP01Camera == true && !permitsFirstPersonAddress ? cue.position : nil, turnPace: turnPace) == true
        cameraTransitionBusy = accepted && rig?.isTransitioning == true && rig?.usesP01Camera != true
        return accepted
    }

    @discardableResult
    func requestTeachingObjectObservation(animated: Bool = true) -> Bool {
        guard usesTeachingObjectObservation, cameraMode == .perspective3D, !temporaryTopDownActive,
              let rig = scene.cameraRig, let target = targetNode, !target.isHidden else { return false }
        scene.discardSavedPerspectiveView()
        refreshObservationCameraContext()
        return rig.observeP01Object(at: target.position, toward: rig.observationPocket?.1,
                                    animated: animated && !UIAccessibility.isReduceMotionEnabled)
            || rig.thirdPersonEntryAwaitsLayout
    }

    func requestSurfaceOverview() {
        guard cameraMode == .perspective3D, !temporaryTopDownActive, let rig = scene.cameraRig else { return }
        scene.discardSavedPerspectiveView()
        refreshObservationCameraContext()
        let aim = currentPlayerAim ?? (rig.usesP01Camera ? SCNVector3(0, 0, -1) : nil)
        let cue = scene.cueBallNode.flatMap { $0.isHidden ? nil : $0.position }
        let object = usesTeachingObjectObservation ? targetNode.flatMap { $0.isHidden ? nil : $0.position } : nil
        let anchor = cue ?? object ?? (rig.usesP01Camera ? SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0) : nil)
        cameraTransitionBusy = rig.enterMergedGlobal(aim: aim, cue: anchor)
            && rig.isTransitioning && !rig.usesP01Camera
    }

    func beginCameraObservation() {
        guard cameraMode == .perspective3D, !temporaryTopDownActive,
              let rig = scene.cameraRig, rig.usesTwoViewPoseControl else { return }
        if let shot = rig.p01RollingShot {
            rig.teachingRollingObservation = .held
            rig.prepareTemporaryObservation(cue: SCNVector3(shot.cue), aim: SCNVector3(shot.aim))
        } else if usesTeachingObjectObservation, let object = rig.p01Snapshot?.shot {
            rig.prepareTemporaryObservation(cue: SCNVector3(object.cue), aim: SCNVector3(object.aim))
        } else if let cue = scene.cueBallNode, let aim = currentPlayerAim, !cue.isHidden {
            refreshObservationCameraContext()
            rig.prepareTemporaryObservation(cue: cue.position, aim: aim)
        }
    }

    /// Finish against the settled board after recommendation and aim have both been published.
    func settleTeachingCamera(frameRecommendedTarget: Bool) {
        guard let rig = scene.cameraRig, rig.p01AnchoredTransitions,
              cameraMode == .perspective3D, !temporaryTopDownActive,
              let cue = scene.cueBallNode, !cue.isHidden else { return }
        if rig.teachingRollingObservation != .idle {
            rig.teachingRollingObservation = frameRecommendedTarget ? .frameTargetOnRelease : .settleCueOnRelease
            return
        }
        if frameRecommendedTarget, targetNode?.isHidden == false,
           requestPlayerView(.thirdPerson, resetThirdPerson: true, turnPace: .selection120) { return }
        rig.settleP01Cue(at: cue.position, preservingVisiblePose: true)
    }

    func endCameraObservation() {
        let pending = scene.cameraRig?.teachingRollingObservation
        scene.cameraRig?.teachingRollingObservation = .idle
        guard cameraMode == .perspective3D, !temporaryTopDownActive,
              let rig = scene.cameraRig, rig.usesTwoViewPoseControl else { return }
        let view = rig.twoViewMode
        rig.endTemporaryObservation()
        if pending == .settleCueOnRelease || pending == .frameTargetOnRelease {
            settleTeachingCamera(frameRecommendedTarget: pending == .frameTargetOnRelease)
        } else if view == .firstPerson, !rig.usesP01Camera { requestPlayerView(view) }
    }

    private var teachingCameraReference: TeachingTableCameraReference {
        let target = targetNode.flatMap { $0.isHidden ? nil : $0 }
        return TeachingTableCameraReference(
            cue: scene.cueBallNode.flatMap { $0.isHidden ? nil : $0.simdPosition },
            target: target.map(ObjectIdentifier.init), targetPosition: target?.simdPosition,
            pocket: selectedPocketIndex, aim: currentPlayerAim.map { SIMD3($0.x, $0.y, $0.z) })
    }

    func beginTemporaryTopDown() {
        // Editing may start before a target/solution exists; the fallback sets only
        // the temporary table orientation and never creates a shot or changes aim.
        let aim = currentPlayerAim ?? SCNVector3(0, 0, -1)
        guard cameraMode == .perspective3D, !temporaryTopDownActive, permitsTemporaryTopDown,
              scene.cameraRig?.p01ShotFrozen != true,
              scene.cameraRig?.beginTemporaryTopDown(aim: aim) == true else { return }
        scene.teachingTopDownEntry = teachingCameraReference
        topDownSelectionChanged = false
        temporaryTopDownActive = true
        trainingObservedTopDown()
    }

    func endTemporaryTopDown() {
        guard temporaryTopDownActive else { return }
        scene.cameraRig?.endTemporaryTopDown()
        temporaryTopDownActive = false
        // Viewing alone restores the original pose. A board edit can establish a new legal reference.
        refreshObservationCameraContext()
        let changed = topDownSelectionChanged && scene.teachingTopDownEntry != teachingCameraReference
        scene.teachingTopDownEntry = nil
        teachingTopDownDidEnd(contentChanged: changed)
        topDownSelectionChanged = false
    }

    func selectionCameraChanged() {
        refreshObservationCameraContext()
        guard scene.cameraRig?.isHoldingP01CueDrag != true else { return }
        if temporaryTopDownActive { topDownSelectionChanged = true }
        else if cameraMode == .perspective3D {
            if usesTeachingObjectObservation {
                if !requestTeachingObjectObservation() { requestSurfaceOverview() }
            } else if currentPlayerAim != nil { requestPlayerView(.thirdPerson) }
            else { requestSurfaceOverview() }
        }
    }

}
