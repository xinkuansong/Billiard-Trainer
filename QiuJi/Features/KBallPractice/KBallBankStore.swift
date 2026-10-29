import Foundation
import CryptoKit
import zlib

enum KBallTiming: String, Codable, CaseIterable {
    case before, after
    var title: String { self == .before ? "入库前K" : "出库后K" }
}

struct KBallBankQuestion: Codable, Identifiable, Equatable {
    let id: String
    let route: Int
    /// World X/Z metres. Preserve the exact source doubles until entering the engine.
    let b, dir: [Double]
    let v, sx, sy: Double
    /// Observed cushion ordinal, NOT the number of cushion contacts before hitting B.
    let rail: Int
    let timing: KBallTiming
    let grade: Int
    let trajectoryAngle, centerRailDistance: Double
    let railID: Int
    let railsBeforeK: [Int]
    var gradeTitle: String { [1: "敏感", 2: "常规", 3: "宽容"][grade] ?? "未知" }
}

struct KBallBankLayout: Codable, Identifiable {
    struct Board: Codable {
        let cue, object: [Double]
        let pocket: Int
        /// Generation parameter, not the compensated collision cut angle.
        let angle: Double
    }
    let id: String
    let board: Board
    let questions: [KBallBankQuestion]
}

struct KBallBankFilter: Codable, Equatable {
    enum Pocket: String, Codable, CaseIterable { case all, corner, middle }
    var rail: Int? = nil
    var timing: KBallTiming? = nil
    var grade: Int? = nil
    var pocket: Pocket = .all

    func accepts(_ question: KBallBankQuestion, pocketIndex: Int) -> Bool {
        (rail == nil || rail == question.rail)
            && (timing == nil || timing == question.timing)
            && (grade == nil || grade == question.grade)
            && (pocket == .all || (pocket == .middle ? pocketIndex >= 4 : pocketIndex < 4))
    }
}

/// Read off the main actor, like TwoBallBankStore. At most two decoded gzip shards survive.
final class KBallBankStore {
    struct Index: Decodable {
        struct Geometry: Decodable { let length, width, radius: Double }
        struct Counts: Decodable { let layouts, questions, routes: Int }
        struct Shard: Decodable { let name, sha256: String; let bytes, rows: Int }
        struct Entry: Decodable { let id, shard: String; let line: Int }
        struct Rules: Decodable {
            let generationAngle: [Double]
            let trajectoryAngleMax, centerRailDistanceMax: Double
            let railClassification, success: String
            let scratchFails: Bool
        }
        let schema, policyVersion, fingerprint, physicsModel, coordinateSystem: String
        let sourceSHA256, sourceAuditSHA256: String
        let geometry: Geometry
        let counts: Counts
        let rules: Rules
        let shards: [Shard]
        let layouts: [Entry]
    }
    enum Failure: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let reason): "K球题库无法读取：\(reason)" }
        }
    }
    let index: Index
    private let root: URL
    private let lock = NSLock()
    private var cache: [String: [KBallBankLayout]] = [:]
    private var lru: [String] = []

    static func load(bundle: Bundle = .main) throws -> KBallBankStore {
        guard let url = bundle.url(forResource: "index", withExtension: "json", subdirectory: "KBallBank") else {
            throw Failure.invalid("缺少资源")
        }
        return try .init(root: url.deletingLastPathComponent())
    }

    init(root: URL) throws {
        self.root = root
        index = try JSONDecoder().decode(Index.self, from: Data(contentsOf: root.appendingPathComponent("index.json")))
        let rules = index.rules
        guard index.schema == "k-ball-parameters-v1", index.policyVersion == "k-ball-one-per-route-v1",
              index.physicsModel == "planarReference", index.coordinateSystem == "scene-xz-metres",
              rules.generationAngle == [5, 50], rules.trajectoryAngleMax == 45,
              rules.centerRailDistanceMax == 0.1, !rules.scratchFails,
              rules.railClassification == "observed-rail-before-and-after",
              rules.success == "first-cue-contact-A; A-designated-pocket; later-cue-contact-B",
              abs(index.geometry.length-2.54) < 1e-7, abs(index.geometry.width-1.27) < 1e-7,
              abs(index.geometry.radius-0.028575) < 1e-7,
              index.counts.layouts == index.layouts.count, index.counts.layouts > 0,
              index.counts.questions >= index.counts.layouts, index.counts.routes == index.counts.questions,
              Set(index.layouts.map(\.id)).count == index.layouts.count,
              Set(index.shards.map(\.name)).count == index.shards.count,
              index.shards.reduce(0, { $0 + $1.rows }) == index.layouts.count,
              [index.fingerprint, index.sourceSHA256, index.sourceAuditSHA256].allSatisfy(Self.isHash) else {
            throw Failure.invalid("版本、规则或数量不匹配")
        }
        for shard in index.shards {
            guard shard.name.count == 5, shard.name.allSatisfy({ $0.isASCII && $0.isNumber }),
                  Self.isHash(shard.sha256), (1...64).contains(shard.rows),
                  (1...4_000_000).contains(shard.bytes) else { throw Failure.invalid("分片描述无效") }
            let entries = index.layouts.filter { $0.shard == shard.name }
            guard entries.count == shard.rows, Set(entries.map(\.line)) == Set(0..<shard.rows) else {
                throw Failure.invalid("分片索引无效")
            }
        }
        guard index.layouts.allSatisfy({ entry in index.shards.contains { $0.name == entry.shard } }) else {
            throw Failure.invalid("索引引用缺失")
        }
    }

    func layout(_ entry: Index.Entry) throws -> KBallBankLayout {
        lock.lock(); defer { lock.unlock() }
        try Task.checkCancellation()
        guard index.layouts.contains(where: { $0.id == entry.id && $0.shard == entry.shard && $0.line == entry.line }) else {
            throw Failure.invalid("未知球形索引")
        }
        let rows: [KBallBankLayout]
        if let hit = cache[entry.shard] { rows = hit }
        else {
            guard let shard = index.shards.first(where: { $0.name == entry.shard }) else { throw Failure.invalid("分片缺失") }
            let data = try Data(contentsOf: root.appendingPathComponent(shard.name + ".jsonl.gz"))
            guard data.count == shard.bytes,
                  SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == shard.sha256 else {
                throw Failure.invalid("分片校验失败")
            }
            rows = try Self.gunzip(data).split(separator: 10).map {
                try JSONDecoder().decode(KBallBankLayout.self, from: Data($0))
            }
            guard rows.count == shard.rows else { throw Failure.invalid("分片行数错误") }
            var ids = Set<String>()
            for (line, row) in rows.enumerated() {
                try Self.validate(row, radius: index.geometry.radius)
                guard index.layouts.contains(where: { $0.shard == entry.shard && $0.line == line && $0.id == row.id }),
                      row.questions.allSatisfy({ ids.insert($0.id).inserted }) else { throw Failure.invalid("分片身份错误") }
            }
            if cache.count >= 2, let oldest = lru.first { cache.removeValue(forKey: oldest); lru.removeFirst() }
            cache[entry.shard] = rows
        }
        lru.removeAll { $0 == entry.shard }; lru.append(entry.shard)
        guard rows.indices.contains(entry.line), rows[entry.line].id == entry.id else { throw Failure.invalid("行定位错误") }
        return rows[entry.line]
    }

    func clearCache() { lock.lock(); defer { lock.unlock() }; cache.removeAll(); lru.removeAll() }
    var decodedShardCount: Int { lock.lock(); defer { lock.unlock() }; return cache.count }

    static func validate(_ row: KBallBankLayout, radius: Double) throws {
        let board = row.board
        let positions = [board.cue, board.object] + row.questions.map(\.b)
        guard !row.id.isEmpty, !row.questions.isEmpty, (0..<6).contains(board.pocket),
              (5...50).contains(board.angle),
              positions.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isFinite) }),
              Set(row.questions.map(\.id)).count == row.questions.count,
              Set(row.questions.map(\.route)).count == row.questions.count else { throw Failure.invalid("球形参数无效") }
        for q in row.questions {
            guard !q.id.isEmpty, q.route >= 0, (1...3).contains(q.rail), (1...3).contains(q.grade),
                  (0..<6).contains(q.railID), (0...45).contains(q.trajectoryAngle),
                  (radius-1e-7...0.1+1e-9).contains(q.centerRailDistance),
                  [q.v, q.sx, q.sy].allSatisfy(\.isFinite), (0.6...4.5).contains(q.v),
                  q.sx*q.sx+q.sy*q.sy <= 0.25+1e-8, q.dir.count == 2, q.dir.allSatisfy(\.isFinite),
                  abs(hypot(q.dir[0],q.dir[1])-1) < 1e-5,
                  q.railsBeforeK.count == q.rail-(q.timing == .before ? 1 : 0),
                  q.railsBeforeK.allSatisfy({ (0..<6).contains($0) }) else { throw Failure.invalid("路线参数无效") }
            let balls = [board.cue, board.object, q.b]
            for i in balls.indices {
                for j in balls.indices where j > i {
                    guard hypot(balls[i][0]-balls[j][0], balls[i][1]-balls[j][1]) >= 2*radius-1e-7 else {
                        throw Failure.invalid("球位重叠")
                    }
                }
            }
        }
    }

    private static func isHash(_ s: String) -> Bool {
        s.count == 64 && s.allSatisfy { "0123456789abcdef".contains($0) }
    }

    private static func gunzip(_ input: Data) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, 15+32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw Failure.invalid("解压初始化失败")
        }
        defer { inflateEnd(&stream) }
        return try input.withUnsafeBytes { bytes in
            stream.next_in = UnsafeMutablePointer(mutating: bytes.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(input.count)
            var result = Data(), buffer = [UInt8](repeating: 0, count: 65536)
            var status: Int32 = Z_OK
            repeat {
                try Task.checkCancellation()
                status = buffer.withUnsafeMutableBytes { output in
                    stream.next_out = output.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(output.count)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                guard status == Z_OK || status == Z_STREAM_END else { throw Failure.invalid("压缩数据损坏") }
                result.append(contentsOf: buffer.prefix(buffer.count-Int(stream.avail_out)))
                guard result.count <= 8_000_000 else { throw Failure.invalid("分片过大") }
            } while status != Z_STREAM_END
            guard stream.avail_in == 0 else { throw Failure.invalid("压缩尾部异常") }
            return result
        }
    }
}
