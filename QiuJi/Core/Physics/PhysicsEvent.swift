//
//  PhysicsEvent.swift
//  QiuJi
//
//  事件驱动引擎的事件类型与球状态值类型（D-A1 第三梯队：从 `EventDrivenEngine` 巨型文件
//  中抽出，作为引擎的公共词汇表，便于独立阅读与单测）。
//

import SceneKit

// MARK: - Event Types

/// Type of physics event
enum PhysicsEventType {
    case ballBall(ballA: String, ballB: String)
    case ballCushion(ball: String, cushionIndex: Int, normal: SCNVector3)
    case transition(ball: String, fromState: BallMotionState, toState: BallMotionState)
    case pocket(ball: String, pocketId: String)
}

/// Physics event with time and priority for ordering
struct PhysicsEvent: Comparable {
    let type: PhysicsEventType
    let time: Float
    let priority: Int  // Lower number = higher priority
    // Keep tie epsilon very small. A large epsilon (e.g. 1e-4) causes near-simultaneous
    // events to be treated as equal and reordered by priority, which can let a transition
    // run before an almost-earlier collision and produce post-evolve overlaps.
    private static let tieEpsilon: Float = 1e-7

    static func < (lhs: PhysicsEvent, rhs: PhysicsEvent) -> Bool {
        if abs(lhs.time - rhs.time) < tieEpsilon {
            return lhs.priority < rhs.priority
        }
        return lhs.time < rhs.time
    }

    static func == (lhs: PhysicsEvent, rhs: PhysicsEvent) -> Bool {
        return abs(lhs.time - rhs.time) < tieEpsilon && lhs.priority == rhs.priority
    }
}

// MARK: - Ball State

/// State of a ball in the event-driven engine
struct BallState {
    var position: SCNVector3
    var velocity: SCNVector3
    var angularVelocity: SCNVector3
    var state: BallMotionState
    let name: String

    var isPocketed: Bool {
        return state == .pocketed
    }

    var isStationary: Bool {
        return state == .stationary
    }
}
