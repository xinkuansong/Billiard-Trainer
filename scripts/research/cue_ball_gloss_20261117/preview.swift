    func testCueBallGlossPreview() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering(asynchronousReflection: false)
        scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal), "Appearance")
        let size = CGSize(width: 1600, height: 1000)
        scene.cameraRig?.viewportSize = size
        scene.setCameraMode(.perspective3D, animated: false)
        scene.hideAllBalls()
        let keys = ["cueBall", "_15", "_2"]
        for (i,key) in keys.enumerated() {
            scene.showBall(key: key, scenePosition: SCNVector3((Float(i)-1)*0.16, scene.surfaceY + AngleSceneCalculator.ballRadius, 0))
        }
        var mats = [SCNMaterial](), seen = Set<ObjectIdentifier>()
        func collect(_ n: SCNNode, clothOnly: Bool) {
            for m in n.geometry?.materials ?? [] where (!clothOnly || m.name == "TaiNi") && seen.insert(ObjectIdentifier(m)).inserted { mats.append(m) }
        }
        let cue = try XCTUnwrap(scene.allBallNodes["cueBall"])
        collect(cue, clothOnly: false)
        cue.enumerateChildNodes { n,_ in collect(n, clothOnly: false) }
        try require(!mats.isEmpty, "Cue materials found")
        for m in mats {
            try require(m.shaderModifiers?[.surface]?.contains("float roughness=0.05;") == true, "Production cue finish is polished")
        }
        let originals = mats.map { $0.shaderModifiers ?? [:] }
        let target = try RenderTarget(device: device, scene: scene, size: size)
        let camera = try XCTUnwrap(scene.cameraNode)
        let exposure = camera.camera!.exposureOffset
        func install(_ roughness: Double, mask: Bool = false) {
            for (i,m) in mats.enumerated() {
                var mods = originals[i]
                if mask { mods[.fragment] = "#pragma body\n_output.color=float4(1.0,0.0,1.0,1.0);" }
                else { mods[.surface] = mods[.surface]!.replacingOccurrences(of: "float roughness=0.05;", with: "float roughness=\(roughness);") }
                m.shaderModifiers = mods
            }
            SCNTransaction.flush()
        }
        var report = [[String: Any]]()
        for view in ["overview", "close", "top"] {
            install(0.34)
            if view == "top" { scene.setCameraMode(.topDown2D, animated: false) }
            else {
                scene.setCameraMode(.perspective3D, animated: false)
                if view == "overview" {
                    try require(scene.cameraRig!.observeWholeTable(yaw: .pi/2), "Production overview")
                } else {
                    let height: Float = 0.22, radius: Float = 0.50, yaw: Float = .pi/2
                    let eye = SIMD3<Float>(0, scene.surfaceY + height, radius)
                    let pose = TwoViewCamera.Pose.looking(eye: eye, yaw: yaw, pitch: -atan2(height,radius), fov: 50)
                    camera.simdTransform = pose.transform
                    camera.camera!.fieldOfView = 50
                    camera.camera!.usesOrthographicProjection = false
                    try require(simd_length(pose.forward - simd_normalize(SIMD3<Float>(0,scene.surfaceY,0)-eye)) < 0.00001, "Camera points at cloth centre")
                }
            }
            SCNTransaction.flush()
            _ = try target.render(frames: 8)
            let baseline = try target.readback()
            attach(baseline, "cue-gloss-\(view)-A-original")
            install(0.34, mask: true); _ = try target.render(frames: 4)
            let mask = try target.readback()
            var targetPixels = Set<Int>()
            for p in stride(from: 0, to: baseline.bgra.count, by: 4) {
                if (0..<3).contains(where: { baseline.bgra[p+$0] != mask.bgra[p+$0] }) { targetPixels.insert(p) }
            }
            for (name,amount) in [("B-polished",0.05)] {
                install(amount); _ = try target.render(frames: 5)
                let frame = try target.readback()
                attach(frame, "cue-gloss-\(view)-\(name)")
                let delta = difference(baseline,frame)
                var outside = 0
                for p in stride(from:0,to:frame.bgra.count,by:4) where !targetPixels.contains(p) {
                    if (0..<3).contains(where:{baseline.bgra[p+$0] != frame.bgra[p+$0]}) {outside += 1}
                }
                try require(frame.magentaPixels == 0 && delta.changedPixels > 30, "Visible valid cue gloss change")
                try require(outside == 0, "Room and all non-target pixels unchanged")
                try require(camera.camera!.exposureOffset == exposure, "Exposure unchanged")
                report.append(["view":view,"variant":name,"roughness":amount,"changedPixels":delta.changedPixels,"maximumChannelDelta":delta.maximum,"outsideTargetChangedPixels":outside])
            }
            install(0.34); _ = try target.render(frames: 5)
            try require(difference(baseline,try target.readback()).maximum == 0,"Exact original restoration")
        }
        attachStrictReport(["scope":"Current production SceneKit on native Mac; no SwiftUI HUD or phone acceptance", "exposure":exposure,"room":"tournament","size":[1600,1000],"targetMaterials":mats.count,"rows":report],name:"cue-gloss-preview.json")
    }
