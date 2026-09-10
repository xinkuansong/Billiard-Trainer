import SceneKit

/// One physical leather region; exactly one material variant is visible at a time.
/// Prepare before attachment to SCNView: iOS 17 must not mutate live materials.
final class PocketLeatherMarker: SCNNode {
    enum Style: Int, CaseIterable { case original, target, firstRole, secondRole, bothRoles }
    let pocketIndex: Int
    private(set) var style: Style = .original
    private var variants: [Style: SCNNode] = [:]

    init(index: Int, geometry: SCNGeometry) throws {
        pocketIndex = index
        super.init()
        name = "pocketMarker_\(index)"
        for style in Style.allCases {
            let g = geometry.copy() as! SCNGeometry
            switch style {
            case .original: break
            case .target: g.materials = geometry.materials.map { PocketLeatherAppearance.material(from: $0, tint: PocketLeatherAppearance.targetTint) }
            case .firstRole: g.materials = geometry.materials.map { PocketLeatherAppearance.material(from: $0, tint: PocketLeatherAppearance.firstRoleTint) }
            case .secondRole: g.materials = geometry.materials.map { PocketLeatherAppearance.material(from: $0, tint: PocketLeatherAppearance.secondRoleTint) }
            case .bothRoles:
                let halves = try PocketLeatherMesh.splitRoleGeometry(geometry)
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
