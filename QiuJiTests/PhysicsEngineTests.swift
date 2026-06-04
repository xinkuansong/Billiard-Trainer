import XCTest
import SceneKit
@testable import QiuJi

/// 物理引擎正确性测试——以 pooltool 物理与经典台球定律（90° 法则、滚动条件、
/// squirt 方向）为基准，回归保护移植后的引擎。
final class PhysicsEngineTests: XCTestCase {

    private let R = BallPhysics.radius

    // MARK: - 击打模型（CueBallStrike）

    /// 修复回归：高杆(b=1) 产生的角速度应在合理量级（数十～两百 rad/s），
    /// 而非旧 bug 的 ~千级（缺 R 因子导致偏大 ~1/R≈35×）。
    func test_strike_topSpin_angularMagnitudeReasonable() {
        let s = CueBallStrike.executeStrike(
            aimDirection: SCNVector3(1, 0, 0), velocity: 2.0,
            spinX: 0, spinY: 1, elevation: 0
        )
        let wMag = s.angularVelocity.length()
        XCTAssertGreaterThan(wMag, 40, "高杆角速度过小")
        XCTAssertLessThan(wMag, 220, "高杆角速度量级异常偏大（疑似 R 因子 bug 回归）")
    }

    /// 高杆：绕垂直于行进方向的水平轴正向滚动；行进 +x 时 w 应主要在 -z，
    /// 且为「过量上旋」（|w| 大于自然滚动 v/R），从而产生跟球。
    func test_strike_topSpin_isForwardRollOverspin() {
        let v0: Float = 2.0
        let s = CueBallStrike.executeStrike(
            aimDirection: SCNVector3(1, 0, 0), velocity: v0,
            spinX: 0, spinY: 1, elevation: 0
        )
        // 行进方向 ≈ +x
        XCTAssertGreaterThan(s.velocity.x, 0.2)
        XCTAssertEqual(s.velocity.z, 0, accuracy: 1e-3)
        // 上旋轴：scene w 主要在 -z
        XCTAssertLessThan(s.angularVelocity.z, -1.0)
        XCTAssertEqual(s.angularVelocity.x, 0, accuracy: 1e-3)
        XCTAssertEqual(s.angularVelocity.y, 0, accuracy: 1e-3)
        // 过量上旋：|w| > 自然滚动 v/R
        let naturalRoll = s.velocity.length() / R
        XCTAssertGreaterThan(abs(s.angularVelocity.z), naturalRoll)
    }

    /// 低杆(b=-1)：回旋方向与高杆相反（w.z 为正）。
    func test_strike_drawSpin_isBackspin() {
        let s = CueBallStrike.executeStrike(
            aimDirection: SCNVector3(1, 0, 0), velocity: 2.0,
            spinX: 0, spinY: -1, elevation: 0
        )
        XCTAssertGreaterThan(s.angularVelocity.z, 1.0, "低杆应产生反向旋转")
    }

    /// 中心击打：无旋转，纯前进。
    func test_strike_center_noSpin() {
        let s = CueBallStrike.executeStrike(
            aimDirection: SCNVector3(1, 0, 0), velocity: 2.0,
            spinX: 0, spinY: 0, elevation: 0
        )
        XCTAssertLessThan(s.angularVelocity.length(), 1e-2, "中心击打不应产生旋转")
        XCTAssertGreaterThan(s.velocity.x, 0.5)
    }

    /// Squirt：左塞(a>0) 使母球向右偏（squirt 角为负，pooltool 约定）。
    func test_squirt_leftEnglish_deflectsRight() {
        XCTAssertLessThan(CueBallStrike.squirtAngle(a: 0.5), 0)
        XCTAssertGreaterThan(CueBallStrike.squirtAngle(a: -0.5), 0)
        XCTAssertEqual(CueBallStrike.squirtAngle(a: 0), 0, accuracy: 1e-6)
    }

    // MARK: - 球-球碰撞（CollisionResolver）

    /// 90° 法则：定杆(无旋)切球，母球与目标球碰后分离角 ≈ 90°
    /// （含 throw 时略小于 90°）。
    func test_ballBall_stun_90degreeRule() {
        let cut: Float = 30 * .pi / 180
        let posA = SCNVector3(0, 0.8, 0)
        let posB = SCNVector3(2 * R * cosf(cut), 0.8, 2 * R * sinf(cut))
        let result = CollisionResolver.resolveBallBallPure(
            posA: posA, posB: posB,
            velA: SCNVector3(2, 0, 0), velB: SCNVector3Zero,
            angVelA: SCNVector3Zero, angVelB: SCNVector3Zero
        )
        let cueDir = horizontalDir(result.velA)
        let objDir = horizontalDir(result.velB)
        let dot = max(-1, min(1, cueDir.x * objDir.x + cueDir.z * objDir.z))
        let sep = acosf(dot) * 180 / .pi
        // 定杆分离角应接近 90°（throw 令其略小）。
        XCTAssertEqual(sep, 90, accuracy: 8, "定杆分离角应接近 90°，实测 \(sep)")
        XCTAssertLessThanOrEqual(sep, 90.5)
    }

    /// 正面全球定杆：母球几乎停住，目标球带走绝大部分速度（e_b=0.95）。
    func test_ballBall_headOn_stun_transfersVelocity() {
        let posA = SCNVector3(0, 0.8, 0)
        let posB = SCNVector3(2 * R, 0.8, 0)   // 连心线沿 +x，与速度同向
        let v: Float = 2.0
        let result = CollisionResolver.resolveBallBallPure(
            posA: posA, posB: posB,
            velA: SCNVector3(v, 0, 0), velB: SCNVector3Zero,
            angVelA: SCNVector3Zero, angVelB: SCNVector3Zero
        )
        // 母球残速 ≈ 0.025v，目标球 ≈ 0.975v（恢复系数 0.95）。
        XCTAssertEqual(result.velA.x, 0.025 * v, accuracy: 0.05)
        XCTAssertEqual(result.velB.x, 0.975 * v, accuracy: 0.05)
        XCTAssertEqual(result.velA.z, 0, accuracy: 1e-3)
        XCTAssertEqual(result.velB.z, 0, accuracy: 1e-3)
    }

    // MARK: - 端到端（ShotPredictor）

    /// 摆一个可进球位，定杆中速击打：目标球应进袋，且能算出分离角与轨迹。
    func test_predictor_stunPot_producesPaths() {
        let surfaceY: Float = BTTablePhysics.surfaceY
        // 目标球在台面中央偏右，母球在其左侧；目标右上角袋(index 1)。
        let target = SCNVector3(0.4, surfaceY + R, 0.0)
        let cue = SCNVector3(-0.2, surfaceY + R, 0.0)
        let input = ShotInput(
            cueBall: cue, targetBall: target,
            pocketIndex: 1, velocity: StrokePhysics.SpeedLevel.medium.velocity, spinX: 0, spinY: 0,
            surfaceY: surfaceY
        )
        let pred = ShotPredictor.predict(input)
        XCTAssertGreaterThan(pred.cuePath.count, 1, "母球轨迹应非空")
        XCTAssertGreaterThan(pred.objectPath.count, 1, "目标球轨迹应非空")
        XCTAssertNotNil(pred.separationAngleDeg, "应发生球-球碰撞并得到分离角")
        if let sep = pred.separationAngleDeg {
            XCTAssertGreaterThan(sep, 40)
            XCTAssertLessThan(sep, 100)
        }
    }

    /// 不可进的角度：母球与目标球同在袋口一侧，需要近 90° 切球 → feasible == false。
    func test_predictor_infeasibleAngle_flagged() {
        let surfaceY: Float = BTTablePhysics.surfaceY
        let target = SCNVector3(0, surfaceY + R, 0)
        let cue = SCNVector3(-0.2, surfaceY + R, 0)
        // 左上角袋(index 0, 位于 -x/-z)：母球已在 -x 侧，无法把目标球推向更 -x 的袋。
        let input = ShotInput(
            cueBall: cue, targetBall: target,
            pocketIndex: 0, velocity: StrokePhysics.SpeedLevel.medium.velocity, spinX: 0, spinY: 0,
            surfaceY: surfaceY
        )
        let pred = ShotPredictor.predict(input)
        XCTAssertFalse(pred.feasible, "该角度应判为无法进袋")
        XCTAssertFalse(pred.infeasibleReason.isEmpty)
        XCTAssertTrue(pred.cuePath.isEmpty, "不可进时不应产生轨迹")
    }

    /// 加塞时 squirt 补偿应保证目标球仍能进袋。
    func test_predictor_withSideSpin_stillPots() {
        let surfaceY: Float = BTTablePhysics.surfaceY
        let target = SCNVector3(0.4, surfaceY + R, 0.0)
        let cue = SCNVector3(-0.2, surfaceY + R, 0.0)
        let input = ShotInput(
            cueBall: cue, targetBall: target,
            pocketIndex: 1, velocity: StrokePhysics.SpeedLevel.mediumHard.velocity, spinX: 0.5, spinY: 0,
            surfaceY: surfaceY
        )
        let pred = ShotPredictor.predict(input)
        XCTAssertTrue(pred.feasible)
        XCTAssertTrue(pred.objectPocketed, "加塞后经 squirt 补偿仍应进袋")
    }

    /// 加塞时瞄准求解必须让**真实模拟**的目标球进袋（而非仅几何标记）。
    /// 这是对用户反馈「加塞后目标球实际轨迹不对、先吃库再进/进不去」的回归防线：
    /// 校验解出的瞄准偏移确实把母球（含 squirt + swerve）带到理想接触点，目标球真正落袋。
    func test_predictor_withSideSpin_objectPotsInSimulation() {
        let surfaceY: Float = BTTablePhysics.surfaceY
        let target = SCNVector3(0.4, surfaceY + R, 0.0)
        let cue = SCNVector3(-0.2, surfaceY + R, 0.0)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: surfaceY)[1]

        func simulatedObjectMinDistToPocket(spinX: Float) -> Float {
            let input = ShotInput(
                cueBall: cue, targetBall: target,
                pocketIndex: 1, velocity: StrokePhysics.SpeedLevel.mediumHard.velocity,
                spinX: spinX, spinY: 0, surfaceY: surfaceY
            )
            let pred = ShotPredictor.predict(input)
            guard let frames = pred.recorder?.framesByBallName[ShotInput.targetBallName] else {
                return .greatestFiniteMagnitude
            }
            var minDist = Float.greatestFiniteMagnitude
            for f in frames {
                let dx = f.position.x - pocket.x, dz = f.position.z - pocket.z
                minDist = min(minDist, sqrtf(dx * dx + dz * dz))
            }
            return minDist
        }

        // 无塞基线与强侧塞都应让模拟中的目标球抵达袋口（捕获窗 ~6cm 内）。
        XCTAssertLessThan(simulatedObjectMinDistToPocket(spinX: 0), 0.06, "无塞：目标球应真实抵达袋口")
        XCTAssertLessThan(simulatedObjectMinDistToPocket(spinX: 0.6), 0.06, "强侧塞：squirt+swerve 补偿后目标球仍应真实抵达袋口")
    }

    /// 近距离小角度切向角袋：必须能进（验证 jaw 几何 + 进袋判定）。
    func test_predictor_easyCornerPot() {
        let surfaceY: Float = BTTablePhysics.surfaceY
        // 目标球靠近右上角袋(index 1, ≈(1.30,-0.665))，母球在其后方小角度。
        let target = SCNVector3(0.95, surfaceY + R, -0.42)
        let cue = SCNVector3(0.35, surfaceY + R, -0.18)
        let input = ShotInput(
            cueBall: cue, targetBall: target,
            pocketIndex: 1, velocity: StrokePhysics.SpeedLevel.mediumHard.velocity, spinX: 0, spinY: 0,
            surfaceY: surfaceY
        )
        let pred = ShotPredictor.predict(input)
        XCTAssertTrue(pred.feasible)
        XCTAssertTrue(pred.objectPocketed, "近距离小角度切角袋应能进")
    }

    /// 默认开箱球形（与 ViewModel.placeBallsAtDefaults 一致）应能进自动选中的袋。
    func test_predictor_defaultLayoutPots() {
        let surfaceY: Float = BTTablePhysics.surfaceY
        let cue = SCNVector3(-0.35, surfaceY + R, 0.22)
        let target = SCNVector3(0.55, surfaceY + R, -0.18)
        // 复制 selectBestPocket：取可行且切球角最小的袋。
        var best = 0
        var bestAngle = Double.greatestFiniteMagnitude
        for i in 0..<AngleSceneCalculator.pocketPositions(surfaceY: surfaceY).count {
            let aim = AngleSceneCalculator.effectivePocketAimPoint(
                targetBall: target, pocketIndex: i, surfaceY: surfaceY
            )
            guard AngleSceneCalculator.isFeasible(cueBall: cue, targetBall: target, pocket: aim) else { continue }
            let angle = AngleSceneCalculator.cutAngle(cueBall: cue, targetBall: target, pocket: aim)
            if angle < bestAngle { bestAngle = angle; best = i }
        }
        let input = ShotInput(
            cueBall: cue, targetBall: target,
            pocketIndex: best, velocity: StrokePhysics.SpeedLevel.medium.velocity, spinX: 0, spinY: 0,
            surfaceY: surfaceY
        )
        let pred = ShotPredictor.predict(input)
        XCTAssertTrue(pred.feasible)
        XCTAssertTrue(pred.objectPocketed, "默认球形应开箱即可进球（选中袋 index=\(best)）")
    }

    // MARK: - 完整进球点算法（P10 物理保真：中袋+角袋、多力度、画面=物理）

    /// 中袋（下中 idx5）正面直球：闭环求解 + 真实模拟在所有常用力度下都应进袋。
    /// 守护「完整进球点算法覆盖中袋」（用户明确关注中袋/底袋）。
    func test_predictor_middlePocket_potsAcrossSpeeds() {
        let sY = BTTablePhysics.surfaceY
        let target = SCNVector3(0, sY + R, 0.30)
        let cue = SCNVector3(0, sY + R, -0.20)
        for v in [Float(1.6), 2.4, 3.3, 4.4, 5.8] {
            let pred = ShotPredictor.predict(ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: 5,
                velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
            XCTAssertTrue(pred.feasible, "中袋直球应可行 v=\(v)")
            XCTAssertTrue(pred.objectPocketed, "中袋直球真实模拟应进袋 v=\(v)")
        }
    }

    /// 角袋近直球（cut≈8°）跨力度稳健进袋（求解器不应落入坏局部最优 / scratch）。
    func test_predictor_cornerNearStraight_potsAcrossSpeeds() {
        let sY = BTTablePhysics.surfaceY
        let target = SCNVector3(0.6, sY + R, -0.20)
        let cue = SCNVector3(0.25, sY + R, 0.10)
        for v in [Float(2.4), 3.3, 4.4, 5.8] {
            let pred = ShotPredictor.predict(ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: 1,
                velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
            XCTAssertTrue(pred.feasible, "角袋近直应可行 v=\(v)")
            XCTAssertFalse(pred.cuePocketed, "角袋近直不应刮母球 v=\(v)")
            XCTAssertTrue(pred.objectPocketed, "角袋近直真实模拟应进袋 v=\(v)")
        }
    }

    /// 画面=物理：进袋时目标球**显示轨迹**末端应抵达选定袋（进捕获窗内），
    /// 即所画橙线确实走到袋口，而非旧版的固定理想直线。
    func test_predictor_objectPath_reachesPocketWhenPotted() {
        let sY = BTTablePhysics.surfaceY
        let target = SCNVector3(0, sY + R, 0.30)
        let cue = SCNVector3(0, sY + R, -0.20)
        let pred = ShotPredictor.predict(ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: 5,
            velocity: 3.3, spinX: 0, spinY: 0, surfaceY: sY))
        XCTAssertTrue(pred.objectPocketed)
        XCTAssertGreaterThan(pred.objectPath.count, 1, "目标球轨迹应为真实折线")
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[5]
        guard let last = pred.objectPath.last else { return XCTFail("无目标球轨迹") }
        let d = sqrtf((last.x - pocket.x) * (last.x - pocket.x) + (last.z - pocket.z) * (last.z - pocket.z))
        let window = AngleSceneCalculator.pocketDropRadius(index: 5) - R + 0.006
        XCTAssertLessThanOrEqual(d, window, "进袋时目标球显示轨迹应抵达袋口（实测末端距袋心 \(d * 1000)mm）")
    }

    // MARK: - Helpers

    private func horizontalDir(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrtf(v.x * v.x + v.z * v.z)
        guard len > 1e-5 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(v.x / len, 0, v.z / len)
    }
}
