//
//  AnalyticAimModel.swift
//  QiuJi
//
//  解析瞄准层（B2，方案 §3）：不进事件驱动引擎主循环，直接用引擎自己的
//  闭式解组件推演「击杆 → 母球飞行 → 首次球-球碰撞 → 目标球碰后方向」。
//
//  **忠实性契约（对拍口径的根基）——全部复用、零重写：**
//  - 击杆：`CueBallStrike.executeStrike`（含 squirt），与 `ShotPredictor.runShot` 同一调用。
//  - 弹道：滑动/滚动均为**常加速度段**（滑动段 û 恒定是闭式解成立的前提，
//    与 `AnalyticalMotion.evolveSliding/evolveRolling` + 引擎事件间演进逐位一致）。
//  - 碰撞检测：`CollisionDetector` 的同一批四次/二次方程求根（球-球、直线库、圆弧库）
//    + 引擎 `findNextEvent` 同款袋口 XZ 四次方程。
//  - 碰撞解算：`EngineNumerics.makeBallBallKiss` + `CollisionResolver.resolveBallBallPure`，
//    与 `EventDrivenEngine.resolveBallBallCollision` 同序同参。
//
//  坐标契约：SceneKit 世界系，台面在 XZ 平面、+Y 朝上，台心 (0, surfaceY, 0)。
//  所有方向量均为 XZ 平面单位向量（y=0）。
//
//  与整程模拟的已知语义差（对拍归因清单，B2-4）：
//  1. 首事件为库边时本层即返回 `cueHitCushionFirst`（评分 = 无效候选基线，
//     与模拟中「碰前吃库后仍击中目标球」的评分完全一致）；但模拟中母球吃库后
//     **永远打不中目标球**的档位，评分是 `invalid + 全程 cueGhostMinDist`，本层
//     少了库后路径的 ghost 距离梯度——只影响无效高原的倾斜方向，不影响有效解。
//  2. 首事件为障碍球/落袋时按「未碰到目标球」处理（与模拟 objDir==nil 同口径），
//     ghost 距离只累计到该事件为止。
//

import SceneKit

enum AnalyticAim {

    /// 一次解析推演的结果（只覆盖瞄准评分需要消费的量，字段口径对齐
    /// `ShotPredictor.RunResult` 中被 `positionAimOffset` 评分消费的子集）。
    struct Outcome {
        /// 目标球被母球首碰后的离开方向（XZ 单位向量）。nil = 母球未（先）碰到目标球。
        var objPostContactDir: SCNVector3?
        /// 母球在碰到目标球之前先撞上任一库边（直线段或 jaw 圆弧）。
        /// 管道法判定为无效候选（对应模拟的 `cueCushionsBeforeContact > 0`）。
        var cueHitCushionFirst: Bool = false
        /// 母球中心路径到幽灵球中心的最近水平距离（对命中/未命中都有定义，
        /// 未命中时作为把搜索拉回目标球的梯度，与模拟评分同用途）。
        var cueGhostMinDist: Float = .greatestFiniteMagnitude
        /// 首次母-目碰撞时刻（秒）。nil = 未碰到。
        var contactTime: Float?
        /// 碰撞解算后的母球状态（make-kiss 后碰点位形 + pooltool 解算后的速度/角速度/运动状态）。
        /// 仅命中目标球时给出——B3 单球 rollout（`AnalyticShotRollout`）的续演起点。
        var cueAfterContact: BallState?
        /// 碰撞解算后的目标球状态（同上）。
        var objAfterContact: BallState?
        /// 击杆 → 首事件之间母球的常加速度路径段（`collectSegments: true` 时给出，
        /// 供情形 B 过点查询在碰前路径上闭式取位）。
        var preContactSegments: [BallPathSegment] = []
    }

    /// 给定发射方向/力度/打点，解析推演到首次母-目碰撞并返回目标球碰后方向。
    ///
    /// - Parameters:
    ///   - aimDir: 母球发射方向（XZ 单位向量，已含瞄准偏移）。
    ///   - velocity: 杆头速度 (m/s)。
    ///   - input: 击球输入（母球/目标球/障碍球位置、打点、仰角、surfaceY）。
    ///   - geometry: 与模拟同一份 `TableGeometry`（库边/圆弧/袋口）。
    ///   - ghost: 幽灵球中心（未命中时的梯度参考点）。
    ///   - maxTime: 推演时间上限（秒），与瞄准搜索的短模拟上限同口径。
    static func outcome(
        aimDir: SCNVector3, velocity: Float, input: ShotInput,
        geometry: TableGeometry, ghost: SCNVector3, maxTime: Float = 15.0,
        collectSegments: Bool = false
    ) -> Outcome {
        let y = input.surfaceY
        let r = BallPhysics.radius

        let strike = CueBallStrike.executeStrike(
            aimDirection: aimDir, velocity: velocity,
            spinX: input.spinX, spinY: input.spinY, elevation: input.elevation
        )
        var cue = BallState(
            position: SCNVector3(input.cueBall.x, y + r, input.cueBall.z),
            velocity: strike.velocity, angularVelocity: strike.angularVelocity,
            state: .sliding, name: ShotInput.cueBallName
        )
        cue.state = EngineNumerics.determineMotionState(cue)

        let targetPos = SCNVector3(input.targetBall.x, y + r, input.targetBall.z)
        var obstaclePositions: [SCNVector3] = []
        obstaclePositions.reserveCapacity(input.obstacles.count)
        for ob in input.obstacles
        where ob.name != ShotInput.cueBallName && ob.name != ShotInput.targetBallName {
            obstaclePositions.append(SCNVector3(ob.position.x, y + r, ob.position.z))
        }

        var out = Outcome()
        var elapsed: Float = 0

        // 母球飞行 = 至多「滑动 → 滚动」两个常加速度段（自旋/静止段不再平移，无新碰撞）。
        // 每段内：加速度恒定 ⇒ 引擎的全部 CCD 求根公式可直接套用，段长 = 状态迁移时刻。
        for _ in 0..<2 {
            let phaseDuration: Float
            switch cue.state {
            case .sliding:
                phaseDuration = AnalyticalMotion.slideToRollTime(
                    velocity: cue.velocity, angularVelocity: cue.angularVelocity)
            case .rolling:
                phaseDuration = AnalyticalMotion.rollToSpinTime(velocity: cue.velocity)
            default:
                return out   // spinning / stationary：不再平移
            }
            let horizon = min(phaseDuration, maxTime - elapsed)
            guard horizon > 1e-6 else { return out }

            let accel = EngineNumerics.acceleration(for: cue)

            // —— 段内首事件检测（与引擎 findNextEvent 同一批求根器）——
            // 目标球（静止，v=a=0；四次方程 + 引擎同款漏检回退）先解：其余事件只需在
            // [0, tTarget] 内找（更晚的事件不影响首事件判定）⇒ 检测窗与几何预筛半径双收窄。
            let tTarget = ballBallTime(
                cue: cue, accel: accel, otherPos: targetPos,
                otherName: ShotInput.targetBallName, horizon: horizon
            )
            let checkHorizon = min(horizon, tTarget ?? horizon)
            // 几何预筛半径：窗内最大位移上界 |v|t + ½|a|t²（滑动段方向会弯，用模上界保守覆盖）。
            let speed = cue.velocity.length()
            let accelMag = accel.length()
            let reach = speed * checkHorizon + 0.5 * accelMag * checkHorizon * checkHorizon
                + BallPhysics.radius + 0.01

            // 障碍球（静止）
            var tObstacle: Float?
            for (i, op) in obstaclePositions.enumerated() {
                guard cue.position.distanceXZ(to: op) < reach + BallPhysics.radius else { continue }
                if let t = ballBallTime(
                    cue: cue, accel: accel, otherPos: op,
                    otherName: "obstacle_\(i)", horizon: checkHorizon
                ), t < (tObstacle ?? .greatestFiniteMagnitude) {
                    tObstacle = t
                }
            }
            // 库边（直线段 + jaw 圆弧）
            let tCushion = earliestCushionTime(
                position: cue.position, velocity: cue.velocity, accel: accel,
                geometry: geometry, horizon: checkHorizon, ballRadius: r, reach: reach
            )
            // 袋口落孔（引擎 findNextEvent 同款 XZ 四次方程）
            var tPocket: Float?
            for pocket in geometry.pockets {
                guard cue.position.distanceXZ(to: pocket.center) < reach + pocket.radius else { continue }
                if let t = ballPocketTime(
                    position: cue.position, velocity: cue.velocity, accel: accel,
                    pocket: pocket, horizon: checkHorizon
                ), t < (tPocket ?? .greatestFiniteMagnitude) {
                    tPocket = t
                }
            }

            // 段内推演终点（首事件或段尾），先累计 ghost 最近距离
            let events: [Float?] = [tTarget, tObstacle, tCushion, tPocket]
            let tFirst = events.compactMap { $0 }.min()
            let tEnd = tFirst ?? horizon
            accumulateGhostMinDist(
                &out.cueGhostMinDist, from: cue.position, velocity: cue.velocity,
                accel: accel, duration: tEnd, ghost: ghost
            )
            if collectSegments, tEnd > 1e-6 {
                out.preContactSegments.append(BallPathSegment(
                    t0: elapsed, duration: tEnd,
                    position: cue.position, velocity: cue.velocity,
                    accel: accel, state: cue.state
                ))
            }

            if let tc = tTarget, tc == tFirst {
                // 首事件 = 击中目标球：演进到碰点（与引擎事件间演进同一闭式解），
                // make-kiss + pooltool 球-球解算，取目标球碰后速度方向。
                var cueAtContact = evolve(cue, dt: tc)
                var targetState = BallState(
                    position: targetPos, velocity: SCNVector3Zero,
                    angularVelocity: SCNVector3Zero, state: .stationary,
                    name: ShotInput.targetBallName
                )
                EngineNumerics.makeBallBallKiss(stateA: &cueAtContact, stateB: &targetState)
                let resolved = CollisionResolver.resolveBallBallPure(
                    posA: cueAtContact.position, posB: targetState.position,
                    velA: cueAtContact.velocity, velB: targetState.velocity,
                    angVelA: cueAtContact.angularVelocity, angVelB: targetState.angularVelocity
                )
                let v = resolved.velB
                let len = sqrtf(v.x * v.x + v.z * v.z)
                if len > 1e-4 {
                    out.objPostContactDir = SCNVector3(v.x / len, 0, v.z / len)
                }
                out.contactTime = elapsed + tc
                // 碰后两球状态（与引擎 resolveBallBallCollision 同序同参，B3 rollout 起点）。
                var cueAfter = cueAtContact
                cueAfter.velocity = resolved.velA
                cueAfter.angularVelocity = resolved.angVelA
                cueAfter.state = EngineNumerics.determineMotionState(cueAfter)
                var objAfter = targetState
                objAfter.velocity = resolved.velB
                objAfter.angularVelocity = resolved.angVelB
                objAfter.state = EngineNumerics.determineMotionState(objAfter)
                out.cueAfterContact = cueAfter
                out.objAfterContact = objAfter
                return out
            }
            if let tcu = tCushion, tcu == tFirst {
                out.cueHitCushionFirst = true
                return out
            }
            if tFirst != nil {
                // 障碍球先被撞 / 母球先落袋：按「未碰到目标球」返回（模拟同口径：objDir==nil）。
                return out
            }

            // 段内无事件：演进到段尾，进入下一运动状态段。
            cue = evolve(cue, dt: horizon)
            elapsed += horizon
            cue.state = EngineNumerics.determineMotionState(cue)
        }
        return out
    }

    // MARK: - 第 0 层几何早筛（B2：障碍球挡死整个瞄准扇区的线段-圆预测试）

    /// 母球 → 幽灵球的**整个 ±`fanHalfAngle` 瞄准扇区**是否被某颗障碍球挡死。
    ///
    /// 保守判据（宁可漏筛、绝不误杀可行候选）：障碍球中心到基线线段的垂距 `d`、
    /// 沿线投影 `s`，即使把瞄准整支偏到扇区边缘、朝远离障碍一侧全力绕行，
    /// 路径在 `s` 处最多再让出 `s·sin(fanHalfAngle)` 的横向间隙；若
    /// `d + s·sin(fan) < 2R − slack` 仍不足两球半径和，则扇区内**任何**直击
    /// 候选都必先撞上该障碍 ⇒ 无需进入一维搜索（下游全保真终验兜底语义不变）。
    /// `slack` 吸收滑动 swerve 的额外弯折与浮点误差。
    static func straightFanBlocked(
        cue: SCNVector3, ghost: SCNVector3, obstacles: [ObstacleBall],
        fanHalfAngle: Float = 12 * .pi / 180
    ) -> Bool {
        guard !obstacles.isEmpty else { return false }
        let dx = ghost.x - cue.x, dz = ghost.z - cue.z
        let segLen = sqrtf(dx * dx + dz * dz)
        guard segLen > 1e-5 else { return false }
        let ux = dx / segLen, uz = dz / segLen
        let twoR = 2 * BallPhysics.radius
        let slack: Float = 0.005   // 5mm：swerve 弯折 + Float 舍入的安全余量
        let sinFan = sinf(fanHalfAngle)

        for ob in obstacles
        where ob.name != ShotInput.cueBallName && ob.name != ShotInput.targetBallName {
            let px = ob.position.x - cue.x, pz = ob.position.z - cue.z
            let s = px * ux + pz * uz                    // 沿线投影
            // 只考虑严格位于母球与幽灵球之间的障碍（端点重叠区交给物理判定）。
            guard s > twoR, s < segLen - twoR else { continue }
            let d = abs(px * uz - pz * ux)               // 到基线的垂距
            if d + s * sinFan < twoR - slack { return true }
        }
        return false
    }

    // MARK: - Ball-ball detection（引擎同款：四次方程 + 漏检回退）

    /// 母球与一颗静止球的碰撞时刻：先走引擎主路径的四次方程 CCD；未找到时按引擎同款
    /// 门控跑离散+二分回退（`EventDrivenEngine.findNextEvent` 的 quartic-miss 兜底），
    /// 保证与模拟评分在近场低速档位上同判。internal：B3 单球 rollout 复用。
    static func ballBallTime(
        cue: BallState, accel: SCNVector3, otherPos: SCNVector3,
        otherName: String, horizon: Float
    ) -> Float? {
        if let t = CollisionDetector.ballBallCollisionTime(
            p1: cue.position, p2: otherPos,
            v1: cue.velocity, v2: SCNVector3Zero,
            a1: accel, a2: SCNVector3Zero,
            R: Double(BallPhysics.radius), maxTime: Double(horizon)
        ) {
            return t
        }
        let other = BallState(
            position: otherPos, velocity: SCNVector3Zero,
            angularVelocity: SCNVector3Zero, state: .stationary, name: otherName
        )
        guard EngineNumerics.shouldRunFallbackBallBallCheck(
            ballA: cue, ballB: other, aA: accel, aB: SCNVector3Zero, maxTime: horizon
        ) else { return nil }
        return EngineNumerics.fallbackBallBallCollisionTime(
            ballA: cue, ballB: other, aA: accel, aB: SCNVector3Zero, maxTime: horizon
        )
    }

    // MARK: - Phase evolution（复用引擎同款闭式解）

    private static func evolve(_ ball: BallState, dt: Float) -> BallState {
        var next = ball
        switch ball.state {
        case .sliding:
            let e = AnalyticalMotion.evolveSliding(
                position: ball.position, velocity: ball.velocity,
                angularVelocity: ball.angularVelocity, dt: dt
            )
            next.position = e.position
            next.velocity = e.velocity
            next.angularVelocity = e.angularVelocity
        case .rolling:
            let e = AnalyticalMotion.evolveRolling(
                position: ball.position, velocity: ball.velocity,
                angularVelocity: ball.angularVelocity, dt: dt
            )
            next.position = e.position
            next.velocity = e.velocity
            next.angularVelocity = e.angularVelocity
        default:
            break
        }
        return next
    }

    // MARK: - Cushion / pocket detection（引擎 findNextEvent 同款求根 + 过滤）

    /// 段内最早的库边碰撞时刻。检测编排已抽至 `AnalyticShotRollout.earliestCushionEvent`
    /// （B3 单一真源，本层只消费时刻、rollout 还消费段索引/法向）。
    private static func earliestCushionTime(
        position: SCNVector3, velocity: SCNVector3, accel: SCNVector3,
        geometry: TableGeometry, horizon: Float, ballRadius: Float, reach: Float
    ) -> Float? {
        AnalyticShotRollout.earliestCushionEvent(
            position: position, velocity: velocity, accel: accel,
            geometry: geometry, horizon: horizon, reach: reach
        )?.time
    }

    /// 球心水平投影抵达袋口孔圈的时刻（引擎 findNextEvent 的袋口 CCD 同款四次方程，XZ-only）。
    /// internal：B3 单球 rollout 复用。
    static func ballPocketTime(
        position: SCNVector3, velocity: SCNVector3, accel: SCNVector3,
        pocket: Pocket, horizon: Float
    ) -> Float? {
        let dpX = position.x - pocket.center.x
        let dpZ = position.z - pocket.center.z
        let dvX = velocity.x, dvZ = velocity.z
        let halfDaX = accel.x * 0.5, halfDaZ = accel.z * 0.5

        let a4 = Double(halfDaX * halfDaX + halfDaZ * halfDaZ)
        let a3 = 2.0 * Double(dvX * halfDaX + dvZ * halfDaZ)
        let a2 = Double(dvX * dvX + dvZ * dvZ) + 2.0 * Double(dpX * halfDaX + dpZ * halfDaZ)
        let a1 = 2.0 * Double(dpX * dvX + dpZ * dvZ)
        let a0 = Double(dpX * dpX + dpZ * dpZ) - Double(pocket.radius * pocket.radius)

        let roots = QuarticSolver.solveQuartic(a: a4, b: a3, c: a2, d: a1, e: a0)
        return EngineNumerics.smallestPositiveRoot(roots, maxTime: horizon)
    }

    // MARK: - Ghost min distance（未命中时的搜索梯度）

    /// 常加速度段 [0, duration] 内母球中心路径到 ghost 的最近水平距离（折线采样近似，
    /// 与模拟侧「事件帧 + 段内线段细分」的近似方式同量级）。
    private static func accumulateGhostMinDist(
        _ minDist: inout Float, from position: SCNVector3, velocity: SCNVector3,
        accel: SCNVector3, duration: Float, ghost: SCNVector3
    ) {
        guard duration > 0 else {
            let dx = position.x - ghost.x, dz = position.z - ghost.z
            minDist = min(minDist, sqrtf(dx * dx + dz * dz))
            return
        }
        let samples = 12
        var prev = position
        for i in 0...samples {
            let t = duration * Float(i) / Float(samples)
            let p = position + velocity * t + accel * (0.5 * t * t)
            if i == 0 {
                let dx = p.x - ghost.x, dz = p.z - ghost.z
                minDist = min(minDist, sqrtf(dx * dx + dz * dz))
            } else {
                minDist = min(minDist, ShotPredictor.segmentPointDistanceXZ(a: prev, b: p, p: ghost))
            }
            prev = p
        }
    }
}
