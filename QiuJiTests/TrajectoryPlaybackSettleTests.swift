//
//  TrajectoryPlaybackSettleTests.swift
//  QiuJiTests
//
//  G15（问题集合 v5）：球停止禁尾速截断——回放/渲染一律播到引擎自然静止，
//  不做 0.07 m/s 感知截断。本用例用**手工构造的确定性 recorder**（不依赖具体物理系数）
//  在引擎级验证：
//    1. 回放时长（`action`）= 引擎自然静止时刻（`recorder.duration`），不被感知截断；
//    2. `stateAt` 尾段速度是自然衰减值（0.001..0.07 之间），不被强制置零；
//    3. 若沿用旧「0.07 感知截断」，球会被冻在非终点位置（与真实落点存在可见间隔 =
//       用户观察到的「最后一跳/瞬移」）；播满自然静止后落点已一致，无瞬移。
//
//  说明：`stateAt` 在**恰好落在事件帧时刻**采样时（dt=0，AnalyticalMotion.evolve 为恒等），
//  返回该帧存储的 position/velocity，因此断言完全确定、与物理积分系数无关。
//

import XCTest
import SceneKit
@testable import QiuJi

final class TrajectoryPlaybackSettleTests: XCTestCase {

    private let dt: Float = 1.0 / 60.0

    /// 构造一颗沿 +x 匀减速滚动、最终自然静止的球：
    /// v(t)=v0−a·t，x(t)=v0·t−0.5·a·t²，末尾追加一个 `.stationary` 帧（真实落点）。
    private func makeRollingRecorder(v0: Float = 0.4, decel a: Float = 0.2)
        -> (recorder: TrajectoryRecorder, name: String, stopTime: Float, restX: Float) {
        let name = "cue"
        let rec = TrajectoryRecorder()
        let stopTime = v0 / a                       // 速度归零时刻
        let restX = v0 * stopTime - 0.5 * a * stopTime * stopTime
        var k = 0
        while true {
            let t = Float(k) * dt
            if t >= stopTime { break }
            let v = v0 - a * t
            let x = v0 * t - 0.5 * a * t * t
            rec.recordFrame(ballName: name, frame: BallFrame(
                time: t,
                position: SCNVector3(x, 0, 0),
                velocity: SCNVector3(v, 0, 0),
                angularVelocity: SCNVector4(0, 0, 0, 0),
                state: .rolling))
            k += 1
        }
        // 自然静止帧（引擎 0.001 m/s 判定的语义终点，保留不动）。
        rec.recordFrame(ballName: name, frame: BallFrame(
            time: stopTime,
            position: SCNVector3(restX, 0, 0),
            velocity: SCNVector3(0, 0, 0),
            angularVelocity: SCNVector4(0, 0, 0, 0),
            state: .stationary))
        return (rec, name, stopTime, restX)
    }

    /// 复刻已删除的旧「感知静止」算法（0.07 m/s 阈值），仅用于在测试内演示旧截断会造成的间隔。
    private func legacyPerceptibleCut(_ pb: TrajectoryPlayback, name: String,
                                      threshold: Float = 0.07) -> Float {
        let duration = pb.duration
        guard duration > dt else { return duration }
        var t = duration
        while t > 0 {
            if let s = pb.stateAt(ballName: name, time: t), s.motionState != .pocketed,
               s.velocity.length() > threshold {
                return min(duration, t + dt)
            }
            t -= dt
        }
        return min(duration, dt)
    }

    func testPlaybackRunsToNaturalSettleNoTailTruncation() {
        let (rec, name, stopTime, restX) = makeRollingRecorder()
        let pb = TrajectoryPlayback(recorder: rec, surfaceY: 0)

        // 1) 播放时长 = 引擎自然静止时刻。
        XCTAssertEqual(pb.duration, stopTime, accuracy: 1e-4,
                       "回放总时长应等于引擎自然静止时刻（recorder.duration）")

        // 末帧（自然静止）落点 = 真实落点。
        let restState = pb.stateAt(ballName: name, time: pb.duration)!
        XCTAssertEqual(restState.position.x, restX, accuracy: 1e-3)
        XCTAssertLessThan(restState.velocity.length(), 1e-4,
                          "自然静止帧速度为 0（物理语义保留）")

        // 2) 尾段（自然静止之前的 creep）速度是自然衰减值，未被强制置零。
        //    取 v≈0.033 m/s 处（落在旧 0.07 截断之后、静止之前）。
        let tailT: Float = (0.4 - 0.033) / 0.2   // 由 v(t)=v0−a·t 反解
        let tail = pb.stateAt(ballName: name, time: tailT)!
        let tailSpeed = tail.velocity.length()
        XCTAssertGreaterThan(tailSpeed, 0.001, "尾段速度不应被强制置零")
        XCTAssertLessThan(tailSpeed, 0.07, "尾段确处于旧截断阈值以下（属被旧逻辑丢弃的 creep 段）")

        // 3) 旧「0.07 感知截断」会把球冻在非终点位置：与真实落点存在可见间隔（= 最后一跳/瞬移）。
        let cut = legacyPerceptibleCut(pb, name: name)
        let cutState = pb.stateAt(ballName: name, time: cut)!
        let jumpGap = restX - cutState.position.x
        XCTAssertGreaterThan(jumpGap, 0.005,
                             "旧截断点与真实落点间隔 > 5mm，正是被 G15 消除的瞬移")
        let extraWait = pb.duration - cut
        print(String(format: "G15-DIAG 自然静止=%.3fs 旧感知截断=%.3fs 额外播放=%.3fs 瞬移间隔=%.1fmm",
                     pb.duration, cut, extraWait, jumpGap * 1000))

        // 4) 消费方口径：action(maxSimTime: nil/duration) 播满自然静止；旧截断会更短。
        let node = SCNNode()
        let fullAction = pb.action(for: node, ballName: name, speed: 1.0, removeOnPocket: false)
        XCTAssertNotNil(fullAction)
        XCTAssertEqual(fullAction!.duration, TimeInterval(pb.duration), accuracy: 1e-3,
                       "默认（G15：settle=duration）回放播满自然静止")
        let truncated = pb.action(for: node, ballName: name, speed: 1.0,
                                  removeOnPocket: false, maxSimTime: cut)
        XCTAssertLessThan(truncated!.duration, fullAction!.duration,
                          "旧 0.07 截断的回放更短（对照，证明 G15 确实延长到自然静止）")
    }
}


final class SpatialMotionContractV63Tests: XCTestCase {
    func testCapturePreservesEntryStateAndAbsoluteTime() throws {
        for centerX: Float in [0.3, 1.31] {
            let pocket = Pocket(id: "measured-pocket", center: SCNVector3(centerX, 0.8, 0), radius: 0.05, isCorner: false)
            let geometry = TableGeometry(linearCushions: [], circularCushions: [], pockets: [pocket])
            let initial = BallState(position: SCNVector3(centerX - 0.2, 0.8 + BallPhysics.radius, 0),
                                    velocity: SCNVector3(1,0,0), angularVelocity: SCNVector3(0,0,-1/BallPhysics.radius),
                                    state: .rolling, name: "probe")
            let rollout = AnalyticShotRollout.rollout(from: initial, startTime: 5, geometry: geometry, staticBalls: [], maxTime: 7)
            let rolloutEntry = try XCTUnwrap(rollout.pocketEntry)
            XCTAssertEqual(rolloutEntry.source, .analyticRollout)
            XCTAssertGreaterThan(rolloutEntry.time, 5)
            XCTAssertFalse(rolloutEntry.ball.isPocketed)
            XCTAssertGreaterThan(rolloutEntry.ball.velocity.x, 0.5)
            let engine = EventDrivenEngine(tableGeometry: geometry)
            engine.setBall(initial); engine.simulate(maxEvents: 100, maxTime: 2)
            let entries = engine.getTrajectoryRecorder().pocketEntries
            XCTAssertEqual(entries.count, 1)
            let entry = try XCTUnwrap(entries.first)
            XCTAssertEqual(entry.pocketID, pocket.id)
            XCTAssertFalse(entry.ball.isPocketed)
            XCTAssertGreaterThan(entry.time, 0)
            XCTAssertEqual(rolloutEntry.time - 5, entry.time, accuracy: 1e-5)
            let expected = AnalyticalMotion.evolveRolling(position: initial.position, velocity: initial.velocity,
                                                          angularVelocity: initial.angularVelocity, dt: entry.time)
            XCTAssertEqual(entry.ball.position.x, expected.position.x, accuracy: 1e-5)
            XCTAssertEqual(entry.ball.velocity.x, expected.velocity.x, accuracy: 1e-5)
            XCTAssertEqual(entry.ball.angularVelocity.z, expected.angularVelocity.z, accuracy: 1e-4)
            XCTAssertEqual(entry.ball.position.y, initial.position.y)
            XCTAssertGreaterThan(abs(entry.ball.position.x - pocket.center.x), 0.04)
            XCTAssertGreaterThan(entry.ball.velocity.x, 0.5)
            XCTAssertEqual(entry.geometry.pockets.first?.radius, pocket.radius)
            XCTAssertEqual(entry.source, .event)
            XCTAssertTrue(try XCTUnwrap(engine.getBall("probe")).isPocketed)
            let times = zip(engine.resolvedEvents, engine.resolvedEventTimes).compactMap { event, time -> Float? in
                if case .pocket = event { return time }; return nil
            }
            XCTAssertEqual(times, [entry.time])
        }
    }

    func testAlreadyInsidePocketFallbackUsesAdvancedStateTime() throws {
        let pocket = Pocket(id: "fallback", center: SCNVector3(1.31,0.8,0), radius: 0.05, isCorner: false)
        let geometry = TableGeometry(linearCushions: [], circularCushions: [], pockets: [pocket])
        let initial = BallState(position: SCNVector3(1.31,0.8+BallPhysics.radius,0), velocity: SCNVector3(0.1,0,0),
                                angularVelocity: SCNVector3(0,0,-0.1/BallPhysics.radius), state: .rolling, name: "probe")
        let engine = EventDrivenEngine(tableGeometry: geometry); engine.setBall(initial)
        engine.simulate(maxEvents: 10, maxTime: 0.01)
        let recorder = engine.getTrajectoryRecorder()
        XCTAssertEqual(recorder.pocketEntries.count, 1)
        let entry = try XCTUnwrap(recorder.pocketEntries.first)
        XCTAssertEqual(entry.source, .boundsFallback)
        XCTAssertEqual(entry.time, 0.01, accuracy: 1e-7)
        let expected = AnalyticalMotion.evolveRolling(position: initial.position, velocity: initial.velocity,
                                                      angularVelocity: initial.angularVelocity, dt: entry.time)
        XCTAssertEqual(entry.ball.position.x, expected.position.x)
        XCTAssertEqual(entry.ball.velocity.x, expected.velocity.x)
        XCTAssertEqual(entry.ball.angularVelocity.z, expected.angularVelocity.z)
        XCTAssertEqual(engine.resolvedEventTimes, [entry.time])
        XCTAssertEqual(recorder.duration, entry.time)
        XCTAssertEqual(recorder.framesByBallName["probe"]?.last?.time, entry.time)
    }

    func testFreeFlightQueriesAreAbsoluteRepeatableAndEnergyConsistent() throws {
        let start = SpatialMotionSegment.Sample(position: SCNVector3(0,1,0), velocity: SCNVector3(2,3,-1),
                                                angularVelocity: SCNVector3(4,5,6))
        let segment = try SpatialMotionSegment(ballName: "cue", phase: .airborne, startTime: 7, duration: 0.5, start: start)
        let energy: Float = 0.5 * 14 + TablePhysics.gravity
        for t: Float in [7.5,7,7.25,7.125,7.25] {
            let sample = try XCTUnwrap(segment.sample(at: t))
            let dt = t - 7
            XCTAssertEqual(sample.position.x, 2*dt, accuracy: 1e-6)
            XCTAssertEqual(sample.position.y, 1 + 3*dt - 0.5*TablePhysics.gravity*dt*dt, accuracy: 1e-6)
            XCTAssertEqual(sample.velocity.y, 3 - TablePhysics.gravity*dt, accuracy: 1e-6)
            XCTAssertEqual(sample.angularVelocity.y, 5)
            let v = sample.velocity
            XCTAssertEqual(0.5*(v.x*v.x+v.y*v.y+v.z*v.z)+TablePhysics.gravity*sample.position.y, energy, accuracy: 1e-4)
        }
        XCTAssertNil(segment.sample(at: 6.99)); XCTAssertNil(segment.sample(at: 7.51))
        XCTAssertNil(segment.sample(at: .nan))
        XCTAssertThrowsError(try SpatialMotionSegment(ballName: "cue", phase: .pocket, startTime: 0, duration: 0, start: start))
    }

    func testLegacyFrameOnlyRecordRemainsUsable() throws {
        let recorder = TrajectoryRecorder()
        recorder.recordFrame(ballName: "cue", frame: BallFrame(time: 0, position: SCNVector3(0,0.83,0),
                            velocity: SCNVector3Zero, angularVelocity: SCNVector4Zero, state: .stationary))
        XCTAssertTrue(recorder.pocketEntries.isEmpty)
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: 0.83)
        XCTAssertEqual(try XCTUnwrap(playback.stateAt(ballName: "cue", time: 0)).position.y, 0.83)
    }
}

final class PocketContinuousContactV63Tests: XCTestCase {
    func testNearbyFiniteEdgeDoesNotCollideAtInfinitePlaneTime() throws {
        let triangle=PocketContactTriangle(a:SIMD3(0,0,-1),b:SIMD3(1,0,-1),c:SIMD3(0,0,1))
        let r=0.028575,offset=0.00005
        let p=SIMD3(-offset,r+0.01,0),v=SIMD3<Double>(0,-1,0)
        let expected=r+0.01-sqrt(r*r-offset*offset)
        XCTAssertNil(triangle.firstContact(position:p,velocity:v,acceleration:.zero,radius:r,horizon:0.01000001))
        let hit=try XCTUnwrap(triangle.firstContact(position:p,velocity:v,acceleration:.zero,radius:r,horizon:0.02))
        XCTAssertEqual(hit.time,expected,accuracy:1e-12)
    }
    typealias V = SIMD3<Double>
    let triangle = PocketContactTriangle(a: V(0,0,0), b: V(1,0,0), c: V(0,0,1))

    func testFaceEdgeAndVertexContactsAtHighSpeed() throws {
        for (p, expected) in [(V(0.2,1,0.2),0.009), (V(-0.06,1,0.2),0.0092),
                              (V(-0.06,1,-0.06),(1-sqrt(0.01-0.0072))/100)] {
            let hit = try XCTUnwrap(triangle.firstContact(position: p, velocity: V(0,-100,0),
                                                         acceleration: .zero, radius: 0.1, horizon: 0.02))
            XCTAssertEqual(hit.time, expected, accuracy: 1e-9)
            let center = p+V(0,-100,0)*hit.time
            let delta = center-hit.point
            XCTAssertEqual(sqrt(delta.x*delta.x+delta.y*delta.y+delta.z*delta.z), 0.1, accuracy: 1e-8)
        }
    }

    func testFreeFallTimeAndFiniteSurfaceMiss() throws {
        let hit = try XCTUnwrap(triangle.firstContact(position: V(0.2,1,0.2), velocity: .zero,
                                                     acceleration: V(0,-9.81,0), radius: 0.1, horizon: 1))
        XCTAssertEqual(hit.time, sqrt(1.8/9.81), accuracy: 1e-9)
        XCTAssertNil(triangle.firstContact(position: V(2,1,2), velocity: V(0,-10,0),
                                           acceleration: .zero, radius: 0.1, horizon: 1))
        XCTAssertNil(triangle.firstContact(position: V(0.2,0.1,0.2), velocity: V(0,1,0),
                                           acceleration: .zero, radius: 0.1, horizon: 1))
    }

    func testWindingAndSubintervalDoNotChangeContact() throws {
        let reverse = PocketContactTriangle(a: triangle.c,b: triangle.b,c: triangle.a)
        let p = V(-0.06,1,0.2), v = V(0,-3,0), g = V(0,-9.81,0)
        let whole = try XCTUnwrap(triangle.firstContact(position: p,velocity: v,acceleration: g,radius: 0.1,horizon: 1))
        let reversed = try XCTUnwrap(reverse.firstContact(position: p,velocity: v,acceleration: g,radius: 0.1,horizon: 1))
        XCTAssertEqual(whole.time,reversed.time,accuracy: 1e-10)
        let dt = whole.time*0.4
        let later = try XCTUnwrap(triangle.firstContact(position: p+v*dt+g*(0.5*dt*dt),velocity: v+g*dt,
                                                       acceleration: g,radius: 0.1,horizon: 1-dt))
        XCTAssertEqual(dt+later.time,whole.time,accuracy: 1e-9)
    }
}

final class PocketContactResponseV63Tests: XCTestCase {
    typealias V = SIMD3<Double>
    func energy(_ m: PocketContactResponse.Motion, radius: Double) -> Double {
        let v=m.velocity,w=m.angularVelocity
        return 0.5*(v.x*v.x+v.y*v.y+v.z*v.z)+0.2*radius*radius*(w.x*w.x+w.y*w.y+w.z*w.z)
    }
    func testImpactDissipatesEnergyAcrossSpinAndIncidence() {
        let r=0.028575
        for x in [-3.0,0,3] { for y in [-0.1,-1.0,-6.0] { for spin in [-200.0,0,200] {
            for e in [0.0,0.5,1.0] { for mu in [0.0,0.2,0.8] {
                let before=PocketContactResponse.Motion(velocity: V(x,y,1),angularVelocity: V(spin,20,-spin))
                let after=PocketContactResponse.impact(before,normal: V(0,1,0),radius: r,restitution: e,friction: mu)
                XCTAssertEqual(after.velocity.y,-e*y,accuracy: 1e-10)
                XCTAssertLessThanOrEqual(energy(after,radius:r),energy(before,radius:r)+1e-10)
            }}
        }}}
    }
    func testTangentialImpulseIncludesSpinAndCoulombLimit() {
        let r=0.1
        let initial=PocketContactResponse.Motion(velocity: V(1,-1,0),angularVelocity: .zero)
        let stick=PocketContactResponse.impact(initial,normal: V(0,1,0),radius:r,restitution:0,friction:1)
        XCTAssertEqual(stick.velocity.x,5.0/7,accuracy:1e-10)
        XCTAssertEqual(stick.angularVelocity.z,-50.0/7,accuracy:1e-10)
        let slide=PocketContactResponse.impact(initial,normal: V(0,1,0),radius:r,restitution:0,friction:0.1)
        XCTAssertEqual(slide.velocity.x,0.9,accuracy:1e-10)
        XCTAssertEqual(slide.angularVelocity.z,-2.5,accuracy:1e-10)
        let separating=PocketContactResponse.Motion(velocity: V(1,1,0),angularVelocity: V(2,3,4))
        let unchanged=PocketContactResponse.impact(separating,normal: V(0,1,0),radius:r,restitution:1,friction:1)
        XCTAssertEqual(unchanged.velocity,separating.velocity)
        XCTAssertEqual(unchanged.angularVelocity,separating.angularVelocity)
    }
    func testPlanarSupportCancelsGravityAndAllowsRollingDownSlope() {
        let rest=PocketContactResponse.Motion(velocity:.zero,angularVelocity:.zero)
        let flat=PocketContactResponse.planarSupport(rest,gravity:V(0,-9.81,0),normal:V(0,1,0),radius:0.1,friction:0.3)
        XCTAssertEqual(flat.linear,.zero);XCTAssertEqual(flat.angular,.zero)
        let n=V(0,cos(Double.pi/6),sin(Double.pi/6))
        let slope=PocketContactResponse.planarSupport(rest,gravity:V(0,-9.81,0),normal:n,radius:0.1,friction:0.3)
        let tangent=V(0,-sin(Double.pi/6),cos(Double.pi/6))
        let along=slope.linear.y*tangent.y+slope.linear.z*tangent.z
        XCTAssertEqual(along,5.0/7*9.81*0.5,accuracy:1e-10)
        XCTAssertEqual(slope.linear.y*n.y+slope.linear.z*n.z,0,accuracy:1e-10)
        let unsupported=PocketContactResponse.planarSupport(rest,gravity:V(0,-9.81,0),normal:V(0,-1,0),radius:0.1,friction:0.3)
        XCTAssertEqual(unsupported.linear,V(0,-9.81,0))
    }
}

final class LocalPocketSimulationV63Tests:XCTestCase {
    func testFloorReactionCanActivateAnOverhangingContact() throws {
        typealias V=SIMD3<Double>
        let radius=0.1,n=V(-1/sqrt(2),-1/sqrt(2),0),center=V(0,0.1,0)
        let anchor=center-n*radius,tangent=V(1/sqrt(2),-1/sqrt(2),0)
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let lip=PocketContactTriangle(a:anchor-tangent-V(0,0,1),b:anchor+tangent-V(0,0,1),c:anchor+V(0,0,1))
        // External force (1,-10,0) points away from the lip. Nevertheless the
        // floor's reaction loads it: lip force=(-1,-1,0), floor force=(0,11,0).
        let solver=LocalPocketSimulation(surfaces:[floor,lip].map{.init(triangle:$0,restitution:0.3,friction:0)},
            radius:radius,gravity:V(1,-10,0),tolerance:1e-6)
        let result=try solver.run(from:.init(time:0,position:center,velocity:.zero,omega:.zero),duration:0.001,maxStep:0.001)
        let end=try XCTUnwrap(result.states.last)
        XCTAssertEqual(end.position.x,center.x,accuracy:1e-11)
        XCTAssertEqual(end.position.y,center.y,accuracy:1e-11)
        XCTAssertEqual(end.velocity.x,0,accuracy:1e-11)
        XCTAssertEqual(end.velocity.y,0,accuracy:1e-11)
    }
    typealias V=SIMD3<Double>
    func testSimultaneousImpactPreservesSymmetryAndEnergy() throws {
        let x=0.09801390473091492,z=0.9951850453455373,r=0.028575
        let initial=PocketContactResponse.Motion(velocity:V(0,-0.2,-2),angularVelocity:V(-2/r,0,0))
        func energy(_ m:PocketContactResponse.Motion)->Double {
            let v=m.velocity,w=m.angularVelocity
            return (v.x*v.x+v.y*v.y+v.z*v.z)/2+0.2*r*r*(w.x*w.x+w.y*w.y+w.z*w.z)
        }
        for e in [0.0,0.3,1.0] {
            for friction in [0.0,0.2,0.8] {
                let constraints=[PocketContactResponse.ImpactConstraint(normal:V(-x,0,z),restitution:e,friction:friction),
                                 .init(normal:V(x,0,z),restitution:e,friction:friction)]
                let a=try PocketContactResponse.simultaneousImpact(initial,constraints:constraints,radius:r)
                let b=try PocketContactResponse.simultaneousImpact(initial,constraints:Array(constraints.reversed()),radius:r)
                XCTAssertEqual(a.velocity.x,0,accuracy:1e-10)
                XCTAssertEqual(a.velocity.x,b.velocity.x,accuracy:1e-10)
                XCTAssertEqual(a.velocity.y,b.velocity.y,accuracy:1e-10)
                XCTAssertEqual(a.velocity.z,b.velocity.z,accuracy:1e-10)
                XCTAssertEqual(a.angularVelocity.y,0,accuracy:1e-10)
                XCTAssertEqual(a.angularVelocity.z,0,accuracy:1e-10)
                XCTAssertLessThanOrEqual(energy(a),energy(initial)+1e-10)
            }
        }
    }
    func testTwoFaceSupportBalancesGravityRegardlessOfFaceOrder() throws {
        let faces = [
            PocketContactTriangle(a: V(0,0,-1), b: V(1,1,-1), c: V(1,1,1)),
            PocketContactTriangle(a: V(0,0,-1), b: V(1,1,1), c: V(0,0,1)),
            PocketContactTriangle(a: V(0,0,-1), b: V(-1,1,-1), c: V(-1,1,1)),
            PocketContactTriangle(a: V(0,0,-1), b: V(-1,1,1), c: V(0,0,1))
        ]
        let initial = LocalPocketSimulation.State(time: 0, position: V(0,0.03*sqrt(2),0), velocity: .zero, omega: .zero)
        for ordered in [faces, Array(faces.reversed())] {
            let solver = LocalPocketSimulation(surfaces: ordered.map { .init(triangle: $0,restitution: 0.3,friction: 0) },
                                               radius: 0.03,gravity: V(0,-9.81,0),tolerance: 1e-6)
            let result = try solver.run(from: initial,duration: 0.1,maxStep: 0.001)
            let last = try XCTUnwrap(result.states.last)
            XCTAssertEqual(last.position.x, initial.position.x, accuracy: 1e-10)
            XCTAssertEqual(last.position.y, initial.position.y, accuracy: 1e-10)
            XCTAssertEqual(last.velocity.y, 0, accuracy: 1e-10)
            XCTAssertTrue(result.contacts.isEmpty)
        }
    }
    func simulator()->LocalPocketSimulation {
        let triangles=[PocketContactTriangle(a:V(-1,0,-1),b:V(0,0,-1),c:V(0,0,1)),
                       PocketContactTriangle(a:V(-1,0,-1),b:V(0,0,1),c:V(-1,0,1))]
        return LocalPocketSimulation(surfaces:triangles.map { .init(triangle:$0,restitution:0.3,friction:0.2) },
                                     radius:0.03,gravity:V(0,-9.81,0),tolerance:1e-6)
    }
    func testFiniteSupportReleasesAndFallsWithStepConvergence() throws {
        let solver=simulator()
        let initial=LocalPocketSimulation.State(time:3,position:V(-0.1,0.03,0),velocity:V(0.5,0,0),omega:V(0,0,-0.5/0.03))
        var finals:[LocalPocketSimulation.State]=[]
        for dt in [0.001,0.0005,0.00025] {
            let result=try solver.run(from:initial,duration:0.5,maxStep:dt)
            let final=try XCTUnwrap(result.states.last);finals.append(final)
            XCTAssertLessThan(final.position.y,-0.2)
            XCTAssertGreaterThan(final.position.x,0.1)
            XCTAssertEqual(final.time,3.5,accuracy:1e-10)
            XCTAssertLessThanOrEqual(result.maxCorrection,4e-6)
            let startEnergy=0.5*0.25+0.2*0.0009*pow(0.5/0.03,2)+9.81*0.03
            for state in result.states {
                let v=state.velocity,w=state.omega
                let energy=0.5*(v.x*v.x+v.y*v.y+v.z*v.z)+0.2*0.0009*(w.x*w.x+w.y*w.y+w.z*w.z)+9.81*state.position.y
                XCTAssertLessThanOrEqual(energy,startEnergy+1e-3)
            }
        }
        XCTAssertLessThan(abs(finals[1].position.y-finals[2].position.y),0.002)
    }
    func testRestingSphereDoesNotBounceOrSink() throws {
        let result=try simulator().run(from:.init(time:0,position:V(-0.2,0.03,0),velocity:.zero,omega:.zero),
                                       duration:1,maxStep:0.001)
        let last=try XCTUnwrap(result.states.last)
        XCTAssertEqual(last.position,V(-0.2,0.03,0))
        XCTAssertEqual(last.velocity,.zero);XCTAssertTrue(result.contacts.isEmpty)
    }
    func testFastEdgeReleaseUsesExactBoundaryTime() throws {
        // x=-0.1 at 2m/s reaches the finite edge at exactly 0.05s.
        // v²/R exceeds gravity there, so positive support is impossible.
        let initial=LocalPocketSimulation.State(time:3,position:V(-0.1,0.03,0),
                                                velocity:V(2,0,0),omega:V(0,0,-2/0.03))
        for step in [0.013,0.0049,0.0007] {
            let result=try simulator().run(from:initial,duration:0.1,maxStep:step)
            let final=try XCTUnwrap(result.states.last)
            XCTAssertEqual(final.position.x,0.1,accuracy:1e-10)
            XCTAssertEqual(final.position.y,0.03-0.5*9.81*0.05*0.05,accuracy:1e-10)
            XCTAssertEqual(final.velocity.y,-9.81*0.05,accuracy:1e-10)
        }
    }
}

final class SpatialBallContactV63Tests:XCTestCase {
    typealias V=SIMD3<Double>
    typealias M=PocketContactResponse.Motion
    private func dot(_ a:V,_ b:V)->Double { a.x*b.x+a.y*b.y+a.z*b.z }
    private func cross(_ a:V,_ b:V)->V { V(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) }
    private func norm(_ v:V)->Double { sqrt(dot(v,v)) }
    private func assertVector(_ a:V,_ b:V,file:StaticString=#filePath,line:UInt=#line) {
        XCTAssertLessThanOrEqual(norm(a-b),1e-11,file:file,line:line)
    }
    func testRelativeGravityContactAndHeightSeparatedMiss() throws {
        let r=0.028575
        let hit=try XCTUnwrap(SpatialBallContact.firstContact(position:V(0,-1,0),velocity:.zero,
            acceleration:V(0,9.81,0),radiusSum:2*r,horizon:1))
        XCTAssertEqual(hit.time,sqrt(2*(1-2*r)/9.81),accuracy:1e-12)
        assertVector(hit.normal,V(0,-1,0))
        XCTAssertNil(try SpatialBallContact.firstContact(position:V(1,2.1*r,0),velocity:V(-100,0,0),
            acceleration:.zero,radiusSum:2*r,horizon:0.1))
        let fast=try XCTUnwrap(SpatialBallContact.firstContact(position:V(1,0,0),velocity:V(-100,0,0),
            acceleration:.zero,radiusSum:2*r,horizon:0.1))
        XCTAssertEqual(fast.time,(1-2*r)/100,accuracy:1e-12)
        XCTAssertNil(try SpatialBallContact.firstContact(position:V(2*r,0,0),velocity:V(1,0,0),
            acceleration:.zero,radiusSum:2*r,horizon:1))
        XCTAssertEqual(try SpatialBallContact.firstContact(position:V(2*r,0,0),velocity:V(-1,0,0),
            acceleration:.zero,radiusSum:2*r,horizon:0)?.time,0)
    }
    func testVerticalElasticExchangeAndSeparatingContact() throws {
        let a=M(velocity:V(0,-2,0),angularVelocity:.zero),b=M(velocity:.zero,angularVelocity:.zero)
        let response=try SpatialBallContact.resolve(a:a,b:b,normal:V(0,-1,0),radius:0.028575,restitution:1,friction:0)
        assertVector(response.a.velocity,.zero);assertVector(response.b.velocity,a.velocity)
        let away=try SpatialBallContact.resolve(a:b,b:a,normal:V(0,-1,0),radius:0.028575,restitution:1,friction:0.2)
        assertVector(away.impulseOnA,.zero)
    }
    func testMomentumAngularMomentumEnergyAndFrictionCone() throws {
        let r=0.028575,inertia=0.4*r*r
        for axis in [V(1,0,0),V(0,-1,0),V(1,2,3)] {
            let n=axis/norm(axis)
            for e in [0.0,0.5,1.0] { for mu in [0.0,0.05,0.5] {
                let a=M(velocity:n*2+V(0.2,0.3,-0.1),angularVelocity:V(3,-8,5))
                let b=M(velocity:-n+V(-0.1,0.2,0.1),angularVelocity:V(-4,2,7))
                let result=try SpatialBallContact.resolve(a:a,b:b,normal:n,radius:r,restitution:e,friction:mu)
                assertVector(a.velocity+b.velocity,result.a.velocity+result.b.velocity)
                let angularBefore=cross(-n*r,a.velocity)+cross(n*r,b.velocity)+(a.angularVelocity+b.angularVelocity)*inertia
                let angularAfter=cross(-n*r,result.a.velocity)+cross(n*r,result.b.velocity)+(result.a.angularVelocity+result.b.angularVelocity)*inertia
                assertVector(angularBefore,angularAfter)
                func energy(_ x:M)->Double { 0.5*dot(x.velocity,x.velocity)+0.5*inertia*dot(x.angularVelocity,x.angularVelocity) }
                XCTAssertLessThanOrEqual(energy(result.a)+energy(result.b),energy(a)+energy(b)+1e-12)
                let j=result.impulseOnA,jn = -dot(j,n),jt=j+n*jn
                XCTAssertLessThanOrEqual(norm(jt),mu*jn+1e-12)
                XCTAssertEqual(dot(result.b.velocity-result.a.velocity,n),e*dot(a.velocity-b.velocity,n),accuracy:1e-12)
                let boost=V(8,-3,7)
                let shifted=try SpatialBallContact.resolve(a:M(velocity:a.velocity+boost,angularVelocity:a.angularVelocity),
                    b:M(velocity:b.velocity+boost,angularVelocity:b.angularVelocity),normal:n,radius:r,restitution:e,friction:mu)
                assertVector(shifted.impulseOnA,j)
            } }
        }
    }
}

extension SpatialBallContactV63Tests {
    func testFallingBallAndSupportedBallResolveTogether() throws {
        let initial=[M(velocity:V(0,-2,0),angularVelocity:.zero),M(velocity:.zero,angularVelocity:.zero)]
        for e in [0.0,0.5,1.0] {
            let constraints=[SpatialBallContact.Constraint(a:0,b:1,normal:V(0,1,0),restitution:e,friction:0),
                             .init(a:1,b:nil,normal:V(0,1,0),restitution:0,friction:0)]
            let result=try SpatialBallContact.resolveCoupled(initial,constraints:constraints,radius:0.028575)
            XCTAssertEqual(result[0].velocity.y,2*e,accuracy:1e-9)
            XCTAssertEqual(result[1].velocity.y,0,accuracy:1e-9)
            let reversed=try SpatialBallContact.resolveCoupled(initial,constraints:constraints.reversed(),radius:0.028575)
            for i in initial.indices { assertVector(result[i].velocity,reversed[i].velocity) }
        }
    }
    func testCoupledPairMatchesFreePairAndThreeBallSymmetry() throws {
        let r=0.028575,n=V(1,0,0)
        let a=M(velocity:V(2,0.5,0),angularVelocity:V(1,2,3)),b=M(velocity:V(-1,0,0.3),angularVelocity:V(4,2,1))
        let direct=try SpatialBallContact.resolve(a:a,b:b,normal:n,radius:r,restitution:0.8,friction:0.1)
        let coupled=try SpatialBallContact.resolveCoupled([a,b],constraints:[.init(a:0,b:1,normal:-n,restitution:0.8,friction:0.1)],radius:r)
        assertVector(direct.a.velocity,coupled[0].velocity);assertVector(direct.b.velocity,coupled[1].velocity)
        assertVector(direct.a.angularVelocity,coupled[0].angularVelocity)
        assertVector(direct.b.angularVelocity,coupled[1].angularVelocity)
        let three=[M(velocity:V(2,0,0),angularVelocity:.zero),M(velocity:.zero,angularVelocity:.zero),M(velocity:V(-2,0,0),angularVelocity:.zero)]
        let constraints=[SpatialBallContact.Constraint(a:0,b:1,normal:-n,restitution:1,friction:0),
                         .init(a:1,b:2,normal:-n,restitution:1,friction:0)]
        let result=try SpatialBallContact.resolveCoupled(three,constraints:constraints,radius:r)
        XCTAssertEqual(result[0].velocity.x,-2,accuracy:1e-9)
        XCTAssertEqual(result[1].velocity.x,0,accuracy:1e-9)
        XCTAssertEqual(result[2].velocity.x,2,accuracy:1e-9)
    }
}

extension SpatialBallContactV63Tests {
    func testSeparatingSupportIsDeferredAndDoesNotCreateEnergy() throws {
        let initial=[M(velocity:V(0,-1,0),angularVelocity:.zero),M(velocity:V(0,2,0),angularVelocity:.zero)]
        let pair=SpatialBallContact.Constraint(a:0,b:1,normal:V(0,1,0),restitution:1,friction:0)
        let floor=SpatialBallContact.Constraint(a:1,b:nil,normal:V(0,1,0),restitution:0,friction:0)
        let first=try SpatialBallContact.resolveCoupled(initial,constraints:[pair,floor],radius:0.028575)
        let before=initial.reduce(0) { $0+0.5*dot($1.velocity,$1.velocity) }
        let after=first.reduce(0) { $0+0.5*dot($1.velocity,$1.velocity) }
        XCTAssertLessThanOrEqual(after,before+1e-10)
        XCTAssertEqual(first[0].velocity.y,2,accuracy:1e-9)
        XCTAssertEqual(first[1].velocity.y,-1,accuracy:1e-9)
        // The newly approaching floor contact is a same-time event to reschedule.
        let second=try SpatialBallContact.resolveCoupled(first,constraints:[pair,floor],radius:0.028575)
        XCTAssertEqual(second[0].velocity.y,2,accuracy:1e-9)
        XCTAssertEqual(second[1].velocity.y,0,accuracy:1e-9)
        XCTAssertLessThanOrEqual(second.reduce(0) { $0+0.5*dot($1.velocity,$1.velocity) },after+1e-10)
    }
}

extension SpatialBallContactV63Tests {
    func testInstantResponseRebuildsContactsWithoutAdvancingTime() throws {
        let initial=[M(velocity:V(0,-1,0),angularVelocity:.zero),M(velocity:V(0,2,0),angularVelocity:.zero)]
        let pair=SpatialBallContact.Constraint(a:0,b:1,normal:V(0,1,0),restitution:1,friction:0)
        let floor=SpatialBallContact.Constraint(a:1,b:nil,normal:V(0,1,0),restitution:0,friction:0)
        let result=try SpatialBallContact.resolveInstant(initial,constraints:[pair,floor],radius:0.028575)
        XCTAssertEqual(result.rounds.count,2)
        assertVector(result.motions[0].velocity,V(0,2,0))
        assertVector(result.motions[1].velocity,.zero)
        var energy=2.5
        for round in result.rounds {
            let next=round.reduce(0) { $0+0.5*dot($1.velocity,$1.velocity) }
            XCTAssertLessThanOrEqual(next,energy+1e-10)
            energy=next
        }
        let reversed=try SpatialBallContact.resolveInstant(initial,constraints:[floor,pair],radius:0.028575)
        XCTAssertEqual(reversed.rounds.count,result.rounds.count)
        for i in initial.indices { assertVector(reversed.motions[i].velocity,result.motions[i].velocity) }
        // Insufficient budget must report a remaining contact, never return the
        // first response with a ball still moving into its supporting surface.
        XCTAssertThrowsError(try SpatialBallContact.resolveInstant(initial,constraints:[pair,floor],radius:0.028575,maxRounds:1)) { error in
            guard case SpatialBallContact.CoupledFailure.convergence(let residual)=error else {
                return XCTFail("Unexpected failure: \(error)")
            }
            XCTAssertGreaterThan(residual,0.9)
        }
    }
}

final class LocalPocketIntervalV63Tests:XCTestCase {
    func testIntervalsRetainIncomingImpactAndOutgoingState() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0.5,friction:0)],
            radius:0.1,gravity:V(0,-10,0),tolerance:1e-6)
        let initial=LocalPocketSimulation.State(time:3,position:V(0,0.3,0),velocity:.zero,omega:V(0,2,0))
        let result=try solver.run(from:initial,duration:0.25,maxStep:0.025)
        let impact=try XCTUnwrap(result.contacts.first)
        XCTAssertEqual(impact.time,3.2,accuracy:1e-12)
        let interval=try XCTUnwrap(result.intervals.first { $0.end.time == impact.time })
        let incoming=try XCTUnwrap(interval.sample(at:impact.time,beforeEndpoint:true))
        let outgoing=try XCTUnwrap(interval.sample(at:impact.time))
        XCTAssertEqual(incoming.velocity.y,-2,accuracy:1e-10)
        XCTAssertEqual(outgoing.velocity.y,1,accuracy:1e-10)
        XCTAssertEqual(incoming.position.y,0.1,accuracy:1e-10)
        for span in result.intervals where span.end.time<impact.time {
            let time=(span.start.time+span.end.time)/2,dt=time-initial.time
            let sample=try XCTUnwrap(span.sample(at:time))
            XCTAssertEqual(sample.position.y,0.3-5*dt*dt,accuracy:1e-12)
            XCTAssertEqual(sample.velocity.y,-10*dt,accuracy:1e-12)
            XCTAssertEqual(sample.omega,initial.omega)
            XCTAssertNil(span.sample(at:span.start.time-0.001))
            XCTAssertNil(span.sample(at:.nan))
        }
        XCTAssertEqual(result.intervals.first?.start.time,initial.time)
        XCTAssertEqual(result.intervals.last?.end.time,result.states.last?.time)
        for (a,b) in zip(result.intervals,result.intervals.dropFirst()) {
            XCTAssertEqual(a.end.time,b.start.time)
        }
    }
}

extension LocalPocketIntervalV63Tests {
    func testPairDetectionMergesDifferentStepPartitionsOnAbsoluteClock() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0.5,friction:0)],
            radius:0.1,gravity:V(0,-10,0),tolerance:1e-6)
        let falling=LocalPocketSimulation.State(time:7,position:V(0,0.5,0),velocity:.zero,omega:.zero)
        let supported=LocalPocketSimulation.State(time:7,position:V(0,0.1,0),velocity:.zero,omega:.zero)
        let b=try solver.run(from:supported,duration:0.25,maxStep:0.037)
        for step in [0.013,0.027] {
            let a=try solver.run(from:falling,duration:0.25,maxStep:step)
            let hit=try XCTUnwrap(LocalPocketSimulation.firstPairContact(a,b,radius:0.1))
            XCTAssertEqual(hit.time,7.2,accuracy:1e-12)
            XCTAssertEqual(hit.a.position.y,0.3,accuracy:1e-12)
            XCTAssertEqual(hit.a.velocity.y,-2,accuracy:1e-12)
            XCTAssertEqual(hit.b.position.y,0.1,accuracy:1e-12)
            XCTAssertEqual(hit.normal,V(0,-1,0))
            let reverse=try XCTUnwrap(LocalPocketSimulation.firstPairContact(b,a,radius:0.1))
            XCTAssertEqual(reverse.time,hit.time,accuracy:1e-12)
            XCTAssertEqual(reverse.normal,-hit.normal)
        }
    }
}

extension LocalPocketIntervalV63Tests {
    func testCoupledAdvanceTruncatesAndRebuildsFutureAfterSupportedImpact() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0.5,friction:0)],
            radius:0.1,gravity:V(0,-10,0),tolerance:1e-6)
        let falling=LocalPocketSimulation.State(time:7,position:V(0,0.5,0),velocity:.zero,omega:.zero)
        let supported=LocalPocketSimulation.State(time:7,position:V(0,0.1,0),velocity:.zero,omega:.zero)
        let hit=try solver.advanceTogether(from:[falling,supported],duration:0.25,maxStep:0.025,pairRestitution:1,pairFriction:0)
        XCTAssertEqual(hit.time,7.2,accuracy:1e-12)
        XCTAssertEqual(hit.states[0].velocity.y,2,accuracy:1e-9)
        XCTAssertEqual(hit.states[1].velocity.y,0,accuracy:1e-9)
        XCTAssertTrue(hit.intervals.flatMap{$0}.allSatisfy{$0.end.time<=hit.time})
        let next=try solver.advanceTogether(from:hit.states,duration:0.05,maxStep:0.013,pairRestitution:1,pairFriction:0)
        XCTAssertEqual(next.time,7.25,accuracy:1e-12)
        XCTAssertEqual(next.states[0].position.y,0.3875,accuracy:1e-9)
        XCTAssertEqual(next.states[0].velocity.y,1.5,accuracy:1e-9)
        XCTAssertEqual(next.states[1].position.y,0.1,accuracy:1e-9)
    }
}

extension LocalPocketIntervalV63Tests {
    func testWorldPositionRoundoffDoesNotHideApproachingPair() throws {
        typealias V=SIMD3<Double>
        func path(_ p:V,_ v:V)->LocalPocketSimulation.Result {
            let start=LocalPocketSimulation.State(time:0,position:p,velocity:v,omega:.zero)
            let end=LocalPocketSimulation.State(time:1e-5,position:p+v*1e-5,velocity:v,omega:.zero)
            return .init(states:[start,end],contacts:[],maxCorrection:0,rejectedSteps:0,
                intervals:[.init(start:start,duration:1e-5,acceleration:.zero,angularAcceleration:.zero,end:end)])
        }
        let a=path(V(-1.2457854749828616,0.828575011342763,-0.5713618888923145),
                   V(-0.0032062958278787665,-7.398595046308605e-15,-0.011522591141875744))
        let b=path(V(-1.2081525993206477,0.8285750113427628,-0.6143722252920829),
                   V(-0.06099623639009142,0,-0.020629664352469074))
        let hit=try XCTUnwrap(LocalPocketSimulation.firstPairContact(a,b,radius:0.028574999421834946))
        XCTAssertEqual(hit.time,0)
    }

    func testCapturedSlidingPairKeepsPressureAcrossSharedHalfSteps() throws {
        typealias V=SIMD3<Double>
        let radius=0.028574999421834946,y=0.8285750113427639-radius
        let floor=PocketContactTriangle(a:V(-3,y,-3),b:V(3,y,-3),c:V(0,y,3))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0.3,friction:0.2)],
            radius:radius,gravity:V(0,-9.81,0),tolerance:1e-6)
        let time=0.08906436529126581
        let a=LocalPocketSimulation.State(time:time,
            position:V(-1.245900639647661,0.8285750113427639,-0.5717759128739625),
            velocity:V(0.0029263310199580312,7.90381436908874e-17,0.011603582434239602),
            omega:V(-10.002993641384212,0.9539778158697961,2.929214640766484))
        let b=LocalPocketSimulation.State(time:time,
            position:V(-1.2075715066711,0.8285750113427639,-0.6141669488732936),
            velocity:V(-0.016494192927286686,-7.90381436908874e-17,-0.005956069678522835),
            omega:V(-3.57618330098576,-1.3951315854551314,10.519475129092195))
        let result=try solver.advanceTogether(from:[a,b],duration:0.0001,maxStep:0.0001,pairRestitution:0.9,pairFriction:0.05)
        XCTAssertEqual(result.time,time+0.0001,accuracy:1e-12)
        XCTAssertTrue(result.constraints.isEmpty,"A pressure-supported pair should not create a new impact each half-step")
    }

    func testSubBudgetReboundTransitionsToSupportedPair() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0,friction:0)],
            radius:0.1,gravity:V(0,-10,0),tolerance:1e-6)
        let upper=LocalPocketSimulation.State(time:0,position:V(0,0.30000001,0),velocity:.zero,omega:.zero)
        let lower=LocalPocketSimulation.State(time:0,position:V(0,0.1,0),velocity:.zero,omega:.zero)
        let impact=try solver.advanceTogether(from:[upper,lower],duration:0.001,maxStep:0.001,pairRestitution:0.9,pairFriction:0)
        XCTAssertEqual(impact.time,sqrt(2e-8/10),accuracy:1e-10)
        XCTAssertEqual(impact.states[0].velocity.y,0,accuracy:1e-11)
        let resting=try solver.advanceTogether(from:impact.states,duration:0.01,maxStep:0.001,pairRestitution:0.9,pairFriction:0)
        XCTAssertEqual(resting.time,impact.time+0.01,accuracy:1e-12)
        XCTAssertTrue(resting.constraints.isEmpty)
        XCTAssertEqual(resting.states[0].position.y,0.3,accuracy:1e-9)
        XCTAssertEqual(resting.states[1].position.y,0.1,accuracy:1e-9)
    }

    func testTouchingRestingPairMaintainsUnilateralSupport() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0,friction:0)],
            radius:0.1,gravity:V(0,-10,0),tolerance:1e-6)
        let upper=LocalPocketSimulation.State(time:0,position:V(0,0.3,0),velocity:.zero,omega:.zero)
        let lower=LocalPocketSimulation.State(time:0,position:V(0,0.1,0),velocity:.zero,omega:.zero)
        let result=try solver.advanceTogether(from:[upper,lower],duration:0.05,maxStep:0.01,pairRestitution:0,pairFriction:0)
        XCTAssertEqual(result.time,0.05,accuracy:1e-12)
        XCTAssertEqual(result.states[0].position.y,0.3,accuracy:1e-9)
        XCTAssertEqual(result.states[0].velocity.y,0,accuracy:1e-9)
        XCTAssertEqual(result.states[1].position.y,0.1,accuracy:1e-9)
    }
}

extension SpatialBallContactV63Tests {
    func testSustainedSupportTransmitsWeightAndSeparatesWithoutTension() throws {
        let zero=M(velocity:.zero,angularVelocity:.zero)
        let gravity=SpatialBallContact.Acceleration(linear:V(0,-10,0),angular:.zero)
        let pair=SpatialBallContact.SupportConstraint(contact:.init(a:0,b:1,normal:V(0,1,0),restitution:0,friction:0),normalRate:.zero)
        let floor=SpatialBallContact.SupportConstraint(contact:.init(a:1,b:nil,normal:V(0,1,0),restitution:0,friction:0),normalRate:.zero)
        let result=try SpatialBallContact.resolveSupport([zero,zero],external:[gravity,gravity],constraints:[pair,floor],radius:0.1)
        for a in result.accelerations { XCTAssertEqual(norm(a.linear),0,accuracy:1e-9) }
        XCTAssertEqual(result.forcesOnA[0].y,10,accuracy:1e-9)
        XCTAssertEqual(result.forcesOnA[1].y,20,accuracy:1e-9)
        let reversed=try SpatialBallContact.resolveSupport([zero,zero],external:[gravity,gravity],constraints:[floor,pair],radius:0.1)
        for i in 0..<2 { assertVector(result.accelerations[i].linear,reversed.accelerations[i].linear) }
        let departing=M(velocity:V(0,1,0),angularVelocity:.zero)
        let away=try SpatialBallContact.resolveSupport([departing,zero],external:[gravity,gravity],constraints:[pair,floor],radius:0.1)
        assertVector(away.forcesOnA[0],.zero)
        assertVector(away.accelerations[0].linear,gravity.linear)
    }
    func testSustainedFrictionDissipatesSlipAndCurvatureReleasesSupport() throws {
        let floor=SpatialBallContact.SupportConstraint(contact:.init(a:0,b:nil,normal:V(0,1,0),restitution:0,friction:0.2),normalRate:.zero)
        let gravity=SpatialBallContact.Acceleration(linear:V(0,-10,0),angular:.zero)
        let sliding=M(velocity:V(1,0,0),angularVelocity:.zero)
        let response=try SpatialBallContact.resolveSupport([sliding],external:[gravity],constraints:[floor],radius:0.1)
        XCTAssertEqual(response.accelerations[0].linear.x,-2,accuracy:1e-10)
        XCTAssertEqual(response.accelerations[0].linear.y,0,accuracy:1e-10)
        XCTAssertEqual(response.accelerations[0].angular.z,-50,accuracy:1e-9)
        XCTAssertLessThan(dot(response.forcesOnA[0],sliding.velocity),0)
        let curved=SpatialBallContact.SupportConstraint(contact:floor.contact,normalRate:V(20,0,0))
        let released=try SpatialBallContact.resolveSupport([sliding],external:[gravity],constraints:[curved],radius:0.1)
        assertVector(released.forcesOnA[0],.zero)
    }
}

extension LocalPocketIntervalV63Tests {
    func testMovingPairKeepsContactWithoutInventingNewImpacts() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0.5,friction:0)],
            radius:0.1,gravity:V(0,-10,0),tolerance:1e-6)
        let upper=LocalPocketSimulation.State(time:0,position:V(0,0.3,0),velocity:V(0.2,0,0),omega:.zero)
        let lower=LocalPocketSimulation.State(time:0,position:V(0,0.1,0),velocity:.zero,omega:.zero)
        var endpoints:[SIMD3<Double>]=[]
        // Preserve the fixed group-step convergence reference. Adaptive error
        // convergence is independently checked by testSharedErrorControlConvergesMechanicalEnergy.
        for step in [0.01,0.005,0.0025] {
            let result=try solver.advanceTogether(from:[upper,lower],duration:0.05,maxStep:step,pairRestitution:0.5,pairFriction:0,useSharedErrorControl:false)
            XCTAssertEqual(result.time,0.05,accuracy:1e-12,"Continuous contact must not turn into a new impact")
            let delta=result.states[0].position-result.states[1].position
            XCTAssertEqual(sqrt(delta.x*delta.x+delta.y*delta.y+delta.z*delta.z),0.2,accuracy:4e-6)
            endpoints.append(result.states[0].position)
        }
        let coarse=endpoints[0]-endpoints[1],fine=endpoints[1]-endpoints[2]
        XCTAssertLessThanOrEqual(sqrt(fine.x*fine.x+fine.y*fine.y+fine.z*fine.z),
                                 sqrt(coarse.x*coarse.x+coarse.y*coarse.y+coarse.z*coarse.z)+1e-8)
    }
}

extension LocalPocketIntervalV63Tests {
    func testSharedErrorControlConvergesMechanicalEnergy() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let initial=[LocalPocketSimulation.State(time:0,position:V(0,0.3,0),velocity:V(0.2,0,0),omega:.zero),
                     .init(time:0,position:V(0,0.1,0),velocity:.zero,omega:.zero)]
        func energy(_ states:[LocalPocketSimulation.State])->Double {
            states.reduce(0) { total,s in
                let translation=0.5*(s.velocity.x*s.velocity.x+s.velocity.y*s.velocity.y+s.velocity.z*s.velocity.z)
                let rotation=0.002*(s.omega.x*s.omega.x+s.omega.y*s.omega.y+s.omega.z*s.omega.z)
                return total+translation+rotation+10*s.position.y
            }
        }
        var errors:[Double]=[]
        for tolerance in [1e-5,1e-6,1e-7] {
            let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0.5,friction:0)],
                radius:0.1,gravity:V(0,-10,0),tolerance:tolerance)
            let result=try solver.advanceTogether(from:initial,duration:0.05,maxStep:0.05,pairRestitution:0.5,pairFriction:0)
            XCTAssertEqual(result.time,0.05,accuracy:1e-12)
            XCTAssertGreaterThan(result.rejectedTrials,0)
            let error=abs(energy(result.states)-energy(initial));errors.append(error)
            XCTAssertLessThanOrEqual(energy(result.states),energy(initial)+1e-8)
            XCTAssertTrue(result.intervals.flatMap{$0}.allSatisfy{$0.end.time<=result.time})
            print("[W06 shared error] tolerance=\(tolerance) energyError=\(error) rejected=\(result.rejectedTrials)")
        }
        XCTAssertLessThan(errors[1],errors[0])
        XCTAssertLessThan(errors[2],errors[1])
        XCTAssertLessThan(errors[2],0.001)
    }
}

extension LocalPocketIntervalV63Tests {
    func testUnilateralPairReleasesImmediatelyAndDuringMotion() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0.5,friction:0)],
            radius:0.1,gravity:V(0,-10,0),tolerance:1e-7)
        let lower=LocalPocketSimulation.State(time:0,position:V(0,0.1,0),velocity:.zero,omega:.zero)
        let fast=LocalPocketSimulation.State(time:0,position:V(0,0.3,0),velocity:V(2,0,0),omega:.zero)
        let free=try solver.advanceTogether(from:[fast,lower],duration:0.02,maxStep:0.01,pairRestitution:0.5,pairFriction:0)
        XCTAssertEqual(free.time,0.02,accuracy:1e-12)
        XCTAssertEqual(free.states[0].position.x,0.04,accuracy:1e-12)
        XCTAssertEqual(free.states[0].position.y,0.298,accuracy:1e-12)
        XCTAssertEqual(free.states[0].velocity.y,-0.2,accuracy:1e-12)
        let moving=LocalPocketSimulation.State(time:0,position:V(0,0.3,0),velocity:V(1,0,0),omega:.zero)
        var final:[LocalPocketSimulation.State]=[]
        for cap in [0.02,0.005] {
            let result=try solver.advanceTogether(from:[moving,lower],duration:0.12,maxStep:cap,pairRestitution:0.5,pairFriction:0)
            XCTAssertEqual(result.time,0.12,accuracy:1e-12)
            let d=result.states[0].position-result.states[1].position
            let distance=sqrt(d.x*d.x+d.y*d.y+d.z*d.z)
            print("[W06 release] cap=\(cap) distance=\(distance) time=\(result.time) rejected=\(result.rejectedTrials)")
            XCTAssertGreaterThan(distance,0.20001)
            // Independent frictionless reduction: conserved horizontal momentum
            // and energy give release at cos(theta)^3-6*cos(theta)+4.5=0.
            // Integrating dt/dtheta then free flight gives these 0.12s positions
            // (derivation and values: output/3d-v63/W06/release-reference.json).
            XCTAssertEqual(result.states[0].position.x,0.12393875396142448,accuracy:1e-4)
            XCTAssertEqual(result.states[0].position.y,0.25400618686001425,accuracy:1e-4)
            XCTAssertEqual(result.states[1].position.x,-0.003938753961424481,accuracy:1e-4)
            final.append(result.states[0])
        }
        let difference=final[0].position-final[1].position
        XCTAssertLessThan(sqrt(difference.x*difference.x+difference.y*difference.y+difference.z*difference.z),1e-4)
    }
}


extension LocalPocketIntervalV63Tests {
    func testInvalidInitialPenetrationIsDiagnosedBeforeStepping() throws {
        typealias V=SIMD3<Double>
        let floor=PocketContactTriangle(a:V(-2,0,-2),b:V(2,0,-2),c:V(0,0,2))
        let solver=LocalPocketSimulation(surfaces:[.init(triangle:floor,restitution:0,friction:0)],
            radius:0.1,gravity:V(0,-10,0),tolerance:1e-6)
        let initial=LocalPocketSimulation.State(time:0,position:V(0,0.09,0),velocity:V(0.2,0,0),omega:.zero)
        XCTAssertThrowsError(try solver.run(from:initial,duration:0.01,maxStep:0.01)) { error in
            guard case LocalPocketSimulation.Failure.initialPenetration(let time,let surface,let depth)=error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(time,0);XCTAssertEqual(surface,0)
            XCTAssertEqual(depth,0.01,accuracy:1e-12)
        }
    }
}

extension SpatialBallContactV63Tests {
    func testTinySeparationAndReturnKeepsDistinctCollisionRoot() throws {
        // Starts touching, separates, then returns after 2*v/a. This root must
        // remain distinct from t=0 even when the excursion is sub-ulp in position.
        let hit=try XCTUnwrap(SpatialBallContact.firstContact(position:V(0.05715,0,0),velocity:V(1e-9,0,0),
            acceleration:V(-1,0,0),radiusSum:0.05715,horizon:1e-6))
        XCTAssertEqual(hit.time,2e-9,accuracy:1e-15)
        XCTAssertEqual(hit.normal,V(1,0,0))
    }

    func testNearRestingPairImpactWithTwoFloorSupportsConverges() throws {
        // Captured from the real corner-pocket run at 0.08938454 s.
        // Both floor contacts are inelastic; the pair retains its material
        // restitution. This must resolve without relaxing the residual budget.
        let initial:[PocketContactResponse.Motion]=[
            .init(velocity:V(0.0033391702244547077,-1.0687990776813721e-12,0.011999909684671317),
                  angularVelocity:V(-9.950890101659907,0.9088675972596636,2.912255546609951)),
            .init(velocity:V(-0.015963749015691957,-9.857758638077732e-12,-0.005448268360302749),
                  angularVelocity:V(-3.571941969041286,-1.3665657176742367,10.465997462676679))]
        let normal=V(-0.6705676107220127,-1.554118001173856e-14,0.7418484208047971)
        let contacts:[SpatialBallContact.Constraint]=[
            .init(a:0,b:nil,normal:V(0,1,0),restitution:0,friction:0.2),
            .init(a:0,b:1,normal:normal,restitution:0.9,friction:0.05),
            .init(a:1,b:nil,normal:V(0,1,0),restitution:0,friction:0.2)]
        let result=try SpatialBallContact.resolveInstant(initial,constraints:contacts,radius:0.028574999421834946)
        XCTAssertGreaterThanOrEqual(result.motions[0].velocity.y,-1e-11)
        XCTAssertGreaterThanOrEqual(result.motions[1].velocity.y,-1e-11)
        let relative=result.motions[0].velocity-result.motions[1].velocity
        XCTAssertGreaterThanOrEqual(relative.x*normal.x+relative.y*normal.y+relative.z*normal.z,-1e-11)
    }
}

final class ConfirmedCaptureV63Tests:XCTestCase {
    func testCaptureKeepsMotionAndDoesNotLeakBeforeItsTime() throws {
        let recorder=TrajectoryRecorder()
        let state=LocalPocketSimulation.State(time:0.25,position:SIMD3(0.02,0.6,-0.7),
            velocity:SIMD3(0.1,-1,0.2),omega:SIMD3(1,2,3))
        let capture=TrajectoryRecorder.ConfirmedCapture(ballName:"object",pocketID:"pocket_4",geometryVersion:"fixture-v1",state:state)
        recorder.recordFrame(ballName:"object",frame:.init(time:0.3,position:SCNVector3(0.025,0.55,-0.69),
            velocity:SCNVector3(0.1,-1.5,0.2),angularVelocity:SCNVector4(1,2,3,0),state:.sliding))
        let frame=try XCTUnwrap(recorder.framesByBallName["object"]?.last)
        try recorder.recordConfirmedCapture(capture)
        try recorder.recordConfirmedCapture(capture)
        XCTAssertEqual(recorder.confirmedCaptures.count,1)
        XCTAssertFalse(recorder.isBallPocketed("object",at:0.249999))
        XCTAssertTrue(recorder.isBallPocketed("object",at:0.25))
        XCTAssertTrue(recorder.isBallPocketed("object"))
        XCTAssertFalse(recorder.isBallPocketed("object",at:.nan))
        XCTAssertEqual(recorder.framesByBallName["object"]?.last?.position.y,frame.position.y)
        XCTAssertEqual(recorder.framesByBallName["object"]?.last?.velocity.y,frame.velocity.y)
        XCTAssertEqual(recorder.framesByBallName["object"]?.last?.state,.sliding)
        XCTAssertEqual(recorder.confirmedCaptures[0].state.velocity,state.velocity)
        XCTAssertEqual(recorder.confirmedCaptures[0].state.omega,state.omega)
        XCTAssertThrowsError(try recorder.recordConfirmedCapture(.init(ballName:"object",pocketID:"pocket_0",geometryVersion:"fixture-v1",state:state)))
        XCTAssertEqual(recorder.confirmedCaptures.first?.pocketID,"pocket_4")
    }

    func testLegacyCaptureQueryAndInvalidCaptureRemainSeparate() throws {
        let recorder=TrajectoryRecorder()
        recorder.recordFrame(ballName:"old",frame:.init(time:1,position:SCNVector3Zero,velocity:SCNVector3Zero,
            angularVelocity:SCNVector4(0,0,0,0),state:.pocketed))
        XCTAssertTrue(recorder.isBallPocketed("old"))
        XCTAssertFalse(recorder.isBallPocketed("old",at:0.5))
        XCTAssertTrue(recorder.isBallPocketed("old",at:1))
        let invalid=LocalPocketSimulation.State(time:.nan,position:.zero,velocity:.zero,omega:.zero)
        XCTAssertThrowsError(try recorder.recordConfirmedCapture(.init(ballName:"new",pocketID:"pocket_0",geometryVersion:"fixture-v1",state:invalid)))
        XCTAssertTrue(recorder.confirmedCaptures.isEmpty)
        XCTAssertFalse(recorder.isBallPocketed("new"))
    }
}
