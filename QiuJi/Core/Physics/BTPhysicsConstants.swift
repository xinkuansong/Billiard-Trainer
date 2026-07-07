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

    // MARK: 袋口参数（CAD，ADR-P10-09 起为**生产物理唯一真源**）
    // 整套袋口构造链（库线 → 圆角弧 → jaw/喉壁 → 落袋孔）在 CAD 上互为切线、数值闭合：
    //   角袋：jaw 直线段是 Φ84 孔的 45° 切线，外端点恰落在孔沿（误差 <1μm）；
    //   中袋：R30 圆角与库线、喉壁 x=±0.043 双切，喉壁与 Φ86 孔相切（孔心 z=±0.688）。
    // USDZ 视觉偏移仅保留在渲染层（`AngleSceneCalculator.pocketMarkerPositions`）。
    static let cornerPocketDiameter: Float = 0.084
    static let cornerPocketRadius: Float = cornerPocketDiameter / 2
    static let cornerPocketFilletRadius: Float = 0.105
    static let sidePocketDiameter: Float = 0.086
    static let sidePocketRadius: Float = sidePocketDiameter / 2
    static let sidePocketFilletRadius: Float = 0.030
    static let pocketDiameter: Float = sidePocketDiameter

    static let cornerPocketCenterOffsetX: Float = innerLength / 2 + cornerPocketRadius
    static let cornerPocketCenterOffsetZ: Float = innerWidth / 2 + cornerPocketRadius
    static let centerInnerHeight: Float = 0.688
    static let sidePocketCenterOffsetZ: Float = centerInnerHeight

    /// 袋口喉腔壁（袋兜衬里）恢复系数：比库边橡皮"死"得多。喉壁均为孔圈切线的延长，
    /// 正常球在触壁前已被「球心入孔圈」判据收袋——喉壁只是数值漏检时的安全兜底。
    static let pocketThroatRestitution: Float = 0.45

    /// 袋口鼻尖圆角（角袋 jaw fillet 弧）恢复系数：比整条库边橡皮"死"。
    /// 物理依据：鼻尖是皮革/橡胶包头 + 斜面剪切接触，吸能远大于库边正撞；单冲量刚体
    /// 反射无法表达真实球「贴着圆角卷进袋喉」的连续接触，用低恢复近似其净效果。
    /// 标定基准（DIAG-R，`PocketBehaviorDiagTests.test_R_railFrozenCornerEntry`）：
    /// 贴库球沿库滚向角袋应「低中力度进、大力 rattle 弹出」。扫值结果（2026-07-07，问题集合条 14）：
    ///   0.60 → 0.6–4.0 全进、5.0+ 弹出（用户反馈：不该进的大力球也进，太松）；
    ///   0.70 → 0.6–1.8 进、2.4+ rattle 弹出；
    ///   0.75 → 仅 ≤1.0 进（中低力也弹，太弹）。
    /// 取 0.70：低中力沿库球稳定进袋，中大力（≥2.4 m/s）冲袋如实被鼻尖拒绝。
    static let pocketNoseRestitution: Float = 0.70

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

    // 落袋判据（ADR-P10-09）：球心水平投影进入袋口孔圈（dist ≤ 孔半径）⇒ 台面无法再提供支撑
    // ⇒ 必然坠落。无任何速度/方向特判——进不进完全由 jaw/圆角/喉壁几何 + 真实碰撞决定。
    // （旧 ADR-P10-05 两段式判据 pocketCoreMissRadius / pocketDropSpeed 已随大捕获圆一并移除。）

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

}

// MARK: - 击球调参量程（UI 单一真源）

enum ShotTuning {
    /// 全 App 力度滑条统一量程 (m/s) — 编排台 / 分离角 / 批量出片台 / ShotControlBar
    /// / 导出 HUD / drill 回放力度条共用，禁止内联重复字面量。
    /// 控件瘦身 v2（问题集合条 13.2）：上限 6.0 → 8.0（冲球/大力开球需要 >6 m/s）。
    static let velocityRange: ClosedRange<Double> = 0.5...8.0

    /// 全 App 击打页默认力度 (m/s)（条 13.2：低速走位是常态，默认从 3.3 降至 1.5）。
    static let defaultVelocity: Double = 1.5

    /// 力度条非线性映射指数（条 13.2：低段细、高段快）。
    /// 视觉行程 fraction ∈ [0,1] → 速度 v = lo + span·fraction^γ：
    /// γ>1 时低速区占据更长的滑动行程（细调），高速区收窄（快速拉满）。
    static let velocityCurveGamma: Double = 1.8

    /// 速度 → 力度条视觉行程（0 = 条底，1 = 条顶）。
    static func fraction(forVelocity v: Double,
                         in range: ClosedRange<Double> = velocityRange) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 1e-9 else { return 0 }
        let linear = min(max((v - range.lowerBound) / span, 0), 1)
        return pow(linear, 1 / velocityCurveGamma)
    }

    /// 力度条视觉行程 → 速度。
    static func velocity(forFraction f: Double,
                         in range: ClosedRange<Double> = velocityRange) -> Double {
        let span = range.upperBound - range.lowerBound
        let clamped = min(max(f, 0), 1)
        return range.lowerBound + span * pow(clamped, velocityCurveGamma)
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
