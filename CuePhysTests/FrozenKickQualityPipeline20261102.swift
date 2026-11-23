// Frozen r9 pipeline for Kick-only equivalence under the current physics constants.
import Foundation
import SceneKit
@testable import QiuJi

enum FrozenKickQualityPipeline20261102 {

    /// 翻袋解上限（沿用旧页上限，方案 §2.1）。
    static let bankSolutionLimit = 12
    /// 反射解上限。
    static let kickSolutionLimit = 16
    /// K10 加塞搜索档（与走位反解 `spinXValues` 同口径）：≈×3 全枚举成本。
    /// 坐标契约：spinX = 接触点偏移/R，+左塞 / −右塞；本档只搜横塞，spinY 恒 0。
    static let sideSpinSearchValues: [Float] = [0, -0.3, 0.3]
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
        cancellation: PredictionCancellation? = nil, limit: Int? = bankSolutionLimit,
        parallelRefinement: Bool = true
    ) -> [BankEngineSolution] {
        var input = ShotInput(cueBall: cue, targetBall: object, pocketIndex: pocketIndex,
                              velocity: power, spinX: 0, spinY: 0, surfaceY: surfaceY)
        input.obstacles = obstacles
        var phaseStart = MixedLoopPhaseClock.now()
        var solutions: [BankEngineSolution] = []
        for sx in spinXValues {
            guard cancellation?.isCancelled != true else { return [] }
            input.spinX = sx
            for (seedRails, pred) in FrozenBankQualityPredictor20261102.predictBankAll(input, cancellation: cancellation, includePresentation: false) {
                if let solution = bankSolution(input: input, seedRails: seedRails, prediction: pred, measureRobustness: false) {
                    solutions.append(solution)
                }
            }
        }
        PerformanceProfiler.recordSample("BankKick.wall.initialSearch", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        phaseStart = MixedLoopPhaseClock.now()
        let baseInput = input
        let attempted = Set(spinXValues.flatMap { spin in
            BankShotCalculator.candidateRailSequences(maxCushions: 3).map { SpinTrialKey(rails: $0, spin: spin) }
        })
        let reduced = minimumSpinRepresentatives(solutions, spinXValues: spinXValues,
                                                cancellation: cancellation, previouslyAttempted: attempted,
                                                parallelTrials: parallelRefinement) { candidate, sx in
            var trial = baseInput
            trial.spinX = sx
            trial.bankRails = candidate.seedRails
            let pred = FrozenBankQualityPredictor20261102.predict(trial, bankCancellation: cancellation, includeBankKickPresentation: false)
            return bankSolution(input: trial, seedRails: candidate.seedRails, prediction: pred, measureRobustness: false)
        }
        guard cancellation?.isCancelled != true else { return [] }
        PerformanceProfiler.recordSample("BankKick.wall.reduceSpin", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        phaseStart = MixedLoopPhaseClock.now()
        let scored = evaluateInOrder(reduced, parallel: parallelRefinement, cancellation: cancellation) { candidate -> BankEngineSolution? in
            guard cancellation?.isCancelled != true else { return nil }
            var trial = baseInput; trial.spinX = candidate.spinX; trial.bankRails = candidate.seedRails
            return bankSolution(input: trial, seedRails: candidate.seedRails,
                                prediction: FrozenBankQualityPredictor20261102.materializeBankKick(candidate.prediction, input: trial),
                                cancellation: cancellation)
        }.compactMap { $0 }
        PerformanceProfiler.recordSample("BankKick.wall.scoreAndPresentation", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        return cancellation?.isCancelled == true ? [] : rank(scored, limit: limit ?? Int.max)
    }

    static func bankSolution(input: ShotInput, seedRails: [BankShotCalculator.Rail],
                             prediction pred: ShotPrediction, measureRobustness: Bool = true,
                             cancellation: PredictionCancellation? = nil) -> BankEngineSolution? {
        guard BankKickValidity.bank(pred),
              let route = BankKickRoute.measured(pred, kick: false), !route.rails.isEmpty else { return nil }
        let length = Double(polylineLengthXZ(route.path))
        let distance = Double(hypotf(input.cueBall.x - input.targetBall.x,
                                    input.cueBall.z - input.targetBall.z))
        let score = BankKickDifficulty.bankScore(cutAngleDeg: pred.cutAngleDeg,
            cueTargetDistance: distance, cushions: route.rails.count, pathLength: length)
        let robustness = measureRobustness ? pred.aimOffsetUsed.flatMap {
            BankKickDifficulty.measureBankRobustness(input: input, rails: seedRails, aimOffset: $0, cancellation: cancellation)
        } : nil
        return BankEngineSolution(rails: route.rails, seedRails: seedRails, prediction: pred,
            cushions: route.rails.count, difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
            robustness: robustness, pathLength: length, spinX: input.spinX, spinY: input.spinY,
            usedFrozenRailSeed: BankShotCalculator.frozenRails(for: input.targetBall).contains(route.rails[0]), measuredRoute: route)
    }

    /// Search seeds are retained only for re-solving; all display metadata uses measured routes.
    static func solveKick(
        cue: SCNVector3, target: SCNVector3, surfaceY: Float, power: Float,
        obstacles: [ObstacleBall] = [],
        spinXValues: [Float] = sideSpinSearchValues,
        cancellation: PredictionCancellation? = nil, limit: Int? = kickSolutionLimit,
        parallelRefinement: Bool = true
    ) -> [KickEngineSolution] {
        var input = ShotInput(cueBall: cue, targetBall: target, pocketIndex: 0,
                              velocity: power, spinX: 0, spinY: 0, surfaceY: surfaceY)
        input.obstacles = obstacles
        var phaseStart = MixedLoopPhaseClock.now()
        var solutions: [KickEngineSolution] = []
        for sx in spinXValues {
            guard cancellation?.isCancelled != true else { return [] }
            input.spinX = sx
            for (seedRails, pred) in FrozenBankQualityPredictor20261102.predictKickAll(input, cancellation: cancellation, includePresentation: false) {
                if let solution = kickSolution(input: input, seedRails: seedRails, prediction: pred, measureRobustness: false) {
                    solutions.append(solution)
                }
            }
        }
        PerformanceProfiler.recordSample("BankKick.wall.initialSearch", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        phaseStart = MixedLoopPhaseClock.now()
        let baseInput = input
        let attempted = Set(spinXValues.flatMap { spin in
            DiamondSystemCalculator.candidateRailSequences(maxCushions: 3).map { rails in
                SpinTrialKey(rails: rails.map { rail in
                    switch rail {
                    case .left: .left
                    case .right: .right
                    case .near: .near
                    case .far: .far
                    }
                }, spin: spin)
            }
        })
        let reduced = minimumSpinRepresentatives(solutions, spinXValues: spinXValues,
                                                cancellation: cancellation, previouslyAttempted: attempted,
                                                parallelTrials: parallelRefinement) { candidate, sx in
            var trial = baseInput
            trial.spinX = sx
            trial.kickRails = candidate.seedRails
            return kickSolution(input: trial, seedRails: candidate.seedRails,
                                prediction: FrozenBankQualityPredictor20261102.predict(trial, bankCancellation: cancellation, includeBankKickPresentation: false), measureRobustness: false)
        }
        guard cancellation?.isCancelled != true else { return [] }
        PerformanceProfiler.recordSample("BankKick.wall.reduceSpin", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        phaseStart = MixedLoopPhaseClock.now()
        let scored = evaluateInOrder(reduced, parallel: parallelRefinement, cancellation: cancellation) { candidate -> KickEngineSolution? in
            guard cancellation?.isCancelled != true else { return nil }
            var trial = baseInput; trial.spinX = candidate.spinX; trial.kickRails = candidate.seedRails
            return kickSolution(input: trial, seedRails: candidate.seedRails,
                                prediction: FrozenBankQualityPredictor20261102.materializeBankKick(candidate.prediction, input: trial),
                                cancellation: cancellation)
        }.compactMap { $0 }
        PerformanceProfiler.recordSample("BankKick.wall.scoreAndPresentation", ms: (MixedLoopPhaseClock.now() - phaseStart) * 1000)
        return cancellation?.isCancelled == true ? [] : rank(scored, limit: limit ?? Int.max)
    }

    static func kickSolution(input: ShotInput, seedRails: [DiamondSystemCalculator.Rail],
                             prediction pred: ShotPrediction, measureRobustness: Bool = true,
                             cancellation: PredictionCancellation? = nil) -> KickEngineSolution? {
        guard BankKickValidity.kick(pred),
              let route = BankKickRoute.measured(pred, kick: true), !route.rails.isEmpty else { return nil }
        let length = Double(polylineLengthXZ(route.path))
        let score = BankKickDifficulty.kickScore(firstRailIncidenceDeg: route.firstRailIncidence,
            cushions: route.rails.count, pathLength: length)
        let robustness = measureRobustness ? pred.aimOffsetUsed.flatMap {
            BankKickDifficulty.measureKickRobustness(input: input, rails: seedRails, aimOffset: $0, cancellation: cancellation)
        } : nil
        return KickEngineSolution(rails: route.kickRails, seedRails: seedRails, prediction: pred,
            cushions: route.rails.count, difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
            robustness: robustness, pathLength: length, spinX: input.spinX, spinY: input.spinY, measuredRoute: route)
    }

    /// Drafts remain playable even when unsuccessful; metadata never comes from the old catalog.
    static func bankDraft(input: ShotInput, seedRails: [BankShotCalculator.Rail],
                          prediction: ShotPrediction) -> BankEngineSolution {
        if let valid = bankSolution(input: input, seedRails: seedRails, prediction: prediction) { return valid }
        let route = BankKickRoute.measured(prediction, kick: false)
        let rails = route?.rails ?? prediction.objectRailContacts
        let length = Double(polylineLengthXZ(route?.path ?? prediction.objectPath))
        let score = BankKickDifficulty.bankScore(cutAngleDeg: prediction.cutAngleDeg,
            cueTargetDistance: Double(hypotf(input.cueBall.x - input.targetBall.x, input.cueBall.z - input.targetBall.z)),
            cushions: rails.count, pathLength: length)
        return BankEngineSolution(rails: rails, seedRails: seedRails, prediction: prediction,
            cushions: rails.count, difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
            robustness: nil, pathLength: length, spinX: input.spinX, spinY: input.spinY,
            usedFrozenRailSeed: rails.first.map(BankShotCalculator.frozenRails(for: input.targetBall).contains) ?? false,
            measuredRoute: route)
    }

    static func kickDraft(input: ShotInput, seedRails: [DiamondSystemCalculator.Rail],
                          prediction: ShotPrediction) -> KickEngineSolution {
        if let valid = kickSolution(input: input, seedRails: seedRails, prediction: prediction) { return valid }
        let route = BankKickRoute.measured(prediction, kick: true)
        let length = Double(polylineLengthXZ(route?.path ?? pathToFirstContact(prediction)))
        let score = BankKickDifficulty.kickScore(firstRailIncidenceDeg: route?.firstRailIncidence,
            cushions: route?.rails.count ?? 0, pathLength: length)
        return KickEngineSolution(rails: route?.kickRails ?? [], seedRails: seedRails, prediction: prediction,
            cushions: route?.rails.count ?? 0, difficultyScore: score, difficultyTier: BankKickDifficulty.tier(score),
            robustness: nil, pathLength: length, spinX: input.spinX, spinY: input.spinY, measuredRoute: route)
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

    /// Request-local single-flight cache. Failed trials are cached too; concurrent route
    /// groups requesting one seed/spin share its completed result, never a partial value.
    private final class SpinTrialMemo<S> {
        private enum Entry { case running, completed(S?) }
        private var entries: [SpinTrialKey: Entry]
        private let condition = NSCondition()

        init(attempted: Set<SpinTrialKey>, successes: [SpinTrialKey: S]) {
            entries = Dictionary(uniqueKeysWithValues: attempted.map { ($0, .completed(nil)) })
            for (key, value) in successes { entries[key] = .completed(value) }
        }

        func value(for key: SpinTrialKey, resolve: () -> S?) -> S? {
            condition.lock()
            while true {
                switch entries[key] {
                case .completed(let result): condition.unlock(); return result
                case .running: condition.wait()
                case nil:
                    entries[key] = .running
                    condition.unlock()
                    let result = resolve()
                    condition.lock()
                    entries[key] = .completed(result)
                    condition.broadcast()
                    condition.unlock()
                    return result
                }
            }
        }
    }

    static func minimumSpinRepresentatives<S: RankableSolution>(
        _ solutions: [S], spinXValues: [Float], cancellation: PredictionCancellation? = nil,
        previouslyAttempted: Set<SpinTrialKey> = [], parallelTrials: Bool = false,
        resolve: (S, Float) -> S?
    ) -> [S] {
        let signs: [Float] = [-1, 1].filter { sign in spinXValues.contains { $0 * sign > 0 } }
        var successesByKey: [SpinTrialKey: S] = [:]
        for candidate in solutions {
            successesByKey[SpinTrialKey(rails: candidate.searchKey, spin: candidate.spinX)] = candidate
        }
        let memo = SpinTrialMemo(attempted: previouslyAttempted, successes: successesByKey)
        let routeGroups = groups(solutions)
        // Spend the bounded worker budget across independent routes, avoiding the per-spin
        // barrier that often left only two workers active. Small catalogs keep trial parallelism
        // so a single expensive route does not lose its two-sign concurrency.
        let refinableGroups = routeGroups.filter { $0.members[0].spinX != 0 }.count
        let parallelGroups = parallelTrials && refinableGroups >= 4
        let out = evaluateInOrder(routeGroups, parallel: parallelGroups, cancellation: cancellation) { group -> S? in
            guard cancellation?.isCancelled != true else { return nil }
            var best = group.members[0]
            if best.spinX == 0 { return best }
            var seeds: [S] = []
            for member in group.members where !seeds.contains(where: { $0.searchKey == member.searchKey }) {
                seeds.append(member)
            }
            // Each route retains its original sequential magnitude search, both signs,
            // disconnected windows and repeated minimization after its measured route moves.
            while best.spinX != 0, let reference = best.route {
                var chosen: S?
                let steps = Int((abs(best.spinX) / minimumSpinStep).nextDown.rounded(.up))
                for step in 0..<max(0, steps) {
                    let magnitude = Float(step) * minimumSpinStep
                    let spins: [Float] = step == 0 ? [0] : signs.map { $0 * magnitude }
                    let jobs = spins.flatMap { sx in seeds.map { (seed: $0, spin: sx) } }
                    let evaluated = evaluateInOrder(jobs, parallel: parallelTrials && !parallelGroups,
                                                    cancellation: cancellation) { job -> S? in
                        let key = SpinTrialKey(rails: job.seed.searchKey, spin: job.spin)
                        return memo.value(for: key) {
                            guard cancellation?.isCancelled != true else { return nil }
                            return resolve(job.seed, job.spin)
                        }
                    }
                    guard cancellation?.isCancelled != true else { return nil }
                    let successes = evaluated.compactMap { $0 }.filter { candidate in
                        candidate.route.map { reference.matches($0) } ?? false
                    }
                    if let winner = successes.sorted(by: preferred).first { chosen = winner; break }
                }
                guard let chosen, abs(chosen.spinX) < abs(best.spinX) else { break }
                best = chosen
            }
            return best
        }.compactMap { $0 }
        return cancellation?.isCancelled == true ? [] : out
    }

    /// Independent simulations own their engine/recorder. Only result slots are written
    /// concurrently; cache mutation, route selection and ranking stay in deterministic order.
    private static func evaluateInOrder<Input, Output>(
        _ inputs: [Input], parallel: Bool, cancellation: PredictionCancellation?,
        evaluate: (Input) -> Output?
    ) -> [Output?] {
        var results = [Output?](repeating: nil, count: inputs.count)
        let workers = parallel ? min(4, min(inputs.count, ProcessInfo.processInfo.activeProcessorCount)) : 1
        if workers > 1 {
            results.withUnsafeMutableBufferPointer { buffer in
                let base = buffer.baseAddress!
                DispatchQueue.concurrentPerform(iterations: workers) { worker in
                    for index in stride(from: worker, to: inputs.count, by: workers) {
                        guard cancellation?.isCancelled != true else { return }
                        (base + index).pointee = evaluate(inputs[index])
                    }
                }
            }
        } else {
            for (index, input) in inputs.enumerated() {
                guard cancellation?.isCancelled != true else { break }
                results[index] = evaluate(input)
            }
        }
        return results
    }

    struct SpinTrialKey: Hashable {
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
