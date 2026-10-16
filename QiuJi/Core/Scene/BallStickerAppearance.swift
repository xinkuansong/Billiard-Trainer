import SceneKit
import UIKit
import CryptoKit
import os

/// Generated albedo on two opposite spherical caps. Corrects the original
/// folded back UVs once while retaining every position/normal and face.
enum BallStickerAppearance {
    private static let logger = Logger(subsystem: "com.xinkuan.qiuji", category: "BallStickerAppearance")
    private static let images = TableAssetImageCache(byteLimit: 36 * 1024 * 1024)
    private static let uvLock = NSLock()
    private static var uvCache: [String: SCNGeometry] = [:]
    private static var uvCosts: [String: Int] = [:]
    private static var uvRecent: [String] = []
    private static let uvByteLimit = 64 * 1024 * 1024
    static var retainedUVBytes: Int { uvLock.lock(); defer { uvLock.unlock() }; return uvCosts.values.reduce(0, +) }
    static var retainedImageBytes: Int { images.retainedBytes }

    static func resetCache() {
        images.reset()
        uvLock.lock(); defer { uvLock.unlock() }
        uvCache.removeAll(); uvCosts.removeAll(); uvRecent.removeAll()
    }

    static func image(named name: String) -> UIImage? {
        images.image(for: name) {
            guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "BallStickers"),
                  let image = UIImage(contentsOfFile: url.path) else {
                logger.error("Missing ball sticker asset: \(name, privacy: .public)")
                return nil
            }
            return image
        }
    }

    static func apply(_ style: BallStickerStyle, to balls: [String: SCNNode]) -> Bool {
        // Resolve the complete set before mutating materials; a missing resource
        // must not leave one table displaying a mixture of styles.
        var resolved: [(SCNNode, UIImage, String)] = []
        for number in 1...15 {
            guard let ball = balls["_\(number)"] else { continue }
            guard let image = image(named: style.textureName(number: number)) else { return false }
            resolved.append((ball, image, "_\(number)"))
        }
        for (ball, image, number) in resolved {
            func applyToNode(_ node: SCNNode) throws {
                if let geometry = node.geometry, !(geometry.name ?? "").hasSuffix(".BallStickerUV.v2") {
                    node.geometry = try cachedSphericalUVs(geometry, number: number)
                }
                node.geometry?.materials.forEach {
                    $0.diffuse.contents = image
                    $0.multiply.contents = UIColor.white
                    $0.roughness.contents = Float(0.12)
                    $0.diffuse.wrapS = .repeat
                    $0.diffuse.wrapT = .clamp
                }
                try node.childNodes.forEach(applyToNode)
            }
            do { try applyToNode(ball) }
            catch {
                logger.error("Ball sticker UV mapping failed: \(String(describing: error), privacy: .public)")
                return false
            }
        }
        return true
    }

    /// Key includes every source/index byte and layout, the model identity,
    /// ball's orientation frame and unwrap revision. No material or pose is shared.
    private static func cachedSphericalUVs(_ geometry: SCNGeometry, number: String) throws -> SCNGeometry {
        var hash = SHA256()
        func add(_ value: String) { hash.update(data: Data(value.utf8)); hash.update(data: Data([0])) }
        add(ModelAssetTrial.identity("TaiQiuZhuo")); add("BallStickerUV.v2"); add(number)
        if let frame = frames[number] { add(String(describing: frame.front)); add(String(describing: frame.up)) }
        for source in geometry.sources {
            add("\(source.semantic.rawValue)|\(source.vectorCount)|\(source.usesFloatComponents)|\(source.bytesPerComponent)|\(source.componentsPerVector)|\(source.dataOffset)|\(source.dataStride)")
            hash.update(data: source.data)
        }
        add(String(describing: geometry.geometrySourceChannels))
        for element in geometry.elements {
            add("\(element.primitiveType.rawValue)|\(element.primitiveCount)|\(element.bytesPerIndex)|\(element.indicesChannelCount)")
            hash.update(data: element.data)
        }
        let key = hash.finalize().map { String(format: "%02x", $0) }.joined()
        uvLock.lock(); defer { uvLock.unlock() }
        let prepared: SCNGeometry
        if let found = uvCache[key] { prepared = found }
        else {
            prepared = try sphericalUVs(geometry, number: number)
            prepared.materials = []
            let cost = prepared.sources.reduce(0) { $0 + $1.data.count }
                + prepared.elements.reduce(0) { $0 + $1.data.count }
            if cost <= uvByteLimit { uvCache[key] = prepared; uvCosts[key] = cost }
        }
        uvRecent.removeAll { $0 == key }
        if uvCache[key] != nil { uvRecent.append(key) }
        while uvCosts.values.reduce(0, +) > uvByteLimit, !uvRecent.isEmpty {
            let old = uvRecent.removeFirst(); uvCache.removeValue(forKey: old); uvCosts.removeValue(forKey: old)
        }
        let result = prepared.copy() as! SCNGeometry
        result.materials = geometry.materials
        return result
    }

    private struct Frame: Decodable { let front: [Float]; let up: [Float] }
    private static let frames: [String: Frame] = {
        do {
            guard let url = Bundle.main.url(forResource: "BallStickerUVFrames", withExtension: "json", subdirectory: "BallStickers") else {
                throw UVFailure.missingFrames
            }
            return try JSONDecoder().decode([String: Frame].self, from: Data(contentsOf: url))
        } catch {
            logger.error("Missing ball sticker UV frames: \(String(describing: error), privacy: .public)")
            return [:]
        }
    }()
    private enum UVFailure: Error { case missingFrames, unsupportedGeometry }

    /// Spherical unwrap matches the Blender authoring script. Each face gets
    /// its own UV corner indices; existing position/normal indices stay intact.
    private static func sphericalUVs(_ geometry: SCNGeometry, number: String) throws -> SCNGeometry {
        guard let frame = frames[number], frame.front.count == 3, frame.up.count == 3,
              let positionIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }),
              let uvIndex = geometry.sources.firstIndex(where: { $0.semantic == .texcoord }) else {
            throw UVFailure.unsupportedGeometry
        }
        let source = geometry.sources[positionIndex]
        guard source.usesFloatComponents, source.bytesPerComponent == 4, source.componentsPerVector >= 3 else {
            throw UVFailure.unsupportedGeometry
        }
        let channels = geometry.geometrySourceChannels ?? geometry.sources.map { _ in NSNumber(value: 0) }
        let positionChannel = channels[positionIndex].intValue
        let oldCount = (channels.map(\.intValue).max() ?? 0) + 1
        let front = simd_normalize(SIMD3<Float>(frame.front[0], frame.front[1], frame.front[2]))
        let up = simd_normalize(SIMD3<Float>(frame.up[0], frame.up[1], frame.up[2]))
        let right = simd_normalize(simd_cross(up, front))
        var positions: [SIMD3<Float>] = []
        for i in 0..<source.vectorCount {
            let start = source.dataOffset + i * source.dataStride
            guard start >= 0, start + 12 <= source.data.count else { throw UVFailure.unsupportedGeometry }
            positions.append(source.data.withUnsafeBytes { bytes in
                SIMD3<Float>(bytes.loadUnaligned(fromByteOffset: start, as: Float.self),
                             bytes.loadUnaligned(fromByteOffset: start + 4, as: Float.self),
                             bytes.loadUnaligned(fromByteOffset: start + 8, as: Float.self))
            })
        }
        guard let first = positions.first else { throw UVFailure.unsupportedGeometry }
        let low = positions.reduce(first) { simd_min($0, $1) }
        let high = positions.reduce(first) { simd_max($0, $1) }
        let center = (low + high) / 2
        var coordinates: [SIMD2<Float>] = []
        var elements: [SCNGeometryElement] = []
        for element in geometry.elements {
            guard element.indicesChannelCount == oldCount else { throw UVFailure.unsupportedGeometry }
            var remapped: [[UInt32]] = []
            // Existing lossless decoder supports SceneKit polygon/multi-index USD meshes.
            for face in try PocketLeatherMesh.decode(element) {
                var uv: [SIMD2<Float>] = []; var poles: [Bool] = []
                for corner in stride(from: 0, to: face.count, by: oldCount) {
                    let index = Int(face[corner + positionChannel])
                    guard positions.indices.contains(index) else { throw UVFailure.unsupportedGeometry }
                    let n = simd_normalize(positions[index] - center)
                    let x = simd_dot(n, right), y = max(-1, min(1, simd_dot(n, up))), z = simd_dot(n, front)
                    // SceneKit image V starts at the top; Blender UV V starts
                    // at the bottom. Explicit new SCN UVs need this conversion.
                    uv.append(SIMD2<Float>(atan2(z, x) / (2 * .pi) + 0.5, 0.5 - asin(y) / .pi))
                    poles.append(abs(y) > 0.9999)
                }
                let ordinary = uv.indices.filter { !poles[$0] }
                guard !ordinary.isEmpty else { throw UVFailure.unsupportedGeometry }
                if ordinary.map({ uv[$0].x }).max()! - ordinary.map({ uv[$0].x }).min()! > 0.5 {
                    for i in uv.indices where uv[i].x < 0.5 { uv[i].x += 1 }
                }
                let mean = ordinary.reduce(Float(0)) { $0 + uv[$1].x } / Float(ordinary.count)
                var newFace: [UInt32] = []
                for i in uv.indices {
                    if poles[i] { uv[i].x = mean }
                    newFace.append(contentsOf: face[(i * oldCount)..<((i + 1) * oldCount)])
                    newFace.append(UInt32(coordinates.count)); coordinates.append(uv[i])
                }
                remapped.append(newFace)
            }
            elements.append(PocketLeatherMesh.makeElement(faces: remapped, channelCount: oldCount + 1))
        }
        let data = coordinates.withUnsafeBufferPointer { Data(buffer: $0) }
        var sources = geometry.sources
        sources[uvIndex] = SCNGeometrySource(data: data, semantic: .texcoord, vectorCount: coordinates.count,
            usesFloatComponents: true, componentsPerVector: 2, bytesPerComponent: 4,
            dataOffset: 0, dataStride: MemoryLayout<SIMD2<Float>>.stride)
        var updatedChannels = channels; updatedChannels[uvIndex] = NSNumber(value: oldCount)
        let result = SCNGeometry(sources: sources, elements: elements, sourceChannels: updatedChannels)
        result.name = (geometry.name ?? "Ball") + ".BallStickerUV.v2"
        result.materials = geometry.materials
        return result
    }
}
