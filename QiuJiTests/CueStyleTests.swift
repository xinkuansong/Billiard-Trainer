import XCTest
import SceneKit
import Metal
@testable import QiuJi

@MainActor
final class CueStyleTests: XCTestCase {
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
            XCTAssertEqual(try worldVertices(nodes), baseline, "Vertex positions changed for \(style)")
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
