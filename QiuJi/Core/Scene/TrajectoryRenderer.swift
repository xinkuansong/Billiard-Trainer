import SceneKit

/// Shared prediction trajectory drawing (C3 / D2).
/// Composer / Silu / PlanThree use `.positionPlay`; Snooker uses `.snookerDefense`
/// so defense semantics stay intentional but are no longer an implicit fork.
enum TrajectoryRenderer {

    enum GhostSource: Equatable {
        /// Ideal ghost-ball center (`ShotPrediction.ghost`).
        case ghost
        /// Cue ball position at first contact (`ShotPrediction.firstContact`).
        case firstContact
    }

    /// How `extraBallPaths` are filtered against `TrajectoryDetail`.
    enum ExtraBallMode: Equatable {
        /// Only when detail == `.full` (Composer / Silu / PlanThree).
        case fullOnly
        /// `.core` → target key only; `.full` → all; `.minimal` → none (Snooker).
        case coreTargetAndFull
    }

    struct Options {
        var includeObjectPath: Bool
        var extendToPocketRim: Bool
        var ghostSource: GhostSource
        var extraBallMode: ExtraBallMode
        /// When true, ghost is hidden unless the target ball node is visible (Snooker).
        var requireVisibleTargetForGhost: Bool

        /// Full potting semantics: object path + rim extend + ghost from `.ghost`.
        static let positionPlay = Options(
            includeObjectPath: true,
            extendToPocketRim: true,
            ghostSource: .ghost,
            extraBallMode: .fullOnly,
            requireVisibleTargetForGhost: false
        )

        /// Defense semantics (D2): no object path, ghost at first contact.
        static let snookerDefense = Options(
            includeObjectPath: false,
            extendToPocketRim: false,
            ghostSource: .firstContact,
            extraBallMode: .coreTargetAndFull,
            requireVisibleTargetForGhost: true
        )
    }

    struct Context {
        let prediction: ShotPrediction
        let targetKey: String
        let pocket: String?
        let surfaceY: Float
        /// When false, skip ghost placement (e.g. Composer free-ball aim).
        var showGhost: Bool = true
    }

    @MainActor
    static func draw(
        prediction p: ShotPrediction,
        options: Options,
        context: Context,
        scene: AngleTrainingScene,
        into nodes: inout [SCNNode],
        detailOverride: TrajectoryDetail? = nil
    ) {
        let detail = detailOverride ?? UserPreferences.shared.trajectoryDetail
        scene.addCueTrajectory(p.cuePath, contact: p.firstContact, detail: detail, into: &nodes)

        if options.includeObjectPath, detail != .minimal {
            var objPath = p.objectPath
            if options.extendToPocketRim, p.objectPocketed,
               let pocket = context.pocket,
               let pocketIndex = ShotIntent.pocketIndex(for: pocket) {
                objPath = PositionPlayShotSolver.extendPathToPocketRim(
                    objPath, pocketIndex: pocketIndex, surfaceY: context.surfaceY
                )
            }
            scene.addObjectTrajectory(objPath, ballKey: context.targetKey, into: &nodes)
        }

        appendExtraBallPaths(
            p.extraBallPaths, detail: detail, mode: options.extraBallMode,
            targetKey: context.targetKey, scene: scene, into: &nodes
        )

        placeGhost(
            prediction: p, options: options, context: context, scene: scene
        )

        if UserPreferences.shared.showSeparationAngle {
            scene.addSeparationAngleLine(for: p, into: &nodes)
        }
    }

    // MARK: - Internals

    private static func appendExtraBallPaths(
        _ paths: [String: [SCNVector3]],
        detail: TrajectoryDetail,
        mode: ExtraBallMode,
        targetKey: String,
        scene: AngleTrainingScene,
        into nodes: inout [SCNNode]
    ) {
        switch mode {
        case .fullOnly:
            guard detail == .full else { return }
            for (key, pts) in paths {
                scene.addObjectTrajectory(pts, ballKey: key, into: &nodes)
            }
        case .coreTargetAndFull:
            guard detail != .minimal else { return }
            for (key, pts) in paths {
                if detail == .core, key != targetKey { continue }
                scene.addObjectTrajectory(pts, ballKey: key, into: &nodes)
            }
        }
    }

    private static func placeGhost(
        prediction p: ShotPrediction,
        options: Options,
        context: Context,
        scene: AngleTrainingScene
    ) {
        guard context.showGhost, let ghost = scene.ghostBallNode else {
            scene.ghostBallNode?.isHidden = true
            return
        }
        let ghostCenter: SCNVector3
        switch options.ghostSource {
        case .ghost:
            ghostCenter = p.ghost
        case .firstContact:
            guard let contact = p.firstContact else {
                ghost.isHidden = true
                return
            }
            ghostCenter = contact
        }
        let target = scene.allBallNodes[context.targetKey]
        let targetVisible = target.map { !$0.isHidden } ?? false
        if options.requireVisibleTargetForGhost, !targetVisible {
            ghost.isHidden = true
            return
        }
        ghost.position = SCNVector3(
            ghostCenter.x,
            context.surfaceY + AngleSceneCalculator.ballRadius,
            ghostCenter.z
        )
        ghost.isHidden = false
        if let target, targetVisible {
            scene.updateContactDot(ghostCenter: ghost.position, targetCenter: target.position)
        }
    }
}

/// The visible horizontal cloth footprint, used only to clip projected assists.
/// Physics and recorded trajectories never consume this mesh-derived geometry.
struct TableAssistSurface {
    typealias Point = SIMD2<Double>
    let triangles: [[Point]]
    let sourceY: Float
    private let bounds: [(min: Point, max: Point)]

    init(triangles: [[Point]], sourceY: Float) {
        self.triangles = triangles
        self.sourceY = sourceY
        self.bounds = triangles.map { triangle in
            (min: Point(triangle.map(\.x).min() ?? .infinity, triangle.map(\.y).min() ?? .infinity),
             max: Point(triangle.map(\.x).max() ?? -.infinity, triangle.map(\.y).max() ?? -.infinity))
        }
    }

    enum Failure: Error { case invalidSurface(String) }

    static func load(from scene: AngleTrainingScene) throws -> TableAssistSurface {
        guard let bedY = try MobileClothAlignment.measuredBedY(in: scene), let table = scene.tableNode else {
            throw Failure.invalidSurface("Missing horizontal cloth surface")
        }
        var candidates: [SCNNode] = []
        table.enumerateChildNodes { node, _ in
            if node.geometry?.materials.contains(where: { $0.name == "TaiNi" }) == true { candidates.append(node) }
        }
        var triangles: [[Point]] = []
        for node in candidates {
            guard let geometry = node.geometry,
                  let sourceIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }) else { continue }
            let source = geometry.sources[sourceIndex]
            // Reuse one owned data snapshot: the SceneKit Objective-C bridge
            // otherwise copies this whole buffer for each vertex on physical iOS.
            let vertexData = source.data
            let channel = geometry.geometrySourceChannels?[sourceIndex].intValue ?? 0
            guard source.usesFloatComponents, source.bytesPerComponent == 4,
                  source.componentsPerVector == 3, source.dataOffset >= 0, source.dataStride >= 12 else {
                throw Failure.invalidSurface("Unsupported cloth position buffer")
            }
            for (index, element) in geometry.elements.enumerated() {
                guard geometry.materials[index % geometry.materials.count].name == "TaiNi" else { continue }
                guard channel >= 0, channel < element.indicesChannelCount else {
                    throw Failure.invalidSurface("Invalid cloth position channel")
                }
                for face in try PocketLeatherMesh.decode(element) {
                    var world: [SCNVector3] = []
                    for offset in stride(from: channel, to: face.count, by: element.indicesChannelCount) {
                        let vertex = Int(face[offset])
                        let start = source.dataOffset + vertex * source.dataStride
                        guard vertex < source.vectorCount, start + 12 <= vertexData.count else {
                            throw Failure.invalidSurface("Cloth index outside vertex buffer")
                        }
                        let local = vertexData.withUnsafeBytes { bytes in
                            SCNVector3(bytes.loadUnaligned(fromByteOffset: start, as: Float.self),
                                       bytes.loadUnaligned(fromByteOffset: start+4, as: Float.self),
                                       bytes.loadUnaligned(fromByteOffset: start+8, as: Float.self))
                        }
                        world.append(node.convertPosition(local, to: scene.rootNode))
                    }
                    guard world.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else {
                        throw Failure.invalidSurface("Non-finite cloth position")
                    }
                    // Same import precision as measuredBedY; exclude rail faces and bevels.
                    guard world.allSatisfy({ abs($0.y - bedY) < 0.00001 }) else { continue }
                    triangles += try triangulate(world.map { Point(Double($0.x), Double($0.z)) })
                }
            }
        }
        guard !triangles.isEmpty else { throw Failure.invalidSurface("Empty cloth footprint") }
        return TableAssistSurface(triangles: triangles, sourceY: bedY)
    }

    /// Ear clipping preserves concave face boundaries; a triangle fan would fill notches.
    static func triangulate(_ input: [Point]) throws -> [[Point]] {
        var polygon: [Point] = []
        for point in input {
            guard point.x.isFinite, point.y.isFinite else { throw Failure.invalidSurface("Non-finite polygon") }
            if polygon.last != point { polygon.append(point) }
        }
        if polygon.count > 1, polygon.first == polygon.last { polygon.removeLast() }
        guard polygon.count >= 3 else { return [] }
        let area = signedArea(polygon)
        guard abs(area) > 1e-12 else { return [] }
        if area < 0 { polygon.reverse() }
        var result: [[Point]] = []
        while polygon.count > 3 {
            var removed = false
            for i in polygon.indices {
                let before = (i + polygon.count - 1) % polygon.count
                let after = (i + 1) % polygon.count
                let a = polygon[before], b = polygon[i], c = polygon[after]
                let turn = cross(b-a, c-a)
                if abs(turn) <= 1e-12 {
                    polygon.remove(at: i); removed = true; break
                }
                guard turn > 0 else { continue }
                let blocked = polygon.indices.contains { j in
                    j != before && j != i && j != after
                        && cross(b-a, polygon[j]-a) >= -1e-12
                        && cross(c-b, polygon[j]-b) >= -1e-12
                        && cross(a-c, polygon[j]-c) >= -1e-12
                }
                if !blocked {
                    result.append([a,b,c]); polygon.remove(at: i); removed = true; break
                }
            }
            guard removed else { throw Failure.invalidSurface("Non-simple cloth polygon") }
        }
        if polygon.count == 3, signedArea(polygon) > 1e-12 { result.append(polygon) }
        return result
    }

    /// Clip a finite-width ribbon to the union of cloth triangles, leaving all holes empty.
    /// The returned vertices form independent upward-facing triangles in world coordinates.
    func ribbon(from start: SCNVector3, to end: SCNVector3, width: Float, at height: Float) -> [SCNVector3] {
        let a = Point(Double(start.x), Double(start.z)), b = Point(Double(end.x), Double(end.z))
        let delta = b-a
        let length = sqrt(delta.x*delta.x + delta.y*delta.y)
        guard length.isFinite, length > 1e-8, width.isFinite, width > 0, height.isFinite else { return [] }
        let side = Point(-delta.y, delta.x) * (Double(width) / (2 * length))
        return clippedConvexPolygon([a-side, b-side, b+side, a+side], at: height)
    }

    /// Intersect a convex display polygon with the measured cloth footprint.
    /// Input winding is normalized; no source points or physical regions change.
    func clippedConvexPolygon(_ input: [Point], at height: Float) -> [SCNVector3] {
        guard input.count >= 3, height.isFinite,
              input.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return [] }
        let area = Self.signedArea(input)
        guard abs(area) > 1e-12 else { return [] }
        let quad = area > 0 ? input : Array(input.reversed())
        let minX = quad.map(\.x).min()!, maxX = quad.map(\.x).max()!
        let minZ = quad.map(\.y).min()!, maxZ = quad.map(\.y).max()!
        var vertices: [SCNVector3] = []
        for index in triangles.indices {
            let bound = bounds[index]
            guard bound.max.x >= minX, bound.min.x <= maxX,
                  bound.max.y >= minZ, bound.min.y <= maxZ else { continue }
            var polygon = triangles[index]
            for i in quad.indices {
                let edgeA = quad[i], edgeB = quad[(i+1) % quad.count]
                let edge = edgeB-edgeA
                let input = polygon; polygon.removeAll(keepingCapacity: true)
                guard var previous = input.last else { break }
                var previousDistance = Self.cross(edge, previous-edgeA)
                for current in input {
                    let distance = Self.cross(edge, current-edgeA)
                    if (distance >= 0) != (previousDistance >= 0) {
                        let t = previousDistance / (previousDistance-distance)
                        polygon.append(previous + (current-previous)*t)
                    }
                    if distance >= 0 { polygon.append(current) }
                    previous = current; previousDistance = distance
                }
            }
            guard polygon.count >= 3 else { continue }
            for i in 1..<(polygon.count-1) {
                guard abs(Self.cross(polygon[i]-polygon[0], polygon[i+1]-polygon[0])) > 1e-12 else { continue }
                for point in [polygon[0], polygon[i+1], polygon[i]] {
                    vertices.append(SCNVector3(Float(point.x), height, Float(point.y)))
                }
            }
        }
        return vertices
    }

    static func signedArea(_ polygon: [Point]) -> Double {
        guard polygon.count >= 3 else { return 0 }
        return polygon.indices.reduce(0) { $0 + cross(polygon[$1], polygon[($1+1) % polygon.count]) } / 2
    }
    private static func cross(_ a: Point, _ b: Point) -> Double { a.x*b.y-a.y*b.x }
}

/// Collision candidates derived from the loaded table, excluding net threads/decorations.
/// A broad window selects candidates only; the solver decides support/contact/capture.
struct PocketContactMesh {
    /// Ownership boundary retains the existing local window. Surface selection
    /// additionally covers the complete sphere at that boundary.
    static let localHalfExtent=0.18
    enum Coverage { case pocket, fullTable }
    struct Patch { let triangle: PocketContactTriangle; let material: String }
    let pocketID: String
    let patches: [Patch]
    let maximumBedAdjustment:Double

    @MainActor
    static func load(from scene: AngleTrainingScene, pocketIndex: Int) throws -> PocketContactMesh {
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)
        guard pockets.indices.contains(pocketIndex), let table = scene.tableNode,
              let bedY = try MobileClothAlignment.measuredBedY(in: scene) else {
            throw TableAssistSurface.Failure.invalidSurface("Missing pocket geometry")
        }
        return try load(table:table,worldRoot:scene.rootNode,pocketID:"pocket_\(pocketIndex)",
                        center:pockets[pocketIndex],surfaceY:scene.surfaceY,bedY:bedY,
                        alignCloth:scene.mobileRendering)
    }

    /// Decode an exclusively owned static node tree into value-only collision
    /// geometry. No camera, lighting, balls, or training scene is required.
    /// The importer must provide measured bed height and the same cloth alignment
    /// contract as the visible table. Never infer those from a pocket center.
    static func load(table:SCNNode,worldRoot:SCNNode,pocketID:String,center:SCNVector3,
                     surfaceY:Float,bedY:Float,alignCloth:Bool,coverage:Coverage = .pocket,
                     materials:Set<String> = ["TaiNi","Leather"]) throws -> PocketContactMesh {
        guard !pocketID.isEmpty,[center.x,center.y,center.z,surfaceY,bedY].allSatisfy({$0.isFinite}) else {
            throw TableAssistSurface.Failure.invalidSurface("Invalid pocket geometry coordinates")
        }
        var nodes = [table]; table.enumerateChildNodes { node, _ in nodes.append(node) }
        var patches: [Patch] = []
        var maximumBedAdjustment=0.0
        for node in nodes {
            guard let geometry = node.geometry,
                  let sourceIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }) else { continue }
            let source = geometry.sources[sourceIndex]
            let channel = geometry.geometrySourceChannels?[sourceIndex].intValue ?? 0
            guard source.usesFloatComponents, source.bytesPerComponent == 4, source.componentsPerVector == 3,
                  source.dataOffset >= 0, source.dataStride >= 12 else {
                throw TableAssistSurface.Failure.invalidSurface("Unsupported pocket position source")
            }
            for (index, element) in geometry.elements.enumerated() {
                guard !geometry.materials.isEmpty,
                      let material = geometry.materials[index % geometry.materials.count].name,
                      materials.contains(material) else { continue }
                guard channel >= 0, channel < element.indicesChannelCount else {
                    throw TableAssistSurface.Failure.invalidSurface("Invalid pocket position channel")
                }
                for face in try PocketLeatherMesh.decode(element) {
                    var vertices: [SIMD3<Double>] = []
                    for offset in stride(from: channel, to: face.count, by: element.indicesChannelCount) {
                        let vertex = Int(face[offset]), address = source.dataOffset + Int(face[offset])*source.dataStride
                        guard vertex < source.vectorCount, address+12 <= source.data.count else {
                            throw TableAssistSurface.Failure.invalidSurface("Pocket vertex out of bounds")
                        }
                        let local = source.data.withUnsafeBytes { bytes in
                            SCNVector3(bytes.loadUnaligned(fromByteOffset:address,as:Float.self),
                                       bytes.loadUnaligned(fromByteOffset:address+4,as:Float.self),
                                       bytes.loadUnaligned(fromByteOffset:address+8,as:Float.self))
                        }
                        var world = node.convertPosition(local,to:worldRoot)
                        let lift = surfaceY-bedY
                        if alignCloth, material == "TaiNi", lift > 0.0001,
                           lift < AngleSceneCalculator.ballRadius/2,
                           world.y >= bedY-0.00001, world.y < surfaceY-0.00001 { world.y += lift }
                        guard world.x.isFinite,world.y.isFinite,world.z.isFinite else {
                            throw TableAssistSurface.Failure.invalidSurface("Nonfinite pocket vertex")
                        }
                        var physical=SIMD3(Double(world.x),Double(world.y),Double(world.z))
                        // The nominal bed acquires one-Float-ULP height seams
                        // through the imported transform. Keep its physical
                        // support plane canonical; retain genuinely lower lip
                        // geometry and every non-cloth material unchanged.
                        let bedDifference=abs(physical.y-Double(surfaceY))
                        if material == "TaiNi",bedDifference<=Double(surfaceY.ulp) {
                            maximumBedAdjustment=max(maximumBedAdjustment,bedDifference)
                            physical.y=Double(surfaceY)
                        }
                        vertices.append(physical)
                    }
                    // Candidate window matches the measured pocket section; not the capture boundary.
                    let ext = localHalfExtent+Double(BallPhysics.radius), cx=Double(center.x), cz=Double(center.z)
                    if case .pocket=coverage {
                        guard vertices.contains(where: { $0.x >= cx-ext }), vertices.contains(where: { $0.x <= cx+ext }),
                              vertices.contains(where: { $0.z >= cz-ext }), vertices.contains(where: { $0.z <= cz+ext }) else { continue }
                    }
                    for t in try triangulate(vertices) { patches.append(Patch(triangle:t,material:material)) }
                }
            }
        }
        guard !patches.isEmpty else { throw TableAssistSurface.Failure.invalidSurface("Empty pocket contact mesh") }
        return PocketContactMesh(pocketID:pocketID,patches:patches,maximumBedAdjustment:maximumBedAdjustment)
    }

    /// Ear clip in the dominant plane, retaining original 3D vertices and concave boundaries.
    static func triangulate(_ vertices: [SIMD3<Double>]) throws -> [PocketContactTriangle] {
        guard vertices.count >= 3 else { return [] }
        var normal = SIMD3<Double>.zero
        for i in vertices.indices {
            let a=vertices[i],b=vertices[(i+1)%vertices.count]
            normal += SIMD3((a.y-b.y)*(a.z+b.z),(a.z-b.z)*(a.x+b.x),(a.x-b.x)*(a.y+b.y))
        }
        let magnitudes=[abs(normal.x),abs(normal.y),abs(normal.z)]
        let axis=magnitudes.indices.max { magnitudes[$0]<magnitudes[$1] }!
        guard magnitudes[axis]>1e-14 else { return [] } // zero-area import faces have no contact surface
        func project(_ v: SIMD3<Double>) -> SIMD2<Double> {
            switch axis { case 0:return SIMD2(v.y,v.z);case 1:return SIMD2(v.x,v.z);default:return SIMD2(v.x,v.y) }
        }
        let planar=vertices.map(project)
        return try TableAssistSurface.triangulate(planar).map { triangle in
            let original = try triangle.map { point -> SIMD3<Double> in
                guard let i=planar.firstIndex(of:point) else { throw TableAssistSurface.Failure.invalidSurface("Triangulation introduced vertex") }
                return vertices[i]
            }
            return PocketContactTriangle(a:original[0],b:original[1],c:original[2])
        }
    }
}

/// Process-lifetime numeric snapshot of the bundled table's pocket geometry.
/// The lock covers initialization; no SceneKit node escapes into the snapshot.
/// Physics always uses the calibrated bed contract, independently of 2D/3D view.
/// Physical roles of the current table's connected cloth components. Material
/// names alone cannot distinguish the bed (including its lip) from rubber rails.
enum PocketSurfaceRole:String { case clothBed, cushion, leather }
enum PocketStaticMaterial:Hashable {
    case prototype
    /// The cloth's vertical impact parameter is explicit until jump/landing
    /// calibration. Horizontal friction comes from the existing table model.
    case tablePhysics(clothRestitution:Double)
}

struct PocketSurfaceRoles {
    static func classify(_ patches:[PocketContactMesh.Patch],surfaceY:Float) throws -> [PocketSurfaceRole] {
        typealias V=SIMD3<Double>
        var parent=Array(patches.indices),seen:[V:Int]=[:]
        func root(_ index:Int)->Int {
            var i=index
            while parent[i] != i { parent[i]=parent[parent[i]];i=parent[i] }
            return i
        }
        for (i,patch) in patches.enumerated() {
            guard patch.material == "TaiNi" || patch.material == "Leather" else {
                throw TableAssistSurface.Failure.invalidSurface("Unclassified physical material: \(patch.material)")
            }
            guard patch.material == "TaiNi" else { continue }
            for vertex in [patch.triangle.a,patch.triangle.b,patch.triangle.c] {
                if let other=seen[vertex] { parent[root(i)]=root(other) }
                else { seen[vertex]=i }
            }
        }
        var groups:[Int:[Int]]=[:]
        for i in patches.indices where patches[i].material == "TaiNi" { groups[root(i),default:[]].append(i) }
        let bed=V(0,Double(surfaceY),0)
        let bedComponents=groups.values.filter { indices in
            indices.contains { simd_length_squared(patches[$0].triangle.closestPoint(to:bed)-bed)<=Double(surfaceY.ulp)*Double(surfaceY.ulp) }
        }
        // This is the bundled model's measured consumer contract, not a generic
        // largest-component heuristic. A replacement asset must be revalidated.
        guard groups.count==7,bedComponents.count==1,let bedIndices=bedComponents.first else {
            throw TableAssistSurface.Failure.invalidSurface("Expected one central cloth component and six separate cushions")
        }
        let bedSet=Set(bedIndices)
        for indices in groups.values where !bedSet.contains(indices[0]) {
            guard indices.contains(where:{ i in
                let t=patches[i].triangle
                return max(t.a.y,t.b.y,t.c.y)>Double(surfaceY)+Double(BallPhysics.radius)
            }) else { throw TableAssistSurface.Failure.invalidSurface("Unidentified cloth component below cushion height") }
        }
        return patches.indices.map { i in
            if patches[i].material == "Leather" { return .leather }
            return bedSet.contains(i) ? .clothBed : .cushion
        }
    }
}

final class PocketGeometryAsset {
    let pockets: [PocketContactMesh]
    /// Same physical material/transform contract without a pocket-window cut.
    /// Used when a touching group extends beyond one ownership region.
    let tablePatches:[PocketContactMesh.Patch]
    /// Raw numeric White surfaces. The envelope builder performs semantic
    /// component selection; no SceneKit node or room resource is retained.
    let bagSourceTrianglesByPocketID:[String:[PocketContactTriangle]]
    let regionsByPocketID:[String:PocketLocalRegion]
    let surfaceY: Float
    let measuredBedY: Float
    private static let lock=NSLock()
    private static var cached: PocketGeometryAsset?
    private let bagLock=NSLock()
    private var cachedBagEnvelopes:[String:PocketBagEnvelope]?
    private let roleLock=NSLock()
    private var cachedSurfaceRoles:[PocketSurfaceRole]?
    private let materialLock=NSLock()
    private var cachedContactSurfaces:[PocketStaticMaterial:[LocalPocketSimulation.Surface]]=[:]
    private struct SimulationKey:Hashable {
        let surface:PocketStaticMaterial
        let ball:SpatialBallContact.MaterialSource
    }
    private let simulationLock=NSLock()
    private var cachedSimulations:[SimulationKey:LocalPocketSimulation]=[:]
    private let captureLock=NSLock()
    private var cachedCaptureBoundaries:[String:PocketCaptureBoundary]?

    func captureBoundaries() throws -> [String:PocketCaptureBoundary] {
        captureLock.lock();defer { captureLock.unlock() }
        if let cachedCaptureBoundaries { return cachedCaptureBoundaries }
        let bags=try bagEnvelopes()
        var boundaries:[String:PocketCaptureBoundary]=[:]
        for mesh in pockets {
            guard let bag=bags[mesh.pocketID] else {
                throw TableAssistSurface.Failure.invalidSurface("Missing pocket bag envelope")
            }
            boundaries[mesh.pocketID]=try PocketCaptureBoundary(bag:bag,
                hardSurfaces:mesh.patches.map(\.triangle),radius:Double(BallPhysics.radius))
        }
        cachedCaptureBoundaries=boundaries
        return boundaries
    }

    /// Only immutable surfaces, constants and their BVH are shared. Ball states,
    /// accepted trajectories and pending events remain owned by each engine.
    func localSimulation(material:PocketStaticMaterial,
                         ballMaterial:SpatialBallContact.MaterialSource) throws -> LocalPocketSimulation {
        // Validate before using floating-point material values as cache keys.
        let surfaces=try contactSurfaces(material:material)
        let key=SimulationKey(surface:material,ball:ballMaterial)
        simulationLock.lock();defer { simulationLock.unlock() }
        if let cached=cachedSimulations[key] { return cached }
        let prepared=LocalPocketSimulation(surfaces:surfaces,radius:Double(BallPhysics.radius),
            gravity:SIMD3<Double>(0,-Double(TablePhysics.gravity),0),tolerance:1e-6,
            ballMaterial:ballMaterial)
        cachedSimulations[key]=prepared
        return prepared
    }

    func contactSurfaces(material:PocketStaticMaterial) throws -> [LocalPocketSimulation.Surface] {
        if case .tablePhysics(let e)=material,(!e.isFinite || !(0...1).contains(e)) {
            throw TableAssistSurface.Failure.invalidSurface("Invalid cloth restitution")
        }
        materialLock.lock();defer { materialLock.unlock() }
        if let cached=cachedContactSurfaces[material] { return cached }
        let roles=try surfaceRoles(),geometry=TableGeometry.chineseEightBallQiuJi(surfaceY:surfaceY)
        let result=try tablePatches.indices.map { i -> LocalPocketSimulation.Surface in
            let triangle=tablePatches[i].triangle
            guard case .tablePhysics(let clothRestitution)=material else {
                return .init(triangle:triangle,restitution:0.3,friction:0.2)
            }
            switch roles[i] {
            case .clothBed:
                return .init(triangle:triangle,restitution:clothRestitution,friction:Double(SpinPhysics.slidingFriction),
                             rollingFriction:Double(SpinPhysics.rollingFriction),spinFriction:Double(SpinPhysics.spinFriction))
            case .leather:
                // Soft hanging liner: absorbs, never returns the ball (see TablePhysics.pocketLinerRetention).
                return .init(triangle:triangle,restitution:Double(TablePhysics.pocketLinerRestitution),friction:Double(TablePhysics.cushionFriction),
                             tangentialRetention:Double(TablePhysics.pocketLinerRetention))
            case .cushion:
                guard let index=geometry.nearestCushionIndex(to:(triangle.a+triangle.b+triangle.c)/3) else {
                    throw TableAssistSurface.Failure.invalidSurface("Missing cushion response binding")
                }
                let e=index<geometry.linearCushions.count ? geometry.linearCushions[index].restitution
                    : geometry.circularCushions[index-geometry.linearCushions.count].restitution
                return .init(triangle:triangle,restitution:Double(e ?? TablePhysics.cushionRestitution),friction:Double(TablePhysics.cushionFriction))
            }
        }
        cachedContactSurfaces[material]=result
        return result
    }

    func surfaceRoles() throws -> [PocketSurfaceRole] {
        roleLock.lock();defer { roleLock.unlock() }
        if let cachedSurfaceRoles { return cachedSurfaceRoles }
        let roles=try PocketSurfaceRoles.classify(tablePatches,surfaceY:surfaceY)
        cachedSurfaceRoles=roles
        return roles
    }

    /// Default measured bag proxies share this immutable asset's lifetime.
    /// Build all pockets before publishing, so callers never receive a partial
    /// geometry set after a malformed source fails. Custom refinements remain
    /// explicit offline/test builds and cannot replace this default snapshot.
    func bagEnvelopes() throws -> [String:PocketBagEnvelope] {
        bagLock.lock();defer { bagLock.unlock() }
        if let cachedBagEnvelopes { return cachedBagEnvelopes }
        var result:[String:PocketBagEnvelope]=[:]
        for pocket in pockets {
            guard let strands=bagSourceTrianglesByPocketID[pocket.pocketID] else {
                throw PocketBagEnvelope.Failure.invalidGeometry("Missing bag source: \(pocket.pocketID)")
            }
            result[pocket.pocketID]=try PocketBagEnvelope.build(pocketID:pocket.pocketID,
                strands:strands,surfaceY:Double(surfaceY))
        }
        cachedBagEnvelopes=result
        return result
    }

    private init(pockets:[PocketContactMesh],tablePatches:[PocketContactMesh.Patch],
                 bagSources:[String:[PocketContactTriangle]],surfaceY:Float,measuredBedY:Float) {
        self.pockets=pockets;self.tablePatches=tablePatches;self.surfaceY=surfaceY;self.measuredBedY=measuredBedY
        self.bagSourceTrianglesByPocketID=bagSources
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:surfaceY)
        // Transfer when the sphere's footprint reaches the pocket window. Waiting
        // for its center can enter the mesh after an adjacent rail contact already
        // overlaps the rendered nose. The full-table solver covers this margin.
        regionsByPocketID=Dictionary(uniqueKeysWithValues:zip(pockets,centers).map { mesh,center in
            (mesh.pocketID,PocketLocalRegion(center:SIMD3(Double(center.x),Double(center.y),Double(center.z)),
                                            halfExtent:PocketContactMesh.localHalfExtent+Double(BallPhysics.radius)))
        })
    }

    static func load() throws -> PocketGeometryAsset {
        lock.lock();defer { lock.unlock() }
        if let cached { return cached }
        guard let model=TableModelLoader.loadTable() else {
            throw TableAssistSurface.Failure.invalidSurface("Cannot load bundled physical table")
        }
        let root=SCNNode(),table=model.visualNode,surfaceY=BTTablePhysics.surfaceY
        table.position.y += surfaceY-model.surfaceY
        root.addChildNode(table)
        guard let bedY=try MobileClothAlignment.measuredBedY(table:table,worldRoot:root,surfaceY:surfaceY) else {
            throw TableAssistSurface.Failure.invalidSurface("Cannot measure bundled physical bed")
        }
        let centers=AngleSceneCalculator.pocketPositions(surfaceY:surfaceY)
        let pockets=try centers.enumerated().map { index,center in
            try PocketContactMesh.load(table:table,worldRoot:root,pocketID:"pocket_\(index)",center:center,
                                       surfaceY:surfaceY,bedY:bedY,alignCloth:true)
        }
        let full=try PocketContactMesh.load(table:table,worldRoot:root,pocketID:"table-contact-geometry",center:SCNVector3Zero,
                                           surfaceY:surfaceY,bedY:bedY,alignCloth:true,coverage:.fullTable)
        let bagSources=try Dictionary(uniqueKeysWithValues:centers.enumerated().map { index,center in
            let id="pocket_\(index)"
            let mesh=try PocketContactMesh.load(table:table,worldRoot:root,pocketID:id,center:center,
                surfaceY:surfaceY,bedY:bedY,alignCloth:true,materials:["White"])
            return (id,mesh.patches.map(\.triangle))
        })
        let result=PocketGeometryAsset(pockets:pockets,tablePatches:full.patches,bagSources:bagSources,
                                       surfaceY:surfaceY,measuredBedY:bedY)
        cached=result
        return result
    }
}
