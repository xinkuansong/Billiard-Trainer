import SceneKit

/// Result of cue elevation solving.
/// - `angle`: butt-up radians to use for rendering.
/// - `blocked`: required elevation exceeds `maxElevationRadians` — caller must hide the stick
///   rather than drawing a penetrating shaft (D1).
enum CueElevation: Equatable {
    case angle(Float)
    case blocked

    var radians: Float? {
        if case .angle(let a) = self { return a }
        return nil
    }
}

/// Cue stick 3D model for angle training scenes.
/// Supports USDZ model (preferred) or procedural fallback.
final class CueStick {

    // MARK: - Constants

    private enum Constants {
        static let length: Float = CueClearance.shaftLength
        static let buttRadius: Float = CueClearance.buttRadius
        /// 皮头横截面半径——单一来源 `CuePhysics.tipContactRadius`（11mm 皮头 → 5.5mm）。
        static let tipRadius: Float = CueClearance.tipRadius
        static let tipHeight: Float = 0.012
        static var tipOffset: Float { CueClearance.tipOffset }
        /// Cushion top above table surface; cue body must clear this when extending over a rail.
        static let railTopAboveSurface: Float = 0.038
        /// Extra clearance for visual safety so the shaft doesn't kiss the rail.
        static let railClearance: Float = 0.012
        /// Minimum elevation for a natural-looking stance even when far from any cushion.
        static let minElevationRadians: Float = 0.05
        /// Cap: 60° (D1). Beyond this → `.blocked` (hide stick), never clamp-and-draw.
        /// Reachability note: on legal layouts ball occlusion peaks ≈32° at s=2R; cushion
        /// path uses `max(0.05, dist)` so peaks ≈23°. `.blocked` is a defensive guard only
        /// (overlapping / synthetic configs, or future formula changes) — see DR-027.
        static let maxElevationRadians: Float = Float.pi / 3
    }

    /// Public max elevation (tests / callers).
    static var maxElevationRadians: Float { Constants.maxElevationRadians }
    static var minElevationRadians: Float { Constants.minElevationRadians }

    /// Required elevation (positive = butt up) so the shaft clears cushions **and**
    /// balls behind the cue along the back direction.
    ///
    /// - Parameter obstacleCenters: world centres of balls that may occlude the shaft
    ///   (already excluding the cue ball itself). Horizontal X–Z; Y ignored for occlusion.
    ///
    /// Ball occlusion (conservative): for each obstacle at horizontal offset along `back`,
    /// if `lateral < R + shaftRadius(s)` and `s` in the occupied span covering max backswing,
    /// need `atan2(R + shaftRadius(s) + clearance, s)`. Lateral does **not** reduce the
    /// required rise (deliberately conservative). Take max over cushions and balls;
    /// if that exceeds 60° → `.blocked`.
    ///
    /// - `.blocked` is **not reachable on legal non-overlapping layouts** with the current
    ///   formulas (ball max ≈32.3° at s=2R; cushion max ≈23° due to `max(0.05, dist)` floor).
    ///   Kept as a defensive hide-rather-than-penetrate guard. Do not inflate elev to “reach” it.
    /// - Known inconsistency (render-only; physics unchanged this round): a large elevation
    ///   cannot physically deliver a strong low-spin stun/draw shot, yet the engine still
    ///   integrates as a level-cue strike. See IMPLEMENTATION-LOG DR-027.
    static func requiredElevation(
        cueBallPosition: SCNVector3,
        aimDirection: SCNVector3,
        obstacleCenters: [SCNVector3] = []
    ) -> CueElevation {
        let cushion = cushionElevation(cueBallPosition: cueBallPosition, aimDirection: aimDirection)
        let ball = ballElevation(cueBallPosition: cueBallPosition, aimDirection: aimDirection,
                                 obstacleCenters: obstacleCenters)
        let needed = max(cushion, ball)
        if needed > Constants.maxElevationRadians {
            return .blocked
        }
        return .angle(max(Constants.minElevationRadians, needed))
    }

    /// Cushion-only elevation (uncapped except for the historical internal min).
    private static func cushionElevation(cueBallPosition: SCNVector3, aimDirection: SCNVector3) -> Float {
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2

        let flatX = aimDirection.x
        let flatZ = aimDirection.z
        let len = sqrtf(flatX * flatX + flatZ * flatZ)
        guard len > 0.0001 else { return Constants.minElevationRadians }

        let aimX = flatX / len
        let aimZ = flatZ / len
        let backX = -aimX
        let backZ = -aimZ

        var distToCushion: Float = .infinity
        if backX > 0.001 { distToCushion = min(distToCushion, (halfL - cueBallPosition.x) / backX) }
        if backX < -0.001 { distToCushion = min(distToCushion, (-halfL - cueBallPosition.x) / backX) }
        if backZ > 0.001 { distToCushion = min(distToCushion, (halfW - cueBallPosition.z) / backZ) }
        if backZ < -0.001 { distToCushion = min(distToCushion, (-halfW - cueBallPosition.z) / backZ) }

        guard distToCushion > 0 else { return Constants.minElevationRadians }
        if distToCushion >= Constants.length { return Constants.minElevationRadians }

        let railRise = max(0, Constants.railTopAboveSurface - AngleSceneCalculator.ballRadius)
        return atan2f(railRise + Constants.railClearance, max(0.05, distToCushion))
    }

    /// Ball-occlusion elevation contribution (0 if none).
    private static func ballElevation(
        cueBallPosition: SCNVector3,
        aimDirection: SCNVector3,
        obstacleCenters: [SCNVector3]
    ) -> Float {
        guard !obstacleCenters.isEmpty else { return 0 }
        let aim = CueClearance.normalizeFlat(aimDirection)
        let back = SCNVector3(-aim.x, 0, -aim.z)
        let r = AngleSceneCalculator.ballRadius
        // Occupied span covers max backswing: [R, R+maxPull+length].
        // Also consider tip-zone (0 < s < R): a ball jammed between pivot and tip
        // (physically overlapping cue ball) still needs a steep / blocked elevation.
        let sMin = r
        let sMax = r + CueClearance.maxPullBack + CueClearance.shaftLength
        var needed: Float = 0
        for p in obstacleCenters {
            let dx = p.x - cueBallPosition.x
            let dz = p.z - cueBallPosition.z
            let s = dx * back.x + dz * back.z
            guard s > 1e-4, s <= sMax + 1e-4 else { continue }
            let latX = dx - s * back.x
            let latZ = dz - s * back.z
            let lateral = sqrtf(latX * latX + latZ * latZ)
            let shaftR = s >= sMin
                ? CueClearance.shaftRadius(atDistanceAlongBack: s)
                : CueClearance.tipRadius
            guard lateral < r + shaftR else { continue }
            // Conservative: required rise ignores lateral (as if ball were on the shaft line).
            let elev = atan2f(r + shaftR + CueClearance.ballClearance, max(1e-4, s))
            needed = max(needed, elev)
        }
        return needed
    }

    // MARK: - Nodes

    let rootNode: SCNNode
    private let usesModelCueStick: Bool
    private var modelNode: SCNNode?
    private var shaftNode: SCNNode?
    private var tipNode: SCNNode?
    private var ferruleNode: SCNNode?
    private var modelTipLocalPoint: SCNVector3 = SCNVector3Zero

    // MARK: - Initialization (USDZ model)

    init(modelCueStickNode: SCNNode) {
        rootNode = SCNNode()
        rootNode.name = "cueStick"
        usesModelCueStick = true

        modelNode = modelCueStickNode
        rootNode.addChildNode(modelCueStickNode)

        let (bMin, bMax) = modelCueStickNode.boundingBox
        modelTipLocalPoint = SCNVector3(
            (bMin.x + bMax.x) * 0.5,
            (bMin.y + bMax.y) * 0.5,
            bMin.z
        )
    }

    /// Procedural cue stick (fallback)
    init() {
        rootNode = SCNNode()
        rootNode.name = "cueStick"
        usesModelCueStick = false

        let shaftLength = Constants.length
        let shaftGeometry = SCNCone(
            topRadius: CGFloat(Constants.tipRadius),
            bottomRadius: CGFloat(Constants.buttRadius),
            height: CGFloat(shaftLength)
        )
        let shaftMaterial = SCNMaterial()
        shaftMaterial.diffuse.contents = UIColor(red: 0.72, green: 0.53, blue: 0.28, alpha: 1.0)
        shaftMaterial.specular.contents = UIColor(white: 0.4, alpha: 1.0)
        shaftMaterial.roughness.contents = 0.4
        shaftGeometry.materials = [shaftMaterial]
        let shaft = SCNNode(geometry: shaftGeometry)
        shaft.name = "shaft"
        shaftNode = shaft

        let ferruleHeight: Float = 0.015
        let ferruleGeometry = SCNCylinder(
            radius: CGFloat(Constants.tipRadius + 0.001),
            height: CGFloat(ferruleHeight)
        )
        let ferruleMaterial = SCNMaterial()
        ferruleMaterial.diffuse.contents = UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0)
        ferruleMaterial.specular.contents = UIColor.white
        ferruleGeometry.materials = [ferruleMaterial]
        let ferrule = SCNNode(geometry: ferruleGeometry)
        ferrule.name = "ferrule"
        ferruleNode = ferrule

        let tipGeometry = SCNCylinder(
            radius: CGFloat(Constants.tipRadius),
            height: CGFloat(Constants.tipHeight)
        )
        let tipMaterial = SCNMaterial()
        tipMaterial.diffuse.contents = UIColor(red: 0.2, green: 0.35, blue: 0.65, alpha: 1.0)
        tipMaterial.roughness.contents = 0.9
        tipGeometry.materials = [tipMaterial]
        let tip = SCNNode(geometry: tipGeometry)
        tip.name = "tip"
        tipNode = tip

        rootNode.addChildNode(shaft)
        rootNode.addChildNode(ferrule)
        rootNode.addChildNode(tip)
    }

    // MARK: - Update

    func update(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float = 0, elevation: Float = 0) {
        if usesModelCueStick {
            updateModelCueStick(cueBallPosition: cueBallPosition, aimDirection: aimDirection, pullBack: pullBack, elevation: elevation)
        } else {
            updateProgrammaticCueStick(cueBallPosition: cueBallPosition, aimDirection: aimDirection, pullBack: pullBack, elevation: elevation)
        }
    }

    private func normalizedTableAim(_ aimDirection: SCNVector3) -> SCNVector3 {
        let flat = SCNVector3(aimDirection.x, 0, aimDirection.z)
        let len = sqrtf(flat.x * flat.x + flat.z * flat.z)
        if len < 0.0001 { return SCNVector3(1, 0, 0) }
        return SCNVector3(flat.x / len, 0, flat.z / len)
    }

    private func updateModelCueStick(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float, elevation: Float) {
        let tipOffset = Constants.tipOffset + pullBack
        let aim = normalizedTableAim(aimDirection)

        rootNode.position = cueBallPosition
        let backDirection = SCNVector3(-aim.x, 0, -aim.z)
        let yaw = atan2(backDirection.x, backDirection.z)
        rootNode.eulerAngles = SCNVector3(-elevation, yaw, 0)

        if let model = modelNode {
            model.position = SCNVector3(
                -modelTipLocalPoint.x,
                -modelTipLocalPoint.y,
                tipOffset - modelTipLocalPoint.z
            )
        }
    }

    private func updateProgrammaticCueStick(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float, elevation: Float) {
        let tipOffset = Constants.tipOffset + pullBack
        let shaftLength = Constants.length
        let tipHeight = Constants.tipHeight
        let ferruleHeight: Float = 0.015
        let aim = normalizedTableAim(aimDirection)

        rootNode.position = cueBallPosition
        let backDirection = SCNVector3(-aim.x, 0, -aim.z)
        let yaw = atan2(backDirection.x, backDirection.z)
        rootNode.eulerAngles = SCNVector3(-elevation, yaw, 0)

        tipNode?.position = SCNVector3(0, 0, tipOffset + tipHeight / 2)
        tipNode?.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)

        ferruleNode?.position = SCNVector3(0, 0, tipOffset + tipHeight + ferruleHeight / 2)
        ferruleNode?.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)

        shaftNode?.position = SCNVector3(0, 0, tipOffset + tipHeight + ferruleHeight + shaftLength / 2)
        shaftNode?.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
    }

    // MARK: - Visibility

    func show() {
        rootNode.isHidden = false
        rootNode.opacity = 1.0
    }

    func hide() {
        rootNode.isHidden = true
        rootNode.opacity = 1.0
    }

    /// Short opacity fade then hide (normal retract / clearance retract).
    func fadeOut(duration: TimeInterval = CueClearance.retractFade, completion: (() -> Void)? = nil) {
        rootNode.removeAction(forKey: "cueFade")
        let fade = SCNAction.fadeOpacity(to: 0, duration: duration)
        let hide = SCNAction.run { [weak self] _ in
            self?.hide()
            completion?()
        }
        rootNode.runAction(.sequence([fade, hide]), forKey: "cueFade")
    }
}
