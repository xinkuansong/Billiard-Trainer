//
//  DrillTryoutBoardStoreTests.swift
//  QiuJiTests
//
//  试打球形加载器单测（方案 20260709-动作库试打模式 D4：与视频示范同源）。
//  数据源 = Bundle `DrillBoards/`（`make tryout-sync` 从出片序列同步）。
//

import XCTest
import SceneKit
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

    func test_c029_loadsSixAuthoredStepsForLayoutRegression() throws {
        let formations = DrillTryoutBoardStore.formations(for: "drill_c029")
        XCTAssertEqual(formations.count, 1)
        XCTAssertEqual(try XCTUnwrap(formations.first).steps.count, 6)
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
        XCTAssertTrue(DrillTryoutBoardStore.formations(for: "drill_c065").isEmpty)

        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c065")
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

        let lines = DrillTryoutBrief.lines(for: drill, formation: formation, orientation: .portrait)
        let goal = try XCTUnwrap(lines.first(where: { $0.label == "局面目标" }))
        XCTAssertTrue(goal.text.contains("左中袋"), "袋口应取序列首杆 topCenter 的竖桌方位")
        XCTAssertTrue(goal.text.contains("共 5 杆"), "杆数应取序列 stepCount")

        let ref = try XCTUnwrap(lines.first(where: { $0.label == "参考打法" }))
        // manual02：spinY ≈ −0.47 → 低杆
        XCTAssertTrue(ref.text.contains("低杆"), "参考打法应含低杆，实际：\(ref.text)")
    }

    /// 无 formation 时说明卡维持原 shotIntent 生成（D2 行为零回归）。
    func test_briefLines_withoutFormation_unchanged() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c042")
        let drill = try XCTUnwrap(loaded)
        let shot = try XCTUnwrap(drill.shotIntent?.shots.first)
        let lines = DrillTryoutBrief.lines(for: drill, orientation: .portrait)
        let goal = try XCTUnwrap(lines.first(where: { $0.label == "局面目标" }))
        XCTAssertEqual(goal.text, "把目标球打进\(PocketDisplay.name(id: shot.pocket, orientation: .portrait))",
                       "单杆且无 formation 时应直接使用根级 shotIntent 袋口")
        let reference = try XCTUnwrap(lines.first(where: { $0.label == "参考打法" }))
        XCTAssertEqual(reference.text, DrillTryoutBrief.referenceText(for: shot),
                       "无 formation 时参考打法应来自根级 shotIntent")
    }
}


@MainActor
final class PocketDisplayTests: XCTestCase {
    /// 从实际相机坐标推导屏幕方位，避免用第二份名称数组验证第一份数组。
    func testNamesMatchBothActualTopDownCameraProjections() {
        let camera = SCNNode()
        camera.camera = SCNCamera()
        let rig = CameraRig(cameraNode: camera, tableSurfaceY: 0)
        for orientation in PocketDisplay.Orientation.allCases {
            if orientation == .portrait { rig.applyTopDown2DRotated() }
            else { rig.applyTopDown2D() }
            for (index, pocket) in AngleSceneCalculator.pocketPositions(surfaceY: 0).enumerated() {
                let point = camera.convertPosition(pocket, from: nil)
                let horizontal = point.x < 0 ? "左" : "右"
                let vertical = point.y > 0 ? "上" : "下"
                let expected = index < 4 ? horizontal + vertical + "角袋"
                    : (orientation == .portrait ? horizontal : vertical) + "中袋"
                XCTAssertEqual(PocketDisplay.name(index: index, orientation: orientation), expected)
            }
        }
    }

    func testPerspectiveKeepsLast2DReferenceAndRotationUpdatesIt() {
        let scene = AngleTrainingScene()
        scene.setCameraMode(.topDown2D)
        scene.setCameraMode(.perspective3D)
        XCTAssertEqual(scene.pocketDisplayOrientation, .landscape)
        scene.setCameraMode(.topDown2DRotated)
        scene.setCameraMode(.perspective3D)
        XCTAssertEqual(scene.pocketDisplayOrientation, .portrait)
        // 页面在 3D 中旋转也要刷新参考方向，镜头转动不参与命名。
        scene.pocketDisplayOrientation = .landscape
        scene.setCameraMode(.perspective3D)
        XCTAssertEqual(scene.pocketDisplayOrientation, .landscape)
    }

    func testBriefRotatesNameWithoutChangingSelectedPocket() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c042")
        let drill = try XCTUnwrap(loaded)
        let formation = try XCTUnwrap(DrillTryoutBoardStore.formations(for: "drill_c042").first)
        let id = try XCTUnwrap(formation.firstShot?.pocket)
        XCTAssertEqual(id, "topCenter")
        for (orientation, expected) in [(PocketDisplay.Orientation.landscape, "上中袋"), (.portrait, "左中袋")] {
            let lines = DrillTryoutBrief.lines(for: drill, formation: formation, orientation: orientation)
            XCTAssertTrue(try XCTUnwrap(lines.first { $0.label == "局面目标" }).text.contains(expected))
            XCTAssertEqual(formation.firstShot?.pocket, id)
        }
    }

    func testInvalidPocketNeverProducesNumberedLabel() {
        for orientation in PocketDisplay.Orientation.allCases {
            XCTAssertEqual(PocketDisplay.name(index: -1, orientation: orientation), "—")
            XCTAssertEqual(PocketDisplay.name(index: 6, orientation: orientation), "—")
            XCTAssertEqual(PocketDisplay.name(id: "unknown", orientation: orientation), "—")
        }
    }
}

@MainActor
final class DrillCopyDisplayTests: XCTestCase {
    func testPocketProseMatchesActualCameraProjection() {
        let node = SCNNode()
        node.camera = SCNCamera()
        let rig = CameraRig(cameraNode: node, tableSurfaceY: 0)
        rig.applyTopDown2D()
        for (index, pocket) in AngleSceneCalculator.pocketPositions(surfaceY: 0).enumerated() {
            let position = node.convertPosition(pocket, from: nil)
            let expected = index < 4
                ? (position.x < 0 ? "左" : "右") + (position.y > 0 ? "上" : "下") + "角袋"
                : (position.y > 0 ? "上" : "下") + "中袋"
            let source = PocketDisplay.name(index: index, orientation: .portrait)
            XCTAssertEqual(DrillCopyDisplay.text(source, drillID: "drill_c033",
                field: "description", orientation: .landscape), expected)
        }
    }

    func testScopedCompoundPhrasesDoNotCascade() {
        let source = "横排从左右两端开始，让上下两端接起来"
        XCTAssertEqual(DrillCopyDisplay.text(source, drillID: "drill_c082",
            field: "description", orientation: .landscape), "纵排从上下两端开始，让左右两端接起来")
        XCTAssertEqual(DrillCopyDisplay.text("先确定8号打左下还是右下角袋", drillID: "drill_c030",
            field: "coachingPoints[0]", orientation: .landscape), "先确定8号打左上还是左下角袋")
        XCTAssertEqual(DrillCopyDisplay.text("左右下角袋", drillID: "drill_c046",
            field: "description", orientation: .landscape), "左侧上下角袋")
        XCTAssertEqual(DrillCopyDisplay.text("左长库与右长库", drillID: "drill_c064",
            field: "coachingPoints[1]", orientation: .landscape), "上长库与下长库")
    }

    func testStrokeRelativeWordsAndUnknownScopesStayUntouched() {
        let source = "左塞向左让、右塞向右让；高低杆、母球下方、向前跟进、横着甩杆、下一杆"
        XCTAssertEqual(DrillCopyDisplay.text(source, drillID: "drill_c073",
            field: "coachingPoints[0]", orientation: .landscape), source)
        // This relative phrase is only approved as table-space in c064's audited fields.
        XCTAssertEqual(DrillCopyDisplay.text("2 号左侧", drillID: "drill_unknown",
            field: "description", orientation: .landscape), "2 号左侧")
        XCTAssertEqual(DrillCopyDisplay.text("右下角袋与上下两端", drillID: "drill_c082",
            field: "description", orientation: .portrait), "右下角袋与上下两端")
    }

    func testBriefFirstPointUsesReceivingTableAndDoesNotMutateContent() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c033")
        let drill = try XCTUnwrap(loaded)
        let original = drill.coachingPoints[0]
        for orientation in PocketDisplay.Orientation.allCases {
            let lines = DrillTryoutBrief.lines(for: drill, orientation: orientation)
            let focus = try XCTUnwrap(lines.first { $0.label == "训练重点" })
            XCTAssertTrue(focus.text.contains(orientation == .landscape ? "左下角袋" : "右下角袋"))
        }
        XCTAssertEqual(drill.coachingPoints[0], original)
    }

    func testBriefRespectsTrainingModeIncludingRestoredTarget() async throws {
        for (id, token, expected) in [
            ("drill_c012", "manual01", "各杆按示范摆位练习"),
            ("drill_c046", "Snipaste_2026_06_19_16_49_09", "按顺序接续完成"),
            ("drill_c069", "manual02", "按顺序接续完成")
        ] {
            let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
            let drill = try XCTUnwrap(loaded)
            let formation = try XCTUnwrap(DrillTryoutBoardStore.formations(for: id).first { $0.token == token })
            let goal = DrillTryoutBrief.goalText(for: drill, formation: formation, orientation: .landscape)
            XCTAssertTrue(goal.contains(expected), "\(id): \(goal)")
            XCTAssertFalse(goal.contains("进球后"))
            if id == "drill_c012" { XCTAssertFalse(goal.contains("目标球")) }
        }
    }

    func testUnknownFormationTokenKeepsNeutralSummary() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c069")
        let drill = try XCTUnwrap(loaded)
        let source = try XCTUnwrap(DrillTryoutBoardStore.formations(for: drill.id).first)
        let unknown = DrillTryoutFormation(token: "unknown", title: source.title,
            fileName: source.fileName, initial: source.initial, stepCount: source.stepCount,
            firstShot: source.firstShot, steps: source.steps)
        XCTAssertNil(DrillTryoutBrief.formationMode(for: drill, formation: unknown))
        let goal = DrillTryoutBrief.goalText(for: drill, formation: unknown, orientation: .portrait)
        XCTAssertTrue(goal.contains("共 \(source.stepCount) 杆示范"))
        XCTAssertFalse(goal.contains("接续"))
        XCTAssertFalse(goal.contains("各杆"))
    }
}
