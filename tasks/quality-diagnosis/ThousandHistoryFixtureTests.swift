import XCTest
import SwiftData
@testable import QiuJi

/// Dedicated fresh simulator only. A prior probe authorizes the exact default
/// store relative path and owner; only the OS-managed sandbox root may relocate.
/// Never deletes/replaces a store or accepts an arbitrary database target URL.
@MainActor
final class ThousandHistoryFixtureTests: XCTestCase {
    func testSeedDedicatedEmptyDefaultStoreForNormalHistoryUI() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["QD_ALLOW_THOUSAND_DISK_SEED"] == "DEDICATED_EMPTY_GUEST_SIMULATOR" else {
            throw XCTSkip("Explicit dedicated empty guest simulator authorization is absent")
        }
        guard ProcessInfo.processInfo.arguments.contains("-v50.inMemoryStore") else {
            XCTFail("Host must use in-memory container before launch; abort to avoid two writers")
            return
        }
        let expectedRelativePath = try XCTUnwrap(env["QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH"])
        let expectedOwner = try XCTUnwrap(env["QD_EXPECTED_GUEST_OWNER"])
        let expectedDay = try XCTUnwrap(env["QD_EXPECTED_LOCAL_DAY"])
        let manifestRelativePath = "Documents/qd-thousand-manifest.json"
        let schema = ModelContainerFactory.currentSchema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let storeURL = config.url.standardizedFileURL
        let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().standardizedFileURL
        let resolvedStore = storeURL.resolvingSymlinksInPath().standardizedFileURL
        let manifestURL = home.appendingPathComponent(manifestRelativePath).resolvingSymlinksInPath().standardizedFileURL
        let components = expectedRelativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !expectedRelativePath.hasPrefix("/"), !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != ".." && $0 != "." }),
              resolvedStore.path.hasPrefix(home.path + "/"),
              String(resolvedStore.path.dropFirst(home.path.count + 1)) == expectedRelativePath,
              manifestURL.path.hasPrefix(home.path + "/"),
              Bundle.main.bundleIdentifier == "com.xinkuan.qiuji",
              expectedOwner.hasPrefix("guest:"),
              let guestID = UserDefaults.standard.string(forKey: DeviceGuestIdentity.defaultsKey),
              expectedOwner == "guest:" + guestID,
              CurrentOwnerContext.shared.ownerKey == expectedOwner else {
            XCTFail("Exact app sandbox path or existing guest identity mismatch; no write")
            return
        }
        let fm = FileManager.default
        guard !fm.fileExists(atPath: storeURL.path),
              !fm.fileExists(atPath: storeURL.path + "-wal"),
              !fm.fileExists(atPath: storeURL.path + "-shm"),
              !fm.fileExists(atPath: manifestURL.path) else {
            XCTFail("Store sidecar/manifest already exists or manifest is outside app sandbox; never overwrite")
            return
        }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.calendar = Calendar.current
        format.timeZone = TimeZone.current
        format.dateFormat = "yyyy-MM-dd"
        let start = Date()
        guard format.string(from: start) == expectedDay else {
            XCTFail("Declared local day mismatch; no write")
            return
        }
        let container = try ModelContainer(for: schema, migrationPlan: QiuJiMigrationPlan.self, configurations: config)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let today = Calendar.current.startOfDay(for: start)
        for index in 0..<1000 {
            let session = TrainingSession(kind: "drill", ownerKey: expectedOwner)
            session.date = today.addingTimeInterval(Double(index) / 1000)
            session.totalDurationMinutes = 2
            session.note = "QD-1000-\(index)"
            let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "半台直线球")
            entry.sets = [DrillSet(setNumber: 1, targetBalls: 10, madeBalls: 8, unitLabel: "球")]
            session.drillEntries = [entry]
            context.insert(session)
        }
        try context.save()
        guard try context.fetchCount(FetchDescriptor<TrainingSession>()) == 1000,
              try context.fetchCount(FetchDescriptor<DrillEntry>()) == 1000,
              try context.fetchCount(FetchDescriptor<DrillSet>()) == 1000,
              try context.fetchCount(FetchDescriptor<SyncPendingItem>()) == 0,
              try context.fetch(FetchDescriptor<TrainingSession>()).allSatisfy({ $0.ownerKey == expectedOwner }),
              format.string(from: Date()) == expectedDay else {
            XCTFail("Saved fixture count/owner/queue/day invalid; no valid manifest emitted")
            return
        }
        let manifest: [String: Any] = [
            "storePath": storeURL.path, "owner": expectedOwner, "localDay": expectedDay,
            "storeRelativePath": expectedRelativePath, "home": home.path,
            "bundleID": Bundle.main.bundleIdentifier ?? "", "pendingSyncCount": 0,
            "sessionCount": 1000, "entryCount": 1000, "setCount": 1000,
            "trainingDays": 1, "durationMinutes": 2000, "made": 8000, "target": 10000,
            "scope": "Synthetic drill-only stress fixture; not plausible wall-clock workload or mixed-kind acceptance"
        ]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: manifestURL, options: .withoutOverwriting)
        // Parent must terminate host and read normally in a new process. Do not copy live sqlite sidecars.
    }
}
