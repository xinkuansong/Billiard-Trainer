import SceneKit

/// PBR material factory for ball nodes extracted from USDZ.
/// Applies physically-based rendering settings to achieve realistic ball sheen.
final class MaterialFactory {

    static func applyBallMaterial(to node: SCNNode) {
        applyBallMaterialRecursive(node)
    }

    private static func applyBallMaterialRecursive(_ node: SCNNode) {
        if let geometry = node.geometry {
            for material in geometry.materials {
                material.lightingModel = .physicallyBased
                material.roughness.contents = Float(0.045)
                material.metalness.contents = Float(0.0)
                material.normal.contents = nil
                material.normal.intensity = 0
                material.isDoubleSided = false
                material.transparency = 1.0
                material.shaderModifiers = [.fragment: clearcoatFragmentShader]
            }
        }
        for child in node.childNodes {
            applyBallMaterialRecursive(child)
        }
    }

    private static let clearcoatFragmentShader = """
    float3 n = normalize(_surface.normal);
    float3 v = normalize(-_surface.position);
    float NdotV = saturate(dot(n, v));
    float ccF0 = 0.04;
    float fresnel = ccF0 + (1.0 - ccF0) * pow(1.0 - NdotV, 5.0);
    _output.color.rgb = _output.color.rgb * (1.0 - fresnel * 0.30) + float3(fresnel * 0.22);
    """
}
