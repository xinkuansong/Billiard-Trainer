import SceneKit

/// Visual-only extraction. Keeps every USDZ position/normal/UV index channel intact.
/// It never changes the analytical pocket centers used by aiming or physics.
enum PocketLeatherMesh {
    struct Part {
        let index: Int
        let parent: SCNNode
        let geometry: SCNGeometry
        let center: SCNVector3
    }
    struct Replacement {
        let node: SCNNode
        let geometry: SCNGeometry
    }
    struct Extraction {
        let parts: [Part]
        let replacements: [Replacement]
    }
    enum Failure: Error {
        case invalidMesh(String)
    }

    /// Prepare all replacements first. Callers must not modify the table on partial failure.
    static func extract(from table: SCNNode, centers: [SCNVector3]) throws -> Extraction {
        guard centers.count == 6 else { throw Failure.invalidMesh("Expected six pocket centers") }
        var candidates: [SCNNode] = []
        table.enumerateChildNodes { node, _ in
            if node.geometry?.materials.contains(where: { $0.name == "Leather" }) == true {
                candidates.append(node)
            }
        }
        var parts: [Part] = []
        var replacements: [Replacement] = []
        for node in candidates {
            guard let geometry = node.geometry,
                  let vertexSourceIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }) else {
                throw Failure.invalidMesh("Missing vertex source")
            }
            let source = geometry.sources[vertexSourceIndex]
            guard source.usesFloatComponents, source.bytesPerComponent == 4, source.componentsPerVector == 3 else {
                throw Failure.invalidMesh("Unsupported position format")
            }
            let channels = geometry.geometrySourceChannels
            guard channels == nil || channels!.count == geometry.sources.count else {
                throw Failure.invalidMesh("Invalid geometry source channels")
            }
            let vertexChannel = channels?[vertexSourceIndex].intValue ?? 0
            guard source.vectorCount > 0, source.dataOffset >= 0, source.dataStride >= 12,
                  source.dataOffset <= source.data.count,
                  source.vectorCount <= (source.data.count - source.dataOffset) / source.dataStride else {
                throw Failure.invalidMesh("Truncated vertex buffer")
            }
            var keptElements: [SCNGeometryElement] = []
            var keptMaterials: [SCNMaterial] = []
            for (elementIndex, element) in geometry.elements.enumerated() {
                guard !geometry.materials.isEmpty else { throw Failure.invalidMesh("No materials") }
                let material = geometry.materials[elementIndex % geometry.materials.count]
                guard material.name == "Leather" else {
                    keptElements.append(element); keptMaterials.append(material); continue
                }
                guard vertexChannel >= 0, vertexChannel < element.indicesChannelCount else {
                    throw Failure.invalidMesh("Invalid vertex channel")
                }
                let faces = try decode(element)
                var buckets = Array(repeating: [[UInt32]](), count: 6)
                var sums = Array(repeating: SCNVector3Zero, count: 6)
                for face in faces {
                    var center = SCNVector3Zero
                    for offset in stride(from: vertexChannel, to: face.count, by: element.indicesChannelCount) {
                        let id = Int(face[offset])
                        guard id < source.vectorCount else { throw Failure.invalidMesh("Vertex index out of bounds") }
                        let p = source.data.withUnsafeBytes { bytes -> SCNVector3 in
                            let start = source.dataOffset + id * source.dataStride
                            return SCNVector3(bytes.loadUnaligned(fromByteOffset: start, as: Float.self),
                                              bytes.loadUnaligned(fromByteOffset: start + 4, as: Float.self),
                                              bytes.loadUnaligned(fromByteOffset: start + 8, as: Float.self))
                        }
                        let world = node.convertPosition(p, to: nil)
                        center.x += world.x; center.y += world.y; center.z += world.z
                    }
                    let count = Float(face.count / element.indicesChannelCount)
                    center = SCNVector3(center.x / count, center.y / count, center.z / count)
                    let distances = centers.map { squaredDistance(center, $0) }
                    guard let index = distances.indices.min(by: { distances[$0] < distances[$1] }) else {
                        throw Failure.invalidMesh("Missing region")
                    }
                    let separation = centers.indices.filter { $0 != index }.map {
                        squaredDistance(centers[index], centers[$0])
                    }.min()!
                    // Reject changed assets whose leather reaches another pocket's region.
                    guard distances[index] < separation / 4 else {
                        throw Failure.invalidMesh("Leather is outside its unambiguous pocket region")
                    }
                    buckets[index].append(face)
                    sums[index].x += center.x; sums[index].y += center.y; sums[index].z += center.z
                }
                for index in buckets.indices where !buckets[index].isEmpty {
                    let e = makeElement(faces: buckets[index], channelCount: element.indicesChannelCount)
                    let g = SCNGeometry(sources: geometry.sources, elements: [e], sourceChannels: channels)
                    g.materials = [material]
                    let n = Float(buckets[index].count)
                    parts.append(Part(index: index, parent: node, geometry: g,
                                      center: SCNVector3(sums[index].x / n, sums[index].y / n, sums[index].z / n)))
                }
            }
            let kept = SCNGeometry(sources: geometry.sources, elements: keptElements, sourceChannels: channels)
            kept.materials = keptMaterials
            replacements.append(Replacement(node: node, geometry: kept))
        }
        guard parts.count == 6, Set(parts.map(\.index)) == Set(0..<6) else {
            throw Failure.invalidMesh("Leather must cover all six pockets; found \(parts.map(\.index))")
        }
        return Extraction(parts: parts, replacements: replacements)
    }

    /// Convert either index layout to interleaved face records without triangulating or welding.
    static func decode(_ element: SCNGeometryElement) throws -> [[UInt32]] {
        guard element.primitiveType == .polygon || element.primitiveType == .triangles,
              [1, 2, 4].contains(element.bytesPerIndex), element.indicesChannelCount > 0 else {
            throw Failure.invalidMesh("Unsupported primitive/index layout")
        }
        guard element.data.count % element.bytesPerIndex == 0 else {
            throw Failure.invalidMesh("Truncated index word")
        }
        let values: [UInt32] = element.data.withUnsafeBytes { bytes in
            stride(from: 0, to: bytes.count, by: element.bytesPerIndex).map { offset in
                switch element.bytesPerIndex {
                case 1: return UInt32(bytes.load(fromByteOffset: offset, as: UInt8.self))
                case 2: return UInt32(bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                default: return bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
                }
            }
        }
        let header = element.primitiveType == .polygon ? element.primitiveCount : 0
        guard values.count >= header else { throw Failure.invalidMesh("Truncated polygon header") }
        let counts = header > 0 ? Array(values.prefix(header)).map(Int.init)
                                : Array(repeating: 3, count: element.primitiveCount)
        guard counts.allSatisfy({ $0 >= 3 && $0 < 256 }) else {
            throw Failure.invalidMesh("Unsupported polygon size")
        }
        let total = counts.reduce(0, +)
        let channelCount = element.indicesChannelCount
        guard values.count == header + total * channelCount else {
            throw Failure.invalidMesh("Truncated index channels")
        }
        var cursor = 0
        var faces: [[UInt32]] = []
        for count in counts {
            var face: [UInt32] = []
            for vertex in cursor..<(cursor + count) {
                for channel in 0..<channelCount {
                    let offset: Int
                    if element.hasInterleavedIndicesChannels {
                        offset = vertex * channelCount + channel
                    } else {
                        offset = channel * total + vertex
                    }
                    face.append(values[header + offset])
                }
            }
            faces.append(face)
            cursor += count
        }
        return faces
    }

    static func makeElement(faces: [[UInt32]], channelCount: Int) -> SCNGeometryElement {
        let values = faces.map { UInt32($0.count / channelCount) } + faces.flatMap { $0 }
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return SCNGeometryElement(data: data, primitiveType: .polygon, primitiveCount: faces.count,
                                  indicesChannelCount: channelCount, interleavedIndicesChannels: true,
                                  bytesPerIndex: MemoryLayout<UInt32>.size)
    }

    private static func squaredDistance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        (a.x - b.x) * (a.x - b.x) + (a.z - b.z) * (a.z - b.z)
    }
}

extension PocketLeatherMesh {
    /// Cache only immutable index subsets, never nodes or per-scene materials.
    /// All table instances originate from the process-immutable bundled USDZ.
    private struct CachedRegion {
        let path: [Int]
        let sourceIndices: [Data]
        let materialNames: [String?]
        let parts: [(Int, SCNGeometry, SCNVector3)]
        let remainder: SCNGeometry
        let remainderMaterialIndices: [Int]
    }
    private static let layoutLock = NSLock()
    private static var cachedRegions: [CachedRegion]?

    static func cachedExtraction(from table: SCNNode, centers: [SCNVector3]) throws -> Extraction {
        layoutLock.lock()
        defer { layoutLock.unlock() }
        if let cachedRegions {
            var parts: [Part] = []
            var replacements: [Replacement] = []
            for region in cachedRegions {
                var node = table
                for index in region.path {
                    guard node.childNodes.indices.contains(index) else { throw Failure.invalidMesh("Cached node path changed") }
                    node = node.childNodes[index]
                }
                guard let source = node.geometry,
                      source.elements.map(\.data) == region.sourceIndices,
                      source.materials.map(\.name) == region.materialNames,
                      let material = source.materials.first(where: { $0.name == "Leather" }) else {
                    throw Failure.invalidMesh("Cached model geometry/material signature changed")
                }
                for (index, template, center) in region.parts {
                    let g = template.copy() as! SCNGeometry
                    g.materials = [material.copy() as! SCNMaterial]
                    parts.append(Part(index: index, parent: node, geometry: g, center: center))
                }
                let g = region.remainder.copy() as! SCNGeometry
                g.materials = region.remainderMaterialIndices.map { source.materials[$0] }
                replacements.append(Replacement(node: node, geometry: g))
            }
            return Extraction(parts: parts, replacements: replacements)
        }
        let raw = try extract(from: table, centers: centers)
        let result = Extraction(parts: try raw.parts.map {
            Part(index: $0.index, parent: $0.parent, geometry: try compact($0.geometry), center: $0.center)
        }, replacements: try raw.replacements.map {
            Replacement(node: $0.node, geometry: try compact($0.geometry))
        })
        var regions: [CachedRegion] = []
        for replacement in result.replacements {
            var path: [Int] = []
            var child = replacement.node
            while child !== table {
                guard let parent = child.parent, let index = parent.childNodes.firstIndex(where: { $0 === child }) else {
                    throw Failure.invalidMesh("Detached source node")
                }
                path.insert(index, at: 0); child = parent
            }
            let g = replacement.node.geometry!
            regions.append(CachedRegion(path: path, sourceIndices: g.elements.map(\.data), materialNames: g.materials.map(\.name),
                parts: result.parts.filter { $0.parent === replacement.node }.map { ($0.index, $0.geometry, $0.center) },
                remainder: replacement.geometry,
                remainderMaterialIndices: g.elements.indices.map { $0 % g.materials.count }.filter { g.materials[$0].name != "Leather" }))
        }
        cachedRegions = regions
        return result
    }

    /// Keep independently indexed attributes and exact bytes, but discard unused
    /// entries. iOS 17 emits one Deindexing warning per unused position, which can
    /// flood libtrace and crash its runtime-issue callback on a full-table buffer.
    static func compact(_ geometry: SCNGeometry) throws -> SCNGeometry {
        guard let first = geometry.elements.first else { throw Failure.invalidMesh("Empty geometry") }
        let channelCount = first.indicesChannelCount
        guard geometry.elements.allSatisfy({ $0.indicesChannelCount == channelCount }) else {
            throw Failure.invalidMesh("Inconsistent index channel counts")
        }
        var maps = Array(repeating: [UInt32: UInt32](), count: channelCount)
        var used = Array(repeating: [UInt32](), count: channelCount)
        var elements: [SCNGeometryElement] = []
        for element in geometry.elements {
            let faces = try decode(element)
            var remapped: [[UInt32]] = []
            for face in faces {
                var newFace: [UInt32] = []
                for (slot, old) in face.enumerated() {
                    let channel = slot % channelCount
                    let index: UInt32
                    if let existing = maps[channel][old] { index = existing }
                    else {
                        index = UInt32(used[channel].count)
                        maps[channel][old] = index; used[channel].append(old)
                    }
                    newFace.append(index)
                }
                remapped.append(newFace)
            }
            elements.append(makeElement(faces: remapped, channelCount: channelCount))
        }
        var sources: [SCNGeometrySource] = []
        for (index, source) in geometry.sources.enumerated() {
            let channel = geometry.geometrySourceChannels?[index].intValue ?? 0
            guard used.indices.contains(channel), !used[channel].isEmpty else {
                throw Failure.invalidMesh("Unused geometry source channel")
            }
            let width = source.bytesPerComponent * source.componentsPerVector
            var data = Data(); data.reserveCapacity(used[channel].count * width)
            for oldIndex in used[channel] {
                let start = source.dataOffset + Int(oldIndex) * source.dataStride
                guard oldIndex < source.vectorCount, start >= 0, start <= source.data.count - width else {
                    throw Failure.invalidMesh("Attribute index outside source buffer")
                }
                data.append(source.data[start..<(start + width)])
            }
            sources.append(SCNGeometrySource(data: data, semantic: source.semantic,
                vectorCount: used[channel].count, usesFloatComponents: source.usesFloatComponents,
                componentsPerVector: source.componentsPerVector, bytesPerComponent: source.bytesPerComponent,
                dataOffset: 0, dataStride: width))
        }
        let result = SCNGeometry(sources: sources, elements: elements, sourceChannels: geometry.geometrySourceChannels)
        result.materials = geometry.materials
        return result
    }

    static func splitRoleGeometry(_ geometry: SCNGeometry) throws -> SCNGeometry {
        guard let sourceIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }),
              let element = geometry.elements.first, let material = geometry.materials.first else {
            throw Failure.invalidMesh("Missing role geometry")
        }
        let source = geometry.sources[sourceIndex]
        let channel = geometry.geometrySourceChannels?[sourceIndex].intValue ?? 0
        let faces = try decode(element)
        let xs: [Float] = faces.map { face in
            let values: [Float] = stride(from: channel, to: face.count, by: element.indicesChannelCount).map { slot in
                source.data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: source.dataOffset + Int(face[slot]) * source.dataStride, as: Float.self) }
            }
            return values.reduce(0,+) / Float(values.count)
        }
        let divider = xs.reduce(0,+) / Float(xs.count)
        let halves = [false, true].map { side in faces.indices.filter { (xs[$0] >= divider) == side }.map { faces[$0] } }
        guard halves.allSatisfy({ !$0.isEmpty }) else { throw Failure.invalidMesh("Empty dual-role partition") }
        let result = SCNGeometry(sources: geometry.sources,
            elements: halves.map { makeElement(faces: $0, channelCount: element.indicesChannelCount) },
            sourceChannels: geometry.geometrySourceChannels)
        result.materials = [PocketLeatherAppearance.firstRoleTint, PocketLeatherAppearance.secondRoleTint].map {
            PocketLeatherAppearance.material(from: material, tint: $0)
        }
        return result
    }
}
