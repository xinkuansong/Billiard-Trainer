import SceneKit

/// Approved H wordmarks, clipped to the original trim/leather triangles offline.
/// All positions are Plane_001 local Z-up metres; the loader owns axis/scale conversion.
/// Seven small draw surfaces (one rail batch, six pickable pockets), 200 triangles.
enum TableBranding {
    static let nodePrefix = "cuephys_brand_"
    private struct Asset: Decodable { let version: Int; let parts: [Part] }
    private struct Part: Decodable {
        let name: String
        let kind: String
        let vertices: [Float]
        let normals: [Float]
        let uv: [Float]
    }
    private static let pocketIndices = ["corner-11": 0, "corner11": 1,
        "corner-1-1": 2, "corner1-1": 3, "middle1": 4, "middle-1": 5]

    @discardableResult
    static func install(on table: SCNNode, referenceLighting: Bool) -> SCNNode? {
        if let node = table.childNode(withName: nodePrefix + "root", recursively: true) { return node }
        guard let parent = table.childNode(withName: "Plane_001", recursively: true),
              let file = Bundle.main.url(forResource: "TableBrandingMesh", withExtension: "json"),
              let mask = Bundle.main.url(forResource: "TableBrandingMask", withExtension: "png") else {
            NSLog("TableBranding: missing packaged mesh/mask or source node"); return nil
        }
        do {
            let asset = try JSONDecoder().decode(Asset.self, from: Data(contentsOf: file))
            guard asset.version == 1, asset.parts.count == 12 else { throw invalidAsset() }
            let root = SCNNode(); root.name = nodePrefix + "root"
            let rail = try makeNode(parts: asset.parts.filter { $0.kind == "rail" }, mask: mask, referenceLighting: referenceLighting)
            rail.name = nodePrefix + "rail"; root.addChildNode(rail)
            for part in asset.parts where part.kind == "pocket" {
                guard let index = pocketIndices[part.name] else { throw invalidAsset() }
                let pocket = try makeNode(parts: [part], mask: mask, referenceLighting: referenceLighting)
                pocket.name = nodePrefix + "pocket_" + String(index); root.addChildNode(pocket)
            }
            parent.addChildNode(root)
            apply(.standard, to: root)
            return root
        } catch {
            NSLog("TableBranding: cannot load approved decals: %@", String(describing: error)); return nil
        }
    }
    private static func invalidAsset() -> NSError {
        NSError(domain: "TableBranding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid branding mesh"])
    }
    private static func makeNode(parts: [Part], mask: URL, referenceLighting: Bool) throws -> SCNNode {
        var positions: [SCNVector3] = [], normals: [SCNVector3] = [], uv: [CGPoint] = []
        for part in parts {
            guard !part.vertices.isEmpty, part.vertices.count % 9 == 0,
                  part.normals.count == part.vertices.count,
                  part.uv.count == part.vertices.count / 3 * 2,
                  (part.vertices + part.normals + part.uv).allSatisfy(\.isFinite) else { throw invalidAsset() }
            for i in stride(from: 0, to: part.vertices.count, by: 3) {
                positions.append(SCNVector3(part.vertices[i], part.vertices[i+1], part.vertices[i+2]))
                normals.append(SCNVector3(part.normals[i], part.normals[i+1], part.normals[i+2]))
            }
            for i in stride(from: 0, to: part.uv.count, by: 2) {
                uv.append(CGPoint(x: CGFloat(part.uv[i]), y: CGFloat(part.uv[i+1])))
            }
        }
        let geometry = SCNGeometry(sources: [.init(vertices: positions), .init(normals: normals), .init(textureCoordinates: uv)],
            elements: [SCNGeometryElement(indices: (0..<positions.count).map(Int32.init), primitiveType: .triangles)])
        let material = SCNMaterial(); material.name = nodePrefix + "ink"
        material.lightingModel = .lambert
        if referenceLighting { MobileReferenceLighting.applyPrintedInk(to: material) }
        material.metalness.contents = 0; material.roughness.contents = 0.8
        material.transparent.contents = mask; material.transparencyMode = .aOne
        material.transparent.wrapS = .clamp; material.transparent.wrapT = .clamp
        material.transparent.mipFilter = .linear; material.transparent.maxAnisotropy = 8
        material.writesToDepthBuffer = false
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.castsShadow = false; node.renderingOrder = 2
        return node
    }
    static func apply(_ style: TableStyle, to root: SCNNode) {
        // Original brown and ivory's dark leather need pale ink; the other three
        // leather palettes need dark ink. Gold trim remains dark across all styles.
        let pale = UIColor(red: 0.88, green: 0.84, blue: 0.74, alpha: 1)
        let dark = UIColor(red: 0.25, green: 0.22, blue: 0.18, alpha: 1)
        root.enumerateChildNodes { node, _ in
            guard let material = node.geometry?.firstMaterial else { return }
            let color = pocketIndex(of: node) != nil && (style == .standard || style == .ivory) ? pale : dark
            if !(material.diffuse.contents as? UIColor == color) {
                let copy = material.copy() as! SCNMaterial
                copy.diffuse.contents = color; node.geometry?.materials = [copy]
            }
        }
    }
    static func pocketIndex(of node: SCNNode) -> Int? {
        let prefix = nodePrefix + "pocket_"
        guard let name = node.name, name.hasPrefix(prefix), let index = Int(name.dropFirst(prefix.count)), (0..<6).contains(index) else { return nil }
        return index
    }
    static func setVisible(_ visible: Bool, in table: SCNNode?) {
        table?.childNode(withName: nodePrefix + "root", recursively: true)?.isHidden = !visible
    }
}
