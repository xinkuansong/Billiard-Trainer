import XCTest
import SceneKit
import Metal
import MetalKit
@testable import QiuJi

/// Deterministic visual experiments, not a phone performance benchmark.
@MainActor
final class RenderQualityV62Tests: XCTestCase {
    private var directory: URL {
        if let path = ProcessInfo.processInfo.environment["V62_SHOT_DIR"] {
            if path == "device" { return FileManager.default.temporaryDirectory.appendingPathComponent("render-quality-v62") }
            return URL(fileURLWithPath: path)
        }
        #if targetEnvironment(simulator)
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/render-quality-v62")
        #else
        return FileManager.default.temporaryDirectory.appendingPathComponent("render-quality-v62")
        #endif
    }

    private func scene(mobile: Bool = false) throws -> AngleTrainingScene {
        let scene = AngleTrainingScene()
        scene.setupScene(mobileRendering: mobile)
        let y = scene.surfaceY + AngleSceneCalculator.ballRadius
        scene.applyBallLayout(cueBallPosition: SCNVector3(-0.45,y,0), targetBallNumber: 3,
                              targetPosition: SCNVector3(0.35,y,0.12))
        scene.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)))
        scene.setCameraMode(.perspective3D, animated: false)
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.enterAiming(cueBallPosition: SCNVector3(-0.45,y,0), targetDirection: SCNVector3(0.8,0,0.12))
        for _ in 0..<120 { rig.update(deltaTime: 1/60) }
        return scene
    }

    private func materials(_ scene: AngleTrainingScene, body: (SCNMaterial) -> Void) {
        for node in scene.allBallNodes.values {
            node.enumerateChildNodes { n,_ in n.geometry?.materials.forEach(body) }
            node.geometry?.materials.forEach(body)
        }
    }

    private func capture(_ scene: AngleTrainingScene, name: String, antialiasing: SCNAntialiasingMode = .multisampling4X, size: CGSize = CGSize(width: 1176, height: 2000)) throws {
        guard ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil else { return }
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = scene; renderer.pointOfView = scene.cameraNode
        renderer.delegate = scene.contactOcclusion
        renderer.autoenablesDefaultLighting = false
        _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: antialiasing)
        let shot = renderer.snapshot(atTime: 0, with: size, antialiasingMode: antialiasing)
        let dest = directory.appendingPathComponent(name + ".png")
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try XCTUnwrap(shot.pngData()).write(to: dest)
        let a = XCTAttachment(image: shot); a.name=name; a.lifetime = .keepAlways;add(a)
    }

    func testContactGeometryAudit() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let s = try scene(mobile: true)
        var rows: [[String: Any]] = []
        s.rootNode.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry,
                  let source = geometry.sources(for: .vertex).first,
                  source.usesFloatComponents, source.bytesPerComponent == 4 else { return }
            let names = geometry.materials.compactMap(\.name)
            guard names.contains("TaiNi") || names.contains(where: { $0.hasPrefix("Lime__") }) ||
                    node.parent?.parent?.parent?.name == "cueBall" ||
                    node.parent?.parent?.name == "cueBall" else { return }
            var low = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var high = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            var heights: [String: Int] = [:]
            let sourceIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }) ?? 0
            let vertexChannel = geometry.geometrySourceChannels?[sourceIndex].intValue ?? 0
            var indices = Set(0..<source.vectorCount)
            if names.contains("TaiNi") {
                indices.removeAll()
                for (index, element) in geometry.elements.enumerated() where names[index % names.count] == "TaiNi" {
                    do {
                        let faces = try PocketLeatherMesh.decode(element)
                        var flatFaces: [[[Float]]] = []
                        for face in faces {
                            let points: [SCNVector3] = stride(from: vertexChannel, to: face.count, by: element.indicesChannelCount).map { offset in
                                let i = Int(face[offset])
                                return source.data.withUnsafeBytes { bytes in
                                    let start = source.dataOffset + i * source.dataStride
                                    return node.convertPosition(SCNVector3(bytes.loadUnaligned(fromByteOffset:start,as:Float.self),
                                        bytes.loadUnaligned(fromByteOffset:start+4,as:Float.self),
                                        bytes.loadUnaligned(fromByteOffset:start+8,as:Float.self)), to:s.rootNode)
                                }
                            }
                            let ys = points.map(\.y)
                            if let lowY=ys.min(), let highY=ys.max(), highY-lowY < 0.00001, highY > 0.79, highY < 0.801 {
                                flatFaces.append(points.map { [$0.x,$0.y,$0.z] })
                            }
                        }
                        rows.append(["flatClothFaces":flatFaces,"vertexChannel":vertexChannel])
                        for face in faces {
                            for offset in stride(from: vertexChannel, to: face.count, by: element.indicesChannelCount) {
                                indices.insert(Int(face[offset]))
                            }
                        }
                    } catch { XCTFail("Cannot decode cloth mesh: \(error)") }

                }
            }
            source.data.withUnsafeBytes { bytes in
                for i in indices {
                    let start = source.dataOffset + i * source.dataStride
                    let v = SCNVector3(bytes.loadUnaligned(fromByteOffset: start, as: Float.self),
                                       bytes.loadUnaligned(fromByteOffset: start+4, as: Float.self),
                                       bytes.loadUnaligned(fromByteOffset: start+8, as: Float.self))
                    let w = node.convertPosition(v, to: s.rootNode)
                    low = simd_min(low, SIMD3(w.x,w.y,w.z)); high = simd_max(high, SIMD3(w.x,w.y,w.z))
                    heights[String(format: "%.5f",w.y), default: 0] += 1
                }
            }
            rows.append(["node":node.name ?? "", "materials":names,
                         "min":[low.x,low.y,low.z],"max":[high.x,high.y,high.z], "yHistogram":heights])
        }
        s.rootNode.enumerateChildNodes { node, _ in
            guard let light = node.light, light.castsShadow else { return }
            rows.append(["shadowMode":light.shadowMode.rawValue,"orthographicScale":light.orthographicScale,
                         "zNear":light.zNear,"zFar":light.zFar,"autoProjection":light.automaticallyAdjustsShadowProjection,
                         "bias":light.shadowBias,"surfaceY":s.surfaceY])
        }
        for point in [SIMD2<Float>(0,0), SIMD2<Float>(0.8,0.3), SIMD2<Float>(-0.8,-0.3)] {
            let hits = s.rootNode.hitTestWithSegment(from: SCNVector3(point.x,1.2,point.y),
                                                     to: SCNVector3(point.x,0.5,point.y),
                                                     options: [SCNHitTestOption.searchMode.rawValue:SCNHitTestSearchMode.all.rawValue,
                                                               SCNHitTestOption.backFaceCulling.rawValue:false, SCNHitTestOption.ignoreHiddenNodes.rawValue:true])
            rows.append(["probe":[point.x,point.y],"hits":hits.map { hit -> [String:Any] in
                let m = hit.node.geometry?.materials ?? []
                return ["y":hit.worldCoordinates.y, "material":m.isEmpty ? "" : m[hit.geometryIndex % m.count].name ?? ""]
            }])
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys])
            .write(to:directory.appendingPathComponent("geometry-audit.json"))
        XCTAssertFalse(rows.isEmpty)
    }

    /// A pipeline compilation failure can leave transforms and UI tests green.
    /// This fixed fixture must actually render a substantial green cloth region.
    func testCandidateClothRenders() throws {
        let s = try scene(mobile: true)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = s; renderer.pointOfView = s.cameraNode
        renderer.delegate = s.contactOcclusion
        renderer.autoenablesDefaultLighting = false
        let size = CGSize(width: 294, height: 500)
        _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        let shot = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        let cg = try XCTUnwrap(shot.cgImage)
        var pixels = [UInt8](repeating: 0, count: 294 * 500 * 4)
        let greenPixels = try pixels.withUnsafeMutableBytes { bytes -> Int in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 294, height: 500,
                bitsPerComponent: 8, bytesPerRow: 294 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(origin: .zero, size: size))
            var green = 0
            for i in stride(from: 0, to: bytes.count, by: 4) {
                let r = Int(bytes[i]), g = Int(bytes[i+1]), b = Int(bytes[i+2])
                if g > 25 && g * 10 > r * 13 && g * 10 > b * 11 { green += 1 }
            }
            return green
        }
        XCTAssertGreaterThan(Double(greenPixels) / Double(294 * 500), 0.30,
            "Candidate cloth did not render; inspect SceneKit pipeline compilation logs")
    }

    func testCandidateIsolationCameraAndAsset() throws {
        XCTAssertNotNil(MobileTableRendering.environmentURL)
        XCTAssertNotNil(MobileTableRendering.railOcclusion)
        let baseline = try scene()
        let candidate = try scene(mobile: true)
        let later = try scene()
        func hasPocketShader(_ scene: AngleTrainingScene) -> Bool {
            var found = false
            scene.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] {
                    if material.shaderModifiers?[.surface]?.contains("pocketVolume") == true { found = true }
                }
            }
            return found
        }
        XCTAssertFalse(hasPocketShader(baseline))
        XCTAssertTrue(hasPocketShader(candidate))
        XCTAssertFalse(hasPocketShader(later))
        func hasInlayShader(_ scene: AngleTrainingScene) -> Bool {
            var found = false
            scene.tableNode?.enumerateChildNodes { node, _ in
                found = found || (node.geometry?.materials.contains { $0.shaderModifiers?[.surface]?.contains("inlayY") == true } ?? false)
            }
            return found
        }
        XCTAssertFalse(hasInlayShader(baseline))
        XCTAssertTrue(hasInlayShader(candidate))
        XCTAssertFalse(hasInlayShader(later))
        XCTAssertTrue(MobilePocketOcclusion.isAvailable)
        XCTAssertTrue(candidate.mobileRendering)
        XCTAssertNotNil(candidate.contactOcclusion)
        XCTAssertNil(baseline.contactOcclusion)
        XCTAssertNil(later.contactOcclusion)
        XCTAssertFalse(later.mobileRendering)
        XCTAssertNil(later.lightingEnvironment.contents)
        XCTAssertTrue(SCNMatrix4EqualToMatrix4(baseline.cameraNode.transform,candidate.cameraNode.transform))
        XCTAssertEqual(baseline.cameraNode.camera?.fieldOfView,candidate.cameraNode.camera?.fieldOfView)
        XCTAssertEqual(baseline.cameraNode.camera?.exposureOffset,candidate.cameraNode.camera?.exposureOffset)
        XCTAssertEqual(baseline.background.contents as? UIColor,candidate.background.contents as? UIColor)
        for key in baseline.allBallNodes.keys {
            let a = try XCTUnwrap(baseline.allBallNodes[key])
            let b = try XCTUnwrap(candidate.allBallNodes[key])
            XCTAssertTrue(SCNMatrix4EqualToMatrix4(a.transform,b.transform),key)
            if let m=a.geometry?.firstMaterial,let n=b.geometry?.firstMaterial { XCTAssertFalse(m === n) }
        }
        try capture(baseline,name:"candidate/baseline")
        try capture(candidate,name:"candidate/mobile")
        let markers=candidate.addPocketMarkers().compactMap { $0 as? PocketLeatherMarker }
        XCTAssertEqual(markers.count,6)
        candidate.setPocketHighlight(markers[3],style:.selected)
        XCTAssertEqual(markers.filter { $0.style == .target }.map(\.pocketIndex),[3])
        candidate.clearPocketHighlights()
        XCTAssertTrue(markers.allSatisfy { $0.style == .original })
    }

    func testBedContactVisualAblation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        // Measurement from S6-flatfaces/bed-proof.json, five independent points.
        // Diagnostic only: no production mesh, ball position or physics change.
        let measuredBedY: Float = 0.7947376370429993
        for variant in 0..<3 {
            let s = try scene(mobile: true)
            if variant >= 1 {
                let worldLift = s.surfaceY - measuredBedY
                s.tableNode?.enumerateChildNodes { node, _ in
                    let lift = node.convertVector(SCNVector3(0, worldLift, 0), from: s.rootNode)
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        material.shaderModifiers = [.geometry:"""
                        #pragma body
                        float4 bedWorld = scn_node.modelTransform * _geometry.position;
                        if (abs(bedWorld.y - \(measuredBedY)) < 0.00001) {
                            _geometry.position.xyz += float3(\(lift.x), \(lift.y), \(lift.z));
                        }
                        """]
                    }
                }
            }
            if variant == 2 {
                s.rootNode.enumerateChildNodes { node, _ in
                    guard let light = node.light, light.castsShadow else { return }
                    light.shadowMapSize = CGSize(width: 2048, height: 2048)
                }
            }
            try capture(s, name: "bed/B\(variant)")
        }
    }

    func testLightTransportAblation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in 0..<3 {
            let s = try scene(mobile: true)
            let y=s.surfaceY+AngleSceneCalculator.ballRadius
            for (i,number) in [1,3,6,8,9,14].enumerated() {
                let ball=try XCTUnwrap(s.allBallNodes["_\(number)"])
                ball.isHidden=false
                ball.position=SCNVector3(Float(i/3)*0.4+0.15,y,Float(i%3)*0.22-0.22)
            }
            s.cameraRig?.handleObservationPinch(scale:0.5)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
            if variant >= 1 {
                s.rootNode.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] { m.ambientOcclusion.contents = 1.0 }
                }
            }
            if variant == 2 {
                s.rootNode.enumerateChildNodes { node, _ in
                    if node.light?.type == .ambient { node.light?.intensity = 0 }
                }
            }
            try capture(s, name:"transport/T\(variant)")
        }
    }

    func testHemisphereLighting() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        guard ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil else {
            throw XCTSkip("Explicit visual experiment; generate S9-bounce/bounce.hdr before selecting this test")
        }
        let source = URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("output/render-quality-v62/S9-bounce/bounce.hdr")
        XCTAssertTrue(FileManager.default.fileExists(atPath:source.path))
        for (variant,ambient) in [CGFloat(0),30,120].enumerated() {
            let s = try scene(mobile:true)
            s.lightingEnvironment.contents = source
            s.rootNode.enumerateChildNodes { n,_ in
                if n.light?.type == .ambient { n.light?.intensity = ambient }
            }
            let y=s.surfaceY+AngleSceneCalculator.ballRadius
            for (i,number) in [1,3,6,8,9,14].enumerated() {
                let ball=try XCTUnwrap(s.allBallNodes["_\(number)"])
                ball.isHidden=false
                ball.position=SCNVector3(Float(i/3)*0.4+0.15,y,Float(i%3)*0.22-0.22)
            }
            // Same normal observation pose as S8.
            s.cameraRig?.handleObservationPinch(scale:0.5)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
            try capture(s,name:"bounce/H\(variant)")
        }
    }

    func testShadowProjectionCoverage() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in 0..<3 {
            let s = try scene(mobile:true)
            if variant >= 1 {
                s.rootNode.enumerateChildNodes { node, _ in
                    guard let light = node.light, light.castsShadow else { return }
                    // The measured table fits a 1.61m sphere about the bed center.
                    // Preserve direction; give a fixed 4m-wide shadow projection.
                    node.simdPosition = SIMD3<Float>(0,s.surfaceY,0) - node.simdWorldFront * 3
                    light.automaticallyAdjustsShadowProjection = false
                    light.orthographicScale = 2
                    light.zNear = 0.5
                    light.zFar = 6
                    light.shadowMapSize = CGSize(width:variant == 1 ? 1024 : 2048,
                                                 height:variant == 1 ? 1024 : 2048)
                }
            }
            try capture(s,name:"projection/P\(variant)")
        }
    }

    func testWoodGrainContrast() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (variant,weight) in [Float(1),0.5,0.25].enumerated() {
            let s = try scene(mobile:true)
            if variant > 0 {
                s.tableNode?.enumerateChildNodes { n,_ in
                    for material in n.geometry?.materials ?? [] where ["Wood","BlackWood"].contains(material.name ?? "") {
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = """
                        #pragma body
                        _surface.diffuse.rgb = mix(float3(0.045,0.023,0.012), _surface.diffuse.rgb, \(weight));
                        """
                        material.shaderModifiers = modifiers
                    }
                }
            }
            try capture(s,name:"wood/W\(variant)")
        }
    }

    func testWoodVarnish() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in 0..<3 {
            let s = try scene(mobile:true)
            s.tableNode?.enumerateChildNodes { n,_ in
                for m in n.geometry?.materials ?? [] where ["Wood","BlackWood"].contains(m.name ?? "") {
                    m.roughness.contents = variant == 2 ? Float(0.35) : Float(0.24)
                    if variant >= 1 {
                        m.shaderModifiers = [.surface:"""
                        #pragma body
                        _surface.diffuse.rgb = mix(float3(0.045,0.023,0.012), _surface.diffuse.rgb, 0.5);
                        """]
                    }
                }
            }
            try capture(s,name:"varnish/V\(variant)")
        }
    }

    /// Exercise the real analytical replay and SCNAction lifecycle at 60 time samples/s.
    /// Encoded image sequences are visual evidence only, not measured presentation fps.
    func testOffsetKeyPlaybackComparison() throws {
        try realPlaybackVisualSequence(contactPrototype: false, baselineLighting: true, outputPrefix: "baseline/")
        try realPlaybackVisualSequence(contactPrototype: false, outputPrefix: "offset/")
    }

    func testSixPocketCloseupReplay() throws {
        for index in 0..<6 {
            try realPlaybackVisualSequence(contactPrototype: false, outputPrefix: "pocket\(index)/", highResolution: true, modes: ["pocket"], pocketIndex: index, pocketCloseup: true)
        }
    }

    func testSixPocketVisualReplay() throws {
        for index in 0..<6 {
            try realPlaybackVisualSequence(contactPrototype: false, outputPrefix: "pocket\(index)/", highResolution: true, modes: ["pocket"], pocketIndex: index)
        }
    }

    func testPocketDepthVisibilityAudit() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit depth visibility diagnostic")
        for level in 0...2 {
            let s = try scene(mobile: true)
            for node in s.allBallNodes.values { node.isHidden = true }
            let pockets = AngleSceneCalculator.pocketPositions(surfaceY: s.surfaceY)
            XCTAssertEqual(pockets.count, 6)
            for (index, pocket) in pockets.enumerated() {
                let node = try XCTUnwrap(s.allBallNodes[index == 0 ? "cueBall" : "_\(index)"])
                node.isHidden = false
                node.position = SCNVector3(pocket.x, s.surfaceY + AngleSceneCalculator.ballRadius - Float(level) * 2 * AngleSceneCalculator.ballRadius, pocket.z)
            }
            s.cameraRig?.handleObservationPinch(scale: 0.3)
            for view in ["front", "orbit"] {
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "depth\(level)-\(view)")
            }
            s.setCameraMode(.topDown2DRotated, animated: false)
            s.cameraNode.camera?.orthographicScale = 3.5
            try capture(s, name: "depth\(level)-top")
        }
    }

    func testPocketDropVisualCandidate() throws {
        try realPlaybackVisualSequence(contactPrototype: false, highResolution: true, modes: ["pocket"])
    }

    func testCurrentFullResolutionPlayback() throws {
        try realPlaybackVisualSequence(contactPrototype: false, highResolution: true)
    }

    func testRealPlaybackVisualSequence() throws {
        try realPlaybackVisualSequence(contactPrototype: false)
    }

    func testContactPlaybackVisualSequence() throws {
        try realPlaybackVisualSequence(contactPrototype: true)
    }

    func testBallOcclusionRealPlayback() throws {
        try realPlaybackVisualSequence(contactPrototype: false, ballOcclusion: true)
    }

    private func realPlaybackVisualSequence(contactPrototype: Bool, ballOcclusion: Bool = false, baselineLighting: Bool = false, outputPrefix: String = "", highResolution: Bool = false, modes: [String] = ["slow", "fast-multiball", "pocket"], pocketIndex: Int? = nil, pocketCloseup: Bool = false) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        guard ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil else {
            throw XCTSkip("Explicit evidence directory required for motion runner")
        }
        for mode in modes {
            let s = try scene(mobile: true)
            if baselineLighting {
                s.lightingEnvironment.intensity = 0.7
                s.rootNode.enumerateChildNodes { node, _ in
                    if node.light?.castsShadow == true {
                        node.light?.intensity = 8
                        node.position = SCNVector3(0, s.surfaceY + 2.2, 0)
                        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
                    }
                }
            }
            if contactPrototype {
                s.lightingEnvironment.contents = directory.appendingPathComponent("broad-bounce.hdr")
                s.lightingEnvironment.intensity = 0.7
                s.rootNode.enumerateChildNodes { node, _ in
                    if node.light?.castsShadow == true { node.light?.intensity = 8 }
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        material.diffuse.contents = UIColor(red: 0.11, green: 0.40, blue: 0.29, alpha: 1)
                    }
                }
            }
            let y = s.surfaceY + AngleSceneCalculator.ballRadius
            for node in s.allBallNodes.values { node.isHidden = true }
            let cue = try XCTUnwrap(s.cueBallNode)
            cue.isHidden = false
            cue.position = SCNVector3(-0.45, y, 0)
            var balls: [ObstacleBall] = []
            if mode == "fast-multiball" {
                for number in 1...15 {
                    let row = (number - 1) / 5, column = (number - 1) % 5
                    let position = SCNVector3(0.05 + Float(row)*0.22, y, Float(column-2)*0.18)
                    let node = try XCTUnwrap(s.allBallNodes["_\(number)"])
                    node.isHidden = false; node.position = position
                    balls.append(ObstacleBall(name: "_\(number)", position: position))
                }
            }
            let pocket = AngleSceneCalculator.pocketPositions(surfaceY: s.surfaceY)[pocketIndex ?? 5]
            if mode == "pocket" {
                cue.position = SCNVector3(0,y,0.3)
                if pocketIndex != nil {
                    if let index = pocketIndex, index < 4 {
                        cue.position = SCNVector3(pocket.x - (pocket.x > 0 ? 0.3 : -0.3), y,
                                                 pocket.z - (pocket.z > 0 ? 0.3 : -0.3))
                    } else {
                        cue.position = SCNVector3(0, y, pocket.z > 0 ? 0.3 : -0.3)
                    }
                }
            }
            if mode != "slow" {
                s.cameraRig?.handleObservationPinch(scale: 0.5)
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            }
            if pocketCloseup {
                // Diagnostic camera only: world X/Z plane, Y up, meters.
                let inward = -simd_normalize(SIMD2<Float>(pocket.x, pocket.z))
                s.cameraNode.camera?.usesOrthographicProjection = false
                s.cameraNode.camera?.fieldOfView = 45
                s.cameraNode.position = SCNVector3(pocket.x + inward.x * 0.65, s.surfaceY + 0.6, pocket.z + inward.y * 0.65)
                s.cameraNode.look(at: SCNVector3(pocket.x, s.surfaceY, pocket.z))
                SCNTransaction.flush()
            }
            let aim = mode == "pocket"
                ? SCNVector3(pocket.x-cue.position.x, 0, pocket.z-cue.position.z)
                : SCNVector3(1,0,0)
            let prediction = ShotPredictor.simulateFree(cueBall: cue.position, aimDir: aim,
                velocity: mode == "slow" ? 0.18 : (mode == "pocket" ? 1.1 : 3),
                spinX: mode == "slow" ? 0.45 : 0, spinY: 0, surfaceY: s.surfaceY, balls: balls)
            let recorder = try XCTUnwrap(prediction.recorder)
            let playback = TrajectoryPlayback(recorder: recorder, surfaceY: y)
            XCTAssertGreaterThan(playback.duration, 0)
            if mode == "pocket" {
                XCTAssertTrue(playback.willBePocketed(ShotInput.cueBallName))
                guard playback.willBePocketed(ShotInput.cueBallName) else {
                    throw NSError(domain: "V62PocketFixture", code: pocketIndex ?? 5,
                                  userInfo: [NSLocalizedDescriptionKey: "Baseline shot did not pot; stop image generation"])
                }
            }
            let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
            renderer.scene = s; renderer.pointOfView = s.cameraNode
            renderer.autoenablesDefaultLighting = false
            let contactUpdate = contactPrototype ? dynamicContactPrototype(s, presentation: true) : nil
            let contactDelegate = contactUpdate.map { update in RenderContactFrameUpdater { update(true) } }
            let ballUpdate = ballOcclusion ? try installBallOcclusionPrototype(s) : nil
            _ = ballUpdate?(false)
            let ballDelegate = ballUpdate.map { update in RenderContactFrameUpdater {
                s.contactOcclusion?.renderer(renderer, didApplyAnimationsAtTime: 0)
                _ = update(true)
            } }
            renderer.delegate = ballDelegate ?? contactDelegate ?? s.contactOcclusion
            let size = highResolution ? CGSize(width: 1176, height: 2000) : CGSize(width: 588, height: 1000)
            _ = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            if pocketCloseup {
                let projected = renderer.projectPoint(SCNVector3(pocket.x, s.surfaceY, pocket.z))
                XCTAssertEqual(projected.x, Float(size.width / 2), accuracy: 1)
                XCTAssertEqual(projected.y, Float(size.height / 2), accuracy: 1)
            }
            for name in playback.ballNames {
                let node = try XCTUnwrap(s.allBallNodes[name])
                if let action = playback.action(for: node, ballName: name, removeOnPocket: false) {
                    node.runAction(action)
                }
            }
            let dir = directory.appendingPathComponent("\(outputPrefix)motion/\(mode)")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let duration = Double(playback.duration) + TrajectoryPlayback.pocketSettleDuration + 0.15
            let samples = Int(ceil(duration * 60))
            let start = cue.position
            var rows: [[String: Any]] = []
            for frame in 0...samples {
                let time = Double(frame) / 60
                let shot = renderer.snapshot(atTime: time, with: size, antialiasingMode: .multisampling4X)
                if highResolution || frame % 2 == 0 {
                    try XCTUnwrap(shot.pngData()).write(to: dir.appendingPathComponent(String(format:"%05d.png", frame / (highResolution ? 1 : 2))))
                    rows.append(["t":time, "cue":[cue.presentation.position.x,cue.presentation.position.y,cue.presentation.position.z],
                                 "opacity":cue.presentation.opacity])
                }
            }
            XCTAssertGreaterThan(simd_distance(SIMD3(start.x,start.y,start.z), cue.simdPosition), 0.001)
            if mode == "pocket" { XCTAssertLessThan(cue.presentation.opacity, 0.01) }
            if pocketIndex != nil {
                s.showBall(key: "cueBall", scenePosition: start)
                XCTAssertNotNil(cue.parent)
                XCTAssertFalse(cue.isHidden)
                XCTAssertEqual(cue.opacity, 1)
                XCTAssertEqual(cue.position.y, y, accuracy: 0.000001)
                let resetShot = renderer.snapshot(atTime: duration + 1, with: size, antialiasingMode: .multisampling4X)
                XCTAssertEqual(cue.presentation.opacity, 1)
                XCTAssertEqual(cue.presentation.position.y, y, accuracy: 0.000001)
                try XCTUnwrap(resetShot.pngData()).write(to: dir.appendingPathComponent("reset.png"))
            }
            withExtendedLifetime(contactDelegate) {}
            withExtendedLifetime(ballDelegate) {}
            try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
                .write(to: dir.appendingPathComponent("samples.json"))
        }
    }

    func testRadialBallNormals() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for radial in [false, true] {
            let s = try scene(mobile: true)
            if radial {
                for ball in s.allBallNodes.values {
                    ball.enumerateChildNodes { node, _ in
                        guard let geometry = node.geometry else { return }
                        let (low,high) = geometry.boundingBox
                        let center = (SIMD3<Float>(low.x,low.y,low.z) + SIMD3<Float>(high.x,high.y,high.z)) / 2
                        for material in geometry.materials {
                            material.shaderModifiers = [.geometry: "#pragma body\n_geometry.normal = normalize(_geometry.position.xyz - float3(\(center.x),\(center.y),\(center.z)));"]
                        }
                    }
                }
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "normals/\(radial ? "radial" : "original")")
        }
    }

    func testBroadBounceReferenceStudy() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let url = directory.appendingPathComponent("broad-bounce.hdr")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        for variant in 0...2 {
            let s = try scene(mobile: true)
            if variant > 0 { s.lightingEnvironment.contents = url }
            if variant == 2 {
                s.rootNode.enumerateChildNodes { node, _ in
                    if node.light?.castsShadow == true { node.light?.intensity = 4 }
                }
            }
            try capture(s, name: "compare/V\(variant)-page")
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/V\(variant)-detail")
        }
    }

    func testEnvironmentDominantResponse() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let url = directory.appendingPathComponent("broad-bounce.hdr")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        for (index, intensity) in [CGFloat(0.35), 1, 2].enumerated() {
            let s = try scene(mobile: true)
            s.lightingEnvironment.contents = url
            s.lightingEnvironment.intensity = intensity
            s.rootNode.enumerateChildNodes { node,_ in
                if node.light?.castsShadow == true { node.light?.intensity = 4 }
            }
            try capture(s, name: "compare/E\(index)-page")
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/E\(index)-detail")
        }
    }

    func testEnvironmentContactOcclusion() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let url = directory.appendingPathComponent("broad-bounce.hdr")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        for (index, strength) in [CGFloat(0), 1, 2].enumerated() {
            let s = try scene(mobile: true)
            s.lightingEnvironment.contents = url
            s.lightingEnvironment.intensity = 1
            s.rootNode.enumerateChildNodes { node,_ in
                if node.light?.castsShadow == true { node.light?.intensity = 4 }
            }
            let camera = try XCTUnwrap(s.cameraNode.camera)
            camera.screenSpaceAmbientOcclusionIntensity = strength
            camera.screenSpaceAmbientOcclusionRadius = CGFloat(AngleSceneCalculator.ballRadius * 2)
            camera.screenSpaceAmbientOcclusionBias = 0.001
            camera.screenSpaceAmbientOcclusionDepthThreshold = 0.03
            camera.screenSpaceAmbientOcclusionNormalThreshold = 0.2
            try capture(s, name: "compare/O\(index)-page")
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/O\(index)-detail")
        }
    }

    func testImportedOcclusionChannelWithSSAO() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let url = directory.appendingPathComponent("broad-bounce.hdr")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        for index in 0...2 {
            let s = try scene(mobile: true)
            s.lightingEnvironment.contents = url
            s.lightingEnvironment.intensity = 1
            s.rootNode.enumerateChildNodes { node,_ in
                if node.light?.castsShadow == true { node.light?.intensity = 4 }
                if index > 0 {
                    for material in node.geometry?.materials ?? [] {
                        material.ambientOcclusion.contents = index == 1 ? (Float(1) as Any) : (UIColor.white as Any)
                    }
                }
            }
            let camera = try XCTUnwrap(s.cameraNode.camera)
            camera.screenSpaceAmbientOcclusionIntensity = 1
            camera.screenSpaceAmbientOcclusionRadius = CGFloat(AngleSceneCalculator.ballRadius * 2)
            camera.screenSpaceAmbientOcclusionBias = 0.001
            camera.screenSpaceAmbientOcclusionDepthThreshold = 0.03
            camera.screenSpaceAmbientOcclusionNormalThreshold = 0.2
            try capture(s, name: "compare/A\(index)-page")
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/A\(index)-detail")
        }
    }

    func testOcclusionRendererWarmup() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let s = try scene(mobile: true)
        let url = directory.appendingPathComponent("broad-bounce.hdr")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        s.lightingEnvironment.contents = url
        s.lightingEnvironment.intensity = 1
        s.rootNode.enumerateChildNodes { node,_ in
            if node.light?.castsShadow == true { node.light?.intensity = 4 }
        }
        let c = try XCTUnwrap(s.cameraNode.camera)
        c.screenSpaceAmbientOcclusionIntensity = 1
        c.screenSpaceAmbientOcclusionRadius = CGFloat(AngleSceneCalculator.ballRadius * 2)
        c.screenSpaceAmbientOcclusionBias = 0.001
        c.screenSpaceAmbientOcclusionDepthThreshold = 0.03
        c.screenSpaceAmbientOcclusionNormalThreshold = 0.2
        let r = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        r.scene = s; r.pointOfView = s.cameraNode; r.autoenablesDefaultLighting = false
        XCTAssertTrue(r.prepare(s, shouldAbortBlock: nil))
        for frame in 0...60 {
            let shot = r.snapshot(atTime: Double(frame)/60, with: CGSize(width:1176,height:2000), antialiasingMode: .multisampling4X)
            if [0,30,60].contains(frame) {
                try XCTUnwrap(shot.pngData()).write(to: directory.appendingPathComponent("frame-\(frame).png"))
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    func testOcclusionPipelineThreshold() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (index, intensity) in [CGFloat(0), 0.001, 0.1].enumerated() {
            let s = try scene(mobile: true)
            let url = directory.appendingPathComponent("broad-bounce.hdr")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            s.lightingEnvironment.contents = url
            s.lightingEnvironment.intensity = 1
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true { node.light?.intensity = 4 }
            }
            let c = try XCTUnwrap(s.cameraNode.camera)
            c.screenSpaceAmbientOcclusionIntensity = intensity
            c.screenSpaceAmbientOcclusionRadius = CGFloat(AngleSceneCalculator.ballRadius * 2)
            c.screenSpaceAmbientOcclusionBias = 0.001
            c.screenSpaceAmbientOcclusionDepthThreshold = 0.03
            c.screenSpaceAmbientOcclusionNormalThreshold = 0.2
            try capture(s, name: "compare/T\(index)-page")
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/T\(index)-detail")
        }
    }

    func testOcclusionCanonicalSphereControl() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for replaceMesh in [false, true] {
            let s = try scene(mobile: true)
            s.lightingEnvironment.contents = directory.appendingPathComponent("broad-bounce.hdr")
            s.lightingEnvironment.intensity = 1
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true { node.light?.intensity = 4 }
            }
            let c = try XCTUnwrap(s.cameraNode.camera)
            c.screenSpaceAmbientOcclusionIntensity = 0.1
            c.screenSpaceAmbientOcclusionRadius = CGFloat(AngleSceneCalculator.ballRadius * 2)
            c.screenSpaceAmbientOcclusionBias = 0.001
            c.screenSpaceAmbientOcclusionDepthThreshold = 0.03
            c.screenSpaceAmbientOcclusionNormalThreshold = 0.2
            if replaceMesh {
                for node in s.allBallNodes.values where !node.isHidden {
                    var sourceMaterial = node.geometry?.firstMaterial
                    node.enumerateChildNodes { child, _ in
                        if sourceMaterial == nil { sourceMaterial = child.geometry?.firstMaterial }
                    }
                    let sphere = SCNSphere(radius: CGFloat(AngleSceneCalculator.ballRadius))
                    sphere.segmentCount = 96
                    sphere.firstMaterial = try XCTUnwrap(sourceMaterial?.copy() as? SCNMaterial)
                    let control = SCNNode(geometry: sphere)
                    control.position = node.worldPosition
                    s.rootNode.addChildNode(control)
                    node.isHidden = true
                }
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: replaceMesh ? "compare/canonical-detail" : "compare/imported-detail")
        }
    }

    func testAnalyticContactOcclusionStudy() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for mode in 0...2 {
            let s = try scene(mobile: true)
            s.lightingEnvironment.contents = directory.appendingPathComponent("broad-bounce.hdr")
            s.lightingEnvironment.intensity = 0.7
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true { node.light?.intensity = 8 }
            }
            if mode > 0 {
                // Diagnostic only: isotropic hemisphere visibility of tangent spheres.
                // Coordinates come from the rendered balls; no camera or physics offsets.
                var shader = "#pragma body\nfloat3 contactWorld = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;\nfloat contactVisibility = 1.0;\n"
                let radius = AngleSceneCalculator.ballRadius
                for node in s.allBallNodes.values where !node.isHidden && node.opacity > 0 {
                    let p = node.worldPosition
                    let height = max(radius, p.y - s.surfaceY)
                    shader += "{ float2 offset = contactWorld.xz - float2(\(p.x), \(p.z)); float distanceSquared = dot(offset, offset) + \(height * height); contactVisibility *= 1.0 - 0.85 * \(radius * radius * height) / pow(distanceSquared, 1.5); }\n"
                }
                shader += mode == 1 ? "_surface.ambientOcclusion = contactVisibility;" : "_surface.diffuse.rgb *= contactVisibility;"
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = shader
                        material.shaderModifiers = modifiers
                    }
                }
            }
            try capture(s, name: "compare/C\(mode)-page")
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/C\(mode)-detail")
        }
    }

    private func dynamicContactPrototype(_ s: AngleTrainingScene, presentation: Bool = false) -> (Bool) -> Void {
        let slots = s.allBallNodes.sorted { $0.key < $1.key }.map(\.value)
        let radius = AngleSceneCalculator.ballRadius
        var shader = "#pragma arguments\n"
        for i in slots.indices { shader += "float4 contactBall\(i);\n" }
        shader += "#pragma body\nfloat3 contactWorld = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;\nfloat contactVisibility = 1.0;\n"
        for i in slots.indices {
            shader += """
            if (contactBall\(i).w > 0.0) {
                float2 offset = contactWorld.xz - contactBall\(i).xy;
                float inverseDistance = rsqrt(dot(offset, offset) + contactBall\(i).z * contactBall\(i).z);
                contactVisibility *= 1.0 - contactBall\(i).w * \(radius * radius) * contactBall\(i).z * inverseDistance * inverseDistance * inverseDistance;
            }

            """
        }
        shader += "_surface.ambientOcclusion = contactVisibility;"
        var targets: [SCNMaterial] = []
        s.tableNode?.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = shader
                material.shaderModifiers = modifiers
                targets.append(material)
            }
        }
        return { enabled in
            SCNTransaction.begin()
            SCNTransaction.disableActions = true
            for (i, node) in slots.enumerated() {
                let rendered = presentation ? node.presentation : node
                let p = rendered.worldPosition
                let h = p.y - s.surfaceY
                let weight = enabled && !node.isHidden ? 0.85 * Float(rendered.opacity) * min(1, max(0, h / radius)) : 0
                let value = NSValue(scnVector4: SCNVector4(p.x, p.z, max(radius, h), weight))
                for material in targets { material.setValue(value, forKey: "contactBall\(i)") }
            }
            SCNTransaction.commit()
        }
    }

    func testDynamicContactPrototype() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let s = try scene(mobile: true)
        s.lightingEnvironment.contents = directory.appendingPathComponent("broad-bounce.hdr")
        s.lightingEnvironment.intensity = 0.7
        s.rootNode.enumerateChildNodes { node, _ in
            if node.light?.castsShadow == true { node.light?.intensity = 8 }
        }
        let update = dynamicContactPrototype(s)
        let cue = try XCTUnwrap(s.allBallNodes["cueBall"])
        let y = s.surfaceY + AngleSceneCalculator.ballRadius
        for state in ["initial", "moved", "faded", "hidden", "sixteen"] {
            switch state {
            case "moved": cue.position = SCNVector3(-0.15, y, -0.16)
            case "faded": cue.opacity = 0.25
            case "hidden": cue.isHidden = true
            case "sixteen":
                for (i, key) in s.allBallNodes.keys.sorted().enumerated() {
                    s.showBall(key: key, scenePosition: SCNVector3(Float(i / 4) * 0.16 - 0.30, y, Float(i % 4) * 0.14 - 0.21))
                }
            default: break
            }
            for enabled in [false, true] {
                update(enabled)
                try capture(s, name: "compare/\(state)-\(enabled ? "on" : "off")")
            }
        }
    }

    func testUniformNormalMaterialControl() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for clear in [false, true] {
            let s = try scene(mobile: true)
            s.lightingEnvironment.contents = directory.appendingPathComponent("broad-bounce.hdr")
            s.lightingEnvironment.intensity = 0.7
            var cleared: [String] = []
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true { node.light?.intensity = 8 }
                if clear {
                    for material in node.geometry?.materials ?? [] where material.normal.contents is UIColor {
                        cleared.append(material.name ?? "unnamed")
                        material.normal.contents = nil
                        material.normal.intensity = 0
                    }
                }
            }
            dynamicContactPrototype(s)(true)
            try capture(s, name: "compare/\(clear ? "geometric" : "imported")-page")
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(clear ? "geometric" : "imported")-detail")
            if clear {
                try JSONSerialization.data(withJSONObject: cleared, options: [.prettyPrinted]).write(to: directory.appendingPathComponent("cleared-materials.json"))
            }
        }
    }

    func testClothAlbedoSeparation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in 0...2 {
            let s = try scene(mobile: true)
            s.lightingEnvironment.contents = directory.appendingPathComponent("broad-bounce.hdr")
            s.lightingEnvironment.intensity = 0.7
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true { node.light?.intensity = 8 }
                for material in node.geometry?.materials ?? [] where material.name == "TaiNi" && variant > 0 {
                    material.diffuse.contents = variant == 1
                        ? UIColor(red: 0.11, green: 0.40, blue: 0.29, alpha: 1)
                        : UIColor(white: 0.40, alpha: 1)
                }
            }
            dynamicContactPrototype(s)(true)
            try capture(s, name: "compare/P\(variant)-page")
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/P\(variant)-detail")
        }
    }

    func testBallHighlightSeparation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in 0...3 {
            let s = try scene(mobile: true)
            materials(s) { material in
                if variant == 1 { material.roughness.contents = Float(0.035) }
                if variant == 2 { material.roughness.contents = Float(0.25) }
                if variant == 3 {
                    material.shaderModifiers = [.surface: "#pragma body\n_surface.diffuse.rgb *= 0.7;"]
                }
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/H\(variant)-detail")
        }
    }

    func testPrintedMarkPlaneAudit() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let s = try scene(mobile: true)
        var report: [[String: Any]] = []
        var nodes: [SCNNode] = []
        s.tableNode?.enumerateChildNodes { node, _ in nodes.append(node) }
        for node in nodes {
            guard let g = node.geometry,
                  let sourceIndex = g.sources.firstIndex(where: { $0.semantic == .vertex }) else { continue }
            let source = g.sources[sourceIndex]
            guard source.usesFloatComponents, source.bytesPerComponent == 4 else { continue }
            let channel = g.geometrySourceChannels?[sourceIndex].intValue ?? 0
            for (index, element) in g.elements.enumerated() where g.materials[index % g.materials.count].name == "White" {
                var heights: [String: Int] = [:]
                for face in try PocketLeatherMesh.decode(element) {
                    for offset in stride(from: channel, to: face.count, by: element.indicesChannelCount) {
                        let vertex = Int(face[offset])
                        let p: SCNVector3 = source.data.withUnsafeBytes { bytes in
                            let start = source.dataOffset + vertex * source.dataStride
                            return SCNVector3(bytes.loadUnaligned(fromByteOffset: start, as: Float.self),
                                              bytes.loadUnaligned(fromByteOffset: start + 4, as: Float.self),
                                              bytes.loadUnaligned(fromByteOffset: start + 8, as: Float.self))
                        }
                        let world = node.convertPosition(p, to: s.rootNode)
                        heights[String(format: "%.9f", world.y), default: 0] += 1
                    }
                }
                report.append(["node": node.name ?? "unnamed", "worldVertexHeights": heights])
            }
        }
        report.append(["clothPlane": try XCTUnwrap(MobileClothAlignment.measuredBedY(in: s))])
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("mark-heights.json"))
    }

    func testBallAlbedoRefinement() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for scale in [Float(1), 0.85] {
            let s = try scene(mobile: true)
            materials(s) { $0.shaderModifiers = [.surface: "#pragma body\n_surface.diffuse.rgb *= \(scale);"] }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/albedo-\(scale)")
        }
    }

    func testBakedRailOcclusion() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let s = try scene(mobile: true)
        let table = try XCTUnwrap(s.tableNode)
        let width = 128, height = 64, rays = 32
        let halfX = AngleSceneCalculator.innerLength / 2
        let halfZ = AngleSceneCalculator.innerWidth / 2
        var pixels = [UInt8](repeating: 255, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let origin = SCNVector3((Float(x) + 0.5) / Float(width) * 2 * halfX - halfX,
                                       s.surfaceY + 0.0001,
                                       (Float(y) + 0.5) / Float(height) * 2 * halfZ - halfZ)
                var hits = 0
                for ray in 0..<rays {
                    let u = (Float(ray) + 0.5) / Float(rays)
                    let phi = Float(ray) * 2.39996323
                    let d = SCNVector3(sqrt(u) * cos(phi), sqrt(1-u), sqrt(u) * sin(phi))
                    let end = SCNVector3(origin.x + d.x * 0.25, origin.y + d.y * 0.25, origin.z + d.z * 0.25)
                    let a = table.convertPosition(origin, from: s.rootNode)
                    let b = table.convertPosition(end, from: s.rootNode)
                    if !table.hitTestWithSegment(from: a, to: b, options: [SCNHitTestOption.backFaceCulling.rawValue: false, SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.any.rawValue]).isEmpty { hits += 1 }
                }
                pixels[y * width + x] = UInt8(round(Float(rays - hits) / Float(rays) * 255))
            }
        }
        let data = Data(pixels.flatMap { [$0, $0, $0, UInt8(255)] })
        let provider = try XCTUnwrap(CGDataProvider(data: data as CFData))
        let cg = try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
            decode: nil, shouldInterpolate: true, intent: .defaultIntent))
        let texture = UIImage(cgImage: cg)
        try XCTUnwrap(texture.pngData()).write(to: directory.appendingPathComponent("rail-occlusion.png"))
        try capture(s, name: "compare/without-page")
        table.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                var modifiers = material.shaderModifiers ?? [:]
                guard var surface = modifiers[.surface] else { continue }
                surface = surface.replacingOccurrences(of: "#pragma arguments", with: "#pragma arguments\ntexture2d<float> bakedRailAO;")
                surface += """

                if (abs(contactWorld.y - \(s.surfaceY)) < 0.0005) {
                    constexpr sampler railSampler(coord::normalized, address::clamp_to_edge, filter::linear);
                    float2 railUV = (contactWorld.xz + float2(\(halfX), \(halfZ))) / float2(\(2 * halfX), \(2 * halfZ));
                    _surface.ambientOcclusion *= bakedRailAO.sample(railSampler, railUV).r;
                }
                """
                modifiers[.surface] = surface
                material.shaderModifiers = modifiers
                material.setValue(SCNMaterialProperty(contents: texture), forKey: "bakedRailAO")
            }
        }
        try capture(s, name: "compare/with-page")
    }

    func testRailSurfaceHeightAudit() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let s = try scene(mobile: true)
        let table = try XCTUnwrap(s.tableNode)
        var rows: [[String: Any]] = []
        for x in stride(from: Float(-1.36), through: -1.05, by: 0.01) {
            let a = table.convertPosition(SCNVector3(x, 1.1, 0), from: s.rootNode)
            let b = table.convertPosition(SCNVector3(x, 0.7, 0), from: s.rootNode)
            if let hit = table.hitTestWithSegment(from: a, to: b, options: [SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue]).first {
                let p = hit.worldCoordinates, n = hit.worldNormal
                let materials = hit.node.geometry?.materials ?? []
                rows.append(["x": x, "y": p.y, "normal": [n.x,n.y,n.z],
                    "material": materials.isEmpty ? "none" : (materials[hit.geometryIndex % materials.count].name ?? "unnamed")])
            }
        }
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted,.sortedKeys]).write(to: directory.appendingPathComponent("front-profile.json"))
        table.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.fragment] = """
                #pragma body
                float height = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).y;
                _output.color.rgb = abs(height - \(s.surfaceY)) < 0.0005 ? float3(0,1,0) : float3(1,0,0);
                """
                material.shaderModifiers = modifiers
            }
        }
        try capture(s, name: "height-classification")
    }

    /// Diagnostic ablation: identify which light flattens cloth and pocket interiors.
    /// No production settings are changed by this experiment.
    /// Low-cost grazing response study for cloth fibers, not an accepted BRDF.
    func testClothSurfaceDetailIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, normal) in [("current", 0.65), ("flat", 0.0), ("soft", 0.25), ("strong", 1.0)] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                    material.normal.intensity = CGFloat(normal)
                }
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name:"compare/\(name)-detail")
            s.cameraRig?.handleObservationPan(deltaX: 180)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name:"compare/\(name)-orbit")
        }
    }

    /// Inspect the final shaded normal directly, bypassing lighting and albedo.
    /// Separate the substrate and varnish using SceneKit's native coat lobe.
    /// Reference screenshot color is uncalibrated; these are visual candidates only.
    /// Compensate the table albedo for reduced upper-environment irradiance.
    /// White is shared by inlays, markings and nets: inspect all visible uses.
    func testInlayReflectanceIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for enabled in [false, true] {
            let s = try scene(mobile: true)
            if enabled {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "White" {
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = (modifiers[.surface] ?? "#pragma body") + """

                        float inlayY = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).y;
                        if (inlayY > 0.82) { _surface.diffuse.rgb *= 0.6; }
                        """
                        material.shaderModifiers = modifiers
                    }
                }
            }
            s.cameraRig?.handleObservationPinch(scale: 0.5)
            for view in 0..<8 {
                if view > 0 { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(enabled ? "inlay" : "current")-orbit-\(view)")
            }
        }
    }

    func testWhiteMaterialResponse() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "rough", "lowerAlbedo"] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == "White" {
                    print("WHITE_MATERIAL", name, material.lightingModel, String(describing: material.diffuse.contents), String(describing: material.emission.contents), String(describing: material.roughness.contents))
                    if name == "rough" { material.roughness.contents = Float(0.75) }
                    if name == "lowerAlbedo" {
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = (modifiers[.surface] ?? "#pragma body") + "\n_surface.diffuse.rgb *= 0.6;"
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testMaterialLightingBalance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, environment, intensity) in [("current", "", 0.7), ("balanced", "bounce55", 0.35), ("moderate", "bounce35", 0.45)] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(environment).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
                s.lightingEnvironment.intensity = CGFloat(intensity)
                let compensation = 0.7 / intensity
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where ["TaiNi", "Wood", "BlackWood"].contains(material.name ?? "") {
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = (modifiers[.surface] ?? "#pragma body") + "\n_surface.diffuse.rgb = min(_surface.diffuse.rgb * \(compensation), float3(1));"
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testCueIvoryResponse() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, tint) in [("current", "1,1,1"), ("softIvory", "1,0.955,0.81"), ("ivory", "1,0.91,0.62")] {
            let s = try scene(mobile: true)
            let cue = try XCTUnwrap(s.cueBallNode)
            func apply(_ node: SCNNode) {
                for material in node.geometry?.materials ?? [] {
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.surface] = """
                    #pragma body
                    _surface.diffuse.rgb *= float3(\(tint));
                    """
                    material.shaderModifiers = modifiers
                }
            }
            apply(cue)
            cue.enumerateChildNodes { node, _ in apply(node) }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testWoodTextureReuse() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "reusedWood"] {
            let s = try scene(mobile: true)
            if name != "current" {
                var woodContents: Any?
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "Wood" {
                        woodContents = material.diffuse.contents
                    }
                }
                let contents = try XCTUnwrap(woodContents)
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "BlackWood" {
                        material.diffuse.contents = contents
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = """
                        #pragma body
                        _surface.diffuse.rgb *= float3(0.35407753,0.41952911,0.38761742);
                        """
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testWoodLayeredVarnish() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, coat) in [("current", 0.0), ("coatHalf", 0.5), ("coatFull", 1.0)] {
            let s = try scene(mobile: true)
            if coat > 0 {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where ["Wood", "BlackWood"].contains(material.name ?? "") {
                        material.roughness.contents = Float(0.45)
                        material.clearCoat.contents = Float(coat)
                        material.clearCoatRoughness.contents = Float(0.12)
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testOffsetEnvironmentSource() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "offset-positive", "offset-negative"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testBalancedBallBounce() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "bounce35", "bounce55"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
                materials(s) { material in
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.surface] = """
                    #pragma body
                    _surface.diffuse.rgb *= 0.8;
                    """
                    material.shaderModifiers = modifiers
                }
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(name)-detail")
            s.cameraRig?.handleObservationPan(deltaX: 180)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(name)-orbit")
        }
    }

    func testBallDiffuseReflectance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, scale) in [("current", 1.0), ("reflectance80", 0.8), ("reflectance65", 0.65)] {
            let s = try scene(mobile: true)
            materials(s) { material in
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = """
                #pragma body
                _surface.diffuse.rgb *= \(scale);
                """
                material.shaderModifiers = modifiers
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(name)-detail")
            s.cameraRig?.handleObservationPan(deltaX: 180)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(name)-orbit")
        }
    }

    func testFiniteIlluminationConsistency() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let data = try Data(contentsOf: directory.appendingPathComponent("field.json"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let variants = try XCTUnwrap(record["variants"] as? [String: [String: Any]])
        let c = try XCTUnwrap(variants["near"]?["coefficients"] as? [Double])
        for mode in ["current", "cloth", "shared"] {
            let s = try scene(mobile: true)
            func apply(_ material: SCNMaterial) {
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = (modifiers[.surface] ?? "#pragma body") + """

                float3 finiteWorld = (scn_frame.inverseViewTransform * float4(_surface.position,1)).xyz;
                float fx2 = finiteWorld.x*finiteWorld.x, fz2 = finiteWorld.z*finiteWorld.z;
                float finiteGain = \(c[0]) + \(c[1])*fx2 + \(c[2])*fz2 + \(c[3])*fx2*fx2 + \(c[4])*fx2*fz2 + \(c[5])*fz2*fz2;
                float heightBlend = smoothstep(0.70,0.79,finiteWorld.y);
                _surface.diffuse.rgb *= mix(1.0,clamp(finiteGain,0.4,1.6),heightBlend);
                """
                material.shaderModifiers = modifiers
            }
            if mode != "current" {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] {
                        let selected = mode == "cloth" ? material.name == "TaiNi" : ["TaiNi","Wood","BlackWood","Leather","White"].contains(material.name ?? "")
                        if selected { apply(material) }
                    }
                }
                if mode == "shared" { materials(s, body: apply) }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(mode)-\(view)")
            }
        }
    }

    func testFiniteClothIllumination() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let data = try Data(contentsOf: directory.appendingPathComponent("field.json"))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let variants = try XCTUnwrap(record["variants"] as? [String: [String: Any]])
        for name in ["current", "high", "near"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let coefficients = try XCTUnwrap(variants[name]?["coefficients"] as? [Double])
                XCTAssertEqual(coefficients.count, 6)
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = (modifiers[.surface] ?? "#pragma body") + """

                        float3 finiteWorld = (scn_frame.inverseViewTransform * float4(_surface.position,1)).xyz;
                        float fx2 = finiteWorld.x * finiteWorld.x, fz2 = finiteWorld.z * finiteWorld.z;
                        float finiteGain = \(coefficients[0]) + \(coefficients[1])*fx2 + \(coefficients[2])*fz2 + \(coefficients[3])*fx2*fx2 + \(coefficients[4])*fx2*fz2 + \(coefficients[5])*fz2*fz2;
                        _surface.diffuse.rgb *= clamp(finiteGain, 0.4, 1.6);
                        """
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    /// S90: isolate the candidate's second cloth darkening stage. Diagnostic only.
    func testClothMultiplyIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "neutral-multiply", "albedo-only"] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                    material.multiply.contents = name == "current" ? UIColor(white: 0.68, alpha: 1) : UIColor.white
                    if name == "albedo-only" {
                        // Preserve the same linear diffuse product; remove multiply
                        // from the rest of the material response for comparison.
                        func linear(_ x: Double) -> Double { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
                        func srgb(_ x: Double) -> CGFloat { CGFloat(x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055) }
                        let tint = linear(0.68)
                        material.diffuse.contents = UIColor(red: srgb(linear(0.11) * tint), green: srgb(linear(0.40) * tint), blue: srgb(linear(0.29) * tint), alpha: 1)
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testTwinSourcePalette() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "twin"] {
            let s = try scene(mobile: true)
            if name == "twin" {
                let url = directory.appendingPathComponent("twin.hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
                materials(s) { $0.roughness.contents = Float(0.05) }
            }
            let y = s.surfaceY + AngleSceneCalculator.ballRadius
            for (index, key) in s.allBallNodes.keys.sorted().enumerated() {
                s.showBall(key: key, scenePosition: SCNVector3(Float(index / 4) * 0.20 - 0.30, y, Float(index % 4) * 0.18 - 0.27))
            }
            for angle in 0..<4 {
                if angle > 0 { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "palette/\(name)-angle\(angle)")
            }
        }
    }

    func testTwinSourceRoughness() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, roughness) in [("current", 0.10), ("twin-005", 0.05), ("twin-002", 0.02)] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("twin.hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
                materials(s) { $0.roughness.contents = Float(roughness) }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "roughness/\(name)-\(view)")
            }
        }
    }

    func testTwinSourceReflection() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["single", "twin", "cross"] {
            let s = try scene(mobile: true)
            let url = directory.appendingPathComponent("\(name).hdr")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            s.lightingEnvironment.contents = url
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testStructuredEnvironmentPalette() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "walls4"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("walls4.hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            let y = s.surfaceY + AngleSceneCalculator.ballRadius
            for (index, key) in s.allBallNodes.keys.sorted().enumerated() {
                s.showBall(key: key, scenePosition: SCNVector3(Float(index / 4) * 0.20 - 0.30, y, Float(index % 4) * 0.18 - 0.27))
            }
            for angle in 0..<4 {
                if angle > 0 { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-angle\(angle)")
            }
        }
    }

    private func diagnosticCubeTexture(name: String) throws -> MTLTexture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float, size: 128, mipmapped: true)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let data = try Data(contentsOf: directory.appendingPathComponent("\(name).rgba16f"))
        XCTAssertEqual(data.count, 1048560)
        var offset = 0
        data.withUnsafeBytes { bytes in
            for face in 0..<6 {
                for level in 0..<8 {
                    let size = max(1, 128 >> level)
                    let count = size * size * 8
                    texture.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: level, slice: face,
                                    withBytes: bytes.baseAddress!.advanced(by: offset), bytesPerRow: size * 8, bytesPerImage: count)
                    offset += count
                }
            }
        }
        XCTAssertEqual(offset, data.count)
        return texture
    }

    /// S123: distinguish a probe binding failure from table materials or HDR decoding.
    func testMinimalWhiteProbeBinding() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float, size: 16, mipmapped: true)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        let cube = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        for level in 0..<cube.mipmapLevelCount {
            let size = max(1, 16 >> level)
            let pixels = [UInt16](repeating: Float16(1).bitPattern, count: size * size * 4)
            pixels.withUnsafeBytes { bytes in
                for face in 0..<6 {
                    cube.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: level,
                                 slice: face, withBytes: bytes.baseAddress!, bytesPerRow: size * 8, bytesPerImage: size * size * 8)
                }
            }
        }
        let output = directory.appendingPathComponent("compare")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for variant in ["global", "global-probe", "probe-only"] {
            let s = SCNScene()
            s.background.contents = UIColor(white: 0.1, alpha: 1)
            if variant != "probe-only" { s.lightingEnvironment.contents = cube }
            s.lightingEnvironment.intensity = 1
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.wantsHDR = true
            camera.camera?.wantsExposureAdaptation = false
            camera.position = SCNVector3(0, 0, 5)
            s.rootNode.addChildNode(camera)
            for index in 0..<3 {
                let material = SCNMaterial()
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                material.roughness.contents = Float(0.1)
                material.metalness.contents = Float(index) / 2
                let sphere = SCNSphere(radius: 0.5)
                sphere.segmentCount = 48
                sphere.firstMaterial = material
                let node = SCNNode(geometry: sphere)
                node.position.x = Float(index - 1) * 1.2
                s.rootNode.addChildNode(node)
            }
            if variant != "global" {
                let light = SCNLight()
                light.type = .probe
                light.probeType = .radiance
                light.probeUpdateType = .never
                light.probeExtents = SIMD3<Float>(repeating: 10)
                light.parallaxCorrectionEnabled = false
                try XCTUnwrap(light.probeEnvironment).contents = cube
                let probe = SCNNode()
                probe.light = light
                s.rootNode.addChildNode(probe)
            }
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = s
            renderer.pointOfView = camera
            renderer.autoenablesDefaultLighting = false
            var last: UIImage?
            for frame in 0..<8 {
                last = renderer.snapshot(atTime: Double(frame) / 60, with: CGSize(width: 720, height: 400), antialiasingMode: .multisampling4X)
            }
            try XCTUnwrap(last?.pngData()).write(to: output.appendingPathComponent(variant + ".png"))
            let attachment = XCTAttachment(image: try XCTUnwrap(last))
            attachment.name = "white-probe-" + variant
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    /// S124: distinguish a probe binding failure from table materials or HDR decoding.
    func testMinimalImageProbeBinding() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float, size: 16, mipmapped: true)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        let cube = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        for level in 0..<cube.mipmapLevelCount {
            let size = max(1, 16 >> level)
            let pixels = [UInt16](repeating: Float16(1).bitPattern, count: size * size * 4)
            pixels.withUnsafeBytes { bytes in
                for face in 0..<6 {
                    cube.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: level,
                                 slice: face, withBytes: bytes.baseAddress!, bytesPerRow: size * 8, bytesPerImage: size * size * 8)
                }
            }
        }
        let whiteImage = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        let faces = [UIImage](repeating: whiteImage, count: 6)
        let output = directory.appendingPathComponent("compare")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for variant in ["global", "global-probe", "probe-only"] {
            let s = SCNScene()
            s.background.contents = UIColor(white: 0.1, alpha: 1)
            if variant != "probe-only" { s.lightingEnvironment.contents = faces }
            s.lightingEnvironment.intensity = 1
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.wantsHDR = true
            camera.camera?.wantsExposureAdaptation = false
            camera.position = SCNVector3(0, 0, 5)
            s.rootNode.addChildNode(camera)
            for index in 0..<3 {
                let material = SCNMaterial()
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                material.roughness.contents = Float(0.1)
                material.metalness.contents = Float(index) / 2
                let sphere = SCNSphere(radius: 0.5)
                sphere.segmentCount = 48
                sphere.firstMaterial = material
                let node = SCNNode(geometry: sphere)
                node.position.x = Float(index - 1) * 1.2
                s.rootNode.addChildNode(node)
            }
            if variant != "global" {
                let light = SCNLight()
                light.type = .probe
                light.probeType = .radiance
                light.probeUpdateType = .never
                light.probeExtents = SIMD3<Float>(repeating: 10)
                light.parallaxCorrectionEnabled = false
                try XCTUnwrap(light.probeEnvironment).contents = faces
                let probe = SCNNode()
                probe.light = light
                s.rootNode.addChildNode(probe)
            }
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = s
            renderer.pointOfView = camera
            renderer.autoenablesDefaultLighting = false
            var last: UIImage?
            for frame in 0..<8 {
                last = renderer.snapshot(atTime: Double(frame) / 60, with: CGSize(width: 720, height: 400), antialiasingMode: .multisampling4X)
            }
            try XCTUnwrap(last?.pngData()).write(to: output.appendingPathComponent(variant + ".png"))
        }
    }

    /// S125: distinguish a probe binding failure from table materials or HDR decoding.
    func testMinimalPreparedProbeBinding() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float, size: 16, mipmapped: true)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        let cube = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        for level in 0..<cube.mipmapLevelCount {
            let size = max(1, 16 >> level)
            let pixels = [UInt16](repeating: Float16(1).bitPattern, count: size * size * 4)
            pixels.withUnsafeBytes { bytes in
                for face in 0..<6 {
                    cube.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: level,
                                 slice: face, withBytes: bytes.baseAddress!, bytesPerRow: size * 8, bytesPerImage: size * size * 8)
                }
            }
        }
        let output = directory.appendingPathComponent("compare")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for variant in ["global", "global-probe", "probe-only"] {
            let s = SCNScene()
            s.background.contents = UIColor(white: 0.1, alpha: 1)
            if variant != "probe-only" { s.lightingEnvironment.contents = try XCTUnwrap(MobileTableRendering.environmentURL) }
            s.lightingEnvironment.intensity = 1
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.wantsHDR = true
            camera.camera?.wantsExposureAdaptation = false
            camera.position = SCNVector3(0, 0, 5)
            s.rootNode.addChildNode(camera)
            for index in 0..<3 {
                let material = SCNMaterial()
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                material.roughness.contents = Float(0.1)
                material.metalness.contents = Float(index) / 2
                let sphere = SCNSphere(radius: 0.5)
                sphere.segmentCount = 48
                sphere.firstMaterial = material
                let node = SCNNode(geometry: sphere)
                node.position.x = Float(index - 1) * 1.2
                s.rootNode.addChildNode(node)
            }
            if variant != "global" {
                let light = SCNLight()
                light.type = .probe
                light.probeType = .radiance
                light.probeUpdateType = .never
                light.probeExtents = SIMD3<Float>(repeating: 10)
                light.parallaxCorrectionEnabled = false
                try XCTUnwrap(light.probeEnvironment).contents = cube
                let probe = SCNNode()
                probe.light = light
                s.rootNode.addChildNode(probe)
            }
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = s
            renderer.pointOfView = camera
            renderer.autoenablesDefaultLighting = false
            _ = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                renderer.prepare([s]) { success in continuation.resume(returning: success) }
            }
            var last: UIImage?
            for frame in 0..<8 {
                try await Task.sleep(nanoseconds: 100_000_000)
                last = renderer.snapshot(atTime: Double(frame) / 60, with: CGSize(width: 720, height: 400), antialiasingMode: .multisampling4X)
            }
            try XCTUnwrap(last?.pngData()).write(to: output.appendingPathComponent(variant + ".png"))
        }
    }

    /// S126: distinguish a probe binding failure from table materials or HDR decoding.
    func testRealtimeProbeCapture() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let output = directory.appendingPathComponent("compare")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for variant in ["global", "realtime"] {
            let s = SCNScene()
            s.background.contents = UIColor(white: 0.1, alpha: 1)
            s.lightingEnvironment.contents = try XCTUnwrap(MobileTableRendering.environmentURL)
            s.lightingEnvironment.intensity = 1
            let enclosure = SCNBox(width: 12, height: 12, length: 12, chamferRadius: 0)
            let wall = SCNMaterial()
            wall.lightingModel = .constant
            wall.diffuse.contents = UIColor.white
            wall.isDoubleSided = true
            enclosure.firstMaterial = wall
            s.rootNode.addChildNode(SCNNode(geometry: enclosure))
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.wantsHDR = true
            camera.camera?.wantsExposureAdaptation = false
            camera.position = SCNVector3(0, 0, 5)
            s.rootNode.addChildNode(camera)
            for index in 0..<3 {
                let material = SCNMaterial()
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                material.roughness.contents = Float(0.1)
                material.metalness.contents = Float(index) / 2
                let sphere = SCNSphere(radius: 0.5)
                sphere.segmentCount = 48
                sphere.firstMaterial = material
                let node = SCNNode(geometry: sphere)
                node.position.x = Float(index - 1) * 1.2
                s.rootNode.addChildNode(node)
            }
            if variant != "global" {
                let light = SCNLight()
                light.type = .probe
                light.probeType = .radiance
                light.probeUpdateType = .realtime
                light.probeExtents = SIMD3<Float>(repeating: 10)
                light.parallaxCorrectionEnabled = false
                let probe = SCNNode()
                probe.light = light
                probe.position = SCNVector3(0, 2, 0)
                s.rootNode.addChildNode(probe)
            }
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = s
            renderer.pointOfView = camera
            renderer.autoenablesDefaultLighting = false
            let prepared = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                renderer.prepare([s]) { success in continuation.resume(returning: success) }
            }
            XCTAssertTrue(prepared)
            var last: UIImage?
            for frame in 0..<8 {
                try await Task.sleep(nanoseconds: 100_000_000)
                last = renderer.snapshot(atTime: Double(frame) / 60, with: CGSize(width: 720, height: 400), antialiasingMode: .multisampling4X)
            }
            try XCTUnwrap(last?.pngData()).write(to: output.appendingPathComponent(variant + ".png"))
        }
    }

    /// S127: distinguish a probe binding failure from table materials or HDR decoding.
    func testViewRealtimeProbeCapture() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let output = directory.appendingPathComponent("compare")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for variant in ["global", "realtime"] {
            let s = SCNScene()
            s.background.contents = UIColor(white: 0.1, alpha: 1)
            s.lightingEnvironment.contents = try XCTUnwrap(MobileTableRendering.environmentURL)
            s.lightingEnvironment.intensity = 1
            let enclosure = SCNBox(width: 12, height: 12, length: 12, chamferRadius: 0)
            let wall = SCNMaterial()
            wall.lightingModel = .constant
            wall.diffuse.contents = UIColor.white
            wall.isDoubleSided = true
            enclosure.firstMaterial = wall
            s.rootNode.addChildNode(SCNNode(geometry: enclosure))
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.wantsHDR = true
            camera.camera?.wantsExposureAdaptation = false
            camera.position = SCNVector3(0, 0, 5)
            s.rootNode.addChildNode(camera)
            for index in 0..<3 {
                let material = SCNMaterial()
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                material.roughness.contents = Float(0.1)
                material.metalness.contents = Float(index) / 2
                let sphere = SCNSphere(radius: 0.5)
                sphere.segmentCount = 48
                sphere.firstMaterial = material
                let node = SCNNode(geometry: sphere)
                node.position.x = Float(index - 1) * 1.2
                s.rootNode.addChildNode(node)
            }
            if variant != "global" {
                let light = SCNLight()
                light.type = .probe
                light.probeType = .radiance
                light.probeUpdateType = .realtime
                light.probeExtents = SIMD3<Float>(repeating: 10)
                light.parallaxCorrectionEnabled = false
                let probe = SCNNode()
                probe.light = light
                probe.position = SCNVector3(0, 2, 0)
                s.rootNode.addChildNode(probe)
            }
            let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = try XCTUnwrap(windowScene.windows.first { $0.isKeyWindow })
            let view = SCNView(frame: CGRect(x: 0, y: 0, width: 360, height: 200), options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
            view.scene = s
            view.pointOfView = camera
            view.autoenablesDefaultLighting = false
            view.antialiasingMode = .multisampling4X
            view.preferredFramesPerSecond = 60
            view.isPlaying = true
            view.rendersContinuously = true
            window.addSubview(view)
            defer { view.removeFromSuperview() }
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let last: UIImage? = view.snapshot()
            try XCTUnwrap(last?.pngData()).write(to: output.appendingPathComponent(variant + ".png"))
        }
    }

    /// S129: artistic local-minus-distant reflection correction, not a replacement BRDF.
    func testBoxReflectionCorrection() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let cube = try diagnosticCubeTexture(name: "original")
        for variant in ["current", "identity", "local"] {
            let s = try scene(mobile: true)
            if variant != "current" {
                materials(s) { material in
                    let property = SCNMaterialProperty(contents: cube)
                    material.setValue(property, forKey: "localReflectionCube")
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = """
                    #pragma arguments
                    texturecube<float> localReflectionCube;
                    #pragma body
                    float3 viewNormal = normalize(_surface.normal);
                    float3 toEye = normalize(-_surface.position);
                    float3 reflectedView = reflect(-toEye, viewNormal);
                    float3 direction = normalize((scn_frame.inverseViewTransform * float4(reflectedView, 0)).xyz);
                    float3 position = (scn_frame.inverseViewTransform * float4(_surface.position, 1)).xyz - float3(0, 1.8, 0);
                    float3 safeDirection = select(float3(-1e-6), float3(1e-6), direction >= 0.0);
                    safeDirection = select(safeDirection, direction, abs(direction) > 1e-6);
                    float3 face = select(float3(-3,-2,-2), float3(3,2,2), direction >= 0.0);
                    float3 distance = (face - position) / safeDirection;
                    float rayLength = min(distance.x, min(distance.y, distance.z));
                    float3 corrected = normalize(position + rayLength * direction);
                    constexpr sampler reflectionSampler(coord::normalized, filter::linear, mip_filter::linear);
                    float3 distantColor = localReflectionCube.sample(reflectionSampler, direction, level(1.0)).rgb;
                    float3 localColor = localReflectionCube.sample(reflectionSampler, \(variant == "identity" ? "direction" : "corrected"), level(1.0)).rgb;
                    float fresnel = 0.04 + 0.96 * pow(1.0 - saturate(dot(viewNormal, toEye)), 5.0);
                    _output.color.rgb = max(float3(0), _output.color.rgb + 0.7 * fresnel * (localColor - distantColor));
                    float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                    _output.color.rgb /= 1.0 + 0.4 * max(0.0, ballPeak - 0.4);
                    """
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(variant)-\(view)")
            }
        }
    }

    func testDielectricReflectionGain() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let cube = try diagnosticCubeTexture(name: "original")
        for variant in ["current", "identity", "gain1", "gain3"] {
            let s = try scene(mobile: true)
            if variant != "current" {
                materials(s) { material in
                    let property = SCNMaterialProperty(contents: cube)
                    material.setValue(property, forKey: "localReflectionCube")
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = """
                    #pragma arguments
                    texturecube<float> localReflectionCube;
                    #pragma body
                    float3 viewNormal = normalize(_surface.normal);
                    float3 toEye = normalize(-_surface.position);
                    float3 reflectedView = reflect(-toEye, viewNormal);
                    float3 direction = normalize((scn_frame.inverseViewTransform * float4(reflectedView, 0)).xyz);
                    float3 position = (scn_frame.inverseViewTransform * float4(_surface.position, 1)).xyz - float3(0, 1.8, 0);
                    float3 safeDirection = select(float3(-1e-6), float3(1e-6), direction >= 0.0);
                    safeDirection = select(safeDirection, direction, abs(direction) > 1e-6);
                    float3 face = select(float3(-3,-2,-2), float3(3,2,2), direction >= 0.0);
                    float3 distance = (face - position) / safeDirection;
                    float rayLength = min(distance.x, min(distance.y, distance.z));
                    float3 corrected = normalize(position + rayLength * direction);
                    constexpr sampler reflectionSampler(coord::normalized, filter::linear, mip_filter::linear);
                    float3 distantColor = localReflectionCube.sample(reflectionSampler, direction, level(1.0)).rgb;
                    float3 localColor = localReflectionCube.sample(reflectionSampler, \(variant == "identity" ? "direction" : "corrected"), level(1.0)).rgb;
                    float fresnel = 0.04 + 0.96 * pow(1.0 - saturate(dot(viewNormal, toEye)), 5.0);
                    _output.color.rgb = max(float3(0), _output.color.rgb + 0.7 * \(variant == "identity" ? "0.0" : variant == "gain1" ? "1.0" : "3.0") * fresnel * distantColor);
                    float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                    _output.color.rgb /= 1.0 + 0.4 * max(0.0, ballPeak - 0.4);
                    """
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(variant)-\(view)")
            }
        }
    }

    func testNativeSceneArchiveRoundTrip() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let source = try scene(mobile: true)
        source.cameraNode.name = "v62ArchiveCamera"
        try capture(source, name: "original")
        let archive = SCNScene()
        archive.rootNode.addChildNode(source.rootNode.clone())
        archive.background.contents = source.background.contents
        archive.lightingEnvironment.contents = source.lightingEnvironment.contents
        archive.lightingEnvironment.intensity = source.lightingEnvironment.intensity
        // SCNKeyedArchiver cannot encode the NSValue matrix custom uniforms.
        // Keep their exact float values in a sidecar and restore before rendering.
        var contactUniforms: [String: [Float]] = [:]
        archive.rootNode.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                for group in 0..<4 {
                    let key = "contactGroup\(group)"
                    if let value = material.value(forKey: key) as? NSValue {
                        let m = simd_float4x4(value.scnMatrix4Value)
                        contactUniforms[key] = (0..<4).flatMap { c in (0..<4).map { r in m[c][r] } }
                        material.setValue(nil, forKey: key)
                    }
                }
            }
        }
        try JSONEncoder().encode(contactUniforms).write(to: directory.appendingPathComponent("contact-uniforms.json"))
        let url = directory.appendingPathComponent("candidate.scn")
        XCTAssertTrue(archive.write(to: url, options: nil, delegate: nil, progressHandler: nil))
        let restored = try SCNScene(url: url, options: nil)
        restored.rootNode.enumerateChildNodes { node, _ in
            for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                for (key, values) in contactUniforms {
                    var matrix = matrix_identity_float4x4
                    for c in 0..<4 { for r in 0..<4 { matrix[c][r] = values[c * 4 + r] } }
                    material.setValue(NSValue(scnMatrix4: SCNMatrix4(matrix)), forKey: key)
                }
            }
        }
        let camera = try XCTUnwrap(restored.rootNode.childNode(withName: "v62ArchiveCamera", recursively: true))
        XCTAssertEqual(camera.camera?.fieldOfView, source.cameraNode.camera?.fieldOfView)
        XCTAssertEqual(camera.camera?.exposureOffset, source.cameraNode.camera?.exposureOffset)
        for col in 0..<4 {
            for row in 0..<4 { XCTAssertEqual(camera.simdWorldTransform[col][row],source.cameraNode.simdWorldTransform[col][row],accuracy:1e-6) }
        }
        let renderer = SCNRenderer(device:try XCTUnwrap(MTLCreateSystemDefaultDevice()),options:nil)
        renderer.scene = restored
        renderer.pointOfView = camera
        renderer.autoenablesDefaultLighting = false
        _ = renderer.snapshot(atTime:0,with:CGSize(width:1176,height:2000),antialiasingMode:.multisampling4X)
        let image = renderer.snapshot(atTime:0,with:CGSize(width:1176,height:2000),antialiasingMode:.multisampling4X)
        try XCTUnwrap(image.pngData()).write(to:directory.appendingPathComponent("restored-ios.png"))
    }

    func testHDRDirectionConvention() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let output = directory
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        guard let device = MTLCreateSystemDefaultDevice() else { preconditionFailure("Metal device unavailable") }
        let descriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float, size: 16, mipmapped: true)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        guard let cube = device.makeTexture(descriptor: descriptor) else { preconditionFailure("Cube allocation failed") }
        for level in 0..<cube.mipmapLevelCount {
            let size = max(1, 16 >> level)
            let pixels = [UInt16](repeating: Float16(1).bitPattern, count: size * size * 4)
            pixels.withUnsafeBytes { bytes in
                for face in 0..<6 {
                    cube.replace(region: MTLRegionMake2D(0,0,size,size), mipmapLevel: level, slice: face,
                                 withBytes: bytes.baseAddress!, bytesPerRow: size*8, bytesPerImage: size*size*8)
                }
            }
        }
        guard let redCube = device.makeTexture(descriptor: descriptor) else { preconditionFailure("Red cube allocation failed") }
        let faceColors: [[Float16]] = [[1,0,0,1],[0,1,0,1],[0,0,1,1],[1,1,0,1],[0,1,1,1],[1,0,1,1]]
        for level in 0..<redCube.mipmapLevelCount {
            let size = max(1,16 >> level)
            for face in 0..<6 {
                let pixels = Array(repeating: faceColors[face],count:size*size).flatMap { $0 }.map { $0.bitPattern }
                pixels.withUnsafeBytes { bytes in
                    redCube.replace(region: MTLRegionMake2D(0,0,size,size),mipmapLevel:level,slice:face,
                                    withBytes:bytes.baseAddress!,bytesPerRow:size*8,bytesPerImage:size*size*8)
                }
            }
        }
        for variant in ["global", "manual", "manual-flipZ"] {
            let scene = SCNScene()
            scene.background.contents = UIColor(white: 0.1, alpha: 1)
            scene.lightingEnvironment.contents = output.appendingPathComponent("direction.hdr")
            scene.lightingEnvironment.intensity = 1
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera!.wantsHDR = true
            camera.camera!.wantsExposureAdaptation = false
            camera.position = SCNVector3(0,0,5)
            scene.rootNode.addChildNode(camera)
            for index in 0..<3 {
                let material = SCNMaterial()
                material.lightingModel = .physicallyBased
                material.diffuse.contents = UIColor(white:0.5,alpha:1)
                material.roughness.contents = Float(0.1)
                material.metalness.contents = Float(1)
                if variant != "global" {
                    material.setValue(SCNMaterialProperty(contents:redCube),forKey:"manualCube")
                    material.shaderModifiers = [.fragment: """
                    #pragma arguments
                    texturecube<float> manualCube;
                    #pragma body
                    float3 reflected = reflect(normalize(_surface.position), normalize(_surface.normal));
                    float3 direction = normalize((scn_frame.inverseViewTransform * float4(reflected,0)).xyz);
                    \(variant == "manual-flipZ" ? "direction.z = -direction.z;" : "")
                    constexpr sampler s(coord::normalized,filter::linear,mip_filter::linear);
                    _output.color.rgb = manualCube.sample(s,direction,level(0.0)).rgb;
                    """]
                }
                let sphere = SCNSphere(radius:0.5)
                sphere.segmentCount = 48
                sphere.firstMaterial = material
                let node = SCNNode(geometry:sphere)
                node.position.x = Float(index-1)*1.2
                scene.rootNode.addChildNode(node)
            }
            let renderer = SCNRenderer(device:device,options:nil)
            renderer.scene = scene
            renderer.pointOfView = camera
            renderer.autoenablesDefaultLighting = false
            var last: UIImage?
            for frame in 0..<8 {
                last = renderer.snapshot(atTime:Double(frame)/60,with:CGSize(width:720,height:400),antialiasingMode:.multisampling4X)
            }
            try XCTUnwrap(last?.pngData()).write(to:output.appendingPathComponent(variant+".png"))
        }
    }

    func testCurrentWoodVarnishLayers() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for name in ["current", "substrate", "polished", "satin"] {
            let s = try scene(mobile: true)
            if name != "current" {
                var count = 0
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where ["Wood", "BlackWood"].contains(material.name ?? "") {
                        material.roughness.contents = Float(0.45)
                        material.clearCoat.contents = Float(name == "substrate" ? 0 : 1)
                        material.clearCoatRoughness.contents = Float(name == "polished" ? 0.04 : 0.12)
                        count += 1
                    }
                }
                XCTAssertGreaterThan(count, 0)
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(name)-\(view)")
            }
        }
    }

    func testClothHueAtMatchedAlbedoLuminance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        func decode(_ x: Double) -> Double { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        func encode(_ x: Double) -> Double { x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x,1/2.4) - 0.055 }
        let weights = [0.2126, 0.7152, 0.0722]
        func luminance(_ a: [Double]) -> Double { zip(a,weights).map(*).reduce(0,+) }
        let base = [0.11,0.40,0.29].map(decode)
        let target = luminance(base)
        var records: [[String: Any]] = []
        for name in ["current", "green", "gray"] {
            var linear = name == "green" ? [0.11,0.40,0.12].map(decode) : name == "gray" ? [target,target,target] : base
            let scale = target / luminance(linear)
            linear = linear.map { $0 * scale }
            XCTAssertEqual(luminance(linear), target, accuracy: 1e-12)
            let rgb = linear.map(encode)
            records.append(["name":name,"linear":linear,"sRGB":rgb,"luminance":luminance(linear)])
            let s = try scene(mobile: true)
            var count = 0
            s.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    m.diffuse.contents = UIColor(red: CGFloat(rgb[0]), green: CGFloat(rgb[1]), blue: CGFloat(rgb[2]), alpha: 1)
                    count += 1
                }
            }
            XCTAssertGreaterThan(count,0)
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(name)-\(view)")
            }
        }
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("albedo-colors.json"))
    }

    func testOffsetAreaGrayCalibration() throws { try offsetAreaEvidence(calibrated: false) }
    func testOffsetAreaMatchedAppearance() throws { try offsetAreaEvidence(calibrated: true) }

    private func offsetAreaEvidence(calibrated: Bool) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        var variants: [(String, Double)] = [("current", 0)]
        if calibrated {
            let data = try Data(contentsOf: directory.appendingPathComponent("calibration.json"))
            let values = try JSONDecoder().decode([String: Double].self, from: data)
            variants += [("strip", try XCTUnwrap(values["strip"])), ("square", try XCTUnwrap(values["square"]))]
        } else {
            variants += [("strip", 10000), ("strip", 80000), ("square", 10000), ("square", 80000)]
        }
        for (name, intensity) in variants {
          for gray in (calibrated ? [true, false] : [true]) {
            let s = try scene(mobile: true)
            if name != "current" {
                var count = 0
                s.rootNode.enumerateChildNodes { node, _ in
                    guard let light = node.light, light.castsShadow else { return }
                    light.type = .area
                    light.areaType = .rectangle
                    light.areaExtents = name == "strip" ? SIMD3<Float>(2,0.4,0) : SIMD3<Float>(0.8,0.8,0)
                    light.drawsArea = true
                    light.doubleSided = true
                    light.attenuationEndDistance = 10
                    light.doubleSided = false
                    light.intensity = CGFloat(intensity)
                    XCTAssertEqual(node.position.x, 1, accuracy: 0.00001)
                    let target = SIMD3<Float>(0,s.surfaceY,0)
                    XCTAssertGreaterThan(simd_dot(node.simdWorldFront, simd_normalize(target-node.simdWorldPosition)), 0.9999)
                    count += 1
                }
                XCTAssertEqual(count, 1)
            }
            if gray {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                        m.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                        m.multiply.contents = UIColor.white
                        m.normal.contents = nil
                        m.roughness.contents = Float(1)
                        var modifiers = m.shaderModifiers ?? [:]
                        modifiers.removeValue(forKey: .surface)
                        modifiers.removeValue(forKey: .fragment)
                        m.shaderModifiers = modifiers
                    }
                }
                try capture(s, name: "gray/\(name)-\(Int(intensity))")
            } else {
                for view in ["entry", "detail", "orbit"] {
                    if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                    if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                    for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                    try capture(s, name: "compare/\(name)-\(view)")
                }
            }
          }
        }
    }

    func testBallShadowResponseIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for variant in ["current", "no-shadow", "no-environment", "no-environment-no-shadow"] {
            let s = try scene(mobile: true)
            if variant.hasPrefix("no-environment") { s.lightingEnvironment.intensity = 0 }
            if variant.hasSuffix("no-shadow") {
                var changed = 0
                s.rootNode.enumerateChildNodes { node, _ in
                    guard let light = node.light, light.castsShadow else { return }
                    light.castsShadow = false
                    changed += 1
                }
                XCTAssertEqual(changed, 1)
            }
            for view in ["detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testCurrentBallNormalAndLightIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for variant in ["current", "radial", "no-key", "no-fill", "no-ambient", "no-environment"] {
            let s = try scene(mobile: true)
            if variant == "radial" {
                var changed = 0
                for ball in s.allBallNodes.values {
                    func configure(_ node: SCNNode) {
                        guard let geometry = node.geometry else { return }
                        let (lo, hi) = geometry.boundingBox
                        let center = (SIMD3<Float>(lo.x,lo.y,lo.z) + SIMD3<Float>(hi.x,hi.y,hi.z))/2
                        for material in geometry.materials {
                            var modifiers = material.shaderModifiers ?? [:]
                            modifiers[.geometry] = "#pragma body\n_geometry.normal = normalize(_geometry.position.xyz - float3(\(center.x),\(center.y),\(center.z)));"
                            material.shaderModifiers = modifiers
                            changed += 1
                        }
                    }
                    configure(ball)
                    ball.enumerateChildNodes { node, _ in configure(node) }
                }
                XCTAssertGreaterThan(changed, 0)
            }
            if variant == "no-environment" { s.lightingEnvironment.intensity = 0 }
            s.rootNode.enumerateChildNodes { node, _ in
                guard let light = node.light else { return }
                if variant == "no-key", light.castsShadow { light.intensity = 0 }
                if variant == "no-fill", light.type == .directional, !light.castsShadow { light.intensity = 0 }
                if variant == "no-ambient", light.type == .ambient { light.intensity = 0 }
            }
            for view in ["detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testBallAlbedoColorSpaceAudit() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        func linear(_ code: Double) -> Double {
            let x = code / 255
            return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        let expected = [205.0, 29.0, 30.0].map(linear)
        for variant in ["texture", "linear", "raw"] {
            let s = try scene(mobile: true)
            let target = try XCTUnwrap(s.targetBallNodes.first)
            var count = 0
            func configure(_ node: SCNNode) {
                for material in node.geometry?.materials ?? [] {
                    let expression: String
                    if variant == "texture" { expression = "_surface.diffuse.rgb" }
                    else if variant == "linear" { expression = "float3(\(expected[0]), \(expected[1]), \(expected[2]))" }
                    else { expression = "float3(205.0/255.0, 29.0/255.0, 30.0/255.0)" }
                    material.shaderModifiers = [.fragment: "#pragma body\n_output.color.rgb = \(expression);"]
                    count += 1
                }
            }
            configure(target)
            target.enumerateChildNodes { node, _ in configure(node) }
            XCTAssertGreaterThan(count, 0)
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 90) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
        try JSONSerialization.data(withJSONObject: ["sourceRGB": [205,29,30], "expectedLinear": expected], options: [.prettyPrinted])
            .write(to: directory.appendingPathComponent("expected.json"))
    }

    func testBallDiffuseBindingIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        var audit: [[String: String]] = []
        for variant in ["current", "neutralMultiply", "specularOnly"] {
            let s = try scene(mobile: true)
            let y = s.surfaceY + AngleSceneCalculator.ballRadius
            for (index, key) in s.allBallNodes.keys.sorted().enumerated() {
                s.showBall(key: key, scenePosition: SCNVector3(Float(index / 4) * 0.20 - 0.30, y, Float(index % 4) * 0.18 - 0.27))
                s.allBallNodes[key]?.simdOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0))
            }
            s.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)))
            materials(s) { material in
                if variant == "current" {
                    audit.append(["name": material.name ?? "", "diffuse": String(describing: material.diffuse.contents),
                                  "multiply": String(describing: material.multiply.contents),
                                  "ambient": String(describing: material.ambient.contents),
                                  "emission": String(describing: material.emission.contents),
                                  "roughness": String(describing: material.roughness.contents)])
                }
                if variant == "neutralMultiply" { material.multiply.contents = UIColor.white }
                if variant == "specularOnly" {
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.surface] = "#pragma body\n_surface.diffuse.rgb = float3(0.0);"
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
        try JSONSerialization.data(withJSONObject: audit, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("bindings.json"))
    }

    func testBoundedReflectionContent() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let cube = try diagnosticCubeTexture(name: "original")
        let photo = try diagnosticCubeTexture(name: "photo")
        for layout in ["pair", "palette"] {
        for variant in ["current", "half", "full"] {
            let s = try scene(mobile: true)
            if layout == "palette" {
                let y = s.surfaceY + AngleSceneCalculator.ballRadius
                for (index, key) in s.allBallNodes.keys.sorted().enumerated() {
                    s.showBall(key: key, scenePosition: SCNVector3(Float(index / 4) * 0.20 - 0.30, y, Float(index % 4) * 0.18 - 0.27))
                    s.allBallNodes[key]?.simdOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0))
                }
                s.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)))
            }
            if variant != "current" {
                materials(s) { material in
                    let property = SCNMaterialProperty(contents: cube)
                    material.setValue(property, forKey: "localReflectionCube")
                    material.setValue(SCNMaterialProperty(contents: photo), forKey: "photoReflectionCube")
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = """
                    #pragma arguments
                    texturecube<float> localReflectionCube;
                    texturecube<float> photoReflectionCube;
                    #pragma body
                    float3 viewNormal = normalize(_surface.normal);
                    float3 toEye = normalize(-_surface.position);
                    float3 reflectedView = reflect(-toEye, viewNormal);
                    float3 direction = normalize((scn_frame.inverseViewTransform * float4(reflectedView, 0)).xyz);
                    constexpr sampler reflectionSampler(coord::normalized, filter::linear, mip_filter::linear);
                    float3 distantColor = localReflectionCube.sample(reflectionSampler, direction, level(1.0)).rgb;
                    float fresnel = 0.04 + 0.96 * pow(1.0 - saturate(dot(viewNormal, toEye)), 5.0);
                    float3 photoDirection = direction;
                    float3 photoColor = photoReflectionCube.sample(reflectionSampler, photoDirection, level(1.0)).rgb;
                    _output.color.rgb = max(float3(0), _output.color.rgb + \(variant == "half" ? "0.175" : "0.35") * fresnel * (photoColor - distantColor));
                    float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                    _output.color.rgb /= 1.0 + 0.4 * max(0.0, ballPeak - 0.4);
                    """
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(layout)/\(variant)-\(view)")
            }
        }
        }
    }

    func testReflectionContentDifference() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let cube = try diagnosticCubeTexture(name: "original")
        let photo = try diagnosticCubeTexture(name: "photo")
        for layout in ["pair", "palette"] {
        for variant in ["current", "photo", "photo90"] {
            let s = try scene(mobile: true)
            if layout == "palette" {
                let y = s.surfaceY + AngleSceneCalculator.ballRadius
                for (index, key) in s.allBallNodes.keys.sorted().enumerated() {
                    s.showBall(key: key, scenePosition: SCNVector3(Float(index / 4) * 0.20 - 0.30, y, Float(index % 4) * 0.18 - 0.27))
                    s.allBallNodes[key]?.simdOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0))
                }
                s.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)))
            }
            if variant != "current" {
                materials(s) { material in
                    let property = SCNMaterialProperty(contents: cube)
                    material.setValue(property, forKey: "localReflectionCube")
                    material.setValue(SCNMaterialProperty(contents: photo), forKey: "photoReflectionCube")
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = """
                    #pragma arguments
                    texturecube<float> localReflectionCube;
                    texturecube<float> photoReflectionCube;
                    #pragma body
                    float3 viewNormal = normalize(_surface.normal);
                    float3 toEye = normalize(-_surface.position);
                    float3 reflectedView = reflect(-toEye, viewNormal);
                    float3 direction = normalize((scn_frame.inverseViewTransform * float4(reflectedView, 0)).xyz);
                    constexpr sampler reflectionSampler(coord::normalized, filter::linear, mip_filter::linear);
                    float3 distantColor = localReflectionCube.sample(reflectionSampler, direction, level(1.0)).rgb;
                    float fresnel = 0.04 + 0.96 * pow(1.0 - saturate(dot(viewNormal, toEye)), 5.0);
                    float3 photoDirection = \(variant == "photo90" ? "float3(-direction.z, direction.y, direction.x)" : "direction");
                    float3 photoColor = photoReflectionCube.sample(reflectionSampler, photoDirection, level(1.0)).rgb;
                    _output.color.rgb = max(float3(0), _output.color.rgb + 0.35 * fresnel * (photoColor - distantColor));
                    float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                    _output.color.rgb /= 1.0 + 0.4 * max(0.0, ballPeak - 0.4);
                    """
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(layout)/\(variant)-\(view)")
            }
        }
        }
    }

    func testOffsetKeyReflectionRestore() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let cube = try diagnosticCubeTexture(name: "original")
        for layout in ["pair", "palette"] {
        for variant in ["current", "restore", "boost"] {
            let s = try scene(mobile: true)
            if layout == "palette" {
                let y = s.surfaceY + AngleSceneCalculator.ballRadius
                for (index, key) in s.allBallNodes.keys.sorted().enumerated() {
                    s.showBall(key: key, scenePosition: SCNVector3(Float(index / 4) * 0.20 - 0.30, y, Float(index % 4) * 0.18 - 0.27))
                    s.allBallNodes[key]?.simdOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0))
                }
                s.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)))
            }
            if variant != "current" {
                materials(s) { material in
                    let property = SCNMaterialProperty(contents: cube)
                    material.setValue(property, forKey: "localReflectionCube")
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = """
                    #pragma arguments
                    texturecube<float> localReflectionCube;
                    #pragma body
                    float3 viewNormal = normalize(_surface.normal);
                    float3 toEye = normalize(-_surface.position);
                    float3 reflectedView = reflect(-toEye, viewNormal);
                    float3 direction = normalize((scn_frame.inverseViewTransform * float4(reflectedView, 0)).xyz);
                    constexpr sampler reflectionSampler(coord::normalized, filter::linear, mip_filter::linear);
                    float3 distantColor = localReflectionCube.sample(reflectionSampler, direction, level(1.0)).rgb;
                    float fresnel = 0.04 + 0.96 * pow(1.0 - saturate(dot(viewNormal, toEye)), 5.0);
                    _output.color.rgb += \(variant == "restore" ? "0.35" : "0.7") * fresnel * distantColor;
                    float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                    _output.color.rgb /= 1.0 + 0.4 * max(0.0, ballPeak - 0.4);
                    """
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(layout)/\(variant)-\(view)")
            }
        }
        }
    }

    func testDirectionalDiffuseReflectionRestore() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let cube = try diagnosticCubeTexture(name: "original")
        for variant in ["current", "half", "halfRestored", "low", "lowRestored"] {
            let s = try scene(mobile: true)
            let environment = variant.hasPrefix("half") ? 0.35 : variant.hasPrefix("low") ? 0.1 : 0.7
            let key = variant.hasPrefix("half") ? 16.24344686890314 : variant.hasPrefix("low") ? 22.12959584327318 : 8.0
            s.lightingEnvironment.intensity = CGFloat(environment)
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true { node.light?.intensity = CGFloat(key) }
            }
            if variant.hasSuffix("Restored") {
                materials(s) { material in
                    let property = SCNMaterialProperty(contents: cube)
                    material.setValue(property, forKey: "localReflectionCube")
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = """
                    #pragma arguments
                    texturecube<float> localReflectionCube;
                    #pragma body
                    float3 viewNormal = normalize(_surface.normal);
                    float3 toEye = normalize(-_surface.position);
                    float3 reflectedView = reflect(-toEye, viewNormal);
                    float3 direction = normalize((scn_frame.inverseViewTransform * float4(reflectedView, 0)).xyz);
                    constexpr sampler reflectionSampler(coord::normalized, filter::linear, mip_filter::linear);
                    float3 distantColor = localReflectionCube.sample(reflectionSampler, direction, level(1.0)).rgb;
                    float fresnel = 0.04 + 0.96 * pow(1.0 - saturate(dot(viewNormal, toEye)), 5.0);
                    _output.color.rgb += \(0.7 - environment) * fresnel * distantColor;
                    float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                    _output.color.rgb /= 1.0 + 0.4 * max(0.0, ballPeak - 0.4);
                    """
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(variant)-\(view)")
            }
        }
    }

    func testReflectionGainPalette() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let cube = try diagnosticCubeTexture(name: "original")
        for variant in ["current", "gain1", "gain3"] {
            let s = try scene(mobile: true)
            let y = s.surfaceY + AngleSceneCalculator.ballRadius
            for (index, key) in s.allBallNodes.keys.sorted().enumerated() {
                s.showBall(key: key, scenePosition: SCNVector3(Float(index / 4) * 0.20 - 0.30, y, Float(index % 4) * 0.18 - 0.27))
                s.allBallNodes[key]?.simdOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0))
            }
            s.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0,1,0)))
            XCTAssertEqual(s.allBallNodes.values.filter { !$0.isHidden }.count, s.allBallNodes.count)
            if variant != "current" {
                materials(s) { material in
                    let property = SCNMaterialProperty(contents: cube)
                    material.setValue(property, forKey: "localReflectionCube")
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = """
                    #pragma arguments
                    texturecube<float> localReflectionCube;
                    #pragma body
                    float3 viewNormal = normalize(_surface.normal);
                    float3 toEye = normalize(-_surface.position);
                    float3 reflectedView = reflect(-toEye, viewNormal);
                    float3 direction = normalize((scn_frame.inverseViewTransform * float4(reflectedView, 0)).xyz);
                    constexpr sampler reflectionSampler(coord::normalized, filter::linear, mip_filter::linear);
                    float3 distantColor = localReflectionCube.sample(reflectionSampler, direction, level(1.0)).rgb;
                    float fresnel = 0.04 + 0.96 * pow(1.0 - saturate(dot(viewNormal, toEye)), 5.0);
                    _output.color.rgb = max(float3(0), _output.color.rgb + 0.7 * \(variant == "identity" ? "0.0" : variant == "gain1" ? "1.0" : "3.0") * fresnel * distantColor);
                    float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                    _output.color.rgb /= 1.0 + 0.4 * max(0.0, ballPeak - 0.4);
                    """
                    material.shaderModifiers = modifiers
                }
            }
            for angle in 0..<4 {
                if angle > 0 { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(variant)-angle\(angle)")
            }
        }
    }

    func testF0ReflectionDifference() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let cube = try diagnosticCubeTexture(name: "original")
        for variant in ["current", "f008", "f016", "f016NoCompensation"] {
            let s = try scene(mobile: true)
            if variant != "current" {
                materials(s) { material in
                    let property = SCNMaterialProperty(contents: cube)
                    material.setValue(property, forKey: "localReflectionCube")
                    var modifiers = material.shaderModifiers ?? [:]
                    let targetF0 = variant == "f008" ? 0.08 : 0.16
                    let diffuseScale = variant == "f016NoCompensation" ? 1.0 : (1.0 - targetF0) / 0.96
                    modifiers[.surface] = "#pragma body\n_surface.diffuse.rgb *= \(diffuseScale);"
                    modifiers[.fragment] = """
                    #pragma arguments
                    texturecube<float> localReflectionCube;
                    #pragma body
                    float3 viewNormal = normalize(_surface.normal);
                    float3 toEye = normalize(-_surface.position);
                    float3 reflectedView = reflect(-toEye, viewNormal);
                    float3 direction = normalize((scn_frame.inverseViewTransform * float4(reflectedView, 0)).xyz);
                    constexpr sampler reflectionSampler(coord::normalized, filter::linear, mip_filter::linear);
                    float3 distantColor = localReflectionCube.sample(reflectionSampler, direction, level(1.0)).rgb;
                    float fresnelDelta = \(targetF0 - 0.04) * (1.0 - pow(1.0 - saturate(dot(viewNormal, toEye)), 5.0));
                    _output.color.rgb += 0.7 * fresnelDelta * distantColor;
                    float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                    _output.color.rgb /= 1.0 + 0.4 * max(0.0, ballPeak - 0.4);
                    """
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(variant)-\(view)")
            }
        }
    }

    /// S131: scanned fleece luminance at its documented 0.3m width, no normal changes.
    func testScannedClothLuminance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let texture = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("Diffuse.jpg").path))
        for variant in ["current", "scan"] {
            let s = try scene(mobile: true)
            if variant == "scan" {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        let property = SCNMaterialProperty(contents: texture)
                        property.wrapS = .repeat
                        property.wrapT = .repeat
                        material.setValue(property, forKey: "scannedCloth")
                        var modifiers = material.shaderModifiers ?? [:]
                        var surface = modifiers[.surface] ?? "#pragma body\n"
                        surface = surface.replacingOccurrences(of: "#pragma arguments", with: "#pragma arguments\ntexture2d<float> scannedCloth;")
                        surface = surface.replacingOccurrences(of: "_surface.diffuse.rgb *= clothFiber;", with: "")
                        surface += """

                        constexpr sampler clothSampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
                        float2 clothUV = contactWorld.xz / 0.3;
                        float3 scannedColor = scannedCloth.sample(clothSampler, clothUV).rgb;
                        float scannedValue = dot(scannedColor, float3(0.2126,0.7152,0.0722)) / 0.2257850666;
                        _surface.diffuse.rgb *= scannedValue;
                        """
                        modifiers[.surface] = surface
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(variant)-\(view)")
            }
        }
    }

    func testClothUVPhysicalScale() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let s = try scene(mobile: true)
        let bedY = try XCTUnwrap(MobileClothAlignment.measuredBedY(in: s))
        var groups: [[String: Any]] = []
        var nodes: [SCNNode] = []
        s.tableNode?.enumerateChildNodes { node, _ in
            if node.geometry?.materials.contains(where: { $0.name == "TaiNi" }) == true { nodes.append(node) }
        }
        for node in nodes {
            guard let geometry = node.geometry,
                  let positionIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }),
                  let uvIndex = geometry.sources.firstIndex(where: { $0.semantic == .texcoord }) else { continue }
            let positions = geometry.sources[positionIndex], uv = geometry.sources[uvIndex]
            XCTAssertEqual(positions.bytesPerComponent, 4)
            XCTAssertEqual(uv.bytesPerComponent, 4)
            let positionChannel = geometry.geometrySourceChannels?[positionIndex].intValue ?? 0
            let uvChannel = geometry.geometrySourceChannels?[uvIndex].intValue ?? 0
            func value(_ source: SCNGeometrySource, _ index: Int, _ component: Int) -> Float {
                source.data.withUnsafeBytes { bytes in
                    bytes.loadUnaligned(fromByteOffset: source.dataOffset + index * source.dataStride + component * 4, as: Float.self)
                }
            }
            for (elementIndex, element) in geometry.elements.enumerated() where geometry.materials[elementIndex % geometry.materials.count].name == "TaiNi" {
                for (faceIndex, face) in try PocketLeatherMesh.decode(element).enumerated() {
                    var rows: [[Float]] = []
                    for offset in stride(from: 0, to: face.count, by: element.indicesChannelCount) {
                        let pi = Int(face[offset + positionChannel]), ti = Int(face[offset + uvChannel])
                        let local = SCNVector3(value(positions,pi,0),value(positions,pi,1),value(positions,pi,2))
                        let world = node.convertPosition(local, to: nil)
                        rows.append([world.x,world.y,world.z,value(uv,ti,0),value(uv,ti,1)])
                    }
                    if rows.allSatisfy({ abs($0[1] - bedY) < 0.00001 }) {
                        groups.append(["node":node.name ?? "", "face":faceIndex, "positionChannel":positionChannel, "uvChannel":uvChannel, "rows":rows])
                    }
                }
            }
        }
        XCTAssertFalse(groups.isEmpty)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: groups, options: [.prettyPrinted,.sortedKeys]).write(to: directory.appendingPathComponent("uv-world.json"))
    }

    func testScannedClothMaterial() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let diffuse = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("Diffuse.jpg").path))
        let normal = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("nor_gl.png").path))
        let roughness = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("Rough.png").path))
        for variant in ["current", "scanned"] {
            let s = try scene(mobile: true)
            if variant == "scanned" {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        material.diffuse.contents = diffuse
                        material.normal.contents = normal
                        material.normal.intensity = 1
                        material.roughness.contents = roughness
                        for property in [material.diffuse,material.normal,material.roughness] {
                            property.wrapS = .repeat
                            property.wrapT = .repeat
                            property.contentsTransform = SCNMatrix4MakeScale(1.4927868539218498, 1.4927868539218498, 1)
                        }
                        var modifiers = material.shaderModifiers ?? [:]
                        let surface = modifiers[.surface] ?? ""
                        modifiers[.surface] = surface.replacingOccurrences(of: "_surface.diffuse.rgb *= clothFiber;", with: "float scannedLuminance = dot(_surface.diffuse.rgb, float3(0.2126,0.7152,0.0722)) / 0.2257850666; _surface.diffuse.rgb = float3(0.011645430905844125,0.13286832155381798,0.06838485415816624) * scannedLuminance;")
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(variant)-\(view)")
            }
        }
    }

    func testScannedNormalColorMetadata() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let diffuse = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("Diffuse.jpg").path))
        let normal = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("nor_gl.png").path))
        let roughness = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("Rough.png").path))
        for variant in ["current", "tagged", "untagged-normal", "untagged-both"] {
            let s = try scene(mobile: true)
            if variant != "current" {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        material.diffuse.contents = diffuse
                        material.normal.contents = variant == "tagged" ? normal : UIImage(contentsOfFile: directory.appendingPathComponent("untagged-nor_gl.png").path)
                        material.normal.intensity = 1
                        material.roughness.contents = variant == "untagged-both" ? UIImage(contentsOfFile: directory.appendingPathComponent("untagged-Rough.png").path) : roughness
                        for property in [material.diffuse,material.normal,material.roughness] {
                            property.wrapS = .repeat
                            property.wrapT = .repeat
                            property.contentsTransform = SCNMatrix4MakeScale(1.4927868539218498, 1.4927868539218498, 1)
                        }
                        var modifiers = material.shaderModifiers ?? [:]
                        let surface = modifiers[.surface] ?? ""
                        modifiers[.surface] = surface.replacingOccurrences(of: "_surface.diffuse.rgb *= clothFiber;", with: "float scannedLuminance = dot(_surface.diffuse.rgb, float3(0.2126,0.7152,0.0722)) / 0.2257850666; _surface.diffuse.rgb = float3(0.011645430905844125,0.13286832155381798,0.06838485415816624) * scannedLuminance;")
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(variant)-\(view)")
            }
        }
    }

    func testScannedClothChannelIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let diffuse = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("Diffuse.jpg").path))
        let normal = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("nor_gl.png").path))
        let roughness = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("Rough.png").path))
        for variant in ["current", "diffuse", "normal", "roughness", "scanned"] {
            let s = try scene(mobile: true)
            if variant != "current" {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        material.diffuse.contents = diffuse
                        var replaced = [material.diffuse]
                        if variant == "normal" || variant == "scanned" {
                            material.normal.contents = normal
                            material.normal.intensity = 1
                            replaced.append(material.normal)
                        }
                        if variant == "roughness" || variant == "scanned" {
                            material.roughness.contents = roughness
                            replaced.append(material.roughness)
                        }
                        for property in replaced {
                            property.wrapS = .repeat
                            property.wrapT = .repeat
                            property.contentsTransform = SCNMatrix4MakeScale(1.4927868539218498, 1.4927868539218498, 1)
                        }
                        var modifiers = material.shaderModifiers ?? [:]
                        let surface = modifiers[.surface] ?? ""
                        modifiers[.surface] = surface.replacingOccurrences(of: "_surface.diffuse.rgb *= clothFiber;", with: "float scannedLuminance = dot(_surface.diffuse.rgb, float3(0.2126,0.7152,0.0722)) / 0.2257850666; _surface.diffuse.rgb = float3(0.011645430905844125,0.13286832155381798,0.06838485415816624) * scannedLuminance;")
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(variant)-\(view)")
            }
        }
    }

    /// S137 numeric diagnostic only: disable camera postprocessing to measure IBL.
    func testEnvironmentDiffuseNumericalCapture() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for variant in ["full", "black", "normal", "calibration"] {
            let s = try scene(mobile: true)
            s.cameraNode.camera?.wantsHDR = false
            s.cameraNode.camera?.exposureOffset = 0
            s.rootNode.enumerateChildNodes { node, _ in node.light?.intensity = 0 }
            materials(s) { material in
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = "#pragma body\n_surface.diffuse.rgb = float3(\(variant == "black" ? "0.0" : "0.5"));"
                if variant == "normal" {
                    modifiers[.fragment] = "#pragma body\n_output.color.rgb = normalize((scn_frame.inverseViewTransform * float4(_surface.normal, 0)).xyz) * 0.5 + 0.5;"
                } else if variant == "calibration" {
                    modifiers[.fragment] = "#pragma body\n_output.color.rgb = float3(0.25);"
                } else {
                    modifiers[.fragment] = "#pragma body\n_output.color.rgb /= 4.0;"
                }
                material.shaderModifiers = modifiers
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(variant)")
        }
    }

    func testExplicitCubeReflectionProbe() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        // World XZ horizontal, Y up, metres. The box describes a virtual
        // reflection volume only; scene geometry and the black background stay fixed.
        for name in ["current", "probe", "parallax", "narrow"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let light = SCNLight()
                light.type = .probe
                light.probeType = .radiance
                light.probeUpdateType = .never
                light.probeExtents = SIMD3<Float>(6, 4, 4)
                light.probeOffset = .zero
                light.parallaxCorrectionEnabled = name != "probe"
                light.parallaxExtentsFactor = SIMD3<Float>(repeating: 1)
                let property = try XCTUnwrap(light.probeEnvironment)
                property.contents = try diagnosticCubeTexture(name: name == "narrow" ? "narrow" : "original")
                property.intensity = 0.7
                let node = SCNNode()
                node.name = "S108StaticReflectionProbe"
                node.light = light
                node.position = SCNVector3(0, s.surfaceY + 1.0, 0)
                s.rootNode.addChildNode(node)
                XCTAssertEqual(light.probeUpdateType, .never)
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testStaticLocalReflectionProbe() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        // World XZ horizontal, Y up, metres. The box describes a virtual
        // reflection volume only; scene geometry and the black background stay fixed.
        for name in ["current", "probe", "parallax", "narrow"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let light = SCNLight()
                light.type = .probe
                light.probeType = .radiance
                light.probeUpdateType = .never
                light.probeExtents = SIMD3<Float>(6, 4, 4)
                light.probeOffset = .zero
                light.parallaxCorrectionEnabled = name != "probe"
                light.parallaxExtentsFactor = SIMD3<Float>(repeating: 1)
                let property = try XCTUnwrap(light.probeEnvironment)
                property.contents = name == "narrow" ? directory.appendingPathComponent("narrow.hdr") : try XCTUnwrap(MobileTableRendering.environmentURL)
                property.intensity = 0.7
                let node = SCNNode()
                node.name = "S108StaticReflectionProbe"
                node.light = light
                node.position = SCNVector3(0, s.surfaceY + 1.0, 0)
                s.rootNode.addChildNode(node)
                XCTAssertEqual(light.probeUpdateType, .never)
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testFiniteAreaKeyIntensityRange() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        // Preserve the existing key's position and downward -Z orientation.
        // World XZ horizontal / Y up / metres. Shape is invisible to the camera.
        for (name, intensity) in [("current", 8.0), ("area800", 800.0), ("area2400", 2400.0), ("area8000", 8000.0)] {
            let s = try scene(mobile: true)
            if name != "current" {
                s.rootNode.enumerateChildNodes { node, _ in
                    guard let light = node.light, light.castsShadow else { return }
                    light.type = .area
                    light.areaType = .rectangle
                    light.areaExtents = SIMD3<Float>(2, 0.4, 0)
                    light.drawsArea = true
                    light.doubleSided = true
                    light.attenuationEndDistance = 10
                    light.doubleSided = false
                    light.intensity = CGFloat(intensity)
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testAreaSourcePlainMaterialIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, type) in [("off", SCNLight.LightType.area), ("area", .area), ("spot", .spot), ("omni", .omni)] {
            let s = try scene(mobile: true)
            s.lightingEnvironment.contents = nil
            s.lightingEnvironment.intensity = 0
            s.rootNode.enumerateChildNodes { node, _ in
                if let light = node.light {
                    if light.castsShadow {
                        light.castsShadow = false
                        light.type = type
                        light.intensity = name == "off" ? 0 : 2000
                        light.areaType = .rectangle
                        light.areaExtents = SIMD3<Float>(2, 0.4, 1)
                        light.drawsArea = true
                    light.doubleSided = true
                    light.attenuationEndDistance = 10
                        light.doubleSided = true
                    } else { light.intensity = 0 }
                }
                for material in node.geometry?.materials ?? [] {
                    material.shaderModifiers = nil
                    material.lightingModel = .physicallyBased
                    material.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                    material.multiply.contents = UIColor.white
                    material.normal.contents = nil
                    material.roughness.contents = Float(0.3)
                    material.metalness.contents = Float(0)
                    material.emission.contents = UIColor.black
                    material.ambientOcclusion.contents = UIColor.white
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testAreaSourceShadowIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        // Preserve the existing key's position and downward -Z orientation.
        // World XZ horizontal / Y up / metres. Shape is invisible to the camera.
        for (name, intensity) in [("current", 8.0), ("shadowed", 8000.0), ("unshadowed", 8000.0), ("two-sided", 8000.0)] {
            let s = try scene(mobile: true)
            if name != "current" {
                s.rootNode.enumerateChildNodes { node, _ in
                    guard let light = node.light, light.castsShadow else { return }
                    light.type = .area
                    light.areaType = .rectangle
                    light.areaExtents = SIMD3<Float>(2, 0.4, 0)
                    light.drawsArea = true
                    light.doubleSided = true
                    light.attenuationEndDistance = 10
                    light.doubleSided = name == "two-sided"
                    light.castsShadow = name == "shadowed"
                    light.intensity = CGFloat(intensity)
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testAreaSourceCalibratedRange() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        // Preserve the existing key's position and downward -Z orientation.
        // World XZ horizontal / Y up / metres. Shape is invisible to the camera.
        for (name, intensity) in [("current", 8.0), ("area30000", 30000.0), ("area100000", 100000.0), ("area300000", 300000.0)] {
            let s = try scene(mobile: true)
            if name != "current" {
                s.rootNode.enumerateChildNodes { node, _ in
                    guard let light = node.light, light.castsShadow else { return }
                    light.type = .area
                    light.areaType = .rectangle
                    light.areaExtents = SIMD3<Float>(2, 0.4, 0)
                    light.drawsArea = true
                    light.doubleSided = true
                    light.attenuationEndDistance = 10
                    light.doubleSided = false
                    light.intensity = CGFloat(intensity)
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testBrightnessMatchedAreaSource() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        // Preserve the existing key's position and downward -Z orientation.
        // World XZ horizontal / Y up / metres. Shape is invisible to the camera.
        for (name, intensity) in [("current", 8.0), ("area10000", 10000.0), ("cross10000", 10000.0)] {
            let s = try scene(mobile: true)
            if name != "current" {
                s.rootNode.enumerateChildNodes { node, _ in
                    guard let light = node.light, light.castsShadow else { return }
                    light.type = .area
                    light.areaType = .rectangle
                    light.areaExtents = name == "cross10000" ? SIMD3<Float>(0.4, 2, 0) : SIMD3<Float>(2, 0.4, 0)
                    light.drawsArea = true
                    light.doubleSided = true
                    light.attenuationEndDistance = 10
                    light.doubleSided = false
                    light.intensity = CGFloat(intensity)
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testFiniteAreaKeySource() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        // Preserve the existing key's position and downward -Z orientation.
        // World XZ horizontal / Y up / metres. Shape is invisible to the camera.
        for (name, intensity) in [("current", 8.0), ("area8", 8.0), ("area24", 24.0), ("area80", 80.0)] {
            let s = try scene(mobile: true)
            if name != "current" {
                s.rootNode.enumerateChildNodes { node, _ in
                    guard let light = node.light, light.castsShadow else { return }
                    light.type = .area
                    light.areaType = .rectangle
                    light.areaExtents = SIMD3<Float>(2, 0.4, 0)
                    light.drawsArea = true
                    light.doubleSided = true
                    light.attenuationEndDistance = 10
                    light.doubleSided = false
                    light.intensity = CGFloat(intensity)
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testOrientedScannedRailAlbedo() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let texture = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("wood-rotated.png").path))
        XCTAssertEqual(texture.cgImage?.width, 1024)
        XCTAssertEqual(texture.cgImage?.height, 1024)
        for name in ["current", "scan", "matched"] {
            let s = try scene(mobile: true)
            if name != "current" {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "BlackWood" {
                        material.diffuse.contents = texture
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = name == "matched" ? """
                        #pragma body
                        _surface.diffuse.rgb *= float3(0.796942509,1.658398317,2.352739275);
                        """ : "#pragma body\n"
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testScannedRailAlbedo() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let texture = try XCTUnwrap(UIImage(contentsOfFile: directory.appendingPathComponent("wood.jpg").path))
        XCTAssertEqual(texture.cgImage?.width, 1024)
        XCTAssertEqual(texture.cgImage?.height, 1024)
        for name in ["current", "scan", "matched"] {
            let s = try scene(mobile: true)
            if name != "current" {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "BlackWood" {
                        material.diffuse.contents = texture
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = name == "matched" ? """
                        #pragma body
                        _surface.diffuse.rgb *= float3(0.796942509,1.658398317,2.352739275);
                        """ : "#pragma body\n"
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testWoodAlbedoSuppression() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, blend) in [("current", 0.0), ("half", 0.5), ("original-albedo", 1.0)] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where ["Wood", "BlackWood"].contains(material.name ?? "") {
                    // Both candidate wood materials already share the smoother Wood
                    // texture. Vary only the albedo suppression, not UVs or normals.
                    let oldExpression = material.name == "BlackWood"
                        ? "_surface.diffuse.rgb * float3(0.35407753,0.41952911,0.38761742)"
                        : "mix(float3(0.045,0.023,0.012), _surface.diffuse.rgb, 0.5)"
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.surface] = """
                    #pragma body
                    _surface.diffuse.rgb = mix(\(oldExpression), _surface.diffuse.rgb, \(blend));
                    """
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testNarrowEnvironmentRailResponse() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, roughness) in [("current", 0.24), ("narrow", 0.24), ("polished", 0.12), ("satin", 0.38)] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("narrow.hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where ["Wood", "BlackWood"].contains(material.name ?? "") {
                    material.roughness.contents = Float(roughness)
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testPhotographicStudioEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "studio", "studio90"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testBilliardHallEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "hall", "hall90"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testWarmBarEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "bar", "bar90"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testNeutralBarEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "bar", "bar90"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testBallSpecularResponseControl() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        // Diagnostic: establish whether SceneKit PBR exposes dielectric response
        // through the surface specular field before designing a production change.
        for (name, strength) in [("current", -1.0), ("zero", 0.0), ("double", 2.0), ("quad", 4.0)] {
            let s = try scene(mobile: true)
            if strength >= 0 {
                materials(s) { material in
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.surface] = "#pragma body\n_surface.specular.rgb *= \(strength);"
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testMomentMatchedEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "matched", "matched90"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testAchromaticBarEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "bar", "bar90"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testRowMatchedStudioEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "matched", "matched90"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testLowAngleEnvironmentPanels() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "low3", "low8"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testStructuredEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for name in ["current", "walls4", "walls8"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let url = directory.appendingPathComponent("\(name).hdr")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
                s.lightingEnvironment.contents = url
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testUpperRailFinish() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, roughness) in [("current", 0.24), ("polished", 0.12), ("satin", 0.38)] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == "BlackWood" {
                    material.roughness.contents = Float(roughness)
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testRailNormalAudit() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let s = try scene(mobile: true)
        var rows: [[String: Any]] = []
        s.tableNode?.enumerateChildNodes { node, _ in
            guard let g = node.geometry,
                  let positions = g.sources(for: .vertex).first,
                  let normals = g.sources(for: .normal).first,
                  positions.bytesPerComponent == 4, normals.bytesPerComponent == 4,
                  positions.usesFloatComponents, normals.usesFloatComponents else { return }
            let pc = g.geometrySourceChannels?[g.sources.firstIndex(of: positions) ?? 0].intValue ?? 0
            let nc = g.geometrySourceChannels?[g.sources.firstIndex(of: normals) ?? 0].intValue ?? 0
            let normalMatrix = simd_transpose(simd_inverse(node.simdWorldTransform))
            func read(_ source: SCNGeometrySource, _ index: Int) -> SIMD3<Float> {
                source.data.withUnsafeBytes { bytes in
                    let offset = source.dataOffset + index * source.dataStride
                    return SIMD3(bytes.loadUnaligned(fromByteOffset: offset, as: Float.self),
                                 bytes.loadUnaligned(fromByteOffset: offset+4, as: Float.self),
                                 bytes.loadUnaligned(fromByteOffset: offset+8, as: Float.self))
                }
            }
            for (index, element) in g.elements.enumerated() {
                guard !g.materials.isEmpty else { continue }
                let name = g.materials[index % g.materials.count].name ?? ""
                guard ["Wood", "BlackWood"].contains(name) else { continue }
                do {
                    for face in try PocketLeatherMesh.decode(element) {
                        var points: [[Float]] = [], directions: [[Float]] = []
                        for offset in stride(from: 0, to: face.count, by: element.indicesChannelCount) {
                            let p = read(positions, Int(face[offset+pc]))
                            let world = node.simdWorldTransform * SIMD4(p.x,p.y,p.z,1)
                            let n = read(normals, Int(face[offset+nc]))
                            let transformed = normalMatrix * SIMD4(n.x,n.y,n.z,0)
                            let unit = simd_normalize(SIMD3(transformed.x,transformed.y,transformed.z))
                            points.append([world.x,world.y,world.z]); directions.append([unit.x,unit.y,unit.z])
                        }
                        if points.contains(where: { $0[1] > 0.78 }) {
                            rows.append(["material":name,"points":points,"normals":directions])
                        }
                    }
                } catch { XCTFail("Rail mesh decode failed: \(error)") }
            }
        }
        XCTAssertFalse(rows.isEmpty)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: rows).write(to: directory.appendingPathComponent("rail-faces.json"))
        try capture(s, name: "current")
    }

    func testNativeBallCoatPalette() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, coat) in [("current", 0.0), ("coat50", 0.5)] {
            let s = try scene(mobile: true)
            let y = s.surfaceY + AngleSceneCalculator.ballRadius
            for (index, key) in s.allBallNodes.keys.sorted().enumerated() {
                s.showBall(key: key, scenePosition: SCNVector3(Float(index / 4) * 0.20 - 0.30, y, Float(index % 4) * 0.18 - 0.27))
            }
            materials(s) { material in
                material.clearCoat.contents = Float(coat)
                material.clearCoatRoughness.contents = Float(0.04)
            }
            for angle in 0..<4 {
                if angle > 0 { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-angle\(angle)")
            }
        }
    }

    func testNativeBallCoat() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, coat) in [("current", 0.0), ("coat50", 0.5), ("coat100", 1.0)] {
            let s = try scene(mobile: true)
            materials(s) { material in
                print("BALL_COAT", name, String(describing: material.clearCoat.contents), String(describing: material.clearCoatRoughness.contents))
                if coat > 0 {
                    material.clearCoat.contents = Float(coat)
                    material.clearCoatRoughness.contents = Float(0.04)
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testCurrentHighlightCompressionAblation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, strength) in [("s95", 0.4), ("uncompressed", 0.0)] {
            let s = try scene(mobile: true)
            materials(s) { material in
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.fragment] = """
                #pragma body
                float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                _output.color.rgb /= 1.0 + \(strength) * max(0.0, ballPeak - 0.4);
                """
                material.shaderModifiers = modifiers
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testBallHighlightShoulder() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, strength) in [("current", 0.0), ("soft40", 0.4), ("soft80", 0.8)] {
            let s = try scene(mobile: true)
            materials(s) { material in
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.fragment] = """
                #pragma body
                float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                _output.color.rgb /= 1.0 + \(strength) * max(0.0, ballPeak - 0.4);
                """
                material.shaderModifiers = modifiers
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testBallShoulderPalette() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, strength) in [("current", 0.0), ("soft40", 0.4)] {
            let s = try scene(mobile: true)
            let y = s.surfaceY + AngleSceneCalculator.ballRadius
            for (index, key) in s.allBallNodes.keys.sorted().enumerated() {
                s.showBall(key: key, scenePosition: SCNVector3(Float(index / 4) * 0.20 - 0.30, y, Float(index % 4) * 0.18 - 0.27))
            }
            materials(s) { material in
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.fragment] = """
                #pragma body
                float ballPeak = max(_output.color.r, max(_output.color.g, _output.color.b));
                _output.color.rgb /= 1.0 + \(strength) * max(0.0, ballPeak - 0.4);
                """
                material.shaderModifiers = modifiers
            }
            for angle in 0..<4 {
                if angle > 0 { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-angle\(angle)")
            }
        }
    }

    func testBallLinearBaseColorAblation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit diagnostic run")
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try XCTUnwrap(device.makeCommandQueue())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func raw(_ scene: SCNScene, camera: SCNNode, name: String, width: Int = 1176, height: Int = 2000) throws -> [UInt16] {
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene; renderer.pointOfView = camera; renderer.autoenablesDefaultLighting = false
            if let training = scene as? AngleTrainingScene { renderer.delegate = training.contactOcclusion }
            let cd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
            cd.usage = [.renderTarget, .shaderRead]; cd.storageMode = .shared
            let color = try XCTUnwrap(device.makeTexture(descriptor: cd))
            let dd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
            dd.usage = .renderTarget; dd.storageMode = .private
            let depth = try XCTUnwrap(device.makeTexture(descriptor: dd))
            for _ in 0..<2 {
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = color
                pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
                pass.depthAttachment.texture = depth; pass.depthAttachment.loadAction = .clear
                pass.depthAttachment.storeAction = .dontCare; pass.depthAttachment.clearDepth = 1
                let command = try XCTUnwrap(queue.makeCommandBuffer())
                renderer.render(atTime: 0, viewport: CGRect(x: 0,y: 0,width: width,height: height), commandBuffer: command, passDescriptor: pass)
                command.commit(); command.waitUntilCompleted()
                XCTAssertEqual(command.status, .completed, String(describing: command.error))
            }
            var values = [UInt16](repeating: 0, count: width*height*4)
            values.withUnsafeMutableBytes { color.getBytes($0.baseAddress!, bytesPerRow: width*8, from: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0) }
            if name == "entry" {
                XCTAssertTrue(values.allSatisfy { Float16(bitPattern: $0).isFinite }, "Current scene must not emit non-finite linear HDR pixels")
            }
            try values.withUnsafeBytes { Data($0) }.write(to: directory.appendingPathComponent(name + ".rgba16f"))
            return values
        }

        for variant in ["current", "uncompressed", "zeroBase"] {
            let s = try scene(mobile: true)
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            if variant != "current" {
                materials(s) { m in
                    var modifiers = m.shaderModifiers ?? [:]
                    modifiers.removeValue(forKey: .fragment)
                    if variant == "zeroBase" {
                        modifiers[.surface] = "#pragma body\n_surface.diffuse.rgb = float3(0);"
                    }
                    m.shaderModifiers = modifiers
                }
            }
            try capture(s, name: variant)
            _ = try raw(s, camera: s.cameraNode, name: variant)
        }
    }

    func testBallBaseResponseFit() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for variant in ["current", "baseFit"] {
            let s = try scene(mobile: true)
            if variant == "baseFit" {
                materials(s) { m in
                    var modifiers = m.shaderModifiers ?? [:]
                    modifiers.removeValue(forKey: .fragment)
                    modifiers[.surface] = "#pragma body\n_surface.diffuse.rgb *= 0.7587012229247322;"
                    m.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testReferencePresentedFrames() async throws {
        try await captureReferencePresentedFrames(requestedFPS: 60)
    }

    func testReferencePresentedFrames120() async throws {
        try await captureReferencePresentedFrames(requestedFPS: 120)
    }

    func testReferenceCostWithoutBallShading() async throws {
        try await captureReferencePresentedFrames(requestedFPS: 120, component: "without-ball-shading")
    }

    func testReferenceCostWithoutClothShading() async throws {
        try await captureReferencePresentedFrames(requestedFPS: 120, component: "without-cloth-shading")
    }

    func testReferencePresentedFrames120Precomputed() async throws {
        try await captureReferencePresentedFrames(requestedFPS: 120, component: "precomputed-balls")
    }

    func testReferencePresentedFrames120AA2() async throws {
        try await captureReferencePresentedFrames(requestedFPS: 120, component: "aa2")
    }

    func testReferenceMixed120() async throws {
        try await captureReferencePresentedFrames(requestedFPS: 120, component: "mixed", duration: 120)
    }

    func testReferenceSustained120() async throws {
        try await captureReferencePresentedFrames(requestedFPS: 120, duration: 60)
    }

    private func captureReferencePresentedFrames(requestedFPS: Int, component: String = "full", duration: Double? = nil) async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical-device presentation probe only")
        #else
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil,"Explicit device probe")
        try XCTSkipUnless(ProcessInfo.processInfo.thermalState == .nominal, "Cool device required before presentation probe")
        let device=try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let window=try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow))
        let s=try scene(mobile:true);MobileReferenceLighting.apply(to:s)
        for (i,key) in s.allBallNodes.keys.sorted().enumerated() {
            guard let node=s.allBallNodes[key] else { continue }
            node.isHidden=false;node.opacity=1
            node.position=SCNVector3(-0.6+Float(i/4)*0.4,s.surfaceY+AngleSceneCalculator.ballRadius,-0.3+Float(i%4)*0.2)
        }
        if component == "precomputed-balls" { precomputeBallSamples(s) }
        if component == "without-ball-shading" {
            materials(s) { m in m.shaderModifiers = nil; m.lightingModel = .constant }
        }
        if component == "without-cloth-shading" {
            s.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    m.shaderModifiers = nil; m.lightingModel = .constant
                }
            }
        }
        let view=MTKView(frame:window.bounds,device:device)
        view.colorPixelFormat = .bgra8Unorm_srgb;view.depthStencilPixelFormat = .depth32Float_stencil8
        view.sampleCount=component == "aa2" ? 2 : 4;view.framebufferOnly=false;view.preferredFramesPerSecond=min(requestedFPS, window.screen.maximumFramesPerSecond)
        let probe=ReferenceFrameProbe(scene:s,device:device);probe.mixedActivity = component == "mixed";view.delegate=probe
        window.addSubview(view)
        defer { view.isPaused=true;view.delegate=nil;view.removeFromSuperview() }
        let thermalStart=ProcessInfo.processInfo.thermalState.rawValue
        let deadline = CACurrentMediaTime() + (duration ?? (requestedFPS == 120 ? 10 : 25))
        probe.stopAt = deadline
        while CACurrentMediaTime() < deadline { try await Task.sleep(nanoseconds:250_000_000) }
        view.isPaused=true
        try await Task.sleep(nanoseconds:500_000_000)
        let rows=probe.samples.snapshot()
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let report:[String:Any]=["runID":UUID().uuidString,"recordedAt":Date().timeIntervalSince1970,"sampleCount":view.sampleCount,"durationRequested":duration ?? (requestedFPS == 120 ? 10 : 25),"component":component,"areaDiffuse":"analytic","requestedFPS":requestedFPS,"screenMaximumFPS":window.screen.maximumFramesPerSecond,"frames":rows,"width":view.drawableSize.width,"height":view.drawableSize.height,
            "thermalStart":thermalStart,"thermalEnd":ProcessInfo.processInfo.thermalState.rawValue,
            "note":"Physical MTKView presented frames with production scene and moving camera; not full training UI or 20-minute acceptance."]
        let reportData=try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted)
        try reportData.write(to:directory.appendingPathComponent(component == "full" ? "presented-frames.json" : "presented-\(component).json"))
        let attachment=XCTAttachment(data:reportData,uniformTypeIdentifier:"public.json")
        attachment.name="presented-frames";attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThan(rows.filter { ($0["presented"] ?? 0)>0 }.count,300)
        XCTAssertEqual(rows.filter { ($0["error"] ?? 0)>0 }.count,0)
        #endif
    }

    private func precomputeBallSamples(_ s: AngleTrainingScene) {
        let alpha = Float(MobileReferenceLighting.ballRoughness * MobileReferenceLighting.ballRoughness)
        let samples = (0..<64).map { i -> String in
            let u = (Float(i) + 0.5) / 64
            let phase = Float(i) * Float(0.61803398875)
            let phi = Float(6.2831853) * (phase - floor(phase))
            let ct = sqrt((1-u)/(1+(alpha*alpha-1)*u))
            let st = sqrt(max(0,1-ct*ct))
            return "float3(\(cos(phi)*st),\(sin(phi)*st),\(ct))"
        }.joined(separator: ",")
            var changed = 0
                for node in s.allBallNodes.values {
                    var children = [node]
                    node.enumerateChildNodes { child, _ in children.append(child) }
                    for child in children {
                        for m in child.geometry?.materials ?? [] {
                            guard var shader = m.shaderModifiers?[.surface], let start = shader.range(of: "float u=(float(i)+0.5)/64.0;"), let end = shader.range(of: "float vh=max(0.0,dot(v,h));") else { continue }
                            shader.replaceSubrange(start.lowerBound..<end.lowerBound, with: "float3 sample=v62Samples[i]; float ct=sample.z; float3 h=normalize(tangent*sample.x+bitangent*sample.y+n*sample.z);\n")
                            shader = shader.replacingOccurrences(of: "for(int i=0;i<64;++i)", with: "const float3 v62Samples[64]={\(samples)};\nfor(int i=0;i<64;++i)")
                            m.shaderModifiers?[.surface] = shader
                            changed += 1
                        }
                    }
                }
            XCTAssertGreaterThan(changed, 0, "Must modify actual ball programs")
    }

    func testReferenceBallSamplePrecomputation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit ball sample comparison")
        for precomputed in [false, true] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if precomputed { precomputeBallSamples(s) }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(precomputed ? "precomputed" : "reference")-\(pose)")
            }
        }
    }

    func testReferenceHighlightHeadroom() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit integrated output comparison")
        let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
        let ball = try XCTUnwrap(s.cueBallNode)
        let before = ball.geometry?.firstMaterial?.shaderModifiers
        MobileReferenceLighting.applyBall(to: ball, exposureOffset: s.cameraNode.camera?.exposureOffset ?? 0)
        XCTAssertEqual(ball.geometry?.firstMaterial?.shaderModifiers, before)
        var mapped = 0
        s.rootNode.enumerateChildNodes { node, _ in
            for m in node.geometry?.materials ?? [] {
                if let shader = m.shaderModifiers?[.fragment], shader.contains("// v62HighlightHeadroom") {
                    XCTAssertEqual(shader.components(separatedBy: "// v62HighlightHeadroom").count, 2)
                    mapped += 1
                }
            }
        }
        XCTAssertGreaterThan(mapped, 0)
        for pose in ["entry", "detail", "orbit"] {
            if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
            if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "headroom-\(pose)")
        }
    }

    func testReferenceDiffuseWood() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit matte wood transfer")
        for unified in [false, true] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if !unified {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where ["Wood", "BlackWood"].contains(m.name ?? "") {
                        m.lightingModel = .physicallyBased
                        m.shaderModifiers?[.surface] = nil
                        m.shaderModifiers?[.fragment] = m.shaderModifiers?[.fragment]?.replacingOccurrences(of: "#pragma body", with: "#pragma body\n_output.color.rgb=max(float3(0.0),_output.color.rgb-_lightingContribution.specular);")
                    }
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(unified ? "unified" : "native")-\(pose)")
            }
        }
    }

    func testReferenceCullingSameRenderer() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit same-renderer culling regression")
        let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
        for (i, key) in s.allBallNodes.keys.sorted().enumerated() {
            guard let node = s.allBallNodes[key] else { continue }
            node.isHidden = false; node.opacity = 1
            node.position = SCNVector3(-0.6+Float(i/4)*0.4,s.surfaceY+AngleSceneCalculator.ballRadius,-0.3+Float(i%4)*0.2)
        }
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = s; renderer.pointOfView = s.cameraNode; renderer.delegate = s.contactOcclusion
        renderer.autoenablesDefaultLighting = false
        var cloth: [(SCNMaterial, String)] = []
        s.tableNode?.enumerateChildNodes { node, _ in
            for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                if let source = m.shaderModifiers?[.surface] { cloth.append((m, source)) }
            }
        }
        XCTAssertFalse(cloth.isEmpty)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for pose in ["entry", "detail", "orbit"] {
            if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
            if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            var pictures: [Data] = []
            for (index, cull) in [false, true, false].enumerated() {
                for (m, source) in cloth { m.shaderModifiers?[.surface] = cull ? source : source.replacingOccurrences(of: "if(shadowPossible)", with: "if(true)") }
                SCNTransaction.flush()
                for _ in 0..<3 { _ = renderer.snapshot(atTime: 0, with: CGSize(width: 1176,height: 2000), antialiasingMode: .multisampling4X) }
                let shot = renderer.snapshot(atTime: 0, with: CGSize(width: 1176,height: 2000), antialiasingMode: .multisampling4X)
                let data = try XCTUnwrap(shot.pngData()); pictures.append(data)
                try data.write(to: directory.appendingPathComponent("same-\(pose)-\(index).png"))
            }
            XCTAssertEqual(pictures[0], pictures[1], "Full vs culled, " + pose)
            XCTAssertEqual(pictures[0], pictures[2], "Full must repeat identically, " + pose)
        }
    }

    func testReferenceResinContactIntegrated() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit final visual regression")
        for baseline in [true, false] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if baseline {
                materials(s) { m in
                    m.shaderModifiers?[.surface] = m.shaderModifiers?[.surface]?.replacingOccurrences(of: "float roughness=\(MobileReferenceLighting.ballRoughness);", with: "float roughness=0.24;")
                }
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                        for i in 0..<s.allBallNodes.count {
                            m.shaderModifiers?[.surface] = m.shaderModifiers?[.surface]?.replacingOccurrences(of: "(contactBall\(i).w / 0.85)", with: "contactBall\(i).w")
                        }
                    }
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(baseline ? "before" : "after")-\(pose)")
            }
        }
    }

    func testReferenceContactOpacity() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit ambient contact comparison")
        for opaque in [false, true] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if !opaque {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                        for i in 0..<s.allBallNodes.count {
                            m.shaderModifiers?[.surface] = m.shaderModifiers?[.surface]?.replacingOccurrences(of: "(contactBall\(i).w / 0.85)", with: "contactBall\(i).w")
                        }
                    }
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(opaque ? "opaque" : "reference")-\(pose)")
            }
        }
    }

    func testReferenceResinRoughness() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit resin comparison")
        for roughness in [0.24, 0.30, 0.36] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            materials(s) { m in
                guard let source = m.shaderModifiers?[.surface] else { XCTFail("Missing ball shader"); return }
                XCTAssertTrue(source.contains("float roughness=\(MobileReferenceLighting.ballRoughness);"))
                m.shaderModifiers?[.surface] = source.replacingOccurrences(of: "float roughness=\(MobileReferenceLighting.ballRoughness);", with: "float roughness=\(roughness);")
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "resin-\(roughness)-\(pose)")
            }
        }
    }

    func testReferenceBroadEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit same-energy environment trial")
        for blend in [0.0, 0.5, 1.0] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            materials(s) { m in
                guard var source = m.shaderModifiers?[.surface] else { XCTFail("Missing ball shader"); return }
                let worldStart = source.range(of: "float v62World(float3 d)")!
                let worldEnd = source.range(of: "float3 v62Reflection(")!
                source.replaceSubrange(worldStart.lowerBound..<worldEnd.lowerBound, with: "float v62World(float3 d) { return mix(0.06+1.2*pow(1.0-abs(d.y),2.0),0.26,\(blend)); }\n")
                source = source.replacingOccurrences(of: "float3(v62worldIntegral(n.y))", with: "float3(mix(v62worldIntegral(n.y),0.13*(1.0+n.y),\(blend)))")
                m.shaderModifiers?[.surface] = source
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "broad-\(blend)-\(pose)")
            }
        }
    }

    func testReferenceDirectionalEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit directional environment trial")
        for directional in [false, true] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if directional {
                materials(s) { m in
                    guard var source = m.shaderModifiers?[.surface] else { XCTFail("Missing ball shader"); return }
                    source = source.replacingOccurrences(of: "float v62World(float3 d)", with: "float v62WorldDirectional(float x) { return ((((((((((((-2.076454092341501e-13*x+1.3513323442700642)*x+5.472566600093564e-13)*x+-3.0455609805230366)*x+-5.434761677512947e-13)*x+2.514576688318056)*x+2.572359244162185e-13)*x+-0.8770661057715977)*x+-5.958595522713467e-14)*x+0.14715318295317417)*x+5.120806073560081e-15)*x+0.04027981597082138)*x+0.14399938964517772); }\nfloat v62World(float3 d)")
                    source = source.replacingOccurrences(of: "pow(1.0-abs(d.y),2.0);", with: "pow(1.0-abs(d.y),2.0)*(1.0+0.8*d.x);")
                    source = source.replacingOccurrences(of: "float3(v62worldIntegral(n.y))", with: "float3(v62worldIntegral(n.y)+n.x*v62WorldDirectional(n.y))")
                    m.shaderModifiers?[.surface] = source
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(directional ? "directional" : "reference")-\(pose)")
            }
        }
    }

    func testReferenceResinEnvironmentBalance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit resin balance comparison")
        for mode in ["reference", "reflection", "balanced"] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if mode != "reference" {
                materials(s) { m in
                    guard var source = m.shaderModifiers?[.surface] else { XCTFail("Missing ball shader"); return }
                    let marker = "if (reflected.y>0.0001) {"
                    XCTAssertTrue(source.contains(marker))
                    source = source.replacingOccurrences(of: marker, with: "    result *= 0.35;\n" + marker)
                    if mode == "balanced" {
                        let diffuse = "*(1.0-F)+spec;"
                        XCTAssertTrue(source.contains(diffuse))
                        source = source.replacingOccurrences(of: diffuse, with: "*0.96+spec;")
                    }
                    m.shaderModifiers?[.surface] = source
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(mode)-\(pose)")
            }
        }
    }

    func testReferenceFilmIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit film diagnosis")
        for mode in ["reference", "no-environment-specular", "diffuse", "lambert"] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            materials(s) { m in
                guard var source = m.shaderModifiers?[.surface] else { XCTFail("Missing ball shader"); return }
                if mode == "no-environment-specular" {
                    source = source.replacingOccurrences(of: "float3 result=float3(v62World(reflected));", with: "float3 result=float3(0.0);")
                    source = source.replacingOccurrences(of: "result=clothRadiance*clamp(r2/(r2+0.028575*0.028575),0.0,1.0);", with: "result=float3(0.0);")
                }
                if mode == "diffuse" || mode == "lambert" {
                    source = source.replacingOccurrences(of: "*(1.0-F)+spec;", with: mode == "lambert" ? ";" : "*(1.0-F);")
                }
                m.shaderModifiers?[.surface] = source
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "film-" + mode)
        }
    }

    func testExportTableShadowMesh() throws {
        let s = try scene(mobile: true)
        let table = try XCTUnwrap(s.tableNode)
        var obj = "# SceneKit world metres; XZ floor, Y up\n", count = 0
        var failure: Error?
        table.enumerateChildNodes { node, _ in
            guard let g = node.geometry, let sourceIndex = g.sources.firstIndex(where: { $0.semantic == .vertex }) else { return }
            let v = g.sources[sourceIndex]
            guard v.usesFloatComponents && v.bytesPerComponent == 4 else { return }
            let channel = g.geometrySourceChannels?[sourceIndex].intValue ?? 0
            v.data.withUnsafeBytes { bytes in
                for i in 0..<v.vectorCount {
                    let j = v.dataOffset + i*v.dataStride
                    let p = node.convertPosition(SCNVector3(bytes.loadUnaligned(fromByteOffset:j,as:Float.self),bytes.loadUnaligned(fromByteOffset:j+4,as:Float.self),bytes.loadUnaligned(fromByteOffset:j+8,as:Float.self)),to:nil)
                    obj += "v \(p.x) \(-p.z) \(p.y)\n"
                }
            }
            do {
                for e in g.elements {
                    for face in try PocketLeatherMesh.decode(e) {
                        let indices = stride(from:channel,to:face.count,by:e.indicesChannelCount).map { String(Int(face[$0])+count+1) }
                        obj += "f " + indices.joined(separator:" ") + "\n"
                    }
                }
            } catch { failure = error }
            count += v.vectorCount
        }
        if let failure { throw failure }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try obj.write(to: directory.appendingPathComponent("table-shadow.obj"),atomically:true,encoding:.utf8)
    }

    func testEntryTiming() async throws {
        let old = ProcessInfo.processInfo.environment["V62_REFERENCE_LIGHTING"]
        setenv("V62_REFERENCE_LIGHTING", "1", 1)
        defer {
            if let old { setenv("V62_REFERENCE_LIGHTING", old, 1) }
            else { unsetenv("V62_REFERENCE_LIGHTING") }
        }
        XCTAssertTrue(MobileReferenceLighting.requested)
        // Match the app's existing background asset warm-up, without retaining a VM.
        await Task.detached(priority: .userInitiated) {
            TableModelLoader.preloadModel()
            TableModelLoader.preloadPocketRegions()
        }.value
        var rows: [[String: Double]] = []
        for i in 0..<3 {
            let vm = PositionPlayViewModel()
            let start = CACurrentMediaTime()
            vm.setupScene(mobileRendering: true)
            XCTAssertNotNil(vm.scene.rootNode.childNode(withName: "reference_room", recursively: false))
            if i == 1 {
                let y = BTTablePhysics.surfaceY + AngleSceneCalculator.ballRadius
                let cue = AngleSceneCalculator.sceneToNormalized(position: SCNVector3(-0.35,y,0.22))
                let target = AngleSceneCalculator.sceneToNormalized(position: SCNVector3(0.55,y,-0.18))
                vm.loadBoard(BoardSnapshot(onTable: [PositionPlayBall.cueKey: CanvasPoint(x: Double(cue.x),y:Double(cue.y)), "_8": CanvasPoint(x:Double(target.x),y:Double(target.y))]))
            }
            while vm.isComputing && CACurrentMediaTime() - start < 45 {
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            XCTAssertFalse(vm.isComputing)
            var row = vm.entryTiming
            row.merge(vm.scene.setupTiming) { _, new in new }
            row["totalMs"] = (CACurrentMediaTime() - start) * 1000
            rows.append(row)
        }
        print("ENTRY_TIMING",rows)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: rows, options: .prettyPrinted).write(to: directory.appendingPathComponent("entry-timing.json"))
    }

    func testRoomCacheIsolation() throws {
        let first = BakedTrainingRoom.make(style: .tournament)
        let second = BakedTrainingRoom.make(style: .tournament)
        func floorMaterial(_ room: SCNNode) throws -> SCNMaterial {
            var material: SCNMaterial?
            room.childNode(withName: "room_floor", recursively: false)?.enumerateChildNodes { n,_ in
                if let m = n.geometry?.firstMaterial { material = m }
            }
            return try XCTUnwrap(material)
        }
        let a = try floorMaterial(first), b = try floorMaterial(second)
        XCTAssertFalse(a === b)
        a.transparency = 0.25
        first.isHidden = true
        XCTAssertEqual(b.transparency, 1)
        XCTAssertFalse(second.isHidden)
        let third = BakedTrainingRoom.make(style: .tournament)
        XCTAssertEqual(try floorMaterial(third).transparency, 1)
    }

    func testRoomLightingCalibrationComparison() throws {
        let path = ProcessInfo.processInfo.environment["V62_ROOM_CANDIDATE_DIR"]
        try XCTSkipUnless(path != nil, "Explicit offline room lighting candidate required")
        let root = URL(fileURLWithPath: try XCTUnwrap(path))
        var stylesChecked = 0
        for style in RoomStyle.allCases {
            guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Room_" + style.rawValue + ".blend").path) else { continue }
            stylesChecked += 1
            for candidate in [false, true] {
                let s = try scene(mobile: true)
                MobileReferenceLighting.apply(to: s)
                s.installReferenceRoom(style: style)
                if candidate {
                    let room = try XCTUnwrap(s.rootNode.childNode(withName: "reference_room", recursively: true))
                    for part in ["floor", "perimeter"] {
                        let image = try XCTUnwrap(UIImage(contentsOfFile: root.appendingPathComponent(style.rawValue + "_" + part + ".png").path))
                        let node = try XCTUnwrap(room.childNode(withName: "room_" + part, recursively: true))
                        var template: SCNMaterial?
                        node.enumerateChildNodes { child, _ in
                            if let material = child.geometry?.firstMaterial { template = material }
                        }
                        let material = try XCTUnwrap(template?.copy() as? SCNMaterial)
                        material.diffuse.contents = MobileReferenceLighting.roomRGBA(image)
                        let asset = try SCNScene(url: root.appendingPathComponent("Room_" + style.rawValue + "_" + part + ".usdz"), options: nil)
                        node.childNodes.forEach { $0.removeFromParentNode() }
                        node.transform = asset.rootNode.transform
                        for child in asset.rootNode.childNodes { node.addChildNode(child.clone()) }
                        node.enumerateChildNodes { child, _ in
                            child.castsShadow = false
                            if part == "floor" { child.renderingOrder = -10 }
                            child.geometry?.materials = [material]
                        }
                    }
                }
                s.updateCueStick(cueBallPosition: SCNVector3(-0.45,s.surfaceY+AngleSceneCalculator.ballRadius,0), aimDirection: SCNVector3(0.8,0,0.12))
                let stem = style.rawValue + (candidate ? "-matched" : "-baseline")
                try capture(s, name: stem + "-entry")
                s.cameraRig?.handleObservationPan(deltaX: 600)
                s.cameraRig?.handleObservationPinch(scale: 0.5)
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: stem + "-wide")
                // Asset inspection only; production camera and gesture policy are untouched.
                let inspection = SCNNode()
                inspection.position = SCNVector3(2.8,1.05,1.8)
                inspection.look(at: SCNVector3(4.85,1.05,1.8))
                s.cameraNode.simdWorldTransform = inspection.simdWorldTransform
                s.cameraNode.camera?.fieldOfView = 50
                try capture(s, name: stem + "-rack")
            }
        }
        XCTAssertGreaterThan(stylesChecked, 0, "No completed room bake was compared")
    }

    func testPostersCoverFourWallsAndFollowRoomStyle() throws {
        for style in RoomStyle.allCases {
            let s = try scene(mobile: true)
            MobileReferenceLighting.apply(to: s)
            s.installReferenceRoom(style: style)
            let room = try XCTUnwrap(s.rootNode.childNode(withName: "reference_room", recursively: false))
            let gallery = try XCTUnwrap(room.childNode(withName: "room_posters", recursively: false))
            XCTAssertEqual(gallery.childNodes.count, 8)
            var wallNormals = Set<String>()
            try capture(s, name: "posters-\(style.rawValue)-entry")
            for poster in gallery.childNodes {
                let captions = poster.childNodes.compactMap { $0.geometry as? SCNText }
                XCTAssertEqual(captions.count, 2)
                for caption in captions {
                    let content = try XCTUnwrap(caption.string as? String)
                    XCTAssertFalse(content.isEmpty, "Room cache cloning must preserve poster captions")
                    XCTAssertGreaterThan(caption.boundingBox.max.x, caption.boundingBox.min.x)
                }
                let p = poster.simdWorldPosition
                let normal = simd_normalize(poster.simdConvertVector(SIMD3<Float>(0, 0, 1), to: nil))
                XCTAssertGreaterThan(simd_dot(normal, -p), 3, "Print must face into the room")
                wallNormals.insert("\(Int(normal.x.rounded())),\(Int(normal.z.rounded()))")
                let face = try XCTUnwrap(poster.childNode(withName: "poster_print", recursively: false))
                let material = try XCTUnwrap(face.geometry?.firstMaterial)
                XCTAssertTrue(material.name?.hasPrefix("Poster_\(style.rawValue)_") == true)
                let image = try XCTUnwrap(material.diffuse.contents as? UIImage)
                let plane = try XCTUnwrap(face.geometry as? SCNPlane)
                XCTAssertEqual(image.size.width / image.size.height, plane.width / plane.height, accuracy: 0.01)
                XCTAssertFalse(material.isDoubleSided)
                XCTAssertFalse(face.castsShadow)
                s.cameraNode.simdPosition = p + normal * 2.4 + SIMD3<Float>(0, 0.05, 0)
                s.cameraNode.look(at: SCNVector3(p))
                s.cameraNode.camera?.fieldOfView = 55
                SCNTransaction.flush()
                try capture(s, name: "posters-\(style.rawValue)-\(poster.name!)")
            }
            XCTAssertEqual(wallNormals, ["1,0", "-1,0", "0,1", "0,-1"])
            let wallPairs = [["practice", "control"], ["calm", "enjoy"],
                             ["again", "angle"], ["next", "route"]]
            for pair in wallPairs {
                let first = try XCTUnwrap(gallery.childNode(withName: "room_poster_" + pair[0], recursively: false))
                let second = try XCTUnwrap(gallery.childNode(withName: "room_poster_" + pair[1], recursively: false))
                let center = (first.simdWorldPosition + second.simdWorldPosition) / 2
                let normal = simd_normalize(first.simdConvertVector(SIMD3<Float>(0, 0, 1), to: nil))
                s.cameraNode.simdPosition = center + normal * 4.8
                s.cameraNode.look(at: SCNVector3(center))
                SCNTransaction.flush()
                s.cameraNode.camera?.fieldOfView = 38
                try capture(s, name: "posters-\(style.rawValue)-wall-\(pair[0])", size: CGSize(width: 1800, height: 1200))
            }
            s.setCameraMode(.topDown2D, animated: false)
            XCTAssertTrue(room.isHidden)
        }
    }

    func testBakedRoomStyleViews() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil)
        for style in RoomStyle.allCases {
            let s = try scene(mobile: true)
            MobileReferenceLighting.apply(to: s)
            s.installReferenceRoom(style: style)
            s.updateCueStick(cueBallPosition: SCNVector3(-0.45,s.surfaceY+AngleSceneCalculator.ballRadius,0), aimDirection: SCNVector3(0.8,0,0.12))
            try capture(s, name: "baked-" + style.rawValue + "-entry")
            s.cameraRig?.handleObservationPan(deltaX: 600)
            s.cameraRig?.handleObservationPinch(scale: 0.5)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "baked-" + style.rawValue + "-wide")
            let inspection = SCNNode()
            inspection.position = SCNVector3(2.8,1.05,1.8)
            inspection.look(at: SCNVector3(4.85,1.05,1.8))
            s.cameraNode.simdWorldTransform = inspection.simdWorldTransform
            s.cameraNode.camera?.fieldOfView = 50
            try capture(s, name: "baked-" + style.rawValue + "-rack")
        }
    }

    func testRoomStyleSelection() throws {
        let suite = "RoomStyleTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(UserPreferences(defaults: defaults).roomStyle, .tournament)
        let prefs = UserPreferences(defaults: defaults); prefs.roomStyle = .walnut
        XCTAssertEqual(UserPreferences(defaults: defaults).roomStyle, .walnut)
        defaults.set("future-unknown", forKey: RoomStyle.preferenceKey)
        XCTAssertEqual(UserPreferences(defaults: defaults).roomStyle, .tournament)
        let s = try scene(mobile: true)
        MobileReferenceLighting.apply(to: s)
        let camera = s.cameraNode.simdWorldTransform
        let ball = try XCTUnwrap(s.allBallNodes.values.first)
        func ballMaterial() -> SCNMaterial? {
            var result = ball.geometry?.firstMaterial
            ball.enumerateChildNodes { node, stop in
                if let material = node.geometry?.firstMaterial { result = material; stop.pointee = true }
            }
            return result
        }
        let material = try XCTUnwrap(ballMaterial())
        for style in [RoomStyle.tournament, .walnut, .eastern, .tournament] {
            s.installReferenceRoom(style: style)
            let room = try XCTUnwrap(s.rootNode.childNode(withName: "reference_room", recursively: false))
            XCTAssertEqual(s.installedReferenceRoomStyle, style)
            XCTAssertEqual(s.rootNode.childNodes.filter { $0.name == "reference_room" }.count, 1)
            s.installReferenceRoom(style: style)
            XCTAssertTrue(room === s.rootNode.childNode(withName: "reference_room", recursively: false))
            XCTAssertEqual(s.cameraNode.simdWorldTransform, camera)
            XCTAssertTrue(material === ballMaterial())
            if ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil { try capture(s, name: "style-" + style.rawValue) }
            s.setCameraMode(.topDown2D, animated: false)
            XCTAssertTrue(room.isHidden)
            s.setCameraMode(.perspective3D, animated: false)
        }
    }

    func testReferenceCarpetRoomViews() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit room evidence")
        let s = try scene(mobile: true)
        MobileReferenceLighting.apply(to: s)
        MobileReferenceLighting.applySurfaceFinishes(to: s)
        let room = try XCTUnwrap(s.rootNode.childNode(withName: "reference_room", recursively: false))
        let ground = try XCTUnwrap(s.rootNode.childNode(withName: "ground_visual", recursively: false))
        let cameraBefore = s.cameraNode.simdWorldTransform
        s.installReferenceRoom()
        XCTAssertEqual(s.rootNode.childNodes.filter { $0.name == "reference_room" }.count, 1)
        XCTAssertEqual(s.cameraNode.simdWorldTransform, cameraBefore)
        XCTAssertEqual(room.childNodes.count, 3)
        XCTAssertNil(ground.geometry, "The imported floor must replace the old coplanar plane")
        let bounds = room.boundingBox
        XCTAssertEqual(bounds.min.x, -5.2, accuracy: 0.02)
        XCTAssertEqual(bounds.max.x, 5.2, accuracy: 0.02)
        XCTAssertEqual(bounds.max.y, 3.6, accuracy: 0.02)
        XCTAssertEqual(bounds.min.z, -4.2, accuracy: 0.02)
        XCTAssertEqual(bounds.max.z, 4.2, accuracy: 0.02)
        room.enumerateChildNodes { node, _ in
            XCTAssertNil(node.light); XCTAssertNil(node.camera)
            if let geometry = node.geometry {
                XCTAssertEqual(geometry.materials.count, 1)
                XCTAssertEqual(geometry.firstMaterial?.lightingModel, .constant)
            }
        }
        s.updateCueStick(cueBallPosition: SCNVector3(-0.45,s.surfaceY+AngleSceneCalculator.ballRadius,0), aimDirection: SCNVector3(0.8,0,0.12))
        for pose in ["entry", "detail", "orbit", "wide"] {
            if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
            if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 600) }
            if pose == "wide" { s.cameraRig?.handleObservationPinch(scale: 0.25) }
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            room.isHidden = true
            try capture(s, name: "carpet-\(pose)")
            room.isHidden = false
            try capture(s, name: "room-\(pose)")
        }
        for mode in [AngleTrainingScene.CameraMode.topDown2D, .topDown2DRotated] {
            s.setCameraMode(mode, animated: false)
            XCTAssertTrue(room.isHidden); XCTAssertTrue(ground.isHidden)
        }
        try capture(s, name: "room-topdown")
        s.setCameraMode(.perspective3D, animated: false)
        XCTAssertFalse(room.isHidden); XCTAssertFalse(ground.isHidden)
    }

    func testReferenceSurfaceFinishComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit finishes")
        for candidate in [false,true] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if candidate { MobileReferenceLighting.applySurfaceFinishes(to:s) }
            s.updateCueStick(cueBallPosition:SCNVector3(-0.45,s.surfaceY+AngleSceneCalculator.ballRadius,0),aimDirection:SCNVector3(0.8,0,0.12))
            for pose in ["entry","detail","orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale:2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX:180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
                try capture(s,name:"\(candidate ? "candidate" : "reference")-\(pose)")
            }
            if candidate {
                let ground = try XCTUnwrap(s.rootNode.childNode(withName:"ground_visual",recursively:false))
                XCTAssertEqual(ground.position.y,BTSceneLayout.groundLevelY)
                s.setCameraMode(.topDown2D,animated:false);XCTAssertTrue(ground.isHidden)
                s.setCameraMode(.perspective3D,animated:false);XCTAssertFalse(ground.isHidden)
            }
        }
    }

    func testReferenceFinishCoverage() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit finish coverage")
        let s = try scene(mobile:true);MobileReferenceLighting.apply(to:s)
        MobileReferenceLighting.applySurfaceFinishes(to:s)
        for (i,key) in s.allBallNodes.keys.sorted().enumerated() {
            let n = try XCTUnwrap(s.allBallNodes[key]);n.isHidden=false;n.opacity=1
            n.position=SCNVector3(-0.6+Float(i/4)*0.4,s.surfaceY+AngleSceneCalculator.ballRadius,-0.3+Float(i%4)*0.2)
        }
        XCTAssertEqual(s.allBallNodes.count,16)
        materials(s) { m in XCTAssertTrue(m.shaderModifiers?[.surface]?.contains("float roughness=0.34;") == true) }
        let markers=s.addPocketMarkers();XCTAssertEqual(markers.count,6)
        for marker in markers {
            let leather=try XCTUnwrap(marker as? PocketLeatherMarker)
            for style in PocketLeatherMarker.Style.allCases { leather.show(style);XCTAssertEqual(leather.style,style) }
            leather.show(.target)
        }
        var selectedCount=0
        s.tableNode?.enumerateChildNodes { n,_ in
            for m in n.geometry?.materials ?? [] where m.name == "Leather" {
                if let src=m.shaderModifiers?[.surface], let tint=src.range(of:"_surface.diffuse.rgb = clamp"),let lighting=src.range(of:"// v62SatinFinish") {
                    XCTAssertLessThan(tint.lowerBound,lighting.lowerBound);selectedCount += 1
                }
            }
        }
        XCTAssertGreaterThan(selectedCount,0)
        for pose in ["entry","detail","orbit"] {
            if pose == "detail" { s.cameraRig?.handleObservationPinch(scale:2) }
            if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX:180) }
            for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
            try capture(s,name:"all16-\(pose)")
        }
    }

    func testReferenceMaterialInventory() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit inventory")
        let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
        var rows: [[String: String]] = []
        s.rootNode.enumerateChildNodes { n, _ in
            for m in n.geometry?.materials ?? [] {
                rows.append(["node": n.name ?? "", "material": m.name ?? "", "diffuse": String(describing:m.diffuse.contents), "roughness": String(describing:m.roughness.contents), "normal":String(describing:m.normal.contents), "model":m.lightingModel.rawValue])
            }
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: rows, options:.prettyPrinted).write(to: directory.appendingPathComponent("inventory.json"))
    }

    func testReferenceLightingBalanceSweep() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit lighting grid")
        for top in [0.50, 0.70, 0.85, 1.0] {
            for fill in [1.0, 1.3, 1.6, 2.0] {
                let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
                var seen = Set<ObjectIdentifier>()
                var changed = 0
                s.rootNode.enumerateChildNodes { node, _ in
                    if node.name == "S267AreaPanel" { node.light?.intensity *= CGFloat(top) }
                    for m in node.geometry?.materials ?? [] where seen.insert(ObjectIdentifier(m)).inserted {
                        guard var mods = m.shaderModifiers else { continue }
                        for key in [SCNShaderModifierEntryPoint.surface, .fragment] {
                            guard var source = mods[key] else { continue }
                            if source.contains("44.5714854") { changed += 1 }
                            source = source.replacingOccurrences(of: "44.5714854", with: String(MobileReferenceLighting.rig.radiance * top))
                            source = source.replacingOccurrences(of: "+0.26", with: "+(0.26*\(fill))")
                            source = source.replacingOccurrences(of: "float3(v62worldIntegral(n.y))", with: "(float3(v62worldIntegral(n.y))*\(fill))")
                            mods[key] = source
                        }
                        m.shaderModifiers = mods
                    }
                }
                XCTAssertGreaterThan(changed, 2)
                for pose in ["entry", "detail", "orbit"] {
                    if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                    if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                    for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                    try capture(s, name: "t\(Int((top*100).rounded()))-f\(Int((fill*100).rounded()))-\(pose)")
                }
            }
        }
    }

    func testReferenceInstalledBalanceTrial() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit installed trial")
        XCTAssertTrue(MobileReferenceLighting.balanceTrialRequested)
        let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
        for pose in ["entry", "detail", "orbit"] {
            if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
            if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "trial-\(pose)")
        }
    }

    func testReferenceCalibratedRatios() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit lighting grid")
        let pairs: [(String, Double, Double)] = [
            ("baseline", 1, 1),
            ("limit", 1.5321798315159696, 0.0),
            ("4-1", 1.4029335211389857, 0.24286209796566752),
            ("2-1", 1.1691112676158215, 0.6822290932482533),
            ("1-1", 0.8768334507118661, 1.2314378373514854),
            ("1-2", 0.5845556338079108, 1.7806465814547177),
            ("1-4", 0.35073338028474643, 2.220013576737303)
        ]
        for (label, top, fill) in pairs {
            for gray in [false, true] {
                let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
                var seen = Set<ObjectIdentifier>()
                var changed = 0
                s.rootNode.enumerateChildNodes { node, _ in
                    if node.name == "S267AreaPanel" { node.light?.intensity *= CGFloat(top) }
                    for m in node.geometry?.materials ?? [] where seen.insert(ObjectIdentifier(m)).inserted {
                        guard var mods = m.shaderModifiers else { continue }
                        for key in [SCNShaderModifierEntryPoint.surface, .fragment] {
                            guard var source = mods[key] else { continue }
                            if source.contains("44.5714854") { changed += 1 }
                            source = source.replacingOccurrences(of: "44.5714854", with: String(MobileReferenceLighting.rig.radiance * top))
                            source = source.replacingOccurrences(of: "+0.26", with: "+(0.26*\(fill))")
                            source = source.replacingOccurrences(of: "float3(v62worldIntegral(n.y))", with: "(float3(v62worldIntegral(n.y))*\(fill))")
                            mods[key] = source
                        }
                        m.shaderModifiers = mods
                    }
                }
                if gray {
                    materials(s) { m in
                        guard let source = m.shaderModifiers?[.surface] else { XCTFail("Missing ball shader"); return }
                        XCTAssertTrue(source.contains("float3 albedo=_surface.diffuse.rgb;"))
                        m.shaderModifiers?[.surface] = source.replacingOccurrences(of: "float3 albedo=_surface.diffuse.rgb;", with: "float3 albedo=float3(0.18);")
                    }
                }
                XCTAssertGreaterThan(changed, 2)
                for pose in ["entry", "detail", "orbit"] {
                    if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                    if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                    for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                    try capture(s, name: "\(label)-\(gray ? "gray" : "ball")-\(pose)")
                }
            }
        }
    }

    func testReferenceBallContributionStages() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit ball contribution diagnosis")
        let final = "_surface.diffuse.rgb=albedo*(v62PanelDiffuse(p,n)/3.14159265+env)*(1.0-F)+spec;"
        for mode in ["reference", "direct", "indirect", "diffuse", "specular", "no-shoulder", "albedo"] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            materials(s) { m in
                guard var source = m.shaderModifiers?[.surface] else { XCTFail("Missing ball shader"); return }
                XCTAssertTrue(source.contains(final))
                let output: String
                switch mode {
                case "direct": output = "albedo*v62PanelDiffuse(p,n)/3.14159265*(1.0-F)"
                case "indirect": output = "albedo*env*(1.0-F)"
                case "diffuse": output = "albedo*(v62PanelDiffuse(p,n)/3.14159265+env)*(1.0-F)"
                case "specular": output = "spec"
                case "albedo": output = "albedo"
                default: output = "albedo*(v62PanelDiffuse(p,n)/3.14159265+env)*(1.0-F)+spec"
                }
                source = source.replacingOccurrences(of: final, with: "_surface.diffuse.rgb=" + output + ";")
                m.shaderModifiers?[.surface] = source
                if mode == "no-shoulder" {
                    XCTAssertTrue(m.shaderModifiers?[.fragment]?.contains("v62HighlightHeadroom") == true)
                    m.shaderModifiers?[.fragment] = nil
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(mode)-\(pose)")
            }
        }
    }

    func testReferenceTableBounceIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit table bounce diagnosis")
        for mode in ["reference", "neutral", "candidate"] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if mode != "candidate" {
                materials(s) { m in
                    guard var source = m.shaderModifiers?[.surface] else { XCTFail("Missing ball shader"); return }
                    let marker = "env=float3(v62worldIntegral(n.y))+clothRadiance*v62bounceIntegral(n.y);"
                    XCTAssertTrue(source.contains(marker))
                    source = source.replacingOccurrences(of: "clothRadiance=mix(float3(dot(clothRadiance,float3(0.2126,0.7152,0.0722))),clothRadiance,0.5);", with: "")
                    let override = mode == "neutral" ? "clothRadiance=float3(dot(clothRadiance,float3(0.2126,0.7152,0.0722)));" : ""
                    source = source.replacingOccurrences(of: marker, with: override + "\n" + marker)
                    m.shaderModifiers?[.surface] = source
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(mode)-\(pose)")
            }
        }
    }

    func testReferenceBroadFillDistribution() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit shared environment distribution")
        let integral = """
        env=float3(0.0);
        for(int j=0;j<256;++j) {
            float u=(float(j)+0.5)/256.0;
            float phi=6.2831853*fract(float(j)*0.61803398875);
            float3 d=tangent*(sqrt(u)*cos(phi))+bitangent*(sqrt(u)*sin(phi))+n*sqrt(1.0-u);
            float3 incoming=float3(v62World(d));
            if(d.y < -0.00001) {
                float3 q=p+d*((0.8-p.y)/d.y);
                if(abs(q.x)<1.27 && abs(q.z)<0.635) {
                    float r2=dot(q.xz-center.xz,q.xz-center.xz);
                    incoming=clothRadiance*clamp(r2/(r2+0.028575*0.028575),0.0,1.0);
                }
            }
            env+=incoming/256.0;
        }
        """
        for mode in ["reference", "matched", "brighter"] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if mode != "reference" {
                materials(s) { m in
                    guard var source = m.shaderModifiers?[.surface] else { XCTFail("Missing ball shader"); return }
                    let world = "return 0.06+1.2*pow(1.0-abs(d.y),2.0);"
                    XCTAssertTrue(source.contains(world))
                    source = source.replacingOccurrences(of: world, with: mode == "matched" ? "return 0.06+0.60*(1.0-abs(d.y));" : "return 0.20+0.60*(1.0-abs(d.y));")
                    let target = "env=float3(v62worldIntegral(n.y))+clothRadiance*v62bounceIntegral(n.y);"
                    XCTAssertTrue(source.contains(target))
                    source = source.replacingOccurrences(of: target, with: integral)
                    m.shaderModifiers?[.surface] = source
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(mode)-\(pose)")
            }
        }
    }

    func testReferenceFiniteIndirectComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit indirect reference")
        let integral = """
        env=float3(0.0);
        for(int j=0;j<256;++j) {
            float u=(float(j)+0.5)/256.0;
            float phi=6.2831853*fract(float(j)*0.61803398875);
            float3 d=tangent*(sqrt(u)*cos(phi))+bitangent*(sqrt(u)*sin(phi))+n*sqrt(1.0-u);
            float3 incoming=float3(v62World(d));
            if(d.y < -0.00001) {
                float3 q=p+d*((0.8-p.y)/d.y);
                if(abs(q.x)<1.27 && abs(q.z)<0.635) {
                    float r2=dot(q.xz-center.xz,q.xz-center.xz);
                    incoming=clothRadiance*clamp(r2/(r2+0.028575*0.028575),0.0,1.0);
                }
            }
            env+=incoming/256.0;
        }
        """
        for finite in [false, true] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if finite {
                materials(s) { m in
                    guard let source = m.shaderModifiers?[.surface] else { XCTFail("Missing ball shader"); return }
                    let target = "env=float3(v62worldIntegral(n.y))+clothRadiance*v62bounceIntegral(n.y);"
                    XCTAssertTrue(source.contains(target))
                    m.shaderModifiers?[.surface] = source.replacingOccurrences(of: target, with: integral)
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(finite ? "finite" : "fitted")-\(pose)")
            }
        }
    }

    func testReferenceClothInputIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit cloth input comparison")
        for mode in ["reference", "emission-only", "explicit-roughness"] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            s.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    var mods = m.shaderModifiers ?? [:]
                    if mode == "emission-only" {
                        mods[.fragment] = "#pragma body\n_output.color.rgb = _surface.emission.rgb;"
                    }
                    if mode == "explicit-roughness" {
                        let transform = m.roughness.contentsTransform
                        print("CLOTH ROUGHNESS", String(describing: m.roughness.contents), transform.m11, transform.m22, m.roughness.intensity)
                        m.setValue(m.roughness, forKey: "referenceRoughness")
                        let surface = mods[.surface] ?? ""
                        mods[.surface] = surface.replacingOccurrences(of: "#pragma arguments", with: "#pragma arguments\ntexture2d<float> referenceRoughness;")
                            .replacingOccurrences(of: "#pragma body", with: """
                            #pragma body
                            constexpr sampler fiberSampler(coord::normalized, address::repeat, filter::linear, mip_filter::linear);
                            _surface.roughness = referenceRoughness.sample(fiberSampler, _surface.diffuseTexcoord * float2(\(transform.m11), \(transform.m22))).r;
                            """)
                        m.lightingModel = .constant
                    }
                    m.shaderModifiers = mods
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(mode)-\(pose)")
            }
        }
    }

    func testReferenceClothBaseCostComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit cloth base comparison")
        for customOnly in [false, true] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            if customOnly {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" { m.lightingModel = .constant }
                }
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(customOnly ? "custom-only" : "native-base")-\(pose)")
            }
        }
    }

    func testReferenceAntialiasingComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit AA comparison")
        for (label, mode) in [("4x", SCNAntialiasingMode.multisampling4X), ("2x", .multisampling2X)] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(label)-\(pose)", antialiasing: mode)
            }
        }
    }

    func testReferenceIdleRenderedFrames() async throws {
        try await captureReferenceSceneViewActivity(mixed: false)
    }

    func testReferenceMixedSceneViewActivity() async throws {
        try await captureReferenceSceneViewActivity(mixed: true)
    }

    func testReferenceDenseMixedSceneViewActivity() async throws {
        try await captureReferenceSceneViewActivity(mixed: true, dense: true, cycles: 15)
    }

    private func captureReferenceSceneViewActivity(mixed: Bool, dense: Bool = false, cycles: Int = 6) async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit presented idle diagnostic")
        let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
        if dense {
            try XCTSkipUnless(ProcessInfo.processInfo.thermalState == .nominal, "Nominal start required for sustained diagnostic")
            for (i, key) in s.allBallNodes.keys.sorted().enumerated() {
                s.showBall(key: key, scenePosition: SCNVector3(-0.6+Float(i/4)*0.4, s.surfaceY+AngleSceneCalculator.ballRadius, -0.3+Float(i%4)*0.2))
            }
        }
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow))
        let view = SCNView(frame: window.bounds)
        view.scene = s; view.pointOfView = s.cameraNode; view.antialiasingMode = .multisampling4X
        window.addSubview(view)
        let count = ReferenceLockedFrameCount()
        s.contactOcclusion?.didRenderFrame = { count.increment() }
        let coordinator = AngleSceneView.Coordinator(scene: s, cameraMode: .perspective3D, interactionMode: .cameraControl)
        coordinator.scnView = view; coordinator.contentIsAnimating = false
        coordinator.startRenderLoop(); coordinator.requestInteractiveFrames()
        defer { coordinator.stopRenderLoop(); view.isPlaying = false; view.removeFromSuperview() }
        try await Task.sleep(for: .seconds(2))
        let idleStart = count.value
        try await Task.sleep(for: .seconds(2))
        let idleFrames = count.value - idleStart
        let stopped = !view.isPlaying
        coordinator.contentIsAnimating = true; coordinator.requestInteractiveFrames()
        let activeStart = count.value
        try await Task.sleep(for: .seconds(2))
        let activeFrames = count.value - activeStart
        var phases: [[String: Any]] = []
        if mixed {
            for cycle in 0..<cycles {
                coordinator.contentIsAnimating = false
                let idleTime = CACurrentMediaTime(); let beforeIdle = count.value
                try await Task.sleep(for: .seconds(13))
                phases.append(["cycle": cycle, "active": false, "duration": CACurrentMediaTime()-idleTime, "frames": count.value-beforeIdle, "thermal": ProcessInfo.processInfo.thermalState.rawValue])
                if ProcessInfo.processInfo.thermalState.rawValue >= 2 { break }
                coordinator.contentIsAnimating = true; coordinator.requestInteractiveFrames()
                let motionTime = CACurrentMediaTime(); let beforeMotion = count.value
                s.cueBallNode?.runAction(.sequence([.moveBy(x: 0.3, y: 0, z: 0, duration: 3.5), .moveBy(x: -0.3, y: 0, z: 0, duration: 3.5)]), completionHandler: nil)
                try await Task.sleep(for: .seconds(7))
                phases.append(["cycle": cycle, "active": true, "duration": CACurrentMediaTime()-motionTime, "frames": count.value-beforeMotion, "thermal": ProcessInfo.processInfo.thermalState.rawValue])
                if ProcessInfo.processInfo.thermalState.rawValue >= 2 { break }
            }
        }
        let report: [String: Any] = ["recordedAt": Date().timeIntervalSince1970, "idleFramesIn2Seconds": idleFrames, "activeFramesIn2Seconds": activeFrames, "idlePlaybackStopped": stopped, "phases": phases, "dense": dense, "cyclesRequested": cycles, "thermal": ProcessInfo.processInfo.thermalState.rawValue, "note": "SCNView didRender callbacks, not display presentation or watts"]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys]).write(to: directory.appendingPathComponent(dense ? "dense-mixed-scene-view.json" : (mixed ? "mixed-scene-view.json" : "idle-frames.json")))
        if mixed { XCTAssertEqual(phases.count, cycles * 2, "Must finish requested cycles without severe thermal state") }
        XCTAssertTrue(stopped)
        XCTAssertLessThanOrEqual(idleFrames, 3, "Stable scene should not redraw at idle polling rate")
        XCTAssertGreaterThan(activeFrames, 30, "Activity must resume actual rendering")
    }

    func testReferenceIdleWakeAndActions() async throws {
        let s = try scene(mobile: true)
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        view.scene = s; view.pointOfView = s.cameraNode
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow))
        window.addSubview(view)
        let coordinator = AngleSceneView.Coordinator(scene: s, cameraMode: .perspective3D, interactionMode: .cameraControl)
        coordinator.scnView = view; coordinator.contentIsAnimating = false
        coordinator.startRenderLoop(); coordinator.requestInteractiveFrames()
        defer { coordinator.stopRenderLoop(); view.removeFromSuperview() }
        try await Task.sleep(for: .seconds(1.5))
        XCTAssertFalse(view.isPlaying, "Stable table must stop continuous scene playback")
        let rig = try XCTUnwrap(s.cameraRig)
        rig.handleObservationPan(deltaX: 200)
        XCTAssertTrue(rig.hasPendingDamping)
        coordinator.requestInteractiveFrames()
        try await Task.sleep(for: .seconds(0.7))
        if rig.hasPendingDamping { XCTAssertTrue(view.isPlaying, "Damping must not stop at the input grace deadline") }
        try await Task.sleep(for: .seconds(2))
        XCTAssertFalse(rig.hasPendingDamping)
        XCTAssertFalse(view.isPlaying)
        coordinator.contentIsAnimating = true; coordinator.requestInteractiveFrames()
        XCTAssertTrue(view.isPlaying, "Physics activity must wake rendering synchronously")
        coordinator.contentIsAnimating = false
        let actionNode = SCNNode(); s.rootNode.addChildNode(actionNode)
        actionNode.runAction(.moveBy(x: 0.1, y: 0, z: 0, duration: 1.2), completionHandler: nil)
        try await Task.sleep(for: .seconds(0.7))
        XCTAssertTrue(view.isPlaying, "SceneKit actions must finish even without physics playback")
        try await Task.sleep(for: .seconds(1.2))
        XCTAssertEqual(actionNode.position.x, 0.1, accuracy: 0.001)
        XCTAssertFalse(view.isPlaying, "Completed actions must settle back to idle")
    }

    func testFrameRateReadoutDoesNotWakeIdleScene() async throws {
        let original = UserPreferences.shared.renderFrameRate
        defer { UserPreferences.shared.renderFrameRate = original }
        let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
        let window = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow))
        let view = SCNView(frame: window.bounds)
        view.scene = s; view.pointOfView = s.cameraNode; window.addSubview(view)
        let counter = ReferenceLockedFrameCount()
        s.contactOcclusion?.didRenderFrame = { counter.increment() }
        let coordinator = AngleSceneView.Coordinator(scene: s, cameraMode: .perspective3D, interactionMode: .cameraControl)
        coordinator.scnView = view; coordinator.contentIsAnimating = false
        coordinator.installFPSReadout(in: view); coordinator.startRenderLoop(); coordinator.requestInteractiveFrames()
        defer { coordinator.stopRenderLoop(); view.isPlaying = false; view.removeFromSuperview() }
        try await Task.sleep(for: .seconds(2.5))
        let before = counter.value
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(counter.value, before, "The FPS readout must not create a feedback redraw loop")
        XCTAssertTrue(view.accessibilityValue?.contains("FPS · 静止") == true)
        coordinator.contentIsAnimating = true
        for selected in RenderFrameRate.allCases {
            UserPreferences.shared.renderFrameRate = selected
            coordinator.requestInteractiveFrames()
            XCTAssertEqual(view.preferredFramesPerSecond,
                AngleSceneView.requestedFPS(maximum: window.screen.maximumFramesPerSecond, selected: selected,
                    active: true, thermal: ProcessInfo.processInfo.thermalState, lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled))
        }
    }

    func testReferenceFramePacingPolicy() {
        for selected in RenderFrameRate.allCases {
            for maximum in [60, 120] {
                for thermal in [ProcessInfo.ThermalState.nominal, .fair, .serious, .critical] {
                    for lowPower in [false, true] {
                        let limit = thermal == .critical ? 30 : (thermal == .serious || lowPower ? 60 : maximum)
                        XCTAssertEqual(AngleSceneView.requestedFPS(maximum: maximum, selected: selected, active: true, thermal: thermal, lowPower: lowPower), min(selected.rawValue, maximum, limit))
                        XCTAssertEqual(AngleSceneView.requestedFPS(maximum: maximum, selected: selected, active: false, thermal: thermal, lowPower: lowPower), 30)
                    }
                }
            }
        }
        XCTAssertEqual(AngleSceneView.requestedFPS(maximum: 120, active: true, thermal: .nominal, lowPower: false), 60)
    }

    func testFrameRatePreferencePersistence() throws {
        let suite = "v62-fps-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(UserPreferences(defaults: defaults).renderFrameRate, .fps60)
        for rate in RenderFrameRate.allCases {
            UserPreferences(defaults: defaults).renderFrameRate = rate
            XCTAssertEqual(UserPreferences(defaults: defaults).renderFrameRate, rate)
        }
        defaults.set(90, forKey: "renderFrameRate")
        XCTAssertEqual(UserPreferences(defaults: defaults).renderFrameRate, .fps60)
    }

    func testReferenceShadowCullingComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit shadow comparison")
        for cull in [false, true] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            for (i, key) in s.allBallNodes.keys.sorted().enumerated() {
                guard let node = s.allBallNodes[key] else { continue }
                node.isHidden = false; node.opacity = 1
                node.position = SCNVector3(-0.6+Float(i/4)*0.4,s.surfaceY+AngleSceneCalculator.ballRadius,-0.3+Float(i%4)*0.2)
            }
            if !cull {
                var count = 0
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                        guard let source = m.shaderModifiers?[.surface], source.contains("if(shadowPossible)") else { continue }
                        var baseline = source.replacingOccurrences(of: "if(shadowPossible)", with: "if(true)")
                        for i in 0..<s.allBallNodes.count {
                            baseline = baseline.replacingOccurrences(of: "if(shadowCandidate\(i))", with: "if(contactBall\(i).w>0.0)")
                        }
                        m.shaderModifiers?[.surface] = baseline
                        count += 1
                    }
                }
                XCTAssertGreaterThan(count, 0)
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(cull ? "culled" : "full")-\(pose)")
            }
        }
    }

    func testReferenceLightingIsIdempotent() throws {
        let s = try scene(mobile: true)
        MobileReferenceLighting.apply(to: s)
        func programs() -> [String] {
            var result: [String] = []
            s.rootNode.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] {
                    if let source = material.shaderModifiers?[.surface] { result.append(source) }
                }
            }
            return result
        }
        let before = programs()
        XCTAssertFalse(before.isEmpty)
        MobileReferenceLighting.apply(to: s)
        XCTAssertEqual(programs(), before)
        XCTAssertEqual(s.rootNode.childNodes.filter { $0.name == "S267AreaPanel" }.count, 2)
    }

    func testBallAnalyticAreaComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit area comparison")
        for analytic in [false, true] {
            let s = try scene(mobile: true); MobileReferenceLighting.apply(to: s)
            materials(s) { $0.shaderModifiers?[.surface] = MobileReferenceLighting.sampledBallShader }
            if analytic {
                var count = 0
                materials(s) { m in
                    guard var source = m.shaderModifiers?[.surface],
                          let start = source.range(of: "float3 v62PanelDiffuse("),
                          let end = source.range(of: "float v62World(") else { return }
                    source.replaceSubrange(start.lowerBound..<end.lowerBound,
                        with: MobileReferenceLighting.analyticPanelDiffuse + "\n")
                    m.shaderModifiers?[.surface] = source; count += 1
                }
                XCTAssertGreaterThan(count, 0)
            }
            for pose in ["entry", "detail", "orbit"] {
                if pose == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if pose == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(analytic ? "analytic" : "sampled")-\(pose)")
            }
        }
    }

    /// Isolate specular output; deliberately retain diffuse energy and shadows.
    func testBallMatteComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit matte comparison")
        let output = "albedo*(v62PanelDiffuse(p,n)/3.14159265+env)*(1.0-F)+spec;"
        for striped in [false, true] {
            for (variant, strength) in [("current", 1.0), ("satin", 0.35), ("matte", 0.0)] {
                let s = try scene(mobile: true)
                MobileReferenceLighting.apply(to: s)
                if striped {
                    let cue = try XCTUnwrap(s.cueBallNode)
                    let ball = try XCTUnwrap(s.allBallNodes["_9"])
                    ball.position = cue.position; ball.isHidden = false; ball.opacity = 1
                    cue.isHidden = true
                }
                var modified = 0
                materials(s) { m in
                    guard let shader = m.shaderModifiers?[.surface], shader.contains(output) else { return }
                    m.shaderModifiers?[.surface] = shader.replacingOccurrences(of: output,
                        with: "albedo*(v62PanelDiffuse(p,n)/3.14159265+env)*(1.0-F)+\(strength)*spec;")
                    modified += 1
                }
                XCTAssertGreaterThan(modified, 0, "Ball shader replacement must actually apply")
                s.cameraRig?.handleObservationPinch(scale: 2)
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(striped ? "stripe" : "white")-\(variant)")
            }
        }
    }

    func testBallMaterialResponse() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil,"Explicit response comparison")
        for variant in ["baseline","environment-off","low-reflectance","polished-low-reflectance"] {
            let s=try scene(mobile:true);MobileReferenceLighting.apply(to:s)
            let cue=try XCTUnwrap(s.cueBallNode)
            let striped=try XCTUnwrap(s.allBallNodes["_9"])
            striped.position=cue.position;striped.isHidden=false;striped.opacity=1;cue.isHidden=true
            materials(s) { m in
                guard var shader=m.shaderModifiers?[.surface] else { return }
                if variant == "environment-off" {
                    shader=shader.replacingOccurrences(of:"float3 result=float3(v62World(reflected));",with:"float3 result=float3(0.0);")
                        .replacingOccurrences(of:"result=clothRadiance*clamp",with:"result=0.0*clothRadiance*clamp")
                }
                if variant.contains("low-reflectance") {
                    shader=shader.replacingOccurrences(of:"0.04+0.96*pow",with:"0.02+0.98*pow")
                }
                if variant == "polished-low-reflectance" {
                    shader=shader.replacingOccurrences(of:"float roughness=0.24;",with:"float roughness=0.12;")
                }
                m.shaderModifiers?[.surface]=shader
            }
            s.cameraRig?.handleObservationPinch(scale:2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
            try capture(s,name:variant)
        }
    }

    func testBallDiffuseBalance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil,"Explicit response comparison")
        for variant in ["baseline","diffuse-fill","diffuse-balance"] {
            let s=try scene(mobile:true);MobileReferenceLighting.apply(to:s)
            let cue=try XCTUnwrap(s.cueBallNode)
            let striped=try XCTUnwrap(s.allBallNodes["_9"])
            striped.position=cue.position;striped.isHidden=false;striped.opacity=1;cue.isHidden=true
            materials(s) { m in
                guard var shader=m.shaderModifiers?[.surface] else { return }
                if variant == "environment-off" {
                    shader=shader.replacingOccurrences(of:"float3 result=float3(v62World(reflected));",with:"float3 result=float3(0.0);")
                        .replacingOccurrences(of:"result=clothRadiance*clamp",with:"result=0.0*clothRadiance*clamp")
                }
                if variant.contains("low-reflectance") {
                    shader=shader.replacingOccurrences(of:"0.04+0.96*pow",with:"0.02+0.98*pow")
                }
                if variant == "polished-low-reflectance" {
                    shader=shader.replacingOccurrences(of:"float roughness=0.24;",with:"float roughness=0.12;")
                }
                if variant == "diffuse-fill" || variant == "diffuse-balance" {
                    shader=shader.replacingOccurrences(of:"env=float3(v62worldIntegral(n.y))+clothRadiance*v62bounceIntegral(n.y);",with:"env=2.0*(float3(v62worldIntegral(n.y))+clothRadiance*v62bounceIntegral(n.y));")
                }
                if variant == "diffuse-balance" {
                    shader=shader.replacingOccurrences(of:"albedo*(v62PanelDiffuse(p,n)/3.14159265+env)",with:"albedo*(0.75*v62PanelDiffuse(p,n)/3.14159265+env)")
                }
                m.shaderModifiers?[.surface]=shader
            }
            s.cameraRig?.handleObservationPinch(scale:2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
            try capture(s,name:variant)
        }
    }

    func testReferenceWoodRoughness() throws {
        try captureOriginalWoodVariants(specular: false)
    }

    func testReferenceWoodSpecular() throws {
        try captureOriginalWoodVariants(specular: true)
    }

    private func captureOriginalWoodVariants(specular: Bool) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit original-wood comparison")
        let original=try XCTUnwrap(TableModelLoader.loadTable())
        var originals:[String:SCNMaterial]=[:]
        original.visualNode.enumerateChildNodes { node,_ in
            for m in node.geometry?.materials ?? [] where ["Wood","BlackWood"].contains(m.name ?? "") {
                originals[m.name!]=m
            }
        }
        XCTAssertEqual(originals.count,2)
        let variants = specular ? [("original",1.0),("light",0.65),("medium",0.35),("matte",0.0)] : [("original",0.0),("light",0.08),("medium",0.16)]
        for (label,lift) in variants {
            let s=try scene(mobile:true);MobileReferenceLighting.apply(to:s)
            s.tableNode?.enumerateChildNodes { node,_ in
                guard let geometry=node.geometry else { return }
                geometry.materials=geometry.materials.map { m in
                    guard let source=originals[m.name ?? ""],let copy=source.copy() as? SCNMaterial else { return m }
                    if label != "original" {
                        var modifiers=copy.shaderModifiers ?? [:]
                        let adjustment = specular ? "_surface.specular.rgb *= \(lift);" : "_surface.roughness=clamp(_surface.roughness+\(lift),0.0,1.0);"
                        modifiers[.surface]=(modifiers[.surface] ?? "#pragma body")+"\n"+adjustment
                        if specular {
                            modifiers[.fragment]="#pragma body\n_output.color.rgb=max(float3(0.0),_output.color.rgb-(1.0-\(lift))*_lightingContribution.specular);"
                        }
                        copy.shaderModifiers=modifiers
                    }
                    return copy
                }
            }
            try capture(s,name:"\(label)-entry")
            s.cameraRig?.handleObservationPinch(scale:2)
            s.cameraRig?.handleObservationPan(deltaX:180)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
            try capture(s,name:"\(label)-orbit")
        }
    }

    func testReferenceResponseAblations() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit material ablations")
        for variant in ["baseline", "ball-environment-off", "cloth-specular-off"] {
            let s=try scene(mobile:true); MobileReferenceLighting.apply(to:s)
            if variant == "ball-environment-off" {
                materials(s) { m in
                    guard let source=m.shaderModifiers?[.surface] else { return }
                    m.shaderModifiers?[.surface]=source.replacingOccurrences(of:"float3 spec=float3(v62World(reflected));",with:"float3 spec=float3(0.0);")
                        .replacingOccurrences(of:"spec=clothRadiance*clamp",with:"spec=0.0*clothRadiance*clamp")
                        .replacingOccurrences(of:"float3 result=float3(v62World(reflected));",with:"float3 result=float3(0.0);")
                        .replacingOccurrences(of:"result=clothRadiance*clamp",with:"result=0.0*clothRadiance*clamp")
                }
            }
            if variant == "cloth-specular-off" {
                s.tableNode?.enumerateChildNodes { node,_ in
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                        if let source=m.shaderModifiers?[.surface] {
                            m.shaderModifiers?[.surface]=source.replacingOccurrences(of:"+S+float3(max",with:"+0.0*S+0.0*float3(max").replacingOccurrences(of:"+0.35*S+0.35*float3(max",with:"+0.0*S+0.0*float3(max")
                        }
                    }
                }
            }
            s.cameraRig?.handleObservationPinch(scale:2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
            try capture(s,name:variant)
        }
    }

    func testReferenceRuntimeCapture() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit reference runtime capture")
        XCTAssertNotNil(UIImage(data:MobileReferenceLighting.environment))
        let s=try scene(mobile:true); MobileReferenceLighting.apply(to:s)
        for view in ["entry","detail","orbit"] {
            if view == "detail" { s.cameraRig?.handleObservationPinch(scale:2) }
            if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX:180) }
            for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
            try capture(s,name:"runtime-\(view)")
            let matrix=s.cameraNode.simdWorldTransform
            let rows=(0..<4).map { row in (0..<4).map { column in matrix[column][row] } }
            try JSONSerialization.data(withJSONObject:["rows":rows,"fov":s.cameraNode.camera?.fieldOfView ?? 45,"projectionDirection":s.cameraNode.camera?.projectionDirection.rawValue ?? 0]).write(to:directory.appendingPathComponent("camera-\(view).json"))
        }
    }

    func testReferenceStripedBall() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit striped-ball inspection")
        let s=try scene(mobile:true); MobileReferenceLighting.apply(to:s)
        let cue=try XCTUnwrap(s.cueBallNode)
        let striped=try XCTUnwrap(s.allBallNodes["_9"])
        striped.position=cue.position;striped.isHidden=false;striped.opacity=1
        cue.isHidden=true
        s.cameraRig?.handleObservationPinch(scale:2)
        for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
        try capture(s,name:"striped-detail")
    }

    func testIntegratedBallLighting() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit ball integral prototype")
        let shader = try String(contentsOf:directory.appendingPathComponent("ball.shader"),encoding:.utf8)
        let s=try scene(mobile:true)
        if FileManager.default.fileExists(atPath:directory.appendingPathComponent("surround.hdr").path) {
            s.rootNode.enumerateChildNodes { n,_ in if n.light != nil { n.light?.intensity=0 } }
            s.lightingEnvironment.contents=directory.appendingPathComponent("surround.hdr");s.lightingEnvironment.intensity=1
            for z in [Float(-0.35),Float(0.35)] {
                let light=SCNLight();light.type = .area;light.areaExtents=SIMD3<Float>(2,0.5,0)
                light.intensity=15000;light.drawsArea=true;light.doubleSided=true;light.attenuationEndDistance=10
                let n=SCNNode();n.light=light;n.position=SCNVector3(0,3,z)
                n.look(at:SCNVector3(0,s.surfaceY,z),up:SCNVector3(0,0,1),localFront:SCNVector3(0,0,-1))
                s.rootNode.addChildNode(n)
            }
        }
        materials(s) { m in
            m.lightingModel = .constant
            m.shaderModifiers = [.surface:shader]
        }
        if FileManager.default.fileExists(atPath:directory.appendingPathComponent("cloth.shader").path) {
            var cloth=try String(contentsOf:directory.appendingPathComponent("cloth.shader"),encoding:.utf8)
            var shadow=""
            for i in 0..<s.allBallNodes.count {
                shadow += """
                if(contactBall\(i).w>0.0) {
                    float3 center=float3(contactBall\(i).x,0.8+contactBall\(i).z,contactBall\(i).y);
                    float3 toCenter=center-p;
                    float t=dot(toCenter,l);
                    float perpendicular2=dot(toCenter,toCenter)-t*t;
                    if(t>0.0 && t*t<r2 && perpendicular2 < 0.028575*0.028575) visibility *= 1.0-min(1.0,contactBall\(i).w/0.85);
                }
                """
            }
            var bounds="bool nearShadow=false;\n"
            for i in 0..<s.allBallNodes.count {
                bounds += """
                if(contactBall\(i).w>0.0) {
                    float bound=0.028575+contactBall\(i).z/max(0.01,2.2-contactBall\(i).z)*(length(contactBall\(i).xy)+1.3);
                    float2 offset=p.xz-contactBall\(i).xy;
                    nearShadow=nearShadow || dot(offset,offset)<bound*bound;
                }
                """
            }
            cloth=cloth.replacingOccurrences(of:"// NEAR_SHADOW",with:bounds)
            cloth=cloth.replacingOccurrences(of:"// SHADOW",with:shadow)
            s.tableNode?.enumerateChildNodes { node,_ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    var mods=m.shaderModifiers ?? [:]
                    mods[.surface]=(mods[.surface] ?? "#pragma body")+"\n"+cloth
                    m.lightingModel = .physicallyBased;m.shaderModifiers=mods
                }
            }
        }
        try capture(s,name:"integrated")
    }

    func testIsolatedGraySphereParity() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit parity diagnostic")
        for mode in ["combined", "direct", "environment"] {
            for hdr in [true, false] {
                let s = SCNScene(); s.background.contents = UIColor.black
                let sphere = SCNSphere(radius: 0.25); sphere.segmentCount = 64
                let m = SCNMaterial(); m.lightingModel = .physicallyBased
                m.roughness.contents = Float(1); m.metalness.contents = Float(0)
                m.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                m.specular.contents = UIColor.black
                if ProcessInfo.processInfo.environment["V62_SHOT_DIR"]?.contains("S279") == true {
                    var shader=try String(contentsOf:directory.appendingPathComponent("ball.shader"),encoding:.utf8)
                    if mode == "direct" { shader=shader.replacingOccurrences(of:"float3(v62World(d))/64.0",with:"float3(0.0)") }
                    if mode == "environment" { shader=shader.replacingOccurrences(of:"v62PanelDiffuse(p,n)/3.14159265",with:"float3(0.0)") }
                    m.lightingModel = .constant; m.shaderModifiers = [.surface:shader]
                }
                sphere.materials = [m]
                let ball = SCNNode(geometry: sphere); ball.position = SCNVector3(0,0.25,0); s.rootNode.addChildNode(ball)
                if mode != "direct" {
                    s.lightingEnvironment.contents = directory.appendingPathComponent("surround.hdr")
                    s.lightingEnvironment.intensity = 1
                }
                if mode != "environment" {
                    for z in [Float(-0.35), Float(0.35)] {
                        let light = SCNLight(); light.type = .area; light.areaType = .rectangle
                        light.areaExtents = SIMD3<Float>(2,0.5,0); light.intensity = 15000
                        light.drawsArea = true; light.doubleSided = true; light.attenuationEndDistance = 10
                        let n = SCNNode(); n.light=light; n.position=SCNVector3(0,2.2,z)
                        n.look(at: SCNVector3(0,0,z), up: SCNVector3(0,0,1), localFront: SCNVector3(0,0,-1))
                        s.rootNode.addChildNode(n)
                    }
                }
                let cam=SCNNode(); cam.camera=SCNCamera(); cam.camera?.usesOrthographicProjection=true
                cam.camera?.orthographicScale=0.6; cam.camera?.wantsHDR=hdr
                cam.camera?.wantsExposureAdaptation=false; cam.camera?.exposureOffset = -0.45
                cam.position=SCNVector3(0,1,3); cam.look(at: SCNVector3(0,0.25,0))
                s.rootNode.addChildNode(cam)
                let r=SCNRenderer(device:try XCTUnwrap(MTLCreateSystemDefaultDevice()),options:nil)
                r.scene=s;r.pointOfView=cam;r.autoenablesDefaultLighting=false
                _ = r.snapshot(atTime:0,with:CGSize(width:512,height:512),antialiasingMode:.multisampling4X)
                let image=r.snapshot(atTime:0,with:CGSize(width:512,height:512),antialiasingMode:.multisampling4X)
                try XCTUnwrap(image.pngData()).write(to:directory.appendingPathComponent("app-\(mode)-hdr\(hdr).png"))
            }
        }
    }

    func testS267UnifiedIBLTransfer() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit transfer diagnostic")
        for variant in ["current", "ibl", "ibl-linearBall"] {
            let s = try scene(mobile: true)
            if variant != "current" {
                s.rootNode.enumerateChildNodes { node, _ in
                    if node.light != nil { node.light?.intensity = 0 }
                }
                s.lightingEnvironment.contents = directory.appendingPathComponent("unified.hdr")
                s.lightingEnvironment.intensity = 1
                if variant == "ibl-linearBall" {
                    materials(s) { material in
                        var mods = material.shaderModifiers ?? [:]
                        mods[.fragment] = nil
                        material.shaderModifiers = mods
                    }
                }
            }
            try capture(s, name: variant)
        }
    }

    func testS267NativeAreaTransfer() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit transfer diagnostic")
        for power in [CGFloat(0), 15000, 30000, 60000] {
            let s = try scene(mobile: true)
            if power > 0 {
                s.rootNode.enumerateChildNodes { node, _ in
                    if node.light != nil { node.light?.intensity = 0 }
                }
                materials(s) { material in
                    var mods = material.shaderModifiers ?? [:]; mods[.fragment] = nil
                    material.shaderModifiers = mods
                }
                s.lightingEnvironment.contents = directory.appendingPathComponent("surround.hdr")
                s.lightingEnvironment.intensity = 1
                for z in [Float(-0.35), Float(0.35)] {
                    let light = SCNLight()
                    light.type = .area
                    light.areaType = .rectangle
                    light.areaExtents = SIMD3<Float>(2, 0.5, 0)
                    light.drawsArea = true
                    light.doubleSided = true
                    light.attenuationEndDistance = 10
                    light.intensity = power
                    light.color = UIColor(red: 1, green: 0.985, blue: 0.96, alpha: 1)
                    light.castsShadow = false
                    light.shadowMapSize = CGSize(width: 1024, height: 1024)
                    let node = SCNNode(); node.light = light
                    node.position = SCNVector3(0, 3, z)
                    node.look(at: SCNVector3(0, s.surfaceY, z), up: SCNVector3(0, 0, 1), localFront: SCNVector3(0, 0, -1))
                    XCTAssertLessThan(simd_length(node.simdWorldFront - SIMD3<Float>(0, -1, 0)), 0.001)
                    s.rootNode.addChildNode(node)
                }
            }
            try capture(s, name: "power-\(Int(power))")
        }
    }

    func testVideoReferenceLightFrame() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit video reference diagnostic")
        let url = directory.appendingPathComponent("lightframe.hdr")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        for variant in ["current", "lightframe"] {
            let s = try scene(mobile: true)
            if variant == "lightframe" { s.lightingEnvironment.contents = url }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testCurrentClothLightCalibration() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit offline calibration")
        for variant in ["full", "ambient", "directional", "spot", "environment"] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    m.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                    m.multiply.contents = UIColor.white
                    m.normal.contents = nil
                    m.roughness.contents = Float(1)
                    m.metalness.contents = Float(0)
                    m.ambientOcclusion.contents = Float(1)
                    var mods = m.shaderModifiers ?? [:]
                    mods[.surface] = nil; mods[.fragment] = nil
                    m.shaderModifiers = mods
                }
            }
            if variant != "full" {
                if variant != "environment" { s.lightingEnvironment.intensity = 0 }
                s.rootNode.enumerateChildNodes { node, _ in
                    if let light = node.light, light.type.rawValue != variant { light.intensity = 0 }
                }
            }
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: variant)
        }
    }

    func testClothBedNormalIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit geometry diagnostic")
        for variant in ["current", "flatBedNormal"] {
            let s = try scene(mobile: true)
            if variant == "flatBedNormal" {
                var count = 0
                s.tableNode?.enumerateChildNodes { node, _ in
                    let up = node.convertVector(SCNVector3(0, 1, 0), from: s.rootNode)
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                        var modifiers = m.shaderModifiers ?? [:]
                        let source = modifiers[.geometry] ?? "#pragma body"
                        modifiers[.geometry] = source + """

                        float3 diagnosticUp = normalize(float3(\(up.x),\(up.y),\(up.z)));
                        float4 diagnosticWorld = scn_node.modelTransform * _geometry.position;
                        if (abs(diagnosticWorld.y - \(s.surfaceY)) < 0.00002 && dot(normalize(_geometry.normal), diagnosticUp) > 0.95) {
                            _geometry.normal = diagnosticUp;
                        }
                        """
                        m.shaderModifiers = modifiers
                        count += 1
                    }
                }
                XCTAssertGreaterThan(count, 0)
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testClothAlbedoContrastIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit material diagnostic")
        for variant in ["current", "boundedFiber"] {
            let s = try scene(mobile: true)
            if variant == "boundedFiber" {
                var count = 0
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                        var modifiers = m.shaderModifiers ?? [:]
                        let source = modifiers[.surface] ?? ""
                        let old = "float clothFiber = clamp(1.0 + 4.0 * (_surface.roughness - 0.8), 0.5, 1.5);"
                        XCTAssertTrue(source.contains(old))
                        modifiers[.surface] = source.replacingOccurrences(of: old, with: "float fiberDeviation = 4.0 * (_surface.roughness - 0.8); float clothFiber = 1.0 + 0.12 * fiberDeviation / (0.12 + abs(fiberDeviation));")
                        m.shaderModifiers = modifiers
                        count += 1
                    }
                }
                XCTAssertGreaterThan(count, 0)
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testClothFilteringIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit material diagnostic")
        for variant in ["current", "anisotropy8"] {
            let s = try scene(mobile: true)
            var count = 0
            s.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    for property in [m.normal, m.roughness] {
                        print("CLOTH_FILTER \(variant) anisotropy=\(property.maxAnisotropy) min=\(property.minificationFilter.rawValue) mip=\(property.mipFilter.rawValue)")
                        if variant == "anisotropy8" { property.maxAnisotropy = 8 }
                    }
                    count += 1
                }
            }
            XCTAssertGreaterThan(count, 0)
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testClothTextureScaleTransfer() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit material diagnostic")
        for variant in ["current", "clothScale2"] {
            let s = try scene(mobile: true)
            do { // Pin both variants so adopting the candidate cannot erase the comparison.
                let textureScale: Float = variant == "clothScale2" ? 2 : 1
                var count = 0
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                        for property in [m.normal, m.roughness] {
                            XCTAssertNotNil(property.contents)
                            property.contentsTransform = SCNMatrix4MakeScale(textureScale, textureScale, 1)
                            property.wrapS = .repeat
                            property.wrapT = .repeat
                        }
                        count += 1
                    }
                }
                XCTAssertGreaterThan(count, 0)
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testBlenderWoodRoughnessTransfer() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for variant in ["current", "woodSoft"] {
            let s = try scene(mobile: true)
            if variant == "woodSoft" {
                var count = 0
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where ["Wood", "BlackWood"].contains(m.name ?? "") {
                        var modifiers = m.shaderModifiers ?? [:]
                        let source = modifiers[.surface] ?? "#pragma body"
                        XCTAssertTrue(source.contains("#pragma body"))
                        modifiers[.surface] = source.replacingOccurrences(of: "#pragma body", with: """
                        #pragma body
                        float woodY = dot(_surface.diffuse.rgb, float3(0.2126,0.7152,0.0722));
                        _surface.roughness = mix(0.22,0.26,clamp((woodY-0.04068398378472859)/(0.07429590255310332-0.04068398378472859),0.0,1.0));
                        """)
                        m.shaderModifiers = modifiers
                        count += 1
                    }
                }
                XCTAssertEqual(count, 2)
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testLeatherBoundedTintTransfer() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit material diagnostic")
        let cases: [(String, UIColor, String)] = [
            ("target", PocketLeatherAppearance.targetTint, "8.230530978671244,11.186813922401255,1.5325792484475174"),
            ("first", PocketLeatherAppearance.firstRoleTint, "1.3135267863911544,21.81101806224492,10.883660841251789"),
            ("second", PocketLeatherAppearance.secondRoleTint, "0.6493951726466205,18.2971481216344,35.96047560473092")
        ]
        for (name, tint, gain) in cases {
            for variant in ["current", "texture"] {
                let s = try scene(mobile: true)
                var changed = 0
                s.tableNode?.enumerateChildNodes { node, _ in
                    guard let geometry = node.geometry else { return }
                    geometry.materials = geometry.materials.map { original in
                        guard original.name == "Leather" else { return original }
                        changed += 1
                        let material = PocketLeatherAppearance.material(from: original, tint: tint)
                        if variant == "texture" {
                            var modifiers = material.shaderModifiers ?? [:]
                            modifiers[.surface] = "#pragma body\n_surface.diffuse.rgb = clamp(_surface.diffuse.rgb * float3(\(gain)), 0.0, 1.0);"
                            material.shaderModifiers = modifiers
                        }
                        return material
                    }
                }
                XCTAssertEqual(changed, 1)
                try capture(s, name: "\(name)-\(variant)")
            }
        }
    }

    func testBallLightingOutputs() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for channel in ["current", "ambient", "diffuse", "specular"] {
            let s = try scene(mobile: true)
            if channel != "current" {
                materials(s) { material in
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = "#pragma body\n_output.color.rgb = _lightingContribution.\(channel);"
                    material.shaderModifiers = modifiers
                }
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(channel)-detail")
        }
    }

    func testClothDetailCameraSequence() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for enabled in [false, true] {
            let s = try scene(mobile: true)
            if !enabled {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = modifiers[.surface]?.replacingOccurrences(of: "_surface.diffuse.rgb *= clothFiber;", with: "")
                        material.shaderModifiers = modifiers
                    }
                }
            }
            let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
            renderer.scene = s; renderer.pointOfView = s.cameraNode
            renderer.delegate = s.contactOcclusion; renderer.autoenablesDefaultLighting = false
            let folder = directory.appendingPathComponent(enabled ? "orbit/on" : "orbit/off")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let initial = s.cameraNode.simdWorldTransform
            for frame in 0...90 {
                s.cameraRig?.handleObservationPan(deltaX: 4)
                s.cameraRig?.update(deltaTime: 1/60)
                let shot = renderer.snapshot(atTime: Double(frame)/60, with: CGSize(width: 588, height: 1000), antialiasingMode: .multisampling4X)
                if frame % 3 == 0 {
                    try XCTUnwrap(shot.pngData()).write(to: folder.appendingPathComponent(String(format: "%05d.png", frame)))
                }
            }
            XCTAssertNotEqual(s.cameraNode.simdWorldTransform, initial)
        }
    }

    func testClothAlbedoMicrostructure() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, strength) in [("current", 0.0), ("fiber4", 4.0), ("fiber8", 8.0)] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.surface] = (modifiers[.surface] ?? "#pragma body") + "\n_surface.diffuse.rgb *= clamp(1.0 + \(strength) * (_surface.roughness - 0.8), 0.5, 1.5);"
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testClothRoughnessSignal() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for mode in ["current", "roughness", "fiber35", "fiber70"] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                    var modifiers = material.shaderModifiers ?? [:]
                    if mode == "roughness" {
                        modifiers[.fragment] = """
                        #pragma body
                        _output.color.rgb = float3(_surface.roughness);
                        """
                    } else if mode.hasPrefix("fiber") {
                        let strength = mode == "fiber35" ? 0.35 : 0.70
                        modifiers[.surface] = (modifiers[.surface] ?? "#pragma body") + "\n_surface.diffuse.rgb *= 1.0 + \(strength) * (_surface.roughness - 0.8);"
                    }
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(mode)-\(view)")
            }
        }
    }

    func testClothNormalSignal() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for mode in ["current", "zero", "removed"] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                    print("CLOTH_NORMAL", mode, String(describing: material.normal.contents), material.normal.mappingChannel, material.normal.contentsTransform)
                    if mode == "zero" { material.normal.intensity = 0 }
                    if mode == "removed" { material.normal.contents = nil }
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = """
                    #pragma body
                    _output.color.rgb = normalize(_surface.normal) * 0.5 + 0.5;
                    """
                    material.shaderModifiers = modifiers
                }
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(mode)-normal")
        }
    }

    func testConstantTextureElimination() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for enabled in [false, true] {
            let s = try scene(mobile: true)
            if enabled {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] {
                        if ["TaiNi", "Wood", "BlackWood", "Leather"].contains(material.name ?? "") {
                            material.metalness.contents = Float(0)
                        }
                    }
                }
            }
            for view in ["entry", "orbit", "full"] {
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                if view == "full" { s.cameraRig?.handleObservationPinch(scale: 0.5) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name:"compare/\(view)-\(enabled ? "constants" : "textures")")
            }
        }
    }

    func testPocketVolumeOcclusion() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let rows = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("boxes.json"))) as? [[String: Any]])
        XCTAssertEqual(rows.count, 6)
        let s = try scene(mobile: true)
        let table = try XCTUnwrap(s.tableNode)
        let n = 8, width = 64, height = 48, rays = 32
        let cachedTexture = UIImage(contentsOfFile: directory.appendingPathComponent("input-volume.png").path)
        var pixels = [UInt8](repeating: 255, count: width * height)
        var body = "#pragma arguments\ntexture2d<float> pocketVolume;\n#pragma body\nfloat3 p = (scn_frame.inverseViewTransform * float4(_surface.position,1)).xyz;\n"
        for (box, row) in rows.enumerated() {
            let low = try XCTUnwrap(row["min"] as? [Double]).map(Float.init)
            let high = try XCTUnwrap(row["max"] as? [Double]).map(Float.init)
            if cachedTexture == nil {
            for iy in 0..<n { for iz in 0..<n { for ix in 0..<n {
                let origin = SCNVector3(low[0] + (high[0]-low[0])*Float(ix)/7,
                                       low[1] + (high[1]-low[1])*Float(iy)/7,
                                       low[2] + (high[2]-low[2])*Float(iz)/7)
                var hits = 0
                for ray in 0..<rays {
                    let dy = 1 - 2*(Float(ray)+0.5)/Float(rays)
                    let phi = Float(ray)*2.39996323
                    let ring = sqrt(1-dy*dy)
                    let direction = SCNVector3(ring*cos(phi),dy,ring*sin(phi))
                    let end = SCNVector3(origin.x+direction.x*0.25,origin.y+direction.y*0.25,origin.z+direction.z*0.25)
                    if !table.hitTestWithSegment(from: table.convertPosition(origin, from: s.rootNode),
                        to: table.convertPosition(end, from: s.rootNode),
                        options: [SCNHitTestOption.backFaceCulling.rawValue:false,
                                  SCNHitTestOption.searchMode.rawValue:SCNHitTestSearchMode.any.rawValue]).isEmpty { hits += 1 }
                }
                pixels[(box*n+iz)*width + iy*n+ix] = UInt8(round(Float(rays-hits)/Float(rays)*255))
            } } }
            }
            body += """

            if (all(p >= float3(\(low[0]),\(low[1]),\(low[2]))) && all(p <= float3(\(high[0]),\(high[1]),\(high[2])))) {
                float3 q = (p-float3(\(low[0]),\(low[1]),\(low[2]))) / float3(\(high[0]-low[0]),\(high[1]-low[1]),\(high[2]-low[2])) * 7.0;
                float y0 = floor(q.y), y1 = min(7.0,y0+1.0);
                constexpr sampler ps(coord::normalized,address::clamp_to_edge,filter::linear);
                float2 uv0 = float2(y0*8.0+q.x+0.5, \(box*8).0+q.z+0.5)/float2(64,48);
                float2 uv1 = float2(y1*8.0+q.x+0.5, \(box*8).0+q.z+0.5)/float2(64,48);
                _surface.ambientOcclusion = mix(pocketVolume.sample(ps,uv0).r,pocketVolume.sample(ps,uv1).r,fract(q.y));
            }
            """
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels.flatMap { [$0,$0,$0,UInt8(255)] }) as CFData))
        let cg = try XCTUnwrap(CGImage(width: width,height: height,bitsPerComponent: 8,bitsPerPixel: 32,bytesPerRow: width*4,
            space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,decode: nil,shouldInterpolate: true,intent: .defaultIntent))
        let texture = cachedTexture ?? UIImage(cgImage: cg)
        try XCTUnwrap(texture.pngData()).write(to: directory.appendingPathComponent("pocket-volume.png"))
        var originals: [(SCNMaterial, [SCNShaderModifierEntryPoint: String])] = []
        table.enumerateChildNodes { node,_ in
            for material in node.geometry?.materials ?? [] where material.name == "White" {
                originals.append((material, material.shaderModifiers ?? [:]))
                material.setValue(SCNMaterialProperty(contents: texture),forKey:"pocketVolume")
            }
        }
        s.cameraRig?.handleObservationPinch(scale: 0.5)
        for view in 0..<8 {
            if view > 0 { s.cameraRig?.handleObservationPan(deltaX: 180) }
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            for enabled in [false,true] {
                for (material, original) in originals {
                    var modifiers = original
                    if enabled { modifiers[.surface] = body }
                    material.shaderModifiers = modifiers
                }
                try capture(s,name:"compare/orbit-\(view)-\(enabled ? "on" : "off")")
            }
        }
    }

    func testWhiteConnectedComponents() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let s = try scene(mobile: true)
        var rows: [[String: Any]] = []
        var failure: Error?
        s.tableNode?.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry,
                  let source = geometry.sources(for: .vertex).first,
                  source.usesFloatComponents, source.bytesPerComponent == 4 else { return }
            let sourceIndex = geometry.sources.firstIndex(where: { $0 === source }) ?? 0
            let channel = geometry.geometrySourceChannels?[sourceIndex].intValue ?? 0
            var parent: [Int: Int] = [:]
            func root(_ index: Int) -> Int {
                var current = index
                while let next = parent[current], next != current { current = next }
                return current
            }
            do {
                for (index, element) in geometry.elements.enumerated()
                where geometry.materials[index % geometry.materials.count].name == "White" {
                    for face in try PocketLeatherMesh.decode(element) {
                        let indices = stride(from: channel, to: face.count, by: element.indicesChannelCount).map { Int(face[$0]) }
                        guard let first = indices.first else { continue }
                        for i in indices { if parent[i] == nil { parent[i] = i } }
                        for i in indices { parent[root(i)] = root(first) }
                    }
                }
            } catch { failure = error; return }
            var groups: [Int: [Int]] = [:]
            for i in parent.keys { groups[root(i), default: []].append(i) }
            for indices in groups.values {
                var low = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
                var high = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
                for i in indices {
                    let point = source.data.withUnsafeBytes { bytes -> SCNVector3 in
                        let start = source.dataOffset + i * source.dataStride
                        return node.convertPosition(SCNVector3(
                            bytes.loadUnaligned(fromByteOffset: start, as: Float.self),
                            bytes.loadUnaligned(fromByteOffset: start + 4, as: Float.self),
                            bytes.loadUnaligned(fromByteOffset: start + 8, as: Float.self)), to: s.rootNode)
                    }
                    low = simd_min(low, SIMD3(point.x, point.y, point.z))
                    high = simd_max(high, SIMD3(point.x, point.y, point.z))
                }
                rows.append(["node": node.name ?? "", "vertices": indices.count,
                             "min": [low.x, low.y, low.z], "max": [high.x, high.y, high.z]])
            }
        }
        if let failure { throw failure }
        XCTAssertFalse(rows.isEmpty)
        let threshold = MobileTableRendering.inlayHeightThreshold
        var inlayCount = 0
        for row in rows {
            let low = try XCTUnwrap(row["min"] as? [Float])
            let high = try XCTUnwrap(row["max"] as? [Float])
            XCTAssertTrue(high[1] < threshold || low[1] > threshold, "White component crosses inlay threshold")
            if low[1] > threshold {
                inlayCount += 1
                XCTAssertEqual(row["vertices"] as? Int, 64)
            }
        }
        XCTAssertEqual(inlayCount, 18)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("white-components.json"))
    }

    func testKeyEnvironmentCalibration() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for (name, environment, key) in [("current", 0.7, 8.0), ("halfLow", 0.35, 8.0), ("halfHigh", 0.35, 80.0), ("lowLow", 0.1, 8.0), ("lowHigh", 0.1, 80.0)] {
            let s = try scene(mobile: true)
            s.lightingEnvironment.intensity = CGFloat(environment)
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true { node.light?.intensity = CGFloat(key) }
            }
            // Diagnostic gray, flat bed only. Restore original material in the visual follow-up.
            s.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    m.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                    m.multiply.contents = UIColor.white
                    m.normal.contents = nil
                    m.roughness.contents = Float(1)
                    // Preserve geometry alignment; remove material modifiers only.
                    var modifiers = m.shaderModifiers ?? [:]
                    modifiers.removeValue(forKey: .surface)
                    modifiers.removeValue(forKey: .fragment)
                    m.shaderModifiers = modifiers
                }
            }
            try capture(s, name: "compare/\(name)")
        }
    }

    func testTrainingGuidesDoNotCastShadows() throws {
        for training in [false, true] {
            let s = try scene(mobile: true)
            s.setupVisualizationNodes(usesTrainingAssistStyle: training)
            let start = SCNVector3(0,s.surfaceY + 0.028575,0)
            let end = SCNVector3(0.4,start.y,0.2)
            let extra = [s.addLine(from: start,to:end,color:.white),
                         s.addDashedLine(from:start,to:end,color:.white),
                         s.addAimPointMarker(at:start)]
            let names = ["ghostBall","pocketLine","strikeLine","contactDot","angleArc","perpLine"]
            let roots = extra + s.rootNode.childNodes.filter { names.contains($0.name ?? "") }
            XCTAssertEqual(roots.count, 9)
            var geometryCount = 0
            for root in roots {
                func check(_ node: SCNNode) {
                    if node.geometry != nil {
                        geometryCount += 1
                        XCTAssertFalse(node.castsShadow, "Virtual guide casts shadow: \(node.name ?? root.name ?? "segment")")
                    }
                }
                check(root)
                root.enumerateChildNodes { node,_ in check(node) }
            }
            XCTAssertGreaterThan(geometryCount, 10)
            XCTAssertTrue(s.allBallNodes.values.contains { $0.castsShadow })
        }
    }

    func testOffsetKeyCalibration() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let variants: [(String, Float, Float)] = [("current",0,0),("xPlus",1,0),("xMinus",-1,0),("zPlus",0,0.8),("zMinus",0,-0.8)]
        for (name, offsetX, offsetZ) in variants {
          for key in (name == "current" ? [8.0] : [8.0, 80.0]) {
            let s = try scene(mobile: true)
            s.lightingEnvironment.intensity = CGFloat(name == "current" ? 0.7 : 0.35)
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true {
                    node.light?.intensity = CGFloat(key)
                    if name != "current" {
                        node.position = SCNVector3(offsetX, s.surfaceY + 2.2, offsetZ)
                        node.look(at: SCNVector3(0, s.surfaceY, 0))
                        let target = SIMD3<Float>(0,s.surfaceY,0)
                        XCTAssertGreaterThan(simd_dot(node.simdWorldFront, simd_normalize(target-node.simdWorldPosition)), 0.9999)
                    }
                }
            }
            // Diagnostic gray, flat bed only. Restore original material in the visual follow-up.
            s.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    m.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                    m.multiply.contents = UIColor.white
                    m.normal.contents = nil
                    m.roughness.contents = Float(1)
                    // Preserve geometry alignment; remove material modifiers only.
                    var modifiers = m.shaderModifiers ?? [:]
                    modifiers.removeValue(forKey: .surface)
                    modifiers.removeValue(forKey: .fragment)
                    m.shaderModifiers = modifiers
                }
            }
            try capture(s, name: "compare/\(name)-\(Int(key))")
          }
        }
    }

    func testMatchedOffsetKey() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let variants: [(String, Float, Float, Double)] = [("current",0,0,8),("xPlus",1,0,25.995107651912413),("xMinus",-1,0,11.950917230151703),("zPlus",0,0.8,17.49145539983722),("zMinus",0,-0.8,16.589330463134992)]
        for (name, offsetX, offsetZ, key) in variants {
          for gray in [true, false] {
            let s = try scene(mobile: true)
            s.lightingEnvironment.intensity = CGFloat(name == "current" ? 0.7 : 0.35)
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true {
                    node.light?.intensity = CGFloat(key)
                    if name != "current" {
                        node.position = SCNVector3(offsetX, s.surfaceY + 2.2, offsetZ)
                        node.look(at: SCNVector3(0, s.surfaceY, 0))
                        let target = SIMD3<Float>(0,s.surfaceY,0)
                        XCTAssertGreaterThan(simd_dot(node.simdWorldFront, simd_normalize(target-node.simdWorldPosition)), 0.9999)
                    }
                }
            }
            if gray {
            s.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    m.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                    m.multiply.contents = UIColor.white
                    m.normal.contents = nil
                    m.roughness.contents = Float(1)
                    // Preserve geometry alignment; remove material modifiers only.
                    var modifiers = m.shaderModifiers ?? [:]
                    modifiers.removeValue(forKey: .surface)
                    modifiers.removeValue(forKey: .fragment)
                    m.shaderModifiers = modifiers
                }
            }
            }
            if gray {
                try capture(s, name: "gray/\(name)")
            } else {
                for view in ["entry", "detail", "orbit"] {
                    if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                    if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                    for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                    try capture(s, name: "compare/\(name)-\(view)")
                }
            }
          }
        }
    }

    func testMatchedKeyEnvironment() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for (name, environment, key) in [("current", 0.7, 8.0), ("half", 0.35, 16.24344686890314), ("low", 0.1, 22.12959584327318)] {
            for gray in [true, false] {
            let s = try scene(mobile: true)
            s.lightingEnvironment.intensity = CGFloat(environment)
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true { node.light?.intensity = CGFloat(key) }
            }
            if gray {
            s.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                    m.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                    m.multiply.contents = UIColor.white
                    m.normal.contents = nil
                    m.roughness.contents = Float(1)
                    // Preserve geometry alignment; remove material modifiers only.
                    var modifiers = m.shaderModifiers ?? [:]
                    modifiers.removeValue(forKey: .surface)
                    modifiers.removeValue(forKey: .fragment)
                    m.shaderModifiers = modifiers
                }
            }
            }
            if gray {
                try capture(s, name: "gray/\(name)")
            } else {
                for view in ["entry", "detail", "orbit"] {
                    if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                    if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                    for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                    try capture(s, name: "compare/\(name)-\(view)")
                }
            }
            }
        }
    }

    func testOfflineGrayLightCalibration() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        var lights: [[String: Any]] = []
        for mode in ["environment", "key", "all", "material-environment"] {
            let s = try scene(mobile: true)
            s.rootNode.enumerateChildNodes { node, _ in
                if let light = node.light {
                    if mode == "all" {
                        let matrix = node.simdWorldTransform
                        lights.append(["type":light.type.rawValue,"intensity":light.intensity,"castsShadow":light.castsShadow,
                            "worldRows":(0..<4).map { r in (0..<4).map { c in matrix[c][r] } },
                            "inner":light.spotInnerAngle,"outer":light.spotOuterAngle])
                    }
                    if mode == "environment" || mode == "material-environment" || (mode == "key" && !light.castsShadow) { light.intensity = 0 }
                }
                for m in node.geometry?.materials ?? [] {
                    let geo = m.shaderModifiers?[.geometry]
                    m.shaderModifiers = geo.map { [.geometry:$0] } ?? [:]
                    if mode == "material-environment" { continue }
                    m.diffuse.contents = UIColor(white: 0.5, alpha: 1)
                    m.multiply.contents = UIColor.white
                    m.lightingModel = .physicallyBased
                    m.metalness.contents = Float(0)
                    m.roughness.contents = Float(1)
                    m.normal.contents = nil
                    m.ambientOcclusion.contents = Float(1)
                    m.emission.contents = UIColor.black
                }
            }
            if mode == "key" { s.lightingEnvironment.intensity = 0 }
            try capture(s, name: mode)
        }
        try JSONSerialization.data(withJSONObject: lights, options: [.prettyPrinted])
            .write(to: directory.appendingPathComponent("lights.json"))
    }

    func testOfflineGeometryExport() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let s = try scene(mobile: true)
        try capture(s, name: "current")
        let bed = try XCTUnwrap(MobileClothAlignment.measuredBedY(in: s))
        func binding(_ property: SCNMaterialProperty) throws -> [String: Any] {
            let transform = simd_float4x4(property.contentsTransform)
            var result: [String: Any] = ["uvChannel": property.mappingChannel, "intensity": property.intensity,
                "transformRows": (0..<4).map { r in (0..<4).map { c in transform[c][r] } }]
            if let url = property.contents as? URL {
                let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
                let offsetText = try XCTUnwrap(parts.queryItems?.first(where: { $0.name == "offset" })?.value)
                let sizeText = try XCTUnwrap(parts.queryItems?.first(where: { $0.name == "size" })?.value)
                let offset = try XCTUnwrap(UInt64(offsetText))
                let size = try XCTUnwrap(Int(sizeText))
                var base = parts; base.query = nil
                let handle = try FileHandle(forReadingFrom: XCTUnwrap(base.url))
                defer { do { try handle.close() } catch { XCTFail("Texture file close failed: \(error)") } }
                try handle.seek(toOffset: offset)
                let bytes = try XCTUnwrap(handle.read(upToCount: size))
                XCTAssertEqual(bytes.count, size)
                let name = "texture-\(offset).png"
                try bytes.write(to: directory.appendingPathComponent(name))
                result["texture"] = name
            } else if let color = property.contents as? UIColor {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
                XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &alpha))
                result["srgb"] = [r,g,b,alpha]
            } else if let number = property.contents as? NSNumber {
                result["scalar"] = number.doubleValue
            } else if property.contents != nil {
                result["unsupported"] = String(describing: property.contents)
            }
            return result
        }
        var rows: [[String: Any]] = []
        var nodes: [SCNNode] = []
        s.rootNode.enumerateChildNodes { node, _ in nodes.append(node) }
        for node in nodes {
            var parent: SCNNode? = node
            var visible = true
            while let n = parent {
                if n.isHidden || n.opacity == 0 { visible = false }
                parent = n.parent
            }
            guard visible, let g = node.geometry, !g.materials.isEmpty,
                  let si = g.sources.firstIndex(where: { $0.semantic == .vertex }) else { continue }
            let src = g.sources[si]
            XCTAssertTrue(src.usesFloatComponents)
            XCTAssertEqual(src.bytesPerComponent, 4)
            let channel = g.geometrySourceChannels?[si].intValue ?? 0
            let ni = g.sources.firstIndex(where: { $0.semantic == .normal })
            let ti = g.sources.firstIndex(where: { $0.semantic == .texcoord })
            let transform = node.simdWorldTransform
            let normalMatrix = simd_transpose(simd_inverse(simd_float3x3(SIMD3(transform.columns.0.x,transform.columns.0.y,transform.columns.0.z), SIMD3(transform.columns.1.x,transform.columns.1.y,transform.columns.1.z), SIMD3(transform.columns.2.x,transform.columns.2.y,transform.columns.2.z))))
            func vector(sourceIndex: Int, face: [UInt32], base: Int, element: SCNGeometryElement) -> [Float] {
                let source = g.sources[sourceIndex]
                let c = g.geometrySourceChannels?[sourceIndex].intValue ?? 0
                let index = Int(face[base + c])
                XCTAssertTrue(source.usesFloatComponents)
                XCTAssertEqual(source.bytesPerComponent, 4)
                XCTAssertLessThan(index, source.vectorCount)
                return source.data.withUnsafeBytes { bytes in
                    (0..<source.componentsPerVector).map { component in
                        bytes.loadUnaligned(fromByteOffset: source.dataOffset + index * source.dataStride + component * 4, as: Float.self)
                    }
                }
            }
            for (ei, element) in g.elements.enumerated() {
                guard element.primitiveType == .triangles || element.primitiveType == .polygon else { continue }
                let m = g.materials[ei % g.materials.count]
                var vertices: [[Float]] = []
                var faces: [[Int]] = []
                var normals: [[Float]] = []
                var uvs: [[Float]] = []
                for face in try PocketLeatherMesh.decode(element) {
                    var indices: [Int] = []
                    for k in stride(from: channel, to: face.count, by: element.indicesChannelCount) {
                        let i = Int(face[k])
                        XCTAssertLessThan(i, src.vectorCount)
                        let v = src.data.withUnsafeBytes { bytes -> SCNVector3 in
                            let o = src.dataOffset + i * src.dataStride
                            return SCNVector3(bytes.loadUnaligned(fromByteOffset: o, as: Float.self),
                                              bytes.loadUnaligned(fromByteOffset: o + 4, as: Float.self),
                                              bytes.loadUnaligned(fromByteOffset: o + 8, as: Float.self))
                        }
                        var w = node.convertPosition(v, to: s.rootNode)
                        if (m.name == "TaiNi" || m.name == "White"),
                           m.shaderModifiers?[.geometry]?.contains("bedWorld") == true,
                           w.y >= bed - 0.00001, w.y < s.surfaceY - 0.00001 { w.y += s.surfaceY - bed }
                        indices.append(vertices.count)
                        vertices.append([w.x, w.y, w.z])
                        if let ni {
                            let n = vector(sourceIndex: ni, face: face, base: k - channel, element: element)
                            let world = simd_normalize(normalMatrix * SIMD3<Float>(n[0],n[1],n[2]))
                            if world.x.isFinite && world.y.isFinite && world.z.isFinite {
                                normals.append([world.x,world.y,world.z])
                            } else {
                                if !normals.contains(where: { $0.isEmpty }) {
                                    print("OFFLINE_INVALID_NORMAL", node.name ?? "", m.name ?? "", n, simd_determinant(transform))
                                }
                                // Empty entry explicitly marks missing/degenerate data; never serialize NaN as a valid normal.
                                normals.append([])
                            }
                        }
                        if let ti { uvs.append(vector(sourceIndex: ti, face: face, base: k - channel, element: element)) }
                    }
                    faces.append(indices)
                }
                rows.append(["node": node.name ?? "", "material": m.name ?? "", "vertices": vertices, "faces": faces,
                    "normals": normals, "uvs": uvs,
                    "diffuse": try binding(m.diffuse), "multiply": try binding(m.multiply),
                    "normal": try binding(m.normal), "roughness": try binding(m.roughness), "metalness": try binding(m.metalness)])
            }
        }
        let camera = try XCTUnwrap(s.cameraNode.camera)
        let matrix = s.cameraNode.simdWorldTransform
        let data: [String: Any] = ["meshes": rows, "width":1176, "height":2000,
            "cameraWorldRows": (0..<4).map { r in (0..<4).map { c in matrix[c][r] } },
            "fov": camera.fieldOfView, "projectionDirection": camera.projectionDirection.rawValue,
            "near": camera.zNear, "far": camera.zFar, "measuredBedY": bed]
        try JSONSerialization.data(withJSONObject: data).write(to: directory.appendingPathComponent("geometry.json"))
        for node in nodes {
            for m in node.geometry?.materials ?? [] {
                let old = m.shaderModifiers?[.geometry]
                m.shaderModifiers = old.map { [.geometry: $0] } ?? [:]
                m.lightingModel = .constant
                m.emission.contents = UIColor.black
                m.transparent.contents = UIColor.white
                m.transparency = 1
            }
        }
        camera.wantsHDR = false
        camera.exposureOffset = 0
        try capture(s, name: "albedo")
        for node in nodes {
            for m in node.geometry?.materials ?? [] {
                let old = m.shaderModifiers?[.geometry]
                m.shaderModifiers = old.map { [.geometry: $0] } ?? [:]
                m.lightingModel = .constant
                m.diffuse.contents = m.name?.hasPrefix("Lime") == true ? UIColor.red : (m.name == "TaiNi" ? UIColor.green : UIColor.blue)
                m.multiply.contents = UIColor.white
                m.emission.contents = UIColor.black
                m.transparent.contents = UIColor.white
                m.transparency = 1
            }
        }
        camera.wantsHDR = false
        camera.exposureOffset = 0
        try capture(s, name: "silhouette")
    }

    func testCoordinatedMaterialResponse() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for variant in ["current", "coordinated"] {
            let s = try scene(mobile: true)
            if variant == "coordinated" {
                materials(s) { m in
                    var modifiers = m.shaderModifiers ?? [:]
                    modifiers.removeValue(forKey: .fragment)
                    m.shaderModifiers = modifiers
                }
                var cloth = 0
                var wood = 0
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] {
                        var modifiers = m.shaderModifiers ?? [:]
                        if m.name == "TaiNi" {
                            let source = modifiers[.surface] ?? ""
                            XCTAssertTrue(source.contains("_surface.diffuse.rgb *= clothFiber;"))
                            modifiers[.surface] = source.replacingOccurrences(of: "_surface.diffuse.rgb *= clothFiber;", with: "")
                            cloth += 1
                        }
                        if m.name == "Wood" {
                            modifiers[.surface] = "#pragma body\n_surface.diffuse.rgb *= float3(0.699178671947, 0.766227464030, 0.779455258512);"
                            wood += 1
                        }
                        m.shaderModifiers = modifiers
                    }
                }
                XCTAssertGreaterThan(cloth, 0)
                XCTAssertGreaterThan(wood, 0)
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testCurrentShadowResolutionIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit shadow diagnostic")
        for variant in ["current", "doubleResolution"] {
            let s = try scene(mobile: true)
            var count = 0
            s.rootNode.enumerateChildNodes { node, _ in
                if let light = node.light, light.castsShadow {
                    if variant == "doubleResolution" {
                        light.shadowMapSize = CGSize(width: light.shadowMapSize.width * 2, height: light.shadowMapSize.height * 2)
                        light.shadowRadius *= 2
                    }
                    count += 1
                }
            }
            XCTAssertEqual(count, 1)
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testCurrentShadowBiasIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit shadow diagnostic")
        for variant in ["current", "zeroBias"] {
            let s = try scene(mobile: true)
            var count = 0
            s.rootNode.enumerateChildNodes { node, _ in
                if let light = node.light, light.castsShadow {
                    if variant == "zeroBias" { light.shadowBias = 0 }
                    count += 1
                }
            }
            XCTAssertEqual(count, 1)
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testCurrentShadowSoftnessComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for radius: CGFloat in [3, 1, 0] {
            let s = try scene(mobile: true)
            var changed = 0
            s.rootNode.enumerateChildNodes { node, _ in
                if let light = node.light, light.castsShadow {
                    light.shadowRadius = radius
                    changed += 1
                }
            }
            XCTAssertEqual(changed, 1)
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "radius\(Int(radius))-\(view)")
            }
        }
    }

    func testCurrentBallContactOcclusionAblation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        for variant in ["current", "withoutBallAO"] {
            let s = try scene(mobile: true)
            if variant == "withoutBallAO" {
                var changed = 0
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                        var modifiers = m.shaderModifiers ?? [:]
                        let source = modifiers[.surface] ?? ""
                        let token = "_surface.ambientOcclusion = contactVisibility;"
                        XCTAssertTrue(source.contains(token))
                        modifiers[.surface] = source.replacingOccurrences(of: token, with: "_surface.ambientOcclusion = 1.0;")
                        m.shaderModifiers = modifiers
                        changed += 1
                    }
                }
                XCTAssertGreaterThan(changed, 0)
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testCueZeroMetallicBindingComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        var rows: [[String: Any]] = []
        for variant in ["current", "constant", "repeatCurrent"] {
            let s = try scene(mobile: true)
            s.updateCueStick(cueBallPosition: SCNVector3(-0.45, s.surfaceY + AngleSceneCalculator.ballRadius, 0),
                             aimDirection: SCNVector3(0.8, 0, 0.12))
            var found = Set<String>()
            s.rootNode.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] {
                    let name = m.name ?? ""
                    guard ["White_Wood", "PiTou"].contains(name) else { continue }
                    found.insert(name)
                    let before = String(describing: m.metalness.contents)
                    if variant == "constant" { m.metalness.contents = Float(0) }
                    rows.append(["variant": variant, "material": name, "node": node.name ?? "",
                                 "before": before, "after": String(describing: m.metalness.contents),
                                 "intensity": m.metalness.intensity])
                }
            }
            XCTAssertEqual(found, Set(["White_Wood", "PiTou"]))
            try capture(s, name: "\(variant)-entry")
            s.cameraRig?.handleObservationPan(deltaX: 180)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "\(variant)-orbit")
        }
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("bindings.json"))
    }

    func testLeatherMaterialBindingAudit() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run")
        let s = try scene(mobile: true)
        var rows: [[String: Any]] = []
        func record(_ phase: String) {
            s.tableNode?.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] where m.name == "Leather" {
                    var row: [String: Any] = ["phase": phase, "node": node.name ?? "", "lighting": m.lightingModel.rawValue,
                        "normalIntensity": m.normal.intensity, "roughnessIntensity": m.roughness.intensity,
                        "diffuseIntensity": m.diffuse.intensity, "hidden": node.isHidden,
                        "surfaceShader": m.shaderModifiers?[.surface] ?? ""]
                    for (key, property) in [("diffuse", m.diffuse), ("normal", m.normal), ("roughness", m.roughness)] {
                        row[key + "Type"] = String(describing: type(of: property.contents as Any))
                        row[key + "Content"] = String(describing: property.contents)
                        row[key + "UV"] = property.mappingChannel
                        if let image = property.contents as? UIImage, let cg = image.cgImage {
                            row[key + "Size"] = [cg.width, cg.height]
                        }
                        XCTAssertNotNil(property.contents, "\(phase) \(key)")
                    }
                    rows.append(row)
                }
            }
        }
        record("before")
        let markers = s.addPocketMarkers()
        XCTAssertEqual(markers.count, 6)
        record("after")
        for state in ["original", "target", "roles", "both"] {
            s.clearPocketHighlights()
            if state == "target" { for node in markers { s.highlightPocket(node, highlighted: true) } }
            if state == "roles" { s.setPocketRoles(first: 0, second: 1) }
            if state == "both" { s.setPocketRoles(first: 0, second: 0) }
            try capture(s, name: "compare/\(state)")
        }
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("bindings.json"))
    }

    func testSceneLinearHighlightAudit() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit evidence run required")
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try XCTUnwrap(device.makeCommandQueue())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func raw(_ scene: SCNScene, camera: SCNNode, name: String, width: Int = 588, height: Int = 1000) throws -> [UInt16] {
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = scene; renderer.pointOfView = camera; renderer.autoenablesDefaultLighting = false
            if let training = scene as? AngleTrainingScene { renderer.delegate = training.contactOcclusion }
            let cd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
            cd.usage = [.renderTarget, .shaderRead]; cd.storageMode = .shared
            let color = try XCTUnwrap(device.makeTexture(descriptor: cd))
            let dd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
            dd.usage = .renderTarget; dd.storageMode = .private
            let depth = try XCTUnwrap(device.makeTexture(descriptor: dd))
            for _ in 0..<2 {
                let pass = MTLRenderPassDescriptor()
                pass.colorAttachments[0].texture = color
                pass.colorAttachments[0].loadAction = .clear; pass.colorAttachments[0].storeAction = .store
                pass.depthAttachment.texture = depth; pass.depthAttachment.loadAction = .clear
                pass.depthAttachment.storeAction = .dontCare; pass.depthAttachment.clearDepth = 1
                let command = try XCTUnwrap(queue.makeCommandBuffer())
                renderer.render(atTime: 0, viewport: CGRect(x: 0,y: 0,width: width,height: height), commandBuffer: command, passDescriptor: pass)
                command.commit(); command.waitUntilCompleted()
                XCTAssertEqual(command.status, .completed, String(describing: command.error))
            }
            var values = [UInt16](repeating: 0, count: width*height*4)
            values.withUnsafeMutableBytes { color.getBytes($0.baseAddress!, bytesPerRow: width*8, from: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0) }
            if name == "entry" {
                XCTAssertTrue(values.allSatisfy { Float16(bitPattern: $0).isFinite }, "Current scene must not emit non-finite linear HDR pixels")
            }
            try values.withUnsafeBytes { Data($0) }.write(to: directory.appendingPathComponent(name + ".rgba16f"))
            return values
        }
        for view in ["entry", "detail", "entry-cue", "orbit-cue", "entry-cue-no-flat-normal", "orbit-cue-no-flat-normal"] {
            let s = try scene(mobile: true)
            var cueIDs = Set<ObjectIdentifier>()
            if view.contains("cue") {
                let y = s.surfaceY + AngleSceneCalculator.ballRadius
                s.updateCueStick(cueBallPosition: SCNVector3(-0.45,y,0), aimDirection: SCNVector3(0.8,0,0.12))
                let cue = try XCTUnwrap(s.cueStick)
                cue.rootNode.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] {
                        cueIDs.insert(ObjectIdentifier(m))
                        if view.contains("no-flat-normal"), ["White_Wood", "PiTou"].contains(m.name ?? "") {
                            m.normal.contents = nil
                        }
                    }
                }
                if view.hasPrefix("orbit") {
                    s.cameraRig?.handleObservationPan(deltaX: 180)
                    for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                }
            }
            if view == "detail" {
                s.cameraRig?.handleObservationPinch(scale: 2)
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            }
            try capture(s, name: view + "-display")
            _ = try raw(s, camera: s.cameraNode, name: view)
            var ballIDs = Set<ObjectIdentifier>()
            materials(s) { ballIDs.insert(ObjectIdentifier($0)) }
            // Same geometry/depth, replace only the final color with category IDs.
            // All balls=.1, cloth=.2, wooden rails=.3, other geometry=.4, cue=.5.
            s.rootNode.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] {
                    let id: Double = cueIDs.contains(ObjectIdentifier(m)) ? 0.5 : ballIDs.contains(ObjectIdentifier(m)) ? 0.1 : m.name == "TaiNi" ? 0.2 : ["Wood","BlackWood"].contains(m.name ?? "") ? 0.3 : 0.4
                    var shaders = m.shaderModifiers ?? [:]
                    shaders[.fragment] = "#pragma body\n_output.color.rgb = float3(\(id),0,0);"
                    m.shaderModifiers = shaders
                }
            }
            _ = try raw(s, camera: s.cameraNode, name: view + "-ids")
        }
        let calibration = SCNScene()
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.camera?.wantsHDR = true; camera.camera?.wantsExposureAdaptation = false
        camera.camera?.exposureOffset = -0.45; camera.position = SCNVector3(0,0,5)
        calibration.rootNode.addChildNode(camera)
        let panel = SCNNode(geometry: SCNPlane(width: 10,height: 10)); calibration.rootNode.addChildNode(panel)
        let material = SCNMaterial(); panel.geometry?.firstMaterial = material
        var check: [[String: Double]] = []
        for value in [0.1,0.5,1,4] {
            material.shaderModifiers = [.fragment: "#pragma body\n_output.color.rgb = float3(\(value));"]
            let pixels = try raw(calibration, camera: camera, name: "calibration-\(value)", width: 32, height: 32)
            check.append(["input":value,"rawCenter":Double(Float16(bitPattern: pixels[(16*32+16)*4]))])
        }
        try JSONSerialization.data(withJSONObject: ["width":588,"height":1000,"format":"little-endian RGBA16Float","exposure":-0.45,"calibration":check], options:[.prettyPrinted,.sortedKeys])
            .write(to: directory.appendingPathComponent("metadata.json"))
    }

    func testUnifiedHighlightRolloffDiagnostic() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in ["current", "balls", "all"] {
            let s = try scene(mobile: true)
            if variant != "current" {
                var ballIDs = Set<ObjectIdentifier>()
                materials(s) { m in
                    ballIDs.insert(ObjectIdentifier(m))
                    var shaders = m.shaderModifiers ?? [:]
                    shaders.removeValue(forKey: .fragment)
                    m.shaderModifiers = shaders
                }
                let exposure = try XCTUnwrap(s.cameraNode.camera).exposureOffset
                let ceiling = pow(2.0, -Double(exposure))
                let knee = 0.8
                var seen = Set<ObjectIdentifier>()
                s.rootNode.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] {
                        let id = ObjectIdentifier(m)
                        guard !seen.contains(id), variant == "all" || ballIDs.contains(id) else { continue }
                        seen.insert(id)
                        var shaders = m.shaderModifiers ?? [:]
                        shaders[.fragment] = (shaders[.fragment] ?? "#pragma body") + """

                        float peak = max(_output.color.r, max(_output.color.g, _output.color.b));
                        if (peak > \(knee)) {
                            float mapped = \(knee) + \(ceiling-knee) * (1.0 - exp(-(peak-\(knee))/\(ceiling-knee)));
                            _output.color.rgb *= mapped / peak;
                        }
                        """
                        m.shaderModifiers = shaders
                    }
                }
                XCTAssertFalse(seen.isEmpty)
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(variant)-\(view)")
            }
        }
    }

    func testCurrentCameraToneResponse() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let source = try scene(mobile: true)
        let original = try XCTUnwrap(source.cameraNode.camera)
        let diagnostic = SCNScene()
        let camera = SCNNode()
        camera.camera = original.copy() as? SCNCamera
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1
        camera.position = SCNVector3(0,0,5)
        diagnostic.rootNode.addChildNode(camera)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.white
        let plane = SCNNode(geometry: SCNPlane(width: 4, height: 4))
        plane.geometry?.firstMaterial = material
        diagnostic.rootNode.addChildNode(plane)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = diagnostic; renderer.pointOfView = camera
        renderer.autoenablesDefaultLighting = false
        var rows: [[String: Any]] = []
        // Isolated calibration fixture only. No training camera, lights or source
        // material is changed. The +1 EV control verifies output-stage exposure.
        for (label, offset, whitePoint) in [("current", original.exposureOffset, original.whitePoint), ("plus1EV", original.exposureOffset + 1, original.whitePoint), ("whitePoint4", original.exposureOffset, CGFloat(4))] {
            camera.camera?.exposureOffset = offset
            camera.camera?.whitePoint = whitePoint
            for (index, value) in [0.0,0.02,0.05,0.1,0.18,0.3,0.5,0.75,1,2,4,8,16].enumerated() {
                material.shaderModifiers = [.fragment: "#pragma body\n_output.color.rgb = float3(\(value));"]
                let image = renderer.snapshot(atTime: 0, with: CGSize(width: 128,height: 128), antialiasingMode: .none)
                let folder = directory.appendingPathComponent(label)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let name = "\(label)/\(index).png"
                try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent(name))
                rows.append(["file": name, "linearInput": value, "exposureOffset": offset])
            }
        }
        try JSONSerialization.data(withJSONObject: ["wantsHDR":original.wantsHDR, "autoExposure":original.wantsExposureAdaptation,
            "whitePoint":original.whitePoint, "averageGray":original.averageGray, "samples":rows], options: [.prettyPrinted,.sortedKeys])
            .write(to: directory.appendingPathComponent("response-inputs.json"))
    }

    func testLocalClothDiffuseBounceDiagnostic() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        func linear(_ x: Double) -> Double { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        let cloth = [linear(48.0/255)*linear(0.54), linear(155.0/255)*linear(0.73), linear(32.0/255)*linear(0.54)]
        let luminance = cloth[0]*0.2126 + cloth[1]*0.7152 + cloth[2]*0.0722
        for name in ["current", "neutral", "cloth"] {
            let s = try scene(mobile: true)
            if name != "current" {
                let color = name == "cloth" ? cloth : [Double](repeating: luminance, count: 3)
                materials(s) { m in
                    var modifiers = m.shaderModifiers ?? [:]
                    // Diagnostic infinite-plane diffuse approximation at unit
                    // irradiance. No finite-table or self-shadow visibility yet.
                    // Do not mistake this emission injection for measured GI.
                    modifiers[.surface] = """
                    #pragma body
                    float3 worldNormal = normalize((scn_frame.inverseViewTransform * float4(_surface.normal, 0)).xyz);
                    float groundFacing = 0.5 * (1.0 - worldNormal.y);
                    _surface.emission.rgb += _surface.diffuse.rgb * float3(\(color[0]),\(color[1]),\(color[2])) * groundFacing;
                    """
                    m.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "\(name)-\(view)")
            }
        }
        try JSONSerialization.data(withJSONObject: ["clothLinearAlbedo": cloth, "neutralLuminance": luminance], options: [.prettyPrinted])
            .write(to: directory.appendingPathComponent("inputs.json"))
    }

    func testCueShaftFinishComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        var audit: [[String: String]] = []
        for (label, floor) in [("current", 0.0), ("soft25", 0.25), ("soft40", 0.4)] {
            let s = try scene(mobile: true)
            let y = s.surfaceY + AngleSceneCalculator.ballRadius
            s.updateCueStick(cueBallPosition: SCNVector3(-0.45,y,0), aimDirection: SCNVector3(0.8,0,0.12))
            let cue = try XCTUnwrap(s.cueStick)
            var count = 0
            cue.rootNode.enumerateChildNodes { node, _ in
                for m in node.geometry?.materials ?? [] {
                    if label == "current" {
                        audit.append(["name": m.name ?? "", "lighting": m.lightingModel.rawValue,
                                      "roughness": String(describing: m.roughness.contents),
                                      "albedo": String(describing: m.diffuse.contents)])
                    }
                    if m.name == "White_Wood" {
                        count += 1
                        if floor > 0 {
                            var modifiers = m.shaderModifiers ?? [:]
                            modifiers[.surface] = (modifiers[.surface] ?? "#pragma body") + "\n_surface.roughness = \(floor) + \(1-floor) * _surface.roughness;"
                            m.shaderModifiers = modifiers
                        }
                    }
                }
            }
            XCTAssertGreaterThan(count, 0)
            try capture(s, name: "\(label)-entry")
            s.cameraRig?.handleObservationPan(deltaX: 180)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "\(label)-orbit")
        }
        try JSONSerialization.data(withJSONObject: audit, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("cue-materials.json"))
    }

    func testOriginalClothConstantAlbedo() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let legacy = try scene(mobile: false)
        var originalAlbedo: Any?
        legacy.tableNode?.enumerateChildNodes { node, _ in
            for m in node.geometry?.materials ?? [] where m.name == "TaiNi" { originalAlbedo = m.diffuse.contents }
        }
        let sourceAlbedo = try XCTUnwrap(originalAlbedo)
        for constant in [false, true] {
            let s = try scene(mobile: true)
            if !constant {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for m in node.geometry?.materials ?? [] where m.name == "TaiNi" {
                        m.diffuse.contents = sourceAlbedo
                    }
                }
            }
            try capture(s, name: constant ? "constant" : "texture")
        }
    }

    func testMobileSixPocketRolePalette() throws {
        let s = try scene(mobile: true)
        let markers = s.addPocketMarkers().compactMap { $0 as? PocketLeatherMarker }
        XCTAssertNil(s.pocketLeatherFailure)
        XCTAssertEqual(markers.count, 6)
        let other = try scene(mobile: true)
        let isolated = other.addPocketMarkers().compactMap { $0 as? PocketLeatherMarker }
        for index in 0..<6 {
            s.clearPocketHighlights()
            s.setPocketHighlight(markers[index], style: .selected)
            XCTAssertEqual(markers.filter { $0.style == .target }.map(\.pocketIndex), [index])
            s.setPocketRoles(first: index, second: (index + 1) % 6)
            XCTAssertEqual(markers.filter { $0.style == .firstRole }.map(\.pocketIndex), [index])
            XCTAssertEqual(markers.filter { $0.style == .secondRole }.map(\.pocketIndex), [(index + 1) % 6])
            s.setPocketRoles(first: index, second: index)
            XCTAssertEqual(markers.filter { $0.style == .bothRoles }.map(\.pocketIndex), [index])
            XCTAssertEqual(markers.filter { $0.style == .original }.count, 5)
            XCTAssertTrue(markers.allSatisfy { $0.childNodes.filter { !$0.isHidden }.count == 1 })
            XCTAssertTrue(isolated.allSatisfy { $0.style == .original })
        }
        // Diagnostic contact sheets: show every physical region in each style.
        // The top-down view is an existing camera mode, not a new product camera.
        // These snapshots do not establish actual-page or phone performance acceptance.
        for mode in ["perspective", "top-down"] {
            if mode == "top-down" { s.setCameraMode(.topDown2DRotated, animated: false) }
            for style in PocketLeatherMarker.Style.allCases {
                for marker in markers { marker.show(style) }
                try capture(s, name: "\(mode)/\(style)")
            }
        }
        s.clearPocketHighlights()
        XCTAssertTrue(markers.allSatisfy { $0.style == .original })
        XCTAssertTrue(zip(markers, s.addPocketMarkers()).allSatisfy { $0 === $1 })
    }

    func testPocketMaterialIdentity() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in ["current", "White", "WeiBian", "Leather"] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == variant {
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.fragment] = "#pragma body\n_output.color.rgb = float3(1,0,1);"
                    material.shaderModifiers = modifiers
                }
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(variant)")
        }
    }

    func testClothGrazingResponse() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, strength) in [("current", 0.0), ("soft-sheen", 0.35), ("strong-sheen", 0.7)] {
            let s = try scene(mobile: true)
            s.tableNode?.enumerateChildNodes { node, _ in
                for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.surface] = (modifiers[.surface] ?? "#pragma body") + """

                    float fiberFacing = clamp(dot(normalize(_surface.normal), normalize(_surface.view)), 0.0, 1.0);
                    _surface.diffuse.rgb *= 1.0 + \(strength) * pow(1.0 - fiberFacing, 5.0);
                    """
                    material.shaderModifiers = modifiers
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testClothIlluminationRebalance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in ["current", "lower-environment", "cloth-rebalanced"] {
            let s = try scene(mobile: true)
            if variant != "current" { s.lightingEnvironment.intensity = 0.35 }
            if variant == "cloth-rebalanced" {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = (modifiers[.surface] ?? "#pragma body") + "\n_surface.diffuse.rgb *= 1.3;"
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(variant)-\(view)")
            }
        }
    }

    func testDiffuseIlluminationRange() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, intensity) in [("current", 0.7), ("half-environment", 0.35), ("low-environment", 0.2)] {
            let s = try scene(mobile: true)
            s.lightingEnvironment.intensity = intensity
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(name)")
        }
    }

    func testBallReflectionIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in ["current", "black-diffuse", "rough"] {
            let s = try scene(mobile: true)
            materials(s) { material in
                if variant == "black-diffuse" {
                    var modifiers = material.shaderModifiers ?? [:]
                    modifiers[.surface] = "#pragma body\n_surface.diffuse.rgb = float3(0);"
                    material.shaderModifiers = modifiers
                }
                if variant == "rough" { material.roughness.contents = Float(1) }
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(variant)")
        }
    }

    func testCurrentKeyFillDistribution() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        // S105: isolate direct light distribution on the current S95 assets.
        // Environment, materials, exposure, transforms and camera stay fixed.
        for (name, fill, key) in [("current", 200.0, 8.0), ("no-fill", 0.0, 8.0),
                                   ("key24", 0.0, 24.0), ("key48", 0.0, 48.0)] {
            let s = try scene(mobile: true)
            var keys = 0
            var fills = 0
            s.rootNode.enumerateChildNodes { node, _ in
                guard let light = node.light else { return }
                if light.castsShadow {
                    light.intensity = CGFloat(key)
                    keys += 1
                } else if light.type == .directional {
                    light.intensity = CGFloat(fill)
                    fills += 1
                }
            }
            XCTAssertEqual(keys, 1)
            XCTAssertEqual(fills, 1)
            for view in ["entry", "detail", "orbit"] {
                if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(name)-\(view)")
            }
        }
    }

    func testDirectEnvironmentBalance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (name, environment, key) in [("current", 0.7, 8.0), ("balanced", 0.35, 16.0), ("direct", 0.2, 24.0)] {
            let s = try scene(mobile: true)
            s.lightingEnvironment.intensity = environment
            s.rootNode.enumerateChildNodes { node, _ in
                if node.light?.castsShadow == true { node.light?.intensity = CGFloat(key) }
            }
            try capture(s, name: "compare/\(name)-page")
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(name)-detail")
        }
    }

    func testLightContributionIsolation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in ["current", "no-fill", "no-ambient", "no-environment"] {
            let s = try scene(mobile: true)
            if variant == "no-environment" { s.lightingEnvironment.intensity = 0 }
            s.rootNode.enumerateChildNodes { node, _ in
                guard let light = node.light else { return }
                if variant == "no-fill", light.type == .directional, !light.castsShadow { light.intensity = 0 }
                if variant == "no-ambient", light.type == .ambient { light.intensity = 0 }
            }
            try capture(s, name: "compare/\(variant)-page")
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/\(variant)-detail")
        }
    }

    func testStaticRailOcclusionViews() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for enabled in [false, true] {
            let s = try scene(mobile: true)
            if !enabled {
                s.tableNode?.enumerateChildNodes { node, _ in
                    for material in node.geometry?.materials ?? [] where material.name == "TaiNi" {
                        var modifiers = material.shaderModifiers ?? [:]
                        modifiers[.surface] = modifiers[.surface]?.replacingOccurrences(
                            of: "_surface.ambientOcclusion *= bakedRailAO.sample(railSampler, railUV).r;", with: "")
                        material.shaderModifiers = modifiers
                    }
                }
            }
            for view in ["entry", "orbit", "full"] {
                if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                if view == "full" { s.cameraRig?.handleObservationPinch(scale: 0.5) }
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "compare/\(view)-\(enabled ? "on" : "off")")
            }
        }
    }

    func testCoplanarMarkDepthSeparation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for separate in [false, true] {
            let s = try scene(mobile: true)
            let bedY = try XCTUnwrap(MobileClothAlignment.measuredBedY(in: s))
            if separate {
                s.tableNode?.enumerateChildNodes { node, _ in
                    let offset = node.convertVector(SCNVector3(0, 0.00005, 0), from: s.rootNode)
                    for material in node.geometry?.materials ?? [] where material.name == "White" {
                        var modifiers = material.shaderModifiers ?? [:]
                        guard var geometry = modifiers[.geometry] else { continue }
                        geometry += "\nif (abs(bedWorld.y - \(bedY)) < 0.000001) { _geometry.position.xyz += float3(\(offset.x), \(offset.y), \(offset.z)); }"
                        modifiers[.geometry] = geometry
                        material.shaderModifiers = modifiers
                    }
                }
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "compare/mark-\(separate ? "separated" : "coplanar")")
        }
    }

    func testBallDiffuseRange() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for (index, scale) in [Float(1), 0.8, 0.6].enumerated() {
            let s = try scene(mobile: true)
            materials(s) { material in
                material.shaderModifiers = [.surface: "#pragma body\n_surface.diffuse.rgb *= \(scale);"]
            }
            s.cameraRig?.handleObservationPinch(scale: 2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
            try capture(s, name: "albedo/A\(index)")
        }
    }

    func testClothCalibrationPreservesMeshAndLegacy() throws {
        let baseline = try scene()
        let candidate = try scene(mobile: true)
        XCTAssertEqual(try XCTUnwrap(MobileClothAlignment.measuredBedY(in: candidate)),
                       0.794737637, accuracy: 0.00001)
        func geometryNodes(_ s: AngleTrainingScene) -> [SCNNode] {
            var result: [SCNNode] = []
            s.tableNode?.enumerateChildNodes { node, _ in
                if node.geometry != nil { result.append(node) }
            }
            return result
        }
        let a = geometryNodes(baseline), b = geometryNodes(candidate)
        XCTAssertEqual(a.count, b.count)
        var clothCount = 0, whiteCount = 0
        for (old, new) in zip(a, b) {
            XCTAssertTrue(SCNMatrix4EqualToMatrix4(old.transform, new.transform))
            let x = try XCTUnwrap(old.geometry), y = try XCTUnwrap(new.geometry)
            XCTAssertEqual(x.sources.map(\.data), y.sources.map(\.data), "Vertex, normal and UV buffers")
            XCTAssertEqual(x.elements.map(\.data), y.elements.map(\.data), "Topology")
            for (before, after) in zip(x.materials, y.materials) {
                XCTAssertFalse(before === after)
                if after.name == "TaiNi" || after.name == "White" {
                    XCTAssertNil(before.shaderModifiers?[.geometry])
                    XCTAssertNotNil(after.shaderModifiers?[.geometry])
                    if after.name == "TaiNi" { clothCount += 1 } else { whiteCount += 1 }
                } else {
                    XCTAssertEqual(before.shaderModifiers?[.geometry], after.shaderModifiers?[.geometry])
                }
            }
        }
        XCTAssertGreaterThan(clothCount, 0)
        XCTAssertGreaterThan(whiteCount, 0)
        XCTAssertEqual(baseline.surfaceY, candidate.surfaceY)
    }

    func testOverheadKeyLight() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        try renderOverhead(intensities: [820,1600,2400], folder: "overhead")
    }

    func testOverheadKeyLightRefinement() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        try renderOverhead(intensities: [20,40,80], folder: "overhead-refined")
    }

    private func renderOverhead(intensities: [CGFloat], folder: String) throws {
        for (variant,intensity) in intensities.enumerated() {
            let s = try scene(mobile:true)
            s.rootNode.enumerateChildNodes { node,_ in
                guard let light=node.light,light.castsShadow else { return }
                light.type = .spot
                node.position = SCNVector3(0,s.surfaceY+2.2,0)
                node.eulerAngles = SCNVector3(-Float.pi/2,0,0)
                light.spotInnerAngle = 60
                light.spotOuterAngle = 95
                light.attenuationStartDistance = 0
                light.attenuationEndDistance = 10
                light.attenuationFalloffExponent = 2
                light.zNear = 0.5
                light.zFar = 6
                light.intensity = intensity
            }
            try capture(s,name:"\(folder)/K\(variant)")
        }
    }

    func testCandidateColorAndViewMatrix() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for mobile in [false,true] {
            let s=try scene(mobile:mobile)
            let y=s.surfaceY+AngleSceneCalculator.ballRadius
            for (i,number) in [1,3,6,8,9,14].enumerated() {
                let ball=try XCTUnwrap(s.allBallNodes["_\(number)"])
                ball.isHidden=false
                ball.position=SCNVector3(Float(i/3)*0.4+0.15,y,Float(i%3)*0.22-0.22)
            }
            let rig=try XCTUnwrap(s.cameraRig)
            for (index,scale) in [Float(1),2,0.25].enumerated() {
                if index>0 { rig.handleObservationPinch(scale:scale) }
                for _ in 0..<120 { rig.update(deltaTime:1/60) }
                try capture(s,name:"candidate/\(mobile ? "mobile" : "baseline")-view\(index)")
            }
        }
    }

    /// Static contact cases. This does not substitute for an in-app rolling replay.
    /// S98 static visual oracle; 256 rays per fragment is NOT a mobile proposal.
    func testStaticBallMutualOcclusion() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let radius = AngleSceneCalculator.ballRadius
        for gap: Float in [0.002, 0.15] {
            for enabled in [false, true] {
                let s = try scene(mobile: true)
                let y = s.surfaceY + radius
                s.applyBallLayout(cueBallPosition: SCNVector3(-0.45, y, 0), targetBallNumber: 3,
                                  targetPosition: SCNVector3(-0.45, y, 2 * radius + gap))
                s.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)))
                let cue = try XCTUnwrap(s.cueBallNode)
                let target = try XCTUnwrap(s.allBallNodes["_3"])
                XCTAssertGreaterThanOrEqual(simd_distance(cue.simdWorldPosition, target.simdWorldPosition), 2 * radius)
                if enabled {
                    for (receiver, occluder) in [(cue, target), (target, cue)] {
                        let center = occluder.worldPosition
                        let shader = """
                        #pragma body
                        float3 p = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
                        float3 n = normalize((scn_frame.inverseViewTransform * float4(_surface.normal, 0.0)).xyz);
                        float3 axis = abs(n.y) < 0.99 ? float3(0,1,0) : float3(1,0,0);
                        float3 tangent = normalize(cross(axis,n));
                        float3 bitangent = cross(n,tangent);
                        float3 delta = float3(\(center.x),\(center.y),\(center.z)) - p;
                        float c = dot(delta,delta) - \(radius * radius);
                        float3 samples[256] = {float3(0.044194174,0.000000000,0.999022960),
                        float3(-0.056443047,0.051706455,0.997066008),
                        float3(0.008639513,-0.098442795,0.995105208),
                        float3(0.071142805,0.092793191,0.993140536),
                        float3(-0.130555797,-0.023093482,0.991171970),
                        float3(0.123673848,-0.078671179,0.989199487),
                        float3(-0.041366482,0.153881250,0.987223062),
                        float3(-0.078890367,-0.151898601,0.985242673),
                        float3(0.171160540,0.062507555,0.983258295),
                        float3(-0.178064022,0.073502240,0.981269904),
                        float3(0.085838625,-0.183432155,0.979277476),
                        float3(0.063432560,0.202232998,0.977280986),
                        float3(-0.191186473,-0.110796469,0.975280408),
                        float3(0.224283496,-0.049308097,0.973275719),
                        float3(-0.136876726,0.194693058,0.971266892),
                        float3(-0.031621693,-0.244022424,0.969253901),
                        float3(0.194126181,0.163609751,0.967236721),
                        float3(-0.261232989,0.010802804,0.965215326),
                        float3(0.190549412,-0.189622115,0.963189688),
                        float3(-0.012748494,0.275697934,0.961159781),
                        float3(-0.181308377,-0.217268031,0.959125578),
                        float3(0.287212489,0.038644034,0.957087052),
                        float3(-0.243354561,0.169319765,0.955044174),
                        float3(0.066498463,-0.295592336,0.952996918),
                        float3(0.153807486,0.268414572,0.950945253),
                        float3(-0.300678919,-0.095924776,0.948889153),
                        float3(0.292071305,-0.134944351,0.946828588),
                        float3(-0.126532587,0.302343148,0.944763529),
                        float3(-0.112927546,-0.313967346,0.942693946),
                        float3(0.300488080,0.157928113,0.940619809),
                        float3(-0.333766650,0.087979818,0.938541089),
                        float3(0.189715267,-0.295050830,0.936457754),
                        float3(0.060349547,0.351156742,0.934369774),
                        float3(-0.286003904,-0.221497499,0.932277118),
                        float3(0.365850965,-0.030310005,0.930179754),
                        float3(-0.252880136,0.273356017,0.928077650),
                        float3(0.001842014,-0.377590694,0.925970774),
                        float3(0.257152473,0.283473069,0.923859094),
                        float3(-0.386147433,-0.035788057,0.921742575),
                        float3(0.312893654,-0.237475128,0.919621186),
                        float3(-0.071190284,0.391324761,0.917494891),
                        float3(-0.214441970,-0.340769741,0.915363657),
                        float3(0.392960067,0.107694063,0.913227450),
                        float3(-0.366742761,0.188206330,0.911086234),
                        float3(0.144930838,-0.390926051,0.908939973),
                        float3(0.158955734,0.390470805,0.906788633),
                        float3(-0.385131962,-0.182521224,0.904632177),
                        float3(0.411631651,-0.126910437,0.902470567),
                        float3(-0.220078265,0.375524543,0.900303768),
                        float3(-0.092321620,-0.429925684,0.898131741),
                        float3(0.362088678,0.257210836,0.895954449),
                        float3(-0.445078681,0.055469299,0.893771853),
                        float3(0.293527131,-0.344847718,0.891583914),
                        float3(0.016659950,0.456844417,0.889390592),
                        float3(-0.323863479,-0.328638209,0.887191848),
                        float3(0.465007065,0.023776124,0.884987641),
                        float3(-0.362161557,0.299235913,0.882777931),
                        float3(0.065487661,-0.469383363,0.880562675),
                        float3(0.271102445,0.393724636,0.878341833),
                        float3(-0.469824511,-0.108105522,0.876115361),
                        float3(0.422968375,-0.239636973,0.873883216),
                        float3(-0.151245949,0.466217801,0.871645355),
                        float3(-0.205048547,-0.449550574,0.869401734),
                        float3(0.458487934,0.194513983,0.867152308),
                        float3(-0.473149192,0.167579734,0.864897031),
                        float3(0.237507008,-0.446598025,0.862635859),
                        float3(0.127504668,0.493465485,0.860368744),
                        float3(-0.430550281,-0.279818388,0.858095639),
                        float3(0.510226960,-0.085126813,0.855816496),
                        float3(-0.321041162,0.410386339,0.853531268),
                        float3(-0.040776455,-0.523190124,0.851239904),
                        float3(0.386187259,0.360771778,0.848942357),
                        float3(-0.532142995,-0.005192067,0.846638574),
                        float3(0.398613820,-0.358073174,0.844328505),
                        float3(-0.052403360,0.536907360,0.842012099),
                        float3(-0.326202586,-0.434181699,0.839689303),
                        float3(0.537340743,0.100464180,0.837360063),
                        float3(-0.467104279,0.290771332,0.835024326),
                        float3(0.148966820,-0.533338084,0.832682037),
                        float3(0.252011194,0.497028403,0.830333141),
                        float3(-0.524833093,-0.197492656,0.827977581),
                        float3(0.523622283,-0.210188200,0.825615301),
                        float3(-0.245615805,0.511799278,0.823246242),
                        float3(-0.165600602,-0.546578737,0.820870346),
                        float3(0.494250626,0.292906886,0.818487553),
                        float3(-0.565618226,0.118576548,0.816097804),
                        float3(0.338936837,-0.472241936,0.813701035),
                        float3(0.069471490,0.580491677,0.811297187),
                        float3(-0.445868797,-0.383280760,0.808886194),
                        float3(0.590983063,-0.018665310,0.806467994),
                        float3(-0.425521762,0.415267209,0.804042521),
                        float3(0.033440774,-0.596911710,0.801609709),
                        float3(0.380612838,0.465254761,0.799169491),
                        float3(-0.598134314,-0.086427524,0.796721799),
                        float3(0.502090210,-0.342119930,0.794266564),
                        float3(-0.139861187,0.594546654,0.791803716),
                        float3(-0.300039867,-0.535657730,0.789333184),
                        float3(0.586084968,0.193297143,0.786854895),
                        float3(-0.565609598,0.254659394,0.784368775),
                        float3(0.246283698,-0.572726999,0.781874750),
                        float3(0.206298522,0.591624074,0.779372745),
                        float3(-0.554492682,-0.298365951,0.776862681),
                        float3(0.613408522,-0.155308115,0.774344481),
                        float3(-0.349089746,0.531444470,0.771818065),
                        float3(-0.102067201,-0.630702316,0.769283352),
                        float3(0.503687298,0.398005630,0.766740259),
                        float3(-0.643279492,0.046980000,0.764188704),
                        float3(0.444672821,-0.471368176,0.761628600),
                        float3(-0.009527278,0.650951116,0.759059863),
                        float3(-0.434675415,-0.488663134,0.756482402),
                        float3(0.653567367,0.067009865,0.753896130),
                        float3(-0.529564828,0.393837489,0.751300955),
                        float3(0.125008053,-0.651019287,0.748696784),
                        float3(0.349121545,0.566986351,0.746083524),
                        float3(-0.643240208,-0.183050977,0.743461078),
                        float3(0.600559947,-0.300831556,0.740829349),
                        float3(-0.240660522,0.630206822,0.738188238),
                        float3(-0.249306157,-0.629945089,0.735537643),
                        float3(0.611939890,0.297355336,0.732877462),
                        float3(-0.654831711,0.194916148,0.730207590),
                        float3(0.352654905,-0.588504582,0.727527920),
                        float3(0.138061710,0.674943212,0.724838344),
                        float3(-0.560010438,-0.406083654,0.722138751),
                        float3(0.690039195,-0.079169342,0.719429027),
                        float3(-0.457175051,0.526610955,0.716709059),
                        float3(-0.018688540,-0.699917933,0.713978729),
                        float3(0.488502791,0.505475666,0.711237917),
                        float3(-0.704418524,-0.042911743,0.708486503),
                        float3(0.550549162,-0.445924596,0.705724362),
                        float3(-0.105146840,0.703422716,0.702951367),
                        float3(-0.399155482,-0.591980174,0.700167391),
                        float3(0.696856392,0.167520277,0.697372300),
                        float3(-0.629378047,0.348513125,0.694565962),
                        float3(0.229527822,-0.684690700,0.691748238),
                        float3(0.294351535,0.662380403,0.688918990),
                        float3(-0.666942796,-0.290661628,0.686078075),
                        float3(0.690656498,-0.237058489,0.683225347),
                        float3(-0.350414458,0.643676225,0.680360658),
                        float3(-0.177052664,-0.713910344,0.677483856),
                        float3(0.615000901,0.408283929,0.674594786),
                        float3(-0.731883575,0.114780478,0.671693289),
                        float3(0.463776764,-0.581072705,0.668779205),
                        float3(0.050712673,0.744358012,0.665852367),
                        float3(-0.542092686,-0.516413008,0.662912607),
                        float3(0.751157925,0.014659345,0.659959753),
                        float3(-0.565730164,0.498305887,0.656993626),
                        float3(0.080827360,-0.752151955,0.654014048),
                        float3(0.449999783,0.611287224,0.651020833),
                        float3(-0.747254681,-0.147270386,0.648013792),
                        float3(0.652668563,-0.397502355,0.644992733),
                        float3(-0.213458851,0.736427827,0.641957456),
                        float3(-0.341179806,-0.689487647,0.638907759),
                        float3(0.719681075,0.278858880,0.635843436),
                        float3(-0.721390540,0.281433943,0.632764273),
                        float3(0.342936665,-0.697072499,0.629670052),
                        float3(0.218699231,0.748059170,0.626560552),
                        float3(-0.668708588,-0.405162868,0.623435542),
                        float3(0.769214325,-0.153439557,0.620294789),
                        float3(-0.465017024,0.634743879,0.617138052),
                        float3(-0.086144719,-0.784618355,0.613965085),
                        float3(0.595380183,0.521991918,0.610775634),
                        float3(-0.794077554,0.017326667,0.607569440),
                        float3(0.575597883,-0.550865412,0.604346238),
                        float3(-0.052484476,0.797444202,0.601105752),
                        float3(-0.501492015,-0.625366999,0.597847702),
                        float3(0.794618240,0.122744565,0.594571800),
                        float3(-0.670857142,0.447595040,0.591277748),
                        float3(0.192899756,-0.785548572,0.587965241),
                        float3(0.389549814,0.711655863,0.584633967),
                        float3(-0.770233975,-0.262390926,0.581283601),
                        float3(0.747384052,-0.327769286,0.577913813),
                        float3(-0.330658196,0.748723602,0.574524260),
                        float3(-0.262701022,-0.777699362,0.571114590),
                        float3(0.721117079,0.397145481,0.567684441),
                        float3(-0.802299364,0.194823908,0.564233440),
                        float3(0.461305060,-0.687564191,0.560761201),
                        float3(0.124644545,0.820924395,0.557267328),
                        float3(-0.648264145,-0.522602118,0.553751411),
                        float3(0.833360084,-0.052693408,0.550213027),
                        float3(-0.580519208,0.603464435,0.546651740),
                        float3(0.020479236,-0.839439531,0.543067100),
                        float3(0.553459291,0.634560626,0.539458641),
                        float3(-0.839045112,-0.094307609,0.535825881),
                        float3(0.684256634,-0.498587739,0.532168324),
                        float3(-0.168214854,0.832109901,0.528485454),
                        float3(-0.439231276,-0.729167513,0.524776738),
                        float3(0.818618689,0.241617606,0.521041625),
                        float3(-0.768887399,0.375811179,0.517279542),
                        float3(0.313930650,-0.798608585,0.513489898),
                        float3(0.308785472,0.803047886,0.509672076),
                        float3(-0.772169207,-0.384571632,0.505825439),
                        float3(0.831321340,-0.238645563,0.501949325),
                        float3(-0.452965788,0.739442438,0.498043045),
                        float3(-0.165912585,-0.853423921,0.494105884),
                        float3(0.700621758,0.518550651,0.490137098),
                        float3(-0.869118270,0.091133462,0.486135912),
                        float3(0.580780693,-0.655951150,0.482101519),
                        float3(0.014876738,0.878215838,0.478033079),
                        float3(-0.605723597,-0.639131871,0.473929715),
                        float3(0.880578842,0.062271806,0.469790512),
                        float3(-0.693106038,0.550279152,0.465614513),
                        float3(0.139713711,-0.876121826,0.461400721),
                        float3(0.490002628,0.742235171,0.457148089),
                        float3(-0.864812806,-0.216842535,0.452855523),
                        float3(0.786085401,-0.425320900,0.448521878),
                        float3(-0.293048654,0.846674000,0.444145950),
                        float3(-0.356699840,-0.824260789,0.439726477),
                        float3(0.821782114,0.367724126,0.435262134),
                        float3(-0.856406835,0.284640928,0.430751524),
                        float3(0.440267578,-0.790268205,0.426193178),
                        float3(0.209677532,0.882213669,0.421585549),
                        float3(-0.752317092,-0.510089079,0.416927002),
                        float3(0.901418919,-0.132370910,0.412215811),
                        float3(-0.576614963,0.708166336,0.407450150),
                        float3(-0.053305960,-0.913810210,0.402628085),
                        float3(0.658104784,0.639292553,0.397747564),
                        float3(-0.919227285,-0.026913266,0.392806409),
                        float3(0.697594755,-0.602470690,0.387802301),
                        float3(-0.107668221,0.917563719,0.382732772),
                        float3(-0.541649426,-0.751024483,0.377595187),
                        float3(0.908768219,0.188330690,0.372386728),
                        float3(-0.799118876,0.476070790,0.367104379),
                        float3(0.268267719,-0.892845483,0.361744903),
                        float3(0.406205948,0.841453268,0.356304820),
                        float3(-0.869856622,-0.346846626,0.350780380),
                        float3(0.877644891,-0.332564010,0.345167532),
                        float3(-0.423440048,0.839919133,0.339461890),
                        float3(-0.255688281,-0.907356258,0.333658695),
                        float3(0.803206416,0.497430978,0.327752765),
                        float3(-0.930298218,0.176152210,0.321738442),
                        float3(0.568217762,-0.759946841,0.315609529),
                        float3(0.094555065,0.946232643,0.309359217),
                        float3(-0.710422365,-0.635219008,0.302979991),
                        float3(0.954974725,-0.011517374,0.296463531),
                        float3(-0.697878370,0.654966721,0.289800578),
                        float3(0.072323845,-0.956394864,0.282980786),
                        float3(0.593963162,0.755669165,0.275992527),
                        float3(-0.950420132,-0.156320015,0.268822665),
                        float3(0.808098787,-0.527841809,0.261456258),
                        float3(-0.239816060,0.937035289,0.253876200),
                        float3(-0.457076597,-0.854712881,0.246062746),
                        float3(0.916283348,0.322155554,0.237992910),
                        float3(-0.895099246,0.382181847,0.229639663),
                        float3(0.402685920,-0.888265684,0.220970869),
                        float3(0.303708500,0.928891421,0.211947812),
                        float3(-0.853141668,-0.480763632,0.202523147),
                        float3(0.955771937,-0.222240025,0.192637938),
                        float3(-0.555759384,0.811127846,0.182217247),
                        float3(-0.138388042,-0.975475205,0.171163299),
                        float3(0.762496652,0.627063180,0.159344360),
                        float3(-0.987790001,0.052787684,0.146575492),
                        float3(0.694089310,-0.707574664,0.132582521),
                        float3(-0.033907247,0.992561546,0.116926793),
                        float3(-0.646740425,-0.756281163,0.098821177),
                        float3(0.989693148,0.121029326,0.076546554),
                        float3(-0.813115846,0.580421826,0.044194174)};
                        float blocked = 0.0;
                        for (int i = 0; i < 256; ++i) {
                            float3 ray = tangent*samples[i].x + bitangent*samples[i].y + n*samples[i].z;
                            float b = dot(delta,ray);
                            blocked += (b > 0.0 && b*b > c) ? 1.0 : 0.0;
                        }
                        _surface.ambientOcclusion = 1.0 - blocked / 256.0;
                        """
                        func apply(_ node: SCNNode) {
                            for m in node.geometry?.materials ?? [] {
                                var modifiers = m.shaderModifiers ?? [:]
                                modifiers[.surface] = shader
                                m.shaderModifiers = modifiers
                            }
                        }
                        apply(receiver)
                        receiver.enumerateChildNodes { node, _ in apply(node) }
                    }
                }
                for view in ["entry", "detail", "orbit"] {
                    if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                    if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                    for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                    try capture(s, name: "compare/gap\(gap)-\(enabled ? "on" : "off")-\(view)")
                }
            }
        }
    }

    /// Diagnostic only: shared packed positions, no production integration.
    /// Dense, static layouts; union rays are a visual oracle only.
    func testDenseBallOcclusionReference() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let r = AngleSceneCalculator.ballRadius
        let spacing = 2*r+0.002
        for layout in ["chain", "hex"] {
            for mode in ["off", "product", "union"] {
                let s = try scene(mobile:true)
                s.hideAllBalls()
                let y = s.surfaceY+r
                let keys = layout == "chain" ? ["cueBall","_3","_1"] : ["cueBall","_3","_1","_2","_6","_7","_8"]
                var centers:[SCNVector3]=[SCNVector3(-0.45,y,0)]
                for index in 1..<keys.count {
                    if layout == "chain" { centers.append(SCNVector3(-0.45,y,Float(index)*spacing)) }
                    else {
                        let angle=Float(index-1)*Float.pi/3
                        centers.append(SCNVector3(-0.45+spacing*cos(angle),y,spacing*sin(angle)))
                    }
                }
                for i in centers.indices {
                    XCTAssertLessThan(abs(centers[i].x)+r,AngleSceneCalculator.innerLength/2)
                    XCTAssertLessThan(abs(centers[i].z)+r,AngleSceneCalculator.innerWidth/2)
                    for j in centers.indices where j<i {
                        XCTAssertGreaterThanOrEqual(simd_distance(SIMD3(centers[i].x,centers[i].y,centers[i].z),SIMD3(centers[j].x,centers[j].y,centers[j].z)),2*r)
                    }
                    s.showBall(key:keys[i],scenePosition:centers[i])
                }
                s.setCueBallHomeOrientation(simd_quatf(angle:0,axis:SIMD3<Float>(0,1,0)))
                if mode == "product" { _ = try installBallOcclusionPrototype(s)(false) }
                if mode == "union" {
                    for (receiverIndex,key) in keys.enumerated() {
                        let receiver=try XCTUnwrap(s.allBallNodes[key])
                        var shader="""
                        #pragma body
                        float3 p=(scn_frame.inverseViewTransform*float4(_surface.position,1.0)).xyz;
                        float3 n=normalize((scn_frame.inverseViewTransform*float4(_surface.normal,0.0)).xyz);
                        float3 axis=abs(n.y)<0.99 ? float3(0,1,0) : float3(1,0,0);
                        float3 tangent=normalize(cross(axis,n));
                        float3 bitangent=cross(n,tangent);
                        float3 samples[256] = {float3(0.044194174,0.000000000,0.999022960),
                        float3(-0.056443047,0.051706455,0.997066008),
                        float3(0.008639513,-0.098442795,0.995105208),
                        float3(0.071142805,0.092793191,0.993140536),
                        float3(-0.130555797,-0.023093482,0.991171970),
                        float3(0.123673848,-0.078671179,0.989199487),
                        float3(-0.041366482,0.153881250,0.987223062),
                        float3(-0.078890367,-0.151898601,0.985242673),
                        float3(0.171160540,0.062507555,0.983258295),
                        float3(-0.178064022,0.073502240,0.981269904),
                        float3(0.085838625,-0.183432155,0.979277476),
                        float3(0.063432560,0.202232998,0.977280986),
                        float3(-0.191186473,-0.110796469,0.975280408),
                        float3(0.224283496,-0.049308097,0.973275719),
                        float3(-0.136876726,0.194693058,0.971266892),
                        float3(-0.031621693,-0.244022424,0.969253901),
                        float3(0.194126181,0.163609751,0.967236721),
                        float3(-0.261232989,0.010802804,0.965215326),
                        float3(0.190549412,-0.189622115,0.963189688),
                        float3(-0.012748494,0.275697934,0.961159781),
                        float3(-0.181308377,-0.217268031,0.959125578),
                        float3(0.287212489,0.038644034,0.957087052),
                        float3(-0.243354561,0.169319765,0.955044174),
                        float3(0.066498463,-0.295592336,0.952996918),
                        float3(0.153807486,0.268414572,0.950945253),
                        float3(-0.300678919,-0.095924776,0.948889153),
                        float3(0.292071305,-0.134944351,0.946828588),
                        float3(-0.126532587,0.302343148,0.944763529),
                        float3(-0.112927546,-0.313967346,0.942693946),
                        float3(0.300488080,0.157928113,0.940619809),
                        float3(-0.333766650,0.087979818,0.938541089),
                        float3(0.189715267,-0.295050830,0.936457754),
                        float3(0.060349547,0.351156742,0.934369774),
                        float3(-0.286003904,-0.221497499,0.932277118),
                        float3(0.365850965,-0.030310005,0.930179754),
                        float3(-0.252880136,0.273356017,0.928077650),
                        float3(0.001842014,-0.377590694,0.925970774),
                        float3(0.257152473,0.283473069,0.923859094),
                        float3(-0.386147433,-0.035788057,0.921742575),
                        float3(0.312893654,-0.237475128,0.919621186),
                        float3(-0.071190284,0.391324761,0.917494891),
                        float3(-0.214441970,-0.340769741,0.915363657),
                        float3(0.392960067,0.107694063,0.913227450),
                        float3(-0.366742761,0.188206330,0.911086234),
                        float3(0.144930838,-0.390926051,0.908939973),
                        float3(0.158955734,0.390470805,0.906788633),
                        float3(-0.385131962,-0.182521224,0.904632177),
                        float3(0.411631651,-0.126910437,0.902470567),
                        float3(-0.220078265,0.375524543,0.900303768),
                        float3(-0.092321620,-0.429925684,0.898131741),
                        float3(0.362088678,0.257210836,0.895954449),
                        float3(-0.445078681,0.055469299,0.893771853),
                        float3(0.293527131,-0.344847718,0.891583914),
                        float3(0.016659950,0.456844417,0.889390592),
                        float3(-0.323863479,-0.328638209,0.887191848),
                        float3(0.465007065,0.023776124,0.884987641),
                        float3(-0.362161557,0.299235913,0.882777931),
                        float3(0.065487661,-0.469383363,0.880562675),
                        float3(0.271102445,0.393724636,0.878341833),
                        float3(-0.469824511,-0.108105522,0.876115361),
                        float3(0.422968375,-0.239636973,0.873883216),
                        float3(-0.151245949,0.466217801,0.871645355),
                        float3(-0.205048547,-0.449550574,0.869401734),
                        float3(0.458487934,0.194513983,0.867152308),
                        float3(-0.473149192,0.167579734,0.864897031),
                        float3(0.237507008,-0.446598025,0.862635859),
                        float3(0.127504668,0.493465485,0.860368744),
                        float3(-0.430550281,-0.279818388,0.858095639),
                        float3(0.510226960,-0.085126813,0.855816496),
                        float3(-0.321041162,0.410386339,0.853531268),
                        float3(-0.040776455,-0.523190124,0.851239904),
                        float3(0.386187259,0.360771778,0.848942357),
                        float3(-0.532142995,-0.005192067,0.846638574),
                        float3(0.398613820,-0.358073174,0.844328505),
                        float3(-0.052403360,0.536907360,0.842012099),
                        float3(-0.326202586,-0.434181699,0.839689303),
                        float3(0.537340743,0.100464180,0.837360063),
                        float3(-0.467104279,0.290771332,0.835024326),
                        float3(0.148966820,-0.533338084,0.832682037),
                        float3(0.252011194,0.497028403,0.830333141),
                        float3(-0.524833093,-0.197492656,0.827977581),
                        float3(0.523622283,-0.210188200,0.825615301),
                        float3(-0.245615805,0.511799278,0.823246242),
                        float3(-0.165600602,-0.546578737,0.820870346),
                        float3(0.494250626,0.292906886,0.818487553),
                        float3(-0.565618226,0.118576548,0.816097804),
                        float3(0.338936837,-0.472241936,0.813701035),
                        float3(0.069471490,0.580491677,0.811297187),
                        float3(-0.445868797,-0.383280760,0.808886194),
                        float3(0.590983063,-0.018665310,0.806467994),
                        float3(-0.425521762,0.415267209,0.804042521),
                        float3(0.033440774,-0.596911710,0.801609709),
                        float3(0.380612838,0.465254761,0.799169491),
                        float3(-0.598134314,-0.086427524,0.796721799),
                        float3(0.502090210,-0.342119930,0.794266564),
                        float3(-0.139861187,0.594546654,0.791803716),
                        float3(-0.300039867,-0.535657730,0.789333184),
                        float3(0.586084968,0.193297143,0.786854895),
                        float3(-0.565609598,0.254659394,0.784368775),
                        float3(0.246283698,-0.572726999,0.781874750),
                        float3(0.206298522,0.591624074,0.779372745),
                        float3(-0.554492682,-0.298365951,0.776862681),
                        float3(0.613408522,-0.155308115,0.774344481),
                        float3(-0.349089746,0.531444470,0.771818065),
                        float3(-0.102067201,-0.630702316,0.769283352),
                        float3(0.503687298,0.398005630,0.766740259),
                        float3(-0.643279492,0.046980000,0.764188704),
                        float3(0.444672821,-0.471368176,0.761628600),
                        float3(-0.009527278,0.650951116,0.759059863),
                        float3(-0.434675415,-0.488663134,0.756482402),
                        float3(0.653567367,0.067009865,0.753896130),
                        float3(-0.529564828,0.393837489,0.751300955),
                        float3(0.125008053,-0.651019287,0.748696784),
                        float3(0.349121545,0.566986351,0.746083524),
                        float3(-0.643240208,-0.183050977,0.743461078),
                        float3(0.600559947,-0.300831556,0.740829349),
                        float3(-0.240660522,0.630206822,0.738188238),
                        float3(-0.249306157,-0.629945089,0.735537643),
                        float3(0.611939890,0.297355336,0.732877462),
                        float3(-0.654831711,0.194916148,0.730207590),
                        float3(0.352654905,-0.588504582,0.727527920),
                        float3(0.138061710,0.674943212,0.724838344),
                        float3(-0.560010438,-0.406083654,0.722138751),
                        float3(0.690039195,-0.079169342,0.719429027),
                        float3(-0.457175051,0.526610955,0.716709059),
                        float3(-0.018688540,-0.699917933,0.713978729),
                        float3(0.488502791,0.505475666,0.711237917),
                        float3(-0.704418524,-0.042911743,0.708486503),
                        float3(0.550549162,-0.445924596,0.705724362),
                        float3(-0.105146840,0.703422716,0.702951367),
                        float3(-0.399155482,-0.591980174,0.700167391),
                        float3(0.696856392,0.167520277,0.697372300),
                        float3(-0.629378047,0.348513125,0.694565962),
                        float3(0.229527822,-0.684690700,0.691748238),
                        float3(0.294351535,0.662380403,0.688918990),
                        float3(-0.666942796,-0.290661628,0.686078075),
                        float3(0.690656498,-0.237058489,0.683225347),
                        float3(-0.350414458,0.643676225,0.680360658),
                        float3(-0.177052664,-0.713910344,0.677483856),
                        float3(0.615000901,0.408283929,0.674594786),
                        float3(-0.731883575,0.114780478,0.671693289),
                        float3(0.463776764,-0.581072705,0.668779205),
                        float3(0.050712673,0.744358012,0.665852367),
                        float3(-0.542092686,-0.516413008,0.662912607),
                        float3(0.751157925,0.014659345,0.659959753),
                        float3(-0.565730164,0.498305887,0.656993626),
                        float3(0.080827360,-0.752151955,0.654014048),
                        float3(0.449999783,0.611287224,0.651020833),
                        float3(-0.747254681,-0.147270386,0.648013792),
                        float3(0.652668563,-0.397502355,0.644992733),
                        float3(-0.213458851,0.736427827,0.641957456),
                        float3(-0.341179806,-0.689487647,0.638907759),
                        float3(0.719681075,0.278858880,0.635843436),
                        float3(-0.721390540,0.281433943,0.632764273),
                        float3(0.342936665,-0.697072499,0.629670052),
                        float3(0.218699231,0.748059170,0.626560552),
                        float3(-0.668708588,-0.405162868,0.623435542),
                        float3(0.769214325,-0.153439557,0.620294789),
                        float3(-0.465017024,0.634743879,0.617138052),
                        float3(-0.086144719,-0.784618355,0.613965085),
                        float3(0.595380183,0.521991918,0.610775634),
                        float3(-0.794077554,0.017326667,0.607569440),
                        float3(0.575597883,-0.550865412,0.604346238),
                        float3(-0.052484476,0.797444202,0.601105752),
                        float3(-0.501492015,-0.625366999,0.597847702),
                        float3(0.794618240,0.122744565,0.594571800),
                        float3(-0.670857142,0.447595040,0.591277748),
                        float3(0.192899756,-0.785548572,0.587965241),
                        float3(0.389549814,0.711655863,0.584633967),
                        float3(-0.770233975,-0.262390926,0.581283601),
                        float3(0.747384052,-0.327769286,0.577913813),
                        float3(-0.330658196,0.748723602,0.574524260),
                        float3(-0.262701022,-0.777699362,0.571114590),
                        float3(0.721117079,0.397145481,0.567684441),
                        float3(-0.802299364,0.194823908,0.564233440),
                        float3(0.461305060,-0.687564191,0.560761201),
                        float3(0.124644545,0.820924395,0.557267328),
                        float3(-0.648264145,-0.522602118,0.553751411),
                        float3(0.833360084,-0.052693408,0.550213027),
                        float3(-0.580519208,0.603464435,0.546651740),
                        float3(0.020479236,-0.839439531,0.543067100),
                        float3(0.553459291,0.634560626,0.539458641),
                        float3(-0.839045112,-0.094307609,0.535825881),
                        float3(0.684256634,-0.498587739,0.532168324),
                        float3(-0.168214854,0.832109901,0.528485454),
                        float3(-0.439231276,-0.729167513,0.524776738),
                        float3(0.818618689,0.241617606,0.521041625),
                        float3(-0.768887399,0.375811179,0.517279542),
                        float3(0.313930650,-0.798608585,0.513489898),
                        float3(0.308785472,0.803047886,0.509672076),
                        float3(-0.772169207,-0.384571632,0.505825439),
                        float3(0.831321340,-0.238645563,0.501949325),
                        float3(-0.452965788,0.739442438,0.498043045),
                        float3(-0.165912585,-0.853423921,0.494105884),
                        float3(0.700621758,0.518550651,0.490137098),
                        float3(-0.869118270,0.091133462,0.486135912),
                        float3(0.580780693,-0.655951150,0.482101519),
                        float3(0.014876738,0.878215838,0.478033079),
                        float3(-0.605723597,-0.639131871,0.473929715),
                        float3(0.880578842,0.062271806,0.469790512),
                        float3(-0.693106038,0.550279152,0.465614513),
                        float3(0.139713711,-0.876121826,0.461400721),
                        float3(0.490002628,0.742235171,0.457148089),
                        float3(-0.864812806,-0.216842535,0.452855523),
                        float3(0.786085401,-0.425320900,0.448521878),
                        float3(-0.293048654,0.846674000,0.444145950),
                        float3(-0.356699840,-0.824260789,0.439726477),
                        float3(0.821782114,0.367724126,0.435262134),
                        float3(-0.856406835,0.284640928,0.430751524),
                        float3(0.440267578,-0.790268205,0.426193178),
                        float3(0.209677532,0.882213669,0.421585549),
                        float3(-0.752317092,-0.510089079,0.416927002),
                        float3(0.901418919,-0.132370910,0.412215811),
                        float3(-0.576614963,0.708166336,0.407450150),
                        float3(-0.053305960,-0.913810210,0.402628085),
                        float3(0.658104784,0.639292553,0.397747564),
                        float3(-0.919227285,-0.026913266,0.392806409),
                        float3(0.697594755,-0.602470690,0.387802301),
                        float3(-0.107668221,0.917563719,0.382732772),
                        float3(-0.541649426,-0.751024483,0.377595187),
                        float3(0.908768219,0.188330690,0.372386728),
                        float3(-0.799118876,0.476070790,0.367104379),
                        float3(0.268267719,-0.892845483,0.361744903),
                        float3(0.406205948,0.841453268,0.356304820),
                        float3(-0.869856622,-0.346846626,0.350780380),
                        float3(0.877644891,-0.332564010,0.345167532),
                        float3(-0.423440048,0.839919133,0.339461890),
                        float3(-0.255688281,-0.907356258,0.333658695),
                        float3(0.803206416,0.497430978,0.327752765),
                        float3(-0.930298218,0.176152210,0.321738442),
                        float3(0.568217762,-0.759946841,0.315609529),
                        float3(0.094555065,0.946232643,0.309359217),
                        float3(-0.710422365,-0.635219008,0.302979991),
                        float3(0.954974725,-0.011517374,0.296463531),
                        float3(-0.697878370,0.654966721,0.289800578),
                        float3(0.072323845,-0.956394864,0.282980786),
                        float3(0.593963162,0.755669165,0.275992527),
                        float3(-0.950420132,-0.156320015,0.268822665),
                        float3(0.808098787,-0.527841809,0.261456258),
                        float3(-0.239816060,0.937035289,0.253876200),
                        float3(-0.457076597,-0.854712881,0.246062746),
                        float3(0.916283348,0.322155554,0.237992910),
                        float3(-0.895099246,0.382181847,0.229639663),
                        float3(0.402685920,-0.888265684,0.220970869),
                        float3(0.303708500,0.928891421,0.211947812),
                        float3(-0.853141668,-0.480763632,0.202523147),
                        float3(0.955771937,-0.222240025,0.192637938),
                        float3(-0.555759384,0.811127846,0.182217247),
                        float3(-0.138388042,-0.975475205,0.171163299),
                        float3(0.762496652,0.627063180,0.159344360),
                        float3(-0.987790001,0.052787684,0.146575492),
                        float3(0.694089310,-0.707574664,0.132582521),
                        float3(-0.033907247,0.992561546,0.116926793),
                        float3(-0.646740425,-0.756281163,0.098821177),
                        float3(0.989693148,0.121029326,0.076546554),
                        float3(-0.813115846,0.580421826,0.044194174)};
                        float blocked=0.0;
                        for (int i=0;i<256;++i) {
                            float3 ray=tangent*samples[i].x+bitangent*samples[i].y+n*samples[i].z;
                            float hit=0.0;

                        """
                        for other in centers.indices where other != receiverIndex {
                            let c=centers[other]
                            shader += """
                            {
                                float3 delta=float3(\(c.x),\(c.y),\(c.z))-p;
                                float b=dot(delta,ray);
                                hit=max(hit,(b>0.0 && b*b>dot(delta,delta)-\(r*r)) ? 1.0 : 0.0);
                            }

                            """
                        }
                        shader += "blocked+=hit; }\n_surface.ambientOcclusion=1.0-blocked/256.0;"
                        func apply(_ node:SCNNode) {
                            for m in node.geometry?.materials ?? [] {
                                var modifiers=m.shaderModifiers ?? [:];modifiers[.surface]=shader;m.shaderModifiers=modifiers
                            }
                        }
                        apply(receiver);receiver.enumerateChildNodes { node,_ in apply(node) }
                    }
                }
                for view in ["entry","detail","orbit"] {
                    if view == "detail" { s.cameraRig?.handleObservationPinch(scale:2) }
                    if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX:180) }
                    for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
                    try capture(s,name:"compare/\(layout)-\(mode)-\(view)")
                }
            }
        }
    }

    private func installBallOcclusionPrototype(_ scene: AngleTrainingScene) throws -> (Bool) -> [SIMD4<Float>] {
        let balls = scene.allBallNodes.sorted { $0.key < $1.key }.map(\.value)
        let radius = AngleSceneCalculator.ballRadius
        let groups = (balls.count + 3) / 4
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float, width: 64, height: 64, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let data = try Data(contentsOf: directory.appendingPathComponent("sphere-ao-64.r16f"))
        XCTAssertEqual(data.count, 8192)
        data.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0,0,64,64), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 128) }
        var targets: [SCNMaterial] = []
        for (receiverIndex, receiver) in balls.enumerated() {
            var shader = "#pragma arguments\ntexture2d<float> sphereVisibility;\n"
            for group in 0..<groups { shader += "float4x4 sphereGroup\(group);\n" }
            shader += """
            #pragma body
            float3 p = (scn_frame.inverseViewTransform * float4(_surface.position,1.0)).xyz;
            float3 n = normalize((scn_frame.inverseViewTransform * float4(_surface.normal,0.0)).xyz);
            constexpr sampler sphereSampler(coord::normalized,address::clamp_to_edge,filter::linear);
            float visibility = 1.0;

            """
            for index in balls.indices where index != receiverIndex {
                shader += """
                {
                    float4 other = sphereGroup\(index / 4)[\(index % 4)];
                    if (other.w > 0.0) {
                        float3 delta = other.xyz-p;
                        float inverseDistance = rsqrt(max(dot(delta,delta),1e-10));
                        float normalDot = clamp(dot(n,delta)*inverseDistance,-1.0,1.0);
                        float alpha = asin(clamp(\(radius)*inverseDistance,0.0,1.0));
                        float2 uv = float2((normalDot+1.0)*0.5,alpha/1.5707963267948966);
                        float blocked = sphereVisibility.sample(sphereSampler,(uv*63.0+0.5)/64.0).r;
                        visibility *= 1.0-other.w*blocked;
                    }
                }

                """
            }
            shader += "_surface.ambientOcclusion = visibility;"
            func apply(_ node: SCNNode) {
                for m in node.geometry?.materials ?? [] {
                    var modifiers = m.shaderModifiers ?? [:]; modifiers[.surface] = shader
                    m.shaderModifiers = modifiers
                    m.setValue(SCNMaterialProperty(contents: texture), forKey: "sphereVisibility")
                    targets.append(m)
                }
            }
            apply(receiver); receiver.enumerateChildNodes { node, _ in apply(node) }
        }
        var previous = Array(repeating: SIMD4<Float>(repeating: .nan), count: balls.count)
        return { presentation in
            var dirty: UInt = 0
            for (index,node) in balls.enumerated() {
                let shown = presentation ? node.presentation : node
                let p = shown.worldPosition
                let weight: Float = node.isHidden || node.parent == nil ? 0 : Float(shown.opacity)
                let value = SIMD4(p.x,p.y,p.z,weight)
                if value != previous[index] { previous[index] = value; dirty |= 1 << (index / 4) }
            }
            SCNTransaction.begin(); SCNTransaction.disableActions = true
            for group in 0..<groups where dirty & (1 << group) != 0 {
                func column(_ offset: Int) -> SIMD4<Float> { group*4+offset < previous.count ? previous[group*4+offset] : .zero }
                let matrix = simd_float4x4(columns:(column(0),column(1),column(2),column(3)))
                let value = NSValue(scnMatrix4: SCNMatrix4(matrix))
                for m in targets { m.setValue(value,forKey:"sphereGroup\(group)") }
            }
            SCNTransaction.commit()
            return previous
        }
    }

    func testDynamicBallOcclusionPrototype() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for enabled in [false,true] {
            let s = try scene(mobile:true)
            let r = AngleSceneCalculator.ballRadius; let y = s.surfaceY+r
            s.applyBallLayout(cueBallPosition: SCNVector3(-0.45,y,0), targetBallNumber:3, targetPosition:SCNVector3(-0.45,y,2*r+0.002))
            s.setCueBallHomeOrientation(simd_quatf(angle:0,axis:SIMD3<Float>(0,1,0)))
            s.cameraRig?.handleObservationPinch(scale:2)
            for _ in 0..<120 { s.cameraRig?.update(deltaTime:1/60) }
            let target = try XCTUnwrap(s.allBallNodes["_3"])
            let targetIndex = try XCTUnwrap(s.allBallNodes.keys.sorted().firstIndex(of:"_3"))
            let update = enabled ? try installBallOcclusionPrototype(s) : nil
            var values = update?(false) ?? []
            let renderer = SCNRenderer(device:try XCTUnwrap(MTLCreateSystemDefaultDevice()),options:nil)
            renderer.scene=s; renderer.pointOfView=s.cameraNode; renderer.autoenablesDefaultLighting=false
            let delegate = RenderContactFrameUpdater {
                s.contactOcclusion?.renderer(renderer,didApplyAnimationsAtTime:0)
                values = update?(true) ?? []
            }
            renderer.delegate=delegate
            let size=CGSize(width:1176,height:2000)
            _=renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
            target.runAction(.sequence([.move(by:SCNVector3(0,0,0.15),duration:1),.fadeOut(duration:0.5),.removeFromParentNode()]))
            let dir=directory.appendingPathComponent(enabled ? "dynamic/on" : "dynamic/off")
            try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
            var rows:[[String:Any]]=[]
            for frame in 0...120 {
                let shot=renderer.snapshot(atTime:Double(frame)/60,with:size,antialiasingMode:.multisampling4X)
                if enabled && frame < 80 {
                    let p=target.presentation.worldPosition
                    XCTAssertEqual(values[targetIndex].x,p.x,accuracy:0.00001)
                    XCTAssertEqual(values[targetIndex].z,p.z,accuracy:0.00001)
                    XCTAssertEqual(values[targetIndex].w,Float(target.presentation.opacity),accuracy:0.00001)
                }
                if enabled && frame==120 { XCTAssertEqual(values[targetIndex].w,0); XCTAssertNil(target.parent) }
                if frame % 10 == 0 {
                    try XCTUnwrap(shot.pngData()).write(to:dir.appendingPathComponent(String(format:"%03d.png",frame)))
                    rows.append(["frame":frame,"targetOpacity":target.presentation.opacity,"attached":target.parent != nil,"uniforms":values.map { [$0.x,$0.y,$0.z,$0.w] }])
                }
            }
            try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("samples.json"))
            withExtendedLifetime(delegate) {}
        }
    }

    func testStaticBallMutualOcclusionLUT() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float, width: 64, height: 64, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        let lookup = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let data = try Data(contentsOf: directory.appendingPathComponent("sphere-ao-64.r16f"))
        XCTAssertEqual(data.count, 64 * 64 * 2)
        data.withUnsafeBytes { bytes in
            lookup.replace(region: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: 64 * 2)
        }
        let radius = AngleSceneCalculator.ballRadius
        for gap: Float in [0.002, 0.15] {
            for enabled in [false, true] {
                let s = try scene(mobile: true)
                let y = s.surfaceY + radius
                s.applyBallLayout(cueBallPosition: SCNVector3(-0.45, y, 0), targetBallNumber: 3,
                                  targetPosition: SCNVector3(-0.45, y, 2 * radius + gap))
                s.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)))
                let cue = try XCTUnwrap(s.cueBallNode)
                let target = try XCTUnwrap(s.allBallNodes["_3"])
                XCTAssertGreaterThanOrEqual(simd_distance(cue.simdWorldPosition, target.simdWorldPosition), 2 * radius)
                if enabled {
                    for (receiver, occluder) in [(cue, target), (target, cue)] {
                        let center = occluder.worldPosition
                        let shader = """
                        #pragma arguments
                        texture2d<float> sphereVisibility;
                        #pragma body
                        float3 p = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
                        float3 n = normalize((scn_frame.inverseViewTransform * float4(_surface.normal, 0.0)).xyz);
                        float3 delta = float3(\(center.x),\(center.y),\(center.z)) - p;
                        float inverseDistance = rsqrt(dot(delta,delta));
                        float normalDot = clamp(dot(n,delta)*inverseDistance,-1.0,1.0);
                        float alpha = asin(clamp(\(radius)*inverseDistance,0.0,1.0));
                        float2 coordinate = float2((normalDot+1.0)*0.5,alpha/1.5707963267948966);
                        constexpr sampler lookupSampler(coord::normalized,address::clamp_to_edge,filter::linear);
                        float occluded = sphereVisibility.sample(lookupSampler,(coordinate*63.0+0.5)/64.0).r;
                        _surface.ambientOcclusion = 1.0-occluded;
                        """
                        func apply(_ node: SCNNode) {
                            for m in node.geometry?.materials ?? [] {
                                var modifiers = m.shaderModifiers ?? [:]
                                modifiers[.surface] = shader
                                m.shaderModifiers = modifiers
                                m.setValue(SCNMaterialProperty(contents: lookup), forKey: "sphereVisibility")
                            }
                        }
                        apply(receiver)
                        receiver.enumerateChildNodes { node, _ in apply(node) }
                    }
                }
                for view in ["entry", "detail", "orbit"] {
                    if view == "detail" { s.cameraRig?.handleObservationPinch(scale: 2) }
                    if view == "orbit" { s.cameraRig?.handleObservationPan(deltaX: 180) }
                    for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                    try capture(s, name: "compare/gap\(gap)-\(enabled ? "on" : "off")-\(view)")
                }
            }
        }
    }

    func testCandidateContactCases() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let radius = AngleSceneCalculator.ballRadius
        let halfLength = AngleSceneCalculator.innerLength / 2
        let halfWidth = AngleSceneCalculator.innerWidth / 2
        let layouts: [(String, SIMD2<Float>, SIMD2<Float>)] = [
            ("rail", SIMD2(0.35, halfWidth - radius - 0.002), SIMD2(-0.45, 0)),
            ("corner", SIMD2(halfLength - 0.12, halfWidth - 0.12), SIMD2(-0.45, 0)),
            ("middle", SIMD2(0.06, halfWidth - 0.10), SIMD2(-0.45, 0)),
            ("adjacent", SIMD2(0.35, 0.12), SIMD2(0.35 - 2 * radius - 0.002, 0.12))
        ]
        for mobile in [false, true] {
            for (name, target, cue) in layouts {
                for position in [target, cue] {
                    XCTAssertLessThanOrEqual(abs(position.x) + radius, halfLength)
                    XCTAssertLessThanOrEqual(abs(position.y) + radius, halfWidth)
                }
                XCTAssertGreaterThanOrEqual(simd_distance(target, cue), 2 * radius)
                let s = try scene(mobile: mobile)
                let y = s.surfaceY + radius
                s.applyBallLayout(cueBallPosition: SCNVector3(cue.x, y, cue.y), targetBallNumber: 3,
                                  targetPosition: SCNVector3(target.x, y, target.y))
                s.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)))
                // Use the existing observation gesture to inspect the whole table.
                s.cameraRig?.handleObservationPinch(scale: 0.5)
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "contact/\(mobile ? "mobile" : "baseline")-\(name)")
            }
        }
    }

    func testOffsetKeyContactComparison() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let radius = AngleSceneCalculator.ballRadius
        let halfLength = AngleSceneCalculator.innerLength / 2
        let halfWidth = AngleSceneCalculator.innerWidth / 2
        let layouts: [(String, SIMD2<Float>, SIMD2<Float>)] = [
            ("rail", SIMD2(0.35, halfWidth - radius - 0.002), SIMD2(-0.45, 0)),
            ("corner", SIMD2(halfLength - 0.12, halfWidth - 0.12), SIMD2(-0.45, 0)),
            ("middle", SIMD2(0.06, halfWidth - 0.10), SIMD2(-0.45, 0)),
            ("adjacent", SIMD2(0.35, 0.12), SIMD2(0.35 - 2 * radius - 0.002, 0.12))
        ]
        for mobile in [false, true] {
            for (name, target, cue) in layouts {
                for position in [target, cue] {
                    XCTAssertLessThanOrEqual(abs(position.x) + radius, halfLength)
                    XCTAssertLessThanOrEqual(abs(position.y) + radius, halfWidth)
                }
                XCTAssertGreaterThanOrEqual(simd_distance(target, cue), 2 * radius)
                let s = try scene(mobile: true)
                if !mobile {
                    s.lightingEnvironment.intensity = 0.7
                    s.rootNode.enumerateChildNodes { node, _ in
                        if node.light?.castsShadow == true {
                            node.light?.intensity = 8
                            node.position = SCNVector3(0,s.surfaceY+2.2,0)
                            node.eulerAngles = SCNVector3(-Float.pi/2,0,0)
                        }
                    }
                }
                let y = s.surfaceY + radius
                s.applyBallLayout(cueBallPosition: SCNVector3(cue.x, y, cue.y), targetBallNumber: 3,
                                  targetPosition: SCNVector3(target.x, y, target.y))
                s.setCueBallHomeOrientation(simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)))
                // Use the existing observation gesture to inspect the whole table.
                s.cameraRig?.handleObservationPinch(scale: 0.5)
                for _ in 0..<120 { s.cameraRig?.update(deltaTime: 1/60) }
                try capture(s, name: "contact/\(mobile ? "mobile" : "baseline")-\(name)")
            }
        }
    }

    private func lightCandidate(_ s: AngleTrainingScene) {
        materials(s) { $0.shaderModifiers = nil }
        s.lightingEnvironment.contents = MobileTableRendering.environmentURL
        s.lightingEnvironment.intensity = 0.35
        s.rootNode.enumerateChildNodes { n,_ in
            if n.light?.type == .ambient { n.light?.intensity = 120 }
        }
    }

    func testShadowAblation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in 0..<3 {
            let s = try scene(); lightCandidate(s)
            if variant == 0 || variant == 2 { s.cameraNode.camera?.screenSpaceAmbientOcclusionIntensity = 0 }
            s.rootNode.enumerateChildNodes { n,_ in
                guard let light = n.light, light.castsShadow else { return }
                if variant == 1 { light.castsShadow = false }
                if variant == 2 {
                    light.shadowMapSize = CGSize(width: 1024,height: 1024)
                    light.shadowSampleCount = 8
                    light.shadowRadius = 3
                    light.shadowBias = 0.002
                    light.shadowColor = UIColor(white:0,alpha:0.55)
                }
            }
            try capture(s,name:"W2/S\(variant)")
        }
    }

    private func shadowCandidate(_ s: AngleTrainingScene, size: CGFloat = 1024) {
        s.cameraNode.camera?.screenSpaceAmbientOcclusionIntensity = 0
        s.rootNode.enumerateChildNodes { n,_ in
            guard let light = n.light, light.castsShadow else { return }
            light.shadowMapSize = CGSize(width:size,height:size)
            light.shadowSampleCount = 8
            light.shadowRadius = 3
            light.shadowBias = 0.002
            light.shadowColor = UIColor(white:0,alpha:0.85)
        }
    }

    func testShadowRefinement() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in 3..<6 {
            let s = try scene();lightCandidate(s);shadowCandidate(s,size:variant >= 4 ? 2048 : 1024)
            if variant == 5 {
                s.cameraNode.camera?.screenSpaceAmbientOcclusionRadius = 0.04
                s.cameraNode.camera?.screenSpaceAmbientOcclusionIntensity = 0.25
            }
            try capture(s,name:"W2/S\(variant)")
        }
    }

    func testClothMaterials() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let raw = try XCTUnwrap(TableModelLoader.loadTable())
        var originals: [String:SCNMaterial] = [:]
        raw.visualNode.enumerateChildNodes { n,_ in
            for m in n.geometry?.materials ?? [] { if let name=m.name { originals[name]=m } }
        }
        for variant in 0..<3 {
            let s = try scene();lightCandidate(s);shadowCandidate(s)
            s.tableNode?.enumerateChildNodes { n,_ in
                for m in n.geometry?.materials ?? [] {
                    guard m.name == "TaiNi",let original=originals["TaiNi"] else { continue }
                    m.roughness.contents = original.roughness.contents
                    if variant >= 1 { m.normal.intensity = 0.3 }
                    if variant >= 2 { m.multiply.contents = UIColor(white:0.68,alpha:1) }
                }
            }
            try capture(s,name:"W3/C\(variant)")
        }
    }

    func testClothRefinement() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        let raw = try XCTUnwrap(TableModelLoader.loadTable())
        var originals: [String:SCNMaterial] = [:]
        raw.visualNode.enumerateChildNodes { n,_ in
            for m in n.geometry?.materials ?? [] { if let name=m.name { originals[name]=m } }
        }
        for variant in 3..<5 {
            let s = try scene();lightCandidate(s);shadowCandidate(s)
            s.tableNode?.enumerateChildNodes { n,_ in
                for m in n.geometry?.materials ?? [] {
                    if m.name == "TaiNi",let original=originals["TaiNi"] {
                        m.roughness.contents = original.roughness.contents
                        m.normal.intensity = 0.65
                        m.multiply.contents = UIColor(white:0.68,alpha:1)
                    }
                    if variant == 4, m.name?.contains("Wood") == true {
                        m.roughness.intensity = 0.75
                    }
                }
            }
            try capture(s,name:"W3/C\(variant)")
        }
    }

    func testSecondRoundHDR() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        for variant in 0..<3 {
            let s = try scene()
            materials(s) { $0.shaderModifiers = nil }
            s.lightingEnvironment.contents = MobileTableRendering.environmentURL
            s.lightingEnvironment.intensity = 0.35
            s.rootNode.enumerateChildNodes { n,_ in
                if n.light?.type == .ambient { n.light?.intensity = 120 }
            }
            if variant >= 1 { materials(s) { $0.roughness.contents = Float(0.18) } }
            if variant >= 2 { s.lightingEnvironment.intensity = 0.7 }
            try capture(s, name: "W1/H\(variant)")
        }
    }

    func testBaselineAndBallLightingAblation() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["V62_SHOT_DIR"] != nil, "Explicit v62 evidence run required")
        // Round one: each variant differs from its predecessor by one factor.
        for variant in 0..<4 {
            let s = try scene()
            if variant >= 1 { materials(s) { $0.shaderModifiers = nil } }
            if variant >= 2 {
                EnhancedEnvironment.apply(to: s)
                s.lightingEnvironment.intensity = 0.35
            }
            if variant >= 3 {
                s.rootNode.enumerateChildNodes { n,_ in
                    if n.light?.type == .ambient { n.light?.intensity = 120 }
                }
            }
            try capture(s, name: variant == 0 ? "W0/B0" : "W1/A\(variant)")
            if variant == 0 {
                var rows: [[String:Any]] = []
                s.rootNode.enumerateChildNodes { node,_ in
                    for mat in node.geometry?.materials ?? [] {
                        let properties = ["diffuse":mat.diffuse,"normal":mat.normal,"roughness":mat.roughness,"metalness":mat.metalness,"multiply":mat.multiply,"ao":mat.ambientOcclusion]
                        var row: [String:Any] = ["node":node.name ?? "", "material":mat.name ?? "", "lighting":mat.lightingModel.rawValue]
                        for (key,p) in properties {
                            row[key] = ["contents":String(describing:p.contents),"type":String(describing:type(of:p.contents as Any)),"intensity":p.intensity]
                        }
                        rows.append(row)
                    }
                }
                try JSONSerialization.data(withJSONObject: rows,options:[.prettyPrinted,.sortedKeys]).write(to:directory.appendingPathComponent("W0/materials.json"))
            }
        }
    }
}

/// Update contact uniforms after SCNAction animation, before the frame is rendered.
private final class RenderContactFrameUpdater: NSObject, SCNSceneRendererDelegate {
    private let update: () -> Void
    init(update: @escaping () -> Void) { self.update = update }
    func renderer(_ renderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
        update()
    }
}

private final class ReferenceFrameSamples: @unchecked Sendable {
    private let lock=NSLock()
    private var rows:[Int:[String:Double]]=[:]
    func set(_ id:Int,_ values:[String:Double]) {
        lock.lock();defer { lock.unlock() }
        for (key,value) in values { rows[id,default:[:]][key]=value }
    }
    func snapshot()->[[String:Double]] {
        lock.lock();defer { lock.unlock() }
        return rows.keys.sorted().compactMap { rows[$0] }
    }
}

@MainActor
private final class ReferenceFrameProbe:NSObject,MTKViewDelegate {
    let samples=ReferenceFrameSamples()
    let renderer:SCNRenderer
    let queue:MTLCommandQueue
    let scene:AngleTrainingScene
    var frame=0
    var stopAt = Double.infinity
    var lastDrawTime: Double?
    var firstDrawTime: Double?
    var mixedActivity = false
    init(scene:AngleTrainingScene,device:MTLDevice) {
        self.scene=scene;renderer=SCNRenderer(device:device,options:nil)
        queue=device.makeCommandQueue()!
        super.init()
        renderer.scene=scene;renderer.pointOfView=scene.cameraNode
        renderer.delegate=scene.contactOcclusion;renderer.autoenablesDefaultLighting=false
    }
    func mtkView(_ view:MTKView,drawableSizeWillChange size:CGSize) {}
    func draw(in view:MTKView) {
        let start=CACurrentMediaTime()
        guard start < stopAt,
              ProcessInfo.processInfo.thermalState != .serious,
              ProcessInfo.processInfo.thermalState != .critical else { view.isPaused = true; return }
        if firstDrawTime == nil { firstDrawTime = start }
        let active = !mixedActivity || (start - firstDrawTime!).truncatingRemainder(dividingBy: 20) < 7
        if mixedActivity {
            let fps = active ? min(120, view.window?.screen.maximumFramesPerSecond ?? 60) : 30
            if view.preferredFramesPerSecond != fps { view.preferredFramesPerSecond = fps }
        }
        let dt = min(0.1, max(0, start - (lastDrawTime ?? start)))
        lastDrawTime = start
        guard let drawable=view.currentDrawable,let pass=view.currentRenderPassDescriptor,
              let command=queue.makeCommandBuffer() else { return }
        let id=frame;frame+=1
        // Exercise live camera and contact-uniform updates, without changing physics.
        if active { scene.cameraRig?.handleObservationPan(deltaX:Float(21 * dt)) }
        scene.cameraRig?.update(deltaTime:Float(dt))
        renderer.render(atTime:start,viewport:CGRect(origin:.zero,size:view.drawableSize),commandBuffer:command,passDescriptor:pass)
        samples.set(id,["active":active ? 1 : 0,"frame":Double(id),"start":start,"cpuMS":(CACurrentMediaTime()-start)*1000])
        let samples=self.samples
        #if !targetEnvironment(simulator)
        // Presentation callbacks are unavailable in the simulator SDK. This probe
        // deliberately measures presentation only on physical hardware.
        drawable.addPresentedHandler { presented in samples.set(id,["presented":presented.presentedTime]) }
        #endif
        command.addCompletedHandler { done in
            samples.set(id,["gpuMS":(done.gpuEndTime-done.gpuStartTime)*1000,"gpuEnd":done.gpuEndTime,"error":done.status == .error ? 1:0])
        }
        command.present(drawable);command.commit()
    }
}

private final class ReferenceLockedFrameCount: @unchecked Sendable {
    private let lock = NSLock()
    private var total = 0
    var value: Int { lock.withLock { total } }
    func increment() { lock.withLock { total += 1 } }
}
