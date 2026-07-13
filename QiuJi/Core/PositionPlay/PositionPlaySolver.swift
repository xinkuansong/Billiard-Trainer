import Foundation
import SceneKit

/// 走位反解器（思路训练器，ADR-P13-01）。
///
/// 与 `PositionPlayShotSolver`（单杆**前向**求解：给定塞/力度算轨迹）相反——本求解器**放开塞与力度**
/// 作为自由变量，把约束改为母球落点：
/// - 情形 A `.restRegion`：母球**停点**落在手画落区内（打一看二的可行区域）。
/// - 情形 B `.passThrough`：母球在 v>vMin 时**经过**指定点（去 K 球）。
///
/// 嵌套结构：外层在 `(spinX, spinY, velocity)` 网格搜索；内层对每个组合复用 `ShotPredictor.predict`
/// 解瞄准并以「目标球进选定袋」为**硬约束**（自动吸收 squirt / throw / swerve）。按吃库数分档枚举，
/// 库少优先；多库要求更大 margin（情形 A）。**离线批处理**——调用方应放后台串行队列。
///
/// 坐标契约：入参快照为归一化系，经 `AngleSceneCalculator` 转 SceneKit（X–Z 水平面）。
enum PositionPlaySolver {

    // MARK: - Search params (可调，默认离线密度；测试传粗网格提速)

    struct SearchParams {
        /// 横塞候选（左右塞，接触点水平偏移/R）。squirt（挤偏）只来自横塞 ⇒ **瞄准只随 spinX 变**，
        /// 故按 spinX 降维并对每个 spinX 只解一次瞄准、跨 spinY 复用（ADR-P13-01 加速）。
        var spinXValues: [Double]
        /// 竖塞候选（高低杆，接触点竖直偏移/R）。只改母球碰后跟/缩走位，不改瞄准线。
        var spinYValues: [Double]
        /// 力度（杆头速度 m/s）扫描：闭区间 [min, max] 步长 step。
        var velocityMin: Double
        var velocityMax: Double
        var velocityStep: Double
        /// 情形 A：母球停点「在区内且余量≥requiredMargin(k)」才算合格解。
        /// requiredMargin(k) = marginBase + k·marginPerCushion（米）；库越多要求越鲁棒。
        var marginBase: Float
        var marginPerCushion: Float
        /// 情形 B：母球轨迹「经过 P」的容差（米，母球中心到 P 的最近距离 < 此值）。
        var passTolerance: Float
        /// 情形 B：母球过 P 时的最小速度（m/s），低于此视为「快停下」不算经过。
        var passMinSpeed: Float

        /// 情形 A 局部求精（B3：停点曲线 velocity 轴细分求根，取代 Hooke-Jeeves 模式搜索）：
        /// 在粗网格代表解 ±velocityStep 括号内做**拓扑锁定**（同吃库桶 + 进袋 + 真停稳）的
        /// 确定性两轮 9 点细分，沿停点曲线把停点推向落区/落点更深处（分辨率 ~velocityStep/32）。
        /// 塞维保持网格分辨率——精修职责收敛到 velocity 轴（旧模式搜索的主要收益轴）。
        /// 粗网格只定位 basin；「basin 整个被跳过」靠加密 spinX，非本机制。
        var refineEnabled: Bool = true

        /// 走位复杂度预算（吃库数上限）。nil = 不限（默认，原行为）；设值（如 1）= 「仅基础走位」——
        /// **优先**返回吃库 ≤ 此值的解，**仅当其为空**才回退展示超预算解并标 `beyondCushionBudget`
        /// （用户拍板「优先+兜底」，绝不因预算给出「无解」）。
        var maxCushions: Int? = nil

        /// 塞幅/杆法预算（E3，「优先+兜底」同 `maxCushions` 语义）。nil = 不限（默认）；
        /// 设值（如 `.vertical`）= 优先返回杆法档 ≤ 此值的解，仅当其为空才回退展示更难杆法解
        /// 并标 `beyondSpinBudget`。预算 ≤ `.vertical` 时走**前置剪枝快路径**：先只扫 spinX=0 列
        /// （combos 约减半，更快），无预算内解才回退全网格重扫——绝不因预算给出「无解」。
        var maxSpinTier: ShotDifficultyTier? = nil

        /// 扰动容错分析开关（E5，默认关）：开启后对最终代表解做 ~6 次参数扰动
        /// （瞄准 ±0.5° / 力度 ±8% / 打点 ±0.05R）轻量评估，产出 `PositionPlaySolution.robustness`。
        var robustnessEnabled: Bool = false

        /// 离线默认（数秒~十几秒）。横塞降维（±0.3 三档，0 优先），竖塞五档。
        static let standard = SearchParams(
            spinXValues: [-0.3, 0, 0.3],
            spinYValues: [-0.4, -0.2, 0, 0.2, 0.4],
            velocityMin: 0.6, velocityMax: 6.0, velocityStep: 0.3,
            marginBase: 0.0, marginPerCushion: 0.04,
            passTolerance: 2 * AngleSceneCalculator.ballRadius,
            passMinSpeed: 0.2
        )

        /// 情形 B 密扫默认：塞粗、力度密（速度分段需细分辨率）。
        static let passThrough = SearchParams(
            spinXValues: [-0.3, 0, 0.3],
            spinYValues: [-0.3, 0, 0.3],
            velocityMin: 0.6, velocityMax: 6.0, velocityStep: 0.15,
            marginBase: 0.0, marginPerCushion: 0.04,
            passTolerance: 2 * AngleSceneCalculator.ballRadius,
            passMinSpeed: 0.2
        )
    }

    // MARK: - Setup (场景坐标输入)

    struct Setup {
        let cue: SCNVector3
        let target: SCNVector3
        let pocketIndex: Int
        /// 其余在桌球（K 目标 / 障碍），作真实碰撞体。
        let obstacles: [ObstacleBall]
        let surfaceY: Float
    }

    // MARK: - Entry (board snapshot 便捷入口)

    /// 从归一化快照求解。返回按「库少优先」排序的解列表（情形 A/B 见各自规则）。
    /// nil = 快照/意图不完整（缺母球/目标球/袋口非法）。
    static func solve(
        before: BoardSnapshot, targetKey: String, pocket: String,
        constraint: SolveConstraint, surfaceY: Float,
        params: SearchParams? = nil
    ) -> [PositionPlaySolution] {
        guard let cuePt = before.onTable[PositionPlayBall.cueKey],
              let targetPt = before.onTable[targetKey],
              let pocketIndex = ShotIntent.pocketIndex(for: pocket) else { return [] }
        let cue = scenePoint(cuePt, surfaceY: surfaceY)
        let target = scenePoint(targetPt, surfaceY: surfaceY)
        let obstacles: [ObstacleBall] = before.onTable.compactMap { key, pt in
            guard key != PositionPlayBall.cueKey, key != targetKey else { return nil }
            return ObstacleBall(name: key, position: scenePoint(pt, surfaceY: surfaceY))
        }
        let setup = Setup(cue: cue, target: target, pocketIndex: pocketIndex,
                          obstacles: obstacles, surfaceY: surfaceY)
        return solve(setup: setup, targetKey: targetKey, pocket: pocket, constraint: constraint, params: params)
    }

    static func solve(
        setup: Setup, targetKey: String, pocket: String,
        constraint: SolveConstraint, params: SearchParams? = nil
    ) -> [PositionPlaySolution] {
        let p: SearchParams
        switch constraint {
        case .restRegion: p = params ?? .standard
        case .passThrough: p = params ?? .passThrough
        }

        // —— E3 塞幅预算前置剪枝快路径：预算不含横塞时先只扫 spinX=0 列（combos 约减半，
        // 更快）；仅当剪枝路径无「预算内 + 满足约束」解才回退全网格重扫（完备性兜底）。——
        var solutions: [PositionPlaySolution]
        let hasSideColumns = p.spinXValues.contains { abs($0) > DifficultyModel.spinEps }
        if let cap = p.maxSpinTier, cap <= .vertical, hasSideColumns {
            var pruned = p
            pruned.spinXValues = [0]
            solutions = solveCore(setup: setup, targetKey: targetKey, pocket: pocket,
                                  constraint: constraint, params: pruned)
            if !solutions.contains(where: { $0.difficultyTier <= cap && $0.satisfiesConstraint }) {
                solutions = solveCore(setup: setup, targetKey: targetKey, pocket: pocket,
                                      constraint: constraint, params: p)
            }
        } else {
            solutions = solveCore(setup: setup, targetKey: targetKey, pocket: pocket,
                                  constraint: constraint, params: p)
        }
        return applyCushionBudget(applySpinTierBudget(solutions, cap: p.maxSpinTier),
                                  maxCushions: p.maxCushions)
    }

    /// 按约束分派核心求解（预算装饰之内的裸求解）。
    private static func solveCore(
        setup: Setup, targetKey: String, pocket: String,
        constraint: SolveConstraint, params: SearchParams
    ) -> [PositionPlaySolution] {
        switch constraint {
        case let .restRegion(region):
            var sols = solveRestRegion(setup: setup, targetKey: targetKey, pocket: pocket,
                                       region: region, params: params)
            if params.robustnessEnabled {
                sols = sols.map {
                    var s = $0
                    s.robustness = measureRobustness($0, setup: setup, targetKey: targetKey,
                                                     pocket: pocket, region: region)
                    return s
                }
            }
            return sols
        case let .passThrough(point, vMin):
            return solvePassThrough(setup: setup, targetKey: targetKey, pocket: pocket,
                                    point: point, vMin: vMin, params: params)
        }
    }

    // MARK: - E5 扰动容错分析

    /// 对一个代表解做 6 次参数扰动（瞄准 ±0.5° / 力度 ±8% / 打点 ±0.05R），统计
    /// 「扰动后仍进球 + 真停稳 + 停点在落区内」的比例（0–1，越大越抗执行误差）。
    /// 轻量实现：解析 rollout 为主（每次 ~µs 级）、覆盖不了的扰动点回退引擎 scoring-only；
    /// 只对最终解列表（每桶 1 个，通常 2–4 个）计算，开销相对扫描阶段 <2%。
    ///
    /// 动机（教学）：margin 只度量结果空间余量，不知参数空间敏感度——力度差一点就换
    /// 吃库拓扑的「悬崖解」margin 再深也不该推荐给学员。
    private static func measureRobustness(
        _ sol: PositionPlaySolution, setup: Setup, targetKey: String, pocket: String,
        region: SolveRegion
    ) -> Double {
        guard let baseOffset = sol.prediction.aimOffsetUsed, let ctx = aimContext(setup) else { return 0 }
        let y = setup.surfaceY
        let shot = sol.shot
        let aimDelta = Float(0.5) * .pi / 180
        let velocityFactor = 0.08
        let spinDelta = 0.05
        // 打点扰动不得越过打滑极限（物理上限，非搜索约束）。
        func clampSpinY(_ sy: Double) -> Double {
            let limit = Double(CuePhysics.miscueLimitFraction)
            let maxY = (limit * limit - shot.spinX * shot.spinX).squareRoot()
            return min(max(sy, -maxY), maxY)
        }
        struct Probe { let off: Float; let v: Double; let sx: Double; let sy: Double }
        let probes: [Probe] = [
            Probe(off: baseOffset + aimDelta, v: shot.velocity, sx: shot.spinX, sy: shot.spinY),
            Probe(off: baseOffset - aimDelta, v: shot.velocity, sx: shot.spinX, sy: shot.spinY),
            Probe(off: baseOffset, v: shot.velocity * (1 + velocityFactor), sx: shot.spinX, sy: shot.spinY),
            Probe(off: baseOffset, v: shot.velocity * (1 - velocityFactor), sx: shot.spinX, sy: shot.spinY),
            Probe(off: baseOffset, v: shot.velocity, sx: shot.spinX, sy: clampSpinY(shot.spinY + spinDelta)),
            Probe(off: baseOffset, v: shot.velocity, sx: shot.spinX, sy: clampSpinY(shot.spinY - spinDelta))
        ]
        var succeeded = 0
        for p in probes {
            let input = ShotInput(
                cueBall: setup.cue, targetBall: setup.target, pocketIndex: setup.pocketIndex,
                velocity: Float(p.v), spinX: Float(p.sx), spinY: Float(p.sy),
                surfaceY: y, obstacles: setup.obstacles
            )
            let fast = AnalyticShotRollout.evaluate(
                aimDir: ctx.aimDir.rotatedY(p.off), velocity: Float(p.v),
                input: input, geometry: ctx.geometry, ghost: ctx.ghost, maxTime: 15.0
            )
            var success = false
            if !fast.needsFullSim, fast.cueFirstBallHit == nil {
                if fast.pottedSelected, fast.cueRested, !fast.cuePocketed, let stop = fast.cueFinalPos {
                    success = region.signedDistanceMeters(fromScene: stop, surfaceY: y) <= 0
                }
            } else {
                // rollout 覆盖不了（级联/kiss/碰前吃库等）⇒ 引擎 scoring-only 裁决。
                let c = evaluate(setup: setup, targetKey: targetKey, pocket: pocket,
                                 spinX: p.sx, spinY: p.sy, velocity: p.v, aimOffset: p.off)
                if c.potted, cueRestedInPlace(c.prediction),
                   let stop = c.prediction.finalPositions[ShotInput.cueBallName] {
                    success = region.signedDistanceMeters(fromScene: stop, surfaceY: y) <= 0
                }
            }
            if success { succeeded += 1 }
        }
        return Double(succeeded) / Double(probes.count)
    }

    /// 塞幅/杆法预算「优先+兜底」（E3）：`cap=nil` 不限（默认，零行为变化）。三级偏好：
    /// ① 预算内且满足约束的解 → 只返回这些；② 无①但有满足约束的更难杆法解 → 返回并标
    /// `beyondSpinBudget`（教学语义「这里必须加塞」）；③ 全是降级解 → 预算内优先、否则原样。
    /// 绝不因预算给出「无解」。
    private static func applySpinTierBudget(
        _ solutions: [PositionPlaySolution], cap: ShotDifficultyTier?
    ) -> [PositionPlaySolution] {
        guard let cap else { return solutions }
        let withinSatisfying = solutions.filter { $0.difficultyTier <= cap && $0.satisfiesConstraint }
        if !withinSatisfying.isEmpty { return withinSatisfying }
        let beyondSatisfying = solutions.filter { $0.satisfiesConstraint }
        if !beyondSatisfying.isEmpty {
            return beyondSatisfying.map {
                var s = $0
                s.beyondSpinBudget = true
                return s
            }
        }
        let within = solutions.filter { $0.difficultyTier <= cap }
        return within.isEmpty ? solutions : within
    }

    /// 走位复杂度预算「优先+兜底」：`maxCushions=nil` 不限（默认，原样返回，零行为变化）；
    /// 否则优先返回吃库 ≤ 上限的解，**仅当其为空**才回退展示全部解并标 `beyondCushionBudget`。
    /// 后处理实现：不改搜索/装配，只在最终解列表上分组兜底（吃库桶很少，开销可忽略）。
    private static func applyCushionBudget(
        _ solutions: [PositionPlaySolution], maxCushions: Int?
    ) -> [PositionPlaySolution] {
        guard let cap = maxCushions else { return solutions }
        let within = solutions.filter { $0.cushionCount <= cap }
        if !within.isEmpty { return within }
        return solutions.map {
            var s = $0
            s.beyondCushionBudget = true
            return s
        }
    }

    // MARK: - Candidate evaluation

    /// 一个网格点的求解结果（含意图与预测）。
    private struct Candidate {
        let spinX: Double
        let spinY: Double
        let velocity: Double
        let shot: PlannedShot
        let prediction: ShotPrediction
        /// 目标球是否真正进选定袋（硬约束）。
        var potted: Bool { prediction.objectPocketed && prediction.feasible }
    }

    /// 母球被判定「真正停稳」的末速上限（m/s）。引擎停稳时会把速度归零，故末速显著 >0
    /// 即意味着模拟被 maxEvents/maxTime 截断、末帧不是真实停点（高速假停由此剔除）。
    static let restSpeedTolerance: Float = 0.05

    /// 跑一个候选：用走位反解快速路径（共享 `prepareAim`/`buildPrediction`，黄金分割轻量瞄准）。
    /// `aimOffset` 为预解的记忆化瞄准（跨 spinY 复用）；为 nil 时现解。
    /// **漏进重解护栏**：复用 aim 没进、但该 spin 自解 aim 可能进 ⇒ 对漏进者单独重解一次，保完备性。
    /// **scoring-only（B1）**：搜索候选一律跳过展示后处理 + 引擎早停（物理判定不变）；
    /// 上屏代表解经 `finalizeCandidate` 用同一 aimOffset 重建完整 prediction。
    /// `aimSearchCenter`：非 nil 且 `aimOffset == nil` 时，瞄准现解用窄括号热启动（精修邻居用）。
    private static func evaluate(
        setup: Setup, targetKey: String, pocket: String,
        spinX: Double, spinY: Double, velocity: Double, aimOffset: Float?,
        aimSearchCenter: Float? = nil
    ) -> Candidate {
        let input = ShotInput(
            cueBall: setup.cue, targetBall: setup.target, pocketIndex: setup.pocketIndex,
            velocity: Float(velocity), spinX: Float(spinX), spinY: Float(spinY),
            surfaceY: setup.surfaceY, obstacles: setup.obstacles
        )
        var pred = predictScoring(input, aimOffset: aimOffset, aimSearchCenter: aimSearchCenter)
        if aimOffset != nil, pred.feasible, !pred.objectPocketed {
            let reSolved = predictScoring(input, aimOffset: nil, aimSearchCenter: nil)
            if reSolved.objectPocketed { pred = reSolved }
        }
        let shot = PlannedShot(targetKey: targetKey, pocket: pocket,
                               velocity: velocity, spinX: spinX, spinY: spinY)
        return Candidate(spinX: spinX, spinY: spinY, velocity: velocity, shot: shot, prediction: pred)
    }

    /// scoring-only 预测（B1）：窄括号热启动时先自解瞄准再走快速路径。
    private static func predictScoring(
        _ input: ShotInput, aimOffset: Float?, aimSearchCenter: Float?
    ) -> ShotPrediction {
        if aimOffset == nil, let center = aimSearchCenter {
            var probe = ShotPrediction()
            guard let ctx = ShotPredictor.prepareAim(input, into: &probe) else { return probe }
            let narrowHalf = Float(2.0) * .pi / 180   // 邻居最优瞄准必在种子附近（±2° 覆盖 squirt/throw 漂移）
            let off = ShotPredictor.positionAimOffset(input: input, context: ctx,
                                                      center: center, halfRange: narrowHalf)
            return ShotPredictor.predictForPositionSolve(input, aimOffset: off,
                                                         includePresentation: false)
        }
        return ShotPredictor.predictForPositionSolve(input, aimOffset: aimOffset,
                                                     includePresentation: false)
    }

    /// 把 scoring-only 候选重建为**完整 prediction**（含轨迹折线/extraBallPaths/分离角，无早停）。
    /// 用候选实际使用的 `aimOffsetUsed` ⇒ 同物理同判定，只补展示量（B1「画面=物理」终验路径）。
    private static func finalizeCandidate(_ c: Candidate, setup: Setup) -> Candidate {
        guard let offset = c.prediction.aimOffsetUsed else { return c }   // 不可行候选无重建必要
        let input = ShotInput(
            cueBall: setup.cue, targetBall: setup.target, pocketIndex: setup.pocketIndex,
            velocity: Float(c.velocity), spinX: Float(c.spinX), spinY: Float(c.spinY),
            surfaceY: setup.surfaceY, obstacles: setup.obstacles
        )
        let full = ShotPredictor.predictForPositionSolve(input, aimOffset: offset)
        return Candidate(spinX: c.spinX, spinY: c.spinY, velocity: c.velocity,
                         shot: c.shot, prediction: full)
    }

    /// 瞄准几何上下文（仅取决于母球/目标球/袋口，与塞/力度无关）。nil = 几何不可进袋（无可进解）。
    private static func aimContext(_ setup: Setup) -> ShotPredictor.AimContext? {
        var probe = ShotPrediction()
        let baseInput = ShotInput(
            cueBall: setup.cue, targetBall: setup.target, pocketIndex: setup.pocketIndex,
            velocity: 1, spinX: 0, spinY: 0, surfaceY: setup.surfaceY, obstacles: setup.obstacles
        )
        return ShotPredictor.prepareAim(baseInput, into: &probe)
    }

    // MARK: - 快速扫描层（B3：单球解析 rollout + 引擎回退）

    /// 一个扫描格子：rollout 快速评估（`fast`）或引擎回退候选（`engine`）二选一。
    /// 快速格子只承载扫描消费的结果量；**任何被选为代表/降级解的格子都会经
    /// `materializeRegion` 引擎复核**——扫描层加速，上屏判定不降级。
    private struct ScanCell {
        let spinX: Double
        let spinY: Double
        let velocity: Double
        /// 本格实际使用的瞄准偏移（记忆化 aim 或漏进重解后的 aim）。
        let aimOffset: Float
        let fast: AnalyticShotRollout.ShotOutcome?
        let engine: Candidate?
    }

    /// 扫描矩阵 `[comboIdx][velIdx]`（B3）：结构与瞄准记忆化跟旧 `candidateMatrix` 完全一致，
    /// 仅把每格的引擎全模拟换成 rollout 快速评估；rollout 自报覆盖不了的格子
    /// （碰前吃库/kiss 风险/级联/截断）在并行段内就地回退引擎（语义与旧路径逐位一致）。
    /// `upgradeOnCueBallHit`：情形 A 母球碰后撞第三球 = 级联 ⇒ 回退引擎；
    /// 情形 B 撞球是 K 球语义的一部分 ⇒ 保留 fast 格子由过点查询消费。
    private static func scanMatrix(
        setup: Setup, targetKey: String, pocket: String,
        ctx: ShotPredictor.AimContext,
        combos: [(Double, Double)], velocities: [Double],
        upgradeOnCueBallHit: Bool
    ) -> [[ScanCell]] {
        guard !combos.isEmpty, !velocities.isEmpty else { return [] }
        let velCount = velocities.count

        // ① 记忆化瞄准：唯一 spinX × velocity（与旧路径同一段，B2 解析评分）。
        let uniqueSpinX = Array(Set(combos.map { $0.0 })).sorted()
        let sxIndex = Dictionary(uniqueKeysWithValues: uniqueSpinX.enumerated().map { ($1, $0) })
        var aimKeys: [(Double, Double)] = []
        for sx in uniqueSpinX { for v in velocities { aimKeys.append((sx, v)) } }
        var offsets = [Float](repeating: 0, count: aimKeys.count)
        PerformanceProfiler.begin(ProfilerLabel.solverAimMemo)
        offsets.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: aimKeys.count) { i in
                let (sx, v) = aimKeys[i]
                let inp = ShotInput(
                    cueBall: setup.cue, targetBall: setup.target, pocketIndex: setup.pocketIndex,
                    velocity: Float(v), spinX: Float(sx), spinY: 0,
                    surfaceY: setup.surfaceY, obstacles: setup.obstacles
                )
                (base + i).pointee = ShotPredictor.positionAimOffset(input: inp, context: ctx)
            }
        }
        PerformanceProfiler.end(ProfilerLabel.solverAimMemo)

        // ② 全候选并行快速评估（rollout；覆盖不了的格子就地引擎回退）。
        let total = combos.count * velCount
        var flat = [ScanCell?](repeating: nil, count: total)
        PerformanceProfiler.begin(ProfilerLabel.solverCandidateEval)
        flat.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: total) { idx in
                let ci = idx / velCount, vi = idx % velCount
                let (sx, sy) = combos[ci]
                let aim = offsets[sxIndex[sx]! * velCount + vi]
                (base + idx).pointee = makeScanCell(
                    setup: setup, targetKey: targetKey, pocket: pocket, ctx: ctx,
                    spinX: sx, spinY: sy, velocity: velocities[vi], memoAim: aim,
                    upgradeOnCueBallHit: upgradeOnCueBallHit)
            }
        }
        PerformanceProfiler.end(ProfilerLabel.solverCandidateEval)

        var matrix: [[ScanCell]] = []
        matrix.reserveCapacity(combos.count)
        for ci in 0..<combos.count {
            matrix.append((0..<velCount).compactMap { flat[ci * velCount + $0] })
        }
        return matrix
    }

    /// 单格评估：rollout 快速路径 + 漏进重解护栏（与引擎路径 `evaluate` 同语义）+ 引擎回退。
    private static func makeScanCell(
        setup: Setup, targetKey: String, pocket: String,
        ctx: ShotPredictor.AimContext,
        spinX: Double, spinY: Double, velocity: Double, memoAim: Float,
        upgradeOnCueBallHit: Bool
    ) -> ScanCell {
        let input = ShotInput(
            cueBall: setup.cue, targetBall: setup.target, pocketIndex: setup.pocketIndex,
            velocity: Float(velocity), spinX: Float(spinX), spinY: Float(spinY),
            surfaceY: setup.surfaceY, obstacles: setup.obstacles
        )
        // maxTime 15s：与引擎路径 `predictForPositionSolve` 默认上限同口径。
        var fast = AnalyticShotRollout.evaluate(
            aimDir: ctx.aimDir.rotatedY(memoAim), velocity: Float(velocity),
            input: input, geometry: ctx.geometry, ghost: ctx.ghost, maxTime: 15.0
        )
        var usedAim = memoAim
        // 漏进重解护栏：复用 aim 没进、但该 spin 自解 aim 可能进 ⇒ 重解一次（引擎路径同语义）。
        if !fast.needsFullSim, !fast.pottedSelected {
            let reAim = ShotPredictor.positionAimOffset(input: input, context: ctx)
            if abs(reAim - memoAim) > 1e-7 {
                let retry = AnalyticShotRollout.evaluate(
                    aimDir: ctx.aimDir.rotatedY(reAim), velocity: Float(velocity),
                    input: input, geometry: ctx.geometry, ghost: ctx.ghost, maxTime: 15.0
                )
                if !retry.needsFullSim, retry.pottedSelected {
                    fast = retry
                    usedAim = reAim
                }
            }
        }
        if fast.needsFullSim || (upgradeOnCueBallHit && fast.cueFirstBallHit != nil) {
            let c = evaluate(setup: setup, targetKey: targetKey, pocket: pocket,
                             spinX: spinX, spinY: spinY, velocity: velocity, aimOffset: memoAim)
            return ScanCell(spinX: spinX, spinY: spinY, velocity: velocity,
                            aimOffset: c.prediction.aimOffsetUsed ?? memoAim,
                            fast: nil, engine: c)
        }
        return ScanCell(spinX: spinX, spinY: spinY, velocity: velocity,
                        aimOffset: usedAim, fast: fast, engine: nil)
    }

    /// 合法打点组合（横塞 × 竖塞，剔除幅值 > 0.5R 打滑极限）。
    private static func spinCombos(xValues: [Double], yValues: [Double]) -> [(Double, Double)] {
        let limit = Double(CuePhysics.miscueLimitFraction)
        var combos: [(Double, Double)] = []
        for x in xValues {
            for y in yValues where (x * x + y * y).squareRoot() <= limit + 1e-6 {
                combos.append((x, y))
            }
        }
        return combos
    }

    private static func velocitySamples(_ p: SearchParams) -> [Double] {
        var v = p.velocityMin
        var out: [Double] = []
        while v <= p.velocityMax + 1e-9 {
            out.append(v)
            v += p.velocityStep
        }
        return out
    }

    // MARK: - Case A: rest region

    /// 一个已打分的扫描点（网格格子或求精后的 off-grid 点）。`engine != nil` 表示该点
    /// 已有引擎候选（回退格 / 复核产物），signed/cushion 即引擎口径。
    private struct ScoredPoint {
        let spinX: Double
        let spinY: Double
        let velocity: Double
        let aimOffset: Float
        let engine: Candidate?
        let signed: Float        // 停点到落区有符号距离（区内为负）
        let cushion: Int         // 碰球后母球吃库数
        /// 执行难度加权范数（E1）：横塞权重 2.5×高低杆 + 力度惩罚（取代旧对称 spinMag）。
        var effort: Double { DifficultyModel.executionEffort(spinX: spinX, spinY: spinY, velocity: velocity) }
        /// 是否带横塞（0 库特判用）。
        var hasSideSpin: Bool { abs(spinX) > DifficultyModel.spinEps }
    }

    private static func solveRestRegion(
        setup: Setup, targetKey: String, pocket: String,
        region: SolveRegion, params: SearchParams
    ) -> [PositionPlaySolution] {
        let combos = spinCombos(xValues: params.spinXValues, yValues: params.spinYValues)
        let velocities = velocitySamples(params)
        let y = setup.surfaceY
        guard let ctx = aimContext(setup) else { return [] }

        // —— 扫描（B3）：rollout 快速评估为主、引擎按需回退（碰前吃库/kiss/级联/截断）。——
        let cells = scanMatrix(setup: setup, targetKey: targetKey, pocket: pocket, ctx: ctx,
                               combos: combos, velocities: velocities,
                               upgradeOnCueBallHit: true).flatMap { $0 }

        // 潜在解打分：进袋 + 真停稳 + 有停点。
        var pottedScored: [ScoredPoint] = []
        for cell in cells {
            if let s = scoreRegionCell(cell, region: region, y: y), sIsPotted(cell) {
                pottedScored.append(s)
            }
        }

        func requiredMargin(_ k: Int) -> Float { params.marginBase + Float(k) * params.marginPerCushion }
        // 桶内代表偏好（E1 可执行性感知，用户拍板「越少加塞越好」升级为难度加权）：
        // ① 0 库桶特判——母球不吃库时横塞几乎零走位收益却最难执行，同桶存在无横塞解则
        //   无横塞者恒优先（可替代性以同桶扫描结果为证据）；
        // ② 执行难度加权范数（横塞 2.5×高低杆 + 力度惩罚）小者优先，同难度取扎入更深者；
        // ③ 再以 (velocity, spinX, spinY) 定序，保证并行扫描下的确定性。
        func preferLessSpin(_ a: ScoredPoint, than b: ScoredPoint) -> Bool {
            if a.cushion == 0, b.cushion == 0, a.hasSideSpin != b.hasSideSpin {
                return !a.hasSideSpin
            }
            if abs(a.effort - b.effort) > 1e-9 { return a.effort < b.effort }
            if abs(a.signed - b.signed) > 1e-9 { return a.signed < b.signed }
            if a.velocity != b.velocity { return a.velocity < b.velocity }
            if a.spinX != b.spinX { return a.spinX < b.spinX }
            return a.spinY < b.spinY
        }
        func closerFirst(_ a: ScoredPoint, _ b: ScoredPoint) -> Bool {
            if abs(a.signed - b.signed) > 1e-9 { return a.signed < b.signed }
            return preferLessSpin(a, than: b)
        }

        /// 每桶按偏好保留前 3 个候选（引擎复核失败时的备选）。
        func topPerBucket(
            _ scored: [ScoredPoint], qualifies: (ScoredPoint) -> Bool,
            better: (ScoredPoint, ScoredPoint) -> Bool
        ) -> [Int: [ScoredPoint]] {
            var buckets: [Int: [ScoredPoint]] = [:]
            for s in scored where qualifies(s) {
                var list = buckets[s.cushion] ?? []
                list.append(s)
                list.sort(by: better)
                if list.count > 3 { list.removeLast(list.count - 3) }
                buckets[s.cushion] = list
            }
            return buckets
        }

        /// 桶代表落地流水线：曲线求精（B3，refineEnabled 时）→ 引擎复核物化。
        /// 复核顺序：求精点 → 原种子 → 桶内次优（求精/复核失败都有确定性退路）。
        func settle(
            _ list: [ScoredPoint], keepBucket: Bool
        ) -> (candidate: Candidate, signed: Float, cushion: Int)? {
            guard let seed = list.first else { return nil }
            var attempts: [ScoredPoint] = []
            if params.refineEnabled {
                let polished = PerformanceProfiler.measureSample(ProfilerLabel.solverRefine) {
                    polishVelocityCurve(seed, setup: setup, targetKey: targetKey, pocket: pocket,
                                        ctx: ctx, region: region, params: params)
                }
                attempts.append(polished)
            }
            attempts.append(contentsOf: list)
            for a in attempts {
                if let m = materializeRegion(a, setup: setup, targetKey: targetKey, pocket: pocket,
                                             region: region, requirePotted: true) {
                    // 引擎复核后的吃库桶若漂移（rollout 与引擎在边界档位的罕见分歧），
                    // 弃用该点试下一备选——桶语义以引擎为准，不迁桶以保桶唯一性。
                    if keepBucket && m.cushion != seed.cushion { continue }
                    return m
                }
            }
            return nil
        }

        if region.isPoint {
            // 落点：最小化到点距离。对所有可进解按吃库桶取「最近代表」（不要求命中也返回），
            // 求精后库少 → 更近排序；容差内（signed<=0）才标满足约束。
            let buckets = topPerBucket(pottedScored, qualifies: { _ in true }, better: closerFirst)
            if !buckets.isEmpty {
                var settled: [(Candidate, Float, Int)] = []
                for key in buckets.keys.sorted() {
                    if let m = settle(buckets[key]!, keepBucket: true), !settled.contains(where: { $0.2 == m.cushion }) {
                        settled.append(m)
                    }
                }
                let ordered = settled.sorted {
                    if $0.2 != $1.2 { return $0.2 < $1.2 }
                    return $0.1 < $1.1
                }
                if !ordered.isEmpty {
                    return ordered.map { makeRegionSolution(finalizeCandidate($0.0, setup: setup),
                                                            signed: $0.1, cushion: $0.2,
                                                            satisfied: $0.1 <= 0, region: region,
                                                            setup: setup) }
                }
            }
        } else {
            // 合格解：在区内（signed<=0）且余量(-signed) >= requiredMargin(cushion)。
            let buckets = topPerBucket(
                pottedScored,
                qualifies: { $0.signed <= 0 && (-$0.signed) >= requiredMargin($0.cushion) },
                better: preferLessSpin)
            if !buckets.isEmpty {
                var settled: [(Candidate, Float, Int)] = []
                for key in buckets.keys.sorted() {
                    if let m = settle(buckets[key]!, keepBucket: true), !settled.contains(where: { $0.2 == m.cushion }) {
                        settled.append(m)
                    }
                }
                // 排序：库少优先 → 执行难度小优先（E1 加权范数）→ 扎入更深（更鲁棒）。
                let ordered = settled.sorted {
                    if $0.2 != $1.2 { return $0.2 < $1.2 }
                    let s0 = candidateEffort($0.0), s1 = candidateEffort($1.0)
                    if abs(s0 - s1) > 1e-9 { return s0 < s1 }
                    return $0.1 < $1.1
                }
                if !ordered.isEmpty {
                    return ordered.map { makeRegionSolution(finalizeCandidate($0.0, setup: setup),
                                                            signed: $0.1, cushion: $0.2,
                                                            satisfied: true, region: region,
                                                            setup: setup) }
                }
            }
            // 降级：无合格解。取「能进球」的最接近解求精——求精后可能反升级为满足约束。
            let closestSorted = pottedScored.sorted(by: closerFirst)
            if !closestSorted.isEmpty,
               let m = settle(Array(closestSorted.prefix(3)), keepBucket: false) {
                let satisfied = m.signed <= 0 && (-m.signed) >= requiredMargin(m.cushion)
                return [makeRegionSolution(finalizeCandidate(m.candidate, setup: setup),
                                           signed: m.signed, cushion: m.cushion,
                                           satisfied: satisfied, region: region, setup: setup)]
            }
        }
        // 连进球解都没有：取「能进球与否不论」里停点最接近落区者，标注未进袋。
        var fallbacks: [ScoredPoint] = []
        for cell in cells {
            if let s = scoreRegionCell(cell, region: region, y: y) { fallbacks.append(s) }
        }
        fallbacks.sort(by: closerFirst)
        for f in fallbacks.prefix(3) {
            if let m = materializeRegion(f, setup: setup, targetKey: targetKey, pocket: pocket,
                                         region: region, requirePotted: false) {
                return [makeRegionSolution(finalizeCandidate(m.candidate, setup: setup),
                                           signed: m.signed, cushion: m.cushion,
                                           satisfied: false, region: region, setup: setup)]
            }
        }
        return []
    }

    /// 格子是否进袋（快速/引擎两口径）。
    private static func sIsPotted(_ cell: ScanCell) -> Bool {
        if let f = cell.fast { return f.pottedSelected }
        return cell.engine?.potted ?? false
    }

    /// 情形 A 打分：进袋与否不论，只要「真停稳 + 有停点」即产出 ScoredPoint（潜在解由调用方
    /// 再叠加进袋过滤；最终降级支需要非进袋停点）。
    private static func scoreRegionCell(
        _ cell: ScanCell, region: SolveRegion, y: Float
    ) -> ScoredPoint? {
        if let f = cell.fast {
            guard f.cueRested, !f.cuePocketed, let stop = f.cueFinalPos else { return nil }
            return ScoredPoint(spinX: cell.spinX, spinY: cell.spinY, velocity: cell.velocity,
                               aimOffset: cell.aimOffset, engine: nil,
                               signed: region.signedDistanceMeters(fromScene: stop, surfaceY: y),
                               cushion: f.cueCushionsAfterContact)
        }
        guard let c = cell.engine, c.prediction.feasible, cueRestedInPlace(c.prediction),
              let stop = c.prediction.finalPositions[ShotInput.cueBallName] else { return nil }
        let cushion = max(0, c.prediction.cueCushionCount - c.prediction.cueCushionsBeforeContact)
        return ScoredPoint(spinX: cell.spinX, spinY: cell.spinY, velocity: cell.velocity,
                           aimOffset: cell.aimOffset, engine: c,
                           signed: region.signedDistanceMeters(fromScene: stop, surfaceY: y),
                           cushion: cushion)
    }

    /// B3 曲线求精（取代 Hooke-Jeeves 模式搜索）：固定 (spinX, spinY)，在种子 ±velocityStep
    /// 括号内沿「velocity → 停点有符号距离」曲线做**确定性两轮 9 点细分**（拓扑锁定：只接受
    /// 进袋 + 真停稳 + 同吃库桶的点），把停点推向落区/落点更深处。分辨率 ~velocityStep/32。
    /// 每个探测点瞄准用种子 aim 窄括号热启动（±2°，B1 同款——邻域最优瞄准必在种子附近）。
    private static func polishVelocityCurve(
        _ seed: ScoredPoint, setup: Setup, targetKey: String, pocket: String,
        ctx: ShotPredictor.AimContext, region: SolveRegion, params: SearchParams
    ) -> ScoredPoint {
        let y = setup.surfaceY
        let narrowHalf = Float(2.0) * .pi / 180

        func scoreAt(_ v: Double) -> ScoredPoint? {
            let input = ShotInput(
                cueBall: setup.cue, targetBall: setup.target, pocketIndex: setup.pocketIndex,
                velocity: Float(v), spinX: Float(seed.spinX), spinY: Float(seed.spinY),
                surfaceY: setup.surfaceY, obstacles: setup.obstacles
            )
            let aim = ShotPredictor.positionAimOffset(
                input: input, context: ctx, center: seed.aimOffset, halfRange: narrowHalf)
            let fast = AnalyticShotRollout.evaluate(
                aimDir: ctx.aimDir.rotatedY(aim), velocity: Float(v),
                input: input, geometry: ctx.geometry, ghost: ctx.ghost, maxTime: 15.0
            )
            if !fast.needsFullSim, fast.cueFirstBallHit == nil {
                guard fast.pottedSelected, fast.cueRested, !fast.cuePocketed,
                      let stop = fast.cueFinalPos else { return nil }
                return ScoredPoint(spinX: seed.spinX, spinY: seed.spinY, velocity: v,
                                   aimOffset: aim, engine: nil,
                                   signed: region.signedDistanceMeters(fromScene: stop, surfaceY: y),
                                   cushion: fast.cueCushionsAfterContact)
            }
            // rollout 覆盖不了的邻域点走引擎（与种子为引擎回退格的情形同路）。
            let c = evaluate(setup: setup, targetKey: targetKey, pocket: pocket,
                             spinX: seed.spinX, spinY: seed.spinY, velocity: v,
                             aimOffset: nil, aimSearchCenter: seed.aimOffset)
            guard c.potted, cueRestedInPlace(c.prediction),
                  let stop = c.prediction.finalPositions[ShotInput.cueBallName] else { return nil }
            let cushion = max(0, c.prediction.cueCushionCount - c.prediction.cueCushionsBeforeContact)
            return ScoredPoint(spinX: seed.spinX, spinY: seed.spinY, velocity: v,
                               aimOffset: c.prediction.aimOffsetUsed ?? seed.aimOffset, engine: c,
                               signed: region.signedDistanceMeters(fromScene: stop, surfaceY: y),
                               cushion: cushion)
        }

        var best = seed
        var lo = max(params.velocityMin, seed.velocity - params.velocityStep)
        var hi = min(params.velocityMax, seed.velocity + params.velocityStep)
        for _ in 0..<2 {
            let n = 8
            var roundBest = best
            for i in 0...n {
                let v = lo + (hi - lo) * Double(i) / Double(n)
                guard abs(v - best.velocity) > 1e-9 else { continue }
                guard let s = scoreAt(v), s.cushion == seed.cushion else { continue }
                if s.signed < roundBest.signed - 1e-6 { roundBest = s }
            }
            best = roundBest
            let span = (hi - lo) / Double(n)
            lo = max(params.velocityMin, best.velocity - span)
            hi = min(params.velocityMax, best.velocity + span)
        }
        return best
    }

    /// 把扫描/求精胜出点物化为引擎候选（全保真判定护栏，B3）：快速点经引擎 scoring-only 复核，
    /// 引擎点直接复用其候选；signed/cushion 一律以引擎预测为准（画面=物理）。
    /// nil = 复核失败（进袋/停稳被引擎推翻）——调用方按确定性顺序试下一备选。
    private static func materializeRegion(
        _ s: ScoredPoint, setup: Setup, targetKey: String, pocket: String,
        region: SolveRegion, requirePotted: Bool
    ) -> (candidate: Candidate, signed: Float, cushion: Int)? {
        let y = setup.surfaceY
        let c: Candidate
        if let e = s.engine {
            c = e
        } else {
            c = evaluate(setup: setup, targetKey: targetKey, pocket: pocket,
                         spinX: s.spinX, spinY: s.spinY, velocity: s.velocity,
                         aimOffset: s.aimOffset)
        }
        if requirePotted {
            guard c.potted else { return nil }
        } else {
            guard c.prediction.feasible else { return nil }
        }
        guard cueRestedInPlace(c.prediction),
              let stop = c.prediction.finalPositions[ShotInput.cueBallName] else { return nil }
        let signed = region.signedDistanceMeters(fromScene: stop, surfaceY: y)
        let cushion = max(0, c.prediction.cueCushionCount - c.prediction.cueCushionsBeforeContact)
        return (c, signed, cushion)
    }

    /// 候选执行难度（E1 加权范数：横塞 2.5×高低杆 + 力度惩罚）。用于「越易执行越好」排序。
    private static func candidateEffort(_ c: Candidate) -> Double {
        DifficultyModel.executionEffort(spinX: c.spinX, spinY: c.spinY, velocity: c.velocity)
    }

    /// 母球是否真正「停在桌面某处」：未 scratch（进袋 = 无停点）且末速接近 0（≠ 截断假停）。
    /// 情形 A 的落区解只接受真实停点——杜绝「母球高速却被当作停在区域内」的反常解（用户反馈）。
    private static func cueRestedInPlace(_ p: ShotPrediction) -> Bool {
        !p.cuePocketed && p.cueFinalSpeed < restSpeedTolerance
    }

    /// 综合难度评分 + 档位（E2/E4）：塞加权范数 + 力度惩罚 + 进球难度（切角/球距，
    /// 同一次求解内为常量——只影响绝对评分与标注，不影响解间排序）。
    private static func difficulty(
        _ c: Candidate, setup: Setup
    ) -> (score: Double, tier: ShotDifficultyTier) {
        let dist = Double(AngleSceneCalculator.horizontalDistance(setup.cue, setup.target))
        let score = DifficultyModel.score(
            spinX: c.spinX, spinY: c.spinY, velocity: c.velocity,
            cutAngleDeg: c.prediction.cutAngleDeg, cueTargetDistance: dist)
        return (score, DifficultyModel.tier(spinX: c.spinX, spinY: c.spinY))
    }

    /// 难度文案（E2/E4）：档位语义 + 综合难度档；薄球（切角超阈）加标注。
    private static func difficultyText(
        tier: ShotDifficultyTier, score: Double, cutAngleDeg: Double?
    ) -> String {
        var t = "\(tier.label) · 难度\(DifficultyModel.gradeLabel(score))"
        if let cut = cutAngleDeg, cut > DifficultyModel.thinCutLabelDeg {
            t += "（薄球）"
        }
        return t
    }

    private static func makeRegionSolution(
        _ c: Candidate, signed: Float, cushion: Int, satisfied: Bool, region: SolveRegion,
        setup: Setup
    ) -> PositionPlaySolution {
        let margin = -signed   // 区内深度（正=离边界多远，越大越鲁棒）；区外为负。
        let constraintText: String
        if case let .point(_, tol) = region {
            // 落点：展示「到目标点距离」= signed + 容差半径（≥0），而非到容差边界的有符号量。
            let distToCenter = max(0, signed + Float(tol) * SolveRegion.sceneScale)
            let dcm = Int((distToCenter * 100).rounded())
            if c.potted {
                constraintText = signed <= 0 ? "命中落点（容差内）· 距目标约 \(dcm)cm" : "距目标约 \(dcm)cm"
            } else {
                constraintText = "未进袋（最接近解）· 距目标约 \(dcm)cm"
            }
        } else {
            let cm = Int((abs(signed) * 100).rounded())
            if c.potted {
                constraintText = signed <= 0 ? "停点在落区内 · 余量约 \(cm)cm" : "未落区 · 距落区约 \(cm)cm"
            } else {
                constraintText = "未进袋（最接近解）· 距落区约 \(cm)cm"
            }
        }
        let d = difficulty(c, setup: setup)
        let diffText = difficultyText(tier: d.tier, score: d.score, cutAngleDeg: c.prediction.cutAngleDeg)
        let summary = "\(spinText(c.spinX, c.spinY)) · \(PowerDisplay.name(c.velocity)) \(String(format: "%.1f", c.velocity)) · \(cushionText(cushion)) · \(diffText) · \(constraintText)"
        return PositionPlaySolution(
            shot: c.shot, prediction: c.prediction, cushionCount: cushion,
            potted: c.potted, margin: margin, summary: summary,
            satisfiesConstraint: satisfied && c.potted && signed <= 0,
            difficultyScore: d.score, difficultyTier: d.tier
        )
    }

    // MARK: - Case B: pass-through (K-ball)

    private static func solvePassThrough(
        setup: Setup, targetKey: String, pocket: String,
        point: CanvasPoint, vMin: Double, params: SearchParams
    ) -> [PositionPlaySolution] {
        let combos = spinCombos(xValues: params.spinXValues, yValues: params.spinYValues)
        let velocities = velocitySamples(params)
        let p = scenePoint(point, surfaceY: setup.surfaceY)
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: setup.surfaceY)
        let minSpeed = max(params.passMinSpeed, Float(vMin))
        guard let ctx = aimContext(setup) else { return [] }

        // 一次速度采样的通过信息。
        struct PassSample {
            let velocity: Double
            let cushionsBeforeP: Int
            /// 过 P 后母球碰到的第一颗球到最近袋口的距离（米）；nil = 过 P 后未再碰球。
            let firstBallNearestPocket: Float?
        }

        // —— 扫描（B3）：rollout 快速评估 + 过点闭式段查询；歧义格（撞球/截断后仍可能过点）
        // 就地回退引擎（语义与旧全引擎路径逐格一致）。撞球在情形 B 是 K 球语义 ⇒ 不升级。——
        let matrix = scanMatrix(setup: setup, targetKey: targetKey, pocket: pocket, ctx: ctx,
                                combos: combos, velocities: velocities,
                                upgradeOnCueBallHit: false)
        guard !matrix.isEmpty else { return [] }

        /// 单格 → 过点样本（并行，各写互不相交下标）。
        func resolveSample(_ cell: ScanCell) -> PassSample? {
            // 引擎格（碰前吃库/kiss/级联回退）：旧口径 passInfo 回放查询。
            if let c = cell.engine {
                guard c.potted,
                      let pass = passInfo(c, p: p, minSpeed: minSpeed, surfaceY: setup.surfaceY,
                                          obstacles: setup.obstacles, pockets: pockets,
                                          tol: params.passTolerance) else { return nil }
                return PassSample(velocity: c.velocity, cushionsBeforeP: pass.cushionsBeforeP,
                                  firstBallNearestPocket: pass.firstBallNearestPocket)
            }
            guard let fast = cell.fast, fast.pottedSelected else { return nil }
            switch passInfoFast(fast, p: p, minSpeed: minSpeed,
                                obstacles: setup.obstacles, pockets: pockets,
                                tol: params.passTolerance) {
            case .pass(let pr):
                return PassSample(velocity: cell.velocity, cushionsBeforeP: pr.cushionsBeforeP,
                                  firstBallNearestPocket: pr.firstBallNearestPocket)
            case .noPass:
                return nil
            case .ambiguous:
                // 母球撞球/截断处路径中止且尚未过点：级联后仍可能过点 ⇒ 引擎全模拟裁决。
                let c = evaluate(setup: setup, targetKey: targetKey, pocket: pocket,
                                 spinX: cell.spinX, spinY: cell.spinY, velocity: cell.velocity,
                                 aimOffset: cell.aimOffset)
                guard c.potted,
                      let pass = passInfo(c, p: p, minSpeed: minSpeed, surfaceY: setup.surfaceY,
                                          obstacles: setup.obstacles, pockets: pockets,
                                          tol: params.passTolerance) else { return nil }
                return PassSample(velocity: c.velocity, cushionsBeforeP: pass.cushionsBeforeP,
                                  firstBallNearestPocket: pass.firstBallNearestPocket)
            }
        }

        let velCount = velocities.count
        var samplesFlat = [PassSample?](repeating: nil, count: combos.count * velCount)
        PerformanceProfiler.begin(ProfilerLabel.solverPassInfo)
        samplesFlat.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: combos.count * velCount) { idx in
                let ci = idx / velCount, vi = idx % velCount
                guard ci < matrix.count, vi < matrix[ci].count else { return }
                (base + idx).pointee = resolveSample(matrix[ci][vi])
            }
        }
        PerformanceProfiler.end(ProfilerLabel.solverPassInfo)

        var solutions: [PositionPlaySolution] = []
        for (ci, combo) in combos.enumerated() where ci < matrix.count {
            let (sx, sy) = combo
            let samples = Array(samplesFlat[(ci * velCount)..<((ci + 1) * velCount)])
            // 连续命中（且到 P 前吃库数相同）聚成速度分段，取中值为代表（off-grid，单独现解瞄准）。
            var i = 0
            while i < samples.count {
                guard let s = samples[i] else { i += 1; continue }
                var j = i
                while j + 1 < samples.count,
                      let nxt = samples[j + 1],
                      nxt.cushionsBeforeP == s.cushionsBeforeP {
                    j += 1
                }
                let lo = s.velocity
                let hi = samples[j]!.velocity
                let midV = (lo + hi) / 2
                var bestNearest: Float = .greatestFiniteMagnitude
                for k in i...j {
                    if let np = samples[k]?.firstBallNearestPocket { bestNearest = min(bestNearest, np) }
                }
                let rep = evaluate(setup: setup, targetKey: targetKey, pocket: pocket,
                                   spinX: sx, spinY: sy, velocity: midV, aimOffset: nil)
                solutions.append(makePassSolution(
                    finalizeCandidate(rep, setup: setup),
                    cushion: s.cushionsBeforeP, nearestPocket: bestNearest,
                    velocityRange: (lo, hi), setup: setup))
                i = j + 1
            }
        }

        // 排序：库少优先 → 「过 P 后第一颗球离袋距离」升序（K 球质量）→ 执行难度小优先
        // （E1 加权范数，取代旧对称塞幅）。
        solutions.sort {
            if $0.cushionCount != $1.cushionCount { return $0.cushionCount < $1.cushionCount }
            if abs($0.margin - $1.margin) > 1e-4 { return $0.margin < $1.margin }
            let s0 = DifficultyModel.executionEffort(
                spinX: $0.shot.spinX, spinY: $0.shot.spinY, velocity: $0.shot.velocity)
            let s1 = DifficultyModel.executionEffort(
                spinX: $1.shot.spinX, spinY: $1.shot.spinY, velocity: $1.shot.velocity)
            return s0 < s1
        }
        return solutions
    }

    private struct PassResult {
        let cushionsBeforeP: Int
        let firstBallNearestPocket: Float?
    }

    /// 判定母球是否在 v>minSpeed 时经过 P；并统计到 P 前吃库数与过 P 后第一颗碰撞球离袋最近距离。
    ///
    /// **B1 事件段扫描**：不再对全程做 dt=0.01 均匀回放采样，而是按母球的**事件帧段**扫描——
    /// 每段先用「弦线段-点距离 − 曲率松弛」做保守下界剪枝（滚动/静止段解析演进为直线 ⇒ 下界精确；
    /// 滑动段可能因塞弧线弯曲 ⇒ 减去 aT²/8 抛物线偏差上界），只有**可能过 P** 的段才做段内
    /// dt=0.01 局部加密。判定语义与全程采样一致（同网格密度），只是跳过了不可能命中的段。
    private static func passInfo(
        _ c: Candidate, p: SCNVector3, minSpeed: Float, surfaceY: Float,
        obstacles: [ObstacleBall], pockets: [SCNVector3], tol: Float
    ) -> PassResult? {
        guard let recorder = c.prediction.recorder, c.prediction.duration > 0 else { return nil }
        guard let cueFrames = recorder.framesByBallName[ShotInput.cueBallName],
              cueFrames.count >= 1 else { return nil }
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: surfaceY + AngleSceneCalculator.ballRadius)
        let frames = cueFrames.sorted { $0.time < $1.time }
        let dt: Float = 0.01
        /// 滑动段弧线偏差上界系数：偏差 ≤ a⊥·T²/8，a⊥ ≤ μ_slide·g ~ 2–3 m/s²，取 a=10 保守 ⇒ 10/8。
        let slidingSlackCoeff: Float = 10.0 / 8.0
        var bestDist = Float.greatestFiniteMagnitude
        var bestTime: Float = 0
        var bestSpeed: Float = 0

        func sample(_ t: Float) {
            guard let st = playback.stateAt(ballName: ShotInput.cueBallName, time: t) else { return }
            let dx = st.position.x - p.x, dz = st.position.z - p.z
            let d = sqrtf(dx * dx + dz * dz)
            if d < bestDist {
                bestDist = d
                bestTime = t
                bestSpeed = sqrtf(st.velocity.x * st.velocity.x + st.velocity.z * st.velocity.z)
            }
        }

        sample(frames[0].time)
        for i in 0..<(frames.count - 1) {
            let a = frames[i], b = frames[i + 1]
            let span = b.time - a.time
            guard span > 1e-6 else { sample(b.time); continue }
            let chord = ShotPredictor.segmentPointDistanceXZ(a: a.position, b: b.position, p: p)
            // 段内路径到弦的最大偏差：滑动段为抛物线上界；滚动/旋转/静止段解析演进沿直线 ⇒ 0。
            let slack: Float = (a.state == .sliding) ? slidingSlackCoeff * span * span : 0
            let lowerBound = chord - slack
            // 剪枝：段内不可能比「当前最优」与「容差」都更近 ⇒ 跳过（不影响 bestDist<tol 判定与最优点）。
            if lowerBound >= min(bestDist, tol) { sample(b.time); continue }
            var t = a.time
            while t < b.time {
                sample(t)
                t += dt
            }
            sample(b.time)
        }
        guard bestDist < tol, bestSpeed > minSpeed else { return nil }

        // 到 P 前母球吃库数：时间 < bestTime 的母球 ballCushion 事件。
        var cushionsBeforeP = 0
        for e in c.prediction.events where e.time < bestTime {
            if case let .ballCushion(ball) = e.kind, ball == ShotInput.cueBallName {
                cushionsBeforeP += 1
            }
        }
        // 过 P 后母球碰到的第一颗球：时间 > bestTime 的首个含母球的 ballBall。
        var firstBallName: String?
        for e in c.prediction.events where e.time > bestTime {
            if case let .ballBall(a, b) = e.kind {
                if a == ShotInput.cueBallName { firstBallName = b; break }
                if b == ShotInput.cueBallName { firstBallName = a; break }
            }
        }
        var nearest: Float?
        if let name = firstBallName,
           let ob = obstacles.first(where: { $0.name == name }) {
            nearest = pockets.map { AngleSceneCalculator.horizontalDistance(ob.position, $0) }.min()
        }
        return PassResult(cushionsBeforeP: cushionsBeforeP, firstBallNearestPocket: nearest)
    }

    /// 快速格的过点裁决。`.ambiguous` = 本层无法下「未过点」结论（母球在撞球/截断处路径中止，
    /// 级联/继续滚动仍可能过 P），须回退引擎——**宁可多跑一次引擎，不可漏解**。
    private enum FastPassOutcome {
        case pass(PassResult)
        case noPass
        case ambiguous
    }

    /// `passInfo` 的解析版（B3）：对 rollout 闭式路径段做同一套「弦距下界剪枝 + 段内 dt=0.01
    /// 局部加密」查询（段就是引擎的事件帧段，滑动段同一 aT²/8 曲率松弛），判定语义与引擎版一致。
    /// 快速格无碰前吃库（该档已回退引擎）⇒ 到 P 前吃库数 = 碰球后吃库时刻 < bestTime 的计数。
    private static func passInfoFast(
        _ o: AnalyticShotRollout.ShotOutcome, p: SCNVector3, minSpeed: Float,
        obstacles: [ObstacleBall], pockets: [SCNVector3], tol: Float
    ) -> FastPassOutcome {
        guard !o.cueSegments.isEmpty else { return .ambiguous }
        let dt: Float = 0.01
        let slidingSlackCoeff: Float = 10.0 / 8.0   // 与引擎版 passInfo 同一保守上界
        var bestDist = Float.greatestFiniteMagnitude
        var bestTime: Float = 0
        var bestSpeed: Float = 0

        for seg in o.cueSegments {
            func sample(_ dtLocal: Float) {
                let pos = seg.position(at: dtLocal)
                let dx = pos.x - p.x, dz = pos.z - p.z
                let d = sqrtf(dx * dx + dz * dz)
                if d < bestDist {
                    bestDist = d
                    bestTime = seg.t0 + dtLocal
                    let v = seg.velocity(at: dtLocal)
                    bestSpeed = sqrtf(v.x * v.x + v.z * v.z)
                }
            }
            let chord = ShotPredictor.segmentPointDistanceXZ(
                a: seg.position, b: seg.position(at: seg.duration), p: p)
            let slack: Float = (seg.state == .sliding)
                ? slidingSlackCoeff * seg.duration * seg.duration : 0
            if chord - slack >= min(bestDist, tol) {
                sample(0); sample(seg.duration); continue
            }
            var t: Float = 0
            while t < seg.duration {
                sample(t)
                t += dt
            }
            sample(seg.duration)
        }

        if bestDist < tol, bestSpeed > minSpeed {
            let cushionsBeforeP = o.cueCushionTimes.filter { $0 < bestTime }.count
            // 过 P 后母球碰到的第一颗球（引擎版扫 ballBall 事件的同语义）：
            // P 在母-目首碰之前 ⇒ 目标球；否则 ⇒ rollout 上报的首颗静止球（若在 P 之后）。
            var firstBallName: String?
            if let ct = o.contactTime, bestTime < ct {
                firstBallName = ShotInput.targetBallName
            } else if let hit = o.cueFirstBallHit, let ht = o.cueFirstBallHitTime, ht > bestTime {
                firstBallName = hit
            }
            var nearest: Float?
            if let name = firstBallName,
               let ob = obstacles.first(where: { $0.name == name }) {
                nearest = pockets.map { AngleSceneCalculator.horizontalDistance(ob.position, $0) }.min()
            }
            return .pass(PassResult(cushionsBeforeP: cushionsBeforeP, firstBallNearestPocket: nearest))
        }
        // 未过点：仅当母球路径**完整走到停稳/落袋**才可下结论；撞球中止或截断 ⇒ 歧义回退。
        if o.cueFirstBallHit != nil || !(o.cueRested || o.cuePocketed) { return .ambiguous }
        return .noPass
    }

    private static func makePassSolution(
        _ c: Candidate, cushion: Int, nearestPocket: Float, velocityRange: (Double, Double),
        setup: Setup
    ) -> PositionPlaySolution {
        let hasK = nearestPocket < .greatestFiniteMagnitude
        let kText: String
        if hasK {
            kText = "过点后 K 球距袋约 \(Int((nearestPocket * 100).rounded()))cm"
        } else {
            kText = "过点（过点后未再碰球）"
        }
        let d = difficulty(c, setup: setup)
        let diffText = difficultyText(tier: d.tier, score: d.score, cutAngleDeg: c.prediction.cutAngleDeg)
        let summary = "\(spinText(c.spinX, c.spinY)) · \(PowerDisplay.name(c.velocity)) \(String(format: "%.1f", c.velocity)) · \(cushionText(cushion)) · \(diffText) · \(kText)"
        return PositionPlaySolution(
            shot: c.shot, prediction: c.prediction, cushionCount: cushion,
            potted: c.potted, margin: nearestPocket, summary: summary,
            satisfiesConstraint: c.potted,
            difficultyScore: d.score, difficultyTier: d.tier
        )
    }

    // MARK: - Text helpers

    private static func spinText(_ x: Double, _ y: Double) -> String {
        let lim = Double(CuePhysics.miscueLimitFraction)
        let h = Int((x / lim * 100).rounded())
        let v = Int((y / lim * 100).rounded())
        if h == 0 && v == 0 { return "中心球" }
        var parts: [String] = []
        if v > 0 { parts.append("高杆") } else if v < 0 { parts.append("低杆") }
        if x > 0 { parts.append("左塞") } else if x < 0 { parts.append("右塞") }
        return parts.isEmpty ? "中心球" : parts.joined()
    }

    private static func cushionText(_ k: Int) -> String {
        k == 0 ? "不吃库" : "\(k) 库"
    }

    // MARK: - Snooker (做斯诺克 / 安全球反解)

    /// 做斯诺克搜索参数。瞄准是自由变量（无袋口可锚定），故按「可接触目标球的张角」采样瞄准方向，
    /// 叠加塞与力度网格，逐候选走 `simulateFree`（不做进袋瞄准求解）。安全球多为轻—中力，故力度上限取 5.0。
    struct SnookerParams {
        var spinXValues: [Double]
        var spinYValues: [Double]
        var velocityMin: Double
        var velocityMax: Double
        var velocityStep: Double
        /// 瞄准方向在「可接触目标球」张角 [−contactHalf, +contactHalf] 内的采样数（端点收缩到 0.92 防薄擦漏触）。
        var aimSamples: Int
        /// 走位复杂度预算（母球吃库上限）。nil = 不限。设值 = 优先 ≤上限解、无则兜底标「进阶」。
        var maxCushions: Int?

        static let standard = SnookerParams(
            spinXValues: [-0.3, 0, 0.3],
            spinYValues: [-0.4, -0.2, 0, 0.2, 0.4],
            velocityMin: 0.6, velocityMax: 5.0, velocityStep: 0.4,
            aimSamples: 21, maxCushions: nil
        )
    }

    /// 防守评分（V8）：从母球终位对**对方球组**逐球评估——挡死几颗 + 未挡死球对手进球难度。
    struct DefenseScore {
        /// 被完全挡死（完全斯诺克）的对方球数。
        let blockedCount: Int
        /// 需隐藏的对方球总数（击球后仍在台面的对方球）。
        let opponentCount: Int
        /// 最弱环（对手最容易打的那颗）难度 [0,1]：挡死记 1。maximin 防守目标——把它抬高。
        let minDifficulty: Double
        /// 所有对方球难度之和（次级偏好）。
        let sumDifficulty: Double
        /// 已挡死球的覆盖余量和（度，稳健度 tie-break：多挡几度更抗薄擦解开）。
        let coverageMarginSum: Float
        /// 是否完全斯诺克（对方球全部挡死）。
        var full: Bool { opponentCount > 0 && blockedCount == opponentCount }
    }

    /// 一个防守候选的评估结果。
    private struct SnookerScored {
        let shot: PlannedShot
        let prediction: ShotPrediction
        let cushion: Int          // 母球吃库数
        let defense: DefenseScore
        var full: Bool { defense.full }
    }

    /// 防守反解（安全球，V8 中八语义）。硬约束：①母球合法首触 `targetKey`（我方将击打的球）；
    /// ②母球不进袋；③母球真停稳。软目标：停稳后让**对方球组** `opponentKeys` 尽量不可见——
    /// 完全斯诺克（全部被某颗球挡死，`AngleSceneCalculator.defenseCoverage`）为最优；无完全解时
    /// 返回「高难度可行解」（对方球全部剩长台/大切角/无可行袋），标 `satisfiesConstraint == false`。
    /// 排序：挡死球多优先 → 最弱环难度大优先 → 难度和大优先 → 覆盖余量大 → 执行难度小 → 力度小。
    /// 无任何合法停稳解时诚实返回空。
    static func solveSnooker(
        before: BoardSnapshot, targetKey: String, opponentKeys: [String],
        surfaceY: Float, params: SnookerParams = .standard
    ) -> [PositionPlaySolution] {
        guard let cuePt = before.onTable[PositionPlayBall.cueKey],
              let targetPt = before.onTable[targetKey],
              !PositionPlayBall.isCue(targetKey),
              !opponentKeys.isEmpty,
              !opponentKeys.contains(targetKey),
              opponentKeys.allSatisfy({ before.onTable[$0] != nil && !PositionPlayBall.isCue($0) })
        else { return [] }

        let cue = scenePoint(cuePt, surfaceY: surfaceY)
        let target = scenePoint(targetPt, surfaceY: surfaceY)
        // 所有非母球作真实碰撞体（含目标球与对方球），按 board key 命名（与 `predName` 自由球分支一致）。
        let balls: [ObstacleBall] = before.onTable.compactMap { key, pt in
            guard key != PositionPlayBall.cueKey else { return nil }
            return ObstacleBall(name: key, position: scenePoint(pt, surfaceY: surfaceY))
        }
        // 初始终位查找表（快评路径：未被扰动的球终位 = 初位）。
        let initialPositions: [String: SCNVector3] = Dictionary(
            uniqueKeysWithValues: balls.map { ($0.name, $0.position) })

        // 瞄准基方向（母球→目标球）与「球心扫过目标球」的可接触张角半角。
        let dx = target.x - cue.x, dz = target.z - cue.z
        let dCT = sqrtf(dx * dx + dz * dz)
        guard dCT > 2 * AngleSceneCalculator.ballRadius else { return [] }
        let baseAngle = atan2f(dz, dx)
        let contactHalf = asinf(min(0.999, 2 * AngleSceneCalculator.ballRadius / dCT))

        let combos = spinCombos(xValues: params.spinXValues, yValues: params.spinYValues)
        let velocities = snookerVelocities(min: params.velocityMin, max: params.velocityMax, step: params.velocityStep)
        let aimOffsets = snookerAimOffsets(count: params.aimSamples, halfRange: contactHalf)
        guard !combos.isEmpty, !velocities.isEmpty, !aimOffsets.isEmpty else { return [] }

        // 展平候选 [aim][combo][vel] 并行评估（simulateFree 各自建引擎，无共享态）。
        struct Cand { let off: Double; let sx: Double; let sy: Double; let v: Double }
        var cands: [Cand] = []
        cands.reserveCapacity(aimOffsets.count * combos.count * velocities.count)
        for off in aimOffsets {
            for (sx, sy) in combos {
                for v in velocities { cands.append(Cand(off: off, sx: sx, sy: sy, v: v)) }
            }
        }

        // —— 扫描（B4）：自由球单球 rollout 快评为主，级联/kiss/截断格就地回退引擎
        // （scoring-only + 早停，B1 语义保留）。空杆/首触非目标/进袋等必败候选由快评直接下结论。——
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: surfaceY)
        let interest: Set<String> = Set([ShotInput.cueBallName, targetKey] + opponentKeys)

        /// 一个扫描格（快评结论或引擎回退候选）。约束量口径对齐 `evaluateSnooker`；
        /// 任何被选为代表的格子都会经 `settle` 引擎全保真复核——扫描加速，上屏判定不降级。
        struct SnookerCell {
            let off: Double; let sx: Double; let sy: Double; let v: Double
            let cushion: Int
            let defense: DefenseScore
            var full: Bool { defense.full }
        }

        let comboCount = combos.count
        let velCount = velocities.count
        func cellIndex(aim: Int, combo: Int, vel: Int) -> Int {
            (aim * comboCount + combo) * velCount + vel
        }

        /// 引擎回退评估一格（scoring-only + 早停）。nil = 硬约束不满足（必败格）。
        func engineCell(_ i: Int) -> SnookerCell? {
            let c = cands[i]
            let ang = baseAngle + Float(c.off)
            let aimDir = SCNVector3(cosf(ang), 0, sinf(ang))
            let pred = ShotPredictor.simulateFree(
                cueBall: cue, aimDir: aimDir, velocity: Float(c.v),
                spinX: Float(c.sx), spinY: Float(c.sy), surfaceY: surfaceY, balls: balls,
                includePresentation: false, earlyStopBallNames: interest)
            guard let s = evaluateSnooker(pred, targetKey: targetKey, opponentKeys: opponentKeys,
                                          spinX: c.sx, spinY: c.sy, velocity: c.v,
                                          surfaceY: surfaceY) else { return nil }
            return SnookerCell(off: c.off, sx: c.sx, sy: c.sy, v: c.v,
                               cushion: s.cushion, defense: s.defense)
        }

        // —— 阶段 1：全网格 rollout 快评（并行）。结论确定的格子（合法/必败）就地落地；
        // 级联/kiss/截断 = 歧义格，只标记不模拟（交给粗细两阶段）。——
        var cellsOpt = [SnookerCell?](repeating: nil, count: cands.count)
        var ambiguous = [Bool](repeating: false, count: cands.count)
        PerformanceProfiler.begin(ProfilerLabel.solverCandidateEval)
        cellsOpt.withUnsafeMutableBufferPointer { buf in
            ambiguous.withUnsafeMutableBufferPointer { ambBuf in
                let base = buf.baseAddress!
                let amb = ambBuf.baseAddress!
                DispatchQueue.concurrentPerform(iterations: cands.count) { i in
                    let c = cands[i]
                    let ang = baseAngle + Float(c.off)
                    let aimDir = SCNVector3(cosf(ang), 0, sinf(ang))
                    let fast = AnalyticShotRollout.evaluateFreeShot(
                        cueBall: cue, aimDir: aimDir, velocity: Float(c.v),
                        spinX: Float(c.sx), spinY: Float(c.sy), surfaceY: surfaceY,
                        balls: balls, geometry: geometry)
                    if fast.needsFullSim {
                        (amb + i).pointee = true
                        return
                    }
                    // 快评硬约束（与 evaluateSnooker 同序同语义）：母球不进袋 + 真停稳 + 首触必须是目标球。
                    // 无级联（否则已 needsFullSim）⇒ 除目标球外所有球终位 = 初始位；目标球终位 = firstHitFinalPos。
                    guard !fast.cuePocketed, fast.cueRested,
                          fast.firstBallHit == targetKey,
                          let finalC = fast.cueFinalPos else { return }
                    var finalPositions = initialPositions
                    if fast.firstHitPocketed {
                        finalPositions[targetKey] = nil
                    } else if let ft = fast.firstHitFinalPos {
                        finalPositions[targetKey] = ft
                    }
                    let defense = defenseScore(cueFinal: finalC, opponentKeys: opponentKeys,
                                               finalPositions: finalPositions, surfaceY: surfaceY)
                    (base + i).pointee = SnookerCell(off: c.off, sx: c.sx, sy: c.sy, v: c.v,
                                                     cushion: fast.cueCushionCount, defense: defense)
                }
            }
        }

        // —— 阶段 2（粗）：歧义格按 (aim 步 3 × vel 步 2 × 全塞) 粗网格引擎评估（方案 B4
        // 「粗力度找可行邻域」）。级联解（母/目标球二次撞对方球后的停位）只能引擎裁决。——
        var coarseIdx: [Int] = []
        for a in stride(from: 0, to: aimOffsets.count, by: 3) {
            for ci in 0..<comboCount {
                for v in stride(from: 0, to: velCount, by: 2) {
                    let i = cellIndex(aim: a, combo: ci, vel: v)
                    if ambiguous[i] { coarseIdx.append(i) }
                }
            }
        }
        cellsOpt.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: coarseIdx.count) { k in
                let i = coarseIdx[k]
                (base + i).pointee = engineCell(i)
            }
        }

        // —— 阶段 3（细）：只对「可行粗格」的邻域（aim ±2 × vel ±1，同塞行）内尚未评估的
        // 歧义格加密至全分辨率——必败区域整片跳过。窄可行带漏检风险由金标准回归护栏。——
        var refineSet = Set<Int>()
        for i in coarseIdx where cellsOpt[i] != nil {
            let a = i / (comboCount * velCount)
            let rem = i % (comboCount * velCount)
            let ci = rem / velCount
            let v = rem % velCount
            for da in -2...2 {
                for dv in -1...1 {
                    let na = a + da, nv = v + dv
                    guard na >= 0, na < aimOffsets.count, nv >= 0, nv < velCount else { continue }
                    let ni = cellIndex(aim: na, combo: ci, vel: nv)
                    if ambiguous[ni], cellsOpt[ni] == nil { refineSet.insert(ni) }
                }
            }
        }
        let refineIdx = refineSet.sorted()
        cellsOpt.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: refineIdx.count) { k in
                let i = refineIdx[k]
                (base + i).pointee = engineCell(i)
            }
        }
        PerformanceProfiler.end(ProfilerLabel.solverCandidateEval)

        let cells = cellsOpt.compactMap { $0 }
        guard !cells.isEmpty else { return [] }

        /// 防守优劣：挡死球多优先 → 最弱环难度大 → 难度和大 → 覆盖余量大 → 执行难度小 → 力度小 → 瞄准偏移小。
        func betterDefense(_ a: DefenseScore, _ ea: (sx: Double, sy: Double, v: Double, off: Double),
                           _ b: DefenseScore, _ eb: (sx: Double, sy: Double, v: Double, off: Double)) -> Bool {
            if a.blockedCount != b.blockedCount { return a.blockedCount > b.blockedCount }
            if abs(a.minDifficulty - b.minDifficulty) > 1e-6 { return a.minDifficulty > b.minDifficulty }
            if abs(a.sumDifficulty - b.sumDifficulty) > 1e-6 { return a.sumDifficulty > b.sumDifficulty }
            if abs(a.coverageMarginSum - b.coverageMarginSum) > 1e-4 { return a.coverageMarginSum > b.coverageMarginSum }
            let s0 = DifficultyModel.executionEffort(spinX: ea.sx, spinY: ea.sy, velocity: ea.v)
            let s1 = DifficultyModel.executionEffort(spinX: eb.sx, spinY: eb.sy, velocity: eb.v)
            if abs(s0 - s1) > 1e-9 { return s0 < s1 }
            if ea.v != eb.v { return ea.v < eb.v }
            return abs(ea.off) < abs(eb.off)
        }
        func betterCell(_ a: SnookerCell, _ b: SnookerCell) -> Bool {
            betterDefense(a.defense, (a.sx, a.sy, a.v, a.off), b.defense, (b.sx, b.sy, b.v, b.off))
        }

        /// 代表格落地：引擎**全保真**重建 + 复核（硬约束/防守/吃库桶以引擎为准），
        /// 不符自动试备选——快评只加速搜索，上屏数值全部引擎口径（比基线多一道复核）。
        func settle(_ list: [SnookerCell], requireFull: Bool, keepBucket: Bool) -> SnookerScored? {
            for cell in list {
                let ang = baseAngle + Float(cell.off)
                let aimDir = SCNVector3(cosf(ang), 0, sinf(ang))
                let pred = ShotPredictor.simulateFree(
                    cueBall: cue, aimDir: aimDir, velocity: Float(cell.v),
                    spinX: Float(cell.sx), spinY: Float(cell.sy), surfaceY: surfaceY, balls: balls)
                guard let s = evaluateSnooker(pred, targetKey: targetKey, opponentKeys: opponentKeys,
                                              spinX: cell.sx, spinY: cell.sy, velocity: cell.v,
                                              surfaceY: surfaceY) else { continue }
                if requireFull && !s.full { continue }
                if keepBucket && s.cushion != cell.cushion { continue }
                return s
            }
            return nil
        }

        // 完全斯诺克解：每桶按防守优劣保留前 3 备选，代表经引擎复核落地。
        var buckets: [Int: [SnookerCell]] = [:]
        for cell in cells where cell.full {
            var list = buckets[cell.cushion] ?? []
            list.append(cell)
            list.sort(by: betterCell)
            if list.count > 3 { list.removeLast(list.count - 3) }
            buckets[cell.cushion] = list
        }
        if !buckets.isEmpty {
            var settled: [SnookerScored] = []
            for key in buckets.keys.sorted() {
                if let s = settle(buckets[key]!, requireFull: true, keepBucket: true),
                   !settled.contains(where: { $0.cushion == s.cushion }) {
                    settled.append(s)
                }
            }
            let ordered = settled.sorted {
                if $0.cushion != $1.cushion { return $0.cushion < $1.cushion }
                return betterDefense($0.defense, ($0.shot.spinX, $0.shot.spinY, $0.shot.velocity, 0),
                                     $1.defense, ($1.shot.spinX, $1.shot.spinY, $1.shot.velocity, 0))
            }
            if !ordered.isEmpty {
                return applyCushionBudget(ordered.map { makeSnookerSolution($0) },
                                          maxCushions: params.maxCushions)
            }
        }

        // 降级：无完全斯诺克——返回防守最优的「高难度可行解」（最多 3 个不同代表），标未完全。
        // 引擎复核失败依次试更次优（最多 12 个），全败则如实返回空。
        let closest = cells.sorted(by: betterCell)
        var partials: [SnookerScored] = []
        var used = Set<String>()
        for cell in closest.prefix(12) {
            guard partials.count < 3 else { break }
            guard let s = settle([cell], requireFull: false, keepBucket: false) else { continue }
            let key = "\(s.cushion)|\(Int((s.defense.minDifficulty * 100).rounded()))|\(s.defense.blockedCount)"
            if used.contains(key) { continue }
            used.insert(key)
            partials.append(s)
        }
        if !partials.isEmpty {
            let ordered = partials.sorted {
                betterDefense($0.defense, ($0.shot.spinX, $0.shot.spinY, $0.shot.velocity, 0),
                              $1.defense, ($1.shot.spinX, $1.shot.spinY, $1.shot.velocity, 0))
            }
            return ordered.map { makeSnookerSolution($0) }
        }
        return []
    }

    /// 从母球终位 + 全部非母球终位（已剔除进袋球）计算防守评分。对方球若已进袋则不计入。
    private static func defenseScore(
        cueFinal: SCNVector3, opponentKeys: [String],
        finalPositions: [String: SCNVector3], surfaceY: Float
    ) -> DefenseScore {
        let opponents: [(key: String, pos: SCNVector3)] = opponentKeys.compactMap { key in
            guard let p = finalPositions[key] else { return nil }
            return (key, p)
        }
        guard !opponents.isEmpty else {
            return DefenseScore(blockedCount: 0, opponentCount: 0,
                                minDifficulty: 0, sumDifficulty: 0, coverageMarginSum: 0)
        }
        let nonCue: [(key: String, pos: SCNVector3)] = finalPositions.map { ($0.key, $0.value) }
        let cov = AngleSceneCalculator.defenseCoverage(
            cueFinal: cueFinal, opponents: opponents, nonCueBalls: nonCue, surfaceY: surfaceY)
        let blocked = cov.filter { $0.blocked }
        let diffs = cov.map { $0.blocked ? 1.0 : $0.pottingDifficulty }
        return DefenseScore(
            blockedCount: blocked.count, opponentCount: opponents.count,
            minDifficulty: diffs.min() ?? 0, sumDifficulty: diffs.reduce(0, +),
            coverageMarginSum: blocked.reduce(0) { $0 + $1.coverageMarginDeg })
    }

    /// 评估一个防守候选；不满足首触/进袋/真停硬约束 ⇒ nil。
    private static func evaluateSnooker(
        _ pred: ShotPrediction, targetKey: String, opponentKeys: [String],
        spinX: Double, spinY: Double, velocity: Double, surfaceY: Float
    ) -> SnookerScored? {
        // 母球不进袋 + 真停稳。
        guard !pred.cuePocketed, pred.cueFinalSpeed < restSpeedTolerance else { return nil }
        // 合法首触：母球第一次球-球碰撞的另一方必须是目标球。
        var firstOther: String?
        for e in pred.events {
            if case let .ballBall(a, b) = e.kind {
                if a == ShotInput.cueBallName { firstOther = b; break }
                if b == ShotInput.cueBallName { firstOther = a; break }
            }
        }
        guard firstOther == targetKey else { return nil }
        guard let finalC = pred.finalPositions[ShotInput.cueBallName] else { return nil }

        // 全部非母球终位（剔除进袋球），供多球防守评估。
        let potted = Set(pred.pocketedBalls)
        var finalPositions: [String: SCNVector3] = [:]
        for (name, pos) in pred.finalPositions where name != ShotInput.cueBallName && !potted.contains(name) {
            finalPositions[name] = pos
        }
        let defense = defenseScore(cueFinal: finalC, opponentKeys: opponentKeys,
                                   finalPositions: finalPositions, surfaceY: surfaceY)
        let cushion = pred.events.reduce(0) { acc, e in
            if case let .ballCushion(ball) = e.kind, ball == ShotInput.cueBallName { return acc + 1 }
            return acc
        }
        let shot = PlannedShot(
            targetKey: targetKey, pocket: "", velocity: velocity, spinX: spinX, spinY: spinY,
            freeAim: canvasDirection(fromScene: pred.aimDirection))
        return SnookerScored(shot: shot, prediction: pred, cushion: cushion, defense: defense)
    }

    private static func makeSnookerSolution(_ s: SnookerScored) -> PositionPlaySolution {
        let cushionTxt = cushionText(s.cushion)
        let spin = spinText(s.shot.spinX, s.shot.spinY)
        let power = "\(PowerDisplay.name(s.shot.velocity)) \(String(format: "%.1f", s.shot.velocity))"
        let d = s.defense
        let covTxt: String
        if d.full {
            let avgMargin = d.opponentCount > 0 ? Int((d.coverageMarginSum / Float(d.opponentCount)).rounded()) : 0
            covTxt = "完全斯诺克 · 对方 \(d.opponentCount) 球全挡死 · 均余量约 \(avgMargin)°"
        } else {
            let pct = Int((d.minDifficulty * 100).rounded())
            covTxt = "高难度可行解 · 挡死 \(d.blockedCount)/\(d.opponentCount) · 对手最易球难度约 \(pct)%"
        }
        // 防守无进球语义 ⇒ 切角/球距不参与执行评分（E4 输入传 nil）。
        let score = DifficultyModel.score(
            spinX: s.shot.spinX, spinY: s.shot.spinY, velocity: s.shot.velocity)
        let tier = DifficultyModel.tier(spinX: s.shot.spinX, spinY: s.shot.spinY)
        let diffText = difficultyText(tier: tier, score: score, cutAngleDeg: nil)
        let summary = "\(spin) · \(power) · \(cushionTxt) · \(diffText) · \(covTxt)"
        return PositionPlaySolution(
            shot: s.shot, prediction: s.prediction, cushionCount: s.cushion,
            potted: false, margin: Float(d.minDifficulty), summary: summary,
            satisfiesConstraint: d.full,
            difficultyScore: score, difficultyTier: tier)
    }

    /// 力度等差采样（含上界）。
    private static func snookerVelocities(min: Double, max: Double, step: Double) -> [Double] {
        var v = min
        var out: [Double] = []
        while v <= max + 1e-9 { out.append(v); v += step }
        return out
    }

    /// 瞄准偏移采样：在 [−halfRange, +halfRange] 内均匀取 `count` 个值，端点收缩到 0.92×
    /// （避免恰在接触边界的薄擦漏触/数值不稳），含 0（正瞄目标球心）。
    private static func snookerAimOffsets(count: Int, halfRange: Float) -> [Double] {
        guard count >= 1, halfRange > 1e-5 else { return [0] }
        let span = Double(halfRange) * 0.92
        if count == 1 { return [0] }
        var out: [Double] = []
        for i in 0..<count {
            let t = Double(i) / Double(count - 1) * 2 - 1   // [-1, 1]
            out.append(t * span)
        }
        return out
    }

    // MARK: - Coordinate bridging

    static func scenePoint(_ pt: CanvasPoint, surfaceY: Float) -> SCNVector3 {
        AngleSceneCalculator.normalizedToScene(point: CGPoint(x: pt.x, y: pt.y), surfaceY: surfaceY)
    }

    /// 场景 XZ 方向 → 归一化系单位方向（与 `PositionPlayShotSolver.canvasDirection` 同口径，自由球瞄准存储用）。
    private static func canvasDirection(fromScene dir: SCNVector3) -> CanvasPoint {
        let len = sqrtf(dir.x * dir.x + dir.z * dir.z)
        guard len > 1e-9 else { return CanvasPoint(x: 1, y: 0) }
        return CanvasPoint(x: Double(dir.x / len), y: Double(dir.z / len))
    }
}
