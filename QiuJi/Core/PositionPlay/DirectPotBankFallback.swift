import Foundation
import SceneKit

/// 直击进袋失败时的翻袋备选（复用翻袋页同一管线，不另写求解器）。
///
/// 触发口径：仅当**直击几何闸门**失败（切角 ≥89° / 母球挡进球线 → `feasible=false`，
/// 或 `AngleSceneCalculator.isFeasible == false`），才枚举翻袋。走位约束无解但直击可进时不跑。
///
/// 引擎真源：`BankKickSolvePipeline.solveBank` → `ShotPredictor.predictBankAll`。
enum DirectPotBankFallback {

    /// 直击预测是否应触发翻袋备选（袋口模式；自由瞄准永不触发）。
    static func shouldAttemptBank(afterDirect pred: ShotPrediction) -> Bool {
        !pred.feasible
    }

    /// 几何层：当前母球/目标/袋口是否直击不可行（思路/打三在 `PositionPlaySolver` 空结果后的闸门）。
    static func isDirectPotInfeasible(
        cue: SCNVector3, target: SCNVector3, pocketIndex: Int, surfaceY: Float
    ) -> Bool {
        let aim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: pocketIndex, surfaceY: surfaceY
        )
        return !AngleSceneCalculator.isFeasible(cueBall: cue, targetBall: target, pocket: aim)
    }

    /// 翻袋备选全枚举（与翻袋页同入口；默认含 K10 加塞档）。
    static func solveBankAlternatives(
        cue: SCNVector3, object: SCNVector3, pocketIndex: Int,
        surfaceY: Float, power: Float, obstacles: [ObstacleBall] = [],
        spinXValues: [Float] = BankKickSolvePipeline.sideSpinSearchValues
    ) -> [BankEngineSolution] {
        BankKickSolvePipeline.solveBank(
            cue: cue, object: object, pocketIndex: pocketIndex,
            surfaceY: surfaceY, power: power, obstacles: obstacles,
            spinXValues: spinXValues
        )
    }

    /// 从桌面快照装配障碍球（不含母球与目标球）。
    static func obstacles(
        before: BoardSnapshot, targetKey: String, surfaceY: Float
    ) -> [ObstacleBall] {
        before.onTable.compactMap { key, pt in
            guard key != PositionPlayBall.cueKey, key != targetKey else { return nil }
            return ObstacleBall(
                name: key,
                position: PositionPlayShotSolver.scenePoint(pt, surfaceY: surfaceY)
            )
        }
    }

    /// 翻袋解 → 走位反解页 `PositionPlaySolution`（不声称满足落区/过点约束）。
    static func asPositionPlaySolutions(
        _ banks: [BankEngineSolution],
        targetKey: String, pocket: String, velocity: Double
    ) -> [PositionPlaySolution] {
        banks.map { bank in
            let shot = PlannedShot(
                targetKey: targetKey, pocket: pocket,
                velocity: velocity,
                spinX: Double(bank.spinX), spinY: Double(bank.spinY)
            )
            let score = DifficultyModel.score(
                spinX: shot.spinX, spinY: shot.spinY, velocity: shot.velocity,
                cutAngleDeg: bank.prediction.cutAngleDeg, cueTargetDistance: nil
            )
            return PositionPlaySolution(
                shot: shot,
                prediction: bank.prediction,
                cushionCount: bank.prediction.cueCushionCount,
                potted: bank.prediction.simObjectPotted,
                margin: 0,
                summary: statusSummary(bank, index: nil, total: nil),
                satisfiesConstraint: false,
                beyondCushionBudget: false,
                difficultyScore: score,
                difficultyTier: DifficultyModel.tier(spinX: shot.spinX, spinY: shot.spinY),
                beyondSpinBudget: false,
                robustness: bank.robustness
            )
        }
    }

    /// 状态条文案：「翻袋备选 · 左库 → … · 中杆」。
    static func statusSummary(
        _ bank: BankEngineSolution, index: Int?, total: Int?
    ) -> String {
        var parts: [String] = []
        if let index, let total, total > 1 {
            parts.append("翻袋备选 \(index + 1)/\(total)")
        } else {
            parts.append("翻袋备选")
        }
        let route = bank.railSequenceText
        if !route.isEmpty { parts.append(route) }
        parts.append("\(bank.cushions) 库")
        let spin = bank.spinLabel
        if spin != "中杆" { parts.append(spin) }
        return parts.joined(separator: " · ")
    }

    /// 思路/打三空结果后的无解文案（区分「直击不可行且无翻袋」与「走位约束无解」）。
    static func emptySolveMessage(
        directInfeasible: Bool, bankAttempted: Bool, bankEmpty: Bool,
        positionHint: String
    ) -> String {
        if directInfeasible, bankAttempted, bankEmpty {
            return "直击角度过大，且暂无翻袋备选（换袋口或移动球位）"
        }
        return positionHint
    }
}
