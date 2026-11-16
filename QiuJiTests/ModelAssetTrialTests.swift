import XCTest
import SceneKit
import CryptoKit
import Metal
@testable import QiuJi

final class ModelAssetTrialTests: XCTestCase {
    private let assets: [(name: String, folder: String?, candidateSHA: String, triangles: Int)] = [
        ("TaiQiuZhuo", nil, "73e43df002f07637656b767fdc105033d10f0d764f6d91aa7a5276cf1c885fb6", 330969),
        ("CueUV", "CueStyles", "9288907e666d897e4f3be5b94e7ec989eb5a75116f74a07d3790e4340f2e117e", 10110)
    ]

    private func sha(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }

    func testBundleContainsOnlyProductionModels() throws {
        for asset in assets {
            let candidate = try XCTUnwrap(ModelAssetTrial.url(asset.name, subdirectory: asset.folder))
            XCTAssertEqual(try sha(candidate), asset.candidateSHA, asset.name)
            XCTAssertNil(Bundle.main.url(forResource: asset.name, withExtension: "usdz", subdirectory: asset.folder))
        }
    }

    func testRetiredPreferenceCannotSelectAnUnpackagedModel() throws {
        let key = "modelAssetTrialUseOriginal"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults.standard.set(true, forKey: key)
        for asset in assets {
            let url = try XCTUnwrap(ModelAssetTrial.url(asset.name, subdirectory: asset.folder))
            XCTAssertEqual(try sha(url), asset.candidateSHA)
        }
    }

    func testMissingProductionModelDoesNotFallBackToLegacyFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: root) }
            catch { XCTFail("Cannot remove test bundle: \(error)") }
        }
        let info = ["CFBundleIdentifier": "com.cuephys.tests.legacy-model", "CFBundlePackageType": "BNDL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: root.appendingPathComponent("Info.plist"))
        try Data([0]).write(to: root.appendingPathComponent("TaiQiuZhuo.usdz"))
        let bundle = try XCTUnwrap(Bundle(url: root))
        XCTAssertNotNil(bundle.url(forResource: "TaiQiuZhuo", withExtension: "usdz"))
        XCTAssertNil(ModelAssetTrial.url("TaiQiuZhuo", bundle: bundle))
    }

    // The protected original table/cue surfaces retain USD polygons.
    // Count their actual triangulated faces, as in the source asset audit.
    private func triangleCount(_ element: SCNGeometryElement) -> Int {
        switch element.primitiveType {
        case .triangles, .triangleStrip: return element.primitiveCount
        case .polygon:
            return element.data.withUnsafeBytes { raw in
                (0..<element.primitiveCount).reduce(0) { sum, index in
                    let offset = index * element.bytesPerIndex
                    let vertices: Int
                    switch element.bytesPerIndex {
                    case 1: vertices = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt8.self))
                    case 2: vertices = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                    case 4: vertices = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
                    default: XCTFail("Unsupported polygon index size"); return sum
                    }
                    XCTAssertGreaterThanOrEqual(vertices, 3)
                    return sum + vertices - 2
                }
            }
        default: XCTFail("Unexpected non-surface primitive"); return 0
        }
    }

    func testCandidateImportsWithExpectedGeometry() throws {
        for asset in assets {
            let url = try XCTUnwrap(ModelAssetTrial.url(asset.name, subdirectory: asset.folder))
            let scene = try SCNScene(url: url, options: [.checkConsistency: true])
            var triangles = 0
            scene.rootNode.enumerateChildNodes { node, _ in
                for element in node.geometry?.elements ?? [] {
                    triangles += triangleCount(element)
                }
            }
            XCTAssertEqual(triangles, asset.triangles, asset.name)
        }
    }

    @MainActor
    func testEveryProductionBallHas2880TrianglesAndRenders() throws {
        TableModelLoader.resetCache()
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: true)
        let keys = ["cueBall"] + (1...15).map { "_\($0)" }
        XCTAssertEqual(scene.allBallNodes.count, 16)
        for (index, key) in keys.enumerated() {
            let ball = try XCTUnwrap(scene.allBallNodes[key])
            var triangles = ball.geometry?.elements.reduce(0) { $0 + triangleCount($1) } ?? 0
            ball.enumerateChildNodes { node, _ in
                triangles += node.geometry?.elements.reduce(0) { $0 + self.triangleCount($1) } ?? 0
            }
            XCTAssertEqual(triangles, 2880, key)
            scene.showBall(key: key, scenePosition: SCNVector3(
                Float(index % 4) * 0.09 - 0.135,
                scene.surfaceY + AngleSceneCalculator.ballRadius,
                Float(index / 4) * 0.09 - 0.135))
        }
        scene.cueStick?.rootNode.isHidden = true
        scene.rootNode.childNode(withName: "reference_room", recursively: false)?.isHidden = true
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.delegate = scene.contactOcclusion
        scene.cameraNode.camera?.usesOrthographicProjection = true
        scene.cameraNode.camera?.orthographicScale = 0.27
        for (name, direction) in [("front", Float(1)), ("back", Float(-1))] {
            scene.cameraNode.position = SCNVector3(0, scene.surfaceY + 0.7, direction * 0.35)
            scene.cameraNode.look(at: SCNVector3(0, scene.surfaceY, 0),
                up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 0, -1))
            SCNTransaction.flush()
            _ = renderer.snapshot(atTime: 0, with: CGSize(width: 1000, height: 1000), antialiasingMode: .multisampling4X)
            let image = renderer.snapshot(atTime: 0, with: CGSize(width: 1000, height: 1000), antialiasingMode: .multisampling4X)
            XCTAssertEqual(image.cgImage?.width, 1000)
            let attachment = XCTAttachment(image: image)
            attachment.name = "balls-2880-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
