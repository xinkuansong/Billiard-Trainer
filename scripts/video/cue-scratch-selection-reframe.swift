// V023 selection: X-Z horizontal metres, Y up. All paths are production recorder output.
import UIKit

final class CueScratchSelectionVideoTests: XCTestCase {
    @MainActor
    func testExportSelection() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["SCRATCH_SELECTION_VIDEO_DIR"] else { throw XCTSkip("Opt-in V023") }
        let out = URL(fileURLWithPath:path)
        let cases = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:out.appendingPathComponent("cases.json"))) as? [[String:Any]])
        XCTAssertEqual(cases.compactMap{$0["galleryID"] as? String},["M067","M071","M007","M030","M033","M053"])
        let size = CGSize(width:1440,height:2560), fps = 60
        let sceneSize=size, sceneOriginY:CGFloat=0
        let panel=CGRect(x:36,y:985,width:320,height:590)
        let y = BTTablePhysics.surfaceY, ballY = y+BallPhysics.radius
        let gold = UIColor(red:1,green:0.79,blue:0.26,alpha:1)
        let red = UIColor(red:1,green:0.32,blue:0.32,alpha:1)
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering:false,mobileRendering:true)
        XCTAssertTrue(scene.applyTableStyle(.charcoal,showsSights:true)); XCTAssertTrue(scene.applyClothColor(.green))
        scene.setCameraMode(.perspective3D,animated:false)
        XCTAssertTrue(scene.cueStick?.applyStyle(.inkDragon) == true)
        scene.setupVisualizationNodes(); scene.hideAllVisualization()
        let camera = try XCTUnwrap(scene.cameraNode)
        camera.camera?.usesOrthographicProjection = false; camera.camera?.projectionDirection = .vertical
        camera.camera?.fieldOfView = 56; camera.camera?.wantsExposureAdaptation = false
        let renderer = SCNRenderer(device:nil,options:nil)
        renderer.scene = scene; renderer.pointOfView = camera; renderer.delegate = scene.contactOcclusion
        renderer.autoenablesDefaultLighting = false
        let exporting = env["SCRATCH_SELECTION_VIDEO_EXPORT"] == "1"
        let writer: VideoWriter? = exporting ? try VideoWriter(url:out.appendingPathComponent("V023-seven-cases.mp4"),size:size,fps:fps,averageBitRate:32_000_000) : nil
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let compositor = UIGraphicsImageRenderer(size:size,format:format)
        var frame = 0, records: [[String:Any]] = []
        for (caseIndex,saved) in cases.enumerated() {
            let id = saved["galleryID"] as! String
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
            scene.showBall(key:PositionPlayBall.cueKey,scenePosition:cue); scene.showBall(key:"_1",scenePosition:object)
            var guides:[SCNNode]=[]
            func pathFor(_ name:String) -> [SCNVector3] {
                let entry=recorder.pocketEntries.first{$0.ball.name==name}!
                var pts=(recorder.framesByBallName[name] ?? []).filter{$0.time <= entry.time && $0.state != .pocketed}.sorted{$0.time<$1.time}.map{$0.position}
                pts.append(entry.ball.position); return pts
            }
            let cuePath=pathFor(ShotInput.cueBallName),objectPath=pathFor(ShotInput.targetBallName)
            scene.addCueTrajectory(cuePath,contact:contact,into:&guides)
            scene.addDashedPolyline(objectPath,color:gold,radius:0.0022,dash:0.028,gap:0.016,placement:.table,into:&guides)
            // The eye, cue and gaze are on the actual cue axis in XZ; no table-end yaw.
            let shotAxis=prediction.aimDirection.normalized()
            let framingPoints=cuePath+objectPath+[pockets[targetPocket],pockets[scratchPocket]]
            let back:Float=1.20, height:Float=0.80
            var fov:Float=52
            camera.position=SCNVector3(cue.x-shotAxis.x*back,y+height,cue.z-shotAxis.z*back)
            XCTAssertLessThan(abs(camera.position.x),3.9);XCTAssertLessThan(abs(camera.position.z),2.9)
            let cameraToCue=cue-camera.position
            XCTAssertEqual(cameraToCue.x*shotAxis.z-cameraToCue.z*shotAxis.x,0,accuracy:0.00001)
            XCTAssertEqual(cameraToCue.dot(shotAxis),back,accuracy:0.00001)
            // Keep full 9:16 output; reduce downward pitch and tighten the lens to each actual route.
            let aspect=Float(sceneSize.width/sceneSize.height)
            var bestPitch:Float=26 * .pi/180
            var foundCamera=false
            // Prefer 26 degrees; increase pitch only if the full route would enter the fixed panel.
            for pitchStep in 260...340 {
                let candidatePitch=Float(pitchStep)/10 * .pi/180
                var requiredTan:Float=0
                var projections:[(Float,Float,Float)]=[]
                for point in framingPoints {
                    for dx:Float in [-0.08,0.08] { for dz:Float in [-0.08,0.08] {
                        let delta=SCNVector3(point.x+dx-camera.position.x,y+0.045-camera.position.y,point.z+dz-camera.position.z)
                        let forward=delta.dot(shotAxis),right = -delta.x*shotAxis.z+delta.z*shotAxis.x
                        let depth=forward*cosf(candidatePitch)-delta.y*sinf(candidatePitch)
                        let up=forward*sinf(candidatePitch)+delta.y*cosf(candidatePitch)
                        requiredTan=max(requiredTan,abs(right)/(depth*aspect*0.94),abs(up)/(depth*0.82))
                        projections.append((right,up,depth))
                    }}
                }
                let candidateFOV=max(52,ceilf(2*atanf(requiredTan)*180 / .pi*10)/10+2)
                let tangent=tanf(candidateFOV * .pi/360)
                var overlaps=false
                for projection in projections {
                    let nx:Float=projection.0 / (projection.2*aspect*tangent)
                    let ny:Float=projection.1 / (projection.2*tangent)
                    let px:CGFloat=CGFloat(nx+1)*sceneSize.width/2
                    let py:CGFloat=CGFloat(1-ny)*sceneSize.height/2
                    if panel.insetBy(dx:-20,dy:-20).contains(CGPoint(x:px,y:py)) { overlaps=true;break }
                }
                if !overlaps { bestPitch=candidatePitch;fov=candidateFOV;foundCamera=true;break }
            }
            XCTAssertTrue(foundCamera,"No panel-safe camera in bounded pitch range: \(id)")
            let tanHalf=tanf(fov * .pi/360)
            var bestScore:Float=0
            for point in framingPoints {
                for dx:Float in [-0.08,0.08] { for dz:Float in [-0.08,0.08] {
                    let delta=SCNVector3(point.x+dx-camera.position.x,y+0.045-camera.position.y,point.z+dz-camera.position.z)
                    let forward=delta.dot(shotAxis),right = -delta.x*shotAxis.z+delta.z*shotAxis.x
                    let depth=forward*cosf(bestPitch)-delta.y*sinf(bestPitch)
                    let up=forward*sinf(bestPitch)+delta.y*cosf(bestPitch)
                    bestScore=max(bestScore,abs(right)/(depth*aspect*tanHalf*0.94),abs(up)/(depth*tanHalf*0.82))
                    let projected=CGPoint(x:CGFloat((right/(depth*aspect*tanHalf)+1)*Float(sceneSize.width)/2),y:CGFloat((1-up/(depth*tanHalf))*Float(sceneSize.height)/2))
                    XCTAssertFalse(panel.insetBy(dx:-20,dy:-20).contains(projected),"Panel overlaps route envelope: \(id)")
                }}
            }
            XCTAssertLessThanOrEqual(bestScore,1,"Full-bleed coverage failed: \(id)")
            let gaze=camera.position+SCNVector3(shotAxis.x*cosf(bestPitch),-sinf(bestPitch),shotAxis.z*cosf(bestPitch))
            camera.look(at:gaze,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
            camera.camera?.fieldOfView=CGFloat(fov)
            SCNTransaction.flush()
            let ghostNodes=makeGhost(at:contact,clothY:y,scene:scene)
            let aim=prediction.aimDirection,strike=CueStroke.strikePosition(cue:cue,aim:aim,spinX:0,spinY:0)
            let obstacles=scene.cueObstacleCenters(excludingStrikeNear:strike)
            guard case .angle(let elevation)=CueStick.requiredElevation(cueBallPosition:strike,aimDirection:aim,obstacleCenters:obstacles) else { XCTFail("No cue pose"); return }
            let endPull=CueStroke.clampedFollowThroughPull(cueBallPosition:strike,aimDirection:aim,obstacleCenters:obstacles,elevation:elevation)
            let impact=1.5+CueStroke.totalDuration(velocity:speed)
            let motionEnd=SequenceVideoExporter.motionEndTime(duration:prediction.duration,playback:playback,pocketedBallNames:prediction.pocketedBalls,speed:1)
            let count=caseIndex==0 ? Int(ceil((impact+Double(motionEnd)+0.5)*Double(fps))) : 90
            let startFrame=frame
            let keys:Set<Int>=caseIndex==0 ? Set([0,Int(impact*60),Int((impact+0.43)*60),Int((impact+1.2)*60),Int((impact+2.15)*60),count-1]) : [0]
            let entries=Dictionary(uniqueKeysWithValues:recorder.pocketEntries.map{($0.ball.name,$0)})
            var previousTime:Float=0,previousOmega:[String:SCNVector3]=[:]
            var staticImage:CGImage?
            for i in 0..<count {
                let wall=Double(i)/Double(fps)
                let t:Float=caseIndex==0 ? min(motionEnd,max(0,Float(wall-impact))) : 0
                let dt=max(0,t-previousTime);previousTime=t
                if caseIndex==0 || i==0 {
                    SCNTransaction.begin();SCNTransaction.disableActions=true
                    for name in [ShotInput.cueBallName,ShotInput.targetBallName] {
                        let node=try XCTUnwrap(scene.allBallNodes[name==ShotInput.cueBallName ? PositionPlayBall.cueKey : "_1"])
                        guard let state=playback.stateAt(ballName:name,time:min(t,prediction.duration)) else { continue }
                        node.position=state.position;node.opacity=1
                        if let opacity=playback.collectionOpacity(ballName:name,time:t),let shown=playback.stateAt(ballName:name,time:t) {
                            node.position=shown.position;node.opacity=opacity
                        } else if let entry=entries[name],t>=entry.time {
                            let pocket=TrajectoryPlayback.nearestPocket(to:entry.ball.position,surfaceY:ballY)
                            let legs=TrajectoryPlayback.solvePocketEntry(capture:entry.ball.position,velocity:entry.ball.velocity,pocketCenter:pocket.center,pocketRadius:pocket.radius,speedScale:1)
                            let elapsed=Double(t-entry.time),end=TrajectoryPlayback.pocketEntryDuration(legs)
                            node.position=TrajectoryPlayback.pocketEntryPosition(start:entry.ball.position,legs:legs,at:elapsed)
                            node.opacity=CGFloat(max(0,min(1,1-(elapsed-end-TrajectoryPlayback.pocketPauseDuration)/TrajectoryPlayback.pocketFadeDuration)))
                        }
                        BallSpinIntegrator.advance(node:node,from:previousOmega[name] ?? state.angularVelocity,to:state.angularVelocity,dt:dt);previousOmega[name]=state.angularVelocity
                    }
                    for node in ghostNodes { node.isHidden=caseIndex==0 && wall>=impact }
                    if caseIndex==0 && wall<impact+0.40 {
                        let pull=wall<impact ? CueStroke.pullBack(at:max(0,wall-1.5),velocity:speed) : CueStroke.followThrough(at:wall-impact,endPull:endPull)
                        scene.updateCueStick(cueBallPosition:strike,aimDirection:aim,pullBack:pull,elevationOverride:elevation)
                    } else { scene.hideCueStick() }
                    SCNTransaction.commit();SCNTransaction.flush()
                }
                if exporting || keys.contains(i) {
                    if caseIndex==0 || staticImage==nil {
                        if i==0 { for _ in 0..<3 { _=renderer.snapshot(atTime:Double(frame)/60,with:sceneSize,antialiasingMode:.multisampling4X) } }
                        let raw=renderer.snapshot(atTime:Double(frame)/60,with:sceneSize,antialiasingMode:.multisampling4X)
                        let image=compositor.image { ctx in
                            UIColor(red:0.06,green:0.09,blue:0.08,alpha:1).setFill();ctx.fill(CGRect(origin:.zero,size:size));raw.draw(in:CGRect(x:0,y:sceneOriginY,width:sceneSize.width,height:sceneSize.height))
                            func text(_ str:String,_ x:CGFloat,_ yy:CGFloat,_ font:CGFloat,_ color:UIColor = .white) {
                                (str as NSString).draw(at:CGPoint(x:x,y:yy),withAttributes:[.font:UIFont.systemFont(ofSize:font,weight:.semibold),.foregroundColor:color])
                            }
                            // One left-centred panel, matching the supplied rounded white border and black header.
                            let cg=ctx.cgContext
                            cg.saveGState()
                            let outline=UIBezierPath(roundedRect:panel,cornerRadius:24)
                            outline.addClip()
                            UIColor.black.setFill();ctx.fill(CGRect(x:panel.minX,y:panel.minY,width:panel.width,height:80))
                            text("击球参数",panel.minX+26,panel.minY+16,43)
                            text(String(format:"切角 %.1f°",cut),panel.minX+24,panel.minY+112,40)
                            text(String(format:"杆速 %.2f m/s",speed),panel.minX+24,panel.minY+181,36)
                            text("母球打点",panel.minX+24,panel.minY+260,36)
                            let disc=CGRect(x:panel.midX-78,y:panel.minY+326,width:156,height:156)
                            cg.setFillColor(UIColor.white.cgColor);cg.fillEllipse(in:disc)
                            cg.setStrokeColor(UIColor.systemRed.cgColor);cg.setLineWidth(1.5)
                            cg.move(to:CGPoint(x:disc.midX,y:disc.minY));cg.addLine(to:CGPoint(x:disc.midX,y:disc.maxY))
                            cg.move(to:CGPoint(x:disc.minX,y:disc.midY));cg.addLine(to:CGPoint(x:disc.maxX,y:disc.midY));cg.strokePath()
                            cg.setFillColor(UIColor.systemOrange.cgColor);cg.fillEllipse(in:CGRect(x:disc.midX-12,y:disc.midY-12,width:24,height:24))
                            text("中杆 · 无塞",panel.minX+64,panel.minY+520,32)
                            cg.restoreGState()
                            UIColor.white.withAlphaComponent(0.95).setStroke();outline.lineWidth=3;outline.stroke()

                        }
                        staticImage=try! XCTUnwrap(image.cgImage)
                        if keys.contains(i) { try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent(String(format:"%@-%04d.png",id,i))) }
                    }
                    if let writer,let image=staticImage { try writer.append(image) }
                }
                frame+=1
                if frame%120==0 { print("V023 frame=\(frame) case=\(id)");await Task.yield() }
            }
            records.append(["id":id,"startFrame":startFrame,"frames":count,"duration":Double(count)/60,"mode":caseIndex==0 ? "full-shot" : "static","speed":speed,"cameraXYZ":[camera.position.x,camera.position.y,camera.position.z],"gazeXYZ":[gaze.x,gaze.y,gaze.z],"pitchDegrees":bestPitch*180 / .pi,"framingScore":bestScore,"cameraBack":back,"cameraHeight":height,"cameraFOV":fov,"aimXZ":[shotAxis.x,shotAxis.z],"cutDegrees":cut,"recommendationCutDegrees":recommendationCut,"spin":[0,0],"targetPocket":targetPocket,"cuePocket":scratchPocket,"aimOffset":offset,"cueElevationDegrees":elevation*180 / .pi,"impactTime":caseIndex==0 ? impact : 0,"events":events,"cuePathPoints":cuePath.count,"objectPathPoints":objectPath.count,"ghostXYZ":[contact.x,contact.y,contact.z]])
            for node in guides+ghostNodes { node.removeFromParentNode() }
        }
        if let writer { try await writer.finish() }
        let manifest:[String:Any]=["version":"selection-r6-camera-reframe-stills","fps":fps,"frames":frame,"duration":Double(frame)/60,"width":1440,"height":2560,"exported":exporting,"cameraPolicy":"full-portrait-close-eye-26deg-pitch-route-fov","sceneViewport":[0,0,1440,2560],"parameterPanel":[36,985,320,590],"cases":records]
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
