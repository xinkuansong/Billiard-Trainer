import Foundation
import SceneKit

/// 「瞄准修正」页实况计算真源层（问题集合 v12 Z1）。
///
/// 固定教学局面 ≈ 半球切角（θ≈30°，与 `AimingMethodsGeometry` 同球位），只读调用
/// `ShotPredictor.prepareAim` / `positionAimOffset`（解析层）/ `CueBallStrike` /
/// `AnalyticAim.outcome`——**不改求解算法本身**。
///
/// 坐标契约（与 `.kiro/steering/table-geometry.md` + 引擎一致）：
/// - SceneKit 世界系；水平面 = **X–Z**；**+Y 朝上**；单位米
/// - +X = 右端；+Z = 顶视图「上」侧（代码袋口标记「屏上」常取 −Z，以投影为准）
/// - 台心 (0, surfaceY, 0)；球半径 R = `BallPhysics.radius`
/// - 水平角恒用 `atan2(z, x)`；绕竖直轴旋转用 `rotatedY`
///
/// Δ 口径：`aimOffset = positionAimOffset(...)`（弧度）——与角度瞄准法的差异就是这个数。
enum AimingCorrectionMath {

    static let surfaceY: Float = BTTablePhysics.surfaceY
    /// 教学切角目标（度）；球位来自 `AimingMethodsGeometry.scene`。
    static let teachingCutAngleDeg: CGFloat = CGFloat(AngleSceneCalculator.halfBall.cutAngleDegrees)
    /// 右上角袋 = `AngleSceneCalculator.pocketPositions` 索引 1（与 Y1 教学袋一致）。
    static let teachingPocketIndex: Int = 1

    // MARK: - Teaching setup

    struct TeachingSetup {
        let cue: SCNVector3
        let target: SCNVector3
        let pocketIndex: Int
        /// 几何构造切角（度），来自 `AimingMethodsGeometry`。
        let constructedCutAngleDeg: Float
        let surfaceY: Float
    }

    /// 固定教学局面：母球/目标球取自半球标准位，袋口 = 右上角袋。
    static func teachingSetup() -> TeachingSetup {
        let s = AimingMethodsGeometry.scene(cutAngleDeg: teachingCutAngleDeg)
        let y = surfaceY
        return TeachingSetup(
            cue: SCNVector3(Float(s.cue.x), y, Float(s.cue.y)),
            target: SCNVector3(Float(s.target.x), y, Float(s.target.y)),
            pocketIndex: teachingPocketIndex,
            constructedCutAngleDeg: Float(s.cutAngleDeg),
            surfaceY: y
        )
    }

    /// `ShotInput` 构造范式对齐 `PositionPlaySolver.evaluate`（velocity/spin/surfaceY）。
    static func makeInput(
        velocity: Float,
        spinX: Float,
        spinY: Float,
        setup: TeachingSetup = teachingSetup()
    ) -> ShotInput {
        ShotInput(
            cueBall: setup.cue,
            targetBall: setup.target,
            pocketIndex: setup.pocketIndex,
            velocity: velocity,
            spinX: spinX,
            spinY: spinY,
            surfaceY: setup.surfaceY,
            obstacles: []
        )
    }

    // MARK: - Live snapshot

    struct Snapshot: Equatable {
        /// 几何基准瞄准方向（幽灵球，`prepareAim.aimDir`）。
        let geometricAimDir: SCNVector3
        /// 求解偏移 Δ（弧度）= `positionAimOffset` 解析层。
        let aimOffsetRadians: Float
        /// 求解瞄准 = geometricAimDir.rotatedY(Δ)。
        let solvedAimDir: SCNVector3
        /// 挤偏角（弧度）；`CueBallStrike.squirtAngle`，负值=向右偏。
        let squirtRadians: Float
        /// 目标球碰后方向（解析层）；nil = 未碰到。
        let objPostContactDir: SCNVector3?
        /// 碰前轨迹段（`collectSegments: true`）。
        let preContactSegments: [BallPathSegment]
        /// `prepareAim` 回填的切角（度）。
        let cutAngleDeg: Float
        /// 理想进球方向（目标球 → 进球点，XZ 单位）。
        let potDir: SCNVector3
        let ghost: SCNVector3
        let velocity: Float
        let spinX: Float
        let spinY: Float

        var aimOffsetDegrees: Float { aimOffsetRadians * 180 / .pi }
        var squirtDegrees: Float { squirtRadians * 180 / .pi }

        static func == (lhs: Snapshot, rhs: Snapshot) -> Bool {
            lhs.aimOffsetRadians == rhs.aimOffsetRadians
                && lhs.squirtRadians == rhs.squirtRadians
                && lhs.velocity == rhs.velocity
                && lhs.spinX == rhs.spinX
                && lhs.spinY == rhs.spinY
                && lhs.cutAngleDeg == rhs.cutAngleDeg
        }
    }

    /// 固定局面下一组 (v, spinX, spinY) 的完整实况快照。失败（几何不可行）返回 nil。
    static func compute(
        velocity: Float,
        spinX: Float,
        spinY: Float,
        setup: TeachingSetup = teachingSetup()
    ) -> Snapshot? {
        let input = makeInput(velocity: velocity, spinX: spinX, spinY: spinY, setup: setup)
        var probe = ShotPrediction()
        guard let ctx = ShotPredictor.prepareAim(input, into: &probe) else { return nil }

        let offset = ShotPredictor.positionAimOffset(input: input, context: ctx)
        let solvedDir = ctx.aimDir.rotatedY(offset)
        let squirt = CueBallStrike.squirtAngle(a: spinX)

        let outcome = AnalyticAim.outcome(
            aimDir: solvedDir,
            velocity: velocity,
            input: input,
            geometry: ctx.geometry,
            ghost: ctx.ghost,
            collectSegments: true
        )

        let potDir = unitXZ(from: input.targetBall, to: ctx.aimPoint)
        return Snapshot(
            geometricAimDir: ctx.aimDir,
            aimOffsetRadians: offset,
            solvedAimDir: solvedDir,
            squirtRadians: squirt,
            objPostContactDir: outcome.objPostContactDir,
            preContactSegments: outcome.preContactSegments,
            cutAngleDeg: Float(probe.cutAngleDeg ?? 0),
            potDir: potDir,
            ghost: ctx.ghost,
            velocity: velocity,
            spinX: spinX,
            spinY: spinY
        )
    }

    /// 几何瞄准（不加 Δ）下的解析推演——用于投掷/厚薄定性扫描（排除求解补偿干扰）。
    static func analyticAtGeometricAim(
        velocity: Float,
        spinX: Float,
        spinY: Float,
        setup: TeachingSetup = teachingSetup()
    ) -> (ctx: ShotPredictor.AimContext, outcome: AnalyticAim.Outcome, potDir: SCNVector3)? {
        let input = makeInput(velocity: velocity, spinX: spinX, spinY: spinY, setup: setup)
        var probe = ShotPrediction()
        guard let ctx = ShotPredictor.prepareAim(input, into: &probe) else { return nil }
        let outcome = AnalyticAim.outcome(
            aimDir: ctx.aimDir,
            velocity: velocity,
            input: input,
            geometry: ctx.geometry,
            ghost: ctx.ghost,
            collectSegments: true
        )
        let potDir = unitXZ(from: input.targetBall, to: ctx.aimPoint)
        return (ctx, outcome, potDir)
    }

    // MARK: - Signed angles / qualitative helpers (for evidence + tests)

    /// XZ 平面有符号角（弧度）：从 `from` 转到 `to`，右手系绕 +Y，范围 (−π, π]。
    static func signedAngleXZ(from: SCNVector3, to: SCNVector3) -> Float {
        let a = unitXZ(from)
        let b = unitXZ(to)
        let crossY = a.x * b.z - a.z * b.x
        let dot = a.x * b.x + a.z * b.z
        return atan2f(crossY, dot)
    }

    /// 切角侧符号：`aimDir` 相对 `potDir` 的旋转侧（+1 / −1）。
    static func cutSideSign(potDir: SCNVector3, aimDir: SCNVector3) -> Float {
        let s = signedAngleXZ(from: potDir, to: aimDir)
        return s >= 0 ? 1 : -1
    }

    /// 投掷角（度）：目标球碰后方向相对理想进球线的绝对偏角。
    static func throwAngleDegrees(potDir: SCNVector3, objPost: SCNVector3) -> Float {
        abs(signedAngleXZ(from: potDir, to: objPost)) * 180 / .pi
    }

    /// 厚薄偏向（度）：**正 = 偏薄，负 = 偏厚**。
    /// 符号已数值标定（Z1 草稿 `thickness-sign-calibration`，2026-07-18）：对无塞中杆的
    /// ±1.5° 瞄准扰动，更薄一侧（碰后目标球速更小）的目标球离开方向相对进球线
    /// 旋向「切角反侧」——故偏薄 = signed∠(potDir→objPost) 投影到切角**反侧**为正。
    static func thicknessBiasDegrees(
        potDir: SCNVector3, aimDir: SCNVector3, objPost: SCNVector3
    ) -> Float {
        let side = cutSideSign(potDir: potDir, aimDir: aimDir)
        let signed = signedAngleXZ(from: potDir, to: objPost) * 180 / .pi
        return -signed * side
    }

    /// 挤偏水平偏向（度）：负值 = 向右（与 `CueBallStrike.squirtAngle` 文档一致）。
    static func squirtDegrees(spinX: Float) -> Float {
        CueBallStrike.squirtAngle(a: spinX) * 180 / .pi
    }

    // MARK: - Private

    private static func unitXZ(from a: SCNVector3, to b: SCNVector3) -> SCNVector3 {
        let dx = b.x - a.x
        let dz = b.z - a.z
        let len = sqrtf(dx * dx + dz * dz)
        guard len > 1e-9 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(dx / len, 0, dz / len)
    }

    private static func unitXZ(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrtf(v.x * v.x + v.z * v.z)
        guard len > 1e-9 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(v.x / len, 0, v.z / len)
    }
}
