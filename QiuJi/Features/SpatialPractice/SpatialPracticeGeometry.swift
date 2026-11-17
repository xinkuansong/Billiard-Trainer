import SceneKit

/// Value-only geometry, exclusively requested by the spatial practice model.
/// World coordinates: X/Z horizontal, Y up, metres; bed and ground share scene constants.
enum SpatialPracticeGeometry {
    static let version = "bundled-table-exterior-v1"
    static let domainHalfExtent: Float = 8
    private static let lock = NSLock()
    private static let solverLock = NSLock()
    private struct Key: Hashable { let material: PocketStaticMaterial; let ball: SpatialBallContact.MaterialSource }
    private static var solvers: [Key: LocalPocketSimulation] = [:]
    private static var exterior: [LocalPocketSimulation.Surface]?

    static func solver(asset: PocketGeometryAsset, material: PocketStaticMaterial,
                       ballMaterial: SpatialBallContact.MaterialSource) throws -> LocalPocketSimulation {
        solverLock.lock(); defer { solverLock.unlock() }
        let key = Key(material:material,ball:ballMaterial)
        if let cached = solvers[key] { return cached }
        let surfaces = try asset.contactSurfaces(material: material) + exteriorSurfaces()
        let result = LocalPocketSimulation(surfaces: surfaces, radius: Double(BallPhysics.radius),
            gravity: SIMD3(0, -Double(TablePhysics.gravity), 0), tolerance: 1e-6, ballMaterial: ballMaterial)
        solvers[key] = result
        return result
    }

    static func exteriorSurfaces() throws -> [LocalPocketSimulation.Surface] {
        lock.lock(); defer { lock.unlock() }
        if let exterior { return exterior }
        guard let model = TableModelLoader.loadTable() else {
            throw TableAssistSurface.Failure.invalidSurface("Missing exterior table")
        }
        let root = SCNNode(), table = model.visualNode
        table.position.y += BTTablePhysics.surfaceY - model.surfaceY
        root.addChildNode(table)
        var materials = Set<String>()
        table.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] {
                if let name = material.name { materials.insert(name) }
            }
        }
        // Cloth/leather are already included by the measured pocket solver. White is the
        // net, represented by its measured collection envelope, not overlapping strands.
        materials.subtract(["TaiNi", "Leather", "White"])
        let mesh = try PocketContactMesh.load(table: table, worldRoot: root,
            pocketID: "practice-exterior", center: SCNVector3Zero,
            surfaceY: BTTablePhysics.surfaceY, bedY: BTTablePhysics.surfaceY,
            alignCloth: false, coverage: .fullTable, materials: materials)
        var surfaces = mesh.patches.map {
            LocalPocketSimulation.Surface(triangle: $0.triangle, restitution: 0.35,
                friction: 0.25, rollingFriction: 0.02, spinFriction: 0.02)
        }
        let d = Double(domainHalfExtent + 1), y = Double(BTSceneLayout.groundLevelY)
        let a = SIMD3(-d, y, -d), b = SIMD3(-d, y, d)
        let c = SIMD3(d, y, d), e = SIMD3(d, y, -d)
        for triangle in [PocketContactTriangle(a: a, b: b, c: c), .init(a: a, b: c, c: e)] {
            surfaces.append(.init(triangle: triangle, restitution: 0.2, friction: 0.35,
                rollingFriction: 0.04, spinFriction: 0.04))
        }
        exterior = surfaces
        return surfaces
    }

    static func isOnBed(_ position: SCNVector3) -> Bool {
        abs(position.y - (BTTablePhysics.surfaceY + BallPhysics.radius)) < 0.00001 &&
        abs(position.x) < TablePhysics.innerLength / 2 && abs(position.z) < TablePhysics.innerWidth / 2
    }
}
