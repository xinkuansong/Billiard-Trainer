import XCTest
import SceneKit
import Metal
@testable import QiuJi

@MainActor
final class ClothAppearanceTests: XCTestCase {
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
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode
        renderer.delegate = scene.contactOcclusion
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
        XCTAssertEqual(snapshot().pngData(), original)
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
