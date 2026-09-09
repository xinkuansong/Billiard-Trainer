import XCTest
import SwiftData
@testable import QiuJi

/// Unregistered review draft. Real favorite repository, independent memory store and owner context.
@MainActor
final class FavoriteOwnerDiagnosticTests: XCTestCase {
    private struct Stop: Error { let message: String }
    private func require(_ value: Bool, _ message: String) throws {
        if !value { throw Stop(message: message) }
    }
    func testSharedAndDistinctFavoritesRemainScopedAcrossGuestABQueriesAndMutations() async throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { environment[key] ?? environment["TEST_RUNNER_" + key] }
        try require(setting("QD_FAVORITE_OWNER_AUTH") == "NEW_EMPTY_MEMORY_HOST", "Dedicated fresh no-credential host required")
        guard let expectedDevice = setting("QD_EXPECTED_DEVICE_UDID"), UUID(uuidString: expectedDevice) != nil,
              setting("SIMULATOR_UDID")?.lowercased() == expectedDevice.lowercased(),
              let path = setting("QD_SHOT_DIR"), path.hasPrefix("/"), path != "/" else { throw Stop(message: "Device/evidence guards failed") }
        let args = ProcessInfo.processInfo.arguments
        try require(args.contains("-v50.inMemoryStore"), "Host memory mode must precede App initialization")
        try require(!args.contains("-v53.authenticatedProfileFixture") && !args.contains("-forcePremium") && !args.contains("-forceNonPremium"), "No identity or premium fixture")
        let output = URL(fileURLWithPath: path).appendingPathComponent("favorite-owner-" + UUID().uuidString)
        try require(!FileManager.default.fileExists(atPath: output.path), "New evidence leaf")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let suite = "QD.FavoriteOwner." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: suite) else { throw Stop(message: "Independent defaults unavailable") }
        try require(defaults.persistentDomain(forName: suite) == nil, "New suite only")
        defer { defaults.removePersistentDomain(forName: suite) }
        let guestID = "qd-favorite-guest-" + UUID().uuidString.lowercased()
        defaults.set(guestID, forKey: "auth.deviceGuestID")
        let owner = CurrentOwnerContext(defaults: defaults)
        let keys = ["guest:" + guestID, "account:qd-favorite-A", "account:qd-favorite-B"]
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let repo = LocalDrillFavoriteRepository(context: context, ownerContext: owner)
        let ids = ["drill_c001", "drill_c009", "drill_c012", "drill_c037"]
        var rows: [[String: Any]] = []
        func choose(_ index: Int) throws {
            if index == 0 { owner.useGuest() } else { owner.useAccount(userID: index == 1 ? "qd-favorite-A" : "qd-favorite-B") }
            try require(owner.ownerKey == keys[index], "Literal owner identity mismatch")
        }
        func saveEvidence(_ stage: String, error: String? = nil) throws {
            let raw = try ModelContext(container).fetch(FetchDescriptor<DrillFavorite>())
            var payload: [String: Any] = ["stage": stage, "device": expectedDevice, "queries": rows,
                "persistedRows": raw.map { ["owner": $0.ownerKey, "drill": $0.drillId, "addedAt": $0.addedAt.timeIntervalSince1970] as [String: Any] }]
            if let error { payload["error"] = error }
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: output.appendingPathComponent(stage + ".json"), options: .withoutOverwriting)
            let a = XCTAttachment(data: data, uniformTypeIdentifier: "public.json"); a.name = stage; a.lifetime = .keepAlways; add(a)
        }
        func checkAll(_ stage: String, _ expected: [Set<String>]) async throws {
            for index in 0..<3 {
                try choose(index)
                let fetched = try await repo.fetchAll()
                var flags: [String: Bool] = [:]
                for id in ids { flags[id] = try await repo.isFavorited(drillId: id) }
                rows.append(["stage": stage, "owner": keys[index], "expected": expected[index].sorted(),
                             "actual": fetched.map(\.drillId).sorted(), "actualOwners": fetched.map(\.ownerKey), "isFavorited": flags])
                try require(fetched.count == expected[index].count && Set(fetched.map(\.drillId)) == expected[index], "Exact owner result count/set: " + stage)
                try require(fetched.allSatisfy { $0.ownerKey == keys[index] }, "Foreign owner leaked")
                for id in ids { try require(flags[id] == expected[index].contains(id), "isFavorited leaked or omitted " + id) }
            }
            let raw = try ModelContext(container).fetch(FetchDescriptor<DrillFavorite>())
            let actualPairs = raw.map { $0.ownerKey + "|" + $0.drillId }
            let expectedPairs = Set((0..<3).flatMap { index in expected[index].map { keys[index] + "|" + $0 } })
            try require(actualPairs.count == expectedPairs.count && Set(actualPairs) == expectedPairs, "Independent context exact rows including duplicates/other owners")
            try saveEvidence(stage)
        }
        do {
            try await checkAll("01-empty", [[], [], []])
            // Same drill shared across all owners; each also has a distinct drill.
            for index in 0..<3 {
                try choose(index)
                try await repo.add(drillId: "drill_c001")
                try await repo.add(drillId: ids[index+1])
                try await repo.add(drillId: "drill_c001")
            }
            try await checkAll("02-six-independent-favorites", [["drill_c001","drill_c009"], ["drill_c001","drill_c012"], ["drill_c001","drill_c037"]])
            let before = try ModelContext(container).fetch(FetchDescriptor<DrillFavorite>())
            let untouched = Dictionary(uniqueKeysWithValues: before.filter { $0.ownerKey != keys[1] }.map { ($0.ownerKey + "|" + $0.drillId, $0.addedAt) })
            try choose(1)
            try await repo.remove(drillId: "drill_c001")
            try await repo.remove(drillId: "drill_c037") // Exists only for B; absent for A.
            try await checkAll("03-A-removal-does-not-touch-B-or-guest", [["drill_c001","drill_c009"], ["drill_c012"], ["drill_c001","drill_c037"]])
            let after = try ModelContext(container).fetch(FetchDescriptor<DrillFavorite>())
            try require(Dictionary(uniqueKeysWithValues: after.filter { $0.ownerKey != keys[1] }.map { ($0.ownerKey + "|" + $0.drillId, $0.addedAt) }) == untouched, "Other owners' original timestamps/rows changed")
            try choose(1); try await repo.add(drillId: "drill_c001")
            try choose(0); try await repo.remove(drillId: "drill_c009")
            try choose(2); try await repo.remove(drillId: "drill_c001")
            try await checkAll("04-final-distinct-mutations", [["drill_c001"], ["drill_c001","drill_c012"], ["drill_c037"]])
            print("[QD-FavoriteOwner] four stages, exact guest/A/B sets, independent context; evidence=\(output.path)")
        } catch {
            try saveEvidence("failure-before-local-suite-cleanup", error: String(describing: error))
            throw error
        }
    }
}
