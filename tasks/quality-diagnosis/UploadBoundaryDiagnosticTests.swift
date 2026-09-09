import XCTest
import SwiftData
@testable import QiuJi

/// Draft only. Run serially in a NEW empty/no-credential QiuJiDiagnosticMemoryHost.
/// Host argv must include -v50.inMemoryStore BEFORE App initialization; no identity/Pro fixture.
/// QD_UPLOAD_AUTH=NEW_EMPTY_MEMORY_HOST, QD_UPLOAD_DEVICE_UDID=SIMULATOR_UDID,
/// QD_SHOT_DIR=new absolute leaf (all keys accept TEST_RUNNER_ fallback).
/// App login notifications use the host's own guest AuthState and return at identity guards.
/// This test injects its separate auth/owner and BOTH shared network backends before login.
@MainActor
final class UploadBoundaryDiagnosticTests: XCTestCase {
    private struct Stop: Error { let message: String }
    private var container: ModelContainer?
    private var output: URL?
    private var backend: UploadBoundaryBackend?
    private var restore: UploadBoundaryRestore?
    private var sequence = 0
    private var finished = true
    private var worker: Task<Void, Never>?
    private var lifecycleWorker: Task<Void, Never>?
    private var lifecycleFinished = true

    func testMultiItemInFlightFailureRetriesOnlyUnacknowledgedItem() async throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_UPLOAD_AUTH") == "NEW_EMPTY_MEMORY_HOST", "Explicit isolated host authorization required")
        guard let expected = setting("QD_UPLOAD_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              env["SIMULATOR_UDID"]?.lowercased() == expected.lowercased() else {
            throw Stop(message: "Runner UDID mismatch")
        }
        let args = ProcessInfo.processInfo.arguments
        try require(args.contains("-v50.inMemoryStore"), "Host must enter memory mode before App initialization")
        try require(!args.contains("-v53.authenticatedProfileFixture") && !args.contains("-forcePremium")
                    && !args.contains("-forceNonPremium"), "No identity or entitlement fixture allowed")
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/"), path != "/" else { throw Stop(message: "Absolute output leaf required") }
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try require(try FileManager.default.contentsOfDirectory(atPath: path).isEmpty, "Refuse existing evidence directory")
        output = URL(fileURLWithPath: path, isDirectory: true)
        let suite = "QD.UploadBoundary." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let owner = CurrentOwnerContext(defaults: defaults)
        let auth = AuthState(backend: UploadBoundaryAuth(), credentials: UploadBoundaryCredentials(), defaults: defaults, ownerContext: owner)
        let memory = ModelContainerFactory.makeInMemoryContainer()
        container = memory
        let context = memory.mainContext
        let coordinator = AccountDataCoordinator(ownerContext: owner, defaults: defaults)
        coordinator.configure(context: context)
        let oldUpload = SyncQueueManager.shared.backend
        let oldRestore = SyncRestoreService.shared.backend
        let oldDefaults = SyncRestoreService.shared.defaults
        SyncQueueManager.shared.configure(context: context)
        SyncRestoreService.shared.configure(context: context)
        SyncRestoreService.shared.defaults = defaults
        let names = ["S0", "S1", "S2", "B", "guest"]
        let owners = [OwnerKey.account("qd-upload-a"), OwnerKey.account("qd-upload-a"), OwnerKey.account("qd-upload-a"), OwnerKey.account("qd-upload-b"), owner.guestOwnerKey]
        var ids: [String] = []
        for i in names.indices {
            let session = TrainingSession(ownerKey: owners[i])
            session.note = names[i]
            session.sourceKind = TodayScheduleSourceKind.template
            session.sourceId = "diagnostic-" + names[i]
            session.sourcePayloadVersion = 1
            session.sourcePayloadSnapshot = Data(("payload-" + names[i]).utf8)
            session.setProgress(role: TodayScheduleProgressRole.neutral, effect: "none")
            context.insert(session)
            let item = SyncPendingItem(entityType: SyncEntityType.trainingSession, entityId: session.id,
                                       operation: SyncOperation.create, ownerKey: owners[i])
            item.createdAt = Date(timeIntervalSince1970: 1_700_000_000 + Double(i))
            context.insert(item); ids.append(session.id.uuidString)
        }
        try context.save()
        let controlled = UploadBoundaryBackend(blockedID: ids[1], expectedNames: Dictionary(uniqueKeysWithValues: zip(ids, names)))
        let downloads = UploadBoundaryRestore()
        backend = controlled; restore = downloads
        SyncQueueManager.shared.backend = controlled
        SyncRestoreService.shared.backend = downloads

        // No shared service is restored to live transport until every controlled worker ends.
        do {
            try await evidence("initial-five-owner-items")
            try verify(ids: ids, names: names, owners: owners, pendingIDs: Set(ids))
            auth.login(user: AppUser(id: "qd-upload-a", provider: .apple))
            auth.setCloudSyncEnabled(true)
            try require(auth.cloudSyncEnabled && owner.ownerKey == owners[0], "Real auth/owner consent prerequisite failed")
            finished = false
            worker = Task { @MainActor in
                // Same normal login path as QiuJiApp didCompleteLogin; guest items must not migrate.
                await coordinator.handleCompletedLogin(userId: "qd-upload-a", authState: auth, offerGuestMigration: false)
                _ = memory // retain the exact container across all awaits
                self.finished = true
            }
            try await waitBounded("S1 must actually suspend inside uploadSession") { await controlled.isWaiting() }
            try await evidence("S1-suspended-before-failure")
            let before = await controlled.state()
            try require(before.attempts == Array(ids.prefix(2)) && before.successes == [ids[0]] && before.failures.isEmpty,
                        "S0 acknowledged and S1 in flight; S2 must not start early")
            // S0 deletion is pending save until the whole batch ends; do not demand fresh-context removal yet.
            try await controlled.releaseNetworkFailure()
            try await waitBounded("First real coordinator round must finish") { self.finished }
            await worker?.value
            try await evidence("first-round-complete")
            let first = await controlled.state()
            try require(first.attempts == Array(ids.prefix(3)), "Failure must not suppress stable-account S2")
            try require(first.successes == [ids[0], ids[2]] && first.failures == [ids[1]], "Only S1 failed; S0/S2 each acknowledged once")
            try require(first.unexpected.isEmpty, "Unexpected backend endpoint was invoked")
            try verify(ids: ids, names: names, owners: owners, pendingIDs: Set([ids[1], ids[3], ids[4]]))
            let fetch1 = await downloads.calls
            try require(fetch1 == ["sessions", "angles"], "Ordinary upload failure still permits the normal pull phase")
            try require(!auth.pendingMigration && !auth.showMigrationPrompt, "Login route must complete consent handling, not skip queue")

            await controlled.allowRetry()
            finished = false
            worker = Task { @MainActor in
                await coordinator.syncActiveAccount(mode: .incremental, authState: auth)
                _ = memory
                self.finished = true
            }
            try await waitBounded("Retry coordinator round must finish") { self.finished }
            await worker?.value
            try await evidence("retry-finished-before-assertions")
            let second = await controlled.state()
            try require(second.attempts == [ids[0], ids[1], ids[2], ids[1]], "Second round must upload only previously unacknowledged S1")
            try require(second.successes == [ids[0], ids[2], ids[1]] && second.failures == [ids[1]] && second.unexpected.isEmpty,
                        "Exact attempted versus successful upload ledger mismatch")
            try require(await downloads.calls == ["sessions", "angles", "sessions", "angles"], "Both pull phases must execute exactly once")
            try require(auth.currentUser?.id == "qd-upload-a" && owner.ownerKey == owners[0] && auth.cloudSyncEnabled,
                        "Stable account/consent must remain unchanged")
            try verify(ids: ids, names: names, owners: owners, pendingIDs: Set([ids[3], ids[4]]))
            try await evidence("verified-only-unacknowledged-retried")
        } catch {
            // Release exactly once BEFORE waiting: cancellation alone cannot release a continuation.
            await controlled.abort()
            worker?.cancel()
            let ended = await awaitFinished()
            do { try await evidence(ended ? "failed-worker-ended" : "failed-worker-still-live-do-not-restore-network") }
            catch { XCTFail("Failure evidence write also failed: \(error)") }
            if ended {
                SyncQueueManager.shared.backend = oldUpload
                SyncRestoreService.shared.backend = oldRestore
                SyncRestoreService.shared.defaults = oldDefaults
                defaults.removePersistentDomain(forName: suite)
            }
            // If a worker remains live, retain the controlled backends/context; host must stop.
            throw error
        }
        SyncQueueManager.shared.backend = oldUpload
        SyncRestoreService.shared.backend = oldRestore
        SyncRestoreService.shared.defaults = oldDefaults
        defaults.removePersistentDomain(forName: suite)
        // Shared context has no getter/reset API. Keep memory alive until this dedicated host exits.
    }

    func testInFlightUploadInvalidationStopsOldBatchAcrossDisableAndABA() async throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_UPLOAD_AUTH") == "NEW_EMPTY_MEMORY_HOST", "Explicit isolated host authorization required")
        guard let expected = setting("QD_UPLOAD_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              env["SIMULATOR_UDID"]?.lowercased() == expected.lowercased() else {
            throw Stop(message: "Runner UDID mismatch")
        }
        let args = ProcessInfo.processInfo.arguments
        try require(args.contains("-v50.inMemoryStore"), "Host must enter memory mode before App initialization")
        try require(!args.contains("-v53.authenticatedProfileFixture") && !args.contains("-forcePremium")
                    && !args.contains("-forceNonPremium"), "No identity or entitlement fixture allowed")
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/"), path != "/" else { throw Stop(message: "Absolute output leaf required") }
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        try require(try FileManager.default.contentsOfDirectory(atPath: path).isEmpty, "Refuse existing evidence directory")
        output = URL(fileURLWithPath: path, isDirectory: true)
        // Five entities per row: S0 acknowledged before the barrier, S1 in flight,
        // S2 not sent, B and guest controls. Every row has an independent store/auth/actors.
        for variant in ["disable-success", "disable-failure", "sync-ABA-failure", "account-ABA-failure"] {
            finished = true
            worker = nil
            lifecycleWorker = nil
            lifecycleFinished = true
            let suite = "QD.UploadBoundary." + UUID().uuidString
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            let owner = CurrentOwnerContext(defaults: defaults)
            let auth = AuthState(backend: UploadBoundaryAuth(), credentials: UploadBoundaryCredentials(), defaults: defaults, ownerContext: owner)
            let memory = ModelContainerFactory.makeInMemoryContainer()
            container = memory
            let context = memory.mainContext
            let coordinator = AccountDataCoordinator(ownerContext: owner, defaults: defaults)
            coordinator.configure(context: context)
            let oldUpload = SyncQueueManager.shared.backend
            let oldRestore = SyncRestoreService.shared.backend
            let oldDefaults = SyncRestoreService.shared.defaults
            SyncQueueManager.shared.configure(context: context)
            SyncRestoreService.shared.configure(context: context)
            SyncRestoreService.shared.defaults = defaults
            let names = ["S0", "S1", "S2", "B", "guest"]
            let owners = [OwnerKey.account("qd-upload-a"), OwnerKey.account("qd-upload-a"), OwnerKey.account("qd-upload-a"), OwnerKey.account("qd-upload-b"), owner.guestOwnerKey]
            var ids: [String] = []
            for i in names.indices {
                let session = TrainingSession(ownerKey: owners[i])
                session.note = names[i]
                session.sourceKind = TodayScheduleSourceKind.template
                session.sourceId = "diagnostic-" + names[i]
                session.sourcePayloadVersion = 1
                session.sourcePayloadSnapshot = Data(("payload-" + names[i]).utf8)
                session.setProgress(role: TodayScheduleProgressRole.neutral, effect: "none")
                context.insert(session)
                let item = SyncPendingItem(entityType: SyncEntityType.trainingSession, entityId: session.id,
                                           operation: SyncOperation.create, ownerKey: owners[i])
                item.createdAt = Date(timeIntervalSince1970: 1_700_000_000 + Double(i))
                context.insert(item); ids.append(session.id.uuidString)
            }
            try context.save()
            let controlled = UploadBoundaryBackend(blockedID: ids[1], expectedNames: Dictionary(uniqueKeysWithValues: zip(ids, names)))
            let downloads = UploadBoundaryRestore()
            backend = controlled; restore = downloads
            SyncQueueManager.shared.backend = controlled
            SyncRestoreService.shared.backend = downloads


            do {
                await controlled.recordEvent("row=" + variant + " initial")
                try verify(ids: ids, names: names, owners: owners, pendingIDs: Set(ids))
                try await evidence(variant + "-initial")
                auth.login(user: AppUser(id: "qd-upload-a", provider: .apple))
                auth.setCloudSyncEnabled(true)
                let originalRevision = auth.syncChoiceRevision
                try require(auth.cloudSyncEnabled && owner.ownerKey == owners[0], "Initial A consent and owner required")
                finished = false
                worker = Task { @MainActor in
                    await controlled.recordEvent("old-login-A-coordinator-start")
                    await coordinator.handleCompletedLogin(userId: "qd-upload-a", authState: auth, offerGuestMigration: false)
                    await controlled.recordEvent("old-login-A-coordinator-end")
                    _ = memory
                    self.finished = true
                }
                try await waitBounded("S1 must be suspended before invalidating old batch") { await controlled.isWaiting() }
                let blocked = await controlled.state()
                try require(blocked.attempts == [ids[0], ids[1]] && blocked.successes == [ids[0]]
                            && blocked.failures.isEmpty && blocked.unexpected.isEmpty, "Exact S0/S1 barrier prerequisite")
                try require(await downloads.calls.isEmpty, "Pull cannot precede completion of push")
                try await evidence(variant + "-S1-suspended")

                if variant == "account-ABA-failure" {
                    auth.login(user: AppUser(id: "qd-upload-b", provider: .apple))
                    try require(auth.currentUser?.id == "qd-upload-b" && owner.ownerKey == owners[3]
                                && !auth.cloudSyncEnabled, "B must be a real independent default-off account")
                    await controlled.recordEvent("login-B-off owner=" + owner.ownerKey + " revision=\(auth.syncChoiceRevision)")
                    // Deliver the genuine B login handler; it increments coordinator generation
                    // and returns at the real default-off guard. Never mutate private generation.
                    lifecycleFinished = false
                    lifecycleWorker = Task { @MainActor in
                        await controlled.recordEvent("B-coordinator-start")
                        await coordinator.handleCompletedLogin(userId: "qd-upload-b", authState: auth, offerGuestMigration: false)
                        await controlled.recordEvent("B-coordinator-end")
                        self.lifecycleFinished = true
                    }
                    // This default-off handler contains no backend await after its guards.
                    try await waitBounded("Default-off B login coordinator must finish") { self.lifecycleFinished }
                    await lifecycleWorker?.value
                    auth.login(user: AppUser(id: "qd-upload-a", provider: .apple))
                    try require(auth.currentUser?.id == "qd-upload-a" && owner.ownerKey == owners[0]
                                && auth.cloudSyncEnabled, "A login must restore its prior true consent")
                    await controlled.recordEvent("login-A-restored-true; new-A-coordinator-delivery-deferred-until-old-round-ends revision=\(auth.syncChoiceRevision)")
                } else {
                    auth.setCloudSyncEnabled(false)
                    try require(!auth.cloudSyncEnabled && auth.syncChoiceRevision > originalRevision,
                                "Disable must invalidate the captured consent revision")
                    await controlled.recordEvent("disable-A revision=\(auth.syncChoiceRevision)")
                    if variant == "sync-ABA-failure" {
                        auth.setCloudSyncEnabled(true)
                        try require(auth.cloudSyncEnabled && auth.syncChoiceRevision > originalRevision + 1,
                                    "ABA must end true with a different consent revision")
                        await controlled.recordEvent("reenable-A revision=\(auth.syncChoiceRevision)")
                    }
                    // Like the existing download-invalidation tests, mutate real AuthState while
                    // old coordinator is awaiting. Defer a NEW coordinator round until old ends:
                    // this isolates request-boundary revision checking, not App notification races.
                    await controlled.recordEvent("new-consent-coordinator-delivery-deferred-until-old-round-ends")
                }
                try require(await controlled.isWaiting(), "U1 barrier must still be held after lifecycle changes")
                try await evidence(variant + "-invalidated-before-late-result")
                if variant == "disable-success" { try await controlled.releaseSuccess() }
                else { try await controlled.releaseNetworkFailure() }
                try await waitBounded("Old invalidated upload round must end") { self.finished }
                await worker?.value
                try await evidence(variant + "-old-round-ended")
                let stale = await controlled.state()
                let successCase = variant == "disable-success"
                try require(stale.attempts == [ids[0], ids[1]] && stale.unexpected.isEmpty,
                            "Old batch must not send S2 or another owner after invalidation")
                try require(stale.successes == (successCase ? [ids[0], ids[1]] : [ids[0]])
                            && stale.failures == (successCase ? [] : [ids[1]]), "Late success/failure must retain its correct outcome")
                try require(await downloads.calls.isEmpty, "Invalidated batch must not start either restore endpoint")
                let retained = successCase ? [ids[2], ids[3], ids[4]] : [ids[1], ids[2], ids[3], ids[4]]
                try verify(ids: ids, names: names, owners: owners, pendingIDs: Set(retained))
                try require(auth.currentUser?.id == "qd-upload-a" && owner.ownerKey == owners[0]
                            && auth.errorMessage == nil, "Late upload result must not replace/sign out/error current A")
                try require(auth.cloudSyncEnabled == (variant == "sync-ABA-failure" || variant == "account-ABA-failure"),
                            "Late result must not rewrite the actual consent state")
                try require(SyncRestoreService.shared.anchor(.sessions, userId: "qd-upload-a") == nil
                            && SyncRestoreService.shared.anchor(.angleTests, userId: "qd-upload-a") == nil,
                            "No old-round restore anchor may be written")

                // Begin the genuine new A login coordinator only after the old one has stopped.
                // It handles pendingMigration via offerGuestMigration:false, as the App login route.
                await controlled.allowRetry()
                if !auth.cloudSyncEnabled { auth.setCloudSyncEnabled(true) }
                finished = false
                worker = Task { @MainActor in
                    await controlled.recordEvent("new-login-A-coordinator-start revision=\(auth.syncChoiceRevision)")
                    await coordinator.handleCompletedLogin(userId: "qd-upload-a", authState: auth, offerGuestMigration: false)
                    await controlled.recordEvent("new-login-A-coordinator-end")
                    _ = memory
                    self.finished = true
                }
                try await waitBounded("New authorized round must finish retry") { self.finished }
                await worker?.value
                try await evidence(variant + "-new-round-ended-before-assertions")
                let final = await controlled.state()
                let expectedAttempts = successCase ? [ids[0], ids[1], ids[2]] : [ids[0], ids[1], ids[1], ids[2]]
                try require(final.attempts == expectedAttempts && final.successes == Array(ids.prefix(3))
                            && final.failures == (successCase ? [] : [ids[1]]) && final.unexpected.isEmpty,
                            "Only unacknowledged A items may be retried by the new round")
                try require(await downloads.calls == ["sessions", "angles"], "Exactly the new round may pull")
                try verify(ids: ids, names: names, owners: owners, pendingIDs: Set([ids[3], ids[4]]))
                try require(auth.currentUser?.id == "qd-upload-a" && owner.ownerKey == owners[0]
                            && auth.cloudSyncEnabled && !auth.pendingMigration && !auth.showMigrationPrompt,
                            "Actual new round must complete without bypassing migration guard")
                try await evidence(variant + "-verified")
            } catch {
                await controlled.abort()
                worker?.cancel()
                lifecycleWorker?.cancel()
                let ended = await awaitInvalidationWorkersFinished()
                do { try await evidence(variant + (ended ? "-failed-worker-ended" : "-failed-worker-live-retain-isolation")) }
                catch { XCTFail("Failure evidence write also failed: \(error)") }
                if ended {
                    SyncQueueManager.shared.backend = oldUpload
                    SyncRestoreService.shared.backend = oldRestore
                    SyncRestoreService.shared.defaults = oldDefaults
                    defaults.removePersistentDomain(forName: suite)
                }
                throw error
            }
            SyncQueueManager.shared.backend = oldUpload
            SyncRestoreService.shared.backend = oldRestore
            SyncRestoreService.shared.defaults = oldDefaults
            defaults.removePersistentDomain(forName: suite)
        }
    }

    private func awaitInvalidationWorkersFinished() async -> Bool {
        for _ in 0..<100 {
            if finished && lifecycleFinished { return true }
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { continuation.resume() }
            }
        }
        return finished && lifecycleFinished
    }

    private func require(_ condition: Bool, _ message: String) throws {
        guard condition else { XCTFail(message); throw Stop(message: message) }
    }
    private func waitBounded(_ message: String, _ condition: () async -> Bool) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try require(false, message)
    }
    private func awaitFinished() async -> Bool {
        // No throwing sleep in failure cleanup; yield a bounded number of scheduled checks.
        for _ in 0..<100 {
            if finished { return true }
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { continuation.resume() }
            }
        }
        return finished
    }
    private func verify(ids: [String], names: [String], owners: [String], pendingIDs: Set<String>) throws {
        let reader = ModelContext(try XCTUnwrap(container))
        let rows = try reader.fetch(FetchDescriptor<TrainingSession>())
        try require(rows.count == 5 && Set(rows.map { $0.id.uuidString }) == Set(ids), "All five original entities must remain")
        for i in ids.indices {
            let row = try XCTUnwrap(rows.first { $0.id.uuidString == ids[i] })
            try require(row.ownerKey == owners[i] && row.note == names[i] && row.sourceId == "diagnostic-" + names[i]
                        && row.sourcePayloadSnapshot == Data(("payload-" + names[i]).utf8)
                        && row.sourceKind == TodayScheduleSourceKind.template && row.sourcePayloadVersion == 1
                        && row.appliedProgressEffect == "none", "Persisted owner/provenance changed")
        }
        let pending = try reader.fetch(FetchDescriptor<SyncPendingItem>())
        try require(pending.count == pendingIDs.count && Set(pending.map { $0.entityId.uuidString }) == pendingIDs, "Independent context pending set mismatch")
        for item in pending {
            let index = try XCTUnwrap(ids.firstIndex(of: item.entityId.uuidString))
            try require(item.ownerKey == owners[index] && item.entityType == SyncEntityType.trainingSession && item.operation == SyncOperation.create
                        && item.createdAt == Date(timeIntervalSince1970: 1_700_000_000 + Double(index)), "Queue identity/order/owner changed")
        }
    }
    private func evidence(_ stage: String) async throws {
        let reader = ModelContext(try XCTUnwrap(container))
        let rows = try reader.fetch(FetchDescriptor<TrainingSession>())
        let pending = try reader.fetch(FetchDescriptor<SyncPendingItem>())
        let state = await backend?.state()
        let fetches = await restore?.calls ?? []
        let object: [String: Any] = ["stage": stage, "uptime": ProcessInfo.processInfo.systemUptime,
            "finished": finished, "events": state?.events ?? [], "attempts": state?.attempts ?? [],
            "successes": state?.successes ?? [], "failures": state?.failures ?? [], "unexpected": state?.unexpected ?? [],
            "fetches": fetches,
            "sessions": rows.map { ["id": $0.id.uuidString, "owner": $0.ownerKey, "note": $0.note,
                                      "source": $0.sourceId ?? "", "payload": $0.sourcePayloadSnapshot?.base64EncodedString() ?? ""] },
            "pending": pending.map { ["id": $0.id.uuidString, "entity": $0.entityId.uuidString, "owner": $0.ownerKey,
                                       "operation": $0.operation, "createdAt": String($0.createdAt.timeIntervalSince1970)] }]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        sequence += 1
        let name = "upload-\(sequence)-" + stage
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        try data.write(to: try XCTUnwrap(output).appendingPathComponent(name + ".json"), options: .withoutOverwriting)
    }
}

private struct UploadBoundaryAuth: AuthSessionBackend {
    func fetchProfile() async throws -> UserDTO { throw AppError.authRequired }
    func logout() async {}
}
private struct UploadBoundaryCredentials: AuthCredentialStore {
    var hasRefreshToken: Bool { false }
    func clearAll() {}
}
private actor UploadBoundaryRestore: SyncRestoreBackend {
    private(set) var calls: [String] = []
    func fetchSessions(after: Date?) async throws -> [SyncedRecord<TrainingSessionDTO>] { calls.append("sessions"); return [] }
    func fetchAngleTests(after: Date?) async throws -> [SyncedRecord<AngleTestDTO>] { calls.append("angles"); return [] }
}
private actor UploadBoundaryBackend: SyncBackend {
    struct State: Sendable {
        var attempts: [String] = []; var successes: [String] = []; var failures: [String] = []
        var unexpected: [String] = []; var events: [String] = []
    }
    private let blockedID: String
    private let expectedNames: [String: String]
    private var ledger = State()
    private var suspended: CheckedContinuation<Void, Error>?
    private var retryAllowed = false
    private var aborted = false
    init(blockedID: String, expectedNames: [String: String]) {
        self.blockedID = blockedID; self.expectedNames = expectedNames
    }
    func state() -> State { ledger }
    func isWaiting() -> Bool { suspended != nil }
    private func event(_ value: String) { ledger.events.append("\(ProcessInfo.processInfo.systemUptime) " + value) }
    func uploadSession(_ dto: TrainingSessionDTO) async throws {
        ledger.attempts.append(dto.clientId)
        event("attempt \(dto.clientId) source=\(dto.sourceId ?? "") payload=\(dto.sourcePayloadSnapshot?.base64EncodedString() ?? "")")
        do {
            guard let name = expectedNames[dto.clientId], ["S0", "S1", "S2"].contains(name),
                  dto.sourceKind == TodayScheduleSourceKind.template,
                  dto.sourceId == "diagnostic-" + name, dto.sourcePayloadVersion == 1,
                  dto.sourcePayloadSnapshot == Data(("payload-" + name).utf8), dto.progressEffect == "none" else {
                ledger.unexpected.append("invalid-owner-or-provenance " + dto.clientId)
                throw AppError.networkError("unexpected owner or DTO provenance")
            }
            if aborted { throw AppError.networkError("diagnostic-aborted") }
            if dto.clientId == blockedID && !retryAllowed {
                guard suspended == nil else { ledger.unexpected.append("concurrent-S1"); throw AppError.networkError("unexpected concurrent S1") }
                try await withCheckedThrowingContinuation { suspended = $0 }
            }
            ledger.successes.append(dto.clientId); event("success " + dto.clientId)
        } catch {
            ledger.failures.append(dto.clientId); event("failure " + dto.clientId)
            throw error
        }
    }
    func releaseNetworkFailure() throws {
        guard let waiter = suspended else { throw AppError.networkError("S1 is not suspended") }
        suspended = nil; event("release-S1-network-failure")
        waiter.resume(throwing: AppError.networkError("diagnostic fixed offline"))
    }
    func releaseSuccess() throws {
        guard let waiter = suspended else { throw AppError.networkError("S1 is not suspended") }
        suspended = nil; event("release-S1-success")
        waiter.resume()
    }
    func recordEvent(_ value: String) { event(value) }
    func allowRetry() { retryAllowed = true; event("allow-retry") }
    func abort() {
        aborted = true
        if let waiter = suspended { suspended = nil; event("abort-release"); waiter.resume(throwing: AppError.networkError("diagnostic-aborted")) }
    }
    func uploadAngleTest(_ dto: AngleTestDTO) async throws {
        ledger.unexpected.append("uploadAngleTest " + dto.clientId); event("unexpected-angle")
        throw AppError.networkError("unexpected angle endpoint")
    }
    func deleteSession(clientId: String) async throws {
        ledger.unexpected.append("deleteSession " + clientId); event("unexpected-delete")
        throw AppError.networkError("unexpected delete endpoint")
    }
}
