import SceneKit
import simd

/// Value-only geometry, exclusively requested by the spatial practice model.
/// World coordinates: X/Z horizontal, Y up, metres; bed and ground share scene constants.
enum SpatialPracticeGeometry {
    static let version = "bundled-table-exterior-v2"
    static let contactTolerance = 1e-6
    /// Two equal-material normals are indistinguishable when their sphere contact
    /// points differ by at most the solver's spatial resolution: |R n1-R n2|<=ε.
    /// This is a geometry bound in metres, not a relaxed impulse residual.
    static var impactNormalMergeTolerance:Double { contactTolerance / Double(BallPhysics.radius) }
    static let domainHalfExtent: Float = 3
    // Stop before the nearest room furniture / walls; room decorations have no collider.
    static func contains(_ p:SIMD3<Double>)->Bool {
        abs(p.x)<=3 && abs(p.z)<=2 && p.y >= -0.1 && p.y<=3.3
    }
    static func exitState(_ spans:[LocalPocketSimulation.Interval],fallback:LocalPocketSimulation.State)->LocalPocketSimulation.State {
        // One accepted solver step can contain several intervals after crossing
        // the boundary. The last interval may already start outside; locate the
        // actual crossing instead of publishing that later out-of-domain state.
        guard let span=spans.first(where:{contains($0.start.position) && !contains($0.end.position)}) else { return fallback }
        var low=span.start.time,high=span.end.time
        for _ in 0..<48 {
            let mid=(low+high)/2
            if let state=span.sample(at:mid,beforeEndpoint:true),contains(state.position) { low=mid } else { high=mid }
        }
        return span.sample(at:low,beforeEndpoint:true) ?? fallback
    }
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
            gravity: SIMD3(0, -Double(TablePhysics.gravity), 0), tolerance: contactTolerance,
            ballMaterial: ballMaterial, impactNormalMergeTolerance:impactNormalMergeTolerance)
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

// Kept in the opt-in page module so the legacy response and layout fingerprint stay unchanged.
extension PocketContactResponse {
    static func spatialPracticeImpact(_ initial:Motion,constraints:[ImpactConstraint],radius:Double,
                                      normalMergeTolerance:Double=1e-6) throws -> Motion {
        // Opt-in mesh-seam regularization. A sphere touching adjacent coplanar
        // triangles can receive nearly identical normals with incompatible tiny
        // tangential impulses. Merge only equal materials below the caller's
        // angular resolution; old callers retain the exact original solve.
        if normalMergeTolerance>0 {
            var groups:[[ImpactConstraint]]=[]
            for c in constraints {
                if let i=groups.firstIndex(where:{ group in group.allSatisfy {
                    $0.restitution==c.restitution && $0.friction==c.friction &&
                    simd_dot($0.normal-c.normal,$0.normal-c.normal)<=normalMergeTolerance*normalMergeTolerance
                } }) { groups[i].append(c) } else { groups.append([c]) }
            }
            if groups.count<constraints.count {
                let merged=groups.map { group -> ImpactConstraint in
                    let sum=group.reduce(V.zero) { $0+$1.normal }
                    return .init(normal:sum/sqrt(simd_dot(sum,sum)),restitution:group[0].restitution,friction:group[0].friction)
                }
                return try simultaneousImpact(initial,constraints:merged,radius:radius)
            }
        }
        return try simultaneousImpact(initial,constraints:constraints,radius:radius)
    }
}
