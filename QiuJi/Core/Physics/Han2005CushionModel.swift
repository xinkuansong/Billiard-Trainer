//
//  Han2005CushionModel.swift
//  QiuJi
//
//  球-库边碰撞 —— Inhwan Han (2005) "Dynamics in Carom and Three Cushion Billiards"
//  闭式解（O(1)，无积分循环）。忠实移植自 pooltool
//  `physics/resolve/ball_cushion/han_2005/model.py` 的 `han2005()`。
//
//  之所以用 Han 替代原 `CushionCollisionModel`（Mathavan 2010 冲量积分）：
//  ① 性能：Mathavan 每次吃库要跑 3000–10000 步内循环（deltaP=1e-4），是轨迹预测
//     "要好几秒"的主因；Han 是常数时间闭式解。
//  ② 真实感：Mathavan 同时叠加库摩擦 mu_w 与台呢摩擦 mu_s，角度球切向能量损耗被放大
//     （用户反馈"吃库后衰减很厉害"）；Han 只用单一库摩擦 f_c，衰减更自然。
//  Han 与 Mathavan 同为 pooltool 官方库边模型（Han 是其"快速"实现），系数沿用
//  pooltool / 项目一默认：e_c = 0.85, f_c = 0.20。
//
//  坐标约定（与 pooltool han2005 的接触系一致，z 朝上）：
//      vNormal  = 沿库面法向、指向运动方向（接近库时 > 0）           ↔ rvw_R[1,0]
//      vTangent = 沿库面切向（台面内）                                ↔ rvw_R[1,1]
//      (vz = 0)                                                       ↔ rvw_R[1,2]
//      wNormal / wTangent / wUp = 分别绕 法向 / 切向 / 上 轴的角速度   ↔ rvw_R[2,0..2]
//  调用方（`CollisionResolver`）负责在右手接触系 (N, T=U×N, U) 与世界系之间换算。
//

import Foundation

enum Han2005CushionModel {

    /// 接触后速度 / 角速度（接触系标量）。
    struct Result {
        var vNormal: Float
        var vTangent: Float
        var wNormal: Float
        var wTangent: Float
        var wUp: Float
    }

    /// 求解一次球-库边碰撞（Han 2005 闭式解）。
    /// - Parameters:
    ///   - vNormal: 法向速度（接近库 > 0）
    ///   - vTangent: 切向速度
    ///   - wNormal/wTangent/wUp: 绕 法向/切向/上 轴的角速度
    ///   - mu: 球-库摩擦系数 f_c
    ///   - e: 球-库恢复系数 e_c
    ///   - h: 库鼻高度（接触点高度）
    ///   - R: 球半径
    ///   - M: 球质量
    static func solve(
        vNormal: Float,
        vTangent: Float,
        wNormal: Float,
        wTangent: Float,
        wUp: Float,
        mu: Float,
        e: Float,
        h: Float,
        R: Float,
        M: Float
    ) -> Result {
        // 接触角：取决于库鼻高度相对球半径。pooltool: theta_a = arcsin(h/R - 1)。
        let ratio = max(-1, min(1, h / R - 1))
        let thetaA = asinf(ratio)
        let sinT = sinf(thetaA)
        let cosT = cosf(thetaA)

        // Eqs 14（vz = rvw_R[1,2] = 0）
        let sx = vNormal * sinT + R * wTangent
        let sy = -vTangent - R * wUp * cosT + R * wNormal * sinT
        let c  = -vNormal * cosT  // 2D 假设

        // Eqs 16
        let II = (2.0 / 5.0) * M * R * R
        let A: Float = 7.0 / 2.0 / M
        let B: Float = 1.0 / M

        // Eqs 17 & 20
        let PzE = -(1 + e) * c / B
        let absS0 = sqrtf(sx * sx + sy * sy)
        let PzS = absS0 / A

        let PxE: Float
        let PyE: Float
        if absS0 < 1e-9 {
            // 无切向滑移 → 无切向冲量。
            PxE = 0
            PyE = 0
        } else if PzS <= mu * PzE {
            // Eqs 18：滑动并粘滞（slip 在接触结束前耗尽）
            PxE = sx / A
            PyE = sy / A
        } else {
            // Eqs 19：持续前向滑动（库摩擦封顶）
            PxE = mu * PzE * sx / absS0
            PyE = mu * PzE * sy / absS0
        }

        // Eqs 21 & 22：把冲量从接触法向系转回库系
        let PX = -PxE * sinT - PzE * cosT
        let PY = PyE
        let PZ = PxE * cosT - PzE * sinT

        // Eqs 23：更新速度与角速度
        var outVNormal = vNormal + PX / M
        let outVTangent = vTangent + PY / M
        let outWNormal = wNormal + (-R / II) * PY * sinT
        let outWTangent = wTangent + (R / II) * (PX * sinT - PZ * cosT)
        let outWUp = wUp + (R / II) * PY * cosT

        // 数值安全：法向速度反弹后应朝离开库的方向（≤ 0），避免极端输入下仍指向库内
        // 引发零时重检测的"库边振荡"。
        if outVNormal > 0 { outVNormal = 0 }

        return Result(
            vNormal: outVNormal,
            vTangent: outVTangent,
            wNormal: outWNormal,
            wTangent: outWTangent,
            wUp: outWUp
        )
    }
}
