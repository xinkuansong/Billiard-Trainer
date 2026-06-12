//
//  ShotPredictor.swift
//  QiuJi
//
//  分离角 / 轨迹页的物理求解门面：把「摆球 + 击打袋口 + 力度 + 塞」翻译成
//  pooltool 事件驱动模拟的一次性求解，输出母球 / 目标球轨迹折线、分离角、
//  切线、进袋结果，供 SceneKit 画线与播放动画使用。
//
//  设计：纯函数、值类型输入输出，不持有 SCNNode；在主线程直接调用即可
//  （2 球场景模拟极快），也可投喂给 `SimulationWorker` 放后台。
//

import SceneKit

// MARK: - Input

struct ShotInput {
    /// 母球位置（世界坐标）。
    var cueBall: SCNVector3
    /// 目标球位置（世界坐标）。
    var targetBall: SCNVector3
    /// 目标袋口索引（对应 `AngleSceneCalculator.pocketPositions` 顺序 0..5）。
    var pocketIndex: Int
    /// 杆头速度 (m/s)。由 5 档速度（`StrokePhysics.SpeedLevel`）映射而来。
    var velocity: Float
    /// 水平打点 -1..1（正 = 左塞）。
    var spinX: Float
    /// 垂直打点 -1..1（正 = 高杆）。
    var spinY: Float
    /// 球杆仰角（弧度，默认 0）。
    var elevation: Float = 0
    /// 台面世界 Y。
    var surfaceY: Float
    /// 进球瞄准点覆盖（世界坐标）。非 nil 时**跳过** `effectivePocketAimPoint` 的管道求解，
    /// 直接用此点作为「目标球应抵达的进球点」。用于反解时把**进球点**作为自由变量：袋口有
    /// 容错（落袋孔半径 > 球半径），目标球可偏离袋心入袋，故在容错窗口内横向滑动进球点以
    /// 贴合截图目标球轨迹。仅影响瞄准/分离角几何；**落袋判定仍以真实袋口捕获窗为准**。
    var pocketAimOverride: SCNVector3? = nil

    /// 其余在桌球（障碍/碰撞体，走位编排器多球场景，ADR-P11-01）。名称须异于
    /// `cueBallName`/`targetBallName`（用 USDZ 球键 `_1`..`_15`）。它们一并进引擎参与真实
    /// 碰撞，但**不是求解目标**——瞄准评分仍只盯 cueBall/object 两个具名球（零评分改动）。
    var obstacles: [ObstacleBall] = []

    static let cueBallName = "cueBall"
    static let targetBallName = "object"
}

/// 走位编排器多球场景中的「其余在桌球」（静止障碍/碰撞体）。
struct ObstacleBall {
    /// 球名（世界唯一，建议用 USDZ 键 `_1`..`_15`）。
    let name: String
    /// 世界坐标摆位。
    let position: SCNVector3
}

// MARK: - Output

struct ShotPrediction {
    /// 选定袋口在几何上是否可进（切球角 < 极限 且 母球不挡路）。
    var feasible: Bool = true
    /// 不可进的原因（feasible == false 时有效）。
    var infeasibleReason: String = ""
    /// 母球轨迹折线（世界坐标，含起点）。
    var cuePath: [SCNVector3] = []
    /// 目标球轨迹折线。
    var objectPath: [SCNVector3] = []
    /// 分离角（度）：首次球-球碰撞后母球方向与目标球方向的夹角。nil = 未发生碰撞。
    var separationAngleDeg: Double?
    /// 瞄准夹角（度）：瞄准线（母球→幽灵球）与进球线（目标球→袋口）之间的切球角 α。
    var cutAngleDeg: Double?
    /// 本次求解实际使用的进球瞄准点（≈ 袋口中心，贴库时沿管道修正）。进球线 = 目标球 → 此点。
    var pocketAimPoint: SCNVector3 = SCNVector3Zero
    /// 切线方向（垂直于撞击线，教学参考，XZ 单位向量）。
    var tangentDir: SCNVector3?
    /// 实际瞄准方向（母球→幽灵球，XZ 单位向量）。
    var aimDirection: SCNVector3 = SCNVector3(1, 0, 0)
    /// 幽灵球中心。
    var ghost: SCNVector3 = SCNVector3Zero
    /// 首次球-球碰撞时刻母球位置（≈ 接触瞬间）。
    var firstContact: SCNVector3?
    /// 母球是否进袋（通常视为失误）。
    var cuePocketed: Bool = false
    /// 目标球是否进袋（画面=物理：直接取自真实模拟结果 `simObjectPotted`）。
    var objectPocketed: Bool = false
    /// 目标球是否在真实模拟中进了选定袋（测量真值；与 `objectPocketed` 现已一致）。
    var simObjectPotted: Bool = false
    /// 母球全程吃库次数（ball-cushion 事件计数）。供反解时按截图标注的吃库数约束解支。
    var cueCushionCount: Int = 0
    /// 目标球落袋前吃库次数（0 = 直接进袋；≥1 = 吃库/翻袋进）。
    var objectCushionCount: Int = 0
    /// 母球首次球-球碰撞前吃库次数（0 = 直瞄直击；≥1 = 绕库/kick 进攻）。
    var cueCushionsBeforeContact: Int = 0
    /// 轨迹回放器（供播放动画复用，避免二次模拟）。
    var recorder: TrajectoryRecorder?
    /// 模拟总时长（秒）。
    var duration: Float = 0
    /// 全场所有球的最终静止位置（世界坐标，走位序列链生成下一杆开局用，ADR-P11-01）。
    /// 母球/目标球取防穿库钳制轨迹末帧；障碍球取真实模拟末帧。
    var finalPositions: [String: SCNVector3] = [:]
    /// 自由球模拟（ADR-P11-03）中除母球外**发生位移**的球的轨迹折线（球名 → 折线）。
    /// 袋口模式恒为空（目标球轨迹走 `objectPath`）。
    var extraBallPaths: [String: [SCNVector3]] = [:]
    /// 本杆进袋（离场）的全部球名（含母球 scratch、被串入袋的障碍球）。
    var pocketedBalls: [String] = []
}

// MARK: - Predictor

enum ShotPredictor {

    /// 求解一次击球的完整轨迹与分离角。
    static func predict(
        _ input: ShotInput,
        maxEvents: Int = 500,
        maxTime: Float = 15.0
    ) -> ShotPrediction {
        let y = input.surfaceY
        let r = BallPhysics.radius

        // 1) 瞄准：把目标球打进选定袋口所需的母球瞄向（幽灵球法 + 进球管道修正）。
        //    若调用方提供 `pocketAimOverride`（反解时把进球点当自由变量），直接采用该进球点，
        //    跳过袋心管道求解——这样目标球被瞄向袋口容错窗内的某个偏心点。
        let aimPoint = input.pocketAimOverride ?? AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: input.targetBall, pocketIndex: input.pocketIndex, surfaceY: y
        )
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: input.targetBall, pocket: aimPoint, ballRadius: r
        )
        let aimDir = unitXZ(from: input.cueBall, to: ghost)

        var result = ShotPrediction()
        result.aimDirection = aimDir
        result.ghost = ghost
        result.pocketAimPoint = aimPoint

        // 1.5) 可行性闸门：选定袋口在几何上能否进球。不可进则直接返回提示，不模拟。
        let cutAngle = AngleSceneCalculator.cutAngle(
            cueBall: input.cueBall, targetBall: input.targetBall, pocket: aimPoint
        )
        result.cutAngleDeg = cutAngle
        if cutAngle >= AngleSceneCalculator.maxCutAngle {
            result.feasible = false
            result.infeasibleReason = "当前角度无法进袋（切球角过大）"
            return result
        }
        if AngleSceneCalculator.isCueBallBlocking(
            cueBall: input.cueBall, targetBall: input.targetBall, pocket: aimPoint
        ) {
            result.feasible = false
            result.infeasibleReason = "母球挡住进球路线，无法进袋"
            return result
        }

        // 2) 闭环瞄准求解：搜索使目标球真正进选定袋的母球发射方向。
        //    通过实际模拟评估而非解析补偿，一次性把 squirt（挤偏）、collision throw（碰撞投掷）、
        //    滑动 swerve 都纳入——这才是“确保进那个袋”。搜索用短时模拟提速，最终再跑完整模拟。
        let velocity = input.velocity
        // 几何统一：USDZ 对齐的 QiuJi 几何（袋口中心 = 屏幕黄色标记），
        // 且已补上完整角袋 jaw 圆弧/直线段 + 中袋圆角（导球入袋）。
        // 模拟几何 == 屏幕几何 ⇒ 不再需要双真源的 60mm 容差。
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: y)
        // 进袋评分 / 命中判定以同一套袋口中心（= 屏幕黄色标记）为准。
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: y)
        let pocketCenter = pockets[input.pocketIndex]

        // 瞄准求解目标：让母球（含 squirt 挤偏 + 滑行 swerve 弧线）实际抵达「幽灵球」中心，
        // 即复现「不加塞时的母球-目标球接触点」⇒ 目标球沿进球线直线离开（用户诉求）。
        let bestOffset = solveAimOffset(
            baseAim: aimDir, velocity: velocity, input: input,
            geometry: geometry, pocketCenter: pocketCenter, ghost: ghost
        )

        // 3) 用求得的最优方向跑一次完整模拟（含母球后续走位）。
        let finalAim = aimDir.rotatedY(bestOffset)
        let run = runShot(
            aimDir: finalAim, velocity: velocity, input: input,
            geometry: geometry, pocketCenter: pocketCenter, ghost: ghost,
            maxEvents: maxEvents, maxTime: maxTime, highFidelity: true
        )
        // 4) 轨迹折线（画面=物理，回归纯物理 ADR-P10-06）：母球与目标球**都直接取自引擎真实
        //    模拟轨迹**，不再做任何显示层钳制 / 捕获修饰。
        //    - 母球（白）：碰后走位（分离角 + 高低杆跟/缩 + 吃库），可贴库直线走。
        //    - 目标球（橙）：真实去向——含碰撞 throw、撞 jaw 反弹、能量不足停球或 rattle。
        //
        // 袋口「进 / rattle 弹出 / 接住穿库球」全部由引擎真实喉腔几何（jaw 库 + 喉腔侧壁/后壁 +
        // 落袋孔，见 `TableGeometry+QiuJi.throatWalls`）自然涌现——小力远jaw→近jaw→袋心进、
        // 大力 jaw 间反复弹回 mouth 弹出、后壁接住越过落袋孔的球。喉腔模型出现后，旧的显示层
        // 「穿库安全网 + 捕获窗一致性闸门」已是冗余补丁（只会把真落袋误判为未进、并把贴库轨迹
        // 钳出折线），故整体移除，让画面与判定都等于引擎物理真值。
        let playback = TrajectoryPlayback(recorder: run.recorder, surfaceY: y + r)
        let duration = run.recorder.duration
        result.recorder = run.recorder
        result.duration = duration
        result.cuePath = polyline(playback, ballName: ShotInput.cueBallName, duration: duration)
        result.objectPath = polyline(playback, ballName: ShotInput.targetBallName, duration: duration)

        // 母球进袋（scratch）判定（纯物理）：直接取引擎信号——母球落入任一袋即 scratch。
        let cuePocketed = run.cuePocketed
        result.cuePocketed = cuePocketed

        // 目标球进袋判定（纯物理）：直接取引擎「目标球真正落入**选定**袋」(`run.pottedSelected`)。
        // 进 / 未进完全由喉腔几何 + 能量决定（力度不足、太薄如实报未进）。
        let potted = run.pottedSelected
        result.simObjectPotted = potted
        result.objectPocketed = potted
        result.cueCushionCount = run.cueCushions
        result.objectCushionCount = run.objCushionsBeforePocket
        result.cueCushionsBeforeContact = run.cueCushionsBeforeContact

        // 4.5) 全场最终静止位置 + 进袋球名（走位序列链，ADR-P11-01）。全部取自引擎真实末帧。
        var finals: [String: SCNVector3] = [:]
        var pocketed: [String] = []
        for (name, frames) in run.recorder.framesByBallName {
            if let last = frames.max(by: { $0.time < $1.time }) {
                finals[name] = last.position
            }
            if run.recorder.isBallPocketed(name) { pocketed.append(name) }
        }
        // 目标球用 `pottedSelected`（比 isBallPocketed 严：须进“选定”袋）覆盖其在进袋列表中的状态。
        if potted, !pocketed.contains(ShotInput.targetBallName) { pocketed.append(ShotInput.targetBallName) }
        if !potted { pocketed.removeAll { $0 == ShotInput.targetBallName } }
        result.finalPositions = finals
        result.pocketedBalls = pocketed

        // 5) 分离角：首次球-球碰撞后两球速度方向夹角。
        if let contactTime = run.firstContactTime {
            let cueVel = velocityAfter(run.recorder, ballName: ShotInput.cueBallName, time: contactTime)
            let objVel = velocityAfter(run.recorder, ballName: ShotInput.targetBallName, time: contactTime)
            if let cueVel, let objVel {
                let cueDir = horizontalDir(cueVel)
                let objDir = horizontalDir(objVel)
                if let cd = cueDir, let od = objDir {
                    let dot = max(-1, min(1, cd.x * od.x + cd.z * od.z))
                    result.separationAngleDeg = Double(acosf(dot) * 180 / .pi)
                }
                // 切线 = 垂直于撞击线；撞击线方向 ≈ 目标球碰后方向。
                if let od = objDir {
                    result.tangentDir = SCNVector3(-od.z, 0, od.x)
                }
            }
            result.firstContact = positionAt(run.recorder, ballName: ShotInput.cueBallName, time: contactTime)
        }

        return result
    }

    // MARK: - Free shot (ADR-P11-03)

    /// 自由球模拟（走位编排台「自由」模式）：**不指定目标球与袋口**，以给定方向直接击打母球，
    /// 全部在桌球（`balls`）作为真实碰撞体一并模拟。不做任何瞄准求解与可行性闸门（恒 feasible）——
    /// 用于安全球 / 轻推贴球 / 纯走位等非进攻击打。球名沿用调用方传入的名字（建议 USDZ 键），
    /// 母球名固定 `ShotInput.cueBallName`。
    static func simulateFree(
        cueBall: SCNVector3,
        aimDir: SCNVector3,
        velocity: Float,
        spinX: Float,
        spinY: Float,
        surfaceY: Float,
        balls: [ObstacleBall],
        maxEvents: Int = 500,
        maxTime: Float = 15.0
    ) -> ShotPrediction {
        let y = surfaceY
        let r = BallPhysics.radius
        let len = sqrtf(aimDir.x * aimDir.x + aimDir.z * aimDir.z)
        let dir = len > 1e-5 ? SCNVector3(aimDir.x / len, 0, aimDir.z / len) : SCNVector3(1, 0, 0)

        let strike = CueBallStrike.executeStrike(
            aimDirection: dir, velocity: velocity,
            spinX: spinX, spinY: spinY, elevation: 0
        )
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: y)
        let engine = EventDrivenEngine(tableGeometry: geometry)
        engine.setBall(BallState(
            position: SCNVector3(cueBall.x, y + r, cueBall.z),
            velocity: strike.velocity, angularVelocity: strike.angularVelocity,
            state: .sliding, name: ShotInput.cueBallName
        ))
        for b in balls where b.name != ShotInput.cueBallName {
            engine.setBall(BallState(
                position: SCNVector3(b.position.x, y + r, b.position.z),
                velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
                state: .stationary, name: b.name
            ))
        }
        engine.simulate(maxEvents: maxEvents, maxTime: maxTime, highFidelityBounds: true)
        let recorder = engine.getTrajectoryRecorder()
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: y + r)
        let duration = recorder.duration

        var result = ShotPrediction()
        result.feasible = true
        result.aimDirection = dir
        result.recorder = recorder
        result.duration = duration
        result.cuePath = polyline(playback, ballName: ShotInput.cueBallName, duration: duration)
        result.cuePocketed = recorder.isBallPocketed(ShotInput.cueBallName)

        var finals: [String: SCNVector3] = [:]
        var pocketed: [String] = []
        var extraPaths: [String: [SCNVector3]] = [:]
        for (name, frames) in recorder.framesByBallName {
            if let last = frames.max(by: { $0.time < $1.time }) {
                finals[name] = last.position
            }
            if recorder.isBallPocketed(name) { pocketed.append(name) }
            if name != ShotInput.cueBallName {
                let pts = polyline(playback, ballName: name, duration: duration)
                if pathLengthXZ(pts) > 0.02 { extraPaths[name] = pts }
            }
        }
        result.finalPositions = finals
        result.pocketedBalls = pocketed
        result.extraBallPaths = extraPaths
        result.objectPocketed = pocketed.contains { $0 != ShotInput.cueBallName }

        if let contactTime = firstBallBallTime(engine) {
            result.firstContact = positionAt(recorder, ballName: ShotInput.cueBallName, time: contactTime)
        }
        return result
    }

    /// 引擎事件流中首次球-球碰撞时刻。
    private static func firstBallBallTime(_ engine: EventDrivenEngine) -> Float? {
        for (e, t) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
            if case .ballBall = e { return t }
        }
        return nil
    }

    /// XZ 平面折线总长。
    private static func pathLengthXZ(_ pts: [SCNVector3]) -> Float {
        guard pts.count >= 2 else { return 0 }
        var total: Float = 0
        for i in 0..<(pts.count - 1) {
            let dx = pts[i + 1].x - pts[i].x, dz = pts[i + 1].z - pts[i].z
            total += sqrtf(dx * dx + dz * dz)
        }
        return total
    }

    // MARK: - Aim solver

    /// 单次模拟结果（搜索与最终共用）。
    private struct RunResult {
        let recorder: TrajectoryRecorder
        /// 目标球是否进了**选定**的那个袋（而非任意袋）。
        let pottedSelected: Bool
        let cuePocketed: Bool
        /// 目标球轨迹到选定袋口中心的最近水平距离（用作未进袋时的连续评分）。
        let objMinDist: Float
        let firstContactTime: Float?
        /// 目标球**碰撞后**的离开方向（XZ 单位向量）。nil = 未发生球-球碰撞。
        let objPostContactDir: SCNVector3?
        /// 母球中心轨迹到「幽灵球」中心的最近水平距离（瞄准求解的核心评分量）：
        /// 越小 ⇒ 母球越接近在理想接触点击中目标球 ⇒ 目标球越贴进球线直线离开。
        /// 对命中/未命中都连续有定义（单峰、便于搜索），自动吸收 squirt + swerve。
        let cueGhostMinDist: Float
        /// 目标球在**落袋前**撞库次数（0 = 直接进袋；≥1 = 吃库/banking 进袋）。
        /// 求解器优先选「直接进袋」解：避免为了躲母球 scratch 而选到绕库的别扭进球路线。
        let objCushionsBeforePocket: Int
        /// 目标球落袋前**撞库点离选定袋中心的最远距离 (m)**（无撞库 = 0）。遥测/诊断量（矩阵测试用其
        /// 统计「擦 jaw 再进」vs「远处翻袋」）；ADR-P10-04 纯几何驱动求解器不再据此评分。
        let objMaxPrepocketCushionDist: Float
        /// 母球全程吃库次数（供反解按截图标注的吃库数约束）。
        let cueCushions: Int
        /// 母球在**首次球-球碰撞前**的吃库次数（0 = 直瞄直击；≥1 = 绕库/kick 进攻路线）。
        let cueCushionsBeforeContact: Int
    }

    /// 以 `aimDir` 方向、`velocity` 力度发射母球并模拟，返回结果。
    private static func runShot(
        aimDir: SCNVector3, velocity: Float, input: ShotInput,
        geometry: TableGeometry, pocketCenter: SCNVector3, ghost: SCNVector3,
        maxEvents: Int, maxTime: Float, highFidelity: Bool = false
    ) -> RunResult {
        let y = input.surfaceY
        let r = BallPhysics.radius
        let strike = CueBallStrike.executeStrike(
            aimDirection: aimDir, velocity: velocity,
            spinX: input.spinX, spinY: input.spinY, elevation: input.elevation
        )
        let engine = EventDrivenEngine(tableGeometry: geometry)
        engine.setBall(BallState(
            position: SCNVector3(input.cueBall.x, y + r, input.cueBall.z),
            velocity: strike.velocity, angularVelocity: strike.angularVelocity,
            state: .sliding, name: ShotInput.cueBallName
        ))
        engine.setBall(BallState(
            position: SCNVector3(input.targetBall.x, y + r, input.targetBall.z),
            velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
            state: .stationary, name: ShotInput.targetBallName
        ))
        // 走位编排器多球场景（ADR-P11-01）：其余在桌球作静止障碍/碰撞体一并入引擎。
        for ob in input.obstacles
        where ob.name != ShotInput.cueBallName && ob.name != ShotInput.targetBallName {
            engine.setBall(BallState(
                position: SCNVector3(ob.position.x, y + r, ob.position.z),
                velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
                state: .stationary, name: ob.name
            ))
        }
        engine.simulate(maxEvents: maxEvents, maxTime: maxTime, highFidelityBounds: highFidelity)
        let recorder = engine.getTrajectoryRecorder()

        var minDist = Float.greatestFiniteMagnitude
        if let frames = recorder.framesByBallName[ShotInput.targetBallName] {
            for f in frames {
                let dx = f.position.x - pocketCenter.x
                let dz = f.position.z - pocketCenter.z
                minDist = min(minDist, sqrtf(dx * dx + dz * dz))
            }
        }
        // 母球轨迹到幽灵球中心的最近水平距离（事件帧 + 段内细分采样，避免长段跨越幽灵球时漏测）。
        var cueGhostMinDist = Float.greatestFiniteMagnitude
        if let cueFrames = recorder.framesByBallName[ShotInput.cueBallName] {
            let sorted = cueFrames.sorted { $0.time < $1.time }
            for i in 0..<sorted.count {
                let p = sorted[i].position
                let dx = p.x - ghost.x, dz = p.z - ghost.z
                cueGhostMinDist = min(cueGhostMinDist, sqrtf(dx * dx + dz * dz))
                // 相邻事件帧之间做线段-点最近距离，覆盖母球高速掠过幽灵球的中间段。
                if i + 1 < sorted.count {
                    let q = sorted[i + 1].position
                    cueGhostMinDist = min(cueGhostMinDist,
                                          segmentPointDistanceXZ(a: p, b: q, p: ghost))
                }
            }
        }
        var contactTime: Float?
        for (e, t) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
            if case .ballBall = e { contactTime = t; break }
        }
        // 目标球碰后离开方向（碰撞解算后第一帧速度的水平分量）。
        var objDir: SCNVector3?
        if let ct = contactTime,
           let v = velocityAfter(recorder, ballName: ShotInput.targetBallName, time: ct) {
            let len = sqrtf(v.x * v.x + v.z * v.z)
            if len > 1e-4 { objDir = SCNVector3(v.x / len, 0, v.z / len) }
        }
        // 进“选定袋”= 目标球的进袋事件袋号等于选定袋（几何统一后袋号一一对应，
        // 不再用距离容差甄别）。同时统计目标球落袋前撞库次数（直接 vs 吃库进袋）。
        var objectPocketId: String?
        var objCushionsBeforePocket = 0
        var objMaxPrepocketCushionDist: Float = 0
        var cueCushions = 0
        var cueCushionsBeforeContact = 0
        var sawBallBall = false
        for (ev, et) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
            switch ev {
            case .ballBall:
                sawBallBall = true
            case .ballCushion(let ball, _, _) where ball == ShotInput.targetBallName:
                if objectPocketId == nil {
                    objCushionsBeforePocket += 1
                    if let p = recorder.stateAt(ballName: ShotInput.targetBallName, time: et)?.position {
                        let dx = p.x - pocketCenter.x, dz = p.z - pocketCenter.z
                        objMaxPrepocketCushionDist = max(objMaxPrepocketCushionDist, sqrtf(dx * dx + dz * dz))
                    }
                }
            case .ballCushion(let ball, _, _) where ball == ShotInput.cueBallName:
                cueCushions += 1
                if !sawBallBall { cueCushionsBeforeContact += 1 }
            case .pocket(let ball, let pid) where ball == ShotInput.targetBallName:
                if objectPocketId == nil { objectPocketId = pid }
            default:
                break
            }
        }
        let pottedSelected = (objectPocketId == "pocket_\(input.pocketIndex)")
        return RunResult(
            recorder: recorder,
            pottedSelected: pottedSelected,
            cuePocketed: recorder.isBallPocketed(ShotInput.cueBallName),
            objMinDist: minDist,
            firstContactTime: contactTime,
            objPostContactDir: objDir,
            cueGhostMinDist: cueGhostMinDist,
            objCushionsBeforePocket: objCushionsBeforePocket,
            objMaxPrepocketCushionDist: objMaxPrepocketCushionDist,
            cueCushions: cueCushions,
            cueCushionsBeforeContact: cueCushionsBeforeContact
        )
    }

    /// XZ 平面内点 `p` 到线段 `a–b` 的最近距离（internal：走位编排台障碍挡线提示复用）。
    static func segmentPointDistanceXZ(a: SCNVector3, b: SCNVector3, p: SCNVector3) -> Float {
        let abx = b.x - a.x, abz = b.z - a.z
        let apx = p.x - a.x, apz = p.z - a.z
        let denom = abx * abx + abz * abz
        guard denom > 1e-9 else { return sqrtf(apx * apx + apz * apz) }
        var t = (apx * abx + apz * abz) / denom
        t = max(0, min(1, t))
        let cx = a.x + abx * t, cz = a.z + abz * t
        let dx = p.x - cx, dz = p.z - cz
        return sqrtf(dx * dx + dz * dz)
    }

    /// 搜索最优瞄准角偏移（弧度）。
    ///
    /// **管道瞄准法求解（用户拍板的最终模型，取代一切混合法 / 进袋评分）：**
    /// 求解只做一件事——**让目标球碰后的实际离开方向对齐「管道方向」`d_pipe`**。
    /// `d_pipe = unit(aimPoint − OB)`，其中 `aimPoint` 由 `effectivePocketAimPoint` 按管道法三种情况
    /// （空心穿喉 / 远端 jaw 反弹 / 不可行）纯几何定出，**与力度、加塞无关、固定**。
    ///
    /// 本函数 = 一维 **throw 补偿反解**：搜索瞄准偏移，使母球（含 squirt 挤偏 + 滑行 swerve）走到
    /// 目标球、碰撞后（含 cut 角 + 加塞引起的 collision throw）目标球**实际**沿 `d_pipe` 离开。
    /// 评分 = 碰后方向与 `d_pipe` 的夹角（rad），对偏移平滑单峰；同分偏好更小偏移（解唯一、稳定）。
    ///
    /// **没有进袋奖励、没有主库罚、没有 kick/scratch 罚、没有分支**：
    ///   · 进不进 = 力度的下游结果，不参与求解（力够→进；力不足→沿同一管子线停在半路 = 未进袋，合理）。
    ///   · 管子本身按几何就不碰库边，目标球沿管子走自然不碰库 ⇒ 无需再罚主库。
    ///   · **管道法是直击**：碰目标球前吃库（绕库 banking / kick）的偏移一律判为**无效候选**，
    ///     绝不退化成"母球绕库蹭袋"。
    private enum AimScoring {
        /// 搜索阶段每次短模拟的事件/时长上限。**与最终模拟同保真**——降保真会与最终全保真产生双景观
        /// 错位（搜到的解上报时变样）。
        static let searchMaxEvents = 500
        static let searchMaxTime: Float = 15.0
        /// 无效候选基线（碰前吃库的绕库解 / 未碰到目标球）。远大于方向误差上限 π(≈3.14)，
        /// 使任何**直击**候选都优于无效候选 ⇒ 直击 + 方向最对齐者胜出。
        static let invalidCandidate: Float = 100
        /// 瞄准偏移正则项系数（rad⁻¹）：同分时偏好更小偏移，使景观有唯一极小、解稳定。
        static let offsetRegularization: Float = 1e-3
        /// 三级网格搜索半幅/步长（度）：粗→中→细。方向景观平滑单峰，无需密梳。
        static let coarseHalfRangeDeg: Float = 12,  coarseStepDeg: Float = 0.5
        static let midHalfRangeDeg: Float = 0.6,    midStepDeg: Float = 0.1
        static let fineHalfRangeDeg: Float = 0.12,  fineStepDeg: Float = 0.02
    }

    private static func solveAimOffset(
        baseAim: SCNVector3, velocity: Float, input: ShotInput,
        geometry: TableGeometry, pocketCenter: SCNVector3, ghost: SCNVector3
    ) -> Float {
        let searchEvents = AimScoring.searchMaxEvents
        let searchTime = AimScoring.searchMaxTime

        // 进球管道目标线（target → 管道选定瞄点 aimPoint，XZ 单位向量）：目标球碰后应沿此方向离开。
        // aimPoint 由 `AngleSceneCalculator.effectivePocketAimPoint` 的**纯几何管道法（far-jaw-only）**
        // 给出——能空心进 ⇒ 袋心；贴库/强切角不可空心进 ⇒ 自动外移、避开近端 jaw、只擦远端 jaw；
        // 力度是否足够决定能否真落袋（本求解器只把目标球送上这条线）。
        // ghost = target − 2R·unit(aimPoint − target) ⇒ unit(target − ghost) = unit(aimPoint − target)。
        let adx = input.targetBall.x - ghost.x
        let adz = input.targetBall.z - ghost.z
        let adl = max(sqrtf(adx * adx + adz * adz), 1e-5)
        let aimDirX = adx / adl, aimDirZ = adz / adl

        // 管道瞄准法求解目标：碰后实际离开方向对齐管道方向 `d_pipe`（= aimDir）。一维 throw 补偿反解。
        func score(_ offset: Float) -> Float {
            let run = runShot(
                aimDir: baseAim.rotatedY(offset), velocity: velocity, input: input,
                geometry: geometry, pocketCenter: pocketCenter, ghost: ghost,
                maxEvents: searchEvents, maxTime: searchTime
            )
            guard let od = run.objPostContactDir else {
                // 未碰到目标球：无效候选，叠加母球-幽灵球距离做梯度，把搜索拉回真正击中目标球。
                return AimScoring.invalidCandidate + run.cueGhostMinDist
            }
            // 管道法是**直击**：碰目标球前吃库（绕库 banking / kick）= 无效候选，绝不退化成绕库蹭袋。
            guard run.cueCushionsBeforeContact == 0 else {
                return AimScoring.invalidCandidate
            }
            // 唯一目标：碰后方向 vs 管道方向 `d_pipe` 夹角（rad）。平滑单峰，自动补偿 squirt+swerve+throw。
            // 同分偏好更小偏移（解唯一、稳定）。进不进由力度决定、不在此评分。
            let dot = max(-1, min(1, od.x * aimDirX + od.z * aimDirZ))
            return acosf(dot) + abs(offset) * AimScoring.offsetRegularization
        }

        let deg = Float.pi / 180
        func bestOf(center: Float, halfRange: Float, step: Float) -> Float {
            var bo = center
            var bs = Float.greatestFiniteMagnitude
            var o = center - halfRange
            while o <= center + halfRange + 1e-6 {
                let s = score(o)
                if s < bs { bs = s; bo = o }
                o += step
            }
            return bo
        }

        // 粗 ±12°/0.5°（49）→ 中 ±0.6°/0.1°（13）→ 细 ±0.12°/0.02°（13）。方向景观平滑单峰、无需密梳。
        let c = bestOf(center: 0, halfRange: AimScoring.coarseHalfRangeDeg * deg, step: AimScoring.coarseStepDeg * deg)
        let m = bestOf(center: c, halfRange: AimScoring.midHalfRangeDeg * deg, step: AimScoring.midStepDeg * deg)
        let f = bestOf(center: m, halfRange: AimScoring.fineHalfRangeDeg * deg, step: AimScoring.fineStepDeg * deg)
        return f
    }

    /// 取某球在 `time` 之后第一帧的速度（即碰撞解算后的速度）。
    private static func velocityAfter(_ recorder: TrajectoryRecorder, ballName: String, time: Float) -> SCNVector3? {
        guard let frames = recorder.framesByBallName[ballName] else { return nil }
        let sorted = frames.sorted { $0.time < $1.time }
        let eps: Float = 1e-5
        for f in sorted where f.time >= time - eps {
            return f.velocity
        }
        return sorted.last?.velocity
    }

    private static func positionAt(_ recorder: TrajectoryRecorder, ballName: String, time: Float) -> SCNVector3? {
        recorder.stateAt(ballName: ballName, time: time)?.position
    }

    /// 按固定时间步解析采样轨迹，再做共线/距离简化，得到平滑且段数受控的折线。
    private static func polyline(_ playback: TrajectoryPlayback, ballName: String, duration: Float) -> [SCNVector3] {
        guard duration > 1e-4 else {
            if let s = playback.stateAt(ballName: ballName, time: 0) { return [s.position] }
            return []
        }
        let dt: Float = 1.0 / 120.0
        var raw: [SCNVector3] = []
        var t: Float = 0
        while t <= duration + 1e-4 {
            if let s = playback.stateAt(ballName: ballName, time: min(t, duration)) {
                raw.append(s.position)
            }
            t += dt
        }
        return simplify(raw)
    }

    /// 共线简化：累计转角 > ~2.6° 或单段 > 12cm 才保留顶点（含首尾）。
    private static func simplify(_ pts: [SCNVector3]) -> [SCNVector3] {
        guard pts.count > 2 else { return pts }
        var out: [SCNVector3] = [pts[0]]
        var anchor = pts[0]
        let turnThreshold: Float = 0.045   // rad ≈ 2.6°
        let maxSegment: Float = 0.12       // m
        for i in 1..<(pts.count - 1) {
            let a = SCNVector3(pts[i].x - anchor.x, 0, pts[i].z - anchor.z)
            let b = SCNVector3(pts[i + 1].x - pts[i].x, 0, pts[i + 1].z - pts[i].z)
            let la = sqrtf(a.x * a.x + a.z * a.z)
            let lb = sqrtf(b.x * b.x + b.z * b.z)
            guard la > 1e-5, lb > 1e-5 else { continue }
            let dot = max(-1, min(1, (a.x * b.x + a.z * b.z) / (la * lb)))
            let turn = acosf(dot)
            if turn > turnThreshold || la > maxSegment {
                out.append(pts[i])
                anchor = pts[i]
            }
        }
        out.append(pts[pts.count - 1])
        return out
    }

    private static func horizontalDir(_ v: SCNVector3) -> SCNVector3? {
        let len = sqrtf(v.x * v.x + v.z * v.z)
        guard len > 0.01 else { return nil }
        return SCNVector3(v.x / len, 0, v.z / len)
    }

    private static func unitXZ(from a: SCNVector3, to b: SCNVector3) -> SCNVector3 {
        let dx = b.x - a.x, dz = b.z - a.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 0.0001 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(dx / len, 0, dz / len)
    }
}
