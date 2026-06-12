//
//  EngineNumerics.swift
//  QiuJi
//
//  事件驱动引擎的**纯数值/运动学辅助**（D-A1 第三梯队：从 1700+ 行的 `EventDrivenEngine`
//  巨型文件中抽出「数值安全网 + 运动学」一块）。这些函数**不持有引擎状态**——只依赖入参与
//  物理常量，故可脱离引擎实例独立单测（满足 D-A1「各自可独立单测」目标）。
//
//  内容：
//  - 运动学：`acceleration(for:)` / `determineMotionState(_:)`
//  - 数值安全网（make-kiss 精确贴合，Ref pooltool）：`makeBallBallKiss` / `makeBallCushionKiss`
//  - 几何谓词：`closestPointOnSegmentXZ` / `isWithinLinearCushionSegment` / `isBallPairOverlappingOrTouching`
//  - 回退碰撞检测（quartic 漏检兜底）：`shouldRunFallbackBallBallCheck` / `fallbackBallBallCollisionTime`
//  - 求根：`smallestPositiveRoot`
//
//  行为与原 `EventDrivenEngine` 私有方法**逐字一致**——本次仅做位置迁移 + 命名空间化，
//  不改任何数值或逻辑。
//

import SceneKit

enum EngineNumerics {

    // MARK: - 演进步长上限（ADR-P10-06）

    /// 单次解析演进的最大时间步长（秒）。事件间 dt 超过此值时，引擎只推进一个上限步并重新检测
    /// 事件（见 `EventDrivenEngine.simulate`）。作用：避免一次跨大步演进跳过从远处漏检的袋口/jaw
    /// 碰撞、并保证 recorder 帧足够密以使回放轨迹保真（不在长空档里外推出台面）。
    /// 取值权衡：越小越保真/越能捕回漏检，但子步越多越慢；0.05s 下贴库速度球单步位移 <~0.3m，
    /// 配合 `enforceTableBounds` 足以把越界球在出界 <~一个球径内拉回。
    static let maxEvolveStep: Float = 0.05

    // MARK: - 近库自适应子步（ADR-P10-07，Option A 连续碰撞兜底）

    /// 球**逼近任一边界特征**（库线 / 袋口落孔）时，单子步允许的最大**球面位移**（米）。
    /// 仅在球确实朝某墙逼近、且一个整 `maxEvolveStep` 步内就会触及时才生效（见 `adaptiveEvolveCap`），
    /// 把"漏检碰撞被大步跨过"导致的穿墙位移压到此量级——已检出的碰撞仍精确演进到接触点（越界=0），
    /// 此值只是**漏检接缝**（喉腔角缝 / 自旋滑行曲线轨迹令解析线交点落到有限段外）的兜底上限。
    /// 取 0.35R ≈ 10mm：< 显示越界护栏的 20mm 余量，且远大于浮点抖动，避免无谓细分拖慢。
    static let nearWallSafeStep: Float = 0.35 * BallPhysics.radius

    /// 球已越出可玩框、落在袋口 jaw 区内、且速度低于此阈值（m/s）时，引擎视其为"挂袋后 settle 落下/
    /// 母球 scratch"直接收袋（见 `EventDrivenEngine.enforceTableBounds`）。封堵"慢速球从库段↔jaw 接缝
    /// 漏到 jaw 死区静止于台外"的几何缝。取值远低于 `pocketDropSpeed`(1.05)：仅对真正 trickle/将停的球
    /// 生效，不误收带速 rattle 球（后者由喉腔壁弹出/弹进，保住"大力反复弹 jaw 弹出"的真实物理）。
    static let jawSettlePocketSpeed: Float = 0.35

    /// 计算当前球态下安全的演进步长上限（秒）：默认 `maxEvolveStep`，但若任一运动球**正朝某边界
    /// 逼近**（沿该墙法向的靠近速度 > 0，且一个整步内即会触及），则把步长压到 `nearWallSafeStep / 速度`，
    /// 使该球贴墙前帧足够密、漏检碰撞在贴墙时被重新检出、且回放无法沿旧速度外推穿墙。
    ///
    /// **只惩罚逼近运动**——沿库平行滚动 / 远离墙的球 closing≤0，不触发细分（保住贴库走位性能）。
    /// 纯由球态 + 几何决定，确定性。
    static func adaptiveEvolveCap(
        balls: [BallState],
        minX: Float, maxX: Float, minZ: Float, maxZ: Float,
        pockets: [Pocket]
    ) -> Float {
        let R = BallPhysics.radius
        let floorDt: Float = 3e-4
        var cap = maxEvolveStep
        for ball in balls {
            guard !ball.isPocketed, ball.state != .stationary, ball.state != .spinning else { continue }
            let vx = ball.velocity.x, vz = ball.velocity.z
            let s = sqrtf(vx * vx + vz * vz)
            guard s > 1e-4 else { continue }

            // 某边界：clearance = 球面到墙的间隙；closing = 沿"减小 clearance"方向的速度分量。
            // 仅当 closing>0（逼近）且 clearance/closing < maxEvolveStep（整步内会触及）时收紧步长。
            func consider(clearance: Float, closing: Float) {
                guard closing > 1e-4 else { return }
                let tHit = clearance / closing
                if tHit < maxEvolveStep {
                    cap = min(cap, max(nearWallSafeStep / s, floorDt))
                }
            }
            // 四条外库（轴对齐）。
            consider(clearance: (maxX - R) - ball.position.x, closing: vx)
            consider(clearance: ball.position.x - (minX + R), closing: -vx)
            consider(clearance: (maxZ - R) - ball.position.z, closing: vz)
            consider(clearance: ball.position.z - (minZ + R), closing: -vz)
            // 六个袋口落孔（径向逼近）。
            for p in pockets {
                let dx = ball.position.x - p.center.x
                let dz = ball.position.z - p.center.z
                let d = sqrtf(dx * dx + dz * dz)
                guard d > 1e-5 else { cap = min(cap, max(nearWallSafeStep / s, floorDt)); continue }
                consider(clearance: d - p.radius, closing: -(vx * dx + vz * dz) / d)
            }
        }
        return max(cap, floorDt)
    }

    // MARK: - 运动学

    /// Compute acceleration for a ball based on its state
    static func acceleration(for ball: BallState) -> SCNVector3 {
        switch ball.state {
        case .sliding:
            // Sliding friction acts in the direction of surface velocity, not linear velocity
            let relVel = AnalyticalMotion.surfaceVelocity(
                linear: ball.velocity,
                angular: ball.angularVelocity,
                radius: BallPhysics.radius
            )
            let relSpeed = relVel.length()
            guard relSpeed > 0.001 else { return SCNVector3Zero }
            let uHat = relVel.normalized()
            let decel = SpinPhysics.slidingFriction * TablePhysics.gravity
            return -uHat * decel
        case .rolling:
            let speed = ball.velocity.length()
            guard speed > 0.001 else { return SCNVector3Zero }
            let vHat = ball.velocity.normalized()
            let decel = SpinPhysics.rollingFriction * TablePhysics.gravity
            return -vHat * decel
        case .spinning, .stationary, .pocketed:
            return SCNVector3Zero
        }
    }

    /// Determine motion state from ball kinematics
    static func determineMotionState(_ ball: BallState) -> BallMotionState {
        if ball.isPocketed {
            return .pocketed
        }

        let speed = ball.velocity.length()
        let relVel = AnalyticalMotion.surfaceVelocity(
            linear: ball.velocity,
            angular: ball.angularVelocity,
            radius: BallPhysics.radius
        )
        let relSpeed = relVel.length()

        if speed < 0.001 && abs(ball.angularVelocity.y) < 0.001 {
            return .stationary
        } else if relSpeed > 0.001 {
            return .sliding
        } else if speed > 0.001 {
            return .rolling
        } else if abs(ball.angularVelocity.y) > 0.001 {
            return .spinning
        } else {
            return .stationary
        }
    }

    // MARK: - 数值安全网（make-kiss）

    /// Precisely positions two balls at exactly 2R + MIN_DIST separation before impulse resolution.
    ///
    /// Ref: pooltool/physics/resolve/ball_ball/core.py CoreBallBallCollision.make_kiss
    ///
    /// Primary method: solve a quadratic for the time offset δt that achieves the target
    /// separation, then shift both balls by δt along their current velocities (acceleration
    /// is negligible for the small offsets involved).
    /// Fallback: when both balls are non-translating or the quadratic solution shifts the
    /// contact midpoint by more than 5× MIN_DIST, push each ball symmetrically along the
    /// line of centers.
    static func makeBallBallKiss(stateA: inout BallState, stateB: inout BallState) {
        let spacer: Float = 1e-5  // MIN_DIST equivalent for ball-ball contact
        let targetDist = 2 * BallPhysics.radius + spacer

        let delta = stateB.position - stateA.position
        let dist = delta.length()

        // Fast-path: already at or beyond target separation, nothing to do.
        if dist >= targetDist { return }

        let n: SCNVector3
        if dist > 1e-6 {
            n = delta * (1.0 / dist)
        } else {
            n = SCNVector3(1, 0, 0)
        }

        let aIsNontranslating = stateA.velocity.length() < 1e-6
        let bIsNontranslating = stateB.velocity.length() < 1e-6

        if aIsNontranslating && bIsNontranslating {
            // Both stationary: push symmetrically along line of centers (fallback).
            let push = (targetDist - dist) * 0.5
            stateA.position = stateA.position - n * push
            stateB.position = stateB.position + n * push
            return
        }

        // Quadratic solve: find δt such that |dr + dv·δt|² = targetDist²
        // where dr = rB - rA, dv = vB - vA
        let dv = stateB.velocity - stateA.velocity
        let alpha = dv.dot(dv)
        let beta  = 2 * delta.dot(dv)
        let gamma = delta.dot(delta) - targetDist * targetDist

        var useFallback = true
        if abs(alpha) > 1e-12 {
            let discriminant = beta * beta - 4 * alpha * gamma
            if discriminant >= 0 {
                let sqrtD = sqrtf(discriminant)
                let t1 = (-beta - sqrtD) / (2 * alpha)
                let t2 = (-beta + sqrtD) / (2 * alpha)
                // Pick the root with smallest |δt|, i.e. smallest position shift.
                let t = abs(t1) <= abs(t2) ? t1 : t2

                let r1New = stateA.position + stateA.velocity * t
                let r2New = stateB.position + stateB.velocity * t

                // Reject if the midpoint moves more than 5× spacer (similar velocity case).
                let midOld = (stateA.position + stateB.position) * 0.5
                let midNew = (r1New + r2New) * 0.5
                if (midNew - midOld).length() <= 5 * spacer {
                    stateA.position = r1New
                    stateB.position = r2New
                    useFallback = false
                }
            }
        }

        if useFallback {
            let newDist = (stateB.position - stateA.position).length()
            let push = (targetDist - max(newDist, 1e-6)) * 0.5
            if push > 0 {
                stateA.position = stateA.position - n * push
                stateB.position = stateB.position + n * push
            }
        }
    }

    /// Translates the ball along the cushion normal so it sits exactly R + spacer from the surface.
    ///
    /// Ref: pooltool/physics/resolve/ball_cushion/core.py
    /// - For linear cushions: project ball center onto cushion line, compute gap, push out.
    /// - For circular cushions: use arc center distance, compute gap, push out along normal.
    static func makeBallCushionKiss(state: inout BallState, cushionIndex: Int, normal: SCNVector3, geometry: TableGeometry) {
        let spacer: Float = 1e-6  // 1e-9 in pooltool; use 1e-6 to absorb Float32 rounding
        let linearCount = geometry.linearCushions.count

        if cushionIndex < linearCount {
            let cushion = geometry.linearCushions[cushionIndex]
            // Closest point on the cushion line segment to the ball center (XZ plane).
            let closest = closestPointOnSegmentXZ(
                point: state.position,
                segStart: cushion.start,
                segEnd: cushion.end
            )
            let dx = state.position.x - closest.x
            let dz = state.position.z - closest.z
            let gap = sqrtf(dx * dx + dz * dz)  // XZ distance from ball center to cushion edge
            let correction = BallPhysics.radius - gap + spacer
            if correction > -spacer {
                // Ensure the normal points away from the cushion (toward ball interior).
                let outward: SCNVector3
                if normal.dot(state.velocity) > 0 {
                    outward = normal
                } else {
                    outward = SCNVector3(-normal.x, -normal.y, -normal.z)
                }
                state.position = state.position - outward * correction
            }
        } else {
            let arcIdx = cushionIndex - linearCount
            guard arcIdx < geometry.circularCushions.count else { return }
            let arc = geometry.circularCushions[arcIdx]
            let dx = state.position.x - arc.center.x
            let dz = state.position.z - arc.center.z
            let distToCenter = sqrtf(dx * dx + dz * dz)
            // Ball surface should be at arc.radius + BallPhysics.radius from arc center.
            let correction = BallPhysics.radius + arc.radius - distToCenter - spacer
            if correction > -spacer {
                let outward = normal  // arc normal already points away from arc center toward ball
                state.position = state.position + outward * correction
            }
        }
    }

    // MARK: - 几何谓词

    /// Returns the closest point on the infinite line through segStart–segEnd to the given point,
    /// clamped to the segment, computed only in the XZ plane (Y coordinate from segStart).
    static func closestPointOnSegmentXZ(point: SCNVector3, segStart: SCNVector3, segEnd: SCNVector3) -> SCNVector3 {
        let dx = segEnd.x - segStart.x
        let dz = segEnd.z - segStart.z
        let lenSq = dx * dx + dz * dz
        guard lenSq > 1e-12 else { return segStart }
        let t = max(0, min(1, ((point.x - segStart.x) * dx + (point.z - segStart.z) * dz) / lenSq))
        return SCNVector3(segStart.x + t * dx, segStart.y, segStart.z + t * dz)
    }

    /// Check whether a collision point lies on a finite cushion segment.
    static func isWithinLinearCushionSegment(point: SCNVector3, segment: LinearCushionSegment) -> Bool {
        let segmentVector = segment.end - segment.start
        let segmentLengthSquared = segmentVector.dot(segmentVector)
        guard segmentLengthSquared > 1e-8 else { return false }

        let t = (point - segment.start).dot(segmentVector) / segmentLengthSquared
        let epsilon: Float = 0.001
        return t >= -epsilon && t <= 1 + epsilon
    }

    /// 判断两球是否已经接触/重叠（用于在 findNextEvent 中立即调度 t=0 碰撞）
    ///
    /// 修复：严重重叠时（穿透 > 0.1mm）无条件返回 true，不检查速度方向。
    /// 原先因 relV.dot(n) 守卫，在链式碰撞后两球同向运动时会漏报 → 四次方程
    /// 对已穿透对求不到正根 → 碰撞被完全忽略 → 重叠积累到 15mm。
    static func isBallPairOverlappingOrTouching(_ a: BallState, _ b: BallState) -> Bool {
        let delta = b.position - a.position
        // Use XZ-plane distance to match separateOverlappingBalls. If we used 3D distance
        // here but separate uses XZ, a pair could be flagged by separate yet not trigger
        // a t=0 event, allowing penetration to grow unchecked.
        let d2 = delta.x * delta.x + delta.z * delta.z
        let dist = sqrtf(max(d2, 1e-12))
        let touchDist = 2 * BallPhysics.radius
        let eps: Float = 0.00025

        guard dist <= touchDist + eps else { return false }

        // If balls are actually penetrating (not just touching), always schedule a t=0
        // resolution regardless of velocity direction. Penetration means the quartic will
        // only find negative-time roots, so we must force-resolve now.
        let penetration = touchDist - dist
        if penetration > 0.00001 {  // > 0.01 mm actual overlap
            return true
        }

        // For just-touching balls, only trigger when approaching (relV.dot(n) < 0) to
        // avoid a storm of zero-time events on resting clusters.
        let relV = b.velocity - a.velocity
        if dist < 1e-5 {
            return relV.length() > 0.02
        }
        let n = SCNVector3(delta.x / dist, 0, delta.z / dist)
        return relV.dot(n) < -0.002
    }

    // MARK: - 回退碰撞检测（quartic 漏检兜底）

    /// 是否值得触发离散保底碰撞检测（昂贵操作，需严格限流）
    static func shouldRunFallbackBallBallCheck(
        ballA: BallState,
        ballB: BallState,
        aA: SCNVector3,
        aB: SCNVector3,
        maxTime: Float
    ) -> Bool {
        guard maxTime > 0 else { return false }

        let dp = ballB.position - ballA.position
        let dx = dp.x, dz = dp.z
        let dist = sqrtf(dx * dx + dz * dz)
        let touch = 2 * BallPhysics.radius
        guard dist > 1e-6 else { return true }  // 已重叠，直接允许

        // Near-field safeguard: quartic misses are most visible for translating vs
        // nontranslating pairs at short range (stationary/spinning target hit by
        // rolling/sliding ball). Allow fallback early in this zone.
        let aTranslating = !(ballA.state == .stationary || ballA.state == .spinning || ballA.state == .pocketed)
        let bTranslating = !(ballB.state == .stationary || ballB.state == .spinning || ballB.state == .pocketed)
        let gap = dist - touch
        // Fallback is a local rescue for quartic misses, not a long-range predictor.
        // Far pairs tend to generate phantom hits under constant-acceleration approximation.
        if gap > 0.35 {
            return false
        }
        if aTranslating != bTranslating && gap < 0.25 {
            return true
        }

        // Also open fallback for generic near-field active pairs (including
        // rolling-rolling / rolling-spinning) where quartic misses still appear in logs.
        // We keep this band small to avoid excessive fallback scans.
        let relVxz = sqrtf(powf(ballB.velocity.x - ballA.velocity.x, 2) + powf(ballB.velocity.z - ballA.velocity.z, 2))
        if (aTranslating || bTranslating) && gap < 0.08 && relVxz > 0.01 {
            return true
        }

        // 连心线方向单位向量（XZ 平面）
        let nx = dx / dist, nz = dz / dist

        let relV = ballB.velocity - ballA.velocity
        let relA = aB - aA

        // 沿连心线的靠近速度（负值 = 靠近）
        let approachV = relV.x * nx + relV.z * nz
        // 沿连心线的靠近加速度（负值 = 加速靠近）
        let approachA = relA.x * nx + relA.z * nz

        // 必须在 horizon 内能靠近到 touch 距离
        // 最大可靠近量 = |min(approachV, 0)| * horizon + 0.5*|min(approachA,0)| * horizon²
        let closingV = max(-approachV, 0.0)   // 靠近速度分量（正值）
        let closingA = max(-approachA, 0.0)   // 靠近加速度分量（正值）
        // Keep the gate local in time to avoid approving long-horizon speculative collisions.
        let horizonForGate = min(maxTime, 0.6)
        let maxClosing = closingV * horizonForGate + 0.5 * closingA * horizonForGate * horizonForGate

        // 若最大可靠近量 + 容差仍不足以从 dist 缩短到 touch，则不可能碰撞
        if dist - touch > maxClosing + 0.002 {
            return false
        }

        return true
    }

    /// quartic 漏检时，使用离散+二分求保底碰撞时刻
    static func fallbackBallBallCollisionTime(
        ballA: BallState,
        ballB: BallState,
        aA: SCNVector3,
        aB: SCNVector3,
        maxTime: Float
    ) -> Float? {
        let touch = 2 * BallPhysics.radius
        guard maxTime > 0 else { return nil }

        // Limit horizon to the time during which the constant-acceleration model is valid.
        // Beyond a state-transition, the acceleration changes, so extending past it
        // produces incorrect (phantom) collision times.
        // Use the shorter of the two balls' remaining state lifetimes.
        func stateLifetime(_ ball: BallState) -> Float {
            switch ball.state {
            case .sliding:
                return AnalyticalMotion.slideToRollTime(
                    velocity: ball.velocity,
                    angularVelocity: ball.angularVelocity
                )
            case .rolling:
                return AnalyticalMotion.rollToSpinTime(velocity: ball.velocity)
            case .spinning:
                return AnalyticalMotion.spinToStationaryTime(angularVelocity: ball.angularVelocity)
            case .stationary, .pocketed:
                return 0
            }
        }
        let lifetimeA = stateLifetime(ballA)
        let lifetimeB = stateLifetime(ballB)
        // Add small margin (1 step) to catch collisions right at the boundary,
        // but cap strictly so we don't wander into the next motion phase.
        let stateHorizon = min(lifetimeA, lifetimeB) * 1.05 + 0.05
        // Keep fallback horizon short and local; quartic is the primary solver for long range.
        let horizon = min(maxTime, stateHorizon, 0.6)
        guard horizon > 0 else { return nil }

        // Adaptive steps: each step ≤ 0.02s; 40–300 steps
        let steps = min(300, max(40, Int(ceil(horizon / 0.02))))
        let dt = horizon / Float(steps)

        func distanceMinusTouch(_ t: Float) -> Float {
            let pA = ballA.position + ballA.velocity * t + aA * (0.5 * t * t)
            let pB = ballB.position + ballB.velocity * t + aB * (0.5 * t * t)
            let dx = pA.x - pB.x
            let dz = pA.z - pB.z
            return sqrtf(dx * dx + dz * dz) - touch
        }

        var t0: Float = 0
        var f0 = distanceMinusTouch(0)
        if f0 <= 0 { return 0 }

        for i in 1...steps {
            let t1 = Float(i) * dt
            let f1 = distanceMinusTouch(t1)
            if f1 <= 0 || (f0 > 0 && f1 < 0) {
                var lo = t0
                var hi = t1
                for _ in 0..<18 {
                    let mid = (lo + hi) * 0.5
                    if distanceMinusTouch(mid) <= 0 {
                        hi = mid
                    } else {
                        lo = mid
                    }
                }
                return hi
            }
            t0 = t1
            f0 = f1
        }

        return nil
    }

    // MARK: - 求根

    /// Select smallest positive root within maxTime
    static func smallestPositiveRoot(_ roots: [Double], maxTime: Float) -> Float? {
        let epsilon = 1e-6
        let maxT = Double(maxTime) + 1e-6
        let validRoots = roots.filter { $0 > epsilon && $0 <= maxT && $0.isFinite && !$0.isNaN }
        guard let smallest = validRoots.min() else { return nil }
        return Float(smallest)
    }
}
