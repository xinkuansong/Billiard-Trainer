import CryptoKit
import Foundation
import Metal
import SceneKit

/// Approved 2026-11-17 rail finish and bed penumbra for the fixed live table.
/// World XZ metres, Y up; bed 0.8, playfield 2.54 x 1.27. The offline bake
/// uses the actual aligned model and the two production panels, 256 rays/texel.
/// Dynamic ball visibility remains multiplicative; specular is unchanged.
enum MobileRailAppearance {
    static let assetName = "MobileRailDirectVisibility-v1"
    static let assetSHA256 = "38d7ee09f09888a38198c0e3e18e83331124cda76100987ff225c06c1c925375"
    static let modelIdentity = "ModelTrial20261010_TaiQiuZhuo.usdz:73e43df002f07637656b767fdc105033d10f0d764f6d91aa7a5276cf1c885fb6"
    private static let lock = NSLock()
    private static weak var cached: MTLTexture?
    private static var cachedDevice: UInt64 = 0
    enum Failure: Error { case unsupportedContract, resource, shader }

    // Weak cache shares the immutable 2 MiB texture while materials own it.
    // No scene/renderer is retained and there is no runtime ray tracing.
    static func texture(emitter: String, device: MTLDevice) throws -> MTLTexture {
        guard ModelAssetTrial.identity("TaiQiuZhuo") == modelIdentity,
              SHA256.hash(data: Data(emitter.utf8)).map({ String(format: "%02x", $0) }).joined()
                == StaticClothIrradiance.expectedEmitterSHA256,
              device.supports32BitFloatFiltering else { throw Failure.unsupportedContract }
        lock.lock(); defer { lock.unlock() }
        if let cached, cachedDevice == device.registryID { return cached }
        guard let url = Bundle.main.url(forResource: assetName, withExtension: "bin") else { throw Failure.resource }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count == 1024 * 512 * 4,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == assetSHA256
        else { throw Failure.resource }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: 1024, height: 512, mipmapped: false)
        descriptor.usage = .shaderRead; descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw Failure.resource }
        texture.label = assetName
        data.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, 1024, 512), mipmapLevel: 0,
                            withBytes: $0.baseAddress!, bytesPerRow: 1024 * 4)
        }
        cached = texture; cachedDevice = device.registryID
        return texture
    }

    /// Apply after the source-identity-checked diffuse/shadow/LTC optimizations.
    /// Contact-occlusion refresh rebuilds the surface; geometry survives refresh.
    static func install(on material: SCNMaterial, modifiers: inout [SCNShaderModifierEntryPoint: String],
                        emitter: String) throws {
        guard let source = modifiers[.surface],
              source.components(separatedBy: "_surface.emission.rgb = ").count == 2,
              source.components(separatedBy: "_surface.diffuse.rgb=float3(0.0);").count == 2,
              source.components(separatedBy: "#pragma body").count == 2,
              !source.contains("bedRailVisibility"),
              let device = MTLCreateSystemDefaultDevice() else { throw Failure.shader }
        let field = try texture(emitter: emitter, device: device)
        let finished = source
            .replacingOccurrences(of: "#pragma body", with: declaration + "#pragma body")
            .replacingOccurrences(of: "_surface.emission.rgb = ", with: attenuation + "_surface.emission.rgb = ")
            .replacingOccurrences(of: "_surface.diffuse.rgb=float3(0.0);", with: finish + "_surface.diffuse.rgb=float3(0.0);")
        modifiers[.surface] = StaticClothRailReuse.requested()
            ? (StaticClothRailReuse.replacing(in: finished) ?? finished) : finished
        let geometry = modifiers[.geometry] ?? "#pragma body"
        if !geometry.contains(uvFinish) { modifiers[.geometry] = geometry + uvFinish }
        material.setValue(SCNMaterialProperty(contents: field), forKey: "bedRailVisibility")
    }

    /// Keep the approved preview's original reflection inputs. Also used by
    /// comparison tests; exact snippets make removal reversible without rebaking.
    static func remove(from material: SCNMaterial) {
        guard var modifiers = material.shaderModifiers else { return }
        if let surface = modifiers[.surface] {
            let original = StaticClothRailReuse.restoring(in: surface) ?? surface
            modifiers[.surface] = original.replacingOccurrences(of: declaration, with: "")
                .replacingOccurrences(of: attenuation, with: "").replacingOccurrences(of: finish, with: "")
        }
        if let geometry = modifiers[.geometry] {
            modifiers[.geometry] = geometry.replacingOccurrences(of: uvFinish, with: "")
        }
        material.shaderModifiers = modifiers
        material.setValue(nil, forKey: "bedRailVisibility")
    }

    static let declaration = "#pragma arguments\ntexture2d<float> bedRailVisibility;\n"
    static let uvFinish = "\nfloat4 railUVWorld=scn_node.modelTransform*_geometry.position; if(railUVWorld.y>0.8005) _geometry.texcoords[0]*=1.5;"
    static let attenuation = "if(abs(p.y-0.8)<0.0005) { constexpr sampler bedShadowSampler(coord::normalized,address::clamp_to_edge,filter::linear); float2 bedShadowUV=(p.xz+float2(1.27,0.635))/float2(2.54,1.27); E*=bedRailVisibility.sample(bedShadowSampler,bedShadowUV).r; }\n"
    // Artistic nose transition and 16% maximum linear dark-side lift, as previewed.
    // Preserve the cushion top and the bottom contact strip.
    static let finish = """
    if(p.y>0.8005) {
        float3 railG=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz);
        float railLip=smoothstep(-0.30,-0.05,railG.y)*(1.0-smoothstep(0.30,0.70,railG.y));
        float3 railSoftNormal=normalize(n+float3(0,0.18,0));
        float3 railSoftE=max(v62PanelDiffuse(p,railSoftNormal)-v62PanelDiffuse(p,n),float3(0.0));
        _surface.emission.rgb+=(_surface.diffuse.rgb*_surface.multiply.rgb)*railSoftE*(0.25/3.14159265)*railLip;
    }
    if(p.y>0.8005) {
        float3 railG=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz);
        float railSide=1.0-smoothstep(-0.15,0.35,railG.y);
        float railFoot=smoothstep(0.802,0.814,p.y);
        float3 railIncident=E/3.14159265+0.26*_surface.ambientOcclusion;
        float railPeak=max(railIncident.r,max(railIncident.g,railIncident.b));
        float railDark=1.0-smoothstep(0.30,0.65,railPeak);
        _surface.emission.rgb*=1.0+0.16*railSide*railFoot*railDark;
    }
    """ + "\n"
}


/// Reuse only the verified C1 analytic fallback and skip zero-contribution rail work.
/// Fixed model/lamp validation remains owned by MobileRailAppearance.texture.
/// No resource, per-camera cache, ball-state storage or frame callback is added.
enum StaticClothRailReuse {
    static let identity = "static-cloth-rail-analytic-reuse-v1"
    static let disableArgument = "-rendering.noStaticClothRailReuse"
    static let inputSHA256 = "ca7cae37f1722967d73caa13f64676f8fe8ce3109303934cae22e8fa03878b04"
    static let outputSHA256 = "8f4324d0bc1fc7f93e2aea3b0ecf94b4e2488cffce7d309cb5eb115f6767a3a1"

    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
        !arguments.contains(disableArgument)
        #else
        true
        #endif
    }

    static func replacing(in source: String) -> String? {
        guard sha(source) == inputSHA256, let result = transform(source, reverse: false),
              sha(result) == outputSHA256 else { return nil }
        return result
    }

    /// Reflection baking removes the approved rail finish. Restore the exact original
    /// source first so that its existing removal contract and reflection inputs survive.
    static func restoring(in source: String) -> String? {
        guard sha(source) == outputSHA256, let result = transform(source, reverse: true),
              sha(result) == inputSHA256 else { return nil }
        return result
    }

    private static func sha(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func transform(_ source: String, reverse: Bool) -> String? {
        var result = source
        let operations = reverse ? Array(replacements.reversed()) : replacements
        for (before, after) in operations {
            let old = reverse ? after : before, new = reverse ? before : after
            guard result.components(separatedBy: old).count == 2 else { return nil }
            result = result.replacingOccurrences(of: old, with: new)
        }
        return result
    }

    // Same complete surface as B3 research; full input/output hashes reject drift,
    // double application and unvalidated ball capacities while preserving the old path.
    private static let replacements: [(String, String)] = [
        ("""
            E=temporalFieldDiffuse(p,n,temporalField0,temporalField1)*(E/max(unoccludedE,float3(0.000001)));
            """,
"""
            // S: fixed-light field evaluated with current M normal.
                float3 clothStaticIrradiance=temporalFieldDiffuse(p,n,temporalField0,temporalField1);
                // D: two lamps retain their original directional weights and normalization.
                float3 clothDiffuseVisibility=E/max(unoccludedE,float3(0.000001));
                E=clothStaticIrradiance*clothDiffuseVisibility;
            """),
        ("""
            _surface.emission.rgb = (_surface.diffuse.rgb * _surface.multiply.rgb)
            """,
"""
            // M: current filtered texture colour; V: nap and S remain view-dependent.
                float3 clothAlbedo=(_surface.diffuse.rgb * _surface.multiply.rgb);
                // C: preserve the original composition, including dynamic railDark below.
                _surface.emission.rgb = clothAlbedo
            """),
        ("""
                float3 railSoftNormal=normalize(n+float3(0,0.18,0));
            """,
"""
                if(railLip>0.0) {
                float3 railSoftNormal=normalize(n+float3(0,0.18,0));
            """),
        ("""
            float3 railSoftE=max(v62PanelDiffuse(p,railSoftNormal)-v62PanelDiffuse(p,n),float3(0.0));
            """,
"""
            // Only the analytic fallback is identical to the base integral here.
                float3 railBaseE=temporalFieldEligible(p,n) ? v62PanelDiffuse(p,n) : clothStaticIrradiance;
                float3 railSoftE=max(v62PanelDiffuse(p,railSoftNormal)-railBaseE,float3(0.0));
            """),
        ("""
                _surface.emission.rgb+=(_surface.diffuse.rgb*_surface.multiply.rgb)*railSoftE*(0.25/3.14159265)*railLip;
            """,
"""
                _surface.emission.rgb+=(_surface.diffuse.rgb*_surface.multiply.rgb)*railSoftE*(0.25/3.14159265)*railLip;
                }
            """)
    ]
}
