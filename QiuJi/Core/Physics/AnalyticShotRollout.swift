//
//  AnalyticShotRollout.swift
//  QiuJi
//
//  第 2 层单球解析 rollout（B3，方案 §2/§3）：碰后母球与目标球各自做
//  「常加速度段 + 库边反弹 + 落袋 + 状态迁移」的闭式推演——这正是事件驱动引擎
//  的事件循环在**单球**下的特化，全部复用引擎同一批组件，零平行物理（红线 2）：
//  - 弹道段：`AnalyticalMotion.evolveSliding/evolveRolling` + 状态迁移时刻闭式解。
//  - 事件检测：`CollisionDetector` 四次/二次方程（球-球、直线库、圆弧库）
//    + 引擎同款袋口 XZ 四次方程（`AnalyticAim.ballPocketTime`）+ quartic-miss 回退。
//  - 库边解算：`EngineNumerics.resolveCushionImpact`（B3 从引擎原样抽出，
//    引擎事件循环与本层**同吃这一份**：恢复系数选择/只推不拉护栏/kiss/Han 解算）。
//  - 状态迁移：与 `EventDrivenEngine.resolveTransition` 同语义（滚动吸附 ω / 自旋清 v）。
//
//  **升级全模拟的边界（忠实性契约）**：单球 rollout 只对「除自身外全场静止」成立。
//  以下情形本层如实上报、由调用方回退引擎全模拟，绝不猜测：
//  1. rollout 球撞上任何一颗静止球（`firstBallHit`）——碰后进入多球级联。
//  2. 母球与目标球碰后路径互相靠近（kiss 风险，`kissRisk`）——两球需耦合解算。
//  3. 超出时间/吃库上限截断（`completed == false`）——与引擎 maxEvents/maxTime
//     截断同判「未真停稳」，候选照旧被 `cueRestedInPlace` 拒绝。
//
//  坐标契约：SceneKit 世界系，台面在 XZ 平面、+Y 朝上，台心 (0, surfaceY, 0)。
//

import SceneKit

/// 常加速度路径段（rollout / 解析瞄准共用的路径原语）：
/// 段内 p(t) = p₀ + v₀·t + ½a·t²（滑动段 û 恒定 ⇒ a 恒定，与引擎事件间演进逐位一致）。
struct BallPathSegment {
    /// 段起点绝对时刻（秒，击杆 = 0）。
    let t0: Float
    let duration: Float
    let position: SCNVector3
    let velocity: SCNVector3
    let accel: SCNVector3
    let state: BallMotionState

    /// 段内相对时刻 dt ∈ [0, duration] 处的球心位置（闭式）。
    func position(at dt: Float) -> SCNVector3 {
        position + velocity * dt + accel * (0.5 * dt * dt)
    }
    /// 段内相对时刻 dt 处的速度（闭式）。
    func velocity(at dt: Float) -> SCNVector3 {
        velocity + accel * dt
    }
}

enum AnalyticShotRollout {

    // MARK: - 单球 rollout

    /// 单球 rollout 结果。
    struct SingleBallResult {
        var finalState: BallState
        /// 落袋的袋号（"pocket_N"）。nil = 未落袋。
        var pocketId: String?
        /// 吃库次数（冲量真正施加的库边碰撞，与引擎 resolvedEvents 同口径）。
        var cushionCount: Int = 0
        /// 各次吃库的绝对时刻。
        var cushionTimes: [Float] = []
        /// rollout 球撞上的第一颗静止球（碰后进入多球级联，本层就此打住）。
        var firstBallHit: String?
        var firstBallHitTime: Float?
        /// true = 真停稳/落袋；false = 撞球中止或超时/超吃库上限截断。
        var completed: Bool = false
        /// 常加速度路径段（过点查询 / kiss 检测的闭式取位）。
        var segments: [BallPathSegment] = []
        /// rollout 终止绝对时刻。
        var endTime: Float = 0

        /// t 时刻球心位置（段内闭式；越过终点取终位；落袋后视为已离台返回 nil）。
        func position(at t: Float) -> SCNVector3? {
            if pocketId != nil, t >= endTime { return nil }
            if t >= endTime { return finalState.position }
            for seg in segments where t >= seg.t0 && t <= seg.t0 + seg.duration {
                return seg.position(at: t - seg.t0)
            }
            return segments.first.map { t < $0.t0 ? $0.position : finalState.position }
                ?? finalState.position
        }
    }

    /// 吃库次数上限：单球在库间衰减弹跳，真实局面远达不到；超限 = 与引擎 maxEvents
    /// 截断同判「未停稳」。
    static let maxCushionBounces = 24

    /// 从给定状态推演单球至停稳/落袋/撞球/超限。
    ///
    /// - Parameters:
    ///   - initial: 起点状态（通常为 `AnalyticAim.Outcome.cueAfterContact/objAfterContact`）。
    ///   - startTime: 起点绝对时刻（秒，击杆 = 0）。
    ///   - staticBalls: 场上其余静止球（名字 + 球心位置）；撞上任何一颗即中止上报。
    ///   - maxTime: 绝对时间上限（与引擎 searchMaxTime 同口径）。
    static func rollout(
        from initial: BallState, startTime: Float, geometry: TableGeometry,
        staticBalls: [(name: String, position: SCNVector3)], maxTime: Float
    ) -> SingleBallResult {
        var ball = initial
        var t = startTime
        var out = SingleBallResult(finalState: initial)
        let r = BallPhysics.radius

        while true {
            switch ball.state {
            case .stationary, .pocketed:
                out.finalState = ball
                out.endTime = t
                out.completed = true
                return out
            case .spinning:
                // 原地自旋：不再平移，位置即终位（引擎 spin→stationary 迁移只清 ω）。
                ball.velocity = SCNVector3Zero
                out.finalState = ball
                out.endTime = t
                out.completed = true
                return out
            case .sliding, .rolling:
                break
            }
            guard t < maxTime, out.cushionCount <= maxCushionBounces else {
                out.finalState = ball
                out.endTime = t
                out.completed = false   // 截断：与引擎 maxEvents/maxTime 同判未停稳
                return out
            }

            let phaseDuration: Float = ball.state == .sliding
                ? AnalyticalMotion.slideToRollTime(velocity: ball.velocity,
                                                   angularVelocity: ball.angularVelocity)
                : AnalyticalMotion.rollToSpinTime(velocity: ball.velocity)
            if phaseDuration <= 1e-6 {
                // 相位时长退化为 0（数值边界）：直接按状态机推进（引擎 transition 同语义），
                // 状态链 sliding→rolling→spinning 严格单向 ⇒ 不会死循环。
                ball = applyTransition(ball)
                continue
            }
            let horizon = min(phaseDuration, maxTime - t)
            let accel = EngineNumerics.acceleration(for: ball)

            // —— 段内首事件检测（与引擎 findNextEvent 同一批求根器）——
            // 几何预筛半径：窗内最大位移上界 |v|t + ½|a|t²（滑动段方向会弯，用模上界保守覆盖）。
            let speed = ball.velocity.length()
            let accelMag = accel.length()
            let reach = speed * horizon + 0.5 * accelMag * horizon * horizon + r + 0.01

            let cushionEvt = earliestCushionEvent(
                position: ball.position, velocity: ball.velocity, accel: accel,
                geometry: geometry, horizon: horizon, reach: reach
            )
            var pocketEvt: (time: Float, id: String)?
            for pocket in geometry.pockets {
                guard ball.position.distanceXZ(to: pocket.center) < reach + pocket.radius else { continue }
                if let tp = AnalyticAim.ballPocketTime(
                    position: ball.position, velocity: ball.velocity, accel: accel,
                    pocket: pocket, horizon: horizon
                ), tp < (pocketEvt?.time ?? .greatestFiniteMagnitude) {
                    pocketEvt = (tp, pocket.id)
                }
            }
            var ballEvt: (time: Float, name: String)?
            for sb in staticBalls {
                guard ball.position.distanceXZ(to: sb.position) < reach + r else { continue }
                if let tb = AnalyticAim.ballBallTime(
                    cue: ball, accel: accel, otherPos: sb.position,
                    otherName: sb.name, horizon: horizon
                ), tb < (ballEvt?.time ?? .greatestFiniteMagnitude) {
                    ballEvt = (tb, sb.name)
                }
            }

            let tFirst = [cushionEvt?.time, pocketEvt?.time, ballEvt?.time]
                .compactMap { $0 }.min()
            let tEnd = tFirst ?? horizon
            if tEnd > 1e-6 {
                out.segments.append(BallPathSegment(
                    t0: t, duration: tEnd,
                    position: ball.position, velocity: ball.velocity,
                    accel: accel, state: ball.state
                ))
            }

            // 事件排序与引擎一致：时间最早者先；1e-7 内并列时按引擎优先级
            // （pocket priority 2 < ballBall/cushion priority 3）落袋先解。
            let tieEps: Float = 1e-7
            if let pe = pocketEvt, let tf = tFirst, pe.time <= tf + tieEps {
                // 落袋：吸附袋心（引擎 resolvePocket 同语义）。
                ball = evolve(ball, dt: pe.time)
                if let pocket = geometry.pockets.first(where: { $0.id == pe.id }) {
                    ball.position = SCNVector3(pocket.center.x, ball.position.y, pocket.center.z)
                }
                ball.state = .pocketed
                ball.velocity = SCNVector3Zero
                ball.angularVelocity = SCNVector3Zero
                out.pocketId = pe.id
                out.finalState = ball
                out.endTime = t + pe.time
                out.completed = true
                return out
            }
            if let be = ballEvt, be.time == tFirst {
                // 撞上静止球：多球级联开始，本层如实中止（调用方升级全模拟或按语义消费）。
                ball = evolve(ball, dt: be.time)
                out.firstBallHit = be.name
                out.firstBallHitTime = t + be.time
                out.finalState = ball
                out.endTime = t + be.time
                out.completed = false
                return out
            }
            if let ce = cushionEvt, ce.time == tFirst {
                // 库边：演进到碰点，走引擎同一份完整解算（含只推不拉护栏）。
                ball = evolve(ball, dt: ce.time)
                t += ce.time
                let applied = EngineNumerics.resolveCushionImpact(
                    state: &ball, cushionIndex: ce.cushionIndex, normal: ce.normal,
                    geometry: geometry
                )
                if applied {
                    out.cushionCount += 1
                    out.cushionTimes.append(t)
                }
                continue
            }

            // 段内无事件：演进到段尾。相位自然结束 ⇒ 状态迁移；否则已到 maxTime（下轮截断返回）。
            ball = evolve(ball, dt: horizon)
            t += horizon
            if horizon >= phaseDuration - 1e-6 {
                ball = applyTransition(ball)
            }
        }
    }

    // MARK: - 一杆快速评估（走位反解扫描消费）

    /// 一杆的快速解析评估结果（字段口径对齐 `ShotPrediction` 中被走位反解扫描消费的子集）。
    struct ShotOutcome {
        /// 本层无法忠实覆盖（碰前吃库/未命中/kiss 风险/级联/截断歧义），调用方须回退引擎全模拟。
        var needsFullSim = false
        /// 母球是否命中目标球。
        var contact = false
        var contactTime: Float?
        /// 目标球进了**选定**袋（与引擎 pottedSelected 同口径）。
        var pottedSelected = false
        var cuePocketed = false
        /// 母球真停稳（真实停点，非截断假停；对应 `cueFinalSpeed < tolerance`）。
        var cueRested = false
        var cueFinalPos: SCNVector3?
        /// 母球**碰球后**吃库数（吃库桶键；碰前吃库的档位已回退引擎，恒为碰后计数）。
        var cueCushionsAfterContact = 0
        /// 母球全程路径段（碰前 + 碰后），供情形 B 过点查询闭式取位。
        var cueSegments: [BallPathSegment] = []
        /// 母球碰球后各次吃库绝对时刻。
        var cueCushionTimes: [Float] = []
        /// 母球（碰目标球后）撞上的第一颗静止球与时刻（情形 B 的 K 球消费；情形 A 视为级联）。
        var cueFirstBallHit: String?
        var cueFirstBallHitTime: Float?
    }

    /// 快速评估一杆：解析瞄准层推演到首碰（B2）→ 两球各自单球 rollout（B3）→ kiss 风险检测。
    /// 任何本层覆盖不了的情形都置 `needsFullSim`，由调用方回退引擎——扫描层加速，判定不降级。
    static func evaluate(
        aimDir: SCNVector3, velocity: Float, input: ShotInput,
        geometry: TableGeometry, ghost: SCNVector3, maxTime: Float = 15.0
    ) -> ShotOutcome {
        var out = ShotOutcome()

        let aim = AnalyticAim.outcome(
            aimDir: aimDir, velocity: velocity, input: input,
            geometry: geometry, ghost: ghost, maxTime: maxTime, collectSegments: true
        )
        guard let cueAfter = aim.cueAfterContact, let objAfter = aim.objAfterContact,
              let contactTime = aim.contactTime, aim.objPostContactDir != nil else {
            // 未（先）命中目标球：含碰前吃库（可能绕库命中）、先撞障碍、先落袋、滚停未达——
            // 这些档位引擎全模拟才有完整语义（绕库命中/级联后停点），一律回退。
            out.needsFullSim = true
            return out
        }
        out.contact = true
        out.contactTime = contactTime
        out.cueSegments = aim.preContactSegments

        let y = input.surfaceY
        let r = BallPhysics.radius
        var staticBalls: [(name: String, position: SCNVector3)] = []
        staticBalls.reserveCapacity(input.obstacles.count)
        for ob in input.obstacles
        where ob.name != ShotInput.cueBallName && ob.name != ShotInput.targetBallName {
            staticBalls.append((ob.name, SCNVector3(ob.position.x, y + r, ob.position.z)))
        }

        // 目标球 rollout：撞障碍/截断 ⇒ 级联/歧义，回退引擎。
        let objRoll = rollout(from: objAfter, startTime: contactTime, geometry: geometry,
                              staticBalls: staticBalls, maxTime: maxTime)
        if objRoll.firstBallHit != nil || !objRoll.completed {
            out.needsFullSim = true
            return out
        }
        out.pottedSelected = (objRoll.pocketId == "pocket_\(input.pocketIndex)")

        // 母球 rollout：撞球如实上报（情形 B 的 K 球是**目的**，情形 A 由调用方判级联回退）。
        let cueRoll = rollout(from: cueAfter, startTime: contactTime, geometry: geometry,
                              staticBalls: staticBalls, maxTime: maxTime)
        out.cueSegments.append(contentsOf: cueRoll.segments)
        out.cueCushionTimes = cueRoll.cushionTimes
        out.cueCushionsAfterContact = cueRoll.cushionCount
        out.cueFirstBallHit = cueRoll.firstBallHit
        out.cueFirstBallHitTime = cueRoll.firstBallHitTime
        out.cuePocketed = cueRoll.pocketId != nil
        out.cueRested = cueRoll.completed && cueRoll.pocketId == nil && cueRoll.firstBallHit == nil
        out.cueFinalPos = cueRoll.finalState.position

        // kiss 风险：碰后两球路径再度靠近 ⇒ 两球需耦合解算，单球模型失效，回退引擎。
        if kissRisk(cue: cueRoll, obj: objRoll, from: contactTime) {
            out.needsFullSim = true
        }
        return out
    }

    // MARK: - 自由球快速评估（做斯诺克反解扫描消费，B4）

    /// 自由球一杆的快速解析评估结果（字段口径对齐 `simulateFree` 中被 `evaluateSnooker`
    /// 消费的子集）。自由球无目标袋语义：只关心母球首触了谁、两球终态与母球全程吃库数。
    struct FreeShotOutcome {
        /// 本层无法忠实覆盖（碰后任一球撞第三球=级联 / kiss 风险 / 截断），调用方须回退引擎。
        var needsFullSim = false
        /// 母球首次球-球碰撞的对方球名。nil = 全程未碰任何球。
        var firstBallHit: String?
        var cuePocketed = false
        /// 母球真停稳（rollout 走到 stationary，末速为零）。
        var cueRested = false
        var cueFinalPos: SCNVector3?
        /// 被首触球是否落袋（任意袋）。
        var firstHitPocketed = false
        var firstHitFinalPos: SCNVector3?
        /// 母球全程吃库数（碰前 + 碰后，与引擎 ballCushion 事件计数同口径）。
        var cueCushionCount = 0
    }

    /// 快速评估一杆自由球：击杆 → 母球单球 rollout 至首触/停稳/落袋 → 碰撞解算（引擎同源）
    /// → 母球与被撞球各自单球 rollout → kiss 风险检测。任何覆盖不了的情形置 `needsFullSim`。
    /// - Parameter balls: 全部在桌球（台面高度原始位置，内部抬升到球心高度）。
    static func evaluateFreeShot(
        cueBall: SCNVector3, aimDir: SCNVector3, velocity: Float,
        spinX: Float, spinY: Float, surfaceY: Float,
        balls: [ObstacleBall], geometry: TableGeometry, maxTime: Float = 15.0
    ) -> FreeShotOutcome {
        var out = FreeShotOutcome()
        let r = BallPhysics.radius
        let len = sqrtf(aimDir.x * aimDir.x + aimDir.z * aimDir.z)
        let dir = len > 1e-5 ? SCNVector3(aimDir.x / len, 0, aimDir.z / len) : SCNVector3(1, 0, 0)

        // 击杆（squirt 同源）→ 初始母球状态（与 `simulateFree` 同参同序）。
        let strike = CueBallStrike.executeStrike(
            aimDirection: dir, velocity: velocity, spinX: spinX, spinY: spinY, elevation: 0)
        var cue = BallState(
            position: SCNVector3(cueBall.x, surfaceY + r, cueBall.z),
            velocity: strike.velocity, angularVelocity: strike.angularVelocity,
            state: .sliding, name: ShotInput.cueBallName)
        cue.state = EngineNumerics.determineMotionState(cue)

        let lifted: [(name: String, position: SCNVector3)] = balls
            .filter { $0.name != ShotInput.cueBallName }
            .map { ($0.name, SCNVector3($0.position.x, surfaceY + r, $0.position.z)) }

        // 碰前母球 rollout（吃库/kick 合法，照常反弹推进）。
        let pre = rollout(from: cue, startTime: 0, geometry: geometry,
                          staticBalls: lifted, maxTime: maxTime)
        out.cueCushionCount = pre.cushionCount
        guard let hit = pre.firstBallHit, let hitTime = pre.firstBallHitTime else {
            if !pre.completed {
                out.needsFullSim = true   // 截断歧义：引擎裁决
                return out
            }
            // 全程未碰球：空杆（停稳或自进袋），结论确定。
            out.cuePocketed = pre.pocketId != nil
            out.cueRested = pre.pocketId == nil
            out.cueFinalPos = pre.finalState.position
            return out
        }
        out.firstBallHit = hit
        guard let hitPos = lifted.first(where: { $0.name == hit })?.position else {
            out.needsFullSim = true
            return out
        }

        // 首触碰撞解算（make-kiss + Han 纯解算，与引擎 resolveBallBallCollision 同序同参）。
        var cueAt = pre.finalState
        var obj = BallState(position: hitPos, velocity: SCNVector3Zero,
                            angularVelocity: SCNVector3Zero, state: .stationary, name: hit)
        EngineNumerics.makeBallBallKiss(stateA: &cueAt, stateB: &obj)
        let resolved = CollisionResolver.resolveBallBallPure(
            posA: cueAt.position, posB: obj.position,
            velA: cueAt.velocity, velB: obj.velocity,
            angVelA: cueAt.angularVelocity, angVelB: obj.angularVelocity)
        cueAt.velocity = resolved.velA
        cueAt.angularVelocity = resolved.angVelA
        cueAt.state = EngineNumerics.determineMotionState(cueAt)
        obj.velocity = resolved.velB
        obj.angularVelocity = resolved.angVelB
        obj.state = EngineNumerics.determineMotionState(obj)

        // 碰后两球各自 rollout（其余球仍静止）；撞第三球=级联、截断=歧义 ⇒ 回退。
        let others = lifted.filter { $0.name != hit }
        let cueRoll = rollout(from: cueAt, startTime: hitTime, geometry: geometry,
                              staticBalls: others, maxTime: maxTime)
        let objRoll = rollout(from: obj, startTime: hitTime, geometry: geometry,
                              staticBalls: others, maxTime: maxTime)
        if cueRoll.firstBallHit != nil || objRoll.firstBallHit != nil
            || !cueRoll.completed || !objRoll.completed
            || kissRisk(cue: cueRoll, obj: objRoll, from: hitTime) {
            out.needsFullSim = true
            return out
        }
        out.cueCushionCount += cueRoll.cushionCount
        out.cuePocketed = cueRoll.pocketId != nil
        out.cueRested = !out.cuePocketed
        out.cueFinalPos = cueRoll.finalState.position
        out.firstHitPocketed = objRoll.pocketId != nil
        out.firstHitFinalPos = objRoll.finalState.position
        return out
    }

    // MARK: - Kiss 风险检测（保守：宁可误报回退引擎，不可漏报出假物理）

    /// 采样两球 rollout 路径的相对距离：碰后两球从 2R 分离，一旦「先拉开、后又逼近到接触带」
    /// 或「长时间贴着不分离」即判 kiss 风险。误报只损失性能（多跑一次引擎），漏报会让
    /// 扫描层出假停点——阈值取保守侧；代表解另有引擎复核兜底（双保险）。
    static func kissRisk(
        cue: SingleBallResult, obj: SingleBallResult, from t0: Float
    ) -> Bool {
        let twoR = 2 * BallPhysics.radius
        let armDist = twoR + 0.004      // 拉开 4mm 视为「已分离」
        let kissDist = twoR + 0.001     // 分离后再进入 1mm 接触带 = kiss 风险
        let tEnd = max(cue.endTime, obj.endTime)
        guard tEnd > t0 + 1e-4 else { return false }

        var armed = false
        var t = t0 + 0.002
        while t <= tEnd {
            let pc = cue.position(at: t)
            let po = obj.position(at: t)
            // 任一球已落袋离台：不再可能 kiss。
            guard let pc, let po else { return false }
            let dx = pc.x - po.x, dz = pc.z - po.z
            let d = sqrtf(dx * dx + dz * dz)
            if !armed {
                if d > armDist {
                    armed = true
                } else if t - t0 > 0.12 {
                    // 碰后 120ms 仍未拉开 4mm：贴身跟进（强跟杆追球等），歧义 ⇒ 回退。
                    return true
                }
            } else if d < kissDist {
                return true
            }
            // 前 0.6s 密采（kiss 高发窗），之后放粗；两球都停止后无需再采。
            if t >= cue.endTime && t >= obj.endTime { return false }
            t += (t - t0 < 0.6) ? 0.008 : 0.04
        }
        return false
    }

    // MARK: - 库边事件检测（AnalyticAim 与 rollout 共用的编排，索引/法向随行）

    /// 段内最早的库边碰撞（直线段做有限段包含过滤，圆弧段内建逼近方向 + 角域过滤），
    /// 携带引擎口径的 `cushionIndex`（线性段序号；圆弧 = linearCount + arcIdx）与法向。
    /// `reach` = 检测窗内最大位移上界 + R，用于按距离粗筛（保守，只省计算）。
    static func earliestCushionEvent(
        position: SCNVector3, velocity: SCNVector3, accel: SCNVector3,
        geometry: TableGeometry, horizon: Float, reach: Float
    ) -> (time: Float, cushionIndex: Int, normal: SCNVector3)? {
        let ballRadius = BallPhysics.radius
        var best: (time: Float, cushionIndex: Int, normal: SCNVector3)?
        for (index, cushion) in geometry.linearCushions.enumerated() {
            let closest = EngineNumerics.closestPointOnSegmentXZ(
                point: position, segStart: cushion.start, segEnd: cushion.end)
            guard position.distanceXZ(to: closest) < reach else { continue }
            let lineOffset = Double(cushion.normal.dot(cushion.start))
            guard let t = CollisionDetector.ballLinearCushionTime(
                p: position, v: velocity, a: accel,
                lineNormal: cushion.normal, lineOffset: lineOffset,
                R: Double(ballRadius), maxTime: Double(horizon)
            ) else { continue }
            let posAtT = position + velocity * t + accel * (0.5 * t * t)
            guard EngineNumerics.isWithinLinearCushionSegment(point: posAtT, segment: cushion) else { continue }
            if t < (best?.time ?? .greatestFiniteMagnitude) {
                best = (t, index, cushion.normal)
            }
        }
        let linearCount = geometry.linearCushions.count
        for (arcIdx, arc) in geometry.circularCushions.enumerated() {
            guard position.distanceXZ(to: arc.center) < reach + arc.radius else { continue }
            if let t = CollisionDetector.ballCircularCushionTime(
                p: position, v: velocity, a: accel,
                arc: arc, R: ballRadius, maxTime: Double(horizon)
            ), t < (best?.time ?? .greatestFiniteMagnitude) {
                let posAtT = position + velocity * t + accel * (0.5 * t * t)
                best = (t, linearCount + arcIdx, arc.normal(at: posAtT))
            }
        }
        return best
    }

    // MARK: - 段演进与状态迁移（引擎同款闭式解 / resolveTransition 同语义）

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

    /// 相位自然结束时的状态迁移（`EventDrivenEngine.resolveTransition` 同语义）：
    /// 滑动→滚动吸附滚动条件 ω；滚动→自旋清 v。
    private static func applyTransition(_ ball: BallState) -> BallState {
        var next = ball
        switch ball.state {
        case .sliding:
            next.state = .rolling
            let up = SCNVector3(0, 1, 0)
            let wRolling = up.cross(next.velocity) * (1.0 / BallPhysics.radius)
            next.angularVelocity = SCNVector3(wRolling.x, next.angularVelocity.y, wRolling.z)
        case .rolling:
            next.state = .spinning
            next.velocity = SCNVector3Zero
        case .spinning:
            next.state = .stationary
            next.velocity = SCNVector3Zero
            next.angularVelocity = SCNVector3Zero
        default:
            break
        }
        return next
    }
}
