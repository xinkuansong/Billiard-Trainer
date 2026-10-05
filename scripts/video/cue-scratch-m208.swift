// Opt-in native export. World: X-Z horizontal metres, Y up; no geometry conversion.
import UIKit

final class CueScratchM208VideoTests: XCTestCase {
    @MainActor
    func testExportM208() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["M208_VIDEO_DIR"] else { throw XCTSkip("Opt-in M208 export") }
        let out = URL(fileURLWithPath:path)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:out.appendingPathComponent("case.json"))) as? [String:Any])
        func numbers(_ key: String) throws -> [Float] { try XCTUnwrap(saved[key] as? [NSNumber]).map { $0.floatValue } }
        let y = BTTablePhysics.surfaceY, ballY = y + BallPhysics.radius
        let c = try numbers("cue"), o = try numbers("object"), expectedAim = try numbers("aim")
        let cue = SCNVector3(c[0],ballY,c[1]), object = SCNVector3(o[0],ballY,o[1])
        let velocity = try XCTUnwrap(saved["speed"] as? NSNumber).floatValue
        let offset = try XCTUnwrap(saved["offset"] as? NSNumber).floatValue
        let input = ShotInput(cueBall:cue,targetBall:object,pocketIndex:5,velocity:velocity,spinX:0,spinY:0,surfaceY:y)
        let prediction = ShotPredictor.predictForPositionSolve(input,aimOffset:offset,maxEvents:1000,maxTime:30,includePresentation:true)
        XCTAssertTrue(prediction.cuePocketed && prediction.objectPocketed)
        XCTAssertEqual(prediction.aimDirection.x,expectedAim[0],accuracy:0.000001)
        XCTAssertEqual(prediction.aimDirection.z,expectedAim[1],accuracy:0.000001)
        var events: [[String:Any]] = [], rails = 0
        for event in prediction.events {
            switch event.kind {
            case .ballCushion(let ball):
                let index = event.cushionIndex ?? -1
                if ball == ShotInput.cueBallName { rails += 1; XCTAssertEqual(index,1) }
                events.append(["kind":"rail","ball":ball,"index":index,"time":event.time])
            case .pocket(let ball,let pocket):
                XCTAssertEqual(pocket,ball == ShotInput.cueBallName ? "pocket_1" : "pocket_5")
                XCTAssertEqual(event.time,ball == ShotInput.cueBallName ? 5.696444 : 1.953055,accuracy:0.002)
                events.append(["kind":"pocket","ball":ball,"pocket":pocket,"time":event.time])
            case .ballBall: events.append(["kind":"contact","time":event.time])
            default: break
            }
        }
        XCTAssertEqual(rails,1)
        let recorder = try XCTUnwrap(prediction.recorder)
        let playback = TrajectoryPlayback(recorder:recorder,surfaceY:ballY)
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering:false,mobileRendering:true)
        XCTAssertTrue(scene.applyTableStyle(.charcoal,showsSights:true))
        XCTAssertTrue(scene.applyClothColor(.green))
        scene.setCameraMode(.perspective3D,animated:false)
        XCTAssertTrue(scene.cueStick?.applyStyle(.inkDragon) == true)
        scene.hideAllBalls(); scene.hideCueStick(); scene.setupVisualizationNodes(); scene.hideAllVisualization()
        scene.setCueBallHomeOrientation(BallSpinIntegrator.identityOrientation)
        scene.showBall(key:PositionPlayBall.cueKey,scenePosition:cue)
        scene.showBall(key:"_1",scenePosition:object)
        let aim = prediction.aimDirection
        let strike = CueStroke.strikePosition(cue:cue,aim:aim,spinX:0,spinY:0)
        guard case .angle(let elevation) = CueStick.requiredElevation(cueBallPosition:strike,aimDirection:aim,obstacleCenters:scene.cueObstacleCenters(excludingStrikeNear:strike)) else {
            XCTFail("No nonpenetrating cue pose"); return
        }
        let size = CGSize(width:1440,height:2560), fps = 60
        let camera = try XCTUnwrap(scene.cameraNode)
        camera.camera?.usesOrthographicProjection = false
        camera.camera?.projectionDirection = .vertical
        camera.camera?.fieldOfView = 48
        camera.camera?.wantsExposureAdaptation = false
        let pitch: Float = .pi/6, distance: Float = 4.20
        camera.position = SCNVector3(-distance*cosf(pitch),y+distance*sinf(pitch),0)
        camera.look(at:SCNVector3(0,y,0),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        let renderer = SCNRenderer(device:nil,options:nil)
        renderer.scene = scene; renderer.pointOfView = camera
        renderer.delegate = scene.contactOcclusion; renderer.autoenablesDefaultLighting = false
        let exporting = env["M208_VIDEO_EXPORT"] == "1"
        let writer: VideoWriter? = exporting ? try VideoWriter(url:out.appendingPathComponent("M208-one-cushion.mp4"),size:size,fps:fps,averageBitRate:32_000_000) : nil
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let compositor = UIGraphicsImageRenderer(size:size,format:format)
        for _ in 0..<3 { _ = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X) }
        let impact = 1.3 + CueStroke.totalDuration(velocity:velocity)
        let motionEnd = SequenceVideoExporter.motionEndTime(duration:prediction.duration,playback:playback,pocketedBallNames:prediction.pocketedBalls,speed:1)
        let count = Int(ceil((impact+Double(motionEnd)+0.7)*Double(fps)))
        let keyTimes = [0.0,impact,impact+0.61,impact+1.113,impact+1.96,impact+5.5,impact+5.9,Double(count-1)/Double(fps)]
        let keys = Set(keyTimes.map { min(count-1,Int($0*Double(fps))) })
        let names = [ShotInput.cueBallName,ShotInput.targetBallName]
        let entries = Dictionary(uniqueKeysWithValues:recorder.pocketEntries.map { ($0.ball.name,$0) })
        var previousTime: Float = 0, previousOmega: [String:SCNVector3] = [:]
        var ledger: [[String:Any]] = []
        for i in 0..<count {
            let wall = Double(i)/Double(fps), t = min(motionEnd,max(0,Float(Double(i)/Double(fps)-impact)))
            let dt = max(0,t-previousTime); previousTime = t
            SCNTransaction.begin(); SCNTransaction.disableActions = true
            for name in names {
                let node = try XCTUnwrap(scene.allBallNodes[name == ShotInput.cueBallName ? PositionPlayBall.cueKey : "_1"])
                guard let state = playback.stateAt(ballName:name,time:min(t,prediction.duration)) else { continue }
                node.position = state.position; node.opacity = 1
                if let opacity = playback.collectionOpacity(ballName:name,time:t),let shown = playback.stateAt(ballName:name,time:t) {
                    node.position = shown.position; node.opacity = opacity
                } else if let entry = entries[name],t >= entry.time {
                    let pocket = TrajectoryPlayback.nearestPocket(to:entry.ball.position,surfaceY:ballY)
                    let legs = TrajectoryPlayback.solvePocketEntry(capture:entry.ball.position,velocity:entry.ball.velocity,pocketCenter:pocket.center,pocketRadius:pocket.radius,speedScale:1)
                    let elapsed = Double(t-entry.time),end = TrajectoryPlayback.pocketEntryDuration(legs)
                    node.position = TrajectoryPlayback.pocketEntryPosition(start:entry.ball.position,legs:legs,at:elapsed)
                    node.opacity = CGFloat(max(0,min(1,1-(elapsed-end-TrajectoryPlayback.pocketPauseDuration)/TrajectoryPlayback.pocketFadeDuration)))
                }
                BallSpinIntegrator.advance(node:node,from:previousOmega[name] ?? state.angularVelocity,to:state.angularVelocity,dt:dt)
                previousOmega[name] = state.angularVelocity
            }
            if wall < impact {
                scene.updateCueStick(cueBallPosition:strike,aimDirection:aim,pullBack:CueStroke.pullBack(at:max(0,wall-1.3),velocity:velocity),elevationOverride:elevation)
            } else { scene.hideCueStick() }
            SCNTransaction.commit(); SCNTransaction.flush()
            if keys.contains(i) || i % fps == 0 {
                let p = scene.allBallNodes[PositionPlayBall.cueKey]!.position
                ledger.append(["frame":i,"physicsTime":t,"cueXYZ":[p.x,p.y,p.z]])
            }
            if exporting || keys.contains(i) {
                let raw = renderer.snapshot(atTime:wall,with:size,antialiasingMode:.multisampling4X)
                let image = compositor.image { context in
                    UIColor.black.setFill(); context.fill(CGRect(origin:.zero,size:size)); raw.draw(in:CGRect(origin:.zero,size:size))
                    let text = "一库掉袋" as NSString
                    let attrs: [NSAttributedString.Key:Any] = [.font:UIFont.systemFont(ofSize:78,weight:.bold),.foregroundColor:UIColor.white]
                    text.draw(at:CGPoint(x:(size.width-text.size(withAttributes:attrs).width)/2,y:340),withAttributes:attrs)
                    let sub = "M208 · 母球走向展示" as NSString
                    let subAttrs: [NSAttributedString.Key:Any] = [.font:UIFont.systemFont(ofSize:32,weight:.medium),.foregroundColor:UIColor(white:0.8,alpha:1)]
                    sub.draw(at:CGPoint(x:(size.width-sub.size(withAttributes:subAttrs).width)/2,y:448),withAttributes:subAttrs)
                }
                if keys.contains(i) { try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent(String(format:"frame-%04d.png",i))) }
                if let writer { try writer.append(try XCTUnwrap(image.cgImage)) }
            }
            if i % 120 == 0 { print("M208 frame=\(i)/\(count), elevation=\(elevation*180 / .pi)"); await Task.yield() }
        }
        if let writer { try await writer.finish() }
        let manifest: [String:Any] = ["case":"M208","version":"r1","frames":count,"fps":fps,"width":1440,"height":2560,"duration":Double(count)/Double(fps),"exported":exporting,"impactTime":impact,"events":events,"ledger":ledger,"cueElevationDegrees":elevation*180 / .pi,"cueSpeed":velocity,"spin":[0,0],"aimOffset":offset,"physicsDuration":prediction.duration,"motionEnd":motionEnd,"appearance":["charcoal","green","inkDragon"],"cameraPosition":[camera.position.x,camera.position.y,camera.position.z],"pitch":30,"FOV":48,"playbackRate":1]
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("manifest.json"))
    }
}
