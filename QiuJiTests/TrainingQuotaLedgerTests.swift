import XCTest
@testable import QiuJi

final class TrainingQuotaLedgerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() {
        suite = "TrainingQuotaTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
    }
    override func tearDown() { defaults.removePersistentDomain(forName: suite) }
    private func ledger(_ namespace: String = "accuracy2D", date: @escaping () -> Date = { Date(timeIntervalSince1970: 1_800_000_000) }) -> TrainingQuotaLedger {
        TrainingQuotaLedger(namespace: namespace, defaults: defaults, now: date,
            calendar: { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c })
    }
    func testLastSlotIsSharedAcrossInstancesAndCancellationReleasesIt() throws {
        let a = ledger(), b = ledger(), q = UUID(), other = UUID()
        XCTAssertTrue(try a.reserve(q, limit: 1, premium: false))
        XCTAssertFalse(try b.reserve(other, limit: 1, premium: false))
        XCTAssertEqual(try b.used(), 0, "Reservations are not completed questions")
        try a.release(q)
        XCTAssertTrue(try b.reserve(other, limit: 1, premium: false))
    }
    func testReplacingUnansweredQuestionTransfersLastReservation() throws {
        let value = ledger(), old = UUID(), next = UUID(), other = UUID()
        XCTAssertTrue(try value.reserve(old, limit: 1, premium: false))
        XCTAssertTrue(try value.reserve(next, limit: 1, premium: false, replacing: old))
        XCTAssertFalse(try value.reserve(other, limit: 1, premium: false))
        try value.release(next)
        XCTAssertTrue(try value.reserve(old, limit: 1, premium: false))
        XCTAssertEqual(try value.used(), 0)
    }
    func testReceiptSurvivesRecreationAndCannotCountTwice() throws {
        let q = UUID(), date = Date(timeIntervalSince1970: 1_800_000_000)
        let receipt = TrainingConsumptionReceipt(questionID: q, acceptedAt: date, charged: true)
        try ledger().accept(receipt); try ledger().accept(receipt)
        XCTAssertEqual(try ledger().used(), 1)
        XCTAssertEqual(try ledger("scene2D").used(), 0)
    }
    func testPremiumReceiptDoesNotConsumeOrEraseFreeUse() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000), value = ledger()
        try value.accept(.init(questionID: UUID(), acceptedAt: date, charged: true))
        let pro = TrainingConsumptionReceipt(questionID: UUID(), acceptedAt: date, charged: false)
        try value.accept(pro); try ledger().accept(pro)
        XCTAssertEqual(try ledger().used(), 1)
    }
    func testMidnightRecoveryKeepsOriginalConsumptionDay() throws {
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        let value = ledger(date: { date })
        let receipt = TrainingConsumptionReceipt(questionID: UUID(), acceptedAt: date, charged: true)
        try value.accept(receipt); date += 86400; try value.accept(receipt)
        XCTAssertEqual(try value.used(), 0)
        try value.accept(.init(questionID: UUID(), acceptedAt: date, charged: true))
        XCTAssertEqual(try value.used(), 1)
    }
    func testLegacyCountAndIDsAreUnionAndOverLimitIsPreserved() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"
        let day = f.string(from: date), id = UUID()
        defaults.set(day, forKey: "sceneTraining.usage.accuracy2D.day")
        defaults.set(18, forKey: "sceneTraining.usage.accuracy2D.count")
        defaults.set(["day": day, "ids": [id.uuidString]], forKey: "sceneTraining.usage.accuracy2D.ledger")
        let value = ledger()
        XCTAssertEqual(try value.used(), 18)
        XCTAssertFalse(try value.reserve(UUID(), limit: 15, premium: false))
        try value.accept(.init(questionID: id, acceptedAt: date, charged: true))
        XCTAssertEqual(try value.used(), 18)
        XCTAssertEqual(defaults.integer(forKey: "sceneTraining.usage.accuracy2D.count"), 18)
    }
    func testAtomicFileRecoveryAndCorruptionFailClosed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("quota.json"), date = Date()
        func store() -> TrainingQuotaLedger {
            .init(namespace: "accuracy2D", defaults: defaults, now: { date }, calendar: { .current }, fileURL: url)
        }
        let receipt = TrainingConsumptionReceipt(questionID: UUID(), acceptedAt: date, charged: true)
        try store().accept(receipt); try store().accept(receipt)
        XCTAssertEqual(try store().used(), 1)
        try Data("broken".utf8).write(to: url, options: .atomic)
        XCTAssertThrowsError(try store().reserve(UUID(), limit: 15, premium: false))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "broken")
    }
    func testMixedObservationAndSubmissionRemainFrozen() throws {
        let q = UUID(); var value = TrainingPresentation(is3D: false)
        value.observe(.twoD, questionID: q); value.current = .threeD
        value.observe(.threeD, questionID: q); value.accept(questionID: q, at: Date(), premium: false)
        value.current = .twoD; value.accept(questionID: q, at: Date(), premium: true)
        let restored = try JSONDecoder().decode(TrainingPresentation.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored.label(for: q), "混合视图")
        XCTAssertEqual(restored.submitted[q], .threeD)
        XCTAssertEqual(restored.receipts[q]?.charged, true)
    }
}
