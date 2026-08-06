import XCTest
import SceneKit
@testable import QiuJi

/// v21 W4：c016/c018/c020/c021 全球形烘焙 + 代表性 animation 回填 + 日志落盘。
///
/// 坐标契约：AngleSceneCalculator 归一化；角度球 bottomCenter；
/// 与 `scripts/v21_w4_r4_coords.py` 同源。
/// 闸门：每球形 `feasible ∧ objectPocketed ∧ ¬cuePocketed`。
final class V21W4BakeTests: XCTestCase {

    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var logDir: URL { root.appendingPathComponent("build/v21-w4-logs", isDirectory: true) }
    private var evidenceDir: URL { root.appendingPathComponent("build/v21-w4-evidence", isDirectory: true) }

    private struct FormSpec {
        let drillId: String
        let formId: String
        let cue: CanvasPoint
        let target: CanvasPoint
        let spinX: Double
        let spinY: Double
        let velocity: Double
        let cutAngleDeg: Double
        let representative: Bool
    }

    /// 与 `scripts/v21_w4_r4_coords.py` 同源（袋口代码真源 y≈0.5209）。
    private func allForms() -> [FormSpec] {
        let pocket = bottomCenterNorm()
        let r = Double(BallPhysics.radius) / Double(AngleSceneCalculator.innerLength)
        let twoR = 2 * r

        func layout(theta: Double, cutSide: String, dtp: Double, d: Double) -> (CanvasPoint, CanvasPoint) {
            let tx = 0.5
            let ty = pocket.y - dtp
            let vx = 0.0, vy = 1.0
            let gx = tx - twoR * vx
            let gy = ty - twoR * vy
            let sign = cutSide == "R" ? 1.0 : -1.0
            let a = theta * .pi / 180.0 * sign
            let hx = vx * cos(a) - vy * sin(a)
            let hy = vx * sin(a) + vy * cos(a)
            let cx = gx - d * hx
            let cy = gy - d * hy
            return (CanvasPoint(x: cx, y: cy), CanvasPoint(x: tx, y: ty))
        }

        var out: [FormSpec] = []

        // c016 — 斯登：θ∈{20,30,40,45}，spin=(0,0)
        let c016: [(String, Double, String, Double, Double, Double, Bool)] = [
            ("A1", 20, "R", 0.18, 0.22, 3.0, true),
            ("A2", 30, "L", 0.18, 0.24, 3.0, false),
            ("A3", 40, "R", 0.16, 0.24, 3.2, false),
            ("A4", 45, "L", 0.15, 0.26, 3.2, false),
        ]
        for (id, th, cut, dtp, d, v, rep) in c016 {
            let (c, t) = layout(theta: th, cutSide: cut, dtp: dtp, d: d)
            out.append(FormSpec(drillId: "drill_c016", formId: id, cue: c, target: t,
                                spinX: 0, spinY: 0, velocity: v, cutAngleDeg: th, representative: rep))
        }

        // c018 — side×轻/中/满；θ=28°
        let c018: [(String, String, Double, Double, Bool)] = [
            ("A1", "R", +0.15, 3.0, true),
            ("A2", "L", -0.15, 3.0, false),
            ("A3", "R", +0.30, 3.3, false),
            ("A4", "L", -0.30, 3.3, false),
            ("A5", "R", +0.50, 3.5, false),
            ("A6", "L", -0.50, 3.5, false),
        ]
        for (id, cut, sx, v, rep) in c018 {
            let (c, t) = layout(theta: 28, cutSide: cut, dtp: 0.18, d: 0.22)
            out.append(FormSpec(drillId: "drill_c018", formId: id, cue: c, target: t,
                                spinX: sx, spinY: 0, velocity: v, cutAngleDeg: 28, representative: rep))
        }

        // c020 — 组合×切角；左塞+高杆（大切角 dtp=0.20/v=3.0 避洗袋）
        let c020: [(String, Double, Double, Double, Double, Double, Bool)] = [
            ("A1", 22, 0.18, 0.24, +0.25, +0.40, true),
            ("A2", 22, 0.18, 0.24, +0.40, +0.25, false),
            ("A3", 36, 0.20, 0.24, +0.25, +0.40, false),
            ("A4", 36, 0.20, 0.24, +0.40, +0.25, false),
        ]
        for (id, th, dtp, d, sx, sy, rep) in c020 {
            let (c, t) = layout(theta: th, cutSide: "R", dtp: dtp, d: d)
            let v = th >= 36 ? 3.0 : 3.2
            out.append(FormSpec(drillId: "drill_c020", formId: id, cue: c, target: t,
                                spinX: sx, spinY: sy, velocity: v, cutAngleDeg: th, representative: rep))
        }

        // c021 — 组合×切角；右塞+低杆
        let c021: [(String, Double, Double, Double, Bool)] = [
            ("A1", 25, -0.25, -0.40, true),
            ("A2", 25, -0.40, -0.25, false),
            ("A3", 40, -0.25, -0.40, false),
            ("A4", 40, -0.40, -0.25, false),
        ]
        for (id, th, sx, sy, rep) in c021 {
            let (c, t) = layout(theta: th, cutSide: "L", dtp: 0.16, d: 0.25)
            out.append(FormSpec(drillId: "drill_c021", formId: id, cue: c, target: t,
                                spinX: sx, spinY: sy, velocity: 3.8, cutAngleDeg: th, representative: rep))
        }

        return out
    }

    private func bottomCenterNorm() -> (x: Double, y: Double) {
        let y = BTTablePhysics.surfaceY
        let p = AngleSceneCalculator.pocketPositions(surfaceY: y)[5]
        let n = AngleSceneCalculator.sceneToNormalized(position: p)
        return (Double(n.x), Double(n.y))
    }

    func testW4_bakeAllFormations_andPatchRepresentativeAnimation() throws {
        try BakeRunnerGate.skipUnlessEnabled("testW4_bakeAllFormations_andPatchRepresentativeAnimation")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: evidenceDir, withIntermediateDirectories: true)

        let pocket = bottomCenterNorm()
        var lines: [String] = [
            "=== v21 W4 bake ===",
            "日期: 2026-07-28",
            String(format: "pocket_code_truth=(%.4f, %.4f)", pocket.x, pocket.y),
            "闸门: feasible ∧ objectPocketed ∧ ¬cuePocketed",
            "",
            "drill\tform\tθ\tspinX\tspinY\tv\tcutMeas\tfeasible\tobj\tcueP\tok",
        ]

        var failures: [String] = []
        var repAnimations: [String: DrillAnimation] = [:]
        var bakeRows: [[String: Any]] = []

        for form in allForms() {
            let shot = ShotIntent.Shot(
                cue: form.cue,
                target: form.target,
                pocket: "bottomCenter",
                velocity: form.velocity,
                spin: ShotIntent.Spin(x: form.spinX, y: form.spinY)
            )
            guard let baked = ShotBaker.bake(shot) else {
                failures.append("\(form.drillId)/\(form.formId): bake nil")
                lines.append(
                    "\(form.drillId)\t\(form.formId)\t\(Int(form.cutAngleDeg))\t"
                    + "\(form.spinX)\t\(form.spinY)\t\(form.velocity)\tnil\tfalse\tfalse\tfalse\tfalse"
                )
                continue
            }
            let ok = baked.feasible && baked.objectPocketed && !baked.cuePocketed
            let cut = baked.cutAngleDeg.map { String(format: "%.2f", $0) } ?? "nil"
            lines.append(
                "\(form.drillId)\t\(form.formId)\t\(Int(form.cutAngleDeg))\t"
                + "\(String(format: "%+.2f", form.spinX))\t\(String(format: "%+.2f", form.spinY))\t"
                + "\(form.velocity)\t\(cut)\t"
                + "\(baked.feasible)\t\(baked.objectPocketed)\t\(baked.cuePocketed)\t\(ok)"
            )
            print(
                "===BAKE=== \(form.drillId) \(form.formId) "
                + "feasible=\(baked.feasible ? "✅" : "❌") "
                + "objectPocketed=\(baked.objectPocketed) "
                + "cuePocketed=\(baked.cuePocketed)"
            )
            bakeRows.append([
                "drillId": form.drillId,
                "formId": form.formId,
                "theta": form.cutAngleDeg,
                "spinX": form.spinX,
                "spinY": form.spinY,
                "velocity": form.velocity,
                "feasible": baked.feasible,
                "objectPocketed": baked.objectPocketed,
                "cuePocketed": baked.cuePocketed,
                "ok": ok,
                "cutAngleDeg": baked.cutAngleDeg as Any,
                "infeasibleReason": baked.infeasibleReason as Any,
            ])
            if form.representative {
                repAnimations[form.drillId] = baked.animation
                let enc = JSONEncoder()
                enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                if let data = try? enc.encode(baked.animation) {
                    try? data.write(to: logDir.appendingPathComponent("\(form.drillId)-rep-animation.json"))
                }
            }
            if !ok {
                failures.append(
                    "\(form.drillId)/\(form.formId): feasible=\(baked.feasible) "
                    + "obj=\(baked.objectPocketed) cueP=\(baked.cuePocketed) reason=\(baked.infeasibleReason)"
                )
            }
        }

        lines.append("")
        lines.append(failures.isEmpty ? "ALL_OK=true" : "ALL_OK=false")
        lines.append("failures=\(failures.count)")
        for f in failures { lines.append("FAIL \(f)") }

        let report = lines.joined(separator: "\n") + "\n"
        try report.write(to: logDir.appendingPathComponent("bake-all-formations.txt"),
                         atomically: true, encoding: .utf8)
        let evData = try JSONSerialization.data(withJSONObject: bakeRows, options: [.prettyPrinted, .sortedKeys])
        try evData.write(to: evidenceDir.appendingPathComponent("bake-table.json"))
        print(report)

        for (drillId, animation) in repAnimations {
            try patchAnimation(drillId: drillId, animation: animation)
        }

        XCTAssertTrue(failures.isEmpty, "烘焙未过闸门：\n\(failures.joined(separator: "\n"))")
        XCTAssertEqual(repAnimations.count, 4, "应有 4 条代表性球形 animation")
    }

    @MainActor
    func testW4_bakeThumbnailsForR4Drills() async throws {
        try BakeRunnerGate.skipUnlessEnabled("testW4_bakeThumbnailsForR4Drills")
        let outDir = root.appendingPathComponent("QiuJi/Resources/DrillThumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        var lines: [String] = ["=== v21 W4 thumbnail bake ==="]
        var failed: [String] = []
        for id in ["drill_c016", "drill_c018", "drill_c020", "drill_c021"] {
            guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: id) else {
                failed.append("\(id)(load)"); continue
            }
            guard let image = DrillThumbnailRenderer.render(drill: drill),
                  let png = image.pngData(), png.count > 4_000 else {
                failed.append("\(id)(render)"); continue
            }
            let path = outDir.appendingPathComponent("\(id).png")
            try png.write(to: path)
            lines.append("OK \(id) bytes=\(png.count) → \(path.path)")
            print("THUMB \(id) \(png.count) bytes")
        }
        lines.append(failed.isEmpty ? "ALL_OK=true" : "ALL_OK=false failures=\(failed)")
        try lines.joined(separator: "\n").write(
            to: logDir.appendingPathComponent("thumbnail-bake.txt"),
            atomically: true, encoding: .utf8
        )
        XCTAssertTrue(failed.isEmpty, "缩略图失败：\(failed)")
    }

    private func patchAnimation(drillId: String, animation: DrillAnimation) throws {
        let path = root
            .appendingPathComponent("QiuJi/Resources/Drills/cueAction/\(drillId).json")
        var rootObj = try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as! [String: Any]
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let animData = try enc.encode(animation)
        let animObj = try JSONSerialization.jsonObject(with: animData)
        rootObj["animation"] = animObj
        let out = try JSONSerialization.data(withJSONObject: rootObj, options: [.prettyPrinted, .sortedKeys])
        var text = String(data: out, encoding: .utf8)! + "\n"
        text = text.replacingOccurrences(of: "\\/", with: "/")
        try text.write(to: path, atomically: true, encoding: .utf8)
        print("patched animation → \(path.path)")
    }
}
