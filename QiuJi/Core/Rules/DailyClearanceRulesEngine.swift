import Foundation

/// 每日清台支持的玩法。4/5/6 球沿用 9 球系规则，并固定以 9 号为终局球。
enum DailyClearanceGame: String, Codable, CaseIterable, Identifiable, Equatable {
    case chineseEightBall
    case nineBall
    case sixBall
    case fiveBall
    case fourBall

    var id: String { rawValue }

    /// Stable inventory includes pocketed balls; presentation only changes their opacity.
    var paletteKeys: [String] {
        let numbers: [Int]
        switch self {
        case .chineseEightBall: numbers = Array(1...15)
        case .nineBall: numbers = Array(1...9)
        case .sixBall: numbers = [1, 2, 3, 4, 5, 9]
        case .fiveBall: numbers = [1, 2, 3, 4, 9]
        case .fourBall: numbers = [1, 2, 3, 9]
        }
        return [PositionPlayBall.cueKey] + numbers.map { "_\($0)" }
    }


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
    var other: Self { self == .solid ? .stripe : .solid }

    static func of(_ key: String) -> DailyClearanceBallGroup? {
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

enum DailyCuePlacement: String, Codable { case none, anywhere, behindHeadString }
enum DailyBreakChoice: String, Codable, CaseIterable {
    case rerackByIncoming, rerackByBreaker, acceptBallInHand, acceptPosition, acceptBehindHeadString
    var label: String {
        switch self {
        case .rerackByIncoming: return "换方重新开球"
        case .rerackByBreaker: return "原方重新开球"
        case .acceptBallInHand: return "接受球形，全台自由球"
        case .acceptPosition: return "接受球形，原位击球"
        case .acceptBehindHeadString: return "接受球形，线后自由球"
        }
    }
}
enum DailyClearanceCompletionKind: String, Codable {
    case chineseEight, breakRun, systemBreakRun, laterVisit, combinationNine, breakNine, systemBreakNine
    var displayName: String {
        switch self {
        case .chineseEight: return "中八清台"
        case .breakRun: return "开球清台"
        case .systemBreakRun: return "一次上手清台（系统开球）"
        case .laterVisit: return "接续清台"
        case .combinationNine: return "组合进9完成"
        case .breakNine: return "开球进9完成"
        case .systemBreakNine: return "系统开球进9"
        }
    }
}

/// Version 1 drafts retain their original single-side rules until the user reracks.
struct DailyClearanceRuleState: Codable, Equatable {
    var assignedGroup: DailyClearanceBallGroup?
    var status: DailyClearanceRuleStatus
    var ruleVersion: Int
    var currentPlayer: RulesPlayer
    var visitCount: Int
    /// Actual visits started by a player. nil means an older archive cannot establish this count.
    var playedVisitCount: Int?
    var lastPlayedVisit: Int?
    var foulCount: Int
    var strokeCount: Int
    var automaticBreak: Bool
    var completionKind: DailyClearanceCompletionKind?
    var cuePlacement: DailyCuePlacement
    var breakChoices: [DailyBreakChoice]
    var warnedBreaker: RulesPlayer?

    init(assignedGroup: DailyClearanceBallGroup? = nil,
         status: DailyClearanceRuleStatus = .active, ruleVersion: Int = 2) {
        self.assignedGroup = assignedGroup
        self.status = status
        self.ruleVersion = ruleVersion
        currentPlayer = .a
        visitCount = 1
        playedVisitCount = 0
        lastPlayedVisit = nil
        foulCount = 0
        strokeCount = 0
        automaticBreak = true
        completionKind = nil
        cuePlacement = .none
        breakChoices = []
        warnedBreaker = nil
    }

    enum CodingKeys: String, CodingKey {
        case assignedGroup, status, ruleVersion, currentPlayer, visitCount, foulCount, strokeCount
        case automaticBreak, completionKind, cuePlacement, breakChoices, warnedBreaker
        case playedVisitCount, lastPlayedVisit
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        assignedGroup = try c.decodeIfPresent(DailyClearanceBallGroup.self, forKey: .assignedGroup)
        status = try c.decode(DailyClearanceRuleStatus.self, forKey: .status)
        ruleVersion = try c.decodeIfPresent(Int.self, forKey: .ruleVersion) ?? 1
        currentPlayer = try c.decodeIfPresent(RulesPlayer.self, forKey: .currentPlayer) ?? .a
        visitCount = try c.decodeIfPresent(Int.self, forKey: .visitCount) ?? 1
        playedVisitCount = try c.decodeIfPresent(Int.self, forKey: .playedVisitCount)
        lastPlayedVisit = try c.decodeIfPresent(Int.self, forKey: .lastPlayedVisit)
        foulCount = try c.decodeIfPresent(Int.self, forKey: .foulCount) ?? 0
        strokeCount = try c.decodeIfPresent(Int.self, forKey: .strokeCount) ?? 0
        automaticBreak = try c.decodeIfPresent(Bool.self, forKey: .automaticBreak) ?? true
        completionKind = try c.decodeIfPresent(DailyClearanceCompletionKind.self, forKey: .completionKind)
        cuePlacement = try c.decodeIfPresent(DailyCuePlacement.self, forKey: .cuePlacement) ?? .none
        breakChoices = try c.decodeIfPresent([DailyBreakChoice].self, forKey: .breakChoices) ?? []
        warnedBreaker = try c.decodeIfPresent(RulesPlayer.self, forKey: .warnedBreaker)
    }
}

struct DailyClearanceRuling {
    var foul = false
    var foulReason: String?
    var ballInHand = false
    var completed = false
    var failed = false
    var message: String
    var respotKeys: Set<String> = []
    var cuePlacement: DailyCuePlacement = .none
    var changedTurn = false
    var breakChoices: [DailyBreakChoice] = []
}

/// 每日清台规则：一位用户轮换中八双方；九球系记录上手而不虚构对手。
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

        guard state.breakChoices.isEmpty else {
            return DailyClearanceRuling(message: "请先选择开球犯规的处理方式", breakChoices: state.breakChoices)
        }
        recordPlayedVisit()
        if state.ruleVersion >= 2 {
            state.strokeCount += 1
            let placement = state.cuePlacement
            state.cuePlacement = .none
            if placement == .behindHeadString && (!facts.cueStartedBehindHeadString || !facts.cueCrossedHeadStringBeforeContact) {
                if facts.pocketedKeys.contains("_8") {
                    state.status = .failed; state.foulCount += 1
                    return DailyClearanceRuling(foul: true, foulReason: "线后自由球未合法越线", failed: true,
                        message: "黑八落袋同时犯规：线后自由球未合法越线，本局结束")
                }
                return foulRuling("线后自由球须先越过开球线再碰目标球")
            }
            if game == .chineseEightBall { return judgeRotatingEightBall(facts) }
            return judgeTrainingNine(facts)
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

        return DailyClearanceRuling(message: "继续击球")
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

        return DailyClearanceRuling(message: "继续击球")
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


extension DailyClearanceRulesEngine {
    private func resolvedFirst(_ facts: ShotFacts, legal: Set<String>) -> String? {
        if let first = facts.firstContactKey, legal.contains(first) { return first }
        return facts.simultaneousFirstContacts.intersection(legal).sorted().first ?? facts.firstContactKey
    }

    private func ruleFoul(_ facts: ShotFacts, legal: Set<String>) -> String? {
        if facts.cuePocketed { return "白球落袋" }
        if facts.offTableKeys.contains(PositionPlayBall.cueKey) { return "白球离台" }
        if !facts.offTableKeys.isEmpty { return "目标球离台" }
        guard let first = resolvedFirst(facts, legal: legal) else { return "未碰到目标球" }
        guard legal.contains(first) else {
            if game == .chineseEightBall {
                if first == "_8" { return "尚未允许先碰黑八" }
                let group = DailyClearanceBallGroup.of(first)?.displayName ?? "非法目标"
                return "先碰到\(group)球"
            }
            let number = legal.compactMap(PositionPlayBall.number(for:)).min() ?? 9
            return "应先碰\(number)号球"
        }
        if facts.pocketedKeys.isEmpty && !facts.railOrPocketAfterContact { return "触球后无球碰库" }
        return nil
    }

    private mutating func recordPlayedVisit() {
        guard let count = state.playedVisitCount, state.lastPlayedVisit != state.visitCount else { return }
        state.playedVisitCount = count + 1
        state.lastPlayedVisit = state.visitCount
    }

    private mutating func rotateVisit() {
        state.visitCount += 1
        if game == .chineseEightBall {
            state.currentPlayer = state.currentPlayer.other
            state.assignedGroup = state.assignedGroup?.other
        }
    }

    private var nextTurnText: String {
        if game == .chineseEightBall {
            return state.assignedGroup.map { "轮到\($0.displayName)" } ?? "换手，球局仍开放"
        }
        return "本次上手结束"
    }

    private mutating func foulRuling(_ reason: String, placement: DailyCuePlacement = .anywhere,
                                    respot: Set<String> = []) -> DailyClearanceRuling {
        state.foulCount += 1
        rotateVisit()
        state.cuePlacement = placement
        let placementText = placement == .behindHeadString ? "线后自由球" : "自由球"
        let resetText = respot.isEmpty ? "" : "，\(respot.sorted().map { PositionPlayBall.shortLabel(for: $0) }.joined(separator: "、"))号已重置"
        return DailyClearanceRuling(foul: true, foulReason: reason, ballInHand: true,
            message: "犯规：\(reason)\(resetText)。\(nextTurnText)，\(placementText)",
            respotKeys: respot, cuePlacement: placement, changedTurn: true)
    }

    private mutating func judgeRotatingEightBall(_ facts: ShotFacts) -> DailyClearanceRuling {
        let legal = legalTargetKeys(tableKeys: facts.tableKeysBefore)
        let foul = ruleFoul(facts, legal: legal)
        let eightGone = facts.pocketedKeys.contains("_8") || facts.offTableKeys.contains("_8")
        if eightGone {
            if foul == nil, legal == ["_8"], !facts.offTableKeys.contains("_8") {
                state.status = .completed
                state.completionKind = .chineseEight
                return DailyClearanceRuling(completed: true,
                    message: "\(state.assignedGroup?.displayName ?? "本方")完成清台")
            }
            state.status = .failed
            if foul != nil { state.foulCount += 1 }
            let reason = facts.offTableKeys.contains("_8") ? "黑八离台" : (foul == nil ? "黑八提前落袋" : "黑八落袋同时犯规：\(foul!)")
            return DailyClearanceRuling(foul: foul != nil, foulReason: foul, failed: true,
                                       message: "\(reason)，本局结束")
        }
        if let foul { return foulRuling(foul) }
        let firstGroup = resolvedFirst(facts, legal: legal).flatMap(DailyClearanceBallGroup.of)
        if state.assignedGroup == nil {
            if let group = firstGroup, facts.pocketedKeys.contains(where: { DailyClearanceBallGroup.of($0) == group }) {
                state.assignedGroup = group
                return DailyClearanceRuling(message: "已定组：\(group.displayName)，继续击球")
            }
            rotateVisit()
            return DailyClearanceRuling(message: facts.pocketedKeys.isEmpty
                ? "未进球，换手；球局仍开放" : "跨组传进，尚未定组，换手", changedTurn: true)
        }
        let ownPot = facts.pocketedKeys.contains { DailyClearanceBallGroup.of($0) == state.assignedGroup }
        if ownPot {
            let remaining = facts.tableKeysBefore.subtracting(facts.pocketedKeys)
            let cleared = !remaining.contains { DailyClearanceBallGroup.of($0) == state.assignedGroup }
            return DailyClearanceRuling(message: cleared
                ? "\(state.assignedGroup!.displayName)已清空，下一杆击打黑八" : "继续击球")
        }
        rotateVisit()
        return DailyClearanceRuling(message: "\(facts.pocketedKeys.isEmpty ? "未进球" : "未进本组球")，\(nextTurnText)", changedTurn: true)
    }

    /// CBSA 2017 §5. Break facts must come from the physical event timeline.
    mutating func judgeChineseBreak(_ facts: ShotFacts, automatic: Bool) -> DailyClearanceRuling {
        guard state.status == .active else { return DailyClearanceRuling(message: "本局已结束") }
        if !automatic { recordPlayedVisit() }
        state.automaticBreak = automatic
        state.assignedGroup = nil
        state.cuePlacement = .none
        if facts.offTableKeys.contains("_8") {
            state.status = .failed
            state.foulCount += 1
            return DailyClearanceRuling(foul: true, foulReason: "黑八离台", failed: true, message: "黑八离台，本局结束")
        }
        let eight = facts.pocketedKeys.contains("_8")
        let respot: Set<String> = eight ? ["_8"] : []
        let legal = Set(facts.tableKeysBefore)
        let first = resolvedFirst(facts, legal: legal)
        let fourRails = facts.railContactKeys.subtracting([PositionPlayBall.cueKey]).count >= 4
        let adequateBreak = !facts.pocketedKeys.isEmpty || fourRails
        if !adequateBreak {
            if state.warnedBreaker == state.currentPlayer {
                state.status = .failed
                return DailyClearanceRuling(foul: true, foulReason: "再次未满足开球碰库要求", failed: true,
                    message: "再次未满足开球碰库要求，本局结束", respotKeys: respot)
            }
            state.foulCount += 1
            state.breakChoices = [.rerackByIncoming, .rerackByBreaker, .acceptBallInHand]
            return DailyClearanceRuling(foul: true, foulReason: "开球未满足碰库要求",
                message: "开球未满足碰库要求，请选择处理方式", respotKeys: respot, breakChoices: state.breakChoices)
        }
        let reason: String? = facts.cuePocketed ? "白球落袋"
            : (!facts.offTableKeys.isEmpty ? "球离台"
               : (!facts.cueStartedBehindHeadString ? "母球未在线后开球" : (first == nil ? "未碰到目标球" : nil)))
        if let reason, eight {
            state.breakChoices = [.acceptPosition, .acceptBehindHeadString]
            // A missing cue cannot be played in place; only the legal placement option is meaningful.
            if facts.cuePocketed || facts.offTableKeys.contains(PositionPlayBall.cueKey) {
                state.breakChoices = []
                return foulRuling(reason, placement: .behindHeadString, respot: respot)
            }
            state.foulCount += 1
            return DailyClearanceRuling(foul: true, foulReason: reason,
                message: "开球犯规：\(reason)，黑八已重置，请选择继续方式", respotKeys: respot,
                breakChoices: state.breakChoices)
        }
        if let reason { return foulRuling(reason, placement: .behindHeadString, respot: respot) }
        if facts.pocketedKeys.isEmpty {
            rotateVisit()
            return DailyClearanceRuling(message: "开球未进球，换手；球局仍开放", changedTurn: true)
        }
        return DailyClearanceRuling(message: eight ? "黑八已重置，继续击球；球局仍开放" : "继续击球；球局仍开放", respotKeys: respot)
    }

    private mutating func judgeTrainingNine(_ facts: ShotFacts) -> DailyClearanceRuling {
        let legal = legalTargetKeys(tableKeys: facts.tableKeysBefore)
        let nineGone = facts.pocketedKeys.contains("_9") || facts.offTableKeys.contains("_9")
        if let reason = ruleFoul(facts, legal: legal) {
            return foulRuling(reason, respot: nineGone ? ["_9"] : [])
        }
        if nineGone {
            state.status = .completed
            let remaining = facts.tableKeysBefore.subtracting(facts.pocketedKeys)
            state.completionKind = legal != ["_9"] || !remaining.isEmpty ? .combinationNine
                : (state.visitCount > 1 ? .laterVisit : (state.automaticBreak ? .systemBreakRun : .breakRun))
            return DailyClearanceRuling(completed: true, message: state.completionKind!.displayName)
        }
        if facts.pocketedKeys.isEmpty {
            rotateVisit()
            return DailyClearanceRuling(message: "未进球，本次上手结束；开始第\(state.visitCount)次上手", changedTurn: true)
        }
        return DailyClearanceRuling(message: "继续击球")
    }

    /// Single-player training profile: no push-out, three-foul loss or monetary scoring.
    mutating func judgeNineBreak(_ facts: ShotFacts, automatic: Bool) -> DailyClearanceRuling {
        if !automatic { recordPlayedVisit() }
        state.automaticBreak = automatic
        state.cuePlacement = .none
        let legal = legalTargetKeys(tableKeys: facts.tableKeysBefore)
        let nineGone = facts.pocketedKeys.contains("_9") || facts.offTableKeys.contains("_9")
        let insufficient = facts.pocketedKeys.isEmpty && facts.railContactKeys.subtracting([PositionPlayBall.cueKey]).count < 4
        let reason = ruleFoul(facts, legal: legal)
            ?? (!facts.cueStartedBehindHeadString ? "母球未在线后开球" : (insufficient ? "开球未满足碰库要求" : nil))
        if let reason { return foulRuling(reason, respot: nineGone ? ["_9"] : []) }
        if nineGone {
            state.status = .completed
            state.completionKind = automatic ? .systemBreakNine : .breakNine
            return DailyClearanceRuling(completed: true, message: state.completionKind!.displayName)
        }
        if facts.pocketedKeys.isEmpty {
            rotateVisit()
            return DailyClearanceRuling(message: "开球未进球，开始第\(state.visitCount)次上手", changedTurn: true)
        }
        return DailyClearanceRuling(message: automatic ? "系统开球完成，继续击球" : "开球完成，继续击球")
    }

    func selectionMessage(for key: String, tableKeys: Set<String>) -> String? {
        guard tableKeys.contains(key) else { return "这颗球已进袋" }
        let legal = legalTargetKeys(tableKeys: tableKeys)
        guard !legal.contains(key) else { return nil }
        guard state.status == .active else { return "本局已结束" }
        if game == .chineseEightBall {
            if legal == ["_8"] { return "本组已清空，请击打黑八" }
            if let group = state.assignedGroup {
                if key == "_8" { return "先打完\(group.displayName)球，再打黑八" }
                return "请先击打\(group.displayName)球"
            }
            return "尚未定组，请选全色或花色球"
        }
        guard let lowest = legal.compactMap(PositionPlayBall.number(for:)).min() else { return "当前没有可选目标球" }
        return key == "_9" ? "先碰\(lowest)号球，可组合进9" : "请先碰\(lowest)号球"
    }

    /// Returns true when the selected rules option requires a fresh rack.
    mutating func resolveBreakChoice(_ choice: DailyBreakChoice) -> Bool {
        guard state.breakChoices.contains(choice) else { return false }
        state.breakChoices = []
        switch choice {
        case .rerackByBreaker:
            // A forced rerack interrupts the run even though the same player returns.
            state.lastPlayedVisit = nil
            state.warnedBreaker = state.currentPlayer
            return true
        case .rerackByIncoming:
            rotateVisit()
            return true
        case .acceptBallInHand:
            rotateVisit(); state.cuePlacement = .anywhere
        case .acceptPosition:
            rotateVisit(); state.cuePlacement = .none
        case .acceptBehindHeadString:
            rotateVisit(); state.cuePlacement = .behindHeadString
        }
        return false
    }
}
