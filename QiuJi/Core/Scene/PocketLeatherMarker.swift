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
    /// Current table appearance without transient selection or teaching-role tints.
    var unhighlightedGeometry: SCNGeometry? { variants[.original]?.geometry }
    static let selectionPulseDuration: TimeInterval = 0.6
    static let selectionPulseDelay: TimeInterval = 1
    private let selectionPulse = SCNNode()
    private static let pulseActionKey = "pocketSelectionPulse"

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
            case .target: break // Selection retains the current leather colour and texture.
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
        let pulseGeometry = geometry.copy() as! SCNGeometry
        pulseGeometry.materials = originalMaterials.map {
            PocketLeatherAppearance.material(from: $0, tint: PocketLeatherAppearance.targetTint, preservesTexture: preservesTexture)
        }
        selectionPulse.geometry = pulseGeometry
        selectionPulse.name = "leather_selectionPulse"
        selectionPulse.opacity = 0
        selectionPulse.isHidden = true
        selectionPulse.renderingOrder = 1
        addChildNode(selectionPulse)
    }

    required init?(coder: NSCoder) { return nil }

    func applyTableStyle(_ selection: TableStyle) {
        guard selection != tableStyle else { return }
        // Role variants always derive from the source leather, never the theme tint.
        let materials = originalMaterials.map { selection.leatherMaterial(from: $0) }
        variants[.original]?.geometry?.materials = materials
        variants[.target]?.geometry?.materials = materials
        tableStyle = selection
    }

    func show(_ newStyle: Style, confirmsSelection: Bool = true) {
        guard newStyle != style else { return }
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        for (key, node) in variants { node.isHidden = key != newStyle }
        cancelSelectionFeedback()
        style = newStyle
        SCNTransaction.commit()
        if newStyle == .target, confirmsSelection { confirmSelection() }
    }

    /// An accepted click is an event, independent of the persistent target style.
    /// It can acknowledge an unavailable pocket while the actual mode is free.
    func confirmSelection(delay: TimeInterval = selectionPulseDelay) {
        cancelSelectionFeedback()
        if delay <= 0 {
            // A direct click is acknowledged now, before the next render/solve.
            selectionPulse.isHidden = false
            selectionPulse.opacity = 1
            selectionPulse.runAction(.sequence([
                .wait(duration: Self.selectionPulseDuration),
                .run { node in node.opacity = 0; node.isHidden = true }
            ]), forKey: Self.pulseActionKey)
        } else {
            selectionPulse.runAction(.sequence([
                .wait(duration: delay),
                .run { node in node.isHidden = false; node.opacity = 1 },
                .wait(duration: Self.selectionPulseDuration),
                .run { node in node.opacity = 0; node.isHidden = true }
            ]), forKey: Self.pulseActionKey)
        }
    }

    func cancelSelectionFeedback() {
        selectionPulse.removeAction(forKey: Self.pulseActionKey)
        selectionPulse.opacity = 0
        selectionPulse.isHidden = true
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
