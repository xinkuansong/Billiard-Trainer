import SceneKit
import UIKit
import os

/// Loads the TaiQiuZhuo.usdz billiard table model and adapts it
/// to the SceneKit coordinate system for angle training.
/// Visual-only: physics bodies are stripped, cameras/lights removed.
/// Extracts ball nodes and cue stick for dynamic control.
final class TableModelLoader {
    private static let logger = Logger(subsystem: "com.xinkuan.qiuji", category: "TableModelLoader")

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

    /// 解析 ModelAssetTrial 当前选择的 USDZ 涉及磁盘读取及网格/贴图准备。
    /// 缓存只读原型以避免每页重复解析；加载耗时仍需与材质、反射和首帧分别测量。
    /// `loadTable()` 复制节点、几何和材质容器，共享不可变的底层图像/缓冲。
    /// 锁同时串行化「加载缓存」与「从缓存 clone」——SceneKit 未承诺跨线程
    /// 并发访问同一节点树安全（缩略图渲染、视频导出会在后台线程调用）。
    private static let cacheLock = NSLock()
    private static var cachedModelScene: SCNScene?
    private static var preparedModel: PreparedModel?
    private static var modelIdentity: String?
    private static func validateAssetIdentity() {
        let identity = ModelAssetTrial.identity("TaiQiuZhuo")
        if identity != modelIdentity {
            cachedModelScene = nil; preparedModel = nil; modelIdentity = identity
            PocketLeatherMesh.resetCache()
        }
    }

    /// App 启动时后台预热：把 USDZ 解析挪出「首次进球桌页」的主线程临界区。
    /// 可从任意线程调用；已缓存时为 no-op。
    static func preloadModel() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        validateAssetIdentity()
        if cachedModelScene == nil && preparedModel == nil {
            cachedModelScene = parseModelScene()
        }
    }

    /// Prepare the immutable leather partitions on the same background warm-up
    /// queue as USDZ parsing. Each page still creates its own material variants.
    static func preloadPocketRegions() {
        guard let model = loadTable() else { return }
        model.visualNode.position.y += BTTablePhysics.surfaceY - model.surfaceY
        do {
            _ = try PocketLeatherMesh.cachedExtraction(from: model.visualNode,
                centers: AngleSceneCalculator.pocketPositions(surfaceY: BTTablePhysics.surfaceY))
        } catch {
            logger.error("Pocket region warm-up failed; page will retry: \(String(describing: error), privacy: .public)")
        }
    }

    /// Asset preparation on an isolated clone. Never creates a renderer or
    /// publishes page state; cancellation is checked between expensive stages.
    static func preloadAppearance(ball: BallStickerStyle, cue: CueStyle, table: TableStyle,
                                  cancelled: () -> Bool) {
        guard !cancelled(), let model = loadTable() else { return }
        guard !cancelled() else { return }
        model.visualNode.position.y += BTTablePhysics.surfaceY - model.surfaceY
        _ = try? PocketLeatherMesh.cachedExtraction(from: model.visualNode,
            centers: AngleSceneCalculator.pocketPositions(surfaceY: BTTablePhysics.surfaceY))
        guard !cancelled() else { return }
        _ = BallStickerAppearance.apply(ball, to: model.ballNodes)
        guard !cancelled() else { return }
        if cue != .original, let node = model.cueStickNode {
            var materials: [SCNMaterial] = node.geometry?.materials ?? []
            node.enumerateChildNodes { child, _ in materials += child.geometry?.materials ?? [] }
            _ = CueStyleModel.geometry(preserving: materials)
            _ = CueStyleModel.apply(cue, to: materials)
        }
        guard !cancelled() else { return }
        TableAppearance.preloadTexture(table)
        // Numerical-map conversion must not wait for the first visible page.
        // The existing warm queue is drained before purge, so cancelled work
        // cannot repopulate these caches after eviction.
        guard !cancelled() else { return }
        _ = TableSurfaceTextures.woodRoughness
        guard !cancelled() else { return }
        _ = TableSurfaceTextures.leatherRoughness
        guard !cancelled() else { return }
        _ = TableSurfaceTextures.leatherNormal
    }

    /// 必须在持有 `cacheLock` 时调用。
    private static func cachedOrParsedModelScene() -> SCNScene? {
        if let scene = cachedModelScene { return scene }
        let scene = parseModelScene()
        cachedModelScene = scene
        return scene
    }

    private static func parseModelScene() -> SCNScene? {
        guard let url = ModelAssetTrial.url("TaiQiuZhuo") else {
            logger.error("Missing TaiQiuZhuo.usdz in bundle")
            return nil
        }
        do { return try SCNScene(url: url, options: [.checkConsistency: true]) }
        catch {
            logger.error("Cannot decode TaiQiuZhuo.usdz: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    // MARK: - Public

    /// The adapted prototype is immutable. Nodes, native geometries and materials
    /// are copied; decoded images/buffers are shared. Never share live ball state.
    static func loadTable(includeVisual: Bool = true) -> TableModel? {
        TableResourceCache.beginModelRead()
        defer { TableResourceCache.endModelRead() }
        cacheLock.lock()
        defer { cacheLock.unlock() }
        validateAssetIdentity()
        if preparedModel == nil {
            preparedModel = autoreleasepool {
                guard let model = prepareTable() else { return nil }
                let prototype = PreparedModel(model)
                cachedModelScene = nil
                return prototype
            }
        }
        guard let model = preparedModel else { return nil }
        return TableModel(visualNode: includeVisual ? Self.instance(of: model.table) : SCNNode(),
            appliedScale: model.appliedScale, surfaceY: model.surfaceY,
            cueStickNode: model.cue.map(Self.instance), ballNodes: model.balls.mapValues(Self.instance))
    }

    /// Cache table, balls and cue as separate immutable components. Keep native
    /// material backing shared for predictable page-entry cost; every consumer
    /// still receives independent nodes and mutable geometry/material containers.
    /// The source scene is released. Page state never enters these prototypes.
    private struct PreparedModel {
        let table: SCNNode
        let cue: SCNNode?
        let balls: [String: SCNNode]
        let appliedScale: SCNVector3
        let surfaceY: Float
        let archivePath: String?
        init(_ model: TableModel) {
            archivePath = ModelAssetTrial.url("TaiQiuZhuo")?.path
            table = model.visualNode; cue = model.cueStickNode; balls = model.ballNodes
            appliedScale = model.appliedScale; surfaceY = model.surfaceY
        }
    }
    /// Pin the original native texture backing for one synchronous material
    /// update, including when another thread evicts the cache during that update.
    static func withNativeMaterialBacking<Result>(_ body: (String?) -> Result) -> Result {
        cacheLock.lock()
        let backing = preparedModel
        cacheLock.unlock()
        return withExtendedLifetime(backing) { body(backing?.archivePath) }
    }
    private static func instance(of prototype: SCNNode) -> SCNNode {
        let node = prototype.clone()
        deepCopyGeometryAndMaterials(in: node)
        return node
    }

    static func resetCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedModelScene = nil
        preparedModel = nil
    }

    private static func prepareTable() -> TableModel? {

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
            logger.error("Invalid table bounds, scale or surface height")
            restoreBalls(removedBalls)
            return nil
        }

        let scaleX = targetOuterLength / actualLength
        let scaleW = targetOuterWidth / actualWidth
        let uniformScale = (scaleX + scaleW) / 2.0

        guard uniformScale > 0.0001, uniformScale < 1000.0,
              !uniformScale.isNaN, !uniformScale.isInfinite else {
            logger.error("Invalid table bounds, scale or surface height")
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
            logger.error("Invalid table bounds, scale or surface height")
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

/// Process-wide asset budget; live page state is never cached here. A single
/// detached table may be lent to one new scene at a time. Simultaneous windows
/// get independent node trees, and returning one cannot mutate another.
@MainActor
final class TableResourceCache: NSObject {
    nonisolated private static let sceneOwnership = TableResourceOwnership()
    static let shared = TableResourceCache(ownership: sceneOwnership, retainsForegroundHotSet: true)
    static let idleLifetime: TimeInterval = 30
    var activeScenes: Int { ownership.sceneCount }
    var generation: UInt64 { ownership.generation }
    nonisolated private let ownership: TableResourceOwnership
    private(set) var idleTable: AngleTrainingScene.ReusableTable?
    private var isForeground = true
    private var expiry: DispatchWorkItem?
    private var warming = false
    private var warmed = false
    private let retainsForegroundHotSet: Bool
    private var warmToken: TableWarmToken?
    private var warmedKey: String?
    private var requestedWarmup = false
    private let warmQueue = DispatchQueue(label: "com.qiuji.table-assets", qos: .utility)

    override init() {
        ownership = TableResourceOwnership()
        retainsForegroundHotSet = false
        super.init()
        registerObservers()
    }
    convenience init(retainsForegroundHotSet: Bool) {
        self.init(ownership: TableResourceOwnership(), retainsForegroundHotSet: retainsForegroundHotSet)
    }
    private init(ownership: TableResourceOwnership, retainsForegroundHotSet: Bool) {
        self.ownership = ownership
        self.retainsForegroundHotSet = retainsForegroundHotSet
        super.init()
        registerObservers()
    }
    private func registerObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(memoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(background),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foreground),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }

    /// A worker-created export scene participates without synchronously hopping
    /// to the main queue (which may itself be waiting for the export).
    nonisolated static func acquireScene() -> UInt64 {
        let ticket = sceneOwnership.acquire()
        DispatchQueue.main.async {
            guard ticket == shared.generation else { return }
            shared.didAcquire()
            if shared.retainsForegroundHotSet { shared.warmForEntry() }
        }
        return ticket
    }
    // Direct geometry extraction borrows only during its synchronous model read.
    // Returned nodes/images own their buffers and remain valid after eviction.
    nonisolated static func beginModelRead() { sceneOwnership.beginRead() }
    nonisolated static func endModelRead() { sceneOwnership.endRead() }
    func acquire() -> UInt64 {
        let ticket = ownership.acquire(); didAcquire(); return ticket
    }
    private func didAcquire() {
        expiry?.cancel(); expiry = nil
        record("acquire")
    }
    func takeTable(key: String) -> AngleTrainingScene.ReusableTable? {
        guard idleTable?.key == key else { record("tableMiss"); return nil }
        record("tableHit")
        defer { idleTable = nil }
        return idleTable
    }
    func release(_ table: AngleTrainingScene.ReusableTable?, generation leaseGeneration: UInt64) {
        ownership.release()
        table?.detach()
        if isForeground, leaseGeneration == generation, let table { idleTable = table }
        record("release")
        scheduleExpiry()
    }
    private func scheduleExpiry() {
        guard activeScenes == 0, isForeground else { return }
        expiry?.cancel()
        let ticket = generation
        let work = DispatchWorkItem { [weak self] in self?.expireIfIdle(generation: ticket) }
        expiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleLifetime, execute: work)
    }
    func expireIfIdle(generation ticket: UInt64) {
        guard activeScenes == 0, ticket == generation, isForeground else { return }
        if retainsForegroundHotSet {
            // Keep the shared hot resources and one detached table. Derived
            // teaching/card images and old room probes are cheap to rebuild.
            TableFigureRenderer.resetCache()
            DrillThumbnailStore.resetCache()
            DrillTutorialImageStore.resetCache()
            BallFeelPerspectiveRenderer.resetCache()
            RoomReflectionProbe.trimToMostRecent()
            expiry = nil
            record("warmIdle")
        } else { purge(reason: "expired") }
    }

    /// Called after the home view is visible and again at each live entry.
    /// Repeated requests coalesce; only the selected appearance is prepared.
    func warmForEntry() {
        requestedWarmup = true
        guard isForeground else { return }
        let ball = BallStickerStyle.selected(), cue = CueStyle.selected()
        let table = TableStyle(rawValue: UserDefaults.standard.string(forKey: TableStyle.preferenceKey) ?? "") ?? .defaultStyle
        let key = [ModelAssetTrial.identity("TaiQiuZhuo"), ball.rawValue, cue.rawValue, table.rawValue].joined(separator: "|")
        guard !warming, warmedKey != key else { return }
        warming = true
        let token = TableWarmToken(); warmToken = token
        let ticket = generation
        record("preparing")
        warmQueue.async { [weak self] in
            autoreleasepool {
                TableModelLoader.preloadAppearance(ball: ball, cue: cue, table: table,
                                                   cancelled: { token.isCancelled })
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.warmToken === token else { return }
                self.warming = false; self.warmToken = nil
                guard !token.isCancelled, ticket == self.generation, self.isForeground else { return }
                self.warmed = true; self.warmedKey = key
                self.record("warm")
                self.scheduleExpiry()
                // A preference may have changed while this request was running.
                self.warmForEntry()
            }
        }
    }
    @objc private func memoryWarning() { purge(reason: "memoryWarning") }
    @objc private func background() { isForeground = false; purge(reason: "background") }
    @objc private func foreground() {
        isForeground = true
        if requestedWarmup { warmForEntry() }
    }

    private func record(_ event: String) {
        DailyLayoutProbe.record("tableCache." + event, ["activeScenes": String(activeScenes),
            "idleTables": idleTable == nil ? "0" : "1", "generation": String(generation),
            "modelReads": String(ownership.modelReads),
            "ballImageBytes": String(BallStickerAppearance.retainedImageBytes),
            "ballUVBytes": String(BallStickerAppearance.retainedUVBytes),
            "cueImageBytes": String(CueStyleModel.retainedImageBytes),
            "warm": String(warmed), "preparing": String(warming),
            "table": idleTable.map { String(describing: ObjectIdentifier($0.node)) } ?? "none"])
    }
    func purge(reason: String = "explicit") {
        ownership.invalidate()
        expiry?.cancel(); expiry = nil
        idleTable = nil
        warmToken?.cancel()
        // A warm worker never waits for the main actor. Drain its current CPU
        // stage before clearing caches so an obsolete worker cannot refill them.
        warmQueue.sync {}
        warmToken = nil; warming = false
        warmed = false; warmedKey = nil
        TableModelLoader.resetCache()
        MobileReferenceLighting.resetImageCache()
        BakedTrainingRoom.resetCache()
        RoomReflectionProbe.resetCache()
        PocketLeatherMesh.resetCache()
        BallStickerAppearance.resetCache()
        TableFigureRenderer.resetCache()
        DrillTryoutBoardStore.resetCache()
        TableSurfaceTextures.resetCache()
        TableAppearance.resetImageCache()
        MaterialFactory.resetTextureCache()
        CueStyleModel.resetCache()
        DrillThumbnailStore.resetCache()
        DrillTutorialImageStore.resetCache()
        BallFeelPerspectiveRenderer.resetCache()
        record("purge." + reason)
    }
}


/// Bounded ownership of decoded images. Live materials/views retain their own
/// references; eviction never mutates an image already borrowed by a consumer.
final class TableAssetImageCache {
    private let lock = NSLock()
    private let byteLimit: Int
    private var images: [String: UIImage] = [:]
    private var costs: [String: Int] = [:]
    private var recent: [String] = []
    init(byteLimit: Int) { self.byteLimit = byteLimit }
    var retainedBytes: Int {
        lock.lock(); defer { lock.unlock() }
        return costs.values.reduce(0, +)
    }
    func image(for key: String, load: () -> UIImage?) -> UIImage? {
        lock.lock(); defer { lock.unlock() }
        if let image = images[key] {
            recent.removeAll { $0 == key }; recent.append(key)
            return image
        }
        guard let image = load() else { return nil }
        let bytes = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        if bytes > 0, bytes <= byteLimit {
            images[key] = image; costs[key] = bytes; recent.append(key)
            while costs.values.reduce(0, +) > byteLimit, !recent.isEmpty {
                let key = recent.removeFirst(); images.removeValue(forKey: key); costs.removeValue(forKey: key)
            }
        }
        return image
    }
    func reset() {
        lock.lock(); defer { lock.unlock() }
        images.removeAll(); costs.removeAll(); recent.removeAll()
    }
}

/// Only scalar ownership crosses threads; SceneKit trees remain confined to
/// their caller, and idle-table transfer is always on the main actor.
private final class TableResourceOwnership: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var reads = 0
    var modelReads: Int { lock.lock(); defer { lock.unlock() }; return reads }
    func beginRead() { lock.lock(); defer { lock.unlock() }; reads += 1 }
    func endRead() { lock.lock(); defer { lock.unlock() }; reads = max(0, reads - 1) }
    private var ticket: UInt64 = 0
    var sceneCount: Int { lock.lock(); defer { lock.unlock() }; return count }
    var generation: UInt64 { lock.lock(); defer { lock.unlock() }; return ticket }
    func acquire() -> UInt64 {
        lock.lock(); defer { lock.unlock() }; count += 1; return ticket
    }
    func release() { lock.lock(); defer { lock.unlock() }; count = max(0, count - 1) }
    func invalidate() { lock.lock(); defer { lock.unlock() }; ticket &+= 1 }
}

/// Cancellation crosses only the warm queue/main actor boundary.
private final class TableWarmToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
}
