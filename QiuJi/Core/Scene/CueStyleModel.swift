import SceneKit
import UIKit
import os

enum CueStyleModel {
    private static let logger = Logger(subsystem: "com.xinkuan.qiuji", category: "CueStyleModel")
    private static let lock = NSLock()
    private static var uvGeometry: SCNGeometry?

    /// Blender exports the original mesh with new UVs only. Its node transforms
    /// are deliberately ignored: the existing cue hierarchy remains authoritative.
    static func geometry(preserving materials: [SCNMaterial]) -> SCNGeometry? {
        lock.lock(); defer { lock.unlock() }
        if uvGeometry == nil {
            guard let url = ModelAssetTrial.url("CueUV", subdirectory: "CueStyles") else { return nil }
            do {
                let scene = try SCNScene(url: url, options: [.checkConsistency: true])
                var candidates: [SCNGeometry] = []
                scene.rootNode.enumerateChildNodes { node, _ in
                    if let geometry = node.geometry,
                       geometry.materials.contains(where: { $0.name == "White_Wood" }) {
                        candidates.append(geometry)
                    }
                }
                guard candidates.count == 1 else {
                    logger.error("Expected one cue surface, found \(candidates.count)")
                    return nil
                }
                uvGeometry = candidates[0]
            } catch {
                logger.error("Cannot load cue UVs: \(String(describing: error), privacy: .public)")
                return nil
            }
        }
        guard let copy = uvGeometry?.copy() as? SCNGeometry else { return nil }
        var mapped: [SCNMaterial] = []
        for material in copy.materials {
            guard let original = materials.first(where: { $0.name == material.name }) else {
                logger.error("Cue UV material binding mismatch")
                return nil
            }
            mapped.append(original.copy() as! SCNMaterial)
        }
        copy.materials = mapped
        return copy
    }

    static func apply(_ style: CueStyle, to materials: [SCNMaterial], originalTip: SCNMaterial? = nil) -> Bool {
        guard style != .original, !materials.isEmpty else { return false }
        guard let albedo = image(style.resourceName),
              let roughness = image(style.resourceName + "_roughness") else {
            logger.error("Missing cue textures: \(style.rawValue, privacy: .public)")
            return false
        }
        let brass = image("CueBrass_generated")
        let tip = image("CueTip_generated")
        guard style.kind != .small || (brass != nil && tip != nil) else { return false }
        for material in materials {
            switch material.name {
            case "White_Wood", "black_2":
                material.diffuse.contents = albedo
                material.roughness.contents = roughness
                material.metalness.contents = 0
                // The original normal texture uses the original UV layout.
                // Reusing it on the cylindrical atlas would distort the lighting.
                material.normal.contents = nil
            case "copp":
                material.diffuse.contents = style.kind == .small
                    ? brass
                    : UIColor(red: 0.945, green: 0.926, blue: 0.87, alpha: 1)
                material.metalness.contents = style.kind == .small ? 1 : 0
                material.lightingModel = .physicallyBased
                material.normal.contents = nil
                material.roughness.contents = style.kind == .small
                    ? image("CueBrass_roughness") : NSNumber(value: 0.28)
            case "PiTou":
                // The generated side/crown scan is baked to the existing tip UVs.
                material.diffuse.contents = style.kind == .small ? tip : originalTip?.diffuse.contents
                material.normal.contents = style.kind == .small ? nil : originalTip?.normal.contents
                material.roughness.contents = style.kind == .small ? NSNumber(value: 0.88) : originalTip?.roughness.contents
                material.metalness.contents = style.kind == .small ? NSNumber(value: 0) : originalTip?.metalness.contents
                material.multiply.contents = UIColor.white
                continue
            default: continue
            }
            material.multiply.contents = UIColor.white
        }
        return true
    }

    private static func image(_ resource: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "png", subdirectory: "CueStyles") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func preview(_ style: CueStyle, detail: Bool = false) -> UIImage? {
        image(style.resourceName + (detail ? "_detail" : "_preview"))
    }
}
