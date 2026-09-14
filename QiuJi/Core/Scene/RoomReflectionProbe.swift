import SceneKit
import Metal
import UIKit

/// Room-baked reflection environment for the reference ball shader.
///
/// The v62 ball shader used to fall back to an analytic grey "world"
/// (`v62World`) for every reflected ray that missed the cloth and the light
/// panels. Once the baked training room became the visible surroundings, that
/// grey gradient no longer matched anything on screen and read as a milky film
/// over the balls. The probe renders the installed room into an equirectangular
/// radiance map (from the table centre at ball height) and projects its upper
/// hemisphere to 9 SH coefficients, so glossy reflection and diffuse ambient
/// both come from the same room the player sees. Cloth reflection and the two
/// light panels stay analytic (they are per-ball exact already).
///
/// Only ball materials consume the probe; cloth, rails, cue, leather and room
/// shading are untouched.
final class RoomReflectionProbe {
    static let width = 512
    static let height = 256
    static let faceSize = 128

    let texture: MTLTexture
    let property: SCNMaterialProperty
    /// Upper-hemisphere irradiance / π as SH9 (order: 00, 1-1, 10, 11, 2-2, 2-1, 20, 21, 22).
    let irradianceSH: [SIMD3<Float>]
    /// Mean radiance of the floor under the table (table hidden during the bake).
    /// Balls below the table plane (pocket net, return rail) see this instead of cloth.
    let floorRadiance: SIMD3<Float>
    let style: RoomStyle?

    static let shaderArgumentNames: [String] = ["roomReflection", "roomFloor"] + (0..<9).map { "roomSH\($0)" }

    // MARK: - Direction ↔ equirect mapping (must match `v62Room` in the ball shader)

    static func uv(for d: SIMD3<Float>) -> SIMD2<Float> {
        let u = atan2(d.x, -d.z) / (2 * .pi) + 0.5
        let v = acos(max(-1, min(1, d.y))) / .pi
        return SIMD2<Float>(u, v)
    }

    static func direction(u: Float, v: Float) -> SIMD3<Float> {
        let phi = (u - 0.5) * 2 * .pi
        let theta = v * .pi
        let st = sin(theta)
        return SIMD3<Float>(st * sin(phi), cos(theta), -st * cos(phi))
    }

    // MARK: - Cube faces

    struct Face {
        let forward: SIMD3<Float>
        let up: SIMD3<Float>
        let size: Int
        /// Linear RGB, row-major, top row first.
        let linear: [SIMD3<Float>]

        var right: SIMD3<Float> { simd_normalize(simd_cross(forward, up)) }
    }

    /// Camera bases for the six faces; `up` is the screen-up vector of each render.
    static let faceBases: [(forward: SIMD3<Float>, up: SIMD3<Float>)] = [
        (SIMD3(1, 0, 0), SIMD3(0, 1, 0)), (SIMD3(-1, 0, 0), SIMD3(0, 1, 0)),
        (SIMD3(0, 1, 0), SIMD3(0, 0, -1)), (SIMD3(0, -1, 0), SIMD3(0, 0, 1)),
        (SIMD3(0, 0, 1), SIMD3(0, 1, 0)), (SIMD3(0, 0, -1), SIMD3(0, 1, 0))
    ]

    /// Resample six 90° faces into an equirectangular linear radiance map.
    static func equirect(faces: [Face], width: Int = width, height: Int = height) -> [SIMD3<Float>] {
        precondition(faces.count == 6)
        let rights = faces.map(\.right)
        var out = [SIMD3<Float>](repeating: .zero, count: width * height)
        out.withUnsafeMutableBufferPointer { out in
            for y in 0..<height {
                let v = (Float(y) + 0.5) / Float(height)
                for x in 0..<width {
                    let u = (Float(x) + 0.5) / Float(width)
                    let d = direction(u: u, v: v)
                    var best = 0
                    var bestDepth: Float = -1
                    for i in 0..<6 {
                        let depth = simd_dot(d, faces[i].forward)
                        if depth > bestDepth { bestDepth = depth; best = i }
                    }
                    let face = faces[best]
                    let sx = simd_dot(d, rights[best]) / bestDepth
                    let sy = simd_dot(d, face.up) / bestDepth
                    let px = min(face.size - 1, max(0, Int((sx + 1) * 0.5 * Float(face.size))))
                    let py = min(face.size - 1, max(0, Int((1 - sy) * 0.5 * Float(face.size))))
                    out[y * width + x] = face.linear[py * face.size + px]
                }
            }
        }
        return out
    }

    // MARK: - SH irradiance

    /// Project radiance to SH9 and pre-multiply the cosine-lobe convolution so the
    /// shader evaluates `E(n)/π` directly. Directions with `y < 0` are the cloth,
    /// which the ball shader integrates analytically, so they are excluded here.
    static func irradianceSH(equirect map: [SIMD3<Float>], width: Int = width, height: Int = height,
                             upperHemisphereOnly: Bool = true) -> [SIMD3<Float>] {
        // Integrate on a 4× decimated grid (box-averaged): SH9 cannot represent
        // finer detail anyway, and this keeps the CPU cost well under a frame.
        let step = max(1, min(width, height) / 64)
        let sw = width / step, shh = height / step
        var c0 = SIMD3<Float>.zero, c1 = SIMD3<Float>.zero, c2 = SIMD3<Float>.zero, c3 = SIMD3<Float>.zero
        var c4 = SIMD3<Float>.zero, c5 = SIMD3<Float>.zero, c6 = SIMD3<Float>.zero, c7 = SIMD3<Float>.zero
        var c8 = SIMD3<Float>.zero
        let dPhi = 2 * Float.pi / Float(sw)
        let dTheta = Float.pi / Float(shh)
        let cellScale = 1 / Float(step * step)
        map.withUnsafeBufferPointer { map in
            for y in 0..<shh {
                let v = (Float(y) + 0.5) / Float(shh)
                let theta = v * .pi
                let weight = sin(theta) * dTheta * dPhi
                for x in 0..<sw {
                    let d = direction(u: (Float(x) + 0.5) / Float(sw), v: v)
                    if upperHemisphereOnly && d.y < 0 { continue }
                    var sum = SIMD3<Float>.zero
                    for yy in 0..<step { for xx in 0..<step { sum += map[(y * step + yy) * width + x * step + xx] } }
                    let radiance = sum * (cellScale * weight)
                    let (px, py, pz) = (d.x, d.y, d.z)
                    c0 += radiance * 0.282095
                    c1 += radiance * (0.488603 * py); c2 += radiance * (0.488603 * pz); c3 += radiance * (0.488603 * px)
                    c4 += radiance * (1.092548 * px * py); c5 += radiance * (1.092548 * py * pz)
                    c6 += radiance * (0.315392 * (3 * pz * pz - 1)); c7 += radiance * (1.092548 * px * pz)
                    c8 += radiance * (0.546274 * (px * px - py * py))
                }
            }
        }
        var coefficients = [c0, c1, c2, c3, c4, c5, c6, c7, c8]
        // Cosine-lobe convolution (Ramamoorthi–Hanrahan) divided by π.
        let a0: Float = 1.0, a1: Float = 2.0 / 3.0, a2: Float = 1.0 / 4.0
        coefficients[0] *= a0
        for i in 1...3 { coefficients[i] *= a1 }
        for i in 4...8 { coefficients[i] *= a2 }
        return coefficients
    }

    static func shBasis(_ d: SIMD3<Float>) -> [Float] {
        let (x, y, z) = (d.x, d.y, d.z)
        return [0.282095,
                0.488603 * y, 0.488603 * z, 0.488603 * x,
                1.092548 * x * y, 1.092548 * y * z, 0.315392 * (3 * z * z - 1),
                1.092548 * x * z, 0.546274 * (x * x - y * y)]
    }

    /// CPU twin of the shader's `v62RoomIrradiance` for tests.
    static func irradianceOverPi(_ sh: [SIMD3<Float>], normal n: SIMD3<Float>) -> SIMD3<Float> {
        let basis = shBasis(n)
        var result = SIMD3<Float>.zero
        for i in 0..<9 { result += sh[i] * basis[i] }
        return simd_max(result, .zero)
    }

    // MARK: - Construction

    init?(linear: [SIMD3<Float>], width: Int = width, height: Int = height,
          sh: [SIMD3<Float>], floorRadiance: SIMD3<Float>, style: RoomStyle?, device: MTLDevice) {
        precondition(linear.count == width * height && sh.count == 9)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float, width: width, height: height, mipmapped: true)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        var halves = [UInt16](repeating: 0, count: width * height * 4)
        for i in 0..<(width * height) {
            let c = linear[i]
            halves[i * 4] = Self.half(c.x); halves[i * 4 + 1] = Self.half(c.y)
            halves[i * 4 + 2] = Self.half(c.z); halves[i * 4 + 3] = Self.half(1)
        }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                        withBytes: halves, bytesPerRow: width * 8)
        if let queue = device.makeCommandQueue(), let buffer = queue.makeCommandBuffer(),
           let blit = buffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: texture)
            blit.endEncoding()
            buffer.commit()
            buffer.waitUntilCompleted()
        }
        self.texture = texture
        self.property = SCNMaterialProperty(contents: texture)
        self.irradianceSH = sh
        self.floorRadiance = floorRadiance
        self.style = style
    }

    /// IEEE-754 binary16 encoding (no `Float16` dependency on the host arch).
    static func half(_ value: Float) -> UInt16 {
        let bits = value.bitPattern
        let sign = UInt16((bits >> 16) & 0x8000)
        var exponent = Int((bits >> 23) & 0xFF) - 127 + 15
        var mantissa = bits & 0x7F_FFFF
        if exponent <= 0 {
            if exponent < -10 { return sign }
            mantissa |= 0x80_0000
            let shift = UInt32(14 - exponent)
            return sign | UInt16(mantissa >> shift)
        }
        if exponent >= 0x1F { return sign | 0x7C00 }
        // Round to nearest even.
        let rounded = mantissa + 0x0FFF + ((mantissa >> 13) & 1)
        if rounded & 0x80_0000 != 0 { exponent += 1; mantissa = 0 } else { mantissa = rounded }
        if exponent >= 0x1F { return sign | 0x7C00 }
        return sign | UInt16(exponent << 10) | UInt16(mantissa >> 13)
    }

    // MARK: - Shader binding

    func install(on material: SCNMaterial) {
        material.setValue(property, forKey: "roomReflection")
        material.setValue(NSValue(scnVector3: SCNVector3(floorRadiance.x, floorRadiance.y, floorRadiance.z)), forKey: "roomFloor")
        for (i, c) in irradianceSH.enumerated() {
            material.setValue(NSValue(scnVector3: SCNVector3(c.x, c.y, c.z)), forKey: "roomSH\(i)")
        }
    }

    /// Bind to every ball-shader material under `node`.
    func install(on node: SCNNode) {
        func update(_ node: SCNNode) {
            for material in node.geometry?.materials ?? [] {
                guard material.shaderModifiers?[.surface]?.contains("roomReflection") == true else { continue }
                install(on: material)
            }
        }
        update(node); node.enumerateChildNodes { node, _ in update(node) }
    }

    // MARK: - Neutral fallback (pre-room transient)

    private static var neutralProbe: RoomReflectionProbe?

    /// The legacy v62 grey world, used until a room probe is available.
    static var neutral: RoomReflectionProbe? {
        if let neutralProbe { return neutralProbe }
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        var map = [SIMD3<Float>](repeating: .zero, count: width * height)
        for y in 0..<height {
            let d = direction(u: 0, v: (Float(y) + 0.5) / Float(height))
            let value = Float(MobileReferenceLighting.rig.environmentBase)
                + Float(MobileReferenceLighting.rig.environmentHorizon) * pow(1 - abs(d.y), 2)
            for x in 0..<width { map[y * width + x] = SIMD3<Float>(repeating: value) }
        }
        let sh = irradianceSH(equirect: map)
        neutralProbe = RoomReflectionProbe(linear: map, sh: sh,
                                           floorRadiance: SIMD3<Float>(repeating: Float(MobileReferenceLighting.rig.environmentBase)),
                                           style: nil, device: device)
        return neutralProbe
    }

    // MARK: - Room bake

    private static let cacheLock = NSLock()
    private static var cache: [RoomStyle: RoomReflectionProbe] = [:]

    /// Cached per room style; bakes from `scene` on first use.
    static func probe(for style: RoomStyle, scene: AngleTrainingScene) -> RoomReflectionProbe? {
        cacheLock.lock()
        if let cached = cache[style] { cacheLock.unlock(); return cached }
        cacheLock.unlock()
        guard let baked = bake(scene: scene, style: style) else { return neutral }
        cacheLock.lock()
        cache[style] = baked
        cacheLock.unlock()
        return baked
    }

    static func resetCache() {
        cacheLock.lock(); cache.removeAll(); cacheLock.unlock()
    }

    /// Render the installed room from the table centre at ball height. Balls, cue
    /// and overlays are hidden for the bake; the table and lights stay.
    static func bake(scene: AngleTrainingScene, style: RoomStyle,
                     device: MTLDevice? = MTLCreateSystemDefaultDevice()) -> RoomReflectionProbe? {
        guard let device,
              let room = scene.rootNode.childNode(withName: "reference_room", recursively: false) else { return nil }
        #if DEBUG
        let started = CACurrentMediaTime()
        #endif
        let centre = SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0)

        // Visibility: keep the table, the room and light nodes.
        var hiddenState: [(SCNNode, Bool)] = []
        for child in scene.rootNode.childNodes {
            guard child !== scene.tableNode, child !== room, child.light == nil else { continue }
            hiddenState.append((child, child.isHidden))
            child.isHidden = true
        }
        let roomWasHidden = room.isHidden
        room.isHidden = false
        defer {
            for (node, hidden) in hiddenState { node.isHidden = hidden }
            room.isHidden = roomWasHidden
        }

        let camera = SCNCamera()
        camera.fieldOfView = 90
        camera.projectionDirection = .vertical
        camera.zNear = 0.01
        camera.zFar = 50
        camera.wantsHDR = false
        camera.wantsExposureAdaptation = false
        let cameraNode = SCNNode()
        cameraNode.name = "roomReflectionProbeCamera"
        cameraNode.camera = camera
        cameraNode.position = centre
        scene.rootNode.addChildNode(cameraNode)
        defer { cameraNode.removeFromParentNode() }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode
        renderer.autoenablesDefaultLighting = false
        let size = CGSize(width: faceSize, height: faceSize)

        var faces: [Face] = []
        for basis in faceBases {
            let target = SCNVector3(centre.x + basis.forward.x, centre.y + basis.forward.y, centre.z + basis.forward.z)
            cameraNode.look(at: target, up: SCNVector3(basis.up.x, basis.up.y, basis.up.z), localFront: SCNVector3(0, 0, -1))
            let shot = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .none)
            guard let linear = linearPixels(of: shot, size: faceSize) else { return nil }
            faces.append(Face(forward: basis.forward, up: basis.up, size: faceSize, linear: linear))
        }
        // Floor under the table: one more downward face with the table hidden.
        let tableWasHidden = scene.tableNode?.isHidden ?? false
        scene.tableNode?.isHidden = true
        cameraNode.look(at: SCNVector3(centre.x, centre.y - 1, centre.z), up: SCNVector3(0, 0, 1), localFront: SCNVector3(0, 0, -1))
        let floorShot = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .none)
        scene.tableNode?.isHidden = tableWasHidden
        guard let floorPixels = linearPixels(of: floorShot, size: faceSize) else { return nil }
        let floorRadiance = floorPixels.reduce(SIMD3<Float>.zero, +) / Float(floorPixels.count)
        #if DEBUG
        let rendered = CACurrentMediaTime()
        #endif
        let map = equirect(faces: faces)
        let sh = irradianceSH(equirect: map)
        #if DEBUG
        let projected = CACurrentMediaTime()
        #endif
        let probe = RoomReflectionProbe(linear: map, sh: sh, floorRadiance: floorRadiance, style: style, device: device)
        #if DEBUG
        let finished = CACurrentMediaTime()
        print(String(format: "[RoomReflectionProbe] baked %@ in %.1f ms (render %.1f, project %.1f, upload %.1f)",
                     style.rawValue, (finished - started) * 1000, (rendered - started) * 1000,
                     (projected - rendered) * 1000, (finished - projected) * 1000))
        #endif
        return probe
    }

    /// Decode an sRGB snapshot into linear RGB at exactly `size × size`.
    static func linearPixels(of image: UIImage, size: Int) -> [SIMD3<Float>]? {
        guard let cg = image.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                      bytesPerRow: size * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = context.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: size * size * 4)
        var out = [SIMD3<Float>](repeating: .zero, count: size * size)
        for i in 0..<(size * size) {
            out[i] = SIMD3<Float>(srgbToLinear[Int(bytes[i * 4])],
                                  srgbToLinear[Int(bytes[i * 4 + 1])],
                                  srgbToLinear[Int(bytes[i * 4 + 2])])
        }
        return out
    }

    static let srgbToLinear: [Float] = (0..<256).map { i in
        let c = Float(i) / 255
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
}
