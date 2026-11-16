    func testNativeClothLTCR7a() throws {
        try runNativeClothLTCR7Cost(finalIntegration: false)
    }

    func testNativeClothLTCR7Final() throws {
        try runNativeClothLTCR7Cost(finalIntegration: true)
    }

    private func runNativeClothLTCR7Cost(finalIntegration: Bool) throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("R7 cost requires native Metal")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else { throw XCTSkip("Native Mac scope") }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let referenceScene = AngleTrainingScene(); referenceScene.clothLTCRequested = false
        referenceScene.configureDailyClearanceRendering(asynchronousReflection: false)
        referenceScene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        @MainActor func cloth(_ scene: AngleTrainingScene) -> [SCNMaterial] {
            var result = [SCNMaterial](), seen = Set<ObjectIdentifier>()
            scene.rootNode.enumerateChildNodes { node,_ in
                for m in node.geometry?.materials ?? [] where m.name == "TaiNi" && seen.insert(ObjectIdentifier(m)).inserted { result.append(m) }
            }
            return result
        }
        let baseline = try XCTUnwrap(cloth(referenceScene).first?.shaderModifiers?[.surface])
        try require(ClothResearchShaders.sha256(baseline) == ClothShadowProgram.outputSHA256, "R7 exact baseline")
        let scene = AngleTrainingScene()
        try require(scene.clothLTCRequested, "Production default requested")
        scene.configureDailyClearanceRendering(asynchronousReflection: false)
        scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        try require(scene.clothLTCState == ClothSpecularLTC.identity, "Production installation")
        let mats = cloth(scene), resource = try XCTUnwrap(scene.clothSpecularLTC)
        let candidate = try XCTUnwrap(mats.first?.shaderModifiers?[.surface])
        try require(mats.allSatisfy { $0.shaderModifiers?[.surface] == candidate }, "Shared cloth source")
        try require(ClothSpecularLTC.replacingSpecular(in: baseline) == candidate, "Current generator transformation")
        try require(ClothSpecularLTC.replacingSpecular(in: baseline + " ") == nil && ClothSpecularLTC.replacingSpecular(in: candidate) == nil, "Drift and double-application fallback")
        let duplicate = try ClothSpecularLTC.acquire(emitter: MobileReferenceLighting.emitterGeometry,
            radiance: StaticClothIrradiance.expectedRadiance, device: device)
        try require(resource === duplicate, "LUT shared on same device")
        XCTAssertThrowsError(try ClothSpecularLTC.acquire(emitter: "different", radiance: StaticClothIrradiance.expectedRadiance, device: device))
        XCTAssertThrowsError(try ClothSpecularLTC.acquire(emitter: MobileReferenceLighting.emitterGeometry, radiance: 1, device: device))
        XCTAssertThrowsError(try ClothSpecularLTC.acquire(emitter: MobileReferenceLighting.emitterGeometry, radiance: StaticClothIrradiance.expectedRadiance, device: device, assetURL: nil))
        let invalid = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([0, 1]).write(to: invalid)
        defer { try? FileManager.default.removeItem(at: invalid) }
        XCTAssertThrowsError(try ClothSpecularLTC.acquire(emitter: MobileReferenceLighting.emitterGeometry,
            radiance: StaticClothIrradiance.expectedRadiance, device: device, assetURL: invalid))
        try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal), "Appearance")
        let camera = try XCTUnwrap(scene.cameraNode), size = CGSize(width: 1400, height: 800)
        scene.cameraRig?.viewportSize = size; scene.setCameraMode(.perspective3D, animated: false)
        let appPose = camera.simdTransform
        let appFOV = camera.camera!.fieldOfView
        let target = try RenderTarget(device: device, scene: scene, size: size)
        let probe = H17AnimationProbe(contact: scene.contactOcclusion); target.renderer.delegate = probe
        let carrier = SCNNode(); scene.rootNode.addChildNode(carrier)
        let keys = ["cueBall"] + (1...15).map { "_\($0)" }
        for key in keys { carrier.addChildNode(try XCTUnwrap(scene.allBallNodes[key])) }
        @MainActor func balls(_ count: Int) {
            scene.hideAllBalls()
            for (i,key) in keys.prefix(count).enumerated() {
                scene.allBallNodes[key]?.opacity = 1
                let x: Float = count == 2 ? Float(i) * 0.075 : Float(i / 4) * 0.6 - 0.9
                let z: Float = count == 2 ? 0 : Float(i % 4) * 0.3 - 0.45
                scene.showBall(key: key, scenePosition: SCNVector3(x, scene.surfaceY + AngleSceneCalculator.ballRadius, z))
            }
            SCNTransaction.flush()
        }
        @MainActor func restart() {
            carrier.removeAllActions(); carrier.simdPosition = .zero
            carrier.runAction(.customAction(duration: 600) { node, elapsed in probe.actionStep(node, elapsed: Double(elapsed)) })
            SCNTransaction.flush()
        }
        @MainActor func install(_ source: String) {
            for m in mats { var modifiers = m.shaderModifiers ?? [:]; modifiers[.surface] = source; m.shaderModifiers = modifiers }
            SCNTransaction.flush()
        }
        // Eye and look target in world metres; each boundary is also exercised on the original source.
        let poses: [(String, SIMD3<Float>, SIMD3<Float>, Int)] = finalIntegration ? [
            ("near-empty-fallback", SIMD3(0.16, 1.15, 0.3), SIMD3(0, 0.8, 0), 0),
            ("near-ltc-increment", SIMD3(0.16, 1.15, 0.3), SIMD3(0, 0.8, 0), 2),
            ("near-16-ltc-increment", SIMD3(0.16, 1.15, 0.3), SIMD3(0, 0.8, 0), 16)
        ] : [
            ("near", SIMD3(0.16, 1.15, 0.3), SIMD3(0, 0.8, 0), 2),
            ("near-16", SIMD3(0.16, 1.15, 0.3), SIMD3(0, 0.8, 0), 16),
            ("pitch30", SIMD3(0, 1.15, 0.604), SIMD3(0, 0.8, 0), 2),
            ("pitch65", SIMD3(0, 1.15, 0.164), SIMD3(0, 0.8, 0), 2),
            ("height-upper", SIMD3(0, 1.299, 0.499), SIMD3(0, 0.8, 0), 2),
            ("height-old-upper-fallback", SIMD3(0, 1.449, 0.649), SIMD3(0, 0.8, 0), 2),
            ("height-lower", SIMD3(0, 1.051, 0.251), SIMD3(0, 0.8, 0), 2),
            ("low-fallback", SIMD3(0, 1.05, 1.8), SIMD3(0, 0.8, 0), 2),
            ("overview-fallback", SIMD3(1.8, 2.7, 2.1), SIMD3(0, 0.8, 0), 16),
            ("ortho-fallback", SIMD3(0, 3.5, 0.001), SIMD3(0, 0.8, 0), 16),
            ("app-default", SIMD3.zero, SIMD3.zero, 2)
        ]
        var rows = [[String: Any]](), completed = false, epoch: Double = 20
        defer {
            install(candidate); carrier.removeAllActions()
            attachStrictReport(["study": finalIntegration ? "H18-R7-final" : "H18-R7a", "completed": completed && testRun?.totalFailureCount == 0,
                "device": device.name, "rows": rows, "preparationMS": resource.preparationMilliseconds,
                "lookupBytes": resource.allocatedBytes, "sourceSHA": ClothResearchShaders.sha256(candidate)], name: "h18-r7a.json")
        }
        for (name, eye, aim, count) in poses {
            // Compare LTC to the same function-isolated reference integrator,
            // so the mathematical approximation does not take credit for code layout.
            let reference = name.contains("ltc-increment")
                ? candidate.replacingOccurrences(of: "if(clothLTCCloseView &&", with: "if(false && clothLTCCloseView &&") : baseline
            balls(count); camera.camera?.usesOrthographicProjection = name == "ortho-fallback"
            camera.camera?.orthographicScale = 3.3
            if name == "app-default" { camera.simdTransform = appPose; camera.camera?.fieldOfView = appFOV }
            else {
                let d = eye - aim
                let pose = TwoViewCamera.Pose.looking(eye: eye, yaw: atan2(d.z, d.x), pitch: -atan2(d.y, hypot(d.x, d.z)), fov: 50)
                camera.simdTransform = pose.transform; camera.camera?.fieldOfView = 50
                try require(simd_dot(pose.forward, simd_normalize(-d)) > 0.99999, "Real camera transform")
            }
            SCNTransaction.flush(); target.researchTime = epoch; restart()
            install(reference); _ = try target.render(frames: 3); let a = try target.readback()
            _ = try target.render(frames: 1); let aa = try target.readback()
            install(candidate); _ = try target.render(frames: 3); let b = try target.readback()
            install(reference); _ = try target.render(frames: 3); let restored = try target.readback()
            let delta = difference(a,b)
            if name == "near" || name.contains("ltc-increment") { try require(delta.changedPixels > 100, "LTC actually executes in the close view") }
            try require(difference(a,aa).maximum == 0 && difference(a,restored).maximum == 0, "AA/restoration")
            if name.contains("fallback") { try require(delta.maximum == 0, "Fallback is original pixels") }
            attach(a, "h18-r7a-\(name)-A"); attach(b, "h18-r7a-\(name)-B")
            var times = [[String: Any]]()
            for cycle in 0..<6 { for kind in cycle % 2 == 0 ? ["AA","AB"] : ["AB","AA"] {
                for arm in cycle % 2 == 0 ? [false,true,true,false] : [true,false,false,true] {
                    epoch += 10; target.researchTime = epoch; restart()
                    install(kind == "AB" && arm ? candidate : reference)
                    for f in 0..<24 { target.researchTime = epoch + Double(f)/60; _ = try target.render(frames: 1) }
                    var samples = [[String: Any]]()
                    for f in 0..<32 { target.researchTime = epoch + Double(f+24)/60; samples += try target.render(frames: 1, includeNativeTiming: true).perFrameTiming }
                    times.append(["kind": kind, "cycle": cycle, "arm": arm ? "B" : "A", "frames": samples, "thermal": ProcessInfo.processInfo.thermalState.rawValue])
                }
            }}
            rows.append(["pose": name, "reference": name.contains("ltc-increment") ? "function-isolated original integrator" : "C1/H9", "maximum": delta.maximum, "changedPixels": delta.changedPixels,
                "eye": [camera.simdPosition.x, camera.simdPosition.y, camera.simdPosition.z], "down": camera.simdTransform.columns.2.y,
                "times": times])
        }
        // Actual material refresh on capacity growth must discard all LTC resources and shader bindings.
        let extra = (0..<20).map { _ in PositionPlayBall.instanceKey(number: 1) }
        scene.configureBallInstances(extra)
        try require(scene.contactOcclusion!.capacity > 16 && scene.clothSpecularLTC == nil && scene.clothLTCState != ClothSpecularLTC.identity, "Expanded capacity fallback")
        try require(cloth(scene).allSatisfy { !($0.shaderModifiers?[.surface]?.contains("bool clothLTCCloseView=") ?? true) && $0.value(forKey: "h18Table0") == nil }, "Expanded materials clean")
        completed = true
        #endif
    }
