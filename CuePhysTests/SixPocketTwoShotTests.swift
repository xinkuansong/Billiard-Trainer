import XCTest
import SceneKit
import UIKit
@testable import QiuJi

/// Research-only two-stroke baseline. Production physics is read-only.
/// XZ horizontal, Y up, metres; portrait up=+X, right=+Z.
final class SixPocketTwoShotTests: XCTestCase {
    private let numbers = [1, 2, 3, 4, 5, 8]
    private let pockets = [1, 3, 5, 2, 0, 4]
    private let y: Float = 0.8
    private var geometry: TableGeometry { .chineseEightBallQiuJi(surfaceY: y) }
    private let cue = ShotInput.cueBallName
    private var calls = 0
    private var rng: UInt64 = 20260920
    private func random() -> Float {
        rng = rng &* 6364136223846793005 &+ 1442695040888963407
        return Float(rng >> 40) / Float(1 << 24)
    }
    private func env(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key] ?? ProcessInfo.processInfo.environment["TEST_RUNNER_" + key]
        return value.flatMap { $0.isEmpty ? nil : $0 }
    }
    private struct Point: Codable, Equatable {
        var x: Float; var z: Float
        init(_ x: Float, _ z: Float) { self.x = x; self.z = z }
        init(_ p: SCNVector3) { x = p.x; z = p.z }
        var vector: SCNVector3 { SCNVector3(x, 0.8 + BallPhysics.radius, z) }
        func distance(_ p: Point) -> Float { hypotf(x - p.x, z - p.z) }
    }
    private struct Board: Codable, Equatable {
        var cue: Point
        var targets: [Int: Point]
    }
    private struct Shot: Codable, Equatable {
        var q: [Float] // angle, cue speed, spinX (left), spinY (follow)
    }
    private struct Result: Codable {
        var shot: Shot
        var start: Board
        var end: Board
        var pots: [Int]
        var pocketIDs: [String: String]
        var contacts: [Int]
        var events: [String]
        var rejected: [String]
        var termination: String
        var gap: Float
        var clean: Bool { rejected.isEmpty && termination == "settled" }
        var cost: Float { Float(start.targets.count - pots.count) * 10 + gap + Float(rejected.count) * 30 }
    }
    private struct Solution: Codable {
        var first: Result
        var second: Result
    }
    private struct BankEntry: Codable {
        var board: Board
        var shot: Shot
    }
    private struct Row: Codable {
        var start: Point
        var status: String
        var simulations: Int
        var validationSimulations: Int
        var seconds: Double
        var cleanFirstMasks: [Int]
        var bestCleanTotal: Int
        var solution: Solution?
    }
    private func fixture(_ start: Point, d: Float) -> Board {
        var targets: [Int: Point] = [:]
        for (n, i) in zip(numbers, pockets) {
            let p = geometry.pockets[i]
            let off = p.isCorner ? d / sqrtf(2) : d
            targets[n] = Point(p.isCorner ? p.center.x - (p.center.x > 0 ? off : -off) : 0,
                               p.center.z - (p.center.z > 0 ? off : -off))
        }
        return Board(cue: start, targets: targets)
    }
    private func legal(_ board: Board) -> Bool {
        let r = BallPhysics.radius
        guard board.cue.x.isFinite, board.cue.z.isFinite,
              abs(board.cue.x) <= TablePhysics.innerLength / 2 - r,
              abs(board.cue.z) <= TablePhysics.innerWidth / 2 - r else { return false }
        return !board.targets.values.contains { board.cue.distance($0) < 2 * r }
            && !geometry.pockets.contains { board.cue.distance(Point($0.center)) <= $0.radius }
    }
    private func clamp(_ q: [Float]) -> Shot {
        var q = q
        q[0] = atan2f(sinf(q[0]), cosf(q[0]))
        q[1] = min(8, max(0.3, q[1]))
        let magnitude = hypotf(q[2], q[3]), cap = CuePhysics.miscueLimitFraction
        if magnitude > cap { q[2] *= cap / magnitude; q[3] *= cap / magnitude }
        return Shot(q: q)
    }
    private func forbiddenRails() -> Set<Int> {
        let g = geometry
        var result = Set(g.circularCushions.indices.map { g.linearCushions.count + $0 })
        for (i, s) in g.linearCushions.enumerated() {
            let long = abs(abs(s.start.z) - TablePhysics.innerWidth / 2) < 1e-4
                && abs(abs(s.end.z) - TablePhysics.innerWidth / 2) < 1e-4 && abs(s.normal.x) < 1e-4
            let short = abs(abs(s.start.x) - TablePhysics.innerLength / 2) < 1e-4
                && abs(abs(s.end.x) - TablePhysics.innerLength / 2) < 1e-4 && abs(s.normal.z) < 1e-4
            if !long && !short { result.insert(i) }
        }
        return result
    }
    private func evaluate(_ board: Board, _ shot: Shot) -> Result {
        calls += 1
        return autoreleasepool {
            let e = EventDrivenEngine(tableGeometry: geometry)
            let q = shot.q
            let raw = SCNVector3(cosf(q[0]), 0, sinf(q[0]))
            let len = hypotf(raw.x, raw.z)
            let strike = CueBallStrike.executeStrike(aimDirection: SCNVector3(raw.x/len, 0, raw.z/len),
                                                     velocity: q[1], spinX: q[2], spinY: q[3])
            e.setBall(BallState(position: board.cue.vector, velocity: strike.velocity,
                               angularVelocity: strike.angularVelocity, state: .sliding, name: cue))
            // Stable production insertion order, never Dictionary iteration order.
            for n in numbers {
                if let p = board.targets[n] {
                    e.setBall(BallState(position: p.vector, velocity: SCNVector3Zero,
                                       angularVelocity: SCNVector3Zero, state: .stationary, name: "_\(n)"))
                }
            }
            var termination = e.simulatePrediction(model: .appDefault, maxEvents: 4000, maxTime: 90,
                                                   highFidelityBounds: true)
            termination = e.completePlanarSpinTail(after: termination, surfaceY: y)
            let recorder = e.getTrajectoryRecorder()
            var rejects: [String] = [], contacts: [Int] = [], events: [String] = []
            var cushionCounts: [String: Int] = [:]
            let forbidden = forbiddenRails()
            for event in e.resolvedEvents {
                switch event {
                case let .ballBall(a,b):
                    if a != cue && b != cue { rejects.append("targetRelay") }
                    let other = a == cue ? b : a
                    if let n = Int(other.dropFirst()), board.targets[n] != nil { contacts.append(n) }
                    events.append("B:\(a):\(b)")
                case let .ballCushion(n,i,_):
                    events.append("C:\(n):\(i)")
                    if n == cue && forbidden.contains(i) { rejects.append("cueJaw") }
                    cushionCounts[n, default: 0] += 1
                case let .pocket(n,p): events.append("P:\(n):\(p)")
                case .transition: break
                }
            }
            var ids: [String: String] = [:], pots: [Int] = []
            for entry in recorder.pocketEntries { ids[entry.ball.name] = entry.pocketID }
            if recorder.isBallPocketed(cue) { rejects.append("scratch") }
            var remaining: [Int: Point] = [:]
            for n in numbers where board.targets[n] != nil {
                let name = "_\(n)"
                let expected = geometry.pockets[pockets[numbers.firstIndex(of: n)!]].id
                if let id = ids[name] {
                    if id == expected { pots.append(n) } else { rejects.append("wrongPocket:\(n)") }
                    if (cushionCounts[name] ?? 0) > 2 { rejects.append("targetRattle:\(n)") }
                    if !contacts.contains(n) { rejects.append("notDirect:\(n)") }
                } else if let ball = e.getBall(name) {
                    remaining[n] = Point(ball.position)
                    if contacts.contains(n) || Point(ball.position).distance(board.targets[n]!) > 1e-6 {
                        rejects.append("displaced:\(n)")
                    }
                    if ball.state != .stationary { rejects.append("moving:\(n)") }
                } else { rejects.append("missing:\(n)") }
            }
            let final = e.getBall(cue)
            if final == nil || final?.state != .stationary { rejects.append("cueNotStationary") }
            // Full recorder order is retained, including same-time last-committed states.
            let frames = recorder.framesByBallName[cue] ?? []
            var gap: Float = 0
            for n in numbers where board.targets[n] != nil && !pots.contains(n) {
                let p = board.targets[n]!
                var nearest: Float = 3
                if frames.count > 1 {
                    for i in 1..<frames.count {
                        let a = Point(frames[i-1].position), b = Point(frames[i].position)
                        let dx = b.x-a.x, dz = b.z-a.z, ll = dx*dx+dz*dz
                        let t = ll > 1e-12 ? min(1,max(0,((p.x-a.x)*dx+(p.z-a.z)*dz)/ll)) : 0
                        nearest = min(nearest,p.distance(Point(a.x+t*dx,a.z+t*dz)))
                    }
                }
                gap += max(0,nearest-2*BallPhysics.radius)
            }
            return Result(shot: shot, start: board,
                          end: Board(cue: Point(final?.position ?? board.cue.vector), targets: remaining),
                          pots: pots, pocketIDs: ids, contacts: contacts, events: events,
                          rejected: Array(Set(rejects)).sorted(), termination: String(describing: termination), gap: gap)
        }
    }
    private func randomShot(_ board: Board) -> Shot {
        var angle = random() * 2 * .pi
        if random() < 0.8, let n = numbers.filter({board.targets[$0] != nil}).randomElement(using: &randomAdapter) {
            let b = board.targets[n]!, p = geometry.pockets[pockets[numbers.firstIndex(of:n)!]].center
            let a = atan2f(p.z-b.z,p.x-b.x) + (random()-0.5)*0.5
            let ghost = Point(b.x-2*BallPhysics.radius*cosf(a),b.z-2*BallPhysics.radius*sinf(a))
            angle = atan2f(ghost.z-board.cue.z,ghost.x-board.cue.x)
        }
        let a = random()*2 * .pi, radius = sqrtf(random())*CuePhysics.miscueLimitFraction
        let sx = radius*cosf(a), sy = radius*sinf(a)
        // Compensate the seeded direction for the production strike's squirt.
        angle += CueBallStrike.squirtAngle(a: sx)
        return clamp([angle,0.3+7.7*random(),sx,sy])
    }
    private var randomAdapter = SeededGenerator()
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64 = 19
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1; return state }
    }
    private func mutate(_ shot: Shot, scale: Float) -> Shot {
        let steps: [Float] = [0.09,0.7,0.15,0.15]
        return clamp(shot.q.enumerated().map { $0.element+(random()*2-1)*steps[$0.offset]*scale })
    }
    private func reflected(_ shot: Shot, x: Float, z: Float) -> Shot {
        // Planar reflection reverses axial side spin; follow/draw retains its local meaning.
        // This only generates seeds. Every transformed stroke is run through the real engine.
        return clamp([atan2f(z*sinf(shot.q[0]),x*cosf(shot.q[0])),shot.q[1],
                      shot.q[2]*x*z,shot.q[3]])
    }
    private func mask(_ balls: [Int]) -> Int {
        balls.reduce(0) { $0 | (1 << numbers.firstIndex(of:$1)!) }
    }
    private func archiveKey(_ r: Result, landing: Bool) -> String {
        let cell = landing ? "|\(Int(floor(r.end.cue.x/0.15))):\(Int(floor(r.end.cue.z/0.15)))" : ""
        return "\(mask(r.pots))|\(r.contacts)|\(r.rejected)" + cell
    }
    private func seededShots(_ board: Board) -> [Shot] {
        var shots: [Shot] = []
        for n in numbers where board.targets[n] != nil {
            let b = board.targets[n]!, p = geometry.pockets[pockets[numbers.firstIndex(of:n)!]].center
            let a = atan2f(p.z-b.z,p.x-b.x)
            let x = b.x-2*BallPhysics.radius*cosf(a), z = b.z-2*BallPhysics.radius*sinf(a)
            for speed: Float in [0.5,1,2,3.5,5,6.5,8] {
                for sy: Float in [-0.4,0,0.4] { shots.append(clamp([atan2f(z-board.cue.z,x-board.cue.x),speed,0,sy])) }
            }
        }
        return shots
    }
    private func save<T: Encodable>(_ object: T, _ path: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        try encoder.encode(object).write(to:path,options:.atomic)
    }
    private func verify(_ solution: Solution) -> Bool {
        var valid = solution.first.end == solution.second.start && solution.first.clean && solution.second.clean
            && !solution.first.pots.isEmpty && !solution.second.pots.isEmpty
            && Set(solution.first.pots+solution.second.pots) == Set(numbers)
        XCTAssertEqual(solution.first.end,solution.second.start)
        XCTAssertTrue(solution.first.clean); XCTAssertTrue(solution.second.clean)
        XCTAssertFalse(solution.first.pots.isEmpty); XCTAssertFalse(solution.second.pots.isEmpty)
        XCTAssertEqual(Set(solution.first.pots+solution.second.pots),Set(numbers))
        for saved in [solution.first,solution.second] {
            let repeatRun = evaluate(saved.start,saved.shot)
            XCTAssertEqual(repeatRun.events,saved.events)
            XCTAssertEqual(repeatRun.end,saved.end)
            XCTAssertEqual(repeatRun.rejected,saved.rejected)
            valid = valid && repeatRun.events == saved.events && repeatRun.end == saved.end
                && repeatRun.rejected == saved.rejected && repeatRun.termination == saved.termination
            let q = saved.shot.q
            let replay = ShotPredictor.simulateFree(cueBall:saved.start.cue.vector,
                aimDir:SCNVector3(cosf(q[0]),0,sinf(q[0])),velocity:q[1],spinX:q[2],spinY:q[3],surfaceY:y,
                balls:numbers.compactMap { n in saved.start.targets[n].map { ObstacleBall(name:"_\(n)",position:$0.vector) } },
                maxEvents:4000,maxTime:90,includePresentation:true)
            calls += 1
            XCTAssertTrue(replay.termination == .settled); XCTAssertFalse(replay.cuePocketed)
            XCTAssertEqual(Set(replay.pocketedBalls),Set(saved.pots.map { "_\($0)" }))
            var ids: [String:String] = [:]
            for entry in replay.recorder?.pocketEntries ?? [] { ids[entry.ball.name] = entry.pocketID }
            XCTAssertEqual(ids,saved.pocketIDs)
            let signature = replay.events.map { event -> String in
                switch event.kind {
                case let .ballBall(a,b): return "B:\(a):\(b)"
                case let .ballCushion(n): return "C:\(n)"
                case let .pocket(n,p): return "P:\(n):\(p)"
                }
            }
            let expected = saved.events.map { $0.hasPrefix("C:") ? $0.split(separator:":").prefix(2).joined(separator:":") : $0 }
            XCTAssertEqual(signature,expected)
            valid = valid && replay.termination == .settled && !replay.cuePocketed
                && Set(replay.pocketedBalls) == Set(saved.pots.map { "_\($0)" })
                && ids == saved.pocketIDs && signature == expected
            if let p = replay.finalPositions[cue] {
                XCTAssertEqual(Point(p),saved.end.cue); valid = valid && Point(p) == saved.end.cue
            } else { XCTFail("Production replay omitted cue end state");valid = false }
            for (n,p) in saved.end.targets {
                if let actual = replay.finalPositions["_\(n)"] {
                    XCTAssertEqual(Point(actual),p);valid = valid && Point(actual) == p
                } else { XCTFail("Production replay omitted target \(n)");valid = false }
            }
        }
        return valid
    }

    func testStateHandoffAndValidation() throws {
        let board = fixture(Point(0,0),d:0.12772500514984131)
        XCTAssertTrue(legal(board))
        XCTAssertFalse(legal(fixture(board.targets[1]!,d:0.12772500514984131)))
        let first = try XCTUnwrap(seededShots(board).lazy.map { self.evaluate(board,$0) }
            .first(where: { $0.clean && !$0.pots.isEmpty }))
        XCTAssertEqual(first.termination,"settled")
        XCTAssertLessThan(first.end.targets.count,board.targets.count)
        let second = evaluate(first.end,seededShots(first.end)[0])
        XCTAssertEqual(first.end,second.start)
        XCTAssertEqual(Set(second.start.targets.keys),Set(board.targets.keys).subtracting(first.pots))
        let replay = evaluate(board,first.shot)
        XCTAssertEqual(replay.events,first.events); XCTAssertEqual(replay.end,first.end)
        let all = (1..<63).map { $0 }
        XCTAssertEqual(Set(all).count,62)
        // Wrong-pocket / scratch input is not allowed to count as a clean solution.
        var invalid = first; invalid.rejected.append("wrongPocket:1")
        XCTAssertFalse(invalid.clean)
        for sx: Float in [-0.4,0.4] {
            let a = CueBallStrike.squirtAngle(a:sx)
            let strike = CueBallStrike.executeStrike(aimDirection:SCNVector3(cosf(a),0,sinf(a)),
                                                    velocity:3,spinX:sx,spinY:0)
            XCTAssertEqual(atan2f(strike.velocity.z,strike.velocity.x),0,accuracy:1e-5)
        }
        let scratch = evaluate(Board(cue:Point(0,0),targets:[:]),Shot(q:[.pi/2,2,0,0]))
        XCTAssertTrue(scratch.rejected.contains("scratch"));XCTAssertFalse(scratch.clean)
        let wrong = evaluate(Board(cue:Point(0,-0.3),targets:[1:Point(0,0)]),Shot(q:[.pi/2,2,0,0]))
        XCTAssertTrue(wrong.rejected.contains("wrongPocket:1"));XCTAssertFalse(wrong.clean)
        let displaced = evaluate(Board(cue:Point(0,-0.1),targets:[1:Point(0,0)]),Shot(q:[.pi/2,0.3,0,0]))
        XCTAssertTrue(displaced.rejected.contains("displaced:1"));XCTAssertFalse(displaced.clean)
        let relay = evaluate(Board(cue:Point(0,-0.3),targets:[1:Point(0,0),2:Point(0,0.2)]),Shot(q:[.pi/2,2,0,0]))
        XCTAssertTrue(relay.rejected.contains("targetRelay"));XCTAssertFalse(relay.clean)
    }

    func testCoverageSearch() throws {
        guard let path = env("TWO_SHOT_DIR") else { throw XCTSkip("Opt-in physical search") }
        let out = URL(fileURLWithPath:path)
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let d: Float = 0.12772500514984131
        let cap = max(1000,Int(env("TWO_SHOT_BUDGET") ?? "18000") ?? 18000)
        let limit = max(10,Double(env("TWO_SHOT_SECONDS") ?? "120") ?? 120)
        let baseSeed = UInt64(env("TWO_SHOT_SEED") ?? "20260920") ?? 20260920
        try save(ProcessInfo.processInfo.environment.filter { $0.key.contains("TWO_SHOT") },
                 out.appendingPathComponent("resolved-inputs.json"))
        var starts = [Point(-0.7093958854675293,-0.5574895739555359)]
        for x: Float in [-1.15,0,1.15] { for z: Float in [-0.50,0,0.50] { starts.append(Point(x,z)) } }
        if let custom = env("TWO_SHOT_STARTS") {
            starts = try JSONDecoder().decode([Point].self,from:Data(contentsOf:URL(fileURLWithPath:custom)))
        }
        var bank: [BankEntry] = [], rows: [Row] = [], library: [Solution] = []
        if let path = env("TWO_SHOT_BANK") {
            bank = try JSONDecoder().decode([BankEntry].self,from:Data(contentsOf:URL(fileURLWithPath:path)))
        }
        if let path = env("TWO_SHOT_SOLUTIONS") {
            library = try JSONDecoder().decode([Solution].self,from:Data(contentsOf:URL(fileURLWithPath:path)))
        }
        for (index,start) in starts.enumerated() {
            rng = baseSeed &+ UInt64(index)*1009; randomAdapter.state = rng
            let board = fixture(start,d:d), before = calls, began = Date()
            if !legal(board) {
                rows.append(Row(start:start,status:"invalidStart",simulations:0,validationSimulations:0,seconds:0,
                                cleanFirstMasks:[],bestCleanTotal:0,solution:nil))
                try save(rows,out.appendingPathComponent("coverage.json"));continue
            }
            var archive: [String:Result] = [:], clean: [String:Result] = [:]
            let historical = Shot(q:[3.38934063911438,7.5059380531311035,0.3955201506614685,0.0036177635192871094])
            var warm: [(Float,Shot,Shot)] = []
            for prior in library where prior.first.start.targets == board.targets {
                for x: Float in [1,-1] { for z: Float in [1,-1] {
                    let p = prior.first.start.cue
                    warm.append((start.distance(Point(p.x*x,p.z*z)),reflected(prior.first.shot,x:x,z:z),
                                 reflected(prior.second.shot,x:x,z:z)))
                } }
            }
            warm.sort { $0.0 < $1.0 };warm = Array(warm.prefix(12))
            let seeds = warm.map {$0.1}+[historical]+seededShots(board)
            func available() -> Bool { calls-before < cap && Date().timeIntervalSince(began) < limit }
            func record(_ r: Result) {
                let k = archiveKey(r,landing:true)
                if archive[k] == nil || r.cost < archive[k]!.cost { archive[k] = r }
                if r.clean && !r.pots.isEmpty && r.pots.count < 6 { clean[k] = r }
            }
            var solution: Solution?, bestTotal = 0
            var pairs: [(Float,Solution)] = []
            for (_,a,b) in warm where available() && solution == nil {
                let first = evaluate(board,a);record(first)
                if first.clean && !first.pots.isEmpty && first.pots.count < 6 && available() {
                    let second = evaluate(first.end,b), pair = Solution(first:first,second:second)
                    pairs.append((second.cost,pair))
                    if second.clean { bestTotal = max(bestTotal,first.pots.count+second.pots.count) }
                    if second.clean && second.pots.count == first.end.targets.count {
                        solution = pair;bank.append(BankEntry(board:first.end,shot:b))
                    }
                }
            }
            let firstBudget = cap / 4
            var n = 0
            while available() && calls-before < firstBudget && solution == nil {
                let shot: Shot
                if n < seeds.count { shot = seeds[n] }
                else if random() < 0.7 && !archive.isEmpty {
                    let ranked = archive.values.sorted { $0.cost == $1.cost ? $0.shot.q.lexicographicallyPrecedes($1.shot.q) : $0.cost < $1.cost }
                    let pool = Array(ranked.prefix(80)); let parent = pool[min(pool.count-1,Int(random()*Float(pool.count)))]
                    shot = mutate(parent.shot,scale:[Float(0.01),0.05,0.2,1,3][n % 5])
                } else { shot = randomShot(board) }
                record(evaluate(board,shot));n += 1
            }
            // Round-robin across pot subsets. One-ball prefixes remain eligible alongside five-ball ones.
            let groups = Dictionary(grouping:clean.values,by:{mask($0.pots)})
            let masks = groups.keys.sorted()
            var firsts: [Result] = []
            for rank in 0..<4 {
                for m in masks {
                    let group = groups[m]!.sorted { $0.gap == $1.gap ? $0.shot.q.lexicographicallyPrecedes($1.shot.q) : $0.gap < $1.gap }
                    if rank < group.count { firsts.append(group[rank]) }
                }
            }
            bestTotal = max(bestTotal,clean.values.map {$0.pots.count}.max() ?? 0)
            for (j,first) in firsts.enumerated() where available() && solution == nil {
                let secondBoard = first.end
                let near = bank.filter { Set($0.board.targets.keys) == Set(secondBoard.targets.keys)
                    && $0.board.targets == secondBoard.targets }.sorted { $0.board.cue.distance(secondBoard.cue) < $1.board.cue.distance(secondBoard.cue) }
                let secondSeeds = near.prefix(8).map(\.shot)+seededShots(secondBoard)
                var pool: [Result] = []
                let per = max(100,min(2000,(cap-(calls-before))*3/4/max(1,firsts.count-j)))
                for k in 0..<per where available() {
                    let shot: Shot
                    if k < secondSeeds.count { shot = secondSeeds[k] }
                    else if !pool.isEmpty && random() < 0.8 {
                        let p = pool[min(pool.count-1,Int(random()*Float(pool.count)))]
                        shot = mutate(p.shot,scale:[Float(0.005),0.03,0.1,0.5,2][k % 5])
                    } else { shot = randomShot(secondBoard) }
                    let second = evaluate(secondBoard,shot)
                    if second.clean { bestTotal = max(bestTotal,first.pots.count+second.pots.count) }
                    if second.clean && second.pots.count == secondBoard.targets.count {
                        solution = Solution(first:first,second:second)
                        bank.append(BankEntry(board:secondBoard,shot:shot));break
                    }
                    pool.append(second);pool.sort {$0.cost < $1.cost};if pool.count > 24 {pool.removeLast()}
                }
                if let best = pool.first { pairs.append((best.cost,Solution(first:first,second:best))) }
            }
            // Joint refinement: every proposal re-simulates shot 1, then shot 2 from its exact end.
            pairs.sort {$0.0 < $1.0};pairs = Array(pairs.prefix(24))
            n = 0
            while available() && calls-before+2 <= cap && solution == nil && !pairs.isEmpty {
                let i = n % pairs.count, pair = pairs[i].1
                let scale: Float = [0.003,0.01,0.04,0.15,0.6][n % 5]
                let first = evaluate(board,mutate(pair.first.shot,scale:scale))
                if first.clean && !first.pots.isEmpty && first.pots.count < 6 && available() {
                    let second = evaluate(first.end,n % 3 == 0 ? pair.second.shot : mutate(pair.second.shot,scale:scale))
                    if second.clean { bestTotal = max(bestTotal,first.pots.count+second.pots.count) }
                    let proposal = Solution(first:first,second:second)
                    if second.clean && second.pots.count == first.end.targets.count {
                        solution = proposal;bank.append(BankEntry(board:first.end,shot:second.shot))
                    } else if second.cost < pairs[i].0 { pairs[i] = (second.cost,proposal) }
                }
                n += 1
            }
            let searchCalls = calls-before
            var verified = false
            if let solution {
                verified = verify(solution)
                try save(solution,out.appendingPathComponent(verified ? "solution-\(index).json" : "rejected-replay-\(index).json"))
                if !verified { bank.removeLast() }
                else { library.append(solution) }
            }
            let row = Row(start:start,status:solution == nil ? "notFoundWithinBudget" : (verified ? "solved" : "replayMismatch"),
                          simulations:searchCalls,validationSimulations:calls-before-searchCalls,
                          seconds:Date().timeIntervalSince(began),cleanFirstMasks:masks,bestCleanTotal:bestTotal,solution:solution)
            rows.append(row)
            try save(rows,out.appendingPathComponent("coverage.json"))
            try save(bank,out.appendingPathComponent("second-shot-bank.json"))
            try save(library,out.appendingPathComponent("solution-library.json"))
            try save(Array(clean.values).sorted {$0.shot.q.lexicographicallyPrecedes($1.shot.q)},
                     out.appendingPathComponent("first-shot-archive-\(index).json"))
            print("TWO_SHOT start=\(index) status=\(row.status) cleanTotal=\(bestTotal) calls=\(searchCalls) seconds=\(row.seconds)")
        }
        XCTAssertEqual(rows.count,starts.count)
        XCTAssertTrue(rows.allSatisfy {$0.simulations <= cap})
    }
}


extension SixPocketTwoShotTests {
    /// Opt-in preview of an already verified solution; no search or trajectory changes.
    @MainActor
    func testTwoShotVideo() async throws {
        guard let path = env("TWO_SHOT_VIDEO_DIR"), let input = env("TWO_SHOT_VIDEO_SOLUTION") else {
            throw XCTSkip("Opt-in two-shot video")
        }
        let out = URL(fileURLWithPath:path)
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let solution = try JSONDecoder().decode(Solution.self,from:Data(contentsOf:URL(fileURLWithPath:input)))
        guard verify(solution) else { XCTFail("Solution failed replay"); return }
        let scene = AngleTrainingScene()
        scene.setupScene(enhancedRendering:false,mobileRendering:true)
        XCTAssertTrue(scene.applyTableStyle(.charcoal,showsSights:true))
        XCTAssertTrue(scene.applyClothColor(.green))
        scene.setCameraMode(.perspective3D,animated:false)
        XCTAssertTrue(scene.cueStick?.applyStyle(.inkDragon) == true)
        scene.hideAllBalls(); scene.hideCueStick()
        scene.setupVisualizationNodes(); scene.hideAllVisualization()
        scene.setCueBallHomeOrientation(BallSpinIntegrator.identityOrientation)
        scene.showBall(key:PositionPlayBall.cueKey,scenePosition:solution.first.start.cue.vector)
        for n in numbers { scene.showBall(key:"_\(n)",scenePosition:solution.first.start.targets[n]!.vector) }
        let size = CGSize(width:1440,height:2560), fps = 60
        let teachingPanelY: CGFloat = 390
        print("TWO SHOT teaching panel y=\(teachingPanelY)")
        let camera = try XCTUnwrap(scene.cameraNode)
        // Saved production video camera: 30 degrees, 5.10m from table centre, vertical FOV 40.
        let pitch: Float = .pi / 6, cameraDistance: Float = 5.10
        camera.camera?.usesOrthographicProjection = false
        camera.camera?.projectionDirection = .vertical
        camera.camera?.fieldOfView = 40
        camera.camera?.wantsExposureAdaptation = false
        camera.position = SCNVector3(-cameraDistance*cosf(pitch),y+cameraDistance*sinf(pitch),0)
        camera.look(at:SCNVector3(0,y,0),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        let renderer = SCNRenderer(device:nil,options:nil)
        renderer.scene = scene; renderer.pointOfView = camera
        renderer.delegate = scene.contactOcclusion; renderer.autoenablesDefaultLighting = false
        let exporting = env("TWO_SHOT_VIDEO_EXPORT") == "1"
        let url = out.appendingPathComponent("two-shot-six-preview.mp4")
        let writer: VideoWriter? = exporting ? try VideoWriter(url:url,size:size,fps:fps) : nil
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let compositor = UIGraphicsImageRenderer(size:size,format:format)
        for _ in 0..<3 { _ = renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X) }
        var frame = 0, completed = 0
        var ledger: [[String:Any]] = []
        var shotRecords: [[String:Any]] = []
        for (shotIndex,saved) in [solution.first,solution.second].enumerated() {
            let q = saved.shot.q, start = saved.start.cue.vector
            // The first shot's terminal nodes are retained, including their orientation.
            if shotIndex == 1 {
                let actual = try XCTUnwrap(scene.allBallNodes[PositionPlayBall.cueKey]).position
                XCTAssertEqual(actual.x,start.x,accuracy:1e-5); XCTAssertEqual(actual.z,start.z,accuracy:1e-5)
            }
            let aim = SCNVector3(cosf(q[0]),0,sinf(q[0]))
            let strike = CueStroke.strikePosition(cue:start,aim:aim,spinX:Double(q[2]),spinY:Double(q[3]))
            let obstacles = scene.cueObstacleCenters(excludingStrikeNear:strike)
            guard case .angle(let cueElevation) = CueStick.requiredElevation(
                cueBallPosition:strike,aimDirection:aim,obstacleCenters:obstacles) else {
                XCTFail("No nonpenetrating cue pose for this shot"); return
            }
            XCTAssertGreaterThan(cueElevation,0)

            let prediction = ShotPredictor.simulateFree(cueBall:start,aimDir:aim,velocity:q[1],spinX:q[2],spinY:q[3],surfaceY:y,
                balls:numbers.compactMap { n in saved.start.targets[n].map { ObstacleBall(name:"_\(n)",position:$0.vector) } },
                maxEvents:4000,maxTime:90,includePresentation:true)
            let recorder = try XCTUnwrap(prediction.recorder)
            var aimNodes: [SCNNode] = []
            scene.addCueTrajectory(prediction.cuePath,contact:prediction.firstContact,into:&aimNodes)
            for (_,points) in prediction.extraBallPaths.sorted(by: { $0.key < $1.key }) {
                scene.addDashedPolyline(points,color:.systemOrange,radius:TrajectoryStyle.potRadius,
                                        placement:.table,into:&aimNodes)
            }
            let contact = try XCTUnwrap(prediction.firstContact)
            let firstTarget = try XCTUnwrap(saved.contacts.first)
            let target = try XCTUnwrap(saved.start.targets[firstTarget]).vector
            XCTAssertEqual(hypotf(contact.x-target.x,contact.z-target.z),2*BallPhysics.radius,accuracy:0.001)
            scene.ghostBallNode?.position = contact
            scene.ghostBallNode?.isHidden = false
            scene.updateContactDot(ghostCenter:contact,targetCenter:target)

            let playback = TrajectoryPlayback(recorder:recorder,surfaceY:y+BallPhysics.radius)
            let collision = try XCTUnwrap(prediction.events.first { event in
                if case .ballBall = event.kind { return true }; return false
            })
            let beforeA = try XCTUnwrap(playback.stateAt(ballName:cue,time:max(0,collision.time-0.005))).position
            let beforeB = try XCTUnwrap(playback.stateAt(ballName:cue,time:max(0,collision.time-0.002))).position
            let incoming = (beforeB-beforeA).normalized()
            let normal = (target-contact).normalized()
            let cutDegrees = acosf(max(-1,min(1,incoming.dot(normal))))*180 / .pi
            let right = SCNVector3(-incoming.z,0,incoming.x)
            let lateral = max(-1,min(1,(contact-target).dot(right)/(2*BallPhysics.radius)))
            let overlap = 1-abs(lateral)
            XCTAssertEqual(abs(lateral),sinf(cutDegrees * .pi/180),accuracy:0.001)
            XCTAssertGreaterThanOrEqual(overlap,0); XCTAssertLessThanOrEqual(overlap,1)
            let motionEnd = SequenceVideoExporter.motionEndTime(duration:prediction.duration,playback:playback,
                                                                pocketedBallNames:prediction.pocketedBalls,speed:1)
            let impact = 2.0 + CueStroke.totalDuration(velocity:q[1])
            let count = Int(ceil((impact + Double(motionEnd) + 1.2)*Double(fps)))
            let keys = Set(([0,Int(impact*Double(fps)),count-1,Int(ceil(impact*Double(fps)))] + recorder.pocketEntries.map {
                Int((impact+Double($0.time)+0.3)*Double(fps))
            }).map { min(count-1,$0) })
            let names = [cue] + numbers.filter { saved.start.targets[$0] != nil }.map { "_\($0)" }
            let entries = Dictionary(uniqueKeysWithValues:recorder.pocketEntries.map { ($0.ball.name,$0) })
            var previousTime: Float = 0
            var previousOmega: [String:SCNVector3] = [:]
            shotRecords.append(["shot":shotIndex+1,"startFrame":frame,"impactFrame":frame+Int(impact*Double(fps)),
                                "firstTarget":firstTarget,"cutDegrees":cutDegrees,"overlapDiameterFraction":overlap,"signedLateralDiameters":lateral,"cueElevationDegrees":cueElevation*180 / .pi,"duration":prediction.duration,"potted":prediction.pocketedBalls,"parameters":q])
            for i in 0..<count {
                let wall = Double(i)/Double(fps)
                let t = min(motionEnd,max(0,Float(wall-impact)))
                let dt = max(0,t-previousTime); previousTime = t
                SCNTransaction.begin(); SCNTransaction.disableActions = true
                for node in aimNodes { node.isHidden = wall >= impact }
                scene.ghostBallNode?.isHidden = wall >= impact
                if wall >= impact { scene.hideContactDot() }

                for name in names {
                    let node = try XCTUnwrap(scene.allBallNodes[name == cue ? PositionPlayBall.cueKey : name])
                    guard let state = playback.stateAt(ballName:name,time:min(t,prediction.duration)) else { continue }
                    node.position = state.position; node.opacity = 1
                    if let opacity = playback.collectionOpacity(ballName:name,time:t),
                       let shown = playback.stateAt(ballName:name,time:t) {
                        node.position = shown.position; node.opacity = opacity
                    } else if let entry = entries[name],t >= entry.time {
                        let pocket = TrajectoryPlayback.nearestPocket(to:entry.ball.position,surfaceY:y+BallPhysics.radius)
                        let legs = TrajectoryPlayback.solvePocketEntry(capture:entry.ball.position,velocity:entry.ball.velocity,
                            pocketCenter:pocket.center,pocketRadius:pocket.radius,speedScale:1)
                        let elapsed = Double(t-entry.time),end = TrajectoryPlayback.pocketEntryDuration(legs)
                        node.position = TrajectoryPlayback.pocketEntryPosition(start:entry.ball.position,legs:legs,at:elapsed)
                        node.opacity = CGFloat(max(0,min(1,1-(elapsed-end-TrajectoryPlayback.pocketPauseDuration)/TrajectoryPlayback.pocketFadeDuration)))
                    }
                    BallSpinIntegrator.advance(node:node,from:previousOmega[name] ?? state.angularVelocity,
                                               to:state.angularVelocity,dt:dt)
                    previousOmega[name] = state.angularVelocity
                }
                if wall < impact {
                    let pull = CueStroke.pullBack(at:max(0,(wall-2.0)),velocity:q[1])
                    scene.updateCueStick(cueBallPosition:strike,
                                         aimDirection:aim,pullBack:pull,elevationOverride:cueElevation)
                } else { scene.hideCueStick() }
                SCNTransaction.commit(); SCNTransaction.flush()
                let pots = completed + recorder.pocketEntries.filter { $0.time <= t }.count
                if keys.contains(i) || i % fps == 0 {
                    ledger.append(["frame":frame,"shot":shotIndex+1,"physicsTime":t,"pots":pots,
                        "aimVisible":wall < impact,"ghostVisible":scene.ghostBallNode?.isHidden == false,"cueXZ":[scene.allBallNodes[PositionPlayBall.cueKey]!.position.x,scene.allBallNodes[PositionPlayBall.cueKey]!.position.z]])
                }
                if exporting || keys.contains(i) {
                    let raw = renderer.snapshot(atTime:Double(frame)/Double(fps),with:size,antialiasingMode:.multisampling4X)
                    let image = compositor.image { context in
                        UIColor.black.setFill(); context.fill(CGRect(origin:.zero,size:size))
                        raw.draw(in:CGRect(origin:.zero,size:size))
                        context.cgContext.scaleBy(x:4.0/3.0,y:4.0/3.0)
                        if wall < impact {
                            // All overlays are in the 1080-wide reference canvas, rasterized natively at 2K.
                            let cg = context.cgContext
                            let disc = CGRect(x:215,y:teachingPanelY,width:140,height:140)
                            cg.setFillColor(UIColor.white.cgColor); cg.fillEllipse(in:disc)
                            cg.setStrokeColor(UIColor(red:0.82,green:0.10,blue:0.14,alpha:1).cgColor)
                            cg.setLineWidth(1); cg.setLineDash(phase:0,lengths:[])
                            cg.move(to:CGPoint(x:disc.midX,y:disc.minY)); cg.addLine(to:CGPoint(x:disc.midX,y:disc.maxY))
                            cg.move(to:CGPoint(x:disc.minX,y:disc.midY)); cg.addLine(to:CGPoint(x:disc.maxX,y:disc.midY)); cg.strokePath()
                            // Same true-scale contact mapping as BTSpinMiniIcon: positive spinX is left.
                            let radius = disc.width/2-3
                            let dx = -CGFloat(q[2]/CuePhysics.tipContactPullFactor)*radius
                            let dy = -CGFloat(q[3]/CuePhysics.tipContactPullFactor)*radius
                            let dot = 2*radius*CGFloat(CuePhysics.tipDiameter/BallPhysics.diameter)
                            cg.setFillColor(UIColor.systemOrange.cgColor)
                            cg.fillEllipse(in:CGRect(x:disc.midX+dx-dot/2,y:disc.midY+dy-dot/2,width:dot,height:dot))
                            let heading: [NSAttributedString.Key:Any] = [.font:UIFont.systemFont(ofSize:25,weight:.medium),.foregroundColor:UIColor.white]
                            ("母球打点" as NSString).draw(at:CGPoint(x:235,y:550),withAttributes:heading)
                            let targetDisc = CGRect(x:650,y:teachingPanelY,width:140,height:140)
                            cg.setFillColor(UIColor.systemOrange.cgColor); cg.fillEllipse(in:targetDisc)
                            let whiteDisc = targetDisc.offsetBy(dx:CGFloat(lateral)*140,dy:0)
                            cg.setFillColor(UIColor.white.withAlphaComponent(0.62).cgColor); cg.fillEllipse(in:whiteDisc)
                            cg.setStrokeColor(UIColor.white.cgColor); cg.setLineWidth(2); cg.strokeEllipse(in:whiteDisc)
                            let caption = String(format:"首碰 %d 号 · 切角 %.1f°",firstTarget,cutDegrees) as NSString
                            caption.draw(at:CGPoint(x:565,y:340),withAttributes:heading)
                            let overlapText = String(format:"重合 %.1f%% 球径",overlap*100) as NSString
                            overlapText.draw(at:CGPoint(x:620,y:550),withAttributes:heading)
                            ("沿来球方向看" as NSString).draw(at:CGPoint(x:643,y:590),withAttributes:[.font:UIFont.systemFont(ofSize:20),.foregroundColor:UIColor.lightGray])
                            let segment = CueClearance.shaftSegment(strikePosition:strike,aimDirection:aim,
                                elevation:cueElevation,pullBack:0)
                            let anchor = SCNVector3(segment.tip.x*0.75+segment.butt.x*0.25,
                                segment.tip.y*0.75+segment.butt.y*0.25,segment.tip.z*0.75+segment.butt.z*0.25)
                            let screen = renderer.projectPoint(anchor)
                            let text = String(format:"杆速 %.2f m/s",q[1]) as NSString
                            let attrs: [NSAttributedString.Key:Any] = [.font:UIFont.systemFont(ofSize:25,weight:.medium),.foregroundColor:UIColor.white]
                            let width = text.size(withAttributes:attrs).width
                            let px = min(1080-width-24,max(24,CGFloat(screen.x)*0.75+24))
                            let py = CGFloat(Float(size.height)-screen.y)*0.75-(shotIndex == 1 ? 125 : 42)
                            text.draw(at:CGPoint(x:px,y:py),withAttributes:attrs)
                        }
                    }
                    if keys.contains(i) { try XCTUnwrap(image.pngData()).write(to:out.appendingPathComponent(String(format:"frame-%04d.png",frame))) }
                    if let writer { try writer.append(try XCTUnwrap(image.cgImage)) }
                }
                frame += 1
                if frame % 120 == 0 { print("TWO SHOT VIDEO frame=\(frame)"); await Task.yield() }
            }
            for node in aimNodes { node.removeFromParentNode() }
            scene.ghostBallNode?.isHidden = true; scene.hideContactDot()
            for n in saved.pots { scene.allBallNodes["_\(n)"]?.isHidden = true }
            completed += saved.pots.count
        }
        if let writer { try await writer.finish() }
        try JSONSerialization.data(withJSONObject:["frames":frame,"fps":fps,"width":1440,"height":2560,
            "duration":Double(frame)/Double(fps),"exported":exporting,"shots":shotRecords,"ledger":ledger,
            "appearance":["charcoal","green","inkDragon"],"pitch":30,"cameraDistance":cameraDistance,"cameraPosition":[camera.position.x,camera.position.y,camera.position.z],"verticalFOV":40,"playbackRate":1,"teachingPanelY":teachingPanelY,"aimHoldSeconds":2,"overlays":"pre-impact only: spin/contact/ghost/paths/cue speed"],options:[.prettyPrinted,.sortedKeys])
            .write(to:out.appendingPathComponent("manifest.json"))
    }
}
