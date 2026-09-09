import Foundation
import XCTest
@testable import QiuJi

/// Unregistered serial hosted diagnostic. Process timezone only, never OS/Simulator clock.
/// This is a running-process local-date/timezone transition, NOT a waited midnight test.
@MainActor
final class QuotaDayBoundaryDiagnosticTests: XCTestCase {
    private struct Stop: Error { let message: String }

    func testLiveFullQuotaMatchesNewInstanceAfterProcessLocalDayChanges() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        func setting(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        try require(setting("QD_QUOTA_DAY_AUTH") == "NEW_EMPTY_MEMORY_HOST_PROCESS_TIMEZONE", "Explicit process-timezone diagnostic authorization required")
        guard let expected = setting("QD_QUOTA_DAY_DEVICE_UDID"), UUID(uuidString: expected) != nil,
              env["SIMULATOR_UDID"]?.lowercased() == expected.lowercased() else {
            throw Stop(message: "Dedicated runner UDID mismatch")
        }
        let args = ProcessInfo.processInfo.arguments
        try require(args.contains("-v50.inMemoryStore"), "Fresh host must use memory schema before App initialization")
        for forbidden in ["-v53.authenticatedProfileFixture", "-forcePremium", "-forceNonPremium",
                          "-w7.forceDailyLimit", "-w7.forceDailyLimitNear"] {
            try require(!args.contains(forbidden), "Disallowed shared identity/quota/Pro override: \(forbidden)")
        }
        try require(CurrentOwnerContext.shared.ownerKey == CurrentOwnerContext.shared.guestOwnerKey, "Host must remain guest")
        guard let path = setting("QD_SHOT_DIR"), path.hasPrefix("/"), path != "/" else {
            throw Stop(message: "Fresh absolute output leaf required")
        }
        let output = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try require(try FileManager.default.contentsOfDirectory(atPath: path).isEmpty, "Refuse existing evidence")
        let suite = "QD.QuotaDay." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let originalZone = NSTimeZone.default
        let west = try XCTUnwrap(TimeZone(secondsFromGMT: -12 * 3600))
        let east = try XCTUnwrap(TimeZone(secondsFromGMT: 14 * 3600))
        var live: AngleUsageLimiter?
        var fresh: AngleUsageLimiter?
        var phase = "initial"
        var oldDay = ""
        var newDay = ""
        var observations: [[String: Any]] = []
        var failure: Error?
        // Always restore even if writing restored evidence itself fails. Never touch .standard.
        defer {
            NSTimeZone.default = originalZone
            defaults.removePersistentDomain(forName: suite)
        }

        func dateFacts() -> [String: Any] {
            let instant = Date()
            let implicit = DateFormatter() // Deliberately mirrors production's fresh formatter.
            implicit.dateFormat = "yyyy-MM-dd"
            let explicit = DateFormatter()
            explicit.locale = Locale(identifier: "en_US_POSIX")
            explicit.calendar = Calendar(identifier: .gregorian)
            explicit.timeZone = NSTimeZone.default
            explicit.dateFormat = "yyyy-MM-dd"
            return ["epoch": instant.timeIntervalSince1970,
                    "processTimeZone": NSTimeZone.default.identifier,
                    "processOffset": NSTimeZone.default.secondsFromGMT(for: instant),
                    "formatterTimeZone": implicit.timeZone.identifier,
                    "formatterOffset": implicit.timeZone.secondsFromGMT(for: instant),
                    "localDay": implicit.string(from: instant), "explicitLocalDay": explicit.string(from: instant)]
        }
        func limiterFacts(_ limiter: AngleUsageLimiter?) -> [String: Any] {
            guard let limiter else { return ["constructed": false] }
            return ["constructed": true, "used": limiter.questionsUsedToday, "remaining": limiter.remainingToday,
                    "limitReached": limiter.isLimitReached, "premium": limiter.isPremium]
        }
        func capture(_ filename: String) throws {
            observations.append(["phase": phase, "uptime": ProcessInfo.processInfo.systemUptime,
                                 "date": dateFacts(), "live": limiterFacts(live), "fresh": limiterFacts(fresh),
                                 "savedDate": defaults.string(forKey: PracticeStorageKey.angleUsageDate) ?? "absent",
                                 "savedCount": defaults.object(forKey: PracticeStorageKey.angleUsageCount) ?? NSNull()])
            let record: [String: Any] = ["suite": suite, "device": expected,
                "scope": "Temporary process timezone/local-date change; not actual midnight, OS clock change or UI refresh proof",
                "originalTimeZone": originalZone.identifier, "oldDay": oldDay, "newDay": newDay,
                "failure": failure.map { String(describing: $0) } as Any? ?? NSNull(), "observations": observations]
            try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent(filename), options: .withoutOverwriting)
        }
        func requireAdoptedZone(_ offset: Int) throws -> String {
            let facts = dateFacts()
            try require(facts["processOffset"] as? Int == offset && facts["formatterOffset"] as? Int == offset,
                        "PRECONDITION: fresh DateFormatter did not adopt temporary timezone; no product verdict")
            let actual = try XCTUnwrap(facts["localDay"] as? String)
            try require(actual == facts["explicitLocalDay"] as? String,
                        "PRECONDITION: implicit day disagrees with independent Gregorian/POSIX oracle")
            return actual
        }
        do {
            try capture("01-original-process-state.json")
            NSTimeZone.default = west
            phase = "UTC-minus12-fill20"
            oldDay = try requireAdoptedZone(-12 * 3600)
            let instance = AngleUsageLimiter(defaults: defaults)
            live = instance
            try require(instance.questionsUsedToday == 0 && instance.remainingToday == 20 && !instance.isLimitReached && !instance.isPremium,
                        "Fresh free quota prerequisite invalid")
            for _ in 0..<20 { instance.recordQuestion() }
            try capture("02-west-full20.json")
            try require(try requireAdoptedZone(-12 * 3600) == oldDay, "PRECONDITION: old local day changed while filling")
            try require(instance.questionsUsedToday == 20 && instance.remainingToday == 0 && instance.isLimitReached,
                        "Normal 20 recordQuestion calls did not exhaust quota")
            try require(defaults.string(forKey: PracticeStorageKey.angleUsageDate) == oldDay &&
                        defaults.integer(forKey: PracticeStorageKey.angleUsageCount) == 20, "Persisted full quota prerequisite invalid")

            NSTimeZone.default = east
            phase = "UTC-plus14-live-before-any-new-instance"
            newDay = try requireAdoptedZone(14 * 3600)
            try require(newDay != oldDay, "PRECONDITION: actual local-day strings did not change")
            // Capture live getters BEFORE fresh init resets the shared isolated defaults.
            let liveRemainingBeforeFresh = instance.remainingToday
            let liveReachedBeforeFresh = instance.isLimitReached
            try capture("03-east-live-before-recreation.json")

            phase = "UTC-plus14-new-instance-comparison"
            let rebuilt = AngleUsageLimiter(defaults: defaults)
            fresh = rebuilt
            try capture("04-east-live-versus-new.json")
            try require(try requireAdoptedZone(14 * 3600) == newDay, "PRECONDITION: new local day changed during comparison")
            try require(rebuilt.questionsUsedToday == 0 && rebuilt.remainingToday == 20 && !rebuilt.isLimitReached,
                        "New-instance current-day reset control failed")
            try require(defaults.string(forKey: PracticeStorageKey.angleUsageDate) == newDay &&
                        defaults.integer(forKey: PracticeStorageKey.angleUsageCount) == 0, "New-instance reset did not persist current day")
            try require(liveRemainingBeforeFresh == 20 && !liveReachedBeforeFresh &&
                        instance.remainingToday == rebuilt.remainingToday && instance.isLimitReached == rebuilt.isLimitReached,
                        "Live full quota did not renew when process local day changed; new instance did")
        } catch { failure = error }

        // Restoration and its evidence happen BEFORE rethrowing any product/prerequisite failure.
        NSTimeZone.default = originalZone
        phase = "restored-original-process-timezone"
        try capture("05-restored-process-state.json")
        try require(NSTimeZone.default == originalZone, "Process default timezone restoration failed")
        if let failure { throw failure }
    }

    private func require(_ condition: Bool, _ message: String,
                         file: StaticString = #filePath, line: UInt = #line) throws {
        guard condition else { throw Stop(message: message) }
    }
}
