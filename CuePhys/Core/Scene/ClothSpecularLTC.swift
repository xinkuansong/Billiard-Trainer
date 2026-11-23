import CryptoKit
import Foundation
import Metal
import SceneKit

/// Fitted single-LTC rectangle highlights, with the original direction-weighted
/// soft ball shadows. The GPU selects a measured close-view domain without
/// changing material programs while the camera moves.
final class ClothSpecularLTC {
    static let identity = "single-ltc-close-view-v2"
    static let disableArgument = "-rendering.noClothLTC"
    static let assetName = "ClothSpecularLTC-v1"
    static let assetSHA256 = "5a94fd48682bdace13bd58911d843444c4ec1e03771ea959431b1e826eb0b463"
    static let width = 48, height = 64

    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
        !arguments.contains(disableArgument) && !arguments.contains("-rendering.referenceCloth")
        #else
        true
        #endif
    }

    private final class WeakEntry { weak var value: ClothSpecularLTC?; init(_ value: ClothSpecularLTC) { self.value = value } }
    private static let lock = NSLock()
    private static var cache: [String: WeakEntry] = [:]
    let textures: [MTLTexture]
    let preparationMilliseconds: Double
    var allocatedBytes: Int { textures.reduce(0) { $0 + $1.allocatedSize } }
    enum Failure: Error { case unsupportedRig, resource(String) }

    /// Preparation only. Scenes own the wrapper; idle table materials may retain
    /// textures, but this weak process index never keeps a scene or resource alive.
    static func acquire(emitter: String, radiance: Double, device: MTLDevice,
                        assetURL: URL? = Bundle.main.url(forResource: assetName, withExtension: "bin")) throws -> ClothSpecularLTC {
        guard sha(emitter) == StaticClothIrradiance.expectedEmitterSHA256,
              radiance == StaticClothIrradiance.expectedRadiance else { throw Failure.unsupportedRig }
        guard device.supports32BitFloatFiltering, let assetURL else { throw Failure.resource("unsupported device or missing LUT") }
        let key = "\(device.registryID):\(assetURL.standardizedFileURL.path):\(identity)"
        lock.lock(); defer { lock.unlock() }
        if let existing = cache[key]?.value { return existing }
        let value = try ClothSpecularLTC(device: device, url: assetURL)
        cache = cache.filter { $0.value.value != nil }
        cache[key] = WeakEntry(value)
        return value
    }

    private init(device: MTLDevice, url: URL) throws {
        let start = ProcessInfo.processInfo.systemUptime
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let bytesPerTable = Self.width * Self.height * 16
        guard data.count == 2 * bytesPerTable,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == Self.assetSHA256 else {
            throw Failure.resource("LUT identity")
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float,
            width: Self.width, height: Self.height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .shaderRead
        var prepared: [MTLTexture] = []
        for index in 0..<2 {
            guard let table = device.makeTexture(descriptor: descriptor) else { throw Failure.resource("allocation") }
            data.withUnsafeBytes { bytes in
                table.replace(region: MTLRegionMake2D(0, 0, Self.width, Self.height), mipmapLevel: 0,
                    withBytes: bytes.baseAddress!.advanced(by: index * bytesPerTable), bytesPerRow: Self.width * 16)
            }
            table.label = "\(Self.identity):\(index)"; prepared.append(table)
        }
        textures = prepared
        preparationMilliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1000
    }

    func install(on material: SCNMaterial) {
        for index in 0..<2 { material.setValue(SCNMaterialProperty(contents: textures[index]), forKey: "h18Table\(index)") }
    }

    static func removeBindings(from material: SCNMaterial) {
        for index in 0..<2 { material.setValue(nil, forKey: "h18Table\(index)") }
    }

    /// Start with today's C1/H9 source, retain its original loop as the fallback.
    /// Unknown capacities, light rigs and diagnostics fail closed to that source.
    static func replacingSpecular(in source: String) -> String? {
        guard sha(source) == ClothShadowProgram.outputSHA256,
              let start = source.range(of: "for(int panel=0;panel<2;++panel) {", options: .backwards),
              let end = source.range(of: "E=temporalFieldDiffuse", range: start.upperBound..<source.endIndex),
              let brdfStart = source.range(of: "float nl=max(0.001,dot(n,l));", options: .backwards),
              let brdfEnd = source.range(of: "float3 weighted=", range: brdfStart.upperBound..<source.endIndex) else { return nil }
        let original = String(source[start.lowerBound..<end.lowerBound])
        let brdf = String(source[brdfStart.lowerBound..<brdfEnd.lowerBound])
        func replacing(_ text: String, _ anchor: String, _ value: String) -> String? {
            guard text.components(separatedBy: anchor).count == 2 else { return nil }
            return text.replacingOccurrences(of: anchor, with: value)
        }
        let density = "float h18D=0.0;if(nearLampMasks[panel]!=0u){float3 h18Q=h18World(l,h18WX,h18WY,h18WZ);float h18Q2=dot(h18Q,h18Q);h18D=h18Scale*max(0.0,h18Q.z)/(h18Q2*h18Q2);}\n"
        guard var loop = replacing(original, brdf, density),
              let sums = replacing(loop, "int samplesX=", "float h18U=0.0,h18V=0.0;\n int samplesX=") else { return nil }
        loop = sums
        let weight = "float h18W=h18D*max(0.0,dot(v62EmitterNormal(panel),-l))/r2*cellArea*v62EmitterGain(panel);h18U+=h18W;h18V+=h18W*visibility;"
        guard let weighted = replacing(loop, "S+=weighted*visibility*D*G*F/(4.0*nv*nl);", weight) else { return nil }
        loop = weighted
        guard let close = loop.lastIndex(of: "}") else { return nil }
        loop.insert(contentsOf: "S+=float3(1,0.985,0.96)*(12.96944123374527/3.14159265)*v62EmitterGain(panel)*h18Polygon(v62EmitterCenter(panel)-p,v62EmitterU(panel),v62EmitterV(panel),h18WX,h18WY,h18WZ,h18C.y)*(nearLampMasks[panel]!=0u ? h18V/max(h18U,1e-12):1.0);\n", at: close)
        let integral = """
        if(all(nearLampMasks==uint2(0u)) && dot(n,(v62EmitterCenter(0)+v62EmitterCenter(1))*0.5-p)>abs(dot(n,v62EmitterU(0)))+abs(dot(n,v62EmitterV(0)*2.0))+1e-5){
         E=float3(1.0);unoccludedE=float3(1.0);
         S=float3(1,0.985,0.96)*(12.96944123374527/3.14159265)*h18Polygon((v62EmitterCenter(0)+v62EmitterCenter(1))*0.5-p,v62EmitterU(0),v62EmitterV(0)*2.0,h18WX,h18WY,h18WZ,h18C.y);
        }else{\(loop)}
        """
        // Keep both integrators out of the caller's register allocation. R7's
        // inlined dual loop slowed even views that never executed the LTC branch.
        let integrators = """
        struct ClothIntegral { float3 E, unoccludedE, S; };
        __attribute__((noinline)) ClothIntegral clothLTCIntegral(float3 p,float3 n,float3 v,float nv,float roughness,uint2 nearLampMasks,constant QiuJiContactUniforms &contactUniforms,texture2d<float> h18Table0,texture2d<float> h18Table1) {
        float3 E=0,unoccludedE=0,S=0; const bool shadowPossible=true;
        \(setup.replacingOccurrences(of: "_surface.roughness", with: "roughness"))
        \(integral)
        return {E,unoccludedE,S};
        }
        __attribute__((noinline)) ClothIntegral clothReferenceIntegral(float3 p,float3 n,float3 v,float nv,float a2,bool shadowPossible,uint2 nearLampMasks,constant QiuJiContactUniforms &contactUniforms) {
        float3 E=0,unoccludedE=0,S=0;
        \(original)
        return {E,unoccludedE,S};
        }
        """
        let replacement = """
        // Camera matrices are already supplied by SceneKit. No frame-time CPU binding or program swap.
        float3 clothLTCEye=scn_frame.inverseViewTransform[3].xyz;
        float clothLTCDown=scn_frame.inverseViewTransform[2].y;
        float clothLTCHeight=clothLTCEye.y-0.8;
        bool clothLTCCloseView=clothLTCHeight>=0.25 && clothLTCHeight<=0.50 && clothLTCDown>=0.5 && clothLTCDown<=0.9063078 && dot(clothLTCEye-p,clothLTCEye-p)<=1.0;
        if(clothLTCCloseView && _surface.roughness>=0.4 && shadowPossible){
        ClothIntegral result=clothLTCIntegral(p,n,v,nv,_surface.roughness,nearLampMasks,contactUniforms,h18Table0,h18Table1);
        E=result.E;unoccludedE=result.unoccludedE;S=result.S;
        }else{
        ClothIntegral result=clothReferenceIntegral(p,n,v,nv,a2,shadowPossible,nearLampMasks,contactUniforms);
        E=result.E;unoccludedE=result.unoccludedE;S=result.S;
        }
        """
        guard let body = replacing(source, original, replacement),
              var result = replacing(body, "#pragma body", helpers + "\n" + integrators + "\n#pragma body"),
              let arguments = result.range(of: "#pragma arguments") else { return nil }
        // C1 and contact uniforms each have an arguments section. Add to the
        // first section, preserving the exact known source's remaining sections.
        result.insert(contentsOf: "\ntexture2d<float> h18Table0;\ntexture2d<float> h18Table1;", at: arguments.upperBound)
        return result
    }

    private static func sha(_ source: String) -> String {
        SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static let setup = """
    float3 h18T=v-n*dot(n,v);
    if(dot(h18T,h18T)<1e-10)h18T=cross(abs(n.y)<0.9?float3(0,1,0):float3(1,0,0),n);
    h18T=normalize(h18T);float3 h18B=cross(n,h18T);
    constexpr sampler h18Sampler(coord::normalized,address::clamp_to_edge,filter::linear);
    float2 h18UV=float2(clamp((_surface.roughness-0.4)/0.6,0.0,1.0),sqrt(1.0-clamp(nv,0.0,1.0)));
    h18UV=(h18UV*float2(47,63)+0.5)/float2(48,64);
    float4 h18A=h18Table0.sample(h18Sampler,h18UV),h18C=h18Table1.sample(h18Sampler,h18UV);
    float3 h18WX=h18A.x*h18T+h18A.y*n,h18WY=h18A.z*h18B,h18WZ=h18A.w*h18T+h18C.x*n;
    float h18Scale=h18C.y*h18A.z*(h18A.x*h18C.x-h18A.y*h18A.w)/3.14159265;
    """

    private static let helpers = """
    // H18 independent LTC density and polygon integral, local Z is shading normal.
    float3 h18Transform(float3 q,float4 a,float4 b) {
     return float3(a.x*q.x+a.y*q.z,a.z*q.y,a.w*q.x+b.x*q.z);
    }
    float h18Density(float3 l,float4 a,float4 b) {
     float3 q=h18Transform(l,a,b);float q2=dot(q,q);
     float determinant=a.z*(a.x*b.x-a.y*a.w);
     return b.y*determinant*max(0.0,q.z)/(3.14159265*q2*q2);
    }
    float h18Edge(float3 p,float3 q) {
     float3 cr=cross(p,q);float sine=length(cr);
     return cr.z*atan2(sine,dot(p,q))/max(1e-8,sine);
    }
    float3 h18World(float3 q,float3 wx,float3 wy,float3 wz){return float3(dot(q,wx),dot(q,wy),dot(q,wz));}
    float h18Polygon(float3 c,float3 u,float3 v,float3 wx,float3 wy,float3 wz,float amplitude) {
     float3 q0=h18World(c-u-v,wx,wy,wz),q1=h18World(c+u-v,wx,wy,wz);
     float3 q2=h18World(c+u+v,wx,wy,wz),q3=h18World(c-u+v,wx,wy,wz);
     if(min(min(q0.z,q1.z),min(q2.z,q3.z))>0.0){
      q0=normalize(q0);q1=normalize(q1);q2=normalize(q2);q3=normalize(q3);
      return abs(h18Edge(q0,q1)+h18Edge(q1,q2)+h18Edge(q2,q3)+h18Edge(q3,q0))*amplitude/(2.0*3.14159265);
     }
     float3 transformed[4]={q0,q1,q2,q3};
     float3 clipped[6];int count=0;
     for(int j=0;j<4;++j){
      float3 p=transformed[j],q=transformed[(j+1)%4];
      if(p.z>0.0)clipped[count++]=p;
      if((p.z>0.0)!=(q.z>0.0))clipped[count++]=p+(q-p)*p.z/(p.z-q.z);
     }
     if(count<3)return 0.0;
     for(int j=0;j<count;++j)clipped[j]=normalize(clipped[j]);
     float total=0.0;
     for(int j=0;j<count;++j){float3 p=clipped[j],q=clipped[(j+1)%count];float3 cr=cross(p,q);float sine=length(cr);total+=cr.z*atan2(sine,dot(p,q))/max(1e-8,sine);}
     return abs(total)*amplitude/(2.0*3.14159265);
    }
    """
}
