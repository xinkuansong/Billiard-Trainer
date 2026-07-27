//
//  TrajectoryPlaybackSpinTests.swift
//  QiuJiTests
//
//  问题集合 v17 W1：回放层球体姿态由「位移弧长 / R + 轴 = ŷ × v̂」改为**引擎角速度 ω 逐帧积分**。
//  本文件用手工构造的确定性 recorder（不依赖具体物理系数，范式沿用
//  `TrajectoryPlaybackSettleTests`）钉死四件事：
//    1. 纯滚动段新旧口径等价（不是把已经对的东西改坏）；
//    2. ω 积分口径正确（增量角 = |ω|·Δt、轴 = ω̂）；
//    3. `.spinning` 位置不动而姿态持续转、随 ω_y 衰减变慢；`.stationary` 完全不转；
//    4. 姿态复位后重播，起始与逐帧姿态逐次可复现（S5）。
//
//  说明：`stateAt` 在**恰好落在事件帧时刻**采样时（dt=0，`AnalyticalMotion.evolve` 为恒等），
//  返回该帧存储的 position/velocity/ω，断言与物理系数无关。
//

import XCTest
import SceneKit
import simd
@testable import QiuJi

final class TrajectoryPlaybackSpinTests: XCTestCase {

    private let dt: Float = 1.0 / 60.0
    private let R = BallPhysics.radius
    private let ballName = "cue"

    // MARK: - 1. 纯滚动不回归（完成标准 2）

    /// 沿 +X 匀减速纯滚动：ω = (ŷ × v)/R ⇒ ω = (0, 0, −v/R)。
    /// 新口径（ω 梯形积分）与旧口径（Σ 位移 / R，轴 = ŷ × v̂）在同一时间窗内应给出同一姿态。
    func test_rollingSegment_omegaIntegrationMatchesLegacyArcLength() {
        let v0: Float = 1.2, a: Float = 0.3
        let (recorder, stopTime) = makeRollingRecorder(v0: v0, decel: a)
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: 0)

        let omegaNode = SCNNode()
        let legacyNode = SCNNode()
        var prevOmega = playback.stateAt(ballName: ballName, time: 0)!.angularVelocity
        var prevPos = playback.stateAt(ballName: ballName, time: 0)!.position
        var totalAngle: Float = 0

        var k = 1
        while Float(k) * dt < stopTime {
            let t = Float(k) * dt
            guard let s = playback.stateAt(ballName: ballName, time: t) else { break }

            BallSpinIntegrator.advance(node: omegaNode, from: prevOmega, to: s.angularVelocity, dt: dt)

            // 旧口径复刻：本帧位移弧长 / R，绕 ŷ × v̂。
            let step = s.position - prevPos
            let dRot = step.length() / R
            if dRot > 1e-5, s.moveDirection.length() > 0.001 {
                let axis = SCNVector3(0, 1, 0).cross(s.moveDirection).normalized()
                let q = simd_quatf(angle: dRot, axis: simd_float3(axis.x, axis.y, axis.z))
                legacyNode.simdOrientation = simd_normalize(q * legacyNode.simdOrientation)
            }

            totalAngle += dRot
            prevOmega = s.angularVelocity
            prevPos = s.position
            k += 1
        }

        XCTAssertGreaterThan(totalAngle, 10, "构造的滚动段应转过足够多弧度才有比较意义")
        let deviation = angleBetween(omegaNode.simdOrientation, legacyNode.simdOrientation)
        let relative = deviation / totalAngle
        XCTAssertLessThan(relative, 0.01,
                          "纯滚动段 ω 积分与旧位移口径偏差 \(deviation) rad / 总转角 \(totalAngle) rad = \(relative)，超 1%")
    }

    // MARK: - 2. ω 积分口径（完成标准 3）

    func test_spinIntegrator_deltaAngleAndAxis() {
        let omega = SCNVector3(1.5, -4.0, 2.5)
        let step: Float = 0.017
        let q = BallSpinIntegrator.delta(angularVelocity: omega, dt: step)

        let expectedAngle = omega.length() * step
        XCTAssertEqual(q.angle, expectedAngle, accuracy: 1e-4, "增量角应为 |ω|·Δt")

        let expectedAxis = simd_normalize(simd_float3(omega.x, omega.y, omega.z))
        XCTAssertGreaterThan(simd_dot(simd_normalize(q.axis), expectedAxis), 1 - 1e-5, "转轴应为 ω̂")
    }

    func test_spinIntegrator_zeroOmegaOrZeroDt_isIdentity() {
        XCTAssertEqual(BallSpinIntegrator.delta(angularVelocity: SCNVector3Zero, dt: 0.1).angle,
                       0, accuracy: 1e-6)
        XCTAssertEqual(BallSpinIntegrator.delta(angularVelocity: SCNVector3(0, 30, 0), dt: 0).angle,
                       0, accuracy: 1e-6)
    }

    /// 纯竖轴自转（加塞）：绕 +Y 转 ω_y·Δt，且姿态增量的轴恒为世界 +Y。
    func test_pureSideSpin_rotatesAboutWorldUp() {
        let node = SCNNode()
        let omega = SCNVector3(0, 12, 0)
        for _ in 0..<10 {
            BallSpinIntegrator.advance(node: node, from: omega, to: omega, dt: dt)
        }
        let q = node.simdOrientation
        XCTAssertEqual(q.angle, 12 * dt * 10, accuracy: 1e-4)
        XCTAssertGreaterThan(simd_dot(simd_normalize(q.axis), simd_float3(0, 1, 0)), 1 - 1e-5)
    }

    // MARK: - 3. spinning / stationary（完成标准 3）

    /// `.spinning`：位置恒定，ω_y 按引擎衰减 ⇒ 球面持续自转且越转越慢，衰减到零后不再转。
    func test_spinningState_positionFixed_orientationKeepsTurningAndSlowsDown() {
        let recorder = TrajectoryRecorder()
        let origin = SCNVector3(0.3, 0, -0.2)
        var wy: Float = 60
        var t: Float = 0
        while wy > 0 {
            recorder.recordFrame(ballName: ballName, frame: BallFrame(
                time: t, position: origin, velocity: SCNVector3Zero,
                angularVelocity: SCNVector4(0, wy, 0, 0), state: .spinning))
            wy = AnalyticalMotion.decaySpin(angularVelocity: SCNVector3(0, wy, 0), dt: dt).y
            t += dt
        }
        recorder.recordFrame(ballName: ballName, frame: BallFrame(
            time: t, position: origin, velocity: SCNVector3Zero,
            angularVelocity: SCNVector4(0, 0, 0, 0), state: .stationary))

        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: 0)
        let node = SCNNode()
        var prevOmega = playback.stateAt(ballName: ballName, time: 0)!.angularVelocity
        var stepAngles: [Float] = []
        var k = 1
        // 多采 5 帧越过静止帧：ω_y 归零后的步长必须严格为 0（进入 `.stationary`）。
        let sampleEnd = t + 5 * dt
        while Float(k) * dt <= sampleEnd {
            let s = playback.stateAt(ballName: ballName, time: Float(k) * dt)!
            XCTAssertEqual(s.position.x, origin.x, accuracy: 1e-6, "自转段位置不应变化")
            XCTAssertEqual(s.position.z, origin.z, accuracy: 1e-6, "自转段位置不应变化")

            let before = node.simdOrientation
            BallSpinIntegrator.advance(node: node, from: prevOmega, to: s.angularVelocity, dt: dt)
            stepAngles.append(angleBetween(before, node.simdOrientation))
            prevOmega = s.angularVelocity
            k += 1
        }

        let spinningSteps = stepAngles.prefix(while: { $0 > 1e-5 })
        XCTAssertGreaterThan(spinningSteps.count, 10, "自转段应有可观的持续转动（旧口径此处完全静止）")
        for i in 1..<spinningSteps.count {
            XCTAssertLessThanOrEqual(spinningSteps[i], spinningSteps[i - 1] + 1e-6,
                                     "自转应随 ω_y 衰减单调变慢（第 \(i) 步反而变快）")
        }
        // 进入 `.stationary` 后（最后 4 步）必须完全不转；衔接的那一步仍应转过残余 ω_y 的一小段。
        for angle in stepAngles.suffix(4) {
            XCTAssertEqual(angle, 0, accuracy: 1e-6, "ω_y 衰减为零、进入静止后不应再转")
        }
    }

    func test_stationaryState_reportsZeroOmega_andNoRotation() {
        let recorder = TrajectoryRecorder()
        recorder.recordFrame(ballName: ballName, frame: BallFrame(
            time: 0, position: SCNVector3(0.1, 0, 0), velocity: SCNVector3(0.2, 0, 0),
            angularVelocity: SCNVector4(0, 0, -7, 0), state: .rolling))
        recorder.recordFrame(ballName: ballName, frame: BallFrame(
            time: 0.5, position: SCNVector3(0.2, 0, 0), velocity: SCNVector3Zero,
            angularVelocity: SCNVector4(0, 3, 0, 0), state: .stationary))

        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: 0)
        let s = playback.stateAt(ballName: ballName, time: 0.8)!
        XCTAssertEqual(s.motionState, .stationary)
        XCTAssertEqual(s.angularVelocity.length(), 0, accuracy: 1e-6, "静止帧不应残留角速度")

        let node = SCNNode()
        BallSpinIntegrator.advance(node: node, from: s.angularVelocity, to: s.angularVelocity, dt: dt)
        XCTAssertEqual(node.simdOrientation.angle, 0, accuracy: 1e-6)
    }

    // MARK: - 4. 姿态复位与可复现（完成标准 5，S5）

    /// 同一杆连播两次：复位后第二次的**起始**与**逐帧**姿态与第一次逐分量一致。
    func test_replayAfterReset_reproducesIdenticalPose() {
        let (recorder, stopTime) = makeRollingRecorder(v0: 1.0, decel: 0.4)
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: 0)
        let node = SCNNode()
        node.simdOrientation = simd_quatf(angle: 1.1, axis: simd_float3(0.3, 0.9, 0.1))  // 上一杆遗留姿态

        func runOnce() -> (start: simd_quatf, end: simd_quatf) {
            BallSpinIntegrator.resetPose(node)
            let start = node.simdOrientation
            var prevOmega = playback.stateAt(ballName: ballName, time: 0)!.angularVelocity
            var k = 1
            while Float(k) * dt < stopTime {
                let s = playback.stateAt(ballName: ballName, time: Float(k) * dt)!
                BallSpinIntegrator.advance(node: node, from: prevOmega, to: s.angularVelocity, dt: dt)
                prevOmega = s.angularVelocity
                k += 1
            }
            return (start, node.simdOrientation)
        }

        let first = runOnce()
        let second = runOnce()
        assertQuatEqual(second.start, first.start, accuracy: 1e-5, "第二次回放起始姿态与第一次不一致")
        assertQuatEqual(second.start, simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)),
                        accuracy: 1e-5, "复位后应回到单位姿态")
        assertQuatEqual(second.end, first.end, accuracy: 1e-5, "同一杆两次回放终态姿态应逐分量一致")
        XCTAssertGreaterThan(angleBetween(first.start, first.end), 1.0, "该杆应确实转过明显角度")
    }

    /// 复位收口点实证：场景层重新摆球（走位编排台 / 各解页复位都经此入口）会清掉回放姿态。
    @MainActor
    func test_sceneShowBall_resetsBallPose() throws {
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering: false)
        let node = try XCTUnwrap(scene.allBallNodes[PositionPlayBall.cueKey], "缺母球节点")
        node.simdOrientation = simd_quatf(angle: 2.0, axis: simd_float3(0, 1, 0))

        scene.showBall(key: PositionPlayBall.cueKey,
                       scenePosition: SCNVector3(0, scene.surfaceY, 0))
        assertQuatEqual(node.simdOrientation, simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)),
                        accuracy: 1e-5, "showBall 未复位球体姿态")

        node.simdOrientation = simd_quatf(angle: -1.3, axis: simd_float3(1, 0, 0))
        scene.applyBallLayout(cueBallPosition: SCNVector3(-0.5, scene.surfaceY, 0),
                              targetBallNumber: 8,
                              targetPosition: SCNVector3(0.2, scene.surfaceY, 0))
        assertQuatEqual(node.simdOrientation, simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)),
                        accuracy: 1e-5, "applyBallLayout 未复位球体姿态")
    }

    // MARK: - Helpers

    /// 沿 +X 匀减速纯滚动的 recorder：v(t)=v0−a·t，ω=(ŷ × v)/R=(0,0,−v/R)，末尾自然静止帧。
    private func makeRollingRecorder(v0: Float, decel a: Float) -> (TrajectoryRecorder, Float) {
        let recorder = TrajectoryRecorder()
        let stopTime = v0 / a
        var k = 0
        while Float(k) * dt < stopTime {
            let t = Float(k) * dt
            let v = v0 - a * t
            let x = v0 * t - 0.5 * a * t * t
            recorder.recordFrame(ballName: ballName, frame: BallFrame(
                time: t,
                position: SCNVector3(x, 0, 0),
                velocity: SCNVector3(v, 0, 0),
                angularVelocity: SCNVector4(0, 0, -v / R, 0),
                state: .rolling))
            k += 1
        }
        let restX = v0 * stopTime - 0.5 * a * stopTime * stopTime
        recorder.recordFrame(ballName: ballName, frame: BallFrame(
            time: stopTime, position: SCNVector3(restX, 0, 0), velocity: SCNVector3Zero,
            angularVelocity: SCNVector4(0, 0, 0, 0), state: .stationary))
        return (recorder, stopTime)
    }

    /// 两个姿态之间的最短转角（弧度）。
    private func angleBetween(_ a: simd_quatf, _ b: simd_quatf) -> Float {
        (b * a.inverse).normalized.angle
    }

    private func assertQuatEqual(_ a: simd_quatf, _ b: simd_quatf, accuracy: Float,
                                 _ message: String, file: StaticString = #filePath,
                                 line: UInt = #line) {
        // 四元数 q 与 −q 表示同一姿态：取同号后再逐分量比较。
        let sign: Float = simd_dot(a.vector, b.vector) < 0 ? -1 : 1
        for i in 0..<4 {
            XCTAssertEqual(a.vector[i] * sign, b.vector[i], accuracy: accuracy,
                           "\(message)（分量 \(i)）", file: file, line: line)
        }
    }
}
