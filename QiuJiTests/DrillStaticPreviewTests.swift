import XCTest
import SceneKit
@testable import QiuJi

@MainActor
final class DrillStaticPreviewTests: XCTestCase {

    private let thumbnailRadius = Double(AngleSceneCalculator.ballRadius)
        * Double(DrillStaticPreview.Options.thumbnail.ballScale) / Double(AngleSceneCalculator.innerLength)

    func test_thumbnailLayout_preservesAlreadySeparatedPositions() throws {
        let input = ["a": CanvasPoint(x: 0.2, y: 0.2), "b": CanvasPoint(x: 0.7, y: 0.4)]
        let result = try ThumbnailBallLayout.resolve(input, radius: thumbnailRadius)
        for key in input.keys {
            XCTAssertEqual(result[key]!.x, input[key]!.x, accuracy: 1e-12)
            XCTAssertEqual(result[key]!.y, input[key]!.y, accuracy: 1e-12)
        }
    }

    func test_thumbnailLayout_movesPairEquallyToTangency() throws {
        let input = ["a": CanvasPoint(x: 0.49, y: 0.25), "b": CanvasPoint(x: 0.51, y: 0.25)]
        let result = try ThumbnailBallLayout.resolve(input, radius: thumbnailRadius)
        XCTAssertEqual(result["a"]!.x, 0.5 - thumbnailRadius, accuracy: 1e-8)
        XCTAssertEqual(result["b"]!.x, 0.5 + thumbnailRadius, accuracy: 1e-8)
        XCTAssertEqual(result["a"]!.y, 0.25, accuracy: 1e-12)
        assertThumbnailLayout(result)
    }

    func test_thumbnailLayout_keepsDenseRailRowOrderedAndInside() throws {
        let input = Dictionary(uniqueKeysWithValues: (0..<8).map {
            (String(format: "%02d", $0), CanvasPoint(x: 0.012 + Double($0) * 0.023, y: 0.015))
        })
        let result = try ThumbnailBallLayout.resolve(input, radius: thumbnailRadius)
        let row = result.keys.sorted().map { result[$0]! }
        for i in 1..<row.count {
            XCTAssertEqual(row[i].x - row[i-1].x, 2 * thumbnailRadius, accuracy: 1e-7)
            XCTAssertEqual(row[i].y, row[0].y, accuracy: 1e-12)
        }
        assertThumbnailLayout(result)
    }

    func test_thumbnailLayout_diagonalClusterIsDeterministicAndDoesNotOverlap() throws {
        let input = ["a": CanvasPoint(x: 0.48, y: 0.23), "b": CanvasPoint(x: 0.50, y: 0.25),
                     "c": CanvasPoint(x: 0.52, y: 0.23), "d": CanvasPoint(x: 0.5, y: 0.21)]
        let result = try ThumbnailBallLayout.resolve(input, radius: thumbnailRadius)
        let reversed = try ThumbnailBallLayout.resolve(Dictionary(uniqueKeysWithValues: input.sorted { $0.key > $1.key }), radius: thumbnailRadius)
        for key in input.keys {
            XCTAssertEqual(result[key]!.x, reversed[key]!.x, accuracy: 1e-12)
            XCTAssertEqual(result[key]!.y, reversed[key]!.y, accuracy: 1e-12)
        }
        assertThumbnailLayout(result)
    }

    func test_thumbnailLayout_coincidentCentersAndImpossibleBounds() throws {
        let same = Dictionary(uniqueKeysWithValues: (0..<4).map { (String($0), CanvasPoint(x: 0.5, y: 0.25)) })
        assertThumbnailLayout(try ThumbnailBallLayout.resolve(same, radius: thumbnailRadius))
        XCTAssertThrowsError(try ThumbnailBallLayout.resolve(same, radius: 0.2))
    }

    func test_thumbnailLayout_allActiveFormationCopiesFitWithoutOverlaps() async throws {
        let loaded = await DrillContentService.shared.loadDrillIndex()
        let index = try XCTUnwrap(loaded)
        for id in index.allDrillIds {
            let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
            let drill = try XCTUnwrap(loaded)
            let source = try XCTUnwrap(DrillStaticPreview.resolveSource(for: drill))
            let original = source.board.onTable
            let positions = try ThumbnailBallLayout.resolve(original, radius: thumbnailRadius)
            assertThumbnailLayout(positions, label: id)
            let reloaded = try XCTUnwrap(DrillStaticPreview.resolveSource(for: drill)).board.onTable
            for key in original.keys {
                XCTAssertEqual(reloaded[key]!.x, original[key]!.x)
                XCTAssertEqual(reloaded[key]!.y, original[key]!.y)
            }
        }
    }

    private func assertThumbnailLayout(_ points: [String: CanvasPoint], label: String = "", file: StaticString = #filePath, line: UInt = #line) {
        let values = Array(points.values)
        for (i, p) in values.enumerated() {
            XCTAssertGreaterThanOrEqual(p.x, thumbnailRadius - 1e-8, label, file: file, line: line)
            XCTAssertLessThanOrEqual(p.x, 1 - thumbnailRadius + 1e-8, label, file: file, line: line)
            XCTAssertGreaterThanOrEqual(p.y, thumbnailRadius - 1e-8, label, file: file, line: line)
            XCTAssertLessThanOrEqual(p.y, 0.5 - thumbnailRadius + 1e-8, label, file: file, line: line)
            for j in values.indices where j > i {
                XCTAssertGreaterThanOrEqual(hypot(p.x-values[j].x, p.y-values[j].y), 2*thumbnailRadius-1e-8, label, file: file, line: line)
            }
        }
    }

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
                let rig = try XCTUnwrap(controller.scene.cameraRig)
                XCTAssertTrue(rig.usesSurfaceCamera)
                XCTAssertEqual(rig.twoViewSnapshot?.mode, .thirdPerson)
                XCTAssertNotNil(rig.twoViewSnapshot?.simpleShot?.surface)
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

/// Exercises the real controller, physics recorder, SceneKit actions and shared camera.
@MainActor
final class DrillSequenceCameraTests: XCTestCase {
    private func controller(id: String = "drill_c042") async throws -> DrillSceneController {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
        let drill = try XCTUnwrap(loaded)
        let result = DrillSceneController()
        result.setup(drill: drill)
        result.switchFormation(token: "manual02")
        result.scene.cameraRig?.viewportSize = CGSize(width: 390, height: 220)
        result.setCameraMode(.perspective3D)
        return result
    }

    private func pump(_ controller: DrillSceneController, renderer: SCNRenderer,
                      timeout: TimeInterval = 45, until condition: () -> Bool) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while !condition(), ProcessInfo.processInfo.systemUptime < deadline {
            renderer.update(atTime: ProcessInfo.processInfo.systemUptime)
            controller.scene.cameraRig?.update(deltaTime: 0.02)
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(condition(), "Timed out: \(controller.playbackPhase), \(controller.stepLabel), \(controller.playbackMessage ?? "")")
    }

    private func renderer(_ controller: DrillSceneController) -> SCNRenderer {
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = controller.scene
        renderer.pointOfView = controller.scene.cameraNode
        return renderer
    }

    func testAuthoredBoardChangeDistinguishesReseatFromContinuousPhysics() async throws {
        let c = try await controller()
        let independent = try XCTUnwrap(c.availableFormations.first { $0.token == "manual01" }).steps
        let continuous = try XCTUnwrap(c.availableFormations.first { $0.token == "manual02" }).steps
        for index in 1..<independent.count {
            XCTAssertTrue(DrillSceneController.requiresBoardChange(after: independent[index - 1].after, before: independent[index].before))
        }
        for index in 1..<continuous.count {
            XCTAssertFalse(DrillSceneController.requiresBoardChange(after: continuous[index - 1].after, before: continuous[index].before))
        }
        var movedCue = continuous[0].after
        let originalCue = try XCTUnwrap(movedCue.onTable[PositionPlayBall.cueKey])
        movedCue.onTable[PositionPlayBall.cueKey] = CanvasPoint(x: originalCue.x + 0.05, y: originalCue.y)
        XCTAssertTrue(DrillSceneController.requiresBoardChange(after: continuous[0].after, before: movedCue),
            "A saved cue reposition is a board change even when the ball identities stay the same")
    }

    func testIndependentShotsRestoreTargetBeforeTurningCameraAndCompleteAllEight() async throws {
        let c = try await controller()
        c.switchFormation(token: "manual01")
        let steps = try XCTUnwrap(c.availableFormations.first { $0.token == "manual01" }).steps
        let target = try XCTUnwrap(c.scene.allBallNodes[steps[1].shot.targetKey])
        let cue = try XCTUnwrap(c.scene.cueBallNode)
        let r = renderer(c)
        c.play()
        try await pump(c, renderer: r) { c.playbackPhase == .aiming }
        c.togglePlayback()
        try await pump(c, renderer: r) { c.playbackState == .paused }
        XCTAssertTrue(target.isHidden, "The first shot actually potted the repeated target")
        let heldCamera = try XCTUnwrap(c.scene.cameraRig?.twoViewSnapshot?.pose)
        let cueRest = cue.simdPosition
        c.togglePlayback()
        try await pump(c, renderer: r) { c.playbackPhase == .arranging }
        XCTAssertEqual(c.scene.cameraRig?.twoViewSnapshot?.pose.eye, heldCamera.eye)
        XCTAssertEqual(cue.simdPosition, cueRest, "Reseating must begin at the visible rest position")
        XCTAssertFalse(target.isHidden)
        XCTAssertEqual(target.opacity, 0, accuracy: 0.0001, "The potted target reappears by fading in")
        try await Task.sleep(nanoseconds: 100_000_000)
        r.update(atTime: ProcessInfo.processInfo.systemUptime)
        c.togglePlayback()
        XCTAssertEqual(c.playbackState, .paused)
        let pausedPosition = cue.simdPosition
        try await Task.sleep(nanoseconds: 150_000_000)
        r.update(atTime: ProcessInfo.processInfo.systemUptime)
        XCTAssertEqual(cue.simdPosition, pausedPosition)
        XCTAssertEqual(c.scene.cameraRig?.twoViewSnapshot?.pose.eye, heldCamera.eye)
        c.togglePlayback()
        try await pump(c, renderer: r) { c.playbackPhase == .transitioning }
        XCTAssertFalse(target.isHidden)
        XCTAssertEqual(target.opacity, 1)
        for (key, p) in steps[1].before.onTable {
            let node = try XCTUnwrap(c.scene.allBallNodes[key])
            let expected = AngleSceneCalculator.normalizedToScene(point: CGPoint(x: p.x, y: p.y), surfaceY: c.scene.surfaceY)
            XCTAssertEqual(node.position.x, expected.x, accuracy: 0.00001)
            XCTAssertEqual(node.position.z, expected.z, accuracy: 0.00001)
        }
        XCTAssertEqual(c.scene.cameraRig?.twoViewSnapshot?.pose.eye, heldCamera.eye,
            "The connector must start only after the new board is completely seated")
        try await pump(c, renderer: r, timeout: 120) { c.playbackState == .idle }
        XCTAssertNil(c.playbackMessage)
        XCTAssertEqual(c.stepLabel, "第 8/8 杆")
        XCTAssertEqual(c.playbackPhase, .finished)
    }

    func testCurrentEngineContinuationMatchesPlaybackRest() async throws {
        for id in ["drill_c042", "drill_c064", "drill_c079", "drill_c081", "drill_c071"] {
            let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
            let drill = try XCTUnwrap(loaded)
            let c = DrillSceneController()
            c.setup(drill: drill)
            let formation = try XCTUnwrap(c.availableFormations.last)
            var board = try XCTUnwrap(formation.steps.first).before
            var count = 0
            for (index, step) in formation.steps.enumerated() {
                guard let pred = PositionPlayShotSolver.solve(before: board, shot: step.shot, surfaceY: c.scene.surfaceY),
                      pred.feasible, pred.hasFinalTableState, let recorder = pred.recorder else {
                    print("CHAIN-AUDIT", id, "stopped", index + 1, board)
                    break
                }
                let playback = TrajectoryPlayback(recorder: recorder, surfaceY: c.scene.surfaceY + AngleSceneCalculator.ballRadius)
                var next = board
                for key in board.onTable.keys {
                    let name = PositionPlayShotSolver.predName(boardKey: key, shot: step.shot)
                    if pred.pocketedBalls.contains(name) { next.onTable.removeValue(forKey: key); continue }
                    if let final = playback.stateAt(ballName: name, time: playback.duration), let engine = pred.finalPositions[name] {
                        XCTAssertEqual(final.position.x, engine.x, accuracy: 0.00001)
                        XCTAssertEqual(final.position.z, engine.z, accuracy: 0.00001)
                        let point = AngleSceneCalculator.sceneToNormalized(position: final.position)
                        next.onTable[key] = CanvasPoint(x: Double(point.x), y: Double(point.y))
                    }
                }
                board = next
                count += 1
            }
            print("CHAIN-AUDIT", id, "completed", count, "of", formation.steps.count)
        }
    }

    func testOpeningUsesSharedThirdPersonSurfaceAndSolvedAim() async throws {
        let c = try await controller()
        let step = try XCTUnwrap(c.availableFormations.first { $0.token == "manual02" }?.steps.first)
        let pred = try XCTUnwrap(PositionPlayShotSolver.solve(before: step.before, shot: step.shot, surfaceY: c.scene.surfaceY))
        let cue = try XCTUnwrap(c.scene.cueBallNode).position
        let expected = CameraSurface(cue: SIMD2(cue.x, cue.z), surfaceY: c.scene.surfaceY,
            viewport: CGSize(width: 390, height: 220),
            bearing: CameraSurface.bearing(cue: SIMD2(cue.x, cue.z), backwards: SIMD2(-pred.aimDirection.x, -pred.aimDirection.z))).pose
        let actual = try XCTUnwrap(c.scene.cameraRig?.twoViewSnapshot)
        XCTAssertEqual(actual.mode, .thirdPerson)
        XCTAssertLessThan(simd_distance(actual.pose.eye, expected.eye), 0.0001)
        XCTAssertLessThan(simd_distance(actual.pose.forward, expected.forward), 0.0001)
        XCTAssertEqual(actual.pose.fov, expected.fov, accuracy: 0.0001)
    }

    func testContinuousFourShotCameraPauseAndFinalBoard() async throws {
        let c = try await controller(id: "drill_c081")
        let r = renderer(c)
        let opening = c.currentBoard()
        c.play()
        try await pump(c, renderer: r) { c.playbackPhase == .aiming }
        let rig = try XCTUnwrap(c.scene.cameraRig)
        rig.handleSurfacePan(delta: SIMD2(40, 0))
        try await Task.sleep(nanoseconds: 80_000_000)
        rig.update(deltaTime: 0.08)
        XCTAssertTrue(rig.twoViewOwnerIsManual)
        c.togglePlayback() // Aiming/motion requests finish the whole shot.
        let firstView = try XCTUnwrap(c.scene.cameraRig?.twoViewSnapshot?.pose)
        try await pump(c, renderer: r) { c.playbackPhase == .moving }
        c.suspendPlayback() // Backgrounding must freeze actual in-flight ball poses.
        let flight = c.scene.allBallNodes.mapValues(\.simdPosition)
        let flightPoses = c.scene.captureBallPoses()
        try await Task.sleep(nanoseconds: 100_000_000)
        r.update(atTime: ProcessInfo.processInfo.systemUptime)
        for (key, p) in flight { XCTAssertEqual(c.scene.allBallNodes[key]?.simdPosition, p) }
        for (key, p) in flightPoses { XCTAssertEqual(c.scene.allBallNodes[key]?.simdOrientation.vector, p.vector) }
        c.togglePlayback()
        c.togglePlayback() // Re-request the boundary pause after background resume.
        try await pump(c, renderer: r) { c.playbackState == .paused }
        XCTAssertEqual(c.playbackPhase, .holding)
        XCTAssertLessThan(simd_distance(try XCTUnwrap(c.scene.cameraRig?.twoViewSnapshot?.pose.eye), firstView.eye), 0.0001)
        let stopped = c.scene.allBallNodes.mapValues(\.simdPosition)
        let poses = c.scene.captureBallPoses()
        c.togglePlayback()
        try await pump(c, renderer: r) { c.playbackPhase == .transitioning }
        for (key, p) in stopped { XCTAssertEqual(c.scene.allBallNodes[key]?.simdPosition, p, "Ball moved at shot boundary: \(key)") }
        for (key, p) in poses { XCTAssertEqual(c.scene.allBallNodes[key]?.simdOrientation.vector, p.vector) }
        c.scene.cameraRig?.update(deltaTime: 0.1)
        c.togglePlayback() // Transition pause is immediate and preserves displayed pose.
        XCTAssertEqual(c.playbackState, .paused)
        let pausedView = try XCTUnwrap(c.scene.cameraRig?.twoViewSnapshot?.pose)
        c.scene.cameraRig?.update(deltaTime: 1)
        XCTAssertEqual(c.scene.cameraRig?.twoViewSnapshot?.pose.eye, pausedView.eye)
        c.setCameraMode(.topDown2D)
        c.setCameraMode(.perspective3D)
        XCTAssertEqual(c.scene.cameraRig?.twoViewSnapshot?.pose.eye, pausedView.eye)
        c.togglePlayback()
        try await pump(c, renderer: r) { c.playbackPhase == .aiming }
        XCTAssertFalse(rig.twoViewOwnerIsManual, "The next shot resumes automatic framing")
        for (key, p) in stopped { XCTAssertEqual(c.scene.allBallNodes[key]?.simdPosition, p) }
        XCTAssertFalse(c.scene.cameraRig?.isTransitioning ?? true)
        try await pump(c, renderer: r, timeout: 120) { c.playbackState == .idle }
        XCTAssertNil(c.playbackMessage)
        XCTAssertEqual(c.stepLabel, "第 4/4 杆")
        XCTAssertEqual(c.playbackPhase, .finished)
        XCTAssertNotEqual(c.currentBoard().onTable.count, opening.onTable.count)
        let finalBoard = c.currentBoard()
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(c.currentBoard().onTable.count, finalBoard.onTable.count)
        c.play()
        XCTAssertEqual(c.currentBoard().onTable.count, opening.onTable.count)
        XCTAssertEqual(c.stepLabel, "第 1/4 杆")
        c.suspendPlayback()
    }

    func testMissingNextTargetStopsWithoutLoadingSavedBoard() async throws {
        let c = try await controller()
        let r = renderer(c)
        let steps = try XCTUnwrap(c.availableFormations.first { $0.token == "manual02" }).steps
        c.play()
        try await pump(c, renderer: r) { c.playbackPhase == .aiming }
        c.togglePlayback()
        try await pump(c, renderer: r) { c.playbackState == .paused }
        let target = try XCTUnwrap(c.scene.allBallNodes[steps[1].shot.targetKey])
        target.isHidden = true
        let positions = c.scene.allBallNodes.mapValues(\.simdPosition)
        let poses = c.scene.captureBallPoses()
        c.togglePlayback()
        try await pump(c, renderer: r) { c.playbackState == .idle }
        XCTAssertNotNil(c.playbackMessage)
        XCTAssertTrue(target.isHidden)
        for (key, p) in positions { XCTAssertEqual(c.scene.allBallNodes[key]?.simdPosition, p) }
        for (key, p) in poses { XCTAssertEqual(c.scene.allBallNodes[key]?.simdOrientation.vector, p.vector) }
    }
}

/// Regression for renderer-thread completion racing the next shot's live-board read.
@MainActor
final class SequenceArrangementRegressionTests: XCTestCase {
    private func makeController(_ id: String) async throws -> DrillSceneController {
        let loaded = await DrillContentService.shared.loadDrillFromBundle(id: id)
        let drill = try XCTUnwrap(loaded)
        let c = DrillSceneController()
        c.setup(drill: drill)
        c.scene.cameraRig?.viewportSize = CGSize(width: 390, height: 220)
        return c
    }

    private func renderer(_ c: DrillSceneController) -> SCNRenderer {
        let r = SCNRenderer(device: nil, options: nil)
        r.scene = c.scene
        r.pointOfView = c.scene.cameraNode
        return r
    }

    private func tick(_ r: SCNRenderer, rate: Double = 1) async throws {
        let time = ProcessInfo.processInfo.systemUptime * rate
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInteractive).async {
                r.update(atTime: time)
                done.resume()
            }
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }

    func testArrangementWaitsForSlowestBallAndCommitsExactBoard() async throws {
        let c = try await makeController("drill_c038")
        let board = try XCTUnwrap(c.availableFormations.first).steps[6].before
        let cue = try XCTUnwrap(c.scene.cueBallNode)
        cue.isPaused = true // One ball deliberately finishes after every other node.
        let r = renderer(c)
        var completions = 0
        SequenceSceneTransition.arrange(board, in: c.scene) {
            completions += 1
            SequenceSceneTransition.finishArrangement(board, in: c.scene)
            for (key, point) in board.onTable {
                let actual = c.scene.allBallNodes[key]!.position
                let expected = PositionPlayShotSolver.scenePoint(point, surfaceY: c.scene.surfaceY)
                XCTAssertEqual(actual.x, expected.x, accuracy: 0.000001, key)
                XCTAssertEqual(actual.z, expected.z, accuracy: 0.000001, key)
                XCTAssertFalse(c.scene.allBallNodes[key]!.isHidden)
            }
        }
        let start = ProcessInfo.processInfo.systemUptime
        while ProcessInfo.processInfo.systemUptime - start < 0.9 { try await tick(r) }
        XCTAssertEqual(completions, 0, "Do not advance merely because the nominal 0.45s elapsed")
        cue.isPaused = false
        while completions == 0, ProcessInfo.processInfo.systemUptime - start < 6 { try await tick(r) }
        XCTAssertEqual(completions, 1)
        let step = try XCTUnwrap(c.availableFormations.first).steps[6]
        let prediction = SequenceReplayResolver.solve(step: step, before: c.currentBoard(), surfaceY: c.scene.surfaceY)
        XCTAssertTrue(try XCTUnwrap(prediction).feasible, "Actual arranged board must satisfy the recorded trajectory")
    }

    func testCancelledArrangementCannotCompleteOverReplacement() async throws {
        let c = try await makeController("drill_c038")
        let steps = try XCTUnwrap(c.availableFormations.first).steps
        let r = renderer(c)
        var cancelledCompletions = 0
        var replacementCompletions = 0
        SequenceSceneTransition.arrange(steps[6].before, in: c.scene) { cancelledCompletions += 1 }
        try await tick(r)
        SequenceSceneTransition.cancelArrangement(in: c.scene)
        SequenceSceneTransition.arrange(steps[0].before, in: c.scene) {
            replacementCompletions += 1
            SequenceSceneTransition.finishArrangement(steps[0].before, in: c.scene)
        }
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        while ProcessInfo.processInfo.systemUptime < deadline { try await tick(r) }
        XCTAssertEqual(cancelledCompletions, 0)
        XCTAssertEqual(replacementCompletions, 1)
        for (key, point) in steps[0].before.onTable {
            let expected = PositionPlayShotSolver.scenePoint(point, surfaceY: c.scene.surfaceY)
            XCTAssertEqual(c.scene.allBallNodes[key]!.position.x, expected.x, accuracy: 0.000001)
            XCTAssertEqual(c.scene.allBallNodes[key]!.position.z, expected.z, accuracy: 0.000001)
        }
    }

    func testEveryBundledFormationCompletesProductionPlayback() async throws {
        let directory = try XCTUnwrap(Bundle.main.resourceURL).appendingPathComponent("DrillBoards")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("drill_c") && $0.pathExtension == "json" }
        let ids = Set(files.map { String($0.lastPathComponent.prefix(10)) }).sorted()
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let archives = try files.map { try decoder.decode(PositionPlaySequence.self, from: Data(contentsOf: $0)) }
        let empty = archives.filter { $0.steps.isEmpty }.count
        var formations = 0, shots = 0
        var playedFiles: Set<String> = []
        let playableFiles = Set(zip(files, archives).filter { !$0.1.steps.isEmpty }.map { $0.0.lastPathComponent })
        for id in ids {
            // Production intentionally excludes initial-only archives from sequence playback.
            if !playableFiles.contains(where: { $0.hasPrefix(id + "__") }) { continue }
            let current = await DrillContentService.shared.loadDrillFromBundle(id: id)
            let drill: DrillContent
            if let current {
                drill = current
            } else {
                // Retired catalog entries still have bundled sequences. Use their actual
                // archived metadata only to host the same production sequence consumer.
                let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                let retired = root.appendingPathComponent("content/retired-drills/Drills")
                let categories = try FileManager.default.contentsOfDirectory(at: retired, includingPropertiesForKeys: nil)
                let file = try XCTUnwrap(categories.map { $0.appendingPathComponent(id + ".json") }
                    .first { FileManager.default.fileExists(atPath: $0.path) }, id)
                drill = try JSONDecoder().decode(DrillContent.self, from: Data(contentsOf: file))
                print("PRODUCTION-REPLAY archived catalog metadata", id)
            }
            let c = DrillSceneController()
            c.setup(drill: drill)
            c.scene.cameraRig?.viewportSize = CGSize(width: 390, height: 220)
            let r = renderer(c)
            for formation in c.availableFormations {
                formations += 1
                c.switchFormation(token: formation.token)
                c.setCameraMode(formations.isMultiple(of: 2) ? .perspective3D : .topDown2D)
                XCTAssertTrue(playedFiles.insert(formation.fileName).inserted, formation.fileName)
                c.play()
                let deadline = ProcessInfo.processInfo.systemUptime + 150
                while c.isPlaying, ProcessInfo.processInfo.systemUptime < deadline {
                    try await tick(r, rate: 8)
                    c.scene.cameraRig?.update(deltaTime: 0.05)
                }
                XCTAssertFalse(c.isPlaying, "Timed out: \(id) \(formation.token) \(c.stepLabel)")
                XCTAssertNil(c.playbackMessage, "\(id) \(formation.token): \(c.playbackMessage ?? "")")
                XCTAssertEqual(c.stepLabel, "第 \(formation.steps.count)/\(formation.steps.count) 杆", "\(id) \(formation.token)")
                XCTAssertEqual(c.playbackPhase, .finished)
                shots += formation.steps.count
                print("PRODUCTION-REPLAY FINISHED", id, formation.token, "shots", formation.steps.count, "message", c.playbackMessage ?? "none")
                c.suspendPlayback()
            }
        }
        XCTAssertEqual(playedFiles, playableFiles)
        XCTAssertEqual(formations, 95)
        XCTAssertEqual(formations + empty, 98)
        XCTAssertEqual(shots, 629)
        XCTAssertEqual(empty, 3)
        print("PRODUCTION-REPLAY total=98 shots=629 empty=3")
    }

    func testTwoRailAndFivePointRepeatedPlayback() async throws {
        for (id, count) in [("drill_c038", 12), ("drill_c023", 8)] {
            let c = try await makeController(id)
            let r = renderer(c)
            for cycle in 0..<3 {
                c.setCameraMode(cycle == 1 ? .perspective3D : .topDown2D)
                c.play()
                let deadline = ProcessInfo.processInfo.systemUptime + 150
                var paused = false
                while c.isPlaying || c.playbackState == .paused {
                    try await tick(r, rate: 8)
                    c.scene.cameraRig?.update(deltaTime: 0.01)
                    if cycle == 2, !paused, c.playbackPhase == .arranging {
                        c.suspendPlayback()
                        let before = c.currentBoard()
                        for _ in 0..<5 { try await tick(r, rate: 8) }
                        for (key, point) in before.onTable {
                            XCTAssertEqual(c.currentBoard().onTable[key]?.x, point.x)
                            XCTAssertEqual(c.currentBoard().onTable[key]?.y, point.y)
                        }
                        c.togglePlayback()
                        paused = true
                    }
                    if ProcessInfo.processInfo.systemUptime > deadline { XCTFail("Timed out: \(id) cycle \(cycle) \(c.stepLabel)"); break }
                }
                XCTAssertNil(c.playbackMessage, "\(id) cycle \(cycle): \(c.playbackMessage ?? "")")
                XCTAssertEqual(c.stepLabel, "第 \(count)/\(count) 杆")
                XCTAssertEqual(c.playbackPhase, .finished)
                if cycle == 2 { XCTAssertTrue(paused) }
                print("ARRANGEMENT-REPLAY PASS", id, "cycle", cycle + 1, "shots", count)
            }
        }
    }
}
