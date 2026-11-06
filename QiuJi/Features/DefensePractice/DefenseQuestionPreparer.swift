import Foundation
import SceneKit
import CryptoKit
import zlib

extension DefenseBankQuestion {
    var cueVector: SCNVector3 { .init(Float(cue[0]), 0, Float(cue[1])) }
    var ownVector: SCNVector3 { let p = balls.first { $0.number == ownBallNumber }!.position; return .init(Float(p[0]), 0, Float(p[1])) }
    var keys: [String] { balls.map { "_\($0.number)" } }
    var isValid: Bool {
        func valid(_ p: [Double]) -> Bool { p.count == 2 && p.allSatisfy(\.isFinite) && abs(p[0]) <= 1.3 && abs(p[1]) <= 0.67 }
        return valid(cue) && !balls.isEmpty && balls.count <= 3 && balls.allSatisfy { valid($0.position) && (1...15).contains($0.number) }
            && Set(balls.map(\.number)).count == balls.count && balls.contains { $0.number == ownBallNumber }
            && balls.contains { $0.number == opponentBallNumber } && DefenseKind(rawValue: kind) != nil
    }
}
/// Reference-content constraint only; player shots retain normal billiards rules.
enum DefenseReferenceRoute {
    /// Production TableGeometry constructs its six main straight rails first.
    /// Subsequent indices are pocket jaws, fillets and throat walls.
    static func isMainCushion(_ index: Int?) -> Bool {
        guard let index else { return false }
        return (0..<6).contains(index)
    }
    static func allows(_ events: [DefenseBankQuestion.Reference.Expected.Event]) -> Bool {
        events.allSatisfy {
            if $0.kind == "cushion" { return isMainCushion($0.railIndex) }
            if $0.kind == "ballBall" { return $0.ballNumbers.contains(0) }
            return true
        }
    }
}
enum DefenseBankStore {
    struct Bank: Decodable { let schema, sourceFingerprint: String; let questions: [DefenseBankQuestion] }
    enum Failure: LocalizedError {
        case invalid(String)
        var errorDescription: String? { switch self { case .invalid(let text): "防守练习暂不可用：" + text } }
    }
    static let trajectoryDigest = "3e536a50dfbd1ef7ff1563b42d836f2f7cc6aba625acc0775aece55c9765af15"
    static func fingerprint(for mode: DefenseMode) -> String {
        mode == .trajectory ? "defense-trajectories-v2:" + trajectoryDigest : "defense-no-object-contact-v5-3511-58470-0439ec02-786c3a90"
    }
    struct Entry: Decodable { let id, kind: String; let offset, size: Int }
    private struct Archive {
        let bytes: Data
        let entries: [Entry]
        let start: Int
        init() throws {
            bytes = try DefenseBankStore.data("defense-trajectories", "bank", sha: trajectoryDigest)
            guard bytes.count >= 8, bytes.prefix(4) == Data("DFT2".utf8) else { throw Failure.invalid("轨迹题库格式有误") }
            start = 8 + bytes[4..<8].reduce(0) { $0 * 256 + Int($1) }
            guard start <= bytes.count else { throw Failure.invalid("轨迹索引损坏") }
            entries = try JSONDecoder().decode([Entry].self, from: bytes[8..<start])
            var offset = 0
            for e in entries {
                guard e.offset == offset, e.size > 0, e.size <= bytes.count-start-offset,
                      DefenseKind(rawValue: e.kind) != nil else { throw Failure.invalid("轨迹索引损坏") }
                offset += e.size
            }
            guard offset == bytes.count-start, !entries.isEmpty, Set(entries.map(\.id)).count == entries.count else { throw Failure.invalid("轨迹索引不完整") }
        }
        func question(_ entry: Entry) throws -> DefenseBankQuestion {
            let offset = start + entry.offset
            let data = try DefenseBankStore.gunzip(bytes.subdata(in: offset..<offset+entry.size))
            let q = try JSONDecoder().decode(DefenseBankQuestion.self, from: data)
            guard q.isValid, q.id == entry.id, q.kind == entry.kind, q.references.count >= 2 else { throw Failure.invalid("轨迹题损坏") }
            return q
        }
    }
    private static let trajectory = Result { try Archive() }
    private static let free: Result<[DefenseBankQuestion], Error> = Result {
        let raw = try data("defense-free-bank.json", "gz", sha: "786c3a909b70a22c749ded7757bda2ab7f5f8a6122745e7553074923a38df7c1")
        return try validate(JSONDecoder().decode([DefenseBankQuestion].self, from: gunzip(raw)))
    }
    private static func data(_ name: String, _ ext: String, sha: String) throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { throw Failure.invalid("未找到题库") }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == sha else { throw Failure.invalid("题库校验失败") }
        return data
    }
    /// Immutable cache initialization cannot inherit a cancelled caller's failure.
    /// Selection checks cancellation after loading; malformed/oversized data still fails closed.
    private static func gunzip(_ input: Data) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, 15+32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw Failure.invalid("解压初始化失败") }
        defer { inflateEnd(&stream) }
        return try input.withUnsafeBytes { bytes in
            stream.next_in = UnsafeMutablePointer(mutating: bytes.bindMemory(to:Bytef.self).baseAddress)
            stream.avail_in = uInt(input.count)
            var result = Data(), buffer = [UInt8](repeating:0,count:65536)
            var status: Int32 = Z_OK
            repeat {
                status = buffer.withUnsafeMutableBytes { out in
                    stream.next_out = out.bindMemory(to:Bytef.self).baseAddress; stream.avail_out = uInt(out.count)
                    return inflate(&stream,Z_NO_FLUSH)
                }
                guard status == Z_OK || status == Z_STREAM_END else { throw Failure.invalid("压缩数据损坏") }
                result.append(contentsOf:buffer.prefix(buffer.count-Int(stream.avail_out)))
                guard result.count <= 32_000_000 else { throw Failure.invalid("题库过大") }
            } while status != Z_STREAM_END
            guard stream.avail_in == 0 else { throw Failure.invalid("压缩尾部异常") }
            return result
        }
    }
    private static func validate(_ rows: [DefenseBankQuestion]) throws -> [DefenseBankQuestion] {
        guard !rows.isEmpty, rows.allSatisfy(\.isValid), Set(rows.map(\.id)).count == rows.count else { throw Failure.invalid("题库格式有误") }
        return rows
    }
    static func entries(_ mode: DefenseMode) throws -> [Entry] {
        if mode == .trajectory { return try trajectory.get().entries }
        return try freeEntries.get()
    }
    private static let freeEntries = Result { try free.get().enumerated().map { Entry(id: $1.id, kind: $1.kind, offset: $0, size: 0) } }
    static func question(_ entry: Entry, mode: DefenseMode) throws -> DefenseBankQuestion {
        if mode == .trajectory { return try trajectory.get().question(entry) }
        return try free.get()[entry.offset]
    }
    static func load(_ mode: DefenseMode) throws -> [DefenseBankQuestion] {
        if mode == .free { return try free.get() }
        return try entries(mode).map { try question($0, mode: mode) }
    }
}
enum DefenseQuestionPreparer {
    struct Prepared { let fingerprint: String; let question: DefenseQuestion }
    static func prepare(_ configuration: DefenseConfiguration, excluding: Set<String> = [], lastContentID: String? = nil,
                        seed: UInt64 = .random(in: 0...UInt64.max)) throws -> Prepared {
        let bank = try DefenseBankStore.entries(configuration.mode)
        #if DEBUG
        let seed = ProcessInfo.processInfo.arguments.contains("-defense.fixedSeed") ? UInt64(7) : seed
        #endif
        var random = SceneTrainingGenerator.SeededRandom(state: seed)
        let matching = bank.filter { configuration.kind == nil || $0.kind == configuration.kind?.rawValue }
        let unseen = matching.filter { !excluding.contains($0.id) }
        var candidates = unseen.isEmpty ? matching.filter { $0.id != lastContentID } : unseen
        // All practice banks follow the confirmed filter-then-random contract.
        // Each eligible unseen question has equal weight; no kind quotas.
        candidates.shuffle(using: &random)
        for entry in candidates.prefix(32) {
            let source = try DefenseBankStore.question(entry, mode: configuration.mode)
            try Task.checkCancellation()
            if configuration.mode == .free {
                return .init(fingerprint: DefenseBankStore.fingerprint(for: configuration.mode), question: .init(id: UUID(), source: source, referenceIndex: nil, referencePaths: [:]))
            }
            for index in source.references.indices {
                do {
                    let prediction = try verified(source: source, reference: source.references[index], surfaceY: 0.8, profile: AccuracyTipSelector.renderedProfile())
                    var paths = [String: [SeparationTrajectory.Point]]()
                    for name in [ShotInput.cueBallName] + source.keys { paths[name] = try SeparationTrajectory.extractBall(prediction, name: name) }
                    return .init(fingerprint: DefenseBankStore.fingerprint(for: configuration.mode), question: .init(id: UUID(), source: source, referenceIndex: index, referencePaths: paths))
                } catch is CancellationError { throw CancellationError() }
                catch { continue }
            }
        }
        throw DefenseBankStore.Failure.invalid("当前筛选暂无可用题目，请放宽条件后重试。")
    }
    /// Both first draw and every alternate demonstration use this same physical replay contract.
    static func verified(source: DefenseBankQuestion, reference r: DefenseBankQuestion.Reference,
                         surfaceY: Float, profile: [CueSection]) throws -> ShotPrediction {
        let p = r.parameters
        guard p.direction.count == 2, r.quality != nil else { throw DefenseBankStore.Failure.invalid("参考杆缺少参数") }
        let prediction = try simulate(source: source, input: .init(spinX: Float(p.spinX), spinY: Float(p.spinY), velocity: Float(p.velocity)),
            direction: .init(Float(p.direction[0]), 0, Float(p.direction[1])), surfaceY: surfaceY, profile: profile)
        guard prediction.hasFinalTableState, DefenseEffect.failure(source, prediction) == nil,
              eventsMatch(prediction, r.expected.events), prediction.pocketedBalls.isEmpty,
              r.expected.pocketedBallNumbers.isEmpty,
              Set(r.expected.finalBalls.map(\.number)) == Set([0] + source.balls.map(\.number)),
              r.expected.finalBalls.allSatisfy({ b in
                  guard b.position.count == 2, let v = prediction.finalPositions[b.number == 0 ? ShotInput.cueBallName : "_\(b.number)"] else { return false }
                  return hypot(Double(v.x)-b.position[0], Double(v.z)-b.position[1]) <= 0.002
              }) else { throw DefenseBankStore.Failure.invalid("参考杆的碰撞或落点未能重现") }
        let effect = try DefenseEffect.evaluate(question: source, prediction: prediction)
        guard let score = effect.score, score >= 80 else { throw DefenseBankStore.Failure.invalid("参考杆未达到防守分门槛") }
        return prediction
    }

    static func eventsMatch(_ prediction: ShotPrediction, _ expected: [DefenseBankQuestion.Reference.Expected.Event]) -> Bool {
        guard prediction.events.count == expected.count else { return false }
        func number(_ name: String) -> Int { name == ShotInput.cueBallName ? 0 : Int(name.dropFirst()) ?? -1 }
        for (actual, stored) in zip(prediction.events, expected) {
            switch actual.kind {
            case .ballBall(let a, let b):
                guard a == ShotInput.cueBallName || b == ShotInput.cueBallName,
                      stored.kind == "ballBall", Set(stored.ballNumbers) == Set([number(a),number(b)]) else { return false }
            case .ballCushion(let ball):
                guard DefenseReferenceRoute.isMainCushion(actual.cushionIndex),
                      stored.kind == "cushion", stored.ballNumbers == [number(ball)], stored.railIndex == actual.cushionIndex else { return false }
            case .pocket(let ball, let id):
                guard stored.kind == "pocket", stored.ballNumbers == [number(ball)], stored.pocketIndex == Int(id.replacingOccurrences(of:"pocket_",with:"")) else { return false }
            }
        }
        return true
    }
    static func solve(question: DefenseQuestion, input: SeparationInput, direction: SCNVector3, surfaceY: Float, profile: [CueSection]) throws -> ShotPrediction {
        try simulate(source: question.source, input: input, direction: direction, surfaceY: surfaceY, profile: profile)
    }
    static func simulate(source: DefenseBankQuestion, input: SeparationInput, direction: SCNVector3, surfaceY: Float, profile: [CueSection]) throws -> ShotPrediction {
        guard source.isValid, input.isValid, direction.x.isFinite, direction.z.isFinite, abs(hypot(direction.x, direction.z)-1) < 0.0001 else { throw DefenseBankStore.Failure.invalid("击球参数有误") }
        let y = surfaceY + BallPhysics.radius
        let cue = SCNVector3(source.cueVector.x, y, source.cueVector.z)
        let balls = source.balls.map { ObstacleBall(name: "_\($0.number)", position: .init(Float($0.position[0]), y, Float($0.position[1]))) }
        let access = CueStrikeAccess(cue: cue, aim: direction, obstacles: balls.map(\.position), surfaceY: surfaceY, profile: profile)
        guard access.isAvailable(spinX: Double(input.spinX), spinY: Double(input.spinY)), access.resolvedPose(spinX: Double(input.spinX), spinY: Double(input.spinY)) != nil else { throw SeparationQuestionGenerator.Failure.inaccessible }
        return ShotPredictor.simulateFree(cueBall: cue, aimDir: direction, velocity: input.velocity, spinX: input.spinX, spinY: input.spinY,
            surfaceY: surfaceY, balls: balls, maxEvents: 1500, maxTime: 60, simulationModel: .planarReference, recordedStrikeDirection: direction)
    }
}
