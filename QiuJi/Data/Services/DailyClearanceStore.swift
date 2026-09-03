import Foundation

enum DailyClearancePhase: String, Codable, Equatable {
    case autoBreaking
    case manualRacked
    case playing
    case failed
}

struct DailyClearanceDraft: Codable {
    var challengeDay: Date
    var game: DailyClearanceGame
    var seed: UInt64
    var automaticRetryCount: Int
    var phase: DailyClearancePhase
    var board: BoardSnapshot?
    var ruleState: DailyClearanceRuleState
    var shotCount: Int
    var foulCount: Int
    var activeDurationSeconds: TimeInterval
    var startedAt: Date
    var updatedAt: Date
}

struct DailyClearanceCompletion: Codable {
    var challengeDay: Date
    var game: DailyClearanceGame
    var shotCount: Int
    var foulCount: Int
    var activeDurationSeconds: TimeInterval
    var completedAt: Date
}

enum DailyClearanceStoreKey {
    static let activeDraft = "dailyClearance.activeDraft.v1"
    static let latestCompletion = "dailyClearance.latestCompletion.v1"
    static let preferredGame = "dailyClearance.preferredGame.v1"
}

/// 每日清台的小体量状态仓库。日期、时钟和 UserDefaults 均可注入，避免零点测试依赖系统状态。
final class DailyClearanceStore {
    typealias LogHandler = (String) -> Void

    private let defaults: UserDefaults
    private var calendar: Calendar
    private let now: () -> Date
    private let log: LogHandler
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard,
         calendar: Calendar = .current,
         now: @escaping () -> Date = Date.init,
         log: @escaping LogHandler = { print("[DailyClearanceStore] \($0)") }) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        self.log = log
    }

    func day(containing date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: now())
    }

    func makeDraft(game: DailyClearanceGame, seed: UInt64) -> DailyClearanceDraft {
        let timestamp = now()
        return DailyClearanceDraft(
            challengeDay: day(containing: timestamp),
            game: game,
            seed: seed,
            automaticRetryCount: 0,
            phase: .autoBreaking,
            board: nil,
            ruleState: DailyClearanceRuleState(),
            shotCount: 0,
            foulCount: 0,
            activeDurationSeconds: 0,
            startedAt: timestamp,
            updatedAt: timestamp
        )
    }

    func saveDraft(_ draft: DailyClearanceDraft) {
        do {
            defaults.set(try encoder.encode(draft), forKey: DailyClearanceStoreKey.activeDraft)
        } catch {
            log("草稿编码失败：\(error.localizedDescription)")
        }
    }

    /// 只返回今天开始的挑战；跨日旧草稿会被明确丢弃。
    func loadTodayDraft() -> DailyClearanceDraft? {
        guard let draft: DailyClearanceDraft = decode(
            DailyClearanceDraft.self,
            key: DailyClearanceStoreKey.activeDraft,
            label: "草稿"
        ) else { return nil }

        guard isToday(draft.challengeDay) else {
            defaults.removeObject(forKey: DailyClearanceStoreKey.activeDraft)
            log("已丢弃跨日草稿")
            return nil
        }
        return draft
    }

    func clearDraft() {
        defaults.removeObject(forKey: DailyClearanceStoreKey.activeDraft)
    }

    func saveCompletion(_ completion: DailyClearanceCompletion) {
        do {
            defaults.set(try encoder.encode(completion), forKey: DailyClearanceStoreKey.latestCompletion)
        } catch {
            log("完成记录编码失败：\(error.localizedDescription)")
        }
    }

    func clearCompletion() {
        defaults.removeObject(forKey: DailyClearanceStoreKey.latestCompletion)
    }

    func complete(_ draft: DailyClearanceDraft) -> DailyClearanceCompletion {
        let completion = DailyClearanceCompletion(
            challengeDay: draft.challengeDay,
            game: draft.game,
            shotCount: draft.shotCount,
            foulCount: draft.foulCount,
            activeDurationSeconds: draft.activeDurationSeconds,
            completedAt: now()
        )
        saveCompletion(completion)
        clearDraft()
        return completion
    }

    func loadTodayCompletion() -> DailyClearanceCompletion? {
        guard let completion: DailyClearanceCompletion = decode(
            DailyClearanceCompletion.self,
            key: DailyClearanceStoreKey.latestCompletion,
            label: "完成记录"
        ) else { return nil }
        return isToday(completion.challengeDay) ? completion : nil
    }

    func hasCompletedToday() -> Bool {
        loadTodayCompletion() != nil
    }

    private func decode<Value: Decodable>(_ type: Value.Type,
                                           key: String,
                                           label: String) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            defaults.removeObject(forKey: key)
            log("\(label)损坏，已清除：\(error.localizedDescription)")
            return nil
        }
    }
}
