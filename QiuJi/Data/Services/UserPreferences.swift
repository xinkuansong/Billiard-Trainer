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

    // Existing
    @Published var preferredSport: PreferredSport {
        didSet { UserDefaults.standard.set(preferredSport.rawValue, forKey: "preferredSport") }
    }

    @Published var weeklyGoalDays: Int {
        didSet { UserDefaults.standard.set(weeklyGoalDays, forKey: "weeklyGoalDays") }
    }

    // New: Personal info
    @Published var skillLevel: SkillLevel {
        didSet { UserDefaults.standard.set(skillLevel.rawValue, forKey: "skillLevel") }
    }

    @Published var yearsPlaying: YearsPlaying {
        didSet { UserDefaults.standard.set(yearsPlaying.rawValue, forKey: "yearsPlaying") }
    }

    // New: Training goal
    @Published var targetSessionMinutes: Int {
        didSet { UserDefaults.standard.set(targetSessionMinutes, forKey: "targetSessionMinutes") }
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

    private init() {
        let sportRaw = UserDefaults.standard.string(forKey: "preferredSport") ?? PreferredSport.chinese8.rawValue
        self.preferredSport = PreferredSport(rawValue: sportRaw) ?? .chinese8

        let days = UserDefaults.standard.integer(forKey: "weeklyGoalDays")
        self.weeklyGoalDays = days > 0 ? days : 3

        let levelRaw = UserDefaults.standard.string(forKey: "skillLevel") ?? SkillLevel.beginner.rawValue
        self.skillLevel = SkillLevel(rawValue: levelRaw) ?? .beginner

        let yearsRaw = UserDefaults.standard.string(forKey: "yearsPlaying") ?? YearsPlaying.lessThan1.rawValue
        self.yearsPlaying = YearsPlaying(rawValue: yearsRaw) ?? .lessThan1

        self.targetSessionMinutes = UserDefaults.standard.integer(forKey: "targetSessionMinutes")

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
    }

    // MARK: - Summaries

    var sportSummary: String { preferredSport.displayName }
    var goalSummary: String { "每周 \(weeklyGoalDays) 天" }

    var personalInfoSummary: String {
        "\(preferredSport.displayName) · \(skillLevel.displayName)"
    }

    var sessionDurationSummary: String {
        targetSessionMinutes > 0 ? "\(targetSessionMinutes) 分钟" : "不限"
    }
}
