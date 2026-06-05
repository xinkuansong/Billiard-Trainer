//
//  PositionPlayModels.swift
//  QiuJi
//
//  走位编排器（Position-Play Composer）内容模型（ADR-P11-01）。
//
//  设计：序列的「真相」是一串桌面快照（`BoardSnapshot`）；每一杆（`SequenceStep`）是
//  「前快照 → 后快照」的一次转移。进袋球离场回球库；母球进袋（scratch）走同一离场逻辑。
//  球号无规则语义，仅作标识。坐标沿用 `Resources/Drills/schema.md` 归一化系
//  （x∈[0,1] 左→右、y∈[0,0.5] 上→下，俯视 2:1），与 `CanvasPoint` / `ShotIntent` 一致。
//

import Foundation

// MARK: - Ball identity

/// 球标识与 `AngleTrainingScene.allBallNodes` / USDZ 提取键完全一致：
/// 母球 `"cueBall"`，目标球 `"_1"`..`"_15"`。
enum PositionPlayBall {
    static let cueKey = "cueBall"
    static let objectKeys: [String] = (1...15).map { "_\($0)" }
    static let allKeys: [String] = [cueKey] + objectKeys

    /// 是否母球。
    static func isCue(_ key: String) -> Bool { key == cueKey }

    /// 球号（目标球 1..15）；母球返回 nil。
    static func number(for key: String) -> Int? {
        guard key.hasPrefix("_"), let n = Int(key.dropFirst()) else { return nil }
        return n
    }

    /// UI 短标签：母球「母」，目标球显示号码。
    static func shortLabel(for key: String) -> String {
        if isCue(key) { return "母" }
        return number(for: key).map(String.init) ?? key
    }
}

// MARK: - Board snapshot

/// 某一时刻的桌面：在桌球键 → 归一化坐标。其余球视为「在库」（off-table）。
struct BoardSnapshot: Codable {
    /// 在桌球：键（`cueBall`/`_n`）→ 归一化坐标。
    var onTable: [String: CanvasPoint]

    init(onTable: [String: CanvasPoint] = [:]) {
        self.onTable = onTable
    }

    /// 在桌球键（无序）。
    var onTableKeys: [String] { Array(onTable.keys) }

    /// 在库球键（可重新选出摆上桌），按号顺序，母球优先。
    var offTableKeys: [String] {
        PositionPlayBall.allKeys.filter { onTable[$0] == nil }
    }

    /// 桌上是否有母球。
    var hasCue: Bool { onTable[PositionPlayBall.cueKey] != nil }

    /// 目标候选键（在桌、非母球），按号排序。
    var targetCandidates: [String] {
        onTableKeys
            .filter { !PositionPlayBall.isCue($0) }
            .sorted { (PositionPlayBall.number(for: $0) ?? 99) < (PositionPlayBall.number(for: $1) ?? 99) }
    }
}

// MARK: - Planned shot

/// 一杆的作者意图：选哪颗目标球、打哪个袋、连续力度与打点。
/// `pocket` 为 schema Pocket ID（topLeft/topRight/bottomLeft/bottomRight/topCenter/bottomCenter）。
struct PlannedShot: Codable {
    var targetKey: String
    var pocket: String
    /// 连续杆头速度 (m/s)。
    var velocity: Double
    /// 水平打点（接触点偏移/R）：+左塞 / −右塞。
    var spinX: Double
    /// 垂直打点（接触点偏移/R）：+高杆 / −低杆。
    var spinY: Double

    init(targetKey: String, pocket: String, velocity: Double, spinX: Double = 0, spinY: Double = 0) {
        self.targetKey = targetKey
        self.pocket = pocket
        self.velocity = velocity
        self.spinX = spinX
        self.spinY = spinY
    }
}

// MARK: - Sequence step

/// 一杆 = 前快照 + 意图 + 引擎求解出的后快照（含进袋离场）。
struct SequenceStep: Codable, Identifiable {
    var id: UUID
    var before: BoardSnapshot
    var shot: PlannedShot
    var after: BoardSnapshot
    /// 本杆进袋离场的球（含母球 scratch）。
    var potted: [String]
    var cuePocketed: Bool
    var objectPocketed: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        before: BoardSnapshot,
        shot: PlannedShot,
        after: BoardSnapshot,
        potted: [String] = [],
        cuePocketed: Bool = false,
        objectPocketed: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.before = before
        self.shot = shot
        self.after = after
        self.potted = potted
        self.cuePocketed = cuePocketed
        self.objectPocketed = objectPocketed
        self.note = note
    }
}

// MARK: - Sequence

/// 一条完整走位序列：开局快照 + 有序击打 Step。
struct PositionPlaySequence: Codable, Identifiable {
    var id: UUID
    var name: String
    var initial: BoardSnapshot
    var steps: [SequenceStep]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        initial: BoardSnapshot = BoardSnapshot(),
        steps: [SequenceStep] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.initial = initial
        self.steps = steps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 当前桌面 = 最后一杆的 after，没有 Step 时 = 开局。
    var currentBoard: BoardSnapshot {
        steps.last?.after ?? initial
    }
}
