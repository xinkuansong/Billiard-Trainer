import XCTest
import SceneKit
import Metal
@testable import QiuJi

/// Rendered equivalence checks; simulator timings are not phone performance evidence.
@MainActor
final class Daily3DClothPerformanceTests: XCTestCase {
    /// Exercises the real SCNNode subclass that crashed generic clone() on a hold.
    func testTemporaryTopDownSnapshotCopiesRealPocketMarkersWithoutSourceWrites() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: false)
        scene.installReferenceRoom()
        let markers = scene.addPocketMarkers()
        XCTAssertEqual(markers.count, 6)
        XCTAssertTrue(markers.allSatisfy { $0 is PocketLeatherMarker })
        let table = try XCTUnwrap(scene.tableNode)
        scene.showBall(key: PositionPlayBall.cueKey,
            scenePosition: SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0))
        let cue = try XCTUnwrap(scene.cueBallNode)
        let camera = try XCTUnwrap(scene.cameraNode)
        let originalFOV = camera.camera?.fieldOfView
        let originalProjection = camera.camera?.usesOrthographicProjection

        // Newly attached marker presentation nodes still have identity world matrices
        // until SceneKit evaluates this tree. Exercise the actual rendered fixture before
        // freezing it, just as a long press captures an already displayed live scene.
        let sourceRenderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        sourceRenderer.scene = scene
        sourceRenderer.pointOfView = camera
        sourceRenderer.autoenablesDefaultLighting = false
        SCNTransaction.flush()
        _ = sourceRenderer.snapshot(atTime: 0, with: CGSize(width: 64, height: 64), antialiasingMode: .none)
        for marker in markers {
            let presented = marker.presentation.simdWorldTransform
            let model = marker.simdWorldTransform
            var error: Float = 0
            for column in 0..<4 {
                for row in 0..<4 {
                    XCTAssertTrue(presented[column][row].isFinite && model[column][row].isFinite)
                    error = max(error, abs(presented[column][row] - model[column][row]))
                }
            }
            XCTAssertLessThanOrEqual(error, 1e-5,
                "Rendered static marker fixture must be synchronized: node=\(marker.name ?? "<unnamed>") maxElementDifference=\(error); presented=\(presented); model=\(model)")
        }

        var sourceNodes: [SCNNode] = []
        scene.rootNode.enumerateHierarchy { node, _ in sourceNodes.append(node) }
        let sourceState = sourceNodes.map { node in
            (node.parent, node.transform, node.pivot, node.isHidden, node.opacity,
             node.geometry, node.geometry?.materials ?? [])
        }
        let sourceMaterials = sourceNodes.flatMap { $0.geometry?.materials ?? [] }
        let materialState = sourceMaterials.map { ($0.shaderModifiers, $0.diffuse.contents as? NSObject) }

        let snapshot = scene.makeTemporaryTopDownRenderScene()
        XCTAssertTrue(snapshot !== scene)
        XCTAssertNil(snapshot.rootNode.childNode(withName: "reference_room", recursively: true))
        XCTAssertNil(snapshot.rootNode.childNode(withName: "trainingCamera", recursively: true))
        XCTAssertNil(snapshot.rootNode.childNode(withName: "cueStick", recursively: true))
        XCTAssertNil(snapshot.rootNode.childNode(withName: "ground_visual", recursively: true))
        XCTAssertNil(snapshot.rootNode.childNode(withName: "ground_contact_shadow", recursively: true))
        for marker in markers {
            let copy = try XCTUnwrap(snapshot.rootNode.childNode(withName: try XCTUnwrap(marker.name), recursively: true))
            XCTAssertFalse(copy is PocketLeatherMarker, "Snapshot must use base nodes, not invoke marker initialization")
            XCTAssertTrue(copy !== marker)
            XCTAssertEqual(copy.childNodes.count, marker.childNodes.count)
        }
        var largestWorldElementDifference: Float = 0
        var largestWorldDifferenceNode = "none"
        func checkTree(_ source: SCNNode, _ copy: SCNNode) {
            XCTAssertTrue(copy !== source)
            XCTAssertTrue(type(of: copy) == SCNNode.self)
            if let sourceGeometry = source.geometry {
                guard let copiedGeometry = copy.geometry else { XCTFail("Missing mirrored geometry"); return }
                XCTAssertFalse(copiedGeometry === sourceGeometry, "Independent renderers must own independent mesh caches")
                XCTAssertEqual(copiedGeometry.sources.map(\.data),sourceGeometry.sources.map(\.data))
                XCTAssertEqual(copiedGeometry.elements.map(\.data),sourceGeometry.elements.map(\.data))
                XCTAssertEqual(copiedGeometry.materials,sourceGeometry.materials,"Selection feedback remains live")
            } else { XCTAssertNil(copy.geometry) }
            let actualWorld = copy.simdWorldTransform
            let expectedWorld = source.presentation.simdWorldTransform
            var maximumDifference: Float = 0
            var finiteElements = true
            for column in 0..<4 {
                for row in 0..<4 {
                    let actual = actualWorld[column][row]
                    let expected = expectedWorld[column][row]
                    finiteElements = finiteElements && actual.isFinite && expected.isFinite
                    maximumDifference = max(maximumDifference, abs(actual - expected))
                }
            }
            let nodeName = source.name ?? "<unnamed>"
            if maximumDifference > largestWorldElementDifference {
                largestWorldElementDifference = maximumDifference
                largestWorldDifferenceNode = nodeName
            }
            XCTAssertTrue(finiteElements, "Nonfinite world matrix at node=\(nodeName); actual=\(actualWorld); expected=\(expectedWorld)")
            // Parent multiplication can recompose frozen transforms with Float rounding.
            // This bound applies to each matrix element (translation entries are meters).
            XCTAssertLessThanOrEqual(maximumDifference, 1e-5,
                "node=\(nodeName) maxWorldElementDifference=\(maximumDifference); actual=\(actualWorld); expected=\(expectedWorld)")
            XCTAssertTrue(SCNMatrix4EqualToMatrix4(copy.pivot, source.presentation.pivot))
            XCTAssertEqual(copy.isHidden, source.isHidden)
            XCTAssertEqual(copy.renderingOrder, source.renderingOrder)
            XCTAssertEqual(copy.categoryBitMask, source.categoryBitMask)
            XCTAssertFalse(copy.hasActions)
            XCTAssertTrue(copy.animationKeys.isEmpty)
            XCTAssertNil(copy.physicsBody)
            XCTAssertEqual(copy.childNodes.count, source.childNodes.count)
            for (child, childCopy) in zip(source.childNodes, copy.childNodes) { checkTree(child, childCopy) }
        }
        checkTree(table, try XCTUnwrap(snapshot.rootNode.childNode(withName: try XCTUnwrap(table.name), recursively: false)))
        checkTree(cue, try XCTUnwrap(snapshot.rootNode.childNode(withName: try XCTUnwrap(cue.name), recursively: false)))
        print("TemporaryTopDownClone maxWorldElementDifference=\(largestWorldElementDifference) node=\(largestWorldDifferenceNode)")
        let sourceLightIDs = Set(sourceNodes.compactMap { $0.light }.map(ObjectIdentifier.init))
        var snapshotLights: [SCNLight] = []
        snapshot.rootNode.enumerateHierarchy { node, _ in
            if let light = node.light { snapshotLights.append(light) }
        }
        XCTAssertEqual(snapshotLights.count, sourceNodes.compactMap { $0.light }.count)
        XCTAssertTrue(snapshotLights.allSatisfy { !sourceLightIDs.contains(ObjectIdentifier($0)) })
        for (node, saved) in zip(sourceNodes, sourceState) {
            XCTAssertTrue(node.parent === saved.0)
            XCTAssertTrue(SCNMatrix4EqualToMatrix4(node.transform, saved.1))
            XCTAssertTrue(SCNMatrix4EqualToMatrix4(node.pivot, saved.2))
            XCTAssertEqual(node.isHidden, saved.3)
            XCTAssertEqual(node.opacity, saved.4)
            XCTAssertTrue(node.geometry === saved.5)
            XCTAssertEqual(node.geometry?.materials.map(ObjectIdentifier.init) ?? [], saved.6.map(ObjectIdentifier.init))
        }
        for (material, saved) in zip(sourceMaterials, materialState) {
            XCTAssertEqual(material.shaderModifiers, saved.0)
            XCTAssertEqual(material.diffuse.contents as? NSObject, saved.1)
        }
        XCTAssertEqual(camera.camera?.fieldOfView, originalFOV)
        XCTAssertEqual(camera.camera?.usesOrthographicProjection, originalProjection)
    }

    func testS8IndependentOverlayMeshMatchesNativeImportedGeometryPixels() throws {
        let source = AngleTrainingScene()
        source.configureDailyClearanceRendering(); source.setupScene()
        var pairs: [(SCNNode,SCNNode)] = []
        let overlay = source.makeTemporaryTopDownRenderScene { pairs.append(($0,$1)) }
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.camera!.usesOrthographicProjection = true
        camera.camera!.orthographicScale = 1.5
        camera.position = SCNVector3(0,5.8,0)
        camera.look(at:SCNVector3(0,0.8,0),up:SCNVector3(0,0,-1),localFront:SCNVector3(0,0,-1))
        overlay.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device:try XCTUnwrap(MTLCreateSystemDefaultDevice()),options:nil)
        renderer.scene = overlay; renderer.pointOfView = camera; renderer.autoenablesDefaultLighting = false
        let size = CGSize(width:640,height:320)
        _ = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
        let isolated = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
        // Sequential, single-renderer baseline uses the actual imported geometry. It
        // deliberately avoids the two-renderer sharing that caused the runtime abort.
        for (original,copy) in pairs { copy.geometry = original.geometry }
        SCNTransaction.flush()
        _ = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
        let native = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
        let a = try pixels(isolated), b = try pixels(native)
        XCTAssertEqual(a.count,b.count)
        let error = zip(a,b).reduce(0.0) { $0 + abs(Double($1.0)-Double($1.1)) } / Double(a.count) / 255
        print("S8 imported overlay normalized pixel MAE=\(error)")
        for (name,image) in [("s8-independent-mesh",isolated),("s8-native-mesh-reference",native)] {
            let attachment = XCTAttachment(image:image); attachment.name = name; attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertLessThan(error,0.005,"Mesh isolation must preserve native vertex formats and rendering")
    }

    private var output: URL {
        #if targetEnvironment(simulator)
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/daily-3d-20260927/cloth-visuals")
        #else
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("daily-3d-cloth-visuals")
        #endif
    }

    func testReferenceAndEquivalentClothVisuals() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: output.appendingPathComponent("run").path),
                          "Explicit daily 3D visual diagnostic required")
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering()
        scene.setupScene(mobileRendering: true)
        scene.hideAllBalls()
        let board = BreakSimulator.breakShot(rack: RackLayout.make(.chineseEightBall, seed: 52), power: 8)
        XCTAssertTrue(board.settled)
        XCTAssertGreaterThanOrEqual(board.board.onTable.count, 10)
        for (key, point) in board.board.onTable {
            scene.showBall(key: key, scenePosition: PositionPlayShotSolver.scenePoint(point, surfaceY: scene.surfaceY))
        }
        let size = CGSize(width: 1400, height: 800)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode; renderer.delegate = scene.contactOcclusion
        renderer.autoenablesDefaultLighting = false
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.viewportSize = size
        scene.setCameraMode(.perspective3D, animated: false)
        let reference = MobileReferenceLighting.directShadowShader(ballCount: scene.allBallNodes.count, profile: .reflection)
        var seen = Set<ObjectIdentifier>()
        var materials: [(SCNMaterial, String)] = []
        scene.rootNode.enumerateHierarchy { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "TaiNi" && seen.insert(ObjectIdentifier(material)).inserted {
                if let source = material.shaderModifiers?[.surface] { materials.append((material, source)) }
            }
        }
        XCTAssertFalse(materials.isEmpty)
        for (_, source) in materials { XCTAssertTrue(source.contains(reference), "Reference shader must be the actual installed daily cloth") }
        func install(_ shader: String) {
            for (material, source) in materials {
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = source.replacingOccurrences(of: reference, with: shader)
                material.shaderModifiers = modifiers
            }
        }
        func capture() throws -> (UIImage, [UInt8]) {
            SCNTransaction.flush()
            let image = renderer.snapshot(atTime: 1, with: size, antialiasingMode: .multisampling4X)
            return (image, try pixels(image))
        }
        func warmCapture() throws -> (UIImage, [UInt8]) {
            for _ in 0..<4 { _ = try capture() }
            return try capture()
        }
        var rows: [[String: Any]] = []
        for pose in ["overview", "low-aim", "pocket", "top-down-regression"] {
            if pose == "overview" { XCTAssertTrue(rig.observeWholeTable(yaw: .pi / 2)) }
            else if pose == "low-aim" {
                rig.enterAiming(cueBallPosition: SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0.4),
                                targetDirection: SCNVector3(0, 0, -1), entryZoom: 0.25)
            } else if pose == "pocket" {
                rig.observe(at: SCNVector3(1.2, scene.surfaceY, 0.58))
                rig.handlePinch(scale: 1.8)
            }
            for _ in 0..<180 { rig.update(deltaTime: 1/60) }
            if pose == "top-down-regression" { scene.setCameraMode(.topDown2D, animated: false) }
            install(reference)
            let before = try warmCapture()
            XCTAssertEqual(before.1, try capture().1, "Reference must be stable before comparison")
            if pose == "overview" {
                // A deliberate material change must be observable. Otherwise
                // stale pipelines or blank snapshots could falsely pass every variant.
                install(reference + "\n_surface.emission.rgb=float3(1.0,0.0,0.0);\n")
                let control = try warmCapture()
                XCTAssertNotEqual(before.1, control.1, "The capture must respond to the installed cloth shader")
                try XCTUnwrap(control.0.pngData()).write(to: output.appendingPathComponent("shader-change-control.png"))
                install(reference)
                XCTAssertEqual(before.1, try warmCapture().1, "Reference must recover after the control")
            }
            try XCTUnwrap(before.0.pngData()).write(to: output.appendingPathComponent("\(pose)-reference.png"))
            for (name, merge, factor) in [("merged", true, false), ("factored", false, true), ("combined", true, true)] {
                let candidate = MobileReferenceLighting.directShadowShader(ballCount: scene.allBallNodes.count,
                    profile: .reflection, mergesSupport: merge, factorsBRDF: factor)
                XCTAssertNotEqual(candidate, reference)
                install(candidate)
                let after = try warmCapture()
                var maximum = 0, changed = 0, total = 0
                for index in before.1.indices where index % 4 != 3 {
                    let difference = abs(Int(before.1[index]) - Int(after.1[index]))
                    maximum = max(maximum, difference); total += difference
                    if difference > 0 { changed += 1 }
                }
                rows.append(["pose": pose, "candidate": name, "maximumRGBDifference": maximum,
                             "changedChannels": changed, "meanRGBDifference": Double(total) / Double(Int(size.width * size.height) * 3)])
                try XCTUnwrap(after.0.pngData()).write(to: output.appendingPathComponent("\(pose)-\(name).png"))
                // Algebraically equivalent Float evaluation may cross one 8-bit
                // rounding boundary; larger changes require investigation.
                XCTAssertLessThanOrEqual(maximum, factor ? 1 : 0, "\(pose)/\(name) altered the reference image")
            }
            install(reference)
            XCTAssertEqual(before.1, try warmCapture().1, "Restored reference must match; shader warmup cannot hide drift")
        }
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("comparison.json"))
    }

    private func pixels(_ image: UIImage) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        try bytes.withUnsafeMutableBytes { raw in
            let context = try XCTUnwrap(CGContext(data: raw.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return bytes
    }
}
