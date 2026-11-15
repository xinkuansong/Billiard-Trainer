import CryptoKit
import Foundation
import Metal
import SceneKit

/// Shared fixed-lamp vector integral, independent of balls,
/// camera, colour and normal. Trilinear interpolation is explicitly approximate.
/// Enabled by default in Debug and Release; unsupported setups keep the analytic path.
final class StaticClothIrradiance {
    static let launchArgument = "-rendering.staticClothField"
    static let disableArgument = "-rendering.noStaticClothField"
    static let identity = "rectangle-vector-64x32x16-f32-v1"
    static let expectedEmitterSHA256 = "65c4665f3e1221ee507eefe9fd4e3e6513de2581fa9818a253e67e190ef3db42"
    static let expectedRadiance = 12.96944123374527
    static let dimensions = SIMD3<Int>(64, 32, 16)
    static let assetName = "StaticClothIrradiance-v1"
    static let assetSHA256 = "bc7509c3ebe99b0f823fd9722264f67503e006f976abc32ac54fdf050ad0b096"
    static let arguments = "#pragma arguments\ntexture3d<float> temporalField0;\ntexture3d<float> temporalField1;\n"

    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
        !arguments.contains(disableArgument) && !arguments.contains("-rendering.referenceCloth")
        #else
        true
        #endif
    }

    private static let lock = NSLock()
    private static weak var cached: StaticClothIrradiance?
    private let cacheKey: String
    let fields: [MTLTexture]
    let preparationMilliseconds: Double
    // Generated offline; zero GPU generation commands at scene preparation.
    let generationMilliseconds = 0.0
    var allocatedBytes: Int { fields.reduce(0) { $0 + $1.allocatedSize } }

    enum Failure: Error { case unsupportedRig, resource(String) }

    /// Called at scene/material preparation, never in a frame callback. The
    /// owning scene retains this object; the process cache does not retain it.
    static func acquire(emitter: String, radiance: Double, device: MTLDevice,
                        assetURL: URL? = Bundle.main.url(forResource: assetName, withExtension: "bin")) throws -> StaticClothIrradiance {
        guard device.supports32BitFloatFiltering else { throw Failure.resource("32-bit float filtering unsupported") }
        let hash = SHA256.hash(data: Data(emitter.utf8)).map { String(format: "%02x", $0) }.joined()
        guard hash == expectedEmitterSHA256, radiance == expectedRadiance else { throw Failure.unsupportedRig }
        let key = "\(identity):\(device.registryID):\(hash):\(radiance)"
        lock.lock(); defer { lock.unlock() }
        if let cached, cached.cacheKey == key { return cached }
        // A failed preparation keeps the original shader for this refresh.
        // Retry at the next scene/material preparation, never in a frame loop.
        let value = try StaticClothIrradiance(device: device, key: key, assetURL: assetURL)
        cached = value
        return value
    }

    private init(device: MTLDevice, key: String, assetURL: URL?) throws {
        let start = ProcessInfo.processInfo.systemUptime
        guard let assetURL else { throw Failure.resource("missing field asset") }
        let data = try Data(contentsOf: assetURL, options: .mappedIfSafe)
        let bytesPerField = Self.dimensions.x * Self.dimensions.y * Self.dimensions.z * 16
        guard data.count == bytesPerField * 2,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == Self.assetSHA256 else {
            throw Failure.resource("field asset identity")
        }
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D; descriptor.pixelFormat = .rgba32Float
        descriptor.width = Self.dimensions.x; descriptor.height = Self.dimensions.y; descriptor.depth = Self.dimensions.z
        descriptor.usage = .shaderRead; descriptor.storageMode = .shared
        guard let first = device.makeTexture(descriptor: descriptor), let second = device.makeTexture(descriptor: descriptor) else {
            throw Failure.resource("allocation")
        }
        data.withUnsafeBytes { bytes in
            for (index, field) in [first, second].enumerated() {
                field.replace(region: MTLRegionMake3D(0, 0, 0, descriptor.width, descriptor.height, descriptor.depth),
                    mipmapLevel: 0, slice: 0, withBytes: bytes.baseAddress!.advanced(by: index * bytesPerField),
                    bytesPerRow: descriptor.width * 16, bytesPerImage: descriptor.width * descriptor.height * 16)
            }
        }
        first.label = Self.identity + ":0"; second.label = Self.identity + ":1"
        fields = [first, second]; cacheKey = key
        preparationMilliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000
    }

    /// The original shader is retained by the caller if its known anchor drifts.
    static func replacingDiffuse(in source: String) -> String? {
        let anchor = "E=v62PanelDiffuse(p,n)*(E/max(unoccludedE,float3(0.000001)));"
        guard source.components(separatedBy: anchor).count == 2,
              source.components(separatedBy: "#pragma body").count == 2,
              !source.contains("temporalFieldDiffuse") else { return nil }
        return arguments + source
            .replacingOccurrences(of: "#pragma body", with: functions + "\n#pragma body")
            .replacingOccurrences(of: anchor, with: "E=temporalFieldDiffuse(p,n,temporalField0,temporalField1)*(E/max(unoccludedE,float3(0.000001)));")
    }

    func install(on material: SCNMaterial) {
        material.setValue(SCNMaterialProperty(contents: fields[0]), forKey: "temporalField0")
        material.setValue(SCNMaterialProperty(contents: fields[1]), forKey: "temporalField1")
    }

    // World metres, XZ horizontal / Y up. No assumptions about a flat receiver
    // normal or p.y == 0.8; cloth pocket walls keep their actual position.
    static let functions = """
    bool temporalFieldEligible(float3 p,float3 n) {
     if(!all(isfinite(p)) || p.x<-1.6 || p.x>1.6 || p.z<-0.95 || p.z>0.95 || p.y<0.65 || p.y>0.9) return false;
     for(int panel=0;panel<2;++panel) {
      float3 c=v62EmitterCenter(panel)-p,u=v62EmitterU(panel),w=v62EmitterV(panel);
      if(!(dot(c-u-w,n)>=0 && dot(c-u+w,n)>=0 && dot(c+u+w,n)>=0 && dot(c+u-w,n)>=0)) return false;
     }
     return true;
    }
    float3 temporalFieldDiffuse(float3 p,float3 n,texture3d<float> field0,texture3d<float> field1) {
     if(!temporalFieldEligible(p,n)) return v62PanelDiffuse(p,n);
     float3 g=float3((p.x+1.6)/3.2,(p.z+0.95)/1.9,(p.y-0.65)/0.25);
     float3 size=float3(field0.get_width(),field0.get_height(),field0.get_depth());
     float3 uv=(g*(size-1.0)+0.5)/size;
     constexpr sampler linearSampler(coord::normalized,address::clamp_to_edge,filter::linear);
     float3 a=field0.sample(linearSampler,uv,level(0)).xyz,b=field1.sample(linearSampler,uv,level(0)).xyz;
     float total=abs(dot(a,n))*0.5*v62EmitterGain(0)+abs(dot(b,n))*0.5*v62EmitterGain(1);
     return float3(1.0,0.985,0.96)*(12.96944123374527/3.14159265)*total;
    }
    """

    static let kernel = """
    kernel void generateClothField(texture3d<float,access::write> field0 [[texture(0)]],texture3d<float,access::write> field1 [[texture(1)]],uint3 id [[thread_position_in_grid]]) {
     uint3 size=uint3(field0.get_width(),field0.get_height(),field0.get_depth());
     if(any(id>=size)) return;
     float3 g=float3(id)/float3(size-1);
     float3 p=float3(-1.6+3.2*g.x,0.65+0.25*g.z,-0.95+1.9*g.y);
     for(int panel=0;panel<2;++panel) {
      float3 c=v62EmitterCenter(panel)-p,u=v62EmitterU(panel),w=v62EmitterV(panel);
      float3 v[4]={normalize(c-u-w),normalize(c-u+w),normalize(c+u+w),normalize(c+u-w)};
      float3 value=float3(0);
      for(int i=0;i<4;++i){float3 a=v[i],b=v[(i+1)%4];float3 edge=cross(a,b);float len=length(edge);
       if(len>0.0000001) value+=atan2(len,dot(a,b))*edge/len;
      }
      if(panel==0) field0.write(float4(value,1),id);else field1.write(float4(value,1),id);
     }
    }
    """
}

/// Preserve the validated C1 lighting while avoiding a dynamically indexed
/// per-fragment ball array and retaining the existing per-lamp blocker masks.
/// CPU uniform bytes, sample counts and BRDF arithmetic remain unchanged.
enum ClothShadowProgram {
    static let identity = "constant-balls-per-lamp-mask-v1"
    static let disableArgument = "-rendering.noConstantClothBalls"
    static let inputSHA256 = "56fde5864ef300c78e7026f890f58c753710fce194bcee9c6dcd778117552d83"
    static let outputSHA256 = "14a880284fffc793f01d0357b0a625559101609d7986c9ac0cac72e7085efa4f"

    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
        !arguments.contains(disableArgument) && !arguments.contains("-rendering.referenceCloth")
        #else
        true
        #endif
    }

    /// Preparation only. Unknown source/ABI variants retain the caller's C1
    /// program; never apply a partially matched rewrite to a new shader recipe.
    static func replacingLocalBalls(in source: String) -> String? {
        guard sha256(source) == inputSHA256 else { return nil }
        var result = source
        let replacements = [
            ("bool diagnosticGlobalQuality=shadowPossible && !diagnosticConeEligible;",
             "uint2 nearLampMasks=(shadowPossible && !diagnosticConeEligible) ? uint2(shadowMask):uint2(0u);"),
            ("bool diagnosticHighQuality=false;", ""),
            ("diagnosticHighQuality=true;", "nearLampMasks[panel]=shadowMask;"),
            ("diagnosticHighQuality=diagnosticHighQuality || diagnosticInside;",
             "if(diagnosticInside){nearLampMasks[panel] |= (1u<<diagnosticIndex);}"),
            ("diagnosticGlobalQuality=diagnosticGlobalQuality || diagnosticHighQuality;", ""),
            ("if(diagnosticGlobalQuality) {", "if(nearLampMasks[panel]!=0u) {"),
            ("uint remainingShadowBalls=shadowMask;", "uint remainingShadowBalls=nearLampMasks[panel];"),
            ("float4x4 contactGroup0;\nfloat4x4 contactGroup1;\nfloat4x4 contactGroup2;\nfloat4x4 contactGroup3;",
             "float4 contactBalls[16];"),
            ("float4 shadowBalls[16]={" + (0..<16).map { "contactBall\($0)" }.joined(separator: ",") + "};",
             "// H9: read original ball data directly from constant memory.")
        ]
        for (anchor, replacement) in replacements {
            guard result.components(separatedBy: anchor).count == 2 else { return nil }
            result = result.replacingOccurrences(of: anchor, with: replacement)
        }
        // Four column-major float4x4 values and sixteen float4 values have the
        // same 256-byte layout. The CPU producer continues to send that buffer.
        for index in 0..<16 {
            let anchor = "contactUniforms.contactGroup\(index / 4)[\(index % 4)]"
            guard result.components(separatedBy: anchor).count == 2 else { return nil }
            result = result.replacingOccurrences(of: anchor, with: "contactUniforms.contactBalls[\(index)]")
        }
        result = result.replacingOccurrences(of: "shadowBalls[", with: "contactUniforms.contactBalls[")
            .replacingOccurrences(of: "legacyConeDomain(float3 p,thread const float4 *balls)",
                                  with: "legacyConeDomain(float3 p,constant float4 *balls)")
            .replacingOccurrences(of: "legacyConeDomain(p,shadowBalls)",
                                  with: "legacyConeDomain(p,contactUniforms.contactBalls)")
        guard sha256(result) == outputSHA256 else { return nil }
        return result
    }

    private static func sha256(_ source: String) -> String {
        SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
