import XCTest
import UserNotifications
@testable import QiuJi

/// Hosted in this App on one explicitly dedicated notification simulator.
/// Reads only: never requests authorization, schedules, cancels, or edits defaults.
@MainActor
final class NotificationPendingDiagnosticTests: XCTestCase {
    func testObserveActualAuthorizationAndDailyPendingRequest() async throws {
        let env = ProcessInfo.processInfo.environment
        func value(_ key: String) -> String? { env[key] ?? env["TEST_RUNNER_" + key] }
        guard value("QD_NOTIFICATION_ENVIRONMENT") == "DEDICATED_GUEST_SIMULATOR" else {
            throw XCTSkip("Dedicated notification simulator required")
        }
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.xinkuan.qiuji")
        XCTAssertTrue(CurrentOwnerContext.shared.ownerKey.hasPrefix("guest:"))
        let expectedStatus = try XCTUnwrap(value("QD_EXPECTED_NOTIFICATION_STATUS"))
        XCTAssertTrue(["notDetermined", "authorized", "denied"].contains(expectedStatus))
        let expectedCount = try XCTUnwrap(value("QD_EXPECTED_NOTIFICATION_COUNT").flatMap(Int.init))
        XCTAssertTrue([0, 1].contains(expectedCount))
        let enabledString = try XCTUnwrap(value("QD_EXPECTED_REMINDER_ENABLED"))
        XCTAssertTrue(["true", "false"].contains(enabledString))

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let status: String
        switch settings.authorizationStatus {
        case .notDetermined: status = "notDetermined"
        case .authorized: status = "authorized"
        case .denied: status = "denied"
        case .provisional: status = "provisional"
        case .ephemeral: status = "ephemeral"
        @unknown default: status = "unknown"
        }
        let requests = await center.pendingNotificationRequests()
        let own = requests.filter { $0.identifier == "qiuji.training.daily-reminder" }
        let enabled = UserDefaults.standard.bool(forKey: "reminderEnabled")
        var report: [String: Any] = [
            "status": status, "dailyRequestCount": own.count,
            "otherPendingCount": requests.count - own.count, "reminderEnabled": enabled,
            "boundary": "Real OS pending requests; does not prove eventual delivery or sound"
        ]
        if let request = own.first {
            report["identifier"] = request.identifier
            report["title"] = request.content.title
            report["body"] = request.content.body
            report["hasSound"] = request.content.sound != nil
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                report["hour"] = trigger.dateComponents.hour
                report["minute"] = trigger.dateComponents.minute
                report["repeats"] = trigger.repeats
                report["explicitTimezone"] = trigger.dateComponents.timeZone?.identifier ?? "nil"
            }
        }
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "notification-pending-observation"; attachment.lifetime = .keepAlways; add(attachment)
        print(String(decoding: data, as: UTF8.self))

        XCTAssertEqual(status, expectedStatus)
        XCTAssertEqual(own.count, expectedCount)
        XCTAssertEqual(enabled, enabledString == "true")
        XCTAssertEqual(requests.count, own.count, "Unexpected unrelated pending requests on dedicated device")
        if expectedCount == 1 {
            let request = try XCTUnwrap(own.first)
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            let hour = try XCTUnwrap(value("QD_EXPECTED_REMINDER_HOUR").flatMap(Int.init))
            let minute = try XCTUnwrap(value("QD_EXPECTED_REMINDER_MINUTE").flatMap(Int.init))
            XCTAssertTrue((0..<24).contains(hour)); XCTAssertTrue((0..<60).contains(minute))
            XCTAssertEqual(trigger.dateComponents.hour, hour)
            XCTAssertEqual(trigger.dateComponents.minute, minute)
            XCTAssertTrue(trigger.repeats)
            XCTAssertEqual(request.content.title, "今天练一会儿球吧")
            XCTAssertEqual(request.content.body, "打开球迹，继续完成你的每周训练目标。")
            XCTAssertNotNil(request.content.sound)
            XCTAssertNil(trigger.dateComponents.timeZone)
        }
    }
}
