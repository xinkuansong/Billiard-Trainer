import XCTest
import SceneKit
import Metal
@testable import QiuJi

@MainActor
final class CueStyleTests: XCTestCase {
    func testFerruleFinishSurvivesProductionLighting() throws {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: CueStyle.preferenceKey)
        defer { defaults.set(previous, forKey: CueStyle.preferenceKey) }
        defaults.set(CueStyle.inkDragon.rawValue, forKey: CueStyle.preferenceKey)
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: true)
        let cue = try XCTUnwrap(scene.cueStick)
        XCTAssertEqual(cue.style, .inkDragon)
        let ferrule = try XCTUnwrap(geometryNodes(cue.rootNode).flatMap { $0.geometry!.materials }.first { $0.name == "copp" })
        let roughness = try XCTUnwrap(ferrule.roughness.contents as? UIImage,
                                     "Scene setup must preserve the selected ferrule texture")
        MobileReferenceLighting.applySurfaceFinishes(to: scene)
        XCTAssertTrue((ferrule.roughness.contents as? UIImage) === roughness)
        cue.update(cueBallPosition: SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0), aimDirection: SCNVector3(0, 0, -1))
        cue.show()
        // Keep production room, emitters, exposure and material processing;
        // only move the existing camera for a close view of the ferrule.
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        scene.cameraNode.camera?.usesOrthographicProjection = true
        scene.cameraNode.camera?.orthographicScale = 0.025
        scene.cameraNode.position = SCNVector3(0.12, y + 0.18, -0.08)
        scene.cameraNode.look(at: SCNVector3(0, y, 0.040))
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode; renderer.delegate = scene.contactOcclusion
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("output/cue-stickers/app-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for before in [true, false] {
            ferrule.roughness.contents = before ? NSNumber(value: 0.45) : roughness
            SCNTransaction.flush()
            let image = renderer.snapshot(atTime: 0, with: CGSize(width: 1200, height: 700), antialiasingMode: .multisampling4X)
            try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent(before ? "ferrule-room-before.png" : "ferrule-room-after.png"))
        }
    }

    func testFivePerKindAndPersistence() {
        XCTAssertEqual(CueStyle.allCases.filter { $0.kind == .small }.count, 5)
        XCTAssertEqual(CueStyle.allCases.filter { $0.kind == .large }.count, 5)
        let name = "CueStyles.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(CueStyle.selected(in: defaults), .original)
        for style in CueStyle.allCases {
            UserPreferences(defaults: defaults).cueStyle = style
            XCTAssertEqual(UserPreferences(defaults: defaults).cueStyle, style)
        }
        defaults.set("unknown", forKey: CueStyle.preferenceKey)
        XCTAssertEqual(CueStyle.selected(in: defaults), .original)
    }

    func testStylesPreserveOriginalDimensionsPoseAndRestore() throws {
        let model = try XCTUnwrap(TableModelLoader.loadTable()?.cueStickNode)
        let cue = CueStick(modelCueStickNode: model)
        XCTAssertTrue(cue.applyStyle(.original))
        cue.update(cueBallPosition: SCNVector3(0.2,0.8,-0.1), aimDirection: SCNVector3(0.8,0,0.6), pullBack: 0.1, elevation: 0.2)
        cue.show()
        let nodes = geometryNodes(cue.rootNode)
        let originals = nodes.map { $0.geometry! }
        let originalMaterials = originals.flatMap(\.materials)
        let originalColors = originalMaterials.map { String(describing: $0.diffuse.contents) }
        let originalNormals = originalMaterials.map { String(describing: $0.normal.contents) }
        let baseline = try worldVertices(nodes)
        let transforms = nodes.map(\.worldTransform)
        let rootTransform = cue.rootNode.transform
        let oldTip = CuePhysics.tipDiameter
        let oldLength = CueClearance.shaftLength
        for style in CueStyle.allCases where style != .original {
            XCTAssertTrue(cue.applyStyle(style), style.rawValue)
            XCTAssertEqual(cue.style, style)
            XCTAssertEqual(originalMaterials.map { String(describing: $0.diffuse.contents) }, originalColors)
            XCTAssertEqual(originalMaterials.map { String(describing: $0.normal.contents) }, originalNormals)
            XCTAssertNotNil(CueStyleModel.preview(style))
            let tip = try XCTUnwrap(nodes.flatMap { $0.geometry!.materials }.first { $0.name == "PiTou" })
            let tint = try XCTUnwrap(tip.multiply.contents as? UIColor)
            XCTAssertEqual(tint, UIColor.white, "Generated texture must not be tinted twice")
            if style.kind == .small {
                XCTAssertNotNil(tip.diffuse.contents as? UIImage)
                XCTAssertNil(tip.normal.contents)
            } else {
                let sourceTip = try XCTUnwrap(originalMaterials.first { $0.name == "PiTou" })
                XCTAssertEqual(String(describing: tip.diffuse.contents), String(describing: sourceTip.diffuse.contents))
                XCTAssertEqual(String(describing: tip.normal.contents), String(describing: sourceTip.normal.contents))
            }
            let current=try worldVertices(nodes)
            // Original and UV-only USDZ sources differ below one micrometre.
            // Comparing independently rounded strings creates boundary failures
            // after a legitimate pole translation. Compare the quantized points
            // within one unit in each axis, in both directions; keep count exact.
            func covered(_ point:String,by cloud:Set<String>) -> Bool {
                if cloud.contains(point) { return true }
                let p=point.split(separator:",").compactMap { Int($0) }
                guard p.count == 3 else { return false }
                for x in -1...1 { for y in -1...1 { for z in -1...1 {
                    if cloud.contains("\(p[0]+x),\(p[1]+y),\(p[2]+z)") { return true }
                } } }
                return false
            }
            XCTAssertEqual(current.count,baseline.count)
            XCTAssertTrue(current.allSatisfy { covered($0,by:baseline) } && baseline.allSatisfy { covered($0,by:current) },
                "Vertex displacement exceeds 1 micrometre per axis for \(style)")
            for (node, transform) in zip(nodes, transforms) { XCTAssertTrue(SCNMatrix4EqualToMatrix4(node.worldTransform, transform)) }
            XCTAssertTrue(SCNMatrix4EqualToMatrix4(cue.rootNode.transform, rootTransform))
            XCTAssertFalse(cue.rootNode.isHidden)
            XCTAssertEqual(CuePhysics.tipDiameter, oldTip)
            XCTAssertEqual(CueClearance.shaftLength, oldLength)
        }
        XCTAssertTrue(cue.applyStyle(.original))
        for (node, original) in zip(nodes, originals) { XCTAssertTrue(node.geometry === original) }
    }

    func testRenderEveryStyleUsingAppCue() throws {
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("output/cue-stickers/app-renders")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let model = try XCTUnwrap(TableModelLoader.loadTable()?.cueStickNode)
        let cue = CueStick(modelCueStickNode: model)
        cue.update(cueBallPosition: SCNVector3Zero, aimDirection: SCNVector3(0,0,-1));cue.show()
        let scene = SCNScene();scene.rootNode.addChildNode(cue.rootNode)
        scene.background.contents = UIColor(white: 0.22, alpha: 1)
        let camera = SCNNode();camera.camera = SCNCamera();camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 0.19
        camera.position = SCNVector3(0,2,0.76)
        camera.look(at: SCNVector3(0,0,0.76), up: SCNVector3(1,0,0), localFront: SCNVector3(0,0,-1))
        scene.rootNode.addChildNode(camera)
        let ambient = SCNNode();ambient.light = SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity = 250
        scene.rootNode.addChildNode(ambient)
        let light = SCNNode();light.light = SCNLight();light.light?.type = .directional;light.light?.intensity = 600;light.eulerAngles = SCNVector3(-Float.pi / 4, 0, Float.pi / 4)
        scene.rootNode.addChildNode(light)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene;renderer.pointOfView = camera
        var signatures = Set<Data>()
        for style in CueStyle.allCases {
            XCTAssertTrue(cue.applyStyle(style))
            SCNTransaction.flush()
            let image = renderer.snapshot(atTime: 0, with: CGSize(width: 1600,height: 320), antialiasingMode: .multisampling4X)
            if style != .original {
                let pixels = try centerStrip(image)
                let colored = pixels.filter { max($0.x, max($0.y, $0.z)) - min($0.x, min($0.y, $0.z)) > 12 && max($0.x, max($0.y, $0.z)) < 245 }.count
                if style != .circuit {
                    XCTAssertGreaterThan(colored, 40, "Cue finish washed out or missing: \(style)")
                } else {
                    XCTAssertGreaterThan(pixels.filter { max($0.x, max($0.y, $0.z)) < 45 }.count, 200, "Carbon shaft must remain dark")
                }
            }
            let data = try XCTUnwrap(image.pngData());signatures.insert(data)
            try data.write(to: output.appendingPathComponent(style.rawValue + ".png"))
            if style == .inkDragon || style == .original {
                camera.camera?.orthographicScale = 0.015
                camera.position = SCNVector3(0, 2, 0.07)
                camera.look(at: SCNVector3(0, 0, 0.07), up: SCNVector3(1, 0, 0), localFront: SCNVector3(0, 0, -1))
                let closeup = renderer.snapshot(atTime: 0, with: CGSize(width: 1600, height: 480), antialiasingMode: .multisampling4X)
                try XCTUnwrap(closeup.pngData()).write(to: output.appendingPathComponent(style.rawValue + "-tip.png"))
                camera.camera?.orthographicScale = 0.19
                camera.position = SCNVector3(0, 2, 0.76)
                camera.look(at: SCNVector3(0, 0, 0.76), up: SCNVector3(1, 0, 0), localFront: SCNVector3(0, 0, -1))
            }
        }
        XCTAssertEqual(signatures.count, 11, "Every style must produce a different actual rendered cue")
    }

    private func centerStrip(_ image: UIImage) throws -> [SIMD3<Int>] {
        let cg = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: cg.width, height: cg.height,
            bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        return (220..<1380).map { x in
            let offset = ((cg.height / 2) * cg.width + x) * 4
            return SIMD3(Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
        }
    }

    private func geometryNodes(_ root: SCNNode) -> [SCNNode] {
        var result: [SCNNode] = []
        root.enumerateChildNodes { node, _ in if node.geometry != nil { result.append(node) } }
        return result
    }

    private func worldVertices(_ nodes: [SCNNode]) throws -> Set<String> {
        var result = Set<String>()
        for node in nodes {
            let source = try XCTUnwrap(node.geometry?.sources(for: .vertex).first)
            XCTAssertTrue(source.usesFloatComponents);XCTAssertEqual(source.bytesPerComponent,4)
            for index in 0..<source.vectorCount {
                let p = source.data.withUnsafeBytes { raw in
                    let offset = source.dataOffset + index * source.dataStride
                    return SCNVector3(raw.loadUnaligned(fromByteOffset: offset, as: Float.self),raw.loadUnaligned(fromByteOffset: offset+4, as: Float.self),raw.loadUnaligned(fromByteOffset: offset+8, as: Float.self))
                }
                let world = node.convertPosition(p, to: nil)
                // Micrometer grid is much finer than any physics tolerance.
                result.insert("\(Int((world.x*1e6).rounded())),\(Int((world.y*1e6).rounded())),\(Int((world.z*1e6).rounded()))")
            }
        }
        return result
    }
}


/// Actual rendered comparison against the former node-opacity implementation.
@MainActor
final class CueFadeRenderingTests: XCTestCase {
    private var output: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/cue-fade-20260927/final-\(UIDevice.current.systemVersion)")
    }

    private func legacyOpacity(_ cue: CueStick) {
        cue.rootNode.enumerateHierarchy { node, _ in
            for material in node.geometry?.materials ?? [] {
                var modifiers = material.shaderModifiers ?? [:]
                if let source = modifiers[.fragment] {
                    modifiers[.fragment] = source
                        .replacingOccurrences(of: "#pragma arguments\nfloat cueFadeOpacity;\n#pragma transparent\n", with: "")
                        .replacingOccurrences(of: "\n// cueOpacityAnimation\n_output.color *= cueFadeOpacity;\n", with: "")
                    material.shaderModifiers = modifiers
                }
            }
        }
    }

    private func pixels(_ image: UIImage) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try bytes.withUnsafeMutableBytes { raw in
            let context = try XCTUnwrap(CGContext(data: raw.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return bytes
    }

    func testOpaqueAndFadeMatchLegacyAcrossStylesAndCameras() throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var report: [[String: Any]] = []
        for style in [CueStyle.original, .inkDragon, .circuit] {
            for perspective in [false, true] {
                var reference: [[UInt8]] = []
                let label = "\(style.rawValue)-\(perspective ? "3d" : "2d")"
                for legacy in [true, false] {
                    let scene = AngleTrainingScene()
                    scene.setupScene(mobileRendering: true)
                    let cue = try XCTUnwrap(scene.cueStick)
                    XCTAssertTrue(cue.applyStyle(style))
                    // Match the same installed production finish after style selection.
                    MobileReferenceLighting.applySurfaceFinishes(to: scene)
                    cue.prepareOpacityAnimation()
                    if legacy { legacyOpacity(cue) }
                    let point = SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0)
                    cue.update(cueBallPosition: point, aimDirection: SCNVector3(1, 0, 0)); cue.show()
                    scene.setCameraMode(perspective ? .perspective3D : .topDown2D, animated: false)
                    if perspective {
                        scene.cameraRig?.enterAiming(cueBallPosition: point, targetDirection: SCNVector3(1, 0, 0), entryZoom: 0.25)
                        scene.cameraRig?.snapToTarget()
                    }
                    let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
                    renderer.scene = scene; renderer.pointOfView = scene.cameraNode; renderer.delegate = scene.contactOcclusion
                    let size = CGSize(width: 1000, height: 600)
                    for _ in 0..<4 { _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X) }
                    for (index, opacity) in [CGFloat(1), 0.99, 0.5, 0.01, 0].enumerated() {
                        cue.rootNode.isHidden = opacity == 0
                        if legacy { cue.rootNode.opacity = opacity } else { cue.setFadeOpacity(opacity) }
                        SCNTransaction.flush()
                        let start = CACurrentMediaTime()
                        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
                        let elapsed = (CACurrentMediaTime() - start) * 1000
                        let bytes = try pixels(image)
                        try XCTUnwrap(image.pngData()).write(to: output.appendingPathComponent("\(label)-\(legacy ? "before" : "after")-\(index).png"))
                        var row: [String: Any] = ["fixture": label, "legacy": legacy, "opacity": opacity, "snapshotMs": elapsed]
                        if legacy { reference.append(bytes) }
                        else {
                            var changed = 0, sum = 0, maxDifference = 0
                            for pixel in stride(from: 0, to: bytes.count, by: 4) {
                                var pixelChanged = false
                                for channel in 0..<3 {
                                    let d = abs(Int(bytes[pixel + channel]) - Int(reference[index][pixel + channel]))
                                    sum += d; maxDifference = max(maxDifference, d)
                                    if d > 1 { pixelChanged = true }
                                }
                                if pixelChanged { changed += 1 }
                            }
                            let mean = Double(sum) / Double(1000 * 600 * 3)
                            row["changedPixelsAboveOneLevel"] = changed; row["meanRGBDifference"] = mean; row["maxRGBDifference"] = maxDifference
                            // Explicit transparency changes MSAA blending at the cue's
                            // silhouette, even at alpha=1. Require exact untouched
                            // background, and less than one 8-bit level average error
                            // over actual cue pixels (not diluted by the whole frame).
                            var cuePixels = 0, outsideDifference = 0, cueDifference = 0, missingCueDifference = 0
                            for pixel in stride(from: 0, to: bytes.count, by: 4) {
                                let mask = (0..<3).contains { reference[0][pixel + $0] != reference[4][pixel + $0] }
                                for channel in 0..<3 {
                                    let d = abs(Int(bytes[pixel + channel]) - Int(reference[index][pixel + channel]))
                                    if mask {
                                        cueDifference += d
                                        missingCueDifference += abs(Int(reference[0][pixel + channel]) - Int(reference[4][pixel + channel]))
                                    } else { outsideDifference += d }
                                }
                                if mask { cuePixels += 1 }
                            }
                            XCTAssertGreaterThan(cuePixels, 0)
                            XCTAssertEqual(outsideDifference, 0, "Background changed: \(label)")
                            XCTAssertGreaterThan(Double(missingCueDifference) / Double(max(1, cuePixels * 3)), 1,
                                                 "An absent cue must fail this image criterion")
                            let cueMean = Double(cueDifference) / Double(max(1, cuePixels * 3))
                            row["cueMeanRGBDifference"] = cueMean
                            if opacity == 0 { XCTAssertEqual(sum, 0, label) }
                            else { XCTAssertLessThan(cueMean, 1, label) }
                            XCTAssertEqual(cue.rootNode.opacity, 1)
                        }
                        report.append(row)
                    }
                    if !legacy {
                        cue.hide(); cue.show()
                        XCTAssertEqual(cue.fadeOpacity, 1)
                        XCTAssertEqual(cue.rootNode.opacity, 1)
                        XCTAssertFalse(cue.rootNode.isHidden)
                    }
                }
                XCTAssertNotEqual(reference[0], reference[4], "Fixture must actually draw the cue")
            }
        }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("comparison.json"))
    }

    func testFadeActionCompletesAndNextShotRestoresVisibility() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        let cue = try XCTUnwrap(scene.cueStick)
        cue.update(cueBallPosition: SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0), aimDirection: SCNVector3(1, 0, 0))
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode
        let size = CGSize(width: 320, height: 240)
        for shot in 0..<2 {
            cue.show()
            let start = Double(shot) * 2
            _ = renderer.snapshot(atTime: start, with: size, antialiasingMode: .none)
            var completed = false
            cue.fadeOut(duration: 0.2) { completed = true }
            _ = renderer.snapshot(atTime: start + 0.01, with: size, antialiasingMode: .none)
            _ = renderer.snapshot(atTime: start + 0.11, with: size, antialiasingMode: .none)
            XCTAssertGreaterThan(cue.fadeOpacity, 0); XCTAssertLessThan(cue.fadeOpacity, 1)
            XCTAssertEqual(cue.rootNode.opacity, 1)
            _ = renderer.snapshot(atTime: start + 0.4, with: size, antialiasingMode: .none)
            _ = renderer.snapshot(atTime: start + 0.5, with: size, antialiasingMode: .none)
            XCTAssertTrue(completed); XCTAssertTrue(cue.rootNode.isHidden)
            XCTAssertEqual(cue.fadeOpacity, 1)
        }
    }
}
