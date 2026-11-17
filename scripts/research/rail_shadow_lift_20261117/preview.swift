    func testRailShadowLiftPreview() throws {
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
        scene.tableNode?.enumerateChildNodes { n,_ in collect(n, clothOnly: true) }
        try require(!mats.isEmpty, "Cloth materials found")
        let originals = mats.map { $0.shaderModifiers ?? [:] }
        let target = try RenderTarget(device: device, scene: scene, size: size)
        let camera = try XCTUnwrap(scene.cameraNode)
        let exposure = camera.camera!.exposureOffset
        // Keep the original dark cushion face; only the existing rounded nose
        // receives a weak diffuse transition. No whole-side lift or bed bounce.
        let lip = """
        if(p.y>0.8005) {
            float3 railG=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz);
            float railLip=smoothstep(-0.30,-0.05,railG.y)*(1.0-smoothstep(0.30,0.70,railG.y));
            float3 railSoftNormal=normalize(n+float3(0,0.18,0));
            float3 railSoftE=max(v62PanelDiffuse(p,railSoftNormal)-v62PanelDiffuse(p,n),float3(0.0));
            _surface.emission.rgb+=(_surface.diffuse.rgb*_surface.multiply.rgb)*railSoftE*(0.25/3.14159265)*railLip;
        }
        """
        // Local shadow tone adjustment, not a change to light power or exposure.
        // Preserve the bed, bright cushion top, and the bottom contact strip.
        let shadowLift = """
        if(p.y>0.8005) {
            float3 railG=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz);
            float railSide=1.0-smoothstep(-0.15,0.35,railG.y);
            float railFoot=smoothstep(0.802,0.814,p.y);
            float3 railIncident=E/3.14159265+0.26*_surface.ambientOcclusion;
            float railPeak=max(railIncident.r,max(railIncident.g,railIncident.b));
            float railDark=1.0-smoothstep(0.30,0.65,railPeak);
            _surface.emission.rgb*=1.0+0.16*railSide*railFoot*railDark;
        }
        """
        func install(_ mode: String) throws {
            for (i,m) in mats.enumerated() {
                var mods = originals[i]
                let original = try XCTUnwrap(mods[.surface])
                if ["finesse","lift"].contains(mode) {
                    let geo=mods[.geometry] ?? "#pragma body"
                    mods[.geometry]=geo+"\nfloat4 railUVWorld=scn_node.modelTransform*_geometry.position; if(railUVWorld.y>0.8005) _geometry.texcoords[0]*=1.5;"
                    if ["finesse","lift"].contains(mode) {
                        let anchor="_surface.diffuse.rgb=float3(0.0);"
                        try require(original.components(separatedBy:anchor).count==2,"Unique cloth output anchor")
                        mods[.surface]=original.replacingOccurrences(of:anchor,with:lip+"\n"+(mode == "lift" ? shadowLift : "")+"\n"+anchor)
                    }
                } else if mode == "normal" {
                    mods[.fragment]="#pragma body\nfloat3 diagnosticNormal=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz); _output.color=float4(diagnosticNormal*0.5+0.5,1.0);"
                } else if mode == "mask" {
                    mods[.surface]=original.replacingOccurrences(of:"_surface.diffuse.rgb=float3(0.0);",with:"if(p.y>0.8005) _surface.emission.rgb=float3(2.0,0.0,2.0);\n_surface.diffuse.rgb=float3(0.0);")
                } else if mode == "wholeClothMask" {
                    mods[.fragment]="#pragma body\n_output.color=float4(1.0,0.0,1.0,1.0);"
                }
                m.shaderModifiers=mods
            }
            SCNTransaction.flush()
        }
        var report = [[String: Any]]()
        for view in ["low", "oblique", "detail", "top"] {
            try install("original")
            if view == "top" { scene.setCameraMode(.topDown2D, animated: false) }
            else if view == "detail" {
                scene.setCameraMode(.perspective3D, animated:false)
                let aim=SIMD3<Float>(0.6,0.823,-0.635)
                let eye=SIMD3<Float>(0.6,1.03,-0.18)
                let delta=eye-aim
                let pose=TwoViewCamera.Pose.looking(eye:eye,yaw:.pi/2,pitch:-atan2(delta.y,delta.z),fov:45)
                camera.simdTransform=pose.transform
                camera.camera!.fieldOfView=45
                camera.camera!.usesOrthographicProjection=false
                try require(simd_length(pose.forward-simd_normalize(aim-eye))<0.00001,"Detail camera aims at actual long cushion")
            }
            else {
                scene.setCameraMode(.perspective3D, animated: false)
                let height: Float = view == "low" ? 0.20 : 0.45
                let radius: Float = 1.50
                let yaw: Float = view == "low" ? .pi/2 : .pi/4
                let eye = SIMD3<Float>(cos(yaw)*radius, scene.surfaceY+height, sin(yaw)*radius)
                let pose = TwoViewCamera.Pose.looking(eye: eye, yaw: yaw, pitch: -atan2(height,radius), fov: 50)
                camera.simdTransform = pose.transform
                camera.camera!.fieldOfView = 50
                camera.camera!.usesOrthographicProjection = false
                try require(simd_length(pose.forward - simd_normalize(SIMD3<Float>(0,scene.surfaceY,0)-eye)) < 0.00001, "Camera aims at cloth centre")
            }
            SCNTransaction.flush()
            _ = try target.render(frames: 8)
            let baseline = try target.readback()
            attach(baseline, "rail-shadow-lift-\(view)-A-original")
            try install("mask"); _ = try target.render(frames: 4)
            let mask = try target.readback()
            attach(mask,"rail-shadow-lift-\(view)-diagnostic-surfaceMask")
            var targetPixels = Set<Int>()
            for p in stride(from: 0, to: baseline.bgra.count, by: 4) {
                if (0..<3).contains(where: { baseline.bgra[p+$0] != mask.bgra[p+$0] }) { targetPixels.insert(p) }
            }
            try install("wholeClothMask"); _=try target.render(frames:4)
            let wholeMask=try target.readback()
            var wholePixels=Set<Int>()
            for p in stride(from:0,to:baseline.bgra.count,by:4) {
                if (0..<3).contains(where:{baseline.bgra[p+$0] != wholeMask.bgra[p+$0]}) {wholePixels.insert(p)}
            }
            for (name,mode) in [("B-finesse","finesse"),("C-shadowLift","lift")] {
                try install(mode); _ = try target.render(frames: 5)
                let frame = try target.readback()
                attach(frame, "rail-shadow-lift-\(view)-\(name)")
                let delta = difference(baseline,frame)
                var outside = 0
                for p in stride(from:0,to:frame.bgra.count,by:4) where !targetPixels.contains(p) {
                    if (0..<3).contains(where:{baseline.bgra[p+$0] != frame.bgra[p+$0]}) {outside += 1}
                }
                try require(frame.magentaPixels == 0, "Valid local shadow tone output")
                var outsideCloth=0
                for p in stride(from:0,to:frame.bgra.count,by:4) where !wholePixels.contains(p) {
                    if (0..<3).contains(where:{baseline.bgra[p+$0] != frame.bgra[p+$0]}) {outsideCloth+=1}
                }
                try require(outsideCloth==0,"Non-cloth material pixels unchanged")
                try require(camera.camera!.exposureOffset == exposure, "Exposure unchanged")
                report.append(["view":view,"variant":name,"mode":mode,"changedPixels":delta.changedPixels,"maximumChannelDelta":delta.maximum,"outsideClothChangedPixels":outsideCloth,"outsideRailChangedPixels":outside])
            }
            if view == "oblique" {
                for mode in ["normal"] {
                    try install(mode); _ = try target.render(frames:5)
                    attach(try target.readback(),"rail-shadow-lift-\(view)-diagnostic-\(mode)")
                }
            }
            try install("original"); _ = try target.render(frames: 5)
            try require(difference(baseline,try target.readback()).maximum == 0,"Exact original restoration")
        }
        attachStrictReport(["scope":"Current production SceneKit on native Mac; no SwiftUI HUD or phone acceptance", "exposure":exposure,"room":"tournament","size":[1600,1000],"targetMaterials":mats.count,"rows":report],name:"rail-shadow-lift-preview.json")

    }
