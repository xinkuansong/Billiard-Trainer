import SwiftUI

/// Practice-home (`AngleHomeView`) cover gradient pairs — single source (v7 C20).
///
/// Values are byte-identical to the former inline `Color(red:green:blue:)` literals.
/// Covers do not currently branch on Light/Dark; keep shared RGB (do not invent dark variants).
enum AngleCoverPalette {
    struct Pair {
        let top: Color
        let bottom: Color
    }

    // MARK: - 学
    static let aimingPrinciple = Pair(
        top: Color(red: 0.16, green: 0.55, blue: 0.34),
        bottom: Color(red: 0.09, green: 0.34, blue: 0.21)
    )
    /// 瞄准方法（v11 Y1）— 青绿，区别于瞄准原理深绿 / 角度与瞄准蓝。
    static let aimingMethods = Pair(
        top: Color(red: 0.12, green: 0.58, blue: 0.50),
        bottom: Color(red: 0.05, green: 0.34, blue: 0.30)
    )
    /// 瞄准修正（v12 Z1）— 暖橙棕，区别于旋转与加塞琥珀 / 瞄准方法青绿 / 几何测验橙。
    static let aimingCorrection = Pair(
        top: Color(red: 0.72, green: 0.38, blue: 0.22),
        bottom: Color(red: 0.42, green: 0.20, blue: 0.12)
    )
    /// 旋转与加塞（v11 Y2）— 琥珀，区别于瞄准方法青绿 / 浅谈球感紫 / 角度与瞄准蓝。
    static let spinAndEnglish = Pair(
        top: Color(red: 0.78, green: 0.42, blue: 0.16),
        bottom: Color(red: 0.48, green: 0.24, blue: 0.08)
    )
    /// 分离角图谱（v11 Y3）— 玫红紫，区别于旋转与加塞琥珀 / 分离角与走位绿 / 角度与瞄准蓝。
    static let separationAngleAtlas = Pair(
        top: Color(red: 0.72, green: 0.22, blue: 0.48),
        bottom: Color(red: 0.42, green: 0.10, blue: 0.30)
    )
    static let angleDynamic = Pair(
        top: Color(red: 0.11, green: 0.46, blue: 0.95),
        bottom: Color(red: 0.05, green: 0.24, blue: 0.58)
    )
    static let ballFeel = Pair(
        top: Color(red: 0.48, green: 0.36, blue: 0.72),
        bottom: Color(red: 0.28, green: 0.20, blue: 0.46)
    )
    static let contactPointTable = Pair(
        top: Color(red: 0.42, green: 0.45, blue: 0.50),
        bottom: Color(red: 0.24, green: 0.26, blue: 0.30)
    )

    // MARK: - 练
    static let geometricQuiz = Pair(
        top: Color(red: 0.85, green: 0.52, blue: 0.13),
        bottom: Color(red: 0.55, green: 0.32, blue: 0.05)
    )
    static let sceneAiming2D = Pair(
        top: Color(red: 0.0, green: 0.60, blue: 0.60),
        bottom: Color(red: 0.0, green: 0.36, blue: 0.40)
    )
    static let sceneAiming3D = Pair(
        top: Color(red: 0.13, green: 0.42, blue: 0.66),
        bottom: Color(red: 0.05, green: 0.24, blue: 0.42)
    )
    static let aimPointTraining = Pair(
        top: Color(red: 0.72, green: 0.28, blue: 0.30),
        bottom: Color(red: 0.44, green: 0.14, blue: 0.16)
    )
    static let aimPointScene2D = Pair(
        top: Color(red: 0.0, green: 0.52, blue: 0.48),
        bottom: Color(red: 0.0, green: 0.30, blue: 0.28)
    )
    static let aimPointScene3D = Pair(
        top: Color(red: 0.30, green: 0.34, blue: 0.72),
        bottom: Color(red: 0.16, green: 0.18, blue: 0.44)
    )

    // MARK: - 打
    static let shotSimulation = Pair(
        top: Color(red: 0.13, green: 0.55, blue: 0.36),
        bottom: Color(red: 0.06, green: 0.33, blue: 0.20)
    )
    static let positionPlayComposer = Pair(
        top: Color(red: 0.72, green: 0.55, blue: 0.13),
        bottom: Color(red: 0.45, green: 0.33, blue: 0.05)
    )
    static let freePlay = Pair(
        top: Color(red: 0.13, green: 0.42, blue: 0.85),
        bottom: Color(red: 0.05, green: 0.22, blue: 0.52)
    )
    static let ballExtraction = Pair(
        top: Color(red: 0.16, green: 0.50, blue: 0.62),
        bottom: Color(red: 0.07, green: 0.28, blue: 0.36)
    )
    /// Simulator-only batch studio card.
    static let batchDrillStudio = Pair(
        top: Color(red: 0.20, green: 0.40, blue: 0.70),
        bottom: Color(red: 0.10, green: 0.22, blue: 0.42)
    )

    // MARK: - 解
    static let positionPlaySolver = Pair(
        top: Color(red: 0.50, green: 0.20, blue: 0.62),
        bottom: Color(red: 0.28, green: 0.10, blue: 0.40)
    )
    static let planThree = Pair(
        top: Color(red: 0.16, green: 0.46, blue: 0.62),
        bottom: Color(red: 0.08, green: 0.26, blue: 0.38)
    )
    static let snookerTactics = Pair(
        top: Color(red: 0.60, green: 0.10, blue: 0.30),
        bottom: Color(red: 0.34, green: 0.04, blue: 0.16)
    )
    static let bankShot = Pair(
        top: Color(red: 0.62, green: 0.14, blue: 0.14),
        bottom: Color(red: 0.36, green: 0.06, blue: 0.06)
    )
    static let diamondSystem = Pair(
        top: Color(red: 0.0, green: 0.45, blue: 0.55),
        bottom: Color(red: 0.0, green: 0.26, blue: 0.34)
    )
}
