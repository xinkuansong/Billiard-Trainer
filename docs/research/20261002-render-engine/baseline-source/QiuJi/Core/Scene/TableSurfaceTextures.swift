import SceneKit
import MetalKit

/// Numerical textures must bypass sRGB conversion. Shared immutable GPU maps;
/// material copies keep their own uniforms and appearance state.
enum TableSurfaceTextures {
    static let leatherNormal = load("LeatherMicro_normal")
    static let leatherRoughness = load("LeatherMicro_roughness")

    static let woodRoughness = load("WoodCoat_Wood")

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
            return try MTKTextureLoader(device: device).newTexture(URL: url, options: [
                .SRGB: false, .generateMipmaps: true,
                .origin: MTKTextureLoader.Origin.bottomLeft
            ])
        } catch {
            preconditionFailure("Cannot load table surface texture \(name): \(error)")
        }
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
