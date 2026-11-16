    func testNativeClothLTCR7b() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("R7 native production material verification")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else { throw XCTSkip("Native Mac scope") }
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        @MainActor func materials(_ scene: AngleTrainingScene) -> [SCNMaterial] {
            var result = [SCNMaterial](), seen = Set<ObjectIdentifier>()
            scene.rootNode.enumerateChildNodes { n,_ in for m in n.geometry?.materials ?? [] where m.name == "TaiNi" && seen.insert(ObjectIdentifier(m)).inserted { result.append(m) } }
            return result
        }
        let reference = AngleTrainingScene(); reference.clothLTCRequested = false
        reference.configureDailyClearanceRendering(asynchronousReflection: false)
        reference.setupScene(recipe: .liveReference, roomStyle: .tournament)
        let baseline = try XCTUnwrap(materials(reference).first?.shaderModifiers?[.surface])
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering(asynchronousReflection: false)
        scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
        try require(scene.clothLTCState == ClothSpecularLTC.identity, "R7b shared installation")
        let cloth = materials(scene), ltc = try XCTUnwrap(scene.clothSpecularLTC)
        let candidate = try XCTUnwrap(cloth.first?.shaderModifiers?[.surface])
        let identifiers = cloth.map(ObjectIdentifier.init)
        let target = try RenderTarget(device: device, scene: scene, size: CGSize(width: 700, height: 400))
        scene.cameraRig?.viewportSize = CGSize(width: 700, height: 400)
        scene.setCameraMode(.perspective3D, animated: false)
        let camera = try XCTUnwrap(scene.cameraNode)
        @MainActor func pose(height: Float = 0.35, pitch: Float = 45, yaw: Float = 1.08) {
            let angle = pitch * .pi / 180, radius = height / tan(angle)
            let eye = SIMD3<Float>(radius*cos(yaw), scene.surfaceY+height, radius*sin(yaw))
            camera.simdTransform = TwoViewCamera.Pose.looking(eye: eye, yaw: yaw, pitch: -angle, fov: 50).transform
            camera.camera?.fieldOfView = 50; camera.camera?.usesOrthographicProjection = false
            SCNTransaction.flush()
        }
        @MainActor func balls(_ offset: Float) {
            scene.hideAllBalls()
            for (i,key) in ["cueBall","_1"].enumerated() {
                scene.showBall(key: key, scenePosition: SCNVector3(offset+Float(i)*0.075, scene.surfaceY+AngleSceneCalculator.ballRadius, 0))
            }
            SCNTransaction.flush()
        }
        @MainActor func install(_ source: String) {
            for m in cloth {var mods=m.shaderModifiers ?? [:];mods[.surface]=source;m.shaderModifiers=mods}
            SCNTransaction.flush()
        }
        var rows = [[String: Any]](), completed = false, previous = [Int16]()
        defer {
            install(candidate)
            attachStrictReport(["study":"H18-R7b","completed":completed && testRun?.totalFailureCount == 0,
                "rows":rows,"scope":"Native current-scene pixels, continuous sampled parameter paths; not phone visual acceptance"], name:"h18-r7b.json")
        }
        @MainActor func compare(_ name: String, save: Bool, probe: Bool = false) throws {
            install(baseline); _=try target.render(frames:3); let a=try target.readback()
            let ballState=cloth.first!.value(forKey:"contactUniforms") as! NSData
            let before=Data(bytes:ballState.bytes,count:ballState.length)
            _=try target.render(frames:1); let aa=try target.readback()
            install(candidate); _=try target.render(frames:3); let b=try target.readback()
            let after=cloth.first!.value(forKey:"contactUniforms") as! NSData
            try require(before == Data(bytes:after.bytes,count:after.length),"Same current ball uniforms")
            install(baseline); _=try target.render(frames:3); let restored=try target.readback()
            try require(difference(a,aa).maximum == 0 && difference(a,restored).maximum == 0,"R7b AA/restore")
            let diff=difference(a,b)
            var bins=["1":0,"2":0,"4":0,"8":0], signed=[Int16](), temporal=0
            signed.reserveCapacity(a.bgra.count/4*3)
            for p in stride(from:0,to:a.bgra.count,by:4) {
                var maximum=0
                for c in 0..<3 {
                    let d=Int16(b.bgra[p+c])-Int16(a.bgra[p+c]); maximum=max(maximum,abs(Int(d))); signed.append(d)
                }
                for level in [1,2,4,8] where maximum>level {bins[String(level),default:0]+=1}
            }
            if previous.count == signed.count {for i in signed.indices {temporal=max(temporal,abs(Int(signed[i]-previous[i])))}}
            previous=signed
            var row:[String:Any]=["case":name,"maximum":diff.maximum,"changedPixels":diff.changedPixels,"over":bins,"errorChange":temporal]
            if probe {
                let diagnostic=candidate+"\n_surface.diffuse=float4(0,0,0,1);_surface.emission.rgb=(clothLTCCloseView && _surface.roughness>=0.4 && shadowPossible)?float3(1,0,0):float3(0);\n"
                install(diagnostic);_=try target.render(frames:3);let frame=try target.readback()
                row["eligibleRedPixels"]=stride(from:0,to:frame.bgra.count,by:4).filter{frame.bgra[$0+2]>120 && frame.bgra[$0+1]<80 && frame.bgra[$0]<80}.count
            }
            if save {attach(a,"h18-r7b-\(name)-A");attach(b,"h18-r7b-\(name)-B")}
            install(candidate)
            try require(materials(scene).map(ObjectIdentifier.init)==identifiers && scene.clothSpecularLTC === ltc,"Stable material/LUT ownership")
            rows.append(row)
        }
        pose(); balls(0)
        for color in ClothColor.allCases {for style in TableStyle.allCases {
            try require(scene.applyClothColor(color) && scene.applyTableStyle(style),"All appearance variants")
            try compare("\(color.rawValue)-\(style.rawValue)", save:style == .charcoal)
        }}
        try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal),"Restore appearance")
        let roughness=cloth.map{$0.roughness.contents}
        previous=[]
        for frame in 0..<120 {
            let segment=frame/24,t=Float(frame%24)/23
            for (i,m) in cloth.enumerated(){m.roughness.contents=roughness[i]}
            switch segment {
            case 0:pose(pitch:28+4*t)
            case 1:pose(pitch:63+4*t)
            case 2:pose(height:0.48+0.04*t)
            case 3:
                pose(); for m in cloth {m.roughness.contents=NSNumber(value:0.36+0.08*t)}
            default:pose(height:0.49,pitch:32-3*t)
            }
            balls(-0.25+0.5*t)
            try compare("motion-\(frame)",save:true,probe:true)
        }
        for (i,m) in cloth.enumerated(){m.roughness.contents=roughness[i]}
        // Orthographic renderer shares the exact material objects; no per-camera program rewrite.
        scene.setCameraMode(.topDown2D,animated:false);SCNTransaction.flush()
        try compare("topdown-return",save:true,probe:true)
        // A local asset path exercises weak cache ownership independently of the scene-held resource.
        let temporary=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at:try XCTUnwrap(Bundle.main.url(forResource:ClothSpecularLTC.assetName,withExtension:"bin")),to:temporary)
        weak var released:ClothSpecularLTC?
        do {
            let value=try ClothSpecularLTC.acquire(emitter:MobileReferenceLighting.emitterGeometry,radiance:StaticClothIrradiance.expectedRadiance,device:device,assetURL:temporary)
            released=value
        }
        try require(released == nil,"Weak device cache releases unused wrapper")
        try FileManager.default.removeItem(at:temporary)
        completed=true
        #endif
    }
