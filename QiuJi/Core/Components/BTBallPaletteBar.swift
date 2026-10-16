import SwiftUI
import SceneKit

// MARK: - Metrics (G21 / D7)

/// Shared ball-palette metrics. Diameters are the only two tiers (D7):
/// regular 36 is the App-wide interactive / decorative / reference default;
/// compact 30 is selected by `ShotStageMetrics.paletteDiameter` when the available
/// scene width is at most 390pt. The slot remains at least 44pt in both tiers.
enum BTBallPaletteMetrics {
    /// Compact visual tier; hit testing remains decoupled through `minimumHitSize`.
    static let compactDiameter: CGFloat = 30
    static let regularDiameter: CGFloat = 36
    static let columns = 8
    // Compact the gaps, not the balls or the page's reserved table area.
    static let rowSpacing: CGFloat = 0
    static let minimumHitSize: CGFloat = 44
    static let dragMinimumDistance: CGFloat = 10
    static let faceStroke = Color.white.opacity(0.18)
    static let faceStrokeWidth: CGFloat = 0.5
    static let dimmedOpacity: Double = 0.3
    static let ghostSuccessLineWidth: CGFloat = 2.5
    static let ghostIdleLineWidth: CGFloat = 1
    static let ghostIdleStroke = Color.white.opacity(0.4)

    static func slotHeight(for diameter: CGFloat) -> CGFloat {
        max(minimumHitSize, diameter + 2)
    }
}

// MARK: - Drag ghost (shared overlay)

/// Floating ghost that follows the finger during a palette drag.
struct BTBallPaletteDragGhost: View {
    let key: String
    let location: CGPoint
    let overTable: Bool
    let placement: BTPalettePlacement?
    let projector: TableProjector

    var body: some View {
        let diameter = placement?.diameter ?? BTBallPaletteMetrics.regularDiameter
        BTPaletteBallModelView(key: key, projector: projector, placement: placement)
            .frame(width: diameter + 2, height: diameter + 2)
            .position(placement?.location ?? location)
            .allowsHitTesting(false)
    }
}

/// The actual table mesh/material, with the same light rig and camera orientation.
/// A separate render tree keeps dragging a preview out of gameplay/solver state.
final class BTPaletteBallModel {
    let scene = SCNScene()
    let ball: SCNNode
    let camera = SCNNode()

    init?(source: AngleTrainingScene, key: String, camera sourceCamera: SCNNode) {
        guard let sourceBall = source.allBallNodes[key] else { return nil }
        ball = sourceBall.clone()
        ball.enumerateHierarchy { node, _ in
            node.removeAllActions()
            node.physicsBody = nil
            if let geometry = node.geometry {
                let copy = geometry.copy() as! SCNGeometry
                copy.materials = geometry.materials
                node.geometry = copy
            }
        }
        TableBallPulse.restore(ball)
        source.restoreNodePose(ball)
        ball.isHidden = false
        ball.opacity = 1
        scene.rootNode.addChildNode(ball)
        scene.background.contents = UIColor.clear
        scene.lightingEnvironment.contents = source.lightingEnvironment.contents
        scene.lightingEnvironment.intensity = source.lightingEnvironment.intensity
        scene.lightingEnvironment.contentsTransform = source.lightingEnvironment.contentsTransform
        source.rootNode.enumerateHierarchy { node, _ in
            guard let light = node.light else { return }
            let copy = SCNNode()
            copy.light = light.copy() as? SCNLight
            copy.simdTransform = node.presentation.simdWorldTransform
            scene.rootNode.addChildNode(copy)
        }
        camera.camera = sourceCamera.camera?.copy() as? SCNCamera ?? SCNCamera()
        camera.simdTransform = sourceCamera.presentation.simdWorldTransform
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.projectionDirection = .vertical
        camera.camera?.zNear = 0.001
        camera.camera?.zFar = 100
        scene.rootNode.addChildNode(camera)
    }

    func update(world: SCNVector3?, diameter: CGFloat, viewport: CGFloat) {
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        if let world { ball.position = world }
        camera.simdPosition = ball.simdWorldPosition - camera.simdWorldFront
        // SceneKit orthographicScale is the half-height of the visible world.
        camera.camera?.orthographicScale = Double(AngleSceneCalculator.ballRadius) * Double(viewport / diameter)
        SCNTransaction.commit()
    }
}

private struct BTPaletteBallModelView: UIViewRepresentable {
    let key: String
    let projector: TableProjector
    let placement: BTPalettePlacement?

    final class Coordinator { var model: BTPaletteBallModel? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = false
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.isPlaying = false
        view.rendersContinuously = false
        return view
    }
    func updateUIView(_ view: SCNView, context: Context) {
        if context.coordinator.model == nil {
            context.coordinator.model = projector.makePaletteBallModel?(key)
            view.scene = context.coordinator.model?.scene
            view.pointOfView = context.coordinator.model?.camera
        }
        let diameter = placement?.diameter ?? BTBallPaletteMetrics.regularDiameter
        context.coordinator.model?.update(world: placement?.resolvedWorld, diameter: diameter, viewport: diameter + 2)
        view.setNeedsDisplay()
    }
    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.scene = nil; coordinator.model = nil
    }
}

// MARK: - Interactive token (Extraction / custom chrome)

/// Single palette slot with tap + drag-to-place. Used by pages whose bottom
/// chrome is not a full-width G8 bar (e.g. Extraction confirm strip).
struct BTBallPaletteToken: View {
    let key: String
    var ballDiameter: CGFloat = BTBallPaletteMetrics.regularDiameter
    var isOnTable: Bool
    var isDragging: Bool
    var allowsDrag: Bool = true
    var isPlaying: Bool = false
    let coordinateSpace: String
    var sceneFrame: CGRect
    var projector: TableProjector
    var resolvePlacement: (String, SCNVector3) -> SCNVector3?
    var onTap: () -> Void
    var onPlace: (SCNVector3?) -> Void
    var onDragInteraction: (() -> Void)? = nil
    @Binding var draggingKey: String?
    @Binding var dragLocation: CGPoint
    @Binding var dragOverTable: Bool

    private var slot: CGFloat { BTBallPaletteMetrics.slotHeight(for: ballDiameter) }

    var body: some View {
        PoolBallFace(key: key, diameter: ballDiameter)
            .overlay(Circle().stroke(BTBallPaletteMetrics.faceStroke,
                                     lineWidth: BTBallPaletteMetrics.faceStrokeWidth))
            .frame(width: slot, height: slot)
            .contentShape(Rectangle())
            .opacity(isDragging ? BTBallPaletteMetrics.dimmedOpacity
                     : (isOnTable ? BTBallPaletteMetrics.dimmedOpacity : 1))
            .accessibilityElement()
            .accessibilityIdentifier("paletteBall_\(key)")
            .accessibilityLabel(key == PositionPlayBall.cueKey ? "母球" : "\(key.replacingOccurrences(of: "_", with: ""))号球")
            .accessibilityValue(isOnTable ? "在桌上" : "未在桌上")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onTap() }
            .onTapGesture(perform: onTap)
            .gesture(paletteDrag, including: allowsDrag ? .all : .subviews)
    }

    private var paletteDrag: some Gesture {
        DragGesture(minimumDistance: BTBallPaletteMetrics.dragMinimumDistance,
                    coordinateSpace: .named(coordinateSpace))
            .onChanged { value in
                guard !isPlaying else { return }
                onDragInteraction?()
                draggingKey = key
                let preview = BTPalettePlacement.sample(key: key, finger: value.location, sourceDiameter: ballDiameter,
                    sceneFrame: sceneFrame, projector: projector, constrain: resolvePlacement)
                dragLocation = preview.location
                dragOverTable = preview.isValid
            }
            .onEnded { value in
                defer { draggingKey = nil; dragOverTable = false }
                guard !isPlaying, let world = projector.palettePreview?.requestedWorld else { return }
                onPlace(world)
            }
    }
}

// MARK: - Interactive / reference palette bar (G21)

/// Two-row × 8-column ball library. Pages pass only deltas
/// (`coordinateSpace`, `ballDiameter`, `isPlaying`, callbacks).
struct BTBallPaletteBar: View {
    let coordinateSpace: String
    var ballDiameter: CGFloat = BTBallPaletteMetrics.regularDiameter
    var isPlaying: Bool = false
    var libraryWidth: CGFloat
    var keys: [String] = PositionPlayBall.allKeys

    /// Whether the key is already on the table (drives dim opacity).
    var isOnTable: (String) -> Bool
    /// When false, only subview gestures fire (on-table / fixed balls).
    /// Defaults to `!isOnTable(key)`.
    var allowsDrag: ((String) -> Bool)? = nil

    var sceneFrame: CGRect = .zero
    var projector: TableProjector
    var resolvePlacement: (String, SCNVector3) -> SCNVector3?

    var onTap: (String) -> Void
    var onPlace: (String, SCNVector3?) -> Void
    var onDragInteraction: (() -> Void)? = nil

    @Binding var draggingKey: String?
    @Binding var dragLocation: CGPoint
    @Binding var dragOverTable: Bool

    private var columnWidth: CGFloat {
        max(libraryWidth / CGFloat(BTBallPaletteMetrics.columns), 1)
    }

    private var slotHeight: CGFloat {
        BTBallPaletteMetrics.slotHeight(for: ballDiameter)
    }

    var body: some View {
        let row1 = Array(keys.prefix(BTBallPaletteMetrics.columns))
        let row2 = Array(keys.dropFirst(BTBallPaletteMetrics.columns))
        return VStack(spacing: BTBallPaletteMetrics.rowSpacing) {
            paletteRow(row1)
            paletteRow(row2)
        }
        .frame(width: libraryWidth)
    }

    private func paletteRow(_ rowKeys: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<BTBallPaletteMetrics.columns, id: \.self) { i in
                Group {
                    if i < rowKeys.count {
                        token(rowKeys[i])
                    } else {
                        Color.clear
                    }
                }
                .frame(width: columnWidth, height: slotHeight)
            }
        }
    }

    private func token(_ key: String) -> some View {
        let onTable = isOnTable(key)
        let canDrag = allowsDrag?(key) ?? !onTable
        return BTBallPaletteToken(
            key: key,
            ballDiameter: ballDiameter,
            isOnTable: onTable,
            isDragging: draggingKey == key,
            allowsDrag: canDrag,
            isPlaying: isPlaying,
            coordinateSpace: coordinateSpace,
            sceneFrame: sceneFrame,
            projector: projector,
            resolvePlacement: resolvePlacement,
            onTap: { onTap(key) },
            onPlace: { world in onPlace(key, world) },
            onDragInteraction: onDragInteraction,
            draggingKey: $draggingKey,
            dragLocation: $dragLocation,
            dragOverTable: $dragOverTable
        )
    }
}

// MARK: - Decorative (read-only) palette (C14)

/// Sister of `BTBallPaletteBar` for quiz chrome: same two-row layout and face
/// styling, no tap/drag. Chosen over a mode flag so interactive pages never
/// need dummy drag bindings.
struct BTDecorativeBallPalette: View {
    var ballDiameter: CGFloat = BTBallPaletteMetrics.regularDiameter
    var libraryWidth: CGFloat
    var keys: [String] = PositionPlayBall.allKeys
    /// Opacity per key (e.g. target ball = 1, others = 0.25).
    var opacityForKey: (String) -> Double

    private var columnWidth: CGFloat {
        max(libraryWidth / CGFloat(BTBallPaletteMetrics.columns), 1)
    }

    private var slotHeight: CGFloat {
        BTBallPaletteMetrics.slotHeight(for: ballDiameter)
    }

    var body: some View {
        let row1 = Array(keys.prefix(BTBallPaletteMetrics.columns))
        let row2 = Array(keys.dropFirst(BTBallPaletteMetrics.columns))
        return VStack(spacing: BTBallPaletteMetrics.rowSpacing) {
            decorativeRow(row1)
            decorativeRow(row2)
        }
        .frame(width: libraryWidth)
        .allowsHitTesting(false)
    }

    private func decorativeRow(_ rowKeys: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(rowKeys, id: \.self) { key in
                PoolBallFace(key: key, diameter: ballDiameter)
                    .overlay(Circle().stroke(BTBallPaletteMetrics.faceStroke,
                                             lineWidth: BTBallPaletteMetrics.faceStrokeWidth))
                    .frame(width: columnWidth, height: slotHeight)
                    .opacity(opacityForKey(key))
            }
        }
    }
}

// MARK: - Reference palette (FreePlay: tap only, no drag)

/// FreePlay-style remaining-ball reference: dim on-table balls, tap to pulse
/// or show a page message — no drag-to-place.
struct BTReferenceBallPalette: View {
    var ballDiameter: CGFloat = BTBallPaletteMetrics.regularDiameter
    var libraryWidth: CGFloat
    var keys: [String] = PositionPlayBall.allKeys
    var isOnTable: (String) -> Bool
    /// On-table opacity (FreePlay uses 0.28); off-table uses `availableOpacity`.
    var onTableOpacity: Double = 0.28
    var availableOpacity: Double = 0.85
    var onTap: (String, Bool /* onTable */) -> Void

    private var columnWidth: CGFloat {
        max(libraryWidth / CGFloat(BTBallPaletteMetrics.columns), 1)
    }

    private var slotHeight: CGFloat {
        BTBallPaletteMetrics.slotHeight(for: ballDiameter)
    }

    var body: some View {
        let row1 = Array(keys.prefix(BTBallPaletteMetrics.columns))
        let row2 = Array(keys.dropFirst(BTBallPaletteMetrics.columns))
        return VStack(spacing: BTBallPaletteMetrics.rowSpacing) {
            referenceRow(row1)
            referenceRow(row2)
        }
        .frame(width: libraryWidth)
    }

    private func referenceRow(_ rowKeys: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<BTBallPaletteMetrics.columns, id: \.self) { i in
                Group {
                    if i < rowKeys.count {
                        let key = rowKeys[i]
                        let onTable = isOnTable(key)
                        PoolBallFace(key: key, diameter: ballDiameter)
                            .overlay(Circle().stroke(BTBallPaletteMetrics.faceStroke,
                                                     lineWidth: BTBallPaletteMetrics.faceStrokeWidth))
                            .frame(width: slotHeight, height: slotHeight)
                            .contentShape(Rectangle())
                            .opacity(onTable ? onTableOpacity : availableOpacity)
                            .accessibilityElement()
                            .accessibilityLabel(key)
                            .accessibilityIdentifier("paletteBall_\(key)")
                            .onTapGesture { onTap(key, onTable) }
                    } else {
                        Color.clear
                    }
                }
                .frame(width: columnWidth, height: slotHeight)
            }
        }
    }
}

// MARK: - Drag-back helper

enum BTBallPaletteDragBack {
    /// Maps a table-local drop point into the named coordinate space and
    /// returns whether it landed inside the palette frame.
    static func hitPalette(localPoint: CGPoint,
                           sceneFrame: CGRect,
                           paletteFrame: CGRect) -> Bool {
        guard sceneFrame != .zero, paletteFrame != .zero else { return false }
        let point = CGPoint(x: localPoint.x + sceneFrame.minX,
                            y: localPoint.y + sceneFrame.minY)
        return paletteFrame.contains(point)
    }
}

/// Shared finger clearance for table dragging and palette previews (points).
enum BTBallDragMetrics {
    static let fingerClearance: CGFloat = 52
}

/// A single sample owns both the displayed legal position and the input committed
/// at release. The host's placement constraint runs with identical inputs in both.
struct BTPalettePlacement {
    let location: CGPoint // host coordinate space
    let diameter: CGFloat
    let requestedWorld: SCNVector3?
    let resolvedWorld: SCNVector3?
    var isValid: Bool { requestedWorld != nil }

    static func sample(key: String, finger: CGPoint, sourceDiameter: CGFloat,
                       sceneFrame: CGRect, projector: TableProjector,
                       constrain: (String, SCNVector3) -> SCNVector3?) -> BTPalettePlacement {
        let sample = CGPoint(x: finger.x, y: finger.y - BTBallDragMetrics.fingerClearance)
        // Even between the library and the viewport, use the table's ball size.
        let referenceWorld = projector.unproject?(CGPoint(x: sceneFrame.width / 2, y: sceneFrame.height / 2))
        let referenceDiameter = referenceWorld.flatMap { projector.ballDiameter?($0) } ?? sourceDiameter
        let outside = BTPalettePlacement(location: sample, diameter: referenceDiameter,
                                        requestedWorld: nil, resolvedWorld: nil)
        guard sceneFrame.contains(sample),
              let requested = projector.unproject?(CGPoint(x: sample.x - sceneFrame.minX, y: sample.y - sceneFrame.minY)),
              let resolved = constrain(key, requested),
              let centre = projector.projectVisible?(resolved),
              let diameter = projector.ballDiameter?(resolved), diameter.isFinite, diameter > 0 else {
            projector.palettePreview = outside
            return outside
        }
        let result = BTPalettePlacement(location: CGPoint(x: centre.x + sceneFrame.minX, y: centre.y + sceneFrame.minY),
            diameter: diameter, requestedWorld: requested, resolvedWorld: resolved)
        projector.palettePreview = result
        #if DEBUG
        projector.palettePlacementDiagnostic = ["key": key, "screen": [centre.x, centre.y],
            "diameter": diameter, "finger": [finger.x - sceneFrame.minX, finger.y - sceneFrame.minY],
            "world": [resolved.x, resolved.y, resolved.z]]
        #endif
        return result
    }
}
