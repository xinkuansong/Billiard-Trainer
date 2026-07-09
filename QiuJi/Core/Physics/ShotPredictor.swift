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

    /// 翻袋库序（W1，ADR-P18-XX / 20260709 翻袋反射页重构方案 §2.1）。
    /// nil / 空 = 直击（现行为逐位不变）；非空 = 反解「母球**直击**目标球，目标球经该库序
    /// 真实翻库进 `pocketIndex` 袋」。种子方向来自镜像展开（`BankShotCalculator.bankSeedPath`），
    /// 评分判据 = 引擎口径真实进袋（squirt / throw / 传旋 / 速度衰减全由引擎裁决）。
    /// 类型直接复用 `BankShotCalculator.Rail`（同 target 无编译边界，库枚举语义单一真源）。
    var bankRails: [BankShotCalculator.Rail]? = nil

    /// 反射/kick 库序（W2，20260709 翻袋反射页重构方案 §2.1）。
    /// nil / 空 = 直击（现行为逐位不变）；非空 = 反解「母球以真实击杆状态（滑动→自然滚动
    /// 过渡）经该库序碰到目标球」——『碰到』= 引擎口径的真实球-球碰撞事件，障碍球是真实
    /// 碰撞体。无进袋语义（`pocketIndex` 不参与判定）。种子方向来自镜像展开
    /// （`DiamondSystemCalculator.kickSeedPath`）。与 `bankRails` 互斥（bank 优先）。
    var kickRails: [DiamondSystemCalculator.Rail]? = nil

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

/// 一次模拟中按时间排序的关键事件（走位反解器分析「过点后碰撞的第一颗球」「到点前吃库数」用，
/// ADR-P13-01）。从引擎 `resolvedEvents` 抽取，剔除 `transition`（纯状态切换无几何语义）。
struct ShotEvent {
    enum Kind {
        case ballBall(ballA: String, ballB: String)
        case ballCushion(ball: String)
        case pocket(ball: String, pocketId: String)
    }
    let time: Float
    let kind: Kind
}

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
    /// 母球末帧水平速度大小（m/s）。`0` = 真正停稳；显著 >0 = 模拟被 maxEvents/maxTime 截断、
    /// 末帧并非真实停点（走位反解器据此剔除「高速假停」的落区解，ADR-P13-01）。
    var cueFinalSpeed: Float = 0
    /// 除母球（及袋口模式的目标球，其轨迹走 `objectPath`）外**发生位移**的球的轨迹折线
    /// （球名 → 折线）。线语言 v2（条 12.4）：袋口模式也填充被串动的障碍球，供各页画本色虚线。
    var extraBallPaths: [String: [SCNVector3]] = [:]
    /// 本杆进袋（离场）的全部球名（含母球 scratch、被串入袋的障碍球）。
    var pocketedBalls: [String] = []
    /// 按时间排序的关键事件（球-球碰撞 / 吃库 / 落袋）。默认空——仅 `predict` / `simulateFree`
    /// 填充。旧调用与序列化零影响（ADR-P13-01，走位反解器消费）。
    var events: [ShotEvent] = []
    /// 本次预测实际使用的瞄准偏移（弧度，相对几何基线 `aimDirection` 前的 ctx.aimDir）。
    /// 仅走位反解快速路径填充（B1：代表解用同一 offset 重建完整 prediction，保证同物理）。
    var aimOffsetUsed: Float?
    /// kick 反解成功判据（W2）：母球首次球-球碰撞对象 == 目标球，且碰前吃库数 ≥ 指定库序数。
    /// 仅 `kickRails` 非空的预测填充；直击/翻袋管线恒为 false。
    var kickContactMade: Bool = false
}

// MARK: - Predictor

enum ShotPredictor {

    /// 求解一次击球的完整轨迹与分离角。
    static func predict(
        _ input: ShotInput,
        maxEvents: Int = 500,
        maxTime: Float = 15.0
    ) -> ShotPrediction {
        // 1) 瞄准几何 + 可行性闸门（不可进直接返回）。
        var result = ShotPrediction()
        guard let ctx = prepareAim(input, into: &result) else { return result }

        // 1b) 翻袋反解（W1）：四层管线求瞄准偏移 + 代表解引擎全保真终验物化。
        if let rails = input.bankRails, !rails.isEmpty {
            return predictBank(input: input, rails: rails, context: ctx, result: result,
                               maxEvents: maxEvents, maxTime: maxTime)
        }
        // 1c) 反射/kick 反解（W2）：同管线（种子 → 解析目标函数 → 歧义回退 → 终验物化）。
        if let rails = input.kickRails, !rails.isEmpty {
            return predictKick(input: input, rails: rails, context: ctx, result: result,
                               maxEvents: maxEvents, maxTime: maxTime)
        }

        // 2) 闭环瞄准求解：短模拟评分搜索使目标球进选定袋的发射方向（吸收 squirt/throw/swerve）。
        let bestOffset = solveAimOffset(
            baseAim: ctx.aimDir, velocity: input.velocity, input: input,
            geometry: ctx.geometry, pocketCenter: ctx.pocketCenter, ghost: ctx.ghost
        )

        // 3) 用最优方向跑完整模拟并提取全部预测字段（共享核心 `buildPrediction`）。
        let finalAim = ctx.aimDir.rotatedY(bestOffset)
        return buildPrediction(finalAim: finalAim, context: ctx, input: input,
                               result: result, maxEvents: maxEvents, maxTime: maxTime)
    }

    // MARK: - Shared aim geometry + prediction core (供 predict 与走位反解快速路径复用)

    /// 瞄准几何上下文：仅取决于母球/目标球/袋口位置，**与塞/力度无关**——故走位反解器可对一组
    /// 候选只算一次、跨 spinY 复用（ADR-P13-01）。
    struct AimContext {
        let aimPoint: SCNVector3
        let ghost: SCNVector3
        let aimDir: SCNVector3
        let geometry: TableGeometry
        let pocketCenter: SCNVector3
    }

    /// 计算瞄准几何（幽灵球法 + 进球管道修正）并跑可行性闸门，顺带回填 `result` 的瞄准/几何字段。
    /// 返回 nil = 几何不可进袋（`result` 已置 `feasible=false` + 原因，调用方直接返回）。
    static func prepareAim(_ input: ShotInput, into result: inout ShotPrediction) -> AimContext? {
        // 翻袋库序：瞄准几何改由镜像展开种子给出（bank 分支）。
        if let rails = input.bankRails, !rails.isEmpty {
            return prepareBankAim(input, rails: rails, into: &result)
        }
        // 反射/kick 库序：瞄准几何 = 母球经镜像展开首库反弹点的出发方向（kick 分支）。
        if let rails = input.kickRails, !rails.isEmpty {
            return prepareKickAim(input, rails: rails, into: &result)
        }
        let y = input.surfaceY
        let r = BallPhysics.radius
        // 若调用方提供 `pocketAimOverride`（反解把进球点当自由变量），直接采用该进球点。
        let aimPoint = input.pocketAimOverride ?? AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: input.targetBall, pocketIndex: input.pocketIndex, surfaceY: y
        )
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: input.targetBall, pocket: aimPoint, ballRadius: r
        )
        let aimDir = unitXZ(from: input.cueBall, to: ghost)
        result.aimDirection = aimDir
        result.ghost = ghost
        result.pocketAimPoint = aimPoint

        let cutAngle = AngleSceneCalculator.cutAngle(
            cueBall: input.cueBall, targetBall: input.targetBall, pocket: aimPoint
        )
        result.cutAngleDeg = cutAngle
        if cutAngle >= AngleSceneCalculator.maxCutAngle {
            result.feasible = false
            result.infeasibleReason = "当前角度无法进袋（切角过大）"
            return nil
        }
        if AngleSceneCalculator.isCueBallBlocking(
            cueBall: input.cueBall, targetBall: input.targetBall, pocket: aimPoint
        ) {
            result.feasible = false
            result.infeasibleReason = "母球挡住进球路线，无法进袋"
            return nil
        }
        // 几何统一：CAD 真源几何（袋口孔心 = pocketPositions，ADR-P10-09）。模拟几何 == 瞄准几何。
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: y)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: y)
        return AimContext(aimPoint: aimPoint, ghost: ghost, aimDir: aimDir,
                          geometry: geometry, pocketCenter: pockets[input.pocketIndex])
    }

    // MARK: - Bank aim geometry（W1，第 0 层：镜像展开种子）

    /// 翻袋瞄准几何：镜像展开种子路径给出目标球出发方向 → 幽灵球 / 瞄准线。
    /// 返回 nil = 该库序无几何种子或切角/母球占位不可行（候选淘汰，`result` 已置原因）。
    /// 坐标契约：SceneKit 世界系，XZ 水平面、+Y 朝上；ghost = target − 2R·unit(出发方向)。
    static func prepareBankAim(
        _ input: ShotInput, rails: [BankShotCalculator.Rail], into result: inout ShotPrediction
    ) -> AimContext? {
        let y = input.surfaceY
        let r = BallPhysics.radius
        guard let seedPath = BankShotCalculator.bankSeedPath(
            object: input.targetBall, pocketIndex: input.pocketIndex,
            rails: rails, surfaceY: y
        ), seedPath.count >= 2 else {
            result.feasible = false
            result.infeasibleReason = "该库序无几何种子路线"
            return nil
        }
        // 目标球出发方向（XZ 单位向量，指向首库反弹点）。
        let firstHop = seedPath[1]
        let dir = unitXZ(from: seedPath[0], to: firstHop)
        let ghost = SCNVector3(input.targetBall.x - 2 * r * dir.x,
                               input.targetBall.y,
                               input.targetBall.z - 2 * r * dir.z)
        let aimDir = unitXZ(from: input.cueBall, to: ghost)
        result.aimDirection = aimDir
        result.ghost = ghost
        result.pocketAimPoint = seedPath[seedPath.count - 1]

        // 切角 = 瞄准线 vs 目标球出发线（把首库反弹点当作「进球点」复用同一几何）。
        let cutAngle = AngleSceneCalculator.cutAngle(
            cueBall: input.cueBall, targetBall: input.targetBall, pocket: firstHop
        )
        result.cutAngleDeg = cutAngle
        if cutAngle >= AngleSceneCalculator.maxCutAngle {
            result.feasible = false
            result.infeasibleReason = "当前角度无法翻袋（切角过大）"
            return nil
        }
        // 母球占位：不能坐在目标球的出发线段上。
        if AngleSceneCalculator.isCueBallBlocking(
            cueBall: input.cueBall, targetBall: input.targetBall, pocket: firstHop
        ) {
            result.feasible = false
            result.infeasibleReason = "母球挡住目标球出发路线"
            return nil
        }
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: y)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: y)
        return AimContext(aimPoint: result.pocketAimPoint, ghost: ghost, aimDir: aimDir,
                          geometry: geometry, pocketCenter: pockets[input.pocketIndex])
    }

    // MARK: - Kick aim geometry（W2，第 0 层：镜像展开种子）

    /// 反射/kick 瞄准几何：镜像展开种子路径给出母球出发方向（指向首库反弹点）。
    /// 返回 nil = 该库序无几何种子（候选淘汰，`result` 已置原因）。
    /// 坐标契约：SceneKit 世界系，XZ 水平面、+Y 朝上；kick 无幽灵球反推（母球自己是运动体），
    /// `ghost` 复用为**接触锚点** = 目标球心沿种子末段来向反向退 2R（评分 miss 梯度锚）。
    static func prepareKickAim(
        _ input: ShotInput, rails: [DiamondSystemCalculator.Rail], into result: inout ShotPrediction
    ) -> AimContext? {
        let y = input.surfaceY
        let r = BallPhysics.radius
        guard let seedPath = DiamondSystemCalculator.kickSeedPath(
            cue: input.cueBall, target: input.targetBall, rails: rails, surfaceY: y
        ), seedPath.count >= 3 else {
            result.feasible = false
            result.infeasibleReason = "该库序无几何种子路线"
            return nil
        }
        // 母球出发方向（XZ 单位向量，指向首库反弹点）。
        let aimDir = unitXZ(from: seedPath[0], to: seedPath[1])
        // 接触锚点：种子末段（末库反弹点 → 目标球心）来向反向退 2R。
        let lastHop = seedPath[seedPath.count - 2]
        let approach = unitXZ(from: lastHop, to: seedPath[seedPath.count - 1])
        let ghost = SCNVector3(input.targetBall.x - 2 * r * approach.x,
                               input.targetBall.y,
                               input.targetBall.z - 2 * r * approach.z)
        result.aimDirection = aimDir
        result.ghost = ghost
        // kick 无进袋语义：`pocketAimPoint` 置目标球心（`pocketIndex` 不参与判定）。
        result.pocketAimPoint = SCNVector3(input.targetBall.x, input.targetBall.y + r,
                                           input.targetBall.z)
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: y)
        // AimContext.pocketCenter 以目标球心占位（runShot 的 objMinDist 在 kick 评分中不消费）。
        return AimContext(aimPoint: result.pocketAimPoint, ghost: ghost, aimDir: aimDir,
                          geometry: geometry, pocketCenter: result.pocketAimPoint)
    }

    /// 用给定发射方向 `finalAim` 跑一次完整模拟并提取全部预测字段（轨迹/进袋/吃库/末位/末速/分离角）。
    /// `result` 须已由 `prepareAim` 回填瞄准/几何字段。**唯一真相**：`predict` 与走位反解快速路径共用，
    /// 避免副本漂移（ADR-P13-01，画面=物理 ADR-P10-06）。
    ///
    /// - Parameter includePresentation: `false` = scoring-only（B1，仅反解搜索用）——跳过展示层后处理
    ///   （cuePath/objectPath 120Hz 采样折线、extraBallPaths、分离角/切线），只保留求解器消费的
    ///   结果量（进袋/吃库/末位/末速/事件流/recorder）。**物理模拟与判定逐位不变**；上屏代表解
    ///   用同一 aimOffset 以 `true` 重建完整 prediction。
    /// - Parameter searchEarlyStop: `true` = 引擎「母球+目标球命运已定」早停（仅反解搜索用，保守判据
    ///   不改变两球结果；见 `EventDrivenEngine.simulate(earlyStopBallNames:)`）。
    static func buildPrediction(
        finalAim: SCNVector3, context ctx: AimContext, input: ShotInput,
        result: ShotPrediction, maxEvents: Int, maxTime: Float,
        includePresentation: Bool = true, searchEarlyStop: Bool = false
    ) -> ShotPrediction {
        var result = result
        let y = input.surfaceY
        let r = BallPhysics.radius
        let run = runShot(
            aimDir: finalAim, velocity: input.velocity, input: input,
            geometry: ctx.geometry, pocketCenter: ctx.pocketCenter, ghost: ctx.ghost,
            maxEvents: maxEvents, maxTime: maxTime, highFidelity: true,
            earlyStop: searchEarlyStop
        )
#if DEBUG
        let postStart = Date()   // B0 分段计时：buildPrediction 后处理（polyline/extraPaths 等）
#endif
        // 轨迹折线（母球白 / 目标球橙）直接取自引擎真实模拟，不做显示层钳制。
        let duration = run.recorder.duration
        result.recorder = run.recorder
        result.duration = duration
        let playback: TrajectoryPlayback? = includePresentation
            ? TrajectoryPlayback(recorder: run.recorder, surfaceY: y + r)
            : nil
        if let playback {
            result.cuePath = polyline(playback, ballName: ShotInput.cueBallName, duration: duration)
            result.objectPath = polyline(playback, ballName: ShotInput.targetBallName, duration: duration)
        }

        result.cuePocketed = run.cuePocketed
        let potted = run.pottedSelected
        result.simObjectPotted = potted
        result.objectPocketed = potted
        result.cueCushionCount = run.cueCushions
        result.objectCushionCount = run.objCushionsBeforePocket
        result.cueCushionsBeforeContact = run.cueCushionsBeforeContact
        result.events = run.events

        // 全场最终静止位置 + 母球末速（走位序列链 / 高速假停护栏）。取自引擎真实末帧。
        var finals: [String: SCNVector3] = [:]
        var pocketed: [String] = []
        var extraPaths: [String: [SCNVector3]] = [:]
        for (name, frames) in run.recorder.framesByBallName {
            if let last = frames.max(by: { $0.time < $1.time }) {
                finals[name] = last.position
                if name == ShotInput.cueBallName {
                    result.cueFinalSpeed = sqrtf(last.velocity.x * last.velocity.x
                                                 + last.velocity.z * last.velocity.z)
                }
            }
            if run.recorder.isBallPocketed(name) { pocketed.append(name) }
            // 被串动的障碍球轨迹（线语言 v2，条 12.4）：袋口模式也补齐，供各页画本色虚线。
            if let playback, name != ShotInput.cueBallName, name != ShotInput.targetBallName {
                let pts = polyline(playback, ballName: name, duration: duration)
                if pathLengthXZ(pts) > 0.02 { extraPaths[name] = pts }
            }
        }
        result.extraBallPaths = extraPaths
        if potted, !pocketed.contains(ShotInput.targetBallName) { pocketed.append(ShotInput.targetBallName) }
        if !potted { pocketed.removeAll { $0 == ShotInput.targetBallName } }
        result.finalPositions = finals
        result.pocketedBalls = pocketed

        // 分离角：首次球-球碰撞后两球速度方向夹角（展示量，scoring-only 跳过）。
        if includePresentation, let contactTime = run.firstContactTime {
            let cueVel = velocityAfter(run.recorder, ballName: ShotInput.cueBallName, time: contactTime)
            let objVel = velocityAfter(run.recorder, ballName: ShotInput.targetBallName, time: contactTime)
            if let cueVel, let objVel {
                let cueDir = horizontalDir(cueVel)
                let objDir = horizontalDir(objVel)
                if let cd = cueDir, let od = objDir {
                    let dot = max(-1, min(1, cd.x * od.x + cd.z * od.z))
                    result.separationAngleDeg = Double(acosf(dot) * 180 / .pi)
                }
                if let od = objDir {
                    result.tangentDir = SCNVector3(-od.z, 0, od.x)
                }
            }
            result.firstContact = positionAt(run.recorder, ballName: ShotInput.cueBallName, time: contactTime)
        }
#if DEBUG
        PerformanceProfiler.recordSample(ProfilerLabel.predictorPostProcess,
                                         ms: Date().timeIntervalSince(postStart) * 1000)
#endif
        return result
    }

    // MARK: - Free shot (ADR-P11-03)

    /// 自由球模拟（走位编排台「自由」模式）：**不指定目标球与袋口**，以给定方向直接击打母球，
    /// 全部在桌球（`balls`）作为真实碰撞体一并模拟。不做任何瞄准求解与可行性闸门（恒 feasible）——
    /// 用于安全球 / 轻推贴球 / 纯走位等非进攻击打。球名沿用调用方传入的名字（建议 USDZ 键），
    /// 母球名固定 `ShotInput.cueBallName`。
    /// - Parameter includePresentation: `false` = scoring-only（B1，仅反解搜索用）——跳过 polyline /
    ///   extraBallPaths 展示后处理，物理与判定不变；上屏代表解用同参数以 `true` 重建。
    /// - Parameter earlyStopBallNames: 引擎早停兴趣球集（保守判据，见 `EventDrivenEngine.simulate`）。
    ///   展示用调用保持 nil。
    static func simulateFree(
        cueBall: SCNVector3,
        aimDir: SCNVector3,
        velocity: Float,
        spinX: Float,
        spinY: Float,
        surfaceY: Float,
        balls: [ObstacleBall],
        maxEvents: Int = 500,
        maxTime: Float = 15.0,
        includePresentation: Bool = true,
        earlyStopBallNames: Set<String>? = nil
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
        // 注意：`highFidelityBounds` 在多球盘面**不是纯展示量**——近库自适应子步会改变
        // evolve 切步序列进而微移轨迹（实测停位差可超 1e-5，个别高速格甚至改变碰撞拓扑），
        // 故 scoring-only 也必须保持 true（B4 曾试关闭换性能，被 `ScoringOnlyConsistencyTests`
        // 打回——scoring 与全保真必须逐位同物理）。
        PerformanceProfiler.measureSample(ProfilerLabel.predictorSimFreeEngine) {
            engine.simulate(maxEvents: maxEvents, maxTime: maxTime, highFidelityBounds: true,
                            earlyStopBallNames: earlyStopBallNames)
        }
#if DEBUG
        let postStart = Date()   // B0 分段计时：simulateFree 后处理（polyline/extraPaths 等）
#endif
        let recorder = engine.getTrajectoryRecorder()
        let playback: TrajectoryPlayback? = includePresentation
            ? TrajectoryPlayback(recorder: recorder, surfaceY: y + r)
            : nil
        let duration = recorder.duration

        var result = ShotPrediction()
        result.feasible = true
        result.aimDirection = dir
        result.recorder = recorder
        result.duration = duration
        if let playback {
            result.cuePath = polyline(playback, ballName: ShotInput.cueBallName, duration: duration)
        }
        result.cuePocketed = recorder.isBallPocketed(ShotInput.cueBallName)

        var finals: [String: SCNVector3] = [:]
        var pocketed: [String] = []
        var extraPaths: [String: [SCNVector3]] = [:]
        for (name, frames) in recorder.framesByBallName {
            if let last = frames.max(by: { $0.time < $1.time }) {
                finals[name] = last.position
                if name == ShotInput.cueBallName {
                    result.cueFinalSpeed = sqrtf(last.velocity.x * last.velocity.x
                                                 + last.velocity.z * last.velocity.z)
                }
            }
            if recorder.isBallPocketed(name) { pocketed.append(name) }
            if let playback, name != ShotInput.cueBallName {
                let pts = polyline(playback, ballName: name, duration: duration)
                if pathLengthXZ(pts) > 0.02 { extraPaths[name] = pts }
            }
        }
        result.finalPositions = finals
        result.pocketedBalls = pocketed
        result.extraBallPaths = extraPaths
        result.objectPocketed = pocketed.contains { $0 != ShotInput.cueBallName }

        var events: [ShotEvent] = []
        for (ev, et) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
            switch ev {
            case let .ballBall(a, b):
                events.append(ShotEvent(time: et, kind: .ballBall(ballA: a, ballB: b)))
            case let .ballCushion(ball, _, _):
                events.append(ShotEvent(time: et, kind: .ballCushion(ball: ball)))
            case let .pocket(ball, pid):
                events.append(ShotEvent(time: et, kind: .pocket(ball: ball, pocketId: pid)))
            case .transition:
                break
            }
        }
        result.events = events

        if let contactTime = firstBallBallTime(engine) {
            result.firstContact = positionAt(recorder, ballName: ShotInput.cueBallName, time: contactTime)
        }
#if DEBUG
        PerformanceProfiler.recordSample(ProfilerLabel.predictorPostProcess,
                                         ms: Date().timeIntervalSince(postStart) * 1000)
#endif
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
        /// 按时间排序的关键事件（球-球碰撞 / 吃库 / 落袋），供走位反解器消费（ADR-P13-01）。
        let events: [ShotEvent]
    }

    /// 以 `aimDir` 方向、`velocity` 力度发射母球并模拟，返回结果。
    /// `earlyStop` = 反解搜索早停（母球+目标球命运已定即结束，保守判据不改两球结果；B1）。
    /// `stopAfterContact` = 瞄准评分专用（B1）：母球与目标球**首次碰撞**解算后立即截断。
    /// 仅当调用方只消费「碰前事件 + 目标球碰后第一帧方向 + 未碰时的 cueGhostMinDist」时可用
    /// （`positionAimOffset` 的评分正是如此）——评分值与整程模拟逐位一致；其余字段（进袋/停点）
    /// 在截断后**不完整**，禁止消费。
    private static func runShot(
        aimDir: SCNVector3, velocity: Float, input: ShotInput,
        geometry: TableGeometry, pocketCenter: SCNVector3, ghost: SCNVector3,
        maxEvents: Int, maxTime: Float, highFidelity: Bool = false, earlyStop: Bool = false,
        stopAfterContact: Bool = false
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
        let interest: Set<String>? = earlyStop
            ? [ShotInput.cueBallName, ShotInput.targetBallName]
            : nil
        let contactPair: (String, String)? = stopAfterContact
            ? (ShotInput.cueBallName, ShotInput.targetBallName)
            : nil
        PerformanceProfiler.measureSample(ProfilerLabel.predictorRunShot) {
            engine.simulate(maxEvents: maxEvents, maxTime: maxTime, highFidelityBounds: highFidelity,
                            earlyStopBallNames: interest, stopAfterContactBetween: contactPair)
        }
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
        var events: [ShotEvent] = []
        for (ev, et) in zip(engine.resolvedEvents, engine.resolvedEventTimes) {
            switch ev {
            case let .ballBall(a, b):
                events.append(ShotEvent(time: et, kind: .ballBall(ballA: a, ballB: b)))
            case let .ballCushion(ball, _, _):
                events.append(ShotEvent(time: et, kind: .ballCushion(ball: ball)))
            case let .pocket(ball, pid):
                events.append(ShotEvent(time: et, kind: .pocket(ball: ball, pocketId: pid)))
            case .transition:
                break
            }
        }
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
            cueCushionsBeforeContact: cueCushionsBeforeContact,
            events: events
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
        /// 搜索阶段每次短模拟的事件/时长上限。**与最终模拟同保真**（同引擎同参数同子步；
        /// 降保真会与最终全保真产生双景观错位，B4 已否决）。搜索模拟另加「母-目首次碰撞后截断」
        /// （`earlyStop` + `stopAfterContact`）——截断≠降保真：评分只消费碰前事件 + 目标球碰后
        /// 首帧方向（未命中时 cueGhostMinDist），首碰解算后的演化与评分无关，截断前物理逐位
        /// 不变（论证与实测见 B1 / `positionAimScore` / `EventDrivenEngine.simulate` 文档，
        /// 一致性由 `ScoringOnlyConsistencyTests` 守护）。
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
        // stopAfterContact：评分只消费碰前事件 + 目标球碰后首帧方向（+未碰时 cueGhostMinDist），
        // 首次母-目碰撞解算后即截断 ⇒ 评分值与整程逐位一致、单次模拟成本大幅下降
        //（与 `positionAimScore` 同参数，论证见 B1 + `EventDrivenEngine.simulate` 文档）。
        func score(_ offset: Float) -> Float {
            let run = runShot(
                aimDir: baseAim.rotatedY(offset), velocity: velocity, input: input,
                geometry: geometry, pocketCenter: pocketCenter, ghost: ghost,
                maxEvents: searchEvents, maxTime: searchTime,
                earlyStop: true, stopAfterContact: true
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

    // MARK: - Bank aim solver（W1，四层管线：解析目标函数 → 歧义引擎回退 → 终验物化）

    /// 翻袋反解常量（20260709 翻袋反射页重构方案 §2.2）。
    private enum BankScoring {
        /// 镜像种子附近的搜索半幅（度）：种子由纯几何反射给出，真实物理（回弹缩角 +
        /// 传旋 + 衰减）在长路径/多库下修正量可达数度（实测 ±3° 不够，见 W1 诊断），
        /// 取 ±8°；吃库数偏离惩罚负责把搜索拉回该库序拓扑族。
        static let searchHalfRangeDeg: Float = 8.0
        static let coarseStepDeg: Float = 0.4
        static let refineHalfRangeDeg: Float = 0.3
        static let refineTolDeg: Float = 0.02
        /// 精修候选数上限与候选间最小间隔（度）：终验失败时自动试备选（B1 finalize 模式）。
        static let maxCandidates = 3
        static let candidateSeparationDeg: Float = 0.5
        /// 粗扫阶段歧义点的引擎评估上限（每库序）：解析候选足够时歧义点整批跳过；
        /// 不足时按序限量引擎评估。被跳过的歧义点只意味着「该 offset 未参与候选竞争」
        /// （宁可少解），任何最终上屏解仍必经引擎终验——有效性判定从不降级。
        static let maxScanEngineEvals = 8
        /// 无效候选基线（母球段吃库 / 未命中目标球），与 `AimScoring.invalidCandidate` 同语义。
        static let invalid: Float = 100
        /// 吃库数偏离指定库序的搜索惩罚（m/库）：只用于把搜索拉回目标拓扑，
        /// 最终取舍一律由引擎终验（真实进袋）裁决，不构成判定阈值。
        static let cushionMismatchPenalty: Float = 0.5
        /// 进袋成功档基线分（远低于任何 miss 距离）；叠加 |offset| 微正则使解唯一稳定。
        static let pottedScore: Float = -1
        static let offsetRegularization: Float = 1e-3
    }

    /// 翻袋反解主流程：粗扫（解析层为主）→ 谷底精修 → 引擎 scoring-only 终验 →
    /// 首个通过者全保真重建上屏；全部候选失败时如实返回「未进袋」的全保真预测，
    /// **绝不回退几何解**（jaw 截断口径，方案 §2.3）。
    private static func predictBank(
        input: ShotInput, rails: [BankShotCalculator.Rail], context ctx: AimContext,
        result: ShotPrediction, maxEvents: Int, maxTime: Float
    ) -> ShotPrediction {
        let deg = Float.pi / 180
        let half = BankScoring.searchHalfRangeDeg * deg
        let step = BankScoring.coarseStepDeg * deg

        // 第 1/2 层：粗扫。解从镜像种子（offset 0）向外衰减聚集 ⇒ **中心向外**评估，
        // 找到进袋候选后再多看几个点即收敛（早停只影响备选覆盖面，不影响判定口径）。
        // 解析评估 µs 级；歧义点限量引擎 scoring-only——预算耗尽的歧义点按无效跳过
        //（宁可少解侧；精修与终验不受预算限制）。
        var offsets: [Float] = [0]
        var k = 1
        while Float(k) * step <= half + 1e-6 {
            offsets.append(Float(k) * step)
            offsets.append(-Float(k) * step)
            k += 1
        }
        var engineBudget = BankScoring.maxScanEngineEvals
        var scan: [(off: Float, s: Float)] = []
        var evalsAfterPotted = -1
        for o in offsets {
            let s: Float
            if let analytic = bankAnalyticScore(offset: o, input: input, context: ctx, rails: rails) {
                s = analytic
            } else if engineBudget > 0 {
                engineBudget -= 1
                s = bankEngineScore(aimDir: ctx.aimDir.rotatedY(o), input: input,
                                    context: ctx, rails: rails)
            } else {
                s = BankScoring.invalid
            }
            scan.append((o, s))
            if s < 0 && evalsAfterPotted < 0 { evalsAfterPotted = 0 }
            if evalsAfterPotted >= 0 {
                evalsAfterPotted += 1
                if evalsAfterPotted > 4 { break }
            }
        }
        scan.sort { $0.s < $1.s }

        // 精修目标函数：解析优先，歧义点限额引擎（与粗扫共享同一预算池思路，独立限额）。
        // 预算耗尽后歧义点按无效处理——精修退化为「以粗扫点直接进终验」，判定口径不变。
        var refineEngineBudget = BankScoring.maxScanEngineEvals
        func score(_ offset: Float) -> Float {
            if let s = bankAnalyticScore(offset: offset, input: input, context: ctx, rails: rails) {
                return s
            }
            guard refineEngineBudget > 0 else { return BankScoring.invalid }
            refineEngineBudget -= 1
            return bankEngineScore(aimDir: ctx.aimDir.rotatedY(offset), input: input,
                                   context: ctx, rails: rails)
        }

        // 谷底去重：按分数序贪心挑相互间隔 ≥ candidateSeparation 的候选中心。
        let sep = BankScoring.candidateSeparationDeg * deg
        var centers: [Float] = []
        for entry in scan where entry.s < BankScoring.invalid {
            if centers.allSatisfy({ abs($0 - entry.off) >= sep }) {
                centers.append(entry.off)
            }
            if centers.count >= BankScoring.maxCandidates { break }
        }

        // 精修：每个谷底黄金分割极小化（同目标函数，tol 0.02°）。
        let refined: [Float] = centers.map { c in
            goldenSectionMin(score,
                             lower: c - BankScoring.refineHalfRangeDeg * deg,
                             upper: c + BankScoring.refineHalfRangeDeg * deg,
                             tol: BankScoring.refineTolDeg * deg)
        }

        // 括号内无任何有效候选（未命中 / 母球段吃库）：无需进引擎，直接如实返回
        // 「未进袋」的瞄准几何结果（feasible 保持 true——几何可行、只是该库序解不出）。
        guard !refined.isEmpty else {
            var final = result
            final.aimOffsetUsed = 0
            return final
        }

        // 第 3 层：引擎终验（scoring-only 与全保真逐位同物理，B1）；首个真进袋者全保真物化。
        var firstProbe: (off: Float, pred: ShotPrediction)?
        for off in refined {
            let probe = buildPrediction(
                finalAim: ctx.aimDir.rotatedY(off), context: ctx, input: input,
                result: result, maxEvents: maxEvents, maxTime: maxTime,
                includePresentation: false, searchEarlyStop: true
            )
            if probe.simObjectPotted && probe.cueCushionsBeforeContact == 0 {
                var final = buildPrediction(
                    finalAim: ctx.aimDir.rotatedY(off), context: ctx, input: input,
                    result: result, maxEvents: maxEvents, maxTime: maxTime
                )
                final.aimOffsetUsed = off
                return final
            }
            if firstProbe == nil { firstProbe = (off, probe) }
        }

        // 全部候选未通过终验：如实返回最优候选的 scoring-only 预测（物理与全保真逐位一致，
        // 仅无展示折线——调用方只据 simObjectPotted 淘汰该库序）。宁可少解，不出几何假解。
        var final = firstProbe?.pred ?? result
        final.aimOffsetUsed = firstProbe?.off ?? 0
        return final
    }

    /// 翻袋瞄准评分（predictBank 的目标函数）。
    /// 第 1 层解析：`AnalyticAim`（母球段闭式）+ `AnalyticShotRollout.rollout`（目标球段
    /// 单球多库闭式，库边解算与引擎共用 `EngineNumerics.resolveCushionImpact`）；
    /// 第 2 层：解析覆盖不了（级联 / kiss / 截断）就地换引擎 scoring-only 评估——判定不降级。
    /// 评分：进袋 = pottedScore + |offset| 正则；未进 = 目标球路径到袋心最近距离
    /// + 吃库数偏离惩罚；母球段吃库 / 未命中 = 无效候选。
    static func bankAimScore(
        offset: Float, input: ShotInput, context ctx: AimContext,
        rails: [BankShotCalculator.Rail]
    ) -> Float {
        bankAnalyticScore(offset: offset, input: input, context: ctx, rails: rails)
            ?? bankEngineScore(aimDir: ctx.aimDir.rotatedY(offset), input: input,
                               context: ctx, rails: rails)
    }

    /// 第 1 层解析评分。返回 nil = 解析层覆盖不了（撞第三球级联 / 截断 / kiss 风险），
    /// 调用方决定回退引擎或（粗扫预算耗尽时）按无效跳过——宁可少解，不出假解。
    private static func bankAnalyticScore(
        offset: Float, input: ShotInput, context ctx: AimContext,
        rails: [BankShotCalculator.Rail]
    ) -> Float? {
        let aimDir = ctx.aimDir.rotatedY(offset)
        let out = AnalyticAim.outcome(
            aimDir: aimDir, velocity: input.velocity, input: input,
            geometry: ctx.geometry, ghost: ctx.ghost, maxTime: AimScoring.searchMaxTime
        )
        if out.cueHitCushionFirst { return BankScoring.invalid }
        guard let cueAfter = out.cueAfterContact, let objAfter = out.objAfterContact,
              let contactTime = out.contactTime else {
            // 未（先）碰到目标球：无效候选 + ghost 距离梯度（把搜索拉回击中目标球）。
            return BankScoring.invalid + out.cueGhostMinDist
        }

        let y = input.surfaceY
        let r = BallPhysics.radius
        var staticBalls: [(name: String, position: SCNVector3)] = []
        staticBalls.reserveCapacity(input.obstacles.count)
        for ob in input.obstacles
        where ob.name != ShotInput.cueBallName && ob.name != ShotInput.targetBallName {
            staticBalls.append((ob.name, SCNVector3(ob.position.x, y + r, ob.position.z)))
        }

        let objRoll = AnalyticShotRollout.rollout(
            from: objAfter, startTime: contactTime, geometry: ctx.geometry,
            staticBalls: staticBalls, maxTime: AimScoring.searchMaxTime)

        // 目标球撞上障碍球：翻袋语义下候选**淘汰**（方案 §4.3「撞障碍 = 候选自然淘汰」，
        // 级联进袋不是用户要的干净翻袋解）——给到袋心的 miss 梯度引导搜索绕开障碍，
        // 不烧引擎预算。
        if objRoll.firstBallHit != nil {
            let miss = minSegmentsDistanceXZ(objRoll.segments, to: ctx.pocketCenter)
            let mismatch = Float(abs(objRoll.cushionCount - rails.count))
            return miss + BankScoring.cushionMismatchPenalty * (mismatch + 1)
        }
        // 目标球段截断（超时/超吃库上限）：歧义，如实上报 nil（判定不降级，回退引擎）。
        guard objRoll.completed else { return nil }

        let cueRoll = AnalyticShotRollout.rollout(
            from: cueAfter, startTime: contactTime, geometry: ctx.geometry,
            staticBalls: staticBalls, maxTime: AimScoring.searchMaxTime)
        // 母球与目标球碰后路径再度靠近（kiss）：两球需耦合解算，回退引擎。
        // 母球撞障碍/截断**不**影响目标球单球判定（级联扰动由第 3 层引擎终验兜底），
        // 评分口径照常。
        if AnalyticShotRollout.kissRisk(cue: cueRoll, obj: objRoll, from: contactTime) {
            return nil
        }

        // 进选定袋（吃库数 ≥ 库序数：贴袋入口擦 jaw 会多计一次，属合法进袋路线）。
        if objRoll.pocketId == "pocket_\(input.pocketIndex)",
           objRoll.cushionCount >= rails.count {
            return BankScoring.pottedScore + abs(offset) * BankScoring.offsetRegularization
        }
        // 未进：目标球路径到袋心最近距离 + 吃库数偏离惩罚（把搜索拉回目标拓扑）。
        let miss = minSegmentsDistanceXZ(objRoll.segments, to: ctx.pocketCenter)
        let mismatch = Float(abs(objRoll.cushionCount - rails.count))
        return miss + BankScoring.cushionMismatchPenalty * mismatch
    }

    /// 第 2 层引擎评估（歧义候选专用）：scoring-only + 兴趣球早停整程模拟，评分口径
    /// 与解析层一致（进袋 / miss 距离 / 直击判据），物理为引擎全语义（级联 / kiss 如实）。
    private static func bankEngineScore(
        aimDir: SCNVector3, input: ShotInput, context ctx: AimContext,
        rails: [BankShotCalculator.Rail]
    ) -> Float {
        let run = runShot(
            aimDir: aimDir, velocity: input.velocity, input: input,
            geometry: ctx.geometry, pocketCenter: ctx.pocketCenter, ghost: ctx.ghost,
            maxEvents: AimScoring.searchMaxEvents, maxTime: AimScoring.searchMaxTime,
            earlyStop: true
        )
        guard run.firstContactTime != nil else {
            return BankScoring.invalid + run.cueGhostMinDist
        }
        guard run.cueCushionsBeforeContact == 0 else { return BankScoring.invalid }
        if run.pottedSelected, run.objCushionsBeforePocket >= rails.count {
            return BankScoring.pottedScore
        }
        let mismatch = Float(abs(run.objCushionsBeforePocket - rails.count))
        return run.objMinDist + BankScoring.cushionMismatchPenalty * mismatch
    }

    // MARK: - Kick aim solver（W2，同 bank 四层管线；常量复用 `BankScoring`——同量纲同语义）

    /// kick 首碰信息（`ShotPrediction.events` / `RunResult.events` 通用口径）：
    /// - `contacted`：母球首次球-球碰撞对象是否为目标球（碰前落袋 = false）。
    /// - `cushionsBefore`：该首碰（或流结束）前母球吃库数。
    /// - `hitOtherFirst`：母球先撞上了障碍球（首碰非目标球）。
    static func kickContactInfo(
        events: [ShotEvent]
    ) -> (contacted: Bool, cushionsBefore: Int, hitOtherFirst: Bool) {
        var cushions = 0
        for ev in events {
            switch ev.kind {
            case let .ballBall(a, b):
                guard a == ShotInput.cueBallName || b == ShotInput.cueBallName else { continue }
                let other = a == ShotInput.cueBallName ? b : a
                if other == ShotInput.targetBallName { return (true, cushions, false) }
                return (false, cushions, true)
            case .ballCushion(let ball) where ball == ShotInput.cueBallName:
                cushions += 1
            case .pocket(let ball, _) where ball == ShotInput.cueBallName:
                return (false, cushions, false)   // 碰到目标球前母球落袋：失败
            default:
                break
            }
        }
        return (false, cushions, false)
    }

    /// kick 反解主流程：粗扫（解析层为主）→ 谷底精修 → 引擎 scoring-only 终验 →
    /// 首个「真实碰到目标球且库序拓扑吻合」者全保真重建上屏；全部候选失败时如实返回
    /// `kickContactMade == false` 的预测，**绝不回退几何解**（与 bank 同口径）。
    private static func predictKick(
        input: ShotInput, rails: [DiamondSystemCalculator.Rail], context ctx: AimContext,
        result: ShotPrediction, maxEvents: Int, maxTime: Float
    ) -> ShotPrediction {
        let deg = Float.pi / 180
        let half = BankScoring.searchHalfRangeDeg * deg
        let step = BankScoring.coarseStepDeg * deg

        // 第 1/2 层：中心向外粗扫 + 命中后早停（与 predictBank 同节奏）。
        var offsets: [Float] = [0]
        var k = 1
        while Float(k) * step <= half + 1e-6 {
            offsets.append(Float(k) * step)
            offsets.append(-Float(k) * step)
            k += 1
        }
        var engineBudget = BankScoring.maxScanEngineEvals
        var scan: [(off: Float, s: Float)] = []
        var evalsAfterHit = -1
        for o in offsets {
            let s: Float
            if let analytic = kickAnalyticScore(offset: o, input: input, context: ctx, rails: rails) {
                s = analytic
            } else if engineBudget > 0 {
                engineBudget -= 1
                s = kickEngineScore(aimDir: ctx.aimDir.rotatedY(o), input: input,
                                    context: ctx, rails: rails)
            } else {
                s = BankScoring.invalid
            }
            scan.append((o, s))
            if s < 0 && evalsAfterHit < 0 { evalsAfterHit = 0 }
            if evalsAfterHit >= 0 {
                evalsAfterHit += 1
                if evalsAfterHit > 4 { break }
            }
        }
        scan.sort { $0.s < $1.s }

        var refineEngineBudget = BankScoring.maxScanEngineEvals
        func score(_ offset: Float) -> Float {
            if let s = kickAnalyticScore(offset: offset, input: input, context: ctx, rails: rails) {
                return s
            }
            guard refineEngineBudget > 0 else { return BankScoring.invalid }
            refineEngineBudget -= 1
            return kickEngineScore(aimDir: ctx.aimDir.rotatedY(offset), input: input,
                                   context: ctx, rails: rails)
        }

        // 谷底去重 + 黄金分割精修（同 predictBank）。
        let sep = BankScoring.candidateSeparationDeg * deg
        var centers: [Float] = []
        for entry in scan where entry.s < BankScoring.invalid {
            if centers.allSatisfy({ abs($0 - entry.off) >= sep }) {
                centers.append(entry.off)
            }
            if centers.count >= BankScoring.maxCandidates { break }
        }
        let refined: [Float] = centers.map { c in
            goldenSectionMin(score,
                             lower: c - BankScoring.refineHalfRangeDeg * deg,
                             upper: c + BankScoring.refineHalfRangeDeg * deg,
                             tol: BankScoring.refineTolDeg * deg)
        }
        guard !refined.isEmpty else {
            var final = result
            final.aimOffsetUsed = 0
            return final
        }

        // 第 3 层：引擎终验；首个真实碰到目标球（拓扑吻合）者全保真物化。
        // 性能口径（W2 benchmark 驱动）：解析层已判成功档的候选（对拍假阳性 0）直接做
        // 全保真物化，用该次模拟自身的事件流终验——终验与物化合并为一次引擎模拟；
        // 判定仍以引擎事件流为准，不降级。解析未判成功的候选保留 scoring-only 探测。
        var firstProbe: (off: Float, pred: ShotPrediction)?
        for off in refined {
            let analyticSuccess = kickAnalyticScore(
                offset: off, input: input, context: ctx, rails: rails).map { $0 < 0 } ?? false
            let probe = buildPrediction(
                finalAim: ctx.aimDir.rotatedY(off), context: ctx, input: input,
                result: result, maxEvents: maxEvents, maxTime: maxTime,
                includePresentation: analyticSuccess, searchEarlyStop: !analyticSuccess
            )
            let info = kickContactInfo(events: probe.events)
            if info.contacted && info.cushionsBefore >= rails.count {
                var final = analyticSuccess ? probe : buildPrediction(
                    finalAim: ctx.aimDir.rotatedY(off), context: ctx, input: input,
                    result: result, maxEvents: maxEvents, maxTime: maxTime
                )
                final.aimOffsetUsed = off
                final.kickContactMade = true
                return final
            }
            if firstProbe == nil { firstProbe = (off, probe) }
        }

        // 全部候选未通过终验：如实返回最优候选的 scoring-only 预测（宁可少解，不出几何假解）。
        var final = firstProbe?.pred ?? result
        final.aimOffsetUsed = firstProbe?.off ?? 0
        let info = kickContactInfo(events: final.events)
        final.kickContactMade = info.contacted && info.cushionsBefore >= rails.count
        return final
    }

    /// 翻袋反解全枚举入口（W3 翻袋页 UI 单次求解口径，与 `predictKickAll` 对称）：
    /// 对指定袋口枚举全部 1...maxCushions 库合法库序，**每条库序独立并行**走完整四层管线。
    /// 返回全部「引擎终验真实进选定袋」的解，按库序枚举顺序稳定排列。
    /// `baseInput.bankRails` 由本函数逐条覆盖，调用方无需预置。
    static func predictBankAll(
        _ baseInput: ShotInput, maxCushions: Int = 3,
        maxEvents: Int = 500, maxTime: Float = 15.0
    ) -> [(rails: [BankShotCalculator.Rail], prediction: ShotPrediction)] {
        let sequences = BankShotCalculator.candidateRailSequences(maxCushions: maxCushions)
        var predictions = [ShotPrediction?](repeating: nil, count: sequences.count)
        predictions.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: sequences.count) { i in
                var input = baseInput
                input.bankRails = sequences[i]
                (base + i).pointee = predict(input, maxEvents: maxEvents, maxTime: maxTime)
            }
        }
        var out: [(rails: [BankShotCalculator.Rail], prediction: ShotPrediction)] = []
        for (i, rails) in sequences.enumerated() {
            guard let pred = predictions[i], pred.feasible, pred.simObjectPotted else { continue }
            out.append((rails, pred))
        }
        return out
    }

    /// kick 反解全枚举入口（W2 性能口径 = W3 反射页 UI 单次求解口径）：
    /// 枚举全部 1...maxCushions 库合法库序，**每条库序独立并行**走完整四层管线
    /// （库序间零共享可变状态，`predict` 已在 `PositionPlaySolver` 并发热点中验证线程安全）。
    /// 返回全部「引擎终验真实碰到目标球」的解，按库序枚举顺序稳定排列。
    /// `baseInput.kickRails` 由本函数逐条覆盖，调用方无需预置。
    static func predictKickAll(
        _ baseInput: ShotInput, maxCushions: Int = 3,
        maxEvents: Int = 500, maxTime: Float = 15.0
    ) -> [(rails: [DiamondSystemCalculator.Rail], prediction: ShotPrediction)] {
        let sequences = DiamondSystemCalculator.candidateRailSequences(maxCushions: maxCushions)
        var predictions = [ShotPrediction?](repeating: nil, count: sequences.count)
        predictions.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: sequences.count) { i in
                var input = baseInput
                input.kickRails = sequences[i]
                (base + i).pointee = predict(input, maxEvents: maxEvents, maxTime: maxTime)
            }
        }
        var out: [(rails: [DiamondSystemCalculator.Rail], prediction: ShotPrediction)] = []
        for (i, rails) in sequences.enumerated() {
            guard let pred = predictions[i], pred.feasible, pred.kickContactMade else { continue }
            out.append((rails, pred))
        }
        return out
    }

    /// kick 瞄准评分（predictKick 的目标函数；internal 供对拍测试交叉评估）。
    /// 第 1 层解析：击杆（`CueBallStrike` 同源）→ 母球单球 rollout（目标球 + 障碍球全部为
    /// 静止碰撞体）至首碰/停稳/落袋——kick 成功判据在首碰即定，无需碰后推演，解析覆盖面
    /// 天然完整；唯一歧义 = rollout 截断（超时/超吃库上限），回退引擎。
    static func kickAimScore(
        offset: Float, input: ShotInput, context ctx: AimContext,
        rails: [DiamondSystemCalculator.Rail]
    ) -> Float {
        kickAnalyticScore(offset: offset, input: input, context: ctx, rails: rails)
            ?? kickEngineScore(aimDir: ctx.aimDir.rotatedY(offset), input: input,
                               context: ctx, rails: rails)
    }

    /// 第 1 层解析评分。返回 nil = rollout 截断歧义（回退引擎）。
    /// 评分：碰到目标球且吃库数 ≥ 库序数 = 成功档（pottedScore + |offset| 正则）；
    /// 碰到但拓扑不符 = 吃库偏离惩罚；先撞障碍 = miss 到接触锚点 + 偏离惩罚（+1 档）；
    /// 停稳未达 = miss + 偏离惩罚；碰前落袋 = 无效候选。
    private static func kickAnalyticScore(
        offset: Float, input: ShotInput, context ctx: AimContext,
        rails: [DiamondSystemCalculator.Rail]
    ) -> Float? {
        let aimDir = ctx.aimDir.rotatedY(offset)
        let y = input.surfaceY
        let r = BallPhysics.radius
        let strike = CueBallStrike.executeStrike(
            aimDirection: aimDir, velocity: input.velocity,
            spinX: input.spinX, spinY: input.spinY, elevation: input.elevation
        )
        var cue = BallState(
            position: SCNVector3(input.cueBall.x, y + r, input.cueBall.z),
            velocity: strike.velocity, angularVelocity: strike.angularVelocity,
            state: .sliding, name: ShotInput.cueBallName
        )
        cue.state = EngineNumerics.determineMotionState(cue)

        var staticBalls: [(name: String, position: SCNVector3)] = [
            (ShotInput.targetBallName, SCNVector3(input.targetBall.x, y + r, input.targetBall.z))
        ]
        staticBalls.reserveCapacity(input.obstacles.count + 1)
        for ob in input.obstacles
        where ob.name != ShotInput.cueBallName && ob.name != ShotInput.targetBallName {
            staticBalls.append((ob.name, SCNVector3(ob.position.x, y + r, ob.position.z)))
        }

        let roll = AnalyticShotRollout.rollout(
            from: cue, startTime: 0, geometry: ctx.geometry,
            staticBalls: staticBalls, maxTime: AimScoring.searchMaxTime)

        if let hit = roll.firstBallHit {
            let mismatch = Float(abs(roll.cushionCount - rails.count))
            if hit == ShotInput.targetBallName {
                if roll.cushionCount >= rails.count {
                    return BankScoring.pottedScore + abs(offset) * BankScoring.offsetRegularization
                }
                return BankScoring.cushionMismatchPenalty * mismatch
            }
            // 先撞障碍球：候选淘汰（真实碰撞体语义），miss 梯度引导搜索绕开，不烧引擎预算。
            let miss = minSegmentsDistanceXZ(roll.segments, to: ctx.ghost)
            return miss + BankScoring.cushionMismatchPenalty * (mismatch + 1)
        }
        // 截断（超时/超吃库上限）：歧义，如实上报 nil（判定不降级，回退引擎）。
        guard roll.completed else { return nil }
        // 碰到目标球前母球落袋：无效候选。
        if roll.pocketId != nil { return BankScoring.invalid }
        // 停稳未达：miss = 母球路径到接触锚点最近距离 + 吃库数偏离惩罚。
        let miss = minSegmentsDistanceXZ(roll.segments, to: ctx.ghost)
        let mismatch = Float(abs(roll.cushionCount - rails.count))
        return miss + BankScoring.cushionMismatchPenalty * mismatch
    }

    /// 第 2 层引擎评估（歧义候选专用）：scoring-only + 兴趣球早停整程模拟，评分口径
    /// 与解析层一致（成功档 / miss 梯度 / 偏离惩罚 / 碰前落袋无效）。
    private static func kickEngineScore(
        aimDir: SCNVector3, input: ShotInput, context ctx: AimContext,
        rails: [DiamondSystemCalculator.Rail]
    ) -> Float {
        let run = runShot(
            aimDir: aimDir, velocity: input.velocity, input: input,
            geometry: ctx.geometry, pocketCenter: ctx.pocketCenter, ghost: ctx.ghost,
            maxEvents: AimScoring.searchMaxEvents, maxTime: AimScoring.searchMaxTime,
            earlyStop: true
        )
        let info = kickContactInfo(events: run.events)
        let mismatch = Float(abs(info.cushionsBefore - rails.count))
        if info.contacted {
            if info.cushionsBefore >= rails.count { return BankScoring.pottedScore }
            return BankScoring.cushionMismatchPenalty * mismatch
        }
        if info.hitOtherFirst {
            return run.cueGhostMinDist + BankScoring.cushionMismatchPenalty * (mismatch + 1)
        }
        // 碰前落袋：无效候选（run 事件流含 pocket(cue) 时 contactInfo 已返回 false）。
        if run.cuePocketed { return BankScoring.invalid }
        return run.cueGhostMinDist + BankScoring.cushionMismatchPenalty * mismatch
    }

    /// 常加速度路径段集合到某点的最近水平距离（每段折线采样，与 ghost 距离累计同量级近似）。
    private static func minSegmentsDistanceXZ(
        _ segments: [BallPathSegment], to point: SCNVector3
    ) -> Float {
        var minDist = Float.greatestFiniteMagnitude
        for seg in segments {
            let samples = 12
            var prev = seg.position(at: 0)
            for i in 0...samples {
                let dt = seg.duration * Float(i) / Float(samples)
                let p = seg.position(at: dt)
                if i == 0 {
                    let dx = p.x - point.x, dz = p.z - point.z
                    minDist = min(minDist, sqrtf(dx * dx + dz * dz))
                } else {
                    minDist = min(minDist, segmentPointDistanceXZ(a: prev, b: p, p: point))
                }
                prev = p
            }
        }
        return minDist
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

// MARK: - 走位反解快速路径（ADR-P13-01，仅 PositionPlaySolver 使用）
//
// 与共享 `predict` 的关系：**完全不碰** `predict` / `solveAimOffset` 的算法（其余 5 个场景与
// 全部物理测试套走的就是它们，零影响）。这里只是「独立编排」——复用同一个共享核心
// `prepareAim` / `runShot` / `buildPrediction`，把内层瞄准换成更省的一维黄金分割，并允许外部
// 传入**预解好的瞄准偏移**以跨 spinY 复用（瞄准与高低杆无关）。同文件 extension ⇒ 可访问
// 私有核心，无需放宽任何可见性。
extension ShotPredictor {

    /// 走位反解专用预测：可传入预解的 `aimOffset`（跨 spinY 复用）；为 nil 时用轻量一维瞄准现解。
    /// 共享 `prepareAim` + `buildPrediction`，结果字段与 `predict` 同口径。
    ///
    /// `includePresentation: false` = scoring-only 搜索模式（B1）：跳过展示后处理 + 引擎
    /// 「母球+目标球命运已定」早停；物理与判定结果不变。代表解上屏前必须用同一
    /// `prediction.aimOffsetUsed` 以默认 `true` 重建完整 prediction。
    static func predictForPositionSolve(
        _ input: ShotInput, aimOffset: Float? = nil,
        maxEvents: Int = 500, maxTime: Float = 15.0,
        includePresentation: Bool = true
    ) -> ShotPrediction {
        var result = ShotPrediction()
        guard let ctx = prepareAim(input, into: &result) else { return result }
        let offset = aimOffset ?? positionAimOffset(input: input, context: ctx)
        result.aimOffsetUsed = offset
        let finalAim = ctx.aimDir.rotatedY(offset)
        return buildPrediction(finalAim: finalAim, context: ctx, input: input,
                               result: result, maxEvents: maxEvents, maxTime: maxTime,
                               includePresentation: includePresentation,
                               searchEarlyStop: !includePresentation)
    }

    /// 轻量一维瞄准：方向景观平滑单峰（见 `solveAimOffset` 注释），用**黄金分割**求极小，
    /// ~15 次短模拟 vs 原三级网格 75 次。精度 0.05° 足够——进袋由 `buildPrediction` 全模拟硬校验。
    /// 评分与 `solveAimOffset` 同口径：目标球碰后离开方向对齐进球管道、碰前吃库判无效。
    /// **与 spinY 无关**（squirt 只来自横塞 spinX）⇒ 可对一组候选只解一次、跨 spinY 复用。
    ///
    /// `center`/`halfRange`：可选窄括号热启动（B1，精修 ±velocity/±spinX 邻居用——邻居的最优
    /// 瞄准必在种子 offset 附近，窄括号把 ~15 次短模拟压到 ~9 次）。默认全幅 ±12°。
    /// B2 特性开关：轻量瞄准的评分函数走解析层（`AnalyticAim`，默认）还是整程模拟。
    /// 对拍验证（`AnalyticAimParityTests`）：评分偏差 P95 0.013°、求解 Δoffset 全量 0°、
    /// 零丢解零失真。回退 = 改为 `false` 重编译（编译期常量，避免并发路径上的可变全局）。
    static let useAnalyticPositionAim = true

    static func positionAimOffset(
        input: ShotInput, context ctx: AimContext,
        center: Float = 0, halfRange: Float? = nil
    ) -> Float {
        let deg = Float.pi / 180
        let half = halfRange ?? AimScoring.coarseHalfRangeDeg * deg
        // 第 0 层几何早筛（B2）：障碍球把整个瞄准扇区挡死 ⇒ 括号内不存在直击候选，
        // 直接返回 center（该候选照旧被下游全保真终验否决，语义不变），省掉整轮一维搜索。
        // 判据保守（考虑扇区边缘全力绕行 + swerve 余量），宁可漏筛不误杀。
        if AnalyticAim.straightFanBlocked(
            cue: input.cueBall, ghost: ctx.ghost, obstacles: input.obstacles,
            fanHalfAngle: half + abs(center)
        ) {
            return center
        }
        let score: (Float) -> Float = useAnalyticPositionAim
            ? { positionAimScoreAnalytic(input: input, context: ctx, offset: $0) }
            : { positionAimScore(input: input, context: ctx, offset: $0) }
        return goldenSectionMin(score,
                                lower: center - half,
                                upper: center + half,
                                tol: 0.05 * deg)
    }

    /// 整程模拟口径的黄金分割瞄准（B2 前的线上路径，作回退与对拍基准保留；
    /// 与 `positionAimOffsetAnalytic` 同括号同容差，仅评分函数不同）。
    static func positionAimOffsetSimulated(
        input: ShotInput, context ctx: AimContext,
        center: Float = 0, halfRange: Float? = nil
    ) -> Float {
        let deg = Float.pi / 180
        let half = halfRange ?? AimScoring.coarseHalfRangeDeg * deg
        return goldenSectionMin({ positionAimScore(input: input, context: ctx, offset: $0) },
                                lower: center - half,
                                upper: center + half,
                                tol: 0.05 * deg)
    }

    /// 走位反解瞄准评分（整程模拟口径，`positionAimOffset` 的目标函数）。
    /// internal：解析层对拍测试（B2-4）需要在同一 offset 上交叉评估两套评分。
    static func positionAimScore(
        input: ShotInput, context ctx: AimContext, offset: Float
    ) -> Float {
        let adx = input.targetBall.x - ctx.ghost.x
        let adz = input.targetBall.z - ctx.ghost.z
        let adl = max(sqrtf(adx * adx + adz * adz), 1e-5)
        let aimDirX = adx / adl, aimDirZ = adz / adl
        // stopAfterContact：评分只消费碰前事件 + 目标球碰后首帧方向（+未碰时 cueGhostMinDist），
        // 首次母-目碰撞解算后即截断 ⇒ 评分值与整程逐位一致、单次模拟成本大幅下降（B1）。
        let run = runShot(
            aimDir: ctx.aimDir.rotatedY(offset), velocity: input.velocity, input: input,
            geometry: ctx.geometry, pocketCenter: ctx.pocketCenter, ghost: ctx.ghost,
            maxEvents: AimScoring.searchMaxEvents, maxTime: AimScoring.searchMaxTime,
            earlyStop: true, stopAfterContact: true
        )
        guard let od = run.objPostContactDir else {
            return AimScoring.invalidCandidate + run.cueGhostMinDist
        }
        guard run.cueCushionsBeforeContact == 0 else { return AimScoring.invalidCandidate }
        let dot = max(-1, min(1, od.x * aimDirX + od.z * aimDirZ))
        return acosf(dot) + abs(offset) * AimScoring.offsetRegularization
    }

    /// 解析瞄准（B2）：评分口径与 `positionAimOffset` 逐项一致（碰后方向对齐 `d_pipe`、
    /// 碰前吃库判无效、未命中叠加 cueGhostMinDist 梯度、|offset| 正则），但单次评估走
    /// `AnalyticAim.outcome` 闭式解（击杆/弹道/CCD/碰撞解算全部复用引擎组件，不进事件循环）。
    /// 搜索器与线上路径同为黄金分割、同括号同容差——对拍偏差（B2-4）因此**只反映
    /// 解析模型 vs 整程模拟的物理保真差**，不混入搜索方法差。
    static func positionAimOffsetAnalytic(
        input: ShotInput, context ctx: AimContext,
        center: Float = 0, halfRange: Float? = nil
    ) -> Float {
        let deg = Float.pi / 180
        let half = halfRange ?? AimScoring.coarseHalfRangeDeg * deg
        return goldenSectionMin({ positionAimScoreAnalytic(input: input, context: ctx, offset: $0) },
                                lower: center - half,
                                upper: center + half,
                                tol: 0.05 * deg)
    }

    /// 解析瞄准评分（`positionAimOffsetAnalytic` 的目标函数，与 `positionAimScore` 同口径）。
    static func positionAimScoreAnalytic(
        input: ShotInput, context ctx: AimContext, offset: Float
    ) -> Float {
        let adx = input.targetBall.x - ctx.ghost.x
        let adz = input.targetBall.z - ctx.ghost.z
        let adl = max(sqrtf(adx * adx + adz * adz), 1e-5)
        let aimDirX = adx / adl, aimDirZ = adz / adl
        let out = AnalyticAim.outcome(
            aimDir: ctx.aimDir.rotatedY(offset), velocity: input.velocity,
            input: input, geometry: ctx.geometry, ghost: ctx.ghost,
            maxTime: AimScoring.searchMaxTime
        )
        guard let od = out.objPostContactDir else {
            // 未（先）碰到目标球（含先吃库/先撞障碍/先落袋）：统一叠加 ghost 距离梯度。
            // **不要**对 cueHitCushionFirst 返回恒值 100：模拟的恒值 100 只出现在
            // 「吃库后仍击中目标球」的绕库支（解析层不追库后路径，无法区分）；而未击中
            // 支在模拟里带 100+dist 梯度。若解析对吃库支给恒值，黄金分割会在两侧
            // 平坦高原上漂到括号边缘（对拍案例 #24 丢解根因）。两种映射同判无效（>99），
            // 带梯度版还能把搜索从高原拉回有效谷——取带梯度版。
            return AimScoring.invalidCandidate + out.cueGhostMinDist
        }
        let dot = max(-1, min(1, od.x * aimDirX + od.z * aimDirZ))
        return acosf(dot) + abs(offset) * AimScoring.offsetRegularization
    }

    /// 黄金分割一维极小化（要求 `f` 在 [lower, upper] 上拟单峰）。
    private static func goldenSectionMin(
        _ f: (Float) -> Float, lower: Float, upper: Float, tol: Float
    ) -> Float {
        let invPhi: Float = 0.618_034
        var a = lower, b = upper
        var c = b - (b - a) * invPhi
        var d = a + (b - a) * invPhi
        var fc = f(c), fd = f(d)
        while (b - a) > tol {
            if fc < fd {
                b = d; d = c; fd = fc
                c = b - (b - a) * invPhi
                fc = f(c)
            } else {
                a = c; c = d; fc = fd
                d = a + (b - a) * invPhi
                fd = f(d)
            }
        }
        return (a + b) / 2
    }
}
