import SceneKit
import os

/// Align only the rendered bed and its printed marks with the existing physical plane.
/// The USDZ, positions, ball radius, pockets, rails, and collision model stay unchanged.
enum MobileClothAlignment {
    private static let logger = Logger(subsystem: "com.xinkuan.qiuji", category: "MobileClothAlignment")

    static func apply(to scene: AngleTrainingScene) {
        do {
            guard let bedY = try measuredBedY(in: scene) else {
                logger.error("No horizontal cloth polygon at table center; preserving original surface")
                return
            }
            let lift = scene.surfaceY - bedY
            // Calibration is for a small import discrepancy, not a different model.
            guard lift > 0.0001, lift < AngleSceneCalculator.ballRadius / 2 else { return }
            scene.tableNode?.enumerateChildNodes { node, _ in
                let localLift = node.convertVector(SCNVector3(0, lift, 0), from: scene.rootNode)
                for material in node.geometry?.materials ?? [] {
                    guard material.name == "TaiNi" || material.name == "White" else { continue }
                    var modifiers = material.shaderModifiers ?? [:]
                    guard modifiers[.geometry] == nil else { continue }
                    modifiers[.geometry] = """
                    #pragma body
                    float4 bedWorld = scn_node.modelTransform * _geometry.position;
                    if (bedWorld.y >= \(bedY - 0.00001) && bedWorld.y < \(scene.surfaceY - 0.00001)) {
                        _geometry.position.xyz += float3(\(localLift.x), \(localLift.y), \(localLift.z));
                    }
                    """
                    material.shaderModifiers = modifiers
                }
            }
        } catch {
            logger.error("Cloth calibration failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Decode the actual polygon/index channels; do not infer bed height from the rail top.
    static func measuredBedY(in scene: AngleTrainingScene) throws -> Float? {
        guard let table=scene.tableNode else { return nil }
        return try measuredBedY(table:table,worldRoot:scene.rootNode,surfaceY:scene.surfaceY)
    }

    /// Read an exclusively owned static tree without creating a training scene.
    static func measuredBedY(table:SCNNode,worldRoot:SCNNode,surfaceY:Float) throws -> Float? {
        var nodes: [SCNNode] = []
        table.enumerateChildNodes { node, _ in
            if node.geometry?.materials.contains(where: { $0.name == "TaiNi" }) == true { nodes.append(node) }
        }
        var highest: Float?
        for node in nodes {
            guard let geometry = node.geometry,
                  let sourceIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }) else { continue }
            let source = geometry.sources[sourceIndex]
            // SceneKit's NSData bridge can copy the full buffer on device.
            // Snapshot once, not for every vertex bounds check/read (S445 trace).
            let vertexData = source.data
            let channel = geometry.geometrySourceChannels?[sourceIndex].intValue ?? 0
            guard source.usesFloatComponents, source.bytesPerComponent == 4, source.componentsPerVector == 3,
                  source.dataOffset >= 0, source.dataStride >= 12 else {
                throw PocketLeatherMesh.Failure.invalidMesh("Unsupported cloth vertex format")
            }
            for (index, element) in geometry.elements.enumerated() {
                guard geometry.materials[index % geometry.materials.count].name == "TaiNi" else { continue }
                guard channel >= 0, channel < element.indicesChannelCount else {
                    throw PocketLeatherMesh.Failure.invalidMesh("Invalid cloth position channel")
                }
                for face in try PocketLeatherMesh.decode(element) {
                    var points: [SCNVector3] = []
                    for offset in stride(from: channel, to: face.count, by: element.indicesChannelCount) {
                        let index = Int(face[offset])
                        let start = source.dataOffset + index * source.dataStride
                        guard index < source.vectorCount, start + 12 <= vertexData.count else {
                            throw PocketLeatherMesh.Failure.invalidMesh("Cloth vertex index out of bounds")
                        }
                        points.append(vertexData.withUnsafeBytes { bytes in
                            node.convertPosition(SCNVector3(
                                bytes.loadUnaligned(fromByteOffset: start, as: Float.self),
                                bytes.loadUnaligned(fromByteOffset: start+4, as: Float.self),
                                bytes.loadUnaligned(fromByteOffset: start+8, as: Float.self)), to: worldRoot)
                        })
                    }
                    guard let low = points.map(\.y).min(), let high = points.map(\.y).max(),
                          high - low < 0.00001, high <= surfaceY, containsCenter(points) else { continue }
                    highest = max(highest ?? high, high)
                }
            }
        }
        return highest
    }

    private static func containsCenter(_ polygon: [SCNVector3]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        for index in polygon.indices {
            let a = polygon[index], b = polygon[(index + polygon.count - 1) % polygon.count]
            if (a.z > 0) != (b.z > 0), 0 < (b.x - a.x) * -a.z / (b.z - a.z) + a.x {
                inside.toggle()
            }
        }
        return inside
    }
}
