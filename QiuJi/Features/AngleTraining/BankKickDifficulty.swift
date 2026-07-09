//
//  BankKickDifficulty.swift
//  QiuJi
//
//  翻袋/反射解球页「好打优先」排序（W3，docs/research/20260709-翻袋反射页重构方案 §3）。
//
//  与 `DifficultyModel`（E1，走位反解的 spin/力度难度语义）**分立不共码**：两页反解不搜塞，
//  难度输入是进球几何（切角/球距/库数/路径长/首库入射角），常量集中在本文件单一真源。
//  排序 = 难度评分 + E5 式扰动容错合成，全部落在「挑选/呈现」层——不碰扫描与终验流水线。
//
//  坐标契约：SceneKit 世界系，水平面 X–Z、+Y 朝上；长库 = 常 Z（±halfW）、短库 = 常 X（±halfL）。
//

import Foundation
import SceneKit

// MARK: - 页面模式（W6：求解 / 自由，方案 §1.1 状态机）

/// 翻袋/反射解球页双模式：`solve` = 引擎反解 + 击打演示；`free` = 用户自定瞄准/打点/力度，
/// `simulateFree` 真物理试手（球停在哪是哪）。
enum BankKickPageMode {
    case solve
    case free
}

// MARK: - 自由模式首碰胶囊文案（两页共用）

enum BankKickFreePill {
    /// USDZ 球键 → 用户可读名（`_8` → 「8 号球」）。
    static func ballName(_ key: String) -> String {
        key.hasPrefix("_") ? "\(key.dropFirst()) 号球" : key
    }
}

// MARK: - Tier（易/中/难档位，pill 文案与 E2 标签对齐）

enum BankKickDifficultyTier: Int, Comparable, CaseIterable {
    case easy = 0
    case medium = 1
    case hard = 2

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .easy: "易"
        case .medium: "中"
        case .hard: "难"
        }
    }
}

// MARK: - Model（常量集中可调，方案 §3「E1 模式：单一真源」）

enum BankKickDifficulty {

    // MARK: 常量

    /// 切角难度起算点/跨度/权重（E4 同参：60° 起算、~90° 满档、75° 薄球）。
    static let cutAngleOnsetDeg = 60.0
    static let cutAngleSpanDeg = 30.0
    static let cutAngleWeight = 0.8
    /// 球距难度起算点（米）与斜率（E4 同参）。
    static let distanceOnsetMeters = 1.0
    static let distanceSlope = 0.3
    /// 每多一库的难度增量（速度衰减 + 库边不确定性叠加）。
    static let perCushionWeight = 0.22
    /// 解线路径长难度：起算点（米）与斜率（长路径放大执行误差）。
    static let pathLengthOnsetMeters = 1.0
    static let pathLengthSlope = 0.12
    /// 反射页首库入射角余量（无切角语义的替代输入，方案 §3）：入射角（相对库面）
    /// 越平越难。低于满余量角起算，线性升至下限角满档。
    static let firstRailFullMarginDeg = 60.0
    static let firstRailMinAngleDeg = 15.0
    static let firstRailMarginWeight = 0.5
    /// 好打分合成：`好打分 = 难度评分 − robustnessWeight·robustness`（升序 = 越好打越靠前）。
    /// 翻袋是「悬崖解」重灾区，容错是主要区分量。
    static let robustnessWeight = 0.8
    /// 档位阈值（难度评分，不含容错）。
    static let tierBoundaries = (easy: 0.55, medium: 1.1)

    /// E5 同款扰动参数（两页反解不搜塞 ⇒ 不扰打点，仅瞄准 + 力度共 4 次）。
    static let probeAimDeltaDeg = 0.5
    static let probeVelocityFactor = 0.08

    // MARK: 难度评分

    /// 翻袋解难度：切角（引擎碰撞口径）+ 球距 + 库数 + 路径长。无量纲，越大越难。
    static func bankScore(
        cutAngleDeg: Double?, cueTargetDistance: Double, cushions: Int, pathLength: Double
    ) -> Double {
        var s = 0.0
        if let cut = cutAngleDeg {
            s += max(0, cut - cutAngleOnsetDeg) / cutAngleSpanDeg * cutAngleWeight
        }
        s += max(0, cueTargetDistance - distanceOnsetMeters) * distanceSlope
        s += Double(cushions) * perCushionWeight
        s += max(0, pathLength - pathLengthOnsetMeters) * pathLengthSlope
        return s
    }

    /// 反射（kick）解难度：首库入射角余量（切角替代输入）+ 库数 + 路径长。
    static func kickScore(
        firstRailIncidenceDeg: Double?, cushions: Int, pathLength: Double
    ) -> Double {
        var s = 0.0
        if let angle = firstRailIncidenceDeg {
            let span = firstRailFullMarginDeg - firstRailMinAngleDeg
            let deficit = (firstRailFullMarginDeg - angle) / span
            s += min(1, max(0, deficit)) * firstRailMarginWeight
        }
        s += Double(cushions) * perCushionWeight
        s += max(0, pathLength - pathLengthOnsetMeters) * pathLengthSlope
        return s
    }

    static func tier(_ score: Double) -> BankKickDifficultyTier {
        if score < tierBoundaries.easy { return .easy }
        if score < tierBoundaries.medium { return .medium }
        return .hard
    }

    /// 排序键：越小越「好打」。robustness nil（未测出）按 0 保守处理。
    static func goodness(difficultyScore: Double, robustness: Double?) -> Double {
        difficultyScore - robustnessWeight * (robustness ?? 0)
    }

    // MARK: E5 式扰动容错（瞄准 ±0.5° / 力度 ±8%，解析优先、歧义回退引擎 scoring-only）

    /// 翻袋解容错：对已终验的解做 4 次扰动，统计仍进选定袋的比例（0–1）。
    /// 评估走 `ShotPredictor.bankAimScore`（解析优先，歧义就地回退引擎——判定不降级）。
    static func measureBankRobustness(
        input baseInput: ShotInput, rails: [BankShotCalculator.Rail], aimOffset: Float
    ) -> Double? {
        var input = baseInput
        input.bankRails = rails
        var scratch = ShotPrediction()
        guard let ctx = ShotPredictor.prepareAim(input, into: &scratch) else { return nil }
        let aimDelta = Float(probeAimDeltaDeg) * .pi / 180
        let vFactor = Float(probeVelocityFactor)
        var succeeded = 0
        for probe in perturbations(offset: aimOffset, velocity: input.velocity,
                                   aimDelta: aimDelta, vFactor: vFactor) {
            var pInput = input
            pInput.velocity = probe.velocity
            if ShotPredictor.bankAimScore(offset: probe.offset, input: pInput,
                                          context: ctx, rails: rails) < 0 {
                succeeded += 1
            }
        }
        return Double(succeeded) / 4.0
    }

    /// 反射解容错：同款 4 次扰动，统计仍「碰到目标球且库序拓扑吻合」的比例。
    static func measureKickRobustness(
        input baseInput: ShotInput, rails: [DiamondSystemCalculator.Rail], aimOffset: Float
    ) -> Double? {
        var input = baseInput
        input.kickRails = rails
        var scratch = ShotPrediction()
        guard let ctx = ShotPredictor.prepareAim(input, into: &scratch) else { return nil }
        let aimDelta = Float(probeAimDeltaDeg) * .pi / 180
        let vFactor = Float(probeVelocityFactor)
        var succeeded = 0
        for probe in perturbations(offset: aimOffset, velocity: input.velocity,
                                   aimDelta: aimDelta, vFactor: vFactor) {
            var pInput = input
            pInput.velocity = probe.velocity
            if ShotPredictor.kickAimScore(offset: probe.offset, input: pInput,
                                          context: ctx, rails: rails) < 0 {
                succeeded += 1
            }
        }
        return Double(succeeded) / 4.0
    }

    private static func perturbations(
        offset: Float, velocity: Float, aimDelta: Float, vFactor: Float
    ) -> [(offset: Float, velocity: Float)] {
        [
            (offset + aimDelta, velocity),
            (offset - aimDelta, velocity),
            (offset, velocity * (1 + vFactor)),
            (offset, velocity * (1 - vFactor))
        ]
    }
}

// MARK: - 解模型（基于引擎全保真 ShotPrediction 装配，方案 §3）

/// 翻袋页解（引擎全保真物化）。`cushions` = 种子库序数（chip/pill 的「N 库」语义，
/// 与 `rails` 文案一致；引擎实测 `objectCushionCount` 含 jaw 擦碰、仅供诊断）。
struct BankEngineSolution: Identifiable {
    let id = UUID()
    let rails: [BankShotCalculator.Rail]
    let prediction: ShotPrediction
    let cushions: Int
    let difficultyScore: Double
    let difficultyTier: BankKickDifficultyTier
    let robustness: Double?
    let pathLength: Double

    var goodness: Double {
        BankKickDifficulty.goodness(difficultyScore: difficultyScore, robustness: robustness)
    }
    var railSequenceText: String { rails.map(\.label).joined(separator: " → ") }
}

/// 反射页解（引擎全保真物化）。`cushions` = 种子库序数（与 `rails` 文案一致）。
struct KickEngineSolution: Identifiable {
    let id = UUID()
    let rails: [DiamondSystemCalculator.Rail]
    let prediction: ShotPrediction
    let cushions: Int
    let difficultyScore: Double
    let difficultyTier: BankKickDifficultyTier
    let robustness: Double?
    let pathLength: Double

    var goodness: Double {
        BankKickDifficulty.goodness(difficultyScore: difficultyScore, robustness: robustness)
    }
    var railSequenceText: String { rails.map(\.label).joined(separator: " → ") }
}

// MARK: - 求解管线（VM 与测试共用的纯函数入口）

enum BankKickSolvePipeline {

    /// 翻袋解上限（沿用旧页上限，方案 §2.1）。
    static let bankSolutionLimit = 12
    /// 反射解上限。
    static let kickSolutionLimit = 16
    /// 去重口径：瞄准方向差 < 0.3° 且引擎实测吃库数相同视为同一解
    /// （不同库序种子可能收敛到同一真实路线）。
    static let dedupAimSeparationRad = Float(0.3) * .pi / 180

    /// 翻袋单袋全枚举 → 装配难度/容错 → 好打优先排序（升序）→ 去重取前 N。
    /// 纯函数、线程安全，供 VM 后台任务与测试直接调用。
    /// `obstacles` = 球库拖入的在桌障碍球（W4，方案 §4.3）：**真实碰撞体**进反解模拟
    /// 与容错扰动（目标球/母球撞障碍 = 候选被引擎自然淘汰，非几何过滤）。
    static func solveBank(
        cue: SCNVector3, object: SCNVector3, pocketIndex: Int,
        surfaceY: Float, power: Float, obstacles: [ObstacleBall] = []
    ) -> [BankEngineSolution] {
        var input = ShotInput(
            cueBall: cue, targetBall: object, pocketIndex: pocketIndex,
            velocity: power, spinX: 0, spinY: 0, surfaceY: surfaceY
        )
        input.obstacles = obstacles
        let dx = Double(cue.x - object.x), dz = Double(cue.z - object.z)
        let distance = (dx * dx + dz * dz).squareRoot()

        var solutions: [BankEngineSolution] = []
        for (rails, pred) in ShotPredictor.predictBankAll(input) {
            let pathLength = Double(polylineLengthXZ(pred.objectPath))
            // 库数取**种子库序数**（用户「1/2/3 库」chip 的语义）：引擎实测
            // `objectCushionCount` 会把贴袋入口擦 jaw 也计入（W1 §2.2 合法进袋路线），
            // 用于分桶/难度/pill 会失真（画面 1 库、读数 5 库）。
            let cushions = rails.count
            let score = BankKickDifficulty.bankScore(
                cutAngleDeg: pred.cutAngleDeg, cueTargetDistance: distance,
                cushions: cushions, pathLength: pathLength
            )
            let robustness = pred.aimOffsetUsed.flatMap {
                BankKickDifficulty.measureBankRobustness(input: input, rails: rails, aimOffset: $0)
            }
            solutions.append(BankEngineSolution(
                rails: rails, prediction: pred, cushions: cushions,
                difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
                robustness: robustness, pathLength: pathLength
            ))
        }
        return rank(solutions, limit: bankSolutionLimit)
    }

    /// 反射全枚举 → 装配难度/容错 → 好打优先排序 → 去重取前 N。
    /// `obstacles` 语义同 `solveBank`（真实碰撞体）。
    static func solveKick(
        cue: SCNVector3, target: SCNVector3, surfaceY: Float, power: Float,
        obstacles: [ObstacleBall] = []
    ) -> [KickEngineSolution] {
        var input = ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: 0,
            velocity: power, spinX: 0, spinY: 0, surfaceY: surfaceY
        )
        input.obstacles = obstacles
        var solutions: [KickEngineSolution] = []
        for (rails, pred) in ShotPredictor.predictKickAll(input) {
            let route = pathToFirstContact(pred)
            let pathLength = Double(polylineLengthXZ(route))
            let incidence = kickFirstRailIncidenceDeg(
                cue: cue, target: target, rails: rails, surfaceY: surfaceY
            )
            // 同 bank：库数取种子库序数（chip 语义），引擎实测计数含 jaw 擦碰会失真。
            let cushions = rails.count
            let score = BankKickDifficulty.kickScore(
                firstRailIncidenceDeg: incidence,
                cushions: cushions, pathLength: pathLength
            )
            let robustness = pred.aimOffsetUsed.flatMap {
                BankKickDifficulty.measureKickRobustness(input: input, rails: rails, aimOffset: $0)
            }
            solutions.append(KickEngineSolution(
                rails: rails, prediction: pred, cushions: cushions,
                difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
                robustness: robustness, pathLength: pathLength
            ))
        }
        return rank(solutions, limit: kickSolutionLimit)
    }

    // MARK: 排序 + 去重

    /// 好打分升序，tie-break 库数少 → 路径短；同吃库数且瞄准方向几乎相同的解去重
    ///（保留排序更优者）。
    private static func rank<S: RankableSolution>(_ solutions: [S], limit: Int) -> [S] {
        let sorted = solutions.sorted { lhs, rhs in
            if lhs.goodness != rhs.goodness { return lhs.goodness < rhs.goodness }
            if lhs.cushions != rhs.cushions { return lhs.cushions < rhs.cushions }
            return lhs.pathLength < rhs.pathLength
        }
        var out: [S] = []
        for sol in sorted {
            let isDup = out.contains { existing in
                existing.cushions == sol.cushions &&
                aimAngleDifference(existing.prediction.aimDirection,
                                   sol.prediction.aimDirection) < dedupAimSeparationRad
            }
            if !isDup { out.append(sol) }
            if out.count >= limit { break }
        }
        return out
    }

    private static func aimAngleDifference(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dot = max(-1, min(1, a.x * b.x + a.z * b.z))
        return acosf(dot)
    }

    // MARK: 几何辅助

    /// 反射解首库入射角（度，相对库面）：从镜像种子首段方向计算
    /// （公式与 `DiamondSystemCalculator.firstCushionAngleOK` 同式：长库 = 常 Z，
    /// 入射角 = atan2(|dz|, |dx|)；短库对调）。
    static func kickFirstRailIncidenceDeg(
        cue: SCNVector3, target: SCNVector3,
        rails: [DiamondSystemCalculator.Rail], surfaceY: Float
    ) -> Double? {
        guard let first = rails.first,
              let seed = DiamondSystemCalculator.kickSeedPath(
                cue: cue, target: target, rails: rails, surfaceY: surfaceY),
              seed.count >= 2 else { return nil }
        let dx0 = seed[1].x - seed[0].x
        let dz0 = seed[1].z - seed[0].z
        let len = sqrtf(dx0 * dx0 + dz0 * dz0)
        guard len > 1e-6 else { return nil }
        let dx = abs(dx0 / len), dz = abs(dz0 / len)
        let angle: Float = first.isLong ? atan2(dz, dx) : atan2(dx, dz)
        return Double(angle) * 180 / .pi
    }

    /// 母球轨迹截到首次球-球碰撞点（kick 的「解线」段）。无首碰时返回全程。
    static func pathToFirstContact(_ pred: ShotPrediction) -> [SCNVector3] {
        guard let contact = pred.firstContact, pred.cuePath.count >= 2 else { return pred.cuePath }
        var bestIdx = pred.cuePath.count - 1
        var bestDist = Float.greatestFiniteMagnitude
        for (i, p) in pred.cuePath.enumerated() {
            let dx = p.x - contact.x, dz = p.z - contact.z
            let d = dx * dx + dz * dz
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        return Array(pred.cuePath.prefix(bestIdx + 1))
    }

    static func polylineLengthXZ(_ path: [SCNVector3]) -> Float {
        guard path.count >= 2 else { return 0 }
        var total: Float = 0
        for i in 0..<(path.count - 1) {
            let dx = path[i + 1].x - path[i].x, dz = path[i + 1].z - path[i].z
            total += sqrtf(dx * dx + dz * dz)
        }
        return total
    }

    // MARK: 碰库点提取（画金点/法线用）

    /// 从引擎折线提取碰库点：不假设接触坐标恰在 ±halfW/±halfL（引擎接触坐标取决于
    /// 库鼻几何），改用「靠近某条库的局部极值聚类」——顶点距库线 < 2R 的连续段取
    /// 最贴库那一点。返回 (点, 指向台内的单位法向)。
    static func cushionTouchPoints(
        _ path: [SCNVector3]
    ) -> [(point: SCNVector3, inwardNormal: SCNVector3)] {
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2
        let threshold = AngleSceneCalculator.ballRadius * 2

        struct RailProximity { let depth: Float; let normal: SCNVector3 }
        func proximity(_ p: SCNVector3) -> RailProximity? {
            // depth = 越贴库越大；四条库取最贴近者。
            var best: RailProximity?
            let candidates: [(Float, SCNVector3)] = [
                (p.z - (-halfW), SCNVector3(0, 0, 1)),   // 长库 Z=-halfW，内向 +Z
                (halfW - p.z, SCNVector3(0, 0, -1)),     // 长库 Z=+halfW，内向 -Z
                (p.x - (-halfL), SCNVector3(1, 0, 0)),   // 短库 X=-halfL，内向 +X
                (halfL - p.x, SCNVector3(-1, 0, 0))      // 短库 X=+halfL，内向 -X
            ]
            for (dist, normal) in candidates where dist < threshold {
                let depth = threshold - dist
                if best == nil || depth > best!.depth {
                    best = RailProximity(depth: depth, normal: normal)
                }
            }
            return best
        }

        var out: [(point: SCNVector3, inwardNormal: SCNVector3)] = []
        var cluster: [(SCNVector3, RailProximity)] = []
        func flush() {
            guard let deepest = cluster.max(by: { $0.1.depth < $1.1.depth }) else { return }
            out.append((deepest.0, deepest.1.normal))
            cluster.removeAll()
        }
        for p in path {
            if let prox = proximity(p) {
                // 换库（法向不同）视为新聚类。
                if let last = cluster.last, (last.1.normal.x != prox.normal.x
                    || last.1.normal.z != prox.normal.z) {
                    flush()
                }
                cluster.append((p, prox))
            } else if !cluster.isEmpty {
                flush()
            }
        }
        flush()
        return out
    }
}

private protocol RankableSolution {
    var goodness: Double { get }
    var cushions: Int { get }
    var pathLength: Double { get }
    var prediction: ShotPrediction { get }
}
extension BankEngineSolution: RankableSolution {}
extension KickEngineSolution: RankableSolution {}

// MARK: - 解缓存（LRU，方案 §4.1）

/// 小容量 LRU：key = 全部球位量化毫米 + 袋口 + 力度步进（库数过滤是展示层后处理不进 key）。
/// 页面持有、退出释放，不落盘。任何 key 成分变化必 miss——绝不出现球形变了还展示旧解。
struct BankKickSolveCache<Key: Hashable, Value> {
    let capacity: Int
    private var entries: [(key: Key, value: Value)] = []

    init(capacity: Int = 8) { self.capacity = capacity }

    mutating func value(for key: Key) -> Value? {
        guard let idx = entries.firstIndex(where: { $0.key == key }) else { return nil }
        let entry = entries.remove(at: idx)
        entries.append(entry)   // 命中移到队尾（最新）。
        return entry.value
    }

    mutating func insert(_ value: Value, for key: Key) {
        entries.removeAll { $0.key == key }
        entries.append((key, value))
        if entries.count > capacity { entries.removeFirst() }
    }

    var count: Int { entries.count }
}

/// 两页共用的量化 key。
struct BankKickSolveKey: Hashable {
    /// 全部球位量化到毫米（顺序固定：母球 x/z、目标球 x/z、障碍球按名序）。
    let ballsMM: [Int32]
    /// 袋口 index（仅翻袋；反射恒 -1）。
    let pocketIndex: Int
    /// 力度量化到滑块步进（0.1 m/s）。
    let powerStep: Int

    static func quantizeMM(_ v: Float) -> Int32 { Int32((v * 1000).rounded()) }
    static func quantizePower(_ p: Double) -> Int { Int((p * 10).rounded()) }

    /// 统一构造：母球/目标球 + 全部障碍球（按名序稳定排列）量化进 key——
    /// 任何球位变化（含障碍球增删挪动）必 miss（§4.1 一致性红线）。
    static func make(
        cue: SCNVector3, object: SCNVector3, obstacles: [ObstacleBall],
        pocketIndex: Int, power: Double
    ) -> BankKickSolveKey {
        var mm: [Int32] = [quantizeMM(cue.x), quantizeMM(cue.z),
                           quantizeMM(object.x), quantizeMM(object.z)]
        for ob in obstacles.sorted(by: { $0.name < $1.name }) {
            mm.append(quantizeMM(ob.position.x))
            mm.append(quantizeMM(ob.position.z))
        }
        return BankKickSolveKey(ballsMM: mm, pocketIndex: pocketIndex,
                                powerStep: quantizePower(power))
    }
}
