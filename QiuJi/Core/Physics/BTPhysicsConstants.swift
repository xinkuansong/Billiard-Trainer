//
//  BTPhysicsConstants.swift
//  QiuJi
//
//  物理引擎常量（移植自 01.billiard_app PhysicsConstants.swift 的物理子集）。
//
//  注意：几何数值（innerLength / innerWidth / height / cushionHeight / ballRadius）
//  与项目已有的 `AngleSceneCalculator` 和 `BTTablePhysics` 完全一致（中式八球标准）。
//  TODO(step3)：将 `TableGeometry` 的袋口/库段对齐到 USDZ 实测后，这里的袋口
//  参数会与 `AngleSceneCalculator.pocketPositions` 统一为单一真源。
//

import Foundation

// MARK: - 球体物理参数

enum BallPhysics {
    /// 球体直径 (米) — 57.15mm（= AngleSceneCalculator.ballRadius * 2）
    static let diameter: Float = 0.05715

    /// 球体半径 (米)
    static let radius: Float = diameter / 2  // 0.028575

    /// 球体质量 (千克)
    static let mass: Float = 0.170

    /// 球-球碰撞弹性系数
    static let restitution: Float = 0.95
}

// MARK: - 球台物理参数

enum TablePhysics {
    /// 内框长度 (米) — = AngleSceneCalculator.innerLength
    static let innerLength: Float = 2.540
    /// 内框宽度 (米) — = AngleSceneCalculator.innerWidth
    static let innerWidth: Float = 1.270

    /// 台面相对地面高度 (米) — = BTTablePhysics.height
    static let height: Float = 0.80
    /// 库边（鼻尖）高度 (米) — = BTTablePhysics.cushionHeight
    static let cushionHeight: Float = 0.037
    static let cushionThickness: Float = 0.05

    // MARK: 袋口参数（CAD，step3 对齐 USDZ 后并入 AngleSceneCalculator）
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
    /// 库边恢复系数 e_c（pooltool / 项目一默认）。库边模型已换为 Han 2005 闭式解，
    /// 不再叠加台呢摩擦，吃库衰减更自然，无需再像上一轮那样上调此值。
    static let cushionRestitution: Float = 0.85
    /// 库边摩擦 f_c（pooltool / 项目一默认）。Han 2005 仅用此单一库摩擦。
    static let cushionFriction: Float = 0.2
    static let gravity: Float = 9.81

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
    static let mass: Float = 0.567
    static let tipRadius: Float = 0.0106
    /// 末端等效质量 (kg) — 用于 squirt 计算
    static let endMass: Float = 0.00567
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
