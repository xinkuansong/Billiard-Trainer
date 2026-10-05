import XCTest
import SceneKit
import Metal
@testable import QiuJi

final class CameraSurfaceTests: XCTestCase {
    private let viewport = CGSize(width:874,height:402)

    @MainActor
    func testS10OverviewInterruptsFromVisibleHeadingNotPendingDestination() throws {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
        rig.usesTwoViewCameraControls = true; rig.usesSimpleCueCamera = true
        rig.usesMergedCamera = true; rig.usesSurfaceCamera = true; rig.viewportSize = viewport
        let cue = SCNVector3(0,0.8+BallPhysics.radius,0)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:SCNVector3(-1,0,0),duration:0))
        rig.update(deltaTime:1/120)
        let turn = Float.pi * 0.9
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:SCNVector3(-cos(turn),0,-sin(turn))))
        rig.update(deltaTime:1/120)
        let visible = node.simdTransform
        XCTAssertTrue(rig.enterMergedGlobal(aim:SCNVector3(1,0,0),cue:cue))
        XCTAssertEqual(node.simdTransform,visible)
        for _ in 0..<600 where rig.isTransitioning { rig.update(deltaTime:1/120) }
        XCTAssertEqual(try XCTUnwrap(rig.twoViewSnapshot?.simpleShot?.surface).bearing,0,accuracy:0.00001)
    }

    func testS10NearestOverviewAngleSeamsTiesAndWholeTurnEquivalence() {
        for degree in stride(from: -720, through: 720, by: 1) {
            let yaw = Float(degree) * .pi / 180
            let chosen = CameraSurface.nearestOverviewBearing(yaw:yaw)
            XCTAssertLessThanOrEqual(abs(TwoViewCamera.angleDelta(yaw,chosen)), .pi / 4 + 0.00001)
            XCTAssertEqual(TwoViewCamera.angleDelta(chosen,
                CameraSurface.nearestOverviewBearing(yaw:yaw + 2 * .pi)),0,accuracy:0.00001)
        }
        for (degree, expected): (Float,Float) in [(45,0),(-45,0),(135,90),(-135,180),(179,180),(-179,180)] {
            XCTAssertEqual(CameraSurface.nearestOverviewBearing(yaw:degree * .pi / 180),expected * .pi / 180,accuracy:0.00001)
        }
    }

    @MainActor
    func testS10OverviewCentersNearestOfFourRailsFromVisibleHeading() throws {
        for (degrees, target): (Float, Float) in [(35,0),(80,90),(170,180),(-80,-90)] {
            let scene = AngleTrainingScene()
            scene.configureDailyClearanceRendering(); scene.setupScene()
            let rig = try XCTUnwrap(scene.cameraRig)
            rig.usesTwoViewCameraControls = true; rig.usesSimpleCueCamera = true
            rig.usesMergedCamera = true; rig.usesSurfaceCamera = true; rig.viewportSize = viewport
            let cue = SCNVector3(0.7,scene.surfaceY + BallPhysics.radius,0.3)
            let angle = degrees * .pi / 180
            let aim = SCNVector3(-cos(angle),0,-sin(angle))
            XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,duration:0))
            rig.update(deltaTime:1/60)
            let origin = scene.cameraNode.simdTransform
            // Deliberately different business aim: overview must follow the visible view.
            XCTAssertTrue(rig.enterMergedGlobal(aim:SCNVector3(1,0,0),cue:cue))
            XCTAssertEqual(scene.cameraNode.simdTransform,origin,"No jump at request time")
            for _ in 0..<600 where rig.isTransitioning {
                rig.update(deltaTime:1/120)
                let visible = try XCTUnwrap(rig.twoViewSnapshot?.simpleShot?.surface)
                XCTAssertLessThan(simd_distance(scene.cameraNode.simdPosition,visible.pose.eye),0.0001)
            }
            let result = try XCTUnwrap(rig.twoViewSnapshot?.simpleShot?.surface)
            let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options:nil)
            renderer.scene = scene; renderer.pointOfView = scene.cameraNode
            SCNTransaction.flush()
            let attachment = XCTAttachment(image: renderer.snapshot(atTime:0,with:viewport,antialiasingMode:.multisampling4X))
            attachment.name = "s10-global-from-\(Int(degrees))-to-\(Int(target))"
            attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertEqual(result.travel,1)
            XCTAssertEqual(TwoViewCamera.angleDelta(result.bearing,target * .pi / 180),0,accuracy:0.00001)
            let eye = scene.cameraNode.simdPosition
            if target == 0 || target == 180 { XCTAssertEqual(eye.z,0,accuracy:0.00001) }
            else { XCTAssertEqual(eye.x,0,accuracy:0.00001) }
            XCTAssertTrue(rig.enterMergedGlobal(aim:aim,cue:cue))
            XCTAssertFalse(rig.isTransitioning,"Repeated global request at destination is stationary")
        }
    }

    @MainActor
    func testS9FirstBreakPerspectiveStartsAtDestinationWithoutTurning() throws {
        try verifyInitialSurface(breakShot: true, rotated: false)
        try verifyInitialSurface(breakShot: true, rotated: true)
    }

    @MainActor
    func testS9FirstFreePerspectiveStartsAtDestinationAndReturnKeepsObservation() throws {
        try verifyInitialSurface(breakShot: false, rotated: false)
    }

    @MainActor
    private func verifyInitialSurface(breakShot: Bool, rotated: Bool) throws {
        let vm = PositionPlayViewModel()
        vm.scene.configureDailyClearanceRendering(); vm.setupScene(); vm.enablePlayerCameraControls()
        defer { vm.cancelDailyAttempt() }
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = viewport
        ShotPlayCamera.setMode(rotated ? .topDown2DRotated : .topDown2D, on: vm)
        if breakShot { vm.startBreakFlow(game: .chineseEightBall, seed: 1234) }
        else { vm.toggleAimMode() }
        XCTAssertFalse(vm.scene.hasPerspectiveView)
        let cue = try XCTUnwrap(vm.scene.cueBallNode).position
        let aim = try XCTUnwrap(vm.currentPlayerAim)
        let expected = CameraSurface(cue: SIMD2(cue.x,cue.z), surfaceY: vm.scene.surfaceY,
            viewport: viewport, bearing: CameraSurface.bearing(cue: SIMD2(cue.x,cue.z),
                backwards: SIMD2(-aim.x,-aim.z)), travel: breakShot ? 1 : 0.5).pose
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        let renderer = SCNRenderer(device: try XCTUnwrap(MTLCreateSystemDefaultDevice()), options: nil)
        renderer.scene = vm.scene; renderer.pointOfView = vm.scene.cameraNode
        SCNTransaction.flush()
        let image = renderer.snapshot(atTime: 0, with: viewport, antialiasingMode: .multisampling4X)
        let attachment = XCTAttachment(image: image)
        attachment.name = "s9-first-frame-break-\(breakShot)-rotated-\(rotated)"
        attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertLessThan(simd_distance(vm.scene.cameraNode.simdPosition, expected.eye), 0.0001)
        XCTAssertGreaterThan(abs(simd_dot(vm.scene.cameraNode.simdOrientation.vector, expected.orientation.vector)), 0.99999)
        XCTAssertFalse(rig.isTransitioning)
        XCTAssertFalse(vm.cameraTransitionBusy)
        for _ in 0..<120 { rig.update(deltaTime: 1/120) }
        XCTAssertLessThan(simd_distance(vm.scene.cameraNode.simdPosition, expected.eye), 0.0001)
        // A repeated host request must not introduce a second turn after initialization.
        vm.requestPlayerView(.thirdPerson)
        XCTAssertFalse(rig.isTransitioning)
        rig.handleHorizontalSwipe(delta: 90)
        for _ in 0..<120 { rig.update(deltaTime: 1/120) }
        let held = vm.scene.cameraNode.simdTransform
        ShotPlayCamera.setMode(.topDown2D, on: vm)
        ShotPlayCamera.setMode(.perspective3D, on: vm)
        XCTAssertEqual(vm.scene.cameraNode.simdTransform, held)
    }

    @MainActor
    func testS6CueUpdatesCannotOverwriteTopDownProjection() throws {
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering(); scene.setupScene()
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.usesTwoViewCameraControls = true; rig.usesSimpleCueCamera = true
        rig.usesMergedCamera = true; rig.usesSurfaceCamera = true
        rig.viewportSize = viewport
        let cue = SCNVector3(0, scene.surfaceY + BallPhysics.radius, 0)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson, cue:cue, aim:SCNVector3(-1,0,0),duration:0))
        rig.update(deltaTime:0.02)
        for rotated in [false, true] {
            if rotated { rig.applyTopDown2DRotated() } else { rig.applyTopDown2D() }
            let transform = scene.cameraNode.simdTransform
            for i in 0..<20 {
                let aim = SCNVector3(cos(Float(i)*0.1),0,sin(Float(i)*0.1))
                rig.updateCuePose(strike:cue,aim:aim,elevation:0,cue:cue)
                rig.followSimpleAim(cue:cue,strike:cue,aim:aim)
                XCTAssertTrue(scene.cameraNode.camera!.usesOrthographicProjection)
                XCTAssertEqual(scene.cameraNode.simdTransform,transform)
            }
        }
    }

    @MainActor
    func testS8SurfaceButtonsUseDistanceGainRatherThanFixedDuration() throws {
        func travelTime(angle:Float, overview:Bool = false) -> Float {
            let node = SCNNode(); node.camera = SCNCamera()
            let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8)
            rig.usesTwoViewCameraControls = true; rig.usesSimpleCueCamera = true
            rig.usesMergedCamera = true; rig.usesSurfaceCamera = true; rig.viewportSize = viewport
            let cue = SCNVector3(0,0.828575,0)
            XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:SCNVector3(-1,0,0),duration:0))
            rig.update(deltaTime:1/120)
            if overview { XCTAssertTrue(rig.enterMergedGlobal(aim:SCNVector3(-1,0,0),cue:cue)) }
            else { XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:SCNVector3(-cos(angle),0,-sin(angle)))) }
            var time:Float = 0
            while rig.isTransitioning && time < 10 {
                rig.update(deltaTime:1/120); time += 1/120
            }
            XCTAssertFalse(rig.isTransitioning)
            return time
        }
        let short = travelTime(angle:.pi/12), long = travelTime(angle:.pi/2)
        XCTAssertGreaterThan(long,short,"Far turns still take longer, with a higher cruise speed")
        XCTAssertLessThan(short,0.4)
        XCTAssertLessThan(long,0.9)
        let overview = travelTime(angle:0,overview:true)
        XCTAssertLessThan(overview,0.8)
        print("S8 rig seconds: short=\(short) long=\(long) overview=\(overview)")
    }

    @MainActor
    func testS7RepeatedSettledViewDoesNotLeaveStrikeBusy() throws {
        let vm = PositionPlayViewModel()
        vm.scene.configureDailyClearanceRendering(); vm.setupScene(); vm.enablePlayerCameraControls()
        defer { vm.cancelDailyAttempt() }
        vm.toggleAimMode()
        vm.cameraMode = .perspective3D
        vm.scene.setCameraMode(.perspective3D,animated:false)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        XCTAssertNotNil(vm.currentPlayerAim)
        vm.requestPlayerView(.thirdPerson)
        for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime:1/120) }
        XCTAssertFalse(rig.isTransitioning)
        vm.requestPlayerView(.thirdPerson)
        XCTAssertFalse(rig.isTransitioning,"A repeated destination has zero path length")
        XCTAssertFalse(vm.cameraTransitionBusy,"No future completion callback exists for zero motion")
        vm.requestSurfaceOverview()
        for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime:1/120) }
        XCTAssertFalse(rig.isTransitioning)
        vm.requestSurfaceOverview()
        XCTAssertFalse(rig.isTransitioning)
        XCTAssertFalse(vm.cameraTransitionBusy)
    }

    func testS8DoubledBaseSpeedAndLinearDistanceGain() {
        let origin = TwoViewCamera.Pose.looking(eye:.zero,yaw:0,pitch:0,fov:45)
        func line(_ distance:Float) -> TwoViewCamera.SurfaceMotion {
            TwoViewCamera.SurfaceMotion { t in
                var p = origin; p.eye.x = distance*t; return p
            }
        }
        let long = line(3.6), short = line(0.02)
        XCTAssertEqual(long.duration,3.6/(3.6*1.9)+0.16,accuracy:0.0001)
        XCTAssertEqual(long.speedGain,1.9,accuracy:0.00001)
        XCTAssertEqual(line(7.2).speedGain,2.8,accuracy:0.00001)
        XCTAssertEqual(line(7.2).duration,7.2/(3.6*2.8)+0.16,accuracy:0.0001)
        // Equal 0.1s intervals in the cruise phase cover equal world distances.
        for t:Float in [0.2,0.3,0.4] {
            XCTAssertEqual(3.6*(long.fraction(at:t+0.1)-long.fraction(at:t)),0.684,accuracy:0.00001)
        }
        XCTAssertLessThan(short.duration,0.16*2)
        XCTAssertEqual(short.fraction(at:short.duration),1)
        XCTAssertEqual(line(0).duration,0)
        let rotate = TwoViewCamera.SurfaceMotion { t in
            .looking(eye:.zero,yaw:.pi*t,pitch:0,fov:45)
        }
        XCTAssertEqual(rotate.duration,1.16,accuracy:0.0001)
        let lens = TwoViewCamera.SurfaceMotion { t in
            var p = origin; p.fov += 80*t; return p
        }
        XCTAssertEqual(lens.duration,1.16,accuracy:0.0001)
    }

    func testS8ActualCurvedPathSpeedAt60And120Hz() {
        for cue in [SIMD2<Float>.zero,SIMD2(1.2,0.5)] {
            for travel:Float in [0.1,0.5,1] {
                for hz:Float in [60,120] {
                    let a = CameraSurface(cue:cue,surfaceY:0.8,viewport:viewport,bearing:2.8,travel:travel)
                    var b = a; b.bearing = -0.8; b.travel = 1-travel
                    let clock = TwoViewCamera.SurfaceMotion { a.interpolated(to:b,fraction:$0).pose }
                    var measuredLength: Float = 0
                    var sample = a.pose
                    for i in 1...2048 {
                        let next = a.interpolated(to:b,fraction:Float(i)/2048).pose
                        measuredLength += simd_distance(sample.eye,next.eye); sample = next
                    }
                    let gain = 1 + measuredLength*0.25
                    XCTAssertEqual(clock.speedGain,gain,accuracy:0.001)
                    var previous = a.pose
                    var peak:Float = 0
                    for frame in 1...Int(ceil(clock.duration*hz)) {
                        let current = a.interpolated(to:b,fraction:clock.fraction(at:Float(frame)/hz)).pose
                        let speed = simd_distance(previous.eye,current.eye)*hz
                        let spin = TwoViewCamera.SurfaceMotion.angleBetween(previous.orientation,current.orientation)*hz
                        peak = max(peak,speed)
                        XCTAssertLessThanOrEqual(speed,3.6*gain*1.02)
                        XCTAssertLessThanOrEqual(spin,Float.pi*gain*1.02)
                        previous = current
                    }
                    XCTAssertGreaterThan(peak,1,"Long motion must actually cruise")
                    XCTAssertLessThan(simd_distance(previous.eye,b.pose.eye),0.00001)
                }
            }
        }
    }

    func testS7SpeedTransitionRetargetAndTouchKeepVisiblePose() {
        let a = CameraSurface(cue:.zero,surfaceY:0.8,viewport:viewport,bearing:0)
        let camera = surfaceCamera(a)
        var b = a; b.bearing = 2
        func shot(_ surface:CameraSurface) -> TwoViewCamera.SimpleShot {
            .init(cue:SIMD3(0,0.829,0),strike:SIMD3(0,0.829,0),aim:SIMD3(-1,0,0),
                  surfaceY:0.8,viewport:viewport,surface:surface)
        }
        camera.enterSimpleShot(shot(b),duration:nil)
        camera.update(deltaTime:0.3,time:1)
        let visible = camera.pose.transform
        b.bearing = -1
        camera.enterSimpleShot(shot(b),duration:nil)
        XCTAssertEqual(camera.pose.transform,visible)
        camera.update(deltaTime:0.2,time:1.2)
        let retargeted = camera.pose.transform
        XCTAssertTrue(camera.beginTemporaryObservation())
        XCTAssertEqual(camera.pose.transform,retargeted)
        XCTAssertFalse(camera.isTransitioning)
        let saved = camera.snapshot()
        camera.restore(saved)
        camera.update(deltaTime:10,time:20)
        XCTAssertEqual(camera.pose.transform,retargeted)
    }

    @MainActor
    func testS8TargetTapReframesRepeatedFreeAndPocketSelectionsWithoutWaitingForSolver() throws {
        let vm = PositionPlayViewModel()
        vm.scene.configureDailyClearanceRendering(); vm.setupScene(); vm.enablePlayerCameraControls()
        defer { vm.cancelDailyAttempt() }
        vm.usesAutomaticPocketFallback = true
        vm.loadBoard(BoardSnapshot(onTable: [PositionPlayBall.cueKey: CanvasPoint(x:0.6,y:0.35),
            "_1":CanvasPoint(x:0.3,y:0.15),"_2":CanvasPoint(x:0.7,y:0.15)]))
        vm.cameraMode = .perspective3D
        vm.scene.setCameraMode(.perspective3D,animated:false)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = viewport
        for free in [false,true] {
            if free { vm.toggleAimMode() }
            for key in ["_1","_1","_2"] {
                let before = vm.twoViewAutomaticThirdPersonEntryCount
                XCTAssertTrue(vm.selectTarget(key:key))
                XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount,before+1,
                    "Every accepted tap must request framing before async solve delivery")
                for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime:1/120) }
                let surface = try XCTUnwrap(rig.twoViewSnapshot?.simpleShot?.surface)
                XCTAssertEqual(surface.travel,0.5)
                XCTAssertFalse(vm.cameraTransitionBusy)
                vm.requestSurfaceOverview()
                for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime:1/120) }
                XCTAssertEqual(rig.twoViewSnapshot?.simpleShot?.surface?.travel,1)
            }
        }
        vm.beginTemporaryTopDown()
        XCTAssertTrue(vm.temporaryTopDownActive)
        let pose = try XCTUnwrap(rig.twoViewSnapshot).pose.transform
        let before = vm.twoViewAutomaticThirdPersonEntryCount
        XCTAssertTrue(vm.selectTarget(key:"_2")) // Same target still requests framing on exit.
        XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount,before)
        XCTAssertEqual(rig.twoViewSnapshot?.pose.transform,pose)
        vm.endTemporaryTopDown()
        XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount,before+1)
        for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime:1/120) }
        XCTAssertEqual(rig.twoViewSnapshot?.simpleShot?.surface?.travel,0.5)
        vm.cameraMode = .topDown2D; vm.scene.setCameraMode(.topDown2D,animated:false)
        let entries = vm.twoViewAutomaticThirdPersonEntryCount
        let topDownPose = vm.scene.cameraNode.simdTransform
        XCTAssertTrue(vm.selectTarget(key:"_1"))
        XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount,entries)
        XCTAssertEqual(vm.scene.cameraNode.simdTransform,topDownPose)
        XCTAssertTrue(vm.scene.cameraNode.camera!.usesOrthographicProjection)
    }

    @MainActor
    func testS8BlockedTargetStillReframesFreeAimAndInvalidTapDoesNot() throws {
        let vm = PositionPlayViewModel()
        vm.scene.configureDailyClearanceRendering(); vm.setupScene(); vm.enablePlayerCameraControls()
        defer { vm.cancelDailyAttempt() }
        vm.usesAutomaticPocketFallback = true; vm.usesDailyShotRanking = true
        vm.legalAimTargets = { $0.intersection(["_1","_2"]) }
        let y = vm.scene.surfaceY + BallPhysics.radius
        var points = [PositionPlayBall.cueKey:SCNVector3(-0.5,y,0),
                      "_1":SCNVector3(0,y,0),"_2":SCNVector3(0.3,y,-0.3)]
        for i in 0..<6 {
            let a = Float(i) * .pi / 3
            points["_\(i+3)"] = SCNVector3(0.07*cos(a),y,0.07*sin(a))
        }
        vm.loadBoard(.init(onTable:points.mapValues {
            let p = AngleSceneCalculator.sceneToNormalized(position:$0)
            return CanvasPoint(x:Double(p.x),y:Double(p.y))
        }))
        vm.cameraMode = .perspective3D; vm.scene.setCameraMode(.perspective3D,animated:false)
        let rig = try XCTUnwrap(vm.scene.cameraRig); rig.viewportSize = viewport
        let before = vm.twoViewAutomaticThirdPersonEntryCount
        XCTAssertTrue(vm.selectTarget(key:"_1"))
        XCTAssertEqual(vm.aimMode,.free)
        XCTAssertEqual(vm.preferredAimMode,.pocket)
        XCTAssertNotNil(vm.temporaryFreeReason)
        XCTAssertEqual(vm.selectedPocketIndex,-1)
        XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount,before+1)
        for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime:1/120) }
        XCTAssertEqual(rig.twoViewSnapshot?.simpleShot?.surface?.travel,0.5)
        let aim = try XCTUnwrap(rig.twoViewSnapshot?.simpleShot?.aim)
        XCTAssertEqual(aim.x,1,accuracy:0.00001); XCTAssertEqual(aim.z,0,accuracy:0.00001)
        XCTAssertFalse(vm.selectTarget(key:"_3"))
        XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount,before+1)
        vm.velocity = 2.2
        XCTAssertEqual(vm.twoViewAutomaticThirdPersonEntryCount,before+1,"Power updates do not reframe")
    }

    @MainActor
    func testS8BreakEntryAndReentryUseFarthestAlignedThirdPerson() throws {
        let vm = PositionPlayViewModel()
        vm.scene.configureDailyClearanceRendering(); vm.setupScene(); vm.enablePlayerCameraControls()
        defer { vm.cancelDailyAttempt() }
        vm.cameraMode = .perspective3D; vm.scene.setCameraMode(.perspective3D,animated:false)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = viewport
        vm.startBreakFlow(game:.chineseEightBall,seed:1234)
        func verifyFar() throws {
            let surface = try XCTUnwrap(rig.twoViewSnapshot?.simpleShot?.surface)
            let cue = try XCTUnwrap(vm.scene.cueBallNode).position
            let aim = try XCTUnwrap(vm.currentPlayerAim)
            XCTAssertEqual(surface.travel,1)
            XCTAssertEqual(surface.bearing,CameraSurface.bearing(cue:SIMD2(cue.x,cue.z),
                backwards:SIMD2(-aim.x,-aim.z)),accuracy:0.00001)
            for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime:1/120) }
            XCTAssertFalse(rig.isTransitioning)
            XCTAssertFalse(vm.cameraTransitionBusy)
        }
        try verifyFar()
        rig.handleVerticalSwipe(delta:-100)
        vm.requestPlayerView(.thirdPerson)
        try verifyFar()
        vm.beginTemporaryTopDown(); vm.endTemporaryTopDown()
        try verifyFar()
    }

    func testS5AxisLockRetainsDirectionThroughDriftReversalAndTurn() {
        for sign: Float in [-1, 1] {
            var horizontal = SurfacePanAxisLock()
            XCTAssertEqual(horizontal.filter(SIMD2(12*sign, 4)), SIMD2(12*sign, 0))
            XCTAssertEqual(horizontal.filter(SIMD2(1, 40)), SIMD2(1, 0))
            XCTAssertEqual(horizontal.filter(SIMD2(0, -40)), .zero)
            XCTAssertEqual(horizontal.filter(SIMD2(-3*sign, -2)), SIMD2(-3*sign, 0))
            var vertical = SurfacePanAxisLock()
            XCTAssertEqual(vertical.filter(SIMD2(4, 12*sign)), SIMD2(0, 12*sign))
            XCTAssertEqual(vertical.filter(SIMD2(40, 1)), SIMD2(0, 1))
            XCTAssertEqual(vertical.filter(SIMD2(-40, 0)), .zero)
            XCTAssertEqual(vertical.filter(SIMD2(-2, -3*sign)), SIMD2(0, -3*sign))
        }
    }

    func testS5AxisLockInvalidInputTieAndNextGesture() {
        var lock = SurfacePanAxisLock()
        XCTAssertEqual(lock.filter(.zero), .zero)
        XCTAssertEqual(lock.filter(SIMD2(.nan, 5)), .zero)
        XCTAssertNil(lock.axis)
        XCTAssertEqual(lock.filter(SIMD2(8, -8)), SIMD2(8, 0))
        XCTAssertEqual(lock.axis, .horizontal)
        lock = SurfacePanAxisLock() // Same reset used at touch-down/end/cancel.
        XCTAssertEqual(lock.filter(SIMD2(0.1, -0.2)), SIMD2(0, -0.2))
        XCTAssertEqual(lock.axis, .vertical)
    }

    @MainActor
    func testDailyProductionDefaultAndOtherHostIsolation() throws {
        XCTAssertFalse(ProcessInfo.processInfo.arguments.contains("-dailyClearance.surfaceCamera"))
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "CameraSurfaceExperiment"))
        let daily = PositionPlayViewModel()
        daily.scene.configureDailyClearanceRendering()
        daily.setupScene()
        daily.enablePlayerCameraControls()
        let rig = try XCTUnwrap(daily.scene.cameraRig)
        XCTAssertTrue(rig.usesSurfaceCamera)
        XCTAssertTrue(rig.usesMergedCamera)
        XCTAssertTrue(rig.usesSimpleCueCamera)
        XCTAssertTrue(rig.usesTwoViewCameraControls)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson, cue: SCNVector3(0,0.829,0),
                                          aim: SCNVector3(-1,0,0), duration: 0))
        XCTAssertEqual(rig.twoViewSnapshot?.simpleShot?.surface?.travel, 0.5)

        let other = PositionPlayViewModel()
        other.setupScene()
        other.enablePlayerCameraControls()
        let otherRig = try XCTUnwrap(other.scene.cameraRig)
        XCTAssertTrue(otherRig.usesRailCameraControls)
        XCTAssertFalse(otherRig.usesSurfaceCamera)
        XCTAssertFalse(otherRig.usesMergedCamera)
        XCTAssertFalse(otherRig.usesSimpleCueCamera)
        XCTAssertFalse(otherRig.usesTwoViewCameraControls)
    }


    private func surfaceCamera(_ surface: CameraSurface) -> TwoViewCamera {
        let camera = TwoViewCamera(pose: surface.pose)
        camera.enterSimpleShot(.init(cue: SIMD3(surface.cue.x,0.829,surface.cue.y),
            strike: SIMD3(0,0.829,0), aim: SIMD3(-1,0,0), surfaceY: surface.surfaceY,
            viewport: surface.viewport, surface: surface), duration: 0)
        return camera
    }

    func testS3UnevenInputResampledAt60And120HzWithoutDroppingFinalInput() {
        let surfaces = [
            CameraSurface(cue: .zero, surfaceY: 0.8, viewport: viewport, bearing: 0),
            CameraSurface(cue: SIMD2(1.2,0.5), surfaceY: 0.8, viewport: viewport, bearing: 1.2, travel: 0.1),
            CameraSurface(cue: SIMD2(-1.2,-0.5), surfaceY: 0.8, viewport: viewport, bearing: -2.4, travel: 1)
        ]
        for initial in surfaces {
        for fps in [60, 120] {
            let camera = surfaceCamera(initial)
            var direct = initial, reference = initial
            var referenceTime = 0.0
            var previousReference = initial.pose.eye
            var referenceSteps: [Float] = []
            var relativeErrors: [Float] = [], directErrors: [Float] = []
            var events: [Double] = [0]
            let gaps = [0.012, 0.023, 0.015, 0.018, 0.014, 0.025]
            for i in 0..<90 { events.append(events.last! + gaps[i % gaps.count]) }
            var index = 1, previous = initial.pose.eye, previousDirect = previous
            var steps: [Float] = [], directSteps: [Float] = []
            for frame in 0...Int(events.last! * Double(fps)) {
                let now = Double(frame) / Double(fps)
                while index < events.count, events[index] <= now {
                    let dx = Float(events[index] - events[index-1]) * 110
                    direct.orbit(points: dx)
                    XCTAssertTrue(camera.surfacePan(delta: SIMD2(dx,0), at: events[index]))
                    index += 1
                }
                camera.update(deltaTime: 1/Float(fps), time: now)
                // Dense, evenly delivered input is the reference: constant finger speed
                // deliberately does NOT imply constant world speed around the outer table.
                let referenceNow = max(0, now - TwoViewCamera.surfaceInputDelay)
                reference.orbit(points: Float(referenceNow - referenceTime) * 110)
                referenceTime = referenceNow
                let expectedStep = simd_length(reference.pose.eye - previousReference)
                if now > 0.15 {
                    let step = simd_length(camera.pose.eye - previous)
                    let directStep = simd_length(direct.pose.eye - previousDirect)
                    steps.append(step); directSteps.append(directStep); referenceSteps.append(expectedStep)
                    relativeErrors.append(step / expectedStep - 1)
                    directErrors.append(directStep / expectedStep - 1)
                }
                previousReference = reference.pose.eye
                previous = camera.pose.eye; previousDirect = direct.pose.eye
            }
            // Include the final event even when it falls between the final display ticks.
            while index < events.count {
                let dx = Float(events[index] - events[index-1]) * 110
                direct.orbit(points: dx)
                XCTAssertTrue(camera.surfacePan(delta: SIMD2(dx,0), at: events[index]))
                index += 1
            }
            func variation(_ values: [Float]) -> Float {
                let mean = values.reduce(0,+) / Float(values.count)
                return sqrt(values.reduce(0) { $0 + ($1-mean)*($1-mean) } / Float(values.count)) / mean
            }
            func rms(_ values: [Float]) -> Float {
                sqrt(values.reduce(0) { $0 + $1*$1 } / Float(values.count))
            }
            let before = rms(directErrors), after = rms(relativeErrors)
            print("S3 resampling travel=\(initial.travel) fps=\(fps) referenceWorldCV=\(variation(referenceSteps)) directWorldCV=\(variation(directSteps)) resampledWorldCV=\(variation(steps)) directStepError=\(before) resampledStepError=\(after)")
            XCTAssertLessThan(after, before * 0.4)
            XCTAssertLessThan(after, 0.05, "Per-frame motion must match evenly delivered input within 5% RMS")
            XCTAssertTrue(steps.allSatisfy { $0 > 0 }, "No held frames during steady motion")
            camera.endTemporaryObservation()
            camera.update(deltaTime: 1/Float(fps), time: events.last! + TwoViewCamera.surfaceInputDelay + 0.000001)
            XCTAssertEqual(camera.pose.transform, direct.pose.transform)
            XCTAssertFalse(camera.hasPendingMotion)
            let final = camera.pose.transform
            camera.update(deltaTime: 1, time: events.last! + 1)
            XCTAssertEqual(camera.pose.transform, final)
        }
        }
    }

    func testS3CombinedInputDefersPoseWriteAndCancelsOnNewContext() {
        let initial = CameraSurface(cue: .zero, surfaceY: 0.8, viewport: viewport, bearing: 0)
        let camera = surfaceCamera(initial)
        XCTAssertTrue(camera.surfacePan(delta: SIMD2(25,25), at: 1))
        XCTAssertEqual(camera.pose.transform, initial.pose.transform, "Input must not submit an intermediate horizontal pose")
        camera.update(deltaTime: 1/120, time: 1.025)
        let visible = camera.pose.transform
        XCTAssertNotEqual(visible, initial.pose.transform)
        let snapshot = camera.snapshot()
        XCTAssertEqual(snapshot.simpleShot?.surface?.pose.transform, visible)
        camera.setViewingContext(UUID())
        camera.update(deltaTime: 1, time: 2)
        XCTAssertEqual(camera.pose.transform, visible, "Old shot samples cannot resume")
        camera.restore(snapshot)
        camera.update(deltaTime: 1, time: 3)
        XCTAssertEqual(camera.pose.transform, visible, "Overlay restore must not drain stale samples")
    }

    func testS3FirstEntryFromNonSurfaceDoesNotJumpOrReplayBufferedInput() {
        let surface = CameraSurface(cue: .zero, surfaceY: 0.8, viewport: viewport, bearing: 0)
        var oldPose = surface.pose; oldPose.eye += SIMD3(0,1,0)
        let camera = TwoViewCamera(pose: oldPose)
        camera.enterSimpleShot(.init(cue: SIMD3(0,0.829,0), strike: SIMD3(0,0.829,0),
            aim: SIMD3(-1,0,0), surfaceY: 0.8, viewport: viewport, surface: surface), duration: 0.3)
        camera.update(deltaTime: 0.1, time: 1)
        let visible = camera.pose.transform
        XCTAssertTrue(camera.surfacePan(delta: SIMD2(5,5), at: 1))
        XCTAssertEqual(camera.pose.transform, visible)
        XCTAssertTrue(camera.isTransitioning)
        camera.update(deltaTime: 0.3, time: 1.3)
        let final = camera.pose.transform
        XCTAssertFalse(camera.hasPendingMotion)
        camera.update(deltaTime: 1/60, time: 1.32)
        XCTAssertEqual(camera.pose.transform, final)
    }

    func testS3ButtonTransitionStaysOnSurfaceAndTouchTakesVisiblePose() throws {
        let initial = CameraSurface(cue: SIMD2(0.7,0.3), surfaceY: 0.8, viewport: viewport, bearing: 2.8)
        let camera = surfaceCamera(initial)
        XCTAssertTrue(camera.retreatSurface(cue: SIMD3(0.7,0.829,0.3), duration: 0.3))
        for _ in 0..<8 {
            camera.update(deltaTime: 1/120)
            let surface = try XCTUnwrap(camera.snapshot().simpleShot?.surface)
            XCTAssertEqual(camera.pose.transform, surface.pose.transform)
            XCTAssertGreaterThanOrEqual(surface.distance, initial.distance)
            XCTAssertLessThanOrEqual(surface.travel, 1)
        }
        let visible = camera.pose.transform
        let revision = camera.requestRevision
        XCTAssertTrue(camera.retreatSurface(cue: SIMD3(0.7,0.829,0.3), duration: 0.3))
        XCTAssertEqual(camera.requestRevision, revision, "Repeated shortcut must not restart its easing")
        XCTAssertTrue(camera.surfacePan(delta: SIMD2(-12,-12), at: 1))
        XCTAssertFalse(camera.isTransitioning)
        XCTAssertEqual(camera.pose.transform, visible, "Touch must cancel at the visible point without jumping to the button target")
        camera.update(deltaTime: 1/60, time: 1 + TwoViewCamera.surfaceInputDelay + 0.000001)
        XCTAssertNotEqual(camera.pose.transform, visible)
    }

    func testIndependentPythonHeightRingFixtures() {
        // Independent Python/double S4 oracle: build/camera-surface-s4-20261005/reference.py.
        let fixtures: [(SIMD2<Float>,Float,Float,SIMD3<Float>,SIMD3<Float>,Float)] = [
            (SIMD2(0.0000000000,0.0000000000),0,0,SIMD3(0.9000000000,0.1800000000,0.0000000000),SIMD3(-0.9976012213,-0.0692228524,-0.0000000000),32.0704985148),
            (SIMD2(1.2000000000,0.5000000000),1.1,0.3,SIMD3(1.2467573311,0.4335911111,1.8897931790),SIMD3(-0.0330443531,-0.1849352930,-0.9821949950),32.0704985148),
            (SIMD2(-0.7000000000,0.4000000000),-2.2,0.7,SIMD3(-1.4656120434,1.0404888889,-1.6100671375),SIMD3(0.4329951406,-0.3622046371,0.8254229274),35.2180848560),
            (SIMD2(0.5000000000,-0.5000000000),2.4,1,SIMD3(-2.5227801859,1.8000000000,2.3109027000),SIMD3(0.6548229141,-0.4597981573,-0.5998271465),37.7723368251)
        ]
        for (cue,phi,u,eye,forward,fov) in fixtures {
            let s = CameraSurface(cue:cue,surfaceY:0,viewport:viewport,bearing:phi,travel:u)
            XCTAssertLessThan(simd_length(s.pose.eye-eye),0.00001)
            XCTAssertLessThan(simd_length(s.pose.forward-forward),0.00001)
            XCTAssertEqual(s.pose.fov,fov,accuracy:0.0001)
        }
    }

    func testOrbitMaintainsHeightIncludingResampledFramesAndOuterIsCueIndependent() {
        for cue in [SIMD2<Float>(0,0),SIMD2(1.23,0.60),SIMD2(-1.23,-0.60)] {
            for phi in stride(from:-Float.pi,through:Float.pi,by:0.1) {
                for u: Float in [0,0.2,0.5,0.7,1] {
                    var s = CameraSurface(cue:cue,surfaceY:0.8,viewport:viewport,bearing:phi,travel:u)
                    let before = s, h = s.pose.eye.y
                    s.orbit(points:100)
                    XCTAssertEqual(s.pose.eye.y,h,accuracy:0.00001)
                    for t: Float in [0.1,0.3,0.5,0.7,0.9] {
                        XCTAssertEqual(before.interpolated(to:s,fraction:t).pose.eye.y,h,accuracy:0.00001)
                    }
                    if u == 0.5 { XCTAssertEqual(s.pose.eye.y,1.45,accuracy:0.00001) }
                }
                let a = CameraSurface(cue:cue,surfaceY:0.8,viewport:viewport,bearing:phi,travel:1).pose
                let b = CameraSurface(cue:.zero,surfaceY:0.8,viewport:viewport,bearing:phi,travel:1).pose
                XCTAssertLessThan(simd_length(a.eye-b.eye),0.00001)
                XCTAssertLessThan(simd_length(a.forward-b.forward),0.00001)
                XCTAssertEqual(a.fov,b.fov,accuracy:0.0001)
            }
        }
    }

    func testS4NearCueCentreClearanceAndOuterTableFraming() {
        for cue in [SIMD2<Float>(0,0), SIMD2(1.241425,0.606425), SIMD2(-1.241425,-0.606425)] {
            for phi in stride(from:-Float.pi,through:Float.pi,by:0.1) {
                for u: Float in [0,0.1,0.25,0.49,0.5,0.51,0.75,1] {
                    let s = CameraSurface(cue:cue,surfaceY:0,viewport:viewport,bearing:phi,travel:u)
                    let p = s.pose
                    let back = simd_normalize(SIMD2(p.eye.x,p.eye.z)-cue)
                    var railDistance: Float = .infinity
                    if abs(back.x)>0.00001 { railDistance=min(railDistance,((back.x>0 ? 1.27 : -1.27)-cue.x)/back.x) }
                    if abs(back.y)>0.00001 { railDistance=min(railDistance,((back.y>0 ? 0.635 : -0.635)-cue.y)/back.y) }
                    if railDistance < s.distance {
                        let crossingY = BallPhysics.radius + (p.eye.y-BallPhysics.radius)*railDistance/s.distance
                        XCTAssertGreaterThan(crossingY, BTTablePhysics.cushionHeight, "Cue-centre ray clearance cue=\(cue) phi=\(phi) u=\(u)")
                    }
                    if u == 1 {
                        XCTAssertEqual(p.eye.y,1.8,accuracy:0.00001)
                        for x: Float in [-1.4055,1.4055] {
                            for z: Float in [-0.7995,0.7995] {
                                for y: Float in [0,BallPhysics.radius+0.037] {
                                    let local=p.orientation.inverse.act(SIMD3(x,y,z)-p.eye)
                                    let sy=abs(local.y / -local.z / tan(p.fov * .pi/360))
                                    let sx=abs(local.x / -local.z / tan(p.fov * .pi/360) / Float(viewport.width/viewport.height))
                                    XCTAssertGreaterThan(-local.z,0)
                                    XCTAssertLessThan(sx,0.88)
                                    XCTAssertLessThan(sy,0.90)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func testRetreatMonotonicAndRoomSafeAcrossCueAndBearing() {
        for cue in [SIMD2<Float>(0,0),SIMD2(1.241425,0.606425),SIMD2(-1.241425,-0.606425)] {
            for phi in stride(from:-Float.pi,through:Float.pi,by:0.2) {
                var height: Float = -.infinity
                for i in 0...100 {
                    let s = CameraSurface(cue:cue,surfaceY:0.8,viewport:viewport,bearing:phi,travel:Float(i)/100)
                    let p = s.pose
                    XCTAssertGreaterThan(p.eye.y,height)
                    XCTAssertLessThan(abs(p.eye.x),3.65)
                    XCTAssertLessThan(abs(p.eye.z),2.65)
                    XCTAssertTrue(p.fov.isFinite)
                    height = p.eye.y
                }
            }
        }
    }

    func testInputEndpointsReverseImmediatelyAndReleaseHolds() throws {
        var surface = CameraSurface(cue:.zero,surfaceY:0.8,viewport:viewport,bearing:0)
        surface.move(points:10000); XCTAssertEqual(surface.travel,1)
        surface.move(points:-1); XCTAssertLessThan(surface.travel,1)
        surface.move(points:-10000); XCTAssertEqual(surface.travel,0)
        surface.move(points:1); XCTAssertGreaterThan(surface.travel,0)
        let shot = TwoViewCamera.SimpleShot(cue:SIMD3(0,0.829,0),strike:SIMD3(0,0.829,0),aim:SIMD3(-1,0,0),surfaceY:0.8,viewport:viewport,surface:surface)
        let camera = TwoViewCamera(pose:shot.pose)
        camera.enterSimpleShot(shot,duration:0)
        XCTAssertTrue(camera.horizontal(delta:100)); XCTAssertTrue(camera.vertical(delta:50))
        camera.endTemporaryObservation()
        camera.update(deltaTime: 1/30, time: CACurrentMediaTime() + TwoViewCamera.surfaceInputDelay)
        let before = camera.pose
        camera.updateSimpleShot(cue:SIMD3(1,0.829,0.5),strike:SIMD3(1,0.829,0.5),aim:SIMD3(0,0,1))
        for _ in 0..<120 { camera.update(deltaTime:1/60) }
        XCTAssertEqual(camera.pose.transform,before.transform)
        XCTAssertEqual(camera.pose.fov,before.fov)
        XCTAssertEqual(camera.owner,.manual)
        let snapshot = camera.snapshot()
        XCTAssertTrue(camera.retreatSurface(cue:SIMD3(0,0.829,0),duration:0.3))
        camera.update(deltaTime:0.3)
        XCTAssertEqual(camera.simpleShot?.surface?.travel,1)
        camera.restore(snapshot)
        XCTAssertEqual(camera.pose.transform,before.transform)
    }

    func testS2DirectionAndSeamResponse() {
        for cue in [SIMD2<Float>(0,0), SIMD2(1.2,0.5), SIMD2(-1.2,-0.5)] {
            for phi in stride(from: -Float.pi, to: Float.pi, by: Float.pi/6) {
                for u: Float in [0.1,0.5,0.9,1] {
                    var sample = CameraSurface(cue:cue,surfaceY:0.8,viewport:viewport,bearing:phi,travel:u)
                    sample.orbit(points:1)
                    let delta = atan2(sin(sample.bearing-phi),cos(sample.bearing-phi))
                    XCTAssertGreaterThan(delta,0, "Rightward viewpoint sign at \(cue), \(phi), \(u)")
                }
                var a = CameraSurface(cue:cue,surfaceY:0.8,viewport:viewport,bearing:phi,travel:0.4999)
                var b = CameraSurface(cue:cue,surfaceY:0.8,viewport:viewport,bearing:phi,travel:0.5001)
                let da=a.distance, db=b.distance
                a.move(points:0.1); b.move(points:0.1)
                let ratio=(b.distance-db)/(a.distance-da)
                XCTAssertEqual(ratio,1,accuracy:0.05,"No speed step at default, cue=\(cue) phi=\(phi)")
            }
        }
        // Independent camera-local projection: a forward target moves left on a right swipe.
        var s = CameraSurface(cue:.zero,surfaceY:0,viewport:viewport,bearing:0)
        let target=SIMD3<Float>(-0.8,BallPhysics.radius,0)
        func x(_ p: TwoViewCamera.Pose) -> Float {
            let local=p.orientation.inverse.act(target-p.eye)
            return local.x / -local.z / tan(p.fov * .pi/360)
        }
        let before=x(s.pose); s.orbit(points:20)
        XCTAssertLessThan(x(s.pose),before)
    }

    func testS2CoalescedInputAndReverseAcrossDefault() {
        for u: Float in [0.2,0.49,0.51,0.8] {
            let initial=CameraSurface(cue:SIMD2(1.1,0.4),surfaceY:0.8,viewport:viewport,bearing:2.3,travel:u)
            for horizontal in [false,true] {
                var one=initial, many=initial
                if horizontal { one.orbit(points:80) } else { one.move(points:80) }
                for _ in 0..<80 {
                    if horizontal { many.orbit(points:1) } else { many.move(points:1) }
                }
                XCTAssertLessThan(simd_length(one.pose.eye-many.pose.eye),0.006)
                if horizontal { one.orbit(points:-80) } else { one.move(points:-80) }
                if many.travel > 0 && many.travel < 1 {
                    XCTAssertLessThan(simd_length(one.pose.eye-initial.pose.eye),0.008)
                }
            }
        }
    }

    func testS2ScreenResponseSamples() {
        // Finite screen displacements with independent quaternion projection, logged for review.
        // The test bounds pathological response; it does not assert device comfort.
        var minimum:Float = .infinity, maximum:Float = 0
        for cue in [SIMD2<Float>(0,0),SIMD2(1.2,0.5)] {
            for phi in stride(from:-Float.pi,to:Float.pi,by:Float.pi/4) {
                for u:Float in [0.1,0.25,0.49,0.51,0.75,0.9] {
                    for horizontal in [false,true] {
                        var s=CameraSurface(cue:cue,surfaceY:0,viewport:viewport,bearing:phi,travel:u)
                        let before=s.pose
                        if horizontal { s.orbit(points:1) } else { s.move(points:1) }
                        let after=s.pose
                        var sum:Float=0, weights:Float=0
                        for x:Float in [-1.27,-0.635,0,0.635,1.27] {
                            for z:Float in [-0.635,0,0.635] {
                                let p=SIMD3(x,0,z)
                                func project(_ pose:TwoViewCamera.Pose) -> SIMD2<Float>? {
                                    let v=pose.orientation.inverse.act(p-pose.eye)
                                    guard -v.z > 0.05 else {return nil}
                                    let sy=v.y / -v.z / tan(pose.fov * .pi/360)
                                    let sx=v.x / -v.z / tan(pose.fov * .pi/360) / Float(viewport.width/viewport.height)
                                    return SIMD2(sx,sy)
                                }
                                guard let a=project(before),let b=project(after) else {continue}
                                let weight=exp(-simd_length_squared((a+b)/2))
                                let delta=(b-a)*SIMD2(Float(viewport.width),Float(viewport.height))/2
                                sum += weight*simd_length_squared(delta); weights += weight
                            }
                        }
                        let gain=sqrt(sum/max(0.00001,weights))
                        minimum=min(minimum,gain); maximum=max(maximum,gain)
                        XCTAssertGreaterThan(gain,0.1)
                        XCTAssertLessThan(gain,1.3,"cue=\(cue) phi=\(phi) u=\(u) horizontal=\(horizontal)")
                    }
                }
            }
        }
        print("S2 screen response pt/pt min=\(minimum) max=\(maximum)")
    }

    func testRigSurfaceOuterOverlayAndCueUpdatesKeepOneOwner() throws {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
        rig.viewportSize = viewport
        rig.usesSurfaceCamera = true; rig.usesMergedCamera = true
        rig.usesSimpleCueCamera = true; rig.usesTwoViewCameraControls = true
        let cue = SCNVector3(1,0.828575,0.3), aim = SCNVector3(-1,0,0)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson,cue:cue,aim:aim,duration:0))
        rig.update(deltaTime:1/60)
        XCTAssertTrue(rig.enterMergedGlobal(aim:aim))
        for _ in 0..<600 where rig.isTransitioning { rig.update(deltaTime:1/60) }
        XCTAssertFalse(rig.isTransitioning)
        XCTAssertFalse(rig.mergedGlobalActive)
        XCTAssertTrue(rig.usesTwoViewPoseControl)
        XCTAssertEqual(rig.twoViewSnapshot?.simpleShot?.surface?.travel,1)
        rig.handleHorizontalSwipe(delta:100);rig.update(deltaTime:1/60)
        let pose = node.simdTransform
        rig.updateCuePose(strike:SCNVector3(-1,0.829,0),aim:SCNVector3(0,0,1),elevation:0.5,cue:SCNVector3(-1,0.829,0))
        XCTAssertEqual(node.simdTransform,pose)
        XCTAssertTrue(rig.beginTemporaryTopDown(aim:aim))
        rig.endTemporaryTopDown();rig.update(deltaTime:1/60)
        XCTAssertEqual(node.simdTransform,pose)
    }
}
