import XCTest
import SceneKit
import Metal
import UIKit
@testable import QiuJi

/// Research capture using the actual iOS scene. A passing test proves capture
/// validity and restoration, not visual acceptance or a performance improvement.
@MainActor
final class ClothLowDimResearchTests: XCTestCase {
    func testProductionSceneK8FrozenComparison() throws {
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering()
        scene.configureClothSupportExperiment(request: .off)
        scene.setupScene(mobileRendering: true)
        XCTAssertEqual(scene.clothSupportRequest, .off)
        XCTAssertFalse(scene.safeClothSupportState.effective)
        scene.hideAllBalls()
        let board = BreakSimulator.breakShot(rack: RackLayout.make(.chineseEightBall, seed: 52), power: 8)
        XCTAssertTrue(board.settled)
        XCTAssertGreaterThanOrEqual(board.board.onTable.count, 10)
        for (key, point) in board.board.onTable {
            XCTAssertNotNil(scene.allBallNodes[key])
            scene.showBall(key: key, scenePosition: PositionPlayShotSolver.scenePoint(point, surfaceY: scene.surfaceY))
        }
        XCTAssertEqual(Set(scene.allBallNodes.filter { !$0.value.isHidden }.keys), Set(board.board.onTable.keys))
        let reference = MobileReferenceLighting.directShadowShader(ballCount: scene.allBallNodes.count, profile: .reflection)
        let candidate = try groupedSpecular(reference)
        var seen = Set<ObjectIdentifier>()
        var materials: [(SCNMaterial, String)] = []
        scene.rootNode.enumerateHierarchy { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "TaiNi" && seen.insert(ObjectIdentifier(material)).inserted {
                if let source = material.shaderModifiers?[.surface] { materials.append((material, source)) }
            }
        }
        XCTAssertFalse(materials.isEmpty)
        for (material, source) in materials {
            XCTAssertTrue(source.contains(reference), "Installed cloth must contain the actual R baseline")
            XCTAssertEqual(material.normal.intensity, 0.65, accuracy: 0.00001)
        }
        func install(_ shader: String) {
            for (material, source) in materials {
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = source.replacingOccurrences(of: reference, with: shader)
                material.shaderModifiers = modifiers
            }
        }
        defer { install(reference) }
        let size = CGSize(width: 1400, height: 800)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.cameraNode
        renderer.delegate = scene.contactOcclusion
        renderer.autoenablesDefaultLighting = false
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.viewportSize = size
        scene.setCameraMode(.perspective3D, animated: false)
        func capture() throws -> (UIImage, [UInt8]) {
            SCNTransaction.flush()
            let image = renderer.snapshot(atTime: 1, with: size, antialiasingMode: .multisampling4X)
            return (image, try pixels(image))
        }
        func settledCapture() throws -> (UIImage, [UInt8]) {
            for _ in 0..<4 { _ = try capture() }
            return try capture()
        }
        func attach(_ image: UIImage, _ name: String) {
            let item = XCTAttachment(image: image)
            item.name = name
            item.lifetime = .keepAlways
            add(item)
        }
        var rows: [[String: Any]] = []
        for pose in ["overview", "low-aim", "pocket", "top-down-regression"] {
            if pose == "overview" {
                XCTAssertTrue(rig.observeWholeTable(yaw: .pi / 2))
            } else if pose == "low-aim" {
                rig.enterAiming(cueBallPosition: SCNVector3(0, scene.surfaceY + AngleSceneCalculator.ballRadius, 0.4),
                                targetDirection: SCNVector3(0, 0, -1), entryZoom: 0.25)
            } else if pose == "pocket" {
                rig.observe(at: SCNVector3(1.2, scene.surfaceY, 0.58))
                rig.handlePinch(scale: 1.8)
            }
            for _ in 0..<180 { rig.update(deltaTime: 1/60) }
            if pose == "top-down-regression" { scene.setCameraMode(.topDown2D, animated: false) }
            install(reference)
            let before = try settledCapture()
            XCTAssertEqual(before.1, try capture().1, "Frozen reference must be stable")
            attach(before.0, "cloth-lowdim-\(pose)-reference")
            install(reference + "\n_surface.emission.rgb=float3(1,0,0);\n")
            let control = try settledCapture()
            XCTAssertNotEqual(before.1, control.1, "Capture must respond to actual installed shader")
            attach(control.0, "cloth-lowdim-\(pose)-red-control")
            install(candidate)
            let after = try settledCapture()
            attach(after.0, "cloth-lowdim-\(pose)-k8-point")
            var histogram = [Int](repeating: 0, count: 256)
            var maximum = 0, total = 0, changed = 0
            for index in before.1.indices where index % 4 != 3 {
                let difference = abs(Int(before.1[index])-Int(after.1[index]))
                histogram[difference] += 1
                maximum = max(maximum, difference)
                total += difference
                if difference > 0 { changed += 1 }
            }
            rows.append(["pose": pose, "maximumRGBDifference": maximum,
                         "changedChannels": changed, "histogramRGBDifference": histogram,
                         "meanRGBDifference": Double(total)/Double(Int(size.width*size.height)*3)])
            install(reference)
            let restored = try settledCapture()
            attach(restored.0, "cloth-lowdim-\(pose)-restored")
            XCTAssertEqual(before.1, restored.1, "Reference must restore exactly after candidate")
        }
        let data = try JSONSerialization.data(withJSONObject: [
            "scope": "Actual iOS production scene snapshot, not complete SwiftUI page, live present timing, phone heat or user visual acceptance",
            "candidate": "64 transport evaluations retained near shadows; 16 grouped BRDF evaluations; original diffuse and exact halfspace/far fallback; no spatial field",
            "ballCount": board.board.onTable.count, "resolution": [1400, 800], "MSAA": 4, "rows": rows
        ], options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "cloth-lowdim-production-comparison.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Rewrite only the existing generated R core; fail when source anchors drift.
    private func groupedSpecular(_ reference: String) throws -> String {
        func one(_ text: String, _ old: String, _ replacement: String) throws -> String {
            guard text.components(separatedBy: old).count == 2 else {
                throw NSError(domain: "ClothLowDimResearch", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Shader anchor is not unique: \(old)"])
            }
            return text.replacingOccurrences(of: old, with: replacement)
        }
        var core = reference
        let declaration = "float3 E=float3(0.0);float3 unoccludedE=float3(0.0);float3 S=float3(0.0);"
        core = try one(core, declaration, declaration + """

        float3 moments[16];for(int q=0;q<16;q++) moments[q]=float3(0);
        bool momentValid=true;
        for(int ax=0;ax<2;ax++)for(int az=0;az<3;az++) {
          float3 corner=float3(ax==0?-2.54:2.54,3.0,float(az-1)*1.27);
          momentValid=momentValid&&dot(n,corner-p)>=0.0;
        }

        """)
        core = try one(core, "for(int panel=0;panel<2;++panel) {",
                       "bool useMoments=momentValid&&shadowPossible;\nfor(int panel=0;panel<2;++panel) {")
        guard let start = core.range(of: "float nl=max(0.001,dot(n,l));")?.lowerBound,
              let end = core.range(of: "float3 weighted=", range: start..<core.endIndex)?.lowerBound else {
            throw NSError(domain: "ClothLowDimResearch", code: 2)
        }
        let brdf = String(core[start..<end])
        core = try one(core, brdf, "")
        core = try one(core, "unoccludedE+=weighted; E+=weighted*visibility; S+=weighted*visibility*D*G*F/(4.0*nv*nl);", """
        unoccludedE+=weighted; E+=weighted*visibility;
        if(useMoments) {
          int group=panel*8+(ix/2)*2+(iz/2);
          float a=\(MobileReferenceLighting.rig.radiance)/3.14159265*max(0.0,dot(v62EmitterNormal(panel),-l))/r2*cellArea*v62EmitterGain(panel);
          moments[group]+=a*visibility*l;
        } else { \(brdf) S+=weighted*visibility*D*G*F/(4.0*nv*nl); }
        """)
        let corrected = "E=v62PanelDiffuse(p,n)*(E/max(unoccludedE,float3(0.000001)));"
        core = try one(core, corrected, """
        if(useMoments) { for(int g=0;g<16;g++) {
          float3 m=moments[g];float len2=dot(m,m);
          if(len2>0.0) { float3 l=m/sqrt(len2);
            \(brdf)
            S+=float3(1.0,0.985,0.96)*max(0.0,dot(n,m))*D*G*F/(4.0*nv*nl);
          }
        }}
        \(corrected)
        """)
        return core
    }

    private func pixels(_ image: UIImage) throws -> [UInt8] {
        let cg = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width*cg.height*4)
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        try bytes.withUnsafeMutableBytes { raw in
            let context = try XCTUnwrap(CGContext(data: raw.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width*4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        return bytes
    }
}
