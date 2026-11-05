import Foundation
import SceneKit

struct DefenseEffect: Codable {
    static let version = "defense-target-pipe-always-scored-v8"
    static let blockedPotScore = 100.0 // User-confirmed: blocked pot contacts earn full marks.
    static let pipeReferenceDegrees = 1.0 // User-confirmed target-pipe scoring scale.
    let scoringVersion: String
    let failure: String?
    let fullDirectBlock: Bool
    let cueToleranceDegrees: Double?
    let comfort: Double?
    let opponentBallNumber: Int
    let score: Double?
    let unavailableReason: String?
    var potContactsBlocked: Bool? = nil
    var attackRoute: DefensePhysicalAttack.Route? = nil

    var targetPipeToleranceDegrees: Double? = nil
    var pipeRoute: DefenseAttackAssessment.PipeRoute? = nil
    var estimateReason: String? = nil

    /// Slow reciprocal decay in target-pipe degrees; comfort belongs to the same route.
    static func angleFactor(_ degrees: Double) -> Double? {
        guard degrees.isFinite, degrees >= 0 else { return nil }
        return pipeReferenceDegrees / (pipeReferenceDegrees + degrees)
    }
    static func value(pipeDegrees: Double, comfort: Double) -> Double? {
        guard let factor = angleFactor(pipeDegrees), comfort.isFinite, (0...100).contains(comfort) else { return nil }
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
            return .init(scoringVersion: version, failure: nil, fullDirectBlock: true, cueToleranceDegrees: nil, comfort: nil, opponentBallNumber: opponent, score: 100, unavailableReason: nil)
        }
        try Task.checkCancellation()
        var assessment = DefenseAttackAssessment()
        assessment.usePrecomputedWindows = usePrecomputedWindows
        typealias P = DefenseAttackAssessment.P
        func point(_ v: SCNVector3) -> P { P(Double(v.x), Double(v.z)) }
        let c = point(cue), t = point(target), others = blockers.map(point)
        let geometryStart = ProcessInfo.processInfo.systemUptime
        var attack = try assessment.pipeAttack(c, t, others)
        timing.geometrySeconds = ProcessInfo.processInfo.systemUptime - geometryStart
        timing.tableHits = assessment.tableHits; timing.exactWindows = assessment.windowCalls
        // Approximate interpolation alone cannot establish a high defensive grade.
        if attack.routes.isEmpty, assessment.tableHits > 0 {
            let start = ProcessInfo.processInfo.systemUptime
            assessment.usePrecomputedWindows = false
            assessment.cache = assessment.cache.filter { $0.value["precomputed"] as? Bool != true }
            attack = try assessment.pipeAttack(c, t, others)
            timing.blockConfirmationSeconds = ProcessInfo.processInfo.systemUptime - start
            timing.exactWindows = assessment.windowCalls
        }
        let reliable = assessment.edges == 0 && assessment.windowDiff <= 0.001 && !assessment.incompleteComfort
        if reliable, let route = attack.best {
            var result = Self(scoringVersion: version, failure: nil, fullDirectBlock: false,
                cueToleranceDegrees: nil, comfort: route.comfort, opponentBallNumber: opponent,
                score: route.score, unavailableReason: nil)
            result.targetPipeToleranceDegrees = route.tolerance
            result.pipeRoute = route
            return result
        }
        if reliable, attack.allPotContactsBlocked {
            var result = Self(scoringVersion: version, failure: nil, fullDirectBlock: false,
                cueToleranceDegrees: nil, comfort: nil, opponentBallNumber: opponent,
                score: blockedPotScore, unavailableReason: nil)
            result.potContactsBlocked = true
            return result
        }
        // Every completed legal stroke receives a score. Lack of a clean-window
        // certificate enters the formula branch; it never implies full blocking.
        let estimated = try assessment.estimatedAttack(c,t,others)
        if let route = [attack.best,estimated].compactMap({$0}).min(by:{$0.score<$1.score}) {
            var result=Self(scoringVersion:version,failure:nil,fullDirectBlock:false,cueToleranceDegrees:nil,
                comfort:route.comfort,opponentBallNumber:opponent,score:route.score,unavailableReason:nil)
            result.targetPipeToleranceDegrees=route.tolerance;result.pipeRoute=route
            result.estimateReason="精确进球窗口未确认，按可达几何线路估算。"
            return result
        }
        // If even a geometric witness is numerically unresolved, give a
        // conservative LOWER defensive estimate using optimistic attack bounds.
        // These are labelled bounds, never presented as an actual viable route.
        let estimate=optimisticAttackBound(cue:c,ball:t,table:assessment.table)
        var result=Self(scoringVersion:version,failure:nil,fullDirectBlock:false,cueToleranceDegrees:nil,
            comfort:estimate.comfort,opponentBallNumber:opponent,score:estimate.score,unavailableReason:nil)
        result.targetPipeToleranceDegrees=estimate.degrees
        result.estimateReason="可行线路尚未确认，按对方进攻的有利几何上界保守估分。"
        return result
    }

    /// Upper bounds for the existing comfort model: allow the best distance
    /// scale, omit directional/adjacent rail penalties, and allow a straight pot.
    /// The capture envelope upper-bounds the target-pipe angle. The unchanged
    /// monotone formula then yields a lower defensive estimate, not a fixed score.
    static func optimisticAttackBound(cue:DefenseAttackAssessment.P,ball:DefenseAttackAssessment.P,
                                      table:TableGeometry) -> (degrees:Double,comfort:Double,score:Double) {
        let distance=(ball-cue).length,r=Double(AngleSceneCalculator.ballRadius)
        let near=max(0.2-distance,0)/0.16,far=max(distance-0.8,0)/0.75
        let distanceUpper=100*exp(-near*near-far*far)
        let hx=Double(AngleSceneCalculator.innerLength)/2,hz=Double(AngleSceneCalculator.innerWidth)/2
        let gaps=[hx-cue.x-r,hx+cue.x-r,hz-cue.z-r,hz+cue.z-r]
        let basePenalty=gaps.map { 45*exp(-pow(max($0,0)*100/8,1.2)) }.max()!
        let spaceUpper=100-basePenalty
        let comfortUpper=min(100,max(0,0.5*min(distanceUpper,spaceUpper)+0.5*pow(distanceUpper*spaceUpper*100,1.0/3)))
        let angleUpper=table.pockets.map { pocket -> Double in
            let reach=DefenseAttackAssessment.PipeReachability(cue:cue,ball:ball,obstacles:[],pocket:pocket)
            guard let envelope=reach.captureEnvelope else { return 360 }
            return (envelope.upperBound-envelope.lowerBound)*180/Double.pi
        }.max()!
        return (angleUpper,comfortUpper,value(pipeDegrees:angleUpper,comfort:comfortUpper)!)
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
            if [Self.version,"defense-target-pipe-continuous-block-v7"].contains(scoringVersion) {
                return "规则判定：合法\n对方目标：\(opponentBallNumber)号\n进攻机会：直接进球线路全部受阻\n进球管道或对应瞄准管道不可通过\n防守得分：\(scoreText)"
            }
            return "规则判定：合法\n对方目标：\(opponentBallNumber)号\n进攻机会：进袋下球点受阻\n防守得分：\(scoreText)\n仍可碰到目标球；区别于完整遮挡。"
        }
        if let estimateReason {
            let labels=pipeRoute == nil ? ("管道角估计上界","进攻舒适分估计上界"):("目标球管道容错角","同路线进攻舒适分")
            return String(format:"规则判定：合法\n对方目标：%d号\n防守得分：%.1f（估算）\n%@：%.6f°\n%@：%.2f\n%@\n仍使用1°参考尺度与原评分公式。",opponentBallNumber,score ?? 0,labels.0,targetPipeToleranceDegrees ?? 0,labels.1,comfort ?? 0,estimateReason)
        }
        if [Self.version, "defense-target-pipe-continuous-block-v7", "defense-target-pipe-angle1-block100-v6", "defense-target-pipe-angle1-zero-comfort-v5", "defense-target-pipe-angle1-comfort-v4"].contains(scoringVersion) {
            let note = pipeRoute?.zeroWidthEstimate == true ? "\n几何路线可达；无正宽管道，按0°计分。" : ""
            return String(format: "规则判定：合法\n对方目标：%d号\n目标球管道容错角：%.6f°\n参考尺度：1°\n同路线进攻舒适分：%.2f\n防守得分：%.1f\n评分：100 × √[(1−舒适分/100) / (1+管道角/1°)]", opponentBallNumber, targetPipeToleranceDegrees ?? 0, comfort ?? 0, score ?? 0) + note
        }
        let factor = ["defense-physical-paired-angle008-comfort-v3", "defense-reciprocal-angle008-comfort-v2"].contains(scoringVersion) ? "[1 / (1 + 容错角/0.008°)]" : "平滑容错因子"
        return String(format: "规则判定：合法\n对方目标：%d号\n容错角：%.6f°\n参考尺度：0.008°\n进攻舒适分：%.2f\n防守得分：%.1f\n临时评分：√[100 × %@ × (100−舒适分)]\n只评估当前模型内的直进机会（含本袋袋角）。", opponentBallNumber, cueToleranceDegrees ?? 0, comfort ?? 0, score ?? 0, factor)
    }
}
