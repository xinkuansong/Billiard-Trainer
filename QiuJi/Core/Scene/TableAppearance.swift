import SceneKit
import CryptoKit

enum TableStyle: String, CaseIterable, Identifiable {
    case charcoal, standard, walnut, ivory, blossom
    /// Product default; raw values remain stable for saved selections and assets.
    static let defaultStyle: TableStyle = .charcoal
    static let preferenceKey = "tableStyle.v1"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .standard: "经典原木"
        case .walnut: "深胡桃木"
        case .charcoal: "标准"
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
        let standard: TableMaterialRecipe
    }
    private let slots: [Slot]
    private let surfaceY: Float
    private(set) var style: TableStyle = .standard
    private(set) var showsSights = true
    private static let textureCache = TableAssetImageCache(byteLimit: 16 * 1024 * 1024)
    static func resetImageCache() { textureCache.reset() }
    static func preloadTexture(_ style: TableStyle) {
        if style != .standard { _ = texture(for: style) }
    }
    private static func texture(for style: TableStyle) -> UIImage? {
        textureCache.image(for: style.rawValue) {
            guard let url = Bundle.main.url(forResource: "TableWood_" + style.rawValue, withExtension: "png"),
                  let image = UIImage(contentsOfFile: url.path) else {
                NSLog("TableAppearance: missing texture for %@", style.rawValue); return nil
            }
            return image
        }
    }

    init(table: SCNNode, surfaceY: Float = BTTablePhysics.surfaceY) {
        self.surfaceY = surfaceY
        // The shipped asset has coincident leg faces in Plane_001/Plane_007.
        // Material replacement can change their opaque sort order, revealing
        // a different UV sample. Keep depth testing and all geometry intact;
        // render the separate leg shell first so theme restoration is stable.
        // Legacy/export pipelines retain their original drawing order.
        var usesMobileMicroSurface = false
        table.enumerateChildNodes { node, _ in
            if node.geometry?.materials.contains(where: {
                $0.shaderModifiers?[.surface]?.contains("// v64LeatherMicroSurface") == true
            }) == true { usesMobileMicroSurface = true }
        }
        if usesMobileMicroSurface,
           let shell = table.childNode(withName: "Plane_007", recursively: true),
           shell.geometry?.materials.allSatisfy({ $0.name == "MG_Gold" }) == true {
            shell.renderingOrder = -1
        }
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
                captured.append(Slot(node: node, standard: TableMaterialRecipe(material)))
            }
        }
        capture(table)
        table.enumerateChildNodes { node, _ in capture(node) }
        slots = captured
    }

    func standardMaterial(named name: String) -> SCNMaterial? {
        TableModelLoader.withNativeMaterialBacking { nativeArchivePath in
            slots.first { $0.standard.name == name }?.standard.make(nativeArchivePath: nativeArchivePath)
        }
    }

    func restoreForReuse(applying _: TableStyle) { _ = apply(.standard) }

    @discardableResult
    func apply(_ selection: TableStyle, showsSights: Bool = true) -> Bool {
        guard selection != style || showsSights != self.showsSights else { return true }
        guard selection == .standard || Self.texture(for: selection) != nil else { return false }
        return TableModelLoader.withNativeMaterialBacking { nativeArchivePath in
            SCNTransaction.begin()
            SCNTransaction.disableActions = true
            for slot in slots {
                // Pocket extraction can replace a node's geometry and reorder slots.
                guard let geometry = slot.node.geometry else { continue }
                var materials = geometry.materials
                guard let index = materials.firstIndex(where: { $0.name == slot.standard.name }) else { continue }
                // While the importer is alive, reuse its native decoded resources.
                // The backing remains pinned through the material transaction; after
                // eviction, independently reopenable files restore every finish.
                let standard = slot.standard.make(nativeArchivePath: nativeArchivePath)
                if slot.standard.name == "White" {
                    materials[index] = selection.sightMaterial(from: standard, visible: showsSights, surfaceY: surfaceY)
                } else if selection == .standard {
                    materials[index] = standard
                } else if slot.standard.name == "Gold" || slot.standard.name == "Black" {
                    let material = standard.copy() as! SCNMaterial
                    material.diffuse.contents = selection.pocketColor
                    material.multiply.contents = UIColor.white
                    // Satin metal shares the leather hue, with its own highlights.
                    material.metalness.contents = 0.75
                    material.roughness.contents = 0.32
                    materials[index] = material
                } else if slot.standard.name == "Leather" {
                    materials[index] = selection.leatherMaterial(from: standard)
                } else {
                    let material = standard.copy() as! SCNMaterial
                    material.diffuse.contents = Self.texture(for: selection)
                    material.multiply.contents = UIColor.white
                    material.metalness.contents = 0.0
                    material.roughness.contents = 0.7
                    material.specular.contents = 0.15
                    material.normal.contents = nil
                    // The generated theme albedos all derive from the Wood source.
                    // Rebind its matching grain roughness, including the BlackWood rail.
                    if material.shaderModifiers?[.surface]?.contains("// v64WoodCoat") == true {
                        TableSurfaceTextures.bindWood(to: material)
                    }
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
}


/// A restorable material with URL-backed maps detached from the native material.
/// SCNMaterial.copy preserves all sampling, lighting, shader and custom-property
/// settings; clearing only URL contents releases SceneKit's decoded image cache.
/// Live/generated images and Metal maps remain shared immutable resources.
final class TableMaterialRecipe {
    static func sourceContents(_ contents: Any?) -> Any? { TableEmbeddedTexture.reference(contents) }
    private let template: SCNMaterial
    private let maps: [(KeyPath<SCNMaterial, SCNMaterialProperty>, PropertyRecipe)]
    var name: String? { template.name }
    private static let properties: [KeyPath<SCNMaterial, SCNMaterialProperty>] = [
        \.diffuse, \.ambient, \.specular, \.emission, \.transparent, \.reflective,
        \.multiply, \.normal, \.displacement, \.ambientOcclusion, \.metalness,
        \.roughness, \.selfIllumination, \.clearCoat, \.clearCoatNormal, \.clearCoatRoughness
    ]
    init(_ material: SCNMaterial) {
        template = material.copy() as! SCNMaterial
        var maps: [(KeyPath<SCNMaterial, SCNMaterialProperty>, PropertyRecipe)] = []
        for key in Self.properties {
            let original = material[keyPath: key]
            maps.append((key, PropertyRecipe(original)))
            // Keep contents only in the value recipe, never in a native material
            // that may retain a decoded texture after a style stops using it.
            template[keyPath: key].contents = nil
        }
        self.maps = maps
    }
    func make(omittingContents replaced: Set<KeyPath<SCNMaterial, SCNMaterialProperty>>) -> SCNMaterial {
        let material = make()
        for key in replaced { material[keyPath:key].contents = nil }
        return material
    }
    func make(nativeArchivePath: String? = nil) -> SCNMaterial {
        let material = template.copy() as! SCNMaterial
        for (key, recipe) in maps {
            recipe.apply(to: material[keyPath: key], nativeArchivePath: nativeArchivePath)
        }
        return material
    }
    private struct PropertyRecipe {
        let contents: Any?
        let intensity: CGFloat
        let transform: SCNMatrix4
        let minification: SCNFilterMode, magnification: SCNFilterMode, mip: SCNFilterMode
        let wrapS: SCNWrapMode, wrapT: SCNWrapMode
        let mappingChannel: Int
        let components: SCNColorMask
        let anisotropy: CGFloat
        init(_ property: SCNMaterialProperty) {
            contents = TableEmbeddedTexture.reference(property.contents); intensity = property.intensity
            transform = property.contentsTransform
            minification = property.minificationFilter; magnification = property.magnificationFilter
            mip = property.mipFilter; wrapS = property.wrapS; wrapT = property.wrapT
            mappingChannel = property.mappingChannel; components = property.textureComponents
            anisotropy = property.maxAnisotropy
        }
        func apply(to property: SCNMaterialProperty, nativeArchivePath: String?) {
            if let nativeArchivePath, let url = contents as? URL, url.path == nativeArchivePath {
                property.contents = url
            } else {
                property.contents = TableEmbeddedTexture.resolve(contents)
            }
            property.intensity = intensity; property.contentsTransform = transform
            property.minificationFilter = minification; property.magnificationFilter = magnification
            property.mipFilter = mip; property.wrapS = wrapS; property.wrapT = wrapT
            property.mappingChannel = mappingChannel; property.textureComponents = components
            // SceneKit resets this when contents changes; restore it last.
            property.maxAnisotropy = anisotropy
        }
    }
}

/// SceneKit cannot reopen USDZ byte-range URLs after the importer is released.
/// Materialize the exact compressed image bytes as a normal file, allowing
/// SceneKit to defer decoding until a material is actually rendered. The process
/// owns only URLs; unused standard maps are never eagerly decoded on hot reuse.
private enum TableEmbeddedTexture {
    private static let lock = NSLock()
    private static var originals: [URL: URL] = [:]
    private static var extracted: [URL: URL] = [:]
    private static let directory: URL = {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("qiuji-table-textures", isDirectory: true)
        // Previous processes cannot have live materials in this app container.
        // Never remove these files during cache purge: a borrower may still use
        // its lazy URL. Temporary files are reclaimed on the next cold process.
        do {
            if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch { NSLog("Table texture file cache unavailable: %@", String(describing: error)) }
        return root
    }()

    static func reference(_ contents: Any?) -> Any? {
        guard let url = contents as? URL else { return contents }
        lock.lock(); defer { lock.unlock() }
        return originals[url] ?? url
    }
    static func resolve(_ contents: Any?) -> Any? {
        guard let url = contents as? URL, url.isFileURL,
              let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let offsetText = query.first(where: { $0.name == "offset" })?.value,
              let sizeText = query.first(where: { $0.name == "size" })?.value else { return contents }
        lock.lock(); defer { lock.unlock() }
        if let file = extracted[url] { return file }
        do {
            guard let offset = UInt64(offsetText), let size = Int(sizeText), size > 0 else {
                throw failure("Invalid embedded texture range: \(url)")
            }
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: url.path))
            defer { do { try handle.close() } catch { NSLog("Table texture close failed: %@", String(describing: error)) } }
            let length = try handle.seekToEnd()
            guard offset <= length, UInt64(size) <= length - offset else { throw failure("Texture range exceeds archive") }
            try handle.seek(toOffset: offset)
            guard let data = try handle.read(upToCount: size), data.count == size else { throw failure("Embedded texture could not be read: \(url)") }
            let name = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
            let file = directory.appendingPathComponent(name + ".png")
            do {
                try data.write(to: file, options: .atomic)
                extracted[url] = file; originals[file] = url
                return file
            } catch {
                // A full temporary volume must not disable appearance changes.
                // Keep the exact decoded image for this borrower in that case.
                guard let image = UIImage(data: data) else { throw error }
                NSLog("Table texture using memory fallback: %@", String(describing: error))
                return image
            }
        } catch { preconditionFailure("Cannot restore table texture: \(error)") }
    }
    private static func failure(_ message: String) -> NSError {
        NSError(domain: "TableEmbeddedTexture", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
