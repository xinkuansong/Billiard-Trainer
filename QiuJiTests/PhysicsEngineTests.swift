import XCTest
import SceneKit
@testable import QiuJi

/// 物理引擎正确性测试——以 pooltool 物理与经典台球定律（90° 法则、滚动条件、
/// squirt 方向）为基准，回归保护移植后的引擎。
final class PhysicsEngineTests: XCTestCase {

    private let R = BallPhysics.radius

    /// H02 constrained-table baseline, not a calibrated elevated strike/flight model.
    /// Reflection, dissipation and rolling contact are independent invariants.
    func testMasseConstrainedMotionSymmetryDissipationAndRollingBoundary() {
        let origin = SCNVector3(0, BTTablePhysics.surfaceY + R, 0)
        let inertia = 0.4 * BallPhysics.mass * R * R
        func energy(_ v: SCNVector3, _ w: SCNVector3) -> Float {
            0.5 * BallPhysics.mass * v.dot(v) + 0.5 * inertia * w.dot(w)
        }
        var cases = 0
        for degrees: Float in [0, 0.01, 30, 60] {
            for speed: Float in [0.6, 1.2, 2] {
                for vertical: Float in [-0.4, 0, 0.4] {
                    for side: Float in [0, 0.5] {
                        let theta = degrees * .pi / 180
                        let hit = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0),
                            velocity: speed, spinX: side, spinY: vertical, elevation: theta)
                        let mirror = CueBallStrike.executeStrike(aimDirection: SCNVector3(1, 0, 0),
                            velocity: speed, spinX: -side, spinY: vertical, elevation: theta)
                        let duration = AnalyticalMotion.slideToRollTime(velocity: hit.velocity,
                            angularVelocity: hit.angularVelocity)
                        XCTAssertTrue(duration.isFinite && duration >= 0)
                        if duration == 0 {
                            // Pure rolling may be present at impact (e.g. b=0.4, level cue).
                            let contact = hit.velocity + hit.angularVelocity.cross(SCNVector3(0, -R, 0))
                            XCTAssertLessThanOrEqual(contact.length(), 0.0001)
                        }
                        var previousEnergy = energy(hit.velocity, hit.angularVelocity)
                        for fraction: Float in [0, 0.25, 0.5, 0.75, 1] {
                            let state = AnalyticalMotion.evolveSliding(position: origin,
                                velocity: hit.velocity, angularVelocity: hit.angularVelocity,
                                dt: duration * fraction)
                            let reflected = AnalyticalMotion.evolveSliding(position: origin,
                                velocity: mirror.velocity, angularVelocity: mirror.angularVelocity,
                                dt: duration * fraction)
                            XCTAssertEqual(state.position.y, origin.y)
                            XCTAssertEqual(state.position.x, reflected.position.x, accuracy: 0.00001)
                            XCTAssertEqual(state.position.z, -reflected.position.z, accuracy: 0.00001)
                            let currentEnergy = energy(state.velocity, state.angularVelocity)
                            XCTAssertLessThanOrEqual(currentEnergy, previousEnergy + 0.000001)
                            previousEnergy = currentEnergy
                            if side == 0 { XCTAssertEqual(state.position.z, 0, accuracy: 0.00001) }
                            if fraction == 1 {
                                let turn = atan2f(state.velocity.z, state.velocity.x)
                                    - atan2f(hit.velocity.z, hit.velocity.x)
                                if side != 0 && degrees >= 30 {
                                    XCTAssertGreaterThan(abs(turn), 0.001)
                                }
                                print("[H02 sample] elevation=\(degrees) speed=\(speed) b=\(vertical) a=\(side) sliding=\(duration) turn=\(turn) end=(\(state.position.x),\(state.position.z))")
                                let slip = AnalyticalMotion.surfaceVelocity(linear: state.velocity,
                                    angular: state.angularVelocity, radius: R)
                                XCTAssertLessThan(slip.length(), 0.00001)
                                let rolled = AnalyticalMotion.evolveRolling(position: state.position,
                                    velocity: state.velocity, angularVelocity: state.angularVelocity, dt: 0)
                                XCTAssertLessThan((rolled.angularVelocity - state.angularVelocity).length(), 0.001)
                            }
                        }
                        cases += 1
                    }
                }
            }
        }
        XCTAssertEqual(cases, 72)
        print("[H02 constrained motion] \(cases) inputs, five samples each; mirror/dissipation/rolling boundary")
    }

    func test_circularCushionReachBoundMatchesOriginalRoots() {
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY)
        var compared = 0, hits = 0
        for arc in geometry.circularCushions {
            for angle: Float in [0, 0.7, 1.6, 2.8, 4.2, 5.5] {
                for gap: Float in [0.00001, 0.002, 0.04, 0.5] {
                    let radial = arc.radius + R + gap
                    let p = SCNVector3(arc.center.x + radial * cosf(angle), BTTablePhysics.surfaceY + R,
                                       arc.center.z + radial * sinf(angle))
                    for speed: Float in [-3, -0.2, 0, 0.2, 3] {
                        let v = SCNVector3(speed * cosf(angle), 0, speed * sinf(angle))
                        for acceleration: Float in [-2, 0, 2] {
                            let a = SCNVector3(acceleration * cosf(angle), 0, acceleration * sinf(angle))
                            for horizon in [0.00001, 0.0025, 0.05, 0.5] {
                                let original = CollisionDetector.ballCircularCushionTime(p: p, v: v, a: a,
                                    arc: arc, R: R, maxTime: horizon, useReachBound: false)
                                let bounded = CollisionDetector.ballCircularCushionTime(p: p, v: v, a: a,
                                    arc: arc, R: R, maxTime: horizon)
                                XCTAssertEqual(bounded, original, "angle=\(angle) gap=\(gap) v=\(speed) a=\(acceleration) h=\(horizon)")
                                compared += 1
                                if original != nil { hits += 1 }
                            }
                        }
                    }
                }
            }
        }
        XCTAssertGreaterThan(hits, 0)
        print("[W07 arc reach] comparisons=\(compared) hits=\(hits)")
    }

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

    /// 打点盘按真实皮头/母球比例 + 0.5R 打滑极限：满塞（=打滑极限）squirt 应落在真实区间(~0.5°–5°)，
    /// 而非旧版允许 a=1.0（球边缘，物理打不出）时的偏大角。守护参数与「真实加塞」的一致性。
    func test_miscueLimit_maxEnglishSquirtIsRealistic() {
        XCTAssertEqual(CuePhysics.miscueLimitFraction, 0.5, accuracy: 1e-6, "打滑极限应为 0.5R")
        XCTAssertEqual(CuePhysics.tipDiameter, 0.011, accuracy: 1e-6, "皮头直径应为 11mm")
        let maxA = CuePhysics.miscueLimitFraction
        let squirtDeg = abs(CueBallStrike.squirtAngle(a: maxA)) * 180 / .pi
        XCTAssertGreaterThan(squirtDeg, 0.5, "满塞 squirt 不应过小")
        XCTAssertLessThan(squirtDeg, 5.0, "满塞 squirt 应落在真实区间(<5°)")
    }

    /// 皮头球冠曲率把接触点拉向球心（contact = placement × R/(R+ρ) < placement）。
    func test_tipCurvature_pullFactorLessThanOne() {
        let R = BallPhysics.radius, rho = CuePhysics.tipCurvatureRadius
        XCTAssertEqual(CuePhysics.tipContactPullFactor, R / (R + rho), accuracy: 1e-6)
        XCTAssertGreaterThan(CuePhysics.tipContactPullFactor, 0.6)
        XCTAssertLessThan(CuePhysics.tipContactPullFactor, 1.0, "曲率应把接触点拉向球心")
    }

    /// 打滑极限钳制：超限的接触点偏移按方向等比钳回 0.5R，方向不变；未超限不动。
    func test_clampToMiscueLimit_boundsMagnitudeKeepsDirection() {
        let (cx, cy) = ShotIntent.clampToMiscueLimit(0.5, 0.5)   // mag 0.707 > 0.5
        XCTAssertEqual((cx * cx + cy * cy).squareRoot(), 0.5, accuracy: 1e-5, "幅值应钳到 0.5R")
        XCTAssertEqual(cx, cy, accuracy: 1e-6, "方向(45°)应保持")
        let (dx, dy) = ShotIntent.clampToMiscueLimit(0.2, -0.1) // mag 0.224 < 0.5
        XCTAssertEqual(dx, 0.2, accuracy: 1e-6)
        XCTAssertEqual(dy, -0.1, accuracy: 1e-6)
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
        print("[W07 side-spin final] termination=\(String(describing: pred.termination)) pot=\(pred.objectPocketed) events=\(pred.events)")
        XCTAssertTrue(pred.hasFinalTableState, "Selected prediction must finish even if an exploratory aim candidate fails")
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

    /// ShotSimulationView still uses this two-ball layout, at default speed 1.5.
    /// This legacy 3.3-speed assertion remains; the test below covers bare VM defaults.
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
        if !pred.objectPocketed {
            print("[W07 default] termination=\(String(describing: pred.termination)) aim=\(pred.aimDirection) pocketAim=\(pred.pocketAimPoint) events=\(pred.events)")
            let frames = pred.recorder?.framesByBallName[ShotInput.targetBallName] ?? []
            for (index, frame) in frames.enumerated() where index == 0 || index == frames.count - 1 || frame.position.x > 1.15 {
                print("[W07 default frame] t=\(frame.time) p=\(frame.position) v=\(frame.velocity) state=\(frame.state)")
            }
        }
    }

    // MARK: - 走位编排器：多球障碍单杆求解（ADR-P11-01）

    @MainActor
    func test_currentPositionPlayDefaultsProduceResolvedPot() async throws {
        let vm = PositionPlayViewModel()
        vm.setupScene()
        let initial = vm.currentSnapshot()
        let deadline = Date().addingTimeInterval(15)
        while (vm.isComputing || vm.solvedShot == nil), Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertFalse(vm.isComputing)
        let solved = try XCTUnwrap(vm.solvedShot)
        XCTAssertEqual(vm.velocity, ShotTuning.defaultVelocity)
        XCTAssertEqual(Set(initial.onTable.keys), Set(solved.before.onTable.keys))
        for (key, point) in initial.onTable {
            XCTAssertEqual(solved.before.onTable[key]?.x, point.x)
            XCTAssertEqual(solved.before.onTable[key]?.y, point.y)
        }
        XCTAssertTrue(solved.prediction.hasFinalTableState)
        XCTAssertTrue(solved.prediction.objectPocketed)
        let boundaries = try PocketGeometryAsset.load().captureBoundaries()
        for capture in try XCTUnwrap(solved.prediction.recorder).confirmedCaptures {
            let boundary = try XCTUnwrap(boundaries[capture.pocketID])
            XCTAssertLessThanOrEqual(capture.state.position.y, boundary.centerPlaneY + 1e-12)
        }
        print("[W07 current defaults] velocity=\(vm.velocity) board=\(initial) shot=\(solved.shot) termination=\(String(describing: solved.prediction.termination)) pot=\(solved.prediction.objectPocketed)")
    }

    /// Diagnostic comparison for FL-070. Does not redefine the default-pot contract above.
    func test_middlePocketFirstReboundSurfaceEvidence() throws {
        let y = BTTablePhysics.surfaceY
        // Spatial evidence test: opts into the presentation solver explicitly (W17-A).
        let prediction = ShotPredictor.predict(ShotInput(simulationModel: .spatialPockets,
            cueBall: SCNVector3(0, y + R, -0.2),
            targetBall: SCNVector3(0, y + R, 0.3), pocketIndex: 5,
            velocity: 3.3, spinX: 0, spinY: 0, surfaceY: y))
        let handoff = try XCTUnwrap(prediction.recorder?.localHandoffs.first {
            $0.ballName == ShotInput.targetBallName && $0.kind == .entered
        })
        let asset = try PocketGeometryAsset.load()
        let solver = try asset.localSimulation(material: .tablePhysics(clothRestitution: 0.3), ballMaterial: .ballPhysics)
        let result = try solver.run(from: handoff.state, duration: 0.1, maxStep: 0.0025)
        XCTAssertEqual(try XCTUnwrap(result.states.last).time, handoff.state.time + 0.1, accuracy: 1e-12)
        let collisions = result.contacts.filter { abs($0.normal.z) > 0.5 }
        XCTAssertFalse(collisions.isEmpty)
        for contact in collisions.prefix(8) {
            let patch = asset.tablePatches[contact.surface]
            print("[W07 middle surface] contact=\(contact) material=\(patch.material) triangle=\(patch.triangle)")
        }
    }

    func test_defaultPocketLeatherResponseSensitivity() throws {
        let y = BTTablePhysics.surfaceY
        // Spatial liner sweep: opts into the presentation solver explicitly (W17-A).
        let input = ShotInput(simulationModel: .spatialPockets,
            cueBall: SCNVector3(-0.35, y + R, 0.22),
            targetBall: SCNVector3(0.55, y + R, -0.18), pocketIndex: 1,
            velocity: 3.3, spinX: 0, spinY: 0, surfaceY: y)
        let prediction = ShotPredictor.predict(input)
        let handoff = try XCTUnwrap(prediction.recorder?.localHandoffs.first {
            $0.ballName == ShotInput.targetBallName && $0.kind == .entered
        })
        let asset = try PocketGeometryAsset.load()
        let roles = try asset.surfaceRoles()
        let baseline = try asset.contactSurfaces(material: .tablePhysics(clothRestitution: 0.3))
        // Rigid e×mu sweep (leather-sweep-r1, 2026-09-14): mu 0.2–2 × e 0–0.45 all returned to
        // the table, mu>=0.5 identical. The liner's tangential retention is the remaining lever.
        let retentions = [1.0, 0.6, 0.4, 0.2, 0.0]
        let restitutions = [0.0, Double(TablePhysics.pocketThroatRestitution)]
        for (retention, restitution) in retentions.flatMap { r in restitutions.map { (r, $0) } } {
            let surfaces = baseline.enumerated().map { index, surface in
                LocalPocketSimulation.Surface(triangle: surface.triangle,
                    restitution: roles[index] == .leather ? restitution : surface.restitution,
                    friction: surface.friction,
                    rollingFriction: surface.rollingFriction, spinFriction: surface.spinFriction,
                    tangentialRetention: roles[index] == .leather ? retention : surface.tangentialRetention)
            }
            let solver = LocalPocketSimulation(surfaces: surfaces, radius: Double(R),
                gravity: SIMD3(0, -Double(TablePhysics.gravity), 0), tolerance: 1e-6,
                ballMaterial: .ballPhysics)
            let result = try solver.run(from: handoff.state, duration: 0.2, maxStep: 0.0025)
            let last = try XCTUnwrap(result.states.last)
            let leatherContacts = result.contacts.filter { roles[$0.surface] == .leather }
            print(String(format: "[W07 liner sweep] retention=%.2f e=%.2f finalPos=(%.4f,%.4f,%.4f) finalV=(%.3f,%.3f,%.3f)|%.3f minY=%.4f leatherContacts=%d totalContacts=%d",
                retention, restitution, last.position.x, last.position.y, last.position.z,
                last.velocity.x, last.velocity.y, last.velocity.z, simd_length(last.velocity),
                result.states.map { $0.position.y }.min()!, leatherContacts.count, result.contacts.count))
            // Contact-by-contact evidence for the rigid baseline only: which role turned the
            // ball around, and what the velocity looked like immediately before/after (FL-070).
            guard retention == 1 else { XCTAssertEqual(last.time, handoff.state.time + 0.2, accuracy: 1e-12); continue }
            for contact in result.contacts.prefix(40) {
                let before = result.states.last { $0.time <= contact.time - 1e-9 }
                let after = result.states.first { $0.time >= contact.time + 1e-9 }
                let vb = before?.velocity ?? .zero, va = after?.velocity ?? .zero
                print(String(format: "[W07 leather contact] e=%.2f t=%.6f role=%@ n=(%.3f,%.3f,%.3f) vBefore=(%.3f,%.3f,%.3f)|%.3f vAfter=(%.3f,%.3f,%.3f)|%.3f y=%.4f",
                    restitution, contact.time, String(describing: roles[contact.surface]),
                    contact.normal.x, contact.normal.y, contact.normal.z,
                    vb.x, vb.y, vb.z, simd_length(vb), va.x, va.y, va.z, simd_length(va),
                    after?.position.y ?? .nan))
            }
            XCTAssertEqual(last.time, handoff.state.time + 0.2, accuracy: 1e-12)
        }
    }

    func test_defaultPocketAimGeometryComparison() {
        let y = BTTablePhysics.surfaceY
        for speed: Float in [2.4, 3.3] {
            for (label, point) in [("pipe", Optional<SCNVector3>.none),
                ("nominal", AngleSceneCalculator.pocketPositions(surfaceY: y)[1]),
                ("marker", AngleSceneCalculator.pocketMarkerPositions(surfaceY: y)[1])] {
                let input = ShotInput(cueBall: SCNVector3(-0.35, y + R, 0.22),
                    targetBall: SCNVector3(0.55, y + R, -0.18), pocketIndex: 1,
                    velocity: speed, spinX: 0, spinY: 0, surfaceY: y, pocketAimOverride: point)
                let prediction = ShotPredictor.predict(input)
                print("[W07 aim geometry] speed=\(speed) source=\(label) point=\(prediction.pocketAimPoint) pot=\(prediction.objectPocketed) termination=\(String(describing: prediction.termination)) events=\(prediction.events)")
                XCTAssertEqual(prediction.termination, .settled)
            }
        }
    }

    func test_pocketCaptureRejectsFalseQuadraticRootAbovePlane() throws {
        let boundaries = try PocketGeometryAsset.load().captureBoundaries()
        let boundary = try XCTUnwrap(boundaries["pocket_5"])
        let center = boundary.outline.reduce(SIMD2<Double>.zero, +) / Double(boundary.outline.count)
        let start = LocalPocketSimulation.State(time: 0,
            position: SIMD3(center.x, boundary.centerPlaneY + 0.1, center.y),
            velocity: .zero, omega: .zero)
        let acceleration = SIMD3<Double>(0, -4e-12, 0)
        let span = LocalPocketSimulation.Interval(start: start, duration: 0.0025,
            acceleration: acceleration, angularAcceleration: .zero,
            end: .init(time: 0.0025, position: start.position + acceleration * (0.5 * 0.0025 * 0.0025),
                       velocity: acceleration * 0.0025, omega: .zero))
        XCTAssertNil(boundary.firstCandidate(in: span), "A numerical root cannot capture a ball 10cm above the collection plane")
        for drop in [1e-10, 0.01, 0.1] {
            for duration in [0.0025, 0.2] {
                var falling = start
                falling.position.y = boundary.centerPlaneY + drop
                let distance = falling.position.y - boundary.centerPlaneY
                // Crossing occurs halfway through the interval, under gravity
                // or at constant vertical speed. Keep tiny distances meaningful.
                for accelerated in [false, true] {
                    falling.velocity.y = accelerated ? 0 : -2 * distance / duration
                    let acceleration = SIMD3<Double>(0, accelerated ? -8 * distance / (duration * duration) : 0, 0)
                    let end = LocalPocketSimulation.State(time: duration,
                        position: falling.position + falling.velocity * duration + acceleration * (0.5 * duration * duration),
                        velocity: falling.velocity + acceleration * duration, omega: .zero)
                    let candidate = try XCTUnwrap(boundary.firstCandidate(in: .init(start: falling, duration: duration,
                        acceleration: acceleration, angularAcceleration: .zero, end: end)))
                    XCTAssertEqual(candidate.time, duration / 2, accuracy: 1e-12)
                    XCTAssertEqual(candidate.position.y, boundary.centerPlaneY, accuracy: 1e-14)
                }
            }
        }
    }

    /// Diagnostic comparison for FL-070. Does not redefine the default-pot contract above.
    func test_defaultLayoutPocketModelSpeedComparison() throws {
        let surfaceY = BTTablePhysics.surfaceY
        let asset = try PocketGeometryAsset.load()
        let roles = try asset.surfaceRoles()
        for speed: Float in [0.8, 1.2, 1.6, 2.4, 3.3] {
            for model: EventDrivenEngine.SimulationModel in [.planarReference, .spatialPockets] {
                let input = ShotInput(simulationModel: model,
                    cueBall: SCNVector3(-0.35, surfaceY + R, 0.22),
                    targetBall: SCNVector3(0.55, surfaceY + R, -0.18),
                    pocketIndex: 1, velocity: speed, spinX: 0, spinY: 0, surfaceY: surfaceY)
                let prediction = ShotPredictor.predict(input)
                let frames = prediction.recorder?.framesByBallName[ShotInput.targetBallName] ?? []
                let entry = frames.first { $0.position.x > 1.25 }
                print("[W07 speed comparison] speed=\(speed) model=\(model) pot=\(prediction.objectPocketed) termination=\(String(describing: prediction.termination)) aim=\(prediction.aimDirection) entry=\(String(describing: entry)) events=\(prediction.events)")
                if speed == 3.3 {
                    let contacts = prediction.recorder?.localStaticContacts.filter {
                        $0.ballName == ShotInput.targetBallName && $0.contact.time < 0.45
                    } ?? []
                    for recorded in contacts {
                        let contact = recorded.contact
                        print("[W07 default contact] time=\(contact.time) surface=\(contact.surface) role=\(roles[contact.surface]) normal=\(contact.normal) triangle=\(asset.tablePatches[contact.surface].triangle)")
                    }
                }
                XCTAssertEqual(prediction.termination, .settled)
            }
        }
    }

    /// 远离瞄准线的障碍球不应影响进袋；`finalPositions` 含全场球末位、`pocketedBalls` 含目标球。
    func test_predictor_obstacleAwayFromLine_stillPots() {
        let sY = BTTablePhysics.surfaceY
        let target = SCNVector3(0.95, sY + R, -0.42)
        let cue = SCNVector3(0.35, sY + R, -0.18)
        // 障碍球摆在对角远处，完全不挡瞄准线/进球线。
        let obstacle = SCNVector3(-0.9, sY + R, 0.40)
        let input = ShotInput(
            cueBall: cue, targetBall: target,
            pocketIndex: 1, velocity: StrokePhysics.SpeedLevel.mediumHard.velocity,
            spinX: 0, spinY: 0, surfaceY: sY,
            obstacles: [ObstacleBall(name: "_3", position: obstacle)]
        )
        let pred = ShotPredictor.predict(input)
        XCTAssertTrue(pred.feasible, "远处障碍不应使其不可行")
        XCTAssertTrue(pred.objectPocketed, "远处障碍不应阻止进袋")
        XCTAssertNotNil(pred.finalPositions[ShotInput.cueBallName], "应回报母球末位")
        XCTAssertNotNil(pred.finalPositions["_3"], "应回报障碍球末位")
        XCTAssertTrue(pred.pocketedBalls.contains(ShotInput.targetBallName), "目标球应在进袋列表")
        // 远处未被碰的障碍球应基本保持原位。
        if let p = pred.finalPositions["_3"] {
            XCTAssertLessThan(AngleSceneCalculator.horizontalDistance(p, obstacle), 0.02,
                              "未被碰的障碍球应保持原位")
        }
    }

    /// 障碍球正挡在目标球→袋口的进球线上时，目标球进不了选定袋（遮挡天然涌现）。
    func test_predictor_obstacleBlockingPocketLine_preventsPot() {
        let sY = BTTablePhysics.surfaceY
        let target = SCNVector3(0, sY + R, 0.30)
        let cue = SCNVector3(0, sY + R, -0.20)
        let pocket = AngleSceneCalculator.pocketPositions(surfaceY: sY)[5]  // 下中
        // 障碍球贴在目标球与下中袋之间，挡住进球线。
        let blockZ = (target.z + pocket.z) / 2
        let blocker = SCNVector3(0, sY + R, blockZ)
        let input = ShotInput(
            cueBall: cue, targetBall: target,
            pocketIndex: 5, velocity: StrokePhysics.SpeedLevel.medium.velocity,
            spinX: 0, spinY: 0, surfaceY: sY,
            obstacles: [ObstacleBall(name: "_7", position: blocker)]
        )
        let pred = ShotPredictor.predict(input)
        XCTAssertFalse(pred.objectPocketed, "进球线被障碍球挡住，目标球不应进选定袋")
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
            if !pred.objectPocketed {
                print("[W07 middle] speed=\(v) termination=\(String(describing: pred.termination)) aim=\(pred.aimDirection) pocketAim=\(pred.pocketAimPoint) events=\(pred.events)")
                for handoff in pred.recorder?.localHandoffs ?? [] where handoff.ballName == ShotInput.targetBallName {
                    print("[W07 middle handoff] speed=\(v) \(handoff)")
                }
                for frame in pred.recorder?.framesByBallName[ShotInput.targetBallName] ?? [] where frame.position.z > 0.56 {
                    print("[W07 middle frame] speed=\(v) t=\(frame.time) p=\(frame.position) v=\(frame.velocity)")
                }
            }
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
        // 2026-09-14（内衬耗能模型）：球心在洞口轮廓内即算抵达袋口。旧窗口 `dropRadius - R + 6mm`
        // 是平面捕获圈语义；空间模型里 4.7m/s 的球飞越洞心仅下沉 1mm，贴到后壁内衬（z≈0.735-R）
        // 才停下落洞，末端距袋心约 30mm，与实物大力进袋在后壁消失一致。断言目的不变：
        // 橙线要真的走到袋口，而不是旧版停在半路的理想直线。
        let window = AngleSceneCalculator.pocketDropRadius(index: 5)
        print("[W07 path endpoint] last=\(last) captures=\(String(describing: pred.recorder?.confirmedCaptures)) tails=\(String(describing: pred.recorder?.collectionTailsByBallName))")
        XCTAssertLessThanOrEqual(d, window, "进袋时目标球显示轨迹应抵达袋口（实测末端距袋心 \(d * 1000)mm）")
    }

    /// 角袋中等切角（≈15°）在**所有**常用力度下都应进袋——守护 P10 漏斗模型 v3 修复的
    /// 「非单调进袋闪烁」（旧版同一球形改个力度就在进/不进间跳变，根因：求解短模拟与上报
    /// 全模拟进袋带错位 + 喉腔弹珠箱致进袋带碎裂 + 缓行入袋被显示截断）。
    /// 注：允许母球刮袋（近直球中心球物理必然），仅断言目标球真实进袋。
    func test_predictor_cornerModerateCut_potsAcrossSpeedsConsistently() {
        let sY = BTTablePhysics.surfaceY
        let target = SCNVector3(0.55, sY + R, -0.10)
        let pocketIndex = 1
        // 由切角 15° 反推母球位置（与求解页一致的几何）。
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket, ballRadius: R)
        let pdx = pocket.x - target.x, pdz = pocket.z - target.z
        let pl = sqrtf(pdx * pdx + pdz * pdz)
        let pd = SCNVector3(pdx / pl, 0, pdz / pl)
        let th: Float = 15 * .pi / 180
        let strikeDir = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0, pd.x * sinf(th) + pd.z * cosf(th))
        let cue = SCNVector3(ghost.x - strikeDir.x * 0.4, sY + R, ghost.z - strikeDir.z * 0.4)

        for v in [Float(2.4), 3.3, 4.4, 5.8] {
            let pred = ShotPredictor.predict(ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                velocity: v, spinX: 0, spinY: 0, surfaceY: sY))
            XCTAssertTrue(pred.feasible, "角袋 cut15 v\(v) 应可行")
            XCTAssertTrue(pred.objectPocketed, "角袋 cut15 v\(v) 目标球应真实进袋（非单调闪烁回归）")
            // 画面=物理：进袋时显示轨迹末端应抵达袋口。
            if pred.objectPocketed, let last = pred.objectPath.last {
                let pc = AngleSceneCalculator.pocketPositions(surfaceY: sY)[pocketIndex]
                let d = sqrtf((last.x - pc.x) * (last.x - pc.x) + (last.z - pc.z) * (last.z - pc.z))
                XCTAssertLessThanOrEqual(d, AngleSceneCalculator.pocketDropRadius(index: pocketIndex),
                                         "进袋时目标球显示轨迹末端应在落袋孔内 v\(v)")
            }
        }
    }

    /// 大切角清晰球（中台→角袋，无遮挡）应直接进袋——守护「大角度不该退化成多库翻袋」。
    /// 用户洞察：目标球进袋路线恒为 target→pocket 直线，大切角只是动量小，理应（足够力度时）
    /// 直接进、绝不变 banking。左右两角袋都测，兼顾镜像对称。
    func test_predictor_largeCutClearShot_directPotBothCorners() {
        let sY = BTTablePhysics.surfaceY
        let target = SCNVector3(0.0, sY + R, 0.0)   // 台面中心，到任一角袋都无遮挡
        for pocketIndex in [0, 1] {                  // 左上 / 右上
            let pocket = AngleSceneCalculator.effectivePocketAimPoint(targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
            let ghost = AngleSceneCalculator.ghostBallPosition(targetBall: target, pocket: pocket, ballRadius: R)
            let pdx = pocket.x - target.x, pdz = pocket.z - target.z
            let pl = sqrtf(pdx * pdx + pdz * pdz)
            let pd = SCNVector3(pdx / pl, 0, pdz / pl)
            for cutDeg in [Float(30), 45, 55, 65] {
                let th = cutDeg * .pi / 180
                let strikeDir = SCNVector3(pd.x * cosf(th) - pd.z * sinf(th), 0, pd.x * sinf(th) + pd.z * cosf(th))
                let cue = SCNVector3(ghost.x - strikeDir.x * 0.45, sY + R, ghost.z - strikeDir.z * 0.45)
                let pred = ShotPredictor.predict(ShotInput(
                    cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                    velocity: 3.3, spinX: 0, spinY: 0, surfaceY: sY))
                XCTAssertTrue(pred.feasible, "中台→袋\(pocketIndex) cut\(cutDeg)° 应可行")
                // 双吻豁免（ADR-P10-09 后合法物理）：大切角下母球保留 sin(cut)≈90% 速度，
                // 弹库折返可再次撞上慢速目标球（65°+v3.3 实测为真实双吻，v2.0 则直接进）。
                // 守护目标不变——「未进袋」只允许由双吻解释；单次接触后翻袋不进仍算回归。
                let ballBallContacts = pred.events.filter {
                    if case .ballBall = $0.kind { return true }; return false
                }.count
                XCTAssertTrue(pred.objectPocketed || ballBallContacts >= 2,
                              "中台→袋\(pocketIndex) cut\(cutDeg)° v3.3 应直接进袋（不退化为多库翻袋；双吻除外，实测接触\(ballBallContacts)次）")
            }
        }
    }

    // MARK: - 翻袋引擎反解（W1，20260709 翻袋反射页重构方案 §2）

    /// 对一组库序逐条反解，返回全部「引擎终验真进袋」的预测（W3 多解枚举的最小内核）。
    private func solveBankSequences(
        cue: SCNVector3, target: SCNVector3, pocketIndex: Int, velocity: Float,
        maxCushions: Int = 2, obstacles: [ObstacleBall] = []
    ) -> [(rails: [BankShotCalculator.Rail], pred: ShotPrediction)] {
        let sY = BTTablePhysics.surfaceY
        var out: [(rails: [BankShotCalculator.Rail], pred: ShotPrediction)] = []
        for rails in BankShotCalculator.candidateRailSequences(maxCushions: maxCushions) {
            let input = ShotInput(
                cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
                velocity: velocity, spinX: 0, spinY: 0, surfaceY: sY,
                obstacles: obstacles, bankRails: rails)
            let pred = ShotPredictor.predict(input)
            if pred.feasible, pred.simObjectPotted { out.append((rails, pred)) }
        }
        return out
    }

    /// 经典跨台翻袋盘面（目标球中台、翻长库进对侧袋）：1–2 库枚举中至少应有一条
    /// 引擎背书的真实进袋解；解必须满足「母球段直击（碰前 0 库）+ 目标球落袋前
    /// 吃库数 ≥ 库序数」的翻袋语义。
    func test_bankSolve_typicalBoard_findsEnginePottedSolution() {
        let sY = BTTablePhysics.surfaceY
        let cue = SCNVector3(-0.5, sY + R, -0.2)
        let target = SCNVector3(0.1, sY + R, 0.1)
        let solutions = solveBankSequences(
            cue: cue, target: target, pocketIndex: 1, velocity: 3.6)
        XCTAssertFalse(solutions.isEmpty, "典型盘面 1–2 库枚举应至少有一条引擎真进袋的翻袋解")
        for (rails, pred) in solutions {
            XCTAssertEqual(pred.cueCushionsBeforeContact, 0,
                           "翻袋解母球必须直击目标球（库序 \(rails.map(\.label))）")
            XCTAssertGreaterThanOrEqual(pred.objectCushionCount, rails.count,
                                        "目标球落袋前吃库数应 ≥ 指定库序数（库序 \(rails.map(\.label))）")
            XCTAssertNotNil(pred.aimOffsetUsed, "翻袋解应回填 aimOffsetUsed（B1 重建口径）")
            XCTAssertTrue(pred.objectPocketed, "画面=物理：objectPocketed 应与 simObjectPotted 一致")
        }
    }

    /// 兼容性：`bankRails` 默认 nil 时行为与旧直击管线逐位一致（同一盘面直击应照常进袋）。
    func test_bankRails_nilDefault_directShotUnchanged() {
        let sY = BTTablePhysics.surfaceY
        let target = SCNVector3(0.6, sY + R, 0.3)
        let pocketIndex = 3
        let pocket = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: pocketIndex, surfaceY: sY)
        let ghost = AngleSceneCalculator.ghostBallPosition(
            targetBall: target, pocket: pocket, ballRadius: R)
        let pd = horizontalDir(SCNVector3(pocket.x - target.x, 0, pocket.z - target.z))
        let cue = SCNVector3(ghost.x - pd.x * 0.5, sY + R, ghost.z - pd.z * 0.5)
        let input = ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: pocketIndex,
            velocity: 3.0, spinX: 0, spinY: 0, surfaceY: sY)
        XCTAssertNil(input.bankRails, "bankRails 默认必须为 nil（直击兼容）")
        let pred = ShotPredictor.predict(input)
        XCTAssertTrue(pred.feasible)
        XCTAssertTrue(pred.objectPocketed, "直球应照常进袋（bank 分支不得影响直击管线）")
        XCTAssertEqual(pred.objectCushionCount, 0, "直球目标球落袋前不应吃库")
    }

    /// 障碍球是真实碰撞体：把障碍球压在种子出发线上，引擎终验不得放行「穿球」假解。
    /// 若仍有解进袋，其事件流须包含目标球与该障碍的真实碰撞（物理诚实），
    /// 否则该库序自然淘汰（simObjectPotted=false）。
    func test_bankSolve_obstacleOnSeedLine_noGhostThroughSolution() {
        let sY = BTTablePhysics.surfaceY
        let cue = SCNVector3(-0.5, sY + R, -0.2)
        let target = SCNVector3(0.1, sY + R, 0.1)
        // 先取无障碍时的第一条解，把障碍球放在其目标球路径中点上。
        let clean = solveBankSequences(cue: cue, target: target, pocketIndex: 1, velocity: 3.6)
        guard let first = clean.first, first.pred.objectPath.count >= 2 else {
            XCTFail("前置：无障碍时应有翻袋解"); return
        }
        let path = first.pred.objectPath
        let mid = path[path.count / 2]
        let blocker = ObstacleBall(name: "_5", position: SCNVector3(mid.x, sY + R, mid.z))
        let input = ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: 1,
            velocity: 3.6, spinX: 0, spinY: 0, surfaceY: sY,
            obstacles: [blocker], bankRails: first.rails)
        let pred = ShotPredictor.predict(input)
        if pred.simObjectPotted {
            // 仍进袋只有两种诚实结局：(a) 求解器换了瞄准偏移、路径真实绕开障碍
            //（与障碍全程保持 ≥2R）；(b) 与障碍发生了真实碰撞事件后仍进。禁止穿球。
            let hitBlocker = pred.events.contains {
                if case let .ballBall(a, b) = $0.kind { return a == "_5" || b == "_5" }
                return false
            }
            if !hitBlocker {
                var minDist = Float.greatestFiniteMagnitude
                for path in [pred.objectPath, pred.cuePath] where path.count >= 2 {
                    for i in 0..<(path.count - 1) {
                        minDist = min(minDist, ShotPredictor.segmentPointDistanceXZ(
                            a: path[i], b: path[i + 1], p: blocker.position))
                    }
                }
                XCTAssertGreaterThanOrEqual(
                    minDist, 2 * R - 0.002,
                    "未碰障碍却进袋 ⇒ 路径必须真实绕开障碍（≥2R），禁止穿球假解")
            }
        }
        // 无论进否，画面=物理不变量恒成立。
        XCTAssertEqual(pred.objectPocketed, pred.simObjectPotted)
    }

    /// 力度是求解输入：同一可解库序把力度压到极低，目标球滚不到袋口 ⇒ 如实报未进袋
    /// （绝不回退几何解谎报可进）。
    func test_bankSolve_insufficientPower_honestlyNotPotted() {
        let sY = BTTablePhysics.surfaceY
        let cue = SCNVector3(-0.5, sY + R, -0.2)
        let target = SCNVector3(0.1, sY + R, 0.1)
        let clean = solveBankSequences(cue: cue, target: target, pocketIndex: 1, velocity: 3.6)
        guard let first = clean.first else { XCTFail("前置：应有翻袋解"); return }
        let input = ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: 1,
            velocity: 0.8, spinX: 0, spinY: 0, surfaceY: sY, bankRails: first.rails)
        let pred = ShotPredictor.predict(input)
        XCTAssertFalse(pred.simObjectPotted, "极低力度翻袋应如实报未进袋（力度是求解输入）")
        XCTAssertTrue(pred.feasible, "几何仍可行，只是力度不足——不可行原因不得混淆")
    }

    /// 无几何种子的库序（镜像展开解不出）：feasible=false + 原因，直接淘汰不进引擎。
    func test_bankSolve_noSeedSequence_infeasible() {
        let sY = BTTablePhysics.surfaceY
        // 目标球贴左长库，向左库（自身贴着的库）翻 1 库进左下角袋：首段几乎零长，无种子。
        let target = SCNVector3(-1.0, sY + R, -0.6)
        let input = ShotInput(
            cueBall: SCNVector3(0.5, sY + R, 0.3), targetBall: target, pocketIndex: 0,
            velocity: 3.0, spinX: 0, spinY: 0, surfaceY: sY,
            bankRails: [.left])
        let pred = ShotPredictor.predict(input)
        if !pred.feasible {
            XCTAssertFalse(pred.infeasibleReason.isEmpty, "不可行必须带原因")
        } else {
            // 若几何上竟有种子，则引擎终验裁决——两种结局都必须是引擎口径，无几何假解。
            XCTAssertEqual(pred.objectPocketed, pred.simObjectPotted, "画面=物理不变量")
        }
    }

    // MARK: - 反射/kick 引擎反解（W2，20260709 翻袋反射页重构方案 §2.1）

    /// 对一组库序 kick 反解（生产入口 `predictKickAll`，并行），
    /// 返回全部「引擎终验真实碰到目标球」的预测。
    private func solveKickSequences(
        cue: SCNVector3, target: SCNVector3, velocity: Float,
        maxCushions: Int = 2, obstacles: [ObstacleBall] = []
    ) -> [(rails: [DiamondSystemCalculator.Rail], pred: ShotPrediction)] {
        let sY = BTTablePhysics.surfaceY
        let input = ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: 0,
            velocity: velocity, spinX: 0, spinY: 0, surfaceY: sY,
            obstacles: obstacles)
        return ShotPredictor.predictKickAll(input, maxCushions: maxCushions)
            .map { ($0.rails, $0.prediction) }
    }

    /// 典型解球盘面（两球中台、无遮挡）：1–2 库枚举中至少应有一条引擎背书的
    /// 真实 kick 解；解必须满足「母球首碰 = 目标球 + 碰前吃库数 ≥ 库序数」。
    func test_kickSolve_typicalBoard_findsEngineContactSolution() {
        let sY = BTTablePhysics.surfaceY
        let cue = SCNVector3(-0.5, sY + R, -0.2)
        let target = SCNVector3(0.4, sY + R, 0.25)
        let solutions = solveKickSequences(cue: cue, target: target, velocity: 3.6)
        XCTAssertFalse(solutions.isEmpty, "典型盘面 1–2 库枚举应至少有一条引擎真实碰到的 kick 解")
        for (rails, pred) in solutions {
            let info = ShotPredictor.kickContactInfo(events: pred.events)
            XCTAssertTrue(info.contacted, "kick 解母球首碰必须是目标球（库序 \(rails.map(\.label))）")
            XCTAssertGreaterThanOrEqual(info.cushionsBefore, rails.count,
                                        "母球碰前吃库数应 ≥ 指定库序数（库序 \(rails.map(\.label))）")
            XCTAssertNotNil(pred.aimOffsetUsed, "kick 解应回填 aimOffsetUsed（B1 重建口径）")
        }
    }

    /// 兼容性：`kickRails` 默认 nil 时行为与旧直击管线逐位一致。
    func test_kickRails_nilDefault_directShotUnchanged() {
        let sY = BTTablePhysics.surfaceY
        let target = SCNVector3(0.6, sY + R, 0.3)
        let input = ShotInput(
            cueBall: SCNVector3(0.0, sY + R, 0.0), targetBall: target, pocketIndex: 3,
            velocity: 3.0, spinX: 0, spinY: 0, surfaceY: sY)
        XCTAssertNil(input.kickRails, "kickRails 默认必须为 nil（直击兼容）")
        let pred = ShotPredictor.predict(input)
        XCTAssertFalse(pred.kickContactMade, "直击管线恒不填充 kickContactMade")
        XCTAssertEqual(pred.objectPocketed, pred.simObjectPotted, "画面=物理不变量")
    }

    /// 障碍球是真实碰撞体：把障碍球压在母球种子路线上，引擎终验不得放行「穿球」假解。
    func test_kickSolve_obstacleOnSeedLine_noGhostThroughSolution() {
        let sY = BTTablePhysics.surfaceY
        let cue = SCNVector3(-0.5, sY + R, -0.2)
        let target = SCNVector3(0.4, sY + R, 0.25)
        let clean = solveKickSequences(cue: cue, target: target, velocity: 3.6)
        guard let first = clean.first, first.pred.cuePath.count >= 2 else {
            XCTFail("前置：无障碍时应有 kick 解"); return
        }
        // 障碍压在母球真实路径中点上。
        let path = first.pred.cuePath
        let mid = path[path.count / 2]
        let blocker = ObstacleBall(name: "_5", position: SCNVector3(mid.x, sY + R, mid.z))
        let input = ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: 0,
            velocity: 3.6, spinX: 0, spinY: 0, surfaceY: sY,
            obstacles: [blocker], kickRails: first.rails)
        let pred = ShotPredictor.predict(input)
        if pred.kickContactMade {
            // 仍成功只有两种诚实结局：(a) 求解器换了瞄准偏移、母球**碰目标球前**真实绕开
            // 障碍（首碰是目标球是判据本身）；(b) 碰到目标球**之后**与障碍发生了真实碰撞
            // 事件（障碍被撞开后母球可合法经过其原位置）。禁止无碰撞事件的穿球。
            let hitBlocker = pred.events.contains {
                if case let .ballBall(a, b) = $0.kind { return a == "_5" || b == "_5" }
                return false
            }
            if !hitBlocker {
                var minDist = Float.greatestFiniteMagnitude
                let cp = pred.cuePath
                for i in 0..<(cp.count - 1) {
                    minDist = min(minDist, ShotPredictor.segmentPointDistanceXZ(
                        a: cp[i], b: cp[i + 1], p: blocker.position))
                }
                XCTAssertGreaterThanOrEqual(
                    minDist, 2 * R - 0.002,
                    "未碰障碍却成功 ⇒ 母球路径必须真实绕开障碍（≥2R），禁止穿球假解")
            }
        }
    }

    /// 力度是求解输入：同一可解库序把力度压到极低，母球滚不到目标球 ⇒ 如实报未碰到
    /// （绝不回退几何解谎报可解）。
    func test_kickSolve_insufficientPower_honestlyNoContact() {
        let sY = BTTablePhysics.surfaceY
        let cue = SCNVector3(-0.5, sY + R, -0.2)
        let target = SCNVector3(0.4, sY + R, 0.25)
        let clean = solveKickSequences(cue: cue, target: target, velocity: 3.6)
        guard let first = clean.first else { XCTFail("前置：应有 kick 解"); return }
        let input = ShotInput(
            cueBall: cue, targetBall: target, pocketIndex: 0,
            velocity: 0.1, spinX: 0, spinY: 0, surfaceY: sY, kickRails: first.rails)
        let pred = ShotPredictor.predict(input)
        // Verify the insufficient-range premise independently on an empty table.
        // The previous 0.6 cue speed produces ~0.92 ball speed and can reach a rail
        // and the target; that input remains covered by the physical-witness test.
        let empty = ShotPredictor.simulateFree(cueBall: cue, aimDir: pred.aimDirection,
            velocity: input.velocity, spinX: 0, spinY: 0, surfaceY: sY, balls: [])
        XCTAssertTrue(empty.hasFinalTableState)
        XCTAssertFalse(empty.events.contains { if case .ballCushion = $0.kind { return true }; return false })
        let travel = empty.cuePath.map { hypotf($0.x-cue.x, $0.z-cue.z) }.max() ?? .infinity
        XCTAssertLessThan(travel, hypotf(target.x-cue.x,target.z-cue.z)-2*R,
                          "This fixture must stop before it could reach the object even without a rail")
        XCTAssertFalse(pred.kickContactMade, "极低力度 kick 应如实报未碰到（力度是求解输入）")
        XCTAssertTrue(pred.feasible, "几何仍可行，只是力度不足——不可行原因不得混淆")
    }
    func test_kickLowPowerContactHasPhysicalWitness() throws {
        let y = BTTablePhysics.surfaceY
        let input = ShotInput(cueBall: SCNVector3(-0.5,y+R,-0.2),
            targetBall: SCNVector3(0.4,y+R,0.25), pocketIndex: 0,
            velocity: 0.6, spinX: 0, spinY: 0, surfaceY: y, kickRails: [.right])
        let pred = ShotPredictor.predict(input)
        XCTAssertTrue(pred.hasFinalTableState)
        XCTAssertTrue(pred.kickContactMade)
        let event = try XCTUnwrap(pred.events.first { event in
            if case let .ballBall(a,b) = event.kind {
                return Set([a,b]) == Set([ShotInput.cueBallName,ShotInput.targetBallName])
            }
            return false
        })
        XCTAssertTrue(pred.events.contains { item in
            if case .ballCushion = item.kind { return item.time < event.time }; return false
        })
        let playback = TrajectoryPlayback(recorder: try XCTUnwrap(pred.recorder), surfaceY: y+R)
        let centers = playback.allBallCentersByName(at: event.time)
        let cue = try XCTUnwrap(centers[ShotInput.cueBallName])
        let object = try XCTUnwrap(centers[ShotInput.targetBallName])
        let d = cue-object
        XCTAssertEqual(sqrtf(d.x*d.x+d.y*d.y+d.z*d.z),2*R,accuracy:1e-5,
                       "A contact flag must have touching recorded spheres, not just a geometric aim")
        print("[W07 low-power physical witness] time=\(event.time) separation=\(sqrtf(d.x*d.x+d.y*d.y+d.z*d.z))")
    }


    /// 无几何种子的库序（镜像展开解不出）：feasible=false + 原因，直接淘汰不进引擎。
    func test_kickSolve_noSeedSequence_infeasible() {
        let sY = BTTablePhysics.surfaceY
        // 母球贴左长库，向左库（自身贴着的库）翻 1 库去碰远处目标球：首段几乎零长，无种子。
        let cue = SCNVector3(-1.0, sY + R, -0.6)
        let input = ShotInput(
            cueBall: cue, targetBall: SCNVector3(0.5, sY + R, 0.3), pocketIndex: 0,
            velocity: 3.0, spinX: 0, spinY: 0, surfaceY: sY,
            kickRails: [.left])
        let pred = ShotPredictor.predict(input)
        if !pred.feasible {
            XCTAssertFalse(pred.infeasibleReason.isEmpty, "不可行必须带原因")
        } else {
            // 若几何上竟有种子，则引擎终验裁决——结局必须是引擎口径，无几何假解。
            let info = ShotPredictor.kickContactInfo(events: pred.events)
            XCTAssertEqual(pred.kickContactMade,
                           info.contacted && info.cushionsBefore >= 1,
                           "kickContactMade 必须与引擎事件流判据一致")
        }
    }

    // MARK: - Helpers

    private func horizontalDir(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrtf(v.x * v.x + v.z * v.z)
        guard len > 1e-5 else { return SCNVector3(1, 0, 0) }
        return SCNVector3(v.x / len, 0, v.z / len)
    }
}


extension PhysicsEngineTests {
    func testSpatialStrikePreservesHorizontalBoundaryAndLegacyElevation() throws {
        for aim in [SCNVector3(1,0,0), SCNVector3(0,0,-1), SCNVector3(-0.6,0,0.8)] {
            for x: Float in [-0.4,0,0.4] {
                for y: Float in [-0.4,0,0.4] {
                    let old = CueBallStrike.executeStrike(aimDirection: aim, velocity: 2, spinX: x, spinY: y)
                    let spatial = try CueBallStrike.executeSpatialStrike(aimDirection: aim, velocity: 2,
                        spinX: x, spinY: y, elevation: 0)
                    for (a,b) in zip([old.velocity.x,old.velocity.y,old.velocity.z,old.angularVelocity.x,
                                     old.angularVelocity.y,old.angularVelocity.z,old.squirtAngle],
                                    [spatial.velocity.x,spatial.velocity.y,spatial.velocity.z,spatial.angularVelocity.x,
                                     spatial.angularVelocity.y,spatial.angularVelocity.z,spatial.squirtAngle]) {
                        XCTAssertEqual(a.bitPattern,b.bitPattern)
                    }
                    let elevatedLegacy = CueBallStrike.executeStrike(aimDirection: aim, velocity: 2,
                        spinX: x, spinY: y, elevation: .pi/4)
                    XCTAssertEqual(elevatedLegacy.velocity.y,0)
                }
            }
        }
    }

    func testSpatialStrikeHasDownwardImpulseAndBoundedEnergy() throws {
        let mass = Double(BallPhysics.mass), radius = Double(BallPhysics.radius)
        for degrees: Float in [0,15,30,45,60,75,90] {
            for offset: Float in [-0.5,0,0.5] {
                let angle = degrees * .pi / 180
                let hit = try CueBallStrike.executeSpatialStrike(aimDirection: SCNVector3(1,0,0),
                    velocity: 2, spinX: offset, spinY: 0.2, elevation: angle)
                XCTAssertLessThanOrEqual(hit.velocity.y,0)
                if degrees > 0 { XCTAssertLessThan(hit.velocity.y,0) }
                let kinetic = 0.5*mass*Double(hit.velocity.x*hit.velocity.x+hit.velocity.y*hit.velocity.y+hit.velocity.z*hit.velocity.z) +
                    0.2*mass*radius*radius*Double(hit.angularVelocity.x*hit.angularVelocity.x+hit.angularVelocity.y*hit.angularVelocity.y+hit.angularVelocity.z*hit.angularVelocity.z)
                XCTAssertLessThanOrEqual(kinetic,0.5*Double(CuePhysics.mass)*4 + 1e-6)
            }
        }
        let centered = try CueBallStrike.executeSpatialStrike(aimDirection: SCNVector3(1,0,0),
            velocity: 2, spinX: 0, spinY: 0, elevation: .pi/4)
        let speed: Float = 4 / (1 + BallPhysics.mass/CuePhysics.mass)
        XCTAssertEqual(centered.velocity.x, speed/sqrt(2), accuracy: 1e-6)
        XCTAssertEqual(centered.velocity.y, -speed/sqrt(2), accuracy: 1e-6)
        XCTAssertLessThan(centered.angularVelocity.length(),1e-4)
    }

    func testSpatialStrikeThroughClothProducesFlightAndLanding() throws {
        typealias V = SIMD3<Double>
        let asset = try PocketGeometryAsset.load()
        let solver = try asset.localSimulation(material: .tablePhysics(clothRestitution: 0.3),
                                               ballMaterial: .ballPhysics)
        let radius = Double(BallPhysics.radius), mass = Double(BallPhysics.mass)
        let bedCenter = Double(asset.surfaceY) + radius
        func vector(_ p: SCNVector3) -> V { V(Double(p.x),Double(p.y),Double(p.z)) }
        func energy(_ state: LocalPocketSimulation.State) -> Double {
            let v=state.velocity,w=state.omega
            return mass * (0.5*(v.x*v.x+v.y*v.y+v.z*v.z)
                + 0.2*radius*radius*(w.x*w.x+w.y*w.y+w.z*w.z)
                + Double(TablePhysics.gravity)*(state.position.y-bedCenter))
        }
        for degrees: Float in [30,60] {
          for side: Float in [0, -0.3, 0.3] {
            let strike = try CueBallStrike.executeSpatialStrike(aimDirection: SCNVector3(1,0,0),
                velocity: 2, spinX: side, spinY: 0, elevation: degrees * .pi / 180)
            let initial = LocalPocketSimulation.State(time: 0,position: V(-0.4,bedCenter,0),
                velocity: vector(strike.velocity),omega: vector(strike.angularVelocity))
            let transition = try solver.runUntilPlanarSupport(from: initial,duration: 0.4,maxStep: 0.0025,
                surfaceY: Double(asset.surfaceY))
            let coarse = transition.result
            let end = try XCTUnwrap(transition.planar)
            let height = (coarse.states.map { $0.position.y }.max() ?? bedCenter) - bedCenter
            do {
                XCTAssertLessThan(initial.velocity.y,0)
                XCTAssertTrue(coarse.states.contains { $0.velocity.y > 0 })
                XCTAssertGreaterThan(height,0.001)
                XCTAssertGreaterThanOrEqual(coarse.contacts.count,2,
                    "The initial cloth impulse and subsequent landing both need actual contacts")
            }
            XCTAssertNotNil(solver.planarSupport(from:end,surfaceY:Double(asset.surfaceY)),
                            "After the short flight the same solver must recover cloth support")
            XCTAssertEqual(end.velocity.y,0)
            XCTAssertEqual(end.position.y,bedCenter,accuracy:4e-6)
            XCTAssertLessThan(end.time,0.4)
            for state in coarse.states {
                XCTAssertLessThanOrEqual(energy(state),energy(initial)+mass*Double(TablePhysics.gravity)*4e-6+1e-6)
            }
            let refined = try solver.runUntilPlanarSupport(from: initial, duration: 0.4,
                maxStep: 0.00125, surfaceY: Double(asset.surfaceY))
            let refinedEnd = try XCTUnwrap(refined.planar)
            let commonEnd = min(end.time, refinedEnd.time)
            var compared = 0
            for tick in 1...Int(commonEnd / 0.005) {
                let time = Double(tick) * 0.005
                let a = try XCTUnwrap(coarse.intervals.last { $0.start.time <= time && $0.end.time >= time }?.sample(at: time))
                let b = try XCTUnwrap(refined.result.intervals.last { $0.start.time <= time && $0.end.time >= time }?.sample(at: time))
                for axis in 0..<3 {
                    XCTAssertEqual(a.position[axis], b.position[axis], accuracy: 8e-6,
                                   "degrees=\(degrees) time=\(time), position")
                    XCTAssertEqual(a.velocity[axis], b.velocity[axis], accuracy: 0.0016,
                                   "degrees=\(degrees) time=\(time), velocity")
                }
                compared += 1
            }
            XCTAssertGreaterThan(compared, 10)
            let landing = try XCTUnwrap(coarse.contacts.first { $0.time > 0.01 })
            let refinedLanding = try XCTUnwrap(refined.result.contacts.first { $0.time > 0.01 })
            XCTAssertEqual(landing.time, refinedLanding.time, accuracy: 0.00001)
            let engine = try EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: asset.surfaceY),
                                              startingAt: end.time)
            var landedBall = BallState(position: SCNVector3(Float(end.position.x), Float(end.position.y), Float(end.position.z)),
                velocity: SCNVector3(Float(end.velocity.x), Float(end.velocity.y), Float(end.velocity.z)),
                angularVelocity: SCNVector3(Float(end.omega.x), Float(end.omega.y), Float(end.omega.z)),
                state: .sliding, name: "cue")
            landedBall.state = EngineNumerics.determineMotionState(landedBall)
            engine.setBall(landedBall)
            engine.getTrajectoryRecorder().recordLocalIntervals(ballName: "cue", intervals: coarse.intervals)
            XCTAssertEqual(engine.spatialTime, end.time)
            let termination = engine.simulatePrediction(model: .spatialPockets, maxTime: 20)
            XCTAssertEqual(termination, .settled)
            let firstPlanarFrame = try XCTUnwrap(engine.getTrajectoryRecorder().framesByBallName["cue"]?.first)
            XCTAssertEqual(firstPlanarFrame.time, Float(end.time))
            XCTAssertEqual(firstPlanarFrame.position.x, landedBall.position.x)
            XCTAssertEqual(firstPlanarFrame.position.z, landedBall.position.z)
            XCTAssertEqual(firstPlanarFrame.velocity.x, landedBall.velocity.x)
            XCTAssertEqual(firstPlanarFrame.angularVelocity.y, landedBall.angularVelocity.y)
            let final = try XCTUnwrap(engine.getBall("cue"))
            XCTAssertEqual(final.state, .stationary)
            XCTAssertGreaterThan(engine.currentTime, Float(end.time))
            let playback = TrajectoryPlayback(recorder: engine.getTrajectoryRecorder(), surfaceY: Float(bedCenter))
            let airborneTime = Float(landing.time * 0.5)
            let airborne = try XCTUnwrap(playback.stateAt(ballName: "cue", time: airborneTime))
            XCTAssertGreaterThan(airborne.position.y, Float(bedCenter + 0.001))
            let jointTime = Float(end.time)
            let beforeJoint = try XCTUnwrap(playback.stateAt(ballName: "cue", time: jointTime.nextDown))
            let afterJoint = try XCTUnwrap(playback.stateAt(ballName: "cue", time: jointTime.nextUp))
            XCTAssertLessThan((beforeJoint.position - afterJoint.position).length(), 0.000002)
            XCTAssertLessThan((beforeJoint.velocity - afterJoint.velocity).length(), 0.00002)
            XCTAssertLessThan((beforeJoint.angularVelocity - afterJoint.angularVelocity).length(), 0.002)
            let playedRest = try XCTUnwrap(playback.stateAt(ballName: "cue", time: engine.currentTime + 1))
            XCTAssertEqual(playedRest.motionState, .stationary)
            XCTAssertLessThan((playedRest.position - final.position).length(), 0.000002)
            // A later query must not mutate or flatten the earlier flight prefix.
            let repeatedAirborne = try XCTUnwrap(playback.stateAt(ballName: "cue", time: airborneTime))
            XCTAssertEqual(repeatedAirborne.position.y, airborne.position.y)
            XCTAssertEqual(repeatedAirborne.velocity.y, airborne.velocity.y)
            print("[H01 landing refinement] degrees=\(degrees) side=\(side) samples=\(compared) handoff=\(end.time)/\(refinedEnd.time) landing=\(landing.time)/\(refinedLanding.time)")
            print("[H01 cloth flight] degrees=\(degrees) side=\(side) height=\(height) contacts=\(coarse.contacts.count) end=\(end)")
          }
        }
    }

    func testMixedEngineInitiallyAirborneBallFollowsGravity() throws {
        let surfaceY = BTTablePhysics.surfaceY
        let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: surfaceY))
        let initial = BallState(position: SCNVector3(0, surfaceY + R + 0.1, 0),
            velocity: SCNVector3(0.4, 0.5, -0.2), angularVelocity: SCNVector3(2, 3, 4),
            state: .sliding, name: "cue")
        engine.setBall(initial)
        let duration: Float = 0.02
        XCTAssertEqual(engine.simulatePrediction(model: .spatialPockets, maxTime: duration), .timeLimit)
        let end = try XCTUnwrap(engine.getBall("cue"))
        let expectedY = initial.position.y + initial.velocity.y * duration
            - 0.5 * TablePhysics.gravity * duration * duration
        let expectedVy = initial.velocity.y - TablePhysics.gravity * duration
        print("[H01 main airborne] actualY=\(end.position.y) expectedY=\(expectedY) actualVy=\(end.velocity.y) expectedVy=\(expectedVy)")
        XCTAssertEqual(end.position.y, expectedY, accuracy: 0.000002)
        XCTAssertEqual(end.velocity.y, expectedVy, accuracy: 0.00002)
        XCTAssertEqual(end.velocity.x, initial.velocity.x, accuracy: 0.00002)
        XCTAssertEqual(end.velocity.z, initial.velocity.z, accuracy: 0.00002)
        let entered = try XCTUnwrap(engine.getTrajectoryRecorder().localHandoffs.first)
        XCTAssertEqual(entered.domain, .airborne)
        XCTAssertNil(entered.pocketID)
    }

    func testAirborneMainEngineClearsOrHitsObstacleAccordingToHeight() throws {
        let y = BTTablePhysics.surfaceY + R
        for height: Float in [0.12, 0.01] {
            let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY))
            engine.setBall(BallState(position: SCNVector3(-0.1, y + height, 0),
                velocity: SCNVector3(2, 0, 0), angularVelocity: SCNVector3Zero, state: .sliding, name: "cue"))
            engine.setBall(BallState(position: SCNVector3(0, y, 0), velocity: SCNVector3Zero,
                angularVelocity: SCNVector3Zero, state: .stationary, name: "object"))
            XCTAssertEqual(engine.simulatePrediction(model: .spatialPockets, maxTime: 0.08), .timeLimit)
            let collided = engine.resolvedEvents.contains {
                if case .ballBall(let a, let b) = $0 { return Set([a,b]) == Set(["cue","object"]) }
                return false
            }
            let cue = try XCTUnwrap(engine.getBall("cue"))
            let object = try XCTUnwrap(engine.getBall("object"))
            if height == 0.12 {
                // At x=0, t=.05s: clearance=.12-g*t²/2 > 2R.
                XCTAssertGreaterThan(height - 0.5*TablePhysics.gravity*0.05*0.05, 2*R)
                XCTAssertFalse(collided)
                XCTAssertGreaterThan(cue.position.x, object.position.x)
                XCTAssertEqual(object.state, .stationary)
                XCTAssertEqual(object.position.x, 0)
            } else {
                XCTAssertTrue(collided)
                XCTAssertGreaterThan(object.velocity.length(), 0.1)
            }
        }
    }

    func testAirborneMainEngineClearsOrHitsRailAccordingToHeight() throws {
        let y = BTTablePhysics.surfaceY + R
        for height: Float in [0.15, 0.01] {
            let engine = EventDrivenEngine(tableGeometry: .chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY))
            engine.setBall(BallState(position: SCNVector3(1.1, y + height, 0),
                velocity: SCNVector3(2, 0, 0), angularVelocity: SCNVector3Zero, state: .sliding, name: "cue"))
            XCTAssertEqual(engine.simulatePrediction(model: .spatialPockets, maxTime: 0.12), .timeLimit)
            let hitRail = engine.resolvedEvents.contains {
                if case .ballCushion(let ball, _, _) = $0 { return ball == "cue" }
                return false
            }
            let end = try XCTUnwrap(engine.getBall("cue"))
            if height == 0.15 {
                XCTAssertFalse(hitRail)
                XCTAssertGreaterThan(end.position.x, TablePhysics.innerLength / 2)
                XCTAssertEqual(end.velocity.x, 2, accuracy: 0.00002)
                XCTAssertEqual(end.position.y, y + height - 0.5*TablePhysics.gravity*0.12*0.12, accuracy: 0.000002)
            } else {
                XCTAssertTrue(hitRail)
                XCTAssertLessThan(end.velocity.x, 0)
            }
            XCTAssertTrue(engine.getTrajectoryRecorder().confirmedCaptures.isEmpty,
                          "Clearing a rail is not a pocket event")
        }
    }

    func testMainElevatedStrikeLandsAndReleasesAirborneOwnership() throws {
        for degrees: Float in [30,60] {
            for side: Float in [-0.3,0.3] {
                let table = TableGeometry.chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY)
                let engine = EventDrivenEngine(tableGeometry: table)
                let strike = try CueBallStrike.executeSpatialStrike(aimDirection: SCNVector3(1,0,0),
                    velocity: 2, spinX: side, spinY: 0, elevation: degrees * .pi / 180)
                engine.setBall(BallState(position: SCNVector3(-0.4,BTTablePhysics.surfaceY+R,0),
                    velocity: strike.velocity, angularVelocity: strike.angularVelocity, state: .sliding, name: "cue"))
                XCTAssertEqual(engine.simulatePrediction(model: .spatialPockets, maxTime: 20), .settled)
                let handoffs = engine.getTrajectoryRecorder().localHandoffs.filter { $0.domain == .airborne }
                XCTAssertTrue(handoffs.contains { $0.kind == .entered && $0.state.velocity.y < 0 })
                XCTAssertTrue(handoffs.contains { $0.kind == .returned && $0.state.velocity.y == 0 })
                XCTAssertTrue(handoffs.allSatisfy { $0.pocketID == nil })
                XCTAssertEqual(try XCTUnwrap(engine.getBall("cue")).state, .stationary)
            }
        }
    }

    func testResumedEngineClockRejectsInvalidTimeAndRetainsDefault() throws {
        let table = TableGeometry.chineseEightBallQiuJi(surfaceY: BTTablePhysics.surfaceY)
        let original = EventDrivenEngine(tableGeometry: table)
        XCTAssertEqual(original.currentTime, 0)
        XCTAssertNil(original.spatialTime)
        for time in [-1, Double.nan, Double.infinity, Double.greatestFiniteMagnitude] {
            XCTAssertThrowsError(try EventDrivenEngine(tableGeometry: table, startingAt: time))
        }
        let resumed = try EventDrivenEngine(tableGeometry: table, startingAt: 7.123456789)
        XCTAssertEqual(resumed.spatialTime, 7.123456789)
        XCTAssertEqual(resumed.currentTime, Float(7.123456789))
        XCTAssertTrue(resumed.getAllBalls().isEmpty)
    }

    func testFlightBudgetDoesNotImplyLandingAndPreservesContinuation() throws {
        typealias V = SIMD3<Double>
        let asset = try PocketGeometryAsset.load()
        let solver = try asset.localSimulation(material: .tablePhysics(clothRestitution: 0.3),
                                               ballMaterial: .ballPhysics)
        let initial = LocalPocketSimulation.State(time: 7,
            position: V(0, Double(asset.surfaceY) + Double(R) + 0.1, 0),
            velocity: V(0.4, 0.5, -0.2), omega: V(2, 3, 4))
        let first = try solver.runUntilPlanarSupport(from: initial, duration: 0.02,
            maxStep: 0.0025, surfaceY: Double(asset.surfaceY))
        XCTAssertNil(first.planar, "A time budget cannot turn an airborne ball into a supported one")
        let middle = try XCTUnwrap(first.result.states.last)
        XCTAssertEqual(middle.time, 7.02, accuracy: 1e-12)
        let resumed = try solver.runUntilPlanarSupport(from: middle, duration: 0.02,
            maxStep: 0.00125, surfaceY: Double(asset.surfaceY))
        let uninterrupted = try solver.runUntilPlanarSupport(from: initial, duration: 0.04,
            maxStep: 0.0025, surfaceY: Double(asset.surfaceY))
        XCTAssertNil(resumed.planar)
        XCTAssertNil(uninterrupted.planar)
        XCTAssertTrue(first.result.contacts.isEmpty && resumed.result.contacts.isEmpty
                      && uninterrupted.result.contacts.isEmpty)
        let end = try XCTUnwrap(resumed.result.states.last)
        let direct = try XCTUnwrap(uninterrupted.result.states.last)
        let t = 0.04, gravity = V(0, -Double(TablePhysics.gravity), 0)
        let expectedPosition = initial.position + initial.velocity * t + gravity * (0.5*t*t)
        let expectedVelocity = initial.velocity + gravity * t
        for axis in 0..<3 {
            XCTAssertEqual(end.position[axis], expectedPosition[axis], accuracy: 1e-9)
            XCTAssertEqual(end.velocity[axis], expectedVelocity[axis], accuracy: 1e-9)
            XCTAssertEqual(end.omega[axis], initial.omega[axis], accuracy: 1e-9)
            XCTAssertEqual(end.position[axis], direct.position[axis], accuracy: 1e-9)
            XCTAssertEqual(end.velocity[axis], direct.velocity[axis], accuracy: 1e-9)
        }
        XCTAssertEqual(end.time, 7.04, accuracy: 1e-12)
        XCTAssertGreaterThan(end.velocity.y, 0, "This fixture is still ascending when its budget ends")
    }

    func testSpatialStrikeRejectsInvalidInputs() {
        for (speed,x,y,angle): (Float,Float,Float,Float) in [(-1,0,0,0),(1,1,1,0),
            (1,0,0,-0.1),(1,0,0,.pi),(Float.nan,0,0,0),(1,Float.nan,0,0)] {
            XCTAssertThrowsError(try CueBallStrike.executeSpatialStrike(aimDirection: SCNVector3(1,0,0),
                velocity: speed, spinX: x, spinY: y, elevation: angle))
        }
        XCTAssertThrowsError(try CueBallStrike.executeSpatialStrike(aimDirection: SCNVector3Zero,
            velocity: 1, spinX: 0, spinY: 0, elevation: 0))
    }
}
