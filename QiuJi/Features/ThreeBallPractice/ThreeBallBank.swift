import Foundation
import CryptoKit

final class ThreeBallBank {
    enum Failure: LocalizedError {
        case unavailable, invalid, missingPocket
        var errorDescription: String? {
            switch self {
            case .unavailable: "当前条件下没有三球球形，请调整训练条件。"
            case .invalid: "三球题库或记录校验失败，请保留记录并重试。"
            case .missingPocket: "请先选择下一颗球的目标袋口。"
            }
        }
    }
    struct Row: Decodable {
        let id: String
        let board: TwoBallSourceBoard
        let second, third: [Double]
    }
    struct Manifest: Decodable {
        struct Shard: Decodable { let file, sha256: String; let count: Int }
        let version, count: Int
        let source: String
        let shards: [Shard]
    }
    private static let lock = NSLock()
    private static var cached: ThreeBallBank?
    static var loadedCount: Int { lock.lock(); defer { lock.unlock() }; return cached?.questions.count ?? 0 }
    static let appearancePolicy = "same-group-two-distinct-black8-v2"
    let fingerprint: String
    let questions: [ThreeBallQuestion]
    static func load() throws -> ThreeBallBank {
        lock.lock(); defer { lock.unlock() }
        if let cached { return cached }
        let value = try ThreeBallBank(); cached = value; return value
    }
    static func currentFingerprint() throws -> String {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("ThreeBallBank") else { throw Failure.unavailable }
        return SHA256.hash(data: try Data(contentsOf: root.appendingPathComponent("manifest.json"))).map { String(format: "%02x", $0) }.joined() + ":" + appearancePolicy
    }
    private init() throws {
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("ThreeBallBank") else { throw Failure.unavailable }
        let data = try Data(contentsOf: root.appendingPathComponent("manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard manifest.version == 1, manifest.count > 0 else { throw Failure.invalid }
        fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() + ":" + Self.appearancePolicy
        let base = try TrainingBankStore.load()
        var values: [ThreeBallQuestion] = [], seen: Set<String> = []
        for shard in manifest.shards {
            try Task.checkCancellation()
            guard !shard.file.contains("/"), !shard.file.contains("..") else { throw Failure.invalid }
            let compressed = try Data(contentsOf: root.appendingPathComponent(shard.file))
            guard SHA256.hash(data: compressed).map({ String(format: "%02x", $0) }).joined() == shard.sha256 else { throw Failure.invalid }
            let rows = try JSONDecoder().decode([Row].self, from: TwoBallBankStore.gunzip(compressed))
            guard rows.count == shard.count else { throw Failure.invalid }
            for row in rows {
                guard seen.insert(row.id).inserted, let classification = base.board(id: row.board.id),
                      [row.board.cue, row.board.object, row.board.aim, row.second, row.third].allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isFinite) }),
                      (0..<6).contains(row.board.pocket) else { throw Failure.invalid }
                func point(_ a: [Double]) -> TrainingBankPoint { .init(.init(Float(a[0]), 0, Float(a[1]))) }
                let board = TrainingBankBoard(gridID: row.board.id, seed: classification.seed,
                    cue: point(row.board.cue).vector, target: point(row.board.object).vector, aim: point(row.board.aim).vector,
                    pocket: row.board.pocket, angle: classification.angle, side: classification.side,
                    cueBand: classification.cueBand, pocketBand: classification.pocketBand,
                    combinationID: classification.combinationID ?? "", qualification: "three-ball-static-v1",
                    generationAngle: classification.generationAngle ?? classification.angle)
                values.append(.init(id: UUID(), contentID: row.id, board: board, second: point(row.second), third: point(row.third)))
            }
        }
        guard values.count == manifest.count else { throw Failure.invalid }
        questions = values
    }
    func draw(_ configuration: SceneTrainingConfiguration, excluding: Set<String>) throws -> ThreeBallQuestion {
        let eligible = questions.filter { $0.board.matches(configuration) && !excluding.contains($0.contentID) }
        #if DEBUG
        let chosen = ProcessInfo.processInfo.arguments.contains("-threeBall.fixedSeed") ? eligible.first : eligible.randomElement()
        #else
        let chosen = eligible.randomElement()
        #endif
        guard let q = chosen else { throw Failure.unavailable }
        return .init(id: UUID(), contentID: q.contentID, board: q.board, second: q.second, third: q.third)
    }
}
