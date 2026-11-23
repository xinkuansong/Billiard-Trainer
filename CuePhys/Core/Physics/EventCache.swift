//
//  EventCache.swift
//  QiuJi
//
//  事件驱动引擎的事件缓存（D-A1 第三梯队：从 `EventDrivenEngine` 巨型文件中抽出独立成块）。
//  缓存已算出的球-球 / 球-库 / 状态转换事件，避免每次 findNextEvent 重复求解四次方程。
//

import Foundation
import SceneKit

// MARK: - Event Cache

/// Cache for computed events to avoid redundant calculations
/// Key 用整数编码（ballId × 2^N + cushionIdx），避免字符串 split/alloc，减少 invalidate 开销
class EventCache {
    private struct CachedEvent {
        let event: PhysicsEvent
        let timeStamp: Float
    }

    private struct NoCollisionEntry {
        let stamp: Float
        let stateA: BallMotionState
        let stateB: BallMotionState
    }

    // 球名称 → 整数 ID（first-seen 时分配，不变）
    private var ballNameToId: [String: Int32] = [:]
    private var nextBallId: Int32 = 0

    // ball-ball: key = min(idA,idB) << 16 | max(idA,idB)  (各球 id ≤ 31，满足 16bit)
    private var ballBallCache: [Int64: CachedEvent] = [:]
    private var ballBallNoCollisionCache: [Int64: NoCollisionEntry] = [:]

    // ball-cushion: key = ballId << 8 | cushionIndex  (cushionIndex ≤ 25)
    private var ballCushionCache: [Int64: CachedEvent] = [:]
    private var ballCushionNoCollisionCache: [Int64: Float] = [:]

    // transition: key = ballId << 4 | transitionTypeId
    private var transitionCache: [Int64: CachedEvent] = [:]

    private static let transitionTypeIds: [String: Int64] = [
        "slideToRoll": 0,
        "rollToSpin": 1,
        "spinToStationary": 2
    ]

    /// Invalidate cache entries for affected balls
    func invalidate(affectedBalls: Set<String>) {
        let affectedIds: Set<Int32> = Set(affectedBalls.compactMap { ballNameToId[$0] })
        guard !affectedIds.isEmpty else { return }

        ballBallCache = ballBallCache.filter { key, _ in
            let idA = Int32(key >> 16)
            let idB = Int32(key & 0xFFFF)
            return !affectedIds.contains(idA) && !affectedIds.contains(idB)
        }
        ballBallNoCollisionCache = ballBallNoCollisionCache.filter { key, _ in
            let idA = Int32(key >> 16)
            let idB = Int32(key & 0xFFFF)
            return !affectedIds.contains(idA) && !affectedIds.contains(idB)
        }
        ballCushionCache = ballCushionCache.filter { key, _ in
            let ballId = Int32(key >> 8)
            return !affectedIds.contains(ballId)
        }
        ballCushionNoCollisionCache = ballCushionNoCollisionCache.filter { key, _ in
            let ballId = Int32(key >> 8)
            return !affectedIds.contains(ballId)
        }
        transitionCache = transitionCache.filter { key, _ in
            let ballId = Int32(key >> 4)
            return !affectedIds.contains(ballId)
        }
    }

    // MARK: - Ball-Ball

    /// Invalidate both the positive and negative cache entries for a specific ball pair.
    /// Called by separateOverlappingBalls so the next findNextEvent re-solves the quartic
    /// instead of trusting a stale "no collision" entry from before the separation.
    func invalidateBallPair(ballA: String, ballB: String) {
        let key = makeBallBallKey(ballA: ballA, ballB: ballB)
        ballBallCache.removeValue(forKey: key)
        ballBallNoCollisionCache.removeValue(forKey: key)
    }

    func getBallBall(ballA: String, ballB: String, currentTime: Float) -> PhysicsEvent? {
        let key = makeBallBallKey(ballA: ballA, ballB: ballB)
        guard let cached = ballBallCache[key] else { return nil }
        let remaining = cached.event.time - (currentTime - cached.timeStamp)
        if remaining <= 0 { ballBallCache[key] = nil; return nil }
        return PhysicsEvent(type: cached.event.type, time: remaining, priority: cached.event.priority)
    }

    func setBallBall(ballA: String, ballB: String, event: PhysicsEvent, currentTime: Float) {
        let key = makeBallBallKey(ballA: ballA, ballB: ballB)
        ballBallCache[key] = CachedEvent(event: event, timeStamp: currentTime)
        ballBallNoCollisionCache.removeValue(forKey: key)
    }

    /// TTL for no-collision cache entries: re-check pairs after this many simulation seconds.
    /// Only applies when both balls are non-translating (stationary/spinning); active balls
    /// always bypass the no-collision cache (see isBallBallNoCollision).
    static let noCollisionTTL: Float = 0.5

    /// Returns true only when both balls recorded as non-colliding are still in the same
    /// motion state AND the entry is within TTL. Active (sliding/rolling) balls are never
    /// considered cached because their trajectories change rapidly.
    func isBallBallNoCollision(ballA: String, ballB: String,
                               stateA: BallMotionState, stateB: BallMotionState,
                               currentTime: Float) -> Bool {
        guard let entry = ballBallNoCollisionCache[makeBallBallKey(ballA: ballA, ballB: ballB)] else { return false }
        // If either ball is now in a different motion state, the cached result is stale.
        guard entry.stateA == stateA && entry.stateB == stateB else { return false }
        // For non-translating pairs (stationary/spinning) we use a generous TTL because
        // they won't drift. For any pair containing an active ball we skip caching entirely.
        let isStatic = (stateA == .stationary || stateA == .spinning)
                    && (stateB == .stationary || stateB == .spinning)
        if !isStatic { return false }
        return (currentTime - entry.stamp) < EventCache.noCollisionTTL
    }

    func setBallBallNoCollision(ballA: String, ballB: String,
                                stateA: BallMotionState, stateB: BallMotionState,
                                currentTime: Float) {
        let entry = NoCollisionEntry(stamp: currentTime, stateA: stateA, stateB: stateB)
        ballBallNoCollisionCache[makeBallBallKey(ballA: ballA, ballB: ballB)] = entry
    }

    // MARK: - Ball-Cushion

    func getBallCushion(ball: String, cushionIndex: Int, currentTime: Float) -> PhysicsEvent? {
        let key = makeBallCushionKey(ball: ball, cushionIndex: cushionIndex)
        guard let cached = ballCushionCache[key] else { return nil }
        let remaining = cached.event.time - (currentTime - cached.timeStamp)
        if remaining <= 0 { ballCushionCache[key] = nil; return nil }
        return PhysicsEvent(type: cached.event.type, time: remaining, priority: cached.event.priority)
    }

    func setBallCushion(ball: String, cushionIndex: Int, event: PhysicsEvent, currentTime: Float) {
        let key = makeBallCushionKey(ball: ball, cushionIndex: cushionIndex)
        ballCushionCache[key] = CachedEvent(event: event, timeStamp: currentTime)
        ballCushionNoCollisionCache.removeValue(forKey: key)
    }

    func isBallCushionNoCollision(ball: String, cushionIndex: Int) -> Bool {
        return ballCushionNoCollisionCache[makeBallCushionKey(ball: ball, cushionIndex: cushionIndex)] != nil
    }

    func setBallCushionNoCollision(ball: String, cushionIndex: Int, currentTime: Float) {
        ballCushionNoCollisionCache[makeBallCushionKey(ball: ball, cushionIndex: cushionIndex)] = currentTime
    }

    // MARK: - Transition

    func getTransition(ball: String, transitionType: String, currentTime: Float) -> PhysicsEvent? {
        let key = makeTransitionKey(ball: ball, transitionType: transitionType)
        guard let cached = transitionCache[key] else { return nil }
        let remaining = cached.event.time - (currentTime - cached.timeStamp)
        if remaining <= 0 { transitionCache[key] = nil; return nil }
        return PhysicsEvent(type: cached.event.type, time: remaining, priority: cached.event.priority)
    }

    func setTransition(ball: String, transitionType: String, event: PhysicsEvent, currentTime: Float) {
        transitionCache[makeTransitionKey(ball: ball, transitionType: transitionType)] = CachedEvent(event: event, timeStamp: currentTime)
    }

    // MARK: - Lifecycle

    func clear() {
        ballBallCache.removeAll()
        ballBallNoCollisionCache.removeAll()
        ballCushionCache.removeAll()
        ballCushionNoCollisionCache.removeAll()
        transitionCache.removeAll()
    }

    // MARK: - Key Helpers

    @inline(__always)
    private func ballId(_ name: String) -> Int64 {
        if let id = ballNameToId[name] { return Int64(id) }
        let id = nextBallId
        nextBallId += 1
        ballNameToId[name] = id
        return Int64(id)
    }

    @inline(__always)
    private func makeBallBallKey(ballA: String, ballB: String) -> Int64 {
        let a = ballId(ballA), b = ballId(ballB)
        return (min(a, b) << 16) | max(a, b)
    }

    @inline(__always)
    private func makeBallCushionKey(ball: String, cushionIndex: Int) -> Int64 {
        return (ballId(ball) << 8) | Int64(cushionIndex)
    }

    @inline(__always)
    private func makeTransitionKey(ball: String, transitionType: String) -> Int64 {
        let typeId = EventCache.transitionTypeIds[transitionType] ?? Int64(abs(transitionType.hashValue) & 0xF)
        return (ballId(ball) << 4) | typeId
    }
}
