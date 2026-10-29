import Foundation

struct MultiBallConfiguration: Codable, Equatable {
    enum Game: String, Codable, CaseIterable { case rotation, chineseEight
        var title: String { self == .rotation ? "追分" : "中八残局" }
    }
    enum PositionMode: String, Codable, CaseIterable {
        case planned, independent
        var title: String { self == .planned ? "规划走位" : "自主走位" }
    }
    var positionMode: PositionMode = .planned
    static let rotationCounts = [4, 5, 6, 9]
    var game: Game = .rotation
    var rotationCount = 4
    var ownCount = 4
    var randomOpponents = false
    var freePractice = false
    var showsPlanningMarkers = true
    static func numbers(_ count: Int) -> [Int] { count == 9 || count == 15 ? Array(1...count) : Array(1..<count) + [9] }
    var count: Int { game == .rotation ? rotationCount : ownCount }
    var bankCount: Int { game == .rotation ? rotationCount : 15 }
    var isValid: Bool { Self.rotationCounts.contains(rotationCount) && (4...8).contains(ownCount) }
    static func load(defaults: UserDefaults = .standard, is3D: Bool = false) -> Self {
        guard let data = defaults.data(forKey: "multiBall.configuration.project.v2") ?? defaults.data(forKey: is3D ? "multiBall.configuration.3D.v1" : "multiBall.configuration.v1"),
              let value = try? JSONDecoder().decode(Self.self, from: data), value.isValid else { return .init() }
        return value
    }
    func save(defaults: UserDefaults = .standard, is3D: Bool = false) {
        if isValid, let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "multiBall.configuration.project.v2") }
    }
}

extension MultiBallConfiguration {
    // Existing preferences predate training length; preserve their ball choices.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        positionMode = try c.decodeIfPresent(PositionMode.self, forKey: .positionMode) ?? .planned
        game = try c.decode(Game.self, forKey: .game)
        rotationCount = try c.decode(Int.self, forKey: .rotationCount)
        ownCount = try c.decode(Int.self, forKey: .ownCount)
        randomOpponents = try c.decode(Bool.self, forKey: .randomOpponents)
        showsPlanningMarkers = try c.decodeIfPresent(Bool.self, forKey: .showsPlanningMarkers) ?? true
        freePractice = try c.decodeIfPresent(Bool.self, forKey: .freePractice) ?? false
    }
}

struct MultiBallBase: Codable {
    let id: String
    /// Canvas coordinates: origin top left, both axes normalized by table length.
    let balls: [String: [Double]]
}

struct MultiBallRack: Codable {
    let sourceID: String
    let ownKeys: Set<String>
    let opponentKeys: Set<String>
    let board: BoardSnapshot
    var paletteKeys: [String] {
        ownKeys.union(opponentKeys).sorted { Int($0.dropFirst())! < Int($1.dropFirst())! }
    }
    static func make<R: RandomNumberGenerator>(base: MultiBallBase, configuration: MultiBallConfiguration,
                                               using random: inout R) -> Self {
        let own: Set<String>, opponent: Set<String>
        if configuration.game == .rotation {
            own = Set(MultiBallConfiguration.numbers(configuration.count).map { "_\($0)" }); opponent = []
        } else {
            let solids = Bool.random(using: &random)
            let mine = (solids ? Array(1...7) : Array(9...15)).shuffled(using: &random)
            let theirs = (solids ? Array(9...15) : Array(1...7)).shuffled(using: &random)
            own = Set(mine.prefix(configuration.ownCount - 1).map { "_\($0)" } + ["_8"])
            let count = configuration.randomOpponents ? Int.random(in: 1...7, using: &random) : 0
            opponent = Set(theirs.prefix(count).map { "_\($0)" })
        }
        let retained = own.union(opponent)
        var positions = base.balls.filter { retained.contains($0.key) }.mapValues { CanvasPoint(x: $0[0], y: $0[1]) }
        // Place a legal cue for presentation; the user has whole-table ball in hand.
        // This does not score, reject or alter the randomly retained object balls.
        let candidates = (1...19).flatMap { x in (1...9).map { y in CanvasPoint(x: Double(x)/20, y: Double(y)/20) } }
        let cue = candidates.max { a, b in
            func clearance(_ p: CanvasPoint) -> Double {
                positions.values.map { hypot($0.x-p.x, $0.y-p.y) }.min() ?? 1
            }
            return clearance(a) < clearance(b)
        }!
        positions[PositionPlayBall.cueKey] = cue
        return .init(sourceID: base.id, ownKeys: own, opponentKeys: opponent, board: .init(onTable: positions))
    }
}

@MainActor
final class MultiBallBank {
    static let shared = MultiBallBank()
    struct Envelope: Decodable { let version: Int; let count: Int; let threshold: Double; let boards: [MultiBallBase] }
    enum BankError: LocalizedError {
        case unavailable
        var errorDescription: String? { "球形库暂时无法读取，请返回后重试" }
    }
    private var cache: [Int: [MultiBallBase]] = [:]
    private var random: SeededGenerator = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-multiBall.fixedSeed") { return SeededGenerator(seed: 42) }
        #endif
        return SeededGenerator(seed: UInt64.random(in: 1...UInt64.max))
    }()
    func draw(configuration: MultiBallConfiguration, excluding previous: String?) throws -> MultiBallRack {
        guard configuration.isValid else { throw BankError.unavailable }
        let count = configuration.bankCount
        if cache[count] == nil {
            guard let url = Bundle.main.url(forResource: "bank-\(count)", withExtension: "json", subdirectory: "MultiBallBank") else { throw BankError.unavailable }
            let value = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: url))
            let margin = Double(BallPhysics.radius / TablePhysics.innerLength) + 1e-6
            let aspect = Double(TablePhysics.innerWidth / TablePhysics.innerLength)
            guard value.version == 1, value.count == count, value.threshold == 1.2, !value.boards.isEmpty,
                  value.boards.allSatisfy({ base in
                      base.balls.count == count && MultiBallConfiguration.numbers(count).allSatisfy { n in
                          guard let p = base.balls["_\(n)"], p.count == 2 else { return false }
                          return p.allSatisfy(\.isFinite) && (-margin...1+margin).contains(p[0]) && (-margin...aspect+margin).contains(p[1])
                      }
                  }) else { throw BankError.unavailable }
            // A full category contains 10,000 boards. Keep only the active
            // category so changing settings cannot accumulate all five banks.
            cache = [count: value.boards]
        }
        let boards = cache[count]!
        var index = Int.random(in: boards.indices, using: &random)
        if boards.count > 1, boards[index].id == previous { index = (index + Int.random(in: 1..<boards.count, using: &random)) % boards.count }
        return MultiBallRack.make(base: boards[index], configuration: configuration, using: &random)
    }
}
