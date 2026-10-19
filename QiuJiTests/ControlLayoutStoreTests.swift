import XCTest
#if canImport(QiuJi)
@testable import QiuJi
#else
@testable import ControlLayoutHarness
#endif

final class ControlLayoutStoreTests: XCTestCase {
    @MainActor func test_localTemplatePinPersistsAndLibrarySeparatesPagesAndModes() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk)
        let point = FreeControlPlacement(x: 0.2, y: 0.4, scale: 1.2)
        let first = UUID(), second = UUID()
        try store.saveNew(id: first, name: "甲", page: .dailyClearance, mode: .twoD, values: ["shot.undo": point], expectedPageRevision: 0)
        try store.saveNew(id: second, name: "乙", page: .dailyClearance, mode: .twoD, values: ["shot.undo": point], expectedPageRevision: 1)
        try store.saveNew(id: UUID(), name: "其他模式", page: .dailyClearance, mode: .threeD, values: ["shot.undo": point], expectedPageRevision: 0)
        try store.saveNew(id: UUID(), name: "其他页面", page: .freePlay, mode: .twoD, values: ["shot.undo": point], expectedPageRevision: 0)
        XCTAssertEqual(store.localTemplates(page: .dailyClearance, mode: .twoD).map(\.id), [second, first])
        try store.setPinned(try XCTUnwrap(store.archive.templates.first { $0.id == first }), pinned: true)
        let reloaded = FreeControlLayoutStore(storage: disk)
        XCTAssertEqual(reloaded.localTemplates(page: .dailyClearance, mode: .twoD).map(\.id), [first, second])
        XCTAssertEqual(reloaded.pageRevision(page: .dailyClearance, mode: .twoD), 2)
        try reloaded.setPinned(try XCTUnwrap(reloaded.archive.templates.first { $0.id == first }), pinned: false)
        XCTAssertEqual(reloaded.localTemplates(page: .dailyClearance, mode: .twoD).map(\.id), [second, first])
    }

    @MainActor func test_localTemplateUpdatePreservesIdentityAndDeletePreservesAppliedLayout() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk), id = UUID()
        let old = FreeControlPlacement(x: 0.2, y: 0.4, scale: 1.2)
        let edited = FreeControlPlacement(x: -0.1, y: 0.7, scale: 1.8)
        try store.saveNew(id: id, name: "甲", page: .dailyClearance, mode: .twoD, values: ["shot.undo": old], expectedPageRevision: 0)
        let template = try XCTUnwrap(store.archive.templates.first)
        try store.updateLocal(template, name: "改后", values: ["shot.undo": edited], expectedPageRevision: 1,
                              sourceWindow: .init(width: 874, height: 402))
        XCTAssertEqual(store.archive.templates.count, 1)
        XCTAssertEqual(store.archive.templates.first?.id, id)
        XCTAssertEqual(store.values(page: .dailyClearance, mode: .twoD)["shot.undo"], edited)
        XCTAssertTrue(store.values(page: .dailyClearance, mode: .threeD).isEmpty)
        XCTAssertTrue(store.values(page: .freePlay, mode: .twoD).isEmpty)
        try store.delete(try XCTUnwrap(store.archive.templates.first))
        XCTAssertTrue(store.archive.templates.isEmpty)
        XCTAssertEqual(FreeControlLayoutStore(storage: disk).values(page: .dailyClearance, mode: .twoD)["shot.undo"], edited)
    }

    @MainActor func test_localTemplateUpdateRejectsStaleTemplateAndDoesNotPublishFailedWrites() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk), id = UUID()
        let point = FreeControlPlacement(x: 0.2, y: 0.4, scale: 1.2)
        try store.saveNew(id: id, name: "甲", page: .dailyClearance, mode: .twoD, values: ["shot.undo": point], expectedPageRevision: 0)
        let stale = try XCTUnwrap(store.archive.templates.first)
        try store.setPinned(stale, pinned: true)
        XCTAssertThrowsError(try store.updateLocal(stale, name: "旧编辑", values: [:], expectedPageRevision: 1,
                                                  sourceWindow: .init(width: 874, height: 402))) {
            XCTAssertEqual($0 as? ControlLayoutError, .conflict)
        }
        let before = store.archive, bytes = disk.data
        disk.failWrite = true
        XCTAssertThrowsError(try store.updateLocal(try XCTUnwrap(store.archive.templates.first), name: "写入失败", values: [:],
                                                  expectedPageRevision: 1, sourceWindow: .init(width: 874, height: 402)))
        XCTAssertEqual(store.archive, before)
        XCTAssertEqual(disk.data, bytes)
    }

    @MainActor func test_freeAngleKeypadSharesKeysWithoutAliasingShotOrModes() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk), id = UUID()
        let point = FreeControlPlacement(x: -0.1, y: 0.2, scale: 1.375)
        try store.saveNew(id: id, name: "角度", page: .sceneAiming2D, mode: .twoD,
            values: ["angle.digit.3": point, "angle.submit": point, "angle.next": point], expectedPageRevision: 0)
        XCTAssertThrowsError(try store.apply(id, page: .dailyClearance, mode: .twoD, expectedPageRevision: 0)) {
            XCTAssertEqual($0 as? ControlLayoutError, .noCommonControls)
        }
        XCTAssertThrowsError(try store.apply(id, page: .sceneAiming3D, mode: .threeD, expectedPageRevision: 0)) {
            XCTAssertEqual($0 as? ControlLayoutError, .modeMismatch)
        }
        XCTAssertTrue(FreeControlCatalog.ids(page: .sceneAiming3D, mode: .twoD).isEmpty)
        XCTAssertEqual(FreeControlCatalog.ids(page: .sceneAiming2D, mode: .twoD).count, 16)
        try store.apply(id, page: .sceneAiming2D, mode: .twoD, expectedPageRevision: 1)
        XCTAssertEqual(store.values(page: .sceneAiming2D, mode: .twoD)["angle.next"], point)
        XCTAssertTrue(store.values(page: .sceneAiming3D, mode: .threeD).isEmpty)
        XCTAssertEqual(FreeControlLayoutStore(storage: disk).archive, store.archive)
    }

    @MainActor func test_freeTeachingTemplatesShareInstrumentsNotDistinctLegends() throws {
        let store = FreeControlLayoutStore(storage: MemoryStorage()), source = UUID()
        let shared = FreeControlPlacement(x: -0.03, y: 0.6, scale: 1.375)
        let local = FreeControlPlacement(x: 0.9, y: 0.7, scale: 0.85)
        try store.saveNew(id: source, name: "分离角", page: .separationAngleAtlas, mode: .twoD,
            values: ["separation.legend.0": shared, "shot.spin": shared, "shot.power": shared], expectedPageRevision: 0)
        try store.saveNew(id: UUID(), name: "吃库", page: .cushionEnglishAtlas, mode: .twoD,
            values: ["cushion.legend.0": local], expectedPageRevision: 0)
        try store.apply(source, page: .cushionEnglishAtlas, mode: .twoD, expectedPageRevision: 1)
        XCTAssertEqual(store.values(page: .cushionEnglishAtlas, mode: .twoD),
            ["cushion.legend.0": local, "shot.spin": shared, "shot.power": shared])
        XCTAssertThrowsError(try store.apply(source, page: .angleDynamic, mode: .twoD, expectedPageRevision: 0)) {
            XCTAssertEqual($0 as? ControlLayoutError, .noCommonControls)
        }
        XCTAssertTrue(FreeControlCatalog.ids(page: .angleDynamic, mode: .twoD).isEmpty)
        XCTAssertEqual(FreeControlCatalog.ids(page: .angleDynamic, mode: .threeD),
            ["camera.overview", "camera.thirdPerson", "camera.firstPerson", "camera.temporaryTopDown"])
        XCTAssertEqual(FreeControlCatalog.ids(page: .separationAngleAtlas, mode: .twoD).count, 10)
        XCTAssertTrue(store.values(page: .cushionEnglishAtlas, mode: .threeD).isEmpty)
    }

    @MainActor func test_freePlanningCapabilitiesPreserveDistinctToolsAndHiddenStages() throws {
        let store = FreeControlLayoutStore(storage: MemoryStorage())
        let source = UUID(), local = FreeControlPlacement(x: 0.8, y: 0.2, scale: 0.8)
        let shared = FreeControlPlacement(x: -0.04, y: 0.7, scale: 1.37)
        try store.saveNew(id: source, name: "规划", page: .planThree, mode: .twoD,
            values: ["planning.roles": shared, "planning.constraintTool": shared, "planning.clearConstraint": shared,
                     "planning.solve": shared, "planning.nextSolution": shared, "break.strike": shared], expectedPageRevision: 0)
        try store.saveNew(id: UUID(), name: "防守", page: .snookerTactics, mode: .twoD,
            values: ["defense.targetTool": local, "defense.clearSelection": local], expectedPageRevision: 0)
        try store.apply(source, page: .snookerTactics, mode: .twoD, expectedPageRevision: 1)
        XCTAssertEqual(store.values(page: .snookerTactics, mode: .twoD),
            ["defense.targetTool": local, "defense.clearSelection": local,
             "planning.solve": shared, "planning.nextSolution": shared])
        try store.apply(source, page: .bankShot, mode: .twoD, expectedPageRevision: 0)
        XCTAssertEqual(store.values(page: .bankShot, mode: .twoD), ["planning.nextSolution": shared])
        let solver = UUID()
        try store.saveNew(id: solver, name: "翻袋", page: .bankShot, mode: .twoD,
            values: ["solver.mode": shared, "solver.cushions": local, "shot.aim": shared], expectedPageRevision: 1)
        try store.apply(solver, page: .diamondSystem, mode: .twoD, expectedPageRevision: 0)
        XCTAssertEqual(store.values(page: .diamondSystem, mode: .twoD),
            ["solver.mode": shared, "solver.cushions": local, "shot.aim": shared])
        XCTAssertThrowsError(try store.apply(solver, page: .snookerTactics, mode: .twoD, expectedPageRevision: 2)) {
            XCTAssertEqual($0 as? ControlLayoutError, .noCommonControls)
        }
        XCTAssertTrue(FreeControlCatalog.ids(page: .planThree, mode: .twoD).contains("break.confirm"))
        XCTAssertFalse(FreeControlCatalog.ids(page: .planThree, mode: .twoD).contains("break.entry"))
        XCTAssertFalse(FreeControlCatalog.ids(page: .snookerTactics, mode: .twoD).contains("shot.aim"))
        XCTAssertTrue(store.values(page: .planThree, mode: .threeD).isEmpty)
    }

    @MainActor func test_freeTrialNavigationAndSnakeCompletionDoNotAliasShotActions() throws {
        let store = FreeControlLayoutStore(storage: MemoryStorage()), source = UUID()
        let sourcePoint = FreeControlPlacement(x: -0.1, y: 0.3, scale: 1.4)
        let local = FreeControlPlacement(x: 0.6, y: 0.8)
        try store.saveNew(id: UUID(), name: "试打", page: .drillTryout, mode: .twoD,
                          values: ["tryout.previous": local, "tryout.next": local, "sequence.play": local], expectedPageRevision: 0)
        try store.saveNew(id: source, name: "击球", page: .dailyClearance, mode: .twoD,
                          values: ["shot.undo": sourcePoint, "shot.replay": sourcePoint, "shot.power": sourcePoint], expectedPageRevision: 0)
        try store.apply(source, page: .drillTryout, mode: .twoD, expectedPageRevision: 1)
        let trial = store.values(page: .drillTryout, mode: .twoD)
        XCTAssertEqual(trial["tryout.previous"], local); XCTAssertEqual(trial["tryout.next"], local)
        XCTAssertEqual(trial["sequence.play"], local); XCTAssertEqual(trial["shot.power"], sourcePoint)
        XCTAssertNil(trial["shot.undo"]); XCTAssertNil(trial["shot.replay"])
        let snake = UUID()
        try store.saveNew(id: snake, name: "下一组", page: .snakePractice, mode: .twoD,
                          values: ["snake.next": sourcePoint, "snake.restart": local], expectedPageRevision: 0)
        XCTAssertThrowsError(try store.apply(snake, page: .composer, mode: .twoD, expectedPageRevision: 0)) {
            XCTAssertEqual($0 as? ControlLayoutError, .noCommonControls)
        }
        XCTAssertTrue(store.values(page: .composer, mode: .twoD).isEmpty)
        let playbackOnly = UUID()
        try store.saveNew(id: playbackOnly, name: "演示", page: .drillTryout, mode: .twoD,
                          values: ["sequence.play": local], expectedPageRevision: 2)
        XCTAssertThrowsError(try store.apply(playbackOnly, page: .composer, mode: .twoD, expectedPageRevision: 0)) {
            XCTAssertEqual($0 as? ControlLayoutError, .noCommonControls)
        }
    }

    @MainActor func test_freeTemplateIntersectionPreservesTargetAndHiddenStages() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk), sourceID = UUID()
        let a = FreeControlPlacement(x: -0.03, y: 0.4, scale: 1.37)
        let b = FreeControlPlacement(x: 0.9, y: 0.8, scale: 0.73)
        let target: FreeControlValues = ["planning.solve": b, "shot.undo": b]
        try store.saveNew(id: UUID(), name: "目标", page: .silu, mode: .twoD, values: target, expectedPageRevision: 0)
        let source: FreeControlValues = ["shot.undo": a, "shot.power": a, "break.entry": a, "break.strike": b]
        try store.saveNew(id: sourceID, name: "源", page: .dailyClearance, mode: .twoD, values: source, expectedPageRevision: 0)
        let original = store.archive.templates
        try store.apply(sourceID, page: .silu, mode: .twoD, expectedPageRevision: 1)
        let applied = store.values(page: .silu, mode: .twoD)
        XCTAssertEqual(applied["shot.undo"], a); XCTAssertEqual(applied["shot.power"], a)
        XCTAssertEqual(applied["planning.solve"], b)
        XCTAssertNil(applied["break.entry"])
        XCTAssertEqual(applied["break.strike"], b, "Legitimate hidden-stage control must survive")
        XCTAssertEqual(store.archive.templates, original)
        XCTAssertEqual(store.values(page: .dailyClearance, mode: .twoD), source)
        XCTAssertTrue(store.values(page: .silu, mode: .threeD).isEmpty)
        try store.apply(sourceID, page: .silu, mode: .twoD, expectedPageRevision: 2)
        XCTAssertEqual(store.values(page: .silu, mode: .twoD), applied)
    }

    @MainActor func test_freeTemplateWrongModeAndZeroIntersectionAreNotSuccessfulWrites() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk), id = UUID()
        try store.saveNew(id: id, name: "无交集", page: .dailyClearance, mode: .twoD,
                          values: ["unknown.futureControl": .init(x: 0.4, y: 0.6)], expectedPageRevision: 0)
        let bytes = disk.data, before = store.archive
        XCTAssertThrowsError(try store.apply(id, page: .silu, mode: .threeD, expectedPageRevision: 0)) {
            XCTAssertEqual($0 as? ControlLayoutError, .modeMismatch)
        }
        XCTAssertThrowsError(try store.apply(id, page: .silu, mode: .twoD, expectedPageRevision: 0)) {
            XCTAssertEqual($0 as? ControlLayoutError, .noCommonControls)
        }
        XCTAssertEqual(store.archive, before); XCTAssertEqual(disk.data, bytes)
    }

    @MainActor func test_freeDerivedTemplateIsPrivateAndKeepsSourceOnlyRecordsAndNames() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk), id = UUID(), derivedID = UUID()
        let original: FreeControlValues = ["shot.undo": .init(x: 0.1, y: 0.5), "break.entry": .init(x: -0.1, y: 0.2)]
        try store.saveNew(id: id, name: " 同名 · 2D · 3D ", page: .dailyClearance, mode: .twoD,
                          values: original, expectedPageRevision: 0)
        let template = try XCTUnwrap(store.archive.templates.first), bytes = disk.data
        var draft = try template.merging(into: [:], page: .silu, mode: .twoD)
        draft["planning.solve"] = .init(x: 0.8, y: 0.7, scale: 1.2)
        XCTAssertEqual(disk.data, bytes, "Creating and editing the draft cannot apply it")
        let sourceOnly = template.values.filter { !FreeControlCatalog.ids(page: .silu, mode: .twoD).contains($0.key) }
        try store.saveNew(id: derivedID, name: "同名", page: .silu, mode: .twoD, values: draft,
                          sourceOnly: sourceOnly, expectedPageRevision: 0,
                          sourceWindow: .init(width: 874, height: 402), sourceTemplateID: id)
        let saved = try XCTUnwrap(store.archive.templates.last)
        XCTAssertEqual(saved.displayName, "同名 · 2D")
        XCTAssertEqual(saved.baseName, template.baseName); XCTAssertNotEqual(saved.id, template.id)
        XCTAssertEqual(saved.values["break.entry"], original["break.entry"])
        XCTAssertNil(store.values(page: .silu, mode: .twoD)["break.entry"])
        XCTAssertEqual(store.archive.templates.first, template)
        XCTAssertEqual(store.values(page: .dailyClearance, mode: .twoD), original)
        XCTAssertEqual(FreeControlLayoutStore(storage: disk).archive, store.archive)
    }

    @MainActor func test_freeDraftSurvivesLibraryDeletionButConflictsWithTargetWrite() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk), id = UUID()
        let values: FreeControlValues = ["shot.undo": .init(x: 0.2, y: 0.5)]
        try store.saveNew(id: id, name: "源", page: .dailyClearance, mode: .twoD, values: values, expectedPageRevision: 0)
        let editing = FreeControlLayoutStore(storage: disk)
        var external = store.archive
        external.templates.removeAll(); external.revision += 1
        disk.data = try JSONEncoder().encode(external)
        try editing.saveNew(id: UUID(), name: "派生", page: .silu, mode: .twoD, values: values,
                            expectedPageRevision: 0, sourceTemplateID: id)
        XCTAssertEqual(editing.archive.templates.count, 1)
        let stale = FreeControlLayoutStore(storage: disk)
        try editing.restore(page: .silu, mode: .twoD, expectedPageRevision: 1)
        let bytes = disk.data
        XCTAssertThrowsError(try stale.saveNew(id: UUID(), name: "过期", page: .silu, mode: .twoD,
                                              values: values, expectedPageRevision: 1)) {
            XCTAssertEqual($0 as? ControlLayoutError, .conflict)
        }
        XCTAssertEqual(disk.data, bytes)
    }

    @MainActor func test_freeSubmissionRetryIsIdempotentAndDoesNotReapplyAfterRestore() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk), id = UUID()
        let values: FreeControlValues = ["shot.undo": .init(x: 0.2, y: 0.5)]
        disk.failWrite = true
        XCTAssertThrowsError(try store.saveNew(id: id, name: "重复提交", page: .dailyClearance, mode: .twoD,
                                              values: values, expectedPageRevision: 0))
        XCTAssertTrue(store.archive.templates.isEmpty); XCTAssertNil(disk.data)
        disk.failWrite = false
        try store.saveNew(id: id, name: "重复提交", page: .dailyClearance, mode: .twoD, values: values, expectedPageRevision: 0)
        try store.restore(page: .dailyClearance, mode: .twoD, expectedPageRevision: 1)
        let bytes = disk.data
        try store.saveNew(id: id, name: "重复提交", page: .dailyClearance, mode: .twoD, values: values, expectedPageRevision: 0)
        XCTAssertEqual(disk.data, bytes); XCTAssertEqual(store.archive.templates.count, 1)
        XCTAssertTrue(store.values(page: .dailyClearance, mode: .twoD).isEmpty)
    }

    @MainActor func test_freeControlsPreserveUnboundedPlacementAndModeAfterReload() throws {
        let storage = MemoryStorage(), id = UUID()
        let store = FreeControlLayoutStore(storage: storage)
        let values: FreeControlValues = ["shot.undo": .init(x: -0.1, y: 1.08, scale: 1.371),
                                         "shot.replay": .init(x: 0.12, y: 0.88, scale: 1)]
        try store.saveNew(id: id, name: " 左手 ", page: .dailyClearance, mode: .twoD, values: values, expectedRevision: 0)
        let reloaded = FreeControlLayoutStore(storage: storage)
        XCTAssertNil(reloaded.loadError)
        XCTAssertEqual(reloaded.values(page: .dailyClearance, mode: .twoD), values)
        XCTAssertEqual(reloaded.archive.templates.first?.displayName, "左手 · 2D")
        XCTAssertTrue(reloaded.values(page: .dailyClearance, mode: .threeD).isEmpty)
        XCTAssertTrue(reloaded.values(page: .freePlay, mode: .twoD).isEmpty)
        XCTAssertEqual(reloaded.archive.templates.first?.id, id)
    }

    @MainActor func test_freeControlsFailedWriteAndStaleDraftNeverPartiallyCommit() throws {
        let storage = MemoryStorage(), store = FreeControlLayoutStore(storage: MemoryStorage())
        XCTAssertTrue(store.archive.templates.isEmpty)
        let writer = FreeControlLayoutStore(storage: storage), stale = FreeControlLayoutStore(storage: storage)
        let values: FreeControlValues = ["shot.undo": .init(x: 0.02, y: 0.8, scale: 1.4)]
        storage.failWrite = true
        XCTAssertThrowsError(try writer.saveNew(id: UUID(), name: "失败", page: .dailyClearance, mode: .twoD, values: values, expectedRevision: 0))
        XCTAssertTrue(writer.archive.templates.isEmpty)
        XCTAssertNil(storage.data)
        storage.failWrite = false
        try writer.saveNew(id: UUID(), name: "保留", page: .dailyClearance, mode: .twoD, values: values, expectedRevision: 0)
        let bytes = storage.data
        XCTAssertThrowsError(try stale.saveNew(id: UUID(), name: "过期", page: .dailyClearance, mode: .twoD, values: [:], expectedRevision: 0))
        XCTAssertEqual(storage.data, bytes)
        XCTAssertTrue(stale.archive.templates.isEmpty)
    }

    @MainActor func test_freeControlsRejectCorruptionAndNonFiniteWithoutOverwriting() throws {
        let storage = MemoryStorage()
        storage.data = Data("broken".utf8)
        let store = FreeControlLayoutStore(storage: storage)
        XCTAssertNotNil(store.loadError)
        XCTAssertThrowsError(try store.saveNew(id: UUID(), name: "x", page: .dailyClearance, mode: .twoD, values: [:], expectedRevision: 0))
        XCTAssertEqual(storage.data, Data("broken".utf8))
        XCTAssertThrowsError(try FreeControlPlacement(x: .nan, y: 0).validate())
        XCTAssertThrowsError(try FreeControlPlacement(x: 0, y: 0, scale: 0).validate())
        XCTAssertNoThrow(try FreeControlPlacement(x: -5, y: 12, scale: 3.5).validate())
    }
    @MainActor func test_freeManagementKeepsAppliedSnapshotsAndCopyOnlyDoesNotApply() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk), id = UUID()
        let values: FreeControlValues = ["shot.undo": .init(x: -0.2, y: 1.2, scale: 1.375)]
        try store.saveNew(id: id, name: "原名", page: .dailyClearance, mode: .twoD, values: values, expectedPageRevision: 0)
        try store.apply(id, page: .silu, mode: .twoD, expectedPageRevision: 0)
        let pages = store.archive.pages, revisions = store.archive.pageRevisions
        let original = try XCTUnwrap(store.archive.templates.first)
        try store.rename(original, to: " 新名 · 3D · 2D ")
        XCTAssertEqual(store.archive.templates.first?.displayName, "新名 · 2D")
        XCTAssertThrowsError(try store.delete(original))
        try store.delete(try XCTUnwrap(store.archive.templates.first))
        XCTAssertEqual(store.archive.pages, pages); XCTAssertEqual(store.archive.pageRevisions, revisions)
        var copy = original; copy.id = UUID(); copy.baseName = "冲突另存 · 2D"
        try store.saveCopyOnly(copy)
        let bytes = disk.data
        try store.saveCopyOnly(copy)
        XCTAssertEqual(disk.data, bytes); XCTAssertEqual(store.archive.pages, pages)
        XCTAssertEqual(store.archive.pageRevisions, revisions)
        XCTAssertThrowsError(try store.rename(try XCTUnwrap(store.archive.templates.first), to: " · 2D "))
    }

    @MainActor func test_freeRecoveryRequiresBackupAndAtomicWriteAndInvalidatesEmptyDrafts() throws {
        for raw in [Data("broken".utf8), Data("{\"schemaVersion\":99}".utf8)] {
            let disk = MemoryStorage(); disk.data = raw
            let store = FreeControlLayoutStore(storage: disk)
            XCTAssertNotNil(store.loadError)
            disk.failBackup = true
            XCTAssertThrowsError(try store.recoverWithDefault())
            XCTAssertEqual(disk.data, raw); XCTAssertEqual(store.archive.revision, 0)
            disk.failBackup = false; disk.failWrite = true
            XCTAssertThrowsError(try store.recoverWithDefault())
            XCTAssertEqual(disk.data, raw); XCTAssertNotNil(store.loadError)
            disk.failWrite = false
            try store.recoverWithDefault()
            XCTAssertNil(store.loadError); XCTAssertTrue(disk.backups.contains(raw))
            XCTAssertEqual(store.archive.legacyImportDisabled, true)
            XCTAssertThrowsError(try store.saveNew(id: UUID(), name: "旧草稿", page: .dailyClearance, mode: .twoD,
                                                  values: [:], expectedPageRevision: 0))
            XCTAssertEqual(FreeControlLayoutStore(storage: disk).archive, store.archive)
        }
    }

    @MainActor func test_freeLegacyMigrationUsesV1GeometryAndKeepsModesDomainsAndOverrides() throws {
        let disk = MemoryStorage(), legacy = MemoryStorage(), old = ControlLayoutStore(storage: legacy), id = UUID()
        let common = address(.replay), threeD = address(.replay, .offset, .threeD)
        let pad = address(.replay, .offset, .common, .padPortrait)
        try old.saveAs(id: id, name: "旧版", page: .dailyClearance,
                       edits: [common: .offset(8), threeD: .offset(16), pad: .offset(24)],
                       incorporating: [common, threeD, pad], expectedRevision: 0)
        try old.setFamilyDefault(.shot, template: id, expectedRevision: 1)
        try old.savePage(.dailyClearance, edits: [common: .offset(32)], expectedRevision: 2)
        let raw = legacy.data
        let store = FreeControlLayoutStore(storage: disk, legacyStorage: legacy)
        let input = ControlLayoutPlacement.Input(page: CGRect(x: 0, y: 0, width: 800, height: 400),
            leading: CGRect(x: 0, y: 44, width: 100, height: 312), trailing: CGRect(x: 700, y: 44, width: 100, height: 312),
            defaults: [.replay: CGRect(x: 20, y: 100, width: 44, height: 92)])
        let controls: [String: FreeControlLegacyMeasurements.Control] = [
            "shot.undo": .init(frame: CGRect(x: 20, y: 100, width: 44, height: 44), group: .replay),
            "shot.replay": .init(frame: CGRect(x: 20, y: 148, width: 44, height: 44), group: .replay)]
        func migrate(_ page: TablePreferencePage = .dailyClearance, _ mode: FreeControlLayoutMode = .twoD,
                     _ domain: ControlLayoutDomain = .phoneLandscape) throws {
            var measured = input
            let window = domain == .padPortrait ? FreeControlWindow(width: 400, height: 800) : .init(width: 800, height: 400)
            measured.page.size = .init(width: window.width, height: window.height)
            try store.migrateMeasuredPage(page: page, pageTitle: "页面", mode: mode, domain: domain,
                input: measured, controls: controls, window: window)
        }
        legacy.failBackup = true
        XCTAssertThrowsError(try migrate()); XCTAssertNil(disk.data); XCTAssertEqual(legacy.data, raw)
        legacy.failBackup = false; disk.failWrite = true
        XCTAssertThrowsError(try migrate()); XCTAssertNil(disk.data); XCTAssertTrue(store.archive.templates.isEmpty)
        disk.failWrite = false
        try migrate()
        XCTAssertEqual(store.archive.templates.count, 2, "Effective override and original template are separate")
        XCTAssertEqual(store.values(page: .dailyClearance, mode: .twoD)["shot.undo"]?.y, 154.0 / 400)
        XCTAssertEqual(store.values(page: .dailyClearance, mode: .twoD)["shot.replay"]?.y, 202.0 / 400)
        let bytes = disk.data, snapshot = store.values(page: .dailyClearance, mode: .twoD)
        try migrate(); XCTAssertEqual(disk.data, bytes)
        try migrate(.dailyClearance, .threeD)
        XCTAssertEqual(store.values(page: .dailyClearance, mode: .threeD)["shot.undo"]?.y, 154.0 / 400, "Page common override has priority over template mode values in v1")
        try migrate(.dailyClearance, .twoD, .padPortrait)
        XCTAssertEqual(store.values(page: .dailyClearance, mode: .twoD), snapshot, "Later window domains cannot replace an applied snapshot")
        try migrate(.freePlay)
        XCTAssertEqual(store.values(page: .freePlay, mode: .twoD)["shot.undo"]?.y, 130.0 / 400, "Family default expands separately")
        let removed = try XCTUnwrap(store.archive.templates.first)
        try store.delete(removed); let count = store.archive.templates.count
        try migrate(); XCTAssertEqual(store.archive.templates.count, count)
        XCTAssertEqual(legacy.data, raw); XCTAssertTrue(legacy.backups.contains(try XCTUnwrap(raw)))
    }

    @MainActor func test_freeLegacyPendingAndUnknownArchiveNeverInventPositions() throws {
        let disk = MemoryStorage(), legacy = MemoryStorage(), old = ControlLayoutStore(storage: legacy)
        try old.savePage(.dailyClearance, edits: [address(.replay): .offset(8)], expectedRevision: 0)
        let store = FreeControlLayoutStore(storage: disk, legacyStorage: legacy)
        let input = ControlLayoutPlacement.Input(page: CGRect(x: 0, y: 0, width: 800, height: 400),
            leading: CGRect(x: 0, y: 44, width: 100, height: 312), trailing: CGRect(x: 700, y: 44, width: 100, height: 312), defaults: [:])
        try store.migrateMeasuredPage(page: .dailyClearance, pageTitle: "每日清台", mode: .twoD, domain: .phoneLandscape,
                                     input: input, controls: [:], window: .init(width: 800, height: 400))
        XCTAssertTrue(store.archive.templates.isEmpty); XCTAssertTrue(store.archive.pages.isEmpty)
        XCTAssertEqual(store.archive.legacyRecords?.count, 1)
        let bytes = disk.data
        legacy.data = Data("{\"schemaVersion\":99}".utf8); store.reloadLegacy()
        XCTAssertNotNil(store.legacyError); XCTAssertNil(store.legacyArchive)
        try store.migrateMeasuredPage(page: .dailyClearance, pageTitle: "每日清台", mode: .twoD, domain: .phoneLandscape,
                                     input: input, controls: [:], window: .init(width: 800, height: 400))
        XCTAssertEqual(disk.data, bytes)
    }

    @MainActor func test_freeReadFailureAndIdenticalRestoreKeepDraftConflictProtection() throws {
        let disk = MemoryStorage(), store = FreeControlLayoutStore(storage: disk)
        try store.saveNew(id: UUID(), name: "原样", page: .dailyClearance, mode: .twoD, values: [:], expectedPageRevision: 0)
        let before = store.archive, bytes = disk.data
        disk.failRead = true; store.reload()
        XCTAssertNotNil(store.loadError); XCTAssertEqual(store.archive, before)
        XCTAssertThrowsError(try store.restore(page: .dailyClearance, mode: .twoD, expectedPageRevision: 1))
        XCTAssertEqual(disk.data, bytes)
        disk.failRead = false; store.reload(); XCTAssertNil(store.loadError)
        try store.restore(page: .dailyClearance, mode: .twoD, expectedPageRevision: 1)
        XCTAssertThrowsError(try store.saveNew(id: UUID(), name: "过期空草稿", page: .dailyClearance, mode: .twoD,
                                              values: [:], expectedPageRevision: 1))
        XCTAssertEqual(store.archive.templates.count, 1)
    }

    func test_freeLegacyFallbackRemainsPendingRatherThanMaterializingDefault() throws {
        var legacy = ControlLayoutArchive()
        legacy.bindings[.dailyClearance] = .init(overrides: [address(.replay): .offset(8)])
        let input = ControlLayoutPlacement.Input(page: CGRect(x: 0, y: 0, width: 800, height: 400),
            leading: CGRect(x: 0, y: 44, width: 100, height: 312), trailing: CGRect(x: 700, y: 44, width: 100, height: 312),
            defaults: [.replay: CGRect(x: 20, y: 100, width: 44, height: 92)], defaultFits: false)
        let result = FreeControlLegacyConverter.convert(legacy, page: .dailyClearance, mode: .twoD, domain: .phoneLandscape,
            input: input, controls: ["shot.undo": .init(frame: CGRect(x: 20, y: 100, width: 44, height: 44), group: .replay)],
            window: .init(width: 800, height: 400))
        XCTAssertTrue(result.values.isEmpty); XCTAssertNotNil(result.pending)
    }

    func test_freeLegacyRejectsTransientPortraitForPhoneLandscape() {
        var legacy = ControlLayoutArchive()
        legacy.bindings[.dailyClearance] = .init(overrides: [address(.replay): .offset(8)])
        let input = ControlLayoutPlacement.Input(page: CGRect(x: 0, y: 0, width: 375, height: 667),
            leading: CGRect(x: 0, y: 44, width: 100, height: 600), trailing: CGRect(x: 275, y: 44, width: 100, height: 600),
            defaults: [.replay: CGRect(x: 20, y: 100, width: 44, height: 92)])
        let controls: [String: FreeControlLegacyMeasurements.Control] = ["shot.undo": .init(frame: CGRect(x: 20, y: 100, width: 44, height: 44), group: .replay)]
        let result = FreeControlLegacyConverter.convert(legacy, page: .dailyClearance, mode: .twoD, domain: .phoneLandscape,
            input: input, controls: controls, window: .init(width: 375, height: 667))
        XCTAssertTrue(result.values.isEmpty); XCTAssertNotNil(result.pending)
        let mismatch = FreeControlLegacyConverter.convert(legacy, page: .dailyClearance, mode: .twoD, domain: .phoneLandscape,
            input: input, controls: controls, window: .init(width: 667, height: 375))
        XCTAssertTrue(mismatch.values.isEmpty); XCTAssertNotNil(mismatch.pending)
    }

    @MainActor private final class MemoryStorage: ControlLayoutStorage {
        var data: Data?
        var failWrite = false
        var failRead = false
        var failBackup = false
        var backups: [Data] = []
        func read() throws -> Data? {
            if failRead { throw CocoaError(.fileReadNoPermission) }
            return data
        }
        func writeAtomically(_ data: Data) throws {
            if failWrite { throw CocoaError(.fileWriteOutOfSpace) }
            self.data = data
        }
        func preserve(_ data: Data) throws {
            if failBackup { throw CocoaError(.fileWriteNoPermission) }
            backups.append(data)
        }
    }

    private func address(_ group: ControlLayoutGroup = .primary, _ property: ControlLayoutProperty = .offset,
                         _ layer: ControlLayoutLayer = .common,
                         _ domain: ControlLayoutDomain = .phoneLandscape) -> ControlLayoutAddress {
        ControlLayoutAddress(domain: domain, layer: layer, group: group, property: property)
    }

    private func resolve(_ archive: ControlLayoutArchive, _ page: TablePreferencePage = .dailyClearance,
                         _ mode: ControlLayoutLayer = .threeD,
                         _ domain: ControlLayoutDomain = .phoneLandscape,
                         _ capabilities: Set<ControlLayoutGroup> = Set(ControlLayoutGroup.allCases)) -> ControlLayoutResolved {
        ControlLayoutResolver.resolve(archive, page: page, domain: domain, mode: mode, capabilities: capabilities)
    }

    func test_draftReadsTheEditedLayerWithoutBorrowingModeOverride() {
        var archive = ControlLayoutArchive()
        archive.bindings[.shotSimulation] = .init(overrides: [address(): .offset(8), address(.primary, .offset, .threeD): .offset(16)])
        let draft = ControlLayoutDraft(archive: archive, page: .shotSimulation, domain: .phoneLandscape)
        XCTAssertEqual(draft.value(.primary, .offset, editing: .common), .offset(8))
        XCTAssertEqual(draft.value(.primary, .offset, editing: .threeD), .offset(16))
        XCTAssertEqual(draft.value(.primary, .offset, editing: .twoD), .offset(8))
    }

    @MainActor func test_coreEntryOverridesStayIndependentAcrossModesAndDomains() async throws {
        let pages: [TablePreferencePage] = [.dailyClearance, .freePlay, .shotSimulation, .snakePractice, .composer, .drillTryout]
        let store = ControlLayoutStore(storage: MemoryStorage()), id = UUID()
        let common = address(), threeD = address(.primary, .offset, .threeD)
        try store.saveAs(id: id, name: "六页共享", page: .dailyClearance, edits: [common: .offset(8)], incorporating: [common], expectedRevision: 0)
        try store.apply(.template(id), to: Set(pages), expectedRevision: 1)
        for (index, page) in pages.enumerated() {
            try store.savePage(page, edits: [threeD: .offset(Double(16 + index * 8))], expectedRevision: store.archive.revision)
        }
        for (index, page) in pages.enumerated() {
            XCTAssertEqual(resolve(store.archive, page, .twoD)[.primary, .offset], .offset(8))
            XCTAssertEqual(resolve(store.archive, page, .threeD)[.primary, .offset], .offset(Double(16 + index * 8)))
            XCTAssertNil(resolve(store.archive, page, .threeD, .padPortrait)[.primary, .offset])
        }
        try store.savePage(.drillTryout, edits: [:], restoring: [threeD], expectedRevision: store.archive.revision)
        XCTAssertEqual(resolve(store.archive, .drillTryout)[.primary, .offset], .offset(8))
        XCTAssertEqual(resolve(store.archive, .composer)[.primary, .offset], .offset(48))
    }

    @MainActor func test_managerPromotesSelectedKeysAndPreservesOtherPagesDomains() async throws {
        let disk = MemoryStorage(), id = UUID(), primary = address(), direction = address(.direction)
        let pad = address(.primary, .offset, .common, .padPortrait)
        let store = ControlLayoutStore(storage: disk)
        try store.saveAs(id: id, name: "共享", page: .dailyClearance, edits: [primary: .offset(8)], incorporating: [primary], expectedRevision: 0)
        try store.apply(.template(id), to: Set([.freePlay, .silu]), expectedRevision: 1)
        try store.savePage(.silu, edits: [primary: .offset(16)], expectedRevision: 2)
        var draft = ControlLayoutDraft(archive: store.archive, page: .dailyClearance, domain: .phoneLandscape)
        draft.change { $0.overrides = [primary: .offset(24), direction: .offset(8), pad: .offset(32)] }
        disk.failWrite = true
        let before = store.archive, bytes = disk.data
        XCTAssertThrowsError(try store.promote(draft, keys: [primary], clearPromoted: true))
        XCTAssertEqual(store.archive, before); XCTAssertEqual(disk.data, bytes)
        disk.failWrite = false
        try store.promote(draft, keys: [primary], clearPromoted: true)
        XCTAssertEqual(resolve(store.archive)[.primary, .offset], .offset(24))
        XCTAssertEqual(resolve(store.archive, .freePlay)[.primary, .offset], .offset(24))
        XCTAssertEqual(resolve(store.archive, .silu)[.primary, .offset], .offset(16))
        XCTAssertEqual(store.archive.bindings[.dailyClearance]?.overrides, [direction: .offset(8), pad: .offset(32)])
        try store.savePage(.silu, edits: [:], restoring: [primary], expectedRevision: 4)
        XCTAssertEqual(resolve(store.archive, .silu)[.primary, .offset], .offset(24))
    }

    @MainActor func test_familyDefaultAndAtomicDeletionKeepExplicitBindingsAndLocalOverrides() async throws {
        let disk = MemoryStorage(), store = ControlLayoutStore(storage: MemoryStorage())
        let a = UUID(), b = UUID(), key = address()
        try store.copy(nil, id: a, name: "A", expectedRevision: 0)
        try store.copy(a, id: b, name: "B", expectedRevision: 1)
        try store.apply(.template(b), to: .freePlay, expectedRevision: 2)
        try store.setFamilyDefault(.shot, template: a, expectedRevision: 3)
        XCTAssertEqual(store.archive.templateID(for: .dailyClearance), a)
        XCTAssertEqual(store.archive.templateID(for: .freePlay), b)
        try store.savePage(.dailyClearance, edits: [key: .offset(8)], expectedRevision: 4)
        disk.data = try JSONEncoder().encode(store.archive)
        let deleting = ControlLayoutStore(storage: disk), before = deleting.archive
        disk.failWrite = true
        XCTAssertThrowsError(try deleting.delete(a, replacingWith: b, expectedRevision: 5))
        XCTAssertEqual(deleting.archive, before)
        disk.failWrite = false
        try deleting.delete(a, replacingWith: b, expectedRevision: 5)
        XCTAssertNil(deleting.archive.templates[a])
        XCTAssertEqual(deleting.archive.templateID(for: .dailyClearance), b)
        XCTAssertEqual(deleting.archive.bindings[.dailyClearance]?.overrides[key], .offset(8))
        try deleting.delete(b, replacingWith: nil, expectedRevision: 6)
        XCTAssertNil(deleting.archive.templateID(for: .freePlay))
        XCTAssertEqual(deleting.archive.bindings[.dailyClearance]?.overrides[key], .offset(8))
        try deleting.archive.validate()
    }

    @MainActor func test_templateDraftNeverTouchesSamplePageAndCopyHasNoLiveLink() async throws {
        let store = ControlLayoutStore(storage: MemoryStorage()), a = UUID(), b = UUID(), key = address()
        try store.saveAs(id: a, name: "A", page: .dailyClearance, edits: [key: .offset(8)], incorporating: [key], expectedRevision: 0)
        try store.savePage(.dailyClearance, edits: [key: .offset(16)], expectedRevision: 1)
        let binding = store.archive.bindings[.dailyClearance]
        var draft = ControlLayoutDraft(archive: store.archive, page: .dailyClearance, domain: .phoneLandscape, templateID: a)
        XCTAssertEqual(resolve(draft.preview)[.primary, .offset], .offset(8), "Sample ignores real page overrides")
        draft.change { $0.overrides[key] = .offset(24) }
        XCTAssertThrowsError(try store.save(draft))
        try store.saveTemplate(draft)
        XCTAssertEqual(store.archive.bindings[.dailyClearance], binding)
        try store.copy(a, id: b, name: "B", expectedRevision: 3)
        try store.rename(b, name: "副本", expectedRevision: 4)
        var update = ControlLayoutDraft(archive: store.archive, page: .dailyClearance, domain: .phoneLandscape, templateID: a)
        update.change { $0.overrides.removeAll() }
        try store.saveTemplate(update)
        XCTAssertEqual(store.archive.templates[b]?.values[key], .offset(24))
        XCTAssertEqual(store.archive.templates[b]?.name, "副本")
        XCTAssertEqual(store.archive.templates[a]?.values, [:])
    }

    @MainActor func test_staleDraftCopyPreservesLatestBindingsAndTemplateSnapshot() async throws {
        let disk = MemoryStorage(), store = ControlLayoutStore(storage: MemoryStorage())
        let key = address(), a = UUID(), b = UUID()
        try store.saveAs(id: a, name: "来源", page: .dailyClearance, edits: [key: .offset(8)], incorporating: [key], expectedRevision: 0)
        var stale = ControlLayoutDraft(archive: store.archive, page: .dailyClearance, domain: .phoneLandscape)
        stale.change { $0.overrides[key] = .offset(16) }
        try store.apply(.builtIn, to: .dailyClearance, expectedRevision: 1)
        disk.data = try JSONEncoder().encode(store.archive)
        let saving = ControlLayoutStore(storage: disk)
        XCTAssertThrowsError(try saving.save(stale))
        try saving.preserveCopy(stale, id: b, name: "旧稿副本")
        XCTAssertEqual(saving.archive.bindings[.dailyClearance]?.selection, .builtIn)
        XCTAssertEqual(saving.archive.templates[b]?.values[key], .offset(16))
        XCTAssertEqual(saving.archive.templates[a]?.values[key], .offset(8))
        XCTAssertEqual(saving.archive.templates.count, 2)
    }

    @MainActor func test_applyBatchClearsOnlyReviewedExactPropertiesAndRejectsMissingTarget() async throws {
        let store = ControlLayoutStore(storage: MemoryStorage()), key = address(), pad = address(.primary, .offset, .threeD, .padPortrait)
        try store.savePage(.dailyClearance, edits: [key: .offset(8), pad: .offset(24)], expectedRevision: 0)
        try store.savePage(.freePlay, edits: [key: .offset(16)], expectedRevision: 1)
        let before = store.archive
        XCTAssertThrowsError(try store.apply(.template(UUID()), to: Set([.dailyClearance, .freePlay]), clearing: [.dailyClearance: [key]], expectedRevision: 2))
        XCTAssertEqual(store.archive, before)
        try store.apply(.builtIn, to: Set([.dailyClearance, .freePlay]), clearing: [.dailyClearance: [key]], expectedRevision: 2)
        XCTAssertEqual(store.archive.bindings[.dailyClearance]?.overrides, [pad: .offset(24)])
        XCTAssertEqual(store.archive.bindings[.freePlay]?.overrides[key], .offset(16))
    }

    @MainActor func test_recoveryInvalidatesAlreadyOpenDraftEvenFromEmptyArchive() async throws {
        let store = ControlLayoutStore(storage: MemoryStorage())
        var stale = ControlLayoutDraft(archive: store.archive, page: .dailyClearance, domain: .phoneLandscape)
        stale.change { $0.overrides[address()] = .offset(8) }
        try store.recoverWithDefault()
        XCTAssertEqual(store.archive.revision, 1)
        XCTAssertThrowsError(try store.save(stale)) { XCTAssertEqual($0 as? ControlLayoutError, .conflict) }
        XCTAssertTrue(store.archive.bindings.isEmpty)
    }

    @MainActor func test_emptyArchiveUsesDefaultWithoutWritingOrMigratingPreferences() async throws {
        let disk = MemoryStorage()
        let store = ControlLayoutStore(storage: disk)
        XCTAssertEqual(store.archive, ControlLayoutArchive())
        XCTAssertTrue(resolve(store.archive).values.isEmpty)
        XCTAssertNil(disk.data)
        XCTAssertNil(store.loadError)
    }
    @MainActor func test_threePageDraftSelectionKeepsLocalOverridesAndMapsOnlyCapabilities() async throws {
        let store = ControlLayoutStore(storage: MemoryStorage())
        let template = UUID(), primary = address(), direction = address(.direction)
        try store.saveAs(id: template, name: "通用", page: .dailyClearance,
            edits: [primary: .offset(8), direction: .offset(-8)], incorporating: [primary, direction], expectedRevision: 0)
        try store.savePage(.freePlay, edits: [primary: .offset(16)], expectedRevision: 1)
        var free = ControlLayoutDraft(archive: store.archive, page: .freePlay, domain: .phoneLandscape)
        free.change { $0.selection = .template(template) }
        XCTAssertEqual(resolve(free.preview, .freePlay)[.primary, .offset], .offset(16))
        XCTAssertNil(store.archive.templateID(for: .freePlay), "Selecting in a draft must not publish")
        try store.save(free)
        var planning = ControlLayoutDraft(archive: store.archive, page: .silu, domain: .phoneLandscape)
        planning.change { $0.selection = .template(template) }
        try store.save(planning)
        let mapped = resolve(store.archive, .silu, .twoD, .phoneLandscape, [.primary, .instrument, .planning])
        XCTAssertEqual(mapped[.primary, .offset], .offset(8))
        XCTAssertNil(mapped[.planning, .offset], "The target's dedicated planning group keeps its native default")
        XCTAssertEqual(mapped.inactive, [direction])
        XCTAssertEqual(resolve(store.archive, .dailyClearance)[.primary, .offset], .offset(8))
        XCTAssertEqual(resolve(store.archive, .freePlay)[.primary, .offset], .offset(16))
        XCTAssertTrue(resolve(store.archive, .silu, .threeD, .padPortrait).values.isEmpty)
    }

    @MainActor func test_layerPrecedenceAndIndependentEntryDomainAndCapabilities() async throws {
        let store = ControlLayoutStore(storage: MemoryStorage())
        let common = address(), threeD = address(.primary, .offset, .threeD)
        try store.saveAs(id: UUID(), name: "共享", page: .dailyClearance,
                         edits: [common: .offset(10), threeD: .offset(20)],
                         incorporating: [common, threeD], expectedRevision: 0)
        try store.savePage(.dailyClearance, edits: [common: .offset(30)], expectedRevision: 1)
        XCTAssertEqual(resolve(store.archive)[.primary, .offset], .offset(30))
        try store.savePage(.dailyClearance, edits: [threeD: .offset(40)], expectedRevision: 2)
        XCTAssertEqual(resolve(store.archive)[.primary, .offset], .offset(40))
        XCTAssertEqual(resolve(store.archive, .dailyClearance, .twoD)[.primary, .offset], .offset(30))
        XCTAssertTrue(resolve(store.archive, .dailyClearance, .threeD, .padLandscape).values.isEmpty)
        XCTAssertTrue(resolve(store.archive, .freePlay).values.isEmpty)
        let unsupported = resolve(store.archive, .dailyClearance, .threeD, .phoneLandscape, [.direction])
        XCTAssertTrue(unsupported.values.isEmpty)
        XCTAssertEqual(unsupported.inactive, [common, threeD])
    }

    @MainActor func test_capabilityRemovalAndReturnPreserveSavedIntentAcrossReload() async throws {
        let storage = MemoryStorage(), key = address(.keyboard, .lane)
        let store = ControlLayoutStore(storage: storage)
        try store.savePage(.sceneAiming2D, edits: [key: .lane(.leading)], expectedRevision: 0)
        let revision = store.archive.revision
        let inactive = resolve(store.archive, .sceneAiming2D, .twoD, .phoneLandscape, [.information, .primary])
        XCTAssertTrue(inactive.values.isEmpty)
        XCTAssertEqual(inactive.inactive, [key])
        let reloaded = ControlLayoutStore(storage: storage)
        let active = resolve(reloaded.archive, .sceneAiming2D, .twoD, .phoneLandscape, [.information, .keyboard, .primary])
        XCTAssertEqual(active[.keyboard, .lane], .lane(.leading))
        XCTAssertEqual(reloaded.archive.revision, revision)
        XCTAssertTrue(resolve(reloaded.archive, .sceneAiming2D, .twoD, .padPortrait, [.keyboard]).values.isEmpty)
        XCTAssertEqual(TablePreferencePage.allCases.filter(\.supportsControlLayoutEditing).count, 18)
        XCTAssertFalse(TablePreferencePage.drillRecordPreview.supportsControlLayoutEditing)
        XCTAssertFalse(TablePreferencePage.customFormationEditor.supportsControlLayoutEditing)
    }

    @MainActor func test_sameValueIsExplicitUntilRestoredAndFixedQuizEntriesStayIndependent() async throws {
        let store = ControlLayoutStore(storage: MemoryStorage())
        let key = address()
        let id = UUID()
        try store.saveAs(id: id, name: "答题", page: .sceneAiming2D, edits: [key: .offset(10)],
                         incorporating: [key], expectedRevision: 0)
        try store.apply(.template(id), to: .sceneAiming3D, expectedRevision: 1)
        try store.savePage(.sceneAiming2D, edits: [key: .offset(10)], expectedRevision: 2)
        try store.transact(expectedRevision: 3) { $0.templates[id]?.values[key] = .offset(20) }
        XCTAssertEqual(resolve(store.archive, .sceneAiming2D, .twoD)[.primary, .offset], .offset(10))
        XCTAssertEqual(resolve(store.archive, .sceneAiming3D)[.primary, .offset], .offset(20))
        try store.savePage(.sceneAiming2D, edits: [:], restoring: [key], expectedRevision: 4)
        XCTAssertEqual(resolve(store.archive, .sceneAiming2D, .twoD)[.primary, .offset], .offset(20))
    }

    @MainActor func test_saveAsCopiesAllSourceDomainsAndClearsOnlyIncorporatedExactKeys() async throws {
        let store = ControlLayoutStore(storage: MemoryStorage())
        let common = address(), mode = address(.primary, .offset, .threeD)
        let pad = address(.primary, .offset, .common, .padPortrait)
        let inactive = address(.planning)
        let original = UUID(), copy = UUID()
        try store.saveAs(id: original, name: "A", page: .dailyClearance,
                         edits: [common: .offset(10), pad: .offset(70)],
                         incorporating: [common, pad], expectedRevision: 0)
        try store.apply(.template(original), to: .freePlay, expectedRevision: 1)
        try store.savePage(.freePlay, edits: [common: .offset(99)], expectedRevision: 2)
        try store.savePage(.dailyClearance, edits: [common: .offset(20), mode: .offset(30), inactive: .offset(40)], expectedRevision: 3)
        try store.saveAs(id: copy, name: "B", page: .dailyClearance, incorporating: [mode], expectedRevision: 4)
        XCTAssertEqual(store.archive.bindings[.dailyClearance]?.overrides, [common: .offset(20), inactive: .offset(40)])
        XCTAssertEqual(store.archive.templates[copy]?.values[pad], .offset(70))
        XCTAssertEqual(store.archive.templates[copy]?.values[mode], .offset(30))
        try store.transact(expectedRevision: 5) { archive in
            archive.templates[copy]?.values[mode] = .offset(50)
            archive.templates[original]?.values[pad] = .offset(80)
        }
        XCTAssertEqual(resolve(store.archive)[.primary, .offset], .offset(20)) // local common follows template mode in precedence
        try store.savePage(.dailyClearance, edits: [:], restoring: [common], expectedRevision: 6)
        XCTAssertEqual(resolve(store.archive)[.primary, .offset], .offset(50))
        XCTAssertEqual(resolve(store.archive, .freePlay)[.primary, .offset], .offset(99))
        XCTAssertEqual(store.archive.templates[copy]?.values[pad], .offset(70))
    }

    @MainActor func test_writeFailurePublishesNothingAndRetryCreatesOneTemplate() async throws {
        let disk = MemoryStorage(), key = address(), id = UUID()
        let store = ControlLayoutStore(storage: disk)
        try store.savePage(.dailyClearance, edits: [key: .offset(15)], expectedRevision: 0)
        let before = store.archive, bytes = disk.data
        var publications = 0
        let subscription = store.$archive.dropFirst().sink { _ in publications += 1 }
        disk.failWrite = true
        XCTAssertThrowsError(try store.saveAs(id: id, name: "B", page: .dailyClearance, incorporating: [key], expectedRevision: 1))
        XCTAssertEqual(store.archive, before)
        XCTAssertEqual(disk.data, bytes)
        XCTAssertEqual(publications, 0)
        disk.failWrite = false
        try store.saveAs(id: id, name: "B", page: .dailyClearance, incorporating: [key], expectedRevision: 1)
        XCTAssertEqual(publications, 1)
        XCTAssertEqual(store.archive.templates.count, 1)
        XCTAssertEqual(store.archive.bindings[.dailyClearance]?.overrides, [:])
        XCTAssertThrowsError(try store.saveAs(id: id, name: "B", page: .dailyClearance, incorporating: [key], expectedRevision: 2))
        XCTAssertEqual(store.archive.templates.count, 1)
        withExtendedLifetime(subscription) {}
    }

    @MainActor func test_revisionAndSecondStoreConflictsPreserveBothDraftAndDisk() async throws {
        let disk = MemoryStorage(), key = address()
        let a = ControlLayoutStore(storage: disk), b = ControlLayoutStore(storage: disk)
        try a.savePage(.dailyClearance, edits: [key: .offset(1)], expectedRevision: 0)
        let bytes = disk.data
        XCTAssertThrowsError(try a.savePage(.dailyClearance, edits: [key: .offset(2)], expectedRevision: 0))
        XCTAssertThrowsError(try b.savePage(.freePlay, edits: [key: .offset(3)], expectedRevision: 0))
        XCTAssertEqual(disk.data, bytes)
        b.reload()
        try b.savePage(.freePlay, edits: [key: .offset(3)], expectedRevision: 1)
        XCTAssertEqual(resolve(b.archive)[.primary, .offset], .offset(1))
    }

    @MainActor func test_invalidIntentAndDanglingReferencesCannotWrite() async throws {
        let disk = MemoryStorage(), store = ControlLayoutStore(storage: MemoryStorage())
        let other = ControlLayoutStore(storage: disk)
        for value in [Double.nan, .infinity, -.infinity, 2049] {
            XCTAssertThrowsError(try store.savePage(.dailyClearance, edits: [address(): .offset(value)], expectedRevision: 0))
        }
        XCTAssertThrowsError(try other.savePage(.dailyClearance, edits: [address(): .lane(.leading)], expectedRevision: 0))
        XCTAssertThrowsError(try other.apply(.template(UUID()), to: .dailyClearance, expectedRevision: 0))
        XCTAssertThrowsError(try other.savePage(.customFormationPractice, edits: [:], expectedRevision: 0))
        XCTAssertThrowsError(try other.saveAs(id: UUID(), name: " \n ", page: .dailyClearance, incorporating: [], expectedRevision: 0))
        XCTAssertNil(disk.data)
    }

    @MainActor func test_corruptAndFutureArchivesRequireExplicitSuccessfulBackup() async throws {
        for bytes in [Data("broken".utf8), Data("{\"schemaVersion\":999}".utf8)] {
            let disk = MemoryStorage()
            disk.data = bytes
            let store = ControlLayoutStore(storage: disk)
            XCTAssertNotNil(store.loadError)
            XCTAssertThrowsError(try store.savePage(.dailyClearance, edits: [:], expectedRevision: 0))
            disk.failBackup = true
            XCTAssertThrowsError(try store.recoverWithDefault())
            XCTAssertEqual(disk.data, bytes)
            disk.failBackup = false
            disk.failWrite = true
            XCTAssertThrowsError(try store.recoverWithDefault())
            XCTAssertEqual(disk.data, bytes)
            disk.failWrite = false
            try store.recoverWithDefault()
            XCTAssertNil(store.loadError)
            XCTAssertTrue(disk.backups.contains(bytes))
            var recovered = ControlLayoutArchive(); recovered.revision = 1
            XCTAssertEqual(try ControlLayoutStore.decode(XCTUnwrap(disk.data)), recovered)
        }
    }

    @MainActor func test_realFileRoundTripAndBackupPreserveOriginalBytes() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { do { try FileManager.default.removeItem(at: folder) } catch { XCTFail("Cleanup: \(error)") } }
        let disk = ControlLayoutFileStorage(url: folder.appendingPathComponent("layout.json"))
        let store = ControlLayoutStore(storage: disk), key = address()
        try store.savePage(.aimPointScene2D, edits: [key: .offset(17)], expectedRevision: 0)
        let original = try XCTUnwrap(disk.read())
        let reopened = ControlLayoutStore(storage: disk)
        XCTAssertEqual(reopened.archive, store.archive)
        try reopened.recoverWithDefault()
        let backups = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("recovery-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), original)
    }

    @MainActor func test_restoreAndBindingChangesAffectOnlyRequestedPageAndKeys() async throws {
        let store = ControlLayoutStore(storage: MemoryStorage()), key = address(), mode = address(.primary, .offset, .threeD)
        let id = UUID()
        try store.saveAs(id: id, name: "A", page: .dailyClearance, incorporating: [], expectedRevision: 0)
        try store.savePage(.freePlay, edits: [key: .offset(1), mode: .offset(2)], expectedRevision: 1)
        try store.apply(.template(id), to: .freePlay, clearing: [key], expectedRevision: 2)
        XCTAssertEqual(store.archive.bindings[.freePlay]?.overrides, [mode: .offset(2)])
        try store.restorePage(.dailyClearance, usingBuiltIn: true, expectedRevision: 3)
        XCTAssertEqual(store.archive.bindings[.dailyClearance]?.selection, .builtIn)
        XCTAssertEqual(store.archive.bindings[.freePlay]?.selection, .template(id))
        XCTAssertEqual(store.archive.bindings[.freePlay]?.overrides, [mode: .offset(2)])
    }
    @MainActor func test_draftUndoCancelFailureAndAtomicSaveAs() async throws {
        let disk = MemoryStorage(), key = address(), pad = address(.primary, .offset, .common, .padPortrait)
        let store = ControlLayoutStore(storage: disk)
        try store.savePage(.dailyClearance, edits: [pad: .offset(80)], expectedRevision: 0)
        var draft = ControlLayoutDraft(archive: store.archive, page: .dailyClearance, domain: .phoneLandscape)
        draft.change { $0.overrides[key] = .offset(20) }
        XCTAssertNil(store.archive.bindings[.dailyClearance]?.overrides[key])
        draft.undo(); XCTAssertFalse(draft.isDirty)
        draft.redo(); XCTAssertEqual(draft.binding.overrides[key], .offset(20))
        let previous = store.archive, bytes = disk.data, id = UUID()
        disk.failWrite = true
        XCTAssertThrowsError(try store.save(draft, newTemplate: (id, "自定义")))
        XCTAssertEqual(store.archive, previous); XCTAssertEqual(disk.data, bytes)
        XCTAssertTrue(draft.isDirty)
        disk.failWrite = false
        try store.save(draft, newTemplate: (id, "自定义"))
        XCTAssertEqual(store.archive.templates[id]?.values[key], .offset(20))
        XCTAssertEqual(store.archive.bindings[.dailyClearance]?.overrides, [pad: .offset(80)])
        try store.transact(expectedRevision: store.archive.revision) { $0.templates[id]?.values[key] = .offset(30) }
        XCTAssertEqual(resolve(store.archive)[.primary, .offset], .offset(30))
        XCTAssertThrowsError(try store.save(draft)) { XCTAssertEqual($0 as? ControlLayoutError, .conflict) }
    }

    func test_editPausesAccumulateOneVisitAndBackgroundFinishesOnlyActiveTime() {
        let zero = Date(timeIntervalSince1970: 1000)
        var clock = ActiveVisitClock()
        clock.resume(at: zero)
        clock.resume(at: zero.addingTimeInterval(4))
        clock.pause(at: zero.addingTimeInterval(10))
        clock.pause(at: zero.addingTimeInterval(60))
        // Failed save/nested management do not resume or finish this visit.
        clock.resume(at: zero.addingTimeInterval(110))
        XCTAssertEqual(clock.finish(at: zero.addingTimeInterval(130)), .init(start: zero, seconds: 30))
        XCTAssertNil(clock.finish(at: zero.addingTimeInterval(140)))
        clock.resume(at: zero.addingTimeInterval(200))
        clock.pause(at: zero.addingTimeInterval(210))
        XCTAssertEqual(clock.finish(at: zero.addingTimeInterval(270))?.seconds, 10)
        // Returning to the editor in foreground does not start a segment.
        XCTAssertNil(clock.finish(at: zero.addingTimeInterval(300)))
        clock.resume(at: zero.addingTimeInterval(320))
        XCTAssertEqual(clock.finish(at: zero.addingTimeInterval(340))?.seconds, 20)
    }

}
