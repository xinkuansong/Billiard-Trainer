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
//  运行：`cd scripts && make thumbnails`
//  （等价于 -only-testing:QiuJiTests/DrillThumbnailBakeRunnerTests + 开 BakeRunnerGate 门）。
//  v29 W1：不随常规全量测试跑（写 git 跟踪的资源目录），门见 `BakeRunnerGate`。
//

import XCTest
import UIKit
@testable import QiuJi

final class DrillThumbnailBakeRunnerTests: XCTestCase {

    func test_staleBakeGateFlag_isRejected() {
        let now = Date(timeIntervalSince1970: 10_000)
        XCTAssertTrue(
            BakeRunnerGate.isFresh(modifiedAt: now.addingTimeInterval(-BakeRunnerGate.flagMaximumAge), now: now)
        )
        XCTAssertFalse(
            BakeRunnerGate.isFresh(modifiedAt: now.addingTimeInterval(-BakeRunnerGate.flagMaximumAge - 1), now: now)
        )
        XCTAssertFalse(BakeRunnerGate.isFresh(modifiedAt: now.addingTimeInterval(1), now: now))
    }

    /// 直接写入 App 资源目录（运行时随 Bundle 打包，需在 project 中作为 folder ref）。
    /// 路径由 `QIUJI_THUMBNAIL_OUTPUT_DIR` 注入，缺省取本仓 `QiuJi/Resources/DrillThumbnails`
    /// （由 `#filePath` 推导，git worktree 下自动指向各自的树）。
    private var outputDir: String { BakeRunnerGate.thumbnailOutputDirectory.path }

    /// 全量烘焙：遍历 index.allDrillIds，逐条渲染 USDZ 2D 顶视缩略图写入资源目录。
    @MainActor
    func test_bakeAllThumbnails() async throws {
        try BakeRunnerGate.skipUnlessEnabled("test_bakeAllThumbnails")
        let fm = FileManager.default

        struct Request: Decodable {
            let outputDirectory: String
            let drillIDs: [String]?
        }
        let requestURL = BakeRunnerGate.repositoryRoot.appendingPathComponent("build/thumbnail-bake-request.json")
        let request = fm.fileExists(atPath: requestURL.path)
            ? try JSONDecoder().decode(Request.self, from: Data(contentsOf: requestURL)) : nil
        let outputDir = request?.outputDirectory ?? self.outputDir
        try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        guard let index = await DrillContentService.shared.loadDrillIndex() else {
            XCTFail("无法加载 Drills/index.json")
            return
        }
        let ids = request?.drillIDs ?? index.allDrillIds
        XCTAssertFalse(ids.isEmpty, "index.allDrillIds 为空")
        guard Set(ids).isSubset(of: Set(index.allDrillIds)) else {
            XCTFail("缩略图请求含未上架动作")
            return
        }

        var ok = 0
        var failed: [String] = []
        var sourceLog: [String] = []
        var layouts: [[String: Any]] = []
        for id in ids {
            guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: id) else {
                failed.append("\(id)(load)")
                continue
            }
            if let src = DrillStaticPreview.resolveSource(for: drill) {
                sourceLog.append(
                    "\(id) token=\(src.token.isEmpty ? "legacy" : src.token) kind=\(src.kind.rawValue) balls=\(src.board.onTable.count)"
                )
                let radius = Double(AngleSceneCalculator.ballRadius)
                    * Double(DrillStaticPreview.Options.thumbnail.ballScale) / Double(AngleSceneCalculator.innerLength)
                let adjusted = try ThumbnailBallLayout.resolve(src.board.onTable, radius: radius)
                let balls = src.board.onTable.keys.sorted().map { key -> [String: Any] in
                    let old = src.board.onTable[key]!, new = adjusted[key]!
                    return ["key": key, "before": [old.x, old.y], "after": [new.x, new.y]]
                }
                layouts.append(["id": id, "radius": radius, "balls": balls])
            } else {
                sourceLog.append("\(id) token=? kind=unresolved")
            }
            let png = autoreleasepool { () -> Data? in
                guard let image = DrillThumbnailRenderer.render(drill: drill) else { return nil }
                XCTAssertEqual(image.size.width * image.scale, 640)
                XCTAssertEqual(image.size.height * image.scale, 320)
                return image.pngData()
            }
            guard let png, png.count > 4_000 else {
                failed.append("\(id)(render)")
                continue
            }
            let path = "\(outputDir)/\(id).png"
            do {
                try png.write(to: URL(fileURLWithPath: path))
                ok += 1
            } catch {
                failed.append("\(id)(write: \(error.localizedDescription))")
            }
        }

        print("THUMB-BAKE done: \(ok)/\(ids.count) written to \(outputDir)")
        for line in sourceLog { print("THUMB-SRC \(line)") }
        if !failed.isEmpty { print("THUMB-BAKE failures: \(failed.joined(separator: ", "))") }
        if request != nil {
            let data = try JSONSerialization.data(withJSONObject: layouts, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: outputDir).appendingPathComponent("layout-report.json"))
        }
        XCTAssertTrue(failed.isEmpty, "缩略图烘焙失败：\(failed.joined(separator: ", "))")
    }

    /// 物理可行性扫描：对每条 Drill 解析 ShotInput → ShotPredictor.predict，打印
    /// `feasible / cut角 / 目标球是否进选定袋`，便于挑出退回手画轨迹的 Drill。不作断言。
    @MainActor
    func test_scanFeasibility() async throws {
        try BakeRunnerGate.skipUnlessEnabled("test_scanFeasibility")
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
