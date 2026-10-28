import Foundation

/// One serialized, atomic document per project. The durable business payload is
/// the recovery source if a process stops between saving a result and accounting.
final class TrainingQuotaLedger {
    private struct Reservation: Codable {
        let process: UUID
        let day: String
    }
    private struct Archive: Codable {
        var version = 1
        var counts: [String: Int] = [:]
        var seen: Set<UUID> = []
        var reservations: [UUID: Reservation] = [:]
    }
    enum Failure: LocalizedError {
        case unreadable
        var errorDescription: String? { "练习额度暂时无法读取，请保留当前练习并重试。" }
    }
    private static let lock = NSRecursiveLock()
    private static let process = UUID()
    private let defaults: UserDefaults
    private let key: String
    private let legacyPrefix: String
    private let url: URL?
    private let calendar: () -> Calendar
    private let now: () -> Date

    init(namespace: String, defaults: UserDefaults, now: @escaping () -> Date,
         calendar: @escaping () -> Calendar, fileURL: URL? = nil) {
        self.defaults = defaults; self.now = now; self.calendar = calendar
        key = "trainingQuota.v1." + namespace
        legacyPrefix = "sceneTraining.usage." + namespace
        if let fileURL { url = fileURL }
        else if defaults === UserDefaults.standard {
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            // A unique XCTest-owned disk domain permits real process-relaunch checks
            // without touching the simulator user's ordinary quota archive.
            if let argument = args.first(where: { $0.hasPrefix("-trainingQuota.testNamespace=") }),
               let namespaceID = UUID(uuidString: String(argument.dropFirst("-trainingQuota.testNamespace=".count))) {
                url = FileManager.default.temporaryDirectory.appendingPathComponent("TrainingQuotaTests/\(namespaceID.uuidString)/\(namespace).json")
                return
            }
            if args.contains("-v50.inMemoryStore") || args.contains("-w7.forceDailyLimit") || args.contains("-w7.forceDailyLimitNear") {
                url = FileManager.default.temporaryDirectory.appendingPathComponent("TrainingQuotaTests/\(Self.process)/\(namespace).json")
                return
            }
            #endif
            url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("QiuJi/TrainingQuota/\(namespace).json")
        } else { url = nil }
    }
    private func day(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar(); f.timeZone = f.calendar.timeZone; f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    private func read() throws -> Archive {
        let data: Data?
        if let url, FileManager.default.fileExists(atPath: url.path) { data = try Data(contentsOf: url) }
        else { data = defaults.data(forKey: key) }
        if let data {
            let value = try JSONDecoder().decode(Archive.self, from: data)
            guard value.version == 1 else { throw Failure.unreadable }
            return value
        }
        // The count already includes the old ledger. Import their union, not sum.
        var value = Archive()
        let date = defaults.string(forKey: legacyPrefix + ".day") ?? ""
        let old = defaults.dictionary(forKey: legacyPrefix + ".ledger")
        let ids = Set((old?["ids"] as? [String] ?? []).compactMap(UUID.init(uuidString:)))
        if !date.isEmpty { value.counts[date] = max(0, defaults.integer(forKey: legacyPrefix + ".count")) }
        if let ledgerDay = old?["day"] as? String {
            value.counts[ledgerDay] = max(value.counts[ledgerDay] ?? 0, ids.count)
            value.seen.formUnion(ids)
        }
        return value
    }
    private func write(_ value: Archive) throws {
        let data = try JSONEncoder().encode(value)
        if let url {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } else { defaults.set(data, forKey: key) }
    }
    func used() throws -> Int {
        Self.lock.lock(); defer { Self.lock.unlock() }
        return try read().counts[day(now())] ?? 0
    }
    func reserve(_ question: UUID, limit: Int, premium: Bool, admitted: Bool = false, replacing: UUID? = nil) throws -> Bool {
        Self.lock.lock(); defer { Self.lock.unlock() }
        var value = try read()
        if value.seen.contains(question) { return true }
        let today = day(now())
        // A new process cannot inherit an unsaved operation's reservation.
        value.reservations = value.reservations.filter { $0.value.process == Self.process && $0.value.day == today }
        if value.reservations[question] != nil { return true }
        if let replacing, replacing != question { value.reservations[replacing] = nil }
        guard admitted || premium || (value.counts[today] ?? 0) + value.reservations.count < limit else { return false }
        if !premium { value.reservations[question] = .init(process: Self.process, day: today) }
        try write(value)
        return true
    }
    func release(_ question: UUID) throws {
        Self.lock.lock(); defer { Self.lock.unlock() }
        var value = try read(); value.reservations[question] = nil; try write(value)
    }
    func accept(_ receipt: TrainingConsumptionReceipt) throws {
        Self.lock.lock(); defer { Self.lock.unlock() }
        var value = try read()
        value.reservations[receipt.questionID] = nil
        if value.seen.insert(receipt.questionID).inserted, receipt.charged {
            value.counts[day(receipt.acceptedAt), default: 0] += 1
        }
        // Receipt and count have one atomic commit; legacy keys are untouched.
        try write(value)
    }
}
