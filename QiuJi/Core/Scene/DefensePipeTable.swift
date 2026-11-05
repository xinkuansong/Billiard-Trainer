import Foundation
import SceneKit
import CryptoKit

/// Immutable target-only XZ lookup. Missing, stale or unsafe data falls back to
/// the production geometry scan. Angles are offsets from target -> pocket centre.
final class DefensePipeTable {
    struct Metadata: Decodable {
        struct Pocket: Decodable { let index: Int; let center: [Double] }
        let schema, binarySHA256, geometryFingerprint: String
        let x, z: [Double]
        let radius, length, width: Double
        let pockets: [Pocket]
        let recordCount, intervalByteOffset, intervalCount: Int
    }
    enum Invalid: Error { case resource, version, layout, checksum, geometry }
    static let shared: DefensePipeTable? = {
        do {
            guard let meta = Bundle.main.url(forResource: "pipe-grid", withExtension: "json", subdirectory: "PocketPipe"),
                  let binary = Bundle.main.url(forResource: "pipe-grid", withExtension: "bin", subdirectory: "PocketPipe") else { throw Invalid.resource }
            return try DefensePipeTable(metadata: Data(contentsOf: meta), binary: Data(contentsOf: binary))
        } catch {
            NSLog("DefensePipeTable: exact geometry fallback: %@", String(describing: error))
            return nil
        }
    }()
    let metadata: Metadata
    private let words: [UInt32]
    init(metadata data: Data, binary: Data) throws {
        guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == "5e0fc32f18c9b92deaaa30c25409cb42b9d54b1d6c1cd11bdca975afc2cd5186" else { throw Invalid.checksum }
        let m = try JSONDecoder().decode(Metadata.self, from: data)
        guard m.schema == "target-pipe-grid-v1",
              m.geometryFingerprint == "b5f48d12f01cea73c47139602220d4e572c35ec58484060d9bbe27c1b9096881" else { throw Invalid.version }
        guard m.x.count == 256, m.z.count == 129, m.recordCount == 198144,
              m.intervalCount == 156816, m.intervalByteOffset == m.recordCount * 8,
              binary.count == m.intervalByteOffset + m.intervalCount * 8,
              m.x.allSatisfy(\.isFinite), m.z.allSatisfy(\.isFinite),
              zip(m.x,m.x.dropFirst()).allSatisfy({ $0 < $1 }),
              zip(m.z,m.z.dropFirst()).allSatisfy({ $0 < $1 }) else { throw Invalid.layout }
        let hash = SHA256.hash(data: binary).map { String(format: "%02x", $0) }.joined()
        guard hash == m.binarySHA256,
              hash == "fb0a930afe75462f6f60100dd03ed6c2a6fc6a45a4f4415e7340b295b201173d" else { throw Invalid.checksum }
        let pockets = AngleSceneCalculator.pocketPositions(surfaceY: 0)
        guard m.radius == Double(AngleSceneCalculator.ballRadius),
              m.length == Double(AngleSceneCalculator.innerLength), m.width == Double(AngleSceneCalculator.innerWidth),
              m.pockets.count == 6, m.pockets.enumerated().allSatisfy({ i, p in
                  p.index == i && p.center == [Double(pockets[i].x),Double(pockets[i].z)]
              }) else { throw Invalid.geometry }
        self.metadata = m
        self.words = binary.withUnsafeBytes { raw in
            (0..<(binary.count / 4)).map { UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: $0 * 4, as: UInt32.self)) }
        }
    }
    private func interval(_ ix: Int, _ iz: Int, _ pocket: Int) -> (Double, Double)? {
        let i = ((ix * metadata.z.count + iz) * 6 + pocket) * 2
        let offset = Int(words[i]), count = Int(words[i+1] & 65535), flags = words[i+1] >> 16
        // Zero and topology boundaries always defer, including exact grid zeros.
        guard flags == 7, count == 1, offset < metadata.intervalCount else { return nil }
        let j = metadata.intervalByteOffset / 4 + offset * 2
        let a = Double(Float(bitPattern: words[j])), b = Double(Float(bitPattern: words[j+1]))
        return a.isFinite && b.isFinite && b > a ? (a,b) : nil
    }
    private func cell(_ axis: [Double], _ value: Double) -> Int {
        var lo = 0, hi = axis.count - 1
        while hi - lo > 1 { let mid = (lo + hi) / 2; if axis[mid] <= value { lo = mid } else { hi = mid } }
        return lo
    }
    func window(_ target: SCNVector3, pocket: Int) -> [String: Any]? {
        let x = Double(target.x), z = Double(target.z), m = metadata
        guard (0..<6).contains(pocket), x.isFinite, z.isFinite,
              x >= m.x[0], x <= m.x.last!, z >= m.z[0], z <= m.z.last! else { return nil }
        let ix = cell(m.x,x), iz = cell(m.z,z)
        let bounds = [(ix,iz),(ix+1,iz),(ix,iz+1),(ix+1,iz+1)].compactMap { interval($0.0,$0.1,pocket) }
        guard bounds.count == 4 else { return nil }
        let left = bounds.map(\.0), right = bounds.map(\.1), widths = bounds.map { $1-$0 }
        guard max(left.max()!-left.min()!, right.max()!-right.min()!) <= 0.1,
              (widths.max()!-widths.min()!)/widths.min()! <= 0.1 else { return nil }
        let u = (x-m.x[ix])/(m.x[ix+1]-m.x[ix]), v = (z-m.z[iz])/(m.z[iz+1]-m.z[iz])
        let weights = [(1-u)*(1-v),u*(1-v),(1-u)*v,u*v]
        let a = zip(weights,left).reduce(0) { $0+$1.0*$1.1 }, b = zip(weights,right).reduce(0) { $0+$1.0*$1.1 }
        // Match the owning calculator's Float subtraction before conversion.
        let pc = AngleSceneCalculator.pocketPositions(surfaceY: 0)[pocket]
        return ["baseRadians": atan2(Double(pc.z-target.z),Double(pc.x-target.x)),
                "intervals": [["leftDegrees":a,"rightDegrees":b,"widthDegrees":b-a]],
                "precomputed": true]
    }
}
