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
