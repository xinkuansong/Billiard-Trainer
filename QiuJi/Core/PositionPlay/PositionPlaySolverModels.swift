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
    /// 扇形（打一走二想三 ②号球停球扇形，Q15.1）：一个或多个**环形扇区**的并集，
    /// 共享顶点 `apex`（②号球假想球位，归一化系）+ 半径带 `[radiusMin, radiusMax]`（**米**，
    /// 非归一化——它们是物理停球距离 sMin/sMax）+ 若干角区间 `intervals`（场景 XZ 系 bearing 弧度，
    /// bearing = atan2(z, x)，与 `AngleSceneCalculator.rotatedAim`/`bearingDeg` 同口径）。
    /// 无③号 → 两侧两个扇区（intervals.count==2）；有③号 → 朝③那一侧单扇区。
    /// SDF 取各扇区有符号距离的 `min`（并集：区内为负，取最深入者）。禁外接矩形近似——
    /// 直接对环形扇区四条边界（内/外弧 + 两条径向边）算精确有符号距离。
    case sector(apex: CanvasPoint, radiusMin: Double, radiusMax: Double, intervals: [SectorAngleInterval])

    /// 扇形角区间（场景 XZ 系 bearing 弧度）。约定 `lo < hi` 且 `hi − lo < π`（本用途恒为 15°）。
    struct SectorAngleInterval: Equatable {
        var lo: Double
        var hi: Double
    }

    /// 是否为落点约束（语义分叉用）。
    var isPoint: Bool { if case .point = self { return true } else { return false } }

    /// 是否为扇形约束（视觉/求解分叉用）。
    var isSector: Bool { if case .sector = self { return true } else { return false } }

    /// 约束中心（归一化）。落区/落点取中心点；扇形取顶点（假想球位）。
    var centerNormalized: CanvasPoint {
        switch self {
        case let .rect(center, _, _), let .circle(center, _), let .point(center, _):
            return center
        case let .sector(apex, _, _, _):
            return apex
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
        case let .sector(apex, rMin, rMax, intervals):
            // 顶点归一化→场景（仅平移+均匀缩放，无旋转/镜像 ⇒ 场景 bearing 与 intervals 一致）。
            let a = AngleSceneCalculator.normalizedToScene(
                point: CGPoint(x: apex.x, y: apex.y), surfaceY: surfaceY)
            // radiusMin/Max 已是米，直接用（非归一化，不乘 sceneScale）。
            var best = Float.greatestFiniteMagnitude
            for iv in intervals {
                best = min(best, Self.annularSectorSDF(
                    p: p, apex: a, rMin: Float(rMin), rMax: Float(rMax),
                    lo: Float(iv.lo), hi: Float(iv.hi)))
            }
            return best
        }
    }

    /// 场景点是否落在区内（含边界）。
    func contains(scene p: SCNVector3, surfaceY: Float) -> Bool {
        signedDistanceMeters(fromScene: p, surfaceY: surfaceY) <= 0
    }

    // MARK: - 环形扇区 SDF（Q15.1，纯 XZ 平面，米）

    /// 单个环形扇区的有符号距离（区内为负）。边界 = 内弧 + 外弧 + 两条径向边（线段）。
    /// signed = inside ? −d : +d，其中 d = 点到四条边界的最近距离——精确、鲁棒（数值草稿对齐
    /// 暴力最近点，误差 ~1e-8）。角区间约定 `lo<hi` 且 `hi−lo<π`。
    static func annularSectorSDF(p: SCNVector3, apex a: SCNVector3,
                                 rMin: Float, rMax: Float, lo: Float, hi: Float) -> Float {
        let vx = p.x - a.x, vz = p.z - a.z
        let r = hypotf(vx, vz)
        let phi = atan2f(vz, vx)
        let inside = r >= rMin && r <= rMax && angleWithin(phi, lo: lo, hi: hi)
        func edgeDist(_ ang: Float) -> Float {
            let cx = cosf(ang), cz = sinf(ang)
            let s0 = SCNVector3(a.x + rMin * cx, a.y, a.z + rMin * cz)
            let s1 = SCNVector3(a.x + rMax * cx, a.y, a.z + rMax * cz)
            return pointSegmentDistXZ(p, s0, s1)
        }
        let d = min(min(arcDistXZ(p, a, rMin, lo, hi), arcDistXZ(p, a, rMax, lo, hi)),
                    min(edgeDist(lo), edgeDist(hi)))
        return inside ? -d : d
    }

    /// 角 `phi` 是否落在 `[lo, hi]`（弧度）内。把 `phi−lo` 归一化到 (−π, π] 再判 `0…(hi−lo)`。
    private static func angleWithin(_ phi: Float, lo: Float, hi: Float) -> Bool {
        var d = phi - lo
        while d > .pi { d -= 2 * .pi }
        while d <= -.pi { d += 2 * .pi }
        return d >= -1e-6 && d <= (hi - lo) + 1e-6
    }

    /// 点到「角区间受限圆弧」的最近距离：投影角在区间内 → ||v|−R|；否则取两端点较近者。
    private static func arcDistXZ(_ p: SCNVector3, _ a: SCNVector3, _ radius: Float,
                                  _ lo: Float, _ hi: Float) -> Float {
        let vx = p.x - a.x, vz = p.z - a.z
        let r = hypotf(vx, vz)
        let phi = atan2f(vz, vx)
        if angleWithin(phi, lo: lo, hi: hi) { return abs(r - radius) }
        let eLo = SCNVector3(a.x + radius * cosf(lo), a.y, a.z + radius * sinf(lo))
        let eHi = SCNVector3(a.x + radius * cosf(hi), a.y, a.z + radius * sinf(hi))
        return min(AngleSceneCalculator.horizontalDistance(p, eLo),
                   AngleSceneCalculator.horizontalDistance(p, eHi))
    }

    /// 点到线段的 XZ 平面最近距离。
    private static func pointSegmentDistXZ(_ p: SCNVector3, _ a: SCNVector3, _ b: SCNVector3) -> Float {
        let vx = b.x - a.x, vz = b.z - a.z
        let ll = vx * vx + vz * vz
        guard ll > 1e-12 else { return AngleSceneCalculator.horizontalDistance(p, a) }
        var t = ((p.x - a.x) * vx + (p.z - a.z) * vz) / ll
        t = max(0, min(1, t))
        let cx = a.x + vx * t, cz = a.z + vz * t
        return hypotf(p.x - cx, p.z - cz)
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

// MARK: - Constraint draft（跨反解页共享的「用户所画约束」草稿，G17）

/// 反解页约束草稿（归一化系）——思路训练 / 打一走二想三共用。
///
/// 与 `SolveConstraint` 的区别：`Draft` **保留视觉/语义分叉**（`SolveConstraint` 会把
/// 「落点 `.restPoint`」与「落区圆 `.region(.point)`」都塌缩为 `.restRegion(.point)`，
/// 丢失了「琥珀十字+容差环」与「青色圈」的区别）。`Draft` 是「上一杆」忠实还原绘制层所需
/// 的最小信息；`currentConstraint()` 由它派生 `SolveConstraint` 喂求解器。
/// 各页 VM 以 `typealias Draft = SolveConstraintDraft` 复用，避免重复定义。
enum SolveConstraintDraft {
    case region(SolveRegion)
    case restPoint(CanvasPoint)
    case passPoint(CanvasPoint)
}

// MARK: - Undo snapshot（G17「上一杆」完整快照，共享口径）

/// 反解页「上一杆」**完整快照**（纯内存态，不持久化 → 无 Codable / 向后兼容负担）。
///
/// 承载一杆击打前的**可恢复求解上下文**：桌面球形 + 该杆意图/预测 + 用户所画约束草稿 +
/// **已求出的全部解（缓存回填，「上一杆」后无需重画约束、无需重新求解）** + 只读参数指示 +
/// 求解选项。这是 `PositionPlayViewModel.restoreShotParams`（袋口/自由瞄准的全参数恢复）
/// 在**反解页**（约束驱动、结果是「解集」）的对应物。
///
/// **页面特有的选择模型**（思路页的「目标球+袋口」、打三页的「①②③ 角色指派」）不进本结构，
/// 由各 VM 以本快照为基座、另行携带（见各 VM 的 `*UndoContext`）。V8（防守）/V9（翻袋·反射）
/// 落地时复用本结构，只需为其页面特有选择模型加一层同款 `UndoContext` 包装。
struct SolveShotSnapshot {
    /// 击打前的桌面球形（归一化系）。
    var before: BoardSnapshot
    /// 该杆意图（目标/袋口/打点/力度/自由瞄准）。
    var shot: PlannedShot
    /// 该杆物理预测（轨迹/进球线/回放 recorder）。
    var prediction: ShotPrediction

    /// 击打前已求出的全部解与当前档位——「解还在」：直接回填，免重解。
    var solutions: [PositionPlaySolution]
    var currentIndex: Int

    /// 击打前用户所画的约束草稿（nil = 无约束）。
    var draft: SolveConstraintDraft?

    /// 只读参数指示（当前解的打点/力度）。
    var velocity: Double
    var spinX: Double
    var spinY: Double

    /// 求解选项（禁横塞 / 仅基础走位）。
    var allowSideSpin: Bool
    var basicPositionOnly: Bool
}
