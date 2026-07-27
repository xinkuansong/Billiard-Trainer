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
    private var tableContactShadowNode: SCNNode?
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

    /// 当前目标球号（`applyBallLayout` 记录）：进球线/标签随球色的取色依据（T-P18-41）。
    private(set) var currentTargetNumber: Int?

    /// 目标球换号时更新取色依据（条 2：角度与打点目标球可选）。
    func setCurrentTargetNumber(_ number: Int?) {
        currentTargetNumber = number
    }
    private(set) var ghostBallNode: SCNNode?
    private(set) var pocketLineNode: SCNNode?
    private(set) var strikeLineNode: SCNNode?
    private(set) var contactDotNode: SCNNode?
    private(set) var angleArcNode: SCNNode?
    private(set) var perpLineNode: SCNNode?
    /// 4x8 台面网格叠加（条 16）：`setTableGridVisible` 懒建。
    private var tableGridNode: SCNNode?

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

        // 台面网格重放（G2 根因修复）：makeUIView 可能先于本方法按偏好建网格，
        // 彼时 surfaceY 还是默认值，网格会埋进桌身。表面高度就位后重建。
        if let grid = tableGridNode, !grid.isHidden {
            setTableGridVisible(true)
        }
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

        // Cloth enhancement (multiply tint + roughness) on BOTH pipelines so the
        // plain 2D / dynamic pages don't over-saturate the USDZ felt into neon
        // green (UR-20260529 U-01 / FL-011). The plain pipeline lacks IBL/HDR
        // tone-mapping, so it needs a stronger darken/desaturate tint than studio.
        MaterialFactory.enhanceClothMaterials(
            in: model.visualNode,
            multiplyTint: enhancedRendering ? MaterialFactory.clothMultiplyStudio
                                            : MaterialFactory.clothMultiplyPlain
        )

        if enhancedRendering {
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
        currentTargetNumber = targetBallNumber
        let correctY = surfaceY + AngleSceneCalculator.ballRadius
        let cuePos = SCNVector3(cueBallPosition.x, correctY, cueBallPosition.z)
        let targetPos = SCNVector3(targetPosition.x, correctY, targetPosition.z)

        for (_, node) in allBallNodes {
            node.isHidden = true
        }

        if let cue = allBallNodes["cueBall"] {
            // 防御性重挂：若回放等流程曾把球移出父节点，仅设 isHidden=false 不够，必须重新挂回
            // 场景，否则 reset/重新摆球后球仍不可见（球"消失"bug）。
            if cue.parent == nil { rootNode.addChildNode(cue) }
            cue.opacity = 1
            BallSpinIntegrator.resetPose(cue)
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
            if target.parent == nil { rootNode.addChildNode(target) }
            target.opacity = 1
            BallSpinIntegrator.resetPose(target)
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

    // MARK: - Multi-ball free placement (Position-Play Composer, ADR-P11-01)

    /// 显示并定位任意一颗 USDZ 球（防御性重挂 + 贴台面 Y + 姿态归零）。
    /// `key`: `cueBall` / `_1`..`_15`。用于走位编排器的自由摆球——把 `allBallNodes` 里的
    /// 现成节点按需上桌。摆球即「重新开局」，故与位置一样把回放转出来的球面姿态一并复位
    /// （S5：否则同一杆反复播放起始姿态逐次漂移）。
    func showBall(key: String, scenePosition: SCNVector3) {
        guard let node = allBallNodes[key] else { return }
        let correctY = surfaceY + AngleSceneCalculator.ballRadius
        if node.parent == nil { rootNode.addChildNode(node) }
        node.removeAllActions()
        node.opacity = 1
        BallSpinIntegrator.resetPose(node)
        node.position = SCNVector3(scenePosition.x, correctY, scenePosition.z)
        node.isHidden = false
        if key == "cueBall" { cueBallNode = node }
    }

    /// 隐藏一颗球（进袋离场 / 撤下回库）。
    func hideBall(key: String) {
        allBallNodes[key]?.isHidden = true
    }

    /// 隐藏全部球（重摆前清场）。
    func hideAllBalls() {
        for (_, node) in allBallNodes { node.isHidden = true }
    }

    /// 当前在桌（可见）的球：键 → 节点。
    func visibleBalls() -> [String: SCNNode] {
        allBallNodes.filter { !$0.value.isHidden }
    }

    /// 节点 → 球键（反查，供点选目标球）。
    func ballKey(for node: SCNNode) -> String? {
        allBallNodes.first(where: { $0.value === node })?.key
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

    func updateCueStick(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float = 0) {
        // 显式重新摆杆（如击球后复位重新瞄准）会取消尚未结束的出杆/跟杆/收杆序列，
        // 避免延迟收杆把刚摆好的瞄准杆又隐藏（收杆/复位竞态）。
        cueStick?.rootNode.removeAction(forKey: "strokeAnim")
        let elevation = CueStick.requiredElevation(
            cueBallPosition: cueBallPosition, aimDirection: aimDirection
        )
        cueStick?.update(
            cueBallPosition: cueBallPosition,
            aimDirection: aimDirection,
            pullBack: pullBack,
            elevation: elevation
        )
        cueStick?.show()
    }

    func hideCueStick() {
        cueStick?.rootNode.removeAction(forKey: "strokeAnim")
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
            // Plain pipeline (2D / dynamic pages). Exposure pulled down a bit
            // so the USDZ felt is not over-exposed into neon green
            // (UR-20260529 U-01 / FL-011).
            camera.fieldOfView = 50
            camera.wantsHDR = true
            camera.wantsExposureAdaptation = false
            camera.exposureOffset = -0.45
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
        if let (halfLength, halfWidth) = measuredTableOuterHalfExtents() {
            cameraRig?.tableOuterHalfLength = halfLength
            cameraRig?.tableOuterHalfWidth = halfWidth
        }
        cameraRig?.applyTopDown2D()
    }

    /// 实测球桌外框半长/半宽（世界 X/Z），供 rotated 顶视自适应取景（ADR-P11-08）。
    /// 遍历球桌节点层级取世界空间包围盒；失败时返回 nil，rig 用兜底常量。
    private func measuredTableOuterHalfExtents() -> (halfLength: Double, halfWidth: Double)? {
        guard let table = tableNode else { return nil }
        var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude, maxZ = -Float.greatestFiniteMagnitude
        table.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let (bMin, bMax) = node.boundingBox
            for corner in [SCNVector3(bMin.x, bMin.y, bMin.z), SCNVector3(bMax.x, bMin.y, bMin.z),
                           SCNVector3(bMin.x, bMin.y, bMax.z), SCNVector3(bMax.x, bMin.y, bMax.z),
                           SCNVector3(bMin.x, bMax.y, bMin.z), SCNVector3(bMax.x, bMax.y, bMin.z),
                           SCNVector3(bMin.x, bMax.y, bMax.z), SCNVector3(bMax.x, bMax.y, bMax.z)] {
                let w = node.convertPosition(corner, to: nil)
                minX = min(minX, w.x); maxX = max(maxX, w.x)
                minZ = min(minZ, w.z); maxZ = max(maxZ, w.z)
            }
        }
        guard maxX > minX, maxZ > minZ else { return nil }
        return (Double(max(abs(minX), abs(maxX))), Double(max(abs(minZ), abs(maxZ))))
    }

    /// 实测球桌最低点世界 Y（= 桌腿底）。模型按外框长宽缩放（非按高度），故桌腿底真实 Y
    /// 无法由「台面高 − 常量桌高」推得，必须遍历几何取世界包围盒最小 Y。供 3D 取景把整桌
    /// （含腿）装入画面（否则近端桌腿掉出画面底被裁）。无表节点/无几何时返回 nil。
    func measuredTableBottomY() -> Float? {
        guard let table = tableNode else { return nil }
        var minY = Float.greatestFiniteMagnitude
        table.enumerateHierarchy { node, _ in
            guard node.geometry != nil else { return }
            let (bMin, bMax) = node.boundingBox
            for corner in [SCNVector3(bMin.x, bMin.y, bMin.z), SCNVector3(bMax.x, bMin.y, bMin.z),
                           SCNVector3(bMin.x, bMin.y, bMax.z), SCNVector3(bMax.x, bMin.y, bMax.z),
                           SCNVector3(bMin.x, bMax.y, bMin.z), SCNVector3(bMax.x, bMax.y, bMin.z),
                           SCNVector3(bMin.x, bMax.y, bMax.z), SCNVector3(bMax.x, bMax.y, bMax.z)] {
                let w = node.convertPosition(corner, to: nil)
                minY = min(minY, w.y)
            }
        }
        return minY < Float.greatestFiniteMagnitude ? minY : nil
    }

    // MARK: - Lighting

    private func setupLighting() {
        if enhancedRendering {
            setupStudioLighting()
        } else {
            setupPlainLighting()
        }
    }

    /// Cheap plain lighting used by the 2D / dynamic pages.
    /// Intensities lowered (was ambient 1000 / dir 1400 / fill 500) so the
    /// USDZ-baked felt is not blown out into neon green; combined with the
    /// plain-camera exposure pull-down and `enhanceClothMaterials`, the cloth
    /// reads as a natural deep green closer to the 3D studio look
    /// (UR-20260529 U-01 / FL-011).
    private func setupPlainLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 450
        ambient.light?.color = UIColor.white
        rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.intensity = 820
        directional.light?.color = UIColor.white
        directional.light?.castsShadow = true
        directional.light?.shadowRadius = 4
        directional.light?.shadowSampleCount = 4
        directional.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        rootNode.addChildNode(directional)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.intensity = 200
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
        // ── Key Light: 5800K, casts a real shadow straight onto the USDZ
        // cloth (forward shadow map, not deferred screen-space — the deferred
        // pass was being washed out by HDR tone-mapping + IBL fill, leaving
        // the balls looking like they floated). A near-overhead pitch keeps
        // the contact shadow tucked under each ball so it reads as grounded.
        // `automaticallyAdjustsShadowProjection` stays on: it fits the shadow
        // frustum to the casters (balls + table), and the 40 m ground plane is
        // a non-caster (`castsShadow = false`) so it can't bloat the frustum.
        let key = SCNLight()
        key.type = .directional
        key.intensity = 820
        key.temperature = 5800
        key.castsShadow = true
        key.shadowMode = .forward
        key.shadowRadius = 3
        key.shadowSampleCount = 16
        key.shadowColor = UIColor(white: 0.0, alpha: 0.55)
        key.shadowMapSize = CGSize(width: 2048, height: 2048)
        key.shadowBias = 0.008

        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(0, 4, 0)
        keyNode.eulerAngles = SCNVector3(
            -74.0 * Float.pi / 180.0,
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

        setupLegFillLighting()
    }

    /// Raking fill lights for the lower table body (skirt + legs).
    ///
    /// 黑底 + 近垂直的 key light 下，竖直的桌身/桌腿立面几乎收不到光，在导出
    /// 视频与 3D 页里读作「没有腿」（FL-023 修复几何后腿仍欠曝）。补三盏近水平
    /// 的低位 directional fill 专照台面以下的立面：水平入射对水平台呢影响极小，
    /// 不破坏 key/fill/rim 的球体塑形与布面投影。
    private func setupLegFillLighting() {
        func addRakingFill(from position: SCNVector3, intensity: CGFloat) {
            let node = SCNNode()
            let light = SCNLight()
            light.type = .directional
            light.intensity = intensity
            light.temperature = 6200
            light.castsShadow = false
            node.light = light
            node.position = position
            // 瞄向桌身下半部中心（低于台面），光沿近水平方向掠过立面。
            node.look(at: SCNVector3(0, surfaceY * 0.45, 0),
                      up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
            rootNode.addChildNode(node)
            enhancedLightNodes.append(node)
        }

        // 前方（+X，导出相机端）主 fill：照亮相机看得见的立面 + 近端腿。
        addRakingFill(from: SCNVector3(3.0, surfaceY * 0.55, 0.0), intensity: 550)
        // 两侧（±Z）辅 fill：补齐侧面裙板与侧腿，避免只有一面亮。
        addRakingFill(from: SCNVector3(1.2, surfaceY * 0.55, 2.4), intensity: 300)
        addRakingFill(from: SCNVector3(1.2, surfaceY * 0.55, -2.4), intensity: 300)
    }

    // MARK: - Ground (enhanced only)

    /// Single unlit visual floor plane at `Y = BTSceneLayout.groundLevelY`.
    ///
    /// 背景统一纯黑后（见 `EnhancedEnvironment`），这块地板比纯黑略亮、呈中性深灰，
    /// 让球桌"踩"在一块可辨认的地板上，而不是浮在黑底里；再叠一层烘焙接地阴影
    /// (`setupContactShadow`) 强化"落地感"。布面的真实投影仍由 key light 落在台呢上。
    private func setupGround() {
        let planeSize: CGFloat = 40

        let visualPlane = SCNPlane(width: planeSize, height: planeSize)
        let visualMat = SCNMaterial()
        visualMat.lightingModel = .constant
        // 渲染统一（问题集合条 11.1）：台面以下地面改**纯黑**，与场景背景融为一体；
        // 桌腿可见性仍由 `setupLegFillLighting` 补光承担（FL-023 的另一半）。
        visualMat.diffuse.contents = UIColor.black
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

        setupContactShadow()
    }

    /// 桌底接地阴影（grounding shadow）：在地板上铺一块软椭圆暗斑，正对球桌外框下方。
    /// 烘焙纹理、不依赖实时光照，黑/暗背景下让球桌读作"落在地板上"而非悬空。
    private func setupContactShadow() {
        let cushion = CGFloat(BTTablePhysics.cushionThickness)
        let outerLength = CGFloat(AngleSceneCalculator.innerLength) + 2 * cushion + 0.18
        let outerWidth = CGFloat(AngleSceneCalculator.innerWidth) + 2 * cushion + 0.18
        // 比外框略大，软边自然外扩。
        let plane = SCNPlane(width: outerLength * 1.18, height: outerWidth * 1.34)

        let mat = SCNMaterial()
        mat.diffuse.contents = Self.contactShadowTexture(size: 256)
        mat.lightingModel = .constant
        mat.isDoubleSided = false
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = true
        mat.transparencyMode = .aOne   // 透明度取自纹理 alpha（与 addTableCenterGlow 同约定）
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.name = "ground_contact_shadow"
        node.eulerAngles.x = -.pi / 2
        // 略高于地板，避免与地板共面 z-fighting。
        node.position = SCNVector3(0, BTSceneLayout.groundLevelY + 0.001, 0)
        node.castsShadow = false
        node.renderingOrder = -9   // 画在地板之上
        rootNode.addChildNode(node)
        tableContactShadowNode = node
    }

    /// 径向软阴影纹理：黑色，中心 alpha≈0.55 → 边缘全透明（RGBA，配 `.aOne` 透明度）。
    private static func contactShadowTexture(size: Int) -> UIImage {
        let s = CGFloat(size)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: s, height: s))
        return renderer.image { ctx in
            let center = CGPoint(x: s / 2, y: s / 2)
            if let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(white: 0, alpha: 0.55).cgColor,
                    UIColor(white: 0, alpha: 0.34).cgColor,
                    UIColor(white: 0, alpha: 0.0).cgColor
                ] as CFArray,
                locations: [0.0, 0.55, 1.0]
            ) {
                ctx.cgContext.drawRadialGradient(
                    grad,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: s * 0.5,
                    options: []
                )
            }
        }
    }

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

    /// 画一条虚线（由等距短实线段拼成），用于真实模式下的「理想路线」对照。
    /// 返回的父节点持有所有段，便于统一清理。
    func addDashedLine(from start: SCNVector3, to end: SCNVector3, color: UIColor,
                       radius: Float = 0.003, dash: Float = 0.03, gap: Float = 0.022) -> SCNNode {
        let parent = SCNNode()
        let dx = end.x - start.x, dy = end.y - start.y, dz = end.z - start.z
        let total = sqrtf(dx * dx + dy * dy + dz * dz)
        guard total > 0.001 else { return parent }
        let ux = dx / total, uy = dy / total, uz = dz / total
        let stride = dash + gap
        var t: Float = 0
        while t < total {
            let segLen = min(dash, total - t)
            guard segLen > 0.001 else { break }
            let a = SCNVector3(start.x + ux * t, start.y + uy * t, start.z + uz * t)
            let b = SCNVector3(start.x + ux * (t + segLen),
                               start.y + uy * (t + segLen),
                               start.z + uz * (t + segLen))
            parent.addChildNode(makeSegment(from: a, to: b, color: color, radius: radius))
            t += stride
        }
        rootNode.addChildNode(parent)
        return parent
    }

    /// 不挂载到 root 的单段圆柱，供 `addDashedLine` 组装。
    private func makeSegment(from start: SCNVector3, to end: SCNVector3,
                             color: UIColor, radius: Float) -> SCNNode {
        let dx = end.x - start.x, dy = end.y - start.y, dz = end.z - start.z
        let length = sqrtf(dx * dx + dy * dy + dz * dz)
        let cylinder = SCNCylinder(radius: CGFloat(radius), height: CGFloat(max(length, 0.0005)))
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .constant
        cylinder.materials = [material]
        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3((start.x + end.x) / 2, (start.y + end.y) / 2, (start.z + end.z) / 2)
        node.look(at: SCNVector3(end.x, end.y, end.z), up: rootNode.worldUp,
                  localFront: SCNVector3(0, 1, 0))
        return node
    }

    // MARK: - Trajectory polylines（线语言 v2，问题集合条 12）

    /// 沿折线按**弧长**铺虚线：真实轨迹采样点很密，逐段 `addDashedLine` 会退化成实线；
    /// 这里按整数周期索引遍历 on 段再与折线段求交（FL-024 教训：浮点相位累积推进会因
    /// Float 精度下 step 下溢为 0 导致主线程死循环；整数索引循环有界，必然终止）。
    func addDashedPolyline(_ pts: [SCNVector3], color: UIColor,
                           radius: Float = TrajectoryStyle.lineMain,
                           dash: Float = TrajectoryStyle.mainDash,
                           gap: Float = TrajectoryStyle.mainGap,
                           into nodes: inout [SCNNode]) {
        guard pts.count >= 2, dash > 1e-4, gap > 1e-4 else { return }
        let period = dash + gap
        var arc: Float = 0
        func lerp(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
            SCNVector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
        }
        for i in 0..<(pts.count - 1) {
            let a = pts[i], b = pts[i + 1]
            let len = AngleSceneCalculator.horizontalDistance(a, b)
            guard len > 1e-6 else { continue }
            let firstK = Int((arc / period).rounded(.down))
            let lastK = Int(((arc + len) / period).rounded(.down))
            for k in firstK...lastK {
                let onStart = Float(k) * period
                let s = max(onStart, arc)
                let e = min(onStart + dash, arc + len)
                guard e - s > 1e-4 else { continue }
                nodes.append(addLine(from: lerp(a, b, (s - arc) / len),
                                     to: lerp(a, b, (e - arc) / len),
                                     color: color, radius: radius))
            }
            arc += len
        }
    }

    /// 母球轨迹（线语言 v2）：碰前段 = 白**实线**瞄准线；碰后段 = 白**虚线**轨迹。
    /// `contact` = 首次球-球碰撞时母球位置；nil（空杆）时以首个吃库拐点为界——
    /// 瞄准线延伸到库边（条 12.5），吃库反弹后为虚线轨迹。
    /// `detail == .minimal` 时只画实线瞄准段（三档标注最简档）。
    func addCueTrajectory(_ pts: [SCNVector3], contact: SCNVector3?,
                          detail: TrajectoryDetail = .full,
                          into nodes: inout [SCNNode]) {
        guard pts.count >= 2 else { return }
        let split = cueSplitIndex(pts, contact: contact)
        // 实线瞄准段。
        for i in 0..<split {
            nodes.append(addLine(from: pts[i], to: pts[i + 1],
                                 color: TrajectoryStyle.aimColor,
                                 radius: TrajectoryStyle.aimRadius))
        }
        // 虚线轨迹段。
        if detail != .minimal, split < pts.count - 1 {
            addDashedPolyline(Array(pts[split...]), color: TrajectoryStyle.aimColor,
                              radius: TrajectoryStyle.aimRadius, into: &nodes)
        }
    }

    /// 被带动球轨迹（含目标球）：本球色**虚线**（黑 8 亮灰变体，条 12.2/12.4）。
    func addObjectTrajectory(_ pts: [SCNVector3], ballKey: String,
                             into nodes: inout [SCNNode]) {
        addDashedPolyline(pts, color: TrajectoryStyle.potColor(for: ballKey),
                          radius: TrajectoryStyle.potRadius, into: &nodes)
    }

    /// 母球折线的实/虚分界索引：优先取距 `contact` 最近的采样点；
    /// 空杆时取首个显著方向变化点（吃库反弹），全程直线则整条为瞄准线。
    private func cueSplitIndex(_ pts: [SCNVector3], contact: SCNVector3?) -> Int {
        if let c = contact {
            var best = pts.count - 1
            var bestD = Float.greatestFiniteMagnitude
            for (i, p) in pts.enumerated() {
                let dx = p.x - c.x, dz = p.z - c.z
                let d = dx * dx + dz * dz
                if d < bestD { bestD = d; best = i }
            }
            return best
        }
        guard pts.count >= 3 else { return pts.count - 1 }
        let cosThreshold: Float = 0.9986   // ≈ 3°
        for i in 1..<(pts.count - 1) {
            let ax = pts[i].x - pts[i - 1].x, az = pts[i].z - pts[i - 1].z
            let bx = pts[i + 1].x - pts[i].x, bz = pts[i + 1].z - pts[i].z
            let la = sqrtf(ax * ax + az * az), lb = sqrtf(bx * bx + bz * bz)
            guard la > 1e-5, lb > 1e-5 else { continue }
            let dot = (ax * bx + az * bz) / (la * lb)
            if dot < cosThreshold { return i }
        }
        return pts.count - 1
    }

    // MARK: - Shared selection ring & teaching overlays

    /// 选中环颜色（亮绿，统一全 App 点选球反馈）。
    static let selectionRingColor = UIColor(red: 0.36, green: 0.92, blue: 0.55, alpha: 0.95)
    /// 90° 分离角辅助线颜色 = 线语言统一品牌绿短虚线（DR-021，弃白免与母球轨迹混淆）。
    static let separationLineColor = TrajectoryStyle.separationColor

    /// 在 `center` 处画一个圆环（由短线段拼成），返回持有所有段的父节点，便于统一清理。
    @discardableResult
    func addRing(center: SCNVector3, radius: Float, color: UIColor,
                 lineRadius: Float = 0.0022, segments: Int = 40) -> SCNNode {
        let parent = SCNNode()
        let y = center.y
        var prev: SCNVector3?
        for i in 0...segments {
            let a = Float(i) / Float(segments) * 2 * .pi
            let p = SCNVector3(center.x + radius * cosf(a), y, center.z + radius * sinf(a))
            if let pr = prev {
                parent.addChildNode(makeSegment(from: pr, to: p, color: color, radius: lineRadius))
            }
            prev = p
        }
        rootNode.addChildNode(parent)
        return parent
    }

    /// 选中球的常驻选中环（半径略大于球，浮于台面之上）。
    @discardableResult
    func addSelectionRing(at center: SCNVector3,
                          color: UIColor = AngleTrainingScene.selectionRingColor) -> SCNNode {
        addRing(center: SCNVector3(center.x, surfaceY + 0.002, center.z),
                radius: AngleSceneCalculator.ballRadius * 1.75, color: color)
    }

    // 注：自由瞄准手柄圆环节点已删除（T-P18-43，设计稿 §1.5「砍」）——粗调改为
    // `AngleSceneView.onAimDragged` 手指跟随（空白处起手拖动即指哪打哪），瞄准线上不再放控件。

    /// 90° 分离角辅助线：过首次碰撞点（≈幽灵球中心），沿切线方向（垂直于撞击线）双向延伸。
    /// 由调用方按用户设置（`UserPreferences.showSeparationAngle`）决定是否调用。
    /// 返回是否成功绘制（无球-球碰撞时 `tangentDir` 为 nil，不画）。
    @discardableResult
    func addSeparationAngleLine(for p: ShotPrediction, into nodes: inout [SCNNode]) -> Bool {
        guard let tangent = p.tangentDir else { return false }
        let len = sqrtf(tangent.x * tangent.x + tangent.z * tangent.z)
        guard len > 0.0001 else { return false }
        let ux = tangent.x / len, uz = tangent.z / len
        let center = p.firstContact ?? p.ghost
        let half: Float = 0.30
        let y = surfaceY + AngleSceneCalculator.ballRadius
        let a = SCNVector3(center.x - ux * half, y, center.z - uz * half)
        let b = SCNVector3(center.x + ux * half, y, center.z + uz * half)
        nodes.append(addDashedLine(from: a, to: b, color: AngleTrainingScene.separationLineColor,
                                   radius: TrajectoryStyle.lineHint,
                                   dash: TrajectoryStyle.hintDash * 0.7,
                                   gap: TrajectoryStyle.hintGap * 0.7))
        return true
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
        let positions = AngleSceneCalculator.pocketMarkerPositions(surfaceY: surfaceY)

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

    // MARK: - Flat Labels / Diamond Guides (颗星公式解球)

    /// Add a flat text label lying on the cloth, oriented to read horizontally in
    /// the rotated 2D top-down view (screen-up = world +X, so screen-horizontal
    /// text runs along world +Z).
    @discardableResult
    func addFlatLabel(text: String, at position: SCNVector3, color: UIColor,
                      fontSize: CGFloat = 15) -> SCNNode {
        let node = makeAlignedFlatTextNode(
            text: text, color: color,
            fontSize: fontSize, scale: 0.0030, weight: .semibold,
            alignDir: SCNVector3(0, 0, 1), flipForScreenUp: false
        )
        node.position = position
        rootNode.addChildNode(node)
        return node
    }

    /// Lay down the rail diamond number labels + small tick markers in one pass.
    /// Returns every created node so the caller can clear them later.
    func addDiamondGuides(labels: [DiamondSystemCalculator.DiamondLabel],
                          ticks: [SCNVector3],
                          labelColor: UIColor,
                          tickColor: UIColor) -> [SCNNode] {
        var nodes: [SCNNode] = []
        nodes.reserveCapacity(labels.count + ticks.count)

        for tick in ticks {
            let sphere = SCNSphere(radius: 0.006)
            sphere.segmentCount = 12
            let mat = SCNMaterial()
            mat.diffuse.contents = tickColor
            mat.lightingModel = .constant
            sphere.materials = [mat]
            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(tick.x, tick.y, tick.z)
            rootNode.addChildNode(node)
            nodes.append(node)
        }

        for label in labels {
            nodes.append(addFlatLabel(text: label.text, at: label.position, color: labelColor))
        }

        return nodes
    }

    // MARK: - Visualization Setup (pre-create all nodes once)

    /// 虚线条纹纹理（白段 + 透明 gap，比例 = `mainDash:mainGap`）：供需逐帧改长度的
    /// 常驻线节点（进球线预览）以纹理方式呈现虚线，避免每帧重建段节点。
    static let dashStripeTexture: UIImage = {
        let h = 64
        let dashFrac = CGFloat(TrajectoryStyle.mainDash / (TrajectoryStyle.mainDash + TrajectoryStyle.mainGap))
        let size = CGSize(width: 4, height: CGFloat(h))
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: size.height * dashFrac))
        }
    }()

    /// 虚线纹理一周期对应的世界长度（米）。
    static let dashStripePeriod: Float = TrajectoryStyle.mainDash + TrajectoryStyle.mainGap

    // MARK: - 4x8 台面网格（条 16）

    /// 显隐 4x8 台面网格：短边 4 等分（3 条纵长线）+ 长边 8 等分（7 条横线），
    /// 白色低透明细线贴台呢，教学定位参考。首次开启时懒建，此后仅切换 isHidden。
    func setTableGridVisible(_ visible: Bool) {
        let y = surfaceY + 0.0015
        if let grid = tableGridNode {
            // 台面高度未变：仅切换显隐。若 scene 在网格懒建后才 setupTable
            //（如进页时偏好已开启，makeUIView 先于 VM setupScene 调用），
            // 旧网格建在默认 surfaceY 上、埋进桌身不可见——移除重建。
            if abs(grid.position.y - y) < 1e-4 {
                grid.isHidden = !visible
                return
            }
            grid.removeFromParentNode()
            tableGridNode = nil
        }
        guard visible else { return }

        let grid = SCNNode()
        grid.name = "tableGrid"
        grid.position = SCNVector3(0, y, 0)
        let mat = SCNMaterial()
        // G2（问题集合 v3）：网格提亮为灰白色——0.28 alpha 在深色台呢上过暗。
        mat.diffuse.contents = UIColor.white.withAlphaComponent(0.55)
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let lineW: CGFloat = 0.0022

        func addLine(from a: SCNVector3, to b: SCNVector3) {
            let dx = b.x - a.x, dz = b.z - a.z
            let len = sqrtf(dx * dx + dz * dz)
            guard len > 1e-4 else { return }
            let geo = SCNCylinder(radius: lineW / 2, height: CGFloat(len))
            geo.radialSegmentCount = 6
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            // Y 由父节点 grid.position.y 承担，子节点相对 0。
            node.position = SCNVector3((a.x + b.x) / 2, 0, (a.z + b.z) / 2)
            node.simdOrientation = simd_quatf(from: simd_float3(0, 1, 0),
                                              to: simd_normalize(simd_float3(dx, 0, dz)))
            grid.addChildNode(node)
        }

        // 长边 8 等分 → 7 条横线（垂直长轴）。
        for i in 1..<8 {
            let x = -halfL + AngleSceneCalculator.innerLength * Float(i) / 8
            addLine(from: SCNVector3(x, y, -halfW), to: SCNVector3(x, y, halfW))
        }
        // 短边 4 等分 → 3 条纵线（沿长轴）。
        for i in 1..<4 {
            let z = -halfW + AngleSceneCalculator.innerWidth * Float(i) / 4
            addLine(from: SCNVector3(-halfL, y, z), to: SCNVector3(halfL, y, z))
        }

        rootNode.addChildNode(grid)
        tableGridNode = grid
    }

    func setupVisualizationNodes() {
        let r = AngleSceneCalculator.ballRadius

        // 假想球（重叠标注 L0，T-P18-42）：品牌绿虚线圈替代旧黄色实心球。
        // 圈 = 母球瞄准落点轮廓，贴台呢平放；与接触点绿点构成全场景常驻的
        // 「什么角度打哪里」教学层（设计稿 §1.3）。节点中心仍在球心高度，
        // 调用方 API（position = 假想球球心、isHidden 开关）不变。
        let ghost = SCNNode()
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = TrajectoryStyle.contactColor
        ringMat.lightingModel = .constant
        let dashCount = 16
        let ringDashLen = 2 * Float.pi * r / Float(dashCount) * 0.55
        for i in 0..<dashCount {
            let theta = Float(i) / Float(dashCount) * 2 * .pi
            let segGeo = SCNCylinder(radius: CGFloat(TrajectoryStyle.lineHint),
                                     height: CGFloat(ringDashLen))
            segGeo.materials = [ringMat]
            let seg = SCNNode(geometry: segGeo)
            seg.position = SCNVector3(r * cosf(theta), -r + 0.002, r * sinf(theta))
            // 圆柱轴默认 +Y，转到圆周切线方向平躺。
            seg.simdOrientation = simd_quatf(from: simd_float3(0, 1, 0),
                                             to: simd_float3(-sinf(theta), 0, cosf(theta)))
            ghost.addChildNode(seg)
        }
        // 瞄准点红心（线语言 v2，条 1.6/4.2）：假想球球心是瞄准参考点，
        // 作为 ghost 子节点随其显隐/移动，所有用假想球的页面自动获得。
        // C15/D8：几何走单一真源 `makeAimPointMarkerNode`（0.0065 球）。
        let aimDot = Self.makeAimPointMarkerNode(color: TrajectoryStyle.aimPointColor)
        aimDot.position = SCNVector3(0, -r + 0.004, 0)   // 球心正下方贴台呢，顶视/斜视均可见
        aimDot.name = "ghostAimDot"
        ghost.addChildNode(aimDot)

        ghost.isHidden = true
        ghost.name = "ghostBall"
        rootNode.addChildNode(ghost)
        ghostBallNode = ghost

        // 进球线：颜色运行时随目标球本色；线语言 v2（条 12.2）改为**虚线**——
        // 单根圆柱贴条纹纹理（白段 + 透明 gap），wrapT=.repeat + contentsTransform
        // 随长度缩放，拖动逐帧改长度也无需重建虚线段节点。
        let plCyl = SCNCylinder(radius: CGFloat(TrajectoryStyle.lineMain), height: 1)
        let plMat = SCNMaterial()
        plMat.diffuse.contents = Self.dashStripeTexture
        plMat.diffuse.wrapT = .repeat
        plMat.multiply.contents = TrajectoryStyle.potColor(forNumber: nil)
        plMat.lightingModel = .constant
        plCyl.materials = [plMat]
        let pl = SCNNode(geometry: plCyl)
        pl.isHidden = true
        pl.name = "pocketLine"
        rootNode.addChildNode(pl)
        pocketLineNode = pl

        let slCyl = SCNCylinder(radius: CGFloat(TrajectoryStyle.lineMain), height: 1)
        let slMat = SCNMaterial()
        slMat.diffuse.contents = UIColor.white
        slMat.lightingModel = .constant
        slCyl.materials = [slMat]
        let sl = SCNNode(geometry: slCyl)
        sl.isHidden = true
        sl.name = "strikeLine"
        rootNode.addChildNode(sl)
        strikeLineNode = sl

        // 接触点：品牌绿（T-P18-41 线语言，弃黄）。
        let dotSphere = SCNSphere(radius: 0.009)
        dotSphere.segmentCount = 16
        let dotMat = SCNMaterial()
        dotMat.diffuse.contents = TrajectoryStyle.contactColor
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

        // 90° 释义线（过假想球球心、垂直于撞击线）：品牌绿短虚线（DR-021）。
        // 长度恒定（±4R）→ 虚线段一次性建成子节点，更新时只动父节点位姿，拖动零重建。
        let pp = SCNNode()
        let perpHalf = AngleSceneCalculator.ballRadius * 4
        let ppMat = SCNMaterial()
        ppMat.diffuse.contents = TrajectoryStyle.separationColor
        ppMat.lightingModel = .constant
        let dashLen = TrajectoryStyle.hintDash * 0.7   // 短虚线：比对照线更碎，一眼区分「释义」
        let gapLen = TrajectoryStyle.hintGap * 0.7
        var yCursor = -perpHalf
        while yCursor < perpHalf {
            let segLen = min(dashLen, perpHalf - yCursor)
            let segGeo = SCNCylinder(radius: CGFloat(TrajectoryStyle.lineHint), height: CGFloat(segLen))
            segGeo.materials = [ppMat]
            let seg = SCNNode(geometry: segGeo)
            seg.position = SCNVector3(0, yCursor + segLen / 2, 0)
            pp.addChildNode(seg)
            yCursor += segLen + gapLen
        }
        pp.isHidden = true
        pp.name = "perpLine"
        rootNode.addChildNode(pp)
        perpLineNode = pp
    }

    // MARK: - Aim Point Markers（C15/D8：瞄准点标记单一真源）

    /// 瞄准点标记半径（D8 拍板：0.0065 球，随 ghost aimDot / `updateVisualization` 现状口径）。
    static let aimPointMarkerRadius: CGFloat = 0.0065

    /// 构建瞄准点标记节点（未挂载）：0.0065 半径小球 + constant 光照。
    /// ghost aimDot 与独立标记共用本工厂，几何/材质单点定义。
    static func makeAimPointMarkerNode(color: UIColor) -> SCNNode {
        let geo = SCNSphere(radius: aimPointMarkerRadius)
        geo.segmentCount = 12
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.lightingModel = .constant
        geo.materials = [mat]
        return SCNNode(geometry: geo)
    }

    /// 在给定世界位置放一枚独立瞄准点标记（挂到 root，调用方持有并负责清理）。
    /// 供瞄准点测验等不走 `updateVisualization` 常驻 ghost 的页面复用（消灭私有实现）。
    @discardableResult
    func addAimPointMarker(at position: SCNVector3,
                           color: UIColor = TrajectoryStyle.aimPointColor) -> SCNNode {
        let node = Self.makeAimPointMarkerNode(color: color)
        node.name = "aimPointMarker"
        node.position = position
        rootNode.addChildNode(node)
        return node
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
    /// - Parameter showAngleAnnotations: when `false`, suppresses the numeric
    ///   angle arc (e.g. "20°"). Used by quiz assist mode where the value is
    ///   the answer being tested (T-P18-48).
    /// - Parameter showOverlapMarkers: contact dot + 90° separation short dash
    ///   （§1.2/§1.3 重叠标注 L1）。Independent of the numeric arc so assist
    ///   mode can keep the markers without revealing the answer.
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
        showOverlapMarkers: Bool = true,
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
        // 进球线绑定目标球本色（黑 8 取亮灰变体）；虚线由条纹纹理呈现，色走 multiply。
        pocketLineNode?.geometry?.firstMaterial?.multiply.contents =
            TrajectoryStyle.potColor(forNumber: currentTargetNumber)
        pocketLineNode?.isHidden = false

        updateLineNode(strikeLineNode, from: cueBall, to: ghostPos)
        strikeLineNode?.isHidden = false

        if showOverlapMarkers {
            let contact = AngleSceneCalculator.contactPointPosition(targetBall: targetBall, pocket: pocket)
            contactDotNode?.position = SCNVector3(contact.x, contact.y + 0.001, contact.z)
            contactDotNode?.isHidden = false

            updatePerpLine(ghost: ghostPos, targetBall: targetBall, pocket: pocket)
            perpLineNode?.isHidden = false
        } else {
            contactDotNode?.isHidden = true
            perpLineNode?.isHidden = true
        }

        if showAngleAnnotations {
            updateAngleArc(cueBall: cueBall, targetBall: targetBall, pocket: pocket, ghost: ghostPos,
                           showLineLabels: showLineLabels)
            angleArcNode?.isHidden = false
        } else {
            angleArcNode?.isHidden = true
        }
    }

    // MARK: - Overlap Annotation L0 helpers (T-P18-42)

    /// 重叠标注 L0：把共享接触点绿点摆到「假想球→目标球」连线上的切点。
    /// 自由瞄准 / 解叠加等不走 `updateVisualization` 的路径共用本方法补齐 L0。
    func updateContactDot(ghostCenter: SCNVector3, targetCenter: SCNVector3) {
        guard let dot = contactDotNode else { return }
        let r = AngleSceneCalculator.ballRadius
        let dx = targetCenter.x - ghostCenter.x
        let dz = targetCenter.z - ghostCenter.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 1e-5 else {
            dot.isHidden = true
            return
        }
        dot.position = SCNVector3(ghostCenter.x + dx / len * r,
                                  ghostCenter.y + 0.001,
                                  ghostCenter.z + dz / len * r)
        dot.isHidden = false
    }

    func hideContactDot() {
        contactDotNode?.isHidden = true
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
            // 虚线纹理节点（进球线）：随长度缩放条纹重复数，保持虚线节奏恒定。
            if node.name == "pocketLine", let mat = cyl.firstMaterial {
                let repeats = max(1, length / Self.dashStripePeriod)
                mat.diffuse.contentsTransform = SCNMatrix4MakeScale(1, repeats, 1)
            }
        }
        node.position = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        node.look(at: end, up: rootNode.worldUp, localFront: SCNVector3(0, 1, 0))
    }

    /// 90° 释义线过**假想球球心**（母球碰撞瞬间的位置）——定杆母球沿此切线离开；
    /// 方向垂直于撞击线（假想球→目标球，与进球线同向）。DR-021 修正：原锚在目标球心。
    private func updatePerpLine(ghost: SCNVector3, targetBall: SCNVector3, pocket: SCNVector3) {
        guard let node = perpLineNode else { return }
        let dx = pocket.x - targetBall.x
        let dz = pocket.z - targetBall.z
        let dist = sqrtf(dx * dx + dz * dz)
        guard dist > 0.001 else { return }
        // 虚线段建在父节点局部 +Y 轴上，这里只需摆位姿（look 的 localFront = +Y）。
        let perpX = -dz / dist
        let perpZ = dx / dist
        node.position = ghost
        let lookTarget = SCNVector3(ghost.x + perpX, ghost.y, ghost.z + perpZ)
        node.look(at: lookTarget, up: rootNode.worldUp, localFront: SCNVector3(0, 1, 0))
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

        // 角度弧 = 品牌绿 + 白读数（T-P18-41 线语言，弃蓝）。
        let arcColor = TrajectoryStyle.contactColor
        let arcRadius: Float = r * 2.6
        let segments = 24
        // K3：弧画在前向楔形（瞄准前向 ↔ 进球前向）。旧实现用 aStart+π 落在背向楔形。
        // 坐标契约：SceneKit XZ 水平、Y 上；水平角 atan2(z,x)；见 build/x1-evidence/k3-*.
        for i in 0..<segments {
            let t0 = Float(i) / Float(segments)
            let t1 = Float(i + 1) / Float(segments)
            let a0 = aStart + delta * t0
            let a1 = aStart + delta * t1
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

        // Angle text on the FORWARD wedge bisector (or side of that wedge when tight).
        let cutAngle = AngleSceneCalculator.cutAngle(cueBall: cueBall, targetBall: targetBall, pocket: pocket)

        let baseMidA = aStart + delta * 0.5
        let angleText = "\(Int(cutAngle.rounded()))°"
        let strikeLabelT: Float = 0.36
        let pocketLabelT: Float = 0.55
        let lineLabelOffset = r * 2.6
        // For small angles or very short cue-target spacing, the wedge has too
        // little visual room for the text. Move the label to the side of the
        // forward bisector while keeping alignment along the bisector/aim ray.
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
        // Align baseline along the forward bisector (aim/pocket wedge mid), not fixed world +Z.
        let alignDir = SCNVector3(cosf(baseMidA), 0, sinf(baseMidA))
        let label = makeAlignedFlatTextNode(text: angleText, color: .white,
                                            fontSize: angleFontSize, scale: angleTextScale, weight: .bold,
                                            alignDir: alignDir)
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
            // 标签随进球线同色（T-P18-41：进球线绑定目标球本色）。
            addInlineLineLabel(text: "进球线",
                               color: TrajectoryStyle.potColor(forNumber: currentTargetNumber),
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
        // Camera in topDown2DRotated has up = world +X (screen-up = +X), right = +Z.
        // After lay-flat + parent yaw, text ascent ends up at (-sin yaw, 0, -cos yaw),
        // its screen-up component = dz. 常规线：dz < 0 时翻 180° 保证字面朝上。
        // T-P18-35：接近屏幕垂直的线（|dz| 很小）字面朝向不再是主要信息，
        // 此时改为保证**读向**从屏幕上→下（中文竖排习惯），即基线的屏幕上分量
        // (dx) 为负；否则「瞄准线」出现下→上读向，观感像倒置。
        let nearVertical = abs(dir.z) < 0.15
        let shouldFlip = nearVertical ? dir.x > 0 : dir.z < 0
        if shouldFlip { yaw += .pi }

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
