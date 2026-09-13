import XCTest
import SceneKit
import Metal
@testable import QiuJi

@MainActor
final class BallStickerTests: XCTestCase {
    private var output: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/ball-stickers-20260913-v2/app-renders")
    }

    func testPreferencePersistenceAndUnknownValue() {
        let name = "BallStickerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(BallStickerStyle.selected(in: defaults), .modern)
        for style in BallStickerStyle.allCases {
            let preferences = UserPreferences(defaults: defaults)
            preferences.ballStickerStyle = style
            XCTAssertEqual(UserPreferences(defaults: defaults).ballStickerStyle, style)
        }
        defaults.set("future-or-corrupted", forKey: BallStickerStyle.preferenceKey)
        XCTAssertEqual(UserPreferences(defaults: defaults).ballStickerStyle, .modern)
    }

    func testEveryPackAndLiveSceneIsolation() throws {
        let scene = AngleTrainingScene(); scene.setupScene()
        let other = AngleTrainingScene(); other.setupScene()
        other.applyBallStickerStyle(.minimal)
        let ball = try XCTUnwrap(scene.allBallNodes["_10"])
        ball.position = SCNVector3(0.25, scene.surfaceY + AngleSceneCalculator.ballRadius, -0.2)
        ball.eulerAngles = SCNVector3(0.3,0.7,0.2); ball.isHidden = false
        let transform = ball.transform
        let cameraTransform = scene.cameraNode.transform
        let cue = try XCTUnwrap(scene.allBallNodes["cueBall"])
        let cueMaterial = try XCTUnwrap(materials(cue).first)
        let cueDiffuse = cueMaterial.diffuse.contents as AnyObject?
        let otherDiffuse = try XCTUnwrap(materials(other.allBallNodes["_10"]!).first?.diffuse.contents as? UIImage)
        let geometry = geometryNodes(ball).map { $0.geometry! }
        let shader = try XCTUnwrap(materials(ball).first).shaderModifiers
        for style in BallStickerStyle.allCases {
            XCTAssertNotNil(BallStickerAppearance.image(named: style.previewName))
            scene.applyBallStickerStyle(style)
            XCTAssertEqual(scene.ballStickerStyle, style)
            for number in 1...15 {
                let expected = try XCTUnwrap(BallStickerAppearance.image(named: style.textureName(number: number)))
                XCTAssertEqual(expected.size, CGSize(width: 1024, height: 512))
                let node = try XCTUnwrap(scene.allBallNodes["_\(number)"])
                XCTAssertFalse(materials(node).isEmpty)
                // NSCache may evict and reload an identical image. Assert actual
                // texture bytes, not an identity that depends on cache pressure.
                for material in materials(node) {
                    let actual = try XCTUnwrap(material.diffuse.contents as? UIImage)
                    XCTAssertEqual(actual.pngData(), expected.pngData(), "\(style.rawValue) / \(number)")
                }
            }
            XCTAssertTrue(SCNMatrix4EqualToMatrix4(ball.transform, transform))
            XCTAssertTrue(SCNMatrix4EqualToMatrix4(scene.cameraNode.transform, cameraTransform))
            XCTAssertFalse(ball.isHidden)
            XCTAssertTrue((cueMaterial.diffuse.contents as AnyObject?) === cueDiffuse)
            XCTAssertTrue((materials(other.allBallNodes["_10"]!).first?.diffuse.contents as? UIImage) === otherDiffuse)
            XCTAssertEqual(materials(ball).first?.shaderModifiers, shader)
            for (a,b) in zip(geometry, geometryNodes(ball).map({ $0.geometry! })) { XCTAssertTrue(a === b) }
        }
    }

    func testSixStylesOnActualSceneKitMeshes() throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        for (pipeline, enhanced, mobile) in [("plain", false, false), ("studio", true, false), ("mobile", false, true)] {
            let scene = AngleTrainingScene(); scene.setupScene(enhancedRendering: enhanced, mobileRendering: mobile)
            let y = scene.surfaceY + AngleSceneCalculator.ballRadius
            scene.applyBallLayout(cueBallPosition: SCNVector3(-0.35,y,0), targetBallNumber: 10, targetPosition: SCNVector3(0.2,y,0))
            scene.setCueBallHomeOrientation(BallSpinIntegrator.identityOrientation)
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene; renderer.pointOfView = scene.cameraNode
            for style in BallStickerStyle.allCases {
                scene.applyBallStickerStyle(style)
                SCNTransaction.flush()
                let shot = renderer.snapshot(atTime: 0, with: CGSize(width: 1000, height: 650), antialiasingMode: .multisampling4X)
                try XCTUnwrap(shot.pngData()).write(to: output.appendingPathComponent("\(pipeline)-\(style.rawValue).png"))
            }
        }
        // Readable close-ups use actual imported mesh UVs, not concept artwork.
        let scene = AngleTrainingScene(); scene.setupScene()
        let framesURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BallStickerUVFrames", withExtension: "json"))
        let frames = try JSONDecoder().decode([String: UVFrame].self, from: Data(contentsOf: framesURL))
        for style in BallStickerStyle.allCases {
            scene.applyBallStickerStyle(style)
            var faces: [UIImage] = []
            for number in [1,6,8,9,10] {
                faces.append(try face(scene.allBallNodes["_\(number)"]!, frame: XCTUnwrap(frames["_\(number)"]), device: device))
            }
            let format = UIGraphicsImageRendererFormat();format.scale = 1
            let strip = UIGraphicsImageRenderer(size: CGSize(width: 1000, height: 220), format: format).image { context in
                UIColor.systemGray5.setFill();context.fill(CGRect(x: 0,y: 0,width: 1000,height: 220))
                for (i, image) in faces.enumerated() {
                    image.draw(in: CGRect(x: i*200,y: 0,width: 190,height: 190))
                }
            }
            try XCTUnwrap(strip.pngData()).write(to: output.appendingPathComponent("closeup-\(style.rawValue).png"))
        }
    }

    func testAllBallsHaveTwoOppositeReadableNumbers() throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let scene = AngleTrainingScene(); scene.setupScene()
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "BallStickerUVFrames", withExtension: "json"))
        let frames = try JSONDecoder().decode([String: UVFrame].self, from: Data(contentsOf: url))
        for style in BallStickerStyle.allCases {
            scene.applyBallStickerStyle(style)
            var review: [UIImage] = []
            for number in 1...15 {
                let ball = try XCTUnwrap(scene.allBallNodes["_\(number)"])
                let frame = try XCTUnwrap(frames["_\(number)"])
                let front = try face(ball, frame: frame, device: device)
                let back = try face(ball, frame: frame, device: device, opposite: true)
                let a = try badgePixels(front), b = try badgePixels(back)
                for pixels in [a, b] {
                    let white = pixels.filter { $0.x > 190 && $0.y > 180 && $0.z > 165 }.count
                    let ink = pixels.filter { max($0.x, max($0.y, $0.z)) < 90 }.count
                    XCTAssertGreaterThan(Double(white) / Double(pixels.count), 0.20, "White badge \(style)/\(number)")
                    XCTAssertGreaterThan(Double(ink) / Double(pixels.count), 0.05, "Number ink \(style)/\(number)")
                }
                // Both cameras share the same up axis. Mirrored or missing back
                // numerals cannot match the central unlit front badge pixels.
                let totalError: Double = zip(a, b).reduce(0.0) { result, pair in
                    let red = abs(Int(pair.0.x) - Int(pair.1.x))
                    let green = abs(Int(pair.0.y) - Int(pair.1.y))
                    let blue = abs(Int(pair.0.z) - Int(pair.1.z))
                    return result + Double(red + green + blue) / (3 * 255)
                }
                let error = totalError / Double(a.count)
                XCTAssertLessThan(error, 0.085, "Antipodal glyph mismatch \(style)/\(number): \(error)")
                if [1,6,8,9,10,15].contains(number) { review += [front,back] }
            }
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let sheet = UIGraphicsImageRenderer(size: CGSize(width: 1140, height: 380), format: format).image { _ in
                for i in 0..<6 {
                    review[i*2].draw(in: CGRect(x: i*190,y: 0,width: 190,height: 190))
                    review[i*2+1].draw(in: CGRect(x: i*190,y: 190,width: 190,height: 190))
                }
            }
            try XCTUnwrap(sheet.pngData()).write(to: output.appendingPathComponent("opposite-\(style.rawValue).png"))
        }
    }

    func testUVRepairPreservesOriginalSurface() throws {
        let original = try XCTUnwrap(TableModelLoader.loadTable())
        let scene = AngleTrainingScene(); scene.setupScene()
        for number in 1...15 {
            let a = geometryNodes(try XCTUnwrap(original.ballNodes["_\(number)"])).compactMap(\.geometry)
            let b = geometryNodes(try XCTUnwrap(scene.allBallNodes["_\(number)"])).compactMap(\.geometry)
            XCTAssertEqual(a.count,b.count)
            for (old,new) in zip(a,b) {
                for semantic in [SCNGeometrySource.Semantic.vertex, .normal] {
                    let before = try XCTUnwrap(old.sources(for: semantic).first)
                    let after = try XCTUnwrap(new.sources(for: semantic).first)
                    XCTAssertEqual(before.data,after.data)
                    XCTAssertEqual(before.vectorCount,after.vectorCount)
                    XCTAssertEqual(before.dataOffset,after.dataOffset)
                    XCTAssertEqual(before.dataStride,after.dataStride)
                }
                XCTAssertEqual(old.elements.count,new.elements.count)
                for (oldElement,newElement) in zip(old.elements,new.elements) {
                    let before = try PocketLeatherMesh.decode(oldElement)
                    let after = try PocketLeatherMesh.decode(newElement)
                    XCTAssertEqual(before.count,after.count)
                    for (oldFace,newFace) in zip(before,after) {
                        let restored = newFace.enumerated().filter {
                            $0.offset % newElement.indicesChannelCount < oldElement.indicesChannelCount
                        }.map(\.element)
                        XCTAssertEqual(oldFace,restored)
                    }
                }
            }
        }
    }

    func testPhotographicResinCandidateInActualLighting() throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        for roughness in [Float(0.34), 0.12] {
            let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
            MobileReferenceLighting.apply(to: scene)
            scene.applyBallStickerStyle(.modern)
            let y = scene.surfaceY + AngleSceneCalculator.ballRadius
            scene.applyBallLayout(cueBallPosition: SCNVector3(-0.35,y,0), targetBallNumber: 10, targetPosition: SCNVector3(0,y,0))
            let ball = try XCTUnwrap(scene.allBallNodes["_10"])
            for material in materials(ball) {
                let shader = try XCTUnwrap(material.shaderModifiers?[.surface])
                XCTAssertTrue(shader.contains("float roughness=0.12;"))
                material.shaderModifiers?[.surface] = shader.replacingOccurrences(of: "float roughness=0.12;", with: "float roughness=\(roughness);")
            }
            let camera = SCNNode(); camera.camera = SCNCamera()
            camera.camera!.usesOrthographicProjection = true; camera.camera!.orthographicScale = 0.043
            camera.camera!.zNear = 0.001; camera.camera!.zFar = 10
            camera.position = SCNVector3(0,y+0.055,0.18)
            camera.look(at: SCNVector3(0,y,0),up: SCNVector3(0,1,0),localFront: SCNVector3(0,0,-1))
            scene.rootNode.addChildNode(camera)
            let renderer = SCNRenderer(device: device,options: nil); renderer.scene = scene;renderer.pointOfView = camera
            let shot = renderer.snapshot(atTime: 0,with: CGSize(width: 600,height: 600),antialiasingMode: .multisampling4X)
            let pixels = try badgePixels(shot)
            XCTAssertEqual(pixels.filter { $0.x > 220 && $0.y < 60 && $0.z > 220 }.count, 0,
                           "SceneKit shader-error magenta must never count as a successful render")
            try XCTUnwrap(shot.pngData()).write(to: output.appendingPathComponent("resin-candidate-\(roughness).png"))
        }
    }

    private func badgePixels(_ image: UIImage) throws -> [SIMD3<UInt8>] {
        let cg = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: 190*190*4)
        try bytes.withUnsafeMutableBytes { raw in
            let context = try XCTUnwrap(CGContext(data: raw.baseAddress, width: 190, height: 190,
                bitsPerComponent: 8, bytesPerRow: 190*4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0,y: 0,width: 190,height: 190))
        }
        return (60..<130).flatMap { y in
            (60..<130).map { x in let i=(y*190+x)*4; return SIMD3(bytes[i],bytes[i+1],bytes[i+2]) }
        }
    }

    private struct UVFrame: Decodable { let front: [Float]; let up: [Float] }
    private func face(_ ball: SCNNode, frame: UVFrame, device: MTLDevice, opposite: Bool = false) throws -> UIImage {
        let clone = ball.clone();clone.isHidden = false;clone.position = SCNVector3Zero
        // A deterministic QA camera faces each ball's original UV badge. This
        // never rotates/reseats the live training balls or changes production UVs.
        let scene = SCNScene();scene.background.contents = UIColor.clear
        scene.rootNode.addChildNode(clone)
        // UV proof uses unlit diffuse so a close-range test light cannot hide
        // the design with specular clipping. Actual page screenshots prove lighting.
        for node in geometryNodes(clone) {
            let geometry = node.geometry!.copy() as! SCNGeometry
            geometry.materials = geometry.materials.map {
                let material = $0.copy() as! SCNMaterial
                material.lightingModel = .constant; material.shaderModifiers = nil
                return material
            }
            node.geometry = geometry
        }
        let mesh = try XCTUnwrap(geometryNodes(clone).first)
        let (lo,hi) = mesh.boundingBox
        let center = mesh.convertPosition(SCNVector3((lo.x+hi.x)/2,(lo.y+hi.y)/2,(lo.z+hi.z)/2), to: nil)
        let r = simd_length(mesh.simdConvertVector(SIMD3<Float>((hi.x-lo.x)/2,0,0), to: nil))
        let front = simd_normalize(mesh.simdConvertVector(SIMD3<Float>(frame.front[0],frame.front[1],frame.front[2]),to: nil)) * (opposite ? -1 : 1)
        let up = simd_normalize(mesh.simdConvertVector(SIMD3<Float>(frame.up[0],frame.up[1],frame.up[2]),to: nil))
        let camera = SCNNode();camera.camera = SCNCamera();camera.camera!.usesOrthographicProjection = true
        camera.camera!.orthographicScale = Double(r)*1.12;camera.camera!.zNear = 0.001
        camera.position = SCNVector3(SIMD3<Float>(center.x,center.y,center.z)+front*r*8)
        camera.look(at: center,up: SCNVector3(up),localFront: SCNVector3(0,0,-1))
        scene.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device: device,options: nil);renderer.scene = scene;renderer.pointOfView = camera
        return renderer.snapshot(atTime: 0,with: CGSize(width: 190,height: 190),antialiasingMode: .multisampling4X)
    }

    private func geometryNodes(_ node: SCNNode) -> [SCNNode] {
        (node.geometry == nil ? [] : [node]) + node.childNodes.flatMap(geometryNodes)
    }
    private func materials(_ node: SCNNode) -> [SCNMaterial] { geometryNodes(node).flatMap { $0.geometry!.materials } }
}
