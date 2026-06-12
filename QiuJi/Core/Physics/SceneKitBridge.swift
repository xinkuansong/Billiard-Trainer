//
//  SceneKitBridge.swift
//  QiuJi
//
//  轨迹回放的 SceneKit 桥接（D-A1 第三梯队：从 `EventDrivenEngine` 巨型文件中抽出）。
//  把 `TrajectoryRecorder` 记录的逐帧轨迹转成可驱动 `SCNNode` 的 `SCNAction`。
//

import SceneKit

// MARK: - SceneKit Bridge

/// Bridge for playing back trajectory recordings in SceneKit
class SceneKitBridge {
    /// Play back trajectory for a ball node
    /// - Parameters:
    ///   - node: SceneKit node to animate
    ///   - ballName: Name of the ball in the trajectory recorder
    ///   - recorder: Trajectory recorder containing recorded frames
    ///   - speed: Playback speed multiplier (1.0 = real-time)
    /// - Returns: SCNAction sequence for the trajectory, or nil if no trajectory found
    static func playTrajectory(
        node: SCNNode,
        ballName: String,
        recorder: TrajectoryRecorder,
        speed: Float = 1.0
    ) -> SCNAction? {
        return recorder.action(for: node, ballName: ballName, speed: speed)
    }

    /// Play back trajectories for multiple balls simultaneously
    /// - Parameters:
    ///   - nodes: Dictionary mapping ball names to SceneKit nodes
    ///   - recorder: Trajectory recorder containing recorded frames
    ///   - speed: Playback speed multiplier (1.0 = real-time)
    /// - Returns: Dictionary mapping ball names to SCNAction sequences
    static func playTrajectories(
        nodes: [String: SCNNode],
        recorder: TrajectoryRecorder,
        speed: Float = 1.0
    ) -> [String: SCNAction] {
        var actions: [String: SCNAction] = [:]

        for (ballName, node) in nodes {
            if let action = recorder.action(for: node, ballName: ballName, speed: speed) {
                actions[ballName] = action
            }
        }

        return actions
    }
}
