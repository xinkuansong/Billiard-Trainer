//
//  EventDrivenEngine.swift
//  BilliardTrainer
//
//  Event-driven physics engine implementing P3.1-P3.4
//

import Foundation
import SceneKit

// MARK: - Event-Driven Engine

/// Event-driven physics engine for billiard simulation
class EventDrivenEngine {
    // Ball states indexed by name
    private var balls: [String: BallState] = [:]

    /// 球名的**插入有序**列表（D-A3 第三梯队：引擎遍历确定性化）。
    /// Swift `Dictionary` 的遍历顺序受每次进程启动的哈希种子随机化影响——同一输入两次运行
    /// 字典遍历顺序可能不同。引擎多处在遍历后做「取最早事件 `candidates.min()`」「按 names 顺序
    /// 逐对推开重叠球」等**对顺序敏感**的操作（min() 在并列时返回首个、separate 顺序影响逐次推位），
    /// 字典随机序会让同一杆每次预测的事件并列裁决/分离顺序漂移（FL-020 残留根因）。改为始终遍历
    /// 本插入有序列表（与 `setBall` 调用顺序一致、跨运行稳定），即可消除该路径的非确定性。
    private var ballOrder: [String] = []

    // Current simulation time
    private(set) var currentTime: Float = 0
    
    // Table geometry bounds
    private let tableBounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float)
    
    // Event cache
    private let eventCache = EventCache()
    
    // Trajectory recorder
    private let trajectoryRecorder = TrajectoryRecorder()
    
    // Table geometry for collision detection
    private let tableGeometry: TableGeometry
    
    // Resolved events history (for game rules and audio)
    private(set) var resolvedEvents: [PhysicsEventType] = []

    /// 每个 resolvedEvent 对应的绝对模拟时间（与 resolvedEvents 等长，下标一一对应）
    private(set) var resolvedEventTimes: [Float] = []

    /// 首次球-球碰撞的模拟时间（用于相机延迟切换观察视角）
    private(set) var firstBallBallCollisionTime: Float?

    /// Initialize engine with table geometry
    init(tableGeometry: TableGeometry) {
        self.tableGeometry = tableGeometry
        
        // Calculate table bounds from inner dimensions
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        
        tableBounds = (
            minX: -halfLength,
            maxX: halfLength,
            minZ: -halfWidth,
            maxZ: halfWidth
        )
    }
    
    /// Add or update a ball state
    func setBall(_ ball: BallState) {
        if balls[ball.name] == nil { ballOrder.append(ball.name) }
        balls[ball.name] = ball
    }
    
    /// Get ball state by name
    func getBall(_ name: String) -> BallState? {
        return balls[name]
    }
    
    /// Get all ball states（按插入有序返回，确定性）
    func getAllBalls() -> [BallState] {
        return ballOrder.compactMap { balls[$0] }
    }
    
    /// Run simulation until maxEvents or maxTime is reached.
    /// - Parameter highFidelityBounds: 仅**展示用最终模拟**置 true → 启用近库自适应子步（ADR-P10-07），
    ///   让贴墙帧足够密、回放轨迹不外推穿墙。求解器的数十次短模拟保持 false（用固定 `maxEvolveStep`
    ///   粗步，避免把每杆求解拖慢一个数量级）——其只需结果（进/吃库/方向），且引擎级方向兜底/settle
    ///   收袋（见 `enforceTableBounds`，**始终生效**）已保证结果正确性（球不会停在台外）。
    /// - Parameter earlyStopBallNames: 反解搜索早停（B1，性能优化方案）：非 nil 时，当这些「兴趣球」
    ///   全部落袋/停稳，且其余仍在运动的球按**能量上界行程**（含碰撞链式接力）不可能再触及任何兴趣球
    ///   时提前结束模拟。保守判据 ⇒ **兴趣球的终态与不早停逐位一致**；代价是其余球的末位可能停在
    ///   「仍在滚动」的中间帧（走位反解不消费它们）。展示用最终模拟必须保持 nil。
    /// - Parameter stopAfterContactBetween: 瞄准评分专用早停（B1）：非 nil 时，两球间**首次碰撞**
    ///   解算并记帧后立即结束。瞄准评分只消费「碰前事件 + 碰后第一帧方向」——碰撞发生 ⇒ 之后的
    ///   演进对评分零贡献，直接截断；碰撞不发生 ⇒ 永不触发，回退整程模拟。评分值与整程逐位一致。
    func simulate(maxEvents: Int = 1000, maxTime: Float = 10.0, highFidelityBounds: Bool = false,
                  earlyStopBallNames: Set<String>? = nil,
                  stopAfterContactBetween: (String, String)? = nil) {
        PerformanceProfiler.begin(ProfilerLabel.simulate)
        defer { PerformanceProfiler.end(ProfilerLabel.simulate) }

        // Run a more thorough initial separation before the first event search.
        // A single pass of 6 iterations is not enough for a densely packed rack where
        // ball positions may carry up to ~16 mm of initial overlap. 50 iterations with
        // a convergence check handles even the worst-case rack layouts.
        separateOverlappingBalls(maxIterations: 50)
        recordSnapshot()
        var eventCount = 0
        var zeroTimeEventStreak = 0
        
        while eventCount < maxEvents && currentTime < maxTime {
            // Find next event
            PerformanceProfiler.begin(ProfilerLabel.findNextEvent)
            let nextEvent = findNextEvent(maxTimeRemaining: maxTime - currentTime)
            PerformanceProfiler.end(ProfilerLabel.findNextEvent)

            guard let nextEvent else {
                // No more events, advance to maxTime
                let dt = maxTime - currentTime
                evolveAllBalls(dt: dt)
                recordSnapshot()
                currentTime = maxTime
                break
            }
            
            // Advance all balls to event time (relative time)
            let dt = nextEvent.time
            guard dt > 0 else {
                // Event at current time or in past, resolve immediately
                zeroTimeEventStreak += 1
                resolveEvent(nextEvent)
                invalidateCache(for: nextEvent)
                recordSnapshot()
                eventCount += 1
                if isContactStopEvent(nextEvent, pair: stopAfterContactBetween) { break }
                
                // 保护：避免连续零时刻事件导致主线程长时间卡死
                if zeroTimeEventStreak > 80 {
                    let nudge = min(0.0005, maxTime - currentTime)
                    if nudge > 0 {
                        evolveAllBalls(dt: nudge)
                        separateOverlappingBalls()
                        currentTime += nudge
                        recordSnapshot()
                    }
                    zeroTimeEventStreak = 0
                }
                continue
            }
            zeroTimeEventStreak = 0

            // 演进步长上限（ADR-P10-06 + P10-07 近库自适应子步）：若到下一事件的 dt 超过安全步长，
            // 先只推进一个安全步、记一帧、作废事件缓存后重新检测，不直接跨大步推进到事件。
            // 安全步长 = `adaptiveEvolveCap`：默认 maxEvolveStep；但若有球正朝某边界逼近（整步内会触墙），
            // 收紧到位移级（nearWallSafeStep/速度）。三重收益：
            //   (a) 漏检的袋口/jaw/喉腔角缝碰撞会在球贴墙时被重新检出（解析线交点落到有限段外的接缝漏检）；
            //   (b) recorder 帧足够密 → 回放 `TrajectoryPlayback.stateAt` 不会在空档里沿旧速度外推穿墙；
            //   (c) `enforceTableBounds` 每子步兜底，把残留越界球在 < nearWallSafeStep 内拉回并记真实帧。
            // 高保真（展示用最终模拟）：近库自适应子步 → 贴墙帧密、回放不外推穿墙。
            // 非高保真（求解器短模拟）：**不切步**（stepCap = +∞）→ 恢复 ADR-P10-06 前速度。
            //   切步本为「显示密帧 + 漏检兜底」而加；求解器只取结果量（进/方向/吃库），且 cueGhostMinDist
            //   已做段内线段-点采样、enforceTableBounds 每步兜底，无需密帧即可正确判结果。
            let stepCap = highFidelityBounds
                ? EngineNumerics.adaptiveEvolveCap(
                    balls: getAllBalls(),
                    minX: tableBounds.minX, maxX: tableBounds.maxX,
                    minZ: tableBounds.minZ, maxZ: tableBounds.maxZ,
                    pockets: tableGeometry.pockets)
                : Float.greatestFiniteMagnitude
            if dt > stepCap {
                evolveAllBalls(dt: stepCap)
                separateOverlappingBalls()
                currentTime += stepCap
                eventCache.clear()   // 从新位置重新检测：捕回从远处漏检/被 no-collision 缓存跳过的碰撞
                recordSnapshot()
                continue
            }

            PerformanceProfiler.begin(ProfilerLabel.evolveAllBalls)
            evolveAllBalls(dt: dt)
            PerformanceProfiler.end(ProfilerLabel.evolveAllBalls)

            separateOverlappingBalls()
            currentTime += dt
            
            // Resolve event
            PerformanceProfiler.begin(ProfilerLabel.resolveEvent)
            resolveEvent(nextEvent)
            PerformanceProfiler.end(ProfilerLabel.resolveEvent)
            
            // Invalidate cache for affected balls
            invalidateCache(for: nextEvent)
            
            // Record snapshot
            recordSnapshot()
            
            eventCount += 1
            
            // 瞄准评分早停（B1）：两具名球首次碰撞已解算并记帧 ⇒ 评分消费量齐备，截断尾部演进。
            if isContactStopEvent(nextEvent, pair: stopAfterContactBetween) { break }
            
            // 提前终止检查（Ref: pooltool event.time == np.inf → done）：
            // 每 8 步检查一次是否所有活动球已 stationary，以避免不必要的碰撞扫描。
            // 这是最主要的加速手段：开球后若球已全部静止，无需继续跑满 15s。
            if eventCount % 8 == 0 {
                let allAtRest = balls.values.allSatisfy { b in
                    b.isPocketed || b.state == .stationary
                }
                if allAtRest {
                    break
                }
                if let interest = earlyStopBallNames, canEarlyStop(interest: interest) {
                    break
                }
            }
        }
    }

    /// 瞄准评分早停判定：本事件是否为 `pair` 两球间的球-球碰撞（无序匹配）。
    private func isContactStopEvent(_ event: PhysicsEvent, pair: (String, String)?) -> Bool {
        guard let (x, y) = pair else { return false }
        if case let .ballBall(a, b) = event.type {
            return (a == x && b == y) || (a == y && b == x)
        }
        return false
    }

    /// 早停保守判据（B1）：兴趣球全部「落袋或线速度归零（stationary/spinning 原地自转）」，
    /// 且其余运动球的**总行程预算**无法触及任何兴趣球。
    ///
    /// 行程预算 = Σ 每球动能上界行程：E/m = v²/2 + (I/m)·ω²/2 = v²/2 + R²ω²/5，全部转成线动能
    /// 后按**最宽松的滚动摩擦**减速可走 E/(μ_roll·g) 米。等质量碰撞 Σv² 不增（e≤1）、吃库只衰减
    /// ⇒ 链式接力的总路径 ≤ 该预算；接力换球每跳最多把「扰动前沿」额外推进 2R ⇒ 松弛量 = 球数·2R。
    /// 判据不满足则继续模拟——绝不改变兴趣球结果，只放弃可证明无关的尾部滚动。
    private func canEarlyStop(interest: Set<String>) -> Bool {
        let r = BallPhysics.radius
        var interestPositions: [SCNVector3] = []
        for name in interest {
            guard let b = balls[name] else { continue }   // 兴趣球不在场（如无该球）不阻塞
            if b.isPocketed { continue }
            guard b.state == .stationary || b.state == .spinning else { return false }
            interestPositions.append(b.position)
        }
        if interestPositions.isEmpty { return true }   // 兴趣球全落袋 ⇒ 命运已定

        var totalBudget: Float = 0
        var minDist = Float.greatestFiniteMagnitude
        var others = 0
        for name in ballOrder {
            guard let b = balls[name], !b.isPocketed, !interest.contains(name) else { continue }
            others += 1
            guard b.state == .sliding || b.state == .rolling else { continue }   // 原地自转不产生位移
            let v2 = b.velocity.x * b.velocity.x + b.velocity.z * b.velocity.z
            let w = b.angularVelocity
            let w2 = w.x * w.x + w.y * w.y + w.z * w.z
            let energyPerMass = v2 / 2 + r * r * w2 / 5
            totalBudget += energyPerMass / (SpinPhysics.rollingFriction * TablePhysics.gravity)
            for p in interestPositions {
                let dx = b.position.x - p.x, dz = b.position.z - p.z
                minDist = min(minDist, sqrtf(dx * dx + dz * dz))
            }
        }
        if totalBudget <= 0 { return true }   // 无运动球（仅原地自转）⇒ 兴趣球安全
        let slack = Float(others) * 2 * r + 0.05
        return totalBudget + slack < minDist - 2 * r
    }
    
    /// Get trajectory recorder
    func getTrajectoryRecorder() -> TrajectoryRecorder {
        return trajectoryRecorder
    }
    
    // MARK: - Private Methods
    
    /// Find the next event to occur
    private func findNextEvent(maxTimeRemaining: Float) -> PhysicsEvent? {
        var candidates: [PhysicsEvent] = []
        
        // Align with pooltool: event detection always uses the remaining simulation horizon.
        // Do not shrink the search window heuristically; aggressive truncation can miss valid
        // later collisions and lead to overlap/penetration artifacts.
        let detectionMaxTime = maxTimeRemaining
        
        // Find next transition events
        for name in ballOrder {
            guard let ball = balls[name] else { continue }
            guard !ball.isPocketed else { continue }
            
            // Check slide-to-roll transition
            if ball.state == .sliding {
                let transitionType = "slideToRoll"
                if let cached = eventCache.getTransition(ball: name, transitionType: transitionType, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.slideToRollTime(
                        velocity: ball.velocity,
                        angularVelocity: ball.angularVelocity
                    )
                    if transitionTime > 0 && transitionTime <= detectionMaxTime {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .sliding, toState: .rolling),
                            time: transitionTime,
                            priority: 2
                        )
                        eventCache.setTransition(ball: name, transitionType: transitionType, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
            
            // Check roll-to-spin transition
            if ball.state == .rolling {
                let transitionType = "rollToSpin"
                if let cached = eventCache.getTransition(ball: name, transitionType: transitionType, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.rollToSpinTime(velocity: ball.velocity)
                    if transitionTime > 0 && transitionTime <= detectionMaxTime {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .rolling, toState: .spinning),
                            time: transitionTime,
                            priority: 2
                        )
                        eventCache.setTransition(ball: name, transitionType: transitionType, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
            
            // Check spin-to-stationary transition
            if ball.state == .spinning {
                let transitionType = "spinToStationary"
                if let cached = eventCache.getTransition(ball: name, transitionType: transitionType, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.spinToStationaryTime(angularVelocity: ball.angularVelocity)
                    if transitionTime > 0 && transitionTime <= detectionMaxTime {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .spinning, toState: .stationary),
                            time: transitionTime,
                            priority: 2
                        )
                        eventCache.setTransition(ball: name, transitionType: transitionType, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
        }
        
        // Find ball-ball collisions
        PerformanceProfiler.begin(ProfilerLabel.ballBallDetect)
        let ballNames = ballOrder
        for i in 0..<ballNames.count {
            for j in (i+1)..<ballNames.count {
                let nameA = ballNames[i]
                let nameB = ballNames[j]
                
                guard let ballA = balls[nameA], let ballB = balls[nameB] else { continue }
                guard !ballA.isPocketed && !ballB.isPocketed else { continue }
                
                // 已接触/重叠时立即触发一次碰撞，避免“穿透后只带走一点”
                if EngineNumerics.isBallPairOverlappingOrTouching(ballA, ballB) {
                    let immediate = PhysicsEvent(
                        type: .ballBall(ballA: nameA, ballB: nameB),
                        time: 0,
                        priority: -1
                    )
                    candidates.append(immediate)
                    continue
                }
                
                // 运动学剪裁（Ref: pooltool solve.py skip_ball_ball_collision）：
                // 两球均不平动（stationary/spinning）时不产生碰撞，与 pooltool nontranslating 判断一致。
                // 注意：此处不做空间距离裁剪和方向裁剪——这类裁剪曾导致合法碰撞漏检，
                // 改由四次方程求解器（maxTime 截断）处理无效球对，保证正确性。
                let aIsNontranslating = ballA.state == .stationary || ballA.state == .spinning
                let bIsNontranslating = ballB.state == .stationary || ballB.state == .spinning
                if aIsNontranslating && bIsNontranslating {
                    continue
                }

                // Negative cache check（Ref: pooltool cache[pair] = np.inf）：
                // 已确认此球对在当前运动状态下不会碰撞，直接跳过
                if eventCache.isBallBallNoCollision(ballA: nameA, ballB: nameB,
                                                    stateA: ballA.state, stateB: ballB.state,
                                                    currentTime: currentTime) {
                    continue
                }
                
                // Check cache first
                if let cached = eventCache.getBallBall(ballA: nameA, ballB: nameB, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                    continue
                }
                
                // Compute acceleration for each ball based on state
                let aA = EngineNumerics.acceleration(for: ballA)
                let aB = EngineNumerics.acceleration(for: ballB)
                
                // Find collision time
                if let collisionTime = CollisionDetector.ballBallCollisionTime(
                    p1: ballA.position,
                    p2: ballB.position,
                    v1: ballA.velocity,
                    v2: ballB.velocity,
                    a1: aA,
                    a2: aB,
                    R: Double(BallPhysics.radius),
                    maxTime: Double(detectionMaxTime)
                ) {
                    let event = PhysicsEvent(
                        type: .ballBall(ballA: nameA, ballB: nameB),
                        time: collisionTime,
                        priority: 3
                    )
                    eventCache.setBallBall(ballA: nameA, ballB: nameB, event: event, currentTime: currentTime)
                    candidates.append(event)
                } else if EngineNumerics.shouldRunFallbackBallBallCheck(
                    ballA: ballA,
                    ballB: ballB,
                    aA: aA,
                    aB: aB,
                    maxTime: detectionMaxTime
                ), let fallbackTime = EngineNumerics.fallbackBallBallCollisionTime(
                    ballA: ballA,
                    ballB: ballB,
                    aA: aA,
                    aB: aB,
                    maxTime: detectionMaxTime
                ) {
                    // Quartic missed but discrete fallback found collision.
                    let dist = (ballB.position - ballA.position).length()
                    let event = PhysicsEvent(
                        type: .ballBall(ballA: nameA, ballB: nameB),
                        time: fallbackTime,
                        priority: 3
                    )
                    eventCache.setBallBall(ballA: nameA, ballB: nameB, event: event, currentTime: currentTime)
                    candidates.append(event)
                } else {
                    // 四次方程和 fallback 均未找到碰撞 → 写入 negative cache（Ref: pooltool np.inf 标记）
                    // 下次同一球对直接跳过，无需重新计算（仅对静止/自旋球对有效，见 isBallBallNoCollision）
                    eventCache.setBallBallNoCollision(ballA: nameA, ballB: nameB,
                                                     stateA: ballA.state, stateB: ballB.state,
                                                     currentTime: currentTime)
                }
            }
        }
        PerformanceProfiler.end(ProfilerLabel.ballBallDetect)
        
        // Find ball-cushion collisions
        PerformanceProfiler.begin(ProfilerLabel.cushionDetect)
        for name in ballOrder {
            guard let ball = balls[name] else { continue }
            guard !ball.isPocketed else { continue }
            
            let a = EngineNumerics.acceleration(for: ball)
            
            // Check linear cushions
            for (index, cushion) in tableGeometry.linearCushions.enumerated() {
                // Negative cache check：已知此球-直线库组合不会碰撞，直接跳过
                // Check cache first
                if let cached = eventCache.getBallCushion(ball: name, cushionIndex: index, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                    continue
                }
                
                // Compute line offset (distance from origin along normal)
                let lineOffset = Double(cushion.normal.dot(cushion.start))
                
                if let collisionTime = CollisionDetector.ballLinearCushionTime(
                    p: ball.position,
                    v: ball.velocity,
                    a: a,
                    lineNormal: cushion.normal,
                    lineOffset: lineOffset,
                    R: Double(BallPhysics.radius),
                    maxTime: Double(detectionMaxTime)
                ) {
                    // Convert infinite-line hit into finite-segment hit.
                    let collisionPos = ball.position
                        + ball.velocity * collisionTime
                        + a * (0.5 * collisionTime * collisionTime)
                    
                    if EngineNumerics.isWithinLinearCushionSegment(point: collisionPos, segment: cushion) {
                        let event = PhysicsEvent(
                            type: .ballCushion(ball: name, cushionIndex: index, normal: cushion.normal),
                            time: collisionTime,
                            priority: 3
                        )
                        eventCache.setBallCushion(ball: name, cushionIndex: index, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
        }
        
        // Find ball-circular-cushion collisions (pocket jaw arcs)
        let linearCount = tableGeometry.linearCushions.count
        for name in ballOrder {
            guard let ball = balls[name] else { continue }
            guard !ball.isPocketed else { continue }
            
            let a = EngineNumerics.acceleration(for: ball)
            
            for (arcIdx, arc) in tableGeometry.circularCushions.enumerated() {
                let cushionIndex = linearCount + arcIdx
                
                if let cached = eventCache.getBallCushion(ball: name, cushionIndex: cushionIndex, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                    continue
                }
                
                if let collisionTime = CollisionDetector.ballCircularCushionTime(
                    p: ball.position,
                    v: ball.velocity,
                    a: a,
                    arc: arc,
                    R: BallPhysics.radius,
                    maxTime: Double(detectionMaxTime),
                    pockets: tableGeometry.pockets
                ) {
                    let t = collisionTime
                    let posAtT = ball.position + ball.velocity * t + a * (0.5 * t * t)
                    let normal = arc.normal(at: posAtT)
                    
                    let event = PhysicsEvent(
                        type: .ballCushion(ball: name, cushionIndex: cushionIndex, normal: normal),
                        time: collisionTime,
                        priority: 3
                    )
                    eventCache.setBallCushion(ball: name, cushionIndex: cushionIndex, event: event, currentTime: currentTime)
                    candidates.append(event)
                }
            }
        }
        
        // Find ball-pocket events (CCD quartic solve, XZ-plane only)
        // 注意：必须使用 XZ 2D 分量，不含 Y（球心 Y 恒高于台面，3D 距离永远够不到孔圈半径）。
        // 判据（ADR-P10-09）：球心水平投影抵达孔圈（dist = pocket.radius，即真实落袋孔半径）
        // ⇒ 台面失去支撑 ⇒ 落袋。无速度/方向特判——能否抵达孔圈完全由 jaw/圆角/喉壁物理决定。
        for name in ballOrder {
            guard let ball = balls[name] else { continue }
            guard !ball.isPocketed else { continue }
            
            let a = EngineNumerics.acceleration(for: ball)
            
            // Check each pocket
            for pocket in tableGeometry.pockets {
                let r = pocket.radius

                // XZ-only: 袋口检测在水平面进行，忽略 Y 轴高度差
                let dpX = ball.position.x - pocket.center.x
                let dpZ = ball.position.z - pocket.center.z
                let dvX = ball.velocity.x
                let dvZ = ball.velocity.z
                let daX = a.x
                let daZ = a.z

                let halfDaX = daX * 0.5
                let halfDaZ = daZ * 0.5

                let halfDaDotHalfDa = Double(halfDaX * halfDaX + halfDaZ * halfDaZ)
                let dvDotHalfDa    = Double(dvX * halfDaX + dvZ * halfDaZ)
                let dvDotDv        = Double(dvX * dvX + dvZ * dvZ)
                let dpDotHalfDa    = Double(dpX * halfDaX + dpZ * halfDaZ)
                let dpDotDv        = Double(dpX * dvX + dpZ * dvZ)
                let dpDotDp        = Double(dpX * dpX + dpZ * dpZ)

                let a4 = halfDaDotHalfDa
                let a3 = 2.0 * dvDotHalfDa
                let a2 = dvDotDv + 2.0 * dpDotHalfDa
                let a1 = 2.0 * dpDotDv
                let a0 = dpDotDp - Double(r * r)

                let roots = QuarticSolver.solveQuartic(a: a4, b: a3, c: a2, d: a1, e: a0)
                if let time = EngineNumerics.smallestPositiveRoot(roots, maxTime: detectionMaxTime) {
                    candidates.append(PhysicsEvent(
                        type: .pocket(ball: name, pocketId: pocket.id),
                        time: time,
                        priority: 2
                    ))
                }
            }
        }
        PerformanceProfiler.end(ProfilerLabel.cushionDetect)
        
        // Return earliest event
        return candidates.min()
    }
    
    /// Evolve all balls forward by dt
    private func evolveAllBalls(dt: Float) {
        for name in ballOrder {
            guard let ball = balls[name] else { continue }
            guard !ball.isPocketed else { continue }
            
            let evolved: (position: SCNVector3, velocity: SCNVector3, angularVelocity: SCNVector3)
            
            switch ball.state {
            case .sliding:
                evolved = AnalyticalMotion.evolveSliding(
                    position: ball.position,
                    velocity: ball.velocity,
                    angularVelocity: ball.angularVelocity,
                    dt: dt
                )
            case .rolling:
                evolved = AnalyticalMotion.evolveRolling(
                    position: ball.position,
                    velocity: ball.velocity,
                    angularVelocity: ball.angularVelocity,
                    dt: dt
                )
            case .spinning:
                let result = AnalyticalMotion.evolveSpinning(
                    position: ball.position,
                    angularVelocity: ball.angularVelocity,
                    dt: dt
                )
                evolved = (result.position, ball.velocity, result.angularVelocity)
            case .stationary, .pocketed:
                // No evolution
                continue
            }
            
            var nextState = BallState(
                position: evolved.position,
                velocity: evolved.velocity,
                angularVelocity: evolved.angularVelocity,
                state: ball.state,
                name: ball.name
            )

            enforceTableBounds(for: &nextState)
            balls[name] = nextState
        }
    }

    /// 修正重叠球，减少"穿插后无碰撞"的数值死区
    private func separateOverlappingBalls(maxIterations: Int = 6) {
        let names = ballOrder
        guard names.count >= 2 else { return }
        let twoR = 2 * BallPhysics.radius
        // Trigger only when balls genuinely penetrate (d < 2R).
        // Use (2R)² as the detection threshold to avoid treating make_kiss clearance as overlap.
        let triggerDistSq = twoR * twoR
        // Push to 2R + spacer so after separation d > 2R, preventing Float32 boundary oscillation
        // where d² = (2R)² - epsilon triggers another iteration.
        let spacer: Float = 3e-5   // 0.03 mm clearance beyond 2R
        let targetDist = twoR + spacer

        for _ in 0..<maxIterations {
            var adjusted = false
            
            for i in 0..<(names.count - 1) {
                for j in (i + 1)..<names.count {
                    let aName = names[i]
                    let bName = names[j]
                    guard var a = balls[aName], var b = balls[bName] else { continue }
                    if a.isPocketed || b.isPocketed { continue }
                    
                    let delta = b.position - a.position
                    let d2 = delta.x * delta.x + delta.z * delta.z
                    // Only act on genuine penetration (d < 2R), not on spacer clearance.
                    if d2 >= triggerDistSq { continue }
                    
                    let dist = sqrtf(max(d2, 1e-12))
                    let nx: Float
                    let nz: Float
                    if dist < 1e-6 {
                        nx = 1
                        nz = 0
                    } else {
                        nx = delta.x / dist
                        nz = delta.z / dist
                    }
                    // Compute push needed to reach targetDist (2R + spacer).
                    let push = (targetDist - max(dist, 1e-6)) * 0.5

                    let move = SCNVector3(nx * push, 0, nz * push)
                    
                    a.position = a.position - move
                    b.position = b.position + move
                    // Do NOT call enforceTableBounds here: it can pull a ball back into
                    // overlap range, causing the loop to never converge.
                    
                    balls[aName] = a
                    balls[bName] = b
                    // Invalidate cache for this pair so the next findNextEvent re-solves
                    // their quartic rather than using a stale no-collision or positive entry.
                    eventCache.invalidateBallPair(ballA: aName, ballB: bName)
                    adjusted = true
                }
            }
            
            if !adjusted { break }
        }
    }

    /// 最终静止摆位重叠清理（#4）：球形生成器把开球结果作为「可编辑摆位」输出前调用，
    /// 消除偶发的「停稳后两球轻微穿插」。纯几何分离——只沿球心连线把穿插球对推到
    /// 2R+spacer，不改速度、不触发落袋、不做边界钳制（避免把球误推进袋或来回震荡）。
    /// 多迭代确保收敛（停稳态位移均为亚毫米，对画面无感）。
    func resolveRestingOverlaps(maxIterations: Int = 16) {
        separateOverlappingBalls(maxIterations: maxIterations)
    }

    /// 兜底边界约束：防止极端数值误差导致球“跑出台外”
    private func enforceTableBounds(for state: inout BallState) {
        guard !state.isPocketed else { return }
        
        let safeMinX = tableBounds.minX + BallPhysics.radius
        let safeMaxX = tableBounds.maxX - BallPhysics.radius
        let safeMinZ = tableBounds.minZ + BallPhysics.radius
        let safeMaxZ = tableBounds.maxZ - BallPhysics.radius

        // 触发余量（FL 根因修复·吃库竞态，2026-06-12）：库线吃库时球心接触位置 **恰好等于**
        // safe 边界（contact = 库线 ∓ R），CCD 把球精确演进到接触点时浮点噪声可落在边界外
        // ~1e-6 m。该状态是「正要解析的合法吃库」而非「跑出台外」；零容差硬钳会抢在事件前
        // 把法向速度减半反向，随后 Han 解析器按（已退离的）速度方向翻转接触系、把球再次
        // 反射回库内——形成「以 ~2 折出射角贴库滑出」的非物理轨迹（S4 数值确证：入29° 实测
        // 出射 131°，手动复算应为 27°）。真正的接缝漏出会逐子步继续向外推进（近库子步位移
        // 上限 ~10mm/步），远超此余量，安全网兜底能力不受影响。
        let boundsEpsilon: Float = 5e-4   // 0.5mm ≫ Float32 接触噪声(~1e-6 m)，≪ 漏出位移(mm 级)

        let outX = state.position.x < safeMinX - boundsEpsilon || state.position.x > safeMaxX + boundsEpsilon
        let outZ = state.position.z < safeMinZ - boundsEpsilon || state.position.z > safeMaxZ + boundsEpsilon
        guard outX || outZ else { return }
        
        // 球已越出可玩框、且落在某袋口附近（`pocket.radius + 3R` 内，覆盖袋嘴→袋兜全通道）。
        for pocket in tableGeometry.pockets {
            let dx = state.position.x - pocket.center.x
            let dz = state.position.z - pocket.center.z
            let dist = sqrtf(dx * dx + dz * dz)
            guard dist < pocket.radius + BallPhysics.radius * 3 else { continue }

            // ① 球心已入孔圈（数值漏检兜底，正常路径由 CCD .pocket 事件收袋）→ 落袋。
            if dist <= pocket.radius {
                state.state = .pocketed
                state.velocity = SCNVector3Zero
                state.angularVelocity = SCNVector3Zero
                // 记一次真实落袋事件，使下游 `pottedSelected`（扫 resolvedEvents 的 .pocket）与画面一致。
                resolvedEvents.append(.pocket(ball: state.name, pocketId: pocket.id))
                resolvedEventTimes.append(currentTime)
                return
            }
            // ② 在袋口通道内（孔圈外）：无论速度/朝向均放行（ADR-P10-09）——
            //    rattle 弹出、慢速滑向孔圈、以及**球心停在孔圈外的合法挂袋**都交给真实几何
            //    （jaw 弧/面 + 喉壁 + 孔圈判据）处理。旧「低速即收袋」特判会把挂袋球吸走，已删除。
            return
        }

        // ④ jaw 弧合法接触带豁免（FL 根因修复，2026-06-12）：
        //    圆弧库（角袋 jaw 弧 / 中袋 fillet）的球心接触圆（r_arc + R）**伸出矩形可玩框**
        //    最多数厘米（越靠袋心越多；如左下角弧在 352° 接触点比 safeMinX 深 ~1.3mm）。
        //    球落在任一弧的角度扇区内、且距弧心 ≤ 接触距 + mouthSlack 时，说明它正与该弧
        //    交互（CCD 已能正确检出并解析），真实边界是弧本身——矩形硬钳在此不适用。
        //    不豁免则硬钳抢在已调度的弧碰撞事件之前触发（法向减半反弹、无事件、不作废缓存），
        //    产生「贴库平行滑出 + 末端小钩」的幽灵反弹。
        //    mouthSlack 覆盖逼近条带：略大于近库子步位移上限 nearWallSafeStep（~10mm）。
        //    径向速度门控（防研磨）：只豁免**径向显著运动**（正撞向弧面→弧事件即将解析；
        //    或刚反弹离开→毫秒级回到框内）的球。沿弧切向蹭行（|vr|≈0，如贴长库滚过中袋
        //    fillet 区）不豁免——该状态下弧 CCD 会以微小 dt 反复出事件（zero-time 风暴），
        //    解算器数千次短模拟被拖垮；维持原软钳把它压回框内即可。
        let mouthSlack: Float = 0.012
        let radialGate: Float = 0.02   // m/s
        for arc in tableGeometry.circularCushions {
            let dxA = state.position.x - arc.center.x
            let dzA = state.position.z - arc.center.z
            let dA = sqrtf(dxA * dxA + dzA * dzA)
            guard dA > 1e-6, dA <= arc.radius + BallPhysics.radius + mouthSlack else { continue }
            guard arc.isAngleInRange(atan2f(dzA, dxA)) else { continue }
            let vr = (state.velocity.x * dxA + state.velocity.z * dzA) / dA
            if abs(vr) > radialGate { return }
        }
        // 不在任何袋嘴通道/弧接触带内（或正从接缝漏出）→ 硬钳回库线 + 反弹（数值安全网）。
        
        // Not near any pocket — hard clamp (numerical safety net)
        let restitution: Float = 0.5
        
        if state.position.x < safeMinX {
            state.position.x = safeMinX
            state.velocity.x = abs(state.velocity.x) * restitution
        } else if state.position.x > safeMaxX {
            state.position.x = safeMaxX
            state.velocity.x = -abs(state.velocity.x) * restitution
        }
        
        if state.position.z < safeMinZ {
            state.position.z = safeMinZ
            state.velocity.z = abs(state.velocity.z) * restitution
        } else if state.position.z > safeMaxZ {
            state.position.z = safeMaxZ
            state.velocity.z = -abs(state.velocity.z) * restitution
        }
        
        state.state = EngineNumerics.determineMotionState(state)
        // 硬钳是事件流之外的状态突变：作废该球缓存，避免按钳前轨迹预测的陈旧事件
        // （吃库/球球）在钳后接力触发，造成二次非物理反射。
        eventCache.invalidate(affectedBalls: [state.name])
    }
    
    /// Resolve a physics event
    private func resolveEvent(_ event: PhysicsEvent) {
        if case .ballBall = event.type, firstBallBallCollisionTime == nil {
            firstBallBallCollisionTime = event.time
        }
        
        switch event.type {
        case .ballBall(let ballA, let ballB):
            resolveBallBallCollision(ballA: ballA, ballB: ballB)
            resolvedEvents.append(event.type)
            resolvedEventTimes.append(currentTime)
            
        case .ballCushion(let ball, let cushionIndex, let normal):
            // 仅在冲量真正施加时记录事件（与 .pocket 同模式）：被「只推不拉」护栏跳过的
            // 过时事件不计入吃库数，避免下游（吃库计数/回放）看到未发生的碰撞。
            let applied = resolveBallCushionCollision(ball: ball, cushionIndex: cushionIndex, normal: normal)
            if applied {
                resolvedEvents.append(event.type)
                resolvedEventTimes.append(currentTime)
            }
            
        case .transition(let ball, let fromState, let toState):
            resolveTransition(ball: ball, fromState: fromState, toState: toState)
            resolvedEvents.append(event.type)
            resolvedEventTimes.append(currentTime)
            
        case .pocket(let ball, let pocketId):
            // Record the event only if the ball was actually pocketed.
            // Previously events were recorded before resolution, causing game-rule layers
            // to see false pockets when resolvePocket's suspicious-pocket guard rejected the event.
            let pocketed = resolvePocket(ball: ball, pocketId: pocketId)
            if pocketed {
                resolvedEvents.append(event.type)
                resolvedEventTimes.append(currentTime)
            }
        }
    }
    
    /// Resolve ball-ball collision using pure computation
    private func resolveBallBallCollision(ballA: String, ballB: String) {
        guard var stateA = balls[ballA], var stateB = balls[ballB] else { return }
        guard !stateA.isPocketed && !stateB.isPocketed else { return }
        
        // Ref: pooltool/physics/resolve/ball_ball/core.py CoreBallBallCollision.make_kiss
        // Precisely position both balls at 2R + MIN_DIST separation before resolving
        // the collision impulse. Without this, floating-point drift from event evolution
        // leaves the balls slightly interpenetrating, causing cascading zero-time events.
        EngineNumerics.makeBallBallKiss(stateA: &stateA, stateB: &stateB)
        
        let result = CollisionResolver.resolveBallBallPure(
            posA: stateA.position,
            posB: stateB.position,
            velA: stateA.velocity,
            velB: stateB.velocity,
            angVelA: stateA.angularVelocity,
            angVelB: stateB.angularVelocity
        )
        
        stateA.velocity = result.velA
        stateA.angularVelocity = result.angVelA
        stateB.velocity = result.velB
        stateB.angularVelocity = result.angVelB
        
        stateA.state = EngineNumerics.determineMotionState(stateA)
        stateB.state = EngineNumerics.determineMotionState(stateB)
        
        balls[ballA] = stateA
        balls[ballB] = stateB
    }
    
    /// Resolve ball-cushion collision using pure computation.
    /// 完整解算编排已抽至 `EngineNumerics.resolveCushionImpact`（B3 单一真源，
    /// 引擎与 `AnalyticShotRollout` 共用）；此处仅做引擎状态表的读写包装。
    /// - Returns: `true` 当冲量真正施加；`false` 当事件因球已退离库面而被跳过。
    @discardableResult
    private func resolveBallCushionCollision(ball: String, cushionIndex: Int, normal: SCNVector3) -> Bool {
        guard var state = balls[ball] else { return false }
        guard !state.isPocketed else { return false }
        let applied = EngineNumerics.resolveCushionImpact(
            state: &state, cushionIndex: cushionIndex, normal: normal, geometry: tableGeometry)
        guard applied else { return false }
        balls[ball] = state
        return true
    }
    
    /// Resolve state transition
    private func resolveTransition(ball: String, fromState: BallMotionState, toState: BallMotionState) {
        guard var state = balls[ball] else { return }
        guard state.state == fromState else { return }
        
        state.state = toState
        
        // When transitioning to rolling, ensure angular velocity matches rolling condition
        if toState == .rolling {
            let up = SCNVector3(0, 1, 0)
            let wRolling = up.cross(state.velocity) * (1.0 / BallPhysics.radius)
            state.angularVelocity = SCNVector3(wRolling.x, state.angularVelocity.y, wRolling.z)
        }
        
        // When transitioning to spinning, zero linear velocity
        if toState == .spinning {
            state.velocity = SCNVector3Zero
        }
        
        // When transitioning to stationary, zero everything
        if toState == .stationary {
            state.velocity = SCNVector3Zero
            state.angularVelocity = SCNVector3Zero
        }
        
        balls[ball] = state
    }
    
    /// Resolve pocket event. Returns true if the ball was actually pocketed, false if rejected.
    @discardableResult
    private func resolvePocket(ball: String, pocketId: String) -> Bool {
        guard var state = balls[ball] else { return false }
        
        // 落袋判据（ADR-P10-09，XZ 2D）：球心水平投影进入孔圈（dist ≤ 孔半径）⇒ 台面无法再
        // 提供支撑 ⇒ 必然坠落。CCD 已把球精确演进到孔圈交点，这里只校验事件未过时
        // （排定后状态被改写的陈旧事件按超距拒绝），无任何速度/方向特判。
        if let pocket = tableGeometry.pockets.first(where: { $0.id == pocketId }) {
            let dx = state.position.x - pocket.center.x
            let dz = state.position.z - pocket.center.z
            let dist = sqrtf(dx * dx + dz * dz)
            // 2mm 容差 ≫ 浮点接触噪声，≪ 任何真实位移——只挡陈旧事件，不挡合法入圈。
            if dist > pocket.radius + 0.002 {
                return false
            }
            // 记录位置吸附到袋心：使轨迹终点明确「进洞」，下游（橙线终点/回放入洞段起点
            // 取进袋前一帧真实位置）与画面一致。
            state.position = SCNVector3(pocket.center.x, state.position.y, pocket.center.z)
        }
        state.state = .pocketed
        state.velocity = SCNVector3Zero
        state.angularVelocity = SCNVector3Zero
        
        balls[ball] = state
        return true
    }
    
    /// Invalidate cache for affected balls in an event
    private func invalidateCache(for event: PhysicsEvent) {
        var affectedBalls: Set<String> = []
        
        switch event.type {
        case .ballBall(let ballA, let ballB):
            affectedBalls.insert(ballA)
            affectedBalls.insert(ballB)
        case .ballCushion(let ball, _, _):
            affectedBalls.insert(ball)
        case .transition(let ball, _, _):
            affectedBalls.insert(ball)
        case .pocket(let ball, _):
            affectedBalls.insert(ball)
        }
        
        eventCache.invalidate(affectedBalls: affectedBalls)
    }
    
    /// Record current state snapshot to trajectory recorder
    private func recordSnapshot() {
        for name in ballOrder {
            guard let ball = balls[name] else { continue }
            let frame = BallFrame(
                time: currentTime,
                position: ball.position,
                velocity: ball.velocity,
                angularVelocity: SCNVector4(ball.angularVelocity.x, ball.angularVelocity.y, ball.angularVelocity.z, 0),
                state: ball.state
            )
            trajectoryRecorder.recordFrame(ballName: name, frame: frame)
        }
    }
}
