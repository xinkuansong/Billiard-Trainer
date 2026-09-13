import SceneKit

/// Prepare before exposing to the renderer. The USDZ leather albedo is a texture,
/// not a flat UIColor: retain it and blend the selection tint in linear light.
enum PocketLeatherAppearance {
    static func material(from original: SCNMaterial, tint: UIColor, preservesTexture: Bool = false) -> SCNMaterial {
        let material = original.copy() as! SCNMaterial
        let color = tint.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        let linearSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let components = color.cgColor.converted(to: linearSpace, intent: .defaultIntent, options: nil)!.components!
        material.setValue(NSValue(scnVector3: SCNVector3(Float(components[0]), Float(components[1]), Float(components[2]))), forKey: "pocketLeatherTint")
        var modifiers = material.shaderModifiers ?? [:]
        let previous = modifiers[.surface] ?? ""
        // Append the body to an existing surface modifier without nesting pragmas.
        modifiers[.surface] = previous.isEmpty ? """
        #pragma arguments
        float3 pocketLeatherTint;
        #pragma body
        _surface.diffuse.rgb = mix(_surface.diffuse.rgb, pocketLeatherTint, 0.65);
        """ : previous + "\n_surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(\(components[0]), \(components[1]), \(components[2])), 0.65);"
        if preservesTexture && original.name == "Leather" {
            // S236: bounded gains fitted to the bundled Leather albedo histogram.
            let gain: String?
            if color == firstRoleTint {
                gain = "1.3135267863911544,21.81101806224492,10.883660841251789"
            } else if color == secondRoleTint {
                gain = "0.6493951726466205,18.2971481216344,35.96047560473092"
            } else if color == targetTint {
                gain = "8.230530978671244,11.186813922401255,1.5325792484475174"
            } else { gain = nil }
            if let gain {
                modifiers[.surface] = (previous.isEmpty ? "#pragma body" : previous)
                    + "\n_surface.diffuse.rgb = clamp(_surface.diffuse.rgb * float3(\(gain)), 0.0, 1.0);"
            }
        }
        if previous.contains("// v62SatinFinish"), let composed = modifiers[.surface], composed.hasPrefix(previous) {
            // Selection is an albedo change, before lighting; never tint/clamp
            // the already-lit satin response as if it were the source texture.
            let tintOperation = String(composed.dropFirst(previous.count))
            modifiers[.surface] = previous.replacingOccurrences(of: "#pragma body", with: "#pragma body\n" + tintOperation)
        }
        material.shaderModifiers = modifiers
        return material
    }

    static let firstRoleTint = UIColor(red: 0.36, green: 0.92, blue: 0.55, alpha: 1)
    static let secondRoleTint = UIColor(red: 0.20, green: 0.85, blue: 0.95, alpha: 1)

    static var targetTint: UIColor {
        (UIColor(named: "btAccent") ?? UIColor(red: 0.941, green: 0.678, blue: 0.188, alpha: 1)).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    }
}
