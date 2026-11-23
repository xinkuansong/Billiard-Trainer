import XCTest
@testable import QiuJi

/// Local and production probes have separate selectors and explicit environment guards.
@MainActor
final class CustomFormationSyncIntegrationTests: XCTestCase {
    /// Only run after explicit authorization, against a newly created disposable production account.
    func testAuthorizedProductionTwoDevicePhase() async throws {
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        guard let path = setting("FORMATION_PRODUCTION_FIXTURE") else {
            throw XCTSkip("Production probe requires explicit authorization and a disposable account fixture")
        }
        guard setting("FORMATION_PRODUCTION_AUTHORIZATION") == "authorized" else {
            XCTFail("Production access was not explicitly enabled"); return
        }
        struct Fixture: Decodable {
            let baseURL: String
            let userID: String
            let token: String
            let templateID: UUID
            let ballIDs: [UUID]
            let vertexIDs: [UUID]
            let lineIDs: [UUID]
            let probeName: String
        }
        let f = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        guard f.baseURL == "http://106.54.3.210:3000", f.probeName.hasPrefix("formation-two-sim-probe-"),
              f.ballIDs.count == 15, f.vertexIDs.count == 3, f.lineIDs.count == 2 else {
            XCTFail("Production fixture does not match the allowlisted probe contract"); return
        }
        let phase = try XCTUnwrap(setting("FORMATION_PRODUCTION_PHASE"))
        let client = APIClient(baseURL: try XCTUnwrap(URL(string: f.baseURL)), tokenStore: IntegrationToken(token: f.token))
        struct Profile: Decodable { let id: String; let displayName: String? }
        let profile: Profile = try await client.request(Endpoint(.get, "/user/profile", expectedAccountID: f.userID))
        guard profile.id == f.userID, profile.displayName == f.probeName else {
            XCTFail("Refusing to write to an account not owned by this probe"); return
        }
        let service = CustomFormationSyncService(backend: FormationRESTBackend(client: client))
        let repo = CustomFormationRepository(ownerKey: "production-verification:\(f.userID)")
        let keys = f.ballIDs.enumerated().map { "_\($0.offset + 1)@" + $0.element.uuidString }
        func sync(_ repository: CustomFormationRepository, full: Bool = false) async throws {
            let result = await service.sync(userID: f.userID, repository: repository, full: full, shouldContinue: { true })
            XCTAssertFalse(result.failed, "Production phase \(phase) failed")
            XCTAssertEqual(try repository.load().pendingCount, 0)
        }
        func assertContent(_ t: CustomFormationTemplate, version: Int) throws {
            XCTAssertEqual(t.id, f.templateID)
            XCTAssertEqual(t.name, version == 1 ? "换机恢复·15颗不同号球" : version == 2 ? "设备B修改" : "设备A再次修改")
            XCTAssertEqual(t.ballKeys, keys)
            XCTAssertEqual(Set(t.ballKeys).count, 15)
            XCTAssertEqual(t.board.onTable.count, 16)
            let cue = try XCTUnwrap(t.board.onTable["cueBall"])
            XCTAssertEqual(cue.x, 0.2, accuracy: 0.00001); XCTAssertEqual(cue.y, 0.4, accuracy: 0.00001)
            for (index, key) in keys.enumerated() {
                let p = try XCTUnwrap(t.board.onTable[key])
                let expectedX = index == 0 && version > 1 ? (version == 2 ? 0.35 : 0.4) : 0.3 + Double(index) * 0.01
                let expectedY = index == 0 && version > 1 ? (version == 2 ? 0.2 : 0.3) : 0.25
                XCTAssertEqual(p.x, expectedX, accuracy: 0.00001); XCTAssertEqual(p.y, expectedY, accuracy: 0.00001)
            }
            let drawing = try XCTUnwrap(t.drawing)
            XCTAssertEqual(drawing.vertices.map(\.id), f.vertexIDs)
            XCTAssertEqual(drawing.lines.map(\.id), f.lineIDs)
            XCTAssertEqual(drawing.lines[0].end, drawing.lines[1].start)
            XCTAssertEqual(drawing.lines[0].balls, version == 1 ? Array(keys.prefix(8)) : Array(keys.prefix(8).reversed()))
            XCTAssertEqual(drawing.lines[1].balls, Array(keys.suffix(7)))
            XCTAssertEqual(Double(drawing.vertices[0].x), version == 1 ? -0.5 : version == 2 ? -0.4 : -0.35, accuracy: 0.00001)
            XCTAssertEqual(Double(drawing.vertices[0].z), version == 1 ? 0 : version == 2 ? -0.2 : -0.15, accuracy: 0.00001)
        }
        switch phase {
        case "A-create":
            XCTAssertFalse(FileManager.default.fileExists(atPath: repo.url.path))
            var positions = ["cueBall": CanvasPoint(x: 0.2, y: 0.4)]
            for (i, key) in keys.enumerated() { positions[key] = .init(x: 0.3 + Double(i) * 0.01, y: 0.25) }
            let vertices = [FormationVertex(id: f.vertexIDs[0], x: -0.5, z: 0),
                            FormationVertex(id: f.vertexIDs[1], x: 0, z: 0),
                            FormationVertex(id: f.vertexIDs[2], x: 0.5, z: 0.2)]
            let t = CustomFormationTemplate(id: f.templateID, name: "换机恢复·15颗不同号球", ballKeys: keys,
                board: .init(onTable: positions), drawing: .init(vertices: vertices, lines: [
                    .init(id: f.lineIDs[0], start: vertices[0].id, end: vertices[1].id, balls: Array(keys.prefix(8))),
                    .init(id: f.lineIDs[1], start: vertices[1].id, end: vertices[2].id, balls: Array(keys.suffix(7)))
                ]))
            try repo.put(t); XCTAssertEqual(try repo.load().pendingCount, 1)
            try await sync(repo); XCTAssertEqual(try repo.load().meta(f.templateID).revision, 1)
            try assertContent(try XCTUnwrap(repo.load().templates.first), version: 1)
        case "B-restore":
            XCTAssertFalse(FileManager.default.fileExists(atPath: repo.url.path))
            XCTAssertTrue(try repo.load().templates.isEmpty); XCTAssertEqual(try repo.load().cursor, 0)
            try await sync(repo)
            XCTAssertEqual(try repo.load().templates.count, 1)
            try assertContent(try XCTUnwrap(repo.load().templates.first), version: 1)
            XCTAssertEqual(try repo.load().meta(f.templateID).revision, 1)
        case "B-edit":
            let original = try XCTUnwrap(repo.load().templates.first)
            try assertContent(original, version: 1)
            var t = original; t.name = "设备B修改"; t.board.onTable[keys[0]] = .init(x: 0.35, y: 0.2)
            t.drawing?.vertices[0].x = -0.4; t.drawing?.vertices[0].z = -0.2
            t.drawing?.lines[0].balls.reverse()
            try repo.put(t, basedOn: original); try await sync(repo)
            XCTAssertEqual(try repo.load().meta(f.templateID).revision, 2)
        case "A-observe-edit-and-edit":
            try assertContent(try XCTUnwrap(repo.load().templates.first), version: 1)
            try await sync(repo)
            let original = try XCTUnwrap(repo.load().templates.first)
            try assertContent(original, version: 2)
            var t = original; t.name = "设备A再次修改"; t.board.onTable[keys[0]] = .init(x: 0.4, y: 0.3)
            t.drawing?.vertices[0].x = -0.35; t.drawing?.vertices[0].z = -0.15
            try repo.put(t, basedOn: original)
            let reopened = CustomFormationRepository(ownerKey: repo.ownerKey)
            XCTAssertEqual(try reopened.load().pendingCount, 1)
            try await sync(reopened); XCTAssertEqual(try repo.load().meta(f.templateID).revision, 3)
        case "B-observe-edit-and-delete":
            try assertContent(try XCTUnwrap(repo.load().templates.first), version: 2)
            try await sync(repo)
            try assertContent(try XCTUnwrap(repo.load().templates.first), version: 3)
            try repo.remove(f.templateID); try await sync(repo)
            XCTAssertTrue(try repo.load().templates.isEmpty)
            XCTAssertEqual(try repo.load().meta(f.templateID).revision, 4)
            XCTAssertTrue(try repo.load().meta(f.templateID).deleted)
        case "A-observe-delete":
            try assertContent(try XCTUnwrap(repo.load().templates.first), version: 3)
            try await sync(repo)
            XCTAssertTrue(try repo.load().templates.isEmpty)
            XCTAssertTrue(try repo.load().meta(f.templateID).deleted)
            XCTAssertEqual(try repo.load().meta(f.templateID).revision, 4)
            let reopened = CustomFormationRepository(ownerKey: repo.ownerKey)
            try await sync(reopened, full: true)
            XCTAssertTrue(try reopened.load().templates.isEmpty)
        case "B-fresh-after-delete":
            XCTAssertTrue(try repo.load().templates.isEmpty)
            let fresh = CustomFormationRepository(ownerKey: repo.ownerKey + ":fresh-after-delete")
            XCTAssertFalse(FileManager.default.fileExists(atPath: fresh.url.path))
            try await sync(fresh)
            XCTAssertTrue(try fresh.load().templates.isEmpty)
            XCTAssertEqual(try fresh.load().meta(f.templateID).revision, 4)
            XCTAssertTrue(try fresh.load().meta(f.templateID).deleted)
            try FileManager.default.removeItem(at: fresh.url)
        case "cleanup":
            if FileManager.default.fileExists(atPath: repo.url.path) { try FileManager.default.removeItem(at: repo.url) }
        default: XCTFail("Unknown production phase")
        }
        let archive = try repo.load()
        let report: [String: Any] = ["phase": phase, "baseURL": f.baseURL,
            "simulatorUDID": env["SIMULATOR_UDID"] ?? "unknown", "accountID": f.userID,
            "templateCount": archive.templates.count, "pendingCount": archive.pendingCount,
            "revision": archive.meta(f.templateID).revision, "deleted": archive.meta(f.templateID).deleted]
        if let output = setting("FORMATION_PRODUCTION_REPORT") {
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: output), options: .atomic)
        }
        print("PRODUCTION_FORMATION_PHASE \(phase) templates=\(archive.templates.count) pending=\(archive.pendingCount)")
    }

    func testTwoDeviceSyncPhase() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["FORMATION_FIXTURE"] ?? env["TEST_RUNNER_FORMATION_FIXTURE"] else {
            throw XCTSkip("Explicit integration run requires the isolated local server fixture")
        }
        let phase = try XCTUnwrap(env["FORMATION_PHASE"] ?? env["TEST_RUNNER_FORMATION_PHASE"])
        struct Fixture: Decodable { let baseURL: String; let userID: String; let token: String; let templateID: UUID }
        let f = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        XCTAssertTrue(f.baseURL.hasPrefix("http://127.0.0.1:"))
        let service = CustomFormationSyncService(backend: FormationRESTBackend(client: APIClient(baseURL: try XCTUnwrap(URL(string: f.baseURL)), tokenStore: IntegrationToken(token: f.token))))
        let repo = CustomFormationRepository(ownerKey: "integration:\(f.userID)")
        func sync() async throws { let result = await service.sync(userID: f.userID, repository: repo, shouldContinue: { true }); XCTAssertFalse(result.failed, "Phase \(phase) failed"); }
        switch phase {
        case "A-create":
            let keys = [PositionPlayBall.instanceKey(number: 1), PositionPlayBall.instanceKey(number: 2)]
            let a = FormationVertex(x: -0.5, z: 0), b = FormationVertex(x: 0.5, z: 0)
            let t = CustomFormationTemplate(id: f.templateID, name: "设备A球形", ballKeys: keys,
                board: .init(onTable: ["cueBall": .init(x: 0.2, y: 0.4), keys[0]: .init(x: 0.3, y: 0.25), keys[1]: .init(x: 0.7, y: 0.25)]),
                drawing: .init(vertices: [a,b], lines: [.init(start:a.id,end:b.id,balls:keys)]))
            try repo.put(t); try await sync(); XCTAssertEqual(try repo.load().pendingCount,0)
        case "B-restore-edit":
            XCTAssertTrue(try repo.load().templates.isEmpty)
            try await sync(); let original = try XCTUnwrap(repo.load().templates.first)
            XCTAssertEqual(original.id,f.templateID); XCTAssertEqual(original.ballKeys.count,2)
            XCTAssertEqual(original.drawing?.lines.first?.balls,original.ballKeys)
            XCTAssertNotEqual(original.ballKeys[0],original.ballKeys[1])
            var edit = original; edit.name = "设备B修改"; try repo.put(edit,basedOn:original); try await sync()
        case "A-offline-conflict":
            let original = try XCTUnwrap(repo.load().templates.first); XCTAssertEqual(original.name,"设备A球形")
            var edit = original; edit.name = "设备A离线修改"; try repo.put(edit,basedOn:original)
            let restarted = CustomFormationRepository(ownerKey:repo.ownerKey)
            XCTAssertEqual(try restarted.load().pendingCount,1)
            // Conflict copy is queued for the subsequent coalesced pass.
            _ = await service.sync(userID:f.userID,repository:repo,shouldContinue:{true})
            try await sync(); let state = try repo.load()
            XCTAssertEqual(state.templates.count,2); XCTAssertEqual(state.templates.first{$0.id == f.templateID}?.name,"设备B修改")
            XCTAssertEqual(state.templates.first{$0.id != f.templateID}?.name,"设备A离线修改 冲突副本")
        case "B-delete":
            try await sync(); XCTAssertEqual(try repo.load().templates.count,2)
            for t in try repo.load().templates { try repo.remove(t.id) }; try await sync()
        case "A-observe-delete":
            try await sync(); XCTAssertTrue(try repo.load().templates.isEmpty); XCTAssertEqual(try repo.load().pendingCount,0)
            try await sync(); XCTAssertTrue(try repo.load().templates.isEmpty)
        default: XCTFail("Unknown integration phase")
        }
    }
}
private struct IntegrationToken: APITokenStore {
    let token: String
    func load(_ key: KeychainService.Key) -> String? { key == .accessToken ? token : nil }
    func save(_ value: String, for key: KeychainService.Key) -> Bool { false }
}
