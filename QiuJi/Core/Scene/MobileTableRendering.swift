import SceneKit
import ImageIO

/// Production table rendering path (v62 closeout, ADR-P5-01). Every interactive
/// `AngleTrainingScene` uses it by default; offline renderers opt out explicitly.
/// The environment supplies reflections; it never changes background or camera pose.
enum MobileTableRendering {
    /// Single gate for the mobile base lighting, the S267 reference lighting,
    /// surface finishes and the baked training room. Release builds are always
    /// on; Debug keeps `-v62.legacyRendering` / `V62_LEGACY_RENDERING=1` as a
    /// diagnostic escape hatch for before/after comparisons.
    static var isEnabled: Bool {
        #if DEBUG
        let info = ProcessInfo.processInfo
        return !info.arguments.contains("-v62.legacyRendering") && info.environment["V62_LEGACY_RENDERING"] != "1"
        #else
        return true
        #endif
    }
    // World Y (metres), calibrated against the original USDZ: 18 inlays start
    // at 0.82626m; all other White components end at 0.80709m. No mesh moves.
    static let inlayHeightThreshold: Float = 0.82

    /// Offline bake of the original table geometry: 128x64 RGBA, cosine-weighted
    /// hemisphere visibility within 0.25m. No ray queries run in the App.
    static let railOcclusion: UIImage? = {
        guard let url = Bundle.main.url(forResource: "MobileRailOcclusion", withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path),
              image.cgImage?.width == 128, image.cgImage?.height == 64 else { return nil }
        return image
    }()

    static let environmentURL: URL? = {
        guard let url = Bundle.main.url(forResource: "MobileTableSoftbox", withExtension: "hdr"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        return url
    }()

    static func applyLighting(to scene: AngleTrainingScene) {
        guard let environmentURL else { return }
        scene.lightingEnvironment.contents = environmentURL
        scene.lightingEnvironment.intensity = 0.35
        // Preserve exposure, projection, pose and background. Static snapshot
        // ablations showed little SSAO benefit; device motion remains unverified.
        scene.cameraNode.camera?.screenSpaceAmbientOcclusionIntensity = 0
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let light = node.light else { return }
            if light.type == .ambient { light.intensity = 30 }
            if light.castsShadow {
                // S157 retained offset key after gray calibration, actual-page and playback review.
                // One existing shadow source; no geometry or camera change.
                light.type = .spot
                node.position = SCNVector3(1, scene.surfaceY + 2.2, 0)
                node.look(at: SCNVector3(0, scene.surfaceY, 0))
                light.spotInnerAngle = 60
                light.spotOuterAngle = 95
                light.attenuationStartDistance = 0
                light.attenuationEndDistance = 10
                light.attenuationFalloffExponent = 2
                light.zNear = 0.5
                light.zFar = 6
                light.intensity = 25.995107651912413
                light.shadowMapSize = CGSize(width: 1024, height: 1024)
                light.shadowSampleCount = 8
                light.shadowRadius = 3
                light.shadowBias = 0.002
                light.shadowColor = UIColor(white: 0, alpha: 0.85)
            }
        }
        // Reuse the less contrasty wood albedo already present in the USDZ.
        // S60/S61: BlackWood's pale streaks read as scratches even under a coat.
        var woodAlbedo: Any?
        scene.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "Wood" {
                woodAlbedo = material.diffuse.contents
            }
        }
        // A continuous varnish surface sits above the original wood grain.
        // Keep UVs and one smooth specular response; BlackWood albedo is replaced below.
        scene.tableNode?.enumerateChildNodes { node, _ in
            // S52 pixel audit: these four 2048x2048 metallic maps are entirely zero.
            // Replace only candidate metallic bindings; other changes are explicit below.
            for material in node.geometry?.materials ?? [] where ["TaiNi", "Wood", "BlackWood", "Leather"].contains(material.name ?? "") {
                material.metalness.contents = Float(0)
            }
            for material in node.geometry?.materials ?? [] where material.name == "White" {
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = """
                #pragma body
                float inlayY = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).y;
                if (inlayY > \(inlayHeightThreshold)) { _surface.diffuse.rgb *= 0.6; }
                """
                material.shaderModifiers = modifiers
            }
            // S201: the original USDZ albedo is uniformly RGBA(48,155,32,255).
            // Preserve that exact sRGB color without a 2048-square color texture.
            // Keep the original multiply tint, normal and roughness separately.
            for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                material.diffuse.contents = UIColor(red: 48.0/255, green: 155.0/255, blue: 32.0/255, alpha: 1)
                // S239 candidate: retain original fiber textures at half their world-space scale.
                for property in [material.normal, material.roughness] {
                    property.contentsTransform = SCNMatrix4MakeScale(2, 2, 1)
                    property.wrapS = .repeat
                    property.wrapT = .repeat
                }
            }
            for material in node.geometry?.materials ?? [] where ["Wood", "BlackWood"].contains(material.name ?? "") {
                // S320 matte preview: retain source grain, normals and roughness.
                // Remove the rendered specular contribution to isolate the wood
                // diffuse response without changing shared lights or other materials.
                if MobileReferenceLighting.requested {
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = """
                    #pragma body
                    _output.color.rgb=max(float3(0.0),_output.color.rgb-_lightingContribution.specular);
                    """
                    material.shaderModifiers = modifiers
                    continue
                }
                material.roughness.contents = Float(0.24)
                if material.name == "BlackWood" {
                    // S209–S212: the constant (128,128,255) normal texture
                    // produces non-finite shading on the lower rail. Use the
                    // original mesh normals; preserve Wood's non-flat map.
                    material.normal.contents = nil
                }
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = """
                #pragma body
                _surface.diffuse.rgb = mix(float3(0.045,0.023,0.012), _surface.diffuse.rgb, 0.5);
                """
                if material.name == "BlackWood", let woodAlbedo {
                    material.diffuse.contents = woodAlbedo
                    // Linear pixel means of original Wood/BlackWood, including
                    // the previous 50% dark-brown mix; retain mean albedo color.
                    modifiers[.surface] = """
                    #pragma body
                    _surface.diffuse.rgb *= float3(0.35407753,0.41952911,0.38761742);
                    """
                }
                material.shaderModifiers = modifiers
            }
        }
    }
}

/// Local diffuse environment occlusion. The sphere/plane solid-angle approximation
/// follows rendered positions and opacity; it does not replace direct-light shadows.
/// One small static rail texture, no extra geometry or render passes.
/// Phone frame cost remains to be measured.
final class MobileContactOcclusion: NSObject, SCNSceneRendererDelegate {
    static let encodedOpacityScale: Float = 0.85
    private let balls: [SCNNode]
    private let materials: [SCNMaterial]
    private let surfaceY: Float
    private let radius = AngleSceneCalculator.ballRadius
    private var previous: [SIMD4<Float>]

    init(scene: AngleTrainingScene) {
        balls = scene.allBallNodes.sorted { $0.key < $1.key }.map(\.value)
        surfaceY = scene.surfaceY
        previous = Array(repeating: SIMD4<Float>(repeating: .nan), count: balls.count)
        var shader = "#pragma arguments\n"
        let railTexture = MobileTableRendering.railOcclusion
        if railTexture != nil { shader += "texture2d<float> bakedRailAO;\n" }
        // SceneKit binds each custom argument separately. Pack four balls per
        // matrix to stay below older simulator constant-buffer limits.
        for group in 0..<((balls.count + 3) / 4) {
            shader += "float4x4 contactGroup\(group);\n"
        }
        shader += "#pragma body\nfloat3 contactWorld = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;\nfloat contactVisibility = 1.0;\n"
        for i in balls.indices {
            shader += """
            float4 contactBall\(i) = contactGroup\(i / 4)[\(i % 4)];
            if (contactBall\(i).w > 0.0) {
                float2 offset = contactWorld.xz - contactBall\(i).xy;
                float inverseDistance = rsqrt(dot(offset, offset) + contactBall\(i).z * contactBall\(i).z);
                contactVisibility *= 1.0 - contactBall\(i).w * \(radius * radius) * contactBall\(i).z * inverseDistance * inverseDistance * inverseDistance;
            }

            """
        }
        shader += "_surface.ambientOcclusion = contactVisibility;"
        if railTexture != nil {
            let halfX = AngleSceneCalculator.innerLength / 2
            let halfZ = AngleSceneCalculator.innerWidth / 2
            // This is a bed-plane bake. The cushion top is a separate surface
            // ~37mm higher and must not receive the bed's visibility values.
            shader += """

            if (abs(contactWorld.y - \(surfaceY)) < 0.0005) {
                constexpr sampler railSampler(coord::normalized, address::clamp_to_edge, filter::linear);
                float2 railUV = (contactWorld.xz + float2(\(halfX), \(halfZ))) / float2(\(2 * halfX), \(2 * halfZ));
                _surface.ambientOcclusion *= bakedRailAO.sample(railSampler, railUV).r;
            }
            """
        }
        // Reuse the already sampled fiber signal: S74's moderate contrast
        // adds cloth color variation without another texture or texture read.
        // This is an art-directed correlation, not a measured fabric BRDF.
        shader += """

        float clothFiber = clamp(1.0 + 4.0 * (_surface.roughness - 0.8), 0.5, 1.5);
        _surface.diffuse.rgb *= clothFiber;
        """
        var targets: [SCNMaterial] = []
        scene.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = shader
                material.shaderModifiers = modifiers
                if let railTexture {
                    material.setValue(SCNMaterialProperty(contents: railTexture), forKey: "bakedRailAO")
                }
                targets.append(material)
            }
        }
        materials = targets
        super.init()
        update(usePresentation: false)
    }

    #if DEBUG
    /// Optional diagnostic; nil during normal application use.
    var didRenderFrame: (() -> Void)?
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        didRenderFrame?()
    }
    #endif

    func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
        update(usePresentation: true)
    }

    private func update(usePresentation: Bool) {
        // Renderer callbacks already run in the frame's transaction. A nested
        // explicit transaction delays these uniforms by one frame (FL-076).
        var changedGroups: UInt = 0
        for (i, node) in balls.enumerated() {
            let rendered = usePresentation ? node.presentation : node
            let p = rendered.worldPosition
            let h = p.y - surfaceY
            let weight: Float = node.isHidden || node.parent == nil ? 0
                : Self.encodedOpacityScale * Float(rendered.opacity) * min(1, max(0, h / radius))
            let value = SIMD4(p.x, p.z, max(radius, h), weight)
            guard value != previous[i] else { continue }
            previous[i] = value
            changedGroups |= 1 << (i / 4)
        }
        for group in 0..<((balls.count + 3) / 4) where changedGroups & (1 << group) != 0 {
            let base = group * 4
            func column(_ offset: Int) -> SIMD4<Float> {
                base + offset < previous.count ? previous[base + offset] : .zero
            }
            let matrix = simd_float4x4(columns: (column(0), column(1), column(2), column(3)))
            let uniform = NSValue(scnMatrix4: SCNMatrix4(matrix))
            for material in materials { material.setValue(uniform, forKey: "contactGroup\(group)") }
        }
    }
}


/// Static isotropic visibility inside measured net bounds. No runtime ray queries.
/// S48 bounds and S49 bake use the unchanged original table mesh in world metres.
enum MobilePocketOcclusion {
    private struct Bounds: Decodable {
        let min: [Float]
        let max: [Float]
    }
    private static let asset: (UIImage, [Bounds])? = {
        guard let imageURL = Bundle.main.url(forResource: "MobilePocketOcclusion", withExtension: "png"),
              let boundsURL = Bundle.main.url(forResource: "MobilePocketOcclusionBounds", withExtension: "json"),
              let image = UIImage(contentsOfFile: imageURL.path),
              image.cgImage?.width == 64, image.cgImage?.height == 48 else { return nil }
        do {
            let boxes = try JSONDecoder().decode([Bounds].self, from: Data(contentsOf: boundsURL))
            guard boxes.count == 6, boxes.allSatisfy({ box in
                box.min.count == 3 && box.max.count == 3 && (0..<3).allSatisfy {
                    box.min[$0].isFinite && box.max[$0].isFinite && box.min[$0] < box.max[$0]
                }
            }) else { return nil }
            return (image, boxes)
        } catch {
            NSLog("MobilePocketOcclusion: cannot decode bounds: %@", String(describing: error))
            return nil
        }
    }()

    static var isAvailable: Bool { asset != nil }

    static func apply(to scene: AngleTrainingScene) {
        guard let (texture, boxes) = asset else { return }
        var body = "#pragma arguments\ntexture2d<float> pocketVolume;\n#pragma body\nfloat3 p = (scn_frame.inverseViewTransform * float4(_surface.position,1)).xyz;\n"
        for (index, box) in boxes.enumerated() {
            let low = box.min, high = box.max
            body += """

            if (all(p >= float3(\(low[0]),\(low[1]),\(low[2]))) && all(p <= float3(\(high[0]),\(high[1]),\(high[2])))) {
                float3 q = (p-float3(\(low[0]),\(low[1]),\(low[2]))) / float3(\(high[0]-low[0]),\(high[1]-low[1]),\(high[2]-low[2])) * 7.0;
                float y0 = floor(q.y), y1 = min(7.0,y0+1.0);
                constexpr sampler ps(coord::normalized,address::clamp_to_edge,filter::linear);
                float2 uv0 = float2(y0*8.0+q.x+0.5, \(index*8).0+q.z+0.5)/float2(64,48);
                float2 uv1 = float2(y1*8.0+q.x+0.5, \(index*8).0+q.z+0.5)/float2(64,48);
                _surface.ambientOcclusion = mix(pocketVolume.sample(ps,uv0).r,pocketVolume.sample(ps,uv1).r,fract(q.y));
            }
            """
        }
        scene.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "White" {
                var modifiers = material.shaderModifiers ?? [:]
                // Keep existing surface logic and the cloth geometry calibration.
                let previous = modifiers[.surface] ?? ""
                modifiers[.surface] = previous.isEmpty ? body : body + "\n" + previous.replacingOccurrences(of: "#pragma body", with: "")
                material.shaderModifiers = modifiers
                material.setValue(SCNMaterialProperty(contents: texture), forKey: "pocketVolume")
            }
        }
    }
}
