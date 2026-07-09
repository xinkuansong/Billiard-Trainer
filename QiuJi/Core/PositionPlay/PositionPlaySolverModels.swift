import Foundation
import SceneKit

/// 走位反解器（思路训练器，ADR-P13-01）的**瞬态**约束输入与解输出。
///
/// 落区/过点是求解器的输入约束，不进 `PlannedShot`、v1 不持久化——只在一次求解期间存在。
/// 求出的解就是标准 `PlannedShot`（含算好的 spin/velocity）+ 一次 `ShotPrediction`。
///
/// 坐标契约（与 `PositionPlayModels` 一致）：约束几何以**归一化系**存储
/// （x∈[0,1] 左→右、y∈[0,0.5] 上→下）；与场景的转换一律走 `AngleSceneCalculator`
/// （SceneKit 水平面 = X–Z，Y 朝上）。归一化→场景两轴缩放均为 `innerLength`(=2×innerWidth)=2.54 m
/// （均匀缩放），故归一化半径映射为场景半径只需乘单一因子。

// MARK: - Constraint

enum SolveConstraint {
    /// 情形 A：母球**停点**落在手画落区内（打一看二的可行区域）。
    case restRegion(SolveRegion)
    /// 情形 B：母球在 **v > vMin（m/s）** 时**经过** point（去 K 球）。
    case passThrough(point: CanvasPoint, vMin: Double)
}

// MARK: - Region (手画落区，归一化系)

enum SolveRegion {
    /// 轴对齐矩形：中心 + 半宽/半高（归一化单位）。
    case rect(center: CanvasPoint, halfWidth: Double, halfHeight: Double)
    /// 圆：中心 + 半径（归一化单位）。
    case circle(center: CanvasPoint, radius: Double)
    /// 落点：母球停在某**精确点**（归一化），`tolerance` 为「命中」容差半径（归一化单位）——
    /// 几何上等价于半径 = tolerance 的圆（各向同性，复用圆公式），但语义是「最小化到点距离」，
    /// 装配/文案与落区分叉（求解返回最近代表、容差内才标满足，见 `solveRestRegion`）。
    case point(center: CanvasPoint, tolerance: Double)

    /// 是否为落点约束（语义分叉用）。
    var isPoint: Bool { if case .point = self { return true } else { return false } }

    /// 约束中心（归一化）。落区/落点统一取中心点。
    var centerNormalized: CanvasPoint {
        switch self {
        case let .rect(center, _, _), let .circle(center, _), let .point(center, _):
            return center
        }
    }

    /// 归一化→场景的单轴缩放因子（米/归一化单位）。X 轴 = innerLength，Y(→Z) 轴 = 2×innerWidth，
    /// 两者相等（2.54），故均匀缩放，半径可乘单一因子。
    static var sceneScale: Float { AngleSceneCalculator.innerLength }

    /// 落区中心的场景坐标。
    func sceneCenter(surfaceY: Float) -> SCNVector3 {
        let center = centerNormalized
        return AngleSceneCalculator.normalizedToScene(
            point: CGPoint(x: center.x, y: center.y), surfaceY: surfaceY)
    }

    /// 场景点 `p` 到落区边界的**有符号水平距离（米）**：区内为负、区外为正、边界为 0。
    /// 用于情形 A 评分（越负越深入区内、越鲁棒）。
    func signedDistanceMeters(fromScene p: SCNVector3, surfaceY: Float) -> Float {
        let scale = Self.sceneScale
        switch self {
        case let .circle(center, radius):
            let c = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: center.x, y: center.y), surfaceY: surfaceY)
            return AngleSceneCalculator.horizontalDistance(p, c) - Float(radius) * scale
        case let .point(center, tolerance):
            // 各向同性圆公式：到点距离 − 容差半径（容差内为负 = 命中）。
            let c = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: center.x, y: center.y), surfaceY: surfaceY)
            return AngleSceneCalculator.horizontalDistance(p, c) - Float(tolerance) * scale
        case let .rect(center, halfWidth, halfHeight):
            let c = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: center.x, y: center.y), surfaceY: surfaceY)
            // 矩形在归一化系轴对齐 ⇒ 映射到场景仍轴对齐（X 对 X、Y 对 Z，均匀缩放）。
            let hw = Float(halfWidth) * scale
            let hh = Float(halfHeight) * scale
            // 标准轴对齐矩形 SDF（XZ 平面）。
            let dx = abs(p.x - c.x) - hw
            let dz = abs(p.z - c.z) - hh
            let outside = hypotf(max(dx, 0), max(dz, 0))
            let inside = min(max(dx, dz), 0)
            return outside + inside
        }
    }

    /// 场景点是否落在区内（含边界）。
    func contains(scene p: SCNVector3, surfaceY: Float) -> Bool {
        signedDistanceMeters(fromScene: p, surfaceY: surfaceY) <= 0
    }
}

// MARK: - Solution

/// 反解出的一个解（一个吃库族/速度分段的代表）。
struct PositionPlaySolution: Identifiable {
    let id = UUID()
    /// 标准化击球意图（含求出的 spin/velocity + 目标球/袋口）。
    let shot: PlannedShot
    /// 该解的完整物理预测（轨迹/进球线/假想球/停点等，供渲染与回放）。
    let prediction: ShotPrediction
    /// 该解的吃库数（情形 A = 碰球后母球吃库数；情形 B = 到达 P 前吃库数）。
    let cushionCount: Int
    /// 目标球是否真正进选定袋（硬约束满足）。
    let potted: Bool
    /// 与约束的余量（米）：
    /// - 情形 A：母球停点到落区边界的有符号距离取负（区内为正余量 = 离边界多远，越大越鲁棒）。
    /// - 情形 B：母球过 P 后第一颗碰撞球到最近袋口的距离（越小越利于 K 进袋）。
    let margin: Float
    /// 一句话说明（UI 文字解释，如「左塞 0.3 · 中等力度 3.2 · 1 库 · 余量 12cm」）。
    let summary: String
    /// 该解是否完全满足约束（落区内 / 过点成功）。false = 最接近降级解。
    let satisfiesConstraint: Bool
    /// 是否为「走位复杂度预算」兜底解：用户选了「仅基础走位（≤N 库）」但该预算内无解，
    /// 回退展示的超预算（更多吃库）解，UI 标「进阶」。默认 false（不限预算 / 预算内解）。
    var beyondCushionBudget: Bool = false
    /// 综合执行难度评分（E2，`DifficultyModel.score`：塞加权范数 + 力度惩罚 + 切角/球距）。
    /// 越大越难；用户可读档位见 `DifficultyModel.gradeLabel`。
    var difficultyScore: Double = 0
    /// 所需杆法档位（E2）：中杆即可 / 需高低杆 / 需横塞 / 需极限塞。
    var difficultyTier: ShotDifficultyTier = .center
    /// 是否为「塞幅预算」兜底解（E3）：`maxSpinTier` 预算内无解、回退展示的更难杆法解。
    var beyondSpinBudget: Bool = false
    /// 扰动容错度（E5，0–1）：对本解做小幅参数扰动（瞄准/力度/打点）后仍满足约束的比例。
    /// nil = 未启用容错分析（默认关，`SearchParams.robustnessEnabled`）。
    var robustness: Double?
}
