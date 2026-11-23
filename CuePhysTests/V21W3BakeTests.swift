import XCTest
import SceneKit
@testable import QiuJi

/// v21 W3：c076/c077/c078 全球形烘焙 + 代表性 animation 回填 + 日志落盘。
///
/// 坐标契约：AngleSceneCalculator 归一化；角度球 bottomCenter；
/// 顺塞=切向同侧塞 / 反塞=异侧塞；spinY=0。
/// 闸门：每球形 `feasible ∧ objectPocketed ∧ ¬cuePocketed`。
final class V21W3BakeTests: XCTestCase {

    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var logDir: URL { root.appendingPathComponent("build/v21-w3-logs", isDirectory: true) }
    private var evidenceDir: URL { root.appendingPathComponent("build/v21-w3-evidence", isDirectory: true) }

    private struct FormSpec {
        let drillId: String
        let formId: String
        let cue: CanvasPoint
        let target: CanvasPoint
        let spinX: Double
        let velocity: Double
        let cutAngleDeg: Double
        let cutSide: String
        let spinKind: String
        let representative: Bool
    }

    /// 与 `scripts/v21_w3_angle_spin_coords.py` 同源（袋口代码真源 y≈0.5209）。
    private func allForms() -> [FormSpec] {
        let pocket = bottomCenterNorm()
        let r = Double(BallPhysics.radius) / Double(AngleSceneCalculator.innerLength)
        let twoR = 2 * r

        func layout(theta: Double, cutSide: String, dtp: Double, d: Double) -> (CanvasPoint, CanvasPoint) {
            let tx = 0.5
            let ty = pocket.y - dtp
            let vx = 0.0, vy = 1.0  // 进球线垂直入下中袋
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

        func spinX(cutSide: String, kind: String) -> Double {
            if kind == "none" { return 0 }
            let same = kind == "running"
            if cutSide == "L" { return same ? +0.30 : -0.30 }
            return same ? -0.30 : +0.30
        }

        // (id, θ, cut, kind, dtp, d, v, rep)
        let c076: [(String, Double, String, String, Double, Double, Double, Bool)] = [
            ("A1", 15, "R", "running", 0.20, 0.22, 3.0, true),
            ("A2", 15, "R", "reverse", 0.20, 0.22, 3.0, false),
            ("A3", 15, "L", "running", 0.20, 0.22, 3.5, false),
            ("A4", 30, "L", "running", 0.18, 0.22, 3.0, false),
            ("A5", 30, "L", "reverse", 0.18, 0.22, 3.0, false),
            ("A6", 30, "R", "reverse", 0.20, 0.25, 3.5, false),
        ]
        let c077: [(String, Double, String, String, Double, Double, Double, Bool)] = [
            ("A1", 45, "R", "none", 0.18, 0.25, 3.0, true),
            ("A2", 45, "R", "running", 0.18, 0.25, 3.0, false),
            ("A3", 45, "R", "reverse", 0.18, 0.25, 3.0, false),
            ("A4", 45, "L", "none", 0.22, 0.28, 3.5, false),
            ("A5", 45, "L", "running", 0.22, 0.28, 3.5, false),
            ("A6", 45, "L", "reverse", 0.15, 0.28, 3.5, false),
        ]
        let c078: [(String, Double, String, String, Double, Double, Double, Bool)] = [
            ("A1", 15, "R", "running", 0.20, 0.25, 3.5, true),
            ("A2", 15, "R", "reverse", 0.20, 0.25, 3.5, false),
            ("A3", 15, "R", "running", 0.17, 0.28, 3.5, false),
            ("A4", 15, "R", "reverse", 0.17, 0.28, 3.0, false),
        ]

        var out: [FormSpec] = []
        for (drill, rows) in [("drill_c076", c076), ("drill_c077", c077), ("drill_c078", c078)] {
            for (id, th, cut, kind, dtp, d, v, rep) in rows {
                let (c, t) = layout(theta: th, cutSide: cut, dtp: dtp, d: d)
                out.append(FormSpec(
                    drillId: drill, formId: id, cue: c, target: t,
                    spinX: spinX(cutSide: cut, kind: kind), velocity: v,
                    cutAngleDeg: th, cutSide: cut, spinKind: kind, representative: rep
                ))
            }
        }
        return out
    }

    private func bottomCenterNorm() -> (x: Double, y: Double) {
        let y = BTTablePhysics.surfaceY
        let p = AngleSceneCalculator.pocketPositions(surfaceY: y)[5]
        let n = AngleSceneCalculator.sceneToNormalized(position: p)
        return (Double(n.x), Double(n.y))
    }

    func testW3_bakeAllFormations_andPatchRepresentativeAnimation() throws {
        try BakeRunnerGate.skipUnlessEnabled("testW3_bakeAllFormations_andPatchRepresentativeAnimation")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: evidenceDir, withIntermediateDirectories: true)

        let pocket = bottomCenterNorm()
        var lines: [String] = [
            "=== v21 W3 bake ===",
            "日期: 2026-07-28",
            String(format: "pocket_code_truth=(%.4f, %.4f)", pocket.x, pocket.y),
            "闸门: feasible ∧ objectPocketed ∧ ¬cuePocketed",
            "顺塞=切向同侧塞; 反塞=异侧塞",
            "",
            "drill\tform\tθ\tcut\tkind\tspinX\tv\tcutMeas\tfeasible\tobj\tcueP\tok",
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
                spin: ShotIntent.Spin(x: form.spinX, y: 0)
            )
            guard let baked = ShotBaker.bake(shot) else {
                failures.append("\(form.drillId)/\(form.formId): bake nil")
                lines.append(
                    "\(form.drillId)\t\(form.formId)\t\(Int(form.cutAngleDeg))\t\(form.cutSide)\t\(form.spinKind)\t"
                    + "\(form.spinX)\t\(form.velocity)\tnil\tfalse\tfalse\tfalse\tfalse"
                )
                continue
            }
            let ok = baked.feasible && baked.objectPocketed && !baked.cuePocketed
            let cut = baked.cutAngleDeg.map { String(format: "%.2f", $0) } ?? "nil"
            lines.append(
                "\(form.drillId)\t\(form.formId)\t\(Int(form.cutAngleDeg))\t\(form.cutSide)\t\(form.spinKind)\t"
                + "\(String(format: "%+.2f", form.spinX))\t\(form.velocity)\t\(cut)\t"
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
                "cutSide": form.cutSide,
                "spinKind": form.spinKind,
                "spinX": form.spinX,
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
        XCTAssertEqual(repAnimations.count, 3, "应有 3 条代表性球形 animation")
    }

    @MainActor
    func testW3_bakeThumbnailsForNewDrills() async throws {
        try BakeRunnerGate.skipUnlessEnabled("testW3_bakeThumbnailsForNewDrills")
        let outDir = root.appendingPathComponent("QiuJi/Resources/DrillThumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        var lines: [String] = ["=== v21 W3 thumbnail bake ==="]
        var failed: [String] = []
        for id in ["drill_c076", "drill_c077", "drill_c078"] {
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
            .appendingPathComponent("QiuJi/Resources/Drills/accuracy/\(drillId).json")
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
