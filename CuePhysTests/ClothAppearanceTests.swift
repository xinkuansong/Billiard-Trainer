import XCTest
import SceneKit
import Metal
@testable import QiuJi

@MainActor
final class ClothAppearanceTests: XCTestCase {
    func testRailAppearanceSurvivesMaterialLifecycles() throws {
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering(asynchronousReflection: false)
        scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        func check(_ table: SCNNode, installed: Bool = true) throws {
            var count = 0
            table.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    count += 1
                    let surface = m.shaderModifiers?[.surface] ?? ""
                    let geometry = m.shaderModifiers?[.geometry] ?? ""
                    XCTAssertEqual(surface.components(separatedBy: MobileRailAppearance.attenuation).count - 1, installed ? 1 : 0)
                    XCTAssertEqual(surface.components(separatedBy: MobileRailAppearance.finish).count - 1, installed ? 1 : 0)
                    XCTAssertEqual(geometry.components(separatedBy: MobileRailAppearance.uvFinish).count - 1, installed ? 1 : 0)
                    let field = (m.value(forKey: "bedRailVisibility") as? SCNMaterialProperty)?.contents as? MTLTexture
                    XCTAssertEqual(field != nil, installed)
                    if let field {
                        XCTAssertEqual(field.width, 1024); XCTAssertEqual(field.height, 512)
                        XCTAssertEqual(field.pixelFormat, .r32Float)
                    }
                }
            }
            XCTAssertGreaterThan(count, 0)
        }
        try check(XCTUnwrap(scene.tableNode))
        MobileReferenceLighting.apply(to: scene)
        try check(XCTUnwrap(scene.tableNode))
        for color in ClothColor.allCases {
            XCTAssertTrue(scene.applyClothColor(color))
            try check(XCTUnwrap(scene.tableNode))
        }
        // More instances than the original shadow buffer force material regeneration.
        let instances = (1...40).map { PositionPlayBall.instanceKey(number: ($0 % 15) + 1) }
        scene.configureBallInstances(instances)
        XCTAssertTrue(instances.allSatisfy { scene.allBallNodes[$0] != nil })
        try check(XCTUnwrap(scene.tableNode))
        let overlay = scene.makeTemporaryTopDownRenderScene()
        try check(overlay.rootNode)
        let probe = try XCTUnwrap(RoomReflectionProbe.prepareBake(scene: scene, style: .tournament))
        try check(XCTUnwrap(probe.table), installed: false)
        for style in [RoomStyle.walnut, .tournament] {
            scene.setupScene(recipe: .liveReference, roomStyle: style)
            try check(XCTUnwrap(scene.tableNode))
            MobileReferenceLighting.apply(to: scene)
            try check(XCTUnwrap(scene.tableNode))
        }
        let legacy = AngleTrainingScene()
        legacy.setupScene(recipe: .legacyMobile, roomStyle: .tournament)
        try check(XCTUnwrap(legacy.tableNode), installed: false)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        XCTAssertThrowsError(try MobileRailAppearance.texture(emitter: "different lamps", device: device))
    }

    func testApprovedBrightnessSurvivesAppearanceAndSceneRebuilds() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        func assertBrightness(_ root: SCNNode, expected: Bool, file: StaticString = #filePath, line: UInt = #line) {
            var count = 0
            func check(_ node: SCNNode) {
                for material in node.geometry?.materials ?? [] {
                    let fragment = material.shaderModifiers?[.fragment] ?? ""
                    let occurrences = fragment.components(separatedBy: "// trainingBrightnessApproved").count - 1
                    XCTAssertEqual(occurrences, expected ? 1 : 0, file: file, line: line)
                    count += 1
                }
            }
            check(root); root.enumerateChildNodes { node, _ in check(node) }
            XCTAssertGreaterThan(count, 0, file: file, line: line)
        }
        func assertScene() throws {
            var clothCount = 0
            scene.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] {
                    let count = (material.shaderModifiers?[.fragment] ?? "").components(separatedBy: "// trainingBrightnessApproved").count - 1
                    XCTAssertEqual(count, material.name == "TaiNi" ? 1 : 0, "Material \(material.name ?? "unnamed") on \(node.name ?? "unnamed")")
                    if material.name == "TaiNi" { clothCount += 1 }
                }
            }
            XCTAssertGreaterThan(clothCount, 0)
            for ball in scene.allBallNodes.values { assertBrightness(ball, expected: true) }
            let room = try XCTUnwrap(scene.rootNode.childNode(withName: "reference_room", recursively: false))
            assertBrightness(room, expected: false)
            let probe = try XCTUnwrap(RoomReflectionProbe.prepareBake(scene: scene, style: .tournament))
            assertBrightness(try XCTUnwrap(probe.table), expected: false)
        }
        try assertScene()
        for color in ClothColor.allCases { XCTAssertTrue(scene.applyClothColor(color)) }
        for style in BallStickerStyle.allCases { scene.applyBallStickerStyle(style) }
        scene.configureBallInstances((1...15).map { PositionPlayBall.instanceKey(number: $0) })
        try assertScene()
        scene.setCameraMode(.perspective3D, animated: false)
        let overlay = scene.makeTemporaryTopDownRenderScene()
        let copies = overlay.rootNode.childNodes.filter { $0.name == "cueBall" }
        XCTAssertEqual(copies.count, 1)
        if let cue = copies.first { assertBrightness(cue, expected: true) }
        scene.setupScene(recipe: .liveReference, roomStyle: .walnut)
        try assertScene()
        let legacy = AngleTrainingScene()
        legacy.setupScene(recipe: .legacyMobile, roomStyle: .tournament)
        assertBrightness(try XCTUnwrap(legacy.tableNode), expected: false)
        for ball in legacy.allBallNodes.values { assertBrightness(ball, expected: false) }
    }

    func testPreferencePersistenceAndFallback() throws {
        let name = "ClothColors." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(UserPreferences(defaults: defaults).clothColor, .green)
        for color in ClothColor.allCases {
            UserPreferences(defaults: defaults).clothColor = color
            XCTAssertEqual(UserPreferences(defaults: defaults).clothColor, color)
        }
        defaults.set("unknown", forKey: ClothColor.preferenceKey)
        XCTAssertEqual(UserPreferences(defaults: defaults).clothColor, .green)
    }

    func testIsolationRestorationAndShadowBindingsAcrossPipelines() throws {
        for pipeline in 0..<3 {
            let scene = AngleTrainingScene()
            scene.setupScene(enhancedRendering: pipeline == 1, mobileRendering: pipeline == 2)
            let untouched = AngleTrainingScene(); untouched.setupScene()
            let table = try XCTUnwrap(scene.tableNode)
            var originals: [(SCNGeometry, SCNMaterial, SCNMaterial)] = []
            table.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] { originals.append((node.geometry!, m, m.copy() as! SCNMaterial)) }
            }
            let camera = scene.cameraNode.transform
            let positions = scene.allBallNodes.mapValues { $0.simdPosition }
            for color in ClothColor.allCases {
                XCTAssertTrue(scene.applyClothColor(color))
                XCTAssertEqual(untouched.installedClothColor, .green)
                XCTAssertEqual(scene.allBallNodes.mapValues { $0.simdPosition }, positions)
                XCTAssertTrue(SCNMatrix4EqualToMatrix4(scene.cameraNode.transform, camera))
                for (geometry, material, original) in originals {
                    XCTAssertTrue(geometry.materials.contains { $0 === material }, "Preserve live shadow bindings")
                    XCTAssertEqual(material.shaderModifiers, original.shaderModifiers)
                    XCTAssertTrue(SCNMatrix4EqualToMatrix4(material.normal.contentsTransform, original.normal.contentsTransform))
                    if material.name != "TaiNi" {
                        XCTAssertEqual(String(describing: material.diffuse.contents), String(describing: original.diffuse.contents))
                    }
                }
            }
            XCTAssertTrue(scene.applyClothColor(.green))
            for (_, material, original) in originals {
                XCTAssertEqual(String(describing: material.diffuse.contents), String(describing: original.diffuse.contents))
                XCTAssertEqual(String(describing: material.multiply.contents), String(describing: original.multiply.contents))
            }
            _ = scene.addPocketMarkers()
            XCTAssertTrue(scene.applyClothColor(.burgundy))
            XCTAssertTrue(scene.applyTableStyle(.ivory))
            XCTAssertEqual(scene.installedClothColor, .burgundy)
            scene.setupScene(mobileRendering: pipeline == 2)
            XCTAssertEqual(scene.installedClothColor, .burgundy)
        }
        let early = AngleTrainingScene()
        XCTAssertFalse(early.applyClothColor(.camel))
        early.setupScene()
        XCTAssertEqual(early.installedClothColor, .camel)
    }

    func testRenderPaletteAndGreenRestoration() throws {
        try renderPalette()
    }

    func testReferenceLightingPaletteAndBounce() throws {
        let previous = ProcessInfo.processInfo.environment["V62_REFERENCE_LIGHTING"]
        setenv("V62_REFERENCE_LIGHTING", "1", 1)
        defer {
            if let previous { setenv("V62_REFERENCE_LIGHTING", previous, 1) }
            else { unsetenv("V62_REFERENCE_LIGHTING") }
        }
        try renderPalette()
    }

    private func renderPalette() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: true)
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        scene.setCameraMode(.perspective3D, animated: false)
        scene.rootNode.childNode(withName: "reference_room", recursively: false)?.isHidden = true
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        scene.applyBallLayout(cueBallPosition: SCNVector3(-0.45, y, 0), targetBallNumber: 3,
                              targetPosition: SCNVector3(0.35, y, 0.12))
        scene.cameraNode.position = SCNVector3(2.9, 2.9, 3.5)
        scene.cameraNode.look(at: SCNVector3(0, 0.55, 0))
        scene.cameraNode.camera?.usesOrthographicProjection = true
        scene.cameraNode.camera?.orthographicScale = 1.35
        scene.background.contents = UIColor(white: 0.14, alpha: 1)
        SCNTransaction.commit()
        SCNTransaction.flush()
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode
        renderer.delegate = scene.contactOcclusion
        XCTAssertTrue(renderer.prepare(scene, shouldAbortBlock: nil))
        func snapshot() -> UIImage {
            SCNTransaction.flush()
            _ = renderer.snapshot(atTime: 0, with: CGSize(width: 1000, height: 640), antialiasingMode: .multisampling4X)
            return renderer.snapshot(atTime: 0, with: CGSize(width: 1000, height: 640), antialiasingMode: .multisampling4X)
        }
        let original = snapshot().pngData()
        var images = Set<Data>()
        for color in ClothColor.allCases {
            XCTAssertTrue(scene.applyClothColor(color))
            if MobileReferenceLighting.requested {
                for node in scene.allBallNodes.values {
                    node.enumerateChildNodes { child, _ in
                        for material in child.geometry?.materials ?? [] {
                            let value = material.value(forKey: "selectedClothAlbedo") as? NSValue
                            XCTAssertEqual(value?.scnVector3Value.x, color.linearAlbedo.x)
                            XCTAssertEqual(value?.scnVector3Value.y, color.linearAlbedo.y)
                            XCTAssertEqual(value?.scnVector3Value.z, color.linearAlbedo.z)
                        }
                    }
                }
            }
            let image = snapshot()
            try assertNoShaderErrorColor(image)
            images.insert(try XCTUnwrap(image.pngData()))
            let attachment = XCTAttachment(image: image)
            attachment.name = color.previewName; attachment.lifetime = .keepAlways; add(attachment)
        }
        XCTAssertEqual(images.count, ClothColor.allCases.count)
        XCTAssertTrue(scene.applyClothColor(.green))
        let restored = snapshot().pngData()
        if restored != original {
            for (name, data) in [("green-original", original), ("green-restored", restored)] {
                let proof = XCTAttachment(data: try XCTUnwrap(data), uniformTypeIdentifier: "public.png")
                proof.name = name; proof.lifetime = .keepAlways; add(proof)
            }
        }
        XCTAssertEqual(restored, original)
    }

    private func assertNoShaderErrorColor(_ image: UIImage) throws {
        let cg = try XCTUnwrap(image.cgImage)
        var rgba = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let context = try XCTUnwrap(CGContext(data: &rgba, width: cg.width, height: cg.height,
            bitsPerComponent: 8, bytesPerRow: cg.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        let magentaPixels = stride(from: 0, to: rgba.count, by: 4).filter {
            rgba[$0] > 220 && rgba[$0 + 1] < 35 && rgba[$0 + 2] > 220
        }.count
        XCTAssertEqual(magentaPixels, 0, "SceneKit shader compilation fallback must fail visual verification")
    }
}
