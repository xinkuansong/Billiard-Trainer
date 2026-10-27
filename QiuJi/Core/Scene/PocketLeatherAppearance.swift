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
        if previous.contains("// v64LeatherMicroSurface") {
            // Retain the theme palette and only a trace of the source pigment.
            // Most visible grain now comes from the same baked micro-surface as
            // the normal/roughness, rather than enlarged low-frequency blotches.
            let operation = """
            float leatherLuma=dot(_surface.diffuse.rgb,float3(0.2126,0.7152,0.0722));
            float leatherVariation=clamp(pow(max(leatherLuma,0.0001)/0.03437944,0.05),0.97,1.03);
            float3 leatherTint=float3(\(components[0]),\(components[1]),\(components[2]));
            _surface.diffuse.rgb=leatherTint*leatherVariation;
            """
            modifiers[.surface] = previous.replacingOccurrences(of: "#pragma body", with: "#pragma body\n" + operation)
            material.shaderModifiers = modifiers
            return material
        }
        // Append the body to an existing surface modifier without nesting pragmas.
        modifiers[.surface] = previous.isEmpty ? """
        #pragma arguments
        float3 pocketLeatherTint;
        #pragma body
        _surface.diffuse.rgb = mix(_surface.diffuse.rgb, pocketLeatherTint, 0.65);
        """ : previous + "\n_surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(\(components[0]), \(components[1]), \(components[2])), 0.65);"
        if preservesTexture && original.name == "Leather" {
            // Preserve leather grain through luminance, independent of the old
            // brown texture's RGB channels; all roles use the same tint transfer.
            modifiers[.surface] = (previous.isEmpty ? "#pragma body" : previous)
                + "\nfloat roleGrain=clamp(pow(max(dot(_surface.diffuse.rgb,float3(0.2126,0.7152,0.0722)),0.0001)/0.03437944,0.12),0.8,1.2);"
                + "\n_surface.diffuse.rgb = float3(\(components[0]),\(components[1]),\(components[2])) * roleGrain;"
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

    // Compatibility adapters for existing marker styles; semantics live in Core.
    static var firstRoleTint: UIColor { BallRoleStyle.current.uiColor }
    static var secondRoleTint: UIColor { BallRoleStyle.next.uiColor }
    static var continuationTargetTint: UIColor { BallRoleStyle.next.uiColor }
    static var targetTint: UIColor { BallRoleStyle.current.uiColor }
}
