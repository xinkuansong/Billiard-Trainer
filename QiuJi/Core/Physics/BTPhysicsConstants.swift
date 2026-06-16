//
//  BTPhysicsConstants.swift
//  QiuJi
//
//  物理引擎常量（移植自 01.billiard_app PhysicsConstants.swift 的物理子集）。
//
//  几何真源（D-A4，2026-06-06 收敛）：
//  - **内框尺寸 `innerLength` / `innerWidth` 与球半径 `BallPhysics.radius` 以本文件为唯一真源**；
//    `AngleSceneCalculator.innerLength/innerWidth/ballRadius` 改为引用本文件（消除双写）。
//  - **袋口洞中心 / jaw 端点 / 落袋半径**（USDZ 实测几何）以 `AngleSceneCalculator` 为唯一真源；
//    生产物理桌面 `TableGeometry.chineseEightBallQiuJi` 已直接消费它。
//  - 下方 `TablePhysics` 的袋口 CAD 参数（cornerPocketDiameter 等）**不是生产袋口真源**，
//    仅供 ① 库边 jaw 构建器 `chineseEightBallCushions` 与 ② 对照用 CAD 几何 `chineseEightBall()`；
//    生产路径的袋口洞一律走 `AngleSceneCalculator`。
//

import Foundation

// MARK: - 球体物理参数

enum BallPhysics {
    /// 球体直径 (米) — 57.15mm。中式八球标准球。
    static let diameter: Float = 0.05715

    /// 球体半径 (米)。**唯一真源**——`AngleSceneCalculator.ballRadius` 引用此值（D-A4）。
    static let radius: Float = diameter / 2  // 0.028575

    /// 球体质量 (千克)
    static let mass: Float = 0.170

    /// 球-球碰撞弹性系数
    static let restitution: Float = 0.95
}

// MARK: - 球台物理参数

enum TablePhysics {
    /// 内框长度 (米)。**唯一真源**——`AngleSceneCalculator.innerLength` 引用此值（D-A4）。
    static let innerLength: Float = 2.540
    /// 内框宽度 (米)。**唯一真源**——`AngleSceneCalculator.innerWidth` 引用此值（D-A4）。
    static let innerWidth: Float = 1.270

    /// 台面相对地面高度 (米) — = BTTablePhysics.height
    static let height: Float = 0.80
    /// 库边（鼻尖）高度 (米) — = BTTablePhysics.cushionHeight
    static let cushionHeight: Float = 0.037
    static let cushionThickness: Float = 0.05

    // MARK: 袋口参数（CAD）——仅供库边 jaw 构建器 + 对照用 CAD 几何；
    // 生产袋口洞的单一真源是 `AngleSceneCalculator`（USDZ 实测），见文件头注 D-A4。
    static let cornerPocketDiameter: Float = 0.084
    static let cornerPocketRadius: Float = cornerPocketDiameter / 2
    static let cornerPocketFilletRadius: Float = 0.105
    static let sidePocketDiameter: Float = 0.086
    static let sidePocketRadius: Float = sidePocketDiameter / 2
    static let sidePocketFilletRadius: Float = 0.030
    static let sidePocketNotchWidth: Float = 0.010
    static let pocketDiameter: Float = sidePocketDiameter

    static let cornerPocketCenterOffsetX: Float = innerLength / 2 + cornerPocketRadius
    static let cornerPocketCenterOffsetZ: Float = innerWidth / 2 + cornerPocketRadius
    static let centerInnerHeight: Float = 0.688
    static let sidePocketCenterOffsetZ: Float = centerInnerHeight

    // MARK: 物理系数
    static let clothFriction: Float = 0.2
    /// 库边恢复系数 e_c。**注意：e_c 不等于实际吃库速度保留率**。
    /// Han 2005 模型里库鼻高于球心（h/R≈1.29，接触角 θ_a≈17°），一部分法向冲量被转成
    /// 旋转（`outWTangent`），导致**有效法向速度保留率显著低于 e_c**。实测（见
    /// `CushionDiagnosticsTests` / `PhysicsBenchmarkTests.test_C`）：
    ///   - e_c=0.85 → 法向正撞保留率仅 ~71.4%（KE 损失 ~49%），比真实台呢库（~80%）偏狠；
    ///   - e_c=0.94 → 法向正撞保留率 ~80%，对齐真实测量，缓解「吃库后明显没劲」。
    /// 2026-06-16 据端到端诊断从 0.85 上调至 0.94（用户反馈吃库衰减过明显；按只调 e_c
    /// 标定，接受总滚动路径略增——见会话记录）。改此值需重跑上述诊断与基准合格带。
    static let cushionRestitution: Float = 0.94
    /// 库边摩擦 f_c（pooltool / 项目一默认）。Han 2005 仅用此单一库摩擦。
    static let cushionFriction: Float = 0.2
    static let gravity: Float = 9.81

    // MARK: 落袋闸门（ADR-P10-05 两段式真实落袋判据）
    /// 「正对小核」轨迹偏移阈值 (米)：球速度射线到袋心的垂距 ≤ 此值 ⇒ 视为正对穿袋，
    /// **任何力度都落袋**（正常清晰进球）。超过则需满足慢速判据才落袋。
    static let pocketCoreMissRadius: Float = 0.022
    /// 「慢速 settle」速度阈值 (m/s)：球抵达袋口捕获圈时水平速度 ≤ 此值 ⇒ 落袋（小力擦 jaw
    /// 衰减后 settle 入袋）；高于此值且非正对 ⇒ 拒绝落袋（撞喉腔后壁 → rattle 弹出，真实袋口行为）。
    static let pocketDropSpeed: Float = 1.05

    static var tableSurfaceY: Float { SceneLayout.groundLevelY + height }
}

// MARK: - 场景布局

enum SceneLayout {
    /// 地面高度 (米)，场景 Y 轴零点 — 与 BTSceneLayout.groundLevelY 一致
    static let groundLevelY: Float = 0
}

// MARK: - 旋转物理参数

enum SpinPhysics {
    static let maxTopSpin: Float = 150.0
    static let maxBackSpin: Float = 150.0
    static let maxSideSpin: Float = 100.0

    /// 自旋摩擦比例系数 (pooltool: 10*2/5/9 ≈ 0.444)
    static let spinFrictionProportionality: Float = 10.0 * 2.0 / 5.0 / 9.0
    /// 旋转衰减摩擦系数 (u_sp = proportionality * R)
    static let spinFriction: Float = spinFrictionProportionality * BallPhysics.radius

    /// 滑动摩擦系数
    static let slidingFriction: Float = 0.2
    /// 滚动摩擦系数
    static let rollingFriction: Float = 0.01
    /// 旋转转化为线速度的系数
    static let spinToVelocityRatio: Float = 0.7
    /// 塞的库边修正系数
    static let cushionSpinCorrectionFactor: Float = 0.15
}

// MARK: - 击球力度参数

enum StrokePhysics {

    /// 常用击球速度五档（杆头速度 m/s）。
    ///
    /// 参考 **项目 16《球理》T04「母球速度分级」**：Capelle 的 9 档体系里，业余玩家
    /// 推荐用 **5 档**（去掉极慢的 1 档与极爆的 9 档），且用「出杆长度」而非「用力大小」
    /// 调控。这里把 5 档落地为 5 个稳定的杆头速度锚点，覆盖从轻推到大力的实用区间，
    /// 最低档也保证母球能完整走完台面并吃库（修复旧「力度 0 速度过小」问题）。
    enum SpeedLevel: Int, CaseIterable, Identifiable, Hashable {
        case soft = 1        // 轻推（近距走位 / safety）
        case mediumSoft = 2  // 中轻
        case medium = 3      // 中等（走位主力区）
        case mediumHard = 4  // 中重
        case hard = 5        // 大力（长台 / 强分离）

        var id: Int { rawValue }

        /// 该档对应的杆头速度 (m/s)。
        var velocity: Float {
            switch self {
            case .soft:       return 1.6
            case .mediumSoft: return 2.4
            case .medium:     return 3.3
            case .mediumHard: return 4.4
            case .hard:       return 5.8
            }
        }

        /// 档位中文短标签（UI 用）。
        var label: String {
            switch self {
            case .soft:       return "轻"
            case .mediumSoft: return "中轻"
            case .medium:     return "中"
            case .mediumHard: return "中重"
            case .hard:       return "大力"
            }
        }
    }

    /// 力度条满格 (100) 对应的杆头速度 (m/s)
    static let maxVelocity: Float = 6.5
    /// 幂函数曲线指数 — 前段细腻、后段爆发
    static let powerGamma: Float = 1.8
    /// 力度条死区 (0-100)
    static let deadZone: Float = 2.0

    /// 将 0-100 力度映射为杆头速度 (m/s)（旧接口，保留兼容）。
    static func velocity(forPower p: Float) -> Float {
        let clamped = min(max(p, 0), 100)
        guard clamped >= deadZone else { return 0 }
        let normalized = clamped / 100.0
        return maxVelocity * powf(normalized, powerGamma)
    }
}

// MARK: - 球杆物理参数

enum CuePhysics {
    /// 球杆总质量 (kg)
    static let mass: Float = 0.567
    /// 末端等效质量 (kg) — 用于 squirt 计算
    static let endMass: Float = 0.00567

    // MARK: 皮头几何（打点盘真实比例 + 打滑极限）

    /// 皮头接触面直径 (米) — 中式八球常见 11mm。
    static let tipDiameter: Float = 0.011
    /// 皮头接触面半径 (米) = tipDiameter / 2（≈5.5mm）。打点盘按「皮头/母球真实比例」画接触斑。
    static let tipContactRadius: Float = tipDiameter / 2
    /// 皮头球冠曲率半径 (米) — nickel 修型 ≈10.5mm。预留给「皮头中心对位 → 球面接触点」精确换算。
    static let tipCurvatureRadius: Float = 0.0105
    /// 打滑极限（miscue limit）：皮头能可靠咬住母球的**最大接触点偏移**，占母球半径 R 的比例。
    /// 经典值 ≈0.5（满塞 ≈ 半个半径）；由皮头/巧粉摩擦决定，超出即打滑（miscue）。
    /// 打点盘据此把可拖区域钳在 0.5R 内，使「加塞多少」对应真实可打击球点。
    static let miscueLimitFraction: Float = 0.5

    /// 皮头球冠曲率「把接触点拉向球心」的系数：contact = 皮头中心对位偏移 × R/(R+ρ)。
    /// 两球相切几何：母球(R) 与皮头球冠(ρ=tipCurvatureRadius) 的接触点在两球心连线上，
    /// 其横向偏移 = 皮头中心横向偏移 × R/(R+ρ)（曲率越大/ρ 越小越接近 1，平头 ρ→∞ 趋 0）。
    /// 打点盘据此从「用户摆放的皮头中心」换算到真实接触点（pooltool a,b）。
    static var tipContactPullFactor: Float { BallPhysics.radius / (BallPhysics.radius + tipCurvatureRadius) }
}

// MARK: - 瞄准/轨迹采样参数

enum AimingSystem {
    static let maxAimLineLength: Float = 3.0
    static let minAimLineLength: Float = 0.05
    static let trajectoryPointCount: Int = 30
    /// 轨迹预测时间步长 (秒)
    static let trajectoryTimeStep: Float = 0.016
    static let separationAngleThreshold: Float = 90.0
}

// MARK: - 分离角参考（教学经验值，仅作 UI 提示，不参与物理求解）

enum SeparationAngle {
    static let pureRolling: Float = 90.0
    static let topSpinCorrection: Float = -20.0
    static let backSpinCorrection: Float = 20.0
    static let thinBallThreshold: Float = 0.25
    static let thickBallThreshold: Float = 0.75
}
