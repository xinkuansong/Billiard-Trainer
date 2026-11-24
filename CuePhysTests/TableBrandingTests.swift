import XCTest
import SceneKit
import Metal
@testable import CuePhys

@MainActor
final class TableBrandingTests: XCTestCase {
    func testBrandingSurvivesThemesPocketExtractionAndCameraModes() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        let table = try XCTUnwrap(scene.tableNode)
        let root = try XCTUnwrap(table.childNode(withName: TableBranding.nodePrefix + "root", recursively: true))
        XCTAssertEqual(root.childNodes.count, 7)
        XCTAssertEqual(root.childNodes.reduce(0) { $0 + ($1.geometry?.elements.first?.primitiveCount ?? 0) }, 200)
        let markers = scene.addPocketMarkers().compactMap { $0 as? PocketLeatherMarker }
        XCTAssertEqual(markers.count, 6)
        for node in root.childNodes where TableBranding.pocketIndex(of: node) != nil {
            let index = try XCTUnwrap(PocketLeatherMarker.index(of: node))
            let bounds = node.boundingBox
            let center = SCNVector3((bounds.min.x+bounds.max.x)/2, (bounds.min.y+bounds.max.y)/2, (bounds.min.z+bounds.max.z)/2)
            let world = node.convertPosition(center, to: nil)
            let centers = AngleSceneCalculator.pocketPositions(surfaceY: scene.surfaceY)
            let nearest = centers.enumerated().min { a,b in
                hypot(a.element.x-world.x,a.element.z-world.z) < hypot(b.element.x-world.x,b.element.z-world.z)
            }!.offset
            XCTAssertEqual(index, nearest, "Branding must pick the same physical pocket")
        }
        for style in TableStyle.allCases + [.charcoal, .standard] {
            XCTAssertTrue(scene.applyTableStyle(style))
            scene.setCameraMode(.perspective3D, animated: false)
            XCTAssertFalse(root.isHidden)
            XCTAssertEqual(root.childNodes.count, 7, "No accumulation on repeated theme switches")
            scene.setPocketRoles(first: 0, second: 0)
            XCTAssertEqual(markers[0].style, .bothRoles)
            scene.setPocketRoles(first: nil, second: nil)
            XCTAssertEqual(markers[0].style, .original)
            scene.setCameraMode(.topDown2D, animated: false)
            XCTAssertTrue(root.isHidden)
            scene.setCameraMode(.perspective3D, animated: false)
            XCTAssertNil(scene.makeTemporaryTopDownRenderScene().rootNode.childNode(withName: TableBranding.nodePrefix + "root", recursively: true))
        }
    }

    func testRenderApprovedBrandingAcrossAllTableStyles() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        scene.setCameraMode(.perspective3D, animated: false)
        _ = scene.addPocketMarkers()
        let table = try XCTUnwrap(scene.tableNode)
        let source = try XCTUnwrap(table.childNode(withName: "Plane_001", recursively: true))
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode; renderer.delegate = scene.contactOcclusion
        scene.cameraNode.camera?.usesOrthographicProjection = false
        scene.cameraNode.camera?.fieldOfView = 42
        let poses: [(String,SCNVector3,SCNVector3)] = [
            ("whole",SCNVector3(3.6,-2.7,1.05),SCNVector3(0,0,-0.19)),
            ("rail",SCNVector3(-0.65,-1.9,0.40),SCNVector3(-0.65,-0.74,-0.07)),
            ("pocket",SCNVector3(1.95,-1.35,0.82),SCNVector3(1.32,-0.68,-0.04))]
        func capture(_ name: String) throws {
            SCNTransaction.flush()
            let size=CGSize(width:1600,height:1000)
            _ = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
            let im=renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
            XCTAssertEqual(im.cgImage?.width,1600)
            let attachment=XCTAttachment(image:im);attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
        }
        for style in TableStyle.allCases {
            XCTAssertTrue(scene.applyTableStyle(style))
            for (name,eye,target) in poses {
                scene.cameraNode.position=source.convertPosition(eye,to:nil)
                scene.cameraNode.look(at:source.convertPosition(target,to:nil))
                try capture("branding-\(style.rawValue)-\(name)")
            }
        }
        scene.setPocketRoles(first:3,second:3)
        try capture("branding-pocket-both-roles")
        scene.setPocketRoles(first:nil,second:nil)
        try capture("branding-pocket-cleared")
    }
}
