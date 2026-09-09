import XCTest
import SwiftData
@testable import QiuJi

/// Unregistered diagnostic source. No OS notification scheduling or system-clock changes.
@MainActor
final class CalendarBoundaryDiagnosticTests: XCTestCase {
    private func require(_ condition: Bool, _ message: String) throws {
        guard condition else {
            XCTFail(message)
            throw NSError(domain: "QDCalendarBoundary", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    private func instant(_ iso: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: iso), "Invalid literal UTC fixture")
    }

    private func evidence(_ name: String, _ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testReminderUsesInjectedCalendarHourMinuteAcrossTimeZonesAndDST() async throws {
        let center = CalendarRecordingReminderCenter()
        let scheduler = TrainingReminderScheduler(center: center)
        let cases: [(zone: String, utc: String, hour: Int, minute: Int)] = [
            ("America/Los_Angeles", "2026-03-08T09:30:00Z", 1, 30),
            ("America/Los_Angeles", "2026-03-08T10:30:00Z", 3, 30),
            ("Asia/Shanghai", "2026-03-08T09:30:00Z", 17, 30),
            ("Asia/Shanghai", "2026-03-08T10:30:00Z", 18, 30),
        ]
        for (index, item) in cases.enumerated() {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: item.zone))
            let result = await scheduler.enable(at: try instant(item.utc), calendar: calendar)
            try evidence("reminder-calendar-\(index)", [
                "zone": item.zone, "utc": item.utc, "expectedHour": item.hour,
                "expectedMinute": item.minute, "result": String(describing: result),
                "calls": center.calls.map { ["hour": $0.hour, "minute": $0.minute] },
                "authorizationChecks": center.authorizationChecks,
                "authorizationRequests": center.authorizationRequests,
                "cancelCount": center.cancelCount,
            ])
            try require(result == .scheduled, "Allowed injected scheduler failed")
            try require(center.calls.count == index + 1, "Each enable must schedule exactly once")
            let actual = center.calls[index]
            try require(actual.hour == item.hour && actual.minute == item.minute,
                        "Wrong exact wall-clock components for \(item.zone) / \(item.utc)")
            try require(center.authorizationChecks == index + 1 && center.authorizationRequests == 0,
                        "Already allowed center should be checked without requesting OS permission")
            try require(center.cancelCount == 0, "Enable unexpectedly called disable")
        }
    }

    func testTodayScheduleArchivesAcrossDSTLocalMidnightWithoutAutoCarry() throws {
        // Retain the complete current V5 container throughout the test, including readback.
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let owner = "guest:qd-calendar-dst"
        let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let first = try instant("2026-03-08T08:30:00Z") // Mar 8 00:30 PST
        let second = try instant("2026-03-09T07:30:00Z") // Mar 9 00:30 PDT
        try require(second.timeIntervalSince(first) == 82_800, "Fixture must cross a 23-hour local day")
        var local = Calendar(identifier: .gregorian); local.timeZone = zone
        for (date, day) in [(first, 8), (second, 9)] {
            let c = local.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            try require(c.year == 2026 && c.month == 3 && c.day == day && c.hour == 0 && c.minute == 30,
                        "Literal fixture does not map to expected local midnight boundary")
        }
        var clock = first
        let service = TodayTrainingScheduleService(context: context, now: { clock }, timeZone: zone)
        let added = try service.addLibraryDrill(id: "drill_c010", title: "定杆", ownerKey: owner)
        let item: TodayScheduleItem
        switch added {
        case .added(let value): item = value
        case .alreadyPresent:
            XCTFail("Empty isolated store unexpectedly contained this item")
            throw NSError(domain: "QDCalendarBoundary", code: 2)
        }
        let yesterday = try XCTUnwrap(item.schedule)
        let originalID = yesterday.id, itemID = item.id, payload = item.payloadSnapshot
        try require(yesterday.localDayKey == "2026-03-08" && yesterday.ownerKey == owner,
                    "First schedule has wrong literal local day or owner")
        try require(yesterday.timeZoneIdentifier == "America/Los_Angeles" && yesterday.calendarIdentifier == "gregorian",
                    "Schedule metadata differs from injected calendar")
        try require(yesterday.archivedAt == nil && yesterday.items.count == 1 && item.state == TodayScheduleItemState.pending,
                    "Initial pending schedule prerequisite failed")
        try context.save()
        clock = second
        let today = try XCTUnwrap(try service.today(ownerKey: owner))
        try evidence("dst-first-rollover", [
            "oldID": originalID.uuidString, "newID": today.id.uuidString,
            "oldDay": yesterday.localDayKey, "newDay": today.localDayKey,
            "oldArchivedAt": yesterday.archivedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "nil",
            "newItemCount": today.items.count, "oldItemState": item.state,
        ])
        try require(today.localDayKey == "2026-03-09" && today.ownerKey == owner && today.id != originalID,
                    "DST rollover did not create correct new local-day schedule")
        try require(yesterday.archivedAt == second && today.archivedAt == nil,
                    "Archive must occur exactly at injected rollover time")
        try require(today.items.isEmpty, "Unfinished item was auto-carried")
        try require(item.id == itemID && item.schedule?.id == originalID && item.state == TodayScheduleItemState.pending && item.payloadSnapshot == payload,
                    "Rollover changed old pending item identity, ownership or payload")
        let repeated = try XCTUnwrap(try service.today(ownerKey: owner))
        try require(repeated.id == today.id && repeated.items.isEmpty && yesterday.archivedAt == second,
                    "Repeated same-day lookup duplicated schedule or rewrote archival state")
        try context.save()
        let readback = ModelContext(container)
        let schedules = try readback.fetch(FetchDescriptor<TodayTrainingSchedule>())
        let items = try readback.fetch(FetchDescriptor<TodayScheduleItem>())
        try evidence("dst-persisted-readback", [
            "schedules": schedules.map { ["id": $0.id.uuidString, "day": $0.localDayKey, "owner": $0.ownerKey, "items": $0.items.count] as [String: Any] },
            "itemCount": items.count,
        ])
        try require(schedules.count == 2 && schedules.allSatisfy { $0.ownerKey == owner }, "Expected exactly two owner-scoped schedules")
        try require(Set(schedules.map(\.id)) == Set([originalID, today.id]), "Persisted schedule identities changed")
        try require(items.count == 1, "Pending item was duplicated or lost")
        let persisted = items[0]
        try require(persisted.id == itemID && persisted.schedule?.id == originalID && persisted.state == TodayScheduleItemState.pending && persisted.payloadSnapshot == payload,
                    "Independent context readback lost original pending payload")
        let old = try XCTUnwrap(schedules.first { $0.id == originalID })
        let new = try XCTUnwrap(schedules.first { $0.id == today.id })
        try require(old.archivedAt == second && old.localDayKey == "2026-03-08" && new.archivedAt == nil && new.localDayKey == "2026-03-09" && new.items.isEmpty,
                    "Persisted rollover state differs from literal contract")
    }
}

@MainActor
private final class CalendarRecordingReminderCenter: TrainingReminderCenter {
    struct Call { let hour: Int; let minute: Int }
    private(set) var calls: [Call] = []
    private(set) var authorizationChecks = 0
    private(set) var authorizationRequests = 0
    private(set) var cancelCount = 0
    func authorization() async -> TrainingReminderAuthorization {
        authorizationChecks += 1; return .allowed
    }
    func requestAuthorization() async throws -> Bool {
        authorizationRequests += 1; return false
    }
    func schedule(hour: Int, minute: Int) async throws { calls.append(Call(hour: hour, minute: minute)) }
    func cancel() { cancelCount += 1 }
}
