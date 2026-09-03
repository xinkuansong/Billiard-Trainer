import SceneKit
import Metal
import XCTest
@testable import QiuJi

@MainActor
final class PocketMarkerHighlightTests: XCTestCase {
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
        let marker = try XCTUnwrap(scene.addPocketMarkers().first)
        let material = try XCTUnwrap(marker.geometry?.materials.first)
        let initialDiffuse = try XCTUnwrap(material.diffuse.contents as AnyObject?)
        let initialEmission = try XCTUnwrap(material.emission.contents as AnyObject?)

        XCTAssertTrue(marker.isHidden)

        scene.setPocketHighlight(marker, style: .selected)
        XCTAssertFalse(marker.isHidden)
        XCTAssertTrue(initialDiffuse === material.diffuse.contents as AnyObject)
        XCTAssertTrue(initialEmission === material.emission.contents as AnyObject)

        scene.setPocketHighlight(marker, style: .viable)
        XCTAssertTrue(marker.isHidden)
        XCTAssertTrue(initialDiffuse === material.diffuse.contents as AnyObject)
        XCTAssertTrue(initialEmission === material.emission.contents as AnyObject)

        scene.setPocketHighlight(marker, style: .infeasible)
        XCTAssertTrue(marker.isHidden)
        XCTAssertTrue(initialDiffuse === material.diffuse.contents as AnyObject)
        XCTAssertTrue(initialEmission === material.emission.contents as AnyObject)
    }
}
