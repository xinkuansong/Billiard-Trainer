//
//  TrajectoryRecorder.swift
//  BilliardTrainer
//
//  轨迹记录与回放
//

import SceneKit

struct BallFrame {
    let time: Float
    let position: SCNVector3
    let velocity: SCNVector3
    let angularVelocity: SCNVector4
    let state: BallMotionState
}

final class TrajectoryRecorder {
    private(set) var framesByBallName: [String: [BallFrame]] = [:]
    private(set) var duration: Float = 0
    
    func recordFrame(ballName: String, frame: BallFrame) {
        var list = framesByBallName[ballName] ?? []
        list.append(frame)
        framesByBallName[ballName] = list
        duration = max(duration, frame.time)
    }
    
    func stateAt(ballName: String, time: Float) -> BallFrame? {
        guard let frames = framesByBallName[ballName], !frames.isEmpty else { return nil }
        // 简单线性查找，可后续优化为二分
        var last: BallFrame = frames[0]
        for frame in frames {
            if frame.time >= time { return frame }
            last = frame
        }
        return last
    }
    
    /// 检查指定球是否在轨迹中被进袋
    func isBallPocketed(_ ballName: String) -> Bool {
        guard let frames = framesByBallName[ballName], let last = frames.last else { return false }
        return last.state == .pocketed
    }
    
    // 回放动作统一由 `TrajectoryPlayback.action(for:ballName:)` 生成（解析解逐帧求值 +
    // 角速度积分自转）。此处旧的「事件帧线性插值 + 位移反推滚动」实现与其唯一调用方
    // `SceneKitBridge` 已于 v17 W2 删除。
}
