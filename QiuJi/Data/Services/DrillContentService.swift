import Foundation

// MARK: - DTOs (Bundle JSON; future: REST API OTA)

struct DrillContent: Codable, Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let category: String
    let subcategory: String
    let ballType: [String]
    let level: String
    let difficulty: Int
    let isPremium: Bool
    let description: String
    let coachingPoints: [String]
    let standardCriteria: String
    let sets: DrillSetsConfig
    let animation: DrillAnimation
    let tutorial: DrillTutorial?
    let videos: [DrillVideo]?
    /// 击球意图（P10 内容管线，ADR-P10-01）。可选——旧 Drill 无此字段照常工作。
    /// 由离线烘焙器 `ShotBaker` 喂给物理引擎，结果回填到 `animation`。
    let shotIntent: ShotIntent?

    init(
        id: String,
        nameZh: String,
        nameEn: String,
        category: String,
        subcategory: String,
        ballType: [String],
        level: String,
        difficulty: Int,
        isPremium: Bool,
        description: String,
        coachingPoints: [String],
        standardCriteria: String,
        sets: DrillSetsConfig,
        animation: DrillAnimation,
        tutorial: DrillTutorial? = nil,
        videos: [DrillVideo]? = nil,
        shotIntent: ShotIntent? = nil
    ) {
        self.id = id
        self.nameZh = nameZh
        self.nameEn = nameEn
        self.category = category
        self.subcategory = subcategory
        self.ballType = ballType
        self.level = level
        self.difficulty = difficulty
        self.isPremium = isPremium
        self.description = description
        self.coachingPoints = coachingPoints
        self.standardCriteria = standardCriteria
        self.sets = sets
        self.animation = animation
        self.tutorial = tutorial
        self.videos = videos
        self.shotIntent = shotIntent
    }

    struct DrillSetsConfig: Codable {
        let defaultSets: Int
        let defaultBallsPerSet: Int
    }
}

struct DrillVideo: Codable, Identifiable, Hashable {
    let id: String
    let file: String
}

struct DrillTutorial: Codable {
    /// 单球形精讲：所有 section 平铺渲染。与 `formations` 二选一。
    /// 可选——多球形 Drill 改用 `formations`；旧 Drill 始终提供 `sections`。
    let sections: [TutorialSection]?
    /// 多球形精讲（可选，ADR-P12-02）：每个球形一段相互隔离的精讲，
    /// UI 用顶部吸顶分段控件切换。存在且非空时优先于 `sections`；旧 Drill 无此字段照常工作。
    let formations: [TutorialFormation]?

    init(sections: [TutorialSection]? = nil, formations: [TutorialFormation]? = nil) {
        self.sections = sections
        self.formations = formations
    }
}

/// 一个「球形」的隔离精讲（多球形 Drill 用，ADR-P12-02）。
struct TutorialFormation: Codable, Identifiable {
    /// 稳定标识，例 `f1`。
    let id: String
    /// 分段控件上显示的短标签，例「球形 A：薄切走位」。
    let title: String
    /// 本球形专属的精讲卡片（与单球形 `sections` 同构，复用同一渲染逻辑）。
    let sections: [TutorialSection]
}

struct TutorialSection: Codable, Identifiable {
    let title: String
    let content: String
    /// 图文精讲配图（静态海报）：`Resources/DrillTutorials/<image>.png`（不含扩展名）。可选——旧 Drill 无此字段照常工作。
    let image: String?
    /// 动态演示片段（可选，mp4，ADR-P12-02）：`Resources/DrillTutorials/<clip>.mp4`（不含扩展名）。
    /// 与 `image`（静态海报）配合——有 clip 时海报上显示播放角标，点击进全屏循环播放。
    /// 内容选用规则：讲位置/几何/落点用静态 `image`；讲运动/走位/杆法效果再加 `clip`。
    let clip: String?
    /// 配图图注（可选，渲染在图下方的细灰字）。
    let caption: String?
    /// 结构化条目（可选，ADR-P11-15）：「标签 + 正文」行，用于逐杆精讲的
    /// 为什么/怎么打/自检，或常见错误的逐条列表。渲染为彩色标签 + 段落。
    let items: [TutorialItem]?
    /// 本节击球参数（可选，逐杆精讲节用）：渲染为打点小图标 + 读数 + 力度胶囊，
    /// 与导出 HUD 同组件同口径（`BTSpinMiniIcon` trueScale / `SpinDisplay` / `PowerDisplay`）。
    let params: TutorialShotParams?

    var id: String { title }

    init(title: String, content: String, image: String? = nil, clip: String? = nil,
         caption: String? = nil, items: [TutorialItem]? = nil, params: TutorialShotParams? = nil) {
        self.title = title
        self.content = content
        self.image = image
        self.clip = clip
        self.caption = caption
        self.items = items
        self.params = params
    }
}

struct TutorialItem: Codable, Identifiable {
    let label: String
    let text: String

    var id: String { label }
}

struct TutorialShotParams: Codable {
    /// 打点（皮头中心偏移/R，同 `ShotIntent.Spin` 语义）。
    let spinX: Double
    let spinY: Double
    /// 杆头速度 (m/s)。
    let velocity: Double
}

// MARK: - Animation Types

struct DrillAnimation: Codable {
    let cueBall: BallAnimation
    let targetBall: BallAnimation
    let pocket: String
    let cueDirection: CanvasPoint
    /// 轨迹来源（P10 内容管线，ADR-P10-01）：`"manual"`（手画，缺省）或 `"baked"`（引擎烘焙）。
    /// 可选——旧 JSON 无此字段，解码为 nil，渲染层视同手画。
    var source: String? = nil
    /// 烘焙器标识（可追溯、可重烘焙），例 `"ShotBaker/engine@v2-geom"`。
    var generator: String? = nil
}

struct BallAnimation: Codable {
    let start: CanvasPoint
    let path: [PathPoint]
}

struct CanvasPoint: Codable {
    let x: Double
    let y: Double
}

struct PathPoint: Codable {
    let x: Double
    let y: Double
    let cp1: CanvasPoint?
    let cp2: CanvasPoint?

    init(x: Double, y: Double, cp1: CanvasPoint? = nil, cp2: CanvasPoint? = nil) {
        self.x = x
        self.y = y
        self.cp1 = cp1
        self.cp2 = cp2
    }

    var isCurve: Bool {
        cp1 != nil && cp2 != nil
    }

    var endPoint: CanvasPoint {
        CanvasPoint(x: x, y: y)
    }
}

// MARK: - Index

struct DrillIndex: Codable {
    let version: Int
    let categories: [CategoryGroup]

    struct CategoryGroup: Codable {
        let category: String
        let drills: [String]
    }

    var allDrillIds: [String] {
        categories.flatMap(\.drills)
    }
}

// MARK: - Category Metadata

enum DrillCategory: String, CaseIterable, Identifiable {
    case fundamentals
    case accuracy
    case cueAction
    case separation
    case positioning
    case forceControl
    case specialShots
    case combined

    var id: String { rawValue }

    var nameZh: String {
        switch self {
        case .fundamentals:  return "基础功"
        case .accuracy:      return "准度训练"
        case .cueAction:     return "杆法训练"
        case .separation:    return "分离角"
        case .positioning:   return "走位训练"
        case .forceControl:  return "控力训练"
        case .specialShots:  return "特殊球路"
        case .combined:      return "综合球形"
        }
    }

    var icon: String {
        switch self {
        case .fundamentals:  return "figure.stand"
        case .accuracy:      return "scope"
        case .cueAction:     return "arrow.up.and.down"
        case .separation:    return "arrow.triangle.branch"
        case .positioning:   return "arrow.triangle.turn.up.right.diamond"
        case .forceControl:  return "gauge.with.dots.needle.33percent"
        case .specialShots:  return "sparkles"
        case .combined:      return "square.grid.3x3"
        }
    }
}

// MARK: - Service

/// Loads bundled Drill JSON. Future: merge with self-hosted `GET /drills` for OTA updates (ADR-002).
actor DrillContentService {

    static let shared = DrillContentService()
    private init() {}

    // MARK: Bundle

    func loadFallbackDrills() -> [DrillContent] {
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Drills") else {
            return []
        }
        guard let indexData = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode(DrillIndex.self, from: indexData) else {
            return []
        }

        return index.allDrillIds.compactMap { drillId in
            loadDrillFromBundle(id: drillId)
        }
    }

    func loadDrillIndex() -> DrillIndex? {
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Drills"),
              let indexData = try? Data(contentsOf: indexURL) else {
            return nil
        }
        return try? JSONDecoder().decode(DrillIndex.self, from: indexData)
    }

    func loadDrillFromBundle(id: String) -> DrillContent? {
        let categories = DrillCategory.allCases.map(\.rawValue)
        for category in categories {
            let subdir = "Drills/\(category)"
            if let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: subdir),
               let data = try? Data(contentsOf: url),
               let drill = try? JSONDecoder().decode(DrillContent.self, from: data) {
                return drill
            }
        }
        return nil
    }

    // v25 W1：引擎渲染视频下线后无调用方；`DrillVideo` / `videos` 字段仍保留
    // （D-v25-1 预留真人示范）。恢复真人示范时再恢复 Bundle 解析即可。
    // nonisolated func videoURL(drillId: String, file: String) -> URL? { ... }

    /// Resolves a tutorial motion clip (mp4) bundled at `Resources/DrillTutorials/<name>.mp4`.
    /// Pass the `clip` name without extension (same convention as tutorial `image`). ADR-P12-02.
    nonisolated func tutorialClipURL(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "DrillTutorials")
    }
}
