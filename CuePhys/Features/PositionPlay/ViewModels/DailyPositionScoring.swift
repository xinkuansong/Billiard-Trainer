import Foundation
import SceneKit

extension PlanThreeRole {
    var selectionPrompt: String {
        switch self {
        case .ball1: return "请选择第一颗球"
        case .pocket1: return "请选择第一颗球的袋口"
        case .ball2: return "请选择第二颗球"
        case .pocket2: return "请选择第二颗球的袋口"
        case .ball3: return "请选择第三颗球"
        }
    }
}

/// A nil scoring state in a draft or completion means scoring was never enabled.
struct DailyScoreSummary: Codable {
    private(set) var total = 0.0
    private(set) var count = 0
    private(set) var last: MultiBallPositionScore.Result?

    mutating func record(_ score: MultiBallPositionScore.Result) {
        total += score.value
        count += 1
        last = score
    }

    var text: String {
        guard count > 0 else { return "本局无可评分杆" }
        return String(format: "平均走位 %.1f 分 · 计分 %d 杆", total / Double(count), count)
    }
}

struct DailyShotPlan: Codable, Equatable {
    var first: String?
    var firstPocket: Int?
    var second: String?
    var secondPocket: Int?
    var third: String?
    var step: PlanThreeRole = .ball1

    var prompt: String { step.selectionPrompt }

    func role(of key: String) -> Int? { [first, second, third].firstIndex { $0 == key } }

    func candidates(_ role: PlanThreeRole, in draft: DailyClearanceDraft) -> Set<String> {
        let balls = Set(draft.board?.onTable.keys.map { $0 } ?? []).subtracting([PositionPlayBall.cueKey])
        if role == .ball1 || role == .pocket1 {
            return DailyClearanceRulesEngine(game: draft.game, state: draft.ruleState).legalTargetKeys(tableKeys: balls)
        }
        guard let first else { return [] }
        var rest = balls.subtracting([first])
        if role == .ball3 {
            guard let second else { return [] }
            rest.remove(second)
        }
        if draft.game != .chineseEightBall {
            return rest.min(by: { (PositionPlayBall.number(for: $0) ?? 99) < (PositionPlayBall.number(for: $1) ?? 99) }).map { [$0] } ?? []
        }
        guard first != "_8", !(role == .ball3 && second == "_8"),
              let group = draft.ruleState.assignedGroup ?? DailyClearanceBallGroup.of(first) else { return [] }
        let own = rest.filter { DailyClearanceBallGroup.of($0) == group }
        return own.isEmpty ? rest.intersection(["_8"]) : own
    }

    func editableSteps(in draft: DailyClearanceDraft) -> [PlanThreeRole] {
        var steps: [PlanThreeRole] = [.ball1, .pocket1]
        if !candidates(.ball2, in: draft).isEmpty { steps += [.ball2, .pocket2] }
        if !candidates(.ball3, in: draft).isEmpty { steps.append(.ball3) }
        return steps.filter { draft.game == .chineseEightBall || !$0.isBall }
    }

    func missingStep(in draft: DailyClearanceDraft) -> PlanThreeRole? {
        editableSteps(in: draft).first {
            switch $0 {
            case .ball1: return first == nil
            case .pocket1: return firstPocket == nil
            case .ball2: return second == nil
            case .pocket2: return secondPocket == nil
            case .ball3: return third == nil
            }
        }
    }

    mutating func advance(in draft: DailyClearanceDraft) {
        if draft.game != .chineseEightBall {
            first = candidates(.ball1, in: draft).first
            second = candidates(.ball2, in: draft).first
            third = candidates(.ball3, in: draft).first
        }
        step = missingStep(in: draft) ?? editableSteps(in: draft).last ?? .pocket1
    }

    mutating func goBack(in draft: DailyClearanceDraft) {
        let steps = editableSteps(in: draft)
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
        if step == .ball1 { firstPocket = nil }
        if step.rawValue < PlanThreeRole.ball2.rawValue, draft.game == .chineseEightBall { second = nil }
        if step.rawValue < PlanThreeRole.pocket2.rawValue { secondPocket = nil }
        if draft.game == .chineseEightBall { third = nil }
    }

    mutating func choose(ball: String, in draft: DailyClearanceDraft) -> Bool {
        guard draft.game == .chineseEightBall, step.isBall, candidates(step, in: draft).contains(ball) else { return false }
        switch step {
        case .ball1:
            first = ball; firstPocket = nil; second = nil; secondPocket = nil; third = nil
        case .ball2:
            second = ball; secondPocket = nil; third = nil
        case .ball3: third = ball
        default: return false
        }
        advance(in: draft)
        return true
    }

    mutating func choose(pocket: Int, in draft: DailyClearanceDraft) -> Bool {
        guard (0..<6).contains(pocket) else { return false }
        switch step {
        case .pocket1: firstPocket = pocket
        case .pocket2: secondPocket = pocket
        default: return false
        }
        advance(in: draft)
        return true
    }

    func continuation(in draft: DailyClearanceDraft) -> Self {
        var next = Self()
        if let second, next.candidates(.ball1, in: draft).contains(second) {
            next.first = second
            next.firstPocket = secondPocket
            if let third, next.candidates(.ball2, in: draft).contains(third) { next.second = third }
        }
        next.advance(in: draft)
        return next
    }
}

struct DailyPositionScoring: Codable {
    var enabled = true
    var plan = DailyShotPlan()
    var summary = DailyScoreSummary()
    var failureMessage: String?

    /// Input coordinates are physical engine X/Z metres, before any rule-driven respot.
    mutating func settle(_ facts: ShotFacts, ruling: DailyClearanceRuling, frozen: DailyShotPlan,
                         draft: DailyClearanceDraft) -> String? {
        if ruling.failed { failureMessage = ruling.message }
        plan = DailyShotPlan()
        plan.advance(in: draft)
        guard let first = frozen.first, let called = frozen.firstPocket, let second = frozen.second,
              let pocket = frozen.secondPocket, !ruling.completed else { return nil }
        guard let rest = facts.scoringRest else { return "本杆未评分 · 缺少停稳球位" }
        let actual = facts.pocketIDs[first]
        if facts.pocketedKeys.contains(first), actual == nil { return "本杆未评分 · 缺少落袋记录" }
        let reason: String?
        if ruling.foul || ruling.failed { reason = ruling.foulReason ?? ruling.message }
        else if !facts.pocketedKeys.contains(first) { reason = "第一球未进" }
        else if actual != "pocket_\(called)" { reason = "第一球未进指定袋" }
        else if ruling.changedTurn { reason = "本杆换手" }
        else { reason = nil; plan = frozen.continuation(in: draft) }
        let score = MultiBallPositionScore.evaluate(positions: rest.mapValues { SCNVector3($0.x, 0, $0.y) },
            target: second, pocket: pocket, third: frozen.third, failure: reason, surfaceY: 0)
        summary.record(score)
        return score.text
    }
}
