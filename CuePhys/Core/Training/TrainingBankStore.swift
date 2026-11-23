import CryptoKit
import Foundation

/// The current grid bank is the sole runtime source for all six scene quizzes.
/// Legacy proof banks remain offline evidence only; there is no runtime fallback.
enum TrainingBankStore {
    struct Manifest: Decodable {
        let schema: String
        let contentSHA256: String
        let counts: [String: Int]
        let qualification: [String: String]
    }
    private static let lock = NSLock()
    private static var cached: TrainingGridBank?

    static func load(bundle: Bundle = .main) throws -> TrainingGridBank {
        lock.lock()
        defer { lock.unlock() }
        if bundle == .main, let cached { return cached }
        guard let dataURL = bundle.url(forResource: "training-grid-bank", withExtension: "json"),
              let manifestURL = bundle.url(forResource: "training-grid-bank-manifest", withExtension: "json") else {
            throw TrainingQuestionBank.Failure.invalid("Missing current grid bank")
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
        let data = try Data(contentsOf: dataURL)
        let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard manifest.schema == "layout-bank-grid-v2-combination-ids", checksum == manifest.contentSHA256,
              manifest.qualification == ["corner": "geometry-candidate", "middle": "center-direct-five-v4"] else {
            throw TrainingQuestionBank.Failure.invalid("Grid manifest mismatch")
        }
        let bank = try TrainingGridBank(data: data, fingerprint: checksum)
        guard bank.payload.counts == manifest.counts else { throw TrainingQuestionBank.Failure.invalid("Manifest counts mismatch") }
        if bundle == .main { cached = bank }
        return bank
    }
}
