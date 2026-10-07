import SceneKit
import UIKit

/// Offline Cycles diffuse illumination. Room assets are Y-up metres at import;
/// the USD-authored root conversion must be retained exactly once.
/// Only the selected style is loaded. No room light affects the table or balls.
enum BakedTrainingRoom {
    /// Owning asset generator: scripts/blender/build_training_rooms.py `walls`.
    /// XZ metres; asset dimensions are checked against these values in tests.
    static let roomLength: Float = 8
    static let roomWidth: Float = 6
    static let ceilingHeight: Float = 3.6
    static let cameraSafeHalfExtents = SIMD2<Float>(roomLength / 2 - 0.35, roomWidth / 2 - 0.35)
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
                // Separate physical yarn scale from the full-floor motif atlas.
                let yarnTile: Float = 0.20
                material.multiply.contentsTransform = SCNMatrix4MakeScale(roomLength / yarnTile, roomWidth / yarnTile, 1)
                material.multiply.wrapS = .mirror; material.multiply.wrapT = .mirror
                material.multiply.minificationFilter = .linear
                material.multiply.mipFilter = .linear
                material.multiply.maxAnisotropy = 16
                guard let patternURL = Bundle.main.url(forResource: "Carpet_" + style.rawValue, withExtension: "png"),
                      let patternImage = UIImage(contentsOfFile: patternURL.path) else {
                    preconditionFailure("Missing carpet atlas: \(style.rawValue)")
                }
                let pattern = SCNMaterialProperty(contents: MobileReferenceLighting.roomRGBA(patternImage))
                pattern.minificationFilter = .linear
                pattern.magnificationFilter = .linear
                pattern.mipFilter = .linear
                pattern.maxAnisotropy = 16
                material.setValue(pattern, forKey: "roomCarpetAtlas")
                // Yarn contributes local occlusion only; the bake owns room illumination and shadow.
                material.shaderModifiers = [.surface: """
                #pragma arguments
                texture2d<float> roomCarpetAtlas;
                #pragma body
                // Recenter the dark swatch around neutral modulation, retaining yarn
                // valleys instead of clipping most samples into a narrow gray band.
                _surface.multiply.rgb = clamp(float3(1.0)+2.4*(sqrt(max(_surface.multiply.rgb,float3(0.0)))-float3(0.32)),float3(0.50),float3(1.50));
                """ + carpetPattern(style: style)]
            }
            container.enumerateChildNodes { node, _ in
                node.castsShadow = false
                precondition(node.light == nil && node.camera == nil, "Room export contains runtime light/camera")
                guard let geometry = node.geometry else { return }
                if part == "floor" { node.renderingOrder = -10 }
                node.geometry?.materials = [material]
            }
        }
        room.addChildNode(makeCeiling(style: style))
        room.addChildNode(makePosters(style: style))
        return room
    }

    /// Interior-only closure: the back face is culled for cameras above the room.
    /// A single textured surface avoids overhead boxes occluding training views.
    /// The existing room cache owns the texture; the reflection probe sees it too.
    private static func makeCeiling(style: RoomStyle) -> SCNNode {
        // Extend 1 cm into each wall to close the wall-top bevel without a light leak.
        let plane = SCNPlane(width: CGFloat(roomLength + 0.02), height: CGFloat(roomWidth + 0.02))
        let material = SCNMaterial()
        material.name = "room_ceiling_" + style.rawValue
        material.lightingModel = .constant
        material.diffuse.contents = ceilingTexture(style: style)
        material.diffuse.minificationFilter = .linear
        material.diffuse.magnificationFilter = .linear
        material.diffuse.mipFilter = .linear
        material.diffuse.maxAnisotropy = 8
        material.isDoubleSided = false
        material.cullMode = .back
        plane.materials = [material]
        let node = SCNNode(geometry: plane)
        node.name = "room_ceiling"
        node.position.y = ceilingHeight
        // SCNPlane +Z normal becomes world -Y; X spans length, local Y spans Z.
        node.eulerAngles.x = .pi / 2
        node.castsShadow = false
        return node
    }

    /// Authored diffuse finish, matching the room's constant baked-material path.
    /// Dimensions below are metres. No emissive strips or additional lights.
    private static func ceilingTexture(style: RoomStyle) -> UIImage {
        let pixelsPerMetre: CGFloat = 192
        let length = CGFloat(roomLength), width = CGFloat(roomWidth)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = true
        let size = CGSize(width: length * pixelsPerMetre, height: width * pixelsPerMetre)
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let c = renderer.cgContext
            c.scaleBy(x: pixelsPerMetre, y: pixelsPerMetre)
            let bounds = CGRect(x: 0, y: 0, width: length, height: width)
            func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
                UIColor(red: r, green: g, blue: b, alpha: 1)
            }
            func fill(_ rect: CGRect, _ color: UIColor) {
                c.setFillColor(color.cgColor); c.fill(rect)
            }
            func frame(_ inset: CGFloat, _ thickness: CGFloat, _ color: UIColor) {
                c.setStrokeColor(color.cgColor); c.setLineWidth(thickness)
                c.stroke(bounds.insetBy(dx: inset + thickness/2, dy: inset + thickness/2))
            }
            let base: UIColor, edge: UIColor, timber: UIColor
            switch style {
            case .tournament:
                base = color(0.34, 0.36, 0.38); edge = color(0.19, 0.21, 0.23)
                timber = edge
            case .walnut:
                base = color(0.53, 0.49, 0.42); edge = color(0.31, 0.28, 0.23)
                timber = color(0.29, 0.205, 0.135)
            case .eastern:
                base = color(0.46, 0.45, 0.41); edge = color(0.27, 0.26, 0.23)
                timber = color(0.20, 0.16, 0.12)
            }
            fill(bounds, base)
            // Soft room-scale falloff keeps the ceiling readable without a flat fill.
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [base.cgColor, edge.cgColor] as CFArray, locations: [0, 1])!
            let center = CGPoint(x: length/2, y: width/2)
            c.drawRadialGradient(gradient, startCenter: center, startRadius: 0.5,
                endCenter: center, endRadius: hypot(length, width)/2, options: .drawsAfterEndLocation)

            switch style {
            case .tournament:
                // Large acoustic panels follow the one-metre wall-panel rhythm.
                c.setLineWidth(0.008)
                c.setStrokeColor(UIColor(white: 0.08, alpha: 0.45).cgColor)
                for x in 1..<Int(length) {
                    c.move(to: CGPoint(x: CGFloat(x), y: 0.12))
                    c.addLine(to: CGPoint(x: CGFloat(x), y: width - 0.12))
                }
                for z in 1..<Int(width) {
                    c.move(to: CGPoint(x: 0.12, y: CGFloat(z)))
                    c.addLine(to: CGPoint(x: length - 0.12, y: CGFloat(z)))
                }
                c.strokePath()
                frame(0, 0.12, edge)
            case .walnut:
                // Warm plaster, a walnut perimeter and three slender longitudinal battens.
                frame(0, 0.28, timber)
                for index in 1...3 {
                    let z = CGFloat(index) * width / 4
                    fill(CGRect(x: 0.28, y: z - 0.035, width: length - 0.56, height: 0.07), timber)
                    fill(CGRect(x: 0.28, y: z + 0.035, width: length - 0.56, height: 0.018),
                         UIColor(white: 0, alpha: 0.14))
                }
                frame(0.28, 0.018, color(0.39, 0.30, 0.21))
            case .eastern:
                // Quiet central field framed by dark timber and a sparse perimeter lattice.
                frame(0, 0.12, timber)
                frame(0.46, 0.075, timber)
                frame(0.64, 0.025, timber)
                for index in 1..<Int(length / 0.25) {
                    let x = CGFloat(index) * 0.25
                    for z in [CGFloat(0.12), width - 0.46] {
                        fill(CGRect(x: x, y: z, width: 0.025, height: 0.34), timber)
                    }
                }
                for index in 2..<Int(width / 0.25) - 1 {
                    let z = CGFloat(index) * 0.25
                    for x in [CGFloat(0.12), length - 0.46] {
                        fill(CGRect(x: x, y: z, width: 0.34, height: 0.025), timber)
                    }
                }
            }
            // Deterministic fine mineral/wood grain; mip filtering removes it at distance.
            var random: UInt32 = 0xCEA11
            for _ in 0..<28_000 {
                random = 1664525 &* random &+ 1013904223
                let x = CGFloat(random & 65535) / 65535 * length
                random = 1664525 &* random &+ 1013904223
                let z = CGFloat(random & 65535) / 65535 * width
                let onWood = style != .tournament && (x < 0.28 || x > length - 0.28 || z < 0.28 || z > width - 0.28)
                fill(CGRect(x: x, y: z, width: onWood ? 0.05 : 0.004, height: 0.004),
                     UIColor(white: random & 1 == 0 ? 0 : 1, alpha: onWood ? 0.035 : 0.018))
            }
            // The narrow wall junction is architectural occlusion, not a second light source.
            frame(0, 0.025, UIColor(white: 0.04, alpha: 0.65))
        }
    }

    /// Replace the bake's uniform carpet albedo while retaining its illumination.
    /// Each room has its own full-floor atlas; the original fine yarn stays independent.
    private static func carpetPattern(style: RoomStyle) -> String {
        let bakedAlbedo = style == .tournament
            ? "float3(0.075, 0.077, 0.078)" : "float3(0.11, 0.103, 0.088)"
        // The approved motifs were oversized in room views: halve their physical repeat.
        let repeatScale: String
        switch style {
        case .tournament: repeatScale = "float2(2.0)"
        case .walnut: repeatScale = "float2(4.0)"
        case .eastern: repeatScale = "float2(1.0)"
        }
        let mipBias = style == .tournament ? "0.0" : "1.0"
        let yarnStrength = "1.0"
        // Repeating motifs were authored for the previous 10 x 8 m floor.
        // Preserve their physical size and centre; the eastern border fits the room.
        let atlasUV = style == .eastern ? "_surface.diffuseTexcoord"
            : "((_surface.diffuseTexcoord-float2(0.5))*float2(\(roomLength / 10),\(roomWidth / 8))+float2(0.5))"
        return """

        // roomCarpetPattern: keep the yarn-only prefix available for visual comparisons.
        constexpr sampler carpetSampler(coord::normalized, address::mirrored_repeat,
                                         filter::linear, mip_filter::linear, max_anisotropy(16));
        float3 carpetAlbedo = roomCarpetAtlas.sample(carpetSampler,
            \(atlasUV) * \(repeatScale), bias(\(mipBias))).rgb;
        // Keep the accepted yarn relief independent of each room's macro motif.
        _surface.multiply.rgb = mix(float3(1.0), _surface.multiply.rgb, \(yarnStrength));
        _surface.diffuse.rgb *= carpetAlbedo / \(bakedAlbedo);
        """
    }

    /// Wall placement follows build_training_rooms.py in App Y-up metres.
    /// Prints sit in front of the existing inlays; the baked room stays intact.
    private static func makePosters(style: RoomStyle) -> SCNNode {
        let gallery = SCNNode()
        gallery.name = "room_posters"
        let endX = roomLength / 2 - 0.113
        let sideZ = roomWidth / 2 - 0.078
        let placements: [(String, SCNVector3, Float, Bool)] = [
            ("practice", SCNVector3(endX, 1.7, -1.8), -.pi / 2, false),
            ("calm", SCNVector3(-endX, 1.7, -1.8), .pi / 2, false),
            ("again", SCNVector3(2.8, 1.72, -sideZ), 0, true),
            ("next", SCNVector3(-2.8, 1.72, sideZ), .pi, true),
            ("control", SCNVector3(endX, 1.72, 0), -.pi / 2, true),
            ("enjoy", SCNVector3(-endX, 1.72, 0), .pi / 2, true),
            ("angle", SCNVector3(1.6, 1.72, -sideZ), 0, true),
            ("route", SCNVector3(-1.6, 1.72, sideZ), .pi, true)
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
