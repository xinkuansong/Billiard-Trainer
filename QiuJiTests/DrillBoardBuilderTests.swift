import XCTest
@testable import QiuJi

/// `DrillBoardBuilder` 单测（动作库试打模式方案 D1）：
/// drill 根级球局 → `BoardSnapshot` 的球数 / 键名 / 坐标恒等直传约定。
final class DrillBoardBuilderTests: XCTestCase {

    // MARK: - c001：无障碍单杆（shotIntent 路径，双球局）

    func test_c001_singleShot_noObstacles() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c001")
        let drill = try XCTUnwrap(loaded)
        let shot = try XCTUnwrap(drill.shotIntent?.shots.first)
        let board = try XCTUnwrap(DrillBoardBuilder.board(for: drill))

        XCTAssertEqual(Set(board.onTable.keys), ["cueBall", "_8"])
        // 坐标契约：归一化系恒等直传，逐分量相等。
        XCTAssertEqual(board.onTable["cueBall"]?.x, shot.cue.x)
        XCTAssertEqual(board.onTable["cueBall"]?.y, shot.cue.y)
        XCTAssertEqual(board.onTable["_8"]?.x, shot.target.x)
        XCTAssertEqual(board.onTable["_8"]?.y, shot.target.y)
    }

    // MARK: - c042：3 杆 + obstacles（只摆首杆局面，obstacles 依序编号跳过 _8）

    func test_c042_multiShot_withObstacles_usesFirstShotOnly() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c042")
        let drill = try XCTUnwrap(loaded)
        let shots = try XCTUnwrap(drill.shotIntent?.shots)
        XCTAssertEqual(shots.count, 3, "c042 应为 3 杆序列（方案锚点）")
        let first = shots[0]
        let obstacles = try XCTUnwrap(first.obstacles)
        XCTAssertEqual(obstacles.count, 2)

        let board = try XCTUnwrap(DrillBoardBuilder.board(for: drill))
        XCTAssertEqual(Set(board.onTable.keys), ["cueBall", "_8", "_1", "_2"])
        XCTAssertEqual(board.onTable["cueBall"]?.x, first.cue.x)
        XCTAssertEqual(board.onTable["_8"]?.y, first.target.y)
        // obstacles 依序 → _1, _2。
        XCTAssertEqual(board.onTable["_1"]?.x, obstacles[0].x)
        XCTAssertEqual(board.onTable["_1"]?.y, obstacles[0].y)
        XCTAssertEqual(board.onTable["_2"]?.x, obstacles[1].x)
        XCTAssertEqual(board.onTable["_2"]?.y, obstacles[1].y)
    }

    // MARK: - obstacles ≥ 7 时跳过 _8（合成 drill，Bundle 无实例）

    func test_obstacleNumbering_skipsTargetKey8() {
        let obstacles = (0..<9).map { CanvasPoint(x: 0.1 + 0.08 * Double($0), y: 0.25) }
        let drill = makeDrill(shot: ShotIntent.Shot(
            cue: CanvasPoint(x: 0.3, y: 0.3), target: CanvasPoint(x: 0.6, y: 0.2),
            pocket: "bottomCenter", velocity: 2.4,
            spin: nil, elevation: nil, obstacles: obstacles))
        let board = DrillBoardBuilder.board(for: drill)!
        // 9 颗障碍 → _1.._7、跳过 _8、_9、_10。
        let expected = Set(["cueBall", "_8"] + (1...7).map { "_\($0)" } + ["_9", "_10"])
        XCTAssertEqual(Set(board.onTable.keys), expected)
        // 第 8 颗障碍（索引 7）落到 _9。
        XCTAssertEqual(board.onTable["_9"]?.x, obstacles[7].x)
    }

    // MARK: - animation 兜底（合成无 shotIntent drill，Bundle 现已 72/72 全有 shotIntent）

    func test_animationFallback_twoBallBoard() {
        let drill = makeDrill(shot: nil)
        let board = DrillBoardBuilder.board(for: drill)!
        XCTAssertEqual(Set(board.onTable.keys), ["cueBall", "_8"])
        XCTAssertEqual(board.onTable["cueBall"]?.x, 0.20)
        XCTAssertEqual(board.onTable["cueBall"]?.y, 0.30)
        XCTAssertEqual(board.onTable["_8"]?.x, 0.70)
        XCTAssertEqual(board.onTable["_8"]?.y, 0.15)
    }

    // MARK: - 全库 smoke：72 drill 不 crash、球数 ≥2、坐标在归一化界内

    func test_allBundledDrills_produceValidBoards() async throws {
        let loadedIndex = await DrillContentService.shared.loadDrillIndex()
        let index = try XCTUnwrap(loadedIndex)
        let ids = index.allDrillIds
        XCTAssertFalse(ids.isEmpty)
        for id in ids {
            guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: id) else {
                XCTFail("\(id): failed to load from bundle"); continue
            }
            guard let board = DrillBoardBuilder.board(for: drill) else {
                XCTFail("\(id): board(for:) returned nil"); continue
            }
            XCTAssertGreaterThanOrEqual(board.onTable.count, 2, "\(id): 球数 < 2")
            XCTAssertTrue(board.hasCue, "\(id): 缺母球")
            for (key, p) in board.onTable {
                XCTAssertTrue((0.0...1.0).contains(p.x), "\(id) \(key): x=\(p.x) 出界")
                XCTAssertTrue((0.0...0.5).contains(p.y), "\(id) \(key): y=\(p.y) 出界")
            }
        }
    }

    // MARK: - Helpers

    private func makeDrill(shot: ShotIntent.Shot?) -> DrillContent {
        DrillContent(
            id: "drill_test", nameZh: "测试", nameEn: "Test",
            category: "accuracy", subcategory: "test", ballType: ["chinese8"],
            level: "beginner", difficulty: 1, isPremium: false,
            description: "test", coachingPoints: ["测试要点"], standardCriteria: "test",
            sets: DrillContent.DrillSetsConfig(defaultSets: 1, defaultBallsPerSet: 1),
            animation: DrillAnimation(
                cueBall: BallAnimation(start: CanvasPoint(x: 0.20, y: 0.30), path: []),
                targetBall: BallAnimation(start: CanvasPoint(x: 0.70, y: 0.15), path: []),
                pocket: "bottomCenter",
                cueDirection: CanvasPoint(x: 1, y: 0)),
            shotIntent: shot.map { ShotIntent(version: 1, shots: [$0]) }
        )
    }
}
