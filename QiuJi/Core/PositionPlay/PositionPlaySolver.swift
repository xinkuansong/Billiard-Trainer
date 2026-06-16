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

        /// 情形 A 局部精修：在粗网格代表解附近做**拓扑锁定的模式搜索**抛光停点。
        /// 粗网格只定位 basin，精修在同一吃库拓扑的连续 (spinX,spinY,velocity) 邻域里把停点推向落区/落点
        /// （治「basin 找对、采样太粗」；治不了「basin 整个被跳过」——后者靠加密 spinX，非本机制）。
        var refineEnabled: Bool = true
        /// 精修初始步长（spin = 接触点偏移/R；vel = m/s），约半个网格步。
        var refineSpinStep: Double = 0.15
        var refineVelStep: Double = 0.15
        /// 精修终止步长（spin/vel 共用）与最大迭代轮数。
        var refineMinStep: Double = 0.02
        var refineMaxIters: Int = 12

        /// 走位复杂度预算（吃库数上限）。nil = 不限（默认，原行为）；设值（如 1）= 「仅基础走位」——
        /// **优先**返回吃库 ≤ 此值的解，**仅当其为空**才回退展示超预算解并标 `beyondCushionBudget`
        /// （用户拍板「优先+兜底」，绝不因预算给出「无解」）。
        var maxCushions: Int? = nil

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
        switch constraint {
        case let .restRegion(region):
            let p = params ?? .standard
            return applyCushionBudget(
                solveRestRegion(setup: setup, targetKey: targetKey, pocket: pocket,
                                region: region, params: p),
                maxCushions: p.maxCushions)
        case let .passThrough(point, vMin):
            let p = params ?? .passThrough
            return applyCushionBudget(
                solvePassThrough(setup: setup, targetKey: targetKey, pocket: pocket,
                                 point: point, vMin: vMin, params: p),
                maxCushions: p.maxCushions)
        }
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
    private static func evaluate(
        setup: Setup, targetKey: String, pocket: String,
        spinX: Double, spinY: Double, velocity: Double, aimOffset: Float?
    ) -> Candidate {
        let input = ShotInput(
            cueBall: setup.cue, targetBall: setup.target, pocketIndex: setup.pocketIndex,
            velocity: Float(velocity), spinX: Float(spinX), spinY: Float(spinY),
            surfaceY: setup.surfaceY, obstacles: setup.obstacles
        )
        var pred = ShotPredictor.predictForPositionSolve(input, aimOffset: aimOffset)
        if aimOffset != nil, pred.feasible, !pred.objectPocketed {
            let reSolved = ShotPredictor.predictForPositionSolve(input, aimOffset: nil)
            if reSolved.objectPocketed { pred = reSolved }
        }
        let shot = PlannedShot(targetKey: targetKey, pocket: pocket,
                               velocity: velocity, spinX: spinX, spinY: spinY)
        return Candidate(spinX: spinX, spinY: spinY, velocity: velocity, shot: shot, prediction: pred)
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

    /// 候选矩阵 `[comboIdx][velIdx]`，全并行。两段并行：
    /// ① 瞄准记忆化——对每个唯一 `(spinX, velocity)` 只解一次轻量瞄准（squirt 仅随 spinX）；
    /// ② 按记忆化 aim 并行跑全部 `(spinX, spinY, velocity)` 候选。
    /// 空 = 几何不可进袋（无任何可进解）。各迭代写互不相交下标，`withUnsafeMutableBufferPointer` 并发安全。
    private static func candidateMatrix(
        setup: Setup, targetKey: String, pocket: String,
        combos: [(Double, Double)], velocities: [Double]
    ) -> [[Candidate]] {
        guard !combos.isEmpty, !velocities.isEmpty, let ctx = aimContext(setup) else { return [] }
        let velCount = velocities.count

        // ① 记忆化瞄准：唯一 spinX × velocity。
        let uniqueSpinX = Array(Set(combos.map { $0.0 })).sorted()
        let sxIndex = Dictionary(uniqueKeysWithValues: uniqueSpinX.enumerated().map { ($1, $0) })
        var aimKeys: [(Double, Double)] = []
        for sx in uniqueSpinX { for v in velocities { aimKeys.append((sx, v)) } }
        var offsets = [Float](repeating: 0, count: aimKeys.count)
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

        // ② 全候选并行预测（复用记忆化 aim）。
        let total = combos.count * velCount
        var flat = [Candidate?](repeating: nil, count: total)
        flat.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: total) { idx in
                let ci = idx / velCount, vi = idx % velCount
                let (sx, sy) = combos[ci]
                let aim = offsets[sxIndex[sx]! * velCount + vi]
                (base + idx).pointee = evaluate(
                    setup: setup, targetKey: targetKey, pocket: pocket,
                    spinX: sx, spinY: sy, velocity: velocities[vi], aimOffset: aim)
            }
        }

        var matrix: [[Candidate]] = []
        matrix.reserveCapacity(combos.count)
        for ci in 0..<combos.count {
            matrix.append((0..<velCount).compactMap { flat[ci * velCount + $0] })
        }
        return matrix
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

    private static func solveRestRegion(
        setup: Setup, targetKey: String, pocket: String,
        region: SolveRegion, params: SearchParams
    ) -> [PositionPlaySolution] {
        let combos = spinCombos(xValues: params.spinXValues, yValues: params.spinYValues)
        let velocities = velocitySamples(params)
        let y = setup.surfaceY

        // 每个吃库桶（碰球后母球吃库数）的最佳合格解 + 全局最接近（降级用）。
        struct Scored {
            let candidate: Candidate
            let signed: Float        // 停点到落区有符号距离（区内为负）
            let cushion: Int         // 碰球后母球吃库数
        }
        var pottedScored: [Scored] = []

        let candidates = candidateMatrix(setup: setup, targetKey: targetKey, pocket: pocket,
                                         combos: combos, velocities: velocities).flatMap { $0 }

        for c in candidates {
            guard c.potted, cueRestedInPlace(c.prediction),
                  let stop = c.prediction.finalPositions[ShotInput.cueBallName] else { continue }
            let signed = region.signedDistanceMeters(fromScene: stop, surfaceY: y)
            let cushion = max(0, c.prediction.cueCushionCount - c.prediction.cueCushionsBeforeContact)
            pottedScored.append(Scored(candidate: c, signed: signed, cushion: cushion))
        }

        // 合格解：在区内（signed<=0）且余量(-signed) >= requiredMargin(cushion)。
        // 桶内选代表（用户拍板「越少加塞越好」）：在「够稳」的候选里**优先加塞最少**，
        // 同塞再取扎入更深者。这样每个库桶展示的是该库数下最朴素的解。
        func requiredMargin(_ k: Int) -> Float { params.marginBase + Float(k) * params.marginPerCushion }
        func preferLessSpin(_ a: Scored, than b: Scored) -> Bool {
            let sa = spinMagnitude(a.candidate), sb = spinMagnitude(b.candidate)
            if abs(sa - sb) > 1e-9 { return sa < sb }
            return a.signed < b.signed
        }
        var bestPerBucket: [Int: Scored] = [:]
        for s in pottedScored where s.signed <= 0 && (-s.signed) >= requiredMargin(s.cushion) {
            if let cur = bestPerBucket[s.cushion] {
                if preferLessSpin(s, than: cur) { bestPerBucket[s.cushion] = s }
            } else {
                bestPerBucket[s.cushion] = s
            }
        }

        // 把精修后的候选重新打分为 Scored（拓扑被精修锁定，cushion 不变；精修失效则回退种子）。
        func rescore(_ c: Candidate, fallback: Scored) -> Scored {
            guard c.potted, cueRestedInPlace(c.prediction),
                  let stop = c.prediction.finalPositions[ShotInput.cueBallName] else { return fallback }
            let signed = region.signedDistanceMeters(fromScene: stop, surfaceY: y)
            let cushion = max(0, c.prediction.cueCushionCount - c.prediction.cueCushionsBeforeContact)
            return Scored(candidate: c, signed: signed, cushion: cushion)
        }
        func refined(_ s: Scored) -> Scored {
            let r = refineCandidate(seed: s.candidate, seedCushion: s.cushion, setup: setup,
                                    targetKey: targetKey, pocket: pocket, region: region, params: params)
            return rescore(r, fallback: s)
        }

        if region.isPoint {
            // 落点：最小化到点距离。对所有可进解按吃库桶取「最近代表」（不要求命中也返回），
            // 精修后库少 → 更近排序；容差内（signed<=0）才标满足约束。
            var closestPerBucket: [Int: Scored] = [:]
            for s in pottedScored {
                if let cur = closestPerBucket[s.cushion] {
                    if s.signed < cur.signed { closestPerBucket[s.cushion] = s }
                } else { closestPerBucket[s.cushion] = s }
            }
            if !closestPerBucket.isEmpty {
                let ordered = closestPerBucket.values.map(refined).sorted {
                    if $0.cushion != $1.cushion { return $0.cushion < $1.cushion }
                    return $0.signed < $1.signed
                }
                return ordered.map { makeRegionSolution($0.candidate, signed: $0.signed, cushion: $0.cushion,
                                                         satisfied: $0.signed <= 0, region: region) }
            }
        } else {
            if !bestPerBucket.isEmpty {
                // 每桶代表解局部精修（停点推向落区更深处，拓扑锁定不跨库），再排序。
                let polished = bestPerBucket.values.map(refined)
                // 排序：库少优先 → 加塞少优先 → 扎入更深（更鲁棒）。
                let ordered = polished.sorted {
                    if $0.cushion != $1.cushion { return $0.cushion < $1.cushion }
                    let s0 = spinMagnitude($0.candidate), s1 = spinMagnitude($1.candidate)
                    if abs(s0 - s1) > 1e-9 { return s0 < s1 }
                    return $0.signed < $1.signed
                }
                return ordered.map { makeRegionSolution($0.candidate, signed: $0.signed, cushion: $0.cushion,
                                                         satisfied: true, region: region) }
            }
            // 降级：无合格解。取「能进球」的最接近解精修——精修后可能反升级为满足约束。
            if let closest = pottedScored.min(by: { $0.signed < $1.signed }) {
                let r = refined(closest)
                let satisfied = r.signed <= 0 && (-r.signed) >= requiredMargin(r.cushion)
                return [makeRegionSolution(r.candidate, signed: r.signed, cushion: r.cushion,
                                           satisfied: satisfied, region: region)]
            }
        }
        // 连进球解都没有：取「能进球与否不论」里停点最接近落区者，标注未进袋（复用已算候选）。
        var fallback: Scored?
        for c in candidates {
            guard c.prediction.feasible, cueRestedInPlace(c.prediction),
                  let stop = c.prediction.finalPositions[ShotInput.cueBallName] else { continue }
            let signed = region.signedDistanceMeters(fromScene: stop, surfaceY: y)
            let cushion = max(0, c.prediction.cueCushionCount - c.prediction.cueCushionsBeforeContact)
            if fallback == nil || signed < fallback!.signed {
                fallback = Scored(candidate: c, signed: signed, cushion: cushion)
            }
        }
        if let f = fallback {
            return [makeRegionSolution(f.candidate, signed: f.signed, cushion: f.cushion,
                                       satisfied: false, region: region)]
        }
        return []
    }

    /// 加塞幅值（接触点偏移/R 的模）。用于「越少加塞越好」排序。
    private static func spinMagnitude(_ c: Candidate) -> Double {
        (c.spinX * c.spinX + c.spinY * c.spinY).squareRoot()
    }

    /// 情形 A 局部精修：拓扑锁定的模式搜索（Hooke-Jeeves 坐标式）。在种子解附近的连续
    /// `(spinX, spinY, velocity)` 邻域里最小化「停点有符号距离」objective，**只接受**「进袋 + 真停稳 +
    /// 碰球后吃库数与种子相同」的样本（其余记 +∞）——故永不跨越拓扑悬崖外推，只抛光已找到的 basin。
    /// 确定性（贪心 + 固定探测顺序），不破坏测试。每轮 6 邻居并行评估。
    private static func refineCandidate(
        seed: Candidate, seedCushion: Int,
        setup: Setup, targetKey: String, pocket: String,
        region: SolveRegion, params: SearchParams
    ) -> Candidate {
        guard params.refineEnabled else { return seed }
        let y = setup.surfaceY
        let limit = Double(CuePhysics.miscueLimitFraction)

        func objective(_ c: Candidate) -> Float {
            guard c.potted, cueRestedInPlace(c.prediction),
                  let stop = c.prediction.finalPositions[ShotInput.cueBallName] else {
                return .greatestFiniteMagnitude
            }
            let cushion = max(0, c.prediction.cueCushionCount - c.prediction.cueCushionsBeforeContact)
            guard cushion == seedCushion else { return .greatestFiniteMagnitude }  // 拓扑锁
            return region.signedDistanceMeters(fromScene: stop, surfaceY: y)
        }
        func legalSpin(_ x: Double, _ yv: Double) -> Bool {
            (x * x + yv * yv).squareRoot() <= limit + 1e-6
        }

        var best = seed
        var bestObj = objective(seed)
        guard bestObj < .greatestFiniteMagnitude else { return seed }  // 种子无效（不应发生）

        var spinStep = params.refineSpinStep
        var velStep = params.refineVelStep
        var iters = 0
        while iters < params.refineMaxIters && (spinStep > params.refineMinStep || velStep > params.refineMinStep) {
            iters += 1
            // 6 邻居：±spinX、±spinY、±velocity（越界/越打滑极限者剔除）。
            // **只精修网格实际搜过的轴**：若某塞轴被刻意塌缩为单值（如「禁左右塞」spinXValues=[0]），
            // 精修不得沿该轴探测，否则会把被禁的塞重新引回（违背用户约束）。
            var probes: [(Double, Double, Double)] = []
            if params.spinXValues.count > 1 {
                for dx in [-spinStep, spinStep] where legalSpin(best.spinX + dx, best.spinY) {
                    probes.append((best.spinX + dx, best.spinY, best.velocity))
                }
            }
            if params.spinYValues.count > 1 {
                for dy in [-spinStep, spinStep] where legalSpin(best.spinX, best.spinY + dy) {
                    probes.append((best.spinX, best.spinY + dy, best.velocity))
                }
            }
            for dv in [-velStep, velStep] {
                let v = min(max(best.velocity + dv, params.velocityMin), params.velocityMax)
                if abs(v - best.velocity) > 1e-9 { probes.append((best.spinX, best.spinY, v)) }
            }
            guard !probes.isEmpty else { break }

            var evaluated = [Candidate?](repeating: nil, count: probes.count)
            evaluated.withUnsafeMutableBufferPointer { buf in
                let base = buf.baseAddress!
                DispatchQueue.concurrentPerform(iterations: probes.count) { i in
                    let (sx, sy, v) = probes[i]
                    (base + i).pointee = evaluate(setup: setup, targetKey: targetKey, pocket: pocket,
                                                  spinX: sx, spinY: sy, velocity: v, aimOffset: nil)
                }
            }
            var movedObj = bestObj
            var movedTo: Candidate?
            for c in evaluated.compactMap({ $0 }) {
                let o = objective(c)
                if o < movedObj - 1e-6 { movedObj = o; movedTo = c }
            }
            if let m = movedTo {
                best = m; bestObj = movedObj   // 贪心移动，保持步长
            } else {
                spinStep /= 2; velStep /= 2     // 无改进 → 收缩步长
            }
        }
        return best
    }

    /// 母球是否真正「停在桌面某处」：未 scratch（进袋 = 无停点）且末速接近 0（≠ 截断假停）。
    /// 情形 A 的落区解只接受真实停点——杜绝「母球高速却被当作停在区域内」的反常解（用户反馈）。
    private static func cueRestedInPlace(_ p: ShotPrediction) -> Bool {
        !p.cuePocketed && p.cueFinalSpeed < restSpeedTolerance
    }

    private static func makeRegionSolution(
        _ c: Candidate, signed: Float, cushion: Int, satisfied: Bool, region: SolveRegion
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
        let summary = "\(spinText(c.spinX, c.spinY)) · \(PowerDisplay.name(c.velocity)) \(String(format: "%.1f", c.velocity)) · \(cushionText(cushion)) · \(constraintText)"
        return PositionPlaySolution(
            shot: c.shot, prediction: c.prediction, cushionCount: cushion,
            potted: c.potted, margin: margin, summary: summary,
            satisfiesConstraint: satisfied && c.potted && signed <= 0
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

        // 一次速度采样的通过信息。
        struct PassSample {
            let velocity: Double
            let cushionsBeforeP: Int
            /// 过 P 后母球碰到的第一颗球到最近袋口的距离（米）；nil = 过 P 后未再碰球。
            let firstBallNearestPocket: Float?
        }

        // 候选矩阵（aim 记忆化 + 全并行，热点已在此消化）；逐塞做速度分段为轻量后处理。
        let matrix = candidateMatrix(setup: setup, targetKey: targetKey, pocket: pocket,
                                     combos: combos, velocities: velocities)
        var solutions: [PositionPlaySolution] = []
        for (ci, combo) in combos.enumerated() where ci < matrix.count {
            let (sx, sy) = combo
            let row = matrix[ci]   // 与 velocities 同序同长
            var samples: [PassSample?] = []
            samples.reserveCapacity(row.count)
            for c in row {
                guard c.potted,
                      let pass = passInfo(c, p: p, minSpeed: minSpeed, surfaceY: setup.surfaceY,
                                          obstacles: setup.obstacles, pockets: pockets,
                                          tol: params.passTolerance) else {
                    samples.append(nil); continue
                }
                samples.append(PassSample(velocity: c.velocity,
                                          cushionsBeforeP: pass.cushionsBeforeP,
                                          firstBallNearestPocket: pass.firstBallNearestPocket))
            }
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
                    rep, cushion: s.cushionsBeforeP, nearestPocket: bestNearest,
                    velocityRange: (lo, hi)))
                i = j + 1
            }
        }

        // 排序：库少优先 → 「过 P 后第一颗球离袋距离」升序（K 球质量）→ 加塞少优先（用户拍板）。
        solutions.sort {
            if $0.cushionCount != $1.cushionCount { return $0.cushionCount < $1.cushionCount }
            if abs($0.margin - $1.margin) > 1e-4 { return $0.margin < $1.margin }
            let s0 = ($0.shot.spinX * $0.shot.spinX + $0.shot.spinY * $0.shot.spinY).squareRoot()
            let s1 = ($1.shot.spinX * $1.shot.spinX + $1.shot.spinY * $1.shot.spinY).squareRoot()
            return s0 < s1
        }
        return solutions
    }

    private struct PassResult {
        let cushionsBeforeP: Int
        let firstBallNearestPocket: Float?
    }

    /// 判定母球是否在 v>minSpeed 时经过 P；并统计到 P 前吃库数与过 P 后第一颗碰撞球离袋最近距离。
    private static func passInfo(
        _ c: Candidate, p: SCNVector3, minSpeed: Float, surfaceY: Float,
        obstacles: [ObstacleBall], pockets: [SCNVector3], tol: Float
    ) -> PassResult? {
        guard let recorder = c.prediction.recorder, c.prediction.duration > 0 else { return nil }
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: surfaceY + AngleSceneCalculator.ballRadius)
        let duration = c.prediction.duration
        let dt: Float = 0.01
        var t: Float = 0
        var bestDist = Float.greatestFiniteMagnitude
        var bestTime: Float = 0
        var bestSpeed: Float = 0
        while t <= duration {
            if let st = playback.stateAt(ballName: ShotInput.cueBallName, time: t) {
                let dx = st.position.x - p.x, dz = st.position.z - p.z
                let d = sqrtf(dx * dx + dz * dz)
                if d < bestDist {
                    bestDist = d
                    bestTime = t
                    bestSpeed = sqrtf(st.velocity.x * st.velocity.x + st.velocity.z * st.velocity.z)
                }
            }
            t += dt
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

    private static func makePassSolution(
        _ c: Candidate, cushion: Int, nearestPocket: Float, velocityRange: (Double, Double)
    ) -> PositionPlaySolution {
        let hasK = nearestPocket < .greatestFiniteMagnitude
        let kText: String
        if hasK {
            kText = "过点后 K 球距袋约 \(Int((nearestPocket * 100).rounded()))cm"
        } else {
            kText = "过点（过点后未再碰球）"
        }
        let summary = "\(spinText(c.spinX, c.spinY)) · \(PowerDisplay.name(c.velocity)) \(String(format: "%.1f", c.velocity)) · \(cushionText(cushion)) · \(kText)"
        return PositionPlaySolution(
            shot: c.shot, prediction: c.prediction, cushionCount: cushion,
            potted: c.potted, margin: nearestPocket, summary: summary,
            satisfiesConstraint: c.potted
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

    /// 一个做斯诺克候选的评估结果。
    private struct SnookerScored {
        let shot: PlannedShot
        let prediction: ShotPrediction
        let cushion: Int          // 母球吃库数
        let coverageDeg: Float    // 覆盖余量（度）：正 = 完全挡死且多挡 N°、负 = 露出 N°
        var full: Bool            // 是否完全斯诺克
    }

    /// 做斯诺克反解。硬约束：①母球合法首触 `targetKey`；②母球不进袋；③目标球不进袋；
    /// ④母球真停稳；⑤停稳后从母球看向目标球终位的视线被 `blockerKey` **完全挡死**
    /// （`AngleSceneCalculator.snookerCoverage`，用三球**终位**判定）。
    /// 排序：库少优先 → 覆盖余量大优先 → 加塞少优先 → 力度小优先。
    /// 无完全斯诺克解时返回覆盖余量最大的**降级解**（半斯诺克，`satisfiesConstraint == false`）。
    static func solveSnooker(
        before: BoardSnapshot, targetKey: String, blockerKey: String,
        surfaceY: Float, params: SnookerParams = .standard
    ) -> [PositionPlaySolution] {
        guard let cuePt = before.onTable[PositionPlayBall.cueKey],
              let targetPt = before.onTable[targetKey],
              before.onTable[blockerKey] != nil,
              targetKey != blockerKey, !PositionPlayBall.isCue(targetKey),
              !PositionPlayBall.isCue(blockerKey) else { return [] }

        let cue = scenePoint(cuePt, surfaceY: surfaceY)
        let target = scenePoint(targetPt, surfaceY: surfaceY)
        // 所有非母球作真实碰撞体（含目标球与障碍球），按 board key 命名（与 `predName` 自由球分支一致）。
        let balls: [ObstacleBall] = before.onTable.compactMap { key, pt in
            guard key != PositionPlayBall.cueKey else { return nil }
            return ObstacleBall(name: key, position: scenePoint(pt, surfaceY: surfaceY))
        }

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

        var scoredOpt = [SnookerScored?](repeating: nil, count: cands.count)
        scoredOpt.withUnsafeMutableBufferPointer { buf in
            let base = buf.baseAddress!
            DispatchQueue.concurrentPerform(iterations: cands.count) { i in
                let c = cands[i]
                let ang = baseAngle + Float(c.off)
                let aimDir = SCNVector3(cosf(ang), 0, sinf(ang))
                let pred = ShotPredictor.simulateFree(
                    cueBall: cue, aimDir: aimDir, velocity: Float(c.v),
                    spinX: Float(c.sx), spinY: Float(c.sy), surfaceY: surfaceY, balls: balls)
                (base + i).pointee = evaluateSnooker(
                    pred, targetKey: targetKey, blockerKey: blockerKey,
                    spinX: c.sx, spinY: c.sy, velocity: c.v)
            }
        }
        let scored = scoredOpt.compactMap { $0 }
        guard !scored.isEmpty else { return [] }

        // 完全斯诺克解：按吃库桶取覆盖余量最大代表。
        var bestPerBucket: [Int: SnookerScored] = [:]
        for s in scored where s.full {
            if let cur = bestPerBucket[s.cushion] {
                if s.coverageDeg > cur.coverageDeg { bestPerBucket[s.cushion] = s }
            } else { bestPerBucket[s.cushion] = s }
        }
        if !bestPerBucket.isEmpty {
            let ordered = bestPerBucket.values.sorted {
                if $0.cushion != $1.cushion { return $0.cushion < $1.cushion }
                if abs($0.coverageDeg - $1.coverageDeg) > 1e-4 { return $0.coverageDeg > $1.coverageDeg }
                let s0 = $0.shot.spinX * $0.shot.spinX + $0.shot.spinY * $0.shot.spinY
                let s1 = $1.shot.spinX * $1.shot.spinX + $1.shot.spinY * $1.shot.spinY
                if abs(s0 - s1) > 1e-9 { return s0 < s1 }
                return $0.shot.velocity < $1.shot.velocity
            }
            return applyCushionBudget(ordered.map(makeSnookerSolution), maxCushions: params.maxCushions)
        }

        // 降级：无完全斯诺克——返回覆盖余量最大（最接近挡死）的单个解，标半斯诺克。
        if let closest = scored.max(by: { $0.coverageDeg < $1.coverageDeg }) {
            return [makeSnookerSolution(closest)]
        }
        return []
    }

    /// 评估一个做斯诺克候选；不满足首触/进袋/真停硬约束 ⇒ nil。
    private static func evaluateSnooker(
        _ pred: ShotPrediction, targetKey: String, blockerKey: String,
        spinX: Double, spinY: Double, velocity: Double
    ) -> SnookerScored? {
        // 母球不进袋 + 真停稳。
        guard !pred.cuePocketed, pred.cueFinalSpeed < restSpeedTolerance else { return nil }
        // 目标球不进袋（它要留在台面当诱饵）。
        guard !pred.pocketedBalls.contains(targetKey) else { return nil }
        // 合法首触：母球第一次球-球碰撞的另一方必须是目标球。
        var firstOther: String?
        for e in pred.events {
            if case let .ballBall(a, b) = e.kind {
                if a == ShotInput.cueBallName { firstOther = b; break }
                if b == ShotInput.cueBallName { firstOther = a; break }
            }
        }
        guard firstOther == targetKey else { return nil }
        // 三球终位齐备。
        guard let finalC = pred.finalPositions[ShotInput.cueBallName],
              let finalT = pred.finalPositions[targetKey],
              let finalB = pred.finalPositions[blockerKey] else { return nil }

        let cov = AngleSceneCalculator.snookerCoverage(cue: finalC, snookered: finalT, blocker: finalB)
        let cushion = pred.events.reduce(0) { acc, e in
            if case let .ballCushion(ball) = e.kind, ball == ShotInput.cueBallName { return acc + 1 }
            return acc
        }
        let shot = PlannedShot(
            targetKey: targetKey, pocket: "", velocity: velocity, spinX: spinX, spinY: spinY,
            freeAim: canvasDirection(fromScene: pred.aimDirection))
        return SnookerScored(shot: shot, prediction: pred, cushion: cushion,
                             coverageDeg: cov.marginDegrees, full: cov.isFullSnooker)
    }

    private static func makeSnookerSolution(_ s: SnookerScored) -> PositionPlaySolution {
        let cushionTxt = cushionText(s.cushion)
        let spin = spinText(s.shot.spinX, s.shot.spinY)
        let power = "\(PowerDisplay.name(s.shot.velocity)) \(String(format: "%.1f", s.shot.velocity))"
        let covTxt: String
        if s.full {
            covTxt = "完全斯诺克 · 余量约 \(Int(s.coverageDeg.rounded()))°"
        } else {
            covTxt = "半斯诺克 · 仍露约 \(Int((-s.coverageDeg).rounded()))°"
        }
        let summary = "\(spin) · \(power) · \(cushionTxt) · \(covTxt)"
        return PositionPlaySolution(
            shot: s.shot, prediction: s.prediction, cushionCount: s.cushion,
            potted: false, margin: s.coverageDeg, summary: summary,
            satisfiesConstraint: s.full)
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
