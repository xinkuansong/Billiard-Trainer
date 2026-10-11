import XCTest
import SceneKit
import CryptoKit
@testable import QiuJi

final class ModelAssetTrialTests: XCTestCase {
    private let assets: [(name: String, folder: String?, candidateSHA: String, originalSHA: String, triangles: Int)] = [
        ("TaiQiuZhuo", nil, "704bd98b17534c8046ab5027da63655e2867964760f893c1240a753742384586", "0e011ae72889d56a97255d8d69f2a7c0615ad779340ab64b938c2947817b48d1", 388569),
        ("CueUV", "CueStyles", "9288907e666d897e4f3be5b94e7ec989eb5a75116f74a07d3790e4340f2e117e", "ad24d3696bc78a02cb3a08a9c09af5f04c657a79404754d8b555c744ba429e7f", 10110)
    ]

    private func sha(_ url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
    }

    func testBundleSelectsLatestCandidatesAndRetainsOriginals() throws {
        for asset in assets {
            let candidate = try XCTUnwrap(ModelAssetTrial.url(asset.name, subdirectory: asset.folder))
            XCTAssertEqual(try sha(candidate), asset.candidateSHA, asset.name)
            let original = try XCTUnwrap(ModelAssetTrial.url(asset.name, subdirectory: asset.folder, useOriginal: true))
            XCTAssertEqual(try sha(original), asset.originalSHA, asset.name)
            XCTAssertNotEqual(candidate, original)
        }
    }

    // The protected original table/cue surfaces retain USD polygons.
    // Count their actual triangulated faces, as in the source asset audit.
    private func triangleCount(_ element: SCNGeometryElement) -> Int {
        switch element.primitiveType {
        case .triangles, .triangleStrip: return element.primitiveCount
        case .polygon:
            return element.data.withUnsafeBytes { raw in
                (0..<element.primitiveCount).reduce(0) { sum, index in
                    let offset = index * element.bytesPerIndex
                    let vertices: Int
                    switch element.bytesPerIndex {
                    case 1: vertices = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt8.self))
                    case 2: vertices = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                    case 4: vertices = Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
                    default: XCTFail("Unsupported polygon index size"); return sum
                    }
                    XCTAssertGreaterThanOrEqual(vertices, 3)
                    return sum + vertices - 2
                }
            }
        default: XCTFail("Unexpected non-surface primitive"); return 0
        }
    }

    func testCandidateImportsWithExpectedGeometry() throws {
        for asset in assets {
            let url = try XCTUnwrap(ModelAssetTrial.url(asset.name, subdirectory: asset.folder))
            let scene = try SCNScene(url: url, options: [.checkConsistency: true])
            var triangles = 0
            scene.rootNode.enumerateChildNodes { node, _ in
                for element in node.geometry?.elements ?? [] {
                    triangles += triangleCount(element)
                }
            }
            XCTAssertEqual(triangles, asset.triangles, asset.name)
        }
    }
}
