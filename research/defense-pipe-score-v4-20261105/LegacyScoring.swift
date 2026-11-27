import Foundation
import SceneKit

struct LegacyDefenseEffect: Codable {
    static let version = "defense-physical-paired-angle008-comfort-v3"
    static let blockedPotScore = 95.0 // Good safety, distinct from a complete direct-hit block.
    static let threshold = 0.008 // degrees, not radians or object-ball window width.
    let scoringVersion: String
    let failure: String?
    let fullDirectBlock: Bool
    let cueToleranceDegrees: Double?
    let comfort: Double?
    let opponentBallNumber: Int
    let score: Double?
    let unavailableReason: String?
    var potContactsBlocked: Bool? = nil
    var attackRoute: LegacyDefensePhysicalAttack.Route? = nil

    /// Training score: a reciprocal tail preserves useful credit beyond the bank's
    /// strict reference-admission scale. At that scale the factor is 1/2, not near zero.
    static func angleFactor(_ degrees: Double) -> Double? {
        guard degrees.isFinite, degrees >= 0 else { return nil }
        return threshold / (threshold + degrees)
    }
    static func value(tolerance: Double, comfort: Double) -> Double? {
        guard let factor = angleFactor(tolerance), comfort.isFinite, (0...100).contains(comfort) else { return nil }
        return sqrt(100 * factor * (100 - comfort))
    }
    static func failure(_ q: DefenseBankQuestion, _ p: ShotPrediction) -> String? {
        if p.cuePocketed || p.pocketedBalls.contains(ShotInput.cueBallName) { return "母球落袋" }
        if p.pocketedBalls.contains("_8") { return "8号球进袋，本次防守结束" }
        if p.pocketedBalls.contains("_\(q.ownBallNumber)") { return "我方球进袋，未完成纯防守任务" }
        guard let index = p.events.firstIndex(where: { if case .ballBall = $0.kind { return true }; return false }),
              case let .ballBall(a, b) = p.events[index].kind,
              Set([a,b]) == Set([ShotInput.cueBallName, "_\(q.ownBallNumber)"]) else { return "未先碰我方目标球" }
        guard p.events.dropFirst(index+1).contains(where: { switch $0.kind { case .ballCushion, .pocket: true; default: false } }) else { return "碰球后没有球碰库或进袋" }
        return nil
    }
    struct Timing {
        var geometrySeconds = 0.0, physicalSeconds = 0.0, blockConfirmationSeconds = 0.0
        var tableHits = 0, exactWindows = 0
    }
    static func evaluate(question q: DefenseBankQuestion, prediction p: ShotPrediction,
                         usePrecomputedWindows: Bool = true, diagnostics: ((Timing) -> Void)? = nil) throws -> Self {
        var timing = Timing()
        defer { diagnostics?(timing) }
        guard p.hasFinalTableState else { throw SeparationQuestionGenerator.Failure.incomplete }
        let active = ([ShotInput.cueBallName] + q.keys).filter { !p.pocketedBalls.contains($0) }
        for (index, name) in active.enumerated() {
            guard let position = p.finalPositions[name], position.x.isFinite, position.z.isFinite else { throw SeparationQuestionGenerator.Failure.incomplete }
            for other in active.dropFirst(index+1) {
                guard let next = p.finalPositions[other], position.distanceXZ(to:next) >= 2*BallPhysics.radius-0.00001 else { throw SeparationQuestionGenerator.Failure.incomplete }
            }
        }
        let opponent = p.pocketedBalls.contains("_\(q.opponentBallNumber)") ? 8 : q.opponentBallNumber
        if let reason = failure(q,p) { return .init(scoringVersion: version, failure: reason, fullDirectBlock: false, cueToleranceDegrees: nil, comfort: nil, opponentBallNumber: opponent, score: 0, unavailableReason: nil) }
        guard let cue = p.finalPositions[ShotInput.cueBallName], let target = p.finalPositions["_\(opponent)"] else { throw SeparationQuestionGenerator.Failure.incomplete }
        let blockers = q.keys.filter { $0 != "_\(opponent)" && !p.pocketedBalls.contains($0) }.compactMap { p.finalPositions[$0] }
        if fullyBlocked(cue, target, blockers) {
            return .init(scoringVersion: version, failure: nil, fullDirectBlock: true, cueToleranceDegrees: 0, comfort: 0, opponentBallNumber: opponent, score: 100, unavailableReason: nil)
        }
        try Task.checkCancellation()
        var assessment = DefenseAttackAssessment()
        assessment.usePrecomputedWindows = usePrecomputedWindows
        typealias P = DefenseAttackAssessment.P
        func point(_ v: SCNVector3) -> P { P(Double(v.x), Double(v.z)) }
        let c = point(cue), t = point(target), others = blockers.map(point)
        let geometryStart = ProcessInfo.processInfo.systemUptime
        let attack = assessment.attack(c, t, others, step: 0.01)
        var options = attack["options"] as! [[String: Any]]
        timing.geometrySeconds = ProcessInfo.processInfo.systemUptime - geometryStart
        timing.tableHits = assessment.tableHits; timing.exactWindows = assessment.windowCalls
        let physicalStart = ProcessInfo.processInfo.systemUptime
        let physical = try LegacyDefensePhysicalAttack.assess(cue: cue, target: target,
            obstacles: q.keys.filter { $0 != "_\(opponent)" && !p.pocketedBalls.contains($0) }
                .compactMap { name in p.finalPositions[name].map { ObstacleBall(name: name, position: $0) } },
            geometricOptions: options)
        timing.physicalSeconds = ProcessInfo.processInfo.systemUptime - physicalStart
        if let route = physical.best, !physical.incomplete {
            var result = Self(scoringVersion: version, failure: nil, fullDirectBlock: false,
                cueToleranceDegrees: route.tolerance, comfort: route.comfort, opponentBallNumber: opponent,
                score: route.score, unavailableReason: nil)
            result.attackRoute = route
            return result
        }
        // All six pockets must have a resolved object-ball opening but no
        // accessible pot contact. A missing clean window is NOT blocking proof.
        func contactsBlocked(_ options: [[String: Any]]) -> Bool { options.count == 6 && options.allSatisfy {
            ($0["objectWidth"] as? Double ?? 0) > 0 && ($0["status"] as? String) == "inaccessible"
        } }
        // Interpolation is approximate: do not award a high safety score solely
        // because an interpolated window missed a tiny reachable pot contact.
        if physical.routes.isEmpty, !physical.incomplete, contactsBlocked(options), assessment.tableHits > 0 {
            let start = ProcessInfo.processInfo.systemUptime
            assessment.usePrecomputedWindows = false
            assessment.cache = assessment.cache.filter { $0.value["precomputed"] as? Bool != true }
            options = assessment.attack(c, t, others, step: 0.01)["options"] as! [[String: Any]]
            timing.blockConfirmationSeconds = ProcessInfo.processInfo.systemUptime - start
            timing.exactWindows = assessment.windowCalls
        }
        let blocked = contactsBlocked(options)
        if physical.routes.isEmpty, !physical.incomplete, blocked,
           assessment.edges == 0, assessment.windowDiff <= 0.001, !assessment.incompleteComfort {
            var result = Self(scoringVersion: version, failure: nil, fullDirectBlock: false,
                cueToleranceDegrees: nil, comfort: nil, opponentBallNumber: opponent,
                score: blockedPotScore, unavailableReason: nil)
            result.potContactsBlocked = true
            return result
        }
        return .init(scoringVersion: version, failure: nil, fullDirectBlock: false,
            cueToleranceDegrees: nil, comfort: nil, opponentBallNumber: opponent, score: nil,
            unavailableReason: physical.incomplete ? "进袋路线评估尚未完成；不计均分" : "尚未确认可用进袋路线；不计均分")
    }

    /// Continuous angular coverage, same conservative proof as the source bank.
    static func fullyBlocked(_ c: SCNVector3, _ t: SCNVector3, _ blockers: [SCNVector3]) -> Bool {
        let d = Double(c.distanceXZ(to:t)), r = Double(2*BallPhysics.radius)
        guard d > r else { return false }
        let h = asin(r/d), at = atan2(Double(t.z-c.z), Double(t.x-c.x))
        var intervals = [(Double,Double)]()
        for b in blockers {
            let db = Double(c.distanceXZ(to:b)); if db <= r || d-db-2*r <= 0 { continue }
            let a = atan2(Double(b.z-c.z), Double(b.x-c.x))-at
            let delta = atan2(sin(a),cos(a)), half = asin(r/db)
            intervals.append((max(-h,delta-half+1e-6),min(h,delta+half-1e-6)))
        }
        var end = -h, covered = 0.0
        for (a,b) in intervals.sorted(by: { $0.0 < $1.0 }) where b > a {
            if b > end { covered += max(0,b-max(a,end)); end = b }
        }
        return covered/(2*h) >= 1-1e-12
    }
    var scoreText: String { score.map { String(format: "%.1f", $0) } ?? "未评分" }
    var resultText: String {
        if let failure { return failure }
        if score != nil { return "防守效果 \(scoreText) 分" }
        return "未评分：" + (unavailableReason ?? "评估信息不足；不计均分")
    }
    var detail: String {
        if let failure { return "规则判定：\(failure)\n防守得分：0" }
        if fullDirectBlock { return "规则判定：合法\n对方目标：\(opponentBallNumber)号\n直线通路：完整遮挡\n防守得分：100" }
        if let unavailableReason { return "规则判定：合法\n\(unavailableReason)" }
        if potContactsBlocked == true {
            return "规则判定：合法\n对方目标：\(opponentBallNumber)号\n进攻机会：进袋下球点受阻\n防守得分：\(scoreText)\n仍可碰到目标球；区别于完整遮挡。"
        }
        let factor = [Self.version, "defense-reciprocal-angle008-comfort-v2"].contains(scoringVersion) ? "[1 / (1 + 容错角/0.008°)]" : "平滑容错因子"
        return String(format: "规则判定：合法\n对方目标：%d号\n容错角：%.6f°\n参考尺度：0.008°\n进攻舒适分：%.2f\n防守得分：%.1f\n临时评分：√[100 × %@ × (100−舒适分)]\n只评估当前模型内的直进机会（含本袋袋角）。", opponentBallNumber, cueToleranceDegrees ?? 0, comfort ?? 0, score ?? 0, factor)
    }
}

enum LegacyDefensePhysicalAttack {
    static let speeds: [Float] = [0.8, 1.4, 2.2]
    static let boundaryPrecision = 0.00025 // degrees
    struct Route: Codable {
        let pocket: Int
        let speed: Float
        let direction, aim: [Float]
        let leftDegrees, rightDegrees, tolerance, comfort: Double
        var score: Double { LegacyDefenseEffect.value(tolerance: tolerance, comfort: comfort)! }
    }
    struct Result {
        var routes: [Route] = []
        var incomplete = false
        var best: Route? { routes.min { $0.score < $1.score } }
    }

    static func assess(cue: SCNVector3, target: SCNVector3, obstacles: [ObstacleBall],
                       geometricOptions: [[String: Any]]) throws -> Result {
        var result = Result()
        let surface = cue.y - BallPhysics.radius
        for pocket in 0..<6 {
            for speed in speeds {
                try Task.checkCancellation()
                var input = ShotInput(simulationModel: .appDefault, cueBall: cue, targetBall: target,
                    pocketIndex: pocket, velocity: speed, spinX: 0, spinY: 0,
                    surfaceY: surface, obstacles: obstacles)
                var prediction = ShotPredictor.predict(input, maxEvents: 1500, maxTime: 60)
                if prediction.feasible && !prediction.hasResolvedSearchState { result.incomplete = true }
                // An obstacle can cover the usual aim while leaving a side of the
                // opening accessible. Reuse that window's reachable aim as a seed.
                if !ShotPredictor.isDirectPot(prediction, pocketIndex: pocket),
                   let option = geometricOptions.first(where: { ($0["pocket"] as? Int) == pocket }),
                   let aim = option["aim"] as? [Double], aim.count == 2 {
                    input.pocketAimOverride = .init(Float(aim[0]), target.y, Float(aim[1]))
                    prediction = ShotPredictor.predict(input, maxEvents: 1500, maxTime: 60)
                    if prediction.feasible && !prediction.hasResolvedSearchState { result.incomplete = true }
                }
                guard ShotPredictor.isDirectPot(prediction, pocketIndex: pocket) else { continue }
                if let route = try measure(input: input, seed: prediction) { result.routes.append(route) }
                else { result.incomplete = true }
            }
        }
        return result
    }

    /// Replays the exact strike, without re-solving aim at each probe. This is the
    /// same collision engine and direct-pot judgement used by the production solver.
    static func replay(input: ShotInput, direction: SCNVector3) throws -> ShotPrediction {
        try Task.checkCancellation()
        return ShotPredictor.simulateFree(cueBall: input.cueBall, aimDir: direction,
            velocity: input.velocity, spinX: 0, spinY: 0, surfaceY: input.surfaceY,
            balls: [.init(name: ShotInput.targetBallName, position: input.targetBall)] + input.obstacles,
            maxEvents: 1500, maxTime: 60, includePresentation: false,
            simulationModel: input.simulationModel, recordedStrikeDirection: direction)
    }

    static func measure(input: ShotInput, seed: ShotPrediction) throws -> Route? {
        let direction = seed.strikeDirection ?? seed.aimDirection
        let base = atan2(Double(direction.z), Double(direction.x))
        let center = try replay(input: input, direction: direction)
        guard center.hasResolvedSearchState, ShotPredictor.isDirectPot(center, pocketIndex: input.pocketIndex),
              let comfort = ShotComfortScore.evaluate(cue: (Double(input.cueBall.x), Double(input.cueBall.z)),
                ball: (Double(input.targetBall.x), Double(input.targetBall.z)),
                aim: (Double(seed.pocketAimPoint.x), Double(seed.pocketAimPoint.z))) else { return nil }
        func succeeds(_ offset: Double) throws -> Bool? {
            let angle = base + offset * .pi / 180
            let d = SCNVector3(Float(cos(angle)), 0, Float(sin(angle)))
            let p = try replay(input: input, direction: d)
            guard p.hasResolvedSearchState else { return nil }
            return ShotPredictor.isDirectPot(p, pocketIndex: input.pocketIndex)
        }
        // The entire direct-hit cone is a hard upper bound, not an arbitrary
        // solver search span. An open limit cannot become a measured endpoint.
        let distance = Double(input.cueBall.distanceXZ(to: input.targetBall))
        let limit = 2 * asin(min(1, Double(2 * BallPhysics.radius) / distance)) * 180 / .pi + 0.1
        func edge(_ sign: Double) throws -> Double? {
            var inside = 0.0, step = 0.001
            while inside < limit {
                let outside = min(limit, inside + step)
                guard let yes = try succeeds(sign * outside) else { return nil }
                if !yes {
                    var low = inside, high = outside
                    while high - low > boundaryPrecision {
                        let mid = (low + high) / 2
                        guard let valid = try succeeds(sign * mid) else { return nil }
                        if valid { low = mid } else { high = mid }
                    }
                    return sign * low
                }
                inside = outside
                step = min(0.025, step * 1.5)
            }
            return nil
        }
        guard let left = try edge(-1), let right = try edge(1), right - left > boundaryPrecision else { return nil }
        return .init(pocket: input.pocketIndex, speed: input.velocity,
            direction: [direction.x, direction.z], aim: [seed.pocketAimPoint.x, seed.pocketAimPoint.z],
            leftDegrees: left, rightDegrees: right, tolerance: right - left, comfort: comfort.total)
    }
}
