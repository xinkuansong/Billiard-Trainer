import SceneKit

/// Loads the TaiQiuZhuo.usdz billiard table model and adapts it
/// to the SceneKit coordinate system for angle training.
/// Visual-only: physics bodies are stripped, cameras/lights removed.
/// Extracts ball nodes and cue stick for dynamic control.
final class TableModelLoader {

    // MARK: - Types

    struct TableModel {
        let visualNode: SCNNode
        let appliedScale: SCNVector3
        let surfaceY: Float
        let cueStickNode: SCNNode?
        let ballNodes: [String: SCNNode]
    }

    // MARK: - Node Names

    private static let removeNodeNames: Set<String> = ["QiuGan"]

    private static let ballNodeNames: Set<String> = [
        "_0", "BaiQiu",
        "_1", "_2", "_3", "_4", "_5", "_6", "_7",
        "_8", "_9", "_10", "_11", "_12", "_13", "_14", "_15"
    ]

    // MARK: - Model Scene Cache

    /// 解析 94 MB 的 TaiQiuZhuo.usdz 需要数秒（同步磁盘 IO + 网格/贴图解码），
    /// 是所有 2D/3D 球桌页进页卡顿的根因。这里缓存解析结果（进程级、只读原型），
    /// 每次 `loadTable()` 从原型 clone + 几何/材质副本（毫秒级）。
    /// 锁同时串行化「加载缓存」与「从缓存 clone」——SceneKit 未承诺跨线程
    /// 并发访问同一节点树安全（缩略图渲染、视频导出会在后台线程调用）。
    private static let cacheLock = NSLock()
    private static var cachedModelScene: SCNScene?

    /// App 启动时后台预热：把 USDZ 解析挪出「首次进球桌页」的主线程临界区。
    /// 可从任意线程调用；已缓存时为 no-op。
    static func preloadModel() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if cachedModelScene == nil {
            cachedModelScene = parseModelScene()
        }
    }

    /// 必须在持有 `cacheLock` 时调用。
    private static func cachedOrParsedModelScene() -> SCNScene? {
        if let scene = cachedModelScene { return scene }
        let scene = parseModelScene()
        cachedModelScene = scene
        return scene
    }

    private static func parseModelScene() -> SCNScene? {
        guard let url = Bundle.main.url(forResource: "TaiQiuZhuo", withExtension: "usdz") else {
            return nil
        }
        return try? SCNScene(url: url, options: [.checkConsistency: true])
    }

    // MARK: - Public

    static func loadTable() -> TableModel? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let modelScene = cachedOrParsedModelScene() else {
            return nil
        }

        let rootTransform = modelScene.rootNode.transform
        let container = SCNNode()
        container.name = "modelContainer"

        if SCNMatrix4IsIdentity(rootTransform) {
            container.eulerAngles.x = -Float.pi / 2
        } else {
            container.transform = rootTransform
        }

        for child in modelScene.rootNode.childNodes {
            let instance = child.clone()
            deepCopyGeometryAndMaterials(in: instance)
            container.addChildNode(instance)
        }

        let visualNode = SCNNode()
        visualNode.name = "tableVisual"
        visualNode.addChildNode(container)

        let cueStickNode = extractCueStick(from: visualNode)

        let removedBalls = detachBallNodes(from: visualNode)

        disablePhysics(in: visualNode)
        removeCamerasAndLights(from: visualNode)

        let (modelMin, modelMax) = visualNode.boundingBox
        let modelSizeX = modelMax.x - modelMin.x
        let modelSizeZ = modelMax.z - modelMin.z
        let modelSizeY = modelMax.y - modelMin.y

        let cushionThickness = BTTablePhysics.cushionThickness
        let targetOuterLength = AngleSceneCalculator.innerLength + 2 * cushionThickness + 0.18
        let targetOuterWidth = AngleSceneCalculator.innerWidth + 2 * cushionThickness + 0.18

        let actualLength = modelSizeX
        let actualWidth = modelSizeZ > modelSizeY ? modelSizeZ : modelSizeY

        guard actualLength > 0.01, actualWidth > 0.01 else {
            restoreBalls(removedBalls)
            return nil
        }

        let scaleX = targetOuterLength / actualLength
        let scaleW = targetOuterWidth / actualWidth
        let uniformScale = (scaleX + scaleW) / 2.0

        guard uniformScale > 0.0001, uniformScale < 1000.0,
              !uniformScale.isNaN, !uniformScale.isInfinite else {
            restoreBalls(removedBalls)
            return nil
        }

        let appliedScale = SCNVector3(uniformScale, uniformScale, uniformScale)
        visualNode.scale = appliedScale

        let centerX = (modelMin.x + modelMax.x) / 2.0
        let centerZ = (modelMin.z + modelMax.z) / 2.0
        visualNode.position = SCNVector3(
            -centerX * uniformScale,
            0,
            -centerZ * uniformScale
        )

        let railTopInWorld = modelMax.y * uniformScale
        let surfaceY = railTopInWorld - BTTablePhysics.cushionHeight

        guard surfaceY > -1.0, surfaceY < 10.0, !surfaceY.isNaN else {
            restoreBalls(removedBalls)
            return nil
        }

        restoreBalls(removedBalls)

        var preparedCueStick: SCNNode?
        if let cueNode = cueStickNode {
            let cueContainer = SCNNode()
            cueContainer.name = "cueStickModel"
            cueContainer.scale = appliedScale
            cueContainer.addChildNode(cueNode)
            disablePhysics(in: cueContainer)
            preparedCueStick = cueContainer
        }

        let extractedBalls = extractBallNodes(from: visualNode, uniformScale: uniformScale)

        return TableModel(
            visualNode: visualNode,
            appliedScale: appliedScale,
            surfaceY: surfaceY,
            cueStickNode: preparedCueStick,
            ballNodes: extractedBalls
        )
    }

    // MARK: - Cue Stick Extraction

    private static func extractCueStick(from node: SCNNode) -> SCNNode? {
        var nodesToExtract: [SCNNode] = []
        collectNodes(in: node, matching: removeNodeNames, result: &nodesToExtract)

        guard let cueStickNode = nodesToExtract.first else { return nil }

        let worldTF = cueStickNode.worldTransform
        cueStickNode.removeFromParentNode()

        var tf = worldTF
        tf.m41 = 0
        tf.m42 = 0
        tf.m43 = 0
        cueStickNode.transform = tf

        return cueStickNode
    }

    // MARK: - Ball Node Management

    private static func detachBallNodes(from node: SCNNode) -> [(SCNNode, SCNNode)] {
        var balls: [(SCNNode, SCNNode)] = []
        collectBallNodesWithParent(in: node, result: &balls)
        for (ball, _) in balls {
            ball.removeFromParentNode()
        }
        return balls
    }

    private static func restoreBalls(_ removed: [(SCNNode, SCNNode)]) {
        for (ball, parent) in removed {
            parent.addChildNode(ball)
        }
    }

    private static func collectBallNodesWithParent(in node: SCNNode, result: inout [(SCNNode, SCNNode)]) {
        for child in node.childNodes {
            if let name = child.name, ballNodeNames.contains(name) {
                result.append((child, node))
            } else {
                collectBallNodesWithParent(in: child, result: &result)
            }
        }
    }

    /// Extract ball nodes from the visual tree, reparent them with correct world scale and centering.
    /// Returns a dictionary keyed by canonical name ("cueBall", "_1".."_15").
    private static func extractBallNodes(from visualNode: SCNNode, uniformScale: Float) -> [String: SCNNode] {
        let cueBallCandidates: Set<String> = ["_0", "BaiQiu"]
        let targetBallNames = (1...15).map { "_\($0)" }
        let allNames = targetBallNames + ["_0", "BaiQiu"]

        var result: [String: SCNNode] = [:]
        var cueBallFound = false

        for name in allNames {
            let isCueBall = cueBallCandidates.contains(name)
            if isCueBall && cueBallFound { continue }

            guard let anchorNode = visualNode.childNode(withName: name, recursively: true) else {
                continue
            }

            guard let sourceNode = firstGeometryNode(in: anchorNode) else {
                continue
            }

            let (meshMin, meshMax) = sourceNode.boundingBox
            let meshCenterLocal = SCNVector3(
                (meshMin.x + meshMax.x) * 0.5,
                (meshMin.y + meshMax.y) * 0.5,
                (meshMin.z + meshMax.z) * 0.5
            )

            let worldTransform = anchorNode.worldTransform
            let col0 = simd_float3(worldTransform.m11, worldTransform.m12, worldTransform.m13)
            let worldScale = simd_length(col0)

            anchorNode.removeFromParentNode()
            anchorNode.transform = SCNMatrix4Identity

            let ballKey = isCueBall ? "cueBall" : name
            let originalBall = SCNNode()
            originalBall.name = ballKey
            originalBall.transform = SCNMatrix4Identity
            originalBall.scale = SCNVector3(worldScale, worldScale, worldScale)

            let centerInAnchor = sourceNode.convertPosition(meshCenterLocal, to: anchorNode)
            anchorNode.position = SCNVector3(-centerInAnchor.x, -centerInAnchor.y, -centerInAnchor.z)
            originalBall.addChildNode(anchorNode)

            result[ballKey] = originalBall

            if isCueBall {
                cueBallFound = true
            }
        }

        return result
    }

    /// Find the first descendant node that has renderable geometry.
    private static func firstGeometryNode(in node: SCNNode) -> SCNNode? {
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

    /// `SCNNode.clone()` 共享 geometry / material 实例。缓存原型后，下游会按管线
    /// 就地改材质（plain/studio 台呢 tint 不同、球面加 shader modifier），若不隔离
    /// 会串扰到原型和其他场景实例。这里给每个实例做 geometry + material 浅拷贝：
    /// 顶点数据与贴图 contents 仍共享（重资产零复制），仅材质参数独立。
    private static func deepCopyGeometryAndMaterials(in node: SCNNode) {
        if let geometry = node.geometry {
            let geoCopy = geometry.copy() as! SCNGeometry
            geoCopy.materials = geometry.materials.map { $0.copy() as! SCNMaterial }
            node.geometry = geoCopy
        }
        for child in node.childNodes {
            deepCopyGeometryAndMaterials(in: child)
        }
    }

    // MARK: - Helpers

    private static func collectNodes(in node: SCNNode, matching names: Set<String>, result: inout [SCNNode]) {
        if let name = node.name, names.contains(name) {
            result.append(node)
            return
        }
        for child in node.childNodes {
            collectNodes(in: child, matching: names, result: &result)
        }
    }

    private static func disablePhysics(in node: SCNNode) {
        node.physicsBody = nil
        for child in node.childNodes {
            disablePhysics(in: child)
        }
    }

    private static func removeCamerasAndLights(from node: SCNNode) {
        var toRemove: [SCNNode] = []
        collectCamerasAndLights(in: node, result: &toRemove)
        for n in toRemove { n.removeFromParentNode() }
    }

    private static func collectCamerasAndLights(in node: SCNNode, result: inout [SCNNode]) {
        if node.camera != nil || node.light != nil {
            result.append(node)
            return
        }
        for child in node.childNodes {
            collectCamerasAndLights(in: child, result: &result)
        }
    }
}
