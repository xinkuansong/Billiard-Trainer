import Metal
import SceneKit
import QuartzCore

/// Split-sum GGX resources. Generated once per probe, never from a render callback.
/// Linear radiance, Y up, equirectangular mapping identical to RoomReflectionProbe.
final class PrefilteredReflection {
    let environment: MTLTexture
    let response: MTLTexture
    let environmentProperty: SCNMaterialProperty
    let responseProperty: SCNMaterialProperty
    let generationMilliseconds: Double
    var allocatedBytes: Int { environment.allocatedSize + response.allocatedSize }
    var texelBytes: Int {
        (0..<environment.mipmapLevelCount).reduce(0) { $0 + max(1, environment.width >> $1) * max(1, environment.height >> $1) * 8 } + response.width * response.height * 4
    }
    static let algorithmVersion = 1

    private struct Programs {
        let filter: MTLComputePipelineState
        let response: MTLComputePipelineState
        let queue: MTLCommandQueue
        let lut: MTLTexture
    }
    private static let lock = NSLock()
    // iOS has one rendering device. Retain only that device's pipelines/LUT.
    private static var programs: (device: UInt64, value: Programs)?

    private static func programs(on device: MTLDevice) throws -> Programs {
        lock.lock(); defer { lock.unlock() }
        if let p = programs, p.device == device.registryID { return p.value }
        let library = try device.makeLibrary(source: kernels, options: nil)
        guard let filter = library.makeFunction(name: "prefilterRoom"),
              let response = library.makeFunction(name: "integrateResponse"),
              let queue = device.makeCommandQueue() else { throw Failure.resource("compute pipeline") }
        let filterPSO = try device.makeComputePipelineState(function: filter)
        let responsePSO = try device.makeComputePipelineState(function: response)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Float, width: 128, height: 128, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]; descriptor.storageMode = .shared
        guard let lut = device.makeTexture(descriptor: descriptor), let command = queue.makeCommandBuffer(),
              let encoder = command.makeComputeCommandEncoder() else { throw Failure.resource("response LUT") }
        lut.label = "GGX response v\(algorithmVersion)"
        encoder.setComputePipelineState(responsePSO); encoder.setTexture(lut, index: 0)
        // Uniform groups also work on Simulator devices without nonuniform dispatch.
        // Both kernels guard their output bounds, including the smallest mip levels.
        encoder.dispatchThreadgroups(MTLSize(width: 16, height: 16, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
        guard command.status == .completed else { throw command.error ?? Failure.resource("response execution") }
        let p = Programs(filter: filterPSO, response: responsePSO, queue: queue, lut: lut)
        programs = (device.registryID, p)
        return p
    }

    enum Failure: Error { case resource(String) }

    init(source: MTLTexture) throws {
        let start = CACurrentMediaTime()
        let device = source.device
        let programs = try Self.programs(on: device)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
            width: source.width, height: source.height, mipmapped: true)
        descriptor.usage = [.shaderRead, .shaderWrite, .pixelFormatView]
        descriptor.storageMode = .shared
        guard let output = device.makeTexture(descriptor: descriptor), let command = programs.queue.makeCommandBuffer() else {
            throw Failure.resource("prefilter texture")
        }
        output.label = "GGX room v\(Self.algorithmVersion)"
        for level in 0..<output.mipmapLevelCount {
            guard let encoder = command.makeComputeCommandEncoder() else { throw Failure.resource("mip \(level)") }
            var parameters = SIMD2<UInt32>(UInt32(level), UInt32(output.mipmapLevelCount))
            encoder.setComputePipelineState(programs.filter)
            encoder.setTexture(source, index: 0); encoder.setTexture(output, index: 1)
            encoder.setBytes(&parameters, length: MemoryLayout<SIMD2<UInt32>>.size, index: 0)
            let width = max(1, output.width >> level), height = max(1, output.height >> level)
            encoder.dispatchThreadgroups(MTLSize(width: (width + 7) / 8, height: (height + 7) / 8, depth: 1),
                                         threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
            encoder.endEncoding()
        }
        command.commit(); command.waitUntilCompleted()
        guard command.status == .completed else { throw command.error ?? Failure.resource("prefilter execution") }
        environment = output; response = programs.lut
        environmentProperty = SCNMaterialProperty(contents: output)
        responseProperty = SCNMaterialProperty(contents: programs.lut)
        generationMilliseconds = (CACurrentMediaTime() - start) * 1000
    }

    func install(on material: SCNMaterial) {
        material.setValue(environmentProperty, forKey: "filteredRoom")
        material.setValue(responseProperty, forKey: "reflectionResponse")
    }

    private static let kernels = """
    #include <metal_stdlib>
    using namespace metal;
    constexpr sampler environmentSampler(coord::normalized, s_address::repeat, t_address::clamp_to_edge, filter::linear, mip_filter::linear);
    float2 uvFor(float3 d) { return float2(atan2(d.x,-d.z)/(2.0*M_PI_F)+0.5, acos(clamp(d.y,-1.0f,1.0f))/M_PI_F); }
    float3 directionFor(float2 uv) {
        float phi=(uv.x-0.5)*2.0*M_PI_F, theta=uv.y*M_PI_F;
        return float3(sin(theta)*sin(phi),cos(theta),-sin(theta)*cos(phi));
    }
    float2 sequence(uint i) { return float2((float(i)+0.5)/256.0, float(reverse_bits(i))*2.3283064365386963e-10); }
    float3 ggx(float2 u,float rough) {
        float a=rough*rough, a2=a*a;
        float ct=sqrt((1.0-u.x)/(1.0+(a2-1.0)*u.x));
        float st=sqrt(max(0.0,1.0-ct*ct)), phi=2.0*M_PI_F*u.y;
        return float3(cos(phi)*st,sin(phi)*st,ct);
    }
    kernel void prefilterRoom(texture2d<float> source [[texture(0)]], texture2d<half,access::write> output [[texture(1)]],
                              constant uint2 &parameters [[buffer(0)]], uint2 pos [[thread_position_in_grid]]) {
        uint mip=parameters.x; float rough=float(mip)/float(parameters.y-1);
        if(pos.x>=output.get_width(mip) || pos.y>=output.get_height(mip)) return;
        float2 uv=(float2(pos)+0.5)/float2(output.get_width(mip),output.get_height(mip));
        if(rough==0.0) { output.write(half4(source.sample(environmentSampler,uv,level(0))),pos,mip); return; }
        float3 n=directionFor(uv), tangent=normalize(cross(abs(n.y)<0.99?float3(0,1,0):float3(1,0,0),n));
        float3 bitangent=cross(n,tangent), sum=0.0;float weight=0.0;
        for(uint i=0;i<256;i++) {
            float3 local=ggx(sequence(i),rough), h=tangent*local.x+bitangent*local.y+n*local.z;
            float3 l=reflect(-n,h);float nl=max(0.0,dot(n,l));
            if(nl>0.0) {
                // Footprint-aware source mip avoids undersampling bright room details.
                float a2=pow(rough,4.0), denom=local.z*local.z*(a2-1.0)+1.0;
                float pdf=max(1e-6,a2/(4.0*M_PI_F*denom*denom));
                float texelArea=2.0*M_PI_F*M_PI_F*max(0.001,sqrt(max(0.0,1.0-l.y*l.y)))/float(source.get_width()*source.get_height());
                float lod=max(0.0,0.5*log2(1.0/(256.0*pdf*texelArea)));
                sum+=source.sample(environmentSampler,uvFor(l),level(lod)).rgb*nl;weight+=nl;
            }
        }
        output.write(half4(half3(sum/max(weight,1e-6)),1.0h),pos,mip);
    }
    kernel void integrateResponse(texture2d<half,access::write> output [[texture(0)]], uint2 pos [[thread_position_in_grid]]) {
        if(pos.x>=output.get_width() || pos.y>=output.get_height()) return;
        float nv=(float(pos.x)+0.5)/float(output.get_width()), rough=(float(pos.y)+0.5)/float(output.get_height());
        float3 v=float3(sqrt(1.0-nv*nv),0,nv);float2 sum=0.0;float a2=pow(rough,4.0);
        for(uint i=0;i<256;i++) {
            float3 h=ggx(sequence(i),rough), l=reflect(-v,h);float nl=l.z,vh=max(0.0,dot(v,h));
            if(nl>0.0 && vh>0.0) {
                float g=2.0*nv/(nv+sqrt(a2+(1.0-a2)*nv*nv))*2.0*nl/(nl+sqrt(a2+(1.0-a2)*nl*nl));
                float visibility=g*vh/(max(0.001,h.z)*nv), fc=pow(1.0-vh,5.0);
                sum+=float2(1.0-fc,fc)*visibility;
            }
        }
        output.write(half4(half2(sum/256.0),0.0h,1.0h),pos);
    }
    """
}
