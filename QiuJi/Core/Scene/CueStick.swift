import SceneKit

/// Cue stick 3D model for angle training scenes.
/// Supports USDZ model (preferred) or procedural fallback.
final class CueStick {

    // MARK: - Constants

    private enum Constants {
        static let length: Float = 1.45
        static let buttRadius: Float = 0.014
        static let tipRadius: Float = 0.006
        static let tipHeight: Float = 0.012
        static var tipOffset: Float { AngleSceneCalculator.ballRadius + 0.001 }
        /// Cushion top above table surface; cue body must clear this when extending over a rail.
        static let railTopAboveSurface: Float = 0.038
        /// Extra clearance for visual safety so the shaft doesn't kiss the rail.
        static let railClearance: Float = 0.012
        /// Minimum elevation for a natural-looking stance even when far from any cushion.
        static let minElevationRadians: Float = 0.05
        /// Cap to avoid wildly steep rendering angles.
        static let maxElevationRadians: Float = 0.55
    }

    /// Required elevation (positive = butt up) so the rear of the cue stick clears the cushion.
    /// Considers the closest cushion the cue body would extend over (back direction).
    static func requiredElevation(cueBallPosition: SCNVector3, aimDirection: SCNVector3) -> Float {
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

        // Cue tip sits at ball-center height; at distToCushion the shaft must be above rail top.
        let railRise = max(0, Constants.railTopAboveSurface - AngleSceneCalculator.ballRadius)
        let needed = atan2f(railRise + Constants.railClearance, max(0.05, distToCushion))
        return max(Constants.minElevationRadians, min(needed, Constants.maxElevationRadians))
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
    }
}
