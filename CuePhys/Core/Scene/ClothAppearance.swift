import SceneKit

enum ClothColor: String, CaseIterable, Identifiable {
    case green, tournamentBlue, mistGray, burgundy, blueGray, camel
    static let preferenceKey = "clothColor.v1"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .green: "经典绿"
        case .tournamentBlue: "赛事蓝"
        case .mistGray: "雾灰"
        case .burgundy: "酒红"
        case .blueGray: "蓝灰"
        case .camel: "暖驼"
        }
    }
    var previewName: String { "ClothPreview_" + rawValue }
    /// sRGB albedo, with fabric detail supplied by the existing normal/roughness maps.
    /// Green restores the original pipeline's complete color bindings.
    var albedo: UIColor? {
        let rgb: (CGFloat, CGFloat, CGFloat)
        switch self {
        case .green: return nil
        case .tournamentBlue: rgb = (50, 141, 181)
        case .mistGray: rgb = (133, 140, 139)
        case .burgundy: rgb = (121, 62, 75)
        case .blueGray: rgb = (88, 126, 142)
        case .camel: rgb = (171, 146, 108)
        }
        return UIColor(red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255, alpha: 1)
    }
    var swatch: UIColor { albedo ?? UIColor(red: 27.0/255, green: 107.0/255, blue: 58.0/255, alpha: 1) }
    var linearAlbedo: SCNVector3 {
        guard let albedo else { return SCNVector3(0.0074764, 0.1612358, 0.0036536) }
        let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let rgb = albedo.cgColor.converted(to: space, intent: .defaultIntent, options: nil)!.components!
        return SCNVector3(Float(rgb[0]), Float(rgb[1]), Float(rgb[2]))
    }
    static func selected(in defaults: UserDefaults = .standard) -> Self {
        Self(rawValue: defaults.string(forKey: preferenceKey) ?? "") ?? .green
    }
}

/// Color bindings only: preserve material identity so the live contact-shadow
/// delegate continues updating its captured materials. Loader instances are isolated.
final class ClothAppearance {
    private struct Slot {
        let material: SCNMaterial
        let diffuse: Any?
        let multiply: Any?
    }
    private let slots: [Slot]
    private(set) var color: ClothColor = .green

    init(table: SCNNode) {
        var captured: [Slot] = []
        var visited = Set<ObjectIdentifier>()
        func capture(_ node: SCNNode) {
            for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                guard visited.insert(ObjectIdentifier(material)).inserted else { continue }
                captured.append(Slot(material: material, diffuse: material.diffuse.contents,
                                     multiply: material.multiply.contents))
            }
        }
        capture(table)
        table.enumerateChildNodes { node, _ in capture(node) }
        slots = captured
    }

    @discardableResult
    func apply(_ selection: ClothColor) -> Bool {
        guard !slots.isEmpty else { return false }
        guard color != selection else { return true }
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        for slot in slots {
            slot.material.diffuse.contents = selection.albedo ?? slot.diffuse
            slot.material.multiply.contents = selection == .green ? slot.multiply : UIColor.white
        }
        SCNTransaction.commit()
        color = selection
        return true
    }
}
