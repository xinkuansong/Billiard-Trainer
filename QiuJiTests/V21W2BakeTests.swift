import XCTest
import SceneKit
@testable import QiuJi

/// v21 W2：c073/c074/c075 全球形烘焙 + 代表性 animation 回填 + 日志落盘。
///
/// 坐标契约：AngleSceneCalculator 归一化；直球 bottomCenter；spinY=0。
/// 闸门：每球形 `feasible ∧ objectPocketed ∧ ¬cuePocketed`。
final class V21W2BakeTests: XCTestCase {

    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var logDir: URL { root.appendingPathComponent("build/v21-w2-logs", isDirectory: true) }

    private struct FormSpec {
        let drillId: String
        let formId: String
        let cue: CanvasPoint
        let target: CanvasPoint
        let spinX: Double
        let velocity: Double
        let representative: Bool
    }

    /// 与 `scripts/v21_w2_straight_spin_coords.py` 同源（袋口代码真源 y=0.5209）。
    private func allForms() -> [FormSpec] {
        let pocketY = bottomCenterNorm().y
        let r = Double(BallPhysics.radius) / Double(AngleSceneCalculator.innerLength)
        func layout(dtp: Double, d: Double) -> (CanvasPoint, CanvasPoint) {
            let ty = pocketY - dtp
            let cy = ty - 2 * r - d
            return (CanvasPoint(x: 0.5, y: cy), CanvasPoint(x: 0.5, y: ty))
        }

        var out: [FormSpec] = []
        // c073 — 近段 d=0.18/0.22；力度避开 W1 中塞洗袋带
        let c073: [(String, Double, Double, Double, Double, Bool)] = [
            ("A1", +0.30, 0.22, 0.18, 3.0, true),
            ("A2", -0.30, 0.22, 0.18, 3.5, false),
            ("A3", +0.30, 0.22, 0.22, 3.0, false),
            ("A4", -0.30, 0.22, 0.22, 3.5, false),
        ]
        for (id, sx, dtp, d, v, rep) in c073 {
            let (c, t) = layout(dtp: dtp, d: d)
            out.append(FormSpec(drillId: "drill_c073", formId: id, cue: c, target: t,
                                spinX: sx, velocity: v, representative: rep))
        }
        // c074 — 中距 d=0.22；长距 d=0.28
        let c074: [(String, Double, Double, Double, Double, Bool)] = [
            ("A1", +0.30, 0.22, 0.22, 3.5, true),
            ("A2", -0.30, 0.22, 0.22, 3.5, false),
            ("A3", +0.30, 0.15, 0.28, 5.0, false),
            ("A4", -0.30, 0.15, 0.28, 5.0, false),
        ]
        for (id, sx, dtp, d, v, rep) in c074 {
            let (c, t) = layout(dtp: dtp, d: d)
            out.append(FormSpec(drillId: "drill_c074", formId: id, cue: c, target: t,
                                spinX: sx, velocity: v, representative: rep))
        }
        // c075 — d=0.22；满塞 v=3.5 避开 2.0–2.5 洗袋带
        let c075: [(String, Double, Double, Double, Double, Bool)] = [
            ("A1", +0.15, 0.22, 0.22, 3.0, true),
            ("A2", -0.15, 0.22, 0.22, 3.5, false),
            ("A3", +0.30, 0.22, 0.22, 3.0, false),
            ("A4", -0.30, 0.22, 0.22, 3.5, false),
            ("A5", +0.50, 0.22, 0.22, 3.5, false),
            ("A6", -0.50, 0.22, 0.22, 3.5, false),
        ]
        for (id, sx, dtp, d, v, rep) in c075 {
            let (c, t) = layout(dtp: dtp, d: d)
            out.append(FormSpec(drillId: "drill_c075", formId: id, cue: c, target: t,
                                spinX: sx, velocity: v, representative: rep))
        }
        return out
    }

    private func bottomCenterNorm() -> (x: Double, y: Double) {
        let y = BTTablePhysics.surfaceY
        let p = AngleSceneCalculator.pocketPositions(surfaceY: y)[5]
        let n = AngleSceneCalculator.sceneToNormalized(position: p)
        return (Double(n.x), Double(n.y))
    }

    func testW2_bakeAllFormations_andPatchRepresentativeAnimation() throws {
        try BakeRunnerGate.skipUnlessEnabled("testW2_bakeAllFormations_andPatchRepresentativeAnimation")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

        let pocket = bottomCenterNorm()
        var lines: [String] = [
            "=== v21 W2 bake ===",
            "日期: 2026-07-28",
            String(format: "pocket_code_truth=(%.4f, %.4f)", pocket.x, pocket.y),
            "闸门: feasible ∧ objectPocketed ∧ ¬cuePocketed",
            "",
            "drill\tform\tspinX\tv\tcut\tfeasible\tobj\tcueP\tok",
        ]

        var failures: [String] = []
        var repAnimations: [String: DrillAnimation] = [:]

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
                lines.append("\(form.drillId)\t\(form.formId)\t\(form.spinX)\t\(form.velocity)\tnil\tfalse\tfalse\tfalse\tfalse")
                continue
            }
            let ok = baked.feasible && baked.objectPocketed && !baked.cuePocketed
            let cut = baked.cutAngleDeg.map { String(format: "%.2f", $0) } ?? "nil"
            lines.append(
                "\(form.drillId)\t\(form.formId)\t\(String(format: "%+.2f", form.spinX))\t\(form.velocity)\t\(cut)\t"
                + "\(baked.feasible)\t\(baked.objectPocketed)\t\(baked.cuePocketed)\t\(ok)"
            )
            print(
                "===BAKE=== \(form.drillId) \(form.formId) "
                + "feasible=\(baked.feasible ? "✅" : "❌") "
                + "objectPocketed=\(baked.objectPocketed) "
                + "cuePocketed=\(baked.cuePocketed)"
            )
            if form.representative {
                repAnimations[form.drillId] = baked.animation
                let enc = JSONEncoder()
                enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                if let data = try? enc.encode(baked.animation),
                   let json = String(data: data, encoding: .utf8) {
                    print("===BAKE \(form.drillId) shot=0===")
                    print(json)
                    print("===END \(form.drillId)===")
                    let animPath = logDir.appendingPathComponent("\(form.drillId)-rep-animation.json")
                    try? data.write(to: animPath)
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
        print(report)

        // Patch representative animations into drill JSON on disk
        for (drillId, animation) in repAnimations {
            try patchAnimation(drillId: drillId, animation: animation)
        }

        XCTAssertTrue(failures.isEmpty, "烘焙未过闸门：\n\(failures.joined(separator: "\n"))")
        XCTAssertEqual(repAnimations.count, 3, "应有 3 条代表性球形 animation")
    }

    /// 仅烘焙 c073/c074/c075 缩略图（不全量 75）。
    @MainActor
    func testW2_bakeThumbnailsForNewDrills() async throws {
        try BakeRunnerGate.skipUnlessEnabled("testW2_bakeThumbnailsForNewDrills")
        let outDir = root.appendingPathComponent("QiuJi/Resources/DrillThumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        var lines: [String] = ["=== v21 W2 thumbnail bake ==="]
        var failed: [String] = []
        for id in ["drill_c073", "drill_c074", "drill_c075"] {
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
        // Keep trailing newline; use UTF-8 without escaping slashes if possible
        var text = String(data: out, encoding: .utf8)! + "\n"
        text = text.replacingOccurrences(of: "\\/", with: "/")
        try text.write(to: path, atomically: true, encoding: .utf8)
        print("patched animation → \(path.path)")
    }
}
