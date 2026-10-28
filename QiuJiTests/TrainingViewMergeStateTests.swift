import XCTest
import SwiftData
import SceneKit
@testable import QiuJi

@MainActor
final class TrainingViewMergeStateTests: XCTestCase {
    func testFullSceneTopDownKeepsTableProjectionInsideOriginalReservation() throws {
        for (size, rect) in [(CGSize(width: 874, height: 402), CGRect(x: 120, y: 62, width: 630, height: 320)),
                             (CGSize(width: 1032, height: 1376), CGRect(x: 172, y: 95, width: 688, height: 1240))] {
            for rotated in [false, true] {
                let scene = SCNScene(), camera = SCNNode()
                camera.camera = SCNCamera(); camera.camera?.projectionDirection = .vertical
                scene.rootNode.addChildNode(camera)
                let rig = CameraRig(cameraNode: camera, tableSurfaceY: 0.8)
                let view = SCNView(frame: CGRect(origin: .zero, size: rect.size))
                view.scene = scene; view.pointOfView = camera
                rig.viewportSize = rect.size
                rig.fitLandscapeTable(viewSize: rect.size, rotated: rotated)
                if rotated { rig.applyTopDown2DRotated() } else { rig.applyTopDown2D() }
                SCNTransaction.flush()
                let points = [SCNVector3(0, 0.8, 0), SCNVector3(-1.4, 0.8, -0.75), SCNVector3(1.4, 0.8, 0.75)]
                let original = points.map { view.projectPoint($0) }
                let fullView = SCNView(frame: CGRect(origin: .zero, size: size))
                fullView.scene = scene; fullView.pointOfView = camera
                rig.viewportSize = size; rig.topDownPresentationRect = rect
                if rotated { rig.applyTopDown2DRotated() } else { rig.applyTopDown2D() }
                SCNTransaction.flush()
                for (point, old) in zip(points, original) {
                    let new = fullView.projectPoint(point)
                    XCTAssertEqual(Double(new.x), Double(old.x) + rect.minX, accuracy: 0.05)
                    XCTAssertEqual(Double(new.y), Double(old.y) + rect.minY, accuracy: 0.05)
                }
            }
        }
    }

    func testSevenProjectsKeepSameRoomFloorAcrossProjectionAndStyleChanges() throws {
        for project in TrainingProject.allCases {
            let scene = AngleTrainingScene()
            scene.tablePreferencePage = project.page2D
            scene.setupScene(recipe: .liveReference, roomStyle: .tournament)
            let room = try XCTUnwrap(scene.rootNode.childNode(withName: "reference_room", recursively: false))
            let floor = try XCTUnwrap(room.childNode(withName: "room_floor", recursively: false))
            let originalTransform = floor.simdTransform
            for mode in [AngleTrainingScene.CameraMode.topDown2D, .perspective3D, .topDown2DRotated, .perspective3D] {
                scene.setCameraMode(mode, animated: false)
                XCTAssertFalse(room.isHidden, project.rawValue)
                XCTAssertFalse(floor.isHidden)
                XCTAssertTrue(room.childNode(withName: "room_floor", recursively: false) === floor)
                XCTAssertEqual(floor.simdTransform, originalTransform)
            }
        }
        let scene = AngleTrainingScene()
        scene.tablePreferencePage = TrainingProject.accuracy.page2D
        scene.setupScene(recipe: .liveReference)
        scene.setCameraMode(.topDown2DRotated, animated: false)
        for style in RoomStyle.allCases {
            scene.installReferenceRoom(style: style)
            XCTAssertEqual(scene.rootNode.childNode(withName: "reference_room", recursively: false)?.isHidden, false)
        }
    }

    func testCheckpointKeepsBothSessionsAndOwnerIsolation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = TrainingCheckpointStore<String>(project: .angle, owner: "a", root: root)
        let b = TrainingCheckpointStore<String>(project: .angle, owner: "b", root: root)
        try a.save("old", id: UUID(), now: Date(timeIntervalSince1970: 1))
        try a.save("latest", id: UUID(), now: Date(timeIntervalSince1970: 2))
        XCTAssertEqual(try a.latest(where: { _ in true }), "latest")
        XCTAssertEqual(try a.latest(where: { $0 == "old" }), "old")
        XCTAssertNil(try b.latest(where: { _ in true }))
    }
    func testPendingAnswerSurvivesReopenAndAcknowledgementIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let owner = CurrentOwnerContext.shared.ownerKey
        let store = try SceneTrainingPersistence(project: .angle, owner: owner, root: root)
        var run = SceneTrainingRun(), views = TrainingPresentation(is3D: false)
        let question = try TrainingBankStore.load().draw(.init(), seed: 33, count: 15).boards[0]
        run.current = .init(id: UUID(), geometry: question.question.geometry, side: question.side,
                            cueBand: question.cueBand, pocketBand: question.pocketBand)
        let id = try XCTUnwrap(run.current?.id)
        views.observe(.twoD, questionID: id); views.current = .threeD
        views.accept(questionID: id, at: Date(), premium: false)
        run.record(error: 1, signedError: 1, angle: question.angle)
        let answer = AngleTestResult(actualAngle: question.angle, userAngle: question.angle + 1,
                                     pocketType: "corner", quizType: "scene3D", ownerKey: owner)
        try store.save(run: run, presentation: views, targetNumber: 3, input: "21", accepting: .init(answer))
        let reopened = try SceneTrainingPersistence(project: .angle, owner: owner, root: root)
        XCTAssertEqual(reopened.current?.pending.map(\.id), [answer.id])
        XCTAssertEqual(reopened.current?.presentation.label(for: id), "混合视图")
        XCTAssertEqual(reopened.current?.run.id, run.id)
        try reopened.acknowledge(answer.id); try reopened.acknowledge(answer.id)
        let acknowledged = try SceneTrainingPersistence(project: .angle, owner: owner, root: root)
        XCTAssertEqual(acknowledged.current?.pending.count, 0)
        XCTAssertEqual(acknowledged.current?.answers.map(\.id), [answer.id])
        XCTAssertEqual(acknowledged.current?.presentation.receipts.count, 1)
    }
    func testProjectPreferenceMigratesOneSourceAndPreservesLegacyDictionaries() throws {
        let suite = "merge-preferences-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy: [String: Any] = ["version": 1, "general": ["grid": 0],
            "pages": ["separationPractice2D": ["grid": 1], "separationPractice3D": ["grid": 0]]]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: TablePreferencesStore.storageKey)
        let prefs = TablePreferencesStore(defaults: defaults)
        XCTAssertFalse(prefs.beginTraining(.separation, source3D: false))
        XCTAssertTrue(prefs.snapshot(for: .separationPractice3D).enabled(.grid))
        prefs.apply(.view3D, value: 1, to: .separationPractice2D)
        XCTAssertTrue(prefs.beginTraining(.separation, source3D: false))
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(defaults.data(forKey: TablePreferencesStore.storageKey))) as? [String: Any])
        XCTAssertEqual((saved["pages"] as? NSDictionary), legacy["pages"] as? NSDictionary)
    }
    func testSevenProjectsShareQuotaAndFreeViewAliases() {
        for project in TrainingProject.allCases {
            XCTAssertEqual(project.roundCount, project == .multiBall ? 3 : 15)
            XCTAssertTrue(AngleUsageLimiter.training(route: project.page2D.rawValue) === AngleUsageLimiter.training(route: project.page3D.rawValue))
        }
        for route: AngleRoute in [.sceneAiming3D, .aimPointScene3D, .accuracy3D, .separationPractice3D, .twoBallPractice3D, .threeBallPractice3D, .multiBallPractice3D] {
            XCTAssertFalse(route.requiresPremium)
        }
        XCTAssertTrue(AngleRoute.snakePractice.requiresPremium)
        XCTAssertEqual(AngleUsageLimiter.shared.limit, 20)
    }
    func testMultiBallCheckpointRestoresRackInputsViewAndMeasurementWithoutChargingAgain() async throws {
        let suite = "merge-rack-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: "multiBallPractice", limit: 3)
        let host = PositionPlayViewModel(); host.setupScene(loadsDefaultLayout: false)
        defer { host.suspendAuthoringActivity() }
        var configuration = MultiBallConfiguration(); configuration.positionMode = .independent
        let controller = MultiBallPracticeController(configuration: configuration, defaults: defaults, limiter: limiter)
        controller.attach(to: host)
        XCTAssertNotNil(controller.rack)
        host.selectPocket(at: 2)
        host.velocity = 2.7; host.spinX = 0.2; host.spinY = -0.3
        for _ in 0..<300 where host.isComputing || host.cameraTransitionBusy {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(host.isComputing); XCTAssertFalse(host.cameraTransitionBusy)
        host.prepareGeometryReference()
        host.geometryReference.select(3)
        host.geometryReference.drag(to: .init(-1.1, 0, -0.4))
        XCTAssertTrue(controller.switchTrainingView(to: true))
        _ = ShotPlayCamera.setMode(.perspective3D, on: host)
        controller.saveCheckpoint()
        XCTAssertNil(controller.checkpointError)
        let used = limiter.questionsUsedToday, input = host.trainingInput
        let snapshot = host.geometryReference.snapshot
        let restoredHost = PositionPlayViewModel(); restoredHost.setupScene(loadsDefaultLayout: false)
        defer { restoredHost.suspendAuthoringActivity() }
        let reopened = MultiBallPracticeController(defaults: defaults, limiter: limiter)
        reopened.attach(to: restoredHost)
        XCTAssertNil(reopened.checkpointError)
        XCTAssertEqual(reopened.rack?.sourceID, controller.rack?.sourceID)
        XCTAssertEqual(reopened.remaining, controller.remaining)
        XCTAssertTrue(reopened.is3D)
        XCTAssertEqual(restoredHost.velocity, 2.7)
        XCTAssertEqual(restoredHost.spinX, 0.2)
        XCTAssertEqual(restoredHost.spinY, -0.3)
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(restoredHost.trainingInput), try encoder.encode(input))
        XCTAssertEqual(restoredHost.geometryReference.draft, snapshot.draft)
        XCTAssertEqual(restoredHost.geometryReference.visible, snapshot.visible)
        XCTAssertEqual(limiter.questionsUsedToday, used)
    }
    func testGeometryCheckpointPreservesRetryAfterResultAndNextShot() throws {
        let scene = AngleTrainingScene()
        // A strong scene is required by the scene-backed tool.
        let live = GeometricReferenceTool(scene: scene)
        live.update(identity: "question-stage-1", cue: .init(-0.6,0,-0.25), target: .init(0,0,0), pocketIndex: 3)
        live.select(5); live.drag(to: .init(-1.2,0,-0.5))
        let original = live.draft
        live.freeze(); live.complete()
        let payload = try JSONEncoder().encode(live.snapshot)
        let reopened = GeometricReferenceTool(scene: scene)
        reopened.restore(try JSONDecoder().decode(GeometricReferenceTool.Snapshot.self, from: payload))
        XCTAssertFalse(reopened.visible)
        reopened.restore()
        XCTAssertTrue(reopened.visible); XCTAssertEqual(reopened.draft, original)
        reopened.nextShot()
        XCTAssertFalse(reopened.visible); XCTAssertEqual(reopened.draft.reflections, 0)
    }

    func testMultiBallCompletedRoundRestoresEndStateWithoutDrawingOrCharging() async throws {
        let suite = "merge-round-end-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AngleUsageLimiter(defaults: defaults, namespace: "multiBallPractice", limit: 3)
        let host = PositionPlayViewModel(); host.setupScene(loadsDefaultLayout: false)
        defer { host.suspendAuthoringActivity() }
        var configuration = MultiBallConfiguration(); configuration.positionMode = .independent
        let controller = MultiBallPracticeController(configuration: configuration, defaults: defaults, limiter: limiter)
        controller.attach(to: host)
        controller.nextRack(); controller.nextRack()
        for _ in 0..<300 where host.isComputing || host.cameraTransitionBusy {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(host.isComputing)
        controller.nextRack()
        XCTAssertTrue(controller.showSessionEnd)
        // SwiftUI dismissing the alert must not reopen the finished round on disk.
        controller.showSessionEnd = false; controller.saveCheckpoint()
        XCTAssertNil(controller.checkpointError)
        let restoredHost = PositionPlayViewModel(); restoredHost.setupScene(loadsDefaultLayout: false)
        defer { restoredHost.suspendAuthoringActivity() }
        let reopened = MultiBallPracticeController(defaults: defaults, limiter: limiter)
        reopened.attach(to: restoredHost)
        XCTAssertTrue(reopened.showSessionEnd)
        XCTAssertEqual(reopened.questionNumber, 3)
        XCTAssertEqual(reopened.rack?.sourceID, controller.rack?.sourceID)
        XCTAssertEqual(limiter.questionsUsedToday, 3)
        XCTAssertNil(reopened.checkpointError)
    }

    func testLatestCompatibleLegacyDraftWinsAcrossViewsWithoutDeletingOtherDraft() throws {
        let container = try ModelContainer(for: TrainingSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let repo = LocalSeparationPracticeRepository(context: container.mainContext, enqueue: { _, _ in })
        let prepared = try SeparationQuestionGenerator.prepare(.init(), seed: 20261022)
        let owner = CurrentOwnerContext.shared.ownerKey
        var older = SeparationPracticeRecord(ownerKey: owner, is3D: false, configuration: .init(), prepared: prepared)
        older.updatedAt = Date(timeIntervalSince1970: 10)
        var newer = SeparationPracticeRecord(ownerKey: owner, is3D: true, configuration: .init(),
            prepared: .init(fingerprint: "old-bank", question: prepared.question))
        newer.updatedAt = Date(timeIntervalSince1970: 20)
        try repo.saveAtomically([older, newer])
        XCTAssertEqual(try repo.resumable(is3D: false)?.id, newer.id)
        XCTAssertEqual(try repo.resumable(is3D: true, compatible: { $0.bankFingerprint == prepared.fingerprint })?.id, older.id)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<TrainingSession>()), 2)
    }

}
