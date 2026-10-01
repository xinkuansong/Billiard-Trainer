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

    // A removed SCNAction can already be executing on the renderer thread.
    // Serialize its last writes with a new address pose and reject old work.
    private let animationLock = NSRecursiveLock()
    private var animationGeneration: UInt64 = 0

    func beginStrokeAnimation() -> UInt64 {
        animationLock.lock(); defer { animationLock.unlock() }
        animationGeneration &+= 1
        return animationGeneration
    }

    func isCurrentStrokeAnimation(_ generation: UInt64) -> Bool {
        animationLock.lock(); defer { animationLock.unlock() }
        return generation == animationGeneration
    }

    @discardableResult
    func withStrokeAnimation(_ generation: UInt64, _ body: () -> Void) -> Bool {
        animationLock.lock(); defer { animationLock.unlock() }
        guard generation == animationGeneration else { return false }
        body()
        return true
    }

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
        /// Low off-centre strikes can require steep elevation; never clamp and draw.
        static let maxElevationRadians: Float = Float.pi / 3
    }

    /// Public max elevation (tests / callers).
    static var maxElevationRadians: Float { Constants.maxElevationRadians }
    static var minElevationRadians: Float { Constants.minElevationRadians }

    /// Render-only clearance about the actual strike pivot, including vertical spin.
    /// The cone envelope covers rest, backswing and maximum follow-through. It is
    /// intentionally extended beyond the finite cue so fast backswing stays safe.
    /// Large visual elevations do not change the existing planar strike physics.
    static func requiredElevation(
        cueBallPosition: SCNVector3,
        aimDirection: SCNVector3,
        obstacleCenters: [SCNVector3] = [],
        surfaceY: Float = BTTablePhysics.surfaceY
    ) -> CueElevation {
        let cushion = cushionElevation(strike: cueBallPosition, aimDirection: aimDirection,
                                       surfaceY: surfaceY)
        let ball = ballElevation(strike: cueBallPosition, aimDirection: aimDirection,
                                 obstacleCenters: obstacleCenters)
        let needed = max(Constants.minElevationRadians, max(cushion, ball))
        return needed > Constants.maxElevationRadians ? .blocked : .angle(needed)
    }

    // Radius bound r(t) = intercept + slope*t for local distance t behind the pivot.
    // The forward-most pose has pull=-3R and tipInset<=R. Include the fallback
    // ferrule's extra 1 mm radius. Backward translation only makes this bound safer.
    private static var envelopeSlope: Float {
        (Constants.buttRadius - Constants.tipRadius) / Constants.length
    }
    private static var envelopeIntercept: Float {
        Constants.tipRadius + 0.001 + envelopeSlope * (-CueStroke.followThroughPull)
    }

    /// Tangent above an obstacle in the back/up plane. The growing cone requires
    /// (s-k*h) sin(e) - (h+k*s) cos(e) >= padding, not atan(rise/s): the latter
    /// clears only the axis at the obstacle centre, not its nearest surface.
    private static func tangentElevation(back s: Float, rise h: Float, padding: Float) -> Float {
        let a = s - envelopeSlope * h
        let b = h + envelopeSlope * s
        let distance = hypotf(a, b)
        guard distance > padding else { return .infinity }
        return atan2f(b, a) + asinf(padding / distance)
    }

    /// Evaluate a fixed pose directly so spin-pad input does not nest two angle searches.
    static func clearsAtElevation(strike: SCNVector3, aim: SCNVector3,
                                  obstacles: [SCNVector3], surfaceY: Float, elevation: Float) -> Bool {
        cushionClears(strike: strike, aimDirection: aim, surfaceY: surfaceY,
                      elevation: elevation, usesContactEnvelope: true)
            && ballsClear(strike: strike, aim: aim, obstacles: obstacles, elevation: elevation)
    }

    private static func cushionClears(strike: SCNVector3, aimDirection: SCNVector3,
                                      surfaceY: Float, elevation: Float, usesContactEnvelope: Bool = false) -> Bool {
        let aim = CueClearance.normalizeFlat(aimDirection)
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        // Interactive access uses the measured-table height contract and the same
        // shaft/ferrule envelope + 2mm clearance, without the old 12mm floor.
        let railHeight = usesContactEnvelope ? BTTablePhysics.cushionHeight : Constants.railTopAboveSurface
        let rise = surfaceY + railHeight - strike.y
        let padding = usesContactEnvelope ? envelopeIntercept + CueClearance.ballClearance
            : max(Constants.railClearance, envelopeIntercept + CueClearance.ballClearance)
        // Each rail is a solid half-space below its top. Work in its normal/up
        // section, so oblique shots also account for the side of the shaft.
        let rails: [(gap: Float, outward: Float)] = [
            (halfL - strike.x, -aim.x), (halfL + strike.x, aim.x),
            (halfW - strike.z, -aim.z), (halfW + strike.z, aim.z)
        ]
        let vertical = sinf(elevation)
        for rail in rails {
            let inward = -rail.outward * cosf(elevation)
            let phi: Float
            if inward >= envelopeSlope {
                phi = 0
            } else {
                let length = hypotf(inward, vertical)
                guard vertical >= envelopeSlope, length >= envelopeSlope else { return false }
                // Supporting plane normal (cos(phi) inward, sin(phi) up).
                // Its dot product with the cue axis equals the taper slope.
                phi = atan2f(vertical, inward) - acosf(envelopeSlope / length)
            }
            if rail.gap * cosf(phi) - rise * sinf(phi) < padding { return false }
        }
        return true
    }

    private static func cushionElevation(strike: SCNVector3, aimDirection: SCNVector3,
                                         surfaceY: Float) -> Float {
        func clears(_ elevation: Float) -> Bool {
            cushionClears(strike: strike, aimDirection: aimDirection, surfaceY: surfaceY, elevation: elevation)
        }
        if clears(Constants.minElevationRadians) { return Constants.minElevationRadians }
        guard clears(Constants.maxElevationRadians) else { return .infinity }
        var low = Constants.minElevationRadians, high = Constants.maxElevationRadians
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if clears(mid) { high = mid } else { low = mid }
        }
        return high
    }

    /// Minimum sphere-to-cone separation, including lateral offset. The cone
    /// still extends conservatively beyond the finite cue and covers follow-through.
    private static func ballsClear(strike: SCNVector3, aim: SCNVector3,
                                   obstacles: [SCNVector3], elevation: Float) -> Bool {
        let flat = CueClearance.normalizeFlat(aim)
        let k = envelopeSlope, scale = sqrtf(1-k*k)
        for ball in obstacles {
            let dx = ball.x-strike.x, dz = ball.z-strike.z, h = ball.y-strike.y
            let back = -dx*flat.x-dz*flat.z
            let lateral = dx*flat.z-dz*flat.x
            let along = back*cosf(elevation)+h*sinf(elevation)
            let radial = hypotf(lateral,h*cosf(elevation)-back*sinf(elevation))
            let t = max(0,along+k*radial/scale)
            let separation = hypotf(radial,along-t)-(envelopeIntercept+k*t)
            if separation < AngleSceneCalculator.ballRadius+CueClearance.ballClearance { return false }
        }
        return true
    }

    private static func ballElevation(strike: SCNVector3, aimDirection: SCNVector3,
                                      obstacleCenters: [SCNVector3]) -> Float {
        let aim = CueClearance.normalizeFlat(aimDirection)
        let r = AngleSceneCalculator.ballRadius
        var needed: Float = 0
        for p in obstacleCenters {
            let dx = p.x - strike.x, dz = p.z - strike.z
            let s = -dx * aim.x - dz * aim.z
            guard s > 1e-4 else { continue }
            let lateral = abs(dx * aim.z - dz * aim.x)
            guard lateral < r + Constants.buttRadius + CueClearance.ballClearance else { continue }
            // Ignore lateral displacement conservatively; honour the actual height.
            let padding = r * sqrtf(1 + envelopeSlope * envelopeSlope)
                + envelopeIntercept + CueClearance.ballClearance
            needed = max(needed, tangentElevation(back: s, rise: p.y - strike.y, padding: padding))
        }
        return needed
    }

    /// Cached once from the rendered mesh, in metres behind the actual tip.
    /// The upper radial hull contains every triangle (norm is convex), including
    /// asymmetric decoration. Subdivision bounds the taper excess to each slice.
    lazy var clearanceProfile: [CueSection] = {
        guard usesModelCueStick else { return CueSection.fallback }
        update(cueBallPosition: SCNVector3Zero, aimDirection: SCNVector3(0,0,-1), elevation: 0)
        var points: [(z: Float, r: Float)] = []
        rootNode.enumerateHierarchy { node, _ in
            for vertex in Self.renderedVertices(node) {
                let p=node.convertPosition(vertex,to:self.rootNode)
                points.append((p.z-CueClearance.tipOffset,hypotf(p.x,p.y)))
            }
        }
        guard !points.isEmpty else { return CueSection.fallback }
        points.sort { $0.z < $1.z }
        var unique: [(z: Float, r: Float)] = []
        for p in points {
            if let last = unique.last, p.z == last.z {
                unique[unique.count-1].r = max(last.r,p.r)
            } else { unique.append(p) }
        }
        var hull: [(z: Float, r: Float)] = []
        for p in unique {
            while hull.count >= 2 {
                let a=hull[hull.count-2], b=hull[hull.count-1]
                if (b.r-a.r)*(p.z-b.z) >= (p.r-b.r)*(b.z-a.z) { break }
                hull.removeLast()
            }
            hull.append(p)
        }
        var result: [CueSection] = []
        for (a,b) in zip(hull,hull.dropFirst()) {
            let n=max(1,Int(ceil((b.z-a.z)/0.005)))
            for i in 0..<n {
                let u=Float(i)/Float(n), v=Float(i+1)/Float(n)
                result.append(CueSection(start:a.z+(b.z-a.z)*u, end:a.z+(b.z-a.z)*v,
                    radius:max(a.r+(b.r-a.r)*u,a.r+(b.r-a.r)*v)))
            }
        }
        return result
    }()

    /// Vertices referenced by rendered elements only (assets may retain unused sources).
    static func renderedVertices(_ node: SCNNode) -> [SCNVector3] {
        // SceneKit primitive sources can be unit meshes; dimensions live in the
        // primitive parameters rather than in the returned vertex buffers.
        if let cone=node.geometry as? SCNCone {
            return primitiveVertices(height:Float(cone.height),bottom:Float(cone.bottomRadius),top:Float(cone.topRadius))
        }
        if let cylinder=node.geometry as? SCNCylinder {
            return primitiveVertices(height:Float(cylinder.height),bottom:Float(cylinder.radius),top:Float(cylinder.radius))
        }
        guard let geometry=node.geometry,let source=geometry.sources(for:.vertex).first,
              source.usesFloatComponents,source.bytesPerComponent==4 else { return [] }
        var used=Set<Int>()
        for element in geometry.elements {
            element.data.withUnsafeBytes { bytes in
                for offset in stride(from:0,to:bytes.count,by:element.bytesPerIndex) {
                    let index:Int
                    switch element.bytesPerIndex {
                    case 1:index=Int(bytes.loadUnaligned(fromByteOffset:offset,as:UInt8.self))
                    case 2:index=Int(bytes.loadUnaligned(fromByteOffset:offset,as:UInt16.self))
                    case 4:index=Int(bytes.loadUnaligned(fromByteOffset:offset,as:UInt32.self))
                    default:continue
                    }
                    if index < source.vectorCount { used.insert(index) }
                }
            }
        }
        return source.data.withUnsafeBytes { bytes in
            used.map { i in
                let offset=source.dataOffset+i*source.dataStride
                return SCNVector3(bytes.loadUnaligned(fromByteOffset:offset,as:Float.self),
                    bytes.loadUnaligned(fromByteOffset:offset+4,as:Float.self),bytes.loadUnaligned(fromByteOffset:offset+8,as:Float.self))
            }
        }
    }

    private static func primitiveVertices(height: Float, bottom: Float, top: Float) -> [SCNVector3] {
        (0...20).flatMap { j in
            let u=Float(j)/20,radius=bottom+(top-bottom)*u
            return (0..<64).map { i in
                let phi=Float(i)*2 * Float.pi/64
                return SCNVector3(radius*cosf(phi),(u-0.5)*height,radius*sinf(phi))
            }
        }
    }

    /// Finite spherical crown plus leather body, axis +Z and pole at z=0.
    private static func crownGeometry(length: Float, material: SCNMaterial,
                                      uvSamples: [(SCNVector3,CGPoint)] = []) -> SCNGeometry {
        let rho=CuePhysics.tipCurvatureRadius,r=CuePhysics.tipContactRadius
        let cap=rho-sqrtf(rho*rho-r*r)
        let rings=24,sides=64
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],indices:[Int32]=[],uvs:[CGPoint]=[]
        for j in 0...rings+1 {
            let radius=j>rings ? (length <= cap+0.000001 ? 0 : r) : r*Float(j)/Float(rings)
            let z=j>rings ? max(length,cap) : rho-sqrtf(rho*rho-radius*radius)
            for i in 0...sides {
                let phi=Float(i)*2 * .pi/Float(sides),x=radius*cosf(phi),y=radius*sinf(phi)
                let vertex=SCNVector3(x,y,z)
                vertices.append(vertex)
                // Preserve the asset's tip texture region after replacing its
                // crown surface. The stock/styled tip UV atlas is not a new unwrap.
                var nearest=Float.infinity,uv=CGPoint(x:CGFloat(i)/CGFloat(sides),y:CGFloat(z/max(length,cap)))
                for (sample,coordinate) in uvSamples {
                    let distance=(sample.x-x)*(sample.x-x)+(sample.y-y)*(sample.y-y)+(sample.z-z)*(sample.z-z)
                    if distance < nearest { nearest=distance;uv=coordinate }
                }
                uvs.append(uv)
                normals.append(j>rings ? (length <= cap+0.000001 ? SCNVector3(0,0,1) : SCNVector3(cosf(phi),sinf(phi),0)) : SCNVector3(x/rho,y/rho,(z-rho)/rho))
                if j>0 && i>0 {
                    let d=Int32(j*(sides+1)+i),c=d-1,b=d-Int32(sides+1),a=b-1
                    indices += [a,b,d,a,d,c]
                }
            }
        }
        let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uvs)],
            elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        geometry.materials=[material];return geometry
    }

    private func installModelCrown() {
        guard usesModelCueStick,let model=modelNode else { return }
        let previousPosition=model.position,previousTipPosition=tipNode?.position
        let rho=CuePhysics.tipCurvatureRadius,r=CuePhysics.tipContactRadius
        let extensionHeight=rho-sqrtf(rho*rho-r*r)
        // Keep the original shaft/ferrule/tip mesh and UVs. Add the spherical
        // crown ahead of it. Do not stretch a constant-radius sleeve down the
        // tapered asset to meet a wider shaft cross-section.
        model.position=SCNVector3Zero
        let reference=model.convertPosition(modelTipLocalPoint,to:rootNode)
        modelPoleOffset=SCNVector3(reference.x,reference.y,reference.z-extensionHeight)
        model.position=SCNVector3(-reference.x,-reference.y,CueClearance.tipOffset-modelPoleOffset.z)
        var material:SCNMaterial?
        var uvSamples:[(SCNVector3,CGPoint)]=[]
        model.enumerateHierarchy { node,_ in
            guard let geometry=node.geometry,!geometry.materials.isEmpty else { return }
            for (i,element) in geometry.elements.enumerated() {
                let m=geometry.materials[i % geometry.materials.count]
                guard m.name == "PiTou" else { continue }
                material=m
                let only=SCNNode(geometry:SCNGeometry(sources:geometry.sources,elements:[element]))
                var coordinates:[SIMD3<Float>:CGPoint]=[:]
                if let positions=geometry.sources(for:.vertex).first,let uv=geometry.sources(for:.texcoord).first,
                   positions.bytesPerComponent==4,uv.bytesPerComponent==4,positions.vectorCount==uv.vectorCount {
                    positions.data.withUnsafeBytes { pBytes in uv.data.withUnsafeBytes { uBytes in
                        for index in 0..<positions.vectorCount {
                            let p=positions.dataOffset+index*positions.dataStride,t=uv.dataOffset+index*uv.dataStride
                            let key=SIMD3<Float>(pBytes.loadUnaligned(fromByteOffset:p,as:Float.self),pBytes.loadUnaligned(fromByteOffset:p+4,as:Float.self),pBytes.loadUnaligned(fromByteOffset:p+8,as:Float.self))
                            coordinates[key]=CGPoint(x:CGFloat(uBytes.loadUnaligned(fromByteOffset:t,as:Float.self)),y:CGFloat(uBytes.loadUnaligned(fromByteOffset:t+4,as:Float.self)))
                        }
                    } }
                }
                for vertex in Self.renderedVertices(only) {
                    let p=node.convertPosition(vertex,to:self.rootNode)
                    if let uv=coordinates[SIMD3<Float>(vertex.x,vertex.y,vertex.z)] {
                        uvSamples.append((SCNVector3(p.x,p.y,p.z-CueClearance.tipOffset),uv))
                    }
                }
            }
        }
        guard let material else { return }
        let tip=tipNode ?? SCNNode();tip.name="contactCrown"
        let key=ObjectIdentifier(material)
        if let cached=crownGeometries[key] { tip.geometry=cached }
        else {
            let geometry=Self.crownGeometry(length:extensionHeight,
                material:material,uvSamples:uvSamples)
            crownGeometries[key]=geometry;tip.geometry=geometry
        }
        if tip.parent == nil { rootNode.addChildNode(tip) }
        tip.position=SCNVector3(0,0,CueClearance.tipOffset);tipNode=tip
        if let previousTipPosition { model.position=previousPosition;tip.position=previousTipPosition }
    }

    // MARK: - Nodes

    let rootNode: SCNNode
    private let usesModelCueStick: Bool
    private(set) var style: CueStyle = .original
    private var styleMaterials: [SCNMaterial] = []
    private var fadeMaterials: [SCNMaterial] = []
    private(set) var fadeOpacity: CGFloat = 1
    private var usesMaterialFade = false
    private var crownGeometries: [ObjectIdentifier:SCNGeometry] = [:]
    private var finishGeometry: [(node: SCNNode, original: SCNGeometry, styled: SCNGeometry)] = []
    private var modelNode: SCNNode?
    private var shaftNode: SCNNode?
    private var tipNode: SCNNode?
    private var ferruleNode: SCNNode?
    private var modelPoleOffset: SCNVector3 = SCNVector3Zero
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
        applyStyle(.selected())
        if tipNode == nil { installModelCrown() }
        _ = clearanceProfile
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

        let tipGeometry = Self.crownGeometry(length:Constants.tipHeight,material:SCNMaterial())
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
        applyStyle(.selected())
        _ = clearanceProfile
    }

    /// Finish and UVs only: node identity, dimensions, pose and physics stay untouched.
    @discardableResult
    func applyStyle(_ selected: CueStyle) -> Bool {
        guard selected != style else { return true }
        guard usesModelCueStick else { return false }
        if finishGeometry.isEmpty {
            var candidates: [SCNNode] = []
            rootNode.enumerateChildNodes { node, _ in
                if node.geometry?.materials.contains(where: { $0.name == "White_Wood" }) == true { candidates.append(node) }
            }
            var prepared: [(SCNNode, SCNGeometry, SCNGeometry)] = []
            for node in candidates {
                guard let original = node.geometry,
                      let styled = CueStyleModel.geometry(preserving: original.materials) else { return false }
                prepared.append((node, original, styled))
            }
            guard !prepared.isEmpty else { return false }
            finishGeometry = prepared
        }
        if styleMaterials.isEmpty {
            styleMaterials = finishGeometry.flatMap { $0.styled.materials }
                .filter { ["White_Wood", "black_2", "copp", "PiTou"].contains($0.name ?? "") }
        }
        // Original geometry and its materials are never mutated. Restoring the
        // original also retains SceneKit's embedded USDZ texture bindings.
        let originalTip = finishGeometry.flatMap { $0.original.materials }.first { $0.name == "PiTou" }
        guard selected == .original || CueStyleModel.apply(selected, to: styleMaterials, originalTip: originalTip) else { return false }
        for item in finishGeometry { item.node.geometry = selected == .original ? item.original : item.styled }
        style = selected
        installModelCrown()
        if usesMaterialFade { prepareOpacityAnimation() }
        return true
    }

    // MARK: - Update

    /// - Parameter tipInset: forward shift of the tip so it rests on the sphere at an
    ///   off-centre strike point (`CueStroke.tipInset`); 0 = centre ball. Render-only.
    func update(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float = 0,
                elevation: Float = 0, tipInset: Float = 0) {
        animationLock.lock(); defer { animationLock.unlock() }
        animationGeneration &+= 1
        applyPose(cueBallPosition: cueBallPosition, aimDirection: aimDirection,
                  pullBack: pullBack, elevation: elevation, tipInset: tipInset)
    }

    func updateStrokeAnimation(_ generation: UInt64, cueBallPosition: SCNVector3,
                               aimDirection: SCNVector3, pullBack: Float,
                               elevation: Float, tipInset: Float) {
        withStrokeAnimation(generation) {
            applyPose(cueBallPosition: cueBallPosition, aimDirection: aimDirection,
                      pullBack: pullBack, elevation: elevation, tipInset: tipInset)
        }
    }

    private func applyPose(cueBallPosition: SCNVector3, aimDirection: SCNVector3,
                           pullBack: Float, elevation: Float, tipInset: Float) {
        let pull = pullBack - max(0, min(tipInset, Constants.tipOffset - 0.0005))
        if usesModelCueStick {
            updateModelCueStick(cueBallPosition: cueBallPosition, aimDirection: aimDirection, pullBack: pull, elevation: elevation)
        } else {
            updateProgrammaticCueStick(cueBallPosition: cueBallPosition, aimDirection: aimDirection, pullBack: pull, elevation: elevation)
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
                -modelPoleOffset.x,
                -modelPoleOffset.y,
                tipOffset - modelPoleOffset.z
            )
        }
        tipNode?.position=SCNVector3(0,0,tipOffset)
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

        tipNode?.position = SCNVector3(0, 0, tipOffset)
        tipNode?.eulerAngles = SCNVector3Zero

        ferruleNode?.position = SCNVector3(0, 0, tipOffset + tipHeight + ferruleHeight / 2)
        ferruleNode?.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)

        shaftNode?.position = SCNVector3(0, 0, tipOffset + tipHeight + ferruleHeight + shaftLength / 2)
        shaftNode?.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
    }

    // MARK: - Visibility

    /// Install after the scene's lighting modifiers. Node opacity crossing 1 → <1
    /// creates a new SceneKit shader variant on the first shot. Keep that state
    /// fixed and animate a uniform instead; the transparent pipeline is drawn
    /// during aiming. No hidden render, delay, or almost-opaque magic value.
    func prepareOpacityAnimation() {
        usesMaterialFade = true
        var seen = Set<ObjectIdentifier>()
        fadeMaterials.removeAll(keepingCapacity: true)
        rootNode.enumerateHierarchy { node, _ in
            for material in node.geometry?.materials ?? [] where seen.insert(ObjectIdentifier(material)).inserted {
                var modifiers = material.shaderModifiers ?? [:]
                let source = modifiers[.fragment] ?? "#pragma body\n"
                if !source.contains("// cueOpacityAnimation") {
                    modifiers[.fragment] = "#pragma arguments\nfloat cueFadeOpacity;\n#pragma transparent\n"
                        + source + "\n// cueOpacityAnimation\n_output.color *= cueFadeOpacity;\n"
                    material.shaderModifiers = modifiers
                }
                material.setValue(Float(fadeOpacity), forKey: "cueFadeOpacity")
                fadeMaterials.append(material)
            }
        }
    }

    /// SceneKit's output is premultiplied: fade RGB and alpha together.
    func setFadeOpacity(_ opacity: CGFloat) {
        animationLock.lock(); defer { animationLock.unlock() }
        let value = max(0, min(1, opacity))
        fadeOpacity = value
        if usesMaterialFade {
            rootNode.opacity = 1
            for material in fadeMaterials { material.setValue(Float(value), forKey: "cueFadeOpacity") }
        } else {
            rootNode.opacity = value
        }
    }

    func show() {
        animationLock.lock(); defer { animationLock.unlock() }
        rootNode.isHidden = false
        setFadeOpacity(1)
    }

    func hide() {
        animationLock.lock(); defer { animationLock.unlock() }
        animationGeneration &+= 1
        applyHidden()
    }

    func hideStrokeAnimation(_ generation: UInt64) {
        withStrokeAnimation(generation) { applyHidden() }
    }

    private func applyHidden() {
        rootNode.isHidden = true
        setFadeOpacity(1)
    }

    /// Short opacity fade then hide (normal retract / clearance retract).
    func fadeOut(duration: TimeInterval = CueClearance.retractFade, completion: (() -> Void)? = nil) {
        animationLock.lock(); defer { animationLock.unlock() }
        let generation = animationGeneration
        rootNode.removeAction(forKey: "cueFade")
        let start = fadeOpacity
        let fade = SCNAction.customAction(duration: duration) { [weak self] _, elapsed in
            let progress = duration > 0 ? min(1, Double(elapsed) / duration) : 1
            self?.withStrokeAnimation(generation) {
                self?.setFadeOpacity(start * CGFloat(1 - progress))
            }
        }
        let hide = SCNAction.run { [weak self] _ in
            let applied = self?.withStrokeAnimation(generation) { self?.applyHidden() } ?? false
            if applied { completion?() }
        }
        rootNode.runAction(.sequence([fade, hide]), forKey: "cueFade")
    }
}

/// A finite radial slice. Capsule endpoints conservatively enclose its flat caps.
struct CueSection {
    let start: Float
    let end: Float
    let radius: Float
    static let fallback: [CueSection] = {
        var sections=[CueSection(start:0,end:0.012,radius:CueClearance.tipRadius),
                      CueSection(start:0.012,end:0.027,radius:CueClearance.tipRadius+0.001)]
        for i in 0..<290 {
            sections.append(CueSection(start:0.027+Float(i)*0.005,
                end:0.027+Float(i+1)*0.005,
                radius:CueClearance.tipRadius+(CueClearance.buttRadius-CueClearance.tipRadius)*Float(i+1)/290))
        }
        return sections
    }()
}

/// Ordinary-shot policy, separate from the rendering-only 60 degree escape cap.
/// 30 degrees is a product limit, not a claim of calibrated elevated-shot physics.
struct CueStrikeAccess {
    static let maximumElevation: Float = .pi / 6
    /// Explicit surface gap, additional to the measured mesh envelope. 0.5 mm
    /// avoids contact/z-fighting without adding the old 2 mm ball-obstacle margin.
    static let railSurfaceGap: Float = 0.0005
    static let unavailableMessage = "当前打点受库边或球遮挡，请调整打点或方向"
    let cue: SCNVector3
    let aim: SCNVector3
    let obstacles: [SCNVector3]
    let surfaceY: Float
    var profile: [CueSection] = CueSection.fallback

    var geometryKey: [Float] {
        [cue.x,cue.y,cue.z,aim.x,aim.y,aim.z,surfaceY] + obstacles.flatMap { [$0.x,$0.y,$0.z] }
    }

    struct Pose {
        let pivot: SCNVector3
        let elevation: Float
        let inset: Float
        let contact: SCNVector3
    }

    /// a/b are offsets in the cue-normal plane, matching CueBallStrike. The
    /// common sphere normal rotates with the cue; the pole is NOT the contact.
    func pose(spinX: Double, spinY: Double, elevation: Float) -> Pose {
        let flat=CueClearance.normalizeFlat(aim)
        let r=AngleSceneCalculator.ballRadius, rho=CuePhysics.tipCurvatureRadius
        let point=CueBallStrike.contactCoordinates(spinX:Float(spinX),spinY:Float(spinY),elevation:elevation)
        let back=SCNVector3(-flat.x*cosf(elevation),sinf(elevation),-flat.z*cosf(elevation))
        let normal=SCNVector3(-flat.x*point.back+flat.z*point.side,point.up,-flat.z*point.back-flat.x*point.side)
        let contact=SCNVector3(cue.x+r*normal.x,cue.y+r*normal.y,cue.z+r*normal.z)
        let pole=SCNVector3(cue.x+(r+rho)*normal.x-rho*back.x,
            cue.y+(r+rho)*normal.y-rho*back.y,cue.z+(r+rho)*normal.z-rho*back.z)
        // A 0.1mm axial standoff avoids z-fighting at the ideal tangent. Inset is
        // zero: the full spherical contact translation is already in the pivot.
        let offset=CueClearance.tipOffset-0.0001
        return Pose(pivot:SCNVector3(pole.x-back.x*offset,pole.y-back.y*offset,pole.z-back.z*offset),
            elevation:elevation,inset:0,contact:contact)
    }

    func isAvailable(spinX: Double, spinY: Double) -> Bool {
        guard spinX.isFinite, spinY.isFinite,
              spinX*spinX+spinY*spinY <= Double(CuePhysics.miscueLimitFraction*CuePhysics.miscueLimitFraction)+1e-6 else { return false }
        // Contact must lie on the finite crown, not beyond its rim.
        guard Float(spinX*spinX+spinY*spinY) <= powf(CuePhysics.tipContactRadius/CuePhysics.tipCurvatureRadius,2) else { return false }
        if clears(pose(spinX:spinX,spinY:spinY,elevation:CueStick.minElevationRadians)) { return true }
        if clears(pose(spinX:spinX,spinY:spinY,elevation:Self.maximumElevation)) { return true }
        for i in 1..<16 {
            let angle=CueStick.minElevationRadians+(Self.maximumElevation-CueStick.minElevationRadians)*Float(i)/16
            if clears(pose(spinX:spinX,spinY:spinY,elevation:angle)) { return true }
        }
        return false
    }

    /// Continuous sweep of finite cue sections, from follow-through to backswing.
    /// Rail solids use the table's measured top / inner-boundary contract. The
    /// half-space beyond each rail is conservative at pocket openings.
    func clears(_ pose: Pose) -> Bool {
        let flat=CueClearance.normalizeFlat(aim)
        let back=SCNVector3(-flat.x*cosf(pose.elevation),sinf(pose.elevation),-flat.z*cosf(pose.elevation))
        let follow=CueStroke.clampedFollowThroughPull(cueBallPosition:pose.pivot,aimDirection:aim,
            obstacleCenters:obstacles,elevation:pose.elevation,tipInset:pose.inset,surfaceY:surfaceY,profile:profile)
        // At larger pulls the section moves upward; extending the upper endpoint
        // indefinitely also covers every speed and withdrawal without a speed cap.
        let tip=SCNVector3(pose.pivot.x+back.x*(CueClearance.tipOffset-pose.inset),
            pose.pivot.y+back.y*(CueClearance.tipOffset-pose.inset),pose.pivot.z+back.z*(CueClearance.tipOffset-pose.inset))
        let rails: [(Float,Float)] = [(AngleSceneCalculator.innerLength/2-tip.x,-back.x),
            (AngleSceneCalculator.innerLength/2+tip.x,back.x),
            (AngleSceneCalculator.innerWidth/2-tip.z,-back.z),
            (AngleSceneCalculator.innerWidth/2+tip.z,back.z)]
        for section in profile {
            let start=section.start+follow
            let radius=section.radius+Self.railSurfaceGap
            if tip.y+back.y*start-radius < surfaceY { return false }
            for (gap,inward) in rails {
                let h=tip.y-surfaceY-BTTablePhysics.cushionHeight
                if h+back.y*start >= radius { continue }
                // Squared distance to the solid quadrant. Its minimum on an
                // axis ray occurs at an endpoint, a boundary crossing, or the
                // corner's perpendicular projection. No frame sampling needed.
                func distance(_ t: Float) -> Float {
                    hypotf(max(0,gap+inward*t),max(0,h+back.y*t))
                }
                var nearest=distance(start)
                if abs(inward)>1e-7 { nearest=min(nearest,distance(max(start,-gap/inward))) }
                nearest=min(nearest,distance(max(start,-h/back.y)))
                let denominator=inward*inward+back.y*back.y
                nearest=min(nearest,distance(max(start,-(gap*inward+h*back.y)/denominator)))
                if nearest < radius { return false }
            }
            for ball in obstacles {
                if tip.y+back.y*start-section.radius-CueClearance.ballClearance >= ball.y+AngleSceneCalculator.ballRadius { continue }
                let delta=SCNVector3(ball.x-tip.x,ball.y-tip.y,ball.z-tip.z)
                let t=max(start,delta.x*back.x+delta.y*back.y+delta.z*back.z)
                let dx=delta.x-back.x*t,dy=delta.y-back.y*t,dz=delta.z-back.z*t
                if sqrtf(dx*dx+dy*dy+dz*dz) < section.radius+CueClearance.ballClearance+AngleSceneCalculator.ballRadius { return false }
            }
        }
        return true
    }

    func resolvedPose(spinX: Double, spinY: Double) -> Pose? {
        guard isAvailable(spinX:spinX,spinY:spinY) else { return nil }
        var low=CueStick.minElevationRadians
        let minimum=pose(spinX:spinX,spinY:spinY,elevation:low)
        if clears(minimum) { return minimum }
        // Find the first feasible bracket, not just feasibility at the 30° cap.
        for i in 1...32 {
            var high=CueStick.minElevationRadians+(Self.maximumElevation-CueStick.minElevationRadians)*Float(i)/32
            if clears(pose(spinX:spinX,spinY:spinY,elevation:high)) {
                for _ in 0..<16 {
                    let middle=(low+high)/2
                    if clears(pose(spinX:spinX,spinY:spinY,elevation:middle)) { high=middle } else { low=middle }
                }
                return pose(spinX:spinX,spinY:spinY,elevation:high)
            }
            low=high
        }
        return nil
    }

    /// Automatic correction balances displacement on the spin disc and elevation,
    /// each normalized by its usable range. Explicit valid user points are never
    /// changed. Drag/nudge clamping continues to use the nearest feasible boundary.
    func automaticPoint(spinX: Double, spinY: Double, allowSideAdjustment: Bool = true) -> (x: Double, y: Double)? {
        if isAvailable(spinX:spinX,spinY:spinY) { return (spinX,spinY) }
        guard let nearest=constrained(spinX:spinX,spinY:spinY,allowSideAdjustment:allowSideAdjustment) else { return nil }
        let limit=Double(CuePhysics.miscueLimitFraction)
        let edge=sqrt(max(0,limit*limit-nearest.x*nearest.x))
        var best=nearest, bestScore=Double.infinity
        func consider(_ y: Double) {
            guard y >= nearest.y, y <= edge,
                  let pose=resolvedPose(spinX:nearest.x,spinY:y) else { return }
            let score=(pow(nearest.x-spinX,2)+pow(y-spinY,2))/(limit*limit)
                + pow(Double(pose.elevation/Self.maximumElevation),2)
            if score < bestScore { best=(nearest.x,y);bestScore=score }
        }
        for i in 0...24 { consider(nearest.y+(edge-nearest.y)*Double(i)/24) }
        var step=(edge-nearest.y)/24
        for _ in 0..<8 {
            let center=best.y
            consider(center-step/2);consider(center+step/2);step /= 2
        }
        return best
    }

    /// Keep valid selections; otherwise find the nearest feasible point on the disc.
    /// Column-only projection is reserved for the mask and locked-side-spin controls.
    func constrained(spinX: Double, spinY: Double, allowSideAdjustment: Bool = true) -> (x: Double, y: Double)? {
        if isAvailable(spinX:spinX,spinY:spinY) { return (spinX,spinY) }
        guard spinX.isFinite, spinY.isFinite else { return nil }
        let limit = Double(CuePhysics.miscueLimitFraction)
        func column(_ x: Double) -> (x: Double, y: Double)? {
            guard abs(x) <= limit else { return nil }
            let edge = sqrt(max(0,limit*limit-x*x))
            let requested = max(-edge,min(edge,spinY))
            if isAvailable(spinX:x,spinY:requested) { return (x,requested) }
            guard isAvailable(spinX:x,spinY:edge) else { return nil }
            var low = requested, high = edge
            for _ in 0..<22 {
                let middle = (low+high)/2
                if isAvailable(spinX:x,spinY:middle) { high=middle } else { low=middle }
            }
            // A small interior reserve avoids Float reconstruction flipping the
            // boundary back to invalid (0.01mm of ball-surface displacement).
            return (x,min(edge,high+0.00035))
        }
        guard allowSideAdjustment else { return column(spinX) }
        // Preserve the chosen side spin when its column has a solution. Search
        // other columns only when that entire column is obstructed.
        if let sameSide=column(spinX) { return sameSide }
        var best: (x:Double,y:Double)?
        func score(_ point: (x: Double, y: Double)) -> Double {
            pow(point.x-spinX,2)+pow(point.y-spinY,2)
        }
        func consider(_ x: Double) {
            guard let point = column(x) else { return }
            if best == nil || score(point) < score(best!) { best=point }
        }
        // Search all columns, then refine locally. A blocked side-spin column
        // must not be mistaken for an entirely blocked spin disc.
        for i in 0...128 { consider(-limit+2*limit*Double(i)/128) }
        var step = 2*limit/128
        for _ in 0..<8 {
            guard let center = best?.x else { break }
            consider(center-step/2); consider(center+step/2)
            step /= 2
        }
        return best
    }
}
