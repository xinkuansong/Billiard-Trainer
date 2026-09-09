import Foundation
import XCTest
@testable import QiuJi

/// Unregistered hosted diagnostic. New empty/no-credential memory host only; run serially.
/// QD_OWNER_GOAL_AUTH=NEW_EMPTY_MEMORY_HOST; QD_OWNER_GOAL_DEVICE_UDID=SIMULATOR_UDID;
/// QD_SHOT_DIR=new absolute empty directory. All QD keys accept TEST_RUNNER_ fallback.
@MainActor
final class OwnerGoalBoundaryDiagnosticTests: XCTestCase {
    private struct Stop: Error { let message: String }

    func testWeeklyGoalsRemainOwnerScopedAcrossSaveSwitchAndStoreRecreation() async throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_OWNER_GOAL_AUTH") == "NEW_EMPTY_MEMORY_HOST", "Fresh no-credential host attestation required")
        guard let expected = setting("QD_OWNER_GOAL_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              env["SIMULATOR_UDID"]?.lowercased() == expected.lowercased() else {
            throw Stop(message: "Explicit diagnostic device mismatch")
        }
        let args = ProcessInfo.processInfo.arguments
        try require(args.contains("-v50.inMemoryStore"), "Memory host argument must precede App initialization")
        try require(!args.contains("-v53.authenticatedProfileFixture") && !args.contains("-forcePremium")
                    && !args.contains("-forceNonPremium"), "No identity or premium overrides")
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/"), path != "/" else {
            throw Stop(message: "Absolute output directory required")
        }
        let output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try require(try FileManager.default.contentsOfDirectory(atPath: path).isEmpty, "Refuse populated evidence directory")
        try require(CurrentOwnerContext.shared.ownerKey == CurrentOwnerContext.shared.guestOwnerKey,
                    "Host shared owner must remain guest before local auth notifications")
        let suite = "QD.OwnerGoal." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = CurrentOwnerContext(defaults: defaults)
        let backend = OwnerGoalControlledBackend()
        let auth = AuthState(backend: backend, credentials: OwnerGoalEmptyCredentials(), defaults: defaults, ownerContext: owner)
        let guestKey = owner.guestOwnerKey
        let aKey = OwnerKey.account("qd-goal-a")
        let bKey = OwnerKey.account("qd-goal-b")
        let keys = [guestKey, aKey, bKey]
        var stores = keys.map { OwnerProfileStore(ownerKey: $0, defaults: defaults, backend: backend) }
        var switches: [[String: Any]] = []
        var phase = "initial"

        func saveEvidence(_ filename: String) async throws {
            let ledger = await backend.ledger()
            let object: [String: Any] = [
                "phase": phase, "suite": suite, "device": expected,
                "owner": owner.ownerKey, "authenticated": auth.isLoggedIn,
                "currentUserID": auth.currentUser?.id ?? "nil",
                "currentUserGoal": auth.currentUser?.weeklyGoalDays as Any? ?? NSNull(),
                "cloudSyncEnabled": auth.cloudSyncEnabled,
                "stores": stores.map { store -> [String: Any] in ["owner": store.ownerKey, "goal": store.weeklyGoalDays,
                                         "isSaving": store.isSaving, "error": store.errorMessage as Any? ?? NSNull()] },
                "persisted": keys.map { key -> [String: Any] in ["owner": key, "goal": defaults.object(forKey: "ownerProfile.\(key).weeklyGoalDays") ?? NSNull()] },
                "switches": switches, "requests": ledger
            ]
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: output.appendingPathComponent(filename), options: .atomic)
        }
        func checkLedger(_ count: Int) async throws {
            let records = await backend.ledger()
            try require(records.count == count, "Unexpected auth/profile request count: \(records.count), expected \(count)")
            for (index, record) in records.enumerated() {
                try require(record["operation"] == "updateProfile" && record["onlyWeeklyGoal"] == "true",
                            "Unexpected operation or unrelated profile mutation")
                try require(record["requested"] == (index == 0 ? "4" : "6") &&
                            record["responseID"] == (index == 0 ? "qd-goal-a" : "qd-goal-b") &&
                            record["responseGoal"] == (index == 0 ? "5" : "6"), "Exact request/response ledger mismatch")
            }
        }
        func checkGoals(_ expectedGoals: [Int]) throws {
            try require(stores.map(\.weeklyGoalDays) == expectedGoals, "Owner goal values mixed or stale")
            for (store, expectedGoal) in zip(stores, expectedGoals) {
                try require(store.errorMessage == nil && !store.isSaving, "Save did not finish successfully")
                try require(defaults.integer(forKey: "ownerProfile.\(store.ownerKey).weeklyGoalDays") == expectedGoal,
                            "Owner-prefixed persisted value mismatch")
            }
        }
        do {
            auth.loginAnonymously()
            try await saveEvidence("01-initial.json")
            try require(!auth.isLoggedIn && owner.ownerKey == guestKey && !auth.cloudSyncEnabled, "Guest prerequisite failed")
            try require(stores.map(\.weeklyGoalDays) == [3, 3, 3], "Fresh defaults must resolve default goals")
            try await checkLedger(0)

            phase = "guest-save-2"
            await stores[0].setWeeklyGoalDays(2, authState: auth)
            try await saveEvidence("02-guest-saved.json")
            try require(stores[0].weeklyGoalDays == 2 && defaults.integer(forKey: "ownerProfile.\(guestKey).weeklyGoalDays") == 2,
                        "Guest goal was not persisted")
            try require(stores[0].errorMessage == nil && !stores[0].isSaving, "Guest save terminal state invalid")
            try await checkLedger(0)

            phase = "account-a-request-4-response-5"
            auth.login(user: AppUser(id: "qd-goal-a", provider: .apple, weeklyGoalDays: 3))
            try require(auth.isLoggedIn && owner.ownerKey == aKey && !auth.cloudSyncEnabled, "Account A prerequisite failed")
            stores[1].load(from: auth.currentUser)
            await stores[1].setWeeklyGoalDays(4, authState: auth)
            try await saveEvidence("03-account-a-saved.json")
            let savedA = try XCTUnwrap(auth.currentUser)
            try require(savedA.id == "qd-goal-a" && savedA.weeklyGoalDays == 5 && stores[1].weeklyGoalDays == 5,
                        "Account A must commit server response 5, not requested 4")
            try require(defaults.integer(forKey: "ownerProfile.\(aKey).weeklyGoalDays") == 5, "Account A response not persisted")
            try await checkLedger(1)

            phase = "account-b-save-6-invalid-0-and-8"
            auth.login(user: AppUser(id: "qd-goal-b", provider: .apple, weeklyGoalDays: 3))
            try require(auth.isLoggedIn && owner.ownerKey == bKey && !auth.cloudSyncEnabled, "Account B prerequisite failed")
            stores[2].load(from: auth.currentUser)
            await stores[2].setWeeklyGoalDays(6, authState: auth)
            let savedB = try XCTUnwrap(auth.currentUser)
            try require(savedB.id == "qd-goal-b" && savedB.weeklyGoalDays == 6, "Account B save prerequisite failed")
            try checkGoals([2, 5, 6])
            try await checkLedger(2)
            await stores[2].setWeeklyGoalDays(0, authState: auth)
            try checkGoals([2, 5, 6])
            try await checkLedger(2)
            await stores[2].setWeeklyGoalDays(8, authState: auth)
            try await saveEvidence("04-account-b-boundaries.json")
            try checkGoals([2, 5, 6])
            try require(auth.currentUser == savedB, "Rejected goals must not change authenticated profile")
            try await checkLedger(2)

            phase = "switch-and-recreate"
            // Reuse committed server profiles, not stale pre-save goal=3 profiles.
            for (index, user) in [(1, Optional(savedA)), (0, Optional<AppUser>.none), (2, Optional(savedB))] {
                if let user { auth.login(user: user) } else { auth.loginAnonymously() }
                try require(owner.ownerKey == keys[index] && !auth.cloudSyncEnabled, "Owner switch failed")
                let rebuilt = OwnerProfileStore(ownerKey: owner.ownerKey, defaults: defaults, backend: backend)
                let cached = rebuilt.weeklyGoalDays
                try require(cached == [2, 5, 6][index], "New Store did not read owner cache")
                rebuilt.load(from: auth.currentUser)
                try require(rebuilt.weeklyGoalDays == cached, "Loading matching server/guest profile changed committed goal")
                stores[index] = rebuilt
                switches.append(["owner": owner.ownerKey, "beforeLoad": cached, "afterLoad": rebuilt.weeklyGoalDays])
                try checkGoals([2, 5, 6])
                try await checkLedger(2)
            }
            let rebuiltOwner = CurrentOwnerContext(defaults: defaults)
            try require(rebuiltOwner.ownerKey == guestKey && rebuiltOwner.guestOwnerKey == guestKey, "Guest identity did not survive context recreation")
            try await saveEvidence("05-switched-and-rebuilt.json")
            try require(switches.count == 3, "All A/guest/B readbacks required")
        } catch {
            // Preserve current values and all requests before the UUID defaults domain is removed.
            do { try await saveEvidence("failure.json") }
            catch let evidenceError {
                XCTFail("Failure evidence write failed: \(evidenceError)")
                throw evidenceError
            }
            throw error
        }
    }

    private func require(_ condition: Bool, _ message: String,
                         file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else { XCTFail(message, file: file, line: line); throw Stop(message: message) }
    }
}

private actor OwnerGoalControlledBackend: UserProfileBackend, AuthSessionBackend {
    private var records: [[String: String]] = []
    private struct UnexpectedRequest: Error {}
    func ledger() -> [[String: String]] { records }
    func updateProfile(_ update: UserProfileUpdate) async throws -> UserDTO {
        let number = records.count
        let onlyGoal = update.displayName == nil && update.preferredSport == nil && update.skillLevel == nil && update.yearsPlaying == nil
        let accepted = number < 2 && onlyGoal && update.weeklyGoalDays == (number == 0 ? 4 : 6)
        let responseID = number == 0 ? "qd-goal-a" : "qd-goal-b"
        let responseGoal = number == 0 ? 5 : 6
        records.append(["operation": "updateProfile", "requested": update.weeklyGoalDays.map(String.init) ?? "nil",
                        "onlyWeeklyGoal": String(onlyGoal), "responseID": accepted ? responseID : "rejected",
                        "responseGoal": accepted ? String(responseGoal) : "none"])
        guard accepted else { throw UnexpectedRequest() }
        return UserDTO(id: responseID, displayName: nil, email: nil, provider: "apple", avatarRevision: nil,
                       preferredSport: "chinese8", skillLevel: "beginner", yearsPlaying: "lessThan1", weeklyGoalDays: responseGoal)
    }
    func fetchProfile() async throws -> UserDTO {
        records.append(["operation": "unexpected-fetchProfile"])
        throw UnexpectedRequest()
    }
    func logout() async { records.append(["operation": "unexpected-logout"]) }
}

private struct OwnerGoalEmptyCredentials: AuthCredentialStore {
    var hasRefreshToken: Bool { false }
    func clearAll() {}
}
