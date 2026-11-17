    func testRailShapePreview() throws {
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
        let helper = """
        // One diffuse bounce from the finite cloth bed. The rectangle excludes the
        // rail tops; pocket cut-outs and further bounces are not represented here.
        float railBedFormFactor(float3 p, float3 n) {
            float3 corners[4]={float3(-1.27,0.8,-0.635)-p,float3(-1.27,0.8,0.635)-p,
                               float3(1.27,0.8,0.635)-p,float3(1.27,0.8,-0.635)-p};
            float3 clipped[8];int count=0;
            for(int i=0;i<4;++i){
                float3 a=corners[i],b=corners[(i+1)%4];float da=dot(a,n),db=dot(b,n);
                if(da>=0.0)clipped[count++]=a;
                if((da>=0.0)!=(db>=0.0))clipped[count++]=a+(b-a)*(da/(da-db));
            }
            if(count<3)return 0.0;
            float integral=0.0;
            for(int i=0;i<count;++i){
                float3 a=normalize(clipped[i]),b=normalize(clipped[(i+1)%count]);
                float3 c=cross(a,b);float len=length(c);
                if(len>1e-7)integral+=atan2(len,dot(a,b))*dot(c,n)/len;
            }
            return clamp(abs(integral)/(2.0*3.14159265),0.0,1.0);
        }
        """
        let bounce = """
        // railClothBouncePreview: unoccluded finite-bed single bounce.
        if (p.y > 0.8005) {
            float3 railAlbedo=_surface.diffuse.rgb*_surface.multiply.rgb;
            float3 railBedPoint=float3(clamp(p.x,-1.27,1.27),0.8,clamp(p.z,-0.635,0.635));
            float3 railBedRadiance=railAlbedo*(v62PanelDiffuse(railBedPoint,float3(0,1,0))/3.14159265+0.26);
            _surface.emission.rgb += railAlbedo*railBedRadiance*railBedFormFactor(p,n);
        }
        """
        // Art-directed diffuse fill only: retain geometric/specular normals.
        // Smooth world-height weighting avoids a new constant-colour side strip.
        func wrapFill(_ lift: String) -> String {
            """
            if (p.y > 0.8005) {
                float railSide=1.0-smoothstep(0.20,0.85,n.y);
                float railHeight=smoothstep(0.801,0.836,p.y);
                float railFoot=smoothstep(0.8005,0.804,p.y);
                float3 railFillNormal=normalize(n+float3(0,\(lift),0));
                float3 railFill=max(v62PanelDiffuse(p,railFillNormal)-v62PanelDiffuse(p,n),float3(0.0))/3.14159265;
                _surface.emission.rgb+=(_surface.diffuse.rgb*_surface.multiply.rgb)*railFill*railSide*railFoot*(0.40+0.60*railHeight);
            }
            """
        }
        func install(_ mode: String) throws {
            for (i,m) in mats.enumerated() {
                var mods = originals[i]
                let original = try XCTUnwrap(mods[.surface])
                if ["bounce","soft","softPlus"].contains(mode) {
                    let anchor="_surface.diffuse.rgb=float3(0.0);"
                    try require(original.components(separatedBy: anchor).count == 2, "Unique cloth output anchor")
                    mods[.surface]=original.replacingOccurrences(of: "#pragma body",with: helper+"\n#pragma body")
                        .replacingOccurrences(of: anchor,with:bounce+"\n"+(mode == "bounce" ? "" : wrapFill(mode == "soft" ? "0.75" : "1.10"))+"\n"+anchor)
                } else if mode == "noAO" {
                    mods[.surface]=original.replacingOccurrences(of:"_surface.ambientOcclusion *= bakedRailAO.sample(railSampler, railUV).r;",with:"// diagnostic: rail AO disabled")
                } else if mode == "normal" {
                    mods[.fragment]="#pragma body\nfloat3 diagnosticNormal=normalize((scn_frame.inverseViewTransform*float4(_surface.geometryNormal,0.0)).xyz); _output.color=float4(diagnosticNormal*0.5+0.5,1.0);"
                } else if mode == "mask" {
                    mods[.surface]=original.replacingOccurrences(of:"_surface.diffuse.rgb=float3(0.0);",with:"if(p.y>0.8005) _surface.emission.rgb=float3(2.0,0.0,2.0);\n_surface.diffuse.rgb=float3(0.0);")
                } else if mode == "maskFragment" {
                    mods[.fragment]=(originals[i][.fragment] ?? "#pragma body")+"\nfloat3 maskWorld=(scn_frame.inverseViewTransform*float4(_surface.position,1.0)).xyz; if(maskWorld.y>0.8005) _output.color=float4(1.0,0.0,1.0,1.0);"
                }
                m.shaderModifiers=mods
            }
            SCNTransaction.flush()
        }
        var report = [[String: Any]]()
        for view in ["low", "oblique", "top"] {
            try install("original")
            if view == "top" { scene.setCameraMode(.topDown2D, animated: false) }
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
            attach(baseline, "rail-shape-\(view)-A-original")
            try install("mask"); _ = try target.render(frames: 4)
            let mask = try target.readback()
            attach(mask,"rail-shape-\(view)-diagnostic-surfaceMask")
            var targetPixels = Set<Int>()
            for p in stride(from: 0, to: baseline.bgra.count, by: 4) {
                if (0..<3).contains(where: { baseline.bgra[p+$0] != mask.bgra[p+$0] }) { targetPixels.insert(p) }
            }
            for (name,mode) in [("B-bounce","bounce"),("C-soft","soft"),("D-softPlus","softPlus")] {
                try install(mode); _ = try target.render(frames: 5)
                let frame = try target.readback()
                attach(frame, "rail-shape-\(view)-\(name)")
                let delta = difference(baseline,frame)
                var outside = 0
                for p in stride(from:0,to:frame.bgra.count,by:4) where !targetPixels.contains(p) {
                    if (0..<3).contains(where:{baseline.bgra[p+$0] != frame.bgra[p+$0]}) {outside += 1}
                }
                try require(frame.magentaPixels == 0, "Valid rail bounce output")
                // Assert after reporting every view so failures retain all diagnostics.
                try require(camera.camera!.exposureOffset == exposure, "Exposure unchanged")
                report.append(["view":view,"variant":name,"mode":mode,"changedPixels":delta.changedPixels,"maximumChannelDelta":delta.maximum,"outsideTargetChangedPixels":outside])
            }
            if view == "oblique" {
                for mode in ["normal","maskFragment"] {
                    try install(mode); _ = try target.render(frames:5)
                    attach(try target.readback(),"rail-shape-\(view)-diagnostic-\(mode)")
                }
            }
            try install("original"); _ = try target.render(frames: 5)
            try require(difference(baseline,try target.readback()).maximum == 0,"Exact original restoration")
        }
        attachStrictReport(["scope":"Current production SceneKit on native Mac; no SwiftUI HUD or phone acceptance", "exposure":exposure,"room":"tournament","size":[1600,1000],"targetMaterials":mats.count,"rows":report],name:"rail-shape-preview.json")
        try require(report.allSatisfy { ($0["outsideTargetChangedPixels"] as? Int) == 0 },"All views: bed, balls, room and non-rail pixels unchanged")
    }
