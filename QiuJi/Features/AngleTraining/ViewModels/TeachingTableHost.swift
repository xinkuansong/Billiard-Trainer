import SwiftUI
import SceneKit

/// Shared host contract for editable teaching diagrams. Geometry and simulation
/// remain in each model; camera transitions use the daily production rig.
@MainActor
protocol TeachingTableHost: ObservableObject {
    var scene: AngleTrainingScene { get }
    var cameraMode: AngleTrainingScene.CameraMode { get set }
    var cameraTransitionBusy: Bool { get set }
    var temporaryTopDownActive: Bool { get set }
    var topDownContentRevision: Int { get set }
    var topDownSelectionChanged: Bool { get set }
    var currentPlayerAim: SCNVector3? { get }
    var targetNode: SCNNode? { get }
    var selectedTargetKey: String? { get }
    var selectedPocketIndex: Int { get }
    var onTableKeys: [String] { get }
    var draggableBalls: [SCNNode] { get }
    var selectableBalls: [SCNNode] { get }
    var isDragging: Bool { get }
    func setupScene()
    func selectPocket(at index: Int)
    func selectTarget(key: String)
    func placeFromPalette(_ key: String)
    func removeFromTable(_ key: String)
    func dragBegan(node: SCNNode)
    func dragMoved(node: SCNNode, worldPosition: SCNVector3)
    func dragEnded(node: SCNNode)
}

extension TeachingTableHost {
    func configureTeachingCamera() {
        scene.cameraRig?.configurePlayerCameraControls(daily: true)
        scene.cameraRig?.setTwoViewViewingContext(UUID())
        scene.cameraRig?.onPlayerTransitionEnded = { [weak self] in self?.cameraTransitionBusy = false }
        scene.cameraRig?.onManualCameraControl = { [weak self] in self?.cameraTransitionBusy = false }
    }

    func setCameraMode(_ mode: AngleTrainingScene.CameraMode) {
        guard !temporaryTopDownActive else { return }
        let initializesSurface = mode == .perspective3D && !scene.hasPerspectiveView
        cameraMode = mode
        scene.setCameraMode(mode, animated: false, initializePerspective: {
            guard initializesSurface else { return false }
            if self.requestPlayerView(.thirdPerson, animated: false) { return true }
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
    func requestPlayerView(_ view: CameraRig.PlayerView, animated: Bool = true) -> Bool {
        guard cameraMode == .perspective3D, !temporaryTopDownActive,
              let cue = scene.cueBallNode, !cue.isHidden, let aim = currentPlayerAim else { return false }
        scene.discardSavedPerspectiveView()
        refreshObservationCameraContext()
        let duration: Float = animated ? (UIAccessibility.isReduceMotionEnabled ? 0.1 : 0.95) : 0
        let accepted = scene.cameraRig?.enterPlayerView(view, cue: cue.position, aim: aim,
            duration: duration, surfaceTravel: 0.5) == true
        cameraTransitionBusy = accepted && scene.cameraRig?.isTransitioning == true
        return accepted
    }

    func requestSurfaceOverview() {
        guard cameraMode == .perspective3D, !temporaryTopDownActive, let rig = scene.cameraRig else { return }
        scene.discardSavedPerspectiveView()
        refreshObservationCameraContext()
        cameraTransitionBusy = rig.enterMergedGlobal(aim: currentPlayerAim, cue: scene.cueBallNode?.position)
            && rig.isTransitioning
    }

    func beginCameraObservation() {
        guard cameraMode == .perspective3D, !temporaryTopDownActive,
              let rig = scene.cameraRig, rig.usesTwoViewPoseControl,
              let cue = scene.cueBallNode, let aim = currentPlayerAim else { return }
        refreshObservationCameraContext()
        rig.prepareTemporaryObservation(cue: cue.position, aim: aim)
    }

    func endCameraObservation() {
        guard cameraMode == .perspective3D, !temporaryTopDownActive,
              let rig = scene.cameraRig, rig.usesTwoViewPoseControl else { return }
        let view = rig.twoViewMode
        rig.endTemporaryObservation()
        if view == .firstPerson { requestPlayerView(view) }
    }

    func beginTemporaryTopDown() {
        guard cameraMode == .perspective3D, !temporaryTopDownActive,
              let aim = currentPlayerAim, scene.cameraRig?.beginTemporaryTopDown(aim: aim) == true else { return }
        topDownSelectionChanged = false
        temporaryTopDownActive = true
    }

    func endTemporaryTopDown() {
        guard temporaryTopDownActive else { return }
        scene.cameraRig?.endTemporaryTopDown()
        temporaryTopDownActive = false
        if topDownSelectionChanged { selectionCameraChanged() }
        topDownSelectionChanged = false
    }

    func selectionCameraChanged() {
        refreshObservationCameraContext()
        if temporaryTopDownActive { topDownSelectionChanged = true }
        else if cameraMode == .perspective3D {
            if currentPlayerAim != nil { requestPlayerView(.thirdPerson) }
            else { requestSurfaceOverview() }
        }
    }

}
