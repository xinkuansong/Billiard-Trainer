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

    /// c042 初级：双球形（manual01=8 杆 / manual02=5 杆）；开局盘面取自首杆 before。
    func test_c042_loadsMultiFormationsAlignedWithSequence() throws {
        let formations = DrillTryoutBoardStore.formations(for: "drill_c042")
        XCTAssertEqual(formations.count, 2, "c042 应有 manual01 + manual02")
        XCTAssertEqual(formations.map(\.token), ["manual01", "manual02"])
        XCTAssertEqual(formations.map(\.title), ["初级蛇彩走位 · 球形1", "初级蛇彩走位 · 球形2"])
        XCTAssertEqual(formations.map(\.stepCount), [8, 5])
        // 开局球数 = 首杆 before（含母球）；副标题 objectBallCount 不含母球
        XCTAssertEqual(formations.map(\.initial.onTable.count), [4, 6])
        XCTAssertEqual(formations.map(\.objectBallCount), [3, 5])

        let fiveBall = try XCTUnwrap(formations.first(where: { $0.token == "manual02" }))
        XCTAssertNotNil(fiveBall.initial.onTable[PositionPlayBall.cueKey])
        XCTAssertNotNil(fiveBall.initial.onTable["_5"])
        let shot = try XCTUnwrap(fiveBall.firstShot)
        XCTAssertEqual(shot.pocket, "topCenter")
        XCTAssertEqual(shot.velocity, 1.7, accuracy: 0.001)

        XCTAssertEqual(fiveBall.steps.count, fiveBall.stepCount, "steps 应与 stepCount 一致")
        XCTAssertTrue(fiveBall.hasSequence, "多杆 drill 应具备序列")
        XCTAssertEqual(fiveBall.steps.first?.shot.pocket, shot.pocket, "首杆应与 firstShot 一致")
    }

    /// 蛇彩多球形：中级 8/10 杆、高级 8/15 杆；objectBallCount 取自首杆 before。
    func test_snakeDrillFamily_formationsSplitByDifficulty() throws {
        let mid = DrillTryoutBoardStore.formations(for: "drill_c069")
        XCTAssertEqual(mid.map(\.token), ["manual01", "manual02"])
        XCTAssertEqual(mid.map(\.stepCount), [8, 10])
        XCTAssertEqual(mid.map(\.objectBallCount), [3, 10])
        XCTAssertEqual(mid.map(\.title), ["中级蛇彩 · 球形1", "中级蛇彩 · 球形2"])

        let adv = DrillTryoutBoardStore.formations(for: "drill_c071")
        XCTAssertEqual(adv.map(\.token), ["manual01", "manual02"])
        XCTAssertEqual(adv.map(\.stepCount), [8, 15])
        XCTAssertEqual(adv.map(\.objectBallCount), [3, 15])
        XCTAssertEqual(adv.map(\.title), ["高级蛇彩贴库综合 · 球形1", "高级蛇彩贴库综合 · 球形2"])
    }

    /// 多球形试打（c076）：选择列表应露出全部 manual，且开局含目标球。
    func test_c076_multiFormationTryoutBoardsHaveObjectBalls() throws {
        let formations = DrillTryoutBoardStore.formations(for: "drill_c076")
        XCTAssertEqual(formations.map(\.token), ["manual01", "manual02"])
        XCTAssertEqual(formations.map(\.stepCount), [14, 14])
        for f in formations {
            XCTAssertGreaterThanOrEqual(f.objectBallCount, 1, "\(f.token) 开局应有目标球")
            XCTAssertEqual(f.initial.onTable.count, f.objectBallCount + 1)
            XCTAssertTrue(f.hasSequence)
        }
    }

    /// c001 仅保留 manual 序列（旧式无 token 单文件已删）。
    func test_c001_loadsManualOnly() throws {
        let formations = DrillTryoutBoardStore.formations(for: "drill_c001")
        XCTAssertEqual(formations.count, 1)
        let f = try XCTUnwrap(formations.first)
        XCTAssertEqual(f.token, "manual01")
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

    /// 全库 smoke：Bundle 内每个序列文件都能 decode 且开局盘面非空、坐标在归一化范围内。
    func test_allBundledBoards_decodeAndInRange() throws {
        let urls = Bundle.main.urls(
            forResourcesWithExtension: "json",
            subdirectory: DrillTryoutBoardStore.bundleSubdirectory
        ) ?? []
        XCTAssertGreaterThanOrEqual(urls.count, 80, "Bundle 应含同步后的 drill 序列")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for url in urls {
            let data = try Data(contentsOf: url)
            let seq = try decoder.decode(PositionPlaySequence.self, from: data)
            let opening = seq.steps.first?.before ?? seq.initial
            XCTAssertFalse(opening.onTable.isEmpty, "\(url.lastPathComponent) 开局盘面为空")
            for (key, p) in opening.onTable {
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
            DrillTryoutBoardStore.formations(for: "drill_c042")
                .first(where: { $0.token == "manual02" }))

        let lines = DrillTryoutBrief.lines(for: drill, formation: formation)
        let goal = try XCTUnwrap(lines.first(where: { $0.label == "局面目标" }))
        XCTAssertTrue(goal.text.contains("上中袋"), "袋口应取序列首杆 topCenter")
        XCTAssertTrue(goal.text.contains("共 5 杆"), "杆数应取序列 stepCount")

        let ref = try XCTUnwrap(lines.first(where: { $0.label == "参考打法" }))
        // manual02：spinY ≈ −0.47 → 低杆
        XCTAssertTrue(ref.text.contains("低杆"), "参考打法应含低杆，实际：\(ref.text)")
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
