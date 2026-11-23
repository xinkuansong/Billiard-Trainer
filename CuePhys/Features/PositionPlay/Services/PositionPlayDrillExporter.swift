import Foundation

/// 把走位序列导出为符合 `Resources/Drills/schema.md` 的 `DrillContent` JSON（ADR-P11-01）。
///
/// 映射：每个 `SequenceStep` → 一个 `ShotIntent.Shot`（cue/target 取该步 `before` 摆位，
/// pocket/velocity/spin 取 `shot`，其余在桌球进 `obstacles` 前向兼容字段）。`animation`
/// 用首杆合成一个最小可解码占位（运行时优先 `shotIntent`，渲染层不依赖它）。
enum PositionPlayDrillExporter {

    /// Drill JSON（`shotIntent.shots[]`）只能表达「目标球 + 袋口」进攻杆；
    /// 含自由球（`PlannedShot.isFree`）的序列无法导出为训练关卡（视频/GIF 不受限）。
    static func canExport(_ sequence: PositionPlaySequence) -> Bool {
        !sequence.steps.isEmpty && !sequence.steps.contains { $0.shot.isFree }
    }

    /// 生成 `DrillContent` 值（可再编码为 JSON）。
    static func makeDrill(
        from sequence: PositionPlaySequence,
        idPrefix: String = "drill_pp",
        category: String = DrillCategory.positioning.rawValue,
        isPremium: Bool = false
    ) -> DrillContent {
        let drillId = "\(idPrefix)_\(sequence.id.uuidString.prefix(8).lowercased())"

        let shots: [ShotIntent.Shot] = sequence.steps.map { step in
            let before = step.before
            let cue = before.onTable[PositionPlayBall.cueKey] ?? CanvasPoint(x: 0.3, y: 0.25)
            let target = before.onTable[step.shot.targetKey] ?? CanvasPoint(x: 0.6, y: 0.25)
            let obstacles = before.onTable
                .filter { $0.key != PositionPlayBall.cueKey && $0.key != step.shot.targetKey }
                .map { $0.value }
            return ShotIntent.Shot(
                cue: cue,
                target: target,
                pocket: step.shot.pocket,
                velocity: step.shot.velocity,
                spin: ShotIntent.Spin(x: step.shot.spinX, y: step.shot.spinY),
                elevation: nil,
                obstacles: obstacles.isEmpty ? nil : obstacles
            )
        }

        let animation = makePlaceholderAnimation(from: sequence)

        return DrillContent(
            id: drillId,
            nameZh: sequence.name,
            nameEn: "Position Play \(drillId)",
            category: category,
            subcategory: "runOut",
            ballType: ["chinese8"],
            level: "L2",
            difficulty: min(5, max(1, 1 + sequence.steps.count / 2)),
            isPremium: isPremium,
            description: "走位编排台生成的走位序列（\(sequence.steps.count) 杆）。",
            coachingPoints: ["按序逐杆击打", "注意每杆母球落点为下一杆做准备"],
            standardCriteria: "依序完成全部 \(sequence.steps.count) 杆走位",
            sets: DrillContent.DrillSetsConfig(defaultSets: 3, defaultBallsPerSet: max(1, sequence.steps.count)),
            animation: animation,
            tutorial: nil,
            videos: nil,
            shotIntent: ShotIntent(version: 1, shots: shots)
        )
    }

    /// 编码为 JSON Data（pretty-printed，便于落库/审阅）。
    static func makeJSON(from sequence: PositionPlaySequence) throws -> Data {
        let drill = makeDrill(from: sequence)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(drill)
    }

    /// 首杆合成的最小动画占位（满足 `DrillAnimation` 非可选要求，运行时优先 `shotIntent`）。
    private static func makePlaceholderAnimation(from sequence: PositionPlaySequence) -> DrillAnimation {
        let first = sequence.steps.first
        let before = first?.before ?? sequence.initial
        let targetKey = first?.shot.targetKey ?? before.targetCandidates.first ?? "_1"
        let cue = before.onTable[PositionPlayBall.cueKey] ?? CanvasPoint(x: 0.3, y: 0.25)
        let target = before.onTable[targetKey] ?? CanvasPoint(x: 0.6, y: 0.25)
        return DrillAnimation(
            cueBall: BallAnimation(start: cue, path: [PathPoint(x: target.x, y: target.y)]),
            targetBall: BallAnimation(start: target, path: [PathPoint(x: target.x, y: target.y)]),
            pocket: first?.shot.pocket ?? "topRight",
            cueDirection: CanvasPoint(x: target.x, y: target.y),
            source: "composer",
            generator: "PositionPlayComposer@v1"
        )
    }
}
