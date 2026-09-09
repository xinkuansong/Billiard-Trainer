import XCTest
import SwiftData
@testable import QiuJi

/// Read-only method; App startup itself initializes its normal guest defaults.
/// Fresh dedicated simulator with no real credentials is an external prerequisite.
/// This probe never reads/prints Keychain contents and does not prove their absence.
@MainActor
final class ThousandStoreProbeTests: XCTestCase {
    func testReportInMemoryHostAndEmptyDefaultStore() throws {
        let info = ProcessInfo.processInfo
        let authorization = info.environment["QD_PROBE_ENVIRONMENT"] ?? info.environment["TEST_RUNNER_QD_PROBE_ENVIRONMENT"]
        guard authorization == "DEDICATED_EMPTY_GUEST_SIMULATOR" else {
            XCTFail("Dedicated empty guest environment must be established before host launch")
            throw NSError(domain: "QDProbePrecondition", code: 1)
        }
        let args = info.arguments
        let hasMemoryFlag = args.contains("-v50.inMemoryStore")
        let prohibited = args.filter {
            $0.hasPrefix("-v") && $0 != "-v50.inMemoryStore" || $0.hasPrefix("-deeplink")
        }
        let config = ModelConfiguration(schema: ModelContainerFactory.currentSchema, isStoredInMemoryOnly: false)
        let url = config.url.standardizedFileURL
        let existingGuest = UserDefaults.standard.string(forKey: DeviceGuestIdentity.defaultsKey)
        let owner = CurrentOwnerContext.shared.ownerKey
        let storeExists = FileManager.default.fileExists(atPath: url.path)
        let walExists = FileManager.default.fileExists(atPath: url.path + "-wal")
        let shmExists = FileManager.default.fileExists(atPath: url.path + "-shm")
        // Report only selected argument facts: no full environment/arguments/token dump.
        let report: [String: Any] = [
            "inMemoryArgumentPresent": hasMemoryFlag, "prohibitedArgumentNames": prohibited,
            "bundleID": Bundle.main.bundleIdentifier ?? "", "home": NSHomeDirectory(),
            "executable": Bundle.main.executableURL?.lastPathComponent ?? "",
            "defaultStorePath": url.path, "guestOwner": owner,
            "defaultStoreRelativePath": String(url.path.dropFirst(NSHomeDirectory().count + 1)),
            "guestDefaultsPresent": existingGuest != nil,
            "storeExists": storeExists, "walExists": walExists, "shmExists": shmExists,
            "credentialBoundary": "External dedicated-device condition; Keychain not inspected"
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "thousand-store-preflight"; attachment.lifetime = .keepAlways; add(attachment)
        print(String(decoding: data, as: UTF8.self))
        XCTAssertTrue(hasMemoryFlag, "Host must receive flag BEFORE App initialization")
        XCTAssertTrue(prohibited.isEmpty)
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.xinkuan.qiuji")
        XCTAssertTrue(url.path.hasPrefix(NSHomeDirectory() + "/"))
        let guest = try XCTUnwrap(existingGuest)
        XCTAssertFalse(guest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertEqual(owner, "guest:" + guest)
        XCTAssertFalse(storeExists); XCTAssertFalse(walExists); XCTAssertFalse(shmExists)
    }
}
