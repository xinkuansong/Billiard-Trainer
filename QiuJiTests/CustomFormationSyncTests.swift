import XCTest
@testable import QiuJi

@MainActor
final class CustomFormationSyncTests: XCTestCase {
    var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    func store(_ owner: String = "account:a") -> CustomFormationRepository { .init(ownerKey: owner, directory: directory) }
    func template(_ name: String = "重复球") -> CustomFormationTemplate {
        let keys = [PositionPlayBall.instanceKey(number: 1), PositionPlayBall.instanceKey(number: 1)]
        let a = FormationVertex(x: -0.5, z: 0), b = FormationVertex(x: 0.5, z: 0)
        return .init(name: name, ballKeys: keys, board: .init(onTable: ["cueBall": .init(x: 0.2, y: 0.4), keys[0]: .init(x: 0.3, y: 0.25), keys[1]: .init(x: 0.7, y: 0.25)]),
                     drawing: .init(vertices: [a,b], lines: [.init(start: a.id, end: b.id, balls: keys)]))
    }
    func record(_ t: CustomFormationTemplate, revision: Int = 1, deleted: Bool = false) -> FormationRemoteRecord {
        .init(clientId: t.id, revision: revision, deleted: deleted, schemaVersion: 1, template: deleted ? nil : t, modifiedAt: Date())
    }
    func testV1MigrationBacksUpAndPreservesIdentityAndDrawing() throws {
        let t = template(), repository = store()
        struct Legacy: Encodable { let version = 1; let templates: [CustomFormationTemplate]; let selectedID: UUID }
        let bytes = try JSONEncoder().encode(Legacy(templates: [t], selectedID: t.id))
        try bytes.write(to: repository.url)
        let a = try repository.load()
        XCTAssertEqual(a.version, 2); XCTAssertEqual(a.pendingCount, 1)
        XCTAssertTrue(try XCTUnwrap(a.templates.first).sameContent(as: t))
        XCTAssertEqual(try Data(contentsOf: repository.url.appendingPathExtension("v1-backup")), bytes)
        XCTAssertEqual(try repository.load().meta(t.id).generation, 1)
    }
    func testTwoLibraryInstancesDoNotOverwriteEachOther() throws {
        let a = CustomFormationLibrary(ownerKey: "account:a", directory: directory)
        let b = CustomFormationLibrary(ownerKey: "account:a", directory: directory)
        XCTAssertTrue(a.save(template("A"))); XCTAssertTrue(b.save(template("B")))
        XCTAssertEqual(try store().load().templates.count, 2)
    }
    func testNewEditDuringUploadKeepsPendingGenerationAndImmutableRetry() throws {
        let t = template(), r = store(); try r.put(t)
        let op = try XCTUnwrap(r.nextOperation(t.id))
        var newer = t; newer.name = "新修改"; try r.put(newer, basedOn: t)
        let retry = try XCTUnwrap(store().nextOperation(t.id))
        XCTAssertEqual(retry.operationId, op.operationId); XCTAssertEqual(retry.template?.name, t.name)
        try r.acknowledge(op, record: record(t), conflict: false)
        let state = try r.load(); XCTAssertEqual(state.templates.first?.name, newer.name); XCTAssertTrue(state.meta(t.id).dirty)
        let next = try XCTUnwrap(r.nextOperation(t.id)); XCTAssertEqual(next.baseRevision, 1); XCTAssertEqual(next.template?.name, newer.name)
    }
    func testDeleteDuringUnknownCreateReceiptSurvivesRestart() throws {
        let t = template(), r = store(); try r.put(t)
        let op = try XCTUnwrap(r.nextOperation(t.id)); try r.remove(t.id)
        XCTAssertEqual(try store().nextOperation(t.id)?.operationId, op.operationId)
        try r.acknowledge(op, record: record(t), conflict: false)
        XCTAssertTrue(try r.load().templates.isEmpty)
        let deletion = try XCTUnwrap(r.nextOperation(t.id)); XCTAssertTrue(deletion.deleted); XCTAssertEqual(deletion.baseRevision, 1)
        try r.acknowledge(deletion, record: record(t, revision: 2, deleted: true), conflict: false)
        try r.apply([record(t), record(t, revision: 2, deleted: true)], cursor: 2)
        XCTAssertTrue(try r.load().templates.isEmpty); XCTAssertEqual(try r.load().pendingCount, 0)
    }
    func testConflictPreservesOneCopyAndRetryDoesNotDuplicate() throws {
        let t = template(), r = store(); try r.apply([record(t)], cursor: 1)
        var local = t; local.name = "本机"; try r.put(local, basedOn: t)
        let op = try XCTUnwrap(r.nextOperation(t.id))
        var remote = t; remote.name = "另一台"; let response = record(remote, revision: 2)
        try r.acknowledge(op, record: response, conflict: true)
        try r.acknowledge(op, record: response, conflict: true)
        let a = try r.load(); XCTAssertEqual(a.templates.count, 2)
        XCTAssertEqual(a.templates.first { $0.id == t.id }?.name, "另一台")
        let copy = try XCTUnwrap(a.templates.first { $0.id != t.id })
        XCTAssertEqual(copy.name, "本机 冲突副本"); XCTAssertEqual(copy.ballKeys, t.ballKeys); XCTAssertEqual(copy.drawing, t.drawing)
        XCTAssertEqual(a.pendingCount, 1)
    }
    func testRemoteDeleteWithEditsCreatesCopyAndOldIDStaysDeleted() throws {
        let t = template(), r = store(); try r.apply([record(t)], cursor: 1)
        var local = t; local.name = "离线编辑"; try r.put(local, basedOn: t)
        let op = try XCTUnwrap(r.nextOperation(t.id))
        try r.acknowledge(op, record: record(t, revision: 2, deleted: true), conflict: true)
        let a = try r.load(); XCTAssertTrue(a.meta(t.id).deleted)
        XCTAssertEqual(a.templates.count, 1); XCTAssertNotEqual(a.templates.first?.id, t.id)
    }
    func testStaleDeleteRestoresRemoteUpdateForExplicitDecision() throws {
        let t = template(), r = store(); try r.apply([record(t)], cursor: 1); try r.remove(t.id)
        let op = try XCTUnwrap(r.nextOperation(t.id))
        var remote = t; remote.name = "另一台的新名字"
        try r.acknowledge(op, record: record(remote, revision: 2), conflict: true)
        let a = try r.load(); XCTAssertEqual(a.templates.first?.name, remote.name); XCTAssertEqual(a.pendingCount, 0); XCTAssertNotNil(a.notice)
    }
    func testOpenEditorDoesNotOverwriteBackgroundUpdate() throws {
        let t = template(), r = store(); try r.apply([record(t)], cursor: 1)
        var remote = t; remote.name = "远端"; try r.apply([record(remote, revision: 2)], cursor: 2)
        var edited = t; edited.name = "编辑中"
        try r.put(edited, basedOn: t)
        XCTAssertEqual(try r.load().templates.count, 2)
    }
    func testInvalidPageDoesNotAdvanceCursorOrPartiallyApply() throws {
        let r = store(), t = template()
        var invalid = template(); invalid.name = ""
        XCTAssertThrowsError(try r.apply([record(t), record(invalid)], cursor: 2))
        XCTAssertEqual(try r.load().cursor, 0); XCTAssertTrue(try r.load().templates.isEmpty)
    }
    func testGuestTransferIsIdempotentAndKeepsConflictingAccountContent() throws {
        let t = template(), source = store("guest:g"), dest = store()
        try source.put(t); var other = t; other.name = "账号原有"; try dest.put(other)
        try CustomFormationRepository.transfer(from: source, to: dest)
        XCTAssertTrue(try source.load().templates.isEmpty); XCTAssertEqual(try dest.load().templates.count, 2)
        // Simulate interruption after destination commit but before source cleanup.
        try source.put(t); try CustomFormationRepository.transfer(from: source, to: dest)
        XCTAssertEqual(try dest.load().templates.count, 2)
    }
    func testInterruptedGuestTransferKeepsLaterGuestEdit() throws {
        let t = template(), source = store("guest:g"), dest = store()
        try source.put(t); try CustomFormationRepository.transfer(from: source, to: dest)
        var newer = t; newer.name = "中断后的修改"; try source.put(newer)
        try CustomFormationRepository.transfer(from: source, to: dest)
        XCTAssertEqual(try dest.load().templates.count, 2)
        XCTAssertTrue(try dest.load().templates.contains { $0.name.hasPrefix(newer.name) })
    }
    func testMissingSyncMetadataCannotSilentlyLoseAnUpload() throws {
        let t = template(), r = store(); try r.put(t)
        XCTAssertThrowsError(try r.transaction { $0.metadata = [:] })
        XCTAssertEqual(try r.load().pendingCount, 1)
    }
    func testWriteFailurePreservesOriginalArchive() throws {
        let t = template(), r = store(); try r.put(t)
        let before = try Data(contentsOf: r.url)
        XCTAssertThrowsError(try r.transaction { a in a.templates[0].name = "" })
        XCTAssertEqual(try Data(contentsOf: r.url), before)
    }
    func testConsentOrOwnerChangeDuringResponseDoesNotAcknowledge() async throws {
        let t = template(), r = store(); try r.put(t)
        let backend = FormationBackendStub(record: record(t)); var allowed = true
        backend.onMutation = { allowed = false }
        _ = await CustomFormationSyncService(backend: backend).sync(userID: "a", repository: r, shouldContinue: { allowed })
        XCTAssertEqual(backend.pullCount, 0); XCTAssertTrue(try r.load().meta(t.id).dirty); XCTAssertNotNil(try r.load().meta(t.id).pending)
    }
    func testNetworkFailureRetainsOperationAndRetryAcknowledgesIt() async throws {
        let t = template(), r = store(); try r.put(t)
        let backend = FormationBackendStub(record: record(t)); backend.failMutation = true
        let service = CustomFormationSyncService(backend: backend)
        let failed = await service.sync(userID: "a", repository: r, shouldContinue: { true })
        XCTAssertTrue(failed.failed)
        let operation = try XCTUnwrap(r.load().meta(t.id).pending)
        XCTAssertNotNil(try r.load().syncError)
        backend.failMutation = false
        let retried = await service.sync(userID: "a", repository: r, shouldContinue: { true })
        XCTAssertFalse(retried.failed); XCTAssertEqual(backend.lastOperationID, operation.operationId)
        XCTAssertEqual(try r.load().pendingCount, 0); XCTAssertNil(try r.load().syncError)
    }
    func testLegacyOversizeDoesNotBlockOtherTemplatesUpload() async throws {
        let t = template(), r = store(); var legacy = template("旧超限模板")
        while legacy.ballKeys.count < 26 {
            let key = PositionPlayBall.instanceKey(number: 1)
            legacy.ballKeys.append(key); legacy.board.onTable[key] = .init(x: 0.5, y: 0.25)
        }
        try r.save(.init(templates: [legacy, t]))
        let backend = FormationBackendStub(record: record(t))
        let result = await CustomFormationSyncService(backend: backend).sync(userID: "a", repository: r, shouldContinue: { true })
        XCTAssertTrue(result.failed); XCTAssertEqual(backend.mutationCount, 1)
        XCTAssertEqual(try r.load().templates.first { $0.id == legacy.id }?.ballKeys.count, 26)
        XCTAssertFalse(try r.load().meta(t.id).dirty); XCTAssertTrue(try r.load().meta(legacy.id).dirty)
    }
    func testDisabledSyncMakesNoNetworkCalls() async throws {
        let t = template(), r = store(); try r.put(t)
        let backend = FormationBackendStub(record: record(t))
        _ = await CustomFormationSyncService(backend: backend).sync(userID: "a", repository: r, shouldContinue: { false })
        XCTAssertEqual(backend.mutationCount, 0); XCTAssertEqual(backend.pullCount, 0)
    }
}
@MainActor
private final class FormationBackendStub: CustomFormationSyncBackend {
    let record: FormationRemoteRecord
    var onMutation: (() -> Void)?
    var failMutation = false
    var lastOperationID: UUID?
    var mutationCount = 0
    var pullCount = 0
    init(record: FormationRemoteRecord) { self.record = record }
    func mutate(_ operation: FormationMutation, userID: String) async throws -> FormationMutationResponse {
        mutationCount += 1; lastOperationID = operation.operationId; onMutation?()
        if failMutation { throw URLError(.notConnectedToInternet) }
        return .init(conflict: false, record: record)
    }
    func changes(after: Int, through: Int?, userID: String) async throws -> FormationChangePage {
        pullCount += 1; return .init(records: [], next: after, through: after, hasMore: false)
    }
}
