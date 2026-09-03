import Foundation

// MARK: - Enums

enum PreferredSport: String, CaseIterable, Identifiable {
    case chinese8 = "chinese8"
    case nineBall = "nineBall"
    case both = "both"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chinese8: return "中式台球"
        case .nineBall: return "9球"
        case .both:     return "两者"
        }
    }
}

enum SkillLevel: String, CaseIterable, Identifiable {
    case beginner = "beginner"
    case elementary = "elementary"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner:     return "入门"
        case .elementary:   return "初级"
        case .intermediate: return "中级"
        case .advanced:     return "高级"
        }
    }
}

enum YearsPlaying: String, CaseIterable, Identifiable {
    case lessThan1 = "lessThan1"
    case oneToThree = "oneToThree"
    case threeToFive = "threeToFive"
    case fivePlus = "fivePlus"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lessThan1:    return "不到 1 年"
        case .oneToThree:   return "1–3 年"
        case .threeToFive:  return "3–5 年"
        case .fivePlus:     return "5 年以上"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }
}

// MARK: - UserPreferences

@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    /// 每日清台新局的默认玩法。已有用户首次升级时由主打球种推导，之后独立持久化。
    @Published var dailyClearanceGame: DailyClearanceGame {
        didSet {
            UserDefaults.standard.set(
                dailyClearanceGame.rawValue,
                forKey: DailyClearanceStoreKey.preferredGame
            )
        }
    }

    @Published var reminderEnabled: Bool {
        didSet { UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled") }
    }

    @Published var reminderTime: Date {
        didSet { UserDefaults.standard.set(reminderTime.timeIntervalSince1970, forKey: "reminderTime") }
    }

    // New: Appearance
    @Published var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode") }
    }

    // New: 击球回放音效（球-球碰撞 / 吃库 / 落袋 / 击球）。默认开启。
    @Published var soundEffectsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEffectsEnabled, forKey: "soundEffectsEnabled") }
    }

    // New: 在所有击球轨迹上叠加 90° 分离角辅助线（过碰撞点、垂直于撞击线）。默认关闭。
    @Published var showSeparationAngle: Bool {
        didSet { UserDefaults.standard.set(showSeparationAngle, forKey: "showSeparationAngle") }
    }

    // 三档轨迹标注（问题集合条 12.5，全击打页统一）：全部球 / 母球+目标球 / 仅瞄准线+假想球。
    @Published var trajectoryDetail: TrajectoryDetail {
        didSet { UserDefaults.standard.set(trajectoryDetail.rawValue, forKey: "trajectoryDetail") }
    }

    // 4×8 台面网格叠加（问题集合条 16，全球桌页面统一）。默认关闭。
    @Published var showTableGrid: Bool {
        didSet { UserDefaults.standard.set(showTableGrid, forKey: "showTableGrid") }
    }

    // 近球瞄准特写 HUD（v23 E3）。默认开启。
    @Published var showAimCloseup: Bool {
        didSet { UserDefaults.standard.set(showAimCloseup, forKey: PracticeStorageKey.showAimCloseup) }
    }

    private init() {
        let sportRaw = UserDefaults.standard.string(forKey: "preferredSport") ?? PreferredSport.chinese8.rawValue
        let initialSport = PreferredSport(rawValue: sportRaw) ?? .chinese8

        if let gameRaw = UserDefaults.standard.string(forKey: DailyClearanceStoreKey.preferredGame),
           let game = DailyClearanceGame(rawValue: gameRaw) {
            self.dailyClearanceGame = game
        } else {
            self.dailyClearanceGame = DailyClearanceGame.initialDefault(for: initialSport)
        }

        OwnerProfileStore.migrateLegacyGuestProfile(in: .standard)

        // v53 删除“每次训练时长目标”。旧值没有运行时消费者，升级时主动清掉，
        // 但 TrainingSession.totalDurationMinutes 的真实训练数据完全不受影响。
        UserDefaults.standard.removeObject(forKey: "targetSessionMinutes")

        self.reminderEnabled = UserDefaults.standard.bool(forKey: "reminderEnabled")

        let storedTime = UserDefaults.standard.double(forKey: "reminderTime")
        if storedTime > 0 {
            self.reminderTime = Date(timeIntervalSince1970: storedTime)
        } else {
            var components = DateComponents()
            components.hour = 19
            components.minute = 0
            self.reminderTime = Calendar.current.date(from: components) ?? Date()
        }

        let modeRaw = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: modeRaw) ?? .system

        // 默认开启；首次启动 UserDefaults 无键时 object(forKey:) 为 nil → 取 true。
        self.soundEffectsEnabled = (UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool) ?? true

        // 默认关闭（可选辅助线）。
        self.showSeparationAngle = (UserDefaults.standard.object(forKey: "showSeparationAngle") as? Bool) ?? false

        // 默认最全档（条 12.5）。
        let detailRaw = UserDefaults.standard.object(forKey: "trajectoryDetail") as? Int
        self.trajectoryDetail = detailRaw.flatMap { TrajectoryDetail(rawValue: $0) } ?? .full

        // 默认关闭（条 16）。
        self.showTableGrid = (UserDefaults.standard.object(forKey: "showTableGrid") as? Bool) ?? false

        // 默认开启（v23 E3）。
        self.showAimCloseup =
            (UserDefaults.standard.object(forKey: PracticeStorageKey.showAimCloseup) as? Bool) ?? true
    }

    func persistReminder(enabled: Bool, time: Date? = nil) {
        if let time { reminderTime = time }
        reminderEnabled = enabled
    }

}
