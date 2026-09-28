import XCTest
import SceneKit
import Metal
@testable import QiuJi

/// Rendered equivalence checks; simulator timings are not phone performance evidence.
@MainActor
final class Daily3DClothPerformanceTests: XCTestCase {
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
