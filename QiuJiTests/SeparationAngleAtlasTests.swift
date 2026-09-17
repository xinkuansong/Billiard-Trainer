import XCTest
import SceneKit
@testable import QiuJi

/// v11 Y3：「分离角图谱」spinY 档位 / 轨迹切片 / 90° 法则不变量。
final class SeparationAngleAtlasTests: XCTestCase {

    func testSpinYLevels_endpointsEqualMiscueLimit() {
        let levels = SeparationAngleAtlasGeometry.spinYLevels()
        XCTAssertEqual(levels.count, 8)
        let limit = CuePhysics.miscueLimitFraction
        XCTAssertEqual(levels.first!, limit, accuracy: 1e-6, "首档 = +miscueLimit（纯高杆）")
        XCTAssertEqual(levels.last!, -limit, accuracy: 1e-6, "末档 = −miscueLimit（纯低杆）")
        // 均匀：相邻差相等
        let step = levels[0] - levels[1]
        for i in 1..<levels.count {
            XCTAssertEqual(levels[i - 1] - levels[i], step, accuracy: 1e-6)
        }
        XCTAssertEqual(SeparationAngleAtlasGeometry.trackColors.count, 8,
                       "页内 8 色板与档位数一致")
    }

    func testPathSlice_startsAtBallBall_endsAtFirstCueCushion() {
        let sY = BTTablePhysics.surfaceY
        let scene = SeparationAngleAtlasGeometry.defaultTeachingScene()
        let y = SeparationAngleAtlasGeometry.sceneKitBallY(surfaceY: sY)
        let cue = SCNVector3(Float(scene.cue.x), y, Float(scene.cue.y))
        let target = SCNVector3(Float(scene.target.x), y, Float(scene.target.y))
        let aim = SCNVector3(Float(scene.aimDir.x), 0, Float(scene.aimDir.y))

        let pred = ShotPredictor.simulateFree(
            cueBall: cue, aimDir: aim, velocity: 2.5,
            spinX: 0, spinY: 0,
            surfaceY: sY,
            balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)]
        )

        let bb = SeparationAngleAtlasGeometry.firstBallBallEvent(in: pred.events)
        let cushion = SeparationAngleAtlasGeometry.firstCueCushionAfterBallBall(in: pred.events)
        XCTAssertNotNil(bb, "应发生球-球碰撞")
        XCTAssertNotNil(cushion, "碰后母球应吃库")
        guard let bb, let cushion else { return }
        XCTAssertGreaterThan(cushion.time, bb.time)

        let slice = SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion(pred)
        XCTAssertGreaterThanOrEqual(slice.count, 2, "切片应有折线段；termination=\(String(describing: pred.termination))")
        guard slice.count >= 2 else { return }

        if let recorder = pred.recorder,
           let start = recorder.stateAt(ballName: ShotInput.cueBallName, time: bb.time),
           let end = recorder.stateAt(ballName: ShotInput.cueBallName, time: cushion.time) {
            let d0 = hypotf(slice.first!.x - start.position.x, slice.first!.z - start.position.z)
            let d1 = hypotf(slice.last!.x - end.position.x, slice.last!.z - end.position.z)
            XCTAssertLessThan(d0, 0.03, "切片起点应贴近首次球-球碰撞位置")
            XCTAssertLessThan(d1, 0.03, "切片终点应贴近母球首个 ballCushion 位置")
        } else {
            XCTFail("simulateFree 应提供 recorder 与事件")
        }
    }

    /// v11 Y3 返工 r1：低力度纯低杆（1.5 m/s, spinY=−0.5）碰后回拖停球、不吃库，
    /// 切片须降级为「碰撞点 → 停球点」而非返回空（默认态 8 条轨迹齐全的保障）。
    func testPathSlice_lowPowerDraw_noCushion_fallsBackToStopPoint() {
        let sY = BTTablePhysics.surfaceY
        let scene = SeparationAngleAtlasGeometry.defaultTeachingScene()
        let y = SeparationAngleAtlasGeometry.sceneKitBallY(surfaceY: sY)
        let cue = SCNVector3(Float(scene.cue.x), y, Float(scene.cue.y))
        let target = SCNVector3(Float(scene.target.x), y, Float(scene.target.y))
        let aim = SCNVector3(Float(scene.aimDir.x), 0, Float(scene.aimDir.y))

        let pred = ShotPredictor.simulateFree(
            cueBall: cue, aimDir: aim, velocity: 1.5,
            spinX: 0, spinY: -CuePhysics.miscueLimitFraction,
            surfaceY: sY,
            balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)]
        )

        let bb = SeparationAngleAtlasGeometry.firstBallBallEvent(in: pred.events)
        XCTAssertNotNil(bb, "应发生球-球碰撞")
        // 前置条件：本场景碰后确实不吃库（若引擎行为变化导致吃库，此测试场景需重选）
        XCTAssertNil(SeparationAngleAtlasGeometry.firstCueCushionAfterBallBall(in: pred.events),
                     "预期低力度纯低杆碰后停球、不吃库（根因场景复现）")

        let slice = SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion(pred)
        if !pred.hasFinalTableState, let recorder = pred.recorder {
            for name in [ShotInput.cueBallName, ShotInput.targetBallName] {
                print("[W07 low draw final] name=\(name) duration=\(pred.duration) state=\(String(describing: recorder.stateAt(ballName: name, time: pred.duration)))")
                print("[W07 low draw local] name=\(name) end=\(String(describing: recorder.localIntervalsByBallName[name]?.last?.end)) handoffs=\(recorder.localHandoffs.filter { $0.ballName == name })")
            }
            print("[W07 low draw events] \(pred.events)")
        }
        XCTAssertGreaterThanOrEqual(slice.count, 2, "未吃库时切片应降级为碰撞点→停球点，不得为空；termination=\(String(describing: pred.termination))")
        guard slice.count >= 2 else { return }

        guard let bb, let recorder = pred.recorder,
              let start = recorder.stateAt(ballName: ShotInput.cueBallName, time: bb.time),
              let stop = pred.cuePath.last else {
            XCTFail("simulateFree 应提供 recorder 与轨迹")
            return
        }
        let d0 = hypotf(slice.first!.x - start.position.x, slice.first!.z - start.position.z)
        let d1 = hypotf(slice.last!.x - stop.x, slice.last!.z - stop.z)
        XCTAssertLessThan(d0, 0.03, "切片起点应贴近首次球-球碰撞位置")
        XCTAssertLessThan(d1, 0.03, "切片终点应贴近母球停球点")
    }

    func testStunHighSpeed_postContactDirApproximatelyTangent() {
        let sY = BTTablePhysics.surfaceY
        let scene = SeparationAngleAtlasGeometry.defaultTeachingScene()
        let y = SeparationAngleAtlasGeometry.sceneKitBallY(surfaceY: sY)
        let cue = SCNVector3(Float(scene.cue.x), y, Float(scene.cue.y))
        let target = SCNVector3(Float(scene.target.x), y, Float(scene.target.y))
        let aim = SCNVector3(Float(scene.aimDir.x), 0, Float(scene.aimDir.y))

        // 中杆 + 较高速度：接触时仍接近滑动 → 90° 法则
        let pred = ShotPredictor.simulateFree(
            cueBall: cue, aimDir: aim, velocity: 4.0,
            spinX: 0, spinY: 0,
            surfaceY: sY,
            balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)]
        )
        let slice = SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion(pred)
        XCTAssertGreaterThanOrEqual(slice.count, 2, "应有碰后轨迹")
        guard let postDir = SeparationAngleAtlasGeometry.postContactInitialDir(slice) else {
            XCTFail("无法取碰后首段方向")
            return
        }

        let n = SCNVector3(Float(scene.potDir.x), 0, Float(scene.potDir.y))
        let tangent = SeparationAngleAtlasGeometry.tangentDir(aim: aim, lineOfCenters: n)
        let dot = abs(postDir.x * tangent.x + postDir.z * tangent.z)
        // 引擎含球面摩擦/投掷与滚动过渡；容差 ~32°（cos32°≈0.85）仍远优于随机方向。
        // 数值草稿：`build/y3-evidence/y3-stun-tangent-measure.txt`
        XCTAssertGreaterThan(dot, 0.85,
                             "中杆高速碰后首段应近似切线方向（90° 法则），dot=\(dot)")
    }
}

extension SeparationAngleAtlasTests {
    func testSliceCompletenessUsesRequiredEventInsteadOfWholeTableRest() throws {
        let scene = SeparationAngleAtlasGeometry.defaultTeachingScene()
        let surface = BTTablePhysics.surfaceY
        let y = SeparationAngleAtlasGeometry.sceneKitBallY(surfaceY: surface)
        func predict(_ duration: Float) -> ShotPrediction {
            ShotPredictor.simulateFree(
                cueBall: SCNVector3(Float(scene.cue.x), y, Float(scene.cue.y)),
                aimDir: SCNVector3(Float(scene.aimDir.x), 0, Float(scene.aimDir.y)),
                velocity: 2.5, spinX: 0, spinY: 0, surfaceY: surface,
                balls: [ObstacleBall(name: ShotInput.targetBallName,
                    position: SCNVector3(Float(scene.target.x), y, Float(scene.target.y)))],
                maxTime: duration)
        }
        let full = predict(15)
        let contact = try XCTUnwrap(SeparationAngleAtlasGeometry.firstBallBallEvent(in: full.events))
        let cushion = try XCTUnwrap(SeparationAngleAtlasGeometry.firstCueCushionAfterBallBall(in: full.events))
        let partial = predict((contact.time + cushion.time) / 2)
        XCTAssertFalse(SeparationAngleAtlasGeometry.hasCompleteSlice(partial))
        XCTAssertTrue(SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion(partial).isEmpty)
        let prefix = predict(cushion.time + 0.01)
        XCTAssertEqual(prefix.termination, .timeLimit)
        XCTAssertTrue(SeparationAngleAtlasGeometry.hasCompleteSlice(prefix))
        XCTAssertFalse(SeparationAngleAtlasGeometry.pathAfterContactToFirstCueCushion(prefix).isEmpty)
    }
}

/// Opt-in film of eight independent production-engine shots with one incoming cue ball and eight synchronized post-contact outcomes.
@MainActor
final class SeparationEightBallVideoCaptureTests: XCTestCase {
    private var is2K: Bool { (ProcessInfo.processInfo.environment["SEPARATION_2K"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_SEPARATION_2K"]) == "1" }
    private var is3D: Bool { (ProcessInfo.processInfo.environment["SEPARATION_VIEW"] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_SEPARATION_VIEW"]) == "3d" }
    private var size: CGSize { is2K ? CGSize(width:1440,height:2560) : CGSize(width:1080,height:1920) }
    private struct Track {
        let playback: TrajectoryPlayback
        let contact: Float
        let end: Float
        let cushion: Bool
        let node: SCNNode
        let spin: Float
    }

    func testExport() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["EIGHT_BALL_VIDEO_DIR"] ?? env["TEST_RUNNER_EIGHT_BALL_VIDEO_DIR"] else {
            throw XCTSkip("Opt-in: TEST_RUNNER_EIGHT_BALL_VIDEO_DIR")
        }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("frames"), withIntermediateDirectories: true)
        let scene = AngleTrainingScene()
        scene.setupScene(); scene.setupVisualizationNodes()
        scene.usesAdaptiveDiagramLabels = true
        scene.applyTableStyle(.standard, showsSights: true); scene.applyClothColor(.green)
        scene.hideAllBalls()
        let radius = AngleSceneCalculator.ballRadius
        let target = SCNVector3(0, scene.surfaceY + radius, 0.10)
        let aim = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: 5, surfaceY: scene.surfaceY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: aim, ballRadius: radius)
        let n = simd_normalize(SIMD2<Float>(aim.x-target.x, aim.z-target.z))
        let angle: Float = 15 * .pi / 180
        let side = SIMD2<Float>(-n.y, n.x)
        let d = n * cos(angle) + side * sin(angle)
        let diameter = 2 * radius
        let length = -diameter*cos(angle) + sqrt(0.60*0.60-pow(diameter*sin(angle), 2))
        let cue = SCNVector3(ghost.x-length*d.x, target.y, ghost.z-length*d.y)
        XCTAssertEqual(AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: aim), 15, accuracy: 0.001)
        XCTAssertEqual(AngleSceneCalculator.horizontalDistance(cue, target), 0.60, accuracy: 0.00001)
        XCTAssertLessThan(d.x, 0) // Portrait down = -X.
        scene.showBall(key: "cueBall", scenePosition: cue)
        scene.showBall(key: "_8", scenePosition: target)
        scene.setCurrentTargetNumber(8)
        scene.updateVisualization(cueBall: cue, targetBall: target, pocket: aim,
            showAngleAnnotations: true, showOverlapMarkers: false, showLineLabels: false, extendStrikeLineToRail: true)
        scene.updateCueStick(cueBallPosition: cue, aimDirection: SCNVector3(d.x,0,d.y))
        let template = try XCTUnwrap(scene.cueBallNode)
        scene.setCameraMode(is3D ? .perspective3D : .topDown2D, animated: false)
        let cameraNode = try XCTUnwrap(scene.cameraNode)
        let camera = try XCTUnwrap(cameraNode.camera)
        camera.usesOrthographicProjection = true; camera.projectionDirection = .vertical
        camera.orthographicScale = 1.60; camera.zNear = 0.01; camera.zFar = 100
        camera.wantsExposureAdaptation = false
        let center = SCNVector3(0, scene.surfaceY, 0)
        cameraNode.position = SCNVector3(center.x, scene.surfaceY+3, center.z)
        cameraNode.look(at: center, up: SCNVector3(1,0,0), localFront: SCNVector3(0,0,-1))
        if is3D {
            camera.usesOrthographicProjection=false;camera.fieldOfView=40
            let elevation=Float(35 * Double.pi / 180);let distance:Float=5.10
            let focus=SCNVector3(0,scene.surfaceY,0)
            cameraNode.position=SCNVector3(-distance*cos(elevation),focus.y+distance*sin(elevation),0)
            cameraNode.look(at:focus,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        }
        let cameraTransform = cameraNode.simdTransform
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene; renderer.pointOfView = cameraNode
        renderer.autoenablesDefaultLighting = false; renderer.delegate = scene.contactOcclusion
        let labelView = SCNView(frame: CGRect(x:0,y:0,width:360,height:640))
        labelView.scene = scene; labelView.pointOfView = cameraNode; labelView.layoutIfNeeded()
        let labels = DiagramLabelOverlay()
        var tracks: [Track] = []
        var ledger: [[String: Any]] = []
        for (index, spin) in SeparationAngleAtlasGeometry.spinYLevels().enumerated() {
            let prediction = ShotPredictor.simulateFree(cueBall: cue, aimDir: SCNVector3(d.x,0,d.y), velocity: 3,
                spinX: 0, spinY: spin, surfaceY: scene.surfaceY,
                balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)])
            guard SeparationAngleAtlasGeometry.hasCompleteSlice(prediction) else {
                XCTFail("Incomplete physics for track \(index): \(String(describing: prediction.termination))")
                throw NSError(domain: "EightBallCapture", code: 1)
            }
            let contact = try XCTUnwrap(SeparationAngleAtlasGeometry.firstBallBallEvent(in: prediction.events)).time
            let cushion = SeparationAngleAtlasGeometry.firstCueCushionAfterBallBall(in: prediction.events)
            let recorder = try XCTUnwrap(prediction.recorder)
            let playback = TrajectoryPlayback(recorder: recorder, surfaceY: target.y)
            let end: Float
            if let cushion { end = cushion.time } else {
                XCTAssertTrue(prediction.hasFinalTableState)
                let frames = try XCTUnwrap(recorder.framesByBallName[ShotInput.cueBallName])
                end = frames.first(where: { $0.time >= contact && $0.velocity.length() == 0 })?.time ?? prediction.duration
            }
            let node: SCNNode
            if index == 0 { node = template } else {
                node = try XCTUnwrap(scene.allBallNodes["_\(index)"])
                node.childNodes.forEach { $0.removeFromParentNode() }
                node.geometry = template.geometry?.copy() as? SCNGeometry
                template.childNodes.forEach { node.addChildNode($0.clone()) }
                node.simdTransform = template.simdTransform
            }
            node.isHidden = false; node.opacity = 1
            let start = try XCTUnwrap(playback.stateAt(ballName: ShotInput.cueBallName, time: contact)).position
            let finish = try XCTUnwrap(playback.stateAt(ballName: ShotInput.cueBallName, time: end)).position
            XCTAssertLessThan(AngleSceneCalculator.horizontalDistance(start, ghost), 0.001)
            for k in 0...240 {
                let t = end*Float(k)/240
                let p = try XCTUnwrap(playback.stateAt(ballName: ShotInput.cueBallName, time: t)).position
                XCTAssertLessThanOrEqual(abs(p.x), AngleSceneCalculator.innerLength/2 + 0.001)
                XCTAssertLessThanOrEqual(abs(p.z), AngleSceneCalculator.innerWidth/2 + 0.001)
                XCTAssertEqual(p.y, target.y, accuracy: 0.0001)
            }
            tracks.append(Track(playback: playback, contact: contact, end: end, cushion: cushion != nil, node: node, spin: spin))
            ledger.append(["index": index, "spinY": spin, "contactTime": contact, "stopTime": end,
                "postContactDuration": end-contact, "stopReason": cushion == nil ? "naturalRest" : "firstCushion",
                "start": [cue.x,cue.y,cue.z], "contactPosition": [start.x,start.y,start.z], "end": [finish.x,finish.y,finish.z],
                "termination": String(describing: prediction.termination)])
            print("EIGHT_BALL track=\(index) contact=\(contact) end=\(end) cushion=\(cushion != nil)")
        }
        XCTAssertEqual(tracks.count, 8)
        // Real-time 1x playback; no per-track speed changes or equal-arrival animation.
        let longest = try XCTUnwrap(tracks.map { $0.end-$0.contact }.max())
        let reference = tracks[0]
        let aimDirection = SCNVector3(d.x,0,d.y)
        let strike = CueStroke.strikePosition(cue:cue,aim:aimDirection,spinX:0,spinY:Double(reference.spin))
        guard case .angle(let elevation) = CueStick.requiredElevation(cueBallPosition:strike,aimDirection:aimDirection,obstacleCenters:[target]) else {
            XCTFail("Cue stroke blocked"); throw NSError(domain:"EightBallCapture",code:2)
        }
        let endPull = CueStroke.clampedFollowThroughPull(cueBallPosition:strike,aimDirection:aimDirection,obstacleCenters:[target])
        let tipInset = CueStroke.tipInset(spinX:0,spinY:Double(reference.spin))
        let strokeStart = 0.25
        let leadIn = strokeStart + CueStroke.totalDuration(velocity:3)
        let branchTime = leadIn + Double(reference.contact)
        let duration = ceil((branchTime + Double(longest) + 0.65)*60)/60
        let frameCount = Int((duration*60).rounded())
        let previewOnly = env["EIGHT_BALL_PREVIEW"] == "1" || env["TEST_RUNNER_EIGHT_BALL_PREVIEW"] == "1"
        let writer = previewOnly ? nil : try VideoWriter(url: dir.appendingPathComponent("00-eight-ball-15deg-silent.mp4"), size: size, fps: 60)
        // Freeze the original setup annotations; moving balls must not redefine the 15-degree shot.
        let targetNode = try XCTUnwrap(scene.allBallNodes["_8"])
        // A single target from the first simulation; only the eight cue balls are compared.
        var trailNodes: [SCNNode] = []
        var frameRecords: [[String: Any]] = []
        let sampleFrames = Set([0, 30, Int((leadIn-0.03)*60), Int((branchTime-0.02)*60), Int((branchTime+0.08)*60), 100, frameCount/2, frameCount-1])
        let renderFrames = previewOnly ? sampleFrames.sorted() : Array(0..<frameCount)
        for frame in renderFrames {
            try autoreleasepool {
                let t = Double(frame)/60
                let elapsed = Float(max(0, t-leadIn))
                scene.clearResultNodes(nodes: &trailNodes)
                var positions: [[Float]] = []
                var visible: [Bool] = []
                let afterContact = Float(max(0,t-branchTime))
                for (index, track) in tracks.enumerated() {
                    let time = t < branchTime ? min(track.contact,elapsed) : min(track.end,track.contact+afterContact)
                    track.node.isHidden = t < branchTime ? index != 0 : afterContact >= track.end-track.contact
                    visible.append(!track.node.isHidden)
                    let state = try XCTUnwrap(track.playback.stateAt(ballName: ShotInput.cueBallName, time: time))
                    track.node.position = state.position
                    // Integrate recorded angular velocity from strike using fixed absolute substeps.
                    var pose = BallSpinIntegrator.identityOrientation
                    let steps = Int(ceil(Double(time)*240))
                    if steps > 0 {
                        for k in 0..<steps {
                            let a = Float(k)/240
                            let b = min(time, Float(k+1)/240)
                            let s = try XCTUnwrap(track.playback.stateAt(ballName: ShotInput.cueBallName, time: (a+b)/2))
                            pose = simd_normalize(BallSpinIntegrator.delta(angularVelocity:s.angularVelocity, dt:b-a)*pose)
                        }
                    }
                    track.node.simdOrientation = pose
                    positions.append([state.position.x,state.position.y,state.position.z])
                    let count = Int(ceil(Double(time-track.contact)*120))
                    if count > 0 {
                        var points: [SCNVector3] = []
                        for k in 0...count {
                            let sampleTime = min(time, track.contact+Float(k)/120)
                            points.append(try XCTUnwrap(track.playback.stateAt(ballName:ShotInput.cueBallName,time:sampleTime)).position)
                        }
                        scene.addDashedPolyline(points, color:SeparationAngleAtlasGeometry.trackColor(at:index),
                            radius:TrajectoryStyle.lineMain, dash:0.018, gap:0.002, placement:.table, into:&trailNodes)
                    }
                }
                let first = tracks[0]
                let objectTime = elapsed
                if let state = first.playback.stateAt(ballName: ShotInput.targetBallName, time: objectTime) {
                    targetNode.position = state.position
                    targetNode.opacity = first.playback.collectionOpacity(ballName: ShotInput.targetBallName, time: objectTime) ?? (first.playback.recorder.isBallPocketed(ShotInput.targetBallName, at: Double(objectTime)) ? 0 : 1)
                }
                let strokeTime = max(0,t-strokeStart)
                let pull = t < leadIn ? CueStroke.pullBack(at:strokeTime,velocity:3) : CueStroke.followThrough(at:Double(elapsed),endPull:endPull)
                scene.cueStick?.update(cueBallPosition:strike,aimDirection:aimDirection,pullBack:pull,elevation:elevation,tipInset:tipInset)
                scene.cueStick?.show()
                let fadeStart = CueStroke.followThroughDuration + CueStroke.exportFollowThroughHold
                let cueOpacity = t < leadIn ? 1.0 : max(0,1-(Double(elapsed)-fadeStart)/0.15)
                scene.cueStick?.rootNode.opacity = CGFloat(min(1,cueOpacity))
                if t < branchTime { XCTAssertEqual(visible.filter { $0 }.count,1) }
                for (index,track) in tracks.enumerated() where t >= branchTime+Double(track.end-track.contact) {
                    XCTAssertFalse(visible[index])
                }
                labels.update(scene: scene, in: labelView)
                XCTAssertEqual(cameraNode.simdTransform, cameraTransform)
                SCNTransaction.flush()
                if frame == renderFrames.first { _ = renderer.snapshot(atTime:t,with:size,antialiasingMode:.multisampling4X) }
                let shot = renderer.snapshot(atTime:t,with:size,antialiasingMode:.multisampling4X)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                let image = UIGraphicsImageRenderer(size:size,format:format).image { context in
                    UIColor.black.setFill(); context.fill(CGRect(origin:.zero,size:size))
                    shot.draw(in:CGRect(origin:.zero,size:size))
                    let cg = context.cgContext
                    cg.scaleBy(x:size.width/1080,y:size.width/1080)
                    cg.saveGState(); cg.scaleBy(x:3,y:3)
                    for layer in labelView.layer.sublayers ?? [] {
                        guard let shape = layer as? CAShapeLayer, shape.name == "angleDiagram.arc", !shape.isHidden, let path = shape.path else { continue }
                        cg.addPath(path); cg.setStrokeColor(shape.strokeColor ?? UIColor.white.cgColor)
                        cg.setLineWidth(shape.lineWidth); cg.setLineCap(.round); cg.strokePath()
                    }
                    let angleLabels = labelView.subviews.compactMap { $0 as? UILabel }.filter { $0.accessibilityIdentifier == "angleDiagram.label.0" }
                    XCTAssertEqual(angleLabels.count, 1)
                    for label in angleLabels {
                        XCTAssertEqual(label.text, "15°")
                        cg.saveGState(); cg.translateBy(x:label.frame.minX,y:label.frame.minY)
                        label.layer.render(in:cg); cg.restoreGState()
                    }
                    cg.restoreGState()
                    let spins = SeparationAngleAtlasGeometry.spinYLevels()
                    let legendOffset:CGFloat = is3D ? 464 : 0
                    for index in 0..<8 {
                        let x = CGFloat(175+index*96)
                        UIColor.white.setFill(); UIBezierPath(ovalIn:CGRect(x:x,y:36+legendOffset,width:55,height:55)).fill()
                        SeparationAngleAtlasGeometry.trackColor(at:index).setFill()
                        UIBezierPath(ovalIn:CGRect(x:x+21,y:57+legendOffset-CGFloat(spins[index])*27.5,width:13,height:13)).fill()
                    }
                    for (text,x) in [("高",CGFloat(100)),("低",CGFloat(960))] {
                        (text as NSString).draw(at:CGPoint(x:x,y:47+legendOffset),withAttributes:[.font:UIFont.systemFont(ofSize:30,weight:.semibold),.foregroundColor:UIColor.white])
                    }
                }
                if sampleFrames.contains(frame) { try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("frames/frame-\(frame).png")) }
                if let writer { try writer.append(XCTUnwrap(image.cgImage)) }
                frameRecords.append(["frame":frame,"time":t,"cuePositions":positions,"visible":visible,"cuePullBack":pull,"cueOpacity":min(1,cueOpacity)])
            }
            if frame % 30 == 0 { print("EIGHT_BALL frame \(frame)/\(frameCount)") }
            try await Task.sleep(nanoseconds:1_000_000)
        }
        if let writer { try await writer.finish() }
        let manifest: [String:Any] = ["cutAngle":15,"centerDistanceM":0.60,"cueStickSpeedMPS":3,
            "width":1080,"height":1920,"fps":60,"frameCount":frameCount,"duration":duration,
            "playbackSpeed":1,"leadIn":leadIn, "branchTime":branchTime, "referenceTrack":0, "synchronization":"singleIncomingThenContactAligned", "cueStrokeDuration":CueStroke.totalDuration(velocity:3),"tracks":ledger,"frames":frameRecords]
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent(previewOnly ? "preview.json" : "manifest.json"))
        print("EIGHT_BALL COMPLETE duration=\(duration) frames=\(frameCount) preview=\(previewOnly)")
    }
}
