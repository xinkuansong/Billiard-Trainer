import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class DrillStaticPreviewTests: XCTestCase {

    /// `A*` 序列命名已随 8293ef4 全量退役（Bundle `DrillBoards/` 零个 `__A[0-9]` 文件），
    /// 门面球形改由 `manual*` 承担；断言前提随之更新为 manual 语义。
    func test_representative_prefersManual_overSnipaste() {
        let forms: [DrillTryoutFormation] = [
            stubFormation(token: "Snipaste_1", file: "drill_c053__Snipaste_1-x-1杆.json"),
            stubFormation(token: "manual01", file: "drill_c053__manual01-x-0杆.json"),
            stubFormation(token: "manual02", file: "drill_c053__manual02-x-0杆.json"),
        ]
        let picked = DrillTryoutBoardStore.representative(from: forms)
        XCTAssertEqual(picked?.token, "manual01")
    }

    func test_representative_preferredTokenWins() {
        let forms: [DrillTryoutFormation] = [
            stubFormation(token: "manual01", file: "manual01.json"),
            stubFormation(token: "manual02", file: "manual02.json"),
        ]
        let picked = DrillTryoutBoardStore.representative(from: forms, preferredToken: "manual02")
        XCTAssertEqual(picked?.token, "manual02")
    }

    func test_representative_legacyEmptyTokenBeforeManual() {
        let forms: [DrillTryoutFormation] = [
            stubFormation(token: "manual01", file: "drill_c001__manual01-x-1杆.json"),
            stubFormation(token: "", file: "drill_c001-半台直线球-1杆.json"),
        ]
        let picked = DrillTryoutBoardStore.representative(from: forms)
        XCTAssertEqual(picked?.token, "")
        XCTAssertEqual(picked?.fileName, "drill_c001-半台直线球-1杆.json")
    }

    /// 前提更新同上：drill_c053 现有 `manual01` / `manual02` 两条序列，门面取 `manual01`。
    func test_resolveSource_multiFormationUsesManualBoard() async throws {
        guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c053") else {
            throw XCTSkip("drill_c053 not in bundle")
        }
        let source = try XCTUnwrap(DrillStaticPreview.resolveSource(for: drill))
        XCTAssertEqual(source.token, "manual01")
        XCTAssertFalse(source.board.onTable.isEmpty)
        XCTAssertNotNil(source.board.onTable[PositionPlayBall.cueKey])
        // Board should not force every object ball to "_8" when sequence has real keys.
        let objectKeys = source.board.onTable.keys.filter { !PositionPlayBall.isCue($0) }
        XCTAssertFalse(objectKeys.isEmpty)
    }

    func test_options_listBallScale_vs_detailTrueSize() {
        // v24 E2/E3: list PNG readability vs live detail true size (no second PNG set).
        XCTAssertEqual(DrillStaticPreview.Options.thumbnail.ballScale, 1.8, accuracy: 0.001)
        XCTAssertEqual(DrillStaticPreview.Options.detail.ballScale, 1.0, accuracy: 0.001)
    }

    func test_renderThumbnail_smoke_c001_and_c053() async throws {
        for id in ["drill_c001", "drill_c053"] {
            guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: id) else {
                throw XCTSkip("\(id) not in bundle")
            }
            let image = try XCTUnwrap(
                DrillThumbnailRenderer.render(drill: drill),
                "render failed for \(id)"
            )
            let png = try XCTUnwrap(image.pngData())
            XCTAssertGreaterThan(png.count, 4_000, "\(id) thumbnail too small")
        }
    }

    // MARK: - Helpers

    func test_detailControllerAndRenderCoordinatorReleaseAfterDismantle() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c078")
        let drill = try XCTUnwrap(loaded)
        for _ in 0..<3 {
            weak var releasedController: DrillSceneController?
            weak var releasedCoordinator: AngleSceneView.Coordinator?
            weak var releasedScene: AngleTrainingScene?
            autoreleasepool {
                let controller = DrillSceneController()
                controller.setup(drill: drill)
                controller.setCameraMode(.perspective3D)
                controller.play()
                let view = SCNView(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
                view.scene = controller.scene
                let coordinator = AngleSceneView.Coordinator(scene: controller.scene,
                    cameraMode: .perspective3D, interactionMode: .tapsOnly)
                coordinator.scnView = view
                coordinator.startRenderLoop()
                releasedController = controller
                releasedCoordinator = coordinator
                releasedScene = controller.scene
                AngleSceneView.dismantleUIView(view, coordinator: coordinator)
            }
            XCTAssertNil(releasedController, "Pending preview work must not retain its page")
            XCTAssertNil(releasedCoordinator, "Dismantling must break the display-link ownership cycle")
            // SceneKit may release render transactions on subsequent main-loop turns.
            for _ in 0..<20 where releasedScene != nil {
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            XCTAssertNil(releasedScene, "Leaving a detail must release its scene")
        }
    }

    func test_detailCameraSwitchPreservesOpeningBoardAndPlaybackState() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c078")
        let drill = try XCTUnwrap(loaded)
        let source = try XCTUnwrap(DrillStaticPreview.resolveSource(for: drill))
        let controller = DrillSceneController()
        controller.setup(drill: drill)
        controller.scene.cameraRig?.viewportSize = CGSize(width: 390, height: 220)
        let positions = controller.scene.allBallNodes.mapValues(\.position)
        controller.play()
        for mode: AngleTrainingScene.CameraMode in [.perspective3D, .topDown2D, .perspective3D] {
            controller.setCameraMode(mode)
            if mode == .perspective3D {
                XCTAssertEqual(try XCTUnwrap(controller.scene.cameraRig).targetYaw, .pi / 2, accuracy: 0.00001)
                let camera = try XCTUnwrap(controller.scene.cameraNode)
                // Check SceneKit's actual camera basis, not a hand-derived yaw convention.
                XCTAssertGreaterThan(camera.convertVector(SCNVector3(1, 0, 0), to: nil).x, 0.99)
            }
            XCTAssertEqual(controller.cameraMode, mode)
            XCTAssertEqual(controller.playbackState, .playing)
            XCTAssertEqual(controller.scene.cameraNode?.camera?.usesOrthographicProjection, mode != .perspective3D)
            for key in source.board.onTable.keys {
                let node = try XCTUnwrap(controller.scene.allBallNodes[key])
                let old = try XCTUnwrap(positions[key])
                XCTAssertFalse(node.isHidden)
                XCTAssertEqual(node.position.x, old.x)
                XCTAssertEqual(node.position.y, old.y)
                XCTAssertEqual(node.position.z, old.z)
            }
        }
    }

    func test_detailSeatsOpeningBallsBeforeAsyncPredictionAndImmediatePlay() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c078")
        let drill = try XCTUnwrap(loaded)
        let source = try XCTUnwrap(DrillStaticPreview.resolveSource(for: drill))
        XCTAssertFalse(source.board.onTable.isEmpty)
        let controller = DrillSceneController()
        controller.setup(drill: drill)
        // No suspension: the main-queue preview completion cannot have run yet.
        for key in source.board.onTable.keys {
            let node = try XCTUnwrap(controller.scene.allBallNodes[key])
            XCTAssertFalse(node.isHidden, "Opening ball must be seated before solving: \(key)")
            XCTAssertNotNil(node.parent)
            XCTAssertEqual(node.opacity, 1)
        }
        controller.play()
        XCTAssertEqual(controller.playbackState, .playing)
        for key in source.board.onTable.keys {
            XCTAssertFalse(try XCTUnwrap(controller.scene.allBallNodes[key]).isHidden,
                "Immediate playback must retain opening ball: \(key)")
        }
    }

    func test_detailFormationSwitchWhilePlayingSeatsNewBoardAndKeeps3D() async throws {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c042")
        let drill = try XCTUnwrap(loaded)
        let controller = DrillSceneController()
        controller.setup(drill: drill)
        controller.scene.cameraRig?.viewportSize = CGSize(width: 402, height: 222)
        controller.setCameraMode(.perspective3D)
        XCTAssertEqual(controller.availableFormations.map(\.stepCount), [8, 5])
        for token in ["manual02", "manual01"] {
            controller.play()
            XCTAssertEqual(controller.playbackState, .playing)
            controller.switchFormation(token: token)
            let formation = try XCTUnwrap(controller.availableFormations.first { $0.token == token })
            let board = try XCTUnwrap(formation.steps.first?.before)
            XCTAssertEqual(controller.currentToken, token)
            XCTAssertEqual(controller.playbackState, .idle)
            XCTAssertEqual(controller.stepLabel, "第 1/\(formation.stepCount) 杆")
            XCTAssertEqual(controller.cameraMode, .perspective3D)
            XCTAssertEqual(controller.scene.cameraNode.camera?.usesOrthographicProjection, false)
            for (key, point) in board.onTable {
                let node = try XCTUnwrap(controller.scene.allBallNodes[key])
                let expected = AngleSceneCalculator.normalizedToScene(
                    point: CGPoint(x: point.x, y: point.y), surfaceY: controller.scene.surfaceY)
                XCTAssertFalse(node.isHidden)
                XCTAssertEqual(node.position.x, expected.x, accuracy: 0.00001)
                XCTAssertEqual(node.position.y, expected.y, accuracy: 0.00001)
                XCTAssertEqual(node.position.z, expected.z, accuracy: 0.00001)
            }
        }
    }

    private func stubFormation(token: String, file: String) -> DrillTryoutFormation {
        DrillTryoutFormation(
            token: token,
            title: file,
            fileName: file,
            initial: BoardSnapshot(onTable: [
                PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.2),
                "_8": CanvasPoint(x: 0.5, y: 0.35),
            ]),
            stepCount: 0,
            firstShot: nil,
            steps: []
        )
    }
}
