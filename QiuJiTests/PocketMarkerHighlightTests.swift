import SceneKit
import Metal
import XCTest
@testable import QiuJi

@MainActor
final class PocketMarkerHighlightTests: XCTestCase {
    func testSelectionWaitsOneSecondThenRendersSixTenthsIn2DAnd3D() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/pocket-selection-20261001/rendered")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for mobile in [false, true] {
            for mode: AngleTrainingScene.CameraMode in [.topDown2DRotated, .perspective3D] {
                let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: mobile)
                scene.setCameraMode(mode, animated: false)
                if mode == .perspective3D {
                    // The default player's view crops the two near pockets.
                    // Keep all six in frame so this is a visible-pixel assertion.
                    scene.cameraNode.position = SCNVector3(0, 6, 3)
                    scene.cameraNode.look(at: SCNVector3(0, scene.surfaceY, 0))
                }
                let marker = try XCTUnwrap(scene.addPocketMarkers().first as? PocketLeatherMarker)
                let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
                renderer.scene = scene; renderer.pointOfView = scene.cameraNode
                func frame(_ time: TimeInterval) -> UIImage {
                    renderer.snapshot(atTime: time, with: CGSize(width: 1200, height: 800), antialiasingMode: .multisampling4X)
                }
                let before = frame(0)
                scene.highlightPocket(marker, highlighted: true)
                _ = frame(1)
                let waiting = frame(1.99)
                let peak = frame(2.12)
                let stillYellow = frame(2.59)
                let restored = frame(2.61)
                let prefix = "\(mobile ? "mobile" : "plain")-\(mode == .perspective3D ? "3d" : "2d")"
                for (name, image) in [("before", before), ("waiting", waiting), ("peak", peak), ("restored", restored)] {
                    try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("\(prefix)-\(name).png"))
                }
                func difference(_ a: UIImage, _ b: UIImage) throws -> Double {
                    let ad = try XCTUnwrap(a.cgImage?.dataProvider?.data) as Data
                    let bd = try XCTUnwrap(b.cgImage?.dataProvider?.data) as Data
                    XCTAssertEqual(ad.count, bd.count)
                    return Double(zip(ad, bd).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }) / Double(ad.count)
                }
                XCTAssertLessThan(try difference(before, waiting), 0.001, "Must wait a full second: " + prefix)
                XCTAssertGreaterThan(try difference(before, peak), 0.001, prefix)
                XCTAssertGreaterThan(try difference(before, stillYellow), 0.001, prefix)
                XCTAssertLessThan(try difference(before, restored), 0.001, prefix)
                let pulse = try XCTUnwrap(marker.childNode(withName: "leather_selectionPulse", recursively: true))
                XCTAssertEqual(pulse.opacity, 0, accuracy: 0.001)
                XCTAssertFalse(pulse.hasActions)
                XCTAssertEqual(marker.style, .target, "The feedback ending must not clear the target")
                scene.highlightPocket(marker, highlighted: false)
                scene.highlightPocket(marker, highlighted: true)
                XCTAssertNotNil(pulse.action(forKey: "pocketSelectionPulse"))
                scene.clearPocketHighlights()
                XCTAssertFalse(pulse.hasActions)
                XCTAssertEqual(pulse.opacity, 0)
            }
        }
    }

    func testLoadedTableRendersOneFrameWithoutNullMeshElement() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        scene.setCameraMode(.topDown2DRotated, animated: false)
        var geometryCount = 0
        var elementCount = 0
        var invalid: [String] = []

        scene.rootNode.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            geometryCount += 1
            let label = node.name ?? "<unnamed>"
            if geometry.sources.isEmpty || geometry.elements.isEmpty {
                invalid.append("\(label): sources=\(geometry.sources.count) elements=\(geometry.elements.count)")
            }
            for (index, element) in geometry.elements.enumerated() {
                elementCount += 1
                if element.primitiveCount == 0 || element.data.isEmpty {
                    invalid.append(
                        "\(label)[\(index)]: type=\(element.primitiveType.rawValue) "
                        + "primitives=\(element.primitiveCount) bytes=\(element.data.count)"
                    )
                }
            }
        }

        XCTAssertGreaterThan(geometryCount, 0)
        XCTAssertGreaterThan(elementCount, 0)
        XCTAssertTrue(invalid.isEmpty, invalid.joined(separator: "\n"))

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        let image = try XCTUnwrap(
            renderer.snapshot(
                atTime: 0,
                with: CGSize(width: 320, height: 480),
                antialiasingMode: .multisampling4X
            )
        )
        XCTAssertEqual(image.size, CGSize(width: 320, height: 480))
    }

    func testHighlightVisibilityChangesWithoutMutatingLiveMaterial() throws {
        let scene = AngleTrainingScene()
        scene.setupScene()
        let marker = try XCTUnwrap(scene.addPocketMarkers().first as? PocketLeatherMarker)
        let selectedNode = try XCTUnwrap(marker.childNodes.first { $0.name == "leather_target" })
        let material = try XCTUnwrap(selectedNode.geometry?.materials.first)
        let initialDiffuse = try XCTUnwrap(material.diffuse.contents as AnyObject?)
        let initialEmission = try XCTUnwrap(material.emission.contents as AnyObject?)
        // v60: original leather stays visible. Only the selected variant hides.
        XCTAssertTrue(selectedNode.isHidden)
        for style: AngleTrainingScene.PocketHighlight in [.selected, .viable, .infeasible, .selected] {
            scene.setPocketHighlight(marker, style: style)
            XCTAssertEqual(selectedNode.isHidden, style != .selected)
            XCTAssertEqual(marker.childNodes.filter { !$0.isHidden }.count, 1)
            XCTAssertTrue(initialDiffuse === material.diffuse.contents as AnyObject)
            XCTAssertTrue(initialEmission === material.emission.contents as AnyObject)
        }
    }
}
