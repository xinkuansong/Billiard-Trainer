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

    static let cueBallName = "cueBall"
    static let targetBallName = "object"
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
    /// 轨迹回放器（供播放动画复用，避免二次模拟）。
    var recorder: TrajectoryRecorder?
    /// 模拟总时长（秒）。
    var duration: Float = 0
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
        let aimPoint = AngleSceneCalculator.effectivePocketAimPoint(
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
            maxEvents: maxEvents, maxTime: maxTime
        )
        // 4) 轨迹折线（画面=物理，P10 Track B）：母球与目标球**都取自真实模拟**。
        //    - 母球（白）：碰后走位（分离角 + 高低杆跟/缩 + 吃库）。
        //    - 目标球（橙）：真实去向——含碰撞 throw、（强切角/贴库时）撞 jaw 反弹、能量不足
        //      停球或 rattle。不再画「固定直线入袋」的理想化结果；闭环求解器已尽力找到能真正
        //      落袋的瞄准，能进则轨迹直抵袋口、不能进（太薄/太软）则如实呈现未进与走向。
        //
        // 安全网：事件驱动引擎在袋口喇叭口偶发「穿库」（球未被袋口捕获也未被库edge反弹，
        // 直接穿过袋口缺口飞出台面，约 8% 触发），导致轨迹/回放冲出球台。这里按解析回放
        // 重采样并把任一球「离开可玩区且不在袋口」的时刻钳到库边冻结，截断其后轨迹——
        // 同时修好画线与回放（二者同源读 recorder），不动底层物理。
        let rawPlayback = TrajectoryPlayback(recorder: run.recorder, surfaceY: y + r)
        let (clampedRecorder, effDuration) = clampedRecorder(
            from: rawPlayback,
            names: [ShotInput.cueBallName, ShotInput.targetBallName],
            duration: run.recorder.duration, surfaceY: y + r
        )
        result.recorder = clampedRecorder
        result.duration = effDuration
        let playback = TrajectoryPlayback(recorder: clampedRecorder, surfaceY: y + r)
        result.cuePath = polyline(playback, ballName: ShotInput.cueBallName, duration: effDuration)
        result.objectPath = polyline(playback, ballName: ShotInput.targetBallName, duration: effDuration)
        result.cuePocketed = run.cuePocketed

        // 进袋判定（轨迹基，画面=物理）：以**显示用钳制轨迹**的目标球最近点是否进入选定袋
        // 的捕获窗（袋心 ± (pocketRadius − R)）为准，而非引擎 pocket 事件。
        // 原因：事件驱动引擎在袋口喇叭口偶发「穿库」（约 8%）会登记 pocket 事件但真实轨迹其实
        // 飞出/被钳——若直接采信引擎事件，会出现「判进但画面里球没到袋」的不一致假阳性
        // （E-solver 45°/55° 高速过力度即触发）。改用轨迹最近点后，进袋与所画轨迹始终一致，
        // 且「过力度打薄切角 rattle 出来」如实呈现为未进。
        let captureWindow =
            AngleSceneCalculator.pocketDropRadius(index: input.pocketIndex) - r + 0.003
        var objMinToPocket = Float.greatestFiniteMagnitude
        if let frames = clampedRecorder.framesByBallName[ShotInput.targetBallName] {
            for f in frames {
                let dx = f.position.x - pocketCenter.x
                let dz = f.position.z - pocketCenter.z
                objMinToPocket = min(objMinToPocket, sqrtf(dx * dx + dz * dz))
            }
        }
        let potted = objMinToPocket <= captureWindow
        result.simObjectPotted = potted
        result.objectPocketed = potted

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
    }

    /// 以 `aimDir` 方向、`velocity` 力度发射母球并模拟，返回结果。
    private static func runShot(
        aimDir: SCNVector3, velocity: Float, input: ShotInput,
        geometry: TableGeometry, pocketCenter: SCNVector3, ghost: SCNVector3,
        maxEvents: Int, maxTime: Float
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
        engine.simulate(maxEvents: maxEvents, maxTime: maxTime)
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
        // 不再用距离容差甄别）。
        var objectPocketId: String?
        for ev in engine.resolvedEvents {
            if case .pocket(let ball, let pid) = ev, ball == ShotInput.targetBallName {
                objectPocketId = pid
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
            cueGhostMinDist: cueGhostMinDist
        )
    }

    // MARK: - Table clamp（穿库安全网）

    /// 球心可玩区半幅（库边接触时球心最大偏移 = 内框半幅 − R）。留一点余量避免误伤正常吃库。
    private static func playableContains(_ p: SCNVector3, halfL: Float, halfW: Float, pockets: [SCNVector3]) -> Bool {
        let r = BallPhysics.radius
        let margin: Float = 0.006
        if abs(p.x) <= halfL - r + margin && abs(p.z) <= halfW - r + margin { return true }
        // 袋口缺口：球心进入任一袋口附近（袋口嘴）属合法进袋路径，不钳制。
        // 角袋中心在内框矩形外约 8.3cm，球进角袋必先穿出矩形角再抵袋心，故允许半径须
        // ≥ 该过渡走廊（取 0.12 留余量），否则会把正常进袋球冻结在矩形角而漏进袋。
        // 真正的「穿库飞出」会远离所有袋口（数米外），仍会在越过该半径后被冻结。
        let pocketMouth: Float = 0.12
        for pk in pockets {
            let dx = p.x - pk.x, dz = p.z - pk.z
            if dx * dx + dz * dz <= pocketMouth * pocketMouth { return true }
        }
        return false
    }

    /// 把越界球心钳回库边矩形（球心可玩区）。
    private static func clampToPlayable(_ p: SCNVector3, halfL: Float, halfW: Float) -> SCNVector3 {
        let r = BallPhysics.radius
        let x = max(-(halfL - r), min(halfL - r, p.x))
        let z = max(-(halfW - r), min(halfW - r, p.z))
        return SCNVector3(x, p.y, z)
    }

    /// 按固定步长解析重采样轨迹到一个新 recorder：任一球「离开可玩区且不在袋口」即把它钳到
    /// 库边并冻结（其后保持静止），从而截断穿库飞出的轨迹。返回 (钳制后的 recorder, 有效时长)。
    /// 有效时长 = 所有球都已静止/进袋/冻结之后再留 0.1s 的时刻（避免长尾空播）。
    private static func clampedRecorder(
        from playback: TrajectoryPlayback, names: [String], duration: Float, surfaceY: Float
    ) -> (TrajectoryRecorder, Float) {
        let out = TrajectoryRecorder()
        guard duration > 1e-4 else {
            for name in names {
                if let s = playback.stateAt(ballName: name, time: 0) {
                    out.recordFrame(ballName: name, frame: BallFrame(
                        time: 0, position: s.position, velocity: s.velocity,
                        angularVelocity: SCNVector4Zero, state: s.motionState))
                }
            }
            return (out, duration)
        }

        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        let dt: Float = 1.0 / 120.0
        var frozen: [String: SCNVector3] = [:]
        var lastActive: Float = 0
        var t: Float = 0
        while t <= duration + 1e-4 {
            let tc = min(t, duration)
            for name in names {
                guard let s = playback.stateAt(ballName: name, time: tc) else { continue }
                var pos = s.position
                var vel = s.velocity
                var state = s.motionState
                if let fz = frozen[name] {
                    pos = fz; vel = SCNVector3Zero; state = .stationary
                } else if state != .pocketed,
                          !playableContains(pos, halfL: halfL, halfW: halfW, pockets: pockets) {
                    pos = clampToPlayable(pos, halfL: halfL, halfW: halfW)
                    vel = SCNVector3Zero; state = .stationary
                    frozen[name] = pos
                }
                out.recordFrame(ballName: name, frame: BallFrame(
                    time: t, position: pos, velocity: vel, angularVelocity: SCNVector4Zero, state: state))
                if state != .stationary && state != .pocketed && vel.length() > 0.02 {
                    lastActive = t
                }
            }
            // 全部静止/进袋/冻结即可停止采样。
            let allDone = names.allSatisfy { name in
                if frozen[name] != nil { return true }
                guard let s = playback.stateAt(ballName: name, time: tc) else { return true }
                return s.motionState == .pocketed || s.motionState == .stationary || s.velocity.length() <= 0.02
            }
            if allDone && t > 0 { break }
            t += dt
        }
        let eff = min(duration, lastActive + 0.1)
        return (out, max(eff, 0.05))
    }

    /// XZ 平面内点 `p` 到线段 `a–b` 的最近距离。
    private static func segmentPointDistanceXZ(a: SCNVector3, b: SCNVector3, p: SCNVector3) -> Float {
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

    /// 搜索使**模拟中的目标球真正进选定袋**的瞄准角偏移（弧度）。
    ///
    /// 评分 = `objMinDist`（目标球轨迹到选定袋口中心的最近水平距离）。这是终极目标量：
    /// 一个瞄准偏移可同时补偿 **squirt（挤偏）+ swerve（滑行弧线）+ collision throw（碰撞投掷）**
    /// ——前两者改变母球抵达的接触点，后者由侧塞在碰撞瞬间额外偏转目标球；三者都体现在目标球
    /// 最终能否抵达袋口上，故直接以「目标球离袋口多近」评分最稳健（这正是用户要的「采样求正确瞄准点」）。
    /// 未碰到目标球时目标球不动 → `objMinDist` 是常数平台，叠加母球-幽灵球距离 `cueGhostMinDist`
    /// 提供梯度，把搜索拉向命中带。三遍逐级细化（粗→中→细）在较宽范围收敛。
    private static func solveAimOffset(
        baseAim: SCNVector3, velocity: Float, input: ShotInput,
        geometry: TableGeometry, pocketCenter: SCNVector3, ghost: SCNVector3
    ) -> Float {
        // 搜索用短时模拟：事件/时间放宽，确保目标球完整抵达袋口（含远袋低速、吃库球），
        // 否则 objMinDist 会在球到袋前就被截断、误导评分。
        let searchEvents = 140
        let searchTime: Float = 7.0

        // 评分（越小越优）。物理保真的关键：以「短模拟里目标球是否真进了选定袋」为**首要**
        // 信号锁定进球带，而非仅靠 objMinDist 的连续逼近——后者在窄喉口/强切角下景观多峰，
        // 粗扫易落入「擦边但没进」或「母球进袋(scratch)」的坏局部最优。
        func score(_ offset: Float) -> Float {
            let run = runShot(
                aimDir: baseAim.rotatedY(offset), velocity: velocity, input: input,
                geometry: geometry, pocketCenter: pocketCenter, ghost: ghost,
                maxEvents: searchEvents, maxTime: searchTime
            )
            if run.pottedSelected {
                // 真进选定袋 = 最优区。−10 基线让任何进球解都压过一切「未进」解（objMinDist≥0）。
                // clean pot 优于 scratch pot（+0.5），同为进球时优先最小修正角（省力、最自然）。
                return -10 + (run.cuePocketed ? 0.5 : 0) + abs(offset) * 1e-3
            }
            // 未进：以目标球到袋口最近距离（米，~0.01–0.1）为主。
            // ⚠️ scratch 罚必须是 mm 量级（0.002），**绝不可**用 1.0 这类大值——否则会压过
            //   objMinDist，把求解器从「更接近进袋但可能刮杆」逼到「不进也不刮」的差解（FL: 45°回归）。
            // 没碰到目标球时叠加母球-幽灵球距离梯度指向命中带。
            let base = (run.objPostContactDir == nil)
                ? (run.objMinDist + run.cueGhostMinDist)
                : run.objMinDist
            return base + (run.cuePocketed ? 0.002 : 0) + abs(offset) * 1e-4
        }

        let deg = Float.pi / 180
        func bestOf(center: Float, halfRange: Float, step: Float) -> (offset: Float, score: Float) {
            var bo = center
            var bs = Float.greatestFiniteMagnitude
            var o = center - halfRange
            while o <= center + halfRange + 1e-6 {
                let s = score(o)
                if s < bs { bs = s; bo = o }
                o += step
            }
            return (bo, bs)
        }

        // 粗扫 ±16°/0.5°（65 样本）覆盖强侧塞 squirt + 滑行 swerve，并把粗扫步长收到 0.5°，
        // 保证宽度≥0.5° 的进球带不被跳过（薄球远袋的进球带很窄）；
        // 中扫 ±0.6°/0.1°（13）、细扫 ±0.12°/0.02°（13）逐级收敛到亚毫米级接触点。
        // 性能由 Han 闭式库边模型保证（单次模拟 O(1)），~91 次短时模拟仍在几十毫秒级。
        let c = bestOf(center: 0, halfRange: 16 * deg, step: 0.5 * deg)
        let m = bestOf(center: c.offset, halfRange: 0.6 * deg, step: 0.1 * deg)
        let f = bestOf(center: m.offset, halfRange: 0.12 * deg, step: 0.02 * deg)
        return f.offset
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
