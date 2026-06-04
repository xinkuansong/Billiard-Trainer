//
//  ShotIntent.swift
//  QiuJi
//
//  「击球意图」内容模型（P10 物理升级 · 内容管线雏形，ADR-P10-01）。
//
//  动作库内容从「人工手画贝塞尔结果路径」升级为「物理意图」：作者只描述
//  摆球 / 选袋 / 塞 / 连续力度，由离线烘焙器（`ShotBaker`）喂给物理引擎
//  （`ShotPredictor` + USDZ 对齐球桌 `chineseEightBallQiuJi`）求解出精确轨迹，
//  回填到现有 `DrillAnimation`（渲染层零改动，向后兼容）。
//
//  坐标系：沿用 `Resources/Drills/schema.md` 的归一化系（x∈[0,1] 左→右、
//  y∈[0,0.5] 上→下，俯视 2:1），与 `BTMiniTable` / `CanvasPoint` 完全一致。
//  转场景坐标用既有桥 `AngleSceneCalculator.normalizedToScene`。
//

import SceneKit

// MARK: - Shot Intent (Codable content model)

/// 一个 Drill 的击球意图集合。绝大多数 Drill 为单杆球（`shots` 长度 1）；
/// `combined` / `positioning` 等多杆球可列多个 shot（v1 逐杆独立烘焙）。
struct ShotIntent: Codable {
    var version: Int
    var shots: [Shot]

    /// 单杆击球的物理意图。
    struct Shot: Codable {
        /// 母球摆位（归一化，同 schema.md 坐标系）。
        var cue: CanvasPoint
        /// 目标球摆位（归一化）。
        var target: CanvasPoint
        /// 选袋（schema.md Pocket IDs：topLeft / topRight / bottomLeft / bottomRight / topCenter / bottomCenter）。
        var pocket: String
        /// 连续杆头速度 (m/s)。**用户要求连续值以支持精准走位**，不用 5 档枚举。
        /// 参考锚点（非约束）：轻 1.6 / 中轻 2.4 / 中 3.3 / 中重 4.4 / 大力 5.8。
        var velocity: Double
        /// 可选打点（塞）。`x`:+左塞/−右塞，`y`:+高杆/−低杆，∈[-1,1]。缺省 {0,0}（中心定杆）。
        var spin: Spin?
        /// 可选球杆仰角（弧度）。缺省 0。
        var elevation: Double?
        /// 可选额外障碍球 / 多球摆位（归一化）。v1 烘焙器不处理，仅前向兼容。
        var obstacles: [CanvasPoint]?
    }

    /// 打点（塞）。-1..1，与 `ShotInput.spinX/spinY` 同义。
    struct Spin: Codable {
        var x: Double
        var y: Double
    }
}

// MARK: - Pocket ID ↔ index

extension ShotIntent {
    /// schema.md Pocket ID → `AngleSceneCalculator.pocketPositions` 索引 (0..5)。
    static func pocketIndex(for pocketId: String) -> Int? {
        switch pocketId {
        case "topLeft":      return 0
        case "topRight":     return 1
        case "bottomLeft":   return 2
        case "bottomRight":  return 3
        case "topCenter":    return 4
        case "bottomCenter": return 5
        default:             return nil
        }
    }

    /// `pocketPositions` 索引 (0..5) → schema.md Pocket ID。
    static func pocketId(for index: Int) -> String? {
        switch index {
        case 0: return "topLeft"
        case 1: return "topRight"
        case 2: return "bottomLeft"
        case 3: return "bottomRight"
        case 4: return "topCenter"
        case 5: return "bottomCenter"
        default: return nil
        }
    }
}

// MARK: - Intent → engine input

extension ShotIntent.Shot {
    /// 把归一化意图翻译成物理引擎入参 `ShotInput`。
    /// - Parameter surfaceY: 台面世界 Y（默认 `TablePhysics.tableSurfaceY`，与运行时引擎一致）。
    /// - Returns: 可烘焙的 `ShotInput`；选袋 ID 非法时返回 nil。
    func shotInput(surfaceY: Float = TablePhysics.tableSurfaceY) -> ShotInput? {
        guard let pocketIndex = ShotIntent.pocketIndex(for: pocket) else { return nil }
        let cueScene = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: cue.x, y: cue.y), surfaceY: surfaceY
        )
        let targetScene = AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: target.x, y: target.y), surfaceY: surfaceY
        )
        return ShotInput(
            cueBall: cueScene,
            targetBall: targetScene,
            pocketIndex: pocketIndex,
            velocity: Float(velocity),
            spinX: Float(spin?.x ?? 0),
            spinY: Float(spin?.y ?? 0),
            elevation: Float(elevation ?? 0),
            surfaceY: surfaceY
        )
    }
}
