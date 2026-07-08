import Foundation

//
//  BilliardRulesEngine.swift
//  QiuJi
//
//  自由击球规则引擎（条 15.10）：单机双玩家（一人扮两方）的中式八球与追分完整规则。
//  规则依据：docs/research/20260707-中八追分规则调研.md（CBSA/WPA 条文 + App 约定）。
//
//  设计：引擎是**纯规则状态机**，不持有场景/物理对象；每杆结束后由宿主把物理事实
//  （`ShotFacts`，全部用桌面球键 `"_n"`）喂给 `judge(_:)`，引擎返回裁决并推进轮转。
//

// MARK: - Players

enum RulesPlayer: String, Codable {
    case a, b

    var other: RulesPlayer { self == .a ? .b : .a }
    var displayName: String { self == .a ? "玩家 A" : "玩家 B" }
}

// MARK: - Shot facts（宿主从 ShotPrediction 提取的物理事实）

struct ShotFacts {
    /// 母球首次触碰的球（桌面球键）。nil = 空杆。
    let firstContactKey: String?
    /// 本杆入袋的目标球（桌面球键，按落袋时间排序，不含母球）。
    let pocketedKeys: [String]
    /// 母球是否落袋。
    let cuePocketed: Bool
    /// 首触之后是否有任意球碰库或入袋（合法击球的「碰库要求」）。
    let railOrPocketAfterContact: Bool
    /// 击球前台面上的目标球（桌面球键，不含母球）。
    let tableKeysBefore: Set<String>
}

// MARK: - Ruling（一杆的裁决结果）

struct ShotRuling {
    var foul = false
    var foulReason: String?
    /// 下一杆的击球方（gameOver 时无意义）。
    var nextPlayer: RulesPlayer
    /// 犯规自由球：对方可全台任意摆放母球。
    var ballInHand = false
    var gameOver = false
    var winner: RulesPlayer?
    /// 面向用户的一句话裁决（状态栏展示）。
    var message: String
}

// MARK: - Engine protocol

@MainActor
protocol BilliardRulesEngine: AnyObject {
    /// 当前击球方。
    var currentPlayer: RulesPlayer { get }
    /// 对局是否已分出胜负。
    var isGameOver: Bool { get }
    /// 记分牌一行摘要（HUD 用）。
    var scoreboardText: String { get }
    /// 双方身份/得分描述（HUD 用，如「玩家A·全色」/「玩家A · 12 分」）。
    func playerLabel(_ player: RulesPlayer) -> String
    /// 裁决一杆并推进状态机。
    @discardableResult
    func judge(_ facts: ShotFacts) -> ShotRuling
    /// 当前击球方**合法首触**的目标球集合（桌面球键 "_n"，不含母球）。
    /// 用于拦截用户选择不合法目标球（v3 P10.2）。空集合 = 无合法目标。
    func legalTargetKeys(tableKeys: Set<String>) -> Set<String>
}

// MARK: - Ball classification helpers

enum BallGroup {
    case solid    // 1–7 全色
    case stripe   // 9–15 花色
    case eight    // 8 号

    /// 桌面球键（"_n"）→ 分组。母球与非法键返回 nil。
    static func of(_ key: String) -> BallGroup? {
        guard key.hasPrefix("_"), let n = Int(key.dropFirst()) else { return nil }
        if n == 8 { return .eight }
        if (1...7).contains(n) { return .solid }
        if (9...15).contains(n) { return .stripe }
        return nil
    }

    var displayName: String { self == .solid ? "全色" : (self == .stripe ? "花色" : "8 号") }
}

/// 桌面球键 → 球号（母球/非法键返回 nil）。
private func ballNumber(_ key: String) -> Int? {
    guard key.hasPrefix("_") else { return nil }
    return Int(key.dropFirst())
}

// MARK: - 中式八球规则引擎

/// 中式八球（调研文档 §1）：开放/定边、首触合法、碰库要求、犯规自由球、8 号胜负。
@MainActor
final class ChineseEightBallRules: BilliardRulesEngine {

    private(set) var currentPlayer: RulesPlayer = .a
    private(set) var isGameOver = false
    private(set) var winner: RulesPlayer?
    /// 花色归属：nil = 开放局。值为玩家 A 的花色（B 持另一色）。
    private(set) var groupOfA: BallGroup?

    init(firstPlayer: RulesPlayer = .a) {
        currentPlayer = firstPlayer
    }

    func playerLabel(_ player: RulesPlayer) -> String {
        guard let a = groupOfA else { return player.displayName }
        let group = player == .a ? a : (a == .solid ? BallGroup.stripe : .solid)
        return "\(player.displayName)·\(group.displayName)"
    }

    var scoreboardText: String {
        if isGameOver, let winner { return "\(playerLabel(winner)) 胜" }
        return groupOfA == nil ? "开放局" : "\(playerLabel(.a)) vs \(playerLabel(.b))"
    }

    /// 玩家的本方花色（开放局返回 nil）。
    private func group(of player: RulesPlayer) -> BallGroup? {
        guard let a = groupOfA else { return nil }
        return player == .a ? a : (a == .solid ? .stripe : .solid)
    }

    /// 击球前本方花色是否已清空（开放局视为未清空）。
    private func ownGroupCleared(player: RulesPlayer, tableBefore: Set<String>) -> Bool {
        guard let g = group(of: player) else { return false }
        return !tableBefore.contains { BallGroup.of($0) == g }
    }

    @discardableResult
    func judge(_ facts: ShotFacts) -> ShotRuling {
        guard !isGameOver else {
            return ShotRuling(nextPlayer: currentPlayer, gameOver: true, winner: winner,
                              message: scoreboardText)
        }
        let shooter = currentPlayer
        let ownCleared = ownGroupCleared(player: shooter, tableBefore: facts.tableKeysBefore)

        // —— 犯规判定（调研 §1.5）——
        var foulReason: String?
        if facts.firstContactKey == nil {
            foulReason = "空杆：未触任何球"
        } else if let first = facts.firstContactKey, let firstGroup = BallGroup.of(first) {
            if groupOfA == nil {
                if firstGroup == .eight { foulReason = "开放局首触 8 号" }
            } else if let own = group(of: shooter) {
                if ownCleared {
                    if firstGroup != .eight { foulReason = "本方球已清空，须首触 8 号" }
                } else if firstGroup != own {
                    foulReason = "首触非本方球（\(firstGroup.displayName)）"
                }
            }
        }
        if foulReason == nil, facts.cuePocketed {
            foulReason = "母球落袋"
        }
        if foulReason == nil, facts.pocketedKeys.isEmpty, !facts.railOrPocketAfterContact {
            foulReason = "触球后无球碰库"
        }
        let foul = foulReason != nil

        let eightPocketed = facts.pocketedKeys.contains { BallGroup.of($0) == .eight }

        // —— 8 号落袋：立即分胜负（调研 §1.6）——
        if eightPocketed {
            isGameOver = true
            if foul || !ownCleared {
                winner = shooter.other
                let why = foul ? (foulReason ?? "犯规") : "本方球未清空"
                return ShotRuling(foul: foul, foulReason: foulReason, nextPlayer: shooter.other,
                                  gameOver: true, winner: winner,
                                  message: "8 号落袋（\(why)）：\(playerLabel(shooter.other)) 胜")
            }
            winner = shooter
            return ShotRuling(nextPlayer: shooter, gameOver: true, winner: shooter,
                              message: "清台成功：\(playerLabel(shooter)) 胜")
        }

        // —— 开放局定边（调研 §1.3）：合法击球打进第一颗非 8 球定花色 ——
        if !foul, groupOfA == nil,
           let firstPot = facts.pocketedKeys.first(where: { BallGroup.of($0) != .eight }),
           let g = BallGroup.of(firstPot) {
            groupOfA = shooter == .a ? g : (g == .solid ? .stripe : .solid)
        }

        // —— 轮转 ——
        if foul {
            currentPlayer = shooter.other
            return ShotRuling(foul: true, foulReason: foulReason, nextPlayer: currentPlayer,
                              ballInHand: true,
                              message: "犯规（\(foulReason ?? "")）：\(currentPlayer.displayName) 自由球")
        }
        let ownAfter = group(of: shooter)
        let pottedOwn = facts.pocketedKeys.contains { key in
            guard let g = BallGroup.of(key), g != .eight else { return false }
            return ownAfter == nil || g == ownAfter
        }
        if pottedOwn {
            return ShotRuling(nextPlayer: shooter,
                              message: "\(playerLabel(shooter)) 进球，继续击球")
        }
        currentPlayer = shooter.other
        return ShotRuling(nextPlayer: currentPlayer,
                          message: "未进球，轮到 \(playerLabel(currentPlayer))")
    }

    /// 合法目标（调研 §1.4/§1.5 首触规则）：
    /// - 开放局：除 8 号外任意球；
    /// - 已定花色 + 本方球未清空：仅本方花色；
    /// - 已定花色 + 本方球已清空：仅 8 号。
    func legalTargetKeys(tableKeys: Set<String>) -> Set<String> {
        let targets = tableKeys.filter { BallGroup.of($0) != nil }
        guard let own = group(of: currentPlayer) else {
            return targets.filter { BallGroup.of($0) != .eight }
        }
        if ownGroupCleared(player: currentPlayer, tableBefore: tableKeys) {
            return targets.filter { BallGroup.of($0) == .eight }
        }
        return targets.filter { BallGroup.of($0) == own }
    }
}

// MARK: - 追分规则引擎（9 球系少球玩法）

/// 追分（调研文档 §2，App 约定规则集）：首触最小号、按球号计分、9 号终局、总分定胜负。
@MainActor
final class ZhuifenRules: BilliardRulesEngine {

    private(set) var currentPlayer: RulesPlayer = .a
    private(set) var isGameOver = false
    private(set) var winner: RulesPlayer?
    private(set) var scoreA = 0
    private(set) var scoreB = 0

    init(firstPlayer: RulesPlayer = .a) {
        currentPlayer = firstPlayer
    }

    func playerLabel(_ player: RulesPlayer) -> String {
        "\(player.displayName) \(player == .a ? scoreA : scoreB) 分"
    }

    var scoreboardText: String {
        if isGameOver {
            if let winner { return "\(winner.displayName) 胜（\(scoreA):\(scoreB)）" }
            return "和局（\(scoreA):\(scoreB)）"
        }
        return "追分 \(scoreA):\(scoreB)"
    }

    private func addScore(_ points: Int, to player: RulesPlayer) {
        if player == .a { scoreA += points } else { scoreB += points }
    }

    /// 终局结算：9 号落袋或台面清空时按总分定胜负（调研 §2.4）。
    private func settle() -> RulesPlayer? {
        if scoreA == scoreB { return nil }
        return scoreA > scoreB ? .a : .b
    }

    @discardableResult
    func judge(_ facts: ShotFacts) -> ShotRuling {
        guard !isGameOver else {
            return ShotRuling(nextPlayer: currentPlayer, gameOver: true, winner: winner,
                              message: scoreboardText)
        }
        let shooter = currentPlayer
        let lowest = facts.tableKeysBefore.compactMap(ballNumber).min()

        // —— 犯规判定（调研 §2.2）——
        var foulReason: String?
        if facts.firstContactKey == nil {
            foulReason = "空杆：未触任何球"
        } else if let first = facts.firstContactKey, let n = ballNumber(first),
                  let lowest, n != lowest {
            foulReason = "首触非最小号（应打 \(lowest) 号）"
        }
        if foulReason == nil, facts.cuePocketed {
            foulReason = "母球落袋"
        }
        if foulReason == nil, facts.pocketedKeys.isEmpty, !facts.railOrPocketAfterContact {
            foulReason = "触球后无球碰库"
        }
        let foul = foulReason != nil

        // —— 计分（犯规不计分，球仍离场，调研 §2.3）——
        let points = foul ? 0 : facts.pocketedKeys.compactMap(ballNumber).reduce(0, +)
        if points > 0 { addScore(points, to: shooter) }

        // —— 终局：9 号落袋或台面清空 ——
        let ninePocketed = facts.pocketedKeys.contains { ballNumber($0) == 9 }
        let tableAfter = facts.tableKeysBefore.subtracting(facts.pocketedKeys)
        if ninePocketed || tableAfter.isEmpty {
            isGameOver = true
            winner = settle()
            return ShotRuling(foul: foul, foulReason: foulReason, nextPlayer: shooter,
                              gameOver: true, winner: winner, message: scoreboardText)
        }

        // —— 轮转 ——
        if foul {
            currentPlayer = shooter.other
            return ShotRuling(foul: true, foulReason: foulReason, nextPlayer: currentPlayer,
                              ballInHand: true,
                              message: "犯规（\(foulReason ?? "")）：\(currentPlayer.displayName) 自由球")
        }
        if points > 0 {
            return ShotRuling(nextPlayer: shooter,
                              message: "\(playerLabel(shooter))，+\(points) 分，继续击球")
        }
        currentPlayer = shooter.other
        return ShotRuling(nextPlayer: currentPlayer,
                          message: "未进球，轮到 \(currentPlayer.displayName)")
    }

    /// 合法目标（调研 §2.2 首触最小号）：仅台面最小号球。
    func legalTargetKeys(tableKeys: Set<String>) -> Set<String> {
        guard let lowest = tableKeys.compactMap(ballNumber).min() else { return [] }
        return tableKeys.filter { ballNumber($0) == lowest }
    }
}
