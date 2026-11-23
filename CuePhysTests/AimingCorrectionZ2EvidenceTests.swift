import XCTest
import SceneKit
@testable import QiuJi

/// Z2 数值补稿（问题集合 v12 Z2）：② 节正文新增的两条定性符号——
/// 「左塞把目标球向右带（SIT）」「切角越大投掷越大（CIT）」——Z1 草稿未覆盖，
/// 按 geometry-spatial-reasoning 技能补数值草稿核验后方可上屏。
/// 证据落盘：`build/z2-evidence/`（相对仓库根）。
final class AimingCorrectionZ2EvidenceTests: XCTestCase {

    private var evidenceDir: URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // QiuJiTests
            .deletingLastPathComponent() // repo root
        return root.appendingPathComponent("build/z2-evidence", isDirectory: true)
    }

    // MARK: - Helpers

    /// 「行进方向的右侧」单位向量：right = forward × up（右手系，up = +ŷ）。
    /// 手性锚定见 `testHandednessCalibration`（不脑算，先锚后用）。
    private static func rightOf(_ dir: SCNVector3) -> SCNVector3 {
        // cross(d, ŷ) = (d.y*0 − d.z*1, d.z*0 − d.x*0, d.x*1 − d.y*0) = (−d.z, 0, d.x)
        SCNVector3(-dir.z, 0, dir.x)
    }

    private static func makeSetup(cutDeg: CGFloat) -> AimingCorrectionMath.TeachingSetup {
        let s = AimingMethodsGeometry.scene(cutAngleDeg: cutDeg)
        let y = AimingCorrectionMath.surfaceY
        return AimingCorrectionMath.TeachingSetup(
            cue: SCNVector3(Float(s.cue.x), y, Float(s.cue.y)),
            target: SCNVector3(Float(s.target.x), y, Float(s.target.y)),
            pocketIndex: AimingCorrectionMath.teachingPocketIndex,
            constructedCutAngleDeg: Float(s.cutAngleDeg),
            surfaceY: y
        )
    }

    private static func dotXZ(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        a.x * b.x + a.z * b.z
    }

    // MARK: - 手性锚定（禁止脑算清单：叉积正负与手性）

    /// 数值锚定「右侧」映射：面向 f、up=+ŷ 时 right = f×ŷ；
    /// 标准样例：面向 −ẑ（SceneKit 相机默认前向）时 right 必须 = +x̂；
    /// 且 `signedAngleXZ(f → 偏向右侧的向量)` 为正。
    func testHandednessCalibration() {
        // 样例 1：f = −ẑ（相机前向）→ right = +x̂
        let rCam = Self.rightOf(SCNVector3(0, 0, -1))
        XCTAssertEqual(rCam.x, 1, accuracy: 1e-6)
        XCTAssertEqual(rCam.z, 0, accuracy: 1e-6)

        // 样例 2：f = +x̂ → right = +ẑ；rotatedY(+ε) 偏向 +ẑ 即右侧
        let f = SCNVector3(1, 0, 0)
        let r = Self.rightOf(f)
        XCTAssertEqual(r.z, 1, accuracy: 1e-6)
        let eps: Float = 0.01
        let tipped = f.rotatedY(+eps)
        XCTAssertGreaterThan(Self.dotXZ(tipped, r), 0, "rotatedY(+ε) 应偏向右侧")
        XCTAssertGreaterThan(
            AimingCorrectionMath.signedAngleXZ(from: f, to: tipped), 0,
            "signedAngleXZ 正 = 偏右，与 right=f×ŷ 一致"
        )
    }

    // MARK: - SIT：左塞把目标球向右带（正碰局面隔离 CIT + 补偿 squirt 隔离几何错位）

    /// 纯 SIT 隔离：cut=0 排除 CIT；出杆方向预旋 +squirt 补偿挤偏，使母球实际
    /// 行进方向仍过幽灵球心（首跑发现不补偿时 squirt 造成的偏心碰撞几何效应
    /// 淹没 SIT，方向反号——根因见 z2-evidence 草稿）。
    private static func pureSIT(spinX: Float, velocity: Float = 1.5)
        -> (potDir: SCNVector3, objPost: SCNVector3)? {
        let setup = makeSetup(cutDeg: 0)
        let input = AimingCorrectionMath.makeInput(
            velocity: velocity, spinX: spinX, spinY: 0, setup: setup)
        var probe = ShotPrediction()
        guard let ctx = ShotPredictor.prepareAim(input, into: &probe) else { return nil }
        // executeStrike 内部 actual = aim.rotatedY(−squirt) ⇒ 预旋 +squirt 抵消。
        let squirt = CueBallStrike.squirtAngle(a: spinX)
        let compensatedAim = ctx.aimDir.rotatedY(squirt)
        let out = AnalyticAim.outcome(
            aimDir: compensatedAim, velocity: velocity, input: input,
            geometry: ctx.geometry, ghost: ctx.ghost
        )
        guard let obj = out.objPostContactDir else { return nil }
        let dx = ctx.aimPoint.x - input.targetBall.x
        let dz = ctx.aimPoint.z - input.targetBall.z
        let len = max(sqrtf(dx * dx + dz * dz), 1e-9)
        return (SCNVector3(dx / len, 0, dz / len), obj)
    }

    func testLeftEnglishThrowsObjectBallRight() {
        guard let left = Self.pureSIT(spinX: 0.35),
              let right = Self.pureSIT(spinX: -0.35) else {
            return XCTFail("纯 SIT 局面解析失败")
        }
        let leftDot = Self.dotXZ(left.objPost, Self.rightOf(left.potDir))
        let rightDot = Self.dotXZ(right.objPost, Self.rightOf(right.potDir))
        XCTAssertGreaterThan(leftDot, 0,
                             "左塞 SIT 应把目标球向行进右侧带，dot=\(leftDot)")
        XCTAssertLessThan(rightDot, 0, "右塞 SIT 应向左，dot=\(rightDot)")
    }

    // MARK: - CIT vs 切角（首跑证伪「单调递增」：引擎显示半球附近见顶）

    private static func citThrow(cutDeg: CGFloat, velocity: Float = 1.5) -> Float? {
        let setup = makeSetup(cutDeg: cutDeg)
        guard let geo = AimingCorrectionMath.analyticAtGeometricAim(
            velocity: velocity, spinX: 0, spinY: 0, setup: setup
        ), let obj = geo.outcome.objPostContactDir else { return nil }
        return AimingCorrectionMath.throwAngleDegrees(
            potDir: geo.potDir, objPost: obj)
    }

    /// 小切角段单调增（15°→30°），且半球附近为峰值邻域（45° 不再高于 30°）。
    /// 正文口径据此收窄为「小切角越薄越明显，在半球附近最明显」。
    func testCITGrowsToHalfBallThenPlateaus() {
        guard let t15 = Self.citThrow(cutDeg: 15),
              let t30 = Self.citThrow(cutDeg: 30),
              let t45 = Self.citThrow(cutDeg: 45) else {
            return XCTFail("CIT 切角扫描失败")
        }
        XCTAssertGreaterThan(t30, t15, "30° CIT (\(t30)°) 应 > 15° (\(t15)°)")
        XCTAssertGreaterThan(t30, 0.5, "半球 CIT 应可测")
        XCTAssertLessThanOrEqual(t45, t30 * 1.05,
                                 "45° CIT (\(t45)°) 不应显著高于半球 (\(t30)°)")
    }

    // MARK: - 落盘（数值草稿证据）

    func testWriteZ2EvidenceDraft() throws {
        let dir = evidenceDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 手性
        let f = SCNVector3(1, 0, 0)
        let tipped = f.rotatedY(0.01)
        let handedOK = Self.dotXZ(tipped, Self.rightOf(f)) > 0
            && AimingCorrectionMath.signedAngleXZ(from: f, to: tipped) > 0

        // SIT（纯隔离：cut=0 + squirt 补偿；对照组 = 不补偿，记录几何错位效应）
        guard let sitL = Self.pureSIT(spinX: 0.35),
              let sitR = Self.pureSIT(spinX: -0.35) else {
            return XCTFail("SIT 局面解析失败")
        }
        let sitLDot = Self.dotXZ(sitL.objPost, Self.rightOf(sitL.potDir))
        let sitRDot = Self.dotXZ(sitR.objPost, Self.rightOf(sitR.potDir))
        let sitLDeg = AimingCorrectionMath.signedAngleXZ(
            from: sitL.potDir, to: sitL.objPost) * 180 / .pi
        let sitRDeg = AimingCorrectionMath.signedAngleXZ(
            from: sitR.potDir, to: sitR.objPost) * 180 / .pi
        let sitOK = sitLDot > 0 && sitRDot < 0

        // 对照组：不补偿 squirt 时（几何瞄准照打），squirt 错位效应主导、方向反号——
        // 首跑证伪记录，说明正文只能说「SIT 分量向右」，不能说「加左塞球一定往右跑」。
        let rawL = AimingCorrectionMath.analyticAtGeometricAim(
            velocity: 1.5, spinX: 0.35, spinY: 0, setup: Self.makeSetup(cutDeg: 0))
        let rawLDeg: Float
        if let rawL, let rawObj = rawL.outcome.objPostContactDir {
            rawLDeg = AimingCorrectionMath.signedAngleXZ(
                from: rawL.potDir, to: rawObj) * 180 / .pi
        } else {
            rawLDeg = .nan
        }

        // CIT vs 切角（首跑证伪「单调递增」，实测半球附近见顶）
        guard let t15 = Self.citThrow(cutDeg: 15),
              let t30 = Self.citThrow(cutDeg: 30),
              let t45 = Self.citThrow(cutDeg: 45) else {
            return XCTFail("CIT 扫描失败")
        }
        let citOK = t30 > t15 && t45 <= t30 * 1.05

        let allPass = handedOK && sitOK && citOK
        let text = """
        === Z2 数值补稿（② 节新增定性符号核验；Z1 草稿未覆盖项）===
        日期: 2026-07-18
        真源: AimingCorrectionMath（只读 prepareAim / AnalyticAim.outcome → resolveBallBallPure）

        【坐标契约回显】
        - 系: SceneKit 世界系；水平面 X–Z；+Y 朝上；单位米
        - 水平角 atan2(z,x)；绕竖直轴 rotatedY；signedAngleXZ 正 = 绕 +Y 旋向
        - 「行进右侧」= forward × ŷ（右手系）；样例锚定: 面向 −ẑ 时 right = +x̂ ✓
        - signedAngleXZ 正 ⇔ 偏向行进右侧（数值标定 ✓，testHandednessCalibration）

        【SIT：正碰局面（cut=0°）+ squirt 补偿（隔离 CIT 与几何错位），v=1.5】
        左塞 spinX=+0.35 → 目标球离开方向 · right = \(String(format: "%.6f", sitLDot))（> 0 = 向右）
          有符号偏角 = \(String(format: "%+.4f", sitLDeg))°
        右塞 spinX=−0.35 → 目标球离开方向 · right = \(String(format: "%.6f", sitRDot))（< 0 = 向左）
          有符号偏角 = \(String(format: "%+.4f", sitRDeg))°
        结论: 左塞的 SIT 分量把目标球向右带？ \(sitLDot > 0 ? "YES" : "NO")；右塞向左？ \(sitRDot < 0 ? "YES" : "NO")

        【对照（首跑证伪记录）：不补偿 squirt、几何瞄准照打，左塞】
        有符号偏角 = \(String(format: "%+.4f", rawLDeg))°（负 = 向左）
        ⇒ squirt 错位的几何效应（约 −9.6°）远大于 SIT（约 +\(String(format: "%.1f", abs(sitLDeg)))°），方向反号。
        正文红线：只可说「左塞的投掷分量把目标球向右带」，不可说「加左塞球就往右跑」。

        【CIT vs 切角：同速 v=1.5、无塞、几何瞄准（首跑证伪「单调递增」）】
        cut=15° throw = \(String(format: "%.4f", t15))°
        cut=30° throw = \(String(format: "%.4f", t30))°
        cut=45° throw = \(String(format: "%.4f", t45))°
        结论: 15°→30° 递增 = \(t30 > t15 ? "YES" : "NO")；45° 较半球持平/略降 = \(t45 <= t30 * 1.05 ? "YES" : "NO")
        正文口径: 「切角越大投掷越明显，到半球附近最明显」（不写全程单调）。

        【定稿符号（② 节正文引用）】
        | 符号 | 结论 | 依据 |
        | 左塞 SIT | 投掷分量向右 | dot=\(String(format: "%.4f", sitLDot)) > 0（cut=0 + squirt 补偿） |
        | 切角 15°→30° | CIT 增大 | \(String(format: "%.3f", t30))° > \(String(format: "%.3f", t15))° |
        | 半球附近 | CIT 峰值邻域 | 45° \(String(format: "%.3f", t45))° ≈ 30° \(String(format: "%.3f", t30))° |

        ALL_PASS=\(allPass)
        """
        try text.write(to: dir.appendingPathComponent("z2-quickref-symbols.txt"),
                       atomically: true, encoding: .utf8)

        XCTAssertTrue(handedOK, "手性锚定失败")
        XCTAssertTrue(sitOK, "SIT 方向核验失败")
        XCTAssertTrue(citOK, "CIT 切角形状核验失败")
    }
}
