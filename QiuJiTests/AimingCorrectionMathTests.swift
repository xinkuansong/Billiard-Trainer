import XCTest
import SceneKit
@testable import QiuJi

/// 瞄准修正真源层单测 + 数值草稿落盘（问题集合 v12 Z1）。
/// 证据目录：`build/z1-evidence/`（相对仓库根）。
final class AimingCorrectionMathTests: XCTestCase {

    private var evidenceDir: URL {
        // QiuJiTests → …/13.billiard_trainer-wt-z1/build/z1-evidence
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // QiuJiTests
            .deletingLastPathComponent() // repo root
        return root.appendingPathComponent("build/z1-evidence", isDirectory: true)
    }

    // MARK: - Required assertions

    /// 左塞 (spinX>0) → squirtAngle 负值 = 向右偏（CueBallStrike 文档）。
    func testLeftEnglishSquirtBiasesRight() {
        let left = AimingCorrectionMath.squirtDegrees(spinX: 0.3)
        let right = AimingCorrectionMath.squirtDegrees(spinX: -0.3)
        XCTAssertLessThan(left, 0, "左塞 squirt 应为负（向右偏），got \(left)°")
        XCTAssertGreaterThan(right, 0, "右塞 squirt 应为正（向左偏），got \(right)°")
        XCTAssertEqual(left, -right, accuracy: 1e-4)
    }

    /// 慢速 vs 快速 CIT：同一几何瞄准、中杆无塞，慢球投掷角更大（Alciatore）。
    func testSlowCITLargerThanFast() {
        guard let slow = AimingCorrectionMath.analyticAtGeometricAim(
            velocity: 0.8, spinX: 0, spinY: 0
        ), let fast = AimingCorrectionMath.analyticAtGeometricAim(
            velocity: 4.0, spinX: 0, spinY: 0
        ) else {
            return XCTFail("prepareAim/outcome failed for teaching setup")
        }
        guard let slowObj = slow.outcome.objPostContactDir,
              let fastObj = fast.outcome.objPostContactDir else {
            return XCTFail("objPostContactDir nil — contact missed")
        }
        let slowThrow = AimingCorrectionMath.throwAngleDegrees(
            potDir: slow.potDir, objPost: slowObj)
        let fastThrow = AimingCorrectionMath.throwAngleDegrees(
            potDir: fast.potDir, objPost: fastObj)
        XCTAssertGreaterThan(slowThrow, fastThrow,
                             "慢速 CIT (\(slowThrow)°) 应 > 快速 (\(fastThrow)°)")
        XCTAssertGreaterThan(slowThrow, 0.01, "慢速投掷应可测（>0.01°）")
    }

    /// Δ 与 `positionAimOffset` 直接调用一致。
    func testDeltaMatchesPositionAimOffset() {
        let v: Float = 1.5
        let sx: Float = 0.2
        let sy: Float = -0.15
        guard let snap = AimingCorrectionMath.compute(
            velocity: v, spinX: sx, spinY: sy
        ) else {
            return XCTFail("compute returned nil")
        }
        let input = AimingCorrectionMath.makeInput(velocity: v, spinX: sx, spinY: sy)
        var probe = ShotPrediction()
        guard let ctx = ShotPredictor.prepareAim(input, into: &probe) else {
            return XCTFail("prepareAim failed")
        }
        let direct = ShotPredictor.positionAimOffset(input: input, context: ctx)
        XCTAssertEqual(snap.aimOffsetRadians, direct, accuracy: 1e-6,
                       "Snapshot.Δ must equal positionAimOffset")
        // solvedAimDir = geometric.rotatedY(Δ)
        let expected = ctx.aimDir.rotatedY(direct)
        XCTAssertEqual(snap.solvedAimDir.x, expected.x, accuracy: 1e-5)
        XCTAssertEqual(snap.solvedAimDir.z, expected.z, accuracy: 1e-5)
    }

    /// 厚薄符号标定（几何红线：符号映射不脑算，用「碰后目标球速度」独立定义厚薄）——
    /// 更薄的碰撞把更少动量传给目标球（碰后球速更小）；对无塞中杆的 ±δ 瞄准扰动，
    /// 碰后球速更小的一侧其 `thicknessBiasDegrees` 必须更正 ⇒「正 = 偏薄」成立。
    func testThicknessBiasSignCalibration() {
        let v: Float = 1.5
        let input = AimingCorrectionMath.makeInput(velocity: v, spinX: 0, spinY: 0)
        var probe = ShotPrediction()
        guard let ctx = ShotPredictor.prepareAim(input, into: &probe) else {
            return XCTFail("prepareAim failed")
        }
        let potDir = Self.unitXZ(from: input.targetBall, to: ctx.aimPoint)
        let delta: Float = 1.5 * .pi / 180

        func probeAim(_ offset: Float) -> (speed: Float, bias: Float)? {
            let out = AnalyticAim.outcome(
                aimDir: ctx.aimDir.rotatedY(offset), velocity: v, input: input,
                geometry: ctx.geometry, ghost: ctx.ghost
            )
            guard let objPost = out.objPostContactDir,
                  let objAfter = out.objAfterContact else { return nil }
            let sp = sqrtf(objAfter.velocity.x * objAfter.velocity.x
                           + objAfter.velocity.z * objAfter.velocity.z)
            let bias = AimingCorrectionMath.thicknessBiasDegrees(
                potDir: potDir, aimDir: ctx.aimDir, objPost: objPost)
            return (sp, bias)
        }

        guard let plus = probeAim(+delta), let minus = probeAim(-delta) else {
            return XCTFail("±δ 扰动应仍命中目标球")
        }
        let thinner = plus.speed < minus.speed ? plus : minus
        let thicker = plus.speed < minus.speed ? minus : plus
        XCTAssertGreaterThan(
            thinner.bias, thicker.bias,
            "更薄侧（碰后球速 \(thinner.speed) < \(thicker.speed)）bias 应更正：thin=\(thinner.bias)° thick=\(thicker.bias)°"
        )
    }

    private static func unitXZ(from a: SCNVector3, to b: SCNVector3) -> SCNVector3 {
        let dx = b.x - a.x, dz = b.z - a.z
        let len = max(sqrtf(dx * dx + dz * dz), 1e-9)
        return SCNVector3(dx / len, 0, dz / len)
    }

    /// 教学局面切角落在半球附近（允许管道修正带来的小漂移）。
    func testTeachingSetupNearHalfBall() {
        guard let snap = AimingCorrectionMath.compute(
            velocity: Float(ShotTuning.defaultVelocity), spinX: 0, spinY: 0
        ) else {
            return XCTFail("compute nil")
        }
        XCTAssertEqual(snap.cutAngleDeg, 30, accuracy: 3.0,
                       "teaching cut should be ~30°, got \(snap.cutAngleDeg)")
        XCTAssertFalse(snap.preContactSegments.isEmpty,
                       "collectSegments should yield pre-contact path")
    }

    // MARK: - Evidence dump（数值草稿落盘）

    /// 扫描 Δ(v×spinY×spinX) + 速查表定性符号核验 → `build/z1-evidence/`。
    func testWriteZ1EvidenceDraft() throws {
        let dir = evidenceDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // 坐标契约
        let contract = """
        === Z1 瞄准修正 — 坐标契约回显 ===
        日期: 2026-07-18
        真源: .kiro/steering/table-geometry.md + AimingCorrectionMath + BTPhysicsConstants

        【钉死坐标契约】
        - 系: SceneKit 世界系
        - 水平面: X–Z；+Y 朝上
        - 轴向: +X = 右端；+Z = 顶视图上方（BTTableFigure landscape 屏上常 = −Z，以投影为准）
        - 单位: 米；R = \(BallPhysics.radius) m；surfaceY = \(BTTablePhysics.surfaceY) m
        - 水平角: atan2(z, x)；绕竖直轴: rotatedY
        - 假想球: G = T − 2R · normalize(pocket − T)（prepareAim 内）
        - Δ 口径: positionAimOffset 解析层（弧度）；不用 Simulated
        - 挤偏: CueBallStrike.squirtAngle(a)；负值=向右偏；左塞 a>0
        - spinY 正 = 高杆；spinX 正 = 左塞
        - 力度量程: \(ShotTuning.velocityRange) m/s；打滑极限: \(CuePhysics.miscueLimitFraction) R

        【教学局面】
        - 构造: AimingMethodsGeometry.scene(θ=30°) → cue/target；pocketIndex=1（右上）
        - prepareAim 回填切角允许 ±3°（进球管道修正）
        """
        try contract.write(to: dir.appendingPathComponent("coordinate-contract.txt"),
                           atomically: true, encoding: .utf8)

        // Δ 扫描表
        let velocities: [Float] = [0.8, 1.5, 3.0, 5.0]
        let spinYs: [Float] = [-0.4, 0, 0.4]
        let spinXs: [Float] = [-0.3, 0, 0.3]
        var scanLines: [String] = [
            "=== Z1 Δ 扫描表（固定教学局面，Δ = positionAimOffset 度）===",
            "v_m/s\tspinY\tspinX\tΔ_deg\tcut_deg\tsquirt_deg\tthrow_geo_deg\tthickness_bias_deg",
        ]
        for v in velocities {
            for sy in spinYs {
                for sx in spinXs {
                    guard let snap = AimingCorrectionMath.compute(
                        velocity: v, spinX: sx, spinY: sy
                    ) else {
                        scanLines.append("\(v)\t\(sy)\t\(sx)\tnil\t-\t-\t-\t-")
                        continue
                    }
                    var throwDeg: Float = .nan
                    var thick: Float = .nan
                    if let geo = AimingCorrectionMath.analyticAtGeometricAim(
                        velocity: v, spinX: sx, spinY: sy
                    ), let obj = geo.outcome.objPostContactDir {
                        throwDeg = AimingCorrectionMath.throwAngleDegrees(
                            potDir: geo.potDir, objPost: obj)
                        thick = AimingCorrectionMath.thicknessBiasDegrees(
                            potDir: geo.potDir, aimDir: geo.ctx.aimDir, objPost: obj)
                    }
                    scanLines.append(String(
                        format: "%.1f\t%+.1f\t%+.1f\t%+.4f\t%.2f\t%+.4f\t%.4f\t%+.4f",
                        v, sy, sx,
                        snap.aimOffsetDegrees, snap.cutAngleDeg, snap.squirtDegrees,
                        throwDeg, thick
                    ))
                }
            }
        }
        let scanText = scanLines.joined(separator: "\n") + "\n"
        try scanText.write(to: dir.appendingPathComponent("delta-scan-table.tsv"),
                           atomically: true, encoding: .utf8)

        // 速查表定性核验（符号以本草稿为准）
        let leftSquirt = AimingCorrectionMath.squirtDegrees(spinX: 0.35)
        let rightSquirt = AimingCorrectionMath.squirtDegrees(spinX: -0.35)

        let slow = AimingCorrectionMath.analyticAtGeometricAim(velocity: 0.8, spinX: 0, spinY: 0)!
        let fast = AimingCorrectionMath.analyticAtGeometricAim(velocity: 4.0, spinX: 0, spinY: 0)!
        let slowT = AimingCorrectionMath.throwAngleDegrees(
            potDir: slow.potDir, objPost: slow.outcome.objPostContactDir!)
        let fastT = AimingCorrectionMath.throwAngleDegrees(
            potDir: fast.potDir, objPost: fast.outcome.objPostContactDir!)

        let high = AimingCorrectionMath.analyticAtGeometricAim(velocity: 1.5, spinX: 0, spinY: 0.4)!
        let mid = AimingCorrectionMath.analyticAtGeometricAim(velocity: 1.5, spinX: 0, spinY: 0)!
        let low = AimingCorrectionMath.analyticAtGeometricAim(velocity: 1.5, spinX: 0, spinY: -0.4)!
        let highBias = AimingCorrectionMath.thicknessBiasDegrees(
            potDir: high.potDir, aimDir: high.ctx.aimDir,
            objPost: high.outcome.objPostContactDir!)
        let midBias = AimingCorrectionMath.thicknessBiasDegrees(
            potDir: mid.potDir, aimDir: mid.ctx.aimDir,
            objPost: mid.outcome.objPostContactDir!)
        let lowBias = AimingCorrectionMath.thicknessBiasDegrees(
            potDir: low.potDir, aimDir: low.ctx.aimDir,
            objPost: low.outcome.objPostContactDir!)

        // 厚薄符号标定（不脑算）：碰后目标球速更小 = 更薄；其 bias 应更正。
        let calibInput = AimingCorrectionMath.makeInput(velocity: 1.5, spinX: 0, spinY: 0)
        var calibProbe = ShotPrediction()
        let calibCtx = ShotPredictor.prepareAim(calibInput, into: &calibProbe)!
        let calibPotDir = Self.unitXZ(from: calibInput.targetBall, to: calibCtx.aimPoint)
        func calib(_ off: Float) -> (speed: Float, bias: Float) {
            let out = AnalyticAim.outcome(
                aimDir: calibCtx.aimDir.rotatedY(off), velocity: 1.5, input: calibInput,
                geometry: calibCtx.geometry, ghost: calibCtx.ghost
            )
            let vB = out.objAfterContact!.velocity
            return (sqrtf(vB.x * vB.x + vB.z * vB.z),
                    AimingCorrectionMath.thicknessBiasDegrees(
                        potDir: calibPotDir, aimDir: calibCtx.aimDir,
                        objPost: out.objPostContactDir!))
        }
        let d15: Float = 1.5 * .pi / 180
        let cPlus = calib(+d15)
        let cMinus = calib(-d15)
        let thinIsPositive = (cPlus.speed < cMinus.speed && cPlus.bias > cMinus.bias)
            || (cMinus.speed < cPlus.speed && cMinus.bias > cPlus.bias)

        // 结论：相对中杆，高杆 bias 更大（更偏薄侧）？低杆更小（更偏厚侧）？
        let highThinner = highBias > midBias
        let lowThicker = lowBias < midBias
        let leftSquirtRight = leftSquirt < 0
        let slowThrowLarger = slowT > fastT

        let conclusions = """
        === Z1 速查表定性符号结论（以本草稿为准，禁止先写后验）===
        局面: AimingMethodsGeometry θ=30° 教学位 → pocketIndex=1
        度量:
          - squirt_deg = CueBallStrike.squirtAngle×180/π（负=向右）
          - throw_geo_deg = |∠(potDir, objPost)| 几何瞄准下（度）
          - thickness_bias_deg = −signed∠(potDir,obj)×cutSide；正=偏薄侧，负=偏厚侧
            （符号经 ±1.5° 瞄准扰动标定：薄侧=碰后球速更小侧，其 bias 必须更正）

        【厚薄符号标定（独立于 spin 的地基）】
        无塞中杆 v=1.5，瞄准 ±1.5° 扰动（碰后球速更小 = 更薄）：
          +1.5°: objSpeed=\(String(format: "%.4f", cPlus.speed)) m/s, bias=\(String(format: "%+.4f", cPlus.bias))°
          −1.5°: objSpeed=\(String(format: "%.4f", cMinus.speed)) m/s, bias=\(String(format: "%+.4f", cMinus.bias))°
        「正 = 偏薄」映射成立？ \(thinIsPositive ? "YES" : "NO")

        【核验数据】
        左塞 spinX=+0.35 → squirt = \(String(format: "%+.4f", leftSquirt))°
        右塞 spinX=-0.35 → squirt = \(String(format: "%+.4f", rightSquirt))°
        慢速 v=0.8  CIT throw = \(String(format: "%.4f", slowT))°
        快速 v=4.0  CIT throw = \(String(format: "%.4f", fastT))°
        高杆 spinY=+0.4 thickness_bias = \(String(format: "%+.4f", highBias))°
        中杆 spinY=0     thickness_bias = \(String(format: "%+.4f", midBias))°
        低杆 spinY=-0.4 thickness_bias = \(String(format: "%+.4f", lowBias))°

        【定性结论（正文/速查表必须对齐）】
        1. 左塞 → 挤偏向右？ \(leftSquirtRight ? "YES" : "NO")  （squirt<0）
        2. 轻力投掷更大？ \(slowThrowLarger ? "YES" : "NO")  （slow CIT > fast CIT）
        3. 高杆相对中杆更偏薄？ \(highThinner ? "YES" : "NO")  （highBias > midBias）
        4. 低杆相对中杆更偏厚？ \(lowThicker ? "YES" : "NO")  （lowBias < midBias）

        【速查表定稿符号】
        | 条件 | 符号结论 | 草稿依据 |
        | 左塞 | 挤偏向右 | squirt=\(String(format: "%+.3f", leftSquirt))° < 0 |
        | 轻力 | 投掷更大 | CIT \(String(format: "%.3f", slowT))° > \(String(format: "%.3f", fastT))° |
        | 高杆 | 偏薄（相对中杆） | bias \(String(format: "%+.3f", highBias))° > \(String(format: "%+.3f", midBias))° |
        | 低杆 | 偏厚（相对中杆） | bias \(String(format: "%+.3f", lowBias))° < \(String(format: "%+.3f", midBias))° |

        ALL_PASS=\(thinIsPositive && leftSquirtRight && slowThrowLarger && highThinner && lowThicker)
        """
        try conclusions.write(to: dir.appendingPathComponent("quickref-symbols.txt"),
                              atomically: true, encoding: .utf8)

        // 也写一份完整 markdown 草稿
        let draft = """
        # Z1 数值草稿（自跑）

        见同目录:
        - coordinate-contract.txt
        - delta-scan-table.tsv
        - quickref-symbols.txt

        ALL_PASS=\(thinIsPositive && leftSquirtRight && slowThrowLarger && highThinner && lowThicker)
        """
        try draft.write(to: dir.appendingPathComponent("z1-geometry-draft.txt"),
                        atomically: true, encoding: .utf8)

        XCTAssertTrue(thinIsPositive, "厚薄符号标定失败：正 = 偏薄映射不成立")
        XCTAssertTrue(leftSquirtRight, "左塞挤偏应向右")
        XCTAssertTrue(slowThrowLarger, "轻力投掷应更大")
        XCTAssertTrue(highThinner, "高杆应相对中杆偏薄；high=\(highBias) mid=\(midBias)")
        XCTAssertTrue(lowThicker, "低杆应相对中杆偏厚；low=\(lowBias) mid=\(midBias)")
    }
}
