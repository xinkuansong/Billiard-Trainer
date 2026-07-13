//
//  DrillTryoutBoardStoreTests.swift
//  QiuJiTests
//
//  试打球形加载器单测（方案 20260709-动作库试打模式 D4：与视频示范同源）。
//  数据源 = Bundle `DrillBoards/`（`make tryout-sync` 从出片序列同步）。
//

import XCTest
@testable import QiuJi

final class DrillTryoutBoardStoreTests: XCTestCase {

    // MARK: - 文件名解析

    func test_belongs_matchesBothNamingStyles() {
        // 多球形式样
        XCTAssertTrue(DrillTryoutBoardStore.belongs(
            "drill_c042__Snipaste_2026_06_19_14_31_49-初级蛇彩走位 · 球形1-5杆.json",
            to: "drill_c042"))
        // 旧式单序列
        XCTAssertTrue(DrillTryoutBoardStore.belongs(
            "drill_c001-半台直线球-1杆.json", to: "drill_c001"))
        // 非本 drill / 前缀伪匹配不误命中
        XCTAssertFalse(DrillTryoutBoardStore.belongs(
            "drill_c042__token-名-5杆.json", to: "drill_c04"))
        XCTAssertFalse(DrillTryoutBoardStore.belongs(
            "seq_ab12cd34-自由序列-3杆.json", to: "drill_c042"))
    }

    func test_token_extraction() {
        XCTAssertEqual(DrillTryoutBoardStore.token(
            fromFileName: "drill_c042__Snipaste_2026_06_19_14_31_49-初级蛇彩走位-5杆.json",
            drillId: "drill_c042"),
            "Snipaste_2026_06_19_14_31_49")
        // 旧式单序列 → 空 token
        XCTAssertEqual(DrillTryoutBoardStore.token(
            fromFileName: "drill_c001-半台直线球-1杆.json", drillId: "drill_c001"),
            "")
    }

    // MARK: - Bundle 加载（真实资源）

    /// c042 多球形：4 个球形按文件名序，标题/杆数/布局与序列文件一致。
    func test_c042_loadsFourFormationsAlignedWithSequences() throws {
        let formations = DrillTryoutBoardStore.formations(for: "drill_c042")
        XCTAssertEqual(formations.count, 4, "c042 应有 4 个球形（与出片序列一致）")

        let first = try XCTUnwrap(formations.first)
        XCTAssertEqual(first.title, "初级蛇彩走位 · 球形1")
        XCTAssertEqual(first.stepCount, 5)
        // 球形1 = 母球 + _1.._5 共 6 球（与序列 initial 对齐，非 shotIntent 的 4 球局）
        XCTAssertEqual(first.initial.onTable.count, 6)
        XCTAssertNotNil(first.initial.onTable[PositionPlayBall.cueKey])
        XCTAssertNotNil(first.initial.onTable["_5"])
        // 首杆意图存在且带真实参数（说明卡用）
        let shot = try XCTUnwrap(first.firstShot)
        XCTAssertEqual(shot.pocket, "bottomCenter")
        XCTAssertEqual(shot.velocity, 0.9, accuracy: 0.001)

        // 杆数随球形递增（5/8/10/15），排序稳定
        XCTAssertEqual(formations.map(\.stepCount), [5, 8, 10, 15])
    }

    /// 旧式单序列文件（drill_c001-…）也能加载。
    func test_legacySingleSequence_loads() throws {
        let formations = DrillTryoutBoardStore.formations(for: "drill_c001")
        XCTAssertEqual(formations.count, 1)
        let f = try XCTUnwrap(formations.first)
        XCTAssertEqual(f.token, "")
        XCTAssertGreaterThan(f.initial.onTable.count, 0)
    }

    /// 无序列 drill 返回空 → 调用侧回退 shotIntent 路径（DrillBoardBuilder）。
    func test_drillWithoutSequences_fallsBackToShotIntent() async throws {
        XCTAssertTrue(DrillTryoutBoardStore.formations(for: "drill_c006").isEmpty)

        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c006")
        let drill = try XCTUnwrap(loaded)
        let board = try XCTUnwrap(DrillBoardBuilder.board(for: drill))
        XCTAssertNotNil(board.onTable[PositionPlayBall.cueKey])
        XCTAssertNotNil(board.onTable[DrillBoardBuilder.targetKey])
    }

    /// 全库 smoke：Bundle 内每个序列文件都能 decode 且 initial 非空、坐标在归一化范围内。
    func test_allBundledBoards_decodeAndInRange() throws {
        let urls = Bundle.main.urls(
            forResourcesWithExtension: "json",
            subdirectory: DrillTryoutBoardStore.bundleSubdirectory
        ) ?? []
        XCTAssertGreaterThanOrEqual(urls.count, 90, "Bundle 应含全部同步序列（当前 91）")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for url in urls {
            let data = try Data(contentsOf: url)
            let seq = try decoder.decode(PositionPlaySequence.self, from: data)
            XCTAssertFalse(seq.initial.onTable.isEmpty, "\(url.lastPathComponent) initial 为空")
            for (key, p) in seq.initial.onTable {
                XCTAssertTrue((0...1).contains(p.x) && (0...0.5).contains(p.y),
                              "\(url.lastPathComponent) \(key) 坐标越界：(\(p.x), \(p.y))")
            }
        }
    }

    // MARK: - 说明卡（序列版生成）

    func test_briefLines_useFormationFirstShot() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c042")
        let drill = try XCTUnwrap(loaded)
        let formation = try XCTUnwrap(
            DrillTryoutBoardStore.formations(for: "drill_c042").first)

        let lines = DrillTryoutBrief.lines(for: drill, formation: formation)
        let goal = try XCTUnwrap(lines.first(where: { $0.label == "局面目标" }))
        XCTAssertTrue(goal.text.contains("下中袋"), "袋口应取序列首杆 bottomCenter")
        XCTAssertTrue(goal.text.contains("共 5 杆"), "杆数应取序列 stepCount")

        let ref = try XCTUnwrap(lines.first(where: { $0.label == "参考打法" }))
        // velocity 0.9 → 轻推；spinY +0.128 → 高杆
        XCTAssertTrue(ref.text.contains("轻推"))
        XCTAssertTrue(ref.text.contains("高杆"))
    }

    /// 无 formation 时说明卡维持原 shotIntent 生成（D2 行为零回归）。
    func test_briefLines_withoutFormation_unchanged() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c042")
        let drill = try XCTUnwrap(loaded)
        let lines = DrillTryoutBrief.lines(for: drill)
        let goal = try XCTUnwrap(lines.first(where: { $0.label == "局面目标" }))
        XCTAssertTrue(goal.text.contains("共 3 杆"), "shotIntent 路径应为 3 杆")
    }
}
