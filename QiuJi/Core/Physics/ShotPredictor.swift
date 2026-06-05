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
        // 钳制/重采样**全部球**（含走位编排器的障碍球），让多球场景的回放也能逐帧驱动每颗球。
        // 单母球+单目标的旧调用路径自动退化为两颗（行为不变）。
        let clampNames = Array(run.recorder.framesByBallName.keys)
        let (clampedRecorder, effDuration) = clampedRecorder(
            from: rawPlayback,
            names: clampNames.isEmpty ? [ShotInput.cueBallName, ShotInput.targetBallName] : clampNames,
            duration: run.recorder.duration, surfaceY: y + r
        )
        result.recorder = clampedRecorder
        result.duration = effDuration
        let playback = TrajectoryPlayback(recorder: clampedRecorder, surfaceY: y + r)
        result.cuePath = polyline(playback, ballName: ShotInput.cueBallName, duration: effDuration)
        result.objectPath = polyline(playback, ballName: ShotInput.targetBallName, duration: effDuration)

        // 母球进袋判定（画面=物理）：与目标球同源——以引擎信号为权威，但用**显示用钳制轨迹**的
        // 最近点做一致性闸门。否则会出现「判进画面不进」假阳性：母球带塞走位弧线掠过中袋嘴时，
        // 袋口 CCD 按直线/抛物线预测排程进袋事件，而曲线母球实际只擦到 54–65mm（>捕获窗、未真正落入
        // 漏斗），引擎 `resolvePocket` 的宽松接受阈值仍判落袋 → 上报「母球进袋」但白线根本没到袋心。
        // 闸门：母球钳制轨迹须真正落入**某个袋**的捕获窗（落袋后引擎吸球心 → 最近点≈0）。
        var cuePocketed = run.cuePocketed
        if cuePocketed, let cueFrames = clampedRecorder.framesByBallName[ShotInput.cueBallName] {
            var reachedAnyPocket = false
            for (pi, p) in pockets.enumerated() {
                let win = AngleSceneCalculator.pocketDropRadius(index: pi) - r + 0.004
                for f in cueFrames {
                    let dx = f.position.x - p.x, dz = f.position.z - p.z
                    if dx * dx + dz * dz <= win * win { reachedAnyPocket = true; break }
                }
                if reachedAnyPocket { break }
            }
            cuePocketed = reachedAnyPocket
        }
        result.cuePocketed = cuePocketed

        // 进袋判定（画面=物理）：以引擎「目标球真正落入**选定**袋」(`run.pottedSelected`) 为
        // 权威信号，并用**显示用钳制轨迹**的最近点做一致性闸门（袋心 ± (dropRadius − R)）。
        // 漏斗模型 v3 下：落袋时引擎把球心吸到袋心 → 钳制轨迹最近点≈0；偏离/过力度球撞 jaw
        // 反弹未落袋 → 最近点远大于捕获窗。两者天然一致，既消除旧「穿库假阳性」也消除旧
        // 「真落袋却因事件采样帧停在喉口外被判未进」的假阴性（cut15/v3.3 闪烁根因）。
        let captureWindow =
            AngleSceneCalculator.pocketDropRadius(index: input.pocketIndex) - r + 0.004
        var objMinToPocket = Float.greatestFiniteMagnitude
        if let frames = clampedRecorder.framesByBallName[ShotInput.targetBallName] {
            for f in frames {
                let dx = f.position.x - pocketCenter.x
                let dz = f.position.z - pocketCenter.z
                objMinToPocket = min(objMinToPocket, sqrtf(dx * dx + dz * dz))
            }
        }
        let potted = run.pottedSelected && objMinToPocket <= captureWindow
        result.simObjectPotted = potted
        result.objectPocketed = potted
        result.cueCushionCount = run.cueCushions
        result.objectCushionCount = run.objCushionsBeforePocket
        result.cueCushionsBeforeContact = run.cueCushionsBeforeContact

        // 4.5) 全场最终静止位置 + 进袋球名（走位序列链，ADR-P11-01）。
        //      障碍球取真实模拟末帧；母球/目标球用防穿库钳制轨迹末帧覆盖（与画面一致）。
        var finals: [String: SCNVector3] = [:]
        var pocketed: [String] = []
        for (name, frames) in run.recorder.framesByBallName {
            if let last = frames.max(by: { $0.time < $1.time }) {
                finals[name] = last.position
            }
            if run.recorder.isBallPocketed(name) { pocketed.append(name) }
        }
        for name in [ShotInput.cueBallName, ShotInput.targetBallName] {
            if let frames = clampedRecorder.framesByBallName[name],
               let last = frames.max(by: { $0.time < $1.time }) {
                finals[name] = last.position
            }
        }
        // 进袋判定以一致性闸门后的结果为准（消除穿库假阳性 / 喉口假阴性）。
        if cuePocketed, !pocketed.contains(ShotInput.cueBallName) { pocketed.append(ShotInput.cueBallName) }
        if !cuePocketed { pocketed.removeAll { $0 == ShotInput.cueBallName } }
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
        /// 母球全程吃库次数（供反解按截图标注的吃库数约束）。
        let cueCushions: Int
        /// 母球在**首次球-球碰撞前**的吃库次数（0 = 直瞄直击；≥1 = 绕库/kick 进攻路线）。
        let cueCushionsBeforeContact: Int
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
        // 走位编排器多球场景（ADR-P11-01）：其余在桌球作静止障碍/碰撞体一并入引擎。
        for ob in input.obstacles
        where ob.name != ShotInput.cueBallName && ob.name != ShotInput.targetBallName {
            engine.setBall(BallState(
                position: SCNVector3(ob.position.x, y + r, ob.position.z),
                velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero,
                state: .stationary, name: ob.name
            ))
        }
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
        // 不再用距离容差甄别）。同时统计目标球落袋前撞库次数（直接 vs 吃库进袋）。
        var objectPocketId: String?
        var objCushionsBeforePocket = 0
        var cueCushions = 0
        var cueCushionsBeforeContact = 0
        var sawBallBall = false
        for ev in engine.resolvedEvents {
            switch ev {
            case .ballBall:
                sawBallBall = true
            case .ballCushion(let ball, _, _) where ball == ShotInput.targetBallName:
                if objectPocketId == nil { objCushionsBeforePocket += 1 }
            case .ballCushion(let ball, _, _) where ball == ShotInput.cueBallName:
                cueCushions += 1
                if !sawBallBall { cueCushionsBeforeContact += 1 }
            case .pocket(let ball, let pid) where ball == ShotInput.targetBallName:
                objectPocketId = pid
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
            cueCushions: cueCushions,
            cueCushionsBeforeContact: cueCushionsBeforeContact
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
        let r = BallPhysics.radius
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)
        let dt: Float = 1.0 / 120.0
        // 真·穿库（飞出台面）判定阈值：球心越过库边内框 ≥ 6cm 且不在任何袋口嘴内，才视为
        // 飞出 → 冻结并截断。低于此阈值的「越界」是**吃库接触瞬间**的回放外推过冲（见下），
        // 只做化妆性钳位、不冻结。袋口嘴半径放宽到 14cm，覆盖球贴角袋/中袋 jaw 的合法入袋路径。
        let farMargin: Float = 0.06
        let pocketMouth: Float = 0.14

        // 真·穿库判定**基于原始事件帧（物理真值）**，而非固定步长重采样的解析外推位置：
        // 正常吃库反弹时引擎在库线（球心 ±(halfW−R)/(halfL−R)）处反弹并 enforceTableBounds 钳回，
        // 记录帧绝不会越过库线；只有「事件帧→下一帧」之间的解析外推才会瞬时冲过库线几毫米~十几
        // 厘米（事件采样产物，吃库越快冲得越远）。若按重采样位置判飞出，高速吃库会被误判 → 把仍
        // 高速运动的球错误冻结在库边（FL：吃库后立即停住）。改为：扫描每个球的**记录帧**，仅当
        // 记录帧本身越界 ≥6cm 且远离所有袋口嘴(14cm) 才认定真飞出，取其首次时刻为冻结时刻。
        func isTrueEscape(_ p: SCNVector3) -> Bool {
            let farOut = abs(p.x) > halfL - r + farMargin || abs(p.z) > halfW - r + farMargin
            guard farOut else { return false }
            let nearPocket = pockets.contains { pk in
                let dx = p.x - pk.x, dz = p.z - pk.z
                return dx * dx + dz * dz <= pocketMouth * pocketMouth
            }
            return !nearPocket
        }
        var freezeTime: [String: Float] = [:]
        for name in names {
            guard let frames = playback.recorder.framesByBallName[name]?
                .sorted(by: { $0.time < $1.time }) else { continue }
            for f in frames where f.state != .pocketed {
                if isTrueEscape(f.position) { freezeTime[name] = f.time; break }
            }
        }

        var frozen: [String: SCNVector3] = [:]
        var lastActive: Float = 0
        var lastPocket: Float = -1
        // 「有效停止」速度阈值：球减速到此速度以下基本肉眼静止（剩余蠕行 <~3cm、<1s），
        // 不再据其延长有效时长——否则母球/目标球走位末尾的缓慢蠕行会让「复位」迟迟不触发
        // （用户：母球停下后还在等目标球停）。同时**单独记录进袋时刻**，保证缓行入袋的「落袋」
        // 一帧仍被纳入（不会因阈值把真实进袋截成未进）。
        let stopSpeed: Float = 0.07
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
                } else if state != .pocketed {
                    if let ft = freezeTime[name], tc >= ft - 1e-4 {
                        // 真·穿库飞出（记录帧确证）：冻结在库边并截断其后轨迹。
                        pos = clampToPlayable(pos, halfL: halfL, halfW: halfW)
                        vel = SCNVector3Zero; state = .stationary
                        frozen[name] = pos
                    } else if !playableContains(pos, halfL: halfL, halfW: halfW, pockets: pockets) {
                        // 吃库接触/袋口嘴的瞬时外推过冲（非真飞出）：仅化妆性钳位（球心拉回库边）
                        // 但**保持速度/运动态、不截断**，球继续按真实轨迹运动。
                        pos = clampToPlayable(pos, halfL: halfL, halfW: halfW)
                    }
                }
                out.recordFrame(ballName: name, frame: BallFrame(
                    time: t, position: pos, velocity: vel, angularVelocity: SCNVector4Zero, state: state))
                // 仍在「可感知运动」（速度 > stopSpeed）才延长有效时长；缓行蠕停不计。
                if state != .stationary && state != .pocketed && vel.length() > stopSpeed {
                    lastActive = t
                }
                if state == .pocketed { lastPocket = max(lastPocket, t) }
            }
            // 全部静止/进袋/冻结即可停止采样（按运动态判定，不再用速度阈值提前结束）。
            let allDone = names.allSatisfy { name in
                if frozen[name] != nil { return true }
                guard let s = playback.stateAt(ballName: name, time: tc) else { return true }
                return s.motionState == .pocketed || s.motionState == .stationary
            }
            if allDone && t > 0 { break }
            t += dt
        }
        // 有效时长 = 最后可感知运动后 +0.1s；若有进袋，确保覆盖到落袋一帧（+0.2s 看清落袋）。
        let activeEnd = lastActive + 0.1
        let pocketEnd = lastPocket >= 0 ? lastPocket + 0.2 : 0
        let eff = min(duration, max(activeEnd, pocketEnd))
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

    /// 搜索最优瞄准角偏移（弧度）。
    ///
    /// **核心目标 = 让目标球碰后沿正确的「进球线方向」（target→袋心）离开，而非强行进袋。**
    /// 用户洞察：大切角 + 小力度时目标球袋向动能不足、进不去是**可接受**的（如实报未进），
    /// 但**进球线方向必须对**。旧版「未进时退化为最小化 objMinDist（到袋心最近距离）」会挑到
    /// 「绕库擦袋」的多库翻袋解（初始方向错、只是反弹后蹭到袋附近）——正是用户看到的"大角度变
    /// 翻袋"。改为**首要评分 = 目标球碰后方向与进球线方向的夹角误差**：该误差对偏移**平滑单峰**
    /// （objDir 随 offset 连续变化），自动补偿 squirt+swerve+collision throw（取自实测碰后方向），
    /// 且天然排斥 banking（绕库解碰后初始方向指向库而非袋 → 误差大）。进袋/不刮母球仅作**极小
    /// 量级 tiebreak**：方向几乎相同时优先「真落袋且不刮杆」。
    ///
    /// 平滑单峰景观 ⇒ 不再需要 0.2° 密梳（那是为旧"碎裂进袋带"防漏），粗 0.5°→中→细即可稳定
    /// 收敛，顺带把单次 predict 开销降回 ~75 次短模拟。
    /// `solveAimOffset` 的评分与搜索参数（D-B4/D-D2：原为散落经验魔数，抽成具名常量并注明含义/量纲；
    /// 数值未改动）。修改任一权重/保真后必须跑 `PhysicsMatrixTests`（进袋合约 + 宏观确定性）守回归。
    private enum AimScoring {
        /// 搜索阶段每次短模拟的事件/时长上限。**与最终模拟同保真**——历史上降保真会与"最终全保真"
        /// 产生双景观错位（搜到的解上报时变样）；D-D2 若要降保真须先过矩阵护栏。
        static let searchMaxEvents = 500
        static let searchMaxTime: Float = 15.0
        /// ① 直接干净进袋解的基线分（足够负，压过任何方向解 acos∈[0,π]）。
        static let cleanPotBaseline: Float = -10
        /// 直接进袋解里母球同时刮袋(scratch)的惩罚（极小 tiebreak：clean 进袋优先不刮杆，不抬到方向解之上）。
        static let cleanPotScratchPenalty: Float = 0.3
        /// 方向解里母球刮袋的惩罚（极小 tiebreak；历史上用 1.0 会挑到差解）。
        static let directionScratchPenalty: Float = 0.05
        /// 母球碰目标球前每次绕库(kick)的惩罚（FL-020：方向解里也优先直瞄候选，压退化 kick 解抬头）。
        static let cueKickPenaltyPerCushion: Float = 0.3
        /// 瞄准偏移正则项系数（rad⁻¹）：同分时偏好更小偏移，使景观有唯一极小、解稳定。
        static let offsetRegularization: Float = 1e-3
        /// 未命中目标球时的大基线（≫ π + 进袋 −10），叠加母球-幽灵球最近距离做命中梯度。
        static let missBaseline: Float = 100
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

        // 进球线方向（target→袋心，XZ 单位向量）：目标球应沿此方向离开。
        let pdx = pocketCenter.x - input.targetBall.x
        let pdz = pocketCenter.z - input.targetBall.z
        let pdl = max(sqrtf(pdx * pdx + pdz * pdz), 1e-5)
        let pockDirX = pdx / pdl, pockDirZ = pdz / pdl

        func score(_ offset: Float) -> Float {
            let run = runShot(
                aimDir: baseAim.rotatedY(offset), velocity: velocity, input: input,
                geometry: geometry, pocketCenter: pocketCenter, ghost: ghost,
                maxEvents: searchEvents, maxTime: searchTime
            )
            guard let od = run.objPostContactDir else {
                // 未碰到目标球：大基线（≫ 任何方向误差 π + 进袋 −10），母球-幽灵球距离梯度拉向命中。
                return AimScoring.missBaseline + run.cueGhostMinDist
            }
            // ① 能**直接进袋**（0 撞库，球穿过 jaw 开口落袋）= 最优区：−10 基线压过一切「方向解」。
            //    直接进袋的瞄点会**穿喉口**（常略偏几何袋心以避开 jaw 鼻），故必须用真实进袋
            //    而非"瞄准袋心方向误差"来认定——后者瞄死袋心反而擦 jaw 出来。clean 优于 scratch。
            //    **额外要求母球碰目标球前 0 吃库**：否则"母球打丢→绕库→歪打正着碰目标球→恰好进袋"
            //    的 kick 退化解也会拿 −10，与真直击解打平，叠加引擎遍历浮点非确定性会令两个完全
            //    不同的解在运行间随机翻转（FL：t3p5 等 30 次重复 cuePreBank 在 0/4 间跳、分离角跨 2°）。
            //    钉死「直击解」唯一占据最优区，是确定性的根本保证之一。
            if run.pottedSelected && run.objCushionsBeforePocket == 0 && run.cueCushionsBeforeContact == 0 {
                return AimScoring.cleanPotBaseline
                    + (run.cuePocketed ? AimScoring.cleanPotScratchPenalty : 0)
                    + abs(offset) * AimScoring.offsetRegularization
            }
            // ② 否则（进袋不可达 / 只能吃库进）：按**进球线方向误差**（用户要求：方向必须对，
            //    力度不足进不去可接受、但不要绕库蹭袋）。目标球碰后方向 vs target→袋心 夹角（rad）。
            //    吃库进袋(objCushions≥1)的碰后初始方向指向库 → 误差大 → 自然排在直接进之后、且不会
            //    被当成"好解"凌驾于"方向正确的直接未进"。
            let dot = max(-1, min(1, od.x * pockDirX + od.z * pockDirZ))
            var s = acosf(dot)
            if run.cuePocketed { s += AimScoring.directionScratchPenalty }
            // 母球碰目标球前绕库的进攻路线（kick）轻惩罚：方向解里也优先「直瞄」候选，避免退化解抬头。
            s += Float(run.cueCushionsBeforeContact) * AimScoring.cueKickPenaltyPerCushion
            s += abs(offset) * AimScoring.offsetRegularization
            return s
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
