import SceneKit
import UIKit

/// Offline Cycles diffuse illumination. Room assets are Y-up metres at import;
/// the USD-authored root conversion must be retained exactly once.
/// Only the selected style is loaded. No room light affects the table or balls.
enum BakedTrainingRoom {
    private static let cacheLock = NSLock()
    private static var cached: (style: RoomStyle, node: SCNNode)?

    static func make(style: RoomStyle) -> SCNNode {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if cached?.style != style { cached = (style, load(style: style)) }
        let copy = cached!.node.clone()
        // SceneKit clone shares geometry/materials. Isolate per-scene output
        // mapping and future edits while retaining immutable decoded images.
        copy.enumerateChildNodes { node, _ in
            guard let original = node.geometry,
                  let geometry = original.copy() as? SCNGeometry else { return }
            // SCNText.copy drops its string on the current SceneKit runtime.
            if let text = original as? SCNText, let copiedText = geometry as? SCNText {
                copiedText.string = text.string
                copiedText.font = text.font
                copiedText.flatness = text.flatness
                copiedText.extrusionDepth = text.extrusionDepth
            }
            geometry.materials = geometry.materials.map { $0.copy() as! SCNMaterial }
            node.geometry = geometry
        }
        return copy
    }

    private static func load(style: RoomStyle) -> SCNNode {
        let room = SCNNode()
        room.name = "reference_room"
        for part in ["perimeter", "floor"] {
            let stem = "Room_\(style.rawValue)_\(part)"
            guard let url = Bundle.main.url(forResource: stem, withExtension: "usdz"),
                  let path = Bundle.main.path(forResource: "\(style.rawValue)_\(part)", ofType: "png"),
                  let image = UIImage(contentsOfFile: path) else {
                preconditionFailure("Missing baked room asset: \(stem)")
            }
            let asset: SCNScene
            do { asset = try SCNScene(url: url, options: nil) }
            catch { preconditionFailure("Invalid room USDZ \(stem): \(error)") }
            let container = SCNNode()
            container.name = "room_" + part
            container.transform = asset.rootNode.transform
            for child in asset.rootNode.childNodes { container.addChildNode(child.clone()) }
            room.addChildNode(container)
            let material = SCNMaterial()
            material.name = stem + "_baked"
            material.lightingModel = .constant
            material.diffuse.contents = MobileReferenceLighting.roomRGBA(image)
            material.diffuse.minificationFilter = .linear
            material.diffuse.magnificationFilter = .linear
            material.diffuse.mipFilter = .linear
            material.diffuse.maxAnisotropy = 4
            if part == "floor" {
                material.multiply.contents = MobileReferenceLighting.roomTexture("TrainingCarpet")
                // The loop-pile swatch covers 30 cm; yarn must stay millimetre-scale.
                material.multiply.contentsTransform = SCNMatrix4MakeScale(10 / 0.30, 8 / 0.30, 1)
                material.multiply.wrapS = .mirror; material.multiply.wrapT = .mirror
                material.multiply.minificationFilter = .linear
                material.multiply.mipFilter = .linear
                material.multiply.maxAnisotropy = 16
                // Yarn contributes local occlusion only; the bake owns room illumination and shadow.
                material.shaderModifiers = [.surface: """
                #pragma body
                // Recenter the dark swatch around neutral modulation, retaining yarn
                // valleys instead of clipping most samples into a narrow gray band.
                _surface.multiply.rgb = clamp(float3(1.0)+2.4*(sqrt(max(_surface.multiply.rgb,float3(0.0)))-float3(0.32)),float3(0.50),float3(1.50));
                """]
            }
            container.enumerateChildNodes { node, _ in
                node.castsShadow = false
                precondition(node.light == nil && node.camera == nil, "Room export contains runtime light/camera")
                guard let geometry = node.geometry else { return }
                if part == "floor" { node.renderingOrder = -10 }
                node.geometry?.materials = [material]
            }
        }
        room.addChildNode(makePosters(style: style))
        return room
    }

    /// Wall placement follows build_training_rooms.py in App Y-up metres.
    /// Prints sit in front of the existing inlays; the baked room stays intact.
    private static func makePosters(style: RoomStyle) -> SCNNode {
        let gallery = SCNNode()
        gallery.name = "room_posters"
        let placements: [(String, SCNVector3, Float, Bool)] = [
            ("practice", SCNVector3(4.887, 1.7, -1.8), -.pi / 2, false),
            ("calm", SCNVector3(-4.887, 1.7, -1.8), .pi / 2, false),
            ("again", SCNVector3(2.8, 1.72, -3.922), 0, true),
            ("next", SCNVector3(-2.8, 1.72, 3.922), .pi, true),
            ("control", SCNVector3(4.887, 1.72, 0), -.pi / 2, true),
            ("enjoy", SCNVector3(-4.887, 1.72, 0), .pi / 2, true),
            ("angle", SCNVector3(1.6, 1.72, -3.922), 0, true),
            ("route", SCNVector3(-1.6, 1.72, 3.922), .pi, true)
        ]
        for (theme, position, yaw, portrait) in placements {
            let printNode = SCNNode()
            printNode.name = "room_poster_" + theme
            printNode.position = position
            printNode.eulerAngles.y = yaw
            let width: CGFloat = portrait ? 0.64 : 1.30
            let height: CGFloat = portrait ? 0.96 : 0.65
            if portrait {
                let frame = SCNBox(width: width + 0.05, height: height + 0.05,
                                   length: 0.036, chamferRadius: 0.004)
                let finish = SCNMaterial()
                finish.name = "poster_frame_" + style.rawValue
                finish.lightingModel = .constant
                switch style {
                case .tournament: finish.diffuse.contents = UIColor(white: 0.065, alpha: 1)
                case .walnut: finish.diffuse.contents = UIColor(red: 0.17, green: 0.115, blue: 0.075, alpha: 1)
                case .eastern: finish.diffuse.contents = UIColor(red: 0.12, green: 0.095, blue: 0.07, alpha: 1)
                }
                frame.materials = [finish]
                let backing = SCNNode(geometry: frame)
                backing.position.z = -0.02
                backing.castsShadow = false
                printNode.addChildNode(backing)
            }
            // Reuse the card artwork itself; typography is separate scene geometry.
            let artwork: (asset: String, title: String, detail: String)
            switch theme {
            case "practice": artwork = ("coverPlanFullskill", "每一杆\n都算数", "把练习\n变成积累")
            case "calm": artwork = ("coverPracticeAimingMethods", "稳住\n再出杆", "看清目标\n做好这一杆")
            case "again": artwork = ("coverPracticeBallFeel", "手感，来自重复", "再来一次，让动作更熟悉。")
            case "control": artwork = ("coverPracticeSpinAndEnglish", "力量，恰到好处", "控制白球，也控制节奏。")
            case "enjoy": artwork = ("coverPracticeFreePlay", "热爱，自有回响", "认真打好眼前的每一杆。")
            case "angle": artwork = ("coverPracticeBankShot", "换个角度，看见可能", "多一种思路，多一条路线。")
            case "route": artwork = ("coverPracticeDiamond", "心中有数，出杆有度", "看清路线，再决定力度。")
            default: artwork = ("coverPracticePlanThree", "这一杆，也有下一杆", "进球之前，先想好白球停在哪里。")
            }
            guard let image = UIImage(named: artwork.asset) else {
                assertionFailure("Missing poster source: \(artwork.asset)")
                continue
            }
            let paperColor: UIColor
            let inkColor: UIColor
            switch style {
            case .tournament:
                paperColor = UIColor(red: 0.12, green: 0.15, blue: 0.15, alpha: 1)
                inkColor = UIColor(white: 0.90, alpha: 1)
            case .walnut:
                paperColor = UIColor(red: 0.82, green: 0.78, blue: 0.70, alpha: 1)
                inkColor = UIColor(red: 0.20, green: 0.18, blue: 0.14, alpha: 1)
            case .eastern:
                paperColor = UIColor(red: 0.87, green: 0.86, blue: 0.81, alpha: 1)
                inkColor = UIColor(red: 0.18, green: 0.22, blue: 0.20, alpha: 1)
            }
            let paper = SCNPlane(width: width, height: height)
            let paperMaterial = SCNMaterial()
            paperMaterial.lightingModel = .constant
            paperMaterial.diffuse.contents = paperColor
            paperMaterial.multiply.contents = UIColor(white: 0.65, alpha: 1)
            paper.materials = [paperMaterial]
            let paperNode = SCNNode(geometry: paper)
            paperNode.castsShadow = false
            printNode.addChildNode(paperNode)

            let aspect = image.size.width / image.size.height
            let imageWidth = portrait ? width : height * aspect
            let imageHeight = portrait ? width / aspect : height
            let plane = SCNPlane(width: imageWidth, height: imageHeight)
            let material = SCNMaterial()
            material.name = "Poster_" + style.rawValue + "_" + theme
            material.lightingModel = .constant
            material.diffuse.contents = image
            material.multiply.contents = UIColor(white: 0.65, alpha: 1)
            material.diffuse.minificationFilter = .linear
            material.diffuse.magnificationFilter = .linear
            material.diffuse.mipFilter = .linear
            material.diffuse.maxAnisotropy = 8
            plane.materials = [material]
            let face = SCNNode(geometry: plane)
            face.name = "poster_print"
            face.position = SCNVector3(portrait ? 0 : Float((imageWidth - width) / 2),
                                      portrait ? Float((height - imageHeight) / 2) : 0, 0.001)
            face.castsShadow = false
            printNode.addChildNode(face)

            func label(_ value: String, maxWidth: CGFloat, size: CGFloat, x: CGFloat, top: CGFloat,
                       weight: UIFont.Weight) {
                let text = SCNText(string: value, extrusionDepth: 0)
                text.font = UIFont.systemFont(ofSize: 100, weight: weight)
                text.flatness = 0.1
                let ink = SCNMaterial()
                ink.lightingModel = .constant
                ink.diffuse.contents = inkColor
                ink.multiply.contents = UIColor(white: 0.65, alpha: 1)
                text.materials = [ink]
                let node = SCNNode(geometry: text)
                let bounds = text.boundingBox
                let scale = min(Float(size) / 100, Float(maxWidth) / max(bounds.max.x - bounds.min.x, 0.001))
                node.scale = SCNVector3(scale, scale, scale)
                node.position = SCNVector3(Float(x) - bounds.min.x * scale,
                                           Float(top) - bounds.max.y * scale, 0.002)
                node.castsShadow = false
                printNode.addChildNode(node)
            }
            let left = portrait ? -width / 2 + 0.045 : -width / 2 + imageWidth + 0.038
            let textWidth = portrait ? width - 0.09 : width - imageWidth - 0.07
            let titleTop: CGFloat = portrait ? -0.07 : 0.19
            label(artwork.title, maxWidth: textWidth, size: portrait ? 0.046 : 0.071,
                  x: left, top: titleTop, weight: .medium)
            label(artwork.detail, maxWidth: textWidth, size: portrait ? 0.025 : 0.029,
                  x: left, top: portrait ? -0.19 : -0.07, weight: .regular)
            gallery.addChildNode(printNode)
        }
        return gallery
    }
}
