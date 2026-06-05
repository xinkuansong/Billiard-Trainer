//
//  DrillThumbnailBakeRunnerTests.swift
//  QiuJiTests
//
//  动作库缩略图离线烘焙跑测（P10 物理升级 · USDZ 2D 顶视缩略图）。
//
//  作用：把 Drill 的 `animation`（烘焙/手画轨迹）用 `DrillThumbnailRenderer` 渲染成
//  「USDZ 球桌 2D 顶视」缩略图 PNG，写入 build/drill_thumbs/ 并作为附件，供拷入
//  `QiuJi/Resources/DrillThumbnails/<id>.png`（运行时零成本静态图）。
//
//  运行：
//    xcodebuild test -scheme QiuJi \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:QiuJiTests/DrillThumbnailBakeRunnerTests
//

import XCTest
import UIKit
@testable import QiuJi

final class DrillThumbnailBakeRunnerTests: XCTestCase {

    /// 直接写入 App 资源目录（运行时随 Bundle 打包，需在 project 中作为 folder ref）。
    private let outputDir = "/Users/song/projects/13.billiard_trainer/QiuJi/Resources/DrillThumbnails"

    /// 全量烘焙：遍历 index.allDrillIds，逐条渲染 USDZ 2D 顶视缩略图写入资源目录。
    @MainActor
    func test_bakeAllThumbnails() async throws {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        guard let index = await DrillContentService.shared.loadDrillIndex() else {
            XCTFail("无法加载 Drills/index.json")
            return
        }
        let ids = index.allDrillIds
        XCTAssertFalse(ids.isEmpty, "index.allDrillIds 为空")

        var ok = 0
        var failed: [String] = []
        for id in ids {
            guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: id) else {
                failed.append("\(id)(load)")
                continue
            }
            guard let image = DrillThumbnailRenderer.render(drill: drill),
                  let png = image.pngData(), png.count > 4_000 else {
                failed.append("\(id)(render)")
                continue
            }
            let path = "\(outputDir)/\(id).png"
            if (try? png.write(to: URL(fileURLWithPath: path))) != nil {
                ok += 1
            } else {
                failed.append("\(id)(write)")
            }
        }

        print("THUMB-BAKE done: \(ok)/\(ids.count) written to \(outputDir)")
        if !failed.isEmpty { print("THUMB-BAKE failures: \(failed.joined(separator: ", "))") }
        XCTAssertTrue(failed.isEmpty, "缩略图烘焙失败：\(failed.joined(separator: ", "))")
    }

    /// 物理可行性扫描：对每条 Drill 解析 ShotInput → ShotPredictor.predict，打印
    /// `feasible / cut角 / 目标球是否进选定袋`，便于挑出退回手画轨迹的 Drill。不作断言。
    @MainActor
    func test_scanFeasibility() async throws {
        guard let index = await DrillContentService.shared.loadDrillIndex() else {
            XCTFail("无法加载 Drills/index.json"); return
        }
        let surfaceY = TablePhysics.tableSurfaceY
        var infeasible: [String] = []
        var notPotted: [String] = []
        for id in index.allDrillIds {
            guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: id) else {
                print("FEAS \(id) LOAD-FAIL"); continue
            }
            guard let input = DrillShotResolver.shotInput(for: drill, surfaceY: surfaceY) else {
                print("FEAS \(id) NO-INPUT (bad pocket)"); infeasible.append(id); continue
            }
            let p = ShotPredictor.predict(input)
            let cut = p.cutAngleDeg.map { String(format: "%.1f", $0) } ?? "-"
            let hasIntent = drill.shotIntent != nil
            print("FEAS \(id) feasible=\(p.feasible) potted=\(p.simObjectPotted) cut=\(cut) intent=\(hasIntent) reason=\(p.infeasibleReason)")
            if !p.feasible { infeasible.append(id) }
            if !p.simObjectPotted { notPotted.append(id) }
        }
        print("FEAS-SUMMARY infeasible(\(infeasible.count)): \(infeasible.joined(separator: ", "))")
        print("FEAS-SUMMARY notPotted(\(notPotted.count)): \(notPotted.joined(separator: ", "))")
    }
}
