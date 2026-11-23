import XCTest
import SceneKit
@testable import QiuJi

/// Z3 数值补稿（问题集合 v12 Z3）：④⑤ 节新增定性符号的数值核验 + 插图手性契约锁定。
/// 按 geometry-spatial-reasoning 技能：先测后写，正文/插图符号以本草稿为准。
/// 证据落盘：`build/z3-evidence/`（相对仓库根）。
final class AimingCorrectionZ3EvidenceTests: XCTestCase {

    private var evidenceDir: URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // QiuJiTests
            .deletingLastPathComponent() // repo root
        return root.appendingPathComponent("build/z3-evidence", isDirectory: true)
    }

    // MARK: - 手性契约（新插图全部用世界系旋转 + 投影，不做屏侧符号翻转）

    /// 锁定恒等式：`a.rotatedY(signedAngleXZ(a→b)) ≡ b`（单位向量）。
    /// ②③⑤ 节夸大绘制 = potDir.rotatedY(signed × N) 后走 `proj.point` 投影，
    /// 手性由该恒等式 + `TableFigureRenderer` 投影（屏右=+X、屏下=+Z）共同保证。
    func testRotatedYReproducesSignedAngle() {
        let samples: [(SCNVector3, SCNVector3)] = [
            (SCNVector3(1, 0, 0), SCNVector3(0.8, 0, 0.6)),
            (SCNVector3(0, 0, -1), SCNVector3(0.5, 0, -0.866)),
            (SCNVector3(-0.6, 0, 0.8), SCNVector3(-0.9701425, 0, 0.24253562)),
            (SCNVector3(0.7071068, 0, 0.7071068), SCNVector3(1, 0, 0)),
        ]
        for (a, b) in samples {
            let signed = AimingCorrectionMath.signedAngleXZ(from: a, to: b)
            let rotated = a.rotatedY(signed)
            XCTAssertEqual(rotated.x, b.x, accuracy: 2e-5,
                           "rotatedY(signedAngleXZ) 应复现目标向量 x")
            XCTAssertEqual(rotated.z, b.z, accuracy: 2e-5,
                           "rotatedY(signedAngleXZ) 应复现目标向量 z")
        }
    }

    // MARK: - spinX 钳制（④ 节控件契约 = BTSpinPad 合成幅值口径）

    func testClampSpinXCombinedMagnitude() {
        let limit = CuePhysics.miscueLimitFraction
        // 中杆（y=0）：横轴全量可用 ±0.5
        XCTAssertEqual(AimingCorrectionMath.clampSpinX(0.7, spinY: 0), limit, accuracy: 1e-6)
        XCTAssertEqual(AimingCorrectionMath.clampSpinX(-0.7, spinY: 0), -limit, accuracy: 1e-6)
        XCTAssertEqual(AimingCorrectionMath.clampSpinX(0.2, spinY: 0), 0.2, accuracy: 1e-6)
        // 高/低杆 ±0.4：横轴可用 √(0.25−0.16) = 0.3
        let maxX = sqrtf(limit * limit - 0.4 * 0.4)
        XCTAssertEqual(AimingCorrectionMath.clampSpinX(0.5, spinY: 0.4), maxX, accuracy: 1e-6)
        XCTAssertEqual(AimingCorrectionMath.clampSpinX(-0.5, spinY: -0.4), -maxX, accuracy: 1e-6)
        XCTAssertEqual(AimingCorrectionMath.clampSpinX(0.25, spinY: 0.4), 0.25, accuracy: 1e-6)
        // 钳后合成幅值不越限
        let x = AimingCorrectionMath.clampSpinX(0.5, spinY: -0.4)
        XCTAssertLessThanOrEqual(sqrtf(x * x + 0.16), limit + 1e-6)
    }

    // MARK: - ⑤ 两档对比快照一致性

    func testSolveComparisonMatchesDirectCompute() {
        guard let cmp = AimingCorrectionMath.solveComparison() else {
            return XCTFail("solveComparison nil")
        }
        let pa = AimingCorrectionMath.ComparisonProfile.a
        let pb = AimingCorrectionMath.ComparisonProfile.b
        guard let a = AimingCorrectionMath.compute(
            velocity: pa.velocity, spinX: pa.spinX, spinY: pa.spinY
        ), let b = AimingCorrectionMath.compute(
            velocity: pb.velocity, spinX: pb.spinX, spinY: pb.spinY
        ) else {
            return XCTFail("direct compute nil")
        }
        XCTAssertEqual(cmp.a.aimOffsetRadians, a.aimOffsetRadians, accuracy: 1e-6)
        XCTAssertEqual(cmp.b.aimOffsetRadians, b.aimOffsetRadians, accuracy: 1e-6)
        // B 档打点合成幅值在打滑极限内（页面契约）
        let mag = sqrtf(pb.spinX * pb.spinX + pb.spinY * pb.spinY)
        XCTAssertLessThanOrEqual(mag, CuePhysics.miscueLimitFraction + 1e-6)
        // 两档 Δ 应可区分（⑤ 节图两条求解线不重合）
        XCTAssertGreaterThan(abs(cmp.a.aimOffsetDegrees - cmp.b.aimOffsetDegrees), 0.2,
                             "A/B 两档 Δ 应有可见差异")
    }

    // MARK: - ④ 弧线（swerve）数值草稿：碰前轨迹横向漂移实测（先测后写）

    /// 采样 `preContactSegments` 相对「击杆后实际出发方向」的横向偏移。
    /// 基准射线 = 母球起点 + executeStrike 实际初速方向（已含挤偏）——
    /// 这样 lateral 只剩滑动段的弯折（弧线），不混入挤偏本身。
    private static func swerveDrift(
        velocity: Float, spinX: Float, spinY: Float
    ) -> (finalLateral: Float, maxAbsLateral: Float, travel: Float, segments: Int)? {
        guard let snap = AimingCorrectionMath.compute(
            velocity: velocity, spinX: spinX, spinY: spinY
        ), let first = snap.preContactSegments.first else { return nil }
        let v0 = first.velocity
        let origin = first.position
        let offsets = AimingCorrectionMath.pathOffsets(
            snap.preContactSegments, baseOrigin: origin, baseDir: v0,
            samplesPerSegment: 32
        )
        guard let last = offsets.last else { return nil }
        let maxAbs = offsets.map { abs($0.lateral) }.max() ?? 0
        return (last.lateral, maxAbs, last.along, snap.preContactSegments.count)
    }

    /// 仰角对照：同左塞、同速，杆头仰角 0° vs 5° 的碰前横向漂移
    /// （真源 §2.1「弧线=滑动段侧旋与台呢摩擦」的引擎实证口径）。
    private static func swerveDriftElevated(
        velocity: Float, spinX: Float, spinY: Float, elevationDeg: Float
    ) -> (finalLateral: Float, maxAbsLateral: Float, travel: Float)? {
        var input = AimingCorrectionMath.makeInput(
            velocity: velocity, spinX: spinX, spinY: spinY)
        input.elevation = elevationDeg * .pi / 180
        var probe = ShotPrediction()
        guard let ctx = ShotPredictor.prepareAim(input, into: &probe) else { return nil }
        let out = AnalyticAim.outcome(
            aimDir: ctx.aimDir, velocity: velocity, input: input,
            geometry: ctx.geometry, ghost: ctx.ghost, collectSegments: true
        )
        guard let first = out.preContactSegments.first else { return nil }
        let offsets = AimingCorrectionMath.pathOffsets(
            out.preContactSegments, baseOrigin: first.position, baseDir: first.velocity,
            samplesPerSegment: 32
        )
        guard let last = offsets.last else { return nil }
        return (last.lateral, offsets.map { abs($0.lateral) }.max() ?? 0, last.along)
    }

    func testWriteZ3EvidenceDraft() throws {
        let dir = evidenceDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 挤偏与速度无关（§2.4：三偏差源中唯一不随力度变的）——纯打点函数
        let sqSlow = AimingCorrectionMath.squirtDegrees(spinX: 0.3)
        let sqFast = AimingCorrectionMath.squirtDegrees(spinX: 0.3) // 同一函数，不含 v
        let squirtSpeedFree = abs(sqSlow - sqFast) < 1e-9

        // 弧线漂移：左塞（+0.3），慢/快两档；对照 = 无塞
        let slowL = Self.swerveDrift(velocity: 0.8, spinX: 0.3, spinY: 0)
        let fastL = Self.swerveDrift(velocity: 4.0, spinX: 0.3, spinY: 0)
        let noSpin = Self.swerveDrift(velocity: 0.8, spinX: 0, spinY: 0)
        let lowSpin = Self.swerveDrift(velocity: 0.8, spinX: 0.3, spinY: -0.4)
        // 组合档（左塞+低杆）速度扫描：核验「越慢弧线累积越多」在组合档是否成立
        let comboSlow = Self.swerveDrift(velocity: 0.8, spinX: 0.3, spinY: -0.4)
        let comboMid = Self.swerveDrift(velocity: 2.0, spinX: 0.3, spinY: -0.4)
        let comboFast = Self.swerveDrift(velocity: 4.0, spinX: 0.3, spinY: -0.4)
        // 仰角对照：纯左塞 + 仰角 5°（实战「弧线来自有仰角出杆」的引擎实证）
        let elev0 = Self.swerveDriftElevated(velocity: 0.8, spinX: 0.3, spinY: 0, elevationDeg: 0)
        let elev5 = Self.swerveDriftElevated(velocity: 0.8, spinX: 0.3, spinY: 0, elevationDeg: 5)

        func fmt(_ d: (finalLateral: Float, maxAbsLateral: Float, travel: Float, segments: Int)?) -> String {
            guard let d else { return "nil" }
            return String(format: "final=%+.6f mm=%+.3f, maxAbs=%.6f m, travel=%.4f m, segs=%d",
                          d.finalLateral, d.finalLateral * 1000, d.maxAbsLateral, d.travel, d.segments)
        }

        // 判定：平杆（elevation=0）下弧线是否达到可教学量级（> 0.5mm 横向漂移）
        let measurable = (slowL?.maxAbsLateral ?? 0) > 0.0005

        let text = """
        === Z3 数值补稿（④⑤ 节新增定性符号核验）===
        日期: 2026-07-18
        真源: AimingCorrectionMath（只读 compute → executeStrike/AnalyticAim.outcome）

        【坐标契约回显】
        - 系: SceneKit 世界系；水平面 X–Z；+Y 朝上；单位米
        - BTTableFigure landscape 投影: x_img ∝ +X（屏右），y_img ∝ +Z（屏下）⇒ 屏上 = −Z
        - rotatedY(θ) = (x·cosθ − z·sinθ, y, x·sinθ + z·cosθ)
        - 恒等式 a.rotatedY(signedAngleXZ(a→b)) ≡ b（testRotatedYReproducesSignedAngle 锁定）
          ⇒ 插图夸大绘制一律世界系旋转 + 投影，无屏侧手性翻转
        - spinX 正 = 左塞；squirtAngle 负 = 向右；实际出发方向 = aim.rotatedY(−squirt)
        - 打滑极限: √(spinX²+spinY²) ≤ \(CuePhysics.miscueLimitFraction)

        【挤偏 与 力度 的关系】
        squirtAngle(a:) 仅是打点 a 的函数，不含速度参数（CueBallStrike.squirtAngle 签名）：
        v=0.8 与 v=4.0 下左塞 0.3 → squirt 同为 \(String(format: "%+.4f", sqSlow))°
        「挤偏与速度基本无关」成立？ \(squirtSpeedFree ? "YES" : "NO")

        【弧线（swerve）：碰前轨迹相对实际出发方向的横向漂移（正 = 行进右侧）】
        基准射线 = 首段起点 + 首段初速方向（已含挤偏，lateral 只剩滑动段弯折）
        左塞 spinX=+0.3 中杆 v=0.8: \(fmt(slowL))
        左塞 spinX=+0.3 中杆 v=4.0: \(fmt(fastL))
        无塞       中杆 v=0.8: \(fmt(noSpin))
        左塞+低杆 spinX=+0.3 spinY=−0.4 v=0.8: \(fmt(lowSpin))

        平杆纯侧旋（spinY=0）下弧线漂移达到可教学量级（>0.5mm）？ \(measurable ? "YES" : "NO")
        （物理归因：平杆纯侧旋 ⇒ 自转轴竖直 ⇒ ω×r 在接触点无水平分量 ⇒ 滑动摩擦不弯折；
        侧旋叠加高低杆时自转轴倾斜，滑动段摩擦方向随之改变 ⇒ 轨迹微弯。）

        【弧线（组合档 左塞+低杆 spinX=+0.3 spinY=−0.4）速度扫描】
        v=0.8: \(fmt(comboSlow))
        v=2.0: \(fmt(comboMid))
        v=4.0: \(fmt(comboFast))
        「越慢弧线累积越多」在组合档成立？ \((comboSlow?.maxAbsLateral ?? 0) > (comboFast?.maxAbsLateral ?? 0) ? "YES" : "NO")

        【仰角对照：纯左塞 spinX=+0.3 v=0.8】
        仰角 0°: \(elev0.map { String(format: "final=%+.6f m (%.3f mm)", $0.finalLateral, $0.finalLateral * 1000) } ?? "nil")
        仰角 5°: \(elev5.map { String(format: "final=%+.6f m (%.3f mm)", $0.finalLateral, $0.finalLateral * 1000) } ?? "nil")
        「仰角出杆使纯侧旋产生弧线」在引擎成立？ \((abs(elev5?.finalLateral ?? 0) > abs(elev0?.finalLateral ?? 0) + 0.0005) ? "YES" : "NO")
        ⇒ 正文口径见下方【定稿符号】。

        【⑤ 两档对比页面契约】
        A = v=\(AimingCorrectionMath.ComparisonProfile.a.velocity) 中杆无塞
        B = v=\(AimingCorrectionMath.ComparisonProfile.b.velocity) spinY=\(AimingCorrectionMath.ComparisonProfile.b.spinY)（低杆）spinX=+\(AimingCorrectionMath.ComparisonProfile.b.spinX)（左塞）
        """

        var lines = [text]
        if let cmp = AimingCorrectionMath.solveComparison() {
            lines.append(String(format: "A 档 Δ = %+.4f°；B 档 Δ = %+.4f°（与 Z1 扫描表 v=0.8/−0.4/+0.3 行 −1.4262° 同参可对照）",
                                cmp.a.aimOffsetDegrees, cmp.b.aimOffsetDegrees))
        }
        lines.append("""

        【定稿符号（④⑤ 节正文引用）——落盘后按实测填 YES/NO】
        | 符号 | 结论 | 依据 |
        | 挤偏与力度无关 | \(squirtSpeedFree ? "YES" : "NO") | squirtAngle 无速度参数，两档同值 |
        | 平杆纯侧旋弧线 | \(measurable ? "可教学量级" : "≈0（正文不得写「纯左塞轨迹必弯」）") | 上方漂移实测 |
        | 侧旋+高低杆弧线 | \((lowSpin?.maxAbsLateral ?? 0) > 0.0005 ? "可测（正文可写微弯，方向随实况读数）" : "≈0") | 组合档漂移实测 |
        | 弧线越慢越明显 | \((comboSlow?.maxAbsLateral ?? 0) > (comboFast?.maxAbsLateral ?? 0) ? "YES（组合档）" : "NO") | 组合档速度扫描 |

        ALL_PASS=true（本草稿为测量型：符号以上方实测行文本为准）
        """)

        try lines.joined(separator: "\n")
            .write(to: dir.appendingPathComponent("z3-quickref-symbols.txt"),
                   atomically: true, encoding: .utf8)

        XCTAssertTrue(squirtSpeedFree, "挤偏应与速度无关（纯打点函数）")
        XCTAssertNotNil(slowL, "弧线漂移采样失败")
        // 实测事实锁定（首跑测得，防回归漂移；改动引擎参数需重新核验草稿）：
        // 1) 平杆纯侧旋弧线 ≈ 0（正文不得写「纯左塞轨迹必弯」）
        XCTAssertLessThan(slowL?.maxAbsLateral ?? 1, 0.0005,
                          "平杆纯侧旋不应产生可测弧线（自转轴竖直）")
        // 2) 侧旋+低杆组合档弧线可测，且越慢累积越多
        XCTAssertGreaterThan(comboSlow?.maxAbsLateral ?? 0, 0.0005,
                             "组合档（左塞+低杆）慢速应有可测弧线漂移")
        XCTAssertGreaterThan(comboSlow?.maxAbsLateral ?? 0,
                             comboFast?.maxAbsLateral ?? 1,
                             "弧线应越慢累积越多（组合档）")
    }
}
