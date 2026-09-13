import XCTest
import SceneKit
import Metal
@testable import QiuJi

@MainActor
final class TableAppearanceTests: XCTestCase {
    func testPackagedPreviewsAndTexturesDecode() throws {
        for style in TableStyle.allCases {
            for suffix in ["", "_noSights"] {
                let url = try XCTUnwrap(Bundle.main.url(forResource: style.previewName + suffix, withExtension: "png"))
                let preview = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
                XCTAssertEqual(preview.width, 1000); XCTAssertEqual(preview.height, 640)
            }
            if style != .standard {
                let textureURL = try XCTUnwrap(Bundle.main.url(forResource: "TableWood_" + style.rawValue, withExtension: "png"))
                let texture = try XCTUnwrap(UIImage(contentsOfFile: textureURL.path)?.cgImage)
                XCTAssertEqual(texture.width, 1024); XCTAssertEqual(texture.height, 1024)
            }
        }
    }
    func testPreferencePersistsAndUnknownValueFallsBack() throws {
        let name = "TableStyleTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertTrue(UserPreferences(defaults: defaults).showsTableSights)
        let preferences = UserPreferences(defaults: defaults)
        preferences.showsTableSights = false
        XCTAssertFalse(UserPreferences(defaults: defaults).showsTableSights)
        preferences.showsTableSights = true
        XCTAssertTrue(UserPreferences(defaults: defaults).showsTableSights)
        XCTAssertEqual(UserPreferences(defaults: defaults).tableStyle, .standard)
        for style in TableStyle.allCases {
            let prefs = UserPreferences(defaults: defaults)
            prefs.tableStyle = style
            XCTAssertEqual(UserPreferences(defaults: defaults).tableStyle, style)
        }
        defaults.set("future-style", forKey: TableStyle.preferenceKey)
        XCTAssertEqual(UserPreferences(defaults: defaults).tableStyle, .standard)
    }

    func testSwitchingRestoresStandardAndIsolatesScenes() throws {
        for pipeline in 0..<3 {
            let scene = AngleTrainingScene()
            scene.setupScene(enhancedRendering: pipeline == 1, mobileRendering: pipeline == 2)
            let untouched = AngleTrainingScene(); untouched.setupScene()
            let table = try XCTUnwrap(scene.tableNode)
            var before: [(SCNGeometry, [SCNMaterial])] = []
            table.enumerateChildNodes { node, _ in
                if let geometry = node.geometry { before.append((geometry, geometry.materials)) }
            }
            let camera = scene.cameraNode.transform
            let ballPositions = scene.allBallNodes.mapValues { $0.simdPosition }
            for style in [TableStyle.walnut, .blossom, .ivory, .charcoal, .walnut] {
                XCTAssertTrue(scene.applyTableStyle(style))
                XCTAssertEqual(scene.installedTableStyle, style)
                XCTAssertEqual(untouched.installedTableStyle, .standard)
                XCTAssertEqual(scene.allBallNodes.mapValues { $0.simdPosition }, ballPositions)
                XCTAssertTrue(SCNMatrix4EqualToMatrix4(scene.cameraNode.transform, camera))
                var changed = 0
                for (geometry, originals) in before {
                    XCTAssertEqual(geometry.materials.count, originals.count)
                    for (index, original) in originals.enumerated() {
                        if TableAppearance.materialNames.contains(original.name ?? "") {
                            changed += 1
                            XCTAssertFalse(geometry.materials[index] === original)
                            if original.name == "White" {
                                XCTAssertNotEqual(geometry.materials[index].shaderModifiers?[.surface], original.shaderModifiers?[.surface])
                            } else { XCTAssertNotNil(geometry.materials[index].diffuse.contents) }
                        } else { XCTAssertTrue(geometry.materials[index] === original) }
                    }
                }
                XCTAssertGreaterThan(changed, 0)
            }
            XCTAssertTrue(scene.applyTableStyle(.standard))
            for (geometry, originals) in before {
                for (index, original) in originals.enumerated() {
                    XCTAssertTrue(geometry.materials[index] === original)
                }
            }
        }
    }

    func testRenderAllStylesAndStandardRestoration() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: true)
        scene.setCameraMode(.perspective3D, animated: false)
        scene.rootNode.childNode(withName: "reference_room", recursively: false)?.isHidden = true
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        scene.applyBallLayout(cueBallPosition: SCNVector3(-0.45,y,0), targetBallNumber: 3,
                              targetPosition: SCNVector3(0.35,y,0.12))
        scene.cameraNode.position = SCNVector3(2.9, 2.9, 3.5)
        scene.cameraNode.look(at: SCNVector3(0, 0.55, 0))
        scene.cameraNode.camera?.usesOrthographicProjection = true
        scene.cameraNode.camera?.orthographicScale = 1.35
        scene.background.contents = UIColor(white: 0.14, alpha: 1)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode
        renderer.delegate = scene.contactOcclusion
        func snapshot() -> UIImage {
            _ = renderer.snapshot(atTime: 0, with: CGSize(width: 1000, height: 640), antialiasingMode: .multisampling4X)
            return renderer.snapshot(atTime: 0, with: CGSize(width: 1000, height: 640), antialiasingMode: .multisampling4X)
        }
        let standard = snapshot()
        var images: [Data] = []
        for style in TableStyle.allCases {
            XCTAssertTrue(scene.applyTableStyle(style))
            let image = snapshot()
            let data = try XCTUnwrap(image.pngData()); images.append(data)
            let attachment = XCTAttachment(image: image)
            attachment.name = style.previewName; attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertTrue(scene.applyTableStyle(style, showsSights: false))
            let hidden = snapshot()
            XCTAssertNotEqual(hidden.pngData(), data)
            let hiddenAttachment = XCTAttachment(image: hidden)
            hiddenAttachment.name = style.previewName + "_noSights"
            hiddenAttachment.lifetime = .keepAlways; add(hiddenAttachment)
            XCTAssertTrue(scene.applyTableStyle(style, showsSights: true))
            XCTAssertEqual(snapshot().pngData(), data, "Showing sights restores exact pixels")
        }
        XCTAssertEqual(Set(images).count, TableStyle.allCases.count, "Every style must visibly render differently")
        XCTAssertTrue(scene.applyTableStyle(.standard))
        XCTAssertEqual(snapshot().pngData(), standard.pngData(), "Returning to standard must restore original pixels")
    }

    func testBasketNetAndCoordinatedSupportsStayIndependentOfSights() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        scene.rootNode.childNode(withName: "reference_room", recursively: false)?.isHidden = true
        scene.setCameraMode(.perspective3D, animated: false)
        let camera = SCNNode()
        camera.camera = scene.cameraNode.camera?.copy() as? SCNCamera
        scene.rootNode.addChildNode(camera)
        camera.position = SCNVector3(1.85, 0.60, 1.20)
        camera.look(at: SCNVector3(1.28, 0.60, 0.67))
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 0.19
        scene.background.contents = UIColor(white: 0.14, alpha: 1)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = camera
        var supports: [SCNMaterial] = []
        var gold: SCNMaterial?
        scene.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] {
                if material.name == "Gold" { gold = material }
                if material.name == "Black" { supports.append(material) }
            }
        }
        let ring = try XCTUnwrap(gold)
        XCTAssertNotNil(ring.diffuse.contents as? UIColor)
        XCTAssertFalse(supports.isEmpty)
        for material in supports {
            XCTAssertEqual(material.diffuse.contents as? UIColor, ring.diffuse.contents as? UIColor)
            XCTAssertEqual(material.metalness.contents as? NSNumber, ring.metalness.contents as? NSNumber)
        }
        func snapshot() -> UIImage {
            _ = renderer.snapshot(atTime: 0, with: CGSize(width: 900, height: 900), antialiasingMode: .multisampling4X)
            return renderer.snapshot(atTime: 0, with: CGSize(width: 900, height: 900), antialiasingMode: .multisampling4X)
        }
        for style in TableStyle.allCases {
            XCTAssertTrue(scene.applyTableStyle(style))
            var hardware: [SCNMaterial] = []
            scene.tableNode?.enumerateChildNodes { node, _ in
                hardware += (node.geometry?.materials ?? []).filter { $0.name == "Gold" || $0.name == "Black" }
            }
            XCTAssertFalse(hardware.isEmpty)
            for material in hardware {
                XCTAssertEqual(material.diffuse.contents as? UIColor, style.pocketColor ?? ring.diffuse.contents as? UIColor)
            }
            let visible = snapshot()
            let beforeAttachment = XCTAttachment(image: visible)
            beforeAttachment.name = "basket-visible-" + style.rawValue
            beforeAttachment.lifetime = .keepAlways; add(beforeAttachment)
            XCTAssertTrue(scene.applyTableStyle(style, showsSights: false))
            let hidden = snapshot()
            // Changing the Metal discard path changes a few thin-net edge samples.
            // Measured baseline MAE < 0.001 on the 0...255 scale; preserve appearance
            // within 0.01, far below one channel quantisation step on average.
            XCTAssertLessThanOrEqual(try pixelDifference(visible, hidden), 0.01,
                                     "Basket must remain visible: \(style)")
            let attachment = XCTAttachment(image: hidden)
            attachment.name = "basket-" + style.rawValue
            attachment.lifetime = .keepAlways; add(attachment)
        }
        let basket = snapshot()
        scene.tableNode?.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            geometry.materials = geometry.materials.map { original in
                guard original.name == "White" else { return original }
                let removed = original.copy() as! SCNMaterial
                removed.shaderModifiers = [.surface: "#pragma body\ndiscard_fragment();"]
                return removed
            }
        }
        // Negative control reproduces the former whole-White visibility error.
        let missingBasket = snapshot()
        XCTAssertGreaterThan(try pixelDifference(basket, missingBasket), 0.1,
                             "Image check must reject a missing white basket")
        let rejected = XCTAttachment(image: missingBasket)
        rejected.name = "negative-control-missing-net"; rejected.lifetime = .keepAlways; add(rejected)
    }

    private func pixelDifference(_ a: UIImage, _ b: UIImage) throws -> Double {
        func pixels(_ image: UIImage) throws -> [UInt8] {
            let source = try XCTUnwrap(image.cgImage)
            var bytes = [UInt8](repeating: 0, count: source.width * source.height * 4)
            let rendered = bytes.withUnsafeMutableBytes { raw -> Bool in
                guard let context = CGContext(data: raw.baseAddress, width: source.width, height: source.height,
                    bitsPerComponent: 8, bytesPerRow: source.width * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
                return true
            }
            XCTAssertTrue(rendered)
            return bytes
        }
        let first = try pixels(a), second = try pixels(b)
        XCTAssertEqual(first.count, second.count)
        let total = zip(first, second).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return Double(total) / Double(first.count)
    }

    func testPocketThemeRestoresAndKeepsSelectionRoles() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        let markers = scene.addPocketMarkers().compactMap { $0 as? PocketLeatherMarker }
        XCTAssertEqual(markers.count, 6)
        let standard = markers.map { $0.childNode(withName: "leather_original", recursively: false)!.geometry!.materials[0] }
        let targets = markers.map { $0.childNode(withName: "leather_target", recursively: false)!.geometry!.materials[0] }
        for style in TableStyle.allCases where style != .standard {
            scene.setPocketRoles(first: 0, second: 0)
            XCTAssertTrue(scene.applyTableStyle(style))
            XCTAssertEqual(markers[0].style, .bothRoles)
            for (index, marker) in markers.enumerated() {
                XCTAssertTrue(marker.childNode(withName: "leather_target", recursively: false)!.geometry!.materials[0] === targets[index])
                XCTAssertFalse(marker.childNode(withName: "leather_original", recursively: false)!.geometry!.materials[0] === standard[index])
            }
            scene.setPocketRoles(first: nil, second: nil)
            XCTAssertTrue(markers.allSatisfy { $0.style == .original })
        }
        XCTAssertTrue(scene.applyTableStyle(.standard))
        for (index, marker) in markers.enumerated() {
            XCTAssertTrue(marker.childNode(withName: "leather_original", recursively: false)!.geometry!.materials[0] === standard[index])
        }
    }

    func testStyleSurvivesPocketExtractionAndSceneRebuild() throws {
        let scene = AngleTrainingScene()
        XCTAssertFalse(scene.applyTableStyle(.blossom))
        scene.setupScene(mobileRendering: true)
        XCTAssertEqual(scene.installedTableStyle, .blossom)
        XCTAssertEqual(scene.addPocketMarkers().count, 6)
        XCTAssertTrue(scene.applyTableStyle(.ivory))
        var changed = 0
        scene.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where TableAppearance.materialNames.contains(material.name ?? "") {
                XCTAssertNotNil(material.diffuse.contents)
                changed += 1
            }
        }
        XCTAssertGreaterThan(changed, 0)
        XCTAssertTrue(scene.applyTableStyle(.standard))
        scene.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "MG_Gold" {
                XCTAssertNotNil(material.diffuse.contents as? UIColor, "Leg finish must restore after geometry replacement")
            }
        }
        XCTAssertTrue(scene.applyTableStyle(.charcoal))
        scene.setupScene(mobileRendering: true)
        XCTAssertEqual(scene.installedTableStyle, .charcoal)
    }
}
