import XCTest
import SwiftData
@testable import QiuJi

/// Uncompiled diagnostic draft. Fixed ledger: 2026-09-06, Asia/Shanghai.
/// Dedicated empty guest installation only. Never register/run automatically.
@MainActor
final class Data1DiskFixtureTests: XCTestCase {
    private func require(_ condition: Bool, _ message: String) throws {
        guard condition else {
            XCTFail(message)
            throw NSError(domain: "Data1FixturePrecondition", code: 1)
        }
    }

    func testSeedSevenSessionLedgerIntoDedicatedEmptyDefaultStore() throws {
        let env = ProcessInfo.processInfo.environment
        try require(env["QD_ALLOW_DATA1_DISK_SEED"] == "DEDICATED_EMPTY_GUEST_SIMULATOR", "Explicit DATA1 authorization missing")
        let args = ProcessInfo.processInfo.arguments
        try require(args.contains("-v50.inMemoryStore"), "Host must start in memory BEFORE App initialization")
        try require(!args.contains(where: { $0.hasPrefix("-deeplink") || ($0.hasPrefix("-v") && $0 != "-v50.inMemoryStore") }), "Other fixture arguments prohibited")
        try require(Bundle.main.bundleIdentifier == "com.xinkuan.qiuji", "Wrong host")
        let owner = try XCTUnwrap(env["QD_EXPECTED_GUEST_OWNER"])
        let guest = try XCTUnwrap(UserDefaults.standard.string(forKey: DeviceGuestIdentity.defaultsKey))
        try require(!guest.isEmpty && owner == "guest:" + guest && CurrentOwnerContext.shared.ownerKey == owner, "Guest changed")
        let expectedRelativePath = try XCTUnwrap(env["QD_EXPECTED_DEFAULT_STORE_RELATIVE_PATH"])
        let manifestRelativePath = "Documents/qd-data1-manifest.json"
        let schema = ModelContainerFactory.currentSchema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let url = config.url.standardizedFileURL
        let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path
        let resolvedStore = url.resolvingSymlinksInPath().standardizedFileURL
        let manifestURL = URL(fileURLWithPath: home).appendingPathComponent(manifestRelativePath).resolvingSymlinksInPath().standardizedFileURL
        let parts = expectedRelativePath.split(separator: "/", omittingEmptySubsequences: false)
        try require(!expectedRelativePath.hasPrefix("/") && !parts.isEmpty && parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }, "Invalid relative path")
        try require(resolvedStore.path.hasPrefix(home + "/") && String(resolvedStore.path.dropFirst(home.count + 1)) == expectedRelativePath && manifestURL.path.hasPrefix(home + "/"), "Default relative path/sandbox mismatch")
        let manifestPath = manifestURL.path
        let fm = FileManager.default
        for path in [url.path, url.path + "-wal", url.path + "-shm", manifestPath] {
            try require(!fm.fileExists(atPath: path), "Refusing existing store/sidecar/manifest")
        }
        try require(TimeZone.current.identifier == "Asia/Shanghai", "Ledger timezone mismatch")
        try require(Calendar.current.identifier == .gregorian, "App calendar must match this Gregorian ledger")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let formatter = DateFormatter()
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        try require(formatter.string(from: Date()) == "2026-09-06", "Fixed ledger expired: prepare a NEW independently calculated ledger; do not change system clock")
        func date(_ month: Int, _ day: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 0, minute: minute))!
        }
        try require(Date() >= date(9, 6, 3), "Ledger must contain no future sessions")
        let container = try ModelContainer(for: schema, migrationPlan: QiuJiMigrationPlan.self, configurations: config)
        let context = ModelContext(container); context.autosaveEnabled = false
        func entry(_ made: Int, _ target: Int, _ unit: String = "球", _ order: Int = 0) -> DrillEntry {
            let e = DrillEntry(drillId: "drill_c001", drillNameZh: "半台直线球")
            e.orderIndex = order
            e.sets = [DrillSet(setNumber: 1, targetBalls: target, madeBalls: made, unitLabel: unit)]
            return e
        }
        func row(_ id: String, _ kind: String, _ when: Date, _ minutes: Int, _ entries: [DrillEntry] = []) -> TrainingSession {
            let s = TrainingSession(kind: kind, ownerKey: owner)
            s.date = when; s.totalDurationMinutes = minutes
            s.note = "QD-DATA1-" + id; s.drillEntries = entries
            context.insert(s); return s
        }
        _ = row("A", "drill", date(9, 6, 1), 20, [entry(8, 10), entry(2, 5, "球", 1)])
        _ = row("B", "drill", date(9, 6, 2), 30, [entry(1, 2, "局")])
        let cognitive = row("C", "cognitive", date(9, 5), 5)
        let answer = AngleTestResult(actualAngle: 45, userAngle: 40, pocketType: "corner", quizType: "geometric", sessionId: cognitive.id, ownerKey: owner)
        answer.date = date(9, 5, 1); context.insert(answer)
        _ = row("D", "tool", date(9, 6, 3), 99)
        _ = row("E", "drill", date(8, 31), 10, [entry(3, 10)])
        _ = row("F", "drill", date(8, 30), 40, [entry(4, 10)])
        _ = row("G", "drill", date(8, 5), 80, [entry(6, 10)])
        try context.save()
        let rows = try context.fetch(FetchDescriptor<TrainingSession>())
        try require(rows.count == 7 && rows.allSatisfy { $0.ownerKey == owner }, "Persisted session count/owner mismatch")
        try require(Set(rows.map(\.note)) == Set(["A","B","C","D","E","F","G"].map { "QD-DATA1-" + $0 }), "Ledger identity mismatch")
        try require(try context.fetchCount(FetchDescriptor<DrillEntry>()) == 6, "Entry count mismatch")
        try require(try context.fetchCount(FetchDescriptor<DrillSet>()) == 6, "Set count mismatch")
        let answers = try context.fetch(FetchDescriptor<AngleTestResult>())
        try require(answers.count == 1 && answers[0].ownerKey == owner && answers[0].sessionId == cognitive.id, "Cognitive relationship mismatch")
        try require(try context.fetchCount(FetchDescriptor<SyncPendingItem>()) == 0, "Unexpected sync queue")
        try require(formatter.string(from: Date()) == "2026-09-06", "Midnight crossed: invalid fixture")
        let manifest: [String: Any] = [
            "fixture": "DATA1-20260906-v1", "localDay": "2026-09-06", "timezone": "Asia/Shanghai",
            "storePath": url.path, "storeRelativePath": expectedRelativePath, "home": home,
            "bundleID": Bundle.main.bundleIdentifier ?? "", "pendingSyncCount": 0,
            "manifestRelativePath": manifestRelativePath, "owner": owner, "sessionCount": 7, "entryCount": 6,
            "setCount": 6, "answerCount": 1,
            "rows": rows.sorted { $0.note < $1.note }.map { s -> [String: Any] in
                ["id": s.id.uuidString, "note": s.note, "kind": s.kind,
                 "date": ISO8601DateFormatter().string(from: s.date), "minutes": s.totalDurationMinutes,
                 "entries": s.drillEntries.map { e -> [String: Any] in
                     ["drillId": e.drillId, "order": e.orderIndex,
                      "sets": e.sets.map { ["made": $0.madeBalls, "target": $0.targetBalls, "unit": $0.unitLabel] as [String: Any] }]
                 }]
            }
        ]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: manifestURL, options: .withoutOverwriting)
        // Parent verifies raw rows against the literal ledger before normal disk UI launch.
        // No business metric/helper is called to generate expected UI values.
    }
}
