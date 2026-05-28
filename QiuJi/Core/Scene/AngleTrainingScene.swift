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
    private(set) var isCameraModeTransitioning = false

    /// Studio-look pipeline flag. Default `false` so existing pages
    /// (`AngleDynamicView` / `Scene2DAimingView`) keep their cheap
    /// 3-light scene. `Scene3DAimingView` opts in via `setupScene(enhancedRendering: true)`.
    private(set) var enhancedRendering: Bool = false

    /// Keep references to nodes we add for the enhanced pipeline so we can detach them
    /// if the flag is toggled off mid-session.
    private var groundVisualNode: SCNNode?
    private var groundShadowNode: SCNNode?
    private var tableCenterGlowNode: SCNNode?
    private var enhancedLightNodes: [SCNNode] = []

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

    /// Build the angle-training scene.
    /// - Parameter enhancedRendering: when `true`, opts into the studio-look
    ///   pipeline (programmatic IBL + ground shadow catcher + 4-light + HDR
    ///   camera + cloth/rail/pocket material enhancers + table center glow).
    ///   Default `false` keeps the cheap 3-light look for the 2D pages.
    func setupScene(enhancedRendering: Bool = false) {
        self.enhancedRendering = enhancedRendering

        if enhancedRendering {
            EnhancedEnvironment.apply(to: self)
            setupGround()
        }

        setupTable()
        setupCamera()
        setupLighting()
    }

    // MARK: - Table

    private func setupTable() {
        guard let model = TableModelLoader.loadTable() else { return }

        surfaceY = model.surfaceY
        let tableHeight = BTTablePhysics.surfaceY
        let yOffset = tableHeight - model.surfaceY
        model.visualNode.position.y += yOffset
        surfaceY = tableHeight

        rootNode.addChildNode(model.visualNode)
        tableNode = model.visualNode
        modelCueStickNode = model.cueStickNode

        setupModelBalls(from: model.ballNodes, uniformScale: model.appliedScale.x)
        enhanceBallMaterials()

        if enhancedRendering {
            MaterialFactory.enhanceClothMaterials(in: model.visualNode)
            MaterialFactory.enhanceRailMaterials(in: model.visualNode)
            MaterialFactory.enhancePocketMaterials(in: model.visualNode)
            addTableCenterGlow()
        }

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
        // Keep every ball's USDZ-baked diffuse texture intact: the cue
        // ball carries red position-marker dots ("stickers") that are
        // intentional spin / aim references, and overriding the diffuse
        // erases them.
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
        let elevation = CueStick.requiredElevation(
            cueBallPosition: cueBallPosition, aimDirection: aimDirection
        )
        cueStick?.update(
            cueBallPosition: cueBallPosition,
            aimDirection: aimDirection,
            elevation: elevation
        )
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

        if enhancedRendering {
            // Studio look: HDR + tone mapping + SSAO + bloom. The brighter
            // exposure / lighting tried earlier flattened the balls' PBR
            // shading and made them look plasticky / fake — restored the
            // original studio exposure so the clearcoat fresnel highlights
            // properly read on the balls.
            camera.fieldOfView = AimingCameraConfig.aimFov
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = false
            camera.exposureOffset = -0.25
            camera.minimumExposure = -2.0
            camera.maximumExposure = 3.0
            camera.whitePoint = 1.0

            camera.screenSpaceAmbientOcclusionIntensity = 0.4
            camera.screenSpaceAmbientOcclusionRadius = 0.04
            camera.screenSpaceAmbientOcclusionNormalThreshold = 0.3
            camera.screenSpaceAmbientOcclusionDepthThreshold = 0.01
            camera.screenSpaceAmbientOcclusionBias = 0.01

            camera.bloomIntensity = 0.25
            camera.bloomThreshold = 0.85
            camera.bloomBlurRadius = 4.0
        } else {
            // Legacy plain pipeline (unchanged from before).
            camera.fieldOfView = 50
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = false
            camera.exposureOffset = -0.15
            camera.minimumExposure = -2
            camera.maximumExposure = 2
            camera.screenSpaceAmbientOcclusionIntensity = 0.35
            camera.screenSpaceAmbientOcclusionRadius = 3.0
        }

        cameraNode = SCNNode()
        cameraNode.name = "trainingCamera"
        cameraNode.camera = camera
        rootNode.addChildNode(cameraNode)

        cameraRig = CameraRig(cameraNode: cameraNode, tableSurfaceY: surfaceY)
        cameraRig?.applyTopDown2D()
    }

    // MARK: - Lighting

    private func setupLighting() {
        if enhancedRendering {
            setupStudioLighting()
        } else {
            setupPlainLighting()
        }
    }

    /// Cheap plain lighting used by the 2D pages (unchanged behavior).
    private func setupPlainLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 1000
        ambient.light?.color = UIColor.white
        rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.intensity = 1400
        directional.light?.color = UIColor.white
        directional.light?.castsShadow = true
        directional.light?.shadowRadius = 4
        directional.light?.shadowSampleCount = 4
        directional.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        rootNode.addChildNode(directional)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 500
        fillLight.light?.color = UIColor.white
        fillLight.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 3, 0)
        rootNode.addChildNode(fillLight)
    }

    /// Studio key + fill + rim trio (mirrors `BilliardScene.setupLights` in
    /// the reference codebase). Intentionally moodier than the plain
    /// pipeline — the IBL fills in the ambient, and the directional
    /// shaping is what makes the balls read as 3D objects with proper PBR
    /// shading. Brighter ambient / directional values flatten the
    /// clearcoat fresnel and make the balls look plasticky.
    private func setupStudioLighting() {
        // ── Key Light: 5800K, casts shadow, slight yaw to break symmetric
        // highlights.
        let key = SCNLight()
        key.type = .directional
        key.intensity = 820
        key.temperature = 5800
        key.castsShadow = true
        key.shadowRadius = 4
        key.shadowSampleCount = 8
        key.shadowColor = UIColor(white: 0.0, alpha: 0.35)
        key.shadowMapSize = CGSize(width: 1024, height: 1024)
        key.shadowBias = 0.008
        key.shadowMode = .deferred
        key.orthographicScale = 1.7

        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(0, 4, 0)
        keyNode.eulerAngles = SCNVector3(
            -68.0 * Float.pi / 180.0,
             18.0 * Float.pi / 180.0,
             0
        )
        rootNode.addChildNode(keyNode)
        enhancedLightNodes.append(keyNode)

        // ── Fill Light: 6800K, no shadow, lifts rails / pockets without
        // killing contrast on the balls.
        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 50
        fill.temperature = 6800
        fill.castsShadow = false

        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(
            -30.0 * Float.pi / 180.0,
            -40.0 * Float.pi / 180.0,
             0
        )
        rootNode.addChildNode(fillNode)
        enhancedLightNodes.append(fillNode)

        // ── Rim Light: warm sliver from upper-back-right for ball
        // silhouette separation.
        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 120
        rim.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
        rim.castsShadow = false

        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(
            -40.0 * Float.pi / 180.0,
            135.0 * Float.pi / 180.0,
             0
        )
        rootNode.addChildNode(rimNode)
        enhancedLightNodes.append(rimNode)
    }

    // MARK: - Ground (enhanced only)

    /// Two stacked planes at `Y = BTSceneLayout.groundLevelY`:
    /// • Layer 1: unlit dark-blue visual (matches studio cube-map background).
    /// • Layer 2: PBR shadow catcher — only renders the cast shadow alpha.
    private func setupGround() {
        let planeSize: CGFloat = 40

        // ── Layer 1: visual ground ──
        let visualPlane = SCNPlane(width: planeSize, height: planeSize)
        let visualMat = SCNMaterial()
        visualMat.lightingModel = .constant
        visualMat.diffuse.contents = UIColor(red: 0.032, green: 0.042, blue: 0.062, alpha: 1.0)
        visualMat.writesToDepthBuffer = true
        visualMat.readsFromDepthBuffer = true
        visualMat.isDoubleSided = false
        visualPlane.materials = [visualMat]

        let visualNode = SCNNode(geometry: visualPlane)
        visualNode.name = "ground_visual"
        visualNode.eulerAngles.x = -.pi / 2
        visualNode.position = SCNVector3(0, BTSceneLayout.groundLevelY, 0)
        visualNode.castsShadow = false
        visualNode.renderingOrder = -10
        rootNode.addChildNode(visualNode)
        groundVisualNode = visualNode

        // ── Layer 2: shadow catcher ──
        let shadowPlane = SCNPlane(width: planeSize, height: planeSize)
        let shadowMat = SCNMaterial()
        shadowMat.lightingModel = .physicallyBased
        shadowMat.diffuse.contents = UIColor.white
        shadowMat.roughness.contents = Float(1.0)
        shadowMat.metalness.contents = Float(0.0)
        shadowMat.isDoubleSided = false
        shadowMat.writesToDepthBuffer = false
        shadowMat.readsFromDepthBuffer = true
        shadowMat.blendMode = .alpha
        shadowMat.shaderModifiers = [.fragment: AngleTrainingScene.shadowCatcherShader]
        shadowPlane.materials = [shadowMat]

        let shadowNode = SCNNode(geometry: shadowPlane)
        shadowNode.name = "ground_shadow"
        shadowNode.eulerAngles.x = -.pi / 2
        shadowNode.position = SCNVector3(0, BTSceneLayout.groundLevelY + 0.0005, 0)
        shadowNode.castsShadow = false
        shadowNode.renderingOrder = -9
        rootNode.addChildNode(shadowNode)
        groundShadowNode = shadowNode
    }

    /// Shadow catcher fragment shader: renders only the alpha contribution from cast shadows.
    private static let shadowCatcherShader = """
    float lum = dot(_lightingContribution.diffuse, float3(0.2126, 0.7152, 0.0722));
    float lit = saturate(lum);
    float shadowAlpha = (1.0 - lit) * 0.35;
    _output.color = float4(0.0, 0.0, 0.0, shadowAlpha);
    """

    /// Subtle radial bright on the cloth centre (~+4% center, 0% edges).
    private func addTableCenterGlow() {
        let w = CGFloat(AngleSceneCalculator.innerLength)
        let h = CGFloat(AngleSceneCalculator.innerWidth)
        let plane = SCNPlane(width: w, height: h)

        let glowSize: CGFloat = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: glowSize, height: glowSize))
        let tex = renderer.image { ctx in
            let center = CGPoint(x: glowSize / 2, y: glowSize / 2)
            if let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(white: 1.0, alpha: 0.04).cgColor,
                    UIColor(white: 1.0, alpha: 0.0).cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            ) {
                ctx.cgContext.drawRadialGradient(
                    grad,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: glowSize * 0.5,
                    options: []
                )
            }
        }

        let mat = SCNMaterial()
        mat.diffuse.contents = tex
        mat.lightingModel = .constant
        mat.isDoubleSided = false
        mat.writesToDepthBuffer = false
        mat.transparencyMode = .aOne
        mat.blendMode = .add
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SCNVector3(0, surfaceY + 0.002, 0)
        node.renderingOrder = -2
        rootNode.addChildNode(node)
        tableCenterGlowNode = node
    }

    // MARK: - Camera Mode Switching

    func setCameraMode(_ mode: CameraMode, animated: Bool = true) {
        guard let rig = cameraRig else { return }
        let previousMode = currentCameraMode
        guard mode != previousMode || animated else { return }

        currentCameraMode = mode

        guard animated else {
            isCameraModeTransitioning = false
            switch mode {
            case .topDown2D:
                rig.applyTopDown2D()
            case .topDown2DRotated:
                rig.applyTopDown2DRotated()
            case .perspective3D:
                cameraNode.camera?.usesOrthographicProjection = false
                rig.snapToTarget()
            }
            return
        }

        switch (previousMode, mode) {
        case (.perspective3D, .topDown2D), (.perspective3D, .topDown2DRotated):
            transitionToTopDown(mode)
        case (.topDown2D, .perspective3D), (.topDown2DRotated, .perspective3D):
            transitionToPerspective()
        default:
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.4
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            switch mode {
            case .topDown2D:
                rig.applyTopDown2D()
            case .topDown2DRotated:
                rig.applyTopDown2DRotated()
            case .perspective3D:
                cameraNode.camera?.usesOrthographicProjection = false
                rig.snapToTarget()
            }
            SCNTransaction.commit()
        }
    }

    /// 3D → 2D: animate to the *final* 2D orientation (using the mode's
    /// own up vector) inside a single `SCNTransaction`. SceneKit slerps the
    /// orientation property as a quaternion, so the rotation follows a
    /// shortest-arc path. Then a tiny stage 2 swaps perspective →
    /// orthographic, which is invisible because the camera is already
    /// looking straight down. The previous implementation animated
    /// `eulerAngles` (component-wise lerp, *not* slerp) and applied the
    /// 2D up vector via a separate `look()` in stage 2 — which produced
    /// the visible "first rotates, then snaps to 2D" feel the user
    /// reported.
    private func transitionToTopDown(_ mode: CameraMode) {
        guard let camera = cameraNode.camera, let rig = cameraRig else { return }
        isCameraModeTransitioning = true
        rig.disableSmoothPoseControl()
        camera.usesOrthographicProjection = false

        let panX = Float(rig.topDownPanOffset.x)
        let panZ = Float(rig.topDownPanOffset.y)
        // Mode-specific screen-up direction: rotated view = world +X (long
        // axis vertical on screen); non-rotated = world -Z.
        let upVector: SCNVector3 = (mode == .topDown2DRotated)
            ? SCNVector3(1, 0, 0)
            : SCNVector3(0, 0, -1)
        let topDownPosition = SCNVector3(panX, surfaceY + 5.0, panZ)
        let topDownLookAt = SCNVector3(panX, surfaceY, panZ)

        // Stage 1 — animate orientation + position to the final 2D pose
        // (still in perspective). At pitch ≈ -90° the perspective and
        // orthographic projections are visually indistinguishable, so the
        // stage-2 swap requires no further rotation.
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        camera.fieldOfView = 22
        cameraNode.position = topDownPosition
        cameraNode.look(at: topDownLookAt, up: upVector, localFront: SCNVector3(0, 0, -1))
        SCNTransaction.completionBlock = { [weak self] in
            guard let self, let camera = self.cameraNode.camera, let rig = self.cameraRig else { return }
            // Stage 2 — projection swap + minor ortho-scale settle. No
            // rotation here: the orientation is already correct from stage 1.
            camera.usesOrthographicProjection = true
            camera.orthographicScale = rig.topDownOrthographicScale * 1.05

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            camera.orthographicScale = rig.topDownOrthographicScale
            // Re-apply the mode-specific top-down to nail the exact final
            // position / orientation (eliminates any float-drift from the
            // animated transform).
            switch mode {
            case .topDown2D:
                rig.applyTopDown2D()
            case .topDown2DRotated:
                rig.applyTopDown2DRotated()
            case .perspective3D:
                break
            }
            SCNTransaction.completionBlock = { [weak self] in
                self?.isCameraModeTransitioning = false
            }
            SCNTransaction.commit()
        }
        SCNTransaction.commit()
    }

    /// 2D → 3D: animate directly to the aim pose in a single swoop.
    ///
    /// The previous two-stage approach (lift to overhead, then `enterAiming`
    /// via `smoothToPose`) caused a visible wobble: at the moment stage 1
    /// completed, the rig's internal pose state was *stale* (still
    /// reflecting whatever zoom / yaw the user had before toggling to 2D),
    /// so `captureCurrentPose()` returned that stale pose as the
    /// `smoothToPose` origin. The next frame, the rig overwrote the
    /// camera node with its stale-derived pose, snapping the camera away
    /// from where the SCNTransaction had just placed it — the user saw
    /// what felt like "switching between observation and aim" instead of
    /// a single transition.
    ///
    /// Fix:
    /// 1. Swap perspective **immediately** with a FOV chosen so the
    ///    perspective projection at the current camera height matches the
    ///    current ortho scale (visually invisible swap).
    /// 2. Single SCNTransaction animates camera position / orientation /
    ///    FOV directly to the aim pose. SceneKit slerps orientation as a
    ///    quaternion, so the path is a shortest-arc rotation from the
    ///    current 2D-rotated up-vector to the 3D default up = +Y.
    /// 3. Completion: call `rig.snapToAimPose(...)` so the rig's internal
    ///    state matches the camera's actual final pose. No subsequent
    ///    `smoothToPose` and therefore no further motion or snap.
    private func transitionToPerspective() {
        guard let camera = cameraNode.camera, let rig = cameraRig else { return }
        isCameraModeTransitioning = true
        let pivot = cueBallNode.map { visualCenter(of: $0) } ?? SCNVector3(0, surfaceY, 0)
        let aimDirection = currentAimDirection()

        // Compute the aim-pose camera pose (mirrors CameraRig.applyCameraTransform
        // at zoom = 0). This is exactly where the rig will hold the camera
        // after the SCNTransaction completes.
        let aimYaw = atan2f(-aimDirection.z, -aimDirection.x)
        let aimRadius = AimingCameraConfig.aimRadius
        let aimHeight = AimingCameraConfig.aimHeight
        let backXZ = SCNVector3(-cosf(aimYaw), 0, -sinf(aimYaw))
        let aimCameraPos = SCNVector3(
            pivot.x - backXZ.x * aimRadius,
            surfaceY + aimHeight,
            pivot.z - backXZ.z * aimRadius
        )

        // Step A: instant perspective swap with FOV matched to current ortho
        // scale. The ortho view shows half-height = `orthographicScale` at
        // any camera height. A matching perspective view at camera height H
        // needs `tan(fov/2) = orthoScale / H`. With H ≈ 5 m and ortho ≈ 1.5
        // m this gives FOV ≈ 34°, indistinguishable from the prior ortho
        // top-down at the moment of swap.
        let H = max(0.5, cameraNode.position.y - surfaceY)
        let matchedHalfTan = Float(rig.topDownOrthographicScale) / H
        let matchedFov = CGFloat(2 * atan(matchedHalfTan) * 180 / .pi)
        camera.usesOrthographicProjection = false
        camera.fieldOfView = matchedFov

        // Step B: animated swoop from the now-perspective overhead view
        // down into aim pose. Uses `look(at:up:)` so SceneKit slerps the
        // orientation between the 2D-rotated up = +X frame and the 3D
        // up = +Y frame on the shortest arc.
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.position = aimCameraPos
        cameraNode.look(
            at: pivot,
            up: SCNVector3(0, 1, 0),
            localFront: SCNVector3(0, 0, -1)
        )
        camera.fieldOfView = AimingCameraConfig.aimFov
        SCNTransaction.completionBlock = { [weak self] in
            guard let self, let rig = self.cameraRig else { return }
            // Sync rig internal state to aim pose. After this, the rig's
            // per-frame `update(_:)` writes the same pose the SCNTransaction
            // just landed on — no discontinuity, no further motion.
            rig.snapToAimPose(pivot: pivot, aimDirection: aimDirection)
            self.isCameraModeTransitioning = false
        }
        SCNTransaction.commit()
    }

    private func currentAimDirection() -> SCNVector3 {
        guard let cueBall = cueBallNode else {
            return cameraRig?.aimDirectionForCurrentYaw() ?? SCNVector3(-1, 0, 0)
        }
        let cue = visualCenter(of: cueBall)
        if let target = targetBallNodes.first {
            let targetPos = visualCenter(of: target)
            let dx = targetPos.x - cue.x
            let dz = targetPos.z - cue.z
            let len = sqrtf(dx * dx + dz * dz)
            if len > 0.0001 {
                return SCNVector3(dx / len, 0, dz / len)
            }
        }
        return cameraRig?.aimDirectionForCurrentYaw() ?? SCNVector3(-1, 0, 0)
    }

    /// Keep a world-space cue ball near a stable screen position by translating
    /// the camera pivot in XZ, matching the legacy anchored-orbit behavior.
    func lockCueBallScreenAnchor(
        in view: SCNView,
        cueBallWorld: SCNVector3,
        anchorNormalized: CGPoint
    ) {
        guard currentCameraMode == .perspective3D,
              !isCameraModeTransitioning,
              let cameraRig else { return }

        let projected = view.projectPoint(cueBallWorld)
        guard projected.z.isFinite else { return }

        let width = view.bounds.width
        let height = view.bounds.height
        guard width > 1, height > 1 else { return }

        let currentScenePoint = SCNVector3(
            projected.x,
            projected.y,
            projected.z
        )
        let targetScenePoint = SCNVector3(
            Float(width * anchorNormalized.x),
            Float(height * (1 - anchorNormalized.y)),
            projected.z
        )

        let currentWorld = view.unprojectPoint(currentScenePoint)
        let targetWorld = view.unprojectPoint(targetScenePoint)
        let delta = SCNVector3(
            currentWorld.x - targetWorld.x,
            0,
            currentWorld.z - targetWorld.z
        )
        let screenError = hypot(
            CGFloat(targetScenePoint.x - currentScenePoint.x),
            CGFloat(targetScenePoint.y - currentScenePoint.y)
        )
        guard screenError > 0.5, abs(delta.x) < 0.5, abs(delta.z) < 0.5 else { return }
        cameraRig.translatePivot(deltaXZ: delta, immediate: true)
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

    // MARK: - Pocket Markers (leather cut-out overlays)

    /// Add 6 pocket-marker overlays as flat smooth circles centered on each pocket's hole.
    ///
    /// 圆心 / 半径直接取自 `AngleSceneCalculator`（基于台球桌几何尺寸 + 球桌中心 + 袋口大小
    /// 的解析公式，源自 `.kiro/steering/table-geometry.md` 唯一事实来源）：
    /// - 角袋中心：击球区角点沿对角线外侧 42mm；半径 42mm
    /// - 中袋中心：击球区长边外侧 53mm；       半径 43mm
    ///
    /// 不再尝试从 USDZ 网格反推袋口洞中心——纯几何参数更稳定也更可预期。
    /// 圆盘禁用深度测试 + 高 renderingOrder，永远画在桌面/皮革之上，不会被遮挡。
    func addPocketMarkers() -> [SCNNode] {
        let positions = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)

        var markers: [SCNNode] = []
        markers.reserveCapacity(positions.count)
        for (index, p) in positions.enumerated() {
            let center = CGPoint(x: CGFloat(p.x), y: CGFloat(p.z))
            let radius = AngleSceneCalculator.pocketMarkerRadius(index: index)
            markers.append(makePocketMarkerCircle(at: center, radius: radius, index: index))
        }
        return markers
    }

    /// Build a flat smooth-circle disc lying on the table at `center`, covering the pocket opening.
    /// 用 SCNPlane + cornerRadius=半径 + 高 cornerSegmentCount 得到真正平滑的圆。
    /// 关键：关闭 reads/writes depth + 高 renderingOrder，使圆盘永远绘制在皮革几何之上，
    /// 不再出现"半圆被遮挡"的情况。
    private func makePocketMarkerCircle(at center: CGPoint, radius: Float, index: Int) -> SCNNode {
        let side = CGFloat(radius * 2)
        let plane = SCNPlane(width: side, height: side)
        plane.cornerRadius = CGFloat(radius)   // = side / 2 → 完整圆
        plane.cornerSegmentCount = 48          // 圆周分段数，足够平滑

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.clear     // viable / infeasible 默认不可见
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = false         // 永远绘制在最上层，不被皮革挡
        plane.materials = [material]

        let node = SCNNode(geometry: plane)
        node.name = "pocketMarker_\(index)"
        // Y 抬高一些（5mm）以防 SceneKit 在某些视角下仍出现轻微 Z-fighting；
        // 由于关闭了深度读，这里的 Y 主要起到点击 hit-test 的作用。
        node.position = SCNVector3(Float(center.x), surfaceY + 0.005, Float(center.y))
        // SCNPlane 默认躺在 XY 平面（垂直于 +Z），绕 X 轴 -π/2 后落到 XZ 平面上、面朝 +Y。
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.renderingOrder = 1000
        rootNode.addChildNode(node)
        return node
    }

    enum PocketHighlight {
        case selected, viable, infeasible
    }

    func highlightPocket(_ node: SCNNode, highlighted: Bool) {
        setPocketHighlight(node, style: highlighted ? .selected : .viable)
    }

    func setPocketHighlight(_ node: SCNNode, style: PocketHighlight) {
        guard let material = node.geometry?.materials.first else { return }
        switch style {
        case .selected:
            // 淡红色高亮：降低不透明度，让袋内纹理仍可透出，避免一片实心红。
            // emission 叠加少量红色，使圆盘在暗色台呢上依然清晰可见。
            material.diffuse.contents = UIColor(red: 1.0, green: 0.40, blue: 0.42, alpha: 0.55)
            material.emission.contents = UIColor(red: 0.55, green: 0.12, blue: 0.14, alpha: 1)
        case .viable, .infeasible:
            // 未选中的袋口（无论可行/不可行）一律不绘制叠加层，
            // 让球桌原本的袋口外观保持自然，避免在桌面上残留红/暗色阴影。
            material.diffuse.contents = UIColor.clear
            material.emission.contents = UIColor.clear
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
        // 提高假想球不透明度让其轮廓更明显；同时加微弱发光让它在 2D 顶视图上更跳脱。
        ghostMat.diffuse.contents = UIColor.yellow.withAlphaComponent(0.7)
        ghostMat.emission.contents = UIColor(red: 0.6, green: 0.5, blue: 0, alpha: 1)
        ghostMat.lightingModel = .constant
        ghostSphere.materials = [ghostMat]
        let ghost = SCNNode(geometry: ghostSphere)
        ghost.isHidden = true
        ghost.name = "ghostBall"
        rootNode.addChildNode(ghost)
        ghostBallNode = ghost

        let plCyl = SCNCylinder(radius: 0.004, height: 1)
        let plMat = SCNMaterial()
        plMat.diffuse.contents = UIColor.systemRed
        plMat.lightingModel = .constant
        plCyl.materials = [plMat]
        let pl = SCNNode(geometry: plCyl)
        pl.isHidden = true
        pl.name = "pocketLine"
        rootNode.addChildNode(pl)
        pocketLineNode = pl

        let slCyl = SCNCylinder(radius: 0.004, height: 1)
        let slMat = SCNMaterial()
        slMat.diffuse.contents = UIColor.white
        slMat.lightingModel = .constant
        slCyl.materials = [slMat]
        let sl = SCNNode(geometry: slCyl)
        sl.isHidden = true
        sl.name = "strikeLine"
        rootNode.addChildNode(sl)
        strikeLineNode = sl

        let dotSphere = SCNSphere(radius: 0.009)
        dotSphere.segmentCount = 16
        let dotMat = SCNMaterial()
        dotMat.diffuse.contents = UIColor.systemYellow
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

    /// Update the on-table aiming visualization (ghost ball, strike / pocket
    /// lines, optional angle arc + numeric label, optional line text labels).
    /// - Parameter showLineLabels: when `false`, suppresses the "瞄准线" /
    ///   "进球线" inline text labels lying flat on the cloth. The angle
    ///   numeric value (e.g. "20°") is still rendered when
    ///   `showAngleAnnotations` is true. Used by the 3D 瞄准 page where
    ///   the perspective view makes the flat-on-table text unreadable.
    func updateVisualization(
        cueBall: SCNVector3,
        targetBall: SCNVector3,
        pocket: SCNVector3,
        showAngleAnnotations: Bool = true,
        showLineLabels: Bool = true
    ) {
        let r = AngleSceneCalculator.ballRadius

        let ghostPos = AngleSceneCalculator.ghostBallPosition(
            targetBall: targetBall, pocket: pocket, ballRadius: r
        )
        ghostBallNode?.position = ghostPos
        ghostBallNode?.isHidden = false

        // Pocket line: from aim point (`pocket`) through target ball, extending
        // beyond the ghost ball so the red line and white strike line visibly form
        // the cut-angle wedge. Keep at least 6R of reverse extension for thin cuts.
        let pocketDir = unitXZ(from: targetBall, to: pocket)
        let reverseLen = max(AngleSceneCalculator.ballRadius * 6, 0.22)
        let pocketLineEnd = SCNVector3(
            targetBall.x - pocketDir.x * reverseLen,
            targetBall.y,
            targetBall.z - pocketDir.z * reverseLen
        )
        updateLineNode(pocketLineNode, from: pocket, to: pocketLineEnd)
        pocketLineNode?.isHidden = false

        updateLineNode(strikeLineNode, from: cueBall, to: ghostPos)
        strikeLineNode?.isHidden = false

        if showAngleAnnotations {
            let contact = AngleSceneCalculator.contactPointPosition(targetBall: targetBall, pocket: pocket)
            contactDotNode?.position = SCNVector3(contact.x, contact.y + 0.001, contact.z)
            contactDotNode?.isHidden = false

            updatePerpLine(targetBall: targetBall, pocket: pocket)
            perpLineNode?.isHidden = false

            updateAngleArc(cueBall: cueBall, targetBall: targetBall, pocket: pocket, ghost: ghostPos,
                           showLineLabels: showLineLabels)
            angleArcNode?.isHidden = false
        } else {
            contactDotNode?.isHidden = true
            perpLineNode?.isHidden = true
            angleArcNode?.isHidden = true
        }
    }

    private func unitXZ(from a: SCNVector3, to b: SCNVector3) -> SCNVector3 {
        let dx = b.x - a.x
        let dz = b.z - a.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 0.0001 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(dx / len, 0, dz / len)
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

    /// Draw the cut-angle arc at GHOST in the wedge formed by the two FORWARD rays
    /// (= the "backward extensions" of the visible line segments) that emerge from
    /// ghost into the open space:
    ///   • ghost → strikeForward (continuation of cue→ghost past ghost)
    ///   • ghost → target → pocket (the pocket-line direction at ghost)
    /// The angle between these two rays IS the cut angle α (acute side).
    private func updateAngleArc(cueBall: SCNVector3, targetBall: SCNVector3,
                                pocket: SCNVector3, ghost: SCNVector3,
                                showLineLabels: Bool = true) {
        angleArcNode?.childNodes.forEach { $0.removeFromParentNode() }

        let r = AngleSceneCalculator.ballRadius

        // Strike-line forward direction at ghost (= cue→ghost direction continuing past ghost).
        let dirStrikeForward = unitXZ(from: cueBall, to: ghost)
        // Pocket-line direction at ghost = target→pocket direction (= ghost→target → past target).
        let dirPocketForward = unitXZ(from: targetBall, to: pocket)

        let aStart = atan2(dirStrikeForward.z, dirStrikeForward.x)
        let aEnd   = atan2(dirPocketForward.z, dirPocketForward.x)
        var delta = aEnd - aStart
        if delta > .pi { delta -= 2 * .pi }
        if delta < -.pi { delta += 2 * .pi }
        // atan2 wrap already gives the acute-side sweep (|delta| ≤ π).

        let arcColor = UIColor.systemBlue
        let arcRadius: Float = r * 2.6
        let segments = 24
        // Single arc on the BACKWARD wedge (between strike-backward = ghost→cue and
        // pocket-backward = ghost→pocket-extension), where both visible line segments
        // already exist. The vertically-opposite forward wedge has no strike-forward
        // line drawn, so we don't put an arc there.
        for i in 0..<segments {
            let t0 = Float(i) / Float(segments)
            let t1 = Float(i + 1) / Float(segments)
            let a0 = aStart + .pi + delta * t0
            let a1 = aStart + .pi + delta * t1
            let p0 = SCNVector3(ghost.x + arcRadius * cosf(a0),
                                ghost.y + 0.0015,
                                ghost.z + arcRadius * sinf(a0))
            let p1 = SCNVector3(ghost.x + arcRadius * cosf(a1),
                                ghost.y + 0.0015,
                                ghost.z + arcRadius * sinf(a1))
            let seg = makeSmallCylinder(from: p0, to: p1, radius: 0.0028,
                                        color: arcColor)
            angleArcNode?.addChildNode(seg)
        }

        // Angle text on the OPPOSITE wedge from where the line labels live —
        // i.e. the vertically-opposite arc, away from the strike-forward / pocket-forward
        // direction so it doesn't crowd "瞄准线" / "进球线" text.
        let cutAngle = AngleSceneCalculator.cutAngle(cueBall: cueBall, targetBall: targetBall, pocket: pocket)

        let baseMidA = aStart + delta * 0.5 + .pi
        let angleText = "\(Int(cutAngle.rounded()))°"
        // Keep the numeric angle label horizontally oriented in the 2D table view.
        // CameraRig.topDown2DRotated has screen-up = world +X, so screen-horizontal
        // text baseline is world +Z.
        let strikeLabelT: Float = 0.36
        let pocketLabelT: Float = 0.55
        let lineLabelOffset = r * 2.6
        // For small angles or very short cue-target spacing, the wedge has too
        // little visual room for the text. Move the label to the side while keeping
        // it horizontal.
        let angleFontSize: CGFloat = 24
        let angleTextScale: Float = 0.0025
        let estimatedTextWorldWidth = Float(angleText.count) * Float(angleFontSize) * angleTextScale * 0.55
        let cueTargetDistance = AngleSceneCalculator.horizontalDistance(cueBall, targetBall)
        let shouldUseSideLabel = cutAngle < 30 || cueTargetDistance < estimatedTextWorldWidth * 6
        let labelAngle = shouldUseSideLabel ? baseMidA - .pi / 2 : baseMidA
        let labelDist = arcRadius + r * (shouldUseSideLabel ? 3.8 : 2.8)
        let labelPos = SCNVector3(
            ghost.x + labelDist * cosf(labelAngle),
            ghost.y + 0.003,
            ghost.z + labelDist * sinf(labelAngle)
        )
        let horizontalDir = SCNVector3(0, 0, 1)
        let label = makeAlignedFlatTextNode(text: angleText, color: arcColor,
                                            fontSize: angleFontSize, scale: angleTextScale, weight: .bold,
                                            alignDir: horizontalDir)
        label.position = labelPos
        angleArcNode?.addChildNode(label)
        angleArcNode?.position = SCNVector3(0, 0, 0)

        // Line labels along the strike line and pocket line, in matching colors.
        // Keep labels away from the ghost/angle label cluster. Suppressed in
        // 3D mode where flat-on-table text becomes unreadable.
        if showLineLabels {
            addInlineLineLabel(text: "瞄准线", color: .white,
                               lineStart: cueBall, lineEnd: ghost,
                               tParam: strikeLabelT, sideOffset: lineLabelOffset)
            addInlineLineLabel(text: "进球线", color: .systemRed,
                               lineStart: targetBall, lineEnd: pocket,
                               tParam: pocketLabelT, sideOffset: lineLabelOffset)
        }
    }

    /// Add a flat text node lying on the table plane parallel to a line.
    /// Implementation uses a parent-child node split to keep rotations clean:
    ///   • parent: yaw around world Y so its local +X aligns with the line
    ///   • child:  -π/2 around local X so the SCNText geometry lies on table
    /// `tParam` ∈ [0,1] picks the position along the line; `sideOffset` shifts
    /// the label perpendicular to the line so the line stays unobscured.
    private func addInlineLineLabel(text: String, color: UIColor,
                                    lineStart: SCNVector3, lineEnd: SCNVector3,
                                    tParam: Float, sideOffset: Float) {
        let dir = unitXZ(from: lineStart, to: lineEnd)

        // Yaw such that parent's local +X axis maps to the line direction (dx,0,dz).
        // SceneKit Y rotation: local +X → (cos yaw, 0, -sin yaw), so:
        //   cos yaw = dx, -sin yaw = dz  →  yaw = atan2(-dz, dx)
        var yaw = atan2(-dir.z, dir.x)
        // Camera in topDown2DRotated has up = world +X (screen-up = +X).
        // After lay-flat + parent yaw, text ascent ends up at (-sin yaw, 0, -cos yaw).
        // Ascent has positive X (i.e. visually upright on screen) iff sin yaw < 0,
        // which corresponds to dz > 0. So flip 180° when dz < 0.
        if dir.z < 0 { yaw += .pi }

        // 字号介于初版（20）与上次过小（16）之间，配合更大的 sideOffset 留白后视觉刚好。
        let textChild = makeFlatTextChild(text: text, color: color,
                                          fontSize: 18, scale: 0.0033, weight: .semibold)
        let parent = SCNNode()
        parent.addChildNode(textChild)
        parent.eulerAngles = SCNVector3(0, yaw, 0)
        parent.position = inlineLineLabelPosition(
            lineStart: lineStart, lineEnd: lineEnd, tParam: tParam, sideOffset: sideOffset
        )

        angleArcNode?.addChildNode(parent)
    }

    private func inlineLineLabelPosition(
        lineStart: SCNVector3, lineEnd: SCNVector3,
        tParam: Float, sideOffset: Float
    ) -> SCNVector3 {
        let dir = unitXZ(from: lineStart, to: lineEnd)
        let perp = SCNVector3(-dir.z, 0, dir.x)
        return SCNVector3(
            lineStart.x + (lineEnd.x - lineStart.x) * tParam + perp.x * sideOffset,
            lineStart.y + 0.003,
            lineStart.z + (lineEnd.z - lineStart.z) * tParam + perp.z * sideOffset
        )
    }

    /// Standalone flat text node (no yaw) — placed at origin, lay-flat applied via
    /// a child wrapper so callers can set `.position` directly without conflicts.
    private func makeFlatTextNode(text: String, color: UIColor,
                                  fontSize: CGFloat, scale: Float,
                                  weight: UIFont.Weight) -> SCNNode {
        let parent = SCNNode()
        parent.addChildNode(makeFlatTextChild(text: text, color: color,
                                              fontSize: fontSize, scale: scale, weight: weight))
        return parent
    }

    /// 与某一方向对齐的平面文字节点：文字基线（左→右）沿 `alignDir` 在 XZ 平面内排列。
    /// `flipForScreenUp` 控制是否在 `dz < 0` 时额外翻转 180°（让文字在 topDown2DRotated 下永远正向朝上）。
    /// 沿线段标注（瞄准线 / 进球线）需要这个翻转保证可读性；
    /// 而需要严格按方向排列（如角度文字朝向中心）的场景则关闭它。
    private func makeAlignedFlatTextNode(text: String, color: UIColor,
                                         fontSize: CGFloat, scale: Float,
                                         weight: UIFont.Weight,
                                         alignDir: SCNVector3,
                                         flipForScreenUp: Bool = true) -> SCNNode {
        let lenXZ = sqrtf(alignDir.x * alignDir.x + alignDir.z * alignDir.z)
        guard lenXZ > 0.0001 else {
            return makeFlatTextNode(text: text, color: color,
                                    fontSize: fontSize, scale: scale, weight: weight)
        }
        let dx = alignDir.x / lenXZ
        let dz = alignDir.z / lenXZ
        var yaw = atan2(-dz, dx)
        if flipForScreenUp, dz < 0 { yaw += .pi }

        let textChild = makeFlatTextChild(text: text, color: color,
                                          fontSize: fontSize, scale: scale, weight: weight)
        let parent = SCNNode()
        parent.addChildNode(textChild)
        parent.eulerAngles = SCNVector3(0, yaw, 0)
        return parent
    }

    /// Build a centred SCNText child rotated to lie on the table (XZ plane).
    /// The child's local +X axis = text baseline (left-to-right reading direction).
    private func makeFlatTextChild(text: String, color: UIColor,
                                   fontSize: CGFloat, scale: Float,
                                   weight: UIFont.Weight) -> SCNNode {
        let textGeo = SCNText(string: text, extrusionDepth: 0)
        textGeo.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        textGeo.flatness = 0.2
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        textGeo.materials = [mat]

        let textNode = SCNNode(geometry: textGeo)
        // Centre the text on its bounding box so position represents the centre.
        let (tMin, tMax) = textNode.boundingBox
        let cx = (tMin.x + tMax.x) * 0.5
        let cy = (tMin.y + tMax.y) * 0.5
        textNode.pivot = SCNMatrix4MakeTranslation(cx, cy, 0)
        textNode.scale = SCNVector3(scale, scale, scale)
        // Lay flat: rotate -π/2 around X (only pitch is set).
        //   local +X (baseline)   → world +X  (preserved by X rotation)
        //   local +Y (ascent)     → world -Z
        //   local +Z (front face) → world +Y  (text faces up, visible from above)
        // Parent yaw rotation around Y then aligns baseline with the line direction.
        textNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        return textNode
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
