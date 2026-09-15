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

/// Requested rendering ceiling; thermal and display limits may lower the actual rate.
enum RenderFrameRate: Int, CaseIterable, Identifiable {
    case fps30 = 30, fps60 = 60, fps120 = 120
    var id: Int { rawValue }
    var displayName: String { "\(rawValue) 帧" }
}

enum RoomStyle: String, CaseIterable, Identifiable {
    case tournament, walnut, eastern
    static let preferenceKey = "roomStyle.v1"
    var id: String { rawValue }
    var displayName: String {
        switch self { case .tournament: "极简赛事"; case .walnut: "温润木质"; case .eastern: "当代东方" }
    }
    var subtitle: String {
        switch self {
        case .tournament: "灰色吸音墙 · 炭灰地毯"
        case .walnut: "温润木饰面 · 暖灰地毯"
        case .eastern: "深木格栅 · 素灰墙面"
        }
    }
    var previewName: String { "RoomStyle_" + rawValue + ".jpg" }
    static var selected: RoomStyle {
        RoomStyle(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .tournament
    }
}

// MARK: - UserPreferences

@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    private static let inferredGameKey = "dailyClearance.inferredGame.v1"
    private let defaults: UserDefaults

    /// 未手动选择时跟随当前用户资料；已保存的旧值也视为用户的明确选择。
    @Published private(set) var dailyClearanceGame: DailyClearanceGame

    func selectDailyClearanceGame(_ game: DailyClearanceGame) {
        dailyClearanceGame = game
        defaults.set(game.rawValue, forKey: DailyClearanceStoreKey.preferredGame)
    }

    func synchronizeDefaultGame(ownerKey: String, user: AppUser?) {
        let profile = OwnerProfileStore(ownerKey: ownerKey, defaults: defaults)
        profile.load(from: user)
        synchronizeDefaultGame(with: profile.preferredSport)
    }

    func synchronizeDefaultGame(with sport: PreferredSport) {
        if let raw = defaults.string(forKey: DailyClearanceStoreKey.preferredGame),
           DailyClearanceGame(rawValue: raw) != nil { return }
        // “两者”没有单一玩法含义，保留当前值；无历史时初始化为中八。
        guard sport != .both else { return }
        dailyClearanceGame = DailyClearanceGame.initialDefault(for: sport)
        defaults.set(dailyClearanceGame.rawValue, forKey: Self.inferredGameKey)
    }

    @Published var reminderWeekdays: Set<Int> {
        didSet { defaults.set(reminderWeekdays.sorted(), forKey: "reminderWeekdays") }
    }

    @Published var reminderEnabled: Bool {
        didSet { defaults.set(reminderEnabled, forKey: "reminderEnabled") }
    }

    @Published var reminderTime: Date {
        didSet {
            defaults.set(reminderTime.timeIntervalSince1970, forKey: "reminderTime")
            defaults.set(Calendar.current.component(.hour, from: reminderTime), forKey: "reminderLocalHour")
            defaults.set(Calendar.current.component(.minute, from: reminderTime), forKey: "reminderLocalMinute")
        }
    }

    // New: Appearance
    @Published var appearanceMode: AppearanceMode {
        didSet { defaults.set(appearanceMode.rawValue, forKey: "appearanceMode") }
    }

    @Published var roomStyle: RoomStyle {
        didSet { defaults.set(roomStyle.rawValue, forKey: RoomStyle.preferenceKey) }
    }

    @Published var showsTableSights: Bool {
        didSet { defaults.set(showsTableSights, forKey: "showsTableSights.v1") }
    }

    @Published var clothColor: ClothColor {
        didSet { defaults.set(clothColor.rawValue, forKey: ClothColor.preferenceKey) }
    }

    @Published var tableStyle: TableStyle {
        didSet { defaults.set(tableStyle.rawValue, forKey: TableStyle.preferenceKey) }
    }

    @Published var ballStickerStyle: BallStickerStyle {
        didSet { defaults.set(ballStickerStyle.rawValue, forKey: BallStickerStyle.preferenceKey) }
    }

    @Published var cueStyle: CueStyle {
        didSet { defaults.set(cueStyle.rawValue, forKey: CueStyle.preferenceKey) }
    }

    @Published var renderFrameRate: RenderFrameRate {
        didSet { defaults.set(renderFrameRate.rawValue, forKey: "renderFrameRate") }
    }

    // Training music and shot effects are independent device preferences.
    @Published var backgroundMusicEnabled: Bool {
        didSet { defaults.set(backgroundMusicEnabled, forKey: "backgroundMusicEnabled") }
    }

    // Shot replay sound effects are disabled by default until audio assets are ready.
    @Published var soundEffectsEnabled: Bool {
        didSet { defaults.set(soundEffectsEnabled, forKey: "soundEffectsEnabled") }
    }

    // New: 在所有击球轨迹上叠加 90° 分离角辅助线（过碰撞点、垂直于撞击线）。默认关闭。
    @Published var showSeparationAngle: Bool {
        didSet { defaults.set(showSeparationAngle, forKey: "showSeparationAngle") }
    }

    // 三档轨迹标注（问题集合条 12.5，全击打页统一）：全部球 / 母球+目标球 / 仅瞄准线+假想球。
    @Published var trajectoryDetail: TrajectoryDetail {
        didSet { defaults.set(trajectoryDetail.rawValue, forKey: "trajectoryDetail") }
    }

    // 4×8 台面网格叠加（问题集合条 16，全球桌页面统一）。默认关闭。
    @Published var showTableGrid: Bool {
        didSet { defaults.set(showTableGrid, forKey: "showTableGrid") }
    }

    // 近球瞄准特写 HUD（v23 E3）。默认开启。
    @Published var showAimCloseup: Bool {
        didSet { defaults.set(showAimCloseup, forKey: PracticeStorageKey.showAimCloseup) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.reminderWeekdays = Set(defaults.array(forKey: "reminderWeekdays") as? [Int] ?? Array(1...7))
        let sportRaw = defaults.string(forKey: "preferredSport") ?? PreferredSport.chinese8.rawValue
        let initialSport = PreferredSport(rawValue: sportRaw) ?? .chinese8

        if let gameRaw = defaults.string(forKey: DailyClearanceStoreKey.preferredGame),
           let game = DailyClearanceGame(rawValue: gameRaw) {
            self.dailyClearanceGame = game
        } else if let raw = defaults.string(forKey: Self.inferredGameKey),
                  let game = DailyClearanceGame(rawValue: raw) {
            self.dailyClearanceGame = game
        } else {
            self.dailyClearanceGame = DailyClearanceGame.initialDefault(for: initialSport)
        }

        OwnerProfileStore.migrateLegacyGuestProfile(in: defaults)

        // v53 删除“每次训练时长目标”。旧值没有运行时消费者，升级时主动清掉，
        // 但 TrainingSession.totalDurationMinutes 的真实训练数据完全不受影响。
        defaults.removeObject(forKey: "targetSessionMinutes")

        self.reminderEnabled = defaults.bool(forKey: "reminderEnabled")

        let storedTime = defaults.double(forKey: "reminderTime")
        if let hour = defaults.object(forKey: "reminderLocalHour") as? Int {
            self.reminderTime = Calendar.current.date(bySettingHour: hour,
                minute: defaults.integer(forKey: "reminderLocalMinute"), second: 0, of: Date()) ?? Date()
        } else if storedTime > 0 {
            self.reminderTime = Date(timeIntervalSince1970: storedTime)
        } else {
            var components = DateComponents()
            components.hour = 19
            components.minute = 0
            self.reminderTime = Calendar.current.date(from: components) ?? Date()
        }

        let modeRaw = defaults.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: modeRaw) ?? .system

        self.roomStyle = RoomStyle(rawValue: defaults.string(forKey: RoomStyle.preferenceKey) ?? "") ?? .tournament
        self.showsTableSights = defaults.object(forKey: "showsTableSights.v1") as? Bool ?? true
        self.clothColor = ClothColor.selected(in: defaults)
        self.tableStyle = TableStyle(rawValue: defaults.string(forKey: TableStyle.preferenceKey) ?? "") ?? .standard
        self.ballStickerStyle = BallStickerStyle.selected(in: defaults)
        self.cueStyle = CueStyle.selected(in: defaults)
        self.renderFrameRate = RenderFrameRate(rawValue: defaults.integer(forKey: "renderFrameRate")) ?? .fps60

        self.backgroundMusicEnabled = (defaults.object(forKey: "backgroundMusicEnabled") as? Bool) ?? false

        // Default to off while preserving an explicitly saved preference.
        self.soundEffectsEnabled = (defaults.object(forKey: "soundEffectsEnabled") as? Bool) ?? false

        // 默认关闭（可选辅助线）。
        self.showSeparationAngle = (defaults.object(forKey: "showSeparationAngle") as? Bool) ?? false

        // 默认最全档（条 12.5）。
        let detailRaw = defaults.object(forKey: "trajectoryDetail") as? Int
        self.trajectoryDetail = detailRaw.flatMap { TrajectoryDetail(rawValue: $0) } ?? .full

        // 默认关闭（条 16）。
        self.showTableGrid = (defaults.object(forKey: "showTableGrid") as? Bool) ?? false

        // 默认开启（v23 E3）。
        self.showAimCloseup =
            (defaults.object(forKey: PracticeStorageKey.showAimCloseup) as? Bool) ?? true
        if defaults.object(forKey: "reminderLocalHour") == nil {
            defaults.set(Calendar.current.component(.hour, from: reminderTime), forKey: "reminderLocalHour")
            defaults.set(Calendar.current.component(.minute, from: reminderTime), forKey: "reminderLocalMinute")
        }
    }

    /// Reconstruct the chosen wall-clock time after an in-process timezone change.
    var localReminderTime: Date {
        let hour = defaults.object(forKey: "reminderLocalHour") as? Int ?? Calendar.current.component(.hour, from: reminderTime)
        let minute = defaults.object(forKey: "reminderLocalMinute") as? Int ?? Calendar.current.component(.minute, from: reminderTime)
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? reminderTime
    }

    func persistReminder(enabled: Bool, time: Date? = nil) {
        if let time { reminderTime = time }
        reminderEnabled = enabled
    }

}
