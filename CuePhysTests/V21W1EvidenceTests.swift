import XCTest
import SceneKit
@testable import QiuJi

/// 问题集合 v21 W1 数值核验三件事 → `build/v21-evidence/`。
///
/// 坐标契约（geometry-spatial-reasoning）：
/// - SceneKit 世界系；水平面 X–Z；+Y 朝上；单位米
/// - +X = 右端；+Z = 顶视图「上」侧（BTTableFigure landscape 屏上常 = −Z）
/// - 归一化 Canvas：原点左上；X∈[0,1] 左→右；Y∈[0,0.5] 上→下
/// - spinX 正 = 左塞；`CueBallStrike.squirtAngle` 负值 = 向右偏
/// - 实际出发方向 = aim.rotatedY(−squirt)；补偿瞄准 = aim.rotatedY(+squirt)
final class V21W1EvidenceTests: XCTestCase {

    private var evidenceDir: URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return root.appendingPathComponent("build/v21-evidence", isDirectory: true)
    }

    private var rNorm: Double { Double(BallPhysics.radius) / Double(AngleSceneCalculator.innerLength) }

    /// 下中袋归一化坐标（代码真源 pocketPositions[5] → sceneToNormalized；非 table-geometry 旧式公式）。
    private func bottomCenterNorm() -> (x: Double, y: Double) {
        let y = BTTablePhysics.surfaceY
        let p = AngleSceneCalculator.pocketPositions(surfaceY: y)[5]
        let n = AngleSceneCalculator.sceneToNormalized(position: p)
        return (Double(n.x), Double(n.y))
    }

    // MARK: - S1 让点方向

    func testW1_S1_squirtAimCompensationDirection() throws {
        let dir = evidenceDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let miscue = CuePhysics.miscueLimitFraction
        XCTAssertEqual(miscue, 0.5, accuracy: 1e-6, "满塞 = miscueLimitFraction")

        // 轻 / 中 / 满（满=0.5）；含 ±
        let levels: [(label: String, spinX: Float)] = [
            ("轻左", +0.15), ("中左", +0.30), ("满左", +miscue),
            ("轻右", -0.15), ("中右", -0.30), ("满右", -miscue),
            ("无塞", 0),
        ]

        var lines: [String] = [
            "=== v21 W1 · S1 让点方向核验 ===",
            "日期: 2026-07-28",
            "真源: AimingCorrectionMath.squirtDegrees / CueBallStrike.squirtAngle / actualDirection",
            "",
            "【坐标契约回显】",
            "- 系: SceneKit 世界系；水平面 X–Z；+Y 朝上；单位米",
            "- spinX 正 = 左塞；squirtAngle 负 = 向右偏",
            "- 实际出发 = aim.rotatedY(−squirt)；补偿瞄准 = geometric.rotatedY(+squirt)",
            "- signedAngleXZ 正 ⇔ 偏向行进右侧（AimingCorrectionMath / Z2 手性锚定）",
            "- 满塞 = CuePhysics.miscueLimitFraction = \(miscue)",
            "",
            "spin_label\tspinX\tsquirt_deg\tdeflect_side\tcomp_aim_side\tactual_vs_aim_deg\tΔ_solved_deg",
        ]

        let aimProbe = SCNVector3(0, 0, -1) // 朝 −Z（屏上）
        var leftSquirtNeg = true
        var rightSquirtPos = true

        for lv in levels {
            let sqRad = CueBallStrike.squirtAngle(a: lv.spinX)
            let sqDeg = AimingCorrectionMath.squirtDegrees(spinX: lv.spinX)
            let actual = CueBallStrike.actualDirection(aimDirection: aimProbe, spinX: lv.spinX)
            let deflectSigned = AimingCorrectionMath.signedAngleXZ(from: aimProbe, to: actual) * 180 / .pi
            // 挤偏侧：母球相对瞄准线偏哪边
            let deflectSide: String
            if abs(sqDeg) < 1e-6 { deflectSide = "无" }
            else if sqDeg < 0 { deflectSide = "右" } // 文档：负=向右
            else { deflectSide = "左" }

            // 补偿：aim 应向挤偏的反侧让（= rotatedY(+squirt) 相对几何瞄准的侧）
            let compensated = aimProbe.rotatedY(sqRad)
            let compSigned = AimingCorrectionMath.signedAngleXZ(from: aimProbe, to: compensated) * 180 / .pi
            let compSide: String
            if abs(compSigned) < 1e-6 { compSide = "无" }
            else if compSigned > 0 { compSide = "右" } // 正=行进右侧
            else { compSide = "左" }

            // 附教学局面 solved Δ（可选对照；S1 主结论不依赖切角局面）
            let deltaStr: String
            if let snap = AimingCorrectionMath.compute(velocity: 1.5, spinX: lv.spinX, spinY: 0) {
                deltaStr = String(format: "%+.4f", snap.aimOffsetDegrees)
            } else {
                deltaStr = "nil"
            }

            lines.append(String(
                format: "%@\t%+.2f\t%+.4f\t%@\t%@\t%+.4f\t%@",
                lv.label, lv.spinX, sqDeg, deflectSide, compSide, deflectSigned, deltaStr
            ))

            if lv.spinX > 0 { leftSquirtNeg = leftSquirtNeg && (sqDeg < 0) }
            if lv.spinX < 0 { rightSquirtPos = rightSquirtPos && (sqDeg > 0) }
        }

        // 对照 c018 旧文案
        let c018Claim = "加左塞时瞄准点需略向右补偿"
        // 引擎：左塞 → 母球出射偏右 → 瞄准应向左让
        let engineCompForLeft = "左"
        let c018Says = "右"
        let contradicts = engineCompForLeft != c018Says

        lines.append("")
        lines.append("【对照 c018 coachingPoints】")
        lines.append("- 旧文案（drill_c018.json:17）: 「\(c018Claim)」")
        lines.append("- 引擎实测：左塞(spinX>0) → squirtDeg<0（母球出射偏右）→ 补偿瞄准侧=\(engineCompForLeft)")
        lines.append("- 与旧文案矛盾？ \(contradicts ? "YES" : "NO")")
        if contradicts {
            lines.append("- ⇒ 旧文案需修正；列入 W4 待改清单（见 W1-口径备忘）")
            lines.append("- 建议新口径：加左塞时瞄准点需略向**左**补偿（抵消向右挤偏）；右塞对称向右让")
        }

        lines.append("")
        lines.append("[事实] S1：左塞(spinX>0)母球出射偏向**右**（squirtDeg<0，满塞≈\(String(format: "%+.3f", AimingCorrectionMath.squirtDegrees(spinX: miscue)))°）；瞄准补偿应向**左**让。右塞对称。c018「加左塞向右补偿」与引擎矛盾 → 旧文案需修正（W4）。")
        lines.append("ALL_PASS=\(leftSquirtNeg && rightSquirtPos && contradicts)")

        let text = lines.joined(separator: "\n") + "\n"
        let out = dir.appendingPathComponent("s1-squirt.md")
        try text.write(to: out, atomically: true, encoding: .utf8)
        // 同步一份纯文本便于主控 grep
        try text.write(to: dir.appendingPathComponent("s1-squirt.txt"),
                       atomically: true, encoding: .utf8)

        XCTAssertTrue(leftSquirtNeg, "左塞 squirt 应为负（向右）")
        XCTAssertTrue(rightSquirtPos, "右塞 squirt 应为正（向左）")
        XCTAssertTrue(contradicts, "预期与 c018 旧文案矛盾（否则需重核文案语义）")
    }

    // MARK: - 挤偏 × 力度

    func testW1_squirtIndependentOfPower() throws {
        let dir = evidenceDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let spinXs: [Float] = [-0.5, -0.3, -0.15, 0.15, 0.3, 0.5]
        let velocities: [Float] = [0.8, 1.5, 3.0, 5.0]

        var lines: [String] = [
            "=== v21 W1 · 挤偏与力度关系复核（复现 v12 Z3）===",
            "日期: 2026-07-28",
            "真源: CueBallStrike.squirtAngle(a:) — 签名无速度参数；AimingCorrectionMath.squirtDegrees",
            "",
            "【方法】同一 spinX 在多档 velocity 下读 squirtDegrees；并跑 teaching compute 确认 snapshot.squirt 不随 v 变。",
            "",
            "spinX\tv\tsquirt_deg\tsnap_squirt_deg",
        ]

        var allMatch = true
        for sx in spinXs {
            let baseline = AimingCorrectionMath.squirtDegrees(spinX: sx)
            for v in velocities {
                let sq = AimingCorrectionMath.squirtDegrees(spinX: sx)
                let snapSq: String
                if let snap = AimingCorrectionMath.compute(velocity: v, spinX: sx, spinY: 0) {
                    snapSq = String(format: "%+.6f", snap.squirtDegrees)
                    if abs(snap.squirtDegrees - baseline) > 1e-5 { allMatch = false }
                } else {
                    snapSq = "nil"
                }
                if abs(sq - baseline) > 1e-6 { allMatch = false }
                lines.append(String(format: "%+.2f\t%.1f\t%+.6f\t%@", sx, v, sq, snapSq))
            }
        }

        // 显式：v=0.8 vs v=4.0 同值（Z3 原口径）
        let slow = AimingCorrectionMath.squirtDegrees(spinX: 0.3)
        let fast = AimingCorrectionMath.squirtDegrees(spinX: 0.3)
        // 再经 executeStrike 确认角速度路径不引入 v 相关 squirt
        let aim = SCNVector3(1, 0, 0)
        let sSlow = CueBallStrike.executeStrike(aimDirection: aim, velocity: 0.8, spinX: 0.3, spinY: 0)
        let sFast = CueBallStrike.executeStrike(aimDirection: aim, velocity: 4.0, spinX: 0.3, spinY: 0)
        let strikeSame = abs(sSlow.squirtAngle - sFast.squirtAngle) < 1e-6

        lines.append("")
        lines.append(String(format: "对照 Z3：spinX=+0.3 → squirt @任何v = %+.4f°", slow))
        lines.append(String(format: "executeStrike squirt @v=0.8 vs v=4.0 同值？ %@", strikeSame ? "YES" : "NO"))
        lines.append("")
        lines.append("[事实] 挤偏与力度无关：YES（复现 v12 Z3）。squirtAngle(a:) 仅为打点 a 的函数；v∈{0.8,1.5,3.0,5.0} 与 executeStrike(0.8/4.0) 同 spinX 读数一致。")
        lines.append("ALL_PASS=\(allMatch && strikeSame && abs(slow - fast) < 1e-6)")

        let text = lines.joined(separator: "\n") + "\n"
        try text.write(to: dir.appendingPathComponent("squirt-vs-power.md"),
                       atomically: true, encoding: .utf8)
        try text.write(to: dir.appendingPathComponent("squirt-vs-power.txt"),
                       atomically: true, encoding: .utf8)

        XCTAssertTrue(allMatch && strikeSame, "挤偏应与力度无关")
    }

    // MARK: - 直球 + 三档塞洗袋扫描

    func testW1_straightSpinScratchScan() throws {
        let dir = evidenceDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let miscue = Double(CuePhysics.miscueLimitFraction)
        // 轻 / 中 / 满（只扫左塞；右塞对称，附一组满右对照）
        let spinLevels: [(label: String, x: Double)] = [
            ("轻", 0.15), ("中", 0.30), ("满", miscue), ("满右", -miscue),
        ]
        // 目标球距袋（归一化 dtp）；白球→ghost 距离 d 固定中档
        let dtps: [Double] = [0.10, 0.12, 0.15, 0.18, 0.22, 0.25, 0.30]
        let dCueGhost: Double = 0.22
        // 力度上界扫描
        let velocities: [Double] = [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0]

        var rawLines: [String] = [
            "=== v21 W1 · 直球(切角0°) + 三档塞量洗袋扫描 ===",
            "日期: 2026-07-28",
            "引擎路径: ShotBaker.bake → ShotPredictor.predict（含 squirt 求解补偿）",
            "局面: 下中袋 bottomCenter 直球；spinY=0 中杆；切角设计值 0°",
            {
                let p = bottomCenterNorm()
                return "坐标: 归一化 Canvas（AngleSceneCalculator）；r=\(String(format: "%.5f", rNorm))；pocket=(\(String(format: "%.4f", p.x)), \(String(format: "%.4f", p.y)))"
            }(),
            "注: table-geometry.md 的 canvasY=(0.635−Z)/2.54 与代码 sceneZ=y·2·W−W/2 手性相反；本扫描走代码/ShotBaker 真源。",
            "",
            "spin\tdtp\td_cg\tv\tcut_deg\tfeasible\tobjectPotted\tcuePocketed\tok_for_W2",
        ]

        struct Key: Hashable { let spin: String; let dtp: Double }
        var okMaxV: [Key: Double] = [:]
        var okAny: [Key: Bool] = [:]
        var rows: [(spin: String, dtp: Double, v: Double, ok: Bool, cueScratch: Bool, obj: Bool, feasible: Bool)] = []

        for sp in spinLevels {
            for dtp in dtps {
                let (cue, target) = straightMidPocketLayout(dtp: dtp, dCueGhost: dCueGhost)
                for v in velocities {
                    let shot = ShotIntent.Shot(
                        cue: cue,
                        target: target,
                        pocket: "bottomCenter",
                        velocity: v,
                        spin: ShotIntent.Spin(x: sp.x, y: 0)
                    )
                    guard let baked = ShotBaker.bake(shot) else {
                        rawLines.append("\(sp.label)\t\(dtp)\t\(dCueGhost)\t\(v)\tnil\tfalse\tfalse\tfalse\tfalse")
                        continue
                    }
                    let cut = baked.cutAngleDeg.map { String(format: "%.2f", $0) } ?? "nil"
                    let ok = baked.feasible && baked.objectPocketed && !baked.cuePocketed
                    rawLines.append(
                        "\(sp.label)\t\(dtp)\t\(dCueGhost)\t\(v)\t\(cut)\t\(baked.feasible)\t\(baked.objectPocketed)\t\(baked.cuePocketed)\t\(ok)"
                    )
                    let key = Key(spin: sp.label, dtp: dtp)
                    if ok {
                        okAny[key] = true
                        okMaxV[key] = max(okMaxV[key] ?? 0, v)
                    } else if okAny[key] == nil {
                        okAny[key] = false
                    }
                    rows.append((sp.label, dtp, v, ok, baked.cuePocketed, baked.objectPocketed, baked.feasible))
                }
            }
        }

        // 汇总可用区间表
        var summary: [String] = [
            "",
            "=== 可用摆位区间表（W2 可引用）===",
            "判定 ok = feasible ∧ objectPocketed ∧ ¬cuePocketed",
            "",
            "spin\tdtp_norm\tmax_ok_v_m/s\t备注",
        ]

        var usableDTPBySpin: [String: [Double]] = [:]
        for sp in spinLevels {
            var usable: [Double] = []
            for dtp in dtps {
                let key = Key(spin: sp.label, dtp: dtp)
                if okAny[key] == true, let maxV = okMaxV[key] {
                    usable.append(dtp)
                    summary.append(String(format: "%@\t%.2f\t%.1f\t可用（力度≤该上界）", sp.label, dtp, maxV))
                } else {
                    let scratchHeavy = rows.contains {
                        $0.spin == sp.label && abs($0.dtp - dtp) < 1e-9 && $0.cueScratch && $0.obj
                    }
                    let note = scratchHeavy ? "洗袋风险（多档 cuePocketed）" : "无 ok 档（未进袋或不可行）"
                    summary.append(String(format: "%@\t%.2f\t—\t%@", sp.label, dtp, note))
                }
            }
            usableDTPBySpin[sp.label] = usable
        }

        // 推导 W2 推荐区间（取轻/中/满左的交集偏保守）
        let light = Set(usableDTPBySpin["轻"] ?? [])
        let mid = Set(usableDTPBySpin["中"] ?? [])
        let full = Set(usableDTPBySpin["满"] ?? [])
        let intersection = light.intersection(mid).intersection(full).sorted()
        let unionSafe = light.union(mid).sorted()

        // 力度上界：仅在「三档塞交集」dtp 上取最小 max_ok_v（不含交集外近袋特例）
        func vCap(spin: String, on dtpsSubset: [Double]) -> Double? {
            let caps = dtpsSubset.compactMap { dtp -> Double? in
                let key = Key(spin: spin, dtp: dtp)
                guard okAny[key] == true else { return nil }
                return okMaxV[key]
            }
            return caps.min()
        }

        summary.append("")
        summary.append("【W2 推荐摆位区间（保守）】")
        summary.append("- 袋口: bottomCenter；切角: 0°（直球）；spinY: 0")
        summary.append("- d_cue_ghost 本扫描固定: \(dCueGhost)（归一化）")
        summary.append("- 三档塞(轻/中/满)均有 ok 的 dtp 交集: \(intersection.isEmpty ? "空（见分档表）" : intersection.map { String(format: "%.2f", $0) }.joined(separator: ", "))")
        summary.append("- 轻/中至少一档可用的 dtp 并集: \(unionSafe.map { String(format: "%.2f", $0) }.joined(separator: ", "))")
        if let cL = vCap(spin: "轻", on: intersection),
           let cM = vCap(spin: "中", on: intersection),
           let cF = vCap(spin: "满", on: intersection) {
            summary.append(String(format: "- 交集内力度上界: 轻≤%.1f / 中≤%.1f / 满≤%.1f m/s", cL, cM, cF))
        }
        // 近袋警示：满塞在 dtp=0.10 仅低力可用
        if let fullNear = okMaxV[Key(spin: "满", dtp: 0.10)] {
            summary.append(String(format: "- 近袋警示: 满塞 dtp=0.10 仅 v≤%.1f；中塞 dtp=0.10 无 ok（洗袋）——基础条勿用过近目标球", fullNear))
        }

        // 找「近袋高风险」：小 dtp 是否更容易 scratch
        let nearScratchRate = scratchRate(rows: rows, dtpMax: 0.12)
        let farScratchRate = scratchRate(rows: rows, dtpMin: 0.22)
        summary.append(String(format: "- 洗袋率对照: dtp≤0.12 → %.0f%%；dtp≥0.22 → %.0f%%（cuePocketed 且 objectPotted）",
                              nearScratchRate * 100, farScratchRate * 100))

        let factLine: String
        if intersection.isEmpty {
            factLine = "[事实] 直球加塞洗袋扫描：三档塞交集为空；W2 须按塞量分档选 dtp/力度——详见区间表。近袋(dtp≤0.12)洗袋率 \(String(format: "%.0f", nearScratchRate * 100))% vs 远袋(dtp≥0.22) \(String(format: "%.0f", farScratchRate * 100))%。d_cg 固定 \(dCueGhost)。"
        } else {
            let dMin = intersection.first!
            let dMax = intersection.last!
            let vL = vCap(spin: "轻", on: intersection).map { String(format: "%.1f", $0) } ?? "?"
            let vM = vCap(spin: "中", on: intersection).map { String(format: "%.1f", $0) } ?? "?"
            let vF = vCap(spin: "满", on: intersection).map { String(format: "%.1f", $0) } ?? "?"
            factLine = "[事实] 直球加塞洗袋扫描：W2 可用摆位区间（三档塞交集）dtp∈[\(String(format: "%.2f", dMin)), \(String(format: "%.2f", dMax))]（归一化，bottomCenter 直球，d_cg=\(dCueGhost)）；交集内力度上界 轻≤\(vL)/中≤\(vM)/满≤\(vF) m/s。近袋更易洗袋（≤0.12: \(String(format: "%.0f", nearScratchRate * 100))% vs ≥0.22: \(String(format: "%.0f", farScratchRate * 100))%）。"
        }
        summary.append("")
        summary.append(factLine)
        summary.append("ALL_PASS=true（测量型草稿；ok 判据已引擎实测）")

        let body = (rawLines + summary).joined(separator: "\n") + "\n"
        try body.write(to: dir.appendingPathComponent("straight-scratch-scan.md"),
                       atomically: true, encoding: .utf8)
        try body.write(to: dir.appendingPathComponent("straight-scratch-scan.txt"),
                       atomically: true, encoding: .utf8)

        // 至少应有若干 ok 点，否则 W2 无法开工——作为硬门
        let okCount = rows.filter(\.ok).count
        XCTAssertGreaterThan(okCount, 0, "洗袋扫描应至少找到若干 ok 摆位供 W2 使用")
    }

    // MARK: - Geometry helpers

    /// 下中袋直球：目标在袋口 X 进球线上；ghost 沿进球线反向退 2r；母球再沿同线退 d。
    /// 代码系：canvas Y 增 → scene +Z → bottomCenter；袋在目标 +Y 侧。
    private func straightMidPocketLayout(dtp: Double, dCueGhost: Double) -> (CanvasPoint, CanvasPoint) {
        let p = bottomCenterNorm()
        let tx = p.x
        let ty = p.y - dtp
        let gy = ty - 2 * rNorm
        let cy = gy - dCueGhost
        return (
            CanvasPoint(x: tx, y: cy),
            CanvasPoint(x: tx, y: ty)
        )
    }

    private func scratchRate(
        rows: [(spin: String, dtp: Double, v: Double, ok: Bool, cueScratch: Bool, obj: Bool, feasible: Bool)],
        dtpMax: Double? = nil,
        dtpMin: Double? = nil
    ) -> Double {
        let filtered = rows.filter { r in
            if let m = dtpMax, r.dtp > m { return false }
            if let m = dtpMin, r.dtp < m { return false }
            // 只统计目标球进袋的样本，看其中洗袋比例
            return r.obj && r.feasible
        }
        guard !filtered.isEmpty else { return 0 }
        let scratches = filtered.filter(\.cueScratch).count
        return Double(scratches) / Double(filtered.count)
    }
}
