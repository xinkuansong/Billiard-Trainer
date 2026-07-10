//
//  DrillBoardBuilder.swift
//  QiuJi
//
//  动作库 drill → 编排台球形（试打模式数据通路，方案 20260709-动作库试打模式）。
//
//  把一条 `DrillContent` 的根级球局转换为 `BoardSnapshot`，供
//  `PositionPlayComposerView(initialBoard:)` 的试打变体载入。
//
//  球号映射约定（本方案约定，obstacles 在 JSON 中无球号）：
//  - `shotIntent.shots[0].cue` → `"cueBall"`
//  - `shotIntent.shots[0].target` → `"_8"`（与详情页 `DrillSceneController` 演示用 8 号一致）
//  - `shotIntent.shots[0].obstacles[i]` → `"_1"`, `"_2"`, …（依序编号，跳过 `_8`）
//  - 无 `shotIntent` 时从 `animation.cueBall.start / targetBall.start` 兜底双球局。
//
//  坐标契约（geometry-spatial-reasoning）：drill JSON 与 `BoardSnapshot.onTable` 同为
//  归一化 2D 系（原点=台面左上角，x 右增 ∈[0,1]，y 下增 ∈[0,0.5]；真源
//  `Resources/Drills/schema.md` / `PositionPlayModels.swift`），转换为恒等直传，
//  零轴向/符号变换。多杆 drill（如 c042）只摆首杆局面，用户自行连续击打。
//

import Foundation

enum DrillBoardBuilder {

    /// 目标球固定映射为 8 号（与详情页演示一致）。
    static let targetKey = "_8"

    /// 把 drill 的根级球局转换为编排台球形。
    /// - Returns: 至少含母球 + 目标球的快照；drill 数据不完整（无 shotIntent 且
    ///   animation 缺摆位信息）时返回 nil。
    static func board(for drill: DrillContent) -> BoardSnapshot? {
        if let shot = drill.shotIntent?.shots.first {
            return board(fromShot: shot)
        }
        return board(fromAnimation: drill.animation)
    }

    /// 试打页首杆意图（进场说明卡「参考打法」用）：优先 shotIntent 首杆。
    static func referenceShot(for drill: DrillContent) -> ShotIntent.Shot? {
        drill.shotIntent?.shots.first
    }

    // MARK: - shotIntent path

    private static func board(fromShot shot: ShotIntent.Shot) -> BoardSnapshot? {
        var onTable: [String: CanvasPoint] = [
            PositionPlayBall.cueKey: shot.cue,
            targetKey: shot.target,
        ]
        // obstacles 依序编号 _1, _2, …，跳过目标球占用的 _8。
        var number = 1
        for point in shot.obstacles ?? [] {
            while "_\(number)" == targetKey { number += 1 }
            guard number <= 15 else { break }
            onTable["_\(number)"] = point
            number += 1
        }
        return BoardSnapshot(onTable: onTable)
    }

    // MARK: - animation fallback (双球局)

    private static func board(fromAnimation animation: DrillAnimation) -> BoardSnapshot? {
        let cue = animation.cueBall.start
        let target = animation.targetBall.start
        return BoardSnapshot(onTable: [
            PositionPlayBall.cueKey: cue,
            targetKey: target,
        ])
    }
}
