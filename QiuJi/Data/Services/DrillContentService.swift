import Foundation
import OSLog

// MARK: - DTOs (Bundle JSON; future: REST API OTA)

struct DrillContent: Codable, Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let category: String
    /// 副分类标签（v31 R1）。主分类 `category` 仍是单值真源——目录归属、统计归属、
    /// 详情主徽章一律只看它；副分类只影响动作库浏览与筛选，**不参与任何统计**。
    /// 可选——旧 JSON 无此字段照常解码；每条 drill 至多 1 个（内容侧约束，见契约 §3.3）。
    let secondaryCategories: [String]?
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
        secondaryCategories: [String]? = nil,
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
        self.secondaryCategories = secondaryCategories
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
        /// 汇总兜底：全部球形轮数之和。`perFormation` 就位后由内容侧保持 `Σ defaultRounds`。
        let defaultSets: Int
        /// 汇总兜底：主球形每轮球数。多球形异构时不足以还原真实剂量，仅供未展开场景显示。
        let defaultBallsPerSet: Int
        /// 逐球形剂量（v31 R3）。可选——旧 JSON 无此字段照常解码，消费方回落到上面两个汇总值。
        let perFormation: [FormationDose]?

        init(defaultSets: Int, defaultBallsPerSet: Int, perFormation: [FormationDose]? = nil) {
            self.defaultSets = defaultSets
            self.defaultBallsPerSet = defaultBallsPerSet
            self.perFormation = perFormation
        }
    }

    /// 一个球形的训练剂量（v31 R3：剂量下沉到球形级）。
    struct FormationDose: Codable, Identifiable, Equatable {
        /// 球形 token，与序列文件名 token / `tutorial.formations[].id` 同一取值（契约 §3.1）。
        let token: String
        /// 训练模式，决定 `ballsPerRound` 的语义与是否受几何校验约束。
        let mode: DoseMode
        /// 每轮球数。`sequence` 型**锁死 = 序列实测杆数**（不变量 I6b）；
        /// `repetition` 型 = 每位置颗数，形状约束 8–15、默认 15（契约 §5.6.2，v34 R13）。
        let ballsPerRound: Int
        /// 轮数。`repetition` 型 = 位置数（= 序列实测杆数，位置全覆盖）；
        /// `sequence` 型 = 整链重复遍数（v34 R1/R2）。
        let defaultRounds: Int
        /// 有意例外剂量的说明（v34 R3）。非默认形状（bpr ≠ 15 或轮数 ≠ 杆数）须写明理由，
        /// 门禁 I6b 凭此豁免形状约束。
        let doseNote: String?

        var id: String { token }
    }

    /// 球形训练模式（v31 R3 定稿口径）。
    enum DoseMode: String, Codable, Equatable, CaseIterable {
        /// 走位链：1 轮 = 按序打完序列全部杆数，每轮球数锁死为杆数。
        case sequence
        /// 独立阶梯 / 目录型：序列仅作示范，1 轮 = 重复该球形 `ballsPerRound` 次。
        case repetition
    }
}

struct DrillVideo: Codable, Identifiable, Hashable {
    let id: String
    let file: String
}

/// Tutorial template kind (v26 W0 / tutorial-migration SKILL).
/// Explicit field on `DrillTutorial` — replaces legacy/modern heuristics for routing.
enum DrillTutorialKind: String, Codable, Equatable, CaseIterable, Identifiable {
    /// 单杆技术课（身体动作 / 器材操作 / 0 杆序列 / 缺素材临时版）
    case singleShot
    /// 多杆应用课（有实测击打序列，含多球形单杆形态）
    case multiShot
    /// 规则流程课（开放式挑战：规则 / 计分 / 胜负）
    case ruleset

    var id: String { rawValue }

    /// Short meta-row label on drill cards.
    var cardLabel: String {
        switch self {
        case .singleShot: return "单杆"
        case .multiShot: return "多杆"
        case .ruleset: return "规则"
        }
    }

    /// Filter / accessibility label.
    var filterLabel: String {
        switch self {
        case .singleShot: return "单杆技术课"
        case .multiShot: return "应用课"
        case .ruleset: return "规则流程课"
        }
    }
}

struct DrillTutorial: Codable {
    /// Template kind (singleShot / multiShot / ruleset). Required on bundled drills (v26 W0).
    let tutorialKind: DrillTutorialKind?
    /// 单球形精讲：所有 section 平铺渲染。与 `formations` 二选一。
    /// 可选——多球形 Drill 改用 `formations`；旧 Drill 始终提供 `sections`。
    let sections: [TutorialSection]?
    /// 多球形精讲（可选，ADR-P12-02）：每个球形一段相互隔离的精讲，
    /// UI 用顶部吸顶分段控件切换。存在且非空时优先于 `sections`；旧 Drill 无此字段照常工作。
    let formations: [TutorialFormation]?

    init(
        tutorialKind: DrillTutorialKind? = nil,
        sections: [TutorialSection]? = nil,
        formations: [TutorialFormation]? = nil
    ) {
        self.tutorialKind = tutorialKind
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

/// 精讲配图在 Bundle 内的落位约定（v25 W4 / D-v25-2）。
///
/// 打包的是**发布目录** `Resources/TutorialFigures`（仅被精讲引用者，HEIC，约 112 MB）；
/// PNG 母版留在 `Resources/DrillTutorials`，含孤儿帧共约 4.9 GB，不进包（D-v25-10）。
/// 产物由 `make tutorial-figures` 生成，发布集与新鲜度由 `make verify-gate` 看守。
enum TutorialAssets {
    static let bundleSubdirectory = "TutorialFigures"
    /// 发布产物为 HEIC；png / jpg 保留回退位，供手工补图与历史资产。
    static let imageExtensions = ["heic", "png", "jpg"]
}

struct TutorialSection: Codable, Identifiable {
    let title: String
    /// 段落正文。可选——「常见错误与纠正」这类纯 `items` 列表节没有正文，
    /// 既有内容里同时存在「省略该键」与 `""` 两种写法，二者语义等同（渲染层均不出段落）。
    let content: String?
    /// 图文精讲配图（静态海报）：`Resources/TutorialFigures/<image>.heic`（不含扩展名）。可选——旧 Drill 无此字段照常工作。
    let image: String?
    /// 动态演示片段（可选，mp4，ADR-P12-02）：`Resources/TutorialFigures/<clip>.mp4`（不含扩展名）。
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

    init(title: String, content: String? = nil, image: String? = nil, clip: String? = nil,
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

// MARK: - Diagnostics

/// Bundle 内容解码失败的诊断出口（`.kiro/steering/observability.md`：os_log，不含用户标识、不上传）。
///
/// 存在理由（FL-029）：`loadDrillFromBundle` 曾用 `try?` 吞掉 `DecodingError`，
/// 34/77 条 drill 因缺必填字段而静默消失于动作库，长期无人发现。
enum DrillContentDiagnostics {

    private static let logger = Logger(subsystem: "com.billiardtrainer", category: "DrillContent")

    /// 把 `DecodingError` 压成一行可定位的说明：类型 + codingPath + 原因。
    /// 非 `DecodingError` 原样返回其描述。测试直接断言这段文本。
    static func describe(_ error: Error) -> String {
        func path(_ context: DecodingError.Context) -> String {
            let joined = context.codingPath.map { key -> String in
                if let index = key.intValue { return "[\(index)]" }
                return key.stringValue
            }.joined(separator: ".")
            return joined.isEmpty ? "<root>" : joined
        }
        switch error {
        case let DecodingError.keyNotFound(key, context):
            return "keyNotFound '\(key.stringValue)' at \(path(context)): \(context.debugDescription)"
        case let DecodingError.typeMismatch(type, context):
            return "typeMismatch expected \(type) at \(path(context)): \(context.debugDescription)"
        case let DecodingError.valueNotFound(type, context):
            return "valueNotFound \(type) at \(path(context)): \(context.debugDescription)"
        case let DecodingError.dataCorrupted(context):
            return "dataCorrupted at \(path(context)): \(context.debugDescription)"
        default:
            return String(describing: error)
        }
    }

    static func logDecodeFailure(resource: String, error: Error) {
        logger.error("Bundle content decode failed — \(resource, privacy: .public): \(describe(error), privacy: .public)")
    }

    static func logMissingResource(name: String) {
        logger.error("Bundle content missing — \(name, privacy: .public)")
    }
}

// MARK: - Service

/// Loads bundled Drill JSON. Future: merge with self-hosted `GET /drills` for OTA updates (ADR-002).
actor DrillContentService {

    static let shared = DrillContentService()
    private init() {}

    // MARK: Bundle

    func loadFallbackDrills() -> [DrillContent] {
        guard let index = loadDrillIndex() else { return [] }
        return index.allDrillIds.compactMap { drillId in
            loadDrillFromBundle(id: drillId)
        }
    }

    func loadDrillIndex() -> DrillIndex? {
        guard let indexURL = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Drills") else {
            DrillContentDiagnostics.logMissingResource(name: "Drills/index.json")
            return nil
        }
        do {
            return try JSONDecoder().decode(DrillIndex.self, from: try Data(contentsOf: indexURL))
        } catch {
            DrillContentDiagnostics.logDecodeFailure(resource: "Drills/index.json", error: error)
            return nil
        }
    }

    func loadDrillFromBundle(id: String) -> DrillContent? {
        Self.decodeDrillFromBundle(id: id)
    }

    /// 同步读取（只读 Bundle，不访问 actor 状态）。SwiftData 迁移与构建器回填需要一条
    /// 不经 `await` 的入口（同 `PlanContentService.decodePlanFromBundle`）。
    nonisolated static func decodeDrillFromBundle(id: String) -> DrillContent? {
        for category in DrillCategory.allCases.map(\.rawValue) {
            guard let url = Bundle.main.url(
                forResource: id, withExtension: "json", subdirectory: "Drills/\(category)"
            ) else { continue }
            do {
                return try JSONDecoder().decode(DrillContent.self, from: try Data(contentsOf: url))
            } catch {
                // 解码失败不再静默：文件确实在这个 category 下，继续扫其余 category 也只会
                // 一无所获，故就地报告并返回 nil（签名不变，调用方 compactMap 行为不变）。
                DrillContentDiagnostics.logDecodeFailure(resource: "Drills/\(category)/\(id).json",
                                                        error: error)
                return nil
            }
        }
        DrillContentDiagnostics.logMissingResource(name: "Drills/*/\(id).json")
        return nil
    }

    /// 该 drill 的球形数。优先取剂量声明（v31 内容批落地后为权威），回落到多球形精讲段数；
    /// 两者都没有则按单球形算 1（契约 §5.6：无球形声明按 1 球形处理）。
    /// ⚠️ 这不是球形几何真源——几何真源是序列文件（契约 §1.1），Bundle 内以
    /// `DrillBoards/` 承载；此处只用于剂量折算这类不涉及几何的场景。
    nonisolated static func formationCount(forDrillId id: String) -> Int {
        guard let drill = decodeDrillFromBundle(id: id) else { return 1 }
        if let perFormation = drill.sets.perFormation, !perFormation.isEmpty {
            return perFormation.count
        }
        if let formations = drill.tutorial?.formations, !formations.isEmpty {
            return formations.count
        }
        return 1
    }

    // v25 W1：引擎渲染视频下线后无调用方；`DrillVideo` / `videos` 字段仍保留
    // （D-v25-1 预留真人示范）。恢复真人示范时再恢复 Bundle 解析即可。
    // nonisolated func videoURL(drillId: String, file: String) -> URL? { ... }

    /// Resolves a tutorial motion clip (mp4) bundled at `Resources/TutorialFigures/<name>.mp4`.
    /// Pass the `clip` name without extension (same convention as tutorial `image`). ADR-P12-02.
    nonisolated func tutorialClipURL(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mp4",
                        subdirectory: TutorialAssets.bundleSubdirectory)
    }
}
