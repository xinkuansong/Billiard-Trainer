import SceneKit

/// One physical leather region; exactly one material variant is visible at a time.
/// Prepare before attachment to SCNView: iOS 17 must not mutate live materials.
final class PocketLeatherMarker: SCNNode {
    enum Style: Int, CaseIterable { case original, target, firstRole, secondRole, bothRoles }
    let pocketIndex: Int
    private(set) var style: Style = .original
    private var originalMaterials: [SCNMaterial] = []
    private var tableStyle: TableStyle = .standard
    private var variants: [Style: SCNNode] = [:]

    init(index: Int, geometry: SCNGeometry, preservesTexture: Bool = false, standardMaterial: SCNMaterial? = nil) throws {
        pocketIndex = index
        super.init()
        name = "pocketMarker_\(index)"
        let geometry = geometry.copy() as! SCNGeometry
        if let standardMaterial { geometry.materials = geometry.materials.map { _ in standardMaterial } }
        originalMaterials = geometry.materials
        for style in Style.allCases {
            let g = geometry.copy() as! SCNGeometry
            switch style {
            case .original: break
            case .target: g.materials = geometry.materials.map { PocketLeatherAppearance.material(from: $0, tint: PocketLeatherAppearance.targetTint, preservesTexture: preservesTexture) }
            case .firstRole: g.materials = geometry.materials.map { PocketLeatherAppearance.material(from: $0, tint: PocketLeatherAppearance.firstRoleTint, preservesTexture: preservesTexture) }
            case .secondRole: g.materials = geometry.materials.map { PocketLeatherAppearance.material(from: $0, tint: PocketLeatherAppearance.secondRoleTint, preservesTexture: preservesTexture) }
            case .bothRoles:
                let halves = try PocketLeatherMesh.splitRoleGeometry(geometry, preservesTexture: preservesTexture)
                let node = SCNNode(geometry: halves)
                node.name = "leather_bothRoles"
                node.isHidden = true
                variants[style] = node
                addChildNode(node)
                continue
            }
            let node = SCNNode(geometry: g)
            node.name = "leather_\(style)"
            node.isHidden = style != .original
            variants[style] = node
            addChildNode(node)
        }
    }

    required init?(coder: NSCoder) { return nil }

    func applyTableStyle(_ selection: TableStyle) {
        guard selection != tableStyle else { return }
        // Role variants always derive from the source leather, never the theme tint.
        variants[.original]?.geometry?.materials = originalMaterials.map { selection.leatherMaterial(from: $0) }
        tableStyle = selection
    }

    func show(_ newStyle: Style) {
        guard newStyle != style else { return }
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        for (key, node) in variants { node.isHidden = key != newStyle }
        style = newStyle
        SCNTransaction.commit()
    }

    static func index(of node: SCNNode) -> Int? {
        var ancestor: SCNNode? = node
        while let current = ancestor {
            if let marker = current as? PocketLeatherMarker { return marker.pocketIndex }
            ancestor = current.parent
        }
        return nil
    }
}
