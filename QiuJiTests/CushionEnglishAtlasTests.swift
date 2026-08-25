import XCTest
import SceneKit
@testable import QiuJi

/// v20 W1：「加塞吃库图谱」spinX 档位 / 挤偏补偿 / 库后切片 / 默认盘面。
final class CushionEnglishAtlasTests: XCTestCase {

    // MARK: - Levels & palette

    func testSpinXLevels_endpointsEqualMiscueLimit() {
        let levels = CushionEnglishAtlasGeometry.spinXLevels()
        XCTAssertEqual(levels.count, 8)
        let limit = CuePhysics.miscueLimitFraction
        XCTAssertEqual(levels.first!, limit, accuracy: 1e-6, "首档 = +miscueLimit（纯左塞）")
        XCTAssertEqual(levels.last!, -limit, accuracy: 1e-6, "末档 = −miscueLimit（纯右塞）")
        let step = levels[0] - levels[1]
        for i in 1..<levels.count {
            XCTAssertEqual(levels[i - 1] - levels[i], step, accuracy: 1e-6)
        }
        XCTAssertEqual(CushionEnglishAtlasGeometry.trackColors.count, 8,
                       "页内 8 色板与档位数一致")
    }

    /// 打滑圆勾股：L=0.5，spinY=0.3 → 弦半长 0.4；满高/满低 → 0。
    func testAllowedSpinXLimit_isMiscueChord() {
        let L = CuePhysics.miscueLimitFraction
        XCTAssertEqual(CushionEnglishAtlasGeometry.allowedSpinXLimit(spinY: 0),
                       L, accuracy: 1e-6, "中杆弦 = 满塞")
        XCTAssertEqual(CushionEnglishAtlasGeometry.allowedSpinXLimit(spinY: 0.3),
                       0.4, accuracy: 1e-6, "√(0.5²−0.3²)=0.4")
        XCTAssertEqual(CushionEnglishAtlasGeometry.allowedSpinXLimit(spinY: -0.3),
                       0.4, accuracy: 1e-6, "高低对称")
        XCTAssertEqual(CushionEnglishAtlasGeometry.allowedSpinXLimit(spinY: 0.4),
                       0.3, accuracy: 1e-6, "√(0.5²−0.4²)=0.3")
        XCTAssertEqual(CushionEnglishAtlasGeometry.allowedSpinXLimit(spinY: L),
                       0, accuracy: 1e-6, "满高无加塞余地")
        XCTAssertEqual(CushionEnglishAtlasGeometry.allowedSpinXLimit(spinY: -L),
                       0, accuracy: 1e-6, "满低无加塞余地")
        XCTAssertEqual(CushionEnglishAtlasGeometry.allowedSpinXLimit(spinY: L + 0.2),
                       0, accuracy: 1e-6, "越界钳到圆上")
    }

    func testSpinXLevels_atHeightUsesChordAndStaysInsideMiscueCircle() {
        let spinY: Float = 0.3
        let levels = CushionEnglishAtlasGeometry.spinXLevels(spinY: spinY)
        XCTAssertEqual(levels.count, 8)
        XCTAssertEqual(levels.first!, 0.4, accuracy: 1e-6)
        XCTAssertEqual(levels.last!, -0.4, accuracy: 1e-6)
        let step = levels[0] - levels[1]
        for i in 1..<levels.count {
            XCTAssertEqual(levels[i - 1] - levels[i], step, accuracy: 1e-6)
        }
        let L = CuePhysics.miscueLimitFraction
        for sx in levels {
            let r = hypot(sx, spinY)
            XCTAssertLessThanOrEqual(r, L + 1e-5,
                                     "spinX=\(sx) spinY=\(spinY) 应在打滑圆内，r=\(r)")
        }
        XCTAssertEqual(hypot(levels.first!, spinY), L, accuracy: 1e-5,
                       "弦端点应落在打滑圆上")
    }

    func testSpinXLevels_atMiscueLimitCollapsesToZero() {
        let levels = CushionEnglishAtlasGeometry.spinXLevels(
            spinY: CuePhysics.miscueLimitFraction)
        XCTAssertEqual(levels.count, 8)
        for sx in levels {
            XCTAssertEqual(sx, 0, accuracy: 1e-6)
        }
    }

    // MARK: - Squirt compensation (E3)

    /// 补偿后 actualDirection(aim', spinX) 与 geometric 夹角 P95 < 0.05°。
    func testSquirtCompensation_alignsActualDirectionToGeometric() {
        let geometric = SCNVector3(0.6, 0, 0.8).normalized()
        let levels = CushionEnglishAtlasGeometry.spinXLevels()
        var angles: [Float] = []
        for spinX in levels {
            let aimP = CushionEnglishAtlasGeometry.aimDirCompensatingSquirt(
                geometric: geometric, spinX: spinX)
            let actual = CueBallStrike.actualDirection(aimDirection: aimP, spinX: spinX)
            let deg = CushionEnglishAtlasGeometry.angleDegBetween(actual, geometric)
            angles.append(deg)
            XCTAssertLessThan(deg, 0.05,
                              "spinX=\(spinX): actual vs geometric = \(deg)°（应 < 0.05°）")
        }
        let sorted = angles.sorted()
        let p95Idx = min(sorted.count - 1, Int(ceil(0.95 * Double(sorted.count))) - 1)
        let p95 = sorted[max(0, p95Idx)]
        XCTAssertLessThan(p95, 0.05, "P95 夹角应 < 0.05°，got \(p95)")
    }

    // MARK: - Default board + slice (D-v20-2 / D-v20-3)

    func testDefaultScene_allEightLevels_hitLongCushionAfterBallBall() {
        let sY = BTTablePhysics.surfaceY
        let scene = CushionEnglishAtlasGeometry.defaultTeachingScene()
        let y = CushionEnglishAtlasGeometry.sceneKitBallY(surfaceY: sY)
        let cue = SCNVector3(Float(scene.cue.x), y, Float(scene.cue.y))
        let target = SCNVector3(Float(scene.target.x), y, Float(scene.target.y))
        let geometric = SCNVector3(Float(scene.aimDir.x), 0, Float(scene.aimDir.y))
        let velocity = Float(ShotTuning.defaultVelocity)
        let levels = CushionEnglishAtlasGeometry.spinXLevels()

        for (i, spinX) in levels.enumerated() {
            let aim = CushionEnglishAtlasGeometry.aimDirCompensatingSquirt(
                geometric: geometric, spinX: spinX)
            let pred = ShotPredictor.simulateFree(
                cueBall: cue, aimDir: aim, velocity: velocity,
                spinX: spinX, spinY: 0,
                surfaceY: sY,
                balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)]
            )
            let bb = CushionEnglishAtlasGeometry.firstBallBallEvent(in: pred.events)
            let cushion = CushionEnglishAtlasGeometry.firstCueCushionAfterBallBall(in: pred.events)
            XCTAssertNotNil(bb, "[\(i)] spinX=\(spinX) 应发生球-球碰撞")
            XCTAssertNotNil(cushion, "[\(i)] spinX=\(spinX) 碰后母球应吃库")
            guard let cushion, let recorder = pred.recorder,
                  let pos = recorder.stateAt(ballName: ShotInput.cueBallName, time: cushion.time)
            else { continue }
            XCTAssertTrue(
                CushionEnglishAtlasGeometry.isNearLongCushion(pos.position),
                "[\(i)] spinX=\(spinX) 首库应贴长库，pos=(\(pos.position.x), \(pos.position.z))"
            )
        }
    }

    func testPathSlice_startsAtFirstCushion_endsPerDv202() {
        let sY = BTTablePhysics.surfaceY
        let scene = CushionEnglishAtlasGeometry.defaultTeachingScene()
        let y = CushionEnglishAtlasGeometry.sceneKitBallY(surfaceY: sY)
        let cue = SCNVector3(Float(scene.cue.x), y, Float(scene.cue.y))
        let target = SCNVector3(Float(scene.target.x), y, Float(scene.target.y))
        let geometric = SCNVector3(Float(scene.aimDir.x), 0, Float(scene.aimDir.y))
        let velocity = Float(ShotTuning.defaultVelocity)

        // Probe center + extremes.
        for spinX in [Float(0), CuePhysics.miscueLimitFraction, -CuePhysics.miscueLimitFraction] {
            let aim = CushionEnglishAtlasGeometry.aimDirCompensatingSquirt(
                geometric: geometric, spinX: spinX)
            let pred = ShotPredictor.simulateFree(
                cueBall: cue, aimDir: aim, velocity: velocity,
                spinX: spinX, spinY: 0,
                surfaceY: sY,
                balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)]
            )
            let cushion1 = CushionEnglishAtlasGeometry.firstCueCushionAfterBallBall(in: pred.events)
            XCTAssertNotNil(cushion1, "spinX=\(spinX) 应有首库")
            guard let cushion1, let recorder = pred.recorder,
                  let start = recorder.stateAt(ballName: ShotInput.cueBallName, time: cushion1.time)
            else { continue }

            let slice = CushionEnglishAtlasGeometry.pathAfterFirstCueCushion(pred)
            XCTAssertGreaterThanOrEqual(slice.count, 2, "spinX=\(spinX) 切片应有折线段")

            let d0 = hypotf(slice.first!.x - start.position.x, slice.first!.z - start.position.z)
            XCTAssertLessThan(d0, 0.03, "切片起点应贴近首库触点")

            if let cushion2 = CushionEnglishAtlasGeometry.secondCueCushionAfterFirst(
                in: pred.events, after: cushion1
            ),
               let end = recorder.stateAt(ballName: ShotInput.cueBallName, time: cushion2.time) {
                let d1 = hypotf(slice.last!.x - end.position.x, slice.last!.z - end.position.z)
                XCTAssertLessThan(d1, 0.03, "有二库时终点应贴近第二库")
            } else {
                let arc = CushionEnglishAtlasGeometry.pathArcLengthXZ(slice)
                let toStop: Float
                if let stop = pred.cuePath.last {
                    // Arc from cushion start along full path to stop (upper bound reference).
                    let startIdx = CushionEnglishAtlasGeometry.nearestIndex(
                        in: pred.cuePath, to: start.position)
                    let stopIdx = pred.cuePath.count - 1
                    toStop = CushionEnglishAtlasGeometry.pathArcLengthXZ(
                        Array(pred.cuePath[startIdx...stopIdx]))
                    _ = stop
                } else {
                    toStop = .greatestFiniteMagnitude
                }
                let expected = min(CushionEnglishAtlasGeometry.postCushionArcLimit, toStop)
                XCTAssertLessThan(
                    abs(arc - expected), 0.05,
                    "无二库时弧长应≈min(0.40, 至停点)=\(expected)，got \(arc)"
                )
                XCTAssertLessThanOrEqual(
                    arc, CushionEnglishAtlasGeometry.postCushionArcLimit + 0.03,
                    "无二库时弧长不得超过 0.40m（采样余量）"
                )
            }
        }
    }

    // MARK: - Evidence draft (chirality)

    /// 落盘数值草稿：补偿对齐 + 库后出射相对中杆开/闭手性。
    func testWriteV20EvidenceDraft() throws {
        let sY = BTTablePhysics.surfaceY
        let scene = CushionEnglishAtlasGeometry.defaultTeachingScene()
        let y = CushionEnglishAtlasGeometry.sceneKitBallY(surfaceY: sY)
        let cue = SCNVector3(Float(scene.cue.x), y, Float(scene.cue.y))
        let target = SCNVector3(Float(scene.target.x), y, Float(scene.target.y))
        let geometric = SCNVector3(Float(scene.aimDir.x), 0, Float(scene.aimDir.y))
        let velocity = Float(ShotTuning.defaultVelocity)
        let levels = CushionEnglishAtlasGeometry.spinXLevels()

        var lines: [String] = []
        lines.append("=== v20 W1 加塞吃库图谱 — 数值草稿 ===")
        lines.append("日期: 2026-07-27")
        lines.append("")
        lines.append("【钉死坐标契约】")
        lines.append("- 系: SceneKit 世界系；水平面 X–Z；Y 朝上；单位 m")
        lines.append("- +X=右端，+Z=顶视图上方；台面中心 (0, 0.80, 0)")
        lines.append("- 水平角 atan2(z,x)；spinX 正=左塞；spinY 本页≡0（中杆）")
        lines.append("- 挤偏补偿: aim'=geometric.rotatedY(+squirtAngle(spinX))")
        lines.append("- 切片: 碰后首个 ballCushion → 下一 ballCushion；无二库则 min(0.40m, 停点)")
        lines.append("")

        // Squirt compensation table
        lines.append("【挤偏补偿对齐】geometric=\(geometric.x),\(geometric.z)")
        var compAngles: [Float] = []
        for spinX in levels {
            let aimP = CushionEnglishAtlasGeometry.aimDirCompensatingSquirt(
                geometric: geometric, spinX: spinX)
            let actual = CueBallStrike.actualDirection(aimDirection: aimP, spinX: spinX)
            let deg = CushionEnglishAtlasGeometry.angleDegBetween(actual, geometric)
            let alphaDeg = CueBallStrike.squirtAngle(a: spinX) * 180 / .pi
            compAngles.append(deg)
            lines.append(String(
                format: "  spinX=%+.3f  α=%+.4f°  err=%.6f°",
                spinX, alphaDeg, deg))
        }
        let p95 = compAngles.sorted()[min(compAngles.count - 1,
                                          Int(ceil(0.95 * Double(compAngles.count))) - 1)]
        lines.append(String(format: "  P95 err=%.6f°  (门槛 0.05°) → %@",
                            p95, p95 < 0.05 ? "PASS" : "FAIL"))
        lines.append("")

        // Default scene + chirality
        lines.append("【默认教学盘面】cut=\(scene.cutAngleDeg)° cueDist=\(scene.cueDistance)")
        lines.append(String(format: "  T=(%.4f, %.4f) C=(%.4f, %.4f)",
                            scene.target.x, scene.target.y, scene.cue.x, scene.cue.y))
        lines.append(String(format: "  aim=(%.4f, %.4f) velocity=%.2f m/s",
                            scene.aimDir.x, scene.aimDir.y, velocity))
        lines.append("")
        lines.append("【8 档 simulateFree：碰后首库 + 库后出射相对中杆】")
        lines.append("SpinAndEnglish 口径：顺塞更开、逆塞更闭（相对无塞基线）。")
        lines.append("本草稿以中杆(spinX=0)库后首段方向为基线，测有符号偏转（CCW=+，俯视 +Y）。")
        lines.append("")

        struct Row {
            var spinX: Float
            var hasBB: Bool
            var hasCushion: Bool
            var nearLong: Bool
            var cushionZ: Float
            var postDir: SCNVector3?
            var yawVsCenter: Float?
            var sliceCount: Int
            var sliceArc: Float
        }
        var rows: [Row] = []

        // 中杆基线单独实测（8 档端点不含 spinX=0）。
        let centerPred = ShotPredictor.simulateFree(
            cueBall: cue, aimDir: geometric, velocity: velocity,
            spinX: 0, spinY: 0,
            surfaceY: sY,
            balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)]
        )
        let centerSlice = CushionEnglishAtlasGeometry.pathAfterFirstCueCushion(centerPred)
        let centerDir = CushionEnglishAtlasGeometry.postCushionInitialDir(centerSlice)
        if let centerDir {
            lines.append(String(
                format: "中杆基线 postDir=(%.4f, %.4f)  sliceArc=%.3f",
                centerDir.x, centerDir.z,
                CushionEnglishAtlasGeometry.pathArcLengthXZ(centerSlice)))
        } else {
            lines.append("中杆基线: 无法取库后首段方向")
        }
        lines.append("")

        for spinX in levels {
            let aim = CushionEnglishAtlasGeometry.aimDirCompensatingSquirt(
                geometric: geometric, spinX: spinX)
            let pred = ShotPredictor.simulateFree(
                cueBall: cue, aimDir: aim, velocity: velocity,
                spinX: spinX, spinY: 0,
                surfaceY: sY,
                balls: [ObstacleBall(name: ShotInput.targetBallName, position: target)]
            )
            let bb = CushionEnglishAtlasGeometry.firstBallBallEvent(in: pred.events)
            let cushion = CushionEnglishAtlasGeometry.firstCueCushionAfterBallBall(in: pred.events)
            var nearLong = false
            var cz: Float = .nan
            if let cushion, let recorder = pred.recorder,
               let s = recorder.stateAt(ballName: ShotInput.cueBallName, time: cushion.time) {
                nearLong = CushionEnglishAtlasGeometry.isNearLongCushion(s.position)
                cz = s.position.z
            }
            let slice = CushionEnglishAtlasGeometry.pathAfterFirstCueCushion(pred)
            let post = CushionEnglishAtlasGeometry.postCushionInitialDir(slice)
            var yaw: Float?
            if let centerDir, let post {
                yaw = CushionEnglishAtlasGeometry.signedYawDeg(from: centerDir, to: post)
            }
            rows.append(Row(
                spinX: spinX, hasBB: bb != nil, hasCushion: cushion != nil,
                nearLong: nearLong, cushionZ: cz, postDir: post, yawVsCenter: yaw,
                sliceCount: slice.count,
                sliceArc: CushionEnglishAtlasGeometry.pathArcLengthXZ(slice)
            ))
        }

        for r in rows {
            let yawStr = r.yawVsCenter.map { String(format: "%+.3f°", $0) } ?? "n/a"
            lines.append(String(
                format: "  spinX=%+.3f  bb=%@  cushion=%@  long=%@  z=% .3f  slice=%d arc=%.3f  Δyaw@center=%@",
                r.spinX,
                r.hasBB ? "Y" : "N",
                r.hasCushion ? "Y" : "N",
                r.nearLong ? "Y" : "N",
                r.cushionZ,
                r.sliceCount,
                r.sliceArc,
                yawStr
            ))
        }
        lines.append("")

        // Chirality note vs SpinAndEnglish
        // For bottom long cushion (normal +Z inward): "opening" means rebound farther from
        // the inward normal — larger |departure from specular|. We report engine-signed yaw
        // honestly rather than forcing the teaching label.
        let left = rows.first { abs($0.spinX - CuePhysics.miscueLimitFraction) < 1e-5 }
        let right = rows.first { abs($0.spinX + CuePhysics.miscueLimitFraction) < 1e-5 }
        lines.append("【手性对照 SpinAndEnglish「顺塞更开 / 逆塞更闭」】")
        lines.append("定义（本盘面实测）：首库贴 |Z|≈0.606 长库；Δyaw = 库后首段相对中杆基线的有符号偏转（CCW=+，俯视 +Y）。")
        lines.append("SpinAndEnglish 文案：顺塞更开、逆塞更闭。本草稿只报告引擎符号，不改物理去迎合文案。")
        if let left, let right, let ly = left.yawVsCenter, let ry = right.yawVsCenter {
            lines.append(String(format: "  纯左塞(+miscue, spinX=+0.5) Δyaw=%+.3f°", ly))
            lines.append(String(format: "  纯右塞(−miscue, spinX=−0.5) Δyaw=%+.3f°", ry))
            let note: String
            if ly * ry < 0 {
                note = "左右塞相对中杆偏转符号相反（扇形张开）——与「侧旋打破入≈反」一致；哪侧更开/更闭见 |Δyaw| 与符号，按入射切向解读顺/逆，不以文案硬套。"
            } else if abs(ly) < 0.05 && abs(ry) < 0.05 {
                note = "极端档相对中杆 Δyaw≈0——引擎在本盘面/力度下库后差极小，如实记录。"
            } else {
                note = "左右塞同号偏转——如实记录引擎符号，不喂绿为「顺开逆闭」。"
            }
            lines.append("  结论: \(note)")
        } else {
            lines.append("  结论: 缺极端档或中杆基线方向，无法对照手性。")
        }
        lines.append("")

        let allCushion = rows.allSatisfy { $0.hasBB && $0.hasCushion && $0.nearLong }
        lines.append("【不变量】")
        lines.append("  spinX[0]==+miscue: \(abs(levels[0] - CuePhysics.miscueLimitFraction) < 1e-6 ? "PASS" : "FAIL")")
        lines.append("  spinX[-1]==−miscue: \(abs(levels[7] + CuePhysics.miscueLimitFraction) < 1e-6 ? "PASS" : "FAIL")")
        lines.append("  compensation P95<0.05°: \(p95 < 0.05 ? "PASS" : "FAIL")")
        lines.append("  8/8 碰后长库: \(allCushion ? "PASS" : "FAIL")")
        lines.append("OVERALL: \(p95 < 0.05 && allCushion ? "PASS" : "FAIL")")

        let dir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/v20-evidence",
                      isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("w1-cushion-english-draft.txt")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        // Also a short acceptance pointer.
        let acc = dir.appendingPathComponent("acceptance.md")
        let accBody = """
        # v20 W1 acceptance

        - Draft: `build/v20-evidence/w1-cushion-english-draft.txt`
        - Overall: \(p95 < 0.05 && allCushion ? "PASS" : "FAIL")
        - Compensation P95: \(String(format: "%.6f", p95))°
        - 8/8 long cushion: \(allCushion)
        """
        try accBody.write(to: acc, atomically: true, encoding: .utf8)

        XCTAssertTrue(allCushion, "默认盘面须 8/8 碰后吃到长库（见草稿 \(url.path)）")
        XCTAssertLessThan(p95, 0.05)
    }
}
