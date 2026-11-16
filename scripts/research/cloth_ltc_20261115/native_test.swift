    // H18 R6: generated fixture is research-only, installed on current production materials.
    func testNativeClothLTCR6() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("H18 R6 requires native Metal")
        #else
        guard ProcessInfo.processInfo.isiOSAppOnMac else { throw XCTSkip("H18 R6 authorized native Mac only") }
        let device=try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let candidate=try XCTUnwrap(String(data:XCTUnwrap(Data(base64Encoded:Self.h18R6Source)),encoding:.utf8))
        let scene=AngleTrainingScene(); scene.clothLTCRequested = false
        scene.configureDailyClearanceRendering(asynchronousReflection:false)
        scene.setupScene(recipe:.liveReference,roomStyle:.tournament)
        try require(scene.applyClothColor(.green) && scene.applyTableStyle(.charcoal),"H18 current appearance")
        scene.hideAllBalls()
        let size=CGSize(width:1400,height:800),camera=try XCTUnwrap(scene.cameraNode)
        scene.cameraRig?.viewportSize=size;scene.setCameraMode(.perspective3D,animated:false)
        @MainActor func setCamera(_ frame:Int=0)throws {
            let eye=SIMD3<Float>(0.16+Float(frame)*0.012,1.15+Float(frame)*0.003,0.3)
            let delta=eye-SIMD3<Float>(0,scene.surfaceY,0)
            let pose=TwoViewCamera.Pose.looking(eye:eye,yaw:atan2(delta.z,delta.x),pitch:-atan2(delta.y,hypot(delta.x,delta.z)),fov:50)
            camera.simdTransform=pose.transform;camera.camera?.fieldOfView=50
            try require(camera.camera?.usesOrthographicProjection==false && simd_dot(pose.forward,simd_normalize(-delta))>0.99999,"H18 real perspective camera")
            SCNTransaction.flush()
        }
        try setCamera()
        let keys=["cueBall"]+(1...15).map{"_\($0)"}
        let carrier=SCNNode();scene.rootNode.addChildNode(carrier)
        for key in keys {carrier.addChildNode(try XCTUnwrap(scene.allBallNodes[key]))}
        @MainActor func setBalls(_ state:Int) {
            SCNTransaction.begin();SCNTransaction.disableActions=true
            scene.hideAllBalls()
            let count=state>=8 ? 16:2
            for (i,key) in keys.prefix(count).enumerated() {
                let x:Float=count==16 ? Float(i/4)*0.6-0.9:Float(i)*0.075
                let z:Float=count==16 ? Float(i%4)*0.3-0.45:0
                scene.showBall(key:key,scenePosition:SCNVector3(x,scene.surfaceY+AngleSceneCalculator.ballRadius,z))
                if state==2 && i==0 {scene.allBallNodes[key]?.position.y += 0.06}
                if state==3 && i==0 {scene.allBallNodes[key]?.opacity=0.5}
                if state==4 && i==0 {scene.allBallNodes[key]?.isHidden=true}
                if state==5 {scene.allBallNodes[key]?.isHidden=true}
            }
            SCNTransaction.commit();SCNTransaction.flush()
        }
        setBalls(0)
        var cloth=[SCNMaterial](),solids=[SCNMaterial](),seen=Set<ObjectIdentifier>()
        scene.rootNode.enumerateChildNodes {node,_ in
            for m in node.geometry?.materials ?? [] where seen.insert(ObjectIdentifier(m)).inserted {
                if m.name=="TaiNi" {cloth.append(m)}
                if ["Wood","BlackWood","MG_Gold"].contains(m.name ?? "") {solids.append(m)}
            }
        }
        try require(!cloth.isEmpty && !solids.isEmpty && solids.allSatisfy{!$0.isDoubleSided && $0.cullMode == .back},"H18 current H15 baseline")
        let reference=try XCTUnwrap(cloth.first?.shaderModifiers?[.surface])
        let digest=SHA256.hash(data:Data(reference.utf8)).map{String(format:"%02x",$0)}.joined()
        try require(digest=="__BASELINE_SHA__" && cloth.allSatisfy{$0.shaderModifiers?[.surface]==reference},"H18 current C1/H9 exact source identity")
        var tables=[MTLTexture]()
        for (i,encoded) in [Self.h18R6Table0,Self.h18R6Table1].enumerated() {
            let bytes=try XCTUnwrap(Data(base64Encoded:encoded));try require(bytes.count==48*64*16,"H18 LUT size")
            let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:48,height:64,mipmapped:false)
            d.storageMode = .shared;d.usage = .shaderRead
            let table=try XCTUnwrap(device.makeTexture(descriptor:d))
            bytes.withUnsafeBytes{table.replace(region:MTLRegionMake2D(0,0,48,64),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:48*16)}
            tables.append(table);for m in cloth {m.setValue(SCNMaterialProperty(contents:table),forKey:"h18Table\(i)")}
        }
        let target=try RenderTarget(device:device,scene:scene,size:size)
        let probe=H17AnimationProbe(contact:scene.contactOcclusion);target.renderer.delegate=probe
        target.researchTime=1
        @MainActor func restart() {
            carrier.removeAllActions();carrier.simdPosition = .zero
            carrier.runAction(.customAction(duration:600) { node,elapsed in probe.actionStep(node,elapsed:Double(elapsed)) })
            SCNTransaction.flush()
        }
        @MainActor func install(_ source:String) {
            for m in cloth {var mods=m.shaderModifiers ?? [:];mods[.surface]=source;m.shaderModifiers=mods}
            SCNTransaction.flush()
        }
        @MainActor func uniforms()throws->Data {
            let value=try XCTUnwrap(cloth.first?.value(forKey:"contactUniforms") as? NSData)
            return Data(bytes:value.bytes,count:value.length)
        }
        try require(target.renderer.prepare(scene,shouldAbortBlock:nil),"H18 prepare current complete scene")
        restart();install(reference);_=try target.render(frames:12)
        let roughness=cloth.map{$0.roughness.intensity}
        var quality=[[String:Any]](),times=[[String:Any]](),completed=false
        defer {
            install(reference);carrier.removeAllActions()
            attachStrictReport(["study":"H18-R6-current-scene","completed":completed && testRun?.totalFailureCount==0,"device":device.name,
                "scope":"Current full 3D scene and real SCNAction; no SwiftUI page or phone energy claim","quality":quality,"times":times,
                "sourceSHA":digest,"lookupBytes":tables.reduce(0){$0+$1.allocatedSize},"policy":"2/4/8 are descriptive bins, not automatic visual acceptance"],name:"h18-r6-current-scene.json")
        }
        for state in 0..<16 {
            target.researchTime=1+Double(state)*0.07;setBalls(state)
            try setCamera(state>=6 ? state-6:0)
            for (i,m) in cloth.enumerated(){m.roughness.intensity=roughness[i]*(state>=12 ? 0.65:1)}
            SCNTransaction.flush()
            install(reference);_=try target.render(frames:3);let a=try target.readback(),aUniforms=try uniforms()
            _=try target.render(frames:1);let aa=try target.readback()
            install(candidate);_=try target.render(frames:2);_=probe.take()
            _=try target.render(frames:1);let b=try target.readback(),calls=probe.take()
            try require(calls["update"]==1 && calls["animations"]==1,"H18 one update per rendered frame")
            try require(aUniforms==uniforms(),"H18 reference/candidate same final animated ball state")
            install(reference);_=try target.render(frames:3);let restored=try target.readback()
            let delta=difference(a,b),noise=difference(a,aa),rest=difference(a,restored)
            try require(noise.maximum==0 && rest.maximum==0,"H18 AA/restoration")
            var bins=["1":0,"2":0,"4":0,"8":0],total=0
            for p in stride(from:0,to:a.bgra.count,by:4) {
                let d=(0..<3).map{abs(Int(a.bgra[p+$0])-Int(b.bgra[p+$0]))}.max()!
                for level in [1,2,4,8] where d>level {bins[String(level),default:0]+=1};total+=1
            }
            quality.append(["state":state,"maximum":delta.maximum,"changedPixels":delta.changedPixels,"pixels":total,"over":bins,"aaMaximum":noise.maximum,"restoreMaximum":rest.maximum,"callbacks":calls])
            attach(a,"h18-r6-\(state)-A");attach(b,"h18-r6-\(state)-B")
        }
        for (i,m) in cloth.enumerated(){m.roughness.intensity=roughness[i]}
        try setCamera();setBalls(0);restart()
        install(reference);_=try target.render(frames:3);let controlA=try target.readback()
        install(candidate+"\n_surface.emission.rgb=float3(2,0,0);\n");_=try target.render(frames:3)
        let controlB=try target.readback(),positive=difference(controlA,controlB)
        try require(positive.maximum>8 && positive.changedPixels>100,"H18 active candidate positive control")
        attach(controlB,"h18-r6-positive-control")
        var epoch:Double=20
        for cycle in 0..<6 {for kind in cycle%2==0 ? ["AA","AB"]:["AB","AA"] {
            for arm in cycle%2==0 ? [false,true,true,false]:[true,false,false,true] {
                epoch+=10;target.researchTime=epoch;setBalls(0);restart()
                install(kind=="AB" && arm ? candidate:reference)
                for f in 0..<24 {target.researchTime=epoch+Double(f)/60;_=try target.render(frames:1)}
                var samples=[[String:Any]]()
                for f in 0..<48 {
                    target.researchTime=epoch+Double(f+24)/60
                    samples += try target.render(frames:1,includeNativeTiming:true).perFrameTiming
                }
                times.append(["kind":kind,"cycle":cycle,"arm":arm ? "B":"A","frames":samples,"thermal":ProcessInfo.processInfo.thermalState.rawValue])
            }
        }}
        completed=true
        #endif
    }

    private static let h18R6Source = "__CANDIDATE_BASE64__"
    private static let h18R6Table0 = "__TABLE0_BASE64__"
    private static let h18R6Table1 = "__TABLE1_BASE64__"
