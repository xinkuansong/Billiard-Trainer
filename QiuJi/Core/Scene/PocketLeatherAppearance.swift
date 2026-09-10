import SceneKit

/// Prepare before exposing to the renderer. The USDZ leather albedo is a texture,
/// not a flat UIColor: retain it and blend the selection tint in linear light.
enum PocketLeatherAppearance {
    static func material(from original: SCNMaterial, tint: UIColor) -> SCNMaterial {
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
        material.shaderModifiers = modifiers
        return material
    }

    static let firstRoleTint = UIColor(red: 0.36, green: 0.92, blue: 0.55, alpha: 1)
    static let secondRoleTint = UIColor(red: 0.20, green: 0.85, blue: 0.95, alpha: 1)

    static var targetTint: UIColor {
        (UIColor(named: "btAccent") ?? UIColor(red: 0.941, green: 0.678, blue: 0.188, alpha: 1)).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
    }
}
