import XCTest
import SceneKit
import UIKit
import simd
@testable import QiuJi

final class P01CameraMotionTests: XCTestCase {
    private var layout: P01CameraMotion.Layout {
        .init(viewport:.init(874,402),insets:.init(128,42,128,18),surfaceY:0.8,
              tableHalfExtents:.init(1.405481,0.7775),roomHalfExtents:.init(3.65,2.65),ceilingY:3.6,ballRadius:0.028575)
    }
    private func shot(x:Float=0,z:Float=0,yaw:Float=0,side:Float=0) -> P01CameraMotion.Shot {
        let aim=SIMD3<Float>(cos(yaw),0,sin(yaw)),cue=SIMD3<Float>(x,0.828575,z)
        return .init(cue:cue,strike:cue+SIMD3(-aim.z,0,aim.x)*side,aim:aim,elevation:0.05)
    }
    func testGeometryIndependentAxesShaftAndLowerAnchor() throws {
        var count=0
        for x:Float in [-1.20,0,1.20] { for z:Float in [-0.57,0,0.57] {
            for degrees in stride(from:0,through:360,by:15) { for side:Float in [-0.02,0,0.02] {
                let s=shot(x:x,z:z,yaw:Float(degrees)*(.pi/180),side:side)
                let base=try XCTUnwrap(P01CameraMotion.evaluate(state:.init(),shot:s,layout:layout))
                let forward=simd_normalize(SIMD2(base.forward.x,base.forward.z))
                XCTAssertEqual(simd_dot(forward,SIMD2(s.aim.x,s.aim.z)),1,accuracy:0.00001)
                let offset=base.eye-s.strike
                XCTAssertEqual(offset.x*s.aim.z-offset.z*s.aim.x,0,accuracy:0.00001)
                XCTAssertLessThan(simd_dot(offset,s.aim),0)
                let screen=try XCTUnwrap(base.project(s.cue,layout:layout))
                XCTAssertEqual(screen.y,0.67,accuracy:0.00001)
                if side != 0 { XCTAssertGreaterThan(abs(screen.x-0.5),0.001) }
                var raised=P01CameraMotion.State();raised.height=1.2
                let high=try XCTUnwrap(P01CameraMotion.evaluate(state:raised,shot:s,layout:layout))
                XCTAssertEqual(high.eye.x,base.eye.x);XCTAssertEqual(high.eye.z,base.eye.z)
                var close=P01CameraMotion.State();close.distance=1.1
                let near=try XCTUnwrap(P01CameraMotion.evaluate(state:close,shot:s,layout:layout))
                XCTAssertEqual(near.eye.y,base.eye.y);XCTAssertEqual(near.verticalFOV,base.verticalFOV)
                XCTAssertTrue(layout.legalEye(base.eye));count += 1
            }}
        }}
        XCTAssertEqual(count,675)
    }
    func testThirdPersonPinchKeepsPitchAndManualPresetResets() throws {
        var c = try XCTUnwrap(P01CameraMotion(shot: shot(), layout: layout, anchoredTransitions: true))
        let standard = c.pose
        c.pan(.init(200, 75))
        let observed = c.pose
        for scale: Float in [1.45, 0.78] {
            c.apply(.init(time: 0, kind: .pinch, scale: scale, preservePinchPitch: true))
            XCTAssertEqual(c.pose.pitch, observed.pitch, accuracy: 0.00001)
            XCTAssertEqual(c.pose.eye.y, observed.eye.y)
            XCTAssertNotEqual(c.pose.eye, observed.eye)
        }
        c.updateShot(shot(yaw: 0.5), manuallyAimed: true)
        c.advance(to: 10)
        XCTAssertEqual(c.pose.pitch, observed.pitch, accuracy: 0.00001)
        c.updateShot(shot(), manuallyAimed: true)
        c.advance(to: 20)
        XCTAssertTrue(c.select(.firstPerson, animated: false))
        c.apply(.init(time: 20, kind: .view, animated: false, view: .thirdPerson, resetThirdPerson: true))
        XCTAssertEqual(c.pose, standard)
        c.pinch(1.5, preservingPitch: true)
        XCTAssertTrue(c.select(.thirdPerson, animated: false, resetThirdPerson: true))
        XCTAssertEqual(c.pose, standard)
    }

    func testThirdPersonZoomClipsAtReadableBoundsWithoutTilting() throws {
        var compact = layout
        compact.viewport = .init(667, 375)
        compact.insets = .init(92, 165, 92, 30)
        for viewport in [layout, compact] {
            for (x, z): (Float, Float) in [(0, 0), (1.2, 0.57), (-1.2, -0.57)] {
                let s = shot(x: x, z: z, yaw: 1.3, side: 0.019)
                var c = try XCTUnwrap(P01CameraMotion(shot: s, layout: viewport, anchoredTransitions: true))
                c.pan(.init(105, 0.55 / 0.67 * viewport.viewport.y))
                let initial = c.pose
                for (index, scale): (Int, Float) in [(0, 20), (1, 0.02)] {
                    c.pinch(scale, preservingPitch: true)
                    let stop = c.pose
                    XCTAssertEqual(stop.eye.y, initial.eye.y)
                    XCTAssertEqual(stop.pitch, initial.pitch, accuracy: 0.00001)
                    XCTAssertEqual(stop.yaw, initial.yaw, accuracy: 0.00001)
                    XCTAssertEqual(stop.verticalFOV, initial.verticalFOV)
                    XCTAssertGreaterThan(simd_distance(stop.eye, initial.eye), 0.1)
                    if index == 0 { XCTAssertGreaterThan(c.state.distance, 0.9) }
                    let shaftBack = -s.aim * cos(s.elevation) + SIMD3<Float>(0, sin(s.elevation), 0)
                    let furthestTip = s.strike + shaftBack * (CueStroke.addressPull + CueClearance.tipOffset)
                    for (point, radius) in [(s.cue, viewport.ballRadius), (furthestTip, CueClearance.tipRadius)] {
                        for axis in [SIMD3<Float>(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)] {
                            for sign: Float in [-1, 1] {
                                let screen = try XCTUnwrap(stop.project(point + axis * radius * sign, layout: viewport))
                                XCTAssertGreaterThanOrEqual(screen.x, viewport.insets.x / viewport.viewport.x - 0.00001)
                                XCTAssertGreaterThanOrEqual(screen.y, viewport.insets.y / viewport.viewport.y - 0.00001)
                                XCTAssertLessThanOrEqual(screen.x, 1 - viewport.insets.z / viewport.viewport.x + 0.00001)
                                XCTAssertLessThanOrEqual(screen.y, 1 - viewport.insets.w / viewport.viewport.y + 0.00001)
                            }
                        }
                    }
                    c.pinch(scale, preservingPitch: true)
                    XCTAssertLessThan(simd_distance(c.pose.eye, stop.eye), 0.00001)
                }
            }
        }
    }

    func testThirdPersonRaiseAndZoomLoopsHaveTheSamePoseInBothOrders() throws {
        for position: SIMD2<Float> in [.zero, .init(0, 0.57), .init(1.2, 0), .init(1.2, 0.57)] {
            let s = shot(x: position.x, z: position.y, yaw: 0.7, side: 0.019)
            let rise = SIMD2<Float>(110, layout.viewport.y * 0.55 / 0.67)
            let scale: Float = 1.10
            let initial = try XCTUnwrap(P01CameraMotion(shot: s, layout: layout, anchoredTransitions: true))
            var firstRaise = initial
            var firstZoom = initial
            for _ in 0..<4 {
                firstRaise.pan(rise)
                firstRaise.pinch(scale, preservingPitch: true)
                firstZoom.pinch(scale, preservingPitch: true)
                firstZoom.pan(rise)
                XCTAssertLessThan(simd_distance(firstRaise.pose.eye, firstZoom.pose.eye), 0.00001)
                XCTAssertEqual(firstRaise.pose.pitch, firstZoom.pose.pitch, accuracy: 0.00001)

                firstRaise.pan(-rise)
                firstRaise.pinch(1 / scale, preservingPitch: true)
                firstZoom.pinch(1 / scale, preservingPitch: true)
                firstZoom.pan(-rise)
                for camera in [firstRaise, firstZoom] {
                    XCTAssertEqual(camera.state.distance, initial.state.distance, accuracy: 0.00001)
                    XCTAssertEqual(camera.state.height, initial.state.height, accuracy: 0.00001)
                    XCTAssertEqual(camera.state.observationYaw, initial.state.observationYaw, accuracy: 0.00001)
                    XCTAssertLessThan(simd_distance(camera.pose.eye, initial.pose.eye), 0.00001)
                    XCTAssertEqual(camera.pose.pitch, initial.pose.pitch, accuracy: 0.00001)
                }
            }
        }
    }

    func testThirdPersonAtNearStopKeepsCueReadableAndCanMoveAwayFromTheStop() throws {
        let s = shot(x: 1.2, z: 0.57, yaw: 1.3, side: 0.019)
        var c = try XCTUnwrap(P01CameraMotion(shot: s, layout: layout, anchoredTransitions: true))
        let rise = SIMD2<Float>(0, 0.55 / 0.67 * layout.viewport.y)
        c.pinch(20, preservingPitch: true)
        let nearDistance = c.state.distance
        let ballBottom = s.cue - SIMD3<Float>(0, layout.ballRadius, 0)
        let bottomEdge = 1 - layout.insets.w / layout.viewport.y
        c.pan(rise)
        let blockedHeight = c.state.height
        XCTAssertEqual(c.state.distance, nearDistance)
        XCTAssertLessThan(blockedHeight, 1.2)
        XCTAssertLessThanOrEqual(try XCTUnwrap(c.pose.project(ballBottom, layout: layout)).y, bottomEdge)
        for _ in 0..<4 {
            c.pan(rise)
            c.pinch(20, preservingPitch: true)
        }
        XCTAssertEqual(c.state.height, blockedHeight, accuracy: 0.00001)
        XCTAssertEqual(c.state.distance, nearDistance, accuracy: 0.00001)
        c.pan(-rise)
        XCTAssertLessThan(c.state.height, blockedHeight)
        XCTAssertLessThan(try XCTUnwrap(c.pose.project(ballBottom, layout: layout)).y, bottomEdge - 0.05)
        c.pinch(0.7, preservingPitch: true)
        XCTAssertGreaterThan(c.state.distance, nearDistance)
        let lowered = c.state.height
        c.pan(rise)
        XCTAssertEqual(c.state.height, lowered + 0.55, accuracy: 0.00001)
        XCTAssertLessThanOrEqual(try XCTUnwrap(c.pose.project(ballBottom, layout: layout)).y, bottomEdge)
    }

    func testPilotFirstPersonEyeSitsAboveTheAddressButt() throws {
        for z: Float in [-0.74, 0.74] {
            for degrees in stride(from: 0, to: 360, by: 30) {
                for length: Float in [1.38, 1.51] {
                    var s = shot(x: 1.37, z: z, yaw: Float(degrees) * .pi / 180, side: 0.017)
                    s.addressButtOffset = length
                    s.elevation = 0.25
                    var camera = try XCTUnwrap(P01CameraMotion(shot: s, layout: layout, anchoredTransitions: true))
                    XCTAssertTrue(camera.select(.firstPerson, animated: false))
                    let butt = s.strike - s.aim * (length * cos(s.elevation))
                        + SIMD3<Float>(0, length * sin(s.elevation), 0)
                    XCTAssertEqual(simd_distance(camera.pose.eye, butt + SIMD3(0, 0.13, 0)), 0, accuracy: 0.00001)
                    XCTAssertEqual(try XCTUnwrap(camera.pose.project(s.cue, layout: layout)).y, 0.70, accuracy: 0.0001)
                    XCTAssertTrue(layout.legalEye(camera.pose.eye))
                }
            }
        }
    }

    func testFirstPersonFixedEyeAndBoundedOcclusion() throws {
        var c=try XCTUnwrap(P01CameraMotion(shot:shot(x:1.1,z:0.55,yaw:0.8),layout:layout))
        XCTAssertTrue(c.select(.firstPerson,animated:false))
        let base=c.pose
        XCTAssertEqual(try XCTUnwrap(base.project(c.shot.cue,layout:layout)).y,0.7,accuracy:0.00001)
        c.beginObservation();c.pan(.init(80,500))
        XCTAssertEqual(c.pose.eye,base.eye);XCTAssertEqual(c.pose.verticalFOV,base.verticalFOV)
        XCTAssertGreaterThan(simd_dot(c.pose.forward,base.orientation.act(.init(1,0,0))),0)
        c.pan(.init(10000,0));XCTAssertEqual(c.state.headYaw,.pi/6,accuracy:0.00001)
        c.release();c.advance(to:10)
        XCTAssertLessThan(simd_distance(c.pose.eye,base.eye),0.00001)
        XCTAssertLessThan(simd_distance(c.pose.forward,base.forward),0.00001)
        var state=P01CameraMotion.State();state.view = .firstPerson
        let lifted=try XCTUnwrap(P01CameraMotion.evaluate(state:state,shot:c.shot,layout:layout,clear:{ eye,_ in eye.y >= base.eye.y+0.08 }))
        XCTAssertGreaterThanOrEqual(lifted.eye.y,base.eye.y+0.08)
        XCTAssertLessThan(lifted.eye.y,base.eye.y+0.09)
        XCTAssertNil(P01CameraMotion.evaluate(state:state,shot:c.shot,layout:layout,clear:{_,_ in false}))
    }
    func testOverviewCircleAndFrozenLens() throws {
        XCTAssertEqual(P01CameraMotion.legacyRadius(0),3.5,accuracy:0.00001)
        XCTAssertEqual(P01CameraMotion.legacyRadius(.pi/2),2.5,accuracy:0.00001)
        var c=try XCTUnwrap(P01CameraMotion(shot:shot(),layout:layout))
        XCTAssertTrue(c.select(.overview,animated:false));let fov=c.pose.verticalFOV, pitch=c.pose.pitch, eye=c.pose.eye
        for _ in 0..<1440 {
            c.pan(.init(2 * .pi / (1440*0.00135),0))
            XCTAssertEqual(hypot(c.pose.eye.x,c.pose.eye.z),hypot(eye.x,eye.z),accuracy:0.00001)
            XCTAssertEqual(c.pose.eye.y,eye.y)
            XCTAssertEqual(c.pose.pitch,pitch,accuracy:0.00001)
            XCTAssertEqual(c.pose.verticalFOV,fov)
            XCTAssertTrue(layout.legalEye(c.pose.eye))
            for x in [-layout.tableHalfExtents.x,layout.tableHalfExtents.x] {
                for z in [-layout.tableHalfExtents.y,layout.tableHalfExtents.y] {
                    let p=try XCTUnwrap(c.pose.project(.init(x,layout.surfaceY,z),layout:layout))
                    XCTAssertGreaterThan(p.x,128/874);XCTAssertLessThan(p.x,1-128/874)
                    XCTAssertGreaterThan(p.y,42/402);XCTAssertLessThan(p.y,1-18/402)
                }
            }
        }
    }
    func testCadenceReplayContinuousAimAndInterrupt() throws {
        let initial=try XCTUnwrap(P01CameraMotion(shot:shot(x:0.3,z:0.2),layout:layout,anchoredTransitions:true))
        var events=[P01CameraMotion.Input(time:0,kind:.view,view:.overview),
                    .init(time:0.723,kind:.pan,delta:.init(70,0)),
                    .init(time:0.9,kind:.aim,shot:shot(x:0.3,z:0.2,yaw:0.1))]
        for i in 1...100 { events.append(.init(time:0.9+Double(i)*0.01,kind:.aim,shot:shot(x:0.3,z:0.2,yaw:Float(i)*0.08))) }
        events.append(.init(time:2.2,kind:.view,view:.firstPerson))
        events.append(.init(time:3.1,kind:.pan,delta:.init(-50,0)))
        events.append(.init(time:3.4,kind:.release))
        func replay(_ fps:Int) -> [P01CameraMotion.Pose] {
            var c=initial,index=0,result=[P01CameraMotion.Pose]()
            for frame in 0...fps*6 {
                let now=Double(frame)/Double(fps)
                while index<events.count && events[index].time<=now { c.apply(events[index]);index += 1 }
                c.advance(to:now)
                XCTAssertTrue(layout.legalEye(c.pose.eye))
                if frame % (fps/30)==0 { result.append(c.pose) }
            }
            XCTAssertFalse(c.hasPendingMotion)
            return result
        }
        let a=replay(30)
        for fps in [60,120] { let b=replay(fps)
            XCTAssertEqual(a.count,b.count)
            for (x,y) in zip(a,b) {
                XCTAssertLessThan(simd_distance(x.eye,y.eye),0.0001)
                XCTAssertLessThan(simd_distance(x.forward,y.forward),0.0001)
                XCTAssertEqual(x.verticalFOV,y.verticalFOV,accuracy:0.0001)
            }
        }
        var c=initial;_ = c.select(.overview);c.advance(to:0.1);let shown=c.pose
        c.beginObservation();XCTAssertEqual(c.pose,shown)
        c.pan(.init(0,0));c.advance(to:10);XCTAssertEqual(c.pose,shown)
    }
    func testSnapshotsInvalidInputsAndContextCancellation() throws {
        var c=try XCTUnwrap(P01CameraMotion(shot:shot(),layout:layout))
        c.beginObservation();c.pan(.init(100,-20))
        let saved=c.snapshot(),data=try JSONEncoder().encode(saved)
        let restored=try JSONDecoder().decode(P01CameraMotion.Snapshot.self,from:data)
        _ = c.select(.firstPerson);c.advance(to:0.1)
        XCTAssertTrue(c.restore(restored));XCTAssertEqual(c.pose,saved.pose)
        c.pan(.init(.nan,0));c.pinch(0);XCTAssertEqual(c.pose,saved.pose)
        _ = c.select(.overview);c.advance(to:0.2);c.setContext(UUID());let pose=c.pose
        c.advance(to:20);XCTAssertEqual(c.pose,pose)
        XCTAssertFalse(c.restore(saved))
    }
    func testSmoothTransitionSpeedBoundsAndStationaryEnd() throws {
        var c=try XCTUnwrap(P01CameraMotion(shot:shot(x:-1.1,z:-0.5,yaw:1.1),layout:layout,anchoredTransitions:true))
        XCTAssertTrue(c.select(.overview));var previous=c.pose
        var maxSpeed:Float=0,maxAngular:Float=0
        for i in 1...2400 {
            c.advance(to:Double(i)/240)
            maxSpeed=max(maxSpeed,simd_distance(c.pose.eye,previous.eye)*240)
            // atan2 cross/dot avoids acos float amplification at tiny frame angles.
            let a=previous.forward,b=c.pose.forward
            maxAngular=max(maxAngular,atan2(simd_length(simd_cross(a,b)),simd_dot(a,b))*240)
            previous=c.pose
        }
        XCTAssertLessThanOrEqual(maxSpeed,1.801)
        XCTAssertLessThanOrEqual(maxAngular,.pi/2+0.001)
        XCTAssertFalse(c.hasPendingMotion);let final=c.pose;c.advance(to:100);XCTAssertEqual(c.pose,final)
    }

    func testAimViewSwitchKeepsCueProjectionBetweenEndpoints() throws {
        let s = shot(x: -1.1, z: 0.6, yaw: 0.8, side: 0.02)
        for start in [P01CameraMotion.View.thirdPerson, .firstPerson] {
            for observation in [Float(0), 300, -1_450] {
                var camera = try XCTUnwrap(P01CameraMotion(shot: s, layout: layout, anchoredTransitions: true))
                XCTAssertTrue(camera.select(start, animated: false))
                if observation != 0 {
                    camera.beginObservation()
                    camera.pan(.init(observation, 0))
                }
                let origin = camera.pose
                let last = start == .firstPerson ? P01CameraMotion.View.thirdPerson : .firstPerson
                XCTAssertTrue(camera.select(last))
                let move = try XCTUnwrap(camera.snapshot().motion)
                let target = try XCTUnwrap(P01CameraMotion.evaluate(state: camera.state, shot: s, layout: layout))
                let startY = try XCTUnwrap(origin.project(s.cue, layout: layout)).y
                let endY = try XCTUnwrap(target.project(s.cue, layout: layout)).y
                var previousY = startY
                for frame in 1...120 {
                    camera.advance(to: move.start + move.duration * Double(frame) / 120)
                    let eye = camera.pose.eye
                    XCTAssertTrue(layout.legalEye(eye))
                    XCTAssertLessThanOrEqual(eye.y, max(origin.eye.y, target.eye.y) + 0.00001)
                    XCTAssertGreaterThanOrEqual(eye.y, min(origin.eye.y, target.eye.y) - 0.00001)
                    let y = try XCTUnwrap(camera.pose.project(s.cue, layout: layout)).y
                    XCTAssertGreaterThanOrEqual(y, min(startY, endY) - 0.00001)
                    XCTAssertLessThanOrEqual(y, max(startY, endY) + 0.00001)
                    if endY >= startY { XCTAssertGreaterThanOrEqual(y, previousY - 0.00001) }
                    else { XCTAssertLessThanOrEqual(y, previousY + 0.00001) }
                    previousY = y
                }
                XCTAssertEqual(camera.pose, target)
                XCTAssertFalse(camera.hasPendingMotion)
            }
        }
    }

    func testOverviewHandoffIsReversibleAndInterruptible() throws {
        let s = shot(x: 0.7, z: 0.45, yaw: 1.2, side: -0.02)
        var camera = try XCTUnwrap(P01CameraMotion(shot: s, layout: layout, anchoredTransitions: true))
        let tableCenter = SIMD3<Float>(0, layout.surfaceY, 0)
        XCTAssertTrue(camera.select(.overview))
        func sample(_ camera: inout P01CameraMotion, from start: SIMD3<Float>, to end: SIMD3<Float>) throws -> [P01CameraMotion.Pose] {
            let origin = camera.pose
            let move = try XCTUnwrap(camera.snapshot().motion)
            let target = try XCTUnwrap(P01CameraMotion.evaluate(state: camera.state, shot: camera.shot, layout: layout))
            let from = try XCTUnwrap(origin.project(start, layout: layout))
            let to = try XCTUnwrap(target.project(end, layout: layout))
            var result = [P01CameraMotion.Pose]()
            for frame in 0...60 {
                let u = Double(frame) / 60
                camera.advance(to: move.start + move.duration * u)
                let t = Float(6 * pow(u, 5) - 15 * pow(u, 4) + 10 * pow(u, 3))
                let screen = try XCTUnwrap(camera.pose.project(start + (end - start) * t, layout: layout))
                XCTAssertEqual(screen.x, from.x + (to.x - from.x) * t, accuracy: 0.00001)
                XCTAssertEqual(screen.y, from.y + (to.y - from.y) * t, accuracy: 0.00001)
                XCTAssertTrue(layout.legalEye(camera.pose.eye))
                result.append(camera.pose)
            }
            return result
        }
        let toOverview = try sample(&camera, from: s.cue, to: tableCenter)
        XCTAssertTrue(camera.select(.thirdPerson))
        let back = try sample(&camera, from: tableCenter, to: s.cue)
        for (a, b) in zip(toOverview, back.reversed()) {
            XCTAssertLessThan(simd_distance(a.eye, b.eye), 0.00001)
            XCTAssertLessThan(simd_distance(a.forward, b.forward), 0.00001)
        }

        XCTAssertTrue(camera.select(.overview))
        let move = try XCTUnwrap(camera.snapshot().motion)
        camera.advance(to: move.start + move.duration * 0.35)
        let visible = camera.pose
        XCTAssertTrue(camera.select(.firstPerson))
        XCTAssertEqual(camera.pose, visible)
        let record = P01CameraMotion.Recording(geometryID: "interrupted-handoff", initial: camera.snapshot(), layout: layout, inputs: [])
        let decoded = try JSONDecoder().decode(P01CameraMotion.Recording.self, from: JSONEncoder().encode(record))
        var replay = try XCTUnwrap(P01CameraMotion(recording: decoded))
        for offset in [0.001, 0.25, 1, 10] {
            camera.advance(to: record.initial.time + offset)
            replay.advance(to: record.initial.time + offset)
            XCTAssertEqual(camera.pose, replay.pose)
        }
    }

    func testOldRecordingKeepsOriginalLiftAndDecodesWithoutFraming() throws {
        var camera = try XCTUnwrap(P01CameraMotion(shot: shot(), layout: layout, anchoredTransitions: true))
        var initial = camera.snapshot()
        initial.state.anchoredTransitions = nil
        let record = P01CameraMotion.Recording(geometryID: "legacy-lift", initial: initial, layout: layout, inputs: [])
        let decoded = try JSONDecoder().decode(P01CameraMotion.Recording.self, from: JSONEncoder().encode(record))
        XCTAssertNil(decoded.initial.state.anchoredTransitions)
        camera = try XCTUnwrap(P01CameraMotion(recording: decoded))
        XCTAssertTrue(camera.select(.firstPerson))
        let move = try XCTUnwrap(camera.snapshot().motion)
        XCTAssertNil(move.framing)
        XCTAssertEqual(move.lift, 0.15)
        let target = try XCTUnwrap(P01CameraMotion.evaluate(state: camera.state, shot: camera.shot, layout: layout))
        camera.advance(to: move.start + move.duration * 0.5)
        XCTAssertEqual(camera.pose.eye.y, (move.origin.eye.y + target.eye.y) / 2 + 0.15, accuracy: 0.00001)
    }

    func testTargetTurnAcceleratesCruisesAndDeceleratesAtTheSameAngularRate() throws {
        for angle in [Float.pi / 2, Float.pi * 0.95] {
            var camera = try XCTUnwrap(P01CameraMotion(shot: shot(), layout: layout, anchoredTransitions: true))
            XCTAssertTrue(camera.selectTarget(shot: shot(yaw: angle), preservesVisiblePose: false, turnPace: .selection120))
            let move = try XCTUnwrap(camera.snapshot().motion)
            XCTAssertEqual(move.duration, Double(angle / .pi) * 1.5 + 0.16, accuracy: 0.001)
            func speed(_ time: Double) -> Float {
                angle * (move.blend(at: time + 0.001) - move.blend(at: time)) / 0.001
            }
            XCTAssertLessThan(speed(0), 0.01)
            XCTAssertEqual(speed(0.08), .pi / 3, accuracy: 0.04)
            XCTAssertEqual(speed(move.duration / 2), 2 * .pi / 3, accuracy: 0.01)
            XCTAssertLessThan(speed(move.duration - 0.001), 0.01)
            camera.advance(to: move.duration)
            XCTAssertFalse(camera.hasPendingMotion)
        }
    }

    func testRecordedTargetTurnUsesItsOriginalTiming() throws {
        for pace in [P01CameraMotion.TurnPace?.none, .selection120] {
            var camera = try XCTUnwrap(P01CameraMotion(shot: shot(), layout: layout, anchoredTransitions: true))
            let input = P01CameraMotion.Input(time: 0, kind: .target, shot: shot(yaw: .pi / 2),
                                              pacedTargetTurn: pace == nil ? true : nil, turnPace: pace)
            camera.apply(try JSONDecoder().decode(P01CameraMotion.Input.self, from: JSONEncoder().encode(input)))
            XCTAssertEqual(try XCTUnwrap(camera.snapshot().motion).duration, pace == nil ? 0.62 : 0.91, accuracy: 0.001)
        }
    }

    func testTargetSelectionAlignsOrPreservesThePresentedPose() throws {
        let original = shot(x: 0.7, z: 0.45, yaw: 1.2, side: -0.02)
        let selected = shot(x: 0.7, z: 0.45, yaw: -0.9, side: -0.02)
        var camera = try XCTUnwrap(P01CameraMotion(shot: original, layout: layout, anchoredTransitions: true))
        camera.beginObservation()
        camera.pan(.init(300, 0))
        let visible = camera.pose
        let record = P01CameraMotion.Recording(geometryID: "selected-target", initial: camera.snapshot(), layout: layout, inputs: [])
        var replay = try XCTUnwrap(P01CameraMotion(recording: record))
        let input = P01CameraMotion.Input(time: camera.time, kind: .target, shot: selected, preservesVisiblePose: true)
        replay.apply(try JSONDecoder().decode(P01CameraMotion.Input.self, from: JSONEncoder().encode(input)))
        XCTAssertTrue(camera.selectTarget(shot: selected, preservesVisiblePose: true))
        XCTAssertEqual(camera.pose, visible)
        XCTAssertEqual(camera.pose, replay.pose)
        XCTAssertEqual(camera.shot, selected)
        XCTAssertFalse(camera.hasPendingMotion)
        camera.pan(.init(0.03, 0))
        XCTAssertLessThan(simd_distance(camera.pose.forward, visible.forward), 0.001)
        XCTAssertLessThan(simd_distance(camera.pose.eye, visible.eye), 0.001)

        let observed = camera.pose
        XCTAssertTrue(camera.selectTarget(shot: original, preservesVisiblePose: false))
        XCTAssertEqual(camera.pose, observed)
        XCTAssertEqual(camera.shot, original)
        XCTAssertTrue(camera.hasPendingMotion)
        camera.advance(to: 20)
        XCTAssertEqual(camera.pose, P01CameraMotion.evaluate(state: camera.state, shot: original, layout: layout))
        XCTAssertFalse(camera.hasPendingMotion)

        XCTAssertTrue(camera.select(.firstPerson, animated: false))
        camera.beginObservation()
        camera.pan(.init(70, 0))
        let headTurn = camera.pose
        XCTAssertTrue(camera.selectTarget(shot: selected, preservesVisiblePose: true))
        XCTAssertEqual(camera.pose, headTurn)
        XCTAssertEqual(camera.state.view, .firstPerson)
        camera.pan(.init(0.03, 0))
        XCTAssertEqual(camera.pose.eye, headTurn.eye)
        XCTAssertLessThan(simd_distance(camera.pose.forward, headTurn.forward), 0.001)

        XCTAssertTrue(camera.select(.overview, animated: false))
        let wholeTable = camera.pose
        XCTAssertTrue(camera.selectTarget(shot: original, preservesVisiblePose: true))
        XCTAssertEqual(camera.pose, wholeTable)
        XCTAssertEqual(camera.state.view, .overview)
        XCTAssertEqual(camera.shot, original)
    }

    func testIntermediateTakeoverPreservesVisiblePoseAndFirstDelta() throws {
        for start in [P01CameraMotion.View.firstPerson,.overview] {
        for view in [P01CameraMotion.View.firstPerson,.thirdPerson,.overview] {
            for input in 0..<(view == .firstPerson ? 2 : 3) {
                var c=try XCTUnwrap(P01CameraMotion(shot:shot(x:0.7,z:0.4,yaw:1),layout:layout))
                _=c.select(start,animated:false);c.advance(to:1)
                _=c.select(view);c.advance(to:1.03)
                let visible=c.pose;c.beginObservation()
                XCTAssertEqual(c.pose,visible)
                if input == 2 { c.pinch(1.00001) }
                else { c.pan(input == 0 ? .init(0.01,0) : .init(0,0.01)) }
                c.advance(to:10)
                XCTAssertLessThan(simd_distance(c.pose.eye,visible.eye),0.001)
                XCTAssertLessThan(simd_distance(c.pose.forward,visible.forward),0.001)
                XCTAssertEqual(c.pose.verticalFOV,visible.verticalFOV,accuracy:0.00001)
            }
        }}
    }
    func testAllRailPositionsFullOrbitAndLayoutChanges() throws {
        for x:Float in [-1.2,0,1.2] { for z:Float in [-0.57,0,0.57] {
            var c=try XCTUnwrap(P01CameraMotion(shot:shot(x:x,z:z,yaw:1.3,side:0.02),layout:layout))
            c.pinch(0.5) // Include orbits limited by the nearest room wall.
            let start = c.pose, anchor = try XCTUnwrap(start.project(c.shot.cue, layout: layout))
            let radius = hypot(start.eye.x - x, start.eye.z - z)
            var previous=c.pose
            for _ in 0..<1440 {
                c.pan(.init(2 * .pi/(1440*0.00135),0))
                XCTAssertTrue(layout.legalEye(c.pose.eye))
                XCTAssertLessThan(simd_distance(previous.eye,c.pose.eye),0.03)
                let screen = try XCTUnwrap(c.pose.project(c.shot.cue, layout: layout))
                XCTAssertEqual(hypot(c.pose.eye.x - x, c.pose.eye.z - z), radius, accuracy: 0.00001)
                XCTAssertEqual(screen.x, anchor.x, accuracy: 0.00001)
                XCTAssertEqual(screen.y, anchor.y, accuracy: 0.00001)
                XCTAssertEqual(c.pose.pitch, start.pitch, accuracy: 0.00001)
                XCTAssertEqual(c.pose.eye.y,previous.eye.y)
                XCTAssertEqual(c.pose.verticalFOV,previous.verticalFOV)
                previous=c.pose
            }
            for size in [SIMD2<Float>(667,375),.init(1024,768),.init(768,1024),.init(600,768)] {
                var next=layout;next.viewport=size;next.insets = .init(60,42,60,18)
                c.setLayout(next)
                XCTAssertEqual(c.state.view,.thirdPerson)
                XCTAssertTrue(next.legalEye(c.pose.eye))
                XCTAssertEqual(c.state.height,0.65)
            }
        }}
    }
    func testOrbitReversalAndOldRecordingWithoutAxisVersion() throws {
        var camera = try XCTUnwrap(P01CameraMotion(shot: shot(x: 0.9, z: -0.5, side: 0.02), layout: layout))
        let start = camera.pose
        camera.pan(.init(100, 0))
        XCTAssertEqual(camera.state.observationYaw, 0.135, accuracy: 0.00001)
        camera.pan(.init(-100, 0))
        XCTAssertLessThan(simd_distance(start.eye, camera.pose.eye), 0.00001)
        XCTAssertLessThan(simd_distance(start.forward, camera.pose.forward), 0.00001)
        camera.pan(.init(0, -60))
        XCTAssertEqual(start.eye.y - camera.pose.eye.y, 0.1, accuracy: 0.001)

        // An omitted optional key is the wire format of an original v67 recording.
        var initial = camera.snapshot()
        initial.state.fixedAxisOrbit = nil
        initial.pose = try XCTUnwrap(P01CameraMotion.evaluate(state: initial.state, shot: initial.shot, layout: layout))
        let record = P01CameraMotion.Recording(geometryID: "old-orbit", initial: initial, layout: layout, inputs: [])
        let decoded = try JSONDecoder().decode(P01CameraMotion.Recording.self, from: JSONEncoder().encode(record))
        var replay = try XCTUnwrap(P01CameraMotion(recording: decoded))
        replay.pan(.init(100, 0))
        XCTAssertEqual(replay.state.observationYaw, 0.25, accuracy: 0.00001)
        let eye = replay.pose.eye - replay.shot.strike
        let expected = initial.state.distance * P01CameraMotion.legacyRadius(replay.shot.bearing + 0.25) / P01CameraMotion.legacyRadius(replay.shot.bearing)
        XCTAssertEqual(hypot(eye.x, eye.z), expected, accuracy: 0.00001)
    }

    func testRecordingRoundTripAndFocusDoesNotChangeAim() throws {
        var c=try XCTUnwrap(P01CameraMotion(shot:shot(),layout:layout))
        _=c.select(.overview,animated:true);c.advance(to:0.2)
        let moving=P01CameraMotion.Recording(geometryID:"mid-transition",initial:c.snapshot(),layout:layout,inputs:[])
        var restored=try XCTUnwrap(P01CameraMotion(recording:JSONDecoder().decode(P01CameraMotion.Recording.self,from:JSONEncoder().encode(moving))))
        c.advance(to:0.5);restored.advance(to:0.5);XCTAssertEqual(c.pose,restored.pose)
        _=c.select(.thirdPerson,animated:false)
        XCTAssertFalse(c.hasPendingMotion)
        XCTAssertEqual(c.pose,P01CameraMotion.evaluate(state:c.state,shot:c.shot,layout:c.layout))
        c.advance(to:25)
        let initial=c.snapshot()
        let inputs=[P01CameraMotion.Input(time:25,kind:.view,animated:false,clearanceLift:0.08,view:.firstPerson),
                    .init(time:25.1,kind:.beginObservation),.init(time:25.2,kind:.pan,delta:.init(80,0)),
                    .init(time:25.5,kind:.release),.init(time:28,kind:.view,view:.thirdPerson),
                    .init(time:32,kind:.focus,point:.init(0.6,0.828575,0.3))]
        let record=P01CameraMotion.Recording(geometryID:"unit-test",initial:initial,layout:layout,inputs:inputs)
        let decoded=try JSONDecoder().decode(P01CameraMotion.Recording.self,from:JSONEncoder().encode(record))
        var replay=try XCTUnwrap(P01CameraMotion(recording:decoded))
        for event in inputs { c.apply(event); replay.apply(event) }
        c.advance(to:40);replay.advance(to:40)
        XCTAssertEqual(c.pose,replay.pose);XCTAssertEqual(c.shot,initial.shot)
        XCTAssertEqual(c.state.view,.thirdPerson)
        let target=try XCTUnwrap(c.pose.project(.init(0.6,0.828575,0.3),layout:layout))
        XCTAssertEqual(target.x,0.5,accuracy:0.00001);XCTAssertEqual(target.y,0.5,accuracy:0.00001)
    }

    func testInterruptedFirstPersonHeadReturnKeepsPresentedEye() throws {
        var c=try XCTUnwrap(P01CameraMotion(shot:shot(),layout:layout))
        _=c.select(.overview,animated:false)
        _=c.select(.firstPerson,animated:true);c.advance(to:0.4)
        let visible=c.pose
        c.beginObservation();c.pan(.init(50,0));c.release()
        for frame in 1...240 {
            c.advance(to:0.4+Double(frame)/120)
            XCTAssertEqual(c.pose.eye,visible.eye)
            XCTAssertEqual(c.pose.verticalFOV,visible.verticalFOV)
        }
        XCTAssertLessThan(simd_distance(c.pose.forward,visible.forward),0.00001)
    }

    func testSnapshotResizesFromCurrentViewportAndRetainsDistancePreference() throws {
        var c=try XCTUnwrap(P01CameraMotion(shot:shot(x:1.2,z:0.55,yaw:3.1),layout:layout))
        c.pinch(0.5);let saved=c.snapshot(),distance=c.state.distance
        c.beginObservation();XCTAssertEqual(c.state.distance,distance)
        var portrait=layout;portrait.viewport = .init(768,1024);portrait.insets = .init(80,60,80,40)
        c.setLayout(portrait)
        XCTAssertTrue(c.restore(saved))
        XCTAssertEqual(c.state.distance,distance)
        XCTAssertEqual(try XCTUnwrap(c.pose.project(c.shot.cue,layout:portrait)).y,0.67,accuracy:0.00001)
        XCTAssertNotEqual(c.pose.verticalFOV,saved.pose.verticalFOV)
        XCTAssertTrue(c.select(.firstPerson,animated:false))
        let fp=c.snapshot();c.setLayout(layout);XCTAssertTrue(c.restore(fp))
        XCTAssertEqual(try XCTUnwrap(c.pose.project(c.shot.cue,layout:layout)).y,0.70,accuracy:0.00001)
        c.beginObservation();c.pan(.init(50,0));c.setLayout(portrait)
        let resized=c.pose;c.pan(.init(0.01,0))
        XCTAssertEqual(c.pose.eye,resized.eye);XCTAssertEqual(c.pose.verticalFOV,resized.verticalFOV)
        XCTAssertLessThan(simd_distance(c.pose.forward,resized.forward),0.001)
    }

    func testCompactOverviewFramesHUDWithoutChangingRequestedHeight() throws {
        var compact=layout;compact.viewport = .init(667,375)
        var c=try XCTUnwrap(P01CameraMotion(shot:shot(),layout:compact))
        XCTAssertTrue(c.select(.overview,animated:false))
        XCTAssertEqual(c.state.overviewHeight,1.8)
        XCTAssertEqual(c.state.overviewFramingLift,0)
        XCTAssertEqual(c.pose.eye.y,compact.surfaceY+1.8,accuracy:0.00001)
        for _ in 0..<720 {
            c.pan(.init(2 * .pi/(720*0.00135),0))
            for x in [-compact.tableHalfExtents.x,compact.tableHalfExtents.x] {
                for z in [-compact.tableHalfExtents.y,compact.tableHalfExtents.y] {
                    let p=try XCTUnwrap(c.pose.project(.init(x,compact.surfaceY,z),layout:compact))
                    XCTAssertGreaterThan(p.x,(compact.insets.x+8)/compact.viewport.x)
                    XCTAssertLessThan(p.x,1-(compact.insets.z+8)/compact.viewport.x)
                    XCTAssertGreaterThan(p.y,(compact.insets.y+8)/compact.viewport.y)
                    XCTAssertLessThan(p.y,1-(compact.insets.w+8)/compact.viewport.y)
                }
            }
        }
        c.setLayout(layout);XCTAssertEqual(c.state.overviewHeight,1.8)
        XCTAssertEqual(c.state.overviewFramingLift,0)
        var portrait=layout;portrait.viewport = .init(834,1194)
        c.setLayout(portrait);let saved=c.snapshot()
        XCTAssertTrue(c.restore(saved));XCTAssertEqual(c.pose,saved.pose)
    }
    func testManualAimAfterFocusConnectsFromVisiblePose() throws {
        var c=try XCTUnwrap(P01CameraMotion(shot:shot(),layout:layout))
        let initial=c.pose
        XCTAssertTrue(c.select(.thirdPerson,shot:shot(yaw:1)))
        XCTAssertEqual(c.pose,initial,"Selecting a different shaft must not publish a new pose before the connector")
        c.advance(to:10)
        c.focus(on:.init(0.5,0.828575,0.6));c.advance(to:20)
        let visible=c.pose
        c.updateShot(shot(yaw:0.1),manuallyAimed:true)
        XCTAssertEqual(c.pose,visible);XCTAssertTrue(c.hasPendingMotion)
        c.advance(to:30)
        XCTAssertGreaterThan(simd_dot(simd_normalize(SIMD2(c.pose.forward.x,c.pose.forward.z)),SIMD2(c.shot.aim.x,c.shot.aim.z)),0.99999)
    }

}

@MainActor
final class P01CameraIdleTransitionTests: XCTestCase {
    func testPlayerViewButtonsWakeIdleRendererInBothDirections() async throws {
        let vm = PositionPlayViewModel()
        vm.setAutomaticRecommendation(false)
        vm.setupScene()
        vm.enablePlayerCameraControls(policy: .p01Replayable)
        // Five-ball position captured while the standing and low-view buttons appeared unresponsive.
        let savedBoard = """
        {"board":{"onTable":{
          "cueBall":{"x":0.2922879457473755,"y":0.08993548154830933},
          "_1":{"x":0.3469245731830597,"y":0.48367851972579956},
          "_2":{"x":0.20072606205940247,"y":0.20295055210590363},
          "_4":{"x":0.06728388369083405,"y":0.44482749700546265},
          "_7":{"x":0.30602380633354187,"y":0.3154478371143341}}},
          "input":{"direction":[-0.47090733,0,0.8821827],"mode":"free","pocket":2,
                   "preference":"pocket","selectionSource":"automatic","spinX":0,"spinY":0,
                   "target":"_2","velocity":2},"manual":true}
        """
        let board = try JSONDecoder().decode(PositionPlayViewModel.SavedBoard.self, from: Data(savedBoard.utf8))
        try vm.restoreSavedBoard(board)
        XCTAssertEqual(Set(vm.onTableKeys), ["cueBall", "_1", "_2", "_4", "_7"])
        _ = ShotPlayCamera.setMode(.perspective3D, on: vm)
        XCTAssertEqual(vm.cameraMode, .perspective3D)
        let rig = try XCTUnwrap(vm.scene.cameraRig)
        let camera = try XCTUnwrap(vm.scene.cameraNode)
        XCTAssertTrue(rig.p01AnchoredTransitions)
        XCTAssertEqual(rig.twoViewMode, .thirdPerson)

        let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: windowScene)
        let previousKeyWindow = windowScene.windows.first { $0.isKeyWindow }
        let view = SCNView()
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        let coordinator = AngleSceneView.Coordinator(scene: vm.scene, cameraMode: .perspective3D,
                                                     interactionMode: .cameraControl)
        coordinator.scnView = view
        view.scene = vm.scene
        view.pointOfView = camera
        view.delegate = coordinator.frameDelegate
        window.makeKeyAndVisible()
        coordinator.startRenderLoop()
        defer {
            AngleSceneView.dismantleUIView(view, coordinator: coordinator)
            window.isHidden = true
            previousKeyWindow?.makeKey()
        }

        coordinator.updateContentActivity(false, cameraMode: .perspective3D)
        try await waitFor("initial rendered scene to become idle") {
            coordinator.frameDelegate.completedFrameNumber > 0
                && coordinator.isDisplayLinkPaused && !view.isPlaying && !rig.isTransitioning
        }
        var previousEye = camera.simdWorldPosition
        for selected: CameraRig.PlayerView in [.firstPerson, .thirdPerson] {
            let initialFrame = coordinator.frameDelegate.completedFrameNumber
            let initialCallback = coordinator.displayLinkCallbackCount

            // Use the same request and third-person reset policy as the P01 button.
            XCTAssertTrue(vm.requestPlayerView(selected, resetThirdPerson: selected == .thirdPerson))
            XCTAssertFalse(coordinator.isDisplayLinkPaused, "The view selection must wake the idle clock")
            try await waitFor("\(selected) to render and return to idle") {
                coordinator.displayLinkCallbackCount > initialCallback
                    && coordinator.frameDelegate.completedFrameNumber > initialFrame
                    && coordinator.isDisplayLinkPaused && !view.isPlaying && !rig.isTransitioning
            }
            XCTAssertEqual(rig.twoViewMode, selected)
            XCTAssertTrue(view.pointOfView === camera)
            XCTAssertGreaterThan(simd_distance(camera.simdWorldPosition, previousEye), 0.05)
            previousEye = camera.simdWorldPosition
        }
    }

    private func waitFor(_ condition: String, until predicate: () -> Bool) async throws {
        let deadline = CACurrentMediaTime() + 8
        while !predicate() {
            guard CACurrentMediaTime() < deadline else {
                throw WaitTimeout(condition: condition)
            }
            try await Task.sleep(nanoseconds: 16_000_000)
        }
    }

    private struct WaitTimeout: Error {
        let condition: String
    }
}
