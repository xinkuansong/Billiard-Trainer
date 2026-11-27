import Foundation
import SceneKit
import CryptoKit
import zlib

struct SpatialQuizQuestion: Codable, Equatable, Identifiable {
    struct Point: Codable, Equatable {
        let x, z: Double
        var position: SCNVector3 { .init(Float(x), BTTablePhysics.surfaceY + BallPhysics.radius, Float(z)) }
    }
    let id: String
    let mode: SpatialQuizMode
    let sourceLayoutID, sourceID, runIdentity, sourcePacketSHA256: String
    let cue, target, obstacle: Point
    let targetNumber: Int
    let s, q: Double
    let side: Int
    let distance: Double
    let reference: SpatialQuizPhysics.Input
    let referencePocket: Int
    var board: SpatialQuizPhysics.Board { .init(cue: cue.position, target: target.position,
        obstacle: obstacle.position, targetNumber: targetNumber, mode: mode) }
    var distanceBin: Int { Int(distance * 2) }
    func referenceAccessible(profile: [CueSection]) -> Bool {
        CueStrikeAccess(cue: board.cue, aim: reference.aim, obstacles: [board.target, board.obstacle],
            surfaceY: BTTablePhysics.surfaceY, profile: profile, fixedElevation: reference.radians)
            .isAvailable(spinX: reference.spinX, spinY: reference.spinY)
    }
}

struct SpatialQuizFilter: Codable, Equatable {
    var distanceBin: Int? = nil
    var s: Double? = nil
    var q: Double? = nil
    func accepts(_ question: SpatialQuizQuestion) -> Bool {
        (distanceBin == nil || distanceBin == question.distanceBin) &&
        (s == nil || s == question.s) && (q == nil || q == question.q)
    }
}

enum SpatialQuizBank {
    struct Manifest: Codable {
        struct Verification: Codable {
            let candidateSHA256, auditSHA256: String
            let planned, completed, passed, failed, unconfirmed: Int
        }
        let version: Int
        let mode: SpatialQuizMode
        let physics, judgement, geometry, file, sha256: String
        let count: Int
        let sourceSHA256, runIdentity: String
        let distanceBins: [Int]
        let sValues, qValues: [Double]
        let verification: Verification
    }
    struct Bank {
        let manifest: Manifest
        let questions: [SpatialQuizQuestion]
        var fingerprint: String { manifest.sha256 }
        func draw(count: Int, filter: SpatialQuizFilter, excluding: Set<String> = []) throws -> [SpatialQuizQuestion] {
            let candidates = questions.filter { filter.accepts($0) && !excluding.contains($0.id) }
            guard count > 0, candidates.count >= count else { throw Failure.invalid("当前条件题目不足，请调整条件或重新开始") }
            #if DEBUG
            if ProcessInfo.processInfo.environment["SPATIAL_BENCHMARK_MODE"] != nil {
                return Array(candidates.prefix(count))
            }
            #endif
            return Array(candidates.shuffled().prefix(count))
        }
    }
    enum Failure: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
    }
    static func load(_ mode: SpatialQuizMode, bundle: Bundle = .main) throws -> Bank {
        guard let root = bundle.resourceURL?.appendingPathComponent("SpatialQuizBank") else {
            throw Failure.invalid("SpatialQuizBank：资源目录缺失")
        }
        return try load(mode, root: root)
    }
    static func load(_ mode: SpatialQuizMode, root: URL) throws -> Bank {
        let name = "\(mode.rawValue)-manifest.json"
        do {
            let manifest = try decode(Manifest.self, data: Data(contentsOf: root.appendingPathComponent(name)), resource: name)
            guard manifest.version == 1, manifest.mode == mode, manifest.physics == "spatialPractice",
                  manifest.judgement == SpatialQuizJudgement.referenceAdmissionVersion, manifest.geometry == SpatialPracticeGeometry.version,
                  manifest.file == "\(mode.rawValue).json.gz", manifest.count >= 15,
                  manifest.verification.planned == manifest.verification.completed,
                  manifest.verification.passed == manifest.count,
                  manifest.verification.failed >= 0, manifest.verification.unconfirmed >= 0,
                  manifest.verification.passed + manifest.verification.failed + manifest.verification.unconfirmed == manifest.verification.completed,
                  validHash(manifest.verification.candidateSHA256), validHash(manifest.verification.auditSHA256),
                  validHash(manifest.sha256), validHash(manifest.sourceSHA256), validHash(manifest.runIdentity) else {
                throw Failure.invalid("\(name)：版本、模式或来源不兼容")
            }
            let compressed = try Data(contentsOf: root.appendingPathComponent(manifest.file))
            guard digest(compressed) == manifest.sha256 else { throw Failure.invalid("\(manifest.file)：SHA256不一致") }
            let questions = try decode([SpatialQuizQuestion].self, data: gunzip(compressed), resource: manifest.file)
            try validate(questions, manifest: manifest)
            return .init(manifest: manifest, questions: questions)
        } catch let error as Failure { throw error }
        catch { throw Failure.invalid("\(name)：\(error.localizedDescription)") }
    }
    static func validate(_ questions: [SpatialQuizQuestion], manifest: Manifest) throws {
        guard questions.count == manifest.count, Set(questions.map(\.id)).count == questions.count else {
            throw Failure.invalid("\(manifest.file)：数量或重复ID异常")
        }
        for (index, question) in questions.enumerated() {
            let finite = [question.cue.x,question.cue.z,question.target.x,question.target.z,
                          question.obstacle.x,question.obstacle.z,question.s,question.q,question.distance].allSatisfy(\.isFinite)
            guard finite, question.board.valid, question.reference.valid, question.mode == manifest.mode,
                  question.id == "spatial-v1-\(manifest.mode.rawValue)-\(question.sourceLayoutID)",
                  !question.sourceLayoutID.isEmpty, !question.sourceID.isEmpty,
                  question.runIdentity == manifest.runIdentity, validHash(question.sourcePacketSHA256),
                  (0...1).contains(question.s), (0...1).contains(question.q), (-1...1).contains(question.side),
                  (0..<6).contains(question.referencePocket), question.distance > 0,
                  abs(question.distance - hypot(question.cue.x-question.target.x,question.cue.z-question.target.z)) < 1e-9 else {
                throw Failure.invalid("\(manifest.file)[\(index)]：球形、身份或参考参数无效")
            }
        }
        guard Set(manifest.distanceBins) == Set(questions.map(\.distanceBin)),
              Set(manifest.sValues) == Set(questions.map(\.s)), Set(manifest.qValues) == Set(questions.map(\.q)) else {
            throw Failure.invalid("\(manifest.file)：筛选分层与题目不一致")
        }
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func validHash(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }
    private static func decode<T: Decodable>(_ type: T.Type, data: Data, resource: String) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw Failure.invalid("\(resource)：\(String(describing: error))") }
    }
    private static func gunzip(_ input: Data) throws -> Data {
        guard input.count <= 16_000_000 else { throw Failure.invalid("题包超过压缩大小限制") }
        var stream = z_stream()
        guard inflateInit2_(&stream, 15+32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw Failure.invalid("题包解压初始化失败")
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
                guard status == Z_OK || status == Z_STREAM_END else { throw Failure.invalid("题包压缩损坏") }
                result.append(contentsOf: buffer.prefix(buffer.count-Int(stream.avail_out)))
                guard result.count <= 32_000_000 else { throw Failure.invalid("题包解压过大") }
            } while status != Z_STREAM_END
            guard stream.avail_in == 0 else { throw Failure.invalid("题包压缩尾部异常") }
            return result
        }
    }
}
