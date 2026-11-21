import XCTest
import SceneKit
import Metal
import Combine
@testable import QiuJi

final class CameraSurfaceTests: XCTestCase {
    private let viewport = CGSize(width:874,height:402)

    @MainActor
    func testC54SurfaceFirstPersonPeekAndOverviewRoundTrip() throws {
        let scene = AngleTrainingScene()
        scene.configureDailyClearanceRendering(); scene.setupScene()
        let rig = try XCTUnwrap(scene.cameraRig)
        rig.usesTwoViewCameraControls = true; rig.usesSimpleCueCamera = true
        rig.usesMergedCamera = true; rig.usesSurfaceCamera = true; rig.viewportSize = viewport
        let cue = SCNVector3(0, scene.surfaceY + BallPhysics.radius, 0)
        let aim = SCNVector3(-1, 0, 0)
        func settle() { for _ in 0..<1200 { rig.update(deltaTime: 1 / 120) } }
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson, cue: cue, aim: aim, duration: 0))
        rig.updateCuePose(strike: cue, aim: aim, elevation: 0.05, cue: cue)
        settle()
        XCTAssertTrue(rig.enterPlayerView(.firstPerson, cue: cue, aim: aim, duration: 0.2))
        settle()
        XCTAssertEqual(rig.playerView, .firstPerson)
        XCTAssertEqual(rig.twoViewMode, .firstPerson)
        XCTAssertNil(rig.twoViewSnapshot?.simpleShot, "Surface gestures must release ownership to first-person")
        let originalEye = scene.cameraNode.simdPosition
        rig.updateCuePose(strike: cue, aim: SCNVector3(0, 0, -1), elevation: 0.05, cue: cue)
        settle()
        XCTAssertEqual(rig.twoViewMode, .firstPerson)
        XCTAssertGreaterThan(simd_distance(scene.cameraNode.simdPosition, originalEye), 0.05,
                             "First-person camera follows a changed shot direction")
        let firstPerson = scene.cameraNode.simdTransform
        XCTAssertTrue(rig.beginTemporaryTopDown(aim: aim))
        settle()
        XCTAssertTrue(rig.temporaryTopDownActive)
        rig.endTemporaryTopDown()
        settle()
        XCTAssertEqual(rig.twoViewMode, .firstPerson)
        XCTAssertEqual(scene.cameraNode.simdTransform, firstPerson)
        XCTAssertTrue(rig.enterMergedGlobal(aim: aim, cue: cue))
        settle()
        XCTAssertTrue(rig.overviewControlSelected)
        XCTAssertEqual(rig.twoViewMode, .thirdPerson)
        XCTAssertTrue(rig.enterPlayerView(.thirdPerson, cue: cue, aim: aim, duration: 0))
        settle()
        XCTAssertFalse(rig.overviewControlSelected)
    }

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
        vm.usesAutomaticPocketFallback = true; vm.usesShotComfortRanking = true
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
    func testP01RenderingAndCameraPoliciesAreIndependent() throws {
        for referenceRendering in [false, true] {
            for shotCamera in [false, true] {
                let host = PositionPlayViewModel()
                let initialProfile = host.scene.renderingProfile
                if referenceRendering { host.scene.configureReferenceTableRendering() }
                if shotCamera { host.scene.configureShotAwareCamera() }
                host.setupScene()
                host.enablePlayerCameraControls()
                let rig = try XCTUnwrap(host.scene.cameraRig)
                XCTAssertEqual(host.scene.renderingProfile, referenceRendering ? .reflection : initialProfile)
                XCTAssertEqual(host.scene.sceneExposureOffset, referenceRendering ? -0.1 : nil)
                XCTAssertEqual(rig.usesTwoViewCameraControls, shotCamera)
                XCTAssertEqual(rig.usesSurfaceCamera, shotCamera)
                XCTAssertTrue(rig.usesRailCameraControls, "Player controls retain their base rail policy in both camera modes")
            }
        }
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


    @MainActor
    func testAngleTeachingUsesP01AndPreservesTeachingState() throws {
        let vm = AngleDynamicViewModel()
        vm.setupScene()
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = viewport
        vm.setCameraMode(.perspective3D)
        XCTAssertTrue(rig.p01AnchoredTransitions)
        let aim = try XCTUnwrap(vm.currentPlayerAim)
        let initialAngle = vm.cutAngleDegrees
        let pocket = vm.selectedPocketIndex
        let target = vm.selectedTargetKey
        let initial = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertLessThan(simd_distance(initial.shot.aim, SIMD3(aim.x, aim.y, aim.z)), 0.0001)
        let pose = try XCTUnwrap(rig.p01Snapshot).pose.transform
        vm.updateCalculations()
        XCTAssertEqual(rig.p01Snapshot?.pose.transform, pose, "Ordinary teaching refresh must not reframe")
        XCTAssertTrue(vm.requestPlayerView(.firstPerson, animated: false))
        vm.beginTemporaryTopDown()
        XCTAssertTrue(vm.temporaryTopDownActive)
        let first = try XCTUnwrap(rig.p01Snapshot).pose.transform
        vm.endTemporaryTopDown()
        XCTAssertEqual(rig.p01Snapshot?.pose.transform, first)
        vm.requestSurfaceOverview()
        for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime: 1/120) }
        XCTAssertTrue(rig.overviewControlSelected)
        XCTAssertEqual(rig.p01Snapshot?.state.view, .overview)
        XCTAssertEqual(vm.cutAngleDegrees, initialAngle)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertEqual(vm.selectedTargetKey, target)
        let beforeReselect = try XCTUnwrap(rig.p01Snapshot).pose.transform
        vm.beginTemporaryTopDown()
        XCTAssertTrue(vm.temporaryTopDownActive)
        vm.selectPocket(at: pocket)
        vm.endTemporaryTopDown()
        for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime: 1/120) }
        // TeachingCameraHost has preserved the visible pose since f75cbafdc (2026-10-11).
        // Re-selecting the same pocket is not a request to enter third person.
        XCTAssertEqual(try XCTUnwrap(rig.p01Snapshot).pose.transform, beforeReselect)
        XCTAssertTrue(rig.overviewControlSelected)
        XCTAssertFalse(vm.cameraTransitionBusy)
    }

    @MainActor
    func testSeparationAtlasReusesTeachingCameraWithoutChangingTracksOrSpeed() throws {
        let vm = SeparationAngleAtlasViewModel()
        vm.setupScene()
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = viewport
        vm.setCameraMode(.perspective3D)
        XCTAssertTrue(rig.p01AnchoredTransitions)
        let aim = try XCTUnwrap(vm.currentPlayerAim)
        let initial = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertLessThan(simd_distance(initial.shot.aim, SIMD3(aim.x, aim.y, aim.z)), 0.0001)
        let pose = try XCTUnwrap(rig.p01Snapshot).pose.transform
        vm.velocity = 3.25; vm.onVelocityChanged(); vm.toggleTrack(2)
        XCTAssertEqual(rig.p01Snapshot?.pose.transform, pose)
        XCTAssertTrue(vm.requestPlayerView(.firstPerson, animated: false))
        let firstPerson = try XCTUnwrap(rig.p01Snapshot).pose.transform
        vm.beginTemporaryTopDown(); XCTAssertTrue(vm.temporaryTopDownActive)
        let revision = vm.topDownContentRevision
        vm.toggleTrack(3)
        XCTAssertGreaterThan(vm.topDownContentRevision, revision)
        vm.endTemporaryTopDown()
        XCTAssertEqual(rig.p01Snapshot?.pose.transform, firstPerson)
        XCTAssertEqual(vm.velocity, 3.25)
        XCTAssertEqual(vm.enabledTracks, Set([0,1,4,5,6,7]))
        vm.beginTemporaryTopDown(); vm.selectPocket(at: vm.selectedPocketIndex); vm.endTemporaryTopDown()
        for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime: 1/120) }
        // A same-pocket selection retains the pre-overlay first-person pose.
        XCTAssertEqual(try XCTUnwrap(rig.p01Snapshot).pose.transform, firstPerson)
        XCTAssertEqual(rig.twoViewMode, .firstPerson)
        vm.removeFromTable("_8")
        XCTAssertNil(vm.currentPlayerAim)
        XCTAssertTrue(vm.scene.cueStick?.rootNode.isHidden ?? true)
        vm.setCameraMode(.topDown2D)
        vm.placeFromPalette("_8")
        XCTAssertNotNil(vm.currentPlayerAim)
    }

    @MainActor
    func testCushionAtlasReusesTeachingCameraAndPreservesCueHeight() throws {
        let vm = CushionEnglishAtlasViewModel()
        vm.setupScene()
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = viewport
        vm.setCameraMode(.perspective3D)
        XCTAssertTrue(rig.p01AnchoredTransitions)
        let aim = try XCTUnwrap(vm.currentPlayerAim)
        let initial = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertLessThan(simd_distance(initial.shot.aim, SIMD3(aim.x, aim.y, aim.z)), 0.0001)
        let pose = try XCTUnwrap(rig.p01Snapshot).pose.transform
        vm.velocity = 3.25; vm.onVelocityChanged(); vm.toggleTrack(2)
        vm.spinY = 0.15; vm.onCueHeightChanged()
        XCTAssertEqual(vm.spinY, 0.15, accuracy: 0.00001)
        XCTAssertEqual(rig.p01Snapshot?.pose.transform, pose)
        XCTAssertTrue(vm.requestPlayerView(.firstPerson, animated: false))
        let firstAddress = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertGreaterThan(firstAddress.shot.strike.y, initial.shot.strike.y)
        let shaft = try XCTUnwrap(vm.scene.cueStick).rootNode
        XCTAssertFalse(shaft.isHidden)
        XCTAssertLessThan(simd_distance(firstAddress.shot.strike, shaft.simdPosition), 0.0001)
        let firstPerson = firstAddress.pose.transform
        vm.beginTemporaryTopDown(); XCTAssertTrue(vm.temporaryTopDownActive)
        let revision = vm.topDownContentRevision
        vm.spinY = 0.2; vm.onCueHeightChanged()
        vm.toggleTrack(3)
        XCTAssertGreaterThan(vm.topDownContentRevision, revision)
        vm.endTemporaryTopDown()
        XCTAssertEqual(rig.p01Snapshot?.pose.transform, firstPerson)
        XCTAssertEqual(vm.velocity, 3.25)
        XCTAssertEqual(vm.spinY, 0.2, accuracy: 0.00001)
        XCTAssertTrue(vm.scene.usesAdaptiveDiagramLabels)
        XCTAssertFalse(vm.scene.diagramShowsLineLabels)
        XCTAssertEqual(vm.enabledTracks, Set([0,1,4,5,6,7]))
        vm.beginTemporaryTopDown(); vm.selectPocket(at: vm.selectedPocketIndex); vm.endTemporaryTopDown()
        for _ in 0..<1200 where rig.isTransitioning { rig.update(deltaTime: 1/120) }
        // A same-pocket selection retains the pre-overlay first-person pose.
        XCTAssertEqual(try XCTUnwrap(rig.p01Snapshot).pose.transform, firstPerson)
        XCTAssertEqual(rig.twoViewMode, .firstPerson)
        vm.removeFromTable("_8")
        XCTAssertNil(vm.currentPlayerAim)
        XCTAssertTrue(vm.scene.cueStick?.rootNode.isHidden ?? true)
        vm.setCameraMode(.topDown2D)
        vm.placeFromPalette("_8")
        XCTAssertNotNil(vm.currentPlayerAim)
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

/// The new facade is opt-in; old CameraSurface assertions above remain unchanged.
final class P01CameraIntegrationTests: XCTestCase {
    @MainActor
    private func rig() -> CameraRig {
        let node = SCNNode(); node.camera = SCNCamera()
        let rig = CameraRig(cameraNode:node,tableSurfaceY:0.8,config:.dailyClearance)
        rig.configurePlayerCameraControls(daily:true,policy:.p01Replayable)
        rig.viewportSize = .init(width:874,height:402)
        rig.setTwoViewReadableInsets(.init(top:42,left:128,bottom:18,right:128))
        return rig
    }
    @MainActor
    private func settle(_ rig: CameraRig) {
        for _ in 0..<1800 { rig.update(deltaTime:1/120) }
        XCTAssertFalse(rig.isTransitioning); XCTAssertFalse(rig.hasPendingDamping)
    }
    @MainActor
    func testAuthoredTeachingPagesUseP01WithTheirOwnObservationReferences() throws {
        func check<T: TeachingTableHost>(_ page: T, file: StaticString = #filePath, line: UInt = #line) throws {
            page.setupScene()
            let rig = try XCTUnwrap(page.scene.cameraRig, file: file, line: line)
            rig.viewportSize = CGSize(width: 874, height: 402)
            page.setCameraMode(.perspective3D)
            XCTAssertTrue(rig.p01AnchoredTransitions, file: file, line: line)
            XCTAssertNotNil(rig.p01Snapshot, file: file, line: line)
        }
        try check(AngleDynamicViewModel())
        try check(SeparationAngleAtlasViewModel())
        try check(CushionEnglishAtlasViewModel())
        let object = PocketToleranceViewModel()
        try check(object)
        let rig = try XCTUnwrap(object.scene.cameraRig)
        let target = try XCTUnwrap(object.targetNode).simdPosition
        let atEntry = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertEqual(atEntry.shot.cue, target)
        XCTAssertTrue(object.scene.cueBallNode?.isHidden ?? true)
        object.selectPocket(at: 3)
        XCTAssertTrue(object.requestTeachingObjectObservation(animated: false))
        let before = try XCTUnwrap(rig.p01Snapshot)
        let pocket = try XCTUnwrap(rig.observationPocket).position
        let direction = SIMD2(pocket.x - target.x, pocket.z - target.z)
        XCTAssertLessThan(simd_distance(SIMD2(before.shot.aim.x, before.shot.aim.z), simd_normalize(direction)), 0.0001)
        object.beginCameraObservation()
        rig.handleHorizontalSwipe(delta: 75)
        object.endCameraObservation()
        XCTAssertNotEqual(rig.p01Snapshot?.pose, before.pose)
        XCTAssertFalse(object.requestPlayerView(.firstPerson, animated: false))
        XCTAssertEqual(object.selectedPocketIndex, 3)
        XCTAssertTrue(object.scene.cueBallNode?.isHidden ?? true)
    }

    @MainActor
    func testP01AngleQuizObservesVisibleBallsWithoutUsingTheAnswer() throws {
        let suite = "p01-angle-quiz.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let quiz = AimingQuizViewModel(limiter: AngleUsageLimiter(defaults: defaults))
        quiz.setupScene(initialCameraMode: .topDown2D)
        let rig = try XCTUnwrap(quiz.scene.cameraRig)
        rig.viewportSize = CGSize(width: 874, height: 402)
        quiz.setCameraMode(.perspective3D)
        XCTAssertTrue(quiz.requestPlayerView(.thirdPerson, animated: false))
        let camera = try XCTUnwrap(rig.p01Snapshot)
        let cue = try XCTUnwrap(quiz.scene.cueBallNode).simdPosition
        let target = try XCTUnwrap(quiz.targetNode).simdPosition
        XCTAssertLessThan(simd_distance(SIMD2(camera.shot.aim.x, camera.shot.aim.z),
                                         simd_normalize(SIMD2(target.x - cue.x, target.z - cue.z))), 0.0001)
        XCTAssertFalse(quiz.requestPlayerView(.firstPerson, animated: false))
        quiz.toggleAimingAssist()
        XCTAssertEqual(rig.p01Snapshot?.shot.aim, camera.shot.aim, "Displaying the authored auxiliary shaft must not move the observation camera")
        XCTAssertTrue(quiz.run.firstAnswers.isEmpty)
    }
    @MainActor
    func testExplicitPolicyAndSharedHostDefaults() {
        XCTAssertEqual(PositionPlayComposerView().cameraPolicy,.legacy)
        XCTAssertEqual(PositionPlayComposerView(cameraPolicy:.p01Replayable).cameraPolicy,.p01Replayable)
        for daily in [false,true] {
            let node=SCNNode();node.camera=SCNCamera()
            let old=CameraRig(cameraNode:node,tableSurfaceY:0.8)
            old.configurePlayerCameraControls(daily:daily)
            XCTAssertFalse(old.usesP01Camera);XCTAssertEqual(old.usesSurfaceCamera,daily)
        }
        let pilot=rig();XCTAssertTrue(pilot.usesP01Camera)
        XCTAssertFalse(pilot.usesSurfaceCamera);XCTAssertNil(pilot.twoViewSnapshot)
    }

    @MainActor
    func testAnchoredTransitionsMatchOptedInPracticeHostsAndPreserveUnanchoredReplay() throws {
        let practice = PositionPlayViewModel()
        practice.scene.configureShotAwareCamera()
        practice.setupScene()
        practice.enablePlayerCameraControls(policy: .p01Replayable)
        defer { practice.cancelInteractiveTrajectoryPreview() }

        let suite = "p01.transition-isolation." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let archive = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let spatial = SpatialPracticeViewModel(defaults: defaults, ownerContext: CurrentOwnerContext(defaults: defaults),
                                               archiveRoot: archive)
        spatial.setupScene()
        defer {
            spatial.suspendTeachingActivity()
            defaults.removePersistentDomain(forName: suite)
            if FileManager.default.fileExists(atPath: archive.path) {
                XCTAssertNoThrow(try FileManager.default.removeItem(at: archive))
            }
        }

        let practiceRig = try XCTUnwrap(practice.scene.cameraRig)
        let spatialRig = try XCTUnwrap(spatial.scene.cameraRig)
        // Older recordings and explicit unanchored rigs retain their original interpolation.
        let unanchoredRig = rig()
        for (rig, height, anchored) in [(practiceRig, practice.scene.surfaceY, true),
                                        (spatialRig, spatial.scene.surfaceY, true),
                                        (unanchoredRig, Float(0.8), false)] {
            rig.viewportSize = .init(width: 874, height: 402)
            let cue = SCNVector3(0.3, height + BallPhysics.radius, 0.37)
            let aim = SCNVector3(0.766, 0, -0.643)
            XCTAssertEqual(rig.cameraPolicy, .p01Replayable)
            rig.updateCuePose(strike: cue, aim: aim, elevation: 0.05, cue: cue)
            XCTAssertTrue(rig.enterPlayerView(.thirdPerson, cue: cue, aim: aim, duration: 0))
            let base = try XCTUnwrap(rig.p01Snapshot)
            XCTAssertEqual(base.state.fixedAxisOrbit, true, "Both hosts keep their existing orbit configuration")
            XCTAssertEqual(base.state.anchoredTransitions == true, anchored)
            XCTAssertTrue(rig.enterPlayerView(.firstPerson, cue: cue, aim: aim))
            let snapshot = try XCTUnwrap(rig.p01Snapshot)
            let move = try XCTUnwrap(snapshot.motion)
            let layout = try XCTUnwrap(snapshot.layout)
            let end = try XCTUnwrap(P01CameraMotion.evaluate(state: snapshot.state, shot: snapshot.shot, layout: layout))
            XCTAssertEqual(move.framing != nil, anchored)
            XCTAssertEqual(move.lift, anchored ? 0 : 0.15, accuracy: 0.00001)
            rig.update(deltaTime: Float(move.duration / 2))
            let halfway = try XCTUnwrap(rig.p01Snapshot).pose
            XCTAssertEqual(halfway.eye.y, (base.pose.eye.y + end.eye.y) / 2 + move.lift, accuracy: 0.00001)
            if anchored {
                let cueProjection = try XCTUnwrap(halfway.project(snapshot.shot.cue, layout: layout))
                XCTAssertEqual(cueProjection.y, 0.685, accuracy: 0.00001)
            } else {
                let length = simd_distance(base.pose.eye, end.eye) + 4 * move.lift
                let angle = abs(P01CameraMotion.angleDelta(base.pose.yaw, end.yaw))
                    + abs(end.pitch - base.pose.pitch) + 2 * move.lift
                let lens = abs(end.verticalFOV - base.pose.verticalFOV)
                let expected = max(0.25, 1.875 * Double(length) / 1.8,
                                   1.875 * Double(angle) / (.pi / 2), 1.875 * Double(lens) / 40)
                XCTAssertEqual(move.duration, expected, accuracy: 0.000001)
            }
        }
    }

    @MainActor
    func testIndependentInputsAndFixedEyeHeadReturn() throws {
        let r=rig(),cue=SCNVector3(0,0.828575,0),aim=SCNVector3(1,0,0)
        XCTAssertTrue(r.enterPlayerView(.thirdPerson,cue:cue,aim:aim,duration:0))
        let base=try XCTUnwrap(r.p01Snapshot)
        XCTAssertTrue(r.prepareTemporaryObservation(cue:cue,aim:aim))
        r.handleVerticalSwipe(delta:40)
        let high=try XCTUnwrap(r.p01Snapshot)
        XCTAssertEqual(high.pose.eye.x,base.pose.eye.x);XCTAssertEqual(high.pose.eye.z,base.pose.eye.z)
        r.handlePinch(scale:1.2)
        XCTAssertEqual(r.p01Snapshot?.pose.eye.y,high.pose.eye.y)
        XCTAssertEqual(r.p01Snapshot?.shot,base.shot)
        XCTAssertTrue(r.enterPlayerView(.firstPerson,cue:cue,aim:aim,duration:0))
        let fp=try XCTUnwrap(r.p01Snapshot)
        _=r.prepareTemporaryObservation(cue:cue,aim:aim);r.handleHorizontalSwipe(delta:80)
        XCTAssertEqual(r.p01Snapshot?.pose.eye,fp.pose.eye)
        r.endTemporaryObservation()
        for _ in 0..<600 {
            r.update(deltaTime:1/120)
            XCTAssertEqual(r.p01Snapshot?.pose.eye,fp.pose.eye)
        }
        XCTAssertLessThan(simd_distance(try XCTUnwrap(r.p01Snapshot).pose.forward,fp.pose.forward),0.00001)
    }
    @MainActor
    func testOverlay2DRoundTripAndBoardGeneration() throws {
        let r=rig(),cue=SCNVector3(0,0.828575,0),aim=SCNVector3(1,0,0)
        _=r.enterPlayerView(.thirdPerson,cue:cue,aim:aim,duration:0)
        r.handleHorizontalSwipe(delta:80);let saved=r.capturePerspectiveState()
        let before=try XCTUnwrap(r.p01Snapshot).pose
        XCTAssertTrue(r.beginTemporaryTopDown(aim:aim));r.update(deltaTime:1)
        r.endTemporaryTopDown();XCTAssertEqual(r.p01Snapshot?.pose,before)
        r.applyTopDown2D();r.update(deltaTime:1)
        r.restorePerspectiveState(saved);XCTAssertEqual(r.p01Snapshot?.pose,before)
        _=r.enterMergedGlobal(aim:aim);r.update(deltaTime:0.2)
        let interrupted=r.capturePerspectiveState(),visible=try XCTUnwrap(r.p01Snapshot).pose
        r.applyTopDown2D();XCTAssertFalse(r.hasPendingDamping);XCTAssertFalse(r.isTransitioning)
        r.restorePerspectiveState(interrupted);settle(r)
        XCTAssertEqual(r.p01Snapshot?.pose,visible)
        r.restorePerspectiveState(saved)
        r.setTwoViewViewingContext(UUID())
        r.updateCuePose(strike:.init(0.4,0.828575,0),aim:aim,elevation:0.05,cue:.init(0.4,0.828575,0))
        r.restorePerspectiveState(saved)
        XCTAssertEqual(r.p01Snapshot?.shot.cue.x,0.4)
        r.restorePerspectiveState(saved,restoringBoard:true)
        XCTAssertEqual(r.p01Snapshot?.pose,before)
        settle(r);XCTAssertEqual(r.p01Snapshot?.pose,before)
    }
    @MainActor
    func testLateLayoutAndFrozenShotReference() throws {
        let r=rig();r.viewportSize = .zero
        let cue=SCNVector3(0,0.828575,0),aim=SCNVector3(1,0,0)
        XCTAssertFalse(r.enterPlayerView(.firstPerson,cue:cue,aim:aim,duration:0))
        r.viewportSize = .init(width:874,height:402)
        XCTAssertEqual(r.p01Snapshot?.state.view,.firstPerson)
        let before=try XCTUnwrap(r.p01Snapshot)
        r.p01ShotFrozen=true
        r.updateCuePose(strike:.init(0.8,0.828575,0),aim:.init(0,0,1),elevation:0.3,cue:.init(0.8,0.828575,0))
        settle(r);XCTAssertEqual(r.p01Snapshot?.shot,before.shot)
        XCTAssertEqual(r.p01Snapshot?.pose,before.pose)
    }
    @MainActor
    func testRealTableMeshFirstPersonAtRailsAndCorners() throws {
        let scene=AngleTrainingScene();scene.configureShotAwareCamera();scene.setupScene()
        let r=try XCTUnwrap(scene.cameraRig)
        r.configurePlayerCameraControls(daily:true,policy:.p01Replayable)
        r.viewportSize = .init(width:874,height:402)
        for point in [SIMD2<Float>(0,0),.init(0,0.57),.init(1.2,0),.init(1.2,0.57),.init(-1.2,-0.57)] {
            for angle in stride(from:Float(0),to:2 * .pi,by:.pi/4) {
                let cue=SCNVector3(point.x,scene.surfaceY+BallPhysics.radius,point.y)
                let aim=SCNVector3(cos(angle),0,sin(angle))
                r.updateCuePose(strike:cue,aim:aim,elevation:0.05,cue:cue)
                XCTAssertTrue(r.enterPlayerView(.firstPerson,cue:cue,aim:aim,duration:0),"cue=\(point) aim=\(angle)")
                let state=try XCTUnwrap(r.p01Snapshot)
                XCTAssertLessThanOrEqual(state.pose.eye.y-cue.y,0.9*sin(0.05)+0.13+0.2001)
                XCTAssertGreaterThan(state.pose.eye.y,scene.surfaceY+0.12)
            }
        }
    }
    @MainActor
    func testVMWheelCommitsFreeModeWithoutBlockingAndPreservesParameters() async throws {
        let vm=PositionPlayViewModel();vm.scene.configureShotAwareCamera();vm.setupScene()
        vm.enablePlayerCameraControls(policy:.p01Replayable)
        let r=try XCTUnwrap(vm.scene.cameraRig);r.viewportSize = .init(width:874,height:402)
        vm.usesAutomaticPocketFallback=true
        vm.loadBoard(PositionPlayComposerView.defaultBoard)
        _=vm.selectTarget(key:"_1");vm.selectPocket(at:1)
        for _ in 0..<100 where vm.isComputing { try await Task.sleep(for:.milliseconds(100)) }
        XCTAssertFalse(vm.isComputing)
        _=ShotPlayCamera.setMode(.perspective3D,on:vm)
        let aim=try XCTUnwrap(vm.currentPlayerAim),cue=try XCTUnwrap(vm.scene.cueBallNode).position
        for view in [CameraRig.PlayerView.thirdPerson,.firstPerson] {
            XCTAssertTrue(vm.requestPlayerView(view,animated:false))
            r.prepareTemporaryObservation(cue:cue,aim:vm.currentPlayerAim ?? aim)
            r.handleHorizontalSwipe(delta:100)
            let velocity=vm.velocity,spinX=vm.spinX,spinY=vm.spinY,target=vm.selectedTargetKey,pocket=vm.selectedPocketIndex
            for _ in 0..<100 { vm.nudgeFreeAim(byDegrees:0.1);r.update(deltaTime:1/120) }
            XCTAssertEqual(vm.aimMode,.free);XCTAssertFalse(vm.cameraTransitionBusy)
            XCTAssertEqual(vm.velocity,velocity);XCTAssertEqual(vm.spinX,spinX);XCTAssertEqual(vm.spinY,spinY)
            XCTAssertEqual(vm.selectedTargetKey,target);XCTAssertEqual(vm.selectedPocketIndex,pocket)
            settle(r)
            let shown=try XCTUnwrap(r.p01Snapshot)
            let forward=simd_normalize(SIMD2(shown.pose.forward.x,shown.pose.forward.z))
            let current=try XCTUnwrap(vm.currentPlayerAim)
            XCTAssertGreaterThan(simd_dot(forward,SIMD2(current.x,current.z)),0.99999)
            vm.nudgeFreeAim(byDegrees:-10);settle(r);XCTAssertEqual(vm.aimMode,.free)
        }
    }

    @MainActor
    private func waitForSelectionPrediction(_ vm: PositionPlayViewModel) async throws {
        for _ in 0..<200 where vm.isComputing { try await Task.sleep(for: .milliseconds(25)) }
        XCTAssertFalse(vm.isComputing)
    }

    @MainActor
    private func selectionFixture() async throws -> (PositionPlayViewModel, CameraRig) {
        let vm = PositionPlayViewModel()
        vm.scene.configureShotAwareCamera()
        vm.setupScene()
        vm.enablePlayerCameraControls(policy: .p01Replayable)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = .init(width: 874, height: 402)
        vm.usesAutomaticPocketFallback = true
        vm.loadBoard(PositionPlayComposerView.defaultBoard)
        vm.setPreferredAimMode(.free)
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        try await waitForSelectionPrediction(vm)
        _ = ShotPlayCamera.setMode(.perspective3D, on: vm)
        XCTAssertTrue(vm.requestPlayerView(.thirdPerson, animated: false))
        return (vm, rig)
    }

    @MainActor
    private func recordedInputs(_ rig: CameraRig) throws -> [P01CameraMotion.Input] {
        try JSONDecoder().decode(P01CameraMotion.Recording.self, from: XCTUnwrap(rig.p01ReplayData)).inputs
    }

    @MainActor
    func testFirstPersonTablePanSwitchesFromPocketAndKeepsNewBearing() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.setPreferredAimMode(.pocket)
        try await waitForSelectionPrediction(vm)
        XCTAssertEqual(vm.aimMode, .pocket)
        XCTAssertFalse(vm.canNudgeP01TableAim)
        XCTAssertTrue(vm.requestPlayerView(.firstPerson, animated: false))
        XCTAssertTrue(vm.canNudgeP01TableAim)
        let stick = try XCTUnwrap(vm.scene.cueStick)
        let camera = try XCTUnwrap(rig.p01Snapshot)
        let offset = try XCTUnwrap(camera.shot.addressButtOffset)
        XCTAssertEqual(offset, stick.addressButtOffset)
        let butt = stick.rootNode.simdConvertPosition(SIMD3(0, 0, offset), to: nil)
        XCTAssertEqual(camera.pose.eye.x, butt.x, accuracy: 0.0001)
        XCTAssertEqual(camera.pose.eye.z, butt.z, accuracy: 0.0001)
        XCTAssertEqual(camera.pose.eye.y, butt.y + 0.13 + camera.state.firstPersonClearanceLift, accuracy: 0.0001)
        let before = try XCTUnwrap(vm.scene.lastCueAim)
        let count = try recordedInputs(rig).count
        vm.nudgeP01TableFreeAim(byDegrees: 8)
        vm.nudgeP01TableFreeAim(byDegrees: -3)
        try await waitForSelectionPrediction(vm)
        settle(rig)
        XCTAssertEqual(vm.aimMode, .free)
        XCTAssertEqual(vm.preferredAimMode, .pocket)
        let expected = AngleSceneCalculator.rotatedAim(before, byDegrees: 5)
        let actual = try XCTUnwrap(rig.p01Snapshot?.shot.aim)
        XCTAssertGreaterThan(simd_dot(actual, SIMD3(expected.x, expected.y, expected.z)), 0.99999)
        XCTAssertEqual(rig.p01Snapshot?.state.headYaw, 0)
        XCTAssertEqual(try recordedInputs(rig).dropFirst(count).map(\.kind), [.aim, .aim])
        vm.requestSurfaceOverview()
        XCTAssertFalse(vm.canNudgeP01TableAim)
    }

    @MainActor
    func testP01FreeTablePanSubmitsOneCameraInputUsingTheDisplayedShaft() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.usesContinuousTrajectoryPreview = true
        let stick = try XCTUnwrap(vm.scene.cueStick?.rootNode)
        for view in [CameraRig.PlayerView.thirdPerson, .firstPerson] {
            XCTAssertTrue(vm.requestPlayerView(view, animated: false))
            vm.scene.explicitCueElevation = view == .thirdPerson ? 0.14 : 0.20
            let count = try recordedInputs(rig).count
            let before = try XCTUnwrap(vm.freeAimDir)
            var selectionPublications = 0
            let publication = rig.objectWillChange.sink { selectionPublications += 1 }
            vm.nudgeP01TableFreeAim(byDegrees: 12)
            publication.cancel()
            XCTAssertEqual(selectionPublications, 0, "A new shaft direction does not change camera selection")

            let delivered = try recordedInputs(rig).dropFirst(count)
            XCTAssertEqual(delivered.map(\.kind), [.aim])
            let shot = try XCTUnwrap(delivered.first?.shot)
            let current = try XCTUnwrap(vm.freeAimDir)
            let authored = AngleSceneCalculator.rotatedAim(before, byDegrees: 12)
            XCTAssertEqual(SIMD3(current.x, current.y, current.z), SIMD3(authored.x, authored.y, authored.z))
            XCTAssertEqual(shot.aim, SIMD3(current.x, current.y, current.z))
            XCTAssertFalse(stick.isHidden)
            XCTAssertEqual(shot.strike, SIMD3(stick.position.x, stick.position.y, stick.position.z))
            XCTAssertEqual(shot.elevation, -stick.eulerAngles.x, accuracy: 0.00001)
            XCTAssertEqual(shot.elevation, try XCTUnwrap(vm.scene.explicitCueElevation), accuracy: 0.00001)
            XCTAssertEqual(rig.p01Snapshot?.shot, shot)
            XCTAssertTrue(vm.isComputing, "The P01 sample retains its continuous prediction")
            try await waitForSelectionPrediction(vm)
        }
    }

    @MainActor
    func testSlowTableAimKeepsCameraAndShaftTogetherWithAndWithoutAssists() async throws {
        let (vm, rig, _) = try await liveBoardFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.setPreferredAimMode(.free)
        try await waitForSelectionPrediction(vm)
        let saved = try XCTUnwrap(vm.savedBoard)
        var traces = [[SIMD3<Float>]]()
        for hidden in [false, true] {
            try vm.restoreSavedBoard(saved)
            vm.hides3DShotAssists = hidden
            try await waitForSelectionPrediction(vm)
            XCTAssertTrue(vm.requestPlayerView(.firstPerson, animated: false))
            let initialAim = try XCTUnwrap(vm.freeAimDir)
            let cue = try XCTUnwrap(vm.scene.cueBallNode)
            let node = try XCTUnwrap(vm.scene.cameraNode)
            var trace = [SIMD3<Float>]()
            vm.setAimTableDragging(true)
            for index in 1...12 {
                vm.nudgeP01TableFreeAim(byDegrees: 0.025)
                rig.update(deltaTime: 1 / 60)
                let shot = try XCTUnwrap(rig.p01Snapshot)
                XCTAssertNil(shot.motion)
                let expected = AngleSceneCalculator.rotatedAim(initialAim, byDegrees: Float(index) * 0.025)
                XCTAssertLessThan(simd_distance(shot.shot.aim, SIMD3(expected.x, expected.y, expected.z)), 0.00001)
                XCTAssertEqual(shot.shot.cue, cue.simdPosition)
                XCTAssertEqual(node.simdPosition, shot.pose.eye)
                XCTAssertTrue(vm.scene.closeupCuePath.isEmpty)
                XCTAssertNil(vm.livePreviewShot)
                XCTAssertEqual(vm.scene.rootNode.childNode(withName: "freeAimPreview", recursively: false) != nil, !hidden)
                trace.append(node.simdPosition)
                try await Task.sleep(for: .milliseconds(35))
                XCTAssertEqual(node.simdPosition, trace.last)
            }
            vm.setAimTableDragging(false)
            let atRelease = try XCTUnwrap(rig.p01Snapshot)
            try await waitForSelectionPrediction(vm)
            settle(rig)
            let solved = try XCTUnwrap(vm.solvedShot?.shot.freeAim)
            let expected = PositionPlayShotSolver.canvasDirection(fromScene: SCNVector3(atRelease.shot.aim))
            XCTAssertEqual(solved.x, expected.x, accuracy: 0.00001)
            XCTAssertEqual(solved.y, expected.y, accuracy: 0.00001)
            XCTAssertEqual(rig.p01Snapshot?.pose, atRelease.pose)
            XCTAssertEqual(vm.scene.closeupCuePath.isEmpty, hidden)
            traces.append(trace)
        }
        XCTAssertEqual(traces[0], traces[1])
    }

    @MainActor
    func testP01FreeTargetAndPocketEachTurnBeforePrediction() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let target = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        let centerLine = simd_normalize(target.simdPosition - cue.simdPosition)
        for temporary in [false, true] {
            if temporary {
                vm.setPreferredAimMode(.pocket)
                try await waitForSelectionPrediction(vm)
                vm.nudgeFreeAim(byDegrees: 15)
            } else { vm.nudgeFreeAim(byDegrees: -14) }
            let count = try recordedInputs(rig).count
            XCTAssertTrue(vm.selectTarget(key: "_1"))
            XCTAssertEqual(vm.aimMode, .free)
            XCTAssertEqual(vm.selectedPocketIndex, -1)
            XCTAssertGreaterThan(simd_dot(try XCTUnwrap(rig.p01Snapshot?.shot.aim), centerLine), 0.99999)
            vm.selectPocket(at: 0)
            let final = try XCTUnwrap(rig.p01Snapshot?.shot.aim)
            XCTAssertLessThan(simd_dot(centerLine, final), 0.99999)
            try await waitForSelectionPrediction(vm)
            XCTAssertEqual(vm.selectedPocketIndex, 0)
            XCTAssertEqual(try recordedInputs(rig).dropFirst(count).filter { $0.kind == .target }.count, 2)
        }
    }

    @MainActor
    func testHandPickedTargetShowsCueBeforePocketSelection() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.setPreferredAimMode(.pocket)
        vm.setAutomaticRecommendation(false)
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let target = try XCTUnwrap(vm.scene.allBallNodes["_1"])
        let shaft = try XCTUnwrap(vm.scene.cueStick)
        let centerLine = simd_normalize(target.simdPosition - cue.simdPosition)
        for _ in 0..<2 {
            XCTAssertTrue(vm.selectTarget(key: "_1"))
            XCTAssertEqual(vm.selectedPocketIndex, -1)
            XCTAssertFalse(shaft.rootNode.isHidden)
            let aim = try XCTUnwrap(vm.scene.lastCueAim)
            XCTAssertGreaterThan(simd_dot(SIMD3(aim.x, aim.y, aim.z), centerLine), 0.99999)
            XCTAssertGreaterThan(simd_dot(try XCTUnwrap(rig.p01Snapshot).shot.aim, centerLine), 0.99999)
            XCTAssertNil(vm.solvedShot)
            XCTAssertFalse(vm.isFeasible)
        }
        func previewCount() -> Int { vm.scene.rootNode.childNodes.filter { $0.name == "freeAimPreview" }.count }
        XCTAssertEqual(previewCount(), 1)
        vm.hides3DShotAssists = true
        XCTAssertEqual(previewCount(), 0)
        XCTAssertFalse(shaft.rootNode.isHidden)
        vm.hides3DShotAssists = false
        XCTAssertEqual(previewCount(), 1)
        let pocket = try XCTUnwrap((0..<6).first(where: vm.isStraightPocketAvailable))
        vm.selectPocket(at: pocket)
        XCTAssertEqual(previewCount(), 0)
        try await waitForSelectionPrediction(vm)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertEqual(vm.aimMode, .pocket)
        XCTAssertFalse(shaft.rootNode.isHidden)
        let aimed = try XCTUnwrap(vm.scene.lastCueAim)
        let prediction = try XCTUnwrap(vm.solvedShot?.prediction)
        XCTAssertTrue(prediction.feasible)
        let actual = SIMD3(aimed.x, aimed.y, aimed.z)
        XCTAssertGreaterThan(simd_dot(actual, SIMD3(prediction.aimDirection.x, prediction.aimDirection.y,
                                                   prediction.aimDirection.z)), 0.9999)
        XCTAssertGreaterThan(simd_length(actual - centerLine), 0.0001)
    }

    @MainActor
    func testP01SameBallPulsesAndReturnsFromObservationWithoutResolvingThePair() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.setPreferredAimMode(.pocket)
        try await waitForSelectionPrediction(vm)
        XCTAssertEqual(vm.aimMode, .pocket)
        settle(rig)
        vm.beginCameraObservation()
        rig.handleHorizontalSwipe(delta: 105)
        vm.endCameraObservation()
        let before = try XCTUnwrap(rig.p01Snapshot)
        let pocket = vm.selectedPocketIndex
        XCTAssertGreaterThanOrEqual(pocket, 0)
        XCTAssertGreaterThan(abs(before.state.observationYaw), 0.1)
        let aim = try XCTUnwrap(vm.scene.lastCueAim)
        let inputs = try recordedInputs(rig).count
        #if DEBUG
        let pulses = vm.scene.manualBallFeedbackCount
        let solves = vm.entryTiming["solveRequests"]
        #endif
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        XCTAssertFalse(vm.isComputing)
        settle(rig)
        XCTAssertNotEqual(rig.p01Snapshot?.pose, before.pose)
        XCTAssertEqual(rig.p01Snapshot?.state.observationYaw, 0)
        XCTAssertEqual(vm.selectedPocketIndex, pocket)
        XCTAssertEqual(rig.p01Snapshot?.shot, before.shot)
        XCTAssertEqual(vm.scene.lastCueAim.map { [$0.x, $0.y, $0.z] }, [aim.x, aim.y, aim.z])
        XCTAssertEqual(try recordedInputs(rig).dropFirst(inputs).filter { $0.kind == .target }.count, 1)
        #if DEBUG
        XCTAssertEqual(vm.scene.manualBallFeedbackCount, pulses + 1)
        XCTAssertEqual(vm.entryTiming["solveRequests"], solves)
        #endif
    }

    @MainActor
    func testP01CuePlacementHoldsTheStageUntilRelease() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        for view in [CameraRig.PlayerView.thirdPerson, .firstPerson] {
            XCTAssertTrue(vm.requestPlayerView(view, animated: false))
            let start = cue.simdPosition
            let initial = try XCTUnwrap(rig.p01Snapshot)
            let layout = try XCTUnwrap(initial.layout)
            let startScreen = try XCTUnwrap(initial.pose.project(start, layout: layout))
            vm.dragBegan(node: cue)
            XCTAssertTrue(rig.isHoldingP01CueDrag)
            for offset in [Float(0.08), 0.16] {
                vm.dragMoved(node: cue, worldPosition: SCNVector3(start.x + offset, start.y, start.z))
                rig.update(deltaTime: 1 / 60)
                XCTAssertEqual(rig.p01Snapshot?.pose, initial.pose)
                XCTAssertEqual(rig.p01Snapshot?.shot, initial.shot)
            }
            let placed = cue.simdPosition
            XCTAssertGreaterThan(simd_distance(placed, start), 0.1)
            XCTAssertGreaterThan(simd_distance(try XCTUnwrap(initial.pose.project(placed, layout: layout)), startScreen), 0.01)
            vm.dragEnded(node: cue)
            XCTAssertFalse(rig.isHoldingP01CueDrag)
            XCTAssertEqual(rig.p01Snapshot?.shot.cue, placed)
            if !UIAccessibility.isReduceMotionEnabled {
                XCTAssertEqual(rig.p01Snapshot?.motion?.origin, initial.pose)
            }
            settle(rig)
            XCTAssertNotEqual(rig.p01Snapshot?.pose, initial.pose)
            try await waitForSelectionPrediction(vm)
            XCTAssertEqual(rig.p01Snapshot?.shot.cue, placed)
        }
    }

    @MainActor
    func testP01BreakCuePlacementHoldsCameraAndUsesLegalReleasePoint() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelBreakFlow(); vm.cancelInteractiveTrajectoryPreview() }
        vm.startBreakFlow(game: .chineseEightBall, seed: 61)
        let runner = try XCTUnwrap(vm.breakRunner)
        let cue = try XCTUnwrap(runner.draggableCue.first)
        for view in [CameraRig.PlayerView.thirdPerson, .firstPerson] {
            XCTAssertTrue(vm.requestPlayerView(view, animated: false))
            XCTAssertEqual(vm.canNudgeP01TableAim, view == .firstPerson)
            if view == .firstPerson {
                let before = try XCTUnwrap(runner.aimDir)
                vm.nudgeP01TableFreeAim(byDegrees: 4)
                let expected = AngleSceneCalculator.rotatedAim(before, byDegrees: 4)
                XCTAssertEqual(rig.p01Snapshot?.shot.aim, SIMD3(expected.x, expected.y, expected.z))
            }
            let initial = try XCTUnwrap(rig.p01Snapshot)
            let origin = cue.simdPosition
            let z: Float = view == .thirdPerson ? 0.18 : -0.18
            runner.dragBegan(node: cue)
            for offset in [z / 2, z] {
                runner.dragMoved(node: cue, worldPosition: SCNVector3(0, origin.y, offset))
                rig.update(deltaTime: 1 / 60)
                XCTAssertEqual(rig.p01Snapshot?.pose, initial.pose)
                XCTAssertEqual(rig.p01Snapshot?.shot, initial.shot)
            }
            let placed = cue.simdPosition
            XCTAssertEqual(placed.x, AngleSceneCalculator.innerLength / 4, accuracy: 0.0001)
            XCTAssertEqual(placed.z, z, accuracy: 0.0001)
            runner.dragEnded(node: cue)
            XCTAssertFalse(rig.isHoldingP01CueDrag)
            XCTAssertEqual(rig.p01Snapshot?.shot.cue, placed)
            let aim = try XCTUnwrap(runner.aimDir)
            XCTAssertEqual(rig.p01Snapshot?.shot.aim, SIMD3(aim.x, aim.y, aim.z))
            settle(rig)
            XCTAssertNotEqual(rig.p01Snapshot?.pose, initial.pose)
        }
    }

    @MainActor
    func testP01AlongCueTargetChangeTurnsToCenterThenResolvedShaft() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.setPreferredAimMode(.pocket)
        try await waitForSelectionPrediction(vm)
        XCTAssertEqual(vm.aimMode, .pocket)
        settle(rig)
        let before = try XCTUnwrap(rig.p01Snapshot)
        let inputs = try recordedInputs(rig).count
        let target = try XCTUnwrap(vm.scene.allBallNodes["_8"])
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let center = simd_normalize(target.simdPosition - cue.simdPosition)

        XCTAssertTrue(vm.selectTarget(key: "_8"))
        let initial = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertGreaterThan(simd_dot(initial.shot.aim, center), 0.9999)
        let firstTurn = try XCTUnwrap(recordedInputs(rig).dropFirst(inputs).first { $0.kind == .target })
        XCTAssertEqual(firstTurn.kind, .target)
        XCTAssertEqual(firstTurn.preservesVisiblePose, false)
        if UIAccessibility.isReduceMotionEnabled {
            XCTAssertFalse(firstTurn.animated)
            XCTAssertNil(initial.motion)
        } else {
            XCTAssertEqual(firstTurn.turnPace, .selection120)
            XCTAssertEqual(initial.motion?.rampSeconds, 0.16)
            XCTAssertEqual(initial.pose, before.pose)
        }

        try await waitForSelectionPrediction(vm)
        XCTAssertTrue(vm.isFeasible)
        let turns = try recordedInputs(rig).dropFirst(inputs).filter { $0.kind == .target }
        XCTAssertEqual(turns.count, 2)
        let secondTurn = try XCTUnwrap(turns.last)
        XCTAssertEqual(secondTurn.preservesVisiblePose, false)
        let actual = try XCTUnwrap(vm.scene.lastCueAim)
        XCTAssertEqual(secondTurn.shot?.aim, SIMD3(actual.x, actual.y, actual.z))
        settle(rig)
        XCTAssertEqual(rig.p01Snapshot?.shot.aim, SIMD3(actual.x, actual.y, actual.z))
        XCTAssertNotEqual(rig.p01Snapshot?.pose, before.pose)

        let alignedShaft = try XCTUnwrap(rig.p01Snapshot?.shot)
        vm.updateSpin(x: 0.15, y: 0.12)
        try await waitForSelectionPrediction(vm)
        settle(rig)
        XCTAssertNotEqual(rig.p01Snapshot?.shot.strike, alignedShaft.strike)
        XCTAssertEqual(try recordedInputs(rig).dropFirst(inputs).filter { $0.kind == .target }.count, 2)
    }

    @MainActor
    func testP01ThirdPersonTapAfterSidePanFollowsEachNewTarget() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.setPreferredAimMode(.pocket)
        try await waitForSelectionPrediction(vm)
        for target in ["_8", "_1"] {
            vm.beginCameraObservation()
            rig.handleHorizontalSwipe(delta: 120)
            vm.endCameraObservation()
            let observed = try XCTUnwrap(rig.p01Snapshot)
            XCTAssertNotEqual(observed.state.observationYaw, 0)
            XCTAssertEqual(rig.playerView, .thirdPerson)
            let count = try recordedInputs(rig).count
            XCTAssertTrue(vm.selectTarget(key: target))
            try await waitForSelectionPrediction(vm)
            settle(rig)
            let after = try XCTUnwrap(rig.p01Snapshot)
            XCTAssertEqual(vm.selectedTargetKey, target)
            XCTAssertEqual(after.state.view, .thirdPerson)
            XCTAssertEqual(after.state.observationYaw, 0)
            XCTAssertNotEqual(after.pose, observed.pose)
            let aim = try XCTUnwrap(vm.scene.lastCueAim)
            XCTAssertEqual(after.shot.aim, SIMD3(aim.x, aim.y, aim.z))
            let turns = try recordedInputs(rig).dropFirst(count).filter { $0.kind == .target }
            XCTAssertEqual(turns.count, 2)
            XCTAssertEqual(turns.first?.preservesVisiblePose, false)
        }
    }

    @MainActor
    func testP01PostShotRecommendationUsesTheSameTargetTurn() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.beginCameraObservation()
        rig.handleHorizontalSwipe(delta: -140)
        rig.handlePinch(scale: 1.25)
        rig.handleVerticalSwipe(delta: 80)
        vm.endCameraObservation()
        vm.legalAimTargets = { $0.intersection(["_8"]) }
        let count = try recordedInputs(rig).count
        vm.recommendTargetAfterShot()
        try await waitForSelectionPrediction(vm)
        XCTAssertEqual(vm.selectedTargetKey, "_8")
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let target = try XCTUnwrap(vm.scene.allBallNodes["_8"])
        let expected = simd_normalize(target.simdPosition - cue.simdPosition)
        let actual = try XCTUnwrap(rig.p01Snapshot?.shot.aim)
        XCTAssertGreaterThan(simd_dot(actual, expected), 0.9999)
        let targets = try recordedInputs(rig).dropFirst(count).filter { $0.kind == .view && $0.resetThirdPerson == true }
        let state = try XCTUnwrap(rig.p01Snapshot).state
        XCTAssertEqual(state.distance, P01CameraMotion.State().distance)
        XCTAssertEqual(state.height, P01CameraMotion.State().height)
        XCTAssertEqual(targets.count, 1)
        if !UIAccessibility.isReduceMotionEnabled {
            XCTAssertEqual(targets.first?.turnPace, .selection120)
            XCTAssertEqual(rig.p01Snapshot?.motion?.rampSeconds, 0.16)
        }
    }

    @MainActor
    func testP01SideViewsKeepVisiblePoseThroughTargetAndOrdinaryPrediction() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.setPreferredAimMode(.pocket)
        try await waitForSelectionPrediction(vm)
        XCTAssertEqual(vm.aimMode, .pocket)
        settle(rig)
        for view in [P01CameraMotion.View.overview, .firstPerson] {
            if view == .overview {
                vm.requestSurfaceOverview()
                settle(rig)
            } else {
                XCTAssertTrue(vm.requestPlayerView(.firstPerson, animated: false))
                vm.beginCameraObservation()
                rig.handleHorizontalSwipe(delta: 120)
            }
            let before = try XCTUnwrap(rig.p01Snapshot)
            let inputs = try recordedInputs(rig).count
            let next = vm.selectedTargetKey == "_1" ? "_8" : "_1"
            XCTAssertTrue(vm.selectTarget(key: next))
            XCTAssertEqual(rig.p01Snapshot?.pose, before.pose)
            try await waitForSelectionPrediction(vm)
            settle(rig)
            XCTAssertTrue(vm.isFeasible)
            XCTAssertEqual(rig.p01Snapshot?.pose, before.pose)
            XCTAssertEqual(rig.p01Snapshot?.state.view, view)
            XCTAssertNotEqual(rig.p01Snapshot?.shot, before.shot)
            let update = try XCTUnwrap(recordedInputs(rig).dropFirst(inputs).first)
            XCTAssertEqual(update.kind, .target)
            XCTAssertEqual(update.preservesVisiblePose, true)
            XCTAssertEqual(try recordedInputs(rig).count, inputs + 1)
            vm.velocity += 0.12
            XCTAssertEqual(rig.p01Snapshot?.pose, before.pose)
            try await waitForSelectionPrediction(vm)
            settle(rig)
            XCTAssertEqual(rig.p01Snapshot?.pose, before.pose)
            XCTAssertEqual(try recordedInputs(rig).count, inputs + 1)
        }
    }

    @MainActor
    func testP01LatestSelectionKeepsAViewChosenWhileSolving() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.setPreferredAimMode(.pocket)
        try await waitForSelectionPrediction(vm)
        XCTAssertEqual(vm.aimMode, .pocket)
        settle(rig)
        let inputs = try recordedInputs(rig).count
        XCTAssertTrue(vm.selectTarget(key: "_8"))
        XCTAssertTrue(vm.selectTarget(key: "_1"))
        let manualTurns = try recordedInputs(rig).dropFirst(inputs).filter { $0.kind == .target }
        XCTAssertEqual(manualTurns.count, 2)
        XCTAssertTrue(manualTurns.allSatisfy { $0.preservesVisiblePose == false })
        let beforeViewChange = try recordedInputs(rig).count
        XCTAssertTrue(vm.requestPlayerView(.firstPerson, animated: false))
        let chosen = try XCTUnwrap(rig.p01Snapshot).pose
        try await waitForSelectionPrediction(vm)
        settle(rig)
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertEqual(rig.p01Snapshot?.pose, chosen)
        XCTAssertEqual(rig.p01Snapshot?.state.view, .firstPerson)
        let selections = try recordedInputs(rig).dropFirst(beforeViewChange).filter { $0.kind == .target }
        XCTAssertEqual(selections.count, 1)
        XCTAssertEqual(selections.first?.preservesVisiblePose, true)
        let aim = try XCTUnwrap(vm.scene.lastCueAim)
        XCTAssertEqual(selections.first?.shot?.aim, SIMD3(aim.x, aim.y, aim.z))
    }

    @MainActor
    func testP01InfeasibleSelectionStopsAtTargetCenter() async throws {
        let (vm, rig) = try await selectionFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.usesAutomaticPocketFallback = false
        vm.setPreferredAimMode(.pocket)
        try await waitForSelectionPrediction(vm)
        let target = try XCTUnwrap(vm.scene.allBallNodes["_8"])
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: vm.scene.surfaceY)
        let impossiblePocket = try XCTUnwrap(pockets.indices.min {
            let toward = target.position - cue.position
            let a = pockets[$0] - target.position, b = pockets[$1] - target.position
            return a.x * toward.x + a.z * toward.z < b.x * toward.x + b.z * toward.z
        })
        vm.practiceLockedPocket = impossiblePocket
        let before = try XCTUnwrap(rig.p01Snapshot)
        let inputs = try recordedInputs(rig).count
        XCTAssertTrue(vm.selectTarget(key: "_8"))
        try await waitForSelectionPrediction(vm)
        XCTAssertFalse(vm.isFeasible)
        settle(rig)
        let after = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertNotEqual(after.pose, before.pose)
        let center = simd_normalize(target.simdPosition - cue.simdPosition)
        XCTAssertGreaterThan(simd_dot(after.shot.aim, center), 0.9999)
        let turns = try recordedInputs(rig).dropFirst(inputs).filter { $0.kind == .target }
        XCTAssertEqual(turns.count, 1)
    }

    @MainActor
    func testNativeRecordingReplaysAndSuspensionCancelsVisibleTransition() throws {
        let r=rig(),cue=SCNVector3(0.2,0.828575,0.1),aim=SCNVector3(1,0,0)
        XCTAssertTrue(r.enterPlayerView(.thirdPerson,cue:cue,aim:aim,duration:0))
        XCTAssertTrue(r.enterMergedGlobal(aim:aim))
        for _ in 0..<30 { r.update(deltaTime:1/60) }
        let visible=try XCTUnwrap(r.p01Snapshot).pose
        r.suspendP01Motion();settle(r)
        XCTAssertEqual(r.p01Snapshot?.pose,visible)
        r.handleHorizontalSwipe(delta:0.01)
        XCTAssertLessThan(simd_distance(try XCTUnwrap(r.p01Snapshot).pose.eye,visible.eye),0.001)
        XCTAssertTrue(r.enterPlayerView(.firstPerson,cue:cue,aim:aim,duration:0.3))
        settle(r)
        _=r.prepareTemporaryObservation(cue:cue,aim:aim)
        r.handleHorizontalSwipe(delta:90);r.endTemporaryObservation();settle(r)
        let saved=r.capturePerspectiveState()
        _=r.enterMergedGlobal(aim:aim);settle(r)
        r.restorePerspectiveState(saved);settle(r)
        let data=try XCTUnwrap(r.p01ReplayData)
        let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.json")
        attachment.name="v67-native-camera-recording.json";attachment.lifetime = .keepAlways;add(attachment)
        let record=try JSONDecoder().decode(P01CameraMotion.Recording.self,from:data)
        XCTAssertGreaterThan(record.samples.count,10)
        for fps in [30,60,120] {
            var replay=try XCTUnwrap(P01CameraMotion(recording:record)),index=0
            for sample in record.samples {
                while index<record.inputs.count && record.inputs[index].time < sample.time-1e-9 {
                    let input=record.inputs[index]
                    while replay.time+1/Double(fps)<input.time { replay.advance(to:replay.time+1/Double(fps)) }
                    replay.apply(input);index += 1
                }
                replay.advance(to:sample.time)
                XCTAssertLessThan(simd_distance(replay.pose.eye,sample.pose.eye),0.0001)
                XCTAssertLessThan(simd_distance(replay.pose.forward,sample.pose.forward),0.0001)
                XCTAssertEqual(replay.pose.verticalFOV,sample.pose.verticalFOV,accuracy:0.0001)
            }
            while index<record.inputs.count { replay.apply(record.inputs[index]);index += 1 }
            replay.advance(to:try XCTUnwrap(r.p01Snapshot).time)
            XCTAssertLessThan(simd_distance(replay.pose.eye,try XCTUnwrap(r.p01Snapshot).pose.eye),0.0001)
        }
    }

    @MainActor
    func testRecordingBoundIncludesViewButtonsAndSnapshotRestore() throws {
        let r=rig(),cue=SCNVector3(0.2,0.828575,0.1),aim=SCNVector3(1,0,0)
        for index in 0..<4100 {
            XCTAssertTrue(r.enterPlayerView(index.isMultiple(of:2) ? .firstPerson : .thirdPerson,
                cue:cue,aim:aim,duration:0))
        }
        func verifyBoundAndReplay() throws {
            let record=try JSONDecoder().decode(P01CameraMotion.Recording.self,from:XCTUnwrap(r.p01ReplayData))
            XCTAssertLessThanOrEqual(record.inputs.count,4096)
            XCTAssertGreaterThan(record.inputs.count,0)
            var replay=try XCTUnwrap(P01CameraMotion(recording:record))
            for input in record.inputs { replay.apply(input) }
            replay.advance(to:try XCTUnwrap(r.p01Snapshot).time)
            let actual=try XCTUnwrap(r.p01Snapshot).pose
            XCTAssertLessThan(simd_distance(replay.pose.eye,actual.eye),0.0001)
            XCTAssertLessThan(simd_distance(replay.pose.forward,actual.forward),0.0001)
            XCTAssertEqual(replay.pose.verticalFOV,actual.verticalFOV,accuracy:0.0001)
        }
        try verifyBoundAndReplay()
        let saved=r.capturePerspectiveState()
        for _ in 0..<4100 { r.restorePerspectiveState(saved) }
        try verifyBoundAndReplay()
    }

    @MainActor
    func testReplayRestoredWhile2DReturnsToOriginalP01Intent() throws {
        let scene=AngleTrainingScene();scene.configureShotAwareCamera();scene.setupScene()
        let r=try XCTUnwrap(scene.cameraRig);r.configurePlayerCameraControls(daily:true,policy:.p01Replayable)
        r.viewportSize = .init(width:874,height:402)
        let cue=SCNVector3(0,scene.surfaceY+BallPhysics.radius,0),aim=SCNVector3(1,0,0)
        scene.setCameraMode(.perspective3D,animated:false)
        XCTAssertTrue(r.enterPlayerView(.firstPerson,cue:cue,aim:aim,duration:0))
        let saved=try XCTUnwrap(scene.capturePerspectiveView()),pose=try XCTUnwrap(r.p01Snapshot).pose
        scene.setCameraMode(.topDown2D,animated:false)
        r.setTwoViewViewingContext(UUID())
        scene.restorePerspectiveView(saved)
        XCTAssertEqual(scene.currentCameraMode,.topDown2D)
        scene.setCameraMode(.perspective3D,animated:false)
        XCTAssertEqual(r.p01Snapshot?.pose,pose)
        XCTAssertEqual(r.p01Snapshot?.state.view,.firstPerson)
    }

    @MainActor
    func testReplayPredictionPreservesRestoredViewAndNewInputSupersedesIt() async throws {
        let vm=PositionPlayViewModel();vm.scene.configureShotAwareCamera();vm.setupScene()
        vm.enablePlayerCameraControls(policy:.p01Replayable)
        let r=try XCTUnwrap(vm.scene.cameraRig);r.viewportSize = .init(width:874,height:402)
        vm.usesAutomaticPocketFallback=true;vm.loadBoard(PositionPlayComposerView.defaultBoard)
        _=vm.selectTarget(key:"_1");vm.selectPocket(at:1)
        for _ in 0..<100 where vm.isComputing { try await Task.sleep(for:.milliseconds(100)) }
        XCTAssertFalse(vm.isComputing);_ = ShotPlayCamera.setMode(.perspective3D,on:vm)
        XCTAssertTrue(vm.requestPlayerView(.thirdPerson,animated:false));settle(r)
        let saved=r.capturePerspectiveState(),pose=try XCTUnwrap(r.p01Snapshot).pose
        vm.recompute();vm.scene.restorePerspectiveView(saved)
        vm.preserveP01CameraThroughPendingPrediction()
        for _ in 0..<100 where vm.isComputing { try await Task.sleep(for:.milliseconds(100)) }
        XCTAssertFalse(vm.isComputing);settle(r);XCTAssertEqual(r.p01Snapshot?.pose,pose)

        vm.recompute();vm.scene.restorePerspectiveView(saved)
        vm.preserveP01CameraThroughPendingPrediction()
        vm.beginCameraObservation();r.handleHorizontalSwipe(delta:100)
        for _ in 0..<100 where vm.isComputing { try await Task.sleep(for:.milliseconds(100)) }
        XCTAssertFalse(vm.isComputing);settle(r)
        XCTAssertGreaterThan(abs(try XCTUnwrap(r.p01Snapshot).state.observationYaw),0.1)
        XCTAssertGreaterThan(simd_distance(try XCTUnwrap(r.p01Snapshot).pose.eye,pose.eye),0.1)

        let solution=try XCTUnwrap(vm.solvedShot)
        let originalAim=try XCTUnwrap(vm.scene.lastCueAim)
        vm.recompute()
        XCTAssertTrue(vm.restoreP01SolvedShot(solution))
        XCTAssertFalse(vm.isComputing)
        XCTAssertEqual(vm.scene.lastCueAim.map { [$0.x,$0.y,$0.z] },[originalAim.x,originalAim.y,originalAim.z])
        try await Task.sleep(for:.milliseconds(500))
        XCTAssertEqual(vm.scene.lastCueAim.map { [$0.x,$0.y,$0.z] },[originalAim.x,originalAim.y,originalAim.z],"Cancelled late work cannot replace the restored shaft")
        vm.suspendAuthoringActivity();vm.resumeAuthoringActivity()
        XCTAssertFalse(vm.isComputing)
        XCTAssertEqual(vm.scene.lastCueAim.map { [$0.x,$0.y,$0.z] },[originalAim.x,originalAim.y,originalAim.z])
        vm.velocity += 0.5
        XCTAssertFalse(vm.restoreP01SolvedShot(solution),"Changed parameters must reject an old solution")
        vm.nudgeFreeAim(byDegrees:5)
        XCTAssertFalse(vm.restoreP01SolvedShot(solution),"A manual direction takes precedence over replay data")
    }

}

extension P01CameraIntegrationTests {
    @MainActor
    private func liveBoardFixture(recommendation: Bool = false) async throws
        -> (PositionPlayViewModel, CameraRig, SCNRenderer) {
        let vm = PositionPlayViewModel()
        vm.scene.configureShotAwareCamera()
        let rules = FreePlayRulesSession()
        let daily = DailyClearanceController()
        let notices = BTRuleNoticeCenter()
        FreePlayRulesSession.connect(vm: vm, rules: rules, daily: daily, notices: notices,
                                     mode: .standard, isEditor: true, isTryout: false,
                                     usesEditorAttackRecommendations: true)
        let handleSettlement = vm.onShotSettled
        vm.onShotSettled = { facts in
            withExtendedLifetime((rules, daily, notices)) { handleSettlement?(facts) }
        }
        vm.setupScene()
        vm.enablePlayerCameraControls(policy: .p01Replayable)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = .init(width: 874, height: 402)
        rig.setTwoViewReadableInsets(.init(top: 41.972, left: 127.83402, bottom: 17.972, right: 127.83402))
        vm.usesContinuousTrajectoryPreview = true
        vm.setAutomaticRecommendation(recommendation)
        try vm.restoreSavedBoard(liveBoardSave())
        try await waitForSelectionPrediction(vm)
        _ = ShotPlayCamera.setMode(.perspective3D, on: vm)
        XCTAssertTrue(vm.requestPlayerView(.thirdPerson, animated: false))
        settle(rig)
        XCTAssertEqual(Set(vm.onTableKeys), ["cueBall", "_1", "_2", "_3", "_4", "_5", "_9", "_10"])
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = vm.scene
        renderer.pointOfView = vm.scene.cameraNode
        renderer.isPlaying = true
        return (vm, rig, renderer)
    }

    private func liveBoardSave() throws -> PositionPlayViewModel.SavedBoard {
        // Normalized board coordinates and input from the eight-ball user save.
        let json = """
        {
          "board": {"onTable": {
            "_1": {"x": 0.9366223216056824, "y": 0.4448546767234802},
            "_10": {"x": 0.7271819114685059, "y": 0.3751247823238373},
            "_2": {"x": 0.2121698409318924, "y": 0.41251564025878906},
            "_3": {"x": 0.03322306647896767, "y": 0.12551087141036987},
            "_4": {"x": 0.011249978095293045, "y": 0.25739210844039917},
            "_5": {"x": 0.31248101592063904, "y": 0.10198964923620224},
            "_9": {"x": 0.2025936096906662, "y": 0.3839951753616333},
            "cueBall": {"x": 0.6588667631149292, "y": 0.23720666766166687}
          }},
          "input": {"direction": [-0.7322672, 0, 0.68101746], "mode": "pocket",
                    "pocket": -1, "preference": "pocket", "selectionSource": "manualTarget",
                    "spinX": 0, "spinY": 0, "target": "_5", "velocity": 2},
          "manual": true
        }
        """
        return try JSONDecoder().decode(PositionPlayViewModel.SavedBoard.self, from: Data(json.utf8))
    }

    @MainActor
    func testColdEntryResolvesSavedBoardAndPreparedBreakWhenViewportArrivesLate() throws {
        for preparedBreak in [false, true] {
            let vm = PositionPlayViewModel()
            vm.scene.configureShotAwareCamera()
            vm.setupScene(loadsDefaultLayout: false)
            vm.enablePlayerCameraControls(policy: .p01Replayable)
            defer { vm.cancelBreakFlow(); vm.cancelInteractiveTrajectoryPreview() }
            try vm.restoreSavedBoard(liveBoardSave())
            if preparedBreak { vm.startBreakFlow(game: .chineseEightBall, manualDeliver: false, seed: 61) }
            let rig = try XCTUnwrap(vm.scene.cameraRig)
            let cue = try XCTUnwrap(vm.scene.cueBallNode).simdPosition
            let aim = try XCTUnwrap(vm.playerViewDirection)
            rig.viewportSize = .zero
            XCTAssertTrue(ShotPlayCamera.setMode(.perspective3D, on: vm))
            rig.viewportSize = CGSize(width: 874, height: 402)
            let snapshot = try XCTUnwrap(rig.p01Snapshot)
            XCTAssertEqual(rig.playerView, .thirdPerson)
            XCTAssertEqual(snapshot.state.view, .thirdPerson)
            XCTAssertEqual(snapshot.shot.cue, cue)
            XCTAssertGreaterThan(simd_dot(simd_normalize(snapshot.shot.aim),
                                          simd_normalize(SIMD3(aim.x, aim.y, aim.z))), 0.9999)
            XCTAssertEqual(vm.scene.cameraNode?.camera?.usesOrthographicProjection, false)
            XCTAssertNil(snapshot.motion)
        }
    }

    @MainActor
    private func driveLiveShot(_ renderer: SCNRenderer, rig: CameraRig,
                               untilSettled isActive: () -> Bool) async throws -> TimeInterval {
        let frameSeconds = 1.0 / 60.0
        for frame in 0..<3600 {
            let time = Double(frame) * frameSeconds
            if !isActive() { return time }
            renderer.update(atTime: time)
            rig.update(deltaTime: Float(frameSeconds))
            try await Task.sleep(for: .milliseconds(4))
        }
        XCTFail("SceneKit shot did not settle")
        return 3600 * frameSeconds
    }

    @MainActor
    @discardableResult
    private func recordLiveBoard(_ name: String, vm: PositionPlayViewModel, rig: CameraRig,
                                 renderer: SCNRenderer, time: TimeInterval = 0) throws
        -> P01CameraMotion.Snapshot {
        let state = try XCTUnwrap(rig.p01Snapshot)
        let layout = try XCTUnwrap(state.layout)
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let target = vm.selectedTargetKey.flatMap { vm.scene.allBallNodes[$0] }
        let targetScreen = target.flatMap { state.pose.project($0.simdPosition, layout: layout) }
        let cueScreen = state.pose.project(cue.simdPosition, layout: layout)
        let facts = """
        view=\(state.state.view.rawValue) mode=\(vm.aimMode) playing=\(vm.isPlaying)
        target=\(vm.selectedTargetKey ?? "-") pocket=\(vm.selectedPocketIndex) feasible=\(vm.isFeasible)
        balls=\(vm.onTableKeys.sorted()) shaftVisible=\(vm.scene.cueStick?.rootNode.isHidden == false)
        cue=\(cue.simdPosition) cueReference=\(state.shot.cue) aim=\(state.shot.aim)
        cueScreen=\(String(describing: cueScreen)) targetScreen=\(String(describing: targetScreen))
        eye=\(state.pose.eye) pitch=\(state.pose.pitch) distance=\(state.state.distance) height=\(state.state.height)
        observationYaw=\(state.state.observationYaw) time=\(time)
        """
        let values = XCTAttachment(string: facts)
        values.name = "\(name)-values"
        values.lifetime = .keepAlways
        add(values)
        let frame = renderer.snapshot(atTime: time, with: CGSize(width: 874, height: 402), antialiasingMode: .none)
        let picture = XCTAttachment(image: frame)
        picture.name = name
        picture.lifetime = .keepAlways
        add(picture)
        return state
    }

    @MainActor
    private func assertLiveCameraReference(_ state: P01CameraMotion.Snapshot, vm: PositionPlayViewModel,
                                           centersTarget: Bool, withinReadableArea: Bool = false,
                                           file: StaticString = #filePath, line: UInt = #line) throws {
        let cue = try XCTUnwrap(vm.scene.cueBallNode, file: file, line: line)
        XCTAssertEqual(state.state.view, .thirdPerson, file: file, line: line)
        XCTAssertLessThan(simd_distance(state.shot.cue, cue.simdPosition), 0.001, file: file, line: line)
        let layout = try XCTUnwrap(state.layout, file: file, line: line)
        let insets = withinReadableArea ? layout.insets : .zero
        let horizontal = (insets.x / layout.viewport.x)...(1 - insets.z / layout.viewport.x)
        let vertical = (insets.y / layout.viewport.y)...(1 - insets.w / layout.viewport.y)
        let screenCue = try XCTUnwrap(state.pose.project(cue.simdPosition, layout: layout), file: file, line: line)
        XCTAssertTrue(horizontal.contains(screenCue.x) && vertical.contains(screenCue.y), file: file, line: line)
        guard centersTarget else { return }
        let key = try XCTUnwrap(vm.selectedTargetKey, file: file, line: line)
        let target = try XCTUnwrap(vm.scene.allBallNodes[key], file: file, line: line)
        let screenTarget = try XCTUnwrap(state.pose.project(target.simdPosition, layout: layout), file: file, line: line)
        XCTAssertTrue(horizontal.contains(screenTarget.x) && vertical.contains(screenTarget.y), file: file, line: line)
        let offset = target.simdPosition - cue.simdPosition
        let bearing = simd_normalize(SIMD3(offset.x, 0, offset.z))
        XCTAssertGreaterThan(simd_dot(bearing, state.shot.aim), 0.9999, file: file, line: line)
    }

    @MainActor
    private func playLiveOrdinaryShot(vm: PositionPlayViewModel, rig: CameraRig, renderer: SCNRenderer,
                                      recommendation: Bool) async throws -> TimeInterval {
        let prefix = recommendation ? "ordinary-recommendation-on" : "ordinary-recommendation-off"
        let handleSettlement = vm.onShotSettled
        defer { vm.onShotSettled = handleSettlement }

        vm.selectPocket(at: 0)
        try await waitForSelectionPrediction(vm)
        settle(rig)
        XCTAssertTrue(vm.isFeasible)
        let before = try recordLiveBoard("\(prefix)-ready", vm: vm, rig: rig, renderer: renderer)
        var settledCount = 0
        vm.onShotSettled = { facts in
            settledCount += 1
            handleSettlement?(facts)
        }
        vm.play()
        XCTAssertTrue(vm.isPlaying)
        let time = try await driveLiveShot(renderer, rig: rig) { vm.isPlaying }
        try await waitForSelectionPrediction(vm)
        settle(rig)
        XCTAssertEqual(settledCount, 1)
        XCTAssertTrue(vm.canReplay)
        let rested = try recordLiveBoard("\(prefix)-rested", vm: vm, rig: rig, renderer: renderer, time: time)
        XCTAssertGreaterThan(simd_distance(rested.shot.cue, before.shot.cue), 0.001)
        try assertLiveCameraReference(rested, vm: vm, centersTarget: false)
        if recommendation {
            let target = try XCTUnwrap(vm.selectedTargetKey)
            XCTAssertTrue(vm.onTableKeys.contains(target))
            return time
        }
        XCTAssertNil(vm.selectedTargetKey)
        let next = try XCTUnwrap(vm.onTableKeys.sorted().first { $0 != "_5" && !PositionPlayBall.isCue($0) })
        XCTAssertTrue(vm.selectTarget(key: next))
        try await waitForSelectionPrediction(vm)
        settle(rig)
        XCTAssertEqual(vm.selectedTargetKey, next)
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        let selected = try recordLiveBoard("\(prefix)-next-ball", vm: vm, rig: rig, renderer: renderer, time: time)
        try assertLiveCameraReference(selected, vm: vm, centersTarget: true)
        return time
    }

    @MainActor
    func testDailyAutomaticNextBallRestoresPresetAfterZoomAndPan() async throws {
        let suite = "DailyNextBallCamera-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DailyClearanceStore(defaults: defaults)
        var draft = store.makeDraft(game: .nineBall, seed: 75)
        draft.phase = .playing
        draft.board = BoardSnapshot(onTable: [
            "cueBall": .init(x: 0.54, y: 0.26), "_1": .init(x: 0.515, y: 0.10),
            "_2": .init(x: 0.30, y: 0.20), "_9": .init(x: 0.78, y: 0.30)
        ])
        store.saveDraft(draft)
        let daily = DailyClearanceController(store: store)
        let vm = PositionPlayViewModel()
        defer { vm.suspendAuthoringActivity() }
        vm.scene.configureDailyClearanceRendering()
        let rules = FreePlayRulesSession(), notices = BTRuleNoticeCenter()
        FreePlayRulesSession.connect(vm: vm, rules: rules, daily: daily, notices: notices,
                                     mode: .dailyClearance, isEditor: false, isTryout: false)
        vm.setupScene(loadsDefaultLayout: false)
        vm.enablePlayerCameraControls(policy: .p01Replayable)
        vm.setAutomaticRecommendation(true)
        daily.start(host: vm, defaultGame: .nineBall)
        daily.syncPlanAim()
        vm.refreshLegalAimSelection()
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        rig.viewportSize = .init(width: 874, height: 402)
        XCTAssertTrue(ShotPlayCamera.setMode(.perspective3D, on: vm))
        try await waitForSelectionPrediction(vm)
        XCTAssertEqual(vm.selectedTargetKey, "_1")
        XCTAssertTrue(vm.requestPlayerView(.thirdPerson, animated: false, resetThirdPerson: true))
        let preset = try XCTUnwrap(rig.p01Snapshot).state
        vm.beginCameraObservation()
        rig.handlePinch(scale: 1.25)
        rig.handleVerticalSwipe(delta: 80)
        rig.handleHorizontalSwipe(delta: 60)
        vm.endCameraObservation()
        settle(rig)
        let modified = try XCTUnwrap(rig.p01Snapshot).state
        XCTAssertNotEqual(modified.distance, preset.distance)
        XCTAssertNotEqual(modified.height, preset.height)

        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = vm.scene
        renderer.pointOfView = vm.scene.cameraNode
        renderer.isPlaying = true
        vm.play()
        XCTAssertTrue(vm.isPlaying)
        _ = try await driveLiveShot(renderer, rig: rig) { vm.isPlaying }
        try await waitForSelectionPrediction(vm)
        settle(rig)
        XCTAssertEqual(daily.shotCount, 1)
        XCTAssertFalse(vm.onTableKeys.contains("_1"))
        XCTAssertEqual(vm.selectedTargetKey, "_2")
        let automatic = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertEqual(automatic.state.view, .thirdPerson)
        XCTAssertEqual(automatic.state.distance, preset.distance)
        XCTAssertEqual(automatic.state.height, preset.height)
        XCTAssertEqual(automatic.state.observationYaw, 0)
        XCTAssertTrue(vm.requestPlayerView(.thirdPerson, animated: false, resetThirdPerson: true))
        let explicit = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertLessThan(simd_distance(automatic.pose.eye, explicit.pose.eye), 0.0001)
        XCTAssertLessThan(simd_distance(automatic.pose.forward, explicit.pose.forward), 0.0001)
    }

    @MainActor
    func testRollingShotViewsAndHeldPanAtSettlement() async throws {
        let (vm, rig, renderer) = try await liveBoardFixture(recommendation: true)
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.selectPocket(at: 0)
        try await waitForSelectionPrediction(vm)
        settle(rig)
        let cue = try XCTUnwrap(vm.scene.cueBallNode)
        let origin = cue.simdPosition
        let window = UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene))
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 874, height: 402))
        window.addSubview(view)
        let coordinator = AngleSceneView.Coordinator(scene: vm.scene, cameraMode: .perspective3D, interactionMode: .cameraControl)
        coordinator.scnView = view
        coordinator.onCameraObservationBegan = vm.beginCameraObservation
        coordinator.onCameraObservationEnded = vm.endCameraObservation
        let pan = TableAimBoundaryTests.Pan()
        view.addGestureRecognizer(pan)
        coordinator.panGesture = pan
        var held: P01CameraMotion.Pose?
        var aimed: P01CameraMotion.Pose?
        vm.play()
        XCTAssertFalse(vm.playerCameraButtonsEnabled, "Pre-contact stroke")
        _ = try await driveLiveShot(renderer, rig: rig) {
            guard vm.isPlaying else { return false }
            guard vm.canObserveRollingShot, simd_distance(cue.simdPosition, origin) > 0.03 else { return true }
            if aimed == nil {
                XCTAssertTrue(vm.playerCameraButtonsEnabled)
                XCTAssertFalse(vm.canNudgeP01TableAim)
                XCTAssertTrue(vm.requestPlayerView(.firstPerson, animated: false))
                XCTAssertEqual(rig.p01Snapshot?.shot.cue, origin)
                aimed = rig.p01Snapshot?.pose
            } else if held == nil {
                XCTAssertEqual(rig.p01Snapshot?.pose, aimed)
                XCTAssertTrue(vm.requestPlayerView(.thirdPerson, animated: false, resetThirdPerson: true))
                vm.requestSurfaceOverview()
                settle(rig)
                XCTAssertTrue(rig.overviewControlSelected)
                let before = rig.p01Snapshot?.pose
                pan.point = CGPoint(x: 100, y: 90)
                pan.phase = .began
                coordinator.handlePan(pan)
                pan.point.x += 70
                pan.phase = .changed
                coordinator.handlePan(pan)
                held = rig.p01Snapshot?.pose
                XCTAssertNotEqual(before, held)
                XCTAssertEqual(rig.p01Snapshot?.shot.cue, origin)
            }
            return true
        }
        try await waitForSelectionPrediction(vm)
        settle(rig)
        let observed = try XCTUnwrap(held)
        XCTAssertNotNil(vm.selectedTargetKey, "The game must settle while the camera is held")
        XCTAssertEqual(rig.p01Snapshot?.pose, observed)
        XCTAssertFalse(vm.canNudgeP01TableAim)
        pan.point.x += 12
        coordinator.handlePan(pan)
        XCTAssertTrue(rig.overviewControlSelected)
        XCTAssertNotEqual(rig.p01Snapshot?.pose, observed, "The same drag continues after the balls stop")
        pan.phase = .ended
        coordinator.handlePan(pan)
        if !UIAccessibility.isReduceMotionEnabled {
            XCTAssertEqual(rig.p01Snapshot?.motion?.rampSeconds, 0.16)
            XCTAssertEqual(try recordedInputs(rig).last(where: { $0.kind == .view })?.turnPace, .selection120)
        }
        settle(rig)
        let ready = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertEqual(ready.state.view, .thirdPerson)
        XCTAssertEqual(ready.shot.cue, cue.simdPosition)
        XCTAssertNotEqual(ready.pose, observed)
        XCTAssertFalse(rig.p01ShotFrozen)
    }

    @MainActor
    func testFreeRollingObservationKeepsTheShotAndManualView() async throws {
        let (vm, rig, renderer) = try await liveBoardFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        vm.setPreferredAimMode(.free)
        XCTAssertTrue(vm.selectTarget(key: "_5"))
        try await waitForSelectionPrediction(vm)
        XCTAssertTrue(vm.isFeasible)
        settle(rig)
        let direction = try XCTUnwrap(vm.freeAimDir)
        let target = vm.selectedTargetKey
        vm.play()
        var observed: P01CameraMotion.Pose?
        _ = try await driveLiveShot(renderer, rig: rig) {
            guard vm.isPlaying else { return false }
            if vm.canObserveRollingShot, observed == nil {
                XCTAssertFalse(vm.canNudgeP01TableAim)
                vm.nudgeP01TableFreeAim(byDegrees: 18)
                vm.beginCameraObservation()
                let start = rig.p01Snapshot?.pose
                rig.handleSurfacePan(delta: .init(100, 0))
                vm.endCameraObservation()
                observed = rig.p01Snapshot?.pose
                XCTAssertNotEqual(start, observed)
                XCTAssertEqual(vm.freeAimDir?.x, direction.x)
                XCTAssertEqual(vm.freeAimDir?.z, direction.z)
                XCTAssertEqual(vm.selectedTargetKey, target)
            }
            return true
        }
        try await waitForSelectionPrediction(vm)
        settle(rig)
        XCTAssertNotNil(observed)
        let ready = try XCTUnwrap(rig.p01Snapshot)
        XCTAssertLessThan(simd_distance(ready.pose.eye, try XCTUnwrap(observed).eye), 0.001)
        XCTAssertEqual(ready.shot.cue, vm.scene.cueBallNode?.simdPosition)
        XCTAssertFalse(vm.canObserveRollingShot)
        XCTAssertTrue(vm.canNudgeP01TableAim)
    }

    @MainActor
    func testLiveBoardOrdinaryShotAndPocketReselection() async throws {
        let (automaticVM, automaticRig, automaticRenderer) = try await liveBoardFixture(recommendation: true)
        defer { automaticVM.cancelInteractiveTrajectoryPreview() }
        _ = try await playLiveOrdinaryShot(vm: automaticVM, rig: automaticRig,
                                          renderer: automaticRenderer, recommendation: true)
        let (vm, rig, renderer) = try await liveBoardFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        XCTAssertEqual(vm.selectedTargetKey, "_5")
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        let restored = try recordLiveBoard("saved-board-third-person", vm: vm, rig: rig, renderer: renderer)
        try assertLiveCameraReference(restored, vm: vm, centersTarget: true)
        XCTAssertTrue(vm.requestPlayerView(.firstPerson, animated: false))
        XCTAssertTrue(vm.requestPlayerView(.thirdPerson, animated: false, resetThirdPerson: true))
        settle(rig)
        let returned = try recordLiveBoard("saved-board-first-to-third", vm: vm, rig: rig, renderer: renderer)
        try assertLiveCameraReference(returned, vm: vm, centersTarget: true)
        let time = try await playLiveOrdinaryShot(vm: vm, rig: rig, renderer: renderer, recommendation: false)

        try vm.restoreSavedBoard(liveBoardSave())
        try await waitForSelectionPrediction(vm)
        settle(rig)
        XCTAssertTrue(vm.selectTarget(key: "_5"))
        try await waitForSelectionPrediction(vm)
        settle(rig)
        let noPocket = try recordLiveBoard("five-no-pocket", vm: vm, rig: rig, renderer: renderer, time: time)
        XCTAssertEqual(vm.selectedPocketIndex, -1)
        XCTAssertFalse(vm.isFeasible)
        try assertLiveCameraReference(noPocket, vm: vm, centersTarget: true)

        vm.beginCameraObservation()
        rig.handleHorizontalSwipe(delta: 300)
        vm.endCameraObservation()
        let side = try recordLiveBoard("five-side-observation", vm: vm, rig: rig, renderer: renderer, time: time)
        XCTAssertGreaterThan(abs(side.state.observationYaw), 0.1)
        XCTAssertTrue(vm.selectTarget(key: "_5"))
        try await waitForSelectionPrediction(vm)
        settle(rig)
        let reselected = try recordLiveBoard("five-reselected", vm: vm, rig: rig, renderer: renderer, time: time)
        try assertLiveCameraReference(reselected, vm: vm, centersTarget: true)
        XCTAssertEqual(reselected.state.observationYaw, 0)
        XCTAssertEqual(vm.selectedPocketIndex, -1)

        vm.selectPocket(at: 0)
        try await waitForSelectionPrediction(vm)
        settle(rig)
        let pocket = try recordLiveBoard("five-pocket-zero", vm: vm, rig: rig, renderer: renderer, time: time)
        XCTAssertEqual(vm.selectedPocketIndex, 0)
        XCTAssertTrue(vm.isFeasible)
        XCTAssertEqual(vm.aimMode, .pocket)
        let shaft = try XCTUnwrap(vm.scene.lastCueAim)
        XCTAssertEqual(pocket.shot.aim, SIMD3(shaft.x, shaft.y, shaft.z))
        XCTAssertGreaterThan(simd_distance(reselected.pose.forward, pocket.pose.forward), 0.001)
    }

    @MainActor
    func testLiveBoardStandardBreakWithRecommendationOffAndOn() async throws {
        let cases: [(recommends: Bool, prefersFree: Bool, name: String)] = [
            (false, false, "break-recommendation-off"),
            (false, true, "break-free-recommendation-off"),
            (true, false, "break-recommendation-on"),
            (true, true, "break-free-recommendation-on")
        ]
        for (recommends, prefersFree, prefix) in cases {
            let (vm, rig, renderer) = try await liveBoardFixture(recommendation: recommends)
            defer { vm.cancelBreakFlow(); vm.cancelInteractiveTrajectoryPreview() }
            if prefersFree {
                vm.setPreferredAimMode(.free)
                try await waitForSelectionPrediction(vm)
                settle(rig)
                XCTAssertEqual(vm.preferredAimMode, .free)
            }
            try recordLiveBoard("\(prefix)-saved-board", vm: vm, rig: rig, renderer: renderer)
            var outcomes: [BreakOutcome] = []
            vm.startBreakFlow(game: .chineseEightBall, manualDeliver: false, seed: 61) { outcomes.append($0) }
            let runner = try XCTUnwrap(vm.breakRunner)
            settle(rig)
            let addressed = try recordLiveBoard("\(prefix)-racked", vm: vm, rig: rig, renderer: renderer)
            runner.breakNow()
            XCTAssertTrue(runner.isBusy)
            var watchingPose: P01CameraMotion.Pose?
            var pullbackStart: Double?
            var pullbackEnd: Double?
            var sawFollowThrough = false
            let time = try await driveLiveShot(renderer, rig: rig) {
                guard vm.breakRunner != nil else { return false }
                guard let current = rig.p01Snapshot else { return true }
                if runner.statusText == "开球中…", vm.scene.cueStick?.rootNode.isHidden == false {
                    if !sawFollowThrough { XCTAssertEqual(current.pose, addressed.pose) }
                    sawFollowThrough = true
                    XCTAssertNotEqual(current.state.watchingBreak, true)
                }
                if current.state.watchingBreak == true {
                    XCTAssertEqual(vm.scene.cueStick?.rootNode.isHidden, true)
                    if let move = current.motion, pullbackStart == nil {
                        pullbackStart = move.start
                        XCTAssertEqual(move.duration, 1.5, accuracy: 0.00001)
                        XCTAssertEqual(move.origin, addressed.pose)
                    } else if current.motion == nil, pullbackEnd == nil {
                        pullbackEnd = current.time
                        watchingPose = current.pose
                    }
                }
                return true
            }
            XCTAssertTrue(sawFollowThrough)
            XCTAssertEqual(try XCTUnwrap(pullbackEnd) - XCTUnwrap(pullbackStart), 1.5, accuracy: 1.0 / 60 + 0.001)
            let wide = try XCTUnwrap(watchingPose, "The break must already be framed while balls are rolling")
            let layout = try XCTUnwrap(rig.p01Snapshot?.layout)
            let edge = layout.tableHalfExtents
            for side: Float in [-1, 1] {
                let near = try XCTUnwrap(wide.project(.init(edge.x, layout.surfaceY, side * edge.y), layout: layout))
                let far = try XCTUnwrap(wide.project(.init(-edge.x, layout.surfaceY, side * edge.y), layout: layout))
                // The camera bounds also include the margin outside the visible rail mesh.
                XCTAssertEqual(abs(near.x - 0.5), 0.46, accuracy: 0.025)
                XCTAssertEqual(near.y, 0.93, accuracy: 0.025)
                XCTAssertEqual(far.y, 0.305, accuracy: 0.025)
            }
            try await waitForSelectionPrediction(vm)
            settle(rig)
            XCTAssertEqual(outcomes.count, 1)
            XCTAssertTrue(try XCTUnwrap(outcomes.first).settled)
            XCTAssertNil(vm.breakRunner)
            let rested = try recordLiveBoard("\(prefix)-rested", vm: vm, rig: rig, renderer: renderer, time: time)
            try assertLiveCameraReference(rested, vm: vm, centersTarget: false)
            if recommends {
                XCTAssertNotEqual(rested.state.watchingBreak, true)
                XCTAssertNotEqual(rested.pose, wide)
                XCTAssertNotNil(vm.selectedTargetKey)
                if prefersFree {
                    XCTAssertEqual(vm.preferredAimMode, .free)
                    XCTAssertEqual(vm.aimMode, .free)
                    XCTAssertEqual(vm.selectedPocketIndex, -1)
                    XCTAssertTrue(vm.isFeasible)
                    XCTAssertFalse(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
                    try assertLiveCameraReference(rested, vm: vm, centersTarget: true)
                } else {
                    XCTAssertEqual(vm.aimMode, .pocket)
                    XCTAssertGreaterThanOrEqual(vm.selectedPocketIndex, 0)
                }
                let displayedAim = try XCTUnwrap(vm.scene.lastCueAim)
                XCTAssertGreaterThan(simd_dot(rested.shot.aim, SIMD3(displayedAim.x, displayedAim.y, displayedAim.z)), 0.9999)
            } else {
                XCTAssertEqual(rested.state.watchingBreak, true)
                XCTAssertEqual(rested.pose, wide)
                XCTAssertNil(vm.selectedTargetKey)
                XCTAssertEqual(vm.selectedPocketIndex, -1)
                XCTAssertTrue(vm.selectTarget(key: "_5"))
                try await waitForSelectionPrediction(vm)
                settle(rig)
                let five = try recordLiveBoard("\(prefix)-five", vm: vm, rig: rig, renderer: renderer, time: time)
                XCTAssertNotEqual(five.state.watchingBreak, true)
                try assertLiveCameraReference(five, vm: vm, centersTarget: true)
            }
        }
    }

    @MainActor
    func testSlowBreakHandsOffOnlyAfterPullbackFinishes() async throws {
        let (vm, rig, renderer) = try await liveBoardFixture(recommendation: true)
        defer { vm.cancelBreakFlow(); vm.cancelInteractiveTrajectoryPreview() }
        var atDelivery: P01CameraMotion.Snapshot?
        vm.startBreakFlow(game: .chineseEightBall, manualDeliver: true, seed: 61)
        let runner = try XCTUnwrap(vm.breakRunner)
        settle(rig)
        runner.velocity = BreakFlowRunner.breakVelocityRange.lowerBound
        runner.breakNow()
        // Manual delivery exposes the exact moment the board becomes available for the next shot.
        _ = try await driveLiveShot(renderer, rig: rig) {
            if runner.phase == .settled { atDelivery = rig.p01Snapshot; return false }
            return true
        }
        let wide = try XCTUnwrap(atDelivery)
        XCTAssertTrue(try XCTUnwrap(vm.scene.cueStick).rootNode.isHidden)
        XCTAssertEqual(wide.state.watchingBreak, true)
        XCTAssertNil(wide.motion)
        runner.confirmSettled()
        XCTAssertNil(vm.breakRunner)
    }

    @MainActor
    func testLiveBoardRepeatedElevationAndZoom() async throws {
        let (vm, rig, renderer) = try await liveBoardFixture()
        defer { vm.cancelInteractiveTrajectoryPreview() }
        XCTAssertTrue(vm.selectTarget(key: "_5"))
        try await waitForSelectionPrediction(vm)
        settle(rig)
        let start = try recordLiveBoard("zoom-start", vm: vm, rig: rig, renderer: renderer)
        for round in 1...6 {
            let raisesFirst = round.isMultiple(of: 2) == false
            let forward: [(String, () -> Void)] = [
                ("raise", { rig.handleVerticalSwipe(delta: 100) }),
                ("near", { rig.handlePinch(scale: 1.20) }),
                ("lower", { rig.handleVerticalSwipe(delta: -100) }),
                ("far", { rig.handlePinch(scale: 1 / 1.20) })
            ]
            let reverse = [forward[1], forward[0], forward[3], forward[2]]
            vm.beginCameraObservation()
            var previous = try XCTUnwrap(rig.p01Snapshot)
            for (name, gesture) in raisesFirst ? forward : reverse {
                gesture()
                settle(rig)
                let current = try XCTUnwrap(rig.p01Snapshot)
                try assertLiveCameraReference(current, vm: vm, centersTarget: true, withinReadableArea: true)
                if name == "near" || name == "far" {
                    XCTAssertEqual(current.pose.pitch, previous.pose.pitch, accuracy: 0.005)
                    if name == "near" { XCTAssertLessThan(current.state.distance, previous.state.distance) }
                    else { XCTAssertGreaterThan(current.state.distance, previous.state.distance) }
                } else if name == "raise" {
                    XCTAssertGreaterThan(current.pose.eye.y, previous.pose.eye.y)
                } else {
                    XCTAssertLessThan(current.pose.eye.y, previous.pose.eye.y)
                }
                if round <= 2 {
                    try recordLiveBoard("zoom-\(round)-\(name)", vm: vm, rig: rig, renderer: renderer)
                }
                previous = current
            }
            vm.endCameraObservation()
            settle(rig)
            let returned = try XCTUnwrap(rig.p01Snapshot)
            XCTAssertEqual(returned.state.height, start.state.height, accuracy: 0.001)
            XCTAssertEqual(returned.state.distance, start.state.distance, accuracy: 0.001)
            XCTAssertEqual(returned.pose.pitch, start.pose.pitch, accuracy: 0.005)
        }
        try recordLiveBoard("zoom-end", vm: vm, rig: rig, renderer: renderer)
    }
}
