import SceneKit
import MetalKit

/// Numerical textures must bypass sRGB conversion. Shared immutable GPU maps;
/// material copies keep their own uniforms and appearance state.
enum TableSurfaceTextures {
    private static let cacheLock = NSLock()
    private static var textures: [String: MTLTexture] = [:]
    static var leatherNormal: MTLTexture { texture("LeatherMicro_normal") }
    static var leatherRoughness: MTLTexture { texture("LeatherMicro_roughness") }
    static var woodRoughness: MTLTexture { texture("WoodCoat_Wood") }
    static func resetCache() {
        cacheLock.lock(); defer { cacheLock.unlock() }; textures.removeAll()
    }
    private static func texture(_ name: String) -> MTLTexture {
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let cached = textures[name] { return cached }
        // MetalKit and the readback can create autoreleased intermediates. Keep
        // only the final immutable texture when this individual load completes.
        let value = autoreleasepool { load(name) }
        textures[name] = value; return value
    }

    static func bindWood(to material: SCNMaterial) {
        // MobileTableRendering already replaces BlackWood albedo with Wood,
        // including standard. Every mobile wood finish therefore uses this map.
        material.setValue(SCNMaterialProperty(contents: woodRoughness), forKey: "woodCoatRoughness")
    }

    private static func load(_ name: String) -> MTLTexture {
        guard let device = MTLCreateSystemDefaultDevice(),
              let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            preconditionFailure("Missing table surface texture: \(name)")
        }
        do {
            let original = try MTKTextureLoader(device: device).newTexture(URL: url, options: [
                .SRGB: false, .generateMipmaps: true,
                .origin: MTKTextureLoader.Origin.bottomLeft
            ])
            let texture = name == "LeatherMicro_normal" ? original : try redChannelTexture(original)
            texture.label = name
            return texture
        } catch {
            preconditionFailure("Cannot load table surface texture \(name): \(error)")
        }
    }

    /// Preserve the loader's exact red-channel bytes at every mip level. The
    /// shaders sample only .r; neither gamma, orientation nor mip generation is
    /// changed. The temporary colour texture/readback die after this conversion.
    static func redChannelTexture(_ source: MTLTexture) throws -> MTLTexture {
        func failure(_ message: String) -> NSError {
            NSError(domain: "TableSurfaceTextures", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let red: Int
        switch source.pixelFormat {
        case .rgba8Unorm: red = 0
        case .bgra8Unorm: red = 2
        default: throw failure("Unsupported numerical texture format: \(source.pixelFormat)")
        }
        var levels: [(width: Int, height: Int, row: Int, offset: Int)] = []
        var bytes = 0
        for level in 0..<source.mipmapLevelCount {
            let width = max(1, source.width >> level), height = max(1, source.height >> level)
            let row = (width * 4 + 255) / 256 * 256
            levels.append((width, height, row, bytes)); bytes += row * height
        }
        let device = source.device
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm,
            width: source.width, height: source.height, mipmapped: source.mipmapLevelCount > 1)
        descriptor.mipmapLevelCount = source.mipmapLevelCount
        descriptor.storageMode = .shared; descriptor.usage = .shaderRead
        guard let result = device.makeTexture(descriptor: descriptor),
              let buffer = device.makeBuffer(length: bytes, options: .storageModeShared),
              let queue = device.makeCommandQueue(), let command = queue.makeCommandBuffer(),
              let blit = command.makeBlitCommandEncoder() else { throw failure("Cannot allocate numerical texture conversion") }
        for (level, shape) in levels.enumerated() {
            blit.copy(from: source, sourceSlice: 0, sourceLevel: level, sourceOrigin: MTLOrigin(x: 0,y: 0,z: 0),
                sourceSize: MTLSize(width: shape.width,height: shape.height,depth: 1), to: buffer,
                destinationOffset: shape.offset, destinationBytesPerRow: shape.row, destinationBytesPerImage: shape.row*shape.height)
        }
        blit.endEncoding(); command.commit(); command.waitUntilCompleted()
        guard command.status == .completed else { throw command.error ?? failure("Numerical texture readback failed") }
        let input = buffer.contents().assumingMemoryBound(to: UInt8.self)
        for (level, shape) in levels.enumerated() {
            var channel = [UInt8](repeating: 0, count: shape.width * shape.height)
            for y in 0..<shape.height { for x in 0..<shape.width {
                channel[y*shape.width+x] = input[shape.offset+y*shape.row+x*4+red]
            } }
            channel.withUnsafeBytes { data in
                result.replace(region: MTLRegionMake2D(0,0,shape.width,shape.height), mipmapLevel: level,
                    withBytes: data.baseAddress!, bytesPerRow: shape.width)
            }
        }
        return result
    }

    static func bindLeather(to material: SCNMaterial) {
        material.normal.contents = nil
        material.roughness.contents = 0.68
        material.setValue(SCNMaterialProperty(contents: leatherNormal), forKey: "leatherMicroNormal")
        material.setValue(SCNMaterialProperty(contents: leatherRoughness), forKey: "leatherMicroRoughness")
    }

    /// Source UV audit: corner top 151 mm/tile, middle top 200 mm/tile.
    /// The middle/corner partition lies in the empty gap between leather regions.
    /// Cotangent frame follows the untouched UVs, including mirrored islands.
    static let leatherSampling = """
    // v64LeatherMicroSurface
    constexpr sampler leatherSampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear, max_anisotropy(8));
    float3 leatherWorld=(scn_frame.inverseViewTransform*float4(_surface.position,1.0)).xyz;
    float leatherTileScale=abs(leatherWorld.x)<\(Double(TablePhysics.innerLength)/4.0) ? 1.3245033 : 1.0;
    float2 leatherUV=_surface.diffuseTexcoord*leatherTileScale;
    float3 leatherN=normalize(_surface.geometryNormal);
    float3 leatherDP1=dfdx(_surface.position), leatherDP2=dfdy(_surface.position);
    float2 leatherUV1=dfdx(_surface.diffuseTexcoord), leatherUV2=dfdy(_surface.diffuseTexcoord);
    float3 leatherP2=cross(leatherDP2,leatherN), leatherP1=cross(leatherN,leatherDP1);
    float3 leatherT=leatherP2*leatherUV1.x+leatherP1*leatherUV2.x;
    float3 leatherB=leatherP2*leatherUV1.y+leatherP1*leatherUV2.y;
    float leatherInv=rsqrt(max(1e-12,max(dot(leatherT,leatherT),dot(leatherB,leatherB))));
    float3 leatherTS=leatherMicroNormal.sample(leatherSampler,leatherUV).rgb*2.0-1.0;
    _surface.normal=normalize((leatherT*leatherTS.x+leatherB*leatherTS.y)*leatherInv+leatherN*leatherTS.z);
    _surface.roughness=leatherMicroRoughness.sample(leatherSampler,leatherUV).r;
    // The baked height also drives roughness (0.76 - 0.16 * height).
    // A restrained, mean-centred pigment response keeps the larger grain legible
    // on the inner wall without baking lighting into the colour or adding a map.
    _surface.diffuse.rgb *= 1.0 + 0.30 * (0.70088982 - _surface.roughness) / 0.16;
    """
}
