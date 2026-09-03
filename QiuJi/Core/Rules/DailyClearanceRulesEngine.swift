import Foundation

/// 每日清台支持的玩法。4/5/6 球沿用 9 球系规则，并固定以 9 号为终局球。
enum DailyClearanceGame: String, Codable, CaseIterable, Identifiable, Equatable {
    case chineseEightBall
    case nineBall
    case sixBall
    case fiveBall
    case fourBall

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chineseEightBall: return "中八"
        case .nineBall: return "9 球"
        case .sixBall: return "6 球"
        case .fiveBall: return "5 球"
        case .fourBall: return "4 球"
        }
    }

    var rackGame: RackGame {
        switch self {
        case .chineseEightBall: return .chineseEightBall
        case .nineBall: return .nineBall
        case .sixBall: return .zhuifen(balls: 6)
        case .fiveBall: return .zhuifen(balls: 5)
        case .fourBall: return .zhuifen(balls: 4)
        }
    }

    var terminalBallKey: String {
        self == .chineseEightBall ? "_8" : "_9"
    }

    static func initialDefault(for preferredSport: PreferredSport) -> DailyClearanceGame {
        switch preferredSport {
        case .chinese8, .both: return .chineseEightBall
        case .nineBall: return .nineBall
        }
    }
}

enum DailyClearanceBallGroup: String, Codable, Equatable {
    case solid
    case stripe

    var displayName: String { self == .solid ? "全色" : "花色" }

    fileprivate static func of(_ key: String) -> DailyClearanceBallGroup? {
        guard let number = PositionPlayBall.number(for: key) else { return nil }
        if (1...7).contains(number) { return .solid }
        if (9...15).contains(number) { return .stripe }
        return nil
    }
}

enum DailyClearanceRuleStatus: String, Codable, Equatable {
    case active
    case completed
    case failed
}

/// 可随草稿持久化的纯规则状态。
struct DailyClearanceRuleState: Codable {
    var assignedGroup: DailyClearanceBallGroup?
    var status: DailyClearanceRuleStatus

    init(assignedGroup: DailyClearanceBallGroup? = nil,
         status: DailyClearanceRuleStatus = .active) {
        self.assignedGroup = assignedGroup
        self.status = status
    }
}

struct DailyClearanceRuling {
    var foul = false
    var foulReason: String?
    var ballInHand = false
    var completed = false
    var failed = false
    var message: String
}

/// 每日清台的单人规则状态机。普通犯规只给自由球并继续，不发生玩家轮转。
struct DailyClearanceRulesEngine {
    let game: DailyClearanceGame
    private(set) var state: DailyClearanceRuleState

    init(game: DailyClearanceGame,
         state: DailyClearanceRuleState = DailyClearanceRuleState()) {
        self.game = game
        self.state = state
    }

    func legalTargetKeys(tableKeys: Set<String>) -> Set<String> {
        guard state.status == .active else { return [] }
        switch game {
        case .chineseEightBall:
            guard let group = state.assignedGroup else {
                return Set(tableKeys.filter {
                    DailyClearanceBallGroup.of($0) != nil
                })
            }
            let ownKeys = Set(tableKeys.filter { DailyClearanceBallGroup.of($0) == group })
            return ownKeys.isEmpty && tableKeys.contains("_8") ? ["_8"] : ownKeys

        case .nineBall, .sixBall, .fiveBall, .fourBall:
            guard let lowest = tableKeys.compactMap(PositionPlayBall.number(for:)).min() else {
                return []
            }
            return ["_\(lowest)"]
        }
    }

    @discardableResult
    mutating func judge(_ facts: ShotFacts) -> DailyClearanceRuling {
        guard state.status == .active else {
            return DailyClearanceRuling(
                completed: state.status == .completed,
                failed: state.status == .failed,
                message: state.status == .completed ? "本局已完成" : "本局已结束"
            )
        }

        switch game {
        case .chineseEightBall:
            return judgeChineseEightBall(facts)
        case .nineBall, .sixBall, .fiveBall, .fourBall:
            return judgeNineBallFamily(facts)
        }
    }

    private mutating func judgeChineseEightBall(_ facts: ShotFacts) -> DailyClearanceRuling {
        let legalTargets = legalTargetKeys(tableKeys: facts.tableKeysBefore)
        let foulReason = commonFoulReason(facts, legalTargets: legalTargets)
        let eightPocketed = facts.pocketedKeys.contains("_8")

        if eightPocketed {
            let groupCleared = state.assignedGroup != nil && legalTargets == ["_8"]
            if foulReason == nil && groupCleared {
                state.status = .completed
                return DailyClearanceRuling(completed: true, message: "8 号合法落袋，完成今日清台")
            }

            state.status = .failed
            let reason = foulReason ?? (state.assignedGroup == nil ? "开放局进 8 号" : "本组球未清空")
            return DailyClearanceRuling(
                foul: foulReason != nil,
                foulReason: foulReason,
                ballInHand: false,
                failed: true,
                message: "8 号提前落袋（\(reason)），本局结束"
            )
        }

        if let foulReason {
            return DailyClearanceRuling(
                foul: true,
                foulReason: foulReason,
                ballInHand: true,
                message: "犯规：\(foulReason)，自由球继续"
            )
        }

        if state.assignedGroup == nil,
           let firstPocketedGroup = facts.pocketedKeys.lazy.compactMap(DailyClearanceBallGroup.of).first {
            state.assignedGroup = firstPocketedGroup
            return DailyClearanceRuling(message: "已定组：\(firstPocketedGroup.displayName)")
        }

        return DailyClearanceRuling(message: "继续清台")
    }

    private mutating func judgeNineBallFamily(_ facts: ShotFacts) -> DailyClearanceRuling {
        let legalTargets = legalTargetKeys(tableKeys: facts.tableKeysBefore)
        let foulReason = commonFoulReason(facts, legalTargets: legalTargets)
        let terminalPocketed = facts.pocketedKeys.contains("_9")

        if terminalPocketed {
            if let foulReason {
                state.status = .failed
                return DailyClearanceRuling(
                    foul: true,
                    foulReason: foulReason,
                    ballInHand: false,
                    failed: true,
                    message: "犯规进 9 号（\(foulReason)），本局结束"
                )
            }
            state.status = .completed
            return DailyClearanceRuling(completed: true, message: "9 号合法落袋，完成今日清台")
        }

        if let foulReason {
            return DailyClearanceRuling(
                foul: true,
                foulReason: foulReason,
                ballInHand: true,
                message: "犯规：\(foulReason)，自由球继续"
            )
        }

        return DailyClearanceRuling(message: "继续清台")
    }

    private func commonFoulReason(_ facts: ShotFacts,
                                  legalTargets: Set<String>) -> String? {
        guard let first = facts.firstContactKey else { return "空杆：未触任何球" }
        if !legalTargets.contains(first) {
            return "首触球不合法"
        }
        if facts.cuePocketed {
            return "母球落袋"
        }
        if facts.pocketedKeys.isEmpty && !facts.railOrPocketAfterContact {
            return "触球后无球碰库"
        }
        return nil
    }
}
