import SwiftUI
import SceneKit

/// Physical segment identity chooses where to mark; contact order chooses the color.
/// The material mask deliberately excludes cloth, rubber, pocket leather and sights.
enum PracticeRailColors {
    static let names = ["蓝", "金", "紫", "珊瑚", "青", "橙"]
    static let colors: [UIColor] = [BallRoleStyle.current.uiColor, BallRoleStyle.next.uiColor,
        BallRoleStyle.upcoming.uiColor, UIColor(named: "btPracticeRailCoral")!,
        UIColor(named: "btPracticeRailTeal")!, UIColor(named: "btPracticeRailOrange")!]

    static func beforeTarget(_ events: [ShotEvent]) -> [Int] {
        var result: [Int] = []
        for event in events {
            if case .ballBall(let a, let b) = event.kind,
               a == ShotInput.cueBallName || b == ShotInput.cueBallName { break }
            if case .ballCushion(let ball) = event.kind, ball == ShotInput.cueBallName,
               let index = event.cushionIndex, (0..<6).contains(index) { result.append(index) }
        }
        return result
    }
    private static let begin = "// practiceRailTintBegin"
    private static let end = "// practiceRailTintEnd"
    static func apply(to table: SCNNode, enabled: Bool, segments: [Int] = [], surfaceY: Float) {
        let shader = enabled ? surfaceShader(surfaceY: surfaceY, segments: segments,
            innerSightEdges: innerSightEdges(in: table, surfaceY: surfaceY)) : ""
        var seen = Set<ObjectIdentifier>()
        func apply(_ node: SCNNode) {
            guard let geometry = node.geometry, seen.insert(ObjectIdentifier(geometry)).inserted else { return }
            geometry.materials = geometry.materials.map { original in
                guard original.name == "Wood" || original.name == "BlackWood" else { return original }
                let material = original.copy() as! SCNMaterial
                var modifiers = material.shaderModifiers ?? [:]
                var source = modifiers[.surface] ?? "#pragma body\n"
                if let start = source.range(of: begin), let finish = source.range(of: end) {
                    source.removeSubrange(start.lowerBound..<finish.upperBound)
                }
                if enabled && !shader.isEmpty {
                    // Tint the albedo before the existing wood lighting shader consumes it.
                    if let body = source.range(of: "#pragma body") { source.insert(contentsOf: "\n" + shader, at: body.upperBound) }
                    else { source = "#pragma body\n" + shader + source }
                }
                modifiers[.surface] = source; material.shaderModifiers = modifiers
                return material
            }
        }
        apply(table); table.enumerateChildNodes { node, _ in apply(node) }
    }
    /// Read the inner tangent directly from the installed White inlay mesh. This
    /// remains valid with sights hidden and follows the loaded asset's transforms.
    static func innerSightEdges(in table: SCNNode, surfaceY: Float) -> [Float?] {
        let rails = TableGeometry.chineseEightBallCushions(y: 0).linear
        var edges = Array<Float?>(repeating: nil, count: 6)
        table.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry, !geometry.materials.isEmpty,
                  let sourceIndex = geometry.sources.firstIndex(where: { $0.semantic == .vertex }) else { return }
            let source = geometry.sources[sourceIndex]
            guard source.usesFloatComponents, source.bytesPerComponent == 4, source.componentsPerVector == 3 else { return }
            let channel = geometry.geometrySourceChannels?[sourceIndex].intValue ?? 0
            var indices = Set<Int>()
            for (index, element) in geometry.elements.enumerated()
                where geometry.materials[index % geometry.materials.count].name == "White" {
                guard channel >= 0, channel < element.indicesChannelCount,
                      let faces = try? PocketLeatherMesh.decode(element) else { continue }
                for face in faces {
                    for slot in stride(from: channel, to: face.count, by: element.indicesChannelCount) {
                        indices.insert(Int(face[slot]))
                    }
                }
            }
            for index in indices where index < source.vectorCount {
                let offset = source.dataOffset + index * source.dataStride
                let local = source.data.withUnsafeBytes { bytes in
                    SCNVector3(bytes.loadUnaligned(fromByteOffset: offset, as: Float.self),
                               bytes.loadUnaligned(fromByteOffset: offset + 4, as: Float.self),
                               bytes.loadUnaligned(fromByteOffset: offset + 8, as: Float.self))
                }
                let p = node.convertPosition(local, to: nil)
                guard p.y > surfaceY + 0.02 else { continue }
                for id in 0..<6 {
                    let rail = rails[id], mid = (rail.start + rail.end) * 0.5
                    let short = abs(rail.normal.x) > 0.9
                    let distance = short ? p.x * (mid.x > 0 ? 1 : -1) : p.z * (mid.z > 0 ? 1 : -1)
                    let nose = short ? abs(mid.x) : abs(mid.z)
                    let along = short ? p.z : p.x
                    guard distance > nose,
                          along >= min(short ? rail.start.z : rail.start.x, short ? rail.end.z : rail.end.x),
                          along <= max(short ? rail.start.z : rail.start.x, short ? rail.end.z : rail.end.x) else { continue }
                    edges[id] = min(edges[id] ?? distance, distance)
                }
            }
        }
        return edges
    }
    static func surfaceShader(surfaceY: Float, segments: [Int], innerSightEdges: [Float?]) -> String {
        let rails = TableGeometry.chineseEightBallCushions(y: 0).linear
        let valid = segments.enumerated().filter { (0..<6).contains($0.element) && $0.offset < colors.count }
        guard !valid.isEmpty else { return "" }
        var shader = """
        \(begin)
        float3 practiceP = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
        float3 practiceN = normalize((scn_frame.inverseViewTransform * float4(_surface.normal, 0.0)).xyz);
        if (practiceP.y > \(surfaceY) && practiceN.y > 0.7) {
        """
        for (order, id) in valid {
            guard innerSightEdges.indices.contains(id), let edge = innerSightEdges[id] else { continue }
            let rail = rails[id], mid = (rail.start + rail.end) * 0.5
            let short = abs(rail.normal.x) > 0.9
            let perpendicular = short ? "practiceP.x" : "practiceP.z"
            let sign = (short ? mid.x : mid.z) > 0 ? 1 : -1
            let nose = short ? abs(mid.x) : abs(mid.z)
            var condition = "\(perpendicular) * \(sign).0 > \(nose) && \(perpendicular) * \(sign).0 <= \(edge)"
            if !short { condition += " && practiceP.x * \(mid.x > 0 ? 1 : -1).0 >= 0.0" }
            // If the same segment is visited twice, share its narrow strip in
            // longitudinal pieces so both order colors remain represented.
            let visits = valid.filter { $0.element == id }.map(\.offset)
            if visits.count > 1, let part = visits.firstIndex(of: order) {
                let a = min(short ? rail.start.z : rail.start.x, short ? rail.end.z : rail.end.x)
                let b = max(short ? rail.start.z : rail.start.x, short ? rail.end.z : rail.end.x)
                let axis = short ? "practiceP.z" : "practiceP.x"
                if part > 0 { condition += " && \(axis) >= \(a + (b-a) * Float(part) / Float(visits.count))" }
                if part < visits.count - 1 { condition += " && \(axis) < \(a + (b-a) * Float(part+1) / Float(visits.count))" }
            }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            colors[order].getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ v: CGFloat) -> Double { v <= 0.04045 ? Double(v / 12.92) : pow(Double((v + 0.055) / 1.055), 2.4) }
            shader += """

            if (\(condition)) {
                float practiceGrain = clamp(dot(_surface.diffuse.rgb, float3(0.2126, 0.7152, 0.0722)) * 1.5 + 0.7, 0.7, 1.1);
                _surface.diffuse.rgb = float3(\(linear(r)), \(linear(g)), \(linear(b))) * practiceGrain;
            }
            """
        }
        shader += "\n}\n\(end)\n"
        return shader
    }
}

struct PracticeRailSequence: View {
    let segments: [Int]
    let cueDiameter: CGFloat
    let identifier: String
    var lastRailOptional = false
    var observedBallKey = PositionPlayBall.cueKey
    var observedBallLabel = "母球"
    var body: some View {
        ViewThatFits(in: .horizontal) {
            sequence(gap: Spacing.xs, interRailArrows: true)
            sequence(gap: Spacing.xs / 2, interRailArrows: true)
            sequence(gap: Spacing.xs / 2, interRailArrows: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(observedBallLabel + "，" + segments.enumerated().map {
            "第\($0.offset + 1)库，\(PracticeRailColors.names[$0.offset % PracticeRailColors.names.count])色"
                + (lastRailOptional && $0.offset == segments.count - 1 ? "，可选" : "")
        }.joined(separator: "，"))
        .accessibilityIdentifier(identifier)
    }
    private func sequence(gap: CGFloat, interRailArrows: Bool) -> some View {
        HStack(alignment: .center, spacing: gap) {
            PoolBallFace(key: observedBallKey, diameter: cueDiameter)
            ForEach(Array(segments.enumerated()), id: \.offset) { order, _ in
                if order == 0 || interRailArrows {
                    Text("→").font(.btCaption2).foregroundStyle(.white).frame(height: cueDiameter)
                }
                RoundedRectangle(cornerRadius: BTRadius.xs)
                    .fill(Color(uiColor: PracticeRailColors.colors[order % PracticeRailColors.colors.count]))
                    .frame(width: cueDiameter, height: cueDiameter)
                    .overlay {
                        Text("\(order + 1)")
                            .font(.btSubheadlineSemibold).monospacedDigit()
                            .foregroundStyle(Color.black.opacity(0.82))
                    }
                    .overlay {
                        if lastRailOptional && order == segments.count - 1 {
                            RoundedRectangle(cornerRadius: BTRadius.xs - 2)
                                .stroke(.white, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                .padding(2)
                        }
                    }
            }
        }.fixedSize()
    }
}
