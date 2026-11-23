//
//  DifficultyModel.swift
//  QiuJi
//
//  可执行性感知求解（E1/E2/E4，docs/research/20260709-可执行性感知求解方案.md）。
//
//  教学产品共识：反解不只回答「解是否存在」，还要建模「人打起来难不难」。
//  本文件是全部难度语义的**单一真源**：
//  - 执行难度加权范数（E1）：横塞（spinX）对业余玩家的难度远高于高低杆（spinY）——
//    需同时补偿 squirt/弧线/随力度变化的偏移；高低杆只改碰后走位、不改瞄准。权重 2.5:1。
//  - 力度惩罚（E1）：大力杆瞄准精度骤降，超过阈值按超出量线性加罚。
//  - 塞幅/难度分档（E2/E3）：语义标签与 `maxSpinTier` 预算的档位定义。
//  - 进球难度（E4）：薄球（大切角）+ 远距离折算进难度评分（不改硬约束，只影响排序与标注）。
//
//  红线：本层只参与「偏好 / 挑选 / 呈现」，不触碰搜索网格与引擎复核流水线
//  （性能约束见方案 §1；每批改动以 SolverPerformanceTests 真实输出验收）。
//

import Foundation

// MARK: - Tier (难度档位，E2/E3)

/// 按「所需杆法」分档（机器可读，供排序与 `maxSpinTier` 预算；语义标签供 UI）。
enum ShotDifficultyTier: Int, Comparable, CaseIterable {
    /// 中杆即可（无塞或幅值可忽略）。
    case center = 0
    /// 需高低杆（无横塞）。
    case vertical = 1
    /// 需横塞（|spinX| ≤ 0.3R，半颗塞以内）。
    case side = 2
    /// 需极限塞（|spinX| > 0.3R，接近打滑极限）。
    case extremeSide = 3

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .center: return "中杆即可"
        case .vertical: return "需高低杆"
        case .side: return "需横塞"
        case .extremeSide: return "需极限塞"
        }
    }
}

// MARK: - Model

enum DifficultyModel {

    // MARK: 常量（方案 §2 拍板默认值，集中可调）

    /// 横塞难度权重（相对高低杆 1.0）。
    static let sideSpinWeight = 2.5
    /// 高低杆难度权重（基准）。
    static let verticalSpinWeight = 1.0
    /// 力度惩罚阈值（m/s）：超过此速度瞄准精度显著下降。
    static let velocityPenaltyThreshold = 4.0
    /// 力度惩罚斜率（effort / (m/s)）。
    static let velocityPenaltySlope = 0.25
    /// 塞幅分档线（接触点偏移 / R）：微塞 / 半颗 / 极限。
    static let spinTierBoundaries = (light: 0.15, half: 0.3, limit: 0.5)
    /// 「无塞」判定阈（浮点噪声容差）。
    static let spinEps = 0.02

    /// 切角难度起算点（度）与满档跨度：60° 起算、~90° 满档。
    static let cutAngleOnsetDeg = 60.0
    static let cutAngleSpanDeg = 30.0
    static let cutAngleWeight = 0.8
    /// 标注「薄球」的切角阈（度）。
    static let thinCutLabelDeg = 75.0
    /// 球距难度起算点（米）与斜率。
    static let distanceOnsetMeters = 1.0
    static let distanceSlope = 0.3

    // MARK: 执行难度（E1，排序用加权范数）

    /// 执行难度加权范数：`wX·|spinX| + wY·|spinY| + 力度惩罚`。
    /// 取代旧对称范数 `√(x²+y²)`（对称范数会让 spinX=0.3 赢过 spinY=0.4 的纯高低杆解，
    /// 与「横塞远难于高低杆」的教学事实相反）。
    static func executionEffort(spinX: Double, spinY: Double, velocity: Double) -> Double {
        sideSpinWeight * abs(spinX) + verticalSpinWeight * abs(spinY) + velocityPenalty(velocity)
    }

    /// 力度惩罚：低于阈值为 0，高于阈值线性增长。
    static func velocityPenalty(_ velocity: Double) -> Double {
        max(0, velocity - velocityPenaltyThreshold) * velocityPenaltySlope
    }

    // MARK: 档位（E2/E3）

    static func tier(spinX: Double, spinY: Double) -> ShotDifficultyTier {
        let sx = abs(spinX)
        if sx <= spinEps {
            return abs(spinY) <= spinEps ? .center : .vertical
        }
        return sx <= spinTierBoundaries.half + 1e-9 ? .side : .extremeSide
    }

    // MARK: 难度评分（E2 + E4）

    /// 综合难度评分（无量纲，越大越难）。`cutAngleDeg`/`cueTargetDistance` 为进球难度输入
    /// （E4，可选——斯诺克等无进球语义的解传 nil）。
    static func score(
        spinX: Double, spinY: Double, velocity: Double,
        cutAngleDeg: Double? = nil, cueTargetDistance: Double? = nil
    ) -> Double {
        var s = executionEffort(spinX: spinX, spinY: spinY, velocity: velocity)
        if let cut = cutAngleDeg {
            s += max(0, cut - cutAngleOnsetDeg) / cutAngleSpanDeg * cutAngleWeight
        }
        if let d = cueTargetDistance {
            s += max(0, d - distanceOnsetMeters) * distanceSlope
        }
        return s
    }

    /// 评分 → 用户可读难度档文案。
    static func gradeLabel(_ score: Double) -> String {
        if score < 0.3 { return "基础" }
        if score < 0.7 { return "中等" }
        if score < 1.2 { return "较高" }
        return "高"
    }
}
