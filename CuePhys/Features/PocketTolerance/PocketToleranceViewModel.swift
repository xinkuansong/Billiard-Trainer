import SwiftUI
import SceneKit

@MainActor
final class PocketToleranceViewModel: TeachingTableHost, BoardMemoryHosting {
    let boardMemory = BoardMemory(page: "tolerance")
    let scene = AngleTrainingScene()
    private let centerRoot = SCNNode()
    private let boundaryRoot = SCNNode()
    private let standardPipeRoot = SCNNode()
    private var markers: [SCNNode] = []
    private var pocketsByBall: [String: Int] = [:]
    private var initialized = false
    private var suspended = false
    private weak var draggedNode: SCNNode?
    private var generation = 0
    private var pending: Request?
    private var computing = false
    private static let calculationQueue = DispatchQueue(label: "qiuji.pocket-tolerance", qos: .userInitiated)
    private struct Request: Sendable { let generation: Int; let x, z: Float; let pocket: Int }

    @Published private(set) var onTableKeys: [String] = []
    @Published private(set) var selectedTargetKey: String?
    @Published var selectedPocketIndex = -1
    @Published private(set) var isDragging = false
    @Published private(set) var angleText = "—"
    @Published private(set) var message = "点击袋口选择目标"
    @Published private(set) var result: PocketToleranceGeometry.Result = .unavailable
    @Published var cameraMode: AngleTrainingScene.CameraMode = .topDown2DRotated
    @Published var cameraTransitionBusy = false
    @Published var temporaryTopDownActive = false
    @Published var topDownContentRevision = 0
    var topDownSelectionChanged = false
    var currentPlayerAim: SCNVector3? { nil }
    var usesTeachingObjectObservation: Bool { true }
    var targetNode: SCNNode? { selectedTargetKey.flatMap { scene.allBallNodes[$0] } }
    var draggableBalls: [SCNNode] { onTableKeys.compactMap { scene.allBallNodes[$0] } }
    var selectableBalls: [SCNNode] { draggableBalls }
    var boundaryCount: Int { boundaryRoot.childNodes.count }
    var centerLineCount: Int { centerRoot.childNodes.count }
    var standardPipeCount: Int { standardPipeRoot.childNodes.count }

    func setupScene() {
        guard !initialized else { return }
        initialized = true
        scene.configureReferenceTableRendering()
        scene.configureShotAwareCamera()
        scene.setupScene()
        configureTeachingCamera(policy: .p01Replayable)
        scene.setupVisualizationNodes()
        scene.hideAllBalls()
        scene.hideCueStick()
        centerRoot.name = "pocketTolerance.center"
        boundaryRoot.name = "pocketTolerance.boundaries"
        standardPipeRoot.name = "pocketTolerance.standardPipe"
        scene.rootNode.addChildNode(centerRoot)
        scene.rootNode.addChildNode(boundaryRoot)
        scene.rootNode.addChildNode(standardPipeRoot)
        markers = scene.addPocketMarkers()
        scene.showBall(key: "_3", scenePosition: SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0))
        onTableKeys = ["_3"]
        selectTarget(key: "_3")
    }

    func selectTarget(key: String) {
        guard !suspended, onTableKeys.contains(key) else { return }
        selectedTargetKey = key
        selectedPocketIndex = pocketsByBall[key] ?? -1
        scene.setCurrentTargetNumber(PositionPlayBall.number(for: key))
        scene.confirmBallSelection(key: key)
        refreshMarkers()
        scheduleCalculation()
        refreshObjectObservation()
    }
    func selectPocket(at index: Int) {
        guard !suspended, let key = selectedTargetKey, (0..<6).contains(index) else { return }
        pocketsByBall[key] = index
        selectedPocketIndex = index
        refreshMarkers()
        scene.confirmPocketSelection(at: index, source: .manual)
        scheduleCalculation()
        refreshObjectObservation()
    }
    private func refreshObjectObservation() {
        if scene.cameraRig?.overviewControlSelected != true { selectionCameraChanged() }
        else { refreshObservationCameraContext() }
    }
    private func refreshMarkers() {
        for (i, marker) in markers.enumerated() {
            scene.setPocketHighlight(marker, style: i == selectedPocketIndex ? .selected : .viable, confirmsSelection: false)
        }
    }
    func paletteTapped(_ key: String) {
        if onTableKeys.contains(key) { selectTarget(key: key) }
        else { placeFromPalette(key) }
    }
    func placeFromPalette(_ key: String) {
        guard !onTableKeys.contains(key), !PositionPlayBall.isCue(key) else { return }
        for x in stride(from: Float(-0.8), through: 0.8, by: 0.2) {
            for z in stride(from: Float(-0.4), through: 0.4, by: 0.16) {
                if let position = palettePlacement(key, atWorld: SCNVector3(x, scene.surfaceY, z)) {
                    placeFromPalette(key, atWorld: position)
                    return
                }
            }
        }
    }
    func placeFromPalette(_ key: String, atWorld point: SCNVector3) {
        guard !suspended, !PositionPlayBall.isCue(key), !onTableKeys.contains(key),
              let position = palettePlacement(key, atWorld: point) else { return }
        scene.showBall(key: key, scenePosition: position)
        onTableKeys.append(key)
        selectTarget(key: key)
    }
    func removeFromTable(_ key: String) {
        guard !suspended, onTableKeys.contains(key) else { return }
        scene.hideBall(key: key)
        onTableKeys.removeAll { $0 == key }
        pocketsByBall[key] = nil
        if selectedTargetKey == key {
            selectedTargetKey = nil
            selectedPocketIndex = -1
            if let next = onTableKeys.first { selectTarget(key: next) }
            else { scene.setCurrentTargetNumber(nil); refreshMarkers(); scheduleCalculation(); refreshObjectObservation() }
        }
    }
    func palettePlacement(_ key: String, atWorld point: SCNVector3) -> SCNVector3? {
        guard !PositionPlayBall.isCue(key), scene.allBallNodes[key] != nil,
              point.x.isFinite, point.z.isFinite else { return nil }
        let r = AngleSceneCalculator.ballRadius
        let hx = AngleSceneCalculator.innerLength / 2 - r, hz = AngleSceneCalculator.innerWidth / 2 - r
        var p = SCNVector3(max(-hx, min(hx, point.x)), scene.surfaceY + r, max(-hz, min(hz, point.z)))
        p = AngleSceneCalculator.clampAwayFromPockets(p, surfaceY: scene.surfaceY)
        guard abs(p.x) <= hx + 0.000001, abs(p.z) <= hz + 0.000001,
              !onTableKeys.contains(where: { other in
                  other != key && scene.allBallNodes[other].map {
                      AngleSceneCalculator.horizontalDistance(p, $0.position) < 2 * r
                  } == true
              }) else { return nil }
        return p
    }
    func dragBegan(node: SCNNode) {
        boardMemory.save()
        guard !suspended, let key = scene.ballKey(for: node), onTableKeys.contains(key) else { return }
        if selectedTargetKey != key { selectTarget(key: key) }
        draggedNode = node; isDragging = true
        TableBallPulse.beginDrag(node)
    }
    func dragMoved(node: SCNNode, worldPosition: SCNVector3) {
        guard !suspended, node === draggedNode, let key = scene.ballKey(for: node),
              let position = palettePlacement(key, atWorld: worldPosition) else { return }
        node.position = position
        scheduleCalculation()
    }
    func dragEnded(node: SCNNode) {
        defer { boardMemory.save() }
        isDragging = false; draggedNode = nil
        TableBallPulse.endDrag(node)
        guard !suspended else { return }
        scheduleCalculation()
        refreshObjectObservation()
    }
    func teachingTopDownDidEnd(contentChanged: Bool) {
        if contentChanged { refreshObjectObservation() }
    }
    func suspendTeachingActivity() {
        suspended = true; generation += 1; pending = nil
        isDragging = false
        if let draggedNode { TableBallPulse.restore(draggedNode) }
        draggedNode = nil
    }
    func resumeTeachingActivity() {
        suspended = false
        scheduleCalculation()
    }
    private func scheduleCalculation() {
        generation += 1
        pending = nil
        centerRoot.childNodes.forEach { $0.removeFromParentNode() }
        boundaryRoot.childNodes.forEach { $0.removeFromParentNode() }
        standardPipeRoot.childNodes.forEach { $0.removeFromParentNode() }
        angleText = "—"; result = .unavailable
        guard let target = targetNode else { message = "从球库添加目标球"; return }
        guard selectedPocketIndex >= 0 else { message = "点击袋口选择目标"; return }
        guard !suspended else { return }
        message = ""
        pending = Request(generation: generation, x: target.position.x, z: target.position.z, pocket: selectedPocketIndex)
        startLatestCalculation()
    }
    private func startLatestCalculation() {
        guard !computing, !suspended, let request = pending else { return }
        pending = nil; computing = true
        Self.calculationQueue.async { [weak self] in
            let result = PocketToleranceGeometry.evaluate(x: request.x, z: request.z, pocket: request.pocket)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.computing = false
                if !self.suspended, request.generation == self.generation { self.apply(result) }
                self.startLatestCalculation()
            }
        }
    }
    private func apply(_ result: PocketToleranceGeometry.Result) {
        self.result = result
        switch result {
        case .window(let window):
            angleText = PocketToleranceGeometry.displayDegrees(window.degrees)
            message = ""
            drawPipe(window)
        case .noStraightWindow:
            if drawReferencePipeIfAvailable() {
                angleText = "0°"
                message = ""
            } else {
                message = "暂无直线管道；袋角附近暂无法评估"
            }
        case .unavailable:
            if drawReferencePipeIfAvailable() {
                angleText = "0°"
                message = ""
            } else {
                message = "当前球位暂无法评估"
            }
        }
        topDownContentRevision &+= 1
    }

    private func drawPipe(_ window: PocketToleranceGeometry.Window) {
        centerRoot.addChildNode(addVisibleLine(window.center, dashed: false,
            color: UIColor.white.withAlphaComponent(0.55), radius: 0.0006))
        for edge in window.edges {
            boundaryRoot.addChildNode(addVisibleLine(edge, dashed: false, color: .white, radius: 0.0007))
        }
        for edge in window.standardEdges {
            standardPipeRoot.addChildNode(addVisibleLine(edge, dashed: true,
                color: UIColor.white.withAlphaComponent(0.8), radius: 0.00055))
        }
    }

    @discardableResult
    private func drawReferencePipeIfAvailable() -> Bool {
        guard let target = targetNode, selectedPocketIndex >= 0,
              let window = PocketToleranceGeometry.referenceWindow(
                x: target.position.x, z: target.position.z, pocket: selectedPocketIndex) else { return false }
        drawPipe(window)
        return true
    }

    /// Table assists use the same clipped cloth surface as the aiming pipe.
    /// Keeping the line in table placement is important here. A spatial
    /// fallback would draw the untrimmed extension over the cushion at a
    /// corner-pocket entry.
    private func addVisibleLine(_ edge: PocketToleranceGeometry.Edge, dashed: Bool,
                                color: UIColor, radius: Float) -> SCNNode {
        let start = SCNVector3(edge.startX, scene.surfaceY, edge.startZ)
        let end = SCNVector3(edge.endX, scene.surfaceY, edge.endZ)
        if dashed {
            return scene.addDashedLine(from: start, to: end, color: color, radius: radius,
                placement: .table, layer: .aiming)
        } else {
            return scene.addLine(from: start, to: end, color: color, radius: radius,
                placement: .table, layer: .aiming)
        }
    }
}

extension PocketToleranceViewModel {
    typealias SavedBoard = SavedObservationBoard
    var savedBoard: SavedBoard? {
        guard !isDragging else { return nil }
        return .init(board: SavedObservationBoard.capture(scene), target: selectedTargetKey, pockets: pocketsByBall)
    }
    func restoreSavedBoard(_ value: SavedBoard) throws {
        try value.validate()
        guard value.board.onTable[PositionPlayBall.cueKey] == nil else { throw CocoaError(.coderReadCorrupt) }
        suspendTeachingActivity(); suspended = false
        value.apply(to: scene)
        onTableKeys = PositionPlayBall.objectKeys.filter { value.board.onTable[$0] != nil }
        pocketsByBall = value.pockets
        selectedTargetKey = value.target
        selectedPocketIndex = value.target.flatMap { value.pockets[$0] } ?? -1
        scene.setCurrentTargetNumber(value.target.flatMap(PositionPlayBall.number(for:)))
        refreshMarkers(); scheduleCalculation(); refreshObjectObservation()
    }
    func resetRememberedBoard() {
        suspendTeachingActivity(); suspended = false
        scene.hideAllBalls(); pocketsByBall = [:]
        scene.showBall(key: "_3", scenePosition: SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0))
        onTableKeys = ["_3"]; selectTarget(key: "_3")
    }
}
