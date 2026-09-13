import SceneKit

enum TableStyle: String, CaseIterable, Identifiable {
    case standard, walnut, charcoal, ivory, blossom
    static let preferenceKey = "tableStyle.v1"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .standard: "标准"
        case .walnut: "深胡桃木"
        case .charcoal: "炭黑木纹"
        case .ivory: "象牙白蜡木"
        case .blossom: "樱花粉木纹"
        }
    }
    var subtitle: String {
        switch self {
        case .standard: "保留原有球桌外观"
        case .walnut: "深棕细纹 · 经典沉稳"
        case .charcoal: "炭灰木纹 · 简洁现代"
        case .ivory: "浅暖木纹 · 明亮自然"
        case .blossom: "柔粉木纹 · 轻盈温柔"
        }
    }
    /// Coordinated leather and basket hardware palette, independent of training roles.
    var pocketColor: UIColor? {
        switch self {
        case .standard: nil
        case .walnut: UIColor(red: 0.72, green: 0.55, blue: 0.37, alpha: 1)
        case .charcoal: UIColor(red: 0.82, green: 0.76, blue: 0.64, alpha: 1)
        case .ivory: UIColor(red: 0.34, green: 0.29, blue: 0.25, alpha: 1)
        case .blossom: UIColor(red: 0.97, green: 0.97, blue: 0.96, alpha: 1)
        }
    }
    var sightColor: UIColor? {
        switch self {
        case .standard: nil
        case .walnut: UIColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1)
        case .charcoal: UIColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1)
        case .ivory: UIColor(red: 0.16, green: 0.18, blue: 0.20, alpha: 1)
        case .blossom: UIColor(red: 0.28, green: 0.16, blue: 0.23, alpha: 1)
        }
    }
    func sightMaterial(from original: SCNMaterial, visible: Bool = true, surfaceY: Float = BTTablePhysics.surfaceY) -> SCNMaterial {
        guard sightColor != nil || !visible else { return original }
        let material = original.copy() as! SCNMaterial
        let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let rgb = (sightColor ?? .white).cgColor.converted(to: space, intent: .defaultIntent, options: nil)!.components!
        // White also contains cloth spots. Restrict the finish to the rail outside
        // the canonical X-Z playing rectangle and above the cloth plane.
        // The lower White basket net must never be recoloured or discarded.
        let operation = """
        float3 sightWorld = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
        if (sightWorld.y > \(surfaceY) && (abs(sightWorld.x) > \(AngleSceneCalculator.innerLength / 2) || abs(sightWorld.z) > \(AngleSceneCalculator.innerWidth / 2))) {
            \(visible ? "_surface.diffuse.rgb = float3(\(rgb[0]), \(rgb[1]), \(rgb[2]));" : "discard_fragment();")
        }
        """
        var modifiers = material.shaderModifiers ?? [:]
        let previous = modifiers[.surface] ?? ""
        modifiers[.surface] = previous.isEmpty ? "#pragma body\n" + operation
            : previous.replacingOccurrences(of: "#pragma body", with: "#pragma body\n" + operation)
        material.shaderModifiers = modifiers
        return material
    }
    func leatherMaterial(from original: SCNMaterial) -> SCNMaterial {
        guard let pocketColor else { return original }
        return PocketLeatherAppearance.material(from: original, tint: pocketColor)
    }
    var previewName: String { "TableStylePreview_" + rawValue }
}

/// Per-table slots captured after lighting setup. Replacing materials never
/// rebuilds geometry or changes balls, pockets, cameras or the loader prototype.
final class TableAppearance {
    static let materialNames: Set<String> = ["Wood", "BlackWood", "MG_Gold", "White", "Leather", "Gold", "Black"]
    private struct Slot {
        let node: SCNNode
        let standard: SCNMaterial
    }
    private let slots: [Slot]
    private let surfaceY: Float
    private(set) var style: TableStyle = .standard
    private(set) var showsSights = true
    private static let textures: [TableStyle: UIImage] = {
        var result: [TableStyle: UIImage] = [:]
        for style in TableStyle.allCases where style != .standard {
            if let url = Bundle.main.url(forResource: "TableWood_" + style.rawValue, withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) {
                result[style] = image
            } else { NSLog("TableAppearance: missing texture for %@", style.rawValue) }
        }
        return result
    }()

    init(table: SCNNode, surfaceY: Float = BTTablePhysics.surfaceY) {
        self.surfaceY = surfaceY
        // The source Gold material belongs to the basket rings and their mount.
        // Give the Black ball supports the same baseline finish as the rings.
        var gold: SCNMaterial?
        table.enumerateChildNodes { node, _ in
            if gold == nil { gold = node.geometry?.materials.first { $0.name == "Gold" } }
        }
        if let gold {
            table.enumerateChildNodes { node, _ in
                guard let geometry = node.geometry,
                      geometry.materials.contains(where: { $0.name == "Black" }) else { return }
                geometry.materials = geometry.materials.map { original in
                    guard original.name == "Black" else { return original }
                    let finish = gold.copy() as! SCNMaterial
                    finish.name = original.name
                    return finish
                }
            }
        }
        var captured: [Slot] = []
        var visited = Set<ObjectIdentifier>()
        func capture(_ node: SCNNode) {
            guard let geometry = node.geometry, visited.insert(ObjectIdentifier(geometry)).inserted else { return }
            for material in geometry.materials
                where Self.materialNames.contains(material.name ?? "") {
                captured.append(Slot(node: node, standard: material))
            }
        }
        capture(table)
        table.enumerateChildNodes { node, _ in capture(node) }
        slots = captured
    }

    func standardMaterial(named name: String) -> SCNMaterial? {
        slots.first { $0.standard.name == name }?.standard
    }

    @discardableResult
    func apply(_ selection: TableStyle, showsSights: Bool = true) -> Bool {
        guard selection != style || showsSights != self.showsSights else { return true }
        guard selection == .standard || Self.textures[selection] != nil else { return false }
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        for slot in slots {
            // Pocket extraction can replace a node's geometry and reorder slots.
            guard let geometry = slot.node.geometry else { continue }
            var materials = geometry.materials
            guard let index = materials.firstIndex(where: { $0.name == slot.standard.name }) else { continue }
            if slot.standard.name == "White" {
                materials[index] = selection.sightMaterial(from: slot.standard, visible: showsSights, surfaceY: surfaceY)
            } else if selection == .standard {
                materials[index] = slot.standard
            } else if slot.standard.name == "Gold" || slot.standard.name == "Black" {
                let material = slot.standard.copy() as! SCNMaterial
                material.diffuse.contents = selection.pocketColor
                material.multiply.contents = UIColor.white
                // Satin metal shares the leather hue, with its own highlights.
                material.metalness.contents = 0.75
                material.roughness.contents = 0.32
                materials[index] = material
            } else if slot.standard.name == "Leather" {
                materials[index] = selection.leatherMaterial(from: slot.standard)
            } else {
                let material = slot.standard.copy() as! SCNMaterial
                material.diffuse.contents = Self.textures[selection]
                material.multiply.contents = UIColor.white
                material.metalness.contents = 0.0
                material.roughness.contents = 0.7
                material.specular.contents = 0.15
                material.normal.contents = nil
                // Retain the current illumination shader and original UV transform.
                materials[index] = material
            }
            geometry.materials = materials
        }
        SCNTransaction.commit()
        style = selection
        self.showsSights = showsSights
        return true
    }
}
