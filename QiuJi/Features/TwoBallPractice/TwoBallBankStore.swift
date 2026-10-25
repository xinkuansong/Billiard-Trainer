import Foundation
import CryptoKit
import SceneKit
import zlib

/// Frozen source coordinates: X/Z metres, Y up; source times begin at first contact.
enum TwoBallMode: String, Codable, CaseIterable {
    case trajectory, free
    var title: String { self == .trajectory ? "轨迹走位" : "自由走位" }
}

struct TwoBallSourceBoard: Codable {
    let id: String
    let cue, object, aim: [Double]
    let pocket: Int
    let angle: Double
}
struct TwoBallRecommendation: Codable {
    struct Comfort: Codable {
        let distanceScore, spaceScore, angleScore, totalScore: Double
        var isQualified: Bool {
            let parts = [distanceScore, spaceScore, angleScore]
            return parts.allSatisfy { $0.isFinite && (0...100).contains($0) }
                && totalScore.isFinite && (85...100).contains(totalScore)
                && abs(pow(parts.reduce(1, *), 1.0/3.0)-totalScore) < 1e-8
        }
    }
    let comboIndex, pocket: Int
    let angle, distance, score: Double
    var comfort: Comfort? = nil
    var sourceRecommendationRank: Int? = nil
}
struct TwoBallCandidate: Codable {
    let cellID: Int
    let position: [Double]
    let top5: [TwoBallRecommendation]
}
struct TwoBallSourceRoute: Codable {
    struct Line: Codable {
        struct Cushion: Codable { let cushionID: Int }
        let coordinateUnit, timeOrigin: String
        let points: [[Double]]
        let mandatoryPointIndices: [Int]
        var cushions: [Cushion]? = nil
        var trajectory: [SeparationTrajectory.Point] {
            let mandatory = Set(mandatoryPointIndices)
            return points.enumerated().map { i, p in
                .init(time: Float(p[0]), position: .init(.init(Float(p[1]), 0, Float(p[2]))), isEvent: mandatory.contains(i))
            }
        }
    }
    let comboIndex: Int
    let velocity, spinX, spinY: Double
    let strikeDirection, cueStop: [Float]
    let trajectory2mm: Line
    var cueMainRailsAfterContact: Int? = nil
    var executionDifficulty: TwoBallExecutionDifficulty? = nil
    var input: SeparationInput { .init(spinX: Float(spinX), spinY: Float(spinY), velocity: Float(velocity)) }
    var direction: SCNVector3 { .init(strikeDirection[0], 0, strikeDirection[1]) }
}

/// Estimated first-shot execution effort, independent of second-shot comfort and player scores.
struct TwoBallExecutionDifficulty: Codable {
    static let version = "execution-effort-v1"
    struct Components: Codable {
        let stroke, power, route, interaction: Double
        var total: Double { stroke + power + route + interaction }
    }
    let version: String
    let lengthMeters: Double
    let components: Components
    let effort, difficulty: Double
    static func evaluate(velocity: Double, spinX: Double, spinY: Double,
                         cushions: Int, lengthMeters: Double) -> Self? {
        guard [velocity, spinX, spinY, lengthMeters].allSatisfy(\.isFinite),
              velocity >= 0, cushions >= 0, lengthMeters >= 0 else { return nil }
        let s = abs(spinX), u = velocity / 4.5, n = Double(cushions)
        let c = Components(stroke: 2.5*s + 0.8*max(spinY, 0) + 1.2*max(-spinY, 0),
                           power: 0.8*u*u, route: 0.12*n + 0.06*lengthMeters,
                           interaction: 0.6*s*u + 0.15*n*s)
        return .init(version: version, lengthMeters: lengthMeters, components: c,
                     effort: c.total, difficulty: 100*c.total/(c.total+1))
    }
    func matches(_ route: TwoBallSourceRoute) -> Bool {
        guard version == Self.version, let n = route.cueMainRailsAfterContact,
              let cushions = route.trajectory2mm.cushions, cushions.count == n,
              cushions.allSatisfy({ (0..<6).contains($0.cushionID) }) else { return false }
        let points = route.trajectory2mm.points
        let length = zip(points, points.dropFirst()).reduce(0.0) {
            $0 + hypot($1.1[1]-$1.0[1], $1.1[2]-$1.0[2])
        }
        guard let expected = Self.evaluate(velocity: route.velocity, spinX: route.spinX,
                                          spinY: route.spinY, cushions: n, lengthMeters: length) else { return false }
        let actual = [lengthMeters, components.stroke, components.power, components.route, components.interaction, effort, difficulty]
        let values = [length, expected.components.stroke, expected.components.power, expected.components.route,
                      expected.components.interaction, expected.effort, expected.difficulty]
        return zip(actual, values).allSatisfy { $0.isFinite && abs($0-$1) < 1e-9 }
    }
}
/// Only approved parameters are bundled; reference lines are generated for the current question.
struct TwoBallParameterRoute: Decodable {
    let id: Int
    let v, sx, sy: Double
    let dir: [Float]
    let rails: [Int]
    var input: SeparationInput { .init(spinX: Float(sx), spinY: Float(sy), velocity: Float(v)) }
    var direction: SCNVector3 { .init(dir[0], 0, dir[1]) }
}
struct TwoBallParameterQuestion: Decodable {
    let id: Int
    let p: [Double]
    let refs: [[Int]]
}
struct TwoBallLayout: Decodable {
    let id: String
    let board: TwoBallSourceBoard
    let questions: [TwoBallParameterQuestion]
    let routes: [TwoBallParameterRoute]
}

/// Synchronous API used only by detached preparation workers. Bounded two-shard cache.
final class TwoBallBankStore {
    static let policyVersion = "comfort85-parameters-v1"
    static let sourceSchema = "two-ball-consumer-parameters-v1"
    struct Index: Decodable {
        struct Counts: Decodable { let layouts, questions, recommendations, routes: Int }
        struct Shard: Decodable { let name, sha256: String; let bytes: Int }
        struct Entry: Decodable { let id, shard: String; let line: Int }
        let schema, fingerprint: String
        let physicsModel, replayVersion, comfortVersion: String
        let policyVersion, executionVersion: String
        let minimumComfort: Double
        let counts: Counts
        let geometry: TwoBallDifficultyMetric.Geometry
        let shards: [Shard]
        let layouts: [Entry]
    }
    enum Failure: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self { case .invalid(let reason): "两球题库无法读取：\(reason)。请保留记录后重试。" }
        }
    }
    private static let lock = NSLock()
    private static var cached: TwoBallBankStore?
    static func releaseDecodedShards() {
        lock.lock(); let bank = cached; lock.unlock()
        bank?.clearCache()
    }
    static func load(bundle: Bundle = .main) throws -> TwoBallBankStore {
        lock.lock(); defer { lock.unlock() }
        if bundle == .main, let cached { return cached }
        guard let url = bundle.url(forResource: "index", withExtension: "json", subdirectory: "TwoBallBank") else {
            throw Failure.invalid("缺少资源")
        }
        let result = try TwoBallBankStore(root: url.deletingLastPathComponent())
        if bundle == .main { cached = result }
        return result
    }
    let index: Index
    let boards: [String: TrainingBankBoard]
    private let root: URL
    private let cacheLock = NSLock()
    private var cache: [String: [TwoBallLayout]] = [:]
    private var lru: [String] = []
    init(root: URL) throws {
        self.root = root
        index = try JSONDecoder().decode(Index.self, from: Data(contentsOf: root.appendingPathComponent("index.json")))
        guard index.schema == Self.sourceSchema,
              index.physicsModel == "planarReference", index.replayVersion == "event-order-rdp2mm-v1",
              index.comfortVersion == TwoBallComfortScore.version,
              index.policyVersion == Self.policyVersion, index.executionVersion == TwoBallExecutionDifficulty.version,
              index.minimumComfort == 85,
              index.counts.layouts == index.layouts.count,
              abs(index.geometry.radius-Double(BallPhysics.radius)) < 1e-7,
              abs(index.geometry.length-TwoBallDifficultyMetric.Geometry.source.length) < 1e-7,
              abs(index.geometry.width-TwoBallDifficultyMetric.Geometry.source.width) < 1e-7,
              Set(index.layouts.map(\.id)).count == index.layouts.count,
              Set(index.shards.map(\.name)).count == index.shards.count else { throw Failure.invalid("版本或标识不匹配") }
        let grid = try TrainingBankStore.load()
        var resolved: [String: TrainingBankBoard] = [:]
        for entry in index.layouts {
            try Task.checkCancellation()
            guard let board = grid.board(id: entry.id), entry.line >= 0,
                  index.shards.contains(where: { $0.name == entry.shard }),
                  !entry.shard.contains("/"), !entry.shard.contains("..") else { throw Failure.invalid("球形不匹配") }
            resolved[entry.id] = board
        }
        boards = resolved
    }
    func layout(_ entry: Index.Entry) throws -> TwoBallLayout {
        cacheLock.lock(); defer { cacheLock.unlock() }
        try Task.checkCancellation()
        let rows: [TwoBallLayout]
        if let hit = cache[entry.shard] { rows = hit }
        else {
            guard let shard = index.shards.first(where: { $0.name == entry.shard }) else { throw Failure.invalid("分片缺失") }
            let data = try Data(contentsOf: root.appendingPathComponent(shard.name + ".jsonl.gz"))
            guard data.count == shard.bytes,
                  SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == shard.sha256 else {
                throw Failure.invalid("分片校验失败")
            }
            rows = try Self.gunzip(data).split(separator: 10).map { line in
                try JSONDecoder().decode(TwoBallLayout.self, from: Data(line))
            }
            for row in rows { try Self.validate(row) }
            if cache.count >= 2, let oldest = lru.first { cache.removeValue(forKey: oldest); lru.removeFirst() }
            cache[entry.shard] = rows
        }
        lru.removeAll { $0 == entry.shard }; lru.append(entry.shard)
        guard rows.indices.contains(entry.line), rows[entry.line].id == entry.id else { throw Failure.invalid("行定位错误") }
        return rows[entry.line]
    }
    func clearCache() { cacheLock.lock(); defer { cacheLock.unlock() }; cache.removeAll(); lru.removeAll() }
    func board(for layout: TwoBallLayout) throws -> TrainingBankBoard {
        let raw = layout.board
        guard let base = boards[layout.id], base.pocketIndex == raw.pocket,
              abs(Double(base.cue.x)-raw.cue[0]) < 1e-5,
              abs(Double(base.cue.z)-raw.cue[1]) < 1e-5 else { throw Failure.invalid("球形不匹配") }
        // The shared inventory supplies classification only. Exact source positions/aim remain authoritative.
        return .init(gridID: raw.id, seed: base.seed,
            cue: .init(Float(raw.cue[0]), 0, Float(raw.cue[1])),
            target: .init(Float(raw.object[0]), 0, Float(raw.object[1])),
            aim: .init(Float(raw.aim[0]), 0, Float(raw.aim[1])), pocket: raw.pocket,
            angle: base.angle, side: base.side, cueBand: base.cueBand, pocketBand: base.pocketBand,
            combinationID: base.combinationID ?? "", qualification: base.qualification ?? "", generationAngle: raw.angle)
    }
    static func validate(_ row: TwoBallLayout) throws {
        let ids = Set(row.routes.map(\.id))
        let positions = [row.board.cue, row.board.object, row.board.aim] + row.questions.map(\.p)
        guard row.id == row.board.id, ids.count == row.routes.count,
              row.board.angle.isFinite, (0..<6).contains(row.board.pocket),
              positions.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isFinite) }),
              Set(row.questions.map(\.id)).count == row.questions.count else { throw Failure.invalid("球形或重复标识") }
        for q in row.questions {
            guard (1...5).contains(q.refs.count),
                  q.refs.allSatisfy({ $0.count == 2 && ids.contains($0[0]) && (0..<6).contains($0[1]) }),
                  Set(q.refs.map { $0[0] }).count == q.refs.count else { throw Failure.invalid("第二球或路线引用") }
        }
        for r in row.routes {
            guard r.input.isValid, [r.v,r.sx,r.sy].allSatisfy(\.isFinite),
                  (0.6...4.5).contains(r.v), r.sx*r.sx+r.sy*r.sy <= 0.25+1e-8,
                  r.dir.count == 2, r.dir.allSatisfy(\.isFinite),
                  abs(hypot(r.dir[0],r.dir[1])-1) < 1e-5,
                  r.rails.allSatisfy({ (0..<6).contains($0) }),
                  !r.rails.isEmpty || r.sx == 0 else { throw Failure.invalid("打点、方向或库序") }
        }
    }
    static func gunzip(_ input: Data) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, 15+32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw Failure.invalid("解压初始化")
        }
        defer { inflateEnd(&stream) }
        return try input.withUnsafeBytes { bytes in
            stream.next_in = UnsafeMutablePointer(mutating: bytes.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(input.count)
            var result = Data(), buffer = [UInt8](repeating: 0, count: 65536)
            var status: Int32 = Z_OK
            repeat {
                try Task.checkCancellation()
                status = buffer.withUnsafeMutableBytes { out in
                    stream.next_out = out.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(out.count)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                guard status == Z_OK || status == Z_STREAM_END else { throw Failure.invalid("压缩数据损坏") }
                result.append(contentsOf: buffer.prefix(buffer.count-Int(stream.avail_out)))
                guard result.count <= 32_000_000 else { throw Failure.invalid("分片过大") }
            } while status != Z_STREAM_END
            guard stream.avail_in == 0 else { throw Failure.invalid("压缩尾部异常") }
            return result
        }
    }
}

enum TwoBallDifficultyMetric {
    struct Geometry: Codable {
        let length, width, radius: Double
        static let source = Self(length: 2.5399999618530273, width: 1.2699999809265137, radius: 0.028574999421834946)
        func anchor(_ pocket: Int) -> (Double, Double)? {
            guard (0..<6).contains(pocket) else { return nil }
            let x = length/2-radius, z = width/2-radius
            return [(-x,-z),(x,-z),(-x,z),(x,z),(0,-width/2),(0,width/2)][pocket]
        }
    }
    struct Result: Codable { let value, angle, cueDistance: Double }
    static func evaluate(cue: (Double, Double), ball: (Double, Double), pocket: Int,
                         geometry: Geometry = .source) -> Result? {
        guard let p = geometry.anchor(pocket), [cue.0,cue.1,ball.0,ball.1].allSatisfy(\.isFinite) else { return nil }
        let d = hypot(p.0-ball.0,p.1-ball.1), cb = hypot(cue.0-ball.0,cue.1-ball.1)
        guard d > 1e-9, cb >= 2*geometry.radius else { return nil }
        let ux = (p.0-ball.0)/d, uz = (p.1-ball.1)/d
        let vx = ball.0-2*geometry.radius*ux-cue.0, vz = ball.1-2*geometry.radius*uz-cue.1
        let norm = hypot(vx,vz), dot = vx*ux+vz*uz
        guard norm > 1e-9, dot > 1e-12 else { return nil }
        let value = d*norm/dot, angle = atan2(abs(vx*uz-vz*ux),dot)*180/Double.pi
        guard value.isFinite else { return nil }
        return .init(value: value, angle: angle, cueDistance: cb)
    }
}
