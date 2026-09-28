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

/// V012 opt-in still: production physics and scene, colors encode impact thickness.
@MainActor
final class PocketThicknessPreviewTests: XCTestCase {
    func testPreview() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["POCKET_THICKNESS_DIR"] ?? env["TEST_RUNNER_POCKET_THICKNESS_DIR"] else {
            throw XCTSkip("Opt-in pocket-thickness preview")
        }
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let scene = AngleTrainingScene()
        scene.setupScene(); scene.setupVisualizationNodes()
        XCTAssertTrue(scene.applyTableStyle(.charcoal, showsSights: true))
        scene.applyClothColor(.green); scene.hideAllBalls(); scene.hideAllVisualization()
        scene.hideCueStick()
        let r = AngleSceneCalculator.ballRadius, y = scene.surfaceY + r
        struct Track { let thickness: Float; let aim: SCNVector3; let pred: ShotPrediction }
        var selected: [Track] = []
        var cue = SCNVector3Zero, target = SCNVector3Zero
        let speed: Float = 2.4
        var search: [[String: Any]] = []
        // XZ metres, Y up. Portrait bottom-left is pocket_0 (-X,-Z).
        // Keep the accepted object position; cue is shifted toward the screen-left long rail.
        // Only direct object pots and complete, non-scratch cue paths qualify.
        for tx: Float in [-1.24] {
            for tz: Float in [-0.60] {
                for cz: Float in [-0.56] {
                    let c = SCNVector3(-0.25, y, cz), t = SCNVector3(tx, y, tz)
                    let delta = SIMD2<Float>(t.x-c.x, t.z-c.z), distance = simd_length(delta)
                    let base = atan2(delta.y, delta.x)
                    var valid: [Track] = []
                    for percent in stride(from: 10, through: 90, by: 1) {
                        let h = Float(percent)/100
                        let angle = base - asin(2*r*(1-h)/distance)
                        let aim = SCNVector3(cos(angle), 0, sin(angle))
                        let pred = ShotPredictor.simulateFree(cueBall:c, aimDir:aim, velocity:speed,
                            spinX:0, spinY:0, surfaceY:scene.surfaceY,
                            balls:[ObstacleBall(name:ShotInput.targetBallName,position:t)], maxTime:30)
                        let pot = pred.events.contains { e in
                            if case .pocket(let ball, let pocket) = e.kind {
                                return ball == ShotInput.targetBallName && pocket == "pocket_0"
                            }; return false
                        }
                        let cueRails = pred.events.filter { if case .ballCushion(let ball) = $0.kind { return ball == ShotInput.cueBallName }; return false }.count
                        let objectRails = pred.events.filter { if case .ballCushion(let ball) = $0.kind { return ball == ShotInput.targetBallName }; return false }.count
                        let validShot = pot && !pred.cuePocketed && pred.hasFinalTableState && cueRails > 0 && objectRails == 0
                        search.append(["target":[tx,tz],"cue":[c.x,cz],"thickness":h,"valid":validShot,
                            "pot":pot,"cueScratch":pred.cuePocketed,"termination":String(describing:pred.termination)])
                        if validShot { valid.append(Track(thickness:h,aim:aim,pred:pred)) }
                    }
                    if valid.count >= 8 && (valid.last!.thickness-valid.first!.thickness) > (selected.last?.thickness ?? 0)-(selected.first?.thickness ?? 0) {
                        selected = (0..<8).map { valid[Int((Double($0)*Double(valid.count-1)/7).rounded())] }
                        cue = c; target = t
                    }
                }
            }
        }
        try JSONSerialization.data(withJSONObject:search, options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("search.json"))
        XCTAssertEqual(selected.count, 8)
        guard selected.count == 8 else { throw NSError(domain:"PocketPreviewNoEightTracks",code:1) }
        scene.showBall(key:"cueBall",scenePosition:cue)
        scene.showBall(key:"_8",scenePosition:target); scene.setCurrentTargetNumber(8)
        var nodes: [SCNNode] = []
        var records: [[String:Any]] = []
        for (i, track) in selected.enumerated() {
            let pred = track.pred, color = SeparationAngleAtlasGeometry.trackColor(at:i)
            let recorder = try XCTUnwrap(pred.recorder)
            let bb = try XCTUnwrap(SeparationAngleAtlasGeometry.firstBallBallEvent(in:pred.events))
            let playback = TrajectoryPlayback(recorder:recorder,surfaceY:y)
            let contact = try XCTUnwrap(playback.stateAt(ballName:ShotInput.cueBallName,time:bb.time)).position
            let obj = try XCTUnwrap(playback.stateAt(ballName:ShotInput.targetBallName,time:bb.time)).position
            let normal = simd_normalize(SIMD2<Float>(obj.x-contact.x,obj.z-contact.z))
            let dot = max(0,min(1,normal.x*track.aim.x+normal.y*track.aim.z))
            let measured = 1-sqrt(max(0,1-dot*dot))
            XCTAssertEqual(measured,track.thickness,accuracy:0.002)
            let count = Int(ceil((pred.duration-bb.time)*120))
            let points = try (0...count).map { k in
                try XCTUnwrap(playback.stateAt(ballName:ShotInput.cueBallName,
                    time:min(pred.duration,bb.time+Float(k)/120))).position
            }
            scene.addDashedPolyline(points,color:color,radius:0.0026,dash:0.035,gap:0.004,placement:.table,into:&nodes)
            let end = try XCTUnwrap(points.last)
            let dotNode = SCNNode(geometry:SCNSphere(radius:0.010))
            dotNode.geometry?.firstMaterial?.diffuse.contents = color
            dotNode.geometry?.firstMaterial?.lightingModel = .constant
            dotNode.position = SCNVector3(end.x,scene.surfaceY+0.010,end.z)
            scene.rootNode.addChildNode(dotNode)
            records.append(["index":i,"thickness":track.thickness,"measuredThickness":measured,
                "cueCushionCount":pred.events.filter { if case .ballCushion(let ball) = $0.kind { return ball == ShotInput.cueBallName }; return false }.count,"targetPocket":"pocket_0","settled":pred.hasFinalTableState,
                "end":[end.x,end.z],"duration":pred.duration,"contact":[contact.x,contact.z],
                "aim":[track.aim.x,track.aim.z],
                "path":points.map { [$0.x,$0.z] }])
        }
        let mid = selected[4]
        scene.addDashedPolyline([cue,try XCTUnwrap(mid.pred.firstContact)],color:UIColor.white.withAlphaComponent(0.55),
            radius:0.0012,dash:0.025,gap:0.014,placement:.table,into:&nodes)
        scene.setCameraMode(.perspective3D,animated:false)
        let cameraNode = try XCTUnwrap(scene.cameraNode), camera = try XCTUnwrap(scene.cameraNode?.camera)
        camera.usesOrthographicProjection=false; camera.fieldOfView=40; camera.projectionDirection = .vertical
        camera.zNear=0.01;camera.zFar=100;camera.wantsExposureAdaptation=false
        let elevation:Float=55 * .pi/180, distance:Float=4.6
        let focus=SCNVector3(0,scene.surfaceY,0)
        cameraNode.position=SCNVector3(-distance*cos(elevation),focus.y+distance*sin(elevation),0)
        cameraNode.look(at:focus,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        SCNTransaction.flush()
        let renderer=SCNRenderer(device:nil,options:nil)
        renderer.scene=scene;renderer.pointOfView=cameraNode;renderer.delegate=scene.contactOcclusion
        renderer.autoenablesDefaultLighting=false
        let size=CGSize(width:1440,height:2560), stageSize=CGSize(width:1440,height:1900)
        _=renderer.snapshot(atTime:0,with:stageSize,antialiasingMode:.multisampling4X)
        let shot=renderer.snapshot(atTime:0,with:stageSize,antialiasingMode:.multisampling4X)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        let image=UIGraphicsImageRenderer(size:size,format:format).image { context in
            UIColor(red:0.035,green:0.043,blue:0.05,alpha:1).setFill();context.fill(CGRect(origin:.zero,size:size))
            shot.draw(in:CGRect(x:0,y:390,width:1440,height:1900))
            func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ font:CGFloat,_ color:UIColor = .white,_ weight:UIFont.Weight = .medium) {
                (s as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:UIFont.systemFont(ofSize:font,weight:weight),.foregroundColor:color])
            }
            text("袋口走位图谱",88,80,66,.white,.semibold)
            text("同一个袋口球 · 不同厚度，不同走位",90,177,32,UIColor(white:0.7,alpha:1))
            text("薄",90,296,28,UIColor(white:0.7,alpha:1))
            text("厚",1305,296,28,UIColor(white:0.7,alpha:1))
            for (i,track) in selected.enumerated() {
                let x=CGFloat(176+i*145), color=SeparationAngleAtlasGeometry.trackColor(at:i)
                let d:CGFloat=56, offset=d*CGFloat(1-track.thickness)
                UIColor(white:0.95,alpha:1).setFill()
                UIBezierPath(ovalIn:CGRect(x:x,y:267,width:d,height:d)).fill()
                color.withAlphaComponent(0.85).setFill()
                UIBezierPath(ovalIn:CGRect(x:x+offset,y:267,width:d,height:d)).fill()
                text(String(format:"%.0f%%",track.thickness*100),x+2,345,28,color,.semibold)
            }
            text("杆速",90,2280,31,UIColor(white:0.65,alpha:1))
            text(String(format:"%.1f",speed),90,2327,74,.white,.semibold)
            text("m/s",228,2365,28,UIColor(white:0.65,alpha:1))
            text("中杆 · 不加塞",545,2293,35)
            text("八档厚度，八号均进左下底袋",545,2360,30,UIColor(white:0.70,alpha:1))
            text("彩色圆点为母球停点",545,2410,30,UIColor(white:0.70,alpha:1))
        }
        try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("preview.png"))
        try JSONSerialization.data(withJSONObject:["speedMPS":speed,"spinX":0,"spinY":0,
            "cue":[cue.x,cue.y,cue.z],"target":[target.x,target.y,target.z],"tracks":records,
            "width":1440,"height":2560,"kind":"staticPreview"],options:[.prettyPrinted,.sortedKeys])
            .write(to:dir.appendingPathComponent("manifest.json"))
        print("POCKET_PREVIEW eight tracks verified; cue=\(cue) target=\(target), thicknesses=\(selected.map{$0.thickness})")
    }
}

extension PocketThicknessPreviewTests {
    func testSpeedProbe() throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["POCKET_SPEED_DIR"] ?? env["TEST_RUNNER_POCKET_SPEED_DIR"] else { throw XCTSkip("Opt-in speed probe") }
        let dir = URL(fileURLWithPath:path)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        let y:Float = 0.8, r = AngleSceneCalculator.ballRadius
        let cue = SCNVector3(-0.25,y+r,-0.56), target = SCNVector3(-1.24,y+r,-0.60)
        let thicknesses:[Float] = [0.12,0.17,0.21,0.24,0.27,0.30,0.35,0.39]
        let delta = SIMD2<Float>(target.x-cue.x,target.z-cue.z), length = simd_length(delta)
        var rows:[[String:Any]] = []
        for tick in 15...150 {
            let speed = Float(tick)/50
            for (index,h) in thicknesses.enumerated() {
                let a = atan2(delta.y,delta.x)-asin(2*r*(1-h)/length)
                let p = ShotPredictor.simulateFree(cueBall:cue,aimDir:SCNVector3(cos(a),0,sin(a)),velocity:speed,
                    spinX:0,spinY:0,surfaceY:y,balls:[ObstacleBall(name:ShotInput.targetBallName,position:target)],maxTime:30)
                let pot = p.events.contains { if case .pocket(let ball,let pocket) = $0.kind { return ball == ShotInput.targetBallName && pocket == "pocket_0" }; return false }
                let rails = p.events.filter { if case .ballCushion(let ball) = $0.kind { return ball == ShotInput.cueBallName }; return false }.count
                let end = p.finalPositions[ShotInput.cueBallName] ?? SCNVector3Zero
                rows.append(["speed":speed,"index":index,"thickness":h,"pot":pot,"scratch":p.cuePocketed,
                    "rails":rails,"settled":p.hasFinalTableState,"end":[end.x,end.z],"duration":p.duration])
            }
            if tick % 10 == 0 { print("POCKET_SPEED probe \(speed)") }
        }
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("probe.json"))
        XCTAssertEqual(rows.count,136*8)
    }
}

extension PocketThicknessPreviewTests {
    func testExportSpeed() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["POCKET_SPEED_DIR"] ?? env["TEST_RUNNER_POCKET_SPEED_DIR"] else { throw XCTSkip("Opt-in speed video") }
        let preview = (env["POCKET_SPEED_MODE"] ?? env["TEST_RUNNER_POCKET_SPEED_MODE"]) != "video"
        let dir = URL(fileURLWithPath:path)
        try FileManager.default.createDirectory(at:dir.appendingPathComponent("frames"),withIntermediateDirectories:true)
        let scene = AngleTrainingScene(); scene.setupScene(); scene.setupVisualizationNodes()
        XCTAssertTrue(scene.applyTableStyle(.charcoal,showsSights:true)); scene.applyClothColor(.green)
        scene.hideAllBalls();scene.hideAllVisualization();scene.hideCueStick()
        let r = AngleSceneCalculator.ballRadius, y = scene.surfaceY+r
        let cue = SCNVector3(-0.25,y,-0.56), target = SCNVector3(-1.24,y,-0.60)
        let thicknesses:[Float] = [0.12,0.17,0.21,0.24,0.27,0.30,0.35,0.39]
        let delta=SIMD2<Float>(target.x-cue.x,target.z-cue.z), length=simd_length(delta)
        let aims=thicknesses.map { h -> SCNVector3 in
            let a=atan2(delta.y,delta.x)-asin(2*r*(1-h)/length)
            return SCNVector3(cos(a),0,sin(a))
        }
        struct Track { let points:[SCNVector3]; let scratch:Bool; let end:SCNVector3; let rails:Int }
        var samples:[[Track]]=[]
        var ledger:[[String:Any]]=[]
        let low:Float=0.52, high:Float=3.0, rampSteps=840, frames=1080
        for step in 0...rampSteps {
            let speed=low+(high-low)*Float(step)/Float(rampSteps)
            var tracks:[Track]=[]
            var rows:[[String:Any]]=[]
            for (index,aim) in aims.enumerated() {
                let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:aim,velocity:speed,spinX:0,spinY:0,
                    surfaceY:scene.surfaceY,balls:[ObstacleBall(name:ShotInput.targetBallName,position:target)],maxTime:30)
                let objectPot=p.events.first { if case .pocket(let ball,let pocket)=$0.kind { return ball == ShotInput.targetBallName && pocket == "pocket_0" };return false }
                guard p.hasFinalTableState, let objectPot else {
                    try JSONSerialization.data(withJSONObject:["step":step,"speed":speed,"index":index,
                        "settled":p.hasFinalTableState,"objectPot":objectPot != nil],options:[.prettyPrinted])
                        .write(to:dir.appendingPathComponent("preflight-failure.json"))
                    XCTFail("Incomplete or missed object: step \(step), track \(index), speed \(speed)")
                    throw NSError(domain:"PocketSpeedPreflight",code:1)
                }
                let recorder=try XCTUnwrap(p.recorder)
                let playback=TrajectoryPlayback(recorder:recorder,surfaceY:y)
                let bb=try XCTUnwrap(SeparationAngleAtlasGeometry.firstBallBallEvent(in:p.events))
                let scratchEvent=p.events.first { if case .pocket(let ball,_)=$0.kind { return ball == ShotInput.cueBallName };return false }
                let endTime=scratchEvent?.time ?? p.duration
                let contact=try XCTUnwrap(playback.stateAt(ballName:ShotInput.cueBallName,time:bb.time)).position
                let objectAtContact=try XCTUnwrap(playback.stateAt(ballName:ShotInput.targetBallName,time:bb.time)).position
                let n=simd_normalize(SIMD2<Float>(objectAtContact.x-contact.x,objectAtContact.z-contact.z))
                let cosine=max(0,min(1,n.x*aim.x+n.y*aim.z))
                let measured=1-sqrt(max(0,1-cosine*cosine))
                // The fixed input is geometric overlap of the initial aim ray and target.
                let geometricThickness=1-abs(delta.x*aim.z-delta.y*aim.x)/(2*r)
                XCTAssertEqual(geometricThickness,thicknesses[index],accuracy:0.00001)
                // Event contact positions include the engine's numerical contact adjustment.
                // Verify the displayed whole-percent label, and retain the unrounded measurement.
                XCTAssertEqual(Int((measured*100).rounded()),Int((thicknesses[index]*100).rounded()))
                let rails=p.events.filter { if case .ballCushion(let ball)=$0.kind {return ball == ShotInput.cueBallName};return false }
                XCTAssertFalse(rails.isEmpty,"Every shown shot reaches a cushion")
                var times=Set((0...Int(ceil((endTime-bb.time)*60))).map {min(endTime,bb.time+Float($0)/60)})
                for event in rails where event.time >= bb.time && event.time <= endTime {times.insert(event.time)}
                times.insert(endTime)
                let points=try times.sorted().map { try XCTUnwrap(playback.stateAt(ballName:ShotInput.cueBallName,time:$0)).position }
                let end=try XCTUnwrap(points.last)
                tracks.append(Track(points:points,scratch:p.cuePocketed,end:end,rails:rails.count))
                var row:[String:Any]=["index":index,"thickness":thicknesses[index],"measuredThickness":measured,"geometricThickness":geometricThickness,
                    "targetPocket":"pocket_0","objectPotTime":objectPot.time,"scratch":p.cuePocketed,
                    "rails":rails.count,"settled":true,"end":[end.x,end.z],"contact":[contact.x,contact.z],"duration":endTime]
                if let scratchEvent, case .pocket(_,let pocket)=scratchEvent.kind {row["cuePocket"]=pocket}
                rows.append(row)
            }
            samples.append(tracks);ledger.append(["step":step,"speedMPS":speed,"tracks":rows])
            if step % 60 == 0 {print("POCKET_SPEED preflight \(step)/\(rampSteps)");try await Task.sleep(nanoseconds:1_000_000)}
        }
        let manifest:[String:Any]=["lowMPS":low,"highMPS":high,"width":1440,"height":2560,"fps":60,"frameCount":frames,
            "duration":18,"rampStartFrame":60,"rampEndFrame":900,"coverageStartFrame":960,
            "cue":[cue.x,cue.y,cue.z],"target":[target.x,target.y,target.z],"spinX":0,"spinY":0,
            "scratchPolicy":"showTruePathAndCrossAtPocket;excludeFromTableRestCloud","samples":ledger]
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("manifest.json"))
        scene.showBall(key:"cueBall",scenePosition:cue);scene.showBall(key:"_8",scenePosition:target);scene.setCurrentTargetNumber(8)
        scene.setCameraMode(.perspective3D,animated:false)
        let cameraNode=try XCTUnwrap(scene.cameraNode),camera=try XCTUnwrap(cameraNode.camera)
        camera.usesOrthographicProjection=false;camera.fieldOfView=40;camera.projectionDirection = .vertical
        camera.zNear=0.01;camera.zFar=100;camera.wantsExposureAdaptation=false
        let elevation:Float=55 * .pi/180,distance:Float=4.6,focus=SCNVector3(0,scene.surfaceY,0)
        cameraNode.position=SCNVector3(-distance*cos(elevation),focus.y+distance*sin(elevation),0)
        cameraNode.look(at:focus,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        let transform=cameraNode.simdTransform
        let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=cameraNode
        renderer.delegate=scene.contactOcclusion;renderer.autoenablesDefaultLighting=false
        let size=CGSize(width:1440,height:2560),stageSize=CGSize(width:1440,height:1900)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        var nodes:[SCNNode]=[],incoming:[SCNNode]=[]
        scene.addDashedPolyline([cue,samples[0][4].points[0]],color:UIColor.white.withAlphaComponent(0.55),
            radius:0.0012,dash:0.025,gap:0.014,placement:.table,into:&incoming)
        func dotNode(_ point:SCNVector3,_ color:UIColor,_ radius:CGFloat)->SCNNode {
            let node=SCNNode(geometry:SCNSphere(radius:radius))
            node.geometry?.firstMaterial?.diffuse.contents=color;node.geometry?.firstMaterial?.lightingModel = .constant
            node.position=SCNVector3(point.x,scene.surfaceY+Float(radius),point.z)
            scene.rootNode.addChildNode(node);return node
        }
        let endNodes=(0..<8).map {dotNode(samples[0][$0].end,SeparationAngleAtlasGeometry.trackColor(at:$0),0.010)}
        // Uniform speed samples only; no interpolation of physics or invented reachable positions.
        let coverageRoot=SCNNode();scene.rootNode.addChildNode(coverageRoot)
        for step in stride(from:0,through:rampSteps,by:6) {
            for (index,track) in samples[step].enumerated() where !track.scratch {
                let node=dotNode(track.end,SeparationAngleAtlasGeometry.trackColor(at:index),0.0048)
                node.removeFromParentNode();coverageRoot.addChildNode(node)
            }
        }
        coverageRoot.opacity=0
        let writer=preview ? nil : try VideoWriter(url:dir.appendingPathComponent("pocket-thickness-speed-2k60-silent.mp4"),size:size,fps:60,averageBitRate:24_000_000)
        let keyframes=Set([0,150,300,360,420,540,660,780,900,1020,1079])
        let renderFrames=preview ? keyframes.sorted() : Array(0..<frames)
        for frame in renderFrames {
            try autoreleasepool {
                let step=max(0,min(rampSteps,frame-60)),speed=low+(high-low)*Float(step)/Float(rampSteps)
                let tracks=samples[step]
                let coverage=CGFloat(max(0,min(1,Double(frame-960)/45)))
                coverageRoot.opacity=coverage*0.65
                scene.clearResultNodes(nodes:&nodes)
                for (i,track) in tracks.enumerated() {
                    let color=SeparationAngleAtlasGeometry.trackColor(at:i)
                    scene.addDashedPolyline(track.points,color:color,radius:0.0026,dash:0.035,gap:0.004,placement:.table,into:&nodes)
                    endNodes[i].isHidden=track.scratch
                    endNodes[i].position=SCNVector3(track.end.x,scene.surfaceY+0.010,track.end.z)
                    endNodes[i].opacity=1-coverage*0.60
                    if track.scratch {
                        let e=track.end,d:Float=0.020
                        scene.addDashedPolyline([SCNVector3(e.x-d,y,e.z-d),SCNVector3(e.x+d,y,e.z+d)],color:color,
                            radius:0.0038,dash:1,gap:0,placement:.table,into:&nodes)
                        scene.addDashedPolyline([SCNVector3(e.x-d,y,e.z+d),SCNVector3(e.x+d,y,e.z-d)],color:color,
                            radius:0.0038,dash:1,gap:0,placement:.table,into:&nodes)
                    }
                }
                for node in nodes {node.opacity=1-coverage*0.84}
                XCTAssertEqual(cameraNode.simdTransform,transform)
                SCNTransaction.flush()
                if frame == renderFrames.first {_=renderer.snapshot(atTime:0,with:stageSize,antialiasingMode:.multisampling4X)}
                let shot=renderer.snapshot(atTime:Double(frame)/60,with:stageSize,antialiasingMode:.multisampling4X)
                let image=UIGraphicsImageRenderer(size:size,format:format).image { context in
                    UIColor(red:0.035,green:0.043,blue:0.05,alpha:1).setFill();context.fill(CGRect(origin:.zero,size:size))
                    shot.draw(in:CGRect(x:0,y:390,width:1440,height:1900))
                    func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ font:CGFloat,_ color:UIColor = .white,_ weight:UIFont.Weight = .medium) {
                        (s as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:UIFont.systemFont(ofSize:font,weight:weight),.foregroundColor:color])
                    }
                    text("袋口走位图谱",88,80,66,.white,.semibold)
                    text(coverage>0 ? "不同厚度 × 不同杆速 · 台面停点分布" : "同一个袋口球 · 不同厚度，不同走位",90,177,32,UIColor(white:0.7,alpha:1))
                    text("薄",90,296,28,UIColor(white:0.7,alpha:1));text("厚",1305,296,28,UIColor(white:0.7,alpha:1))
                    for (i,h) in thicknesses.enumerated() {
                        let x=CGFloat(176+i*145),color=SeparationAngleAtlasGeometry.trackColor(at:i),d:CGFloat=56
                        UIColor(white:0.95,alpha:1).setFill();UIBezierPath(ovalIn:CGRect(x:x,y:267,width:d,height:d)).fill()
                        color.withAlphaComponent(0.85).setFill();UIBezierPath(ovalIn:CGRect(x:x+d*CGFloat(1-h),y:267,width:d,height:d)).fill()
                        text(String(format:"%.0f%%",h*100),x+2,345,28,color,.semibold)
                    }
                    text("杆速",90,2280,31,UIColor(white:0.65,alpha:1))
                    text(coverage>0 ? "全程" : String(format:"%.2f",speed),90,2327,74,.white,.semibold)
                    text(coverage>0 ? "0.52–3.00 m/s" : "m/s",90,2430,28,UIColor(white:0.65,alpha:1))
                    text("中杆 · 不加塞",545,2293,35)
                    let scratches=tracks.enumerated().filter{$0.element.scratch}.map{String(format:"%.0f%%",thicknesses[$0.offset]*100)}
                    text(coverage>0 ? "各杆速的真实停点 · 落袋不计入" : "八档厚度，八号均进左下底袋",545,2360,30,UIColor(white:0.70,alpha:1))
                    text(coverage>0 ? "颜色对应厚度 · 每个点对应一杆" : (scratches.isEmpty ? "● 母球停点   × 母球落袋" : "母球落袋："+scratches.joined(separator:"、")),
                        545,2410,30,scratches.isEmpty || coverage>0 ? UIColor(white:0.70,alpha:1) : UIColor(red:1,green:0.65,blue:0.3,alpha:1))
                }
                if keyframes.contains(frame) {try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("frames/frame-\(frame).png"))}
                if let writer {try writer.append(XCTUnwrap(image.cgImage))}
            }
            if frame % 30 == 0 {print("POCKET_SPEED render \(frame)/\(frames)")}
            try await Task.sleep(nanoseconds:1_000_000)
        }
        if let writer {try await writer.finish()}
        print("POCKET_SPEED COMPLETE preview=\(preview) \(frames) frames / 18s; \(samples.count*8) verified shots")
    }
}

extension PocketThicknessPreviewTests {
    /// Screen-space scratch labels remain visible over pocket openings, outside cloth clipping.
    func testProjectScratchMarkers() throws {
        let env=ProcessInfo.processInfo.environment
        guard let path=env["POCKET_SPEED_DIR"] ?? env["TEST_RUNNER_POCKET_SPEED_DIR"] else {throw XCTSkip("Opt-in markers")}
        let dir=URL(fileURLWithPath:path)
        let manifest=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:dir.appendingPathComponent("manifest.json"))) as? [String:Any])
        let cue=try XCTUnwrap(manifest["cue"] as? [Double])
        let surface=Float(cue[1])-AngleSceneCalculator.ballRadius
        let scene=SCNScene(),node=SCNNode();node.camera=SCNCamera();scene.rootNode.addChildNode(node)
        let camera=try XCTUnwrap(node.camera);camera.fieldOfView=40;camera.projectionDirection = .vertical
        camera.zNear=0.01;camera.zFar=100;camera.wantsExposureAdaptation=false
        let e:Float=55 * .pi/180,d:Float=4.6,focus=SCNVector3(0,surface,0)
        node.position=SCNVector3(-d*cos(e),surface+d*sin(e),0)
        node.look(at:focus,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=node
        SCNTransaction.flush()
        _=renderer.snapshot(atTime:0,with:CGSize(width:1440,height:1900),antialiasingMode:.none)
        let center=renderer.projectPoint(focus)
        XCTAssertEqual(center.x,720,accuracy:0.1);XCTAssertEqual(center.y,950,accuracy:0.1)
        let samples=try XCTUnwrap(manifest["samples"] as? [[String:Any]])
        var markers:[[String:Any]]=[]
        for sample in samples {
            let step=try XCTUnwrap(sample["step"] as? Int)
            let tracks=try XCTUnwrap(sample["tracks"] as? [[String:Any]])
            for track in tracks where track["scratch"] as? Bool == true {
                let end=try XCTUnwrap(track["end"] as? [Double])
                let point=renderer.projectPoint(SCNVector3(Float(end[0]),surface+0.01,Float(end[1])))
                XCTAssertTrue(point.x.isFinite && point.y.isFinite)
                markers.append(["frame":step+60,"index":try XCTUnwrap(track["index"] as? Int),
                    "x":point.x,"y":390+1900-point.y])
            }
        }
        try JSONSerialization.data(withJSONObject:markers,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("scratch-markers.json"))
        XCTAssertFalse(markers.isEmpty)
    }
}

extension PocketThicknessPreviewTests {
    func testPositionProbe() throws {
        let env=ProcessInfo.processInfo.environment
        guard let path=env["POCKET_POSITION_DIR"] ?? env["TEST_RUNNER_POCKET_POSITION_DIR"] else {throw XCTSkip("Opt-in position probe")}
        let dir=URL(fileURLWithPath:path), r=AngleSceneCalculator.ballRadius, y:Float=0.8
        let target=SCNVector3(-1.24,y+r,-0.60)
        var rows:[[String:Any]]=[]
        for step in 0...12 {
            let cue=SCNVector3(-0.25,y+r,-0.56+1.12*Float(step)/12)
            let delta=SIMD2<Float>(target.x-cue.x,target.z-cue.z),length=simd_length(delta)
            var valid:[Int]=[], direct:[Int]=[]
            for signedOffset in -99...99 {
                let a=atan2(delta.y,delta.x)+asin(2*r*Float(signedOffset)/100/length)
                let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:SCNVector3(cos(a),0,sin(a)),velocity:1.5,spinX:0,spinY:0,surfaceY:y,
                    balls:[ObstacleBall(name:ShotInput.targetBallName,position:target)],maxTime:30,includePresentation:false)
                let pot=p.events.contains {if case .pocket(let ball,let pocket)=$0.kind {return ball == ShotInput.targetBallName && pocket == "pocket_0"};return false}
                if pot {valid.append(signedOffset)}
                let objectRails=p.events.filter {if case .ballCushion(let ball)=$0.kind {return ball == ShotInput.targetBallName};return false}.count
                let bb=SeparationAngleAtlasGeometry.firstBallBallEvent(in:p.events)
                let railFirst=p.events.contains {if case .ballCushion(let ball)=$0.kind {return ball == ShotInput.cueBallName && $0.time < (bb?.time ?? 100)};return false}
                if pot && objectRails == 0 && bb != nil && !railFirst {direct.append(signedOffset)}
            }
            rows.append(["step":step,"cueZ":cue.z,"validSignedOffsets":valid,"directSignedOffsets":direct])
            print("POSITION_PROBE \(step) direct: \(direct)")
        }
        try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("probe.json"))
    }
}

private struct PocketPositionTrack: Codable {
    let offset: Int
    let points: [[Float]]
    let end: [Float]
    let scratch: Bool
    let rails: Int
    let objectPotTime: Float
    let geometricThickness: Float
    let cuePocket: String?
}
private struct PocketPositionSample: Codable {
    let step: Int
    let cueZ: Float
    let validOffsets: [Int]
    let tracks: [PocketPositionTrack]
}

extension PocketThicknessPreviewTests {
    func testExportPosition() async throws {
        let env=ProcessInfo.processInfo.environment
        guard let path=env["POCKET_POSITION_DIR"] ?? env["TEST_RUNNER_POCKET_POSITION_DIR"] else {throw XCTSkip("Opt-in position video")}
        let preview=(env["POCKET_POSITION_MODE"] ?? env["TEST_RUNNER_POCKET_POSITION_MODE"]) != "video"
        let dir=URL(fileURLWithPath:path), cache=dir.appendingPathComponent("samples-complete.json")
        try FileManager.default.createDirectory(at:dir.appendingPathComponent("frames"),withIntermediateDirectories:true)
        let scene=AngleTrainingScene();scene.setupScene();scene.setupVisualizationNodes()
        XCTAssertTrue(scene.applyTableStyle(.charcoal,showsSights:true));scene.applyClothColor(.green)
        scene.hideAllBalls();scene.hideAllVisualization();scene.hideCueStick()
        let r=AngleSceneCalculator.ballRadius,y=scene.surfaceY+r,target=SCNVector3(-1.24,y,-0.60)
        let steps=720,frames=840
        func directPot(_ p:ShotPrediction)->ShotEvent? {
            guard let bb=SeparationAngleAtlasGeometry.firstBallBallEvent(in:p.events) else {return nil}
            let excluded=p.events.contains {e in
                if case .ballCushion(let ball)=e.kind {return ball == ShotInput.targetBallName || (ball == ShotInput.cueBallName && e.time < bb.time)}
                return false
            }
            if excluded {return nil}
            return p.events.first {if case .pocket(let ball,let pocket)=$0.kind {return ball == ShotInput.targetBallName && pocket == "pocket_0"};return false}
        }
        var budgetRetries:[[String:Any]]=[]
        func completeTrack(cue:SCNVector3,offset:Int,step:Int) throws -> PocketPositionTrack {
            let delta=SIMD2<Float>(target.x-cue.x,target.z-cue.z),length=simd_length(delta)
            func aim(_ offset:Int)->SCNVector3 {
                let a=atan2(delta.y,delta.x)+asin(2*r*Float(offset)/100/length)
                return SCNVector3(cos(a),0,sin(a))
            }
            let direction=aim(offset)
            var p=ShotPredictor.simulateFree(cueBall:cue,aimDir:direction,velocity:1.5,spinX:0,spinY:0,
                surfaceY:scene.surfaceY,balls:[ObstacleBall(name:ShotInput.targetBallName,position:target)],maxTime:30)
            if !p.hasFinalTableState {
                let reason=String(describing:p.termination)
                print("POCKET_POSITION retry step \(step), offset \(offset): \(reason)")
                p=ShotPredictor.simulateFree(cueBall:cue,aimDir:direction,velocity:1.5,spinX:0,spinY:0,
                    surfaceY:scene.surfaceY,balls:[ObstacleBall(name:ShotInput.targetBallName,position:target)],maxEvents:2000,maxTime:90)
                budgetRetries.append(["step":step,"offset":offset,"initialTermination":reason,"finalTermination":String(describing:p.termination),"duration":p.duration])
                try JSONSerialization.data(withJSONObject:budgetRetries,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("budget-retries.json"))
            }
            guard p.hasFinalTableState else {
                throw NSError(domain:"PocketPositionUnresolved",code:step)
            }
            let pot=try XCTUnwrap(directPot(p),"Full simulation disagrees at position \(step), offset \(offset)")
            let geometric=1-abs(delta.x*direction.z-delta.y*direction.x)/(2*r)
            XCTAssertEqual(geometric,1-Float(abs(offset))/100,accuracy:0.00002)
            let recorder=try XCTUnwrap(p.recorder),playback=TrajectoryPlayback(recorder:recorder,surfaceY:y)
            let bb=try XCTUnwrap(SeparationAngleAtlasGeometry.firstBallBallEvent(in:p.events))
            let scratch=p.events.first {if case .pocket(let ball,_)=$0.kind {return ball == ShotInput.cueBallName};return false}
            let endTime=scratch?.time ?? p.duration
            let rails=p.events.filter {if case .ballCushion(let ball)=$0.kind {return ball == ShotInput.cueBallName};return false}
            var times=Set((0...Int(ceil((endTime-bb.time)*60))).map{min(endTime,bb.time+Float($0)/60)})
            for event in rails where event.time >= bb.time && event.time <= endTime {times.insert(event.time)}
            times.insert(endTime)
            let points=try times.sorted().map {t -> [Float] in
                let v=try XCTUnwrap(playback.stateAt(ballName:ShotInput.cueBallName,time:t)).position
                XCTAssertTrue(v.x.isFinite && v.z.isFinite);return [v.x,v.y,v.z]
            }
            var pocket:String?
            if let scratch,case .pocket(_,let id)=scratch.kind {pocket=id}
            return PocketPositionTrack(offset:offset,points:points,end:try XCTUnwrap(points.last),scratch:p.cuePocketed,
                rails:rails.count,objectPotTime:pot.time,geometricThickness:geometric,cuePocket:pocket)
        }
        var substitutions:[[String:Any]]=[]
        func completeTracks(cue:SCNVector3,selected:[Int],valid:[Int],step:Int) throws -> [PocketPositionTrack] {
            var reserved=Set(selected),result:[PocketPositionTrack]=[]
            for original in selected {
                do {result.append(try completeTrack(cue:cue,offset:original,step:step))}
                catch let error as NSError where error.domain == "PocketPositionUnresolved" {
                    // Numerical non-convergence is not a scratch filter. Keep the target-pot range,
                    // and choose the closest distinct, complete sample on the same cut side.
                    let alternatives=valid.filter{!reserved.contains($0) && ($0<0) == (original<0)}.sorted {
                        let a=abs($0-original),b=abs($1-original);return a == b ? $0<$1 : a<b
                    }
                    var replacement:PocketPositionTrack?
                    for offset in alternatives {
                        do {replacement=try completeTrack(cue:cue,offset:offset,step:step);break}
                        catch let next as NSError where next.domain == "PocketPositionUnresolved" {continue}
                    }
                    guard let replacement else {throw error}
                    reserved.insert(replacement.offset);result.append(replacement)
                    substitutions.append(["step":step,"originalOffset":original,"replacementOffset":replacement.offset,
                        "reason":"cue pocket-jaw event limit; target direct-pot range retained; replacement chosen by nearest thickness, never scratch status"])
                    print("POCKET_POSITION substituted step \(step): \(original) -> \(replacement.offset)")
                }
            }
            return result
        }
        var samples:[PocketPositionSample]=[]
        if FileManager.default.fileExists(atPath:cache.path) {
            samples=try JSONDecoder().decode([PocketPositionSample].self,from:Data(contentsOf:cache))
            XCTAssertEqual(samples.count,steps+1)
            print("POCKET_POSITION loaded verified cache: \(samples.count) positions")
        } else if FileManager.default.fileExists(atPath:dir.appendingPathComponent("samples.json").path) {
            let initial=try JSONDecoder().decode([PocketPositionSample].self,from:Data(contentsOf:dir.appendingPathComponent("samples.json")))
            XCTAssertEqual(initial.count,steps+1)
            for sample in initial {
                let cue=SCNVector3(-0.25,y,sample.cueZ)
                let tracks=try completeTracks(cue:cue,selected:sample.tracks.map{$0.offset},valid:sample.validOffsets,step:sample.step)
                samples.append(PocketPositionSample(step:sample.step,cueZ:sample.cueZ,validOffsets:sample.validOffsets,tracks:tracks))
                if sample.step % 30 == 0 {print("POCKET_POSITION complete \(sample.step)/\(steps)");try await Task.sleep(nanoseconds:1_000_000)}
            }
            try JSONEncoder().encode(samples).write(to:cache)
        } else {
            for step in 0...steps {
                let cue=SCNVector3(-0.25,y,-0.56+1.12*Float(step)/Float(steps))
                let delta=SIMD2<Float>(target.x-cue.x,target.z-cue.z),length=simd_length(delta)
                func aim(_ offset:Int)->SCNVector3 {
                    let a=atan2(delta.y,delta.x)+asin(2*r*Float(offset)/100/length)
                    return SCNVector3(cos(a),0,sin(a))
                }
                var valid:[Int]=[]
                for offset in -99...99 {
                    let p=ShotPredictor.simulateFree(cueBall:cue,aimDir:aim(offset),velocity:1.5,spinX:0,spinY:0,
                        surfaceY:scene.surfaceY,balls:[ObstacleBall(name:ShotInput.targetBallName,position:target)],maxTime:30,
                        includePresentation:false,earlyStopBallNames:[ShotInput.targetBallName])
                    if directPot(p) != nil {valid.append(offset)}
                }
                XCTAssertGreaterThanOrEqual(valid.count,8)
                guard valid.count >= 8 else {throw NSError(domain:"PocketPositionNoEight",code:step)}
                // Fixed quantiles of the ordered feasible set; explicitly reserve samples for both sides.
                func pick(_ values:[Int],_ count:Int)->[Int] {
                    guard count>0 else {return []}
                    if count == 1 {return [values[values.count/2]]}
                    return (0..<count).map {values[Int((Double($0)*Double(values.count-1)/Double(count-1)).rounded())]}
                }
                let positive=valid.filter{$0 <= 0},reverse=valid.filter{$0 > 0}
                let selected:[Int]
                if !positive.isEmpty && !reverse.isEmpty {
                    let reverseCount=min(4,reverse.count),positiveCount=8-reverseCount
                    selected=pick(positive,positiveCount)+pick(reverse,reverseCount)
                } else {selected=pick(valid,8)}
                XCTAssertEqual(Set(selected).count,8)
                let tracks=try completeTracks(cue:cue,selected:selected,valid:valid,step:step)
                samples.append(PocketPositionSample(step:step,cueZ:cue.z,validOffsets:valid,tracks:tracks))
                if step % 20 == 0 {print("POCKET_POSITION solve \(step)/\(steps)");try await Task.sleep(nanoseconds:1_000_000)}
            }
            try JSONEncoder().encode(samples).write(to:cache)
        }
        if !substitutions.isEmpty {
            try JSONSerialization.data(withJSONObject:substitutions,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("sample-substitutions.json"))
        }
        func intervals(_ values:[Int])->[[Int]] {
            let values=Array(Set(values)).sorted();var result:[[Int]]=[]
            for v in values {
                if let last=result.last,last[1]+1 == v {result[result.count-1][1]=v}
                else {result.append([v,v])}
            }
            return result
        }
        var rows:[[String:Any]]=[]
        for sample in samples {
            XCTAssertEqual(sample.tracks.count,8)
            let normal=intervals(sample.validOffsets.filter{$0 <= 0}.map{100-abs($0)})
            let reverse=intervals(sample.validOffsets.filter{$0 >= 0}.map{100-abs($0)})
            rows.append(["step":sample.step,"cueZ":sample.cueZ,"positiveRangesPercent":normal,"reverseRangesPercent":reverse,
                "validSignedOffsets":sample.validOffsets,"tracks":sample.tracks.enumerated().map {i,t -> [String:Any] in
                    ["index":i,"signedOffset":t.offset,"side":t.offset == 0 ? "full" : (t.offset<0 ? "positive":"reverse"),
                     "thicknessPercent":100-abs(t.offset),"geometricThickness":t.geometricThickness,"scratch":t.scratch,
                     "cuePocket":t.cuePocket ?? "","rails":t.rails,"targetPocket":"pocket_0","objectPotTime":t.objectPotTime,
                     "end":t.end,"settled":true]
                }])
        }
        let manifest:[String:Any]=["speedMPS":1.5,"spinX":0,"spinY":0,"cueX":-0.25,"cueZStart":-0.56,"cueZEnd":0.56,
            "target":[target.x,target.y,target.z],"width":1440,"height":2560,"fps":60,"frameCount":frames,"duration":14,
            "rampStartFrame":60,"rampEndFrame":780,"scanResolutionPercent":1,"candidatesPerPosition":199,
            "rangePolicy":"direct object pot into pocket_0; first contact before cue cushion; cue scratch retained",
            "positiveSide":"negative aim rotation from cue-to-object direction","samples":rows]
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:dir.appendingPathComponent("manifest.json"))
        scene.showBall(key:"_8",scenePosition:target);scene.setCurrentTargetNumber(8)
        scene.setCameraMode(.perspective3D,animated:false)
        let cameraNode=try XCTUnwrap(scene.cameraNode),camera=try XCTUnwrap(cameraNode.camera)
        camera.usesOrthographicProjection=false;camera.fieldOfView=40;camera.projectionDirection = .vertical
        camera.zNear=0.01;camera.zFar=100;camera.wantsExposureAdaptation=false
        let elevation:Float=55 * .pi/180,distance:Float=4.6,focus=SCNVector3(0,scene.surfaceY,0)
        cameraNode.position=SCNVector3(-distance*cos(elevation),focus.y+distance*sin(elevation),0)
        cameraNode.look(at:focus,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        let transform=cameraNode.simdTransform
        let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=cameraNode
        renderer.delegate=scene.contactOcclusion;renderer.autoenablesDefaultLighting=false
        let size=CGSize(width:1440,height:2560),stageSize=CGSize(width:1440,height:1900)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        var nodes:[SCNNode]=[]
        let writer=preview ? nil : try VideoWriter(url:dir.appendingPathComponent("pocket-thickness-position-2k60-silent.mp4"),size:size,fps:60,averageBitRate:24_000_000)
        let keyframes=Set([0,180,300,420,540,600,613,660,720,780,839])
        let renderFrames=preview ? keyframes.sorted() : Array(0..<frames)
        for frame in renderFrames {
            try autoreleasepool {
                let sample=samples[max(0,min(steps,frame-60))],cue=SCNVector3(-0.25,y,sample.cueZ)
                scene.showBall(key:"cueBall",scenePosition:cue)
                scene.clearResultNodes(nodes:&nodes)
                for (i,track) in sample.tracks.enumerated() {
                    let color=SeparationAngleAtlasGeometry.trackColor(at:i)
                    let points=track.points.map{SCNVector3($0[0],$0[1],$0[2])}
                    scene.addDashedPolyline(points,color:color,radius:0.0026,dash:0.035,gap:0.004,placement:.table,into:&nodes)
                    if !track.scratch {
                        let dot=SCNNode(geometry:SCNSphere(radius:0.010));dot.geometry?.firstMaterial?.diffuse.contents=color
                        dot.geometry?.firstMaterial?.lightingModel = .constant
                        dot.position=SCNVector3(track.end[0],scene.surfaceY+0.01,track.end[2]);scene.rootNode.addChildNode(dot);nodes.append(dot)
                    }
                }
                let contact=sample.tracks[4].points[0]
                scene.addDashedPolyline([cue,SCNVector3(contact[0],contact[1],contact[2])],color:UIColor.white.withAlphaComponent(0.50),
                    radius:0.0012,dash:0.025,gap:0.014,placement:.table,into:&nodes)
                XCTAssertEqual(cameraNode.simdTransform,transform);SCNTransaction.flush()
                if frame == renderFrames.first {_=renderer.snapshot(atTime:0,with:stageSize,antialiasingMode:.multisampling4X)}
                let shot=renderer.snapshot(atTime:Double(frame)/60,with:stageSize,antialiasingMode:.multisampling4X)
                let image=UIGraphicsImageRenderer(size:size,format:format).image {context in
                    UIColor(red:0.035,green:0.043,blue:0.05,alpha:1).setFill();context.fill(CGRect(origin:.zero,size:size))
                    shot.draw(in:CGRect(x:0,y:390,width:1440,height:1900))
                    func text(_ s:String,_ x:CGFloat,_ y:CGFloat,_ font:CGFloat,_ color:UIColor = .white,_ weight:UIFont.Weight = .medium) {
                        (s as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:UIFont.systemFont(ofSize:font,weight:weight),.foregroundColor:color])
                    }
                    text("袋口走位 · 母球横移",88,80,62,.white,.semibold)
                    text("相同杆速，换个位置 · 正反角都算",90,177,32,UIColor(white:0.70,alpha:1))
                    for (i,t) in sample.tracks.enumerated() {
                        let x=CGFloat(128+i*153),color=SeparationAngleAtlasGeometry.trackColor(at:i),d:CGFloat=54
                        let offset=d*CGFloat(abs(t.offset))/100,shift=t.offset>0 ? -offset:offset
                        UIColor(white:0.95,alpha:1).setFill();UIBezierPath(ovalIn:CGRect(x:x-shift/2,y:269,width:d,height:d)).fill()
                        color.withAlphaComponent(0.85).setFill();UIBezierPath(ovalIn:CGRect(x:x+shift/2,y:269,width:d,height:d)).fill()
                        let side=t.offset == 0 ? "满" : (t.offset<0 ? "正":"反")
                        text("\(side)\(100-abs(t.offset))%",x-18,346,27,color,.semibold)
                    }
                    text("固定杆速",90,2280,31,UIColor(white:0.65,alpha:1))
                    text("1.5",90,2327,74,.white,.semibold);text("m/s · 中杆无塞",90,2430,28,UIColor(white:0.65,alpha:1))
                    @MainActor func rangeText(_ offsets:[Int])->String {
                        let ranges=intervals(offsets.map{100-abs($0)})
                        return ranges.isEmpty ? "无" : ranges.map{$0[0] == $0[1] ? "\($0[0])%":"\($0[0])–\($0[1])%"}.joined(separator:" / ")
                    }
                    text("八号直进范围",520,2290,34)
                    text("正角  "+rangeText(sample.validOffsets.filter{$0 <= 0}),520,2350,30,UIColor(white:0.82,alpha:1))
                    text("反角  "+rangeText(sample.validOffsets.filter{$0 >= 0}),520,2396,30,UIColor(white:0.82,alpha:1))
                    text("● 停点  × 落袋  ·  厚度按1%扫描",520,2452,25,UIColor(white:0.57,alpha:1))
                    for (i,t) in sample.tracks.enumerated() where t.scratch {
                        let projected=renderer.projectPoint(SCNVector3(t.end[0],scene.surfaceY+0.01,t.end[2]))
                        let x=CGFloat(projected.x),y=2290-CGFloat(projected.y)
                        let cross=UIBezierPath();cross.move(to:CGPoint(x:x-12,y:y-12));cross.addLine(to:CGPoint(x:x+12,y:y+12))
                        cross.move(to:CGPoint(x:x-12,y:y+12));cross.addLine(to:CGPoint(x:x+12,y:y-12))
                        UIColor.black.withAlphaComponent(0.8).setStroke();cross.lineWidth=9;cross.stroke()
                        SeparationAngleAtlasGeometry.trackColor(at:i).setStroke();cross.lineWidth=5;cross.stroke()
                    }
                }
                if keyframes.contains(frame) {try XCTUnwrap(image.pngData()).write(to:dir.appendingPathComponent("frames/frame-\(frame).png"))}
                if let writer {try writer.append(XCTUnwrap(image.cgImage))}
            }
            if frame % 30 == 0 {print("POCKET_POSITION render \(frame)/\(frames)")}
            try await Task.sleep(nanoseconds:1_000_000)
        }
        if let writer {try await writer.finish()}
        print("POCKET_POSITION COMPLETE preview=\(preview), \(samples.count) positions, \(samples.count*8) verified tracks")
    }
}
