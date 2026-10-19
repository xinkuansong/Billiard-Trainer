//
//  BankKickDifficulty.swift
//  QiuJi
//
//  翻袋/反射解球页「好打优先」排序（W3，docs/research/20260709-翻袋反射页重构方案 §3）。
//
//  Measured-route grouping and minimum-spin representatives precede cross-route ranking.
//  Difficulty uses shot geometry; robustness probes aim, speed and horizontal contact error.
//  Every reduced-spin candidate reuses the production aim search and physics verification.
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

    /// Aim / speed probes plus horizontal contact-point error, including zero-spin shots.
    static let probeAimDeltaDeg = 0.5
    static let probeVelocityFactor = 0.08
    static let probeSpinDelta: Float = 0.02

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

    /// Six deterministic probes; this fraction is not a calibrated success probability.
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
        for delta in [-probeSpinDelta, probeSpinDelta] {
            var probe = input
            probe.spinX += delta
            if ShotPredictor.bankAimScore(offset: aimOffset, input: probe, context: ctx, rails: rails) < 0 {
                succeeded += 1
            }
        }
        return Double(succeeded) / 6.0
    }

    /// Six probes of aim, speed and horizontal contact-point error.
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
        for delta in [-probeSpinDelta, probeSpinDelta] {
            var probe = input
            probe.spinX += delta
            if ShotPredictor.kickAimScore(offset: aimOffset, input: probe, context: ctx, rails: rails) < 0 {
                succeeded += 1
            }
        }
        return Double(succeeded) / 6.0
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

/// 翻袋页解（引擎全保真物化）。`rails`/`cushions` = **实测主库序**（引擎事件流主库
/// 分类 + 贴库首弹重建，`BankShotCalculator.reconstructedRailContacts`）——画面、文案、
/// 库数 chip 同一真源；种子库序只作搜索锚不上屏。jaw 擦碰不计（`objectCushionCount`
/// 含 jaw、仅供诊断）。
/// K10：`spinX`/`spinY` = 该解搜索/击打用的加塞（接触点偏移/R；+X 左塞 / −X 右塞）。
/// `usedFrozenRailSeed` = 首库为目标球所贴自库（扎库解，文案「扎库(自库)」）。
struct BankEngineSolution: Identifiable {
    let id = UUID()
    let rails: [BankShotCalculator.Rail]
    /// 种子库序（搜索锚）：微调重算（K11 `adjustCurrentSolution`）沿原库序 predict 用；
    /// 与展示 `rails`（实测）可能不同——扎库解种子不含自库。
    let seedRails: [BankShotCalculator.Rail]
    let prediction: ShotPrediction
    let cushions: Int
    let difficultyScore: Double
    let difficultyTier: BankKickDifficultyTier
    let robustness: Double?
    let pathLength: Double
    let spinX: Float
    let spinY: Float
    let usedFrozenRailSeed: Bool

    var goodness: Double {
        BankKickDifficulty.goodness(difficultyScore: difficultyScore, robustness: robustness)
    }
    var railSequenceText: String {
        guard usedFrozenRailSeed, let first = rails.first else {
            return rails.map(\.label).joined(separator: " → ")
        }
        let rest = rails.dropFirst().map(\.label).joined(separator: " → ")
        return rest.isEmpty ? "扎库(\(first.label))" : "扎库(\(first.label)) → \(rest)"
    }
    var spinLabel: String {
        ShotSpinLabel.text(spinX: Double(spinX), spinY: Double(spinY))
    }
}

/// Kick display rails/count come from main-rail events before the cue's first ball contact.
/// K10：同翻袋，解携带搜索时的加塞。
struct KickEngineSolution: Identifiable {
    let id = UUID()
    let rails: [DiamondSystemCalculator.Rail]
    let seedRails: [DiamondSystemCalculator.Rail]
    let prediction: ShotPrediction
    let cushions: Int
    let difficultyScore: Double
    let difficultyTier: BankKickDifficultyTier
    let robustness: Double?
    let pathLength: Double
    let spinX: Float
    let spinY: Float

    var goodness: Double {
        BankKickDifficulty.goodness(difficultyScore: difficultyScore, robustness: robustness)
    }
    var railSequenceText: String { rails.map(\.label).joined(separator: " → ") }
    var spinLabel: String {
        ShotSpinLabel.text(spinX: Double(spinX), spinY: Double(spinY))
    }
}

/// Route identity in world XZ metres. Excludes the cue's post-contact motion (kick)
/// and the object's pocket presentation tail (bank). A ball diameter is the catalogue
/// grouping tolerance, NOT a physics success tolerance. Rail order must also agree.
struct BankKickRoute {
    let rails: [BankShotCalculator.Rail]
    let contacts: [SCNVector3]
    let path: [SCNVector3]
    let pocketID: String?

    static var tolerance: Float { 2 * BallPhysics.radius }

    func matches(_ other: Self) -> Bool {
        guard rails == other.rails, pocketID == other.pocketID,
              contacts.count == other.contacts.count,
              path.count >= 2, other.path.count >= 2 else { return false }
        func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
            hypotf(a.x - b.x, a.z - b.z)
        }
        guard zip(contacts, other.contacts).allSatisfy({ distance($0, $1) <= Self.tolerance }) else {
            return false
        }
        // Ordered arc-length samples distinguish traversals even when their point sets overlap.
        let a = Self.samples(path), b = Self.samples(other.path)
        return !a.isEmpty && a.count == b.count && zip(a, b).allSatisfy { distance($0, $1) <= Self.tolerance }
    }

    private static func samples(_ path: [SCNVector3]) -> [SCNVector3] {
        var lengths: [Float] = [0]
        for (a, b) in zip(path, path.dropFirst()) {
            lengths.append(lengths.last! + hypotf(b.x - a.x, b.z - a.z))
        }
        guard let total = lengths.last, total > 0 else { return [] }
        var segment = 1
        return (0...32).map { index in
            let at = total * Float(index) / 32
            while segment < lengths.count - 1 && lengths[segment] < at { segment += 1 }
            let length = lengths[segment] - lengths[segment - 1]
            let t = length > 0 ? (at - lengths[segment - 1]) / length : 0
            let a = path[segment - 1], b = path[segment]
            return SCNVector3(a.x + (b.x - a.x) * t, a.y, a.z + (b.z - a.z) * t)
        }
    }

    static func measured(_ prediction: ShotPrediction, kick: Bool) -> Self? {
        let ball = kick ? ShotInput.cueBallName : ShotInput.targetBallName
        guard let recorder = prediction.recorder,
              let frames = recorder.framesByBallName[ball], !frames.isEmpty else { return nil }
        var rails: [BankShotCalculator.Rail] = []
        var contacts: [SCNVector3] = []
        var endTime: Float?
        var pocketID: String?
        for event in prediction.events {
            switch event.kind {
            case let .ballBall(a, b) where kick && (a == ball || b == ball):
                endTime = event.time
            case let .pocket(name, id) where name == ball:
                endTime = event.time
                pocketID = id
            case let .ballCushion(name) where name == ball:
                if let index = event.cushionIndex, let normal = event.contactNormal,
                   let rail = ShotPredictor.mainRail(cushionIndex: index, normal: normal),
                   rails.last != rail,
                   let point = recorder.stateAt(ballName: ball, time: event.time)?.position {
                    rails.append(rail)
                    contacts.append(point)
                }
            default: break
            }
            if endTime != nil { break }
        }
        // A manual adjustment can miss; its displayed rail sequence still comes from events.
        if kick && endTime == nil { endTime = frames.last?.time }
        guard let endTime else { return nil }
        var path = frames.filter { $0.time < endTime }.map(\.position)
        if let end = recorder.stateAt(ballName: ball, time: endTime)?.position { path.append(end) }
        guard path.count >= 2 else { return nil }
        if !kick {
            let reconstructed = BankShotCalculator.reconstructedRailContacts(
                object: path[0], departure: prediction.objectDepartureDir, engineRails: rails)
            if reconstructed.count > rails.count { contacts.insert(path[0], at: 0) }
            rails = reconstructed
        }
        return Self(rails: rails, contacts: contacts, path: path, pocketID: pocketID)
    }

    var kickRails: [DiamondSystemCalculator.Rail] {
        rails.map {
            switch $0 {
            case .left: .left
            case .right: .right
            case .far: .far
            case .near: .near
            }
        }
    }

    var firstRailIncidence: Double? {
        guard let rail = rails.first, let contact = contacts.first, let start = path.first else { return nil }
        let dx = abs(contact.x - start.x), dz = abs(contact.z - start.z)
        guard dx + dz > 0 else { return nil }
        return Double(rail.isLong ? atan2f(dz, dx) : atan2f(dx, dz)) * 180 / .pi
    }
}

// MARK: - 求解管线（VM 与测试共用的纯函数入口）

enum BankKickSolvePipeline {

    /// 翻袋解上限（沿用旧页上限，方案 §2.1）。
    static let bankSolutionLimit = 12
    /// 反射解上限。
    static let kickSolutionLimit = 16
    /// K10 加塞搜索档（与走位反解 `spinXValues` 同口径）：≈×3 全枚举成本。
    /// 坐标契约：spinX = 接触点偏移/R，+左塞 / −右塞；本档只搜横塞，spinY 恒 0。
    static let sideSpinSearchValues: [Float] = [-0.3, 0, 0.3]
    /// Minimum spin is searched on this finite grid, re-solving aim at every step.
    /// No monotonic-feasibility assumption / binary search across disconnected success windows.
    static let minimumSpinStep: Float = 0.02

    /// 翻袋单袋全枚举 → 装配难度/容错 → 好打优先排序（升序）→ 去重取前 N。
    /// 纯函数、线程安全，供 VM 后台任务与测试直接调用。
    /// `obstacles` = 球库拖入的在桌障碍球（W4，方案 §4.3）：**真实碰撞体**进反解模拟
    /// 与容错扰动（目标球/母球撞障碍 = 候选被引擎自然淘汰，非几何过滤）。
    /// K10：外层枚举 `sideSpinSearchValues`；引擎管线（squirt）已支持，本函数只消费。
    static func solveBank(
        cue: SCNVector3, object: SCNVector3, pocketIndex: Int,
        surfaceY: Float, power: Float, obstacles: [ObstacleBall] = [],
        spinXValues: [Float] = sideSpinSearchValues,
        cancellation: PredictionCancellation? = nil
    ) -> [BankEngineSolution] {
        var input = ShotInput(cueBall: cue, targetBall: object, pocketIndex: pocketIndex,
                              velocity: power, spinX: 0, spinY: 0, surfaceY: surfaceY)
        input.obstacles = obstacles
        var solutions: [BankEngineSolution] = []
        for sx in spinXValues {
            guard cancellation?.isCancelled != true else { return [] }
            input.spinX = sx
            for (seedRails, pred) in ShotPredictor.predictBankAll(input, cancellation: cancellation) {
                if let solution = bankSolution(input: input, seedRails: seedRails, prediction: pred) {
                    solutions.append(solution)
                }
            }
        }
        let baseInput = input
        let reduced = minimumSpinRepresentatives(solutions, spinXValues: spinXValues,
                                                cancellation: cancellation) { candidate, sx in
            var trial = baseInput
            trial.spinX = sx
            trial.bankRails = candidate.seedRails
            let pred = ShotPredictor.predict(trial, bankCancellation: cancellation)
            return bankSolution(input: trial, seedRails: candidate.seedRails, prediction: pred)
        }
        return cancellation?.isCancelled == true ? [] : rank(reduced, limit: bankSolutionLimit)
    }

    static func bankSolution(input: ShotInput, seedRails: [BankShotCalculator.Rail],
                             prediction pred: ShotPrediction) -> BankEngineSolution? {
        guard pred.feasible, pred.simObjectPotted, pred.hasFinalTableState,
              pred.cueCushionsBeforeContact == 0,
              let route = BankKickRoute.measured(pred, kick: false), !route.rails.isEmpty else { return nil }
        let length = Double(polylineLengthXZ(route.path))
        let distance = Double(hypotf(input.cueBall.x - input.targetBall.x,
                                    input.cueBall.z - input.targetBall.z))
        let score = BankKickDifficulty.bankScore(cutAngleDeg: pred.cutAngleDeg,
            cueTargetDistance: distance, cushions: route.rails.count, pathLength: length)
        let robustness = pred.aimOffsetUsed.flatMap {
            BankKickDifficulty.measureBankRobustness(input: input, rails: seedRails, aimOffset: $0)
        }
        return BankEngineSolution(rails: route.rails, seedRails: seedRails, prediction: pred,
            cushions: route.rails.count, difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
            robustness: robustness, pathLength: length, spinX: input.spinX, spinY: input.spinY,
            usedFrozenRailSeed: BankShotCalculator.frozenRails(for: input.targetBall).contains(route.rails[0]))
    }

    /// Search seeds are retained only for re-solving; all display metadata uses measured routes.
    static func solveKick(
        cue: SCNVector3, target: SCNVector3, surfaceY: Float, power: Float,
        obstacles: [ObstacleBall] = [],
        spinXValues: [Float] = sideSpinSearchValues
    ) -> [KickEngineSolution] {
        var input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: 0,
                              velocity: power, spinX: 0, spinY: 0, surfaceY: surfaceY)
        input.obstacles = obstacles
        var solutions: [KickEngineSolution] = []
        for sx in spinXValues {
            input.spinX = sx
            for (seedRails, pred) in ShotPredictor.predictKickAll(input) {
                if let solution = kickSolution(input: input, seedRails: seedRails, prediction: pred) {
                    solutions.append(solution)
                }
            }
        }
        let baseInput = input
        let reduced = minimumSpinRepresentatives(solutions, spinXValues: spinXValues) { candidate, sx in
            var trial = baseInput
            trial.spinX = sx
            trial.kickRails = candidate.seedRails
            return kickSolution(input: trial, seedRails: candidate.seedRails,
                                prediction: ShotPredictor.predict(trial))
        }
        return rank(reduced, limit: kickSolutionLimit)
    }

    static func kickSolution(input: ShotInput, seedRails: [DiamondSystemCalculator.Rail],
                             prediction pred: ShotPrediction) -> KickEngineSolution? {
        guard pred.feasible, pred.kickContactMade, pred.hasFinalTableState,
              let route = BankKickRoute.measured(pred, kick: true), !route.rails.isEmpty else { return nil }
        let length = Double(polylineLengthXZ(route.path))
        let score = BankKickDifficulty.kickScore(firstRailIncidenceDeg: route.firstRailIncidence,
            cushions: route.rails.count, pathLength: length)
        let robustness = pred.aimOffsetUsed.flatMap {
            BankKickDifficulty.measureKickRobustness(input: input, rails: seedRails, aimOffset: $0)
        }
        return KickEngineSolution(rails: route.kickRails, seedRails: seedRails, prediction: pred,
            cushions: route.rails.count, difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
            robustness: robustness, pathLength: length, spinX: input.spinX, spinY: input.spinY)
    }

    // MARK: Route grouping / minimum-spin representatives / ranking

    private struct RouteGroup<S: RankableSolution> {
        let route: BankKickRoute
        var members: [S]
    }

    private static func preferred<S: RankableSolution>(_ a: S, _ b: S) -> Bool {
        if abs(a.spinX) != abs(b.spinX) { return abs(a.spinX) < abs(b.spinX) }
        if a.goodness != b.goodness { return a.goodness < b.goodness }
        return a.pathLength < b.pathLength
    }

    private static func groups<S: RankableSolution>(_ solutions: [S]) -> [RouteGroup<S>] {
        var groups: [RouteGroup<S>] = []
        // Anchor to the simplest candidate, rather than transitively chaining nearby routes.
        for solution in solutions.sorted(by: preferred) {
            guard let route = solution.route else { continue }
            if let index = groups.firstIndex(where: { $0.route.matches(route) }) {
                groups[index].members.append(solution)
            } else {
                groups.append(RouteGroup(route: route, members: [solution]))
            }
        }
        return groups
    }

    static func minimumSpinRepresentatives<S: RankableSolution>(
        _ solutions: [S], spinXValues: [Float], cancellation: PredictionCancellation? = nil,
        resolve: (S, Float) -> S?
    ) -> [S] {
        var out: [S] = []
        let signs: [Float] = [-1, 1].filter { sign in spinXValues.contains { $0 * sign > 0 } }
        // Across route groups, the same seed/spin is exactly the same deterministic solve.
        var attempted: Set<SpinTrialKey> = []
        var successesByKey: [SpinTrialKey: S] = [:]
        for group in groups(solutions) {
            guard cancellation?.isCancelled != true else { return [] }
            var best = group.members[0]
            if best.spinX == 0 { out.append(best); continue }
            var seeds: [S] = []
            for member in group.members where !seeds.contains(where: { $0.searchKey == member.searchKey }) {
                seeds.append(member)
            }
            // Spin reduction moves bounce points. Recheck against the NEW measured route
            // until no smaller grid value solves it, not just against the initial ±0.3 route.
            // Every accepted iteration strictly reduces |spin|, so termination is bounded.
            while best.spinX != 0, let reference = best.route {
                var chosen: S?
                // nextDown removes a one-ULP quotient overshoot at grid values such as 0.3.
                let steps = Int((abs(best.spinX) / minimumSpinStep).nextDown.rounded(.up))
                for step in 0..<max(0, steps) {
                    let magnitude = Float(step) * minimumSpinStep
                    let spins: [Float] = step == 0 ? [0] : signs.map { $0 * magnitude }
                    var successes: [S] = []
                    for sx in spins {
                        for seed in seeds {
                            guard cancellation?.isCancelled != true else { return [] }
                            let key = SpinTrialKey(rails: seed.searchKey, spin: sx)
                            if attempted.insert(key).inserted, let candidate = resolve(seed, sx) {
                                successesByKey[key] = candidate
                            }
                            if let candidate = successesByKey[key], let route = candidate.route,
                               reference.matches(route) {
                                successes.append(candidate)
                            }
                        }
                    }
                    if let winner = successes.sorted(by: preferred).first {
                        chosen = winner
                        break
                    }
                }
                guard let chosen, abs(chosen.spinX) < abs(best.spinX) else { break }
                best = chosen
            }
            out.append(best)
        }
        return out
    }

    private struct SpinTrialKey: Hashable {
        let rails: [BankShotCalculator.Rail]
        let spin: Float
    }

    static func rank<S: RankableSolution>(_ solutions: [S], limit: Int) -> [S] {
        // Zero/minimal spin wins within a route BEFORE goodness is compared across routes.
        let representatives = groups(solutions).map { $0.members[0] }
        return Array(representatives.sorted { lhs, rhs in
            if lhs.goodness != rhs.goodness { return lhs.goodness < rhs.goodness }
            if lhs.cushions != rhs.cushions { return lhs.cushions < rhs.cushions }
            return lhs.pathLength < rhs.pathLength
        }.prefix(limit))
    }

    /// Kept for existing bank regression callers; no aim-angle shortcut remains.
    static func isSameRefinedSolution(_ a: ShotPrediction, _ b: ShotPrediction) -> Bool {
        guard let a = BankKickRoute.measured(a, kick: false),
              let b = BankKickRoute.measured(b, kick: false) else { return false }
        return a.matches(b)
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

protocol RankableSolution {
    var spinX: Float { get }
    var route: BankKickRoute? { get }
    var searchKey: [BankShotCalculator.Rail] { get }
    var goodness: Double { get }
    var cushions: Int { get }
    var pathLength: Double { get }
    var prediction: ShotPrediction { get }
}
extension BankEngineSolution: RankableSolution {
    var route: BankKickRoute? { BankKickRoute.measured(prediction, kick: false) }
    var searchKey: [BankShotCalculator.Rail] { seedRails }
}
extension KickEngineSolution: RankableSolution {
    var route: BankKickRoute? { BankKickRoute.measured(prediction, kick: true) }
    var searchKey: [BankShotCalculator.Rail] {
        seedRails.map {
            switch $0 {
            case .left: .left
            case .right: .right
            case .far: .far
            case .near: .near
            }
        }
    }
}

// MARK: - 解缓存（LRU，方案 §4.1）

/// 小容量 LRU：key = 全部球位量化毫米 + 袋口 + 力度步进 + 塞档（库数过滤是展示层后处理不进 key）。
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
    /// K10：塞维度。单档 = `quantizeSpinX(spinX)`；全档搜索（默认）= `multiSpinSearchProfile`。
    let spinXCenti: Int

    /// 全档 `sideSpinSearchValues` 搜索的 key 哨兵（与单档 centi 不撞车）。
    static let multiSpinSearchProfile = 10_000

    static func quantizeMM(_ v: Float) -> Int32 { Int32((v * 1000).rounded()) }
    static func quantizePower(_ p: Double) -> Int { Int((p * 10).rounded()) }
    static func quantizeSpinX(_ s: Float) -> Int { Int((s * 100).rounded()) }

    /// 统一构造：母球/目标球 + 全部障碍球（按名序稳定排列）量化进 key——
    /// 任何球位变化（含障碍球增删挪动）必 miss（§4.1 一致性红线）。
    /// 默认 `spinXCenti = multiSpinSearchProfile`：一页一次求解覆盖全部加塞档。
    static func make(
        cue: SCNVector3, object: SCNVector3, obstacles: [ObstacleBall],
        pocketIndex: Int, power: Double,
        spinXCenti: Int = multiSpinSearchProfile
    ) -> BankKickSolveKey {
        var mm: [Int32] = [quantizeMM(cue.x), quantizeMM(cue.z),
                           quantizeMM(object.x), quantizeMM(object.z)]
        for ob in obstacles.sorted(by: { $0.name < $1.name }) {
            mm.append(quantizeMM(ob.position.x))
            mm.append(quantizeMM(ob.position.z))
        }
        return BankKickSolveKey(ballsMM: mm, pocketIndex: pocketIndex,
                                powerStep: quantizePower(power),
                                spinXCenti: spinXCenti)
    }
}
