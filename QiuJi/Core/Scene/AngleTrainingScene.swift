import SceneKit

/// SceneKit scene for angle training: loads the USDZ table model,
/// manages camera (2D/3D), lighting, USDZ ball nodes, and cue stick.
final class AngleTrainingScene: SCNScene {

    // MARK: - Camera Mode

    enum CameraMode: Equatable {
        case topDown2D
        case topDown2DRotated
        case perspective3D
    }

    // MARK: - Properties

    private(set) var tableNode: SCNNode?
    private(set) var cameraNode: SCNNode!
    private(set) var cameraRig: CameraRig?
    private(set) var surfaceY: Float = 0.5
    private(set) var currentCameraMode: CameraMode = .topDown2D

    // MARK: - USDZ Ball Nodes

    private(set) var cueBallNode: SCNNode?
    private(set) var targetBallNodes: [SCNNode] = []
    private(set) var allBallNodes: [String: SCNNode] = [:]
    private(set) var initialBallPositions: [String: SCNVector3] = [:]

    // MARK: - Cue Stick

    private(set) var modelCueStickNode: SCNNode?
    private(set) var cueStick: CueStick?

    // MARK: - Fallback Procedural Balls (when USDZ balls not available)

    private var fallbackCueBall: SCNNode?
    private var fallbackTargetBall: SCNNode?

    // MARK: - Visualization Nodes (pre-created, toggled via isHidden)

    private(set) var ghostBallNode: SCNNode?
    private(set) var pocketLineNode: SCNNode?
    private(set) var strikeLineNode: SCNNode?
    private(set) var contactDotNode: SCNNode?
    private(set) var angleArcNode: SCNNode?
    private(set) var perpLineNode: SCNNode?

    // MARK: - Setup

    func setupScene() {
        setupTable()
        setupCamera()
        setupLighting()
    }

    // MARK: - Table

    private func setupTable() {
        guard let model = TableModelLoader.loadTable() else { return }

        surfaceY = model.surfaceY
        let tableHeight: Float = 0.8
        let yOffset = tableHeight - model.surfaceY
        model.visualNode.position.y += yOffset
        surfaceY = tableHeight

        rootNode.addChildNode(model.visualNode)
        tableNode = model.visualNode
        modelCueStickNode = model.cueStickNode

        setupModelBalls(from: model.ballNodes, uniformScale: model.appliedScale.x)
        enhanceBallMaterials()
        setupCueStick()
    }

    // MARK: - USDZ Ball Management

    private func setupModelBalls(from extractedBalls: [String: SCNNode], uniformScale: Float) {
        allBallNodes.removeAll()
        targetBallNodes.removeAll()
        initialBallPositions.removeAll()

        let correctY = surfaceY + AngleSceneCalculator.ballRadius

        for (key, ballNode) in extractedBalls {
            ballNode.position = SCNVector3(ballNode.position.x, correctY, ballNode.position.z)
            ballNode.isHidden = true
            rootNode.addChildNode(ballNode)

            allBallNodes[key] = ballNode
            initialBallPositions[key] = ballNode.position

            if key == "cueBall" {
                cueBallNode = ballNode
            } else {
                targetBallNodes.append(ballNode)
            }
        }
    }

    /// Show only specified balls, hide all others. Position them at given locations.
    /// Falls back to procedural balls if USDZ balls weren't extracted.
    func applyBallLayout(cueBallPosition: SCNVector3, targetBallNumber: Int, targetPosition: SCNVector3) {
        let correctY = surfaceY + AngleSceneCalculator.ballRadius
        let cuePos = SCNVector3(cueBallPosition.x, correctY, cueBallPosition.z)
        let targetPos = SCNVector3(targetPosition.x, correctY, targetPosition.z)

        for (_, node) in allBallNodes {
            node.isHidden = true
        }

        if let cue = allBallNodes["cueBall"] {
            cue.position = cuePos
            cue.isHidden = false
            cueBallNode = cue
        } else {
            fallbackCueBall?.removeFromParentNode()
            let node = addBall(at: cuePos, color: .white)
            node.name = "cueBall"
            fallbackCueBall = node
            cueBallNode = node
        }

        let targetKey = "_\(targetBallNumber)"
        if let target = allBallNodes[targetKey] {
            target.position = targetPos
            target.isHidden = false
            targetBallNodes = [target]
        } else {
            fallbackTargetBall?.removeFromParentNode()
            let ballColor = targetBallNumber == 8
                ? UIColor.black
                : UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1)
            let node = addBall(at: targetPos, color: ballColor)
            node.name = targetKey
            fallbackTargetBall = node
            targetBallNodes = [node]
        }
    }

    /// Position a specific ball by key without changing visibility of others.
    func moveBall(_ key: String, to position: SCNVector3) {
        let correctY = surfaceY + AngleSceneCalculator.ballRadius
        allBallNodes[key]?.position = SCNVector3(position.x, correctY, position.z)
    }

    /// Show all balls at their initial positions.
    func showAllBalls() {
        let correctY = surfaceY + AngleSceneCalculator.ballRadius
        for (_, node) in allBallNodes {
            node.position.y = correctY
            node.isHidden = false
        }
    }

    func enhanceBallMaterials() {
        for (_, ballNode) in allBallNodes {
            MaterialFactory.applyBallMaterial(to: ballNode)
        }
    }

    // MARK: - Ball Helpers

    func visualCenter(of node: SCNNode) -> SCNVector3 {
        if let meshNode = firstGeometryNode(in: node) {
            let (meshMin, meshMax) = meshNode.boundingBox
            let center = SCNVector3(
                (meshMin.x + meshMax.x) * 0.5,
                (meshMin.y + meshMax.y) * 0.5,
                (meshMin.z + meshMax.z) * 0.5
            )
            return meshNode.convertPosition(center, to: nil)
        }
        return node.position
    }

    private func firstGeometryNode(in node: SCNNode) -> SCNNode? {
        if let geo = node.geometry, !geo.sources.isEmpty {
            return node
        }
        for child in node.childNodes {
            if let found = firstGeometryNode(in: child) {
                return found
            }
        }
        return nil
    }

    // MARK: - Cue Stick

    func setupCueStick() {
        cueStick?.rootNode.removeFromParentNode()

        if let modelCueNode = modelCueStickNode {
            cueStick = CueStick(modelCueStickNode: modelCueNode)
        } else {
            cueStick = CueStick()
        }
        rootNode.addChildNode(cueStick!.rootNode)
        cueStick?.hide()
    }

    func updateCueStick(cueBallPosition: SCNVector3, aimDirection: SCNVector3) {
        cueStick?.update(cueBallPosition: cueBallPosition, aimDirection: aimDirection)
        cueStick?.show()
    }

    func hideCueStick() {
        cueStick?.hide()
    }

    // MARK: - Camera

    private func setupCamera() {
        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = 50

        cameraNode = SCNNode()
        cameraNode.name = "trainingCamera"
        cameraNode.camera = camera
        rootNode.addChildNode(cameraNode)

        cameraRig = CameraRig(cameraNode: cameraNode, tableSurfaceY: surfaceY)
        cameraRig?.applyTopDown2D()
    }

    // MARK: - Lighting

    private func setupLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 600
        ambient.light?.color = UIColor.white
        rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.intensity = 800
        directional.light?.color = UIColor.white
        directional.light?.castsShadow = true
        directional.light?.shadowRadius = 4
        directional.light?.shadowSampleCount = 4
        directional.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        rootNode.addChildNode(directional)
    }

    // MARK: - Camera Mode Switching

    func setCameraMode(_ mode: CameraMode, animated: Bool = true) {
        guard mode != currentCameraMode else { return }
        currentCameraMode = mode

        guard let rig = cameraRig else { return }

        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.4
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        }

        switch mode {
        case .topDown2D:
            rig.applyTopDown2D()
        case .topDown2DRotated:
            rig.applyTopDown2DRotated()
        case .perspective3D:
            rig.snapToTarget()
        }

        if animated {
            SCNTransaction.commit()
        }
    }

    // MARK: - Procedural Ball Management (for visualization nodes)

    @discardableResult
    func addBall(at position: SCNVector3, color: UIColor, radius: Float = AngleSceneCalculator.ballRadius) -> SCNNode {
        let sphere = SCNSphere(radius: CGFloat(radius))
        sphere.segmentCount = 24
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.3
        material.metalness.contents = 0.0
        sphere.materials = [material]

        let node = SCNNode(geometry: sphere)
        node.position = position
        rootNode.addChildNode(node)
        return node
    }

    func removeBall(_ node: SCNNode) {
        node.removeFromParentNode()
    }

    // MARK: - Aiming Lines

    @discardableResult
    func addLine(from start: SCNVector3, to end: SCNVector3, color: UIColor, radius: Float = 0.003) -> SCNNode {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dz = end.z - start.z
        let length = sqrtf(dx * dx + dy * dy + dz * dz)
        guard length > 0.001 else { return SCNNode() }

        let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(length))
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .constant
        cylinder.materials = [material]

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        node.look(at: SCNVector3(end.x, end.y, end.z),
                  up: rootNode.worldUp,
                  localFront: SCNVector3(0, 1, 0))

        rootNode.addChildNode(node)
        return node
    }

    func removeLine(_ node: SCNNode) {
        node.removeFromParentNode()
    }

    // MARK: - Pocket Markers

    func addPocketMarkers() -> [SCNNode] {
        let positions = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        return positions.map { pos in
            let torus = SCNTorus(ringRadius: 0.04, pipeRadius: 0.005)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemGreen
            material.lightingModel = .constant
            torus.materials = [material]

            let node = SCNNode(geometry: torus)
            node.position = pos
            rootNode.addChildNode(node)
            return node
        }
    }

    enum PocketHighlight {
        case selected, viable, infeasible
    }

    func highlightPocket(_ node: SCNNode, highlighted: Bool) {
        setPocketHighlight(node, style: highlighted ? .selected : .viable)
    }

    func setPocketHighlight(_ node: SCNNode, style: PocketHighlight) {
        guard let torus = node.geometry as? SCNTorus else { return }
        switch style {
        case .selected:
            torus.materials.first?.diffuse.contents = UIColor(red: 1, green: 0.84, blue: 0, alpha: 1)
            torus.pipeRadius = 0.008
        case .viable:
            torus.materials.first?.diffuse.contents = UIColor.systemGreen
            torus.pipeRadius = 0.005
        case .infeasible:
            torus.materials.first?.diffuse.contents = UIColor.systemRed.withAlphaComponent(0.6)
            torus.pipeRadius = 0.005
        }
    }

    // MARK: - Cleanup

    func clearResultNodes(nodes: inout [SCNNode]) {
        for node in nodes { node.removeFromParentNode() }
        nodes.removeAll()
    }

    // MARK: - Visualization Setup (pre-create all nodes once)

    func setupVisualizationNodes() {
        let r = AngleSceneCalculator.ballRadius

        let ghostSphere = SCNSphere(radius: CGFloat(r))
        ghostSphere.segmentCount = 24
        let ghostMat = SCNMaterial()
        ghostMat.diffuse.contents = UIColor.yellow.withAlphaComponent(0.3)
        ghostMat.lightingModel = .constant
        ghostSphere.materials = [ghostMat]
        let ghost = SCNNode(geometry: ghostSphere)
        ghost.isHidden = true
        ghost.name = "ghostBall"
        rootNode.addChildNode(ghost)
        ghostBallNode = ghost

        let plCyl = SCNCylinder(radius: 0.003, height: 1)
        let plMat = SCNMaterial()
        plMat.diffuse.contents = UIColor.white.withAlphaComponent(0.6)
        plMat.lightingModel = .constant
        plCyl.materials = [plMat]
        let pl = SCNNode(geometry: plCyl)
        pl.isHidden = true
        pl.name = "pocketLine"
        rootNode.addChildNode(pl)
        pocketLineNode = pl

        let slCyl = SCNCylinder(radius: 0.003, height: 1)
        let slMat = SCNMaterial()
        slMat.diffuse.contents = UIColor.cyan.withAlphaComponent(0.6)
        slMat.lightingModel = .constant
        slCyl.materials = [slMat]
        let sl = SCNNode(geometry: slCyl)
        sl.isHidden = true
        sl.name = "strikeLine"
        rootNode.addChildNode(sl)
        strikeLineNode = sl

        let dotSphere = SCNSphere(radius: 0.008)
        dotSphere.segmentCount = 16
        let dotMat = SCNMaterial()
        dotMat.diffuse.contents = UIColor.red
        dotMat.lightingModel = .constant
        dotSphere.materials = [dotMat]
        let dot = SCNNode(geometry: dotSphere)
        dot.isHidden = true
        dot.name = "contactDot"
        rootNode.addChildNode(dot)
        contactDotNode = dot

        let arc = SCNNode()
        arc.isHidden = true
        arc.name = "angleArc"
        rootNode.addChildNode(arc)
        angleArcNode = arc

        let ppCyl = SCNCylinder(radius: 0.002, height: 1)
        let ppMat = SCNMaterial()
        ppMat.diffuse.contents = UIColor.yellow.withAlphaComponent(0.4)
        ppMat.lightingModel = .constant
        ppCyl.materials = [ppMat]
        let pp = SCNNode(geometry: ppCyl)
        pp.isHidden = true
        pp.name = "perpLine"
        rootNode.addChildNode(pp)
        perpLineNode = pp
    }

    // MARK: - Show / Hide Visualization

    func hideAllVisualization() {
        ghostBallNode?.isHidden = true
        pocketLineNode?.isHidden = true
        strikeLineNode?.isHidden = true
        contactDotNode?.isHidden = true
        angleArcNode?.isHidden = true
        perpLineNode?.isHidden = true
    }

    func updateVisualization(cueBall: SCNVector3, targetBall: SCNVector3, pocket: SCNVector3) {
        let r = AngleSceneCalculator.ballRadius

        let ghostPos = AngleSceneCalculator.ghostBallPosition(
            targetBall: targetBall, pocket: pocket, ballRadius: r
        )
        ghostBallNode?.position = ghostPos
        ghostBallNode?.isHidden = false

        updateLineNode(pocketLineNode, from: targetBall, to: pocket)
        pocketLineNode?.isHidden = false

        updateLineNode(strikeLineNode, from: cueBall, to: ghostPos)
        strikeLineNode?.isHidden = false

        let contact = AngleSceneCalculator.contactPointPosition(cueBall: cueBall, targetBall: targetBall)
        contactDotNode?.position = contact
        contactDotNode?.isHidden = false

        updatePerpLine(targetBall: targetBall, pocket: pocket)
        perpLineNode?.isHidden = false

        updateAngleArc(cueBall: cueBall, targetBall: targetBall, pocket: pocket)
        angleArcNode?.isHidden = false
    }

    // MARK: - Line Node Helpers

    private func updateLineNode(_ node: SCNNode?, from start: SCNVector3, to end: SCNVector3) {
        guard let node else { return }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dz = end.z - start.z
        let length = sqrtf(dx * dx + dy * dy + dz * dz)
        guard length > 0.001 else { return }

        if let cyl = node.geometry as? SCNCylinder {
            cyl.height = CGFloat(length)
        }
        node.position = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        node.look(at: end, up: rootNode.worldUp, localFront: SCNVector3(0, 1, 0))
    }

    private func updatePerpLine(targetBall: SCNVector3, pocket: SCNVector3) {
        let dx = pocket.x - targetBall.x
        let dz = pocket.z - targetBall.z
        let dist = sqrtf(dx * dx + dz * dz)
        guard dist > 0.001 else { return }
        let perpX = -dz / dist
        let perpZ = dx / dist
        let len: Float = AngleSceneCalculator.ballRadius * 4
        let start = SCNVector3(targetBall.x - perpX * len, targetBall.y, targetBall.z - perpZ * len)
        let end = SCNVector3(targetBall.x + perpX * len, targetBall.y, targetBall.z + perpZ * len)
        updateLineNode(perpLineNode, from: start, to: end)
    }

    private func updateAngleArc(cueBall: SCNVector3, targetBall: SCNVector3, pocket: SCNVector3) {
        angleArcNode?.childNodes.forEach { $0.removeFromParentNode() }

        let r = AngleSceneCalculator.ballRadius
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: targetBall, pocket: pocket, ballRadius: r)

        let pocketAngle = atan2(pocket.z - targetBall.z, pocket.x - targetBall.x)
        let ghostAngle = atan2(ghost.z - targetBall.z, ghost.x - targetBall.x)

        let arcRadius: Float = r * 3
        let segments = 20
        let startA = pocketAngle
        var delta = ghostAngle - startA
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        let endA = startA + delta

        for i in 0..<segments {
            let t0 = Float(i) / Float(segments)
            let t1 = Float(i + 1) / Float(segments)
            let a0 = startA + (endA - startA) * t0
            let a1 = startA + (endA - startA) * t1
            let p0 = SCNVector3(targetBall.x + arcRadius * cosf(a0), targetBall.y + 0.001, targetBall.z + arcRadius * sinf(a0))
            let p1 = SCNVector3(targetBall.x + arcRadius * cosf(a1), targetBall.y + 0.001, targetBall.z + arcRadius * sinf(a1))
            let seg = makeSmallCylinder(from: p0, to: p1, radius: 0.002, color: UIColor.yellow.withAlphaComponent(0.7))
            angleArcNode?.addChildNode(seg)
        }

        let cutAngle = AngleSceneCalculator.cutAngle(cueBall: cueBall, targetBall: targetBall, pocket: pocket)
        let midAngle = startA + (endA - startA) * 0.5
        let labelDist = arcRadius + r * 2
        let labelPos = SCNVector3(targetBall.x + labelDist * cosf(midAngle), targetBall.y + 0.002, targetBall.z + labelDist * sinf(midAngle))

        let textGeo = SCNText(string: "\(Int(cutAngle))°", extrusionDepth: 0)
        textGeo.font = UIFont.systemFont(ofSize: 0.8, weight: .bold)
        textGeo.flatness = 0.1
        let textMat = SCNMaterial()
        textMat.diffuse.contents = UIColor.yellow
        textMat.lightingModel = .constant
        textGeo.materials = [textMat]

        let textNode = SCNNode(geometry: textGeo)
        let (tMin, tMax) = textNode.boundingBox
        let textW = tMax.x - tMin.x
        let textH = tMax.y - tMin.y
        textNode.pivot = SCNMatrix4MakeTranslation(textW / 2, textH / 2, 0)
        textNode.scale = SCNVector3(0.03, 0.03, 0.03)
        textNode.position = labelPos
        textNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)

        angleArcNode?.addChildNode(textNode)
        angleArcNode?.position = SCNVector3(0, 0, 0)
    }

    private func makeSmallCylinder(from start: SCNVector3, to end: SCNVector3, radius: Float, color: UIColor) -> SCNNode {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dz = end.z - start.z
        let length = sqrtf(dx * dx + dy * dy + dz * dz)
        guard length > 0.0001 else { return SCNNode() }

        let cyl = SCNCylinder(radius: CGFloat(radius), height: CGFloat(length))
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .constant
        cyl.materials = [mat]

        let node = SCNNode(geometry: cyl)
        node.position = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)
        node.look(at: end, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        return node
    }
}
