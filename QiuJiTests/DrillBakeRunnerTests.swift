//
//  DrillBakeRunnerTests.swift
//  QiuJiTests
//
//  动作库烘焙跑测（P10 物理升级 · 内容管线雏形，ADR-P10-01）。
//
//  作用有二：
//  1. **离线烘焙管线的命令行载体**：把试点 Drill 的「击球意图」(`shotIntent`) 喂给
//     `ShotBaker` → 物理引擎，打印回填用的 `DrillAnimation` JSON（在 BAKE 标记之间），
//     供人工拷回 Drill JSON 的 `animation` 字段（source = "baked"）。
//  2. **物理可达校验 + 回归**：断言每条试点 Drill 几何可进（feasible），并打印
//     校验报告行（feasible / 真实模拟进选定袋 / 切球角），对接 H-11 人工核查。
//
//  运行：
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
//      -only-testing:QiuJiTests/DrillBakeRunnerTests
//

import XCTest
@testable import QiuJi

final class DrillBakeRunnerTests: XCTestCase {

    /// 试点 Drill（多类别覆盖：准度直线/斜角、走位一库、杆法定杆、分离角）。
    private let pilotDrillIds = [
        "drill_c001",  // accuracy · 直线 · bottomCenter
        "drill_c002",  // accuracy · 斜角 · bottomRight
        "drill_c005",  // positioning · 一库走位 · bottomRight
        "drill_c014",  // cueAction · 定杆 · bottomCenter
        "drill_c024",  // separation · 90°规则 · topRight
        "drill_c053",  // accuracy · 中袋角度 A1 代表性球形 · bottomCenter（B4）
    ]

    /// 端到端：从 Bundle 读取试点 Drill 的 `shotIntent` → 烘焙 → 断言可进 + 打印回填 JSON。
    func test_bakePilotDrills_areFeasibleAndPrintBakedAnimation() async throws {
        var reportRows: [String] = []
        reportRows.append("| Drill | shot | feasible | sim进选定袋 | 切球角° | 母球进袋 |")
        reportRows.append("|-------|------|----------|-------------|---------|----------|")

        for id in pilotDrillIds {
            guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: id) else {
                XCTFail("无法从 Bundle 加载试点 Drill：\(id)")
                continue
            }
            guard let intent = drill.shotIntent else {
                XCTFail("\(id) 缺少 shotIntent（请先在 JSON 中标注击球意图）")
                continue
            }

            for (i, shot) in intent.shots.enumerated() {
                guard let result = ShotBaker.bake(shot) else {
                    XCTFail("\(id) shot[\(i)] 选袋 ID 非法：\(shot.pocket)")
                    continue
                }

                XCTAssertTrue(
                    result.feasible,
                    "\(id) shot[\(i)] 几何不可进：\(result.infeasibleReason)"
                )

                let cut = result.cutAngleDeg.map { String(format: "%.1f", $0) } ?? "—"
                reportRows.append(
                    "| \(id) | \(i) | \(result.feasible ? "✅" : "❌") "
                    + "| \(result.simObjectPotted ? "✅" : "⚠️") | \(cut) "
                    + "| \(result.cuePocketed ? "⚠️是" : "否") |"
                )

                // 打印回填用的烘焙动画 JSON（拷回 Drill JSON 的 animation 字段）。
                printBakedAnimation(id: id, shotIndex: i, animation: result.animation)
            }
        }

        // 打印汇总校验报告（拷入 tasks/qa-reports/DRILL-BAKE-REPORT.md）。
        print("\n===BAKE-REPORT===")
        reportRows.forEach { print($0) }
        print("===END-REPORT===\n")
    }

    // MARK: - Helpers

    private func printBakedAnimation(id: String, shotIndex: Int, animation: DrillAnimation) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(animation),
              let json = String(data: data, encoding: .utf8) else {
            print("⚠️ 编码烘焙动画失败：\(id) shot[\(shotIndex)]")
            return
        }
        print("\n===BAKE \(id) shot=\(shotIndex)===")
        print(json)
        print("===END \(id)===")
    }
}
