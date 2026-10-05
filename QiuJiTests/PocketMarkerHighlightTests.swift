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

    func testS6ImmediateFeedbackRendersInSourceAndResidentOverlay() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/camera-surface-s6-20261005/feedback")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering: true)
        scene.setCameraMode(.perspective3D, animated: false)
        scene.cameraNode.position = SCNVector3(0, 6, 3)
        scene.cameraNode.look(at: SCNVector3(0, scene.surfaceY, 0))
        let ball = scene.addBall(at: SCNVector3(0, scene.surfaceY + 0.029, 0), color: .yellow)
        let marker = try XCTUnwrap(scene.addPocketMarkers().first as? PocketLeatherMarker)
        scene.setPocketHighlight(marker, style: .selected)
        let pulse = try XCTUnwrap(marker.childNode(withName: "leather_selectionPulse", recursively: true))
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let source = SCNRenderer(device: device, options: nil)
        source.scene = scene; source.pointOfView = scene.cameraNode
        var copies: [SCNNode: SCNNode] = [:]
        let overlay = scene.makeTemporaryTopDownRenderScene { copies[$0] = $1 }
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.camera!.usesOrthographicProjection = true; camera.camera!.orthographicScale = 1.7
        camera.position = SCNVector3(0, 8, 0)
        camera.look(at: SCNVector3(0, scene.surfaceY, 0), up: SCNVector3(0,0,-1), localFront: SCNVector3(0,0,-1))
        overlay.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = overlay; renderer.pointOfView = camera
        let ballCopy = try XCTUnwrap(copies[ball])
        let pulseCopy = try XCTUnwrap(copies[pulse])
        let resident = copies
        func frame(_ time: Double) -> [UIImage] {
            let a = source.snapshot(atTime: time, with: CGSize(width:1200,height:800), antialiasingMode:.multisampling4X)
            scene.synchronizeTemporaryTopDownScene(overlay, copies:&copies)
            let b = renderer.snapshot(atTime: time, with: CGSize(width:1200,height:800), antialiasingMode:.multisampling4X)
            return [a,b]
        }
        let before = frame(0)
        let base = ball.scale.x
        TableBallPulse.pulse(ball)
        marker.confirmSelection(delay: 0)
        XCTAssertEqual(pulse.opacity, 1, "Manual pocket feedback begins immediately")
        _ = frame(1)
        let peak = frame(1.18)
        XCTAssertGreaterThan(ball.presentation.scale.x, base * 1.5)
        XCTAssertEqual(ballCopy.scale.x, ball.presentation.scale.x, accuracy:0.001)
        XCTAssertEqual(pulseCopy.opacity, 1)
        XCTAssertFalse(pulseCopy.isHidden)
        let restored = frame(1.7)
        XCTAssertEqual(ballCopy.scale.x, base, accuracy:0.001)
        XCTAssertEqual(pulseCopy.opacity, 0)
        for (id, node) in resident { XCTAssertTrue(copies[id] === node, "Feedback must preserve resident table nodes") }
        for i in 0..<2 {
            let prefix = i == 0 ? "3d" : "overlay"
            for (name, images) in [("before",before),("peak",peak),("restored",restored)] {
                try XCTUnwrap(images[i].pngData()).write(to:directory.appendingPathComponent("\(prefix)-\(name).png"))
            }
            func difference(_ a: UIImage, _ b: UIImage) throws -> Double {
                let ad = try XCTUnwrap(a.cgImage?.dataProvider?.data) as Data
                let bd = try XCTUnwrap(b.cgImage?.dataProvider?.data) as Data
                return Double(zip(ad,bd).reduce(0) { $0 + abs(Int($1.0)-Int($1.1)) }) / Double(ad.count)
            }
            XCTAssertGreaterThan(try difference(before[i],peak[i]),0.01,prefix)
            XCTAssertLessThan(try difference(before[i],restored[i]),0.001,prefix)
        }
        // Prediction overlays can be replaced without replacing the table or camera.
        let transient = SCNNode(geometry:SCNSphere(radius:0.01)); scene.rootNode.addChildNode(transient)
        scene.synchronizeTemporaryTopDownScene(overlay,copies:&copies)
        let transientCopy = try XCTUnwrap(copies[transient])
        transient.removeFromParentNode()
        scene.synchronizeTemporaryTopDownScene(overlay,copies:&copies)
        XCTAssertNil(transientCopy.parent)
        XCTAssertTrue(camera.parent === overlay.rootNode)
        XCTAssertTrue(copies[ball] === ballCopy)
    }

    func testS7BallPulseKeepsBottomOnClothWithoutMovingPhysicalCenter() throws {
        let scene = AngleTrainingScene(); scene.setupScene(mobileRendering:true)
        scene.hideAllBalls()
        let ball = try XCTUnwrap(scene.allBallNodes["_1"])
        ball.isHidden = false
        ball.position = SCNVector3(0,scene.surfaceY+BallPhysics.radius,0)
        let physical = ball.simdPosition, baseScale = ball.simdScale, basePivot = ball.simdPivot
        let renderer = SCNRenderer(device:try XCTUnwrap(MTLCreateSystemDefaultDevice()),options:nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode
        scene.setCameraMode(.perspective3D,animated:false)
        scene.cameraNode.position = SCNVector3(0,1.03,0.6)
        scene.cameraNode.look(at:SCNVector3(0,scene.surfaceY+0.035,0))
        let directory = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/camera-surface-s7-20261005/pulse")
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        func frame(_ t:Double,_ name:String? = nil) throws {
            let image = renderer.snapshot(atTime:t,with:CGSize(width:1000,height:600),antialiasingMode:.multisampling4X)
            if let name { try XCTUnwrap(image.pngData()).write(to:directory.appendingPathComponent(name+".png")) }
        }
        // Native presentation transforms already include pivot (verified against model/presentation
        // translation). Applying inverse(pivot) again would count the visual lift twice.
        func minimumY(_ root:SCNNode, presentation:Bool = true) -> Float {
            var low = Float.infinity
            func visit(_ node:SCNNode,_ parent:simd_float4x4) {
                let model = parent * (presentation ? node.presentation.simdTransform : node.simdTransform)
                for source in node.geometry?.sources(for:.vertex) ?? [] {
                    for i in 0..<source.vectorCount {
                        let v:SIMD3<Float> = source.data.withUnsafeBytes { bytes in
                            let offset = source.dataOffset+i*source.dataStride
                            return SIMD3((0..<3).map { bytes.loadUnaligned(fromByteOffset:offset+$0*source.bytesPerComponent,as:Float.self) })
                        }
                        low = min(low,(model*SIMD4(v,1)).y)
                    }
                }
                for child in node.childNodes { visit(child,model) }
            }
            visit(root,matrix_identity_float4x4)
            return low
        }
        var copies: [SCNNode:SCNNode] = [:]
        let overlay = scene.makeTemporaryTopDownRenderScene { copies[$0] = $1 }
        let visualBall = try XCTUnwrap(copies[ball])
        for (i,rotation) in [SIMD3<Float>(0,0,0),SIMD3(0.4,0.7,1.1)].enumerated() {
            ball.simdEulerAngles = rotation
            let start = Double(i)*3
            try frame(start,"before-\(i)")
            let bottom = minimumY(ball)
            TableBallPulse.pulse(ball)
            try frame(start+0.1)
            try frame(start+0.28,"peak-\(i)")
            print("S7 ball model=\(ball.simdTransform.columns.3) shown=\(ball.presentation.simdTransform.columns.3) pivot=\(ball.simdPivot.columns.3) shownPivot=\(ball.presentation.simdPivot.columns.3) scale=\(ball.simdScale)")
            XCTAssertGreaterThan(ball.scale.x/baseScale.x,1.5)
            XCTAssertEqual(minimumY(ball),bottom,accuracy:0.0003,"Scaled visual ball stays on its original support plane")
            scene.synchronizeTemporaryTopDownScene(overlay,copies:&copies)
            XCTAssertEqual(minimumY(visualBall,presentation:false),bottom,accuracy:0.0003,
                           "Temporary overlay must apply exactly one visual lift")
            XCTAssertEqual(ball.simdPosition,physical,"Feedback cannot change the solver's ball centre")
            try frame(start+0.7,"restored-\(i)")
            XCTAssertEqual(ball.simdScale,baseScale)
            XCTAssertEqual(ball.simdPivot,basePivot)
            TableBallPulse.beginDrag(ball)
            try frame(start+0.8)
            try frame(start+0.9)
            XCTAssertEqual(minimumY(ball),bottom,accuracy:0.0003)
            TableBallPulse.restore(ball)
            XCTAssertEqual(ball.simdScale,baseScale)
            XCTAssertEqual(ball.simdPivot,basePivot)
            XCTAssertEqual(ball.simdPosition,physical)
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
