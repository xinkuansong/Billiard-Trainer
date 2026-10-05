// V023 six native overhead photo cards. World XZ in metres, Y up; screen up +X/right +Z.
import UIKit
final class CueScratchTopdownCardsTests: XCTestCase {
    @MainActor
    func testExportCards() async throws {
        guard let path=ProcessInfo.processInfo.environment["SCRATCH_SELECTION_VIDEO_DIR"] else { throw XCTSkip("Opt-in V023 cards") }
        let out=URL(fileURLWithPath:path)
        let cases=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:out.appendingPathComponent("cases.json"))) as? [[String:Any]])
        let size=CGSize(width:1440,height:1920),sceneSize=CGSize(width:1440,height:1600)
        let y=BTTablePhysics.surfaceY,ballY=y+BallPhysics.radius,targetLineColor=UIColor.black
        let scene=AngleTrainingScene()
        scene.setupScene(enhancedRendering:false,mobileRendering:true)
        XCTAssertTrue(scene.applyTableStyle(.charcoal,showsSights:true));XCTAssertTrue(scene.applyClothColor(.green))
        scene.setCameraMode(.perspective3D,animated:false)
        XCTAssertTrue(scene.cueStick?.applyStyle(.inkDragon) == true)
        scene.setupVisualizationNodes();scene.hideAllVisualization()
        let camera=try XCTUnwrap(scene.cameraNode)
        camera.camera?.usesOrthographicProjection=true
        camera.camera?.projectionDirection = .vertical
        camera.camera?.wantsExposureAdaptation=false
        let renderer=SCNRenderer(device:nil,options:nil)
        renderer.scene=scene;renderer.pointOfView=camera;renderer.delegate=scene.contactOcclusion
        renderer.autoenablesDefaultLighting=false
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let compositor=UIGraphicsImageRenderer(size:size,format:format)
        var records:[[String:Any]]=[]
        for (caseIndex,saved) in cases.enumerated() {
            let id=saved["galleryID"] as! String
            func values(_ key:String) -> [Float] { (saved[key] as! [NSNumber]).map{$0.floatValue} }
            let c=values("cue"),o=values("object"),expectedAim=values("aim")
            let cue=SCNVector3(c[0],ballY,c[1]),object=SCNVector3(o[0],ballY,o[1])
            let speed=(saved["speed"] as! NSNumber).floatValue,offset=(saved["offset"] as! NSNumber).floatValue
            let targetPocket=(saved["pocket"] as! NSNumber).intValue
            let scratchPocket=Int((saved["cuePocket"] as! String).split(separator:"_").last!)!
            let recommendationCut=(saved["cut"] as! NSNumber).doubleValue
            let input=ShotInput(cueBall:cue,targetBall:object,pocketIndex:targetPocket,velocity:speed,spinX:0,spinY:0,surfaceY:y)
            let prediction=ShotPredictor.predictForPositionSolve(input,aimOffset:offset,maxEvents:1000,maxTime:30,includePresentation:true)
            XCTAssertTrue(prediction.cuePocketed && prediction.objectPocketed,id)
            XCTAssertEqual(prediction.aimDirection.x,expectedAim[0],accuracy:0.000001)
            XCTAssertEqual(prediction.aimDirection.z,expectedAim[1],accuracy:0.000001)
            let oldEvents=saved["events"] as! [[String:Any]]
            XCTAssertEqual(prediction.events.count,oldEvents.count)
            var events:[[String:Any]]=[]
            for (event,old) in zip(prediction.events,oldEvents) {
                XCTAssertEqual(event.time,(old["t"] as! NSNumber).floatValue,accuracy:0.002)
                switch event.kind {
                case .ballBall: events.append(["kind":"contact","time":event.time])
                case .ballCushion: XCTFail("Unexpected cushion in \(id)")
                case .pocket(let ball,let pocket):
                    XCTAssertEqual(pocket,ball == ShotInput.cueBallName ? "pocket_\(scratchPocket)" : "pocket_\(targetPocket)")
                    events.append(["kind":"pocket","ball":ball,"pocket":pocket,"time":event.time])
                }
            }
            let recorder=try XCTUnwrap(prediction.recorder), contact=try XCTUnwrap(prediction.firstContact)
            XCTAssertEqual(hypotf(contact.x-object.x,contact.z-object.z),2*BallPhysics.radius,accuracy:0.0001)
            let pockets=AngleSceneCalculator.pocketPositions(surfaceY:y)
            let recommended=try XCTUnwrap(AngleSceneCalculator.dailyPocketCandidate(cue:cue,target:object,targetKey:"object",pocketIndex:targetPocket,obstacles:[],surfaceY:y))
            XCTAssertEqual(recommended.cutDegrees,recommendationCut,accuracy:0.01)
            // Actual collision cut uses incoming direction and contact normal, not a nominal pocket-centre line.
            let normal=(object-contact).normalized(), incoming=prediction.aimDirection.normalized()
            let cut=Double(acosf(max(-1,min(1,incoming.dot(normal)))) * 180 / .pi)
            XCTAssertGreaterThan(cut,0);XCTAssertLessThan(cut,90)
            let playback=TrajectoryPlayback(recorder:recorder,surfaceY:ballY)
            scene.hideAllBalls(); scene.hideCueStick(); scene.hideAllVisualization()
            scene.setCueBallHomeOrientation(BallSpinIntegrator.identityOrientation)
            scene.showBall(key:PositionPlayBall.cueKey,scenePosition:cue); scene.showBall(key:"_8",scenePosition:object)
            XCTAssertNotNil(scene.allBallNodes["_8"])
            XCTAssertFalse(scene.allBallNodes["_8"]!.isHidden)
            XCTAssertTrue(scene.allBallNodes["_1"]!.isHidden)
            var guides:[SCNNode]=[]
            func pathFor(_ name:String) -> [SCNVector3] {
                let entry=recorder.pocketEntries.first{$0.ball.name==name}!
                var pts=(recorder.framesByBallName[name] ?? []).filter{$0.time <= entry.time && $0.state != .pocketed}.sorted{$0.time<$1.time}.map{$0.position}
                pts.append(entry.ball.position); return pts
            }
            let cuePath=pathFor(ShotInput.cueBallName),objectPath=pathFor(ShotInput.targetBallName)
            scene.addCueTrajectory(cuePath,contact:contact,into:&guides)
            scene.addDashedPolyline(objectPath,color:targetLineColor,radius:0.0022,dash:0.028,gap:0.016,placement:.table,into:&guides)

            let ghostNodes=makeGhost(at:contact,clothY:y,scene:scene)
            let aim=prediction.aimDirection,strike=CueStroke.strikePosition(cue:cue,aim:aim,spinX:0,spinY:0)
            let obstacles=scene.cueObstacleCenters(excludingStrikeNear:strike)
            guard case .angle(let elevation)=CueStick.requiredElevation(cueBallPosition:strike,aimDirection:aim,obstacleCenters:obstacles) else { XCTFail("No cue pose");return }
            scene.updateCueStick(cueBallPosition:strike,aimDirection:aim,pullBack:CueStroke.pullBack(at:0,velocity:speed),elevationOverride:elevation)
            let stick=try XCTUnwrap(scene.cueStick?.rootNode)
            XCTAssertFalse(stick.isHidden)
            let bb=stick.boundingBox
            var bounds=[SCNVector3(-1.51,y,-0.87),SCNVector3(1.51,y,0.87)]
            for x in [bb.min.x,bb.max.x] { for yy in [bb.min.y,bb.max.y] { for z in [bb.min.z,bb.max.z] {
                bounds.append(stick.convertPosition(SCNVector3(x,yy,z),to:nil))
            }}}
            let minX=bounds.map{$0.x}.min()!,maxX=bounds.map{$0.x}.max()!
            let minZ=bounds.map{$0.z}.min()!,maxZ=bounds.map{$0.z}.max()!
            let cx=(minX+maxX)/2,cz=(minZ+maxZ)/2,aspect=Float(sceneSize.width/sceneSize.height)
            let scale=max((maxX-minX)/2,(maxZ-minZ)/2/aspect)+0.12
            camera.position=SCNVector3(cx,y+5,cz)
            camera.look(at:SCNVector3(cx,y,cz),up:SCNVector3(1,0,0),localFront:SCNVector3(0,0,-1))
            camera.camera?.orthographicScale=Double(scale)
            for p in bounds+cuePath+objectPath+[contact] {
                XCTAssertLessThan(abs(p.x-cx),scale)
                XCTAssertLessThan(abs(p.z-cz),scale*aspect)
            }
            SCNTransaction.flush()
            for _ in 0..<3 { _=renderer.snapshot(atTime:0,with:sceneSize,antialiasingMode:.multisampling4X) }
            let raw=renderer.snapshot(atTime:0,with:sceneSize,antialiasingMode:.multisampling4X)
            try XCTUnwrap(raw.pngData()).write(to:out.appendingPathComponent("\(id)-scene.png"))
            let image=compositor.image { ctx in
                let cg=ctx.cgContext
                UIColor(red:0.95,green:0.96,blue:0.94,alpha:1).setFill();ctx.fill(CGRect(origin:.zero,size:size))
                raw.draw(in:CGRect(x:0,y:150,width:1440,height:1600))
                func text(_ value:String,_ x:CGFloat,_ yy:CGFloat,_ font:CGFloat,_ color:UIColor = .black) {
                    (value as NSString).draw(at:CGPoint(x:x,y:yy),withAttributes:[.font:UIFont.systemFont(ofSize:font,weight:.semibold),.foregroundColor:color])
                }
                UIColor(red:1,green:0.88,blue:0.08,alpha:1).setFill()
                UIBezierPath(roundedRect:CGRect(x:44,y:32,width:245,height:87),cornerRadius:18).fill()
                text("球形"+["一","二","三","四","五","六"][caseIndex],67,43,53)
                text("母球掉袋：不吃库",335,43,53)
                text(String(format:"切角  %.1f°",cut),52,1801,42)
                text(String(format:"杆速  %.2f m/s",speed),450,1801,42)
                text("中杆 · 无塞",1110,1807,34)
                let disc=CGRect(x:978,y:1777,width:115,height:115)
                cg.setFillColor(UIColor.white.cgColor);cg.fillEllipse(in:disc)
                cg.setStrokeColor(UIColor.red.cgColor);cg.setLineWidth(2)
                cg.move(to:CGPoint(x:disc.midX,y:disc.minY));cg.addLine(to:CGPoint(x:disc.midX,y:disc.maxY))
                cg.move(to:CGPoint(x:disc.minX,y:disc.midY));cg.addLine(to:CGPoint(x:disc.maxX,y:disc.midY));cg.strokePath()
                cg.setFillColor(UIColor.red.cgColor);cg.fillEllipse(in:CGRect(x:disc.midX-8,y:disc.midY-8,width:16,height:16))
            }
            try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent("\(id).png"))
            records.append(["id":id,"cutDegrees":cut,"speed":speed,"cueXYZ":[cue.x,cue.y,cue.z],"objectXYZ":[object.x,object.y,object.z],"ghostXYZ":[contact.x,contact.y,contact.z],"aimXZ":[aim.x,aim.z],"cameraXYZ":[camera.position.x,camera.position.y,camera.position.z],"orthographicScale":scale,"cueElevationDegrees":elevation*180 / .pi,"cuePath":cuePath.map{[$0.x,$0.y,$0.z]},"objectPath":objectPath.map{[$0.x,$0.y,$0.z]},"events":events,"cueVisible":!stick.isHidden,"guidesCount":guides.count,"spin":[0,0]])
            for n in guides+ghostNodes { n.removeFromParentNode() }
        }
        let manifest:[String:Any]=["version":"topdown-r1","width":1440,"height":1920,"screenUp":"+X","screenRight":"+Z","projection":"orthographic","cases":records]
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("manifest.json"))
    }

    @MainActor
    private func makeGhost(at position:SCNVector3,clothY:Float,scene:AngleTrainingScene) -> [SCNNode] {
        // Video-only frosted ghost: stable world-space illustrative lighting.
        let radius = BallPhysics.radius
        let ghost = SCNNode()
        scene.rootNode.addChildNode(ghost)
        ghost.position = position
        ghost.isHidden = false
        ghost.childNodes.forEach { $0.isHidden = true }
        let sphere = SCNSphere(radius:CGFloat(radius))
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.white
        material.blendMode = .alpha
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        material.shaderModifiers = [.fragment: """
        #pragma transparent
        #pragma body
        float3 N = normalize((scn_frame.inverseViewTransform * float4(_surface.normal, 0.0)).xyz);
        float3 V = normalize((scn_frame.inverseViewTransform * float4(-_surface.position, 0.0)).xyz);
        float3 L = normalize(float3(-0.55, 0.80, -0.35));
        float diffuse = max(dot(N, L), 0.0);
        float highlight = pow(max(dot(N, normalize(L + V)), 0.0), 28.0);
        float rim = pow(1.0 - abs(dot(N, V)), 3.0);
        float shade = 0.20 + 0.67 * diffuse;
        float3 color = float3(0.90, 0.96, 1.0) * shade + float3(0.6) * highlight;
        float alpha = clamp(0.43 + 0.18 * rim + 0.24 * highlight, 0.0, 0.85);
        _output.color = float4(min(color, float3(1.0)) * alpha, alpha);
        """]
        sphere.materials = [material]
        let shell = SCNNode(geometry:sphere)
        shell.castsShadow = false
        ghost.addChildNode(shell)
        // Soft cloth contact cue, confined to this preview's ghost footprint.
        let contact = SCNPlane(width:CGFloat(radius*2.0),height:CGFloat(radius*2.0))
        let shadowMaterial = SCNMaterial()
        shadowMaterial.lightingModel = .constant
        shadowMaterial.diffuse.contents = UIColor.black
        shadowMaterial.writesToDepthBuffer = false
        shadowMaterial.blendMode = .alpha
        let shadowFormat = UIGraphicsImageRendererFormat()
        shadowFormat.scale = 1
        shadowFormat.opaque = false
        let shadowImage = UIGraphicsImageRenderer(size:CGSize(width:256,height:256),format:shadowFormat).image { renderer in
            let colors = [UIColor.black.withAlphaComponent(0.58).cgColor,
                          UIColor.black.withAlphaComponent(0.30).cgColor,
                          UIColor.clear.cgColor] as CFArray
            let gradient = CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,0.38,1])!
            renderer.cgContext.drawRadialGradient(gradient,startCenter:CGPoint(x:128,y:128),startRadius:0,
                                                  endCenter:CGPoint(x:128,y:128),endRadius:128,options:[])
        }
        shadowMaterial.diffuse.contents = shadowImage
        contact.materials = [shadowMaterial]
        let contactNode = SCNNode(geometry:contact)
        contactNode.eulerAngles.x = -.pi/2
        contactNode.position = SCNVector3(position.x,clothY+0.0002,position.z)
        scene.rootNode.addChildNode(contactNode)
        // Video-only footprint: a true cloth-plane ring, projected in both views.
        let footprint = SCNTorus(ringRadius:CGFloat(radius),pipeRadius:0.0008)
        footprint.ringSegmentCount = 128
        footprint.pipeSegmentCount = 8
        let footprintMaterial = SCNMaterial()
        footprintMaterial.lightingModel = .constant
        footprintMaterial.diffuse.contents = UIColor(red:0.88,green:1.0,blue:0.94,alpha:0.92)
        footprintMaterial.writesToDepthBuffer = false
        footprintMaterial.shaderModifiers = [.fragment: """
        #pragma body
        float3 world = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
        float angle = atan2(world.z - \(position.z), world.x - \(position.x));
        float dash = fract((angle / 6.28318530718 + 0.5) * 16.0);
        if (dash > 0.60) { discard_fragment(); }
        """]

        footprint.materials = [footprintMaterial]
        let footprintNode = SCNNode(geometry:footprint)
        footprintNode.name = "videoGhostFootprintRing"
        footprintNode.position = SCNVector3(position.x,clothY+0.001,position.z)
        footprintNode.castsShadow = false
        scene.rootNode.addChildNode(footprintNode)


        return [ghost,contactNode,footprintNode]
    }
}
