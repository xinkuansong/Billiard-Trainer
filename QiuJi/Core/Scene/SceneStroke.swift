import SceneKit

/// Shared SceneKit stroke helpers for constraint / overlay rings (C17).
/// - Circle: 36 segments, line radius 0.0022
/// - Input heights are retained for caller compatibility; display geometry is
///   projected to the actual cloth surface and clipped at its boundary.
enum SceneStroke {
    static func roleRing(role: BallRoleStyle) -> SCNNode {
        let inner = Float(AngleSceneCalculator.ballRadius), outer = inner + 0.004
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        for i in 0..<96 where role != .upcoming || i % 12 < 7 {
            let a = Float(i) * 2 * .pi / 96, b = Float(i + 1) * 2 * .pi / 96
            let base = Int32(vertices.count)
            vertices += [SCNVector3(inner * cos(a), 0, inner * sin(a)),
                         SCNVector3(outer * cos(a), 0, outer * sin(a)),
                         SCNVector3(inner * cos(b), 0, inner * sin(b)),
                         SCNVector3(outer * cos(b), 0, outer * sin(b))]
            indices += [base, base + 2, base + 1, base + 1, base + 2, base + 3]
        }
        let geometry = SCNGeometry(sources: [.init(vertices: vertices)],
            elements: [.init(indices: indices, primitiveType: .triangles)])
        let material = SCNMaterial()
        material.lightingModel = .constant; material.diffuse.contents = role.uiColor
        material.isDoubleSided = true; material.readsFromDepthBuffer = true; material.writesToDepthBuffer = false
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry); node.castsShadow = false
        return node
    }

    static let circleSegments = 36
    static let lineRadius: Float = 0.0022

    static func strokeCircle(
        center: SCNVector3,
        radius: Float,
        color: UIColor,
        y: Float? = nil,
        scene: AngleTrainingScene,
        into nodes: inout [SCNNode]
    ) {
        let drawY = y ?? center.y
        var prev: SCNVector3?
        for i in 0...circleSegments {
            let a = Float(i) / Float(circleSegments) * 2 * .pi
            let p = SCNVector3(center.x + radius * cosf(a), drawY, center.z + radius * sinf(a))
            if let pr = prev {
                nodes.append(scene.addLine(from: pr, to: p, color: color, radius: lineRadius, placement: .table))
            }
            prev = p
        }
    }

    static func strokeRect(
        center: SCNVector3,
        halfX: Float,
        halfZ: Float,
        color: UIColor,
        scene: AngleTrainingScene,
        into nodes: inout [SCNNode]
    ) {
        let c = center
        let corners = [
            SCNVector3(c.x - halfX, c.y, c.z - halfZ),
            SCNVector3(c.x + halfX, c.y, c.z - halfZ),
            SCNVector3(c.x + halfX, c.y, c.z + halfZ),
            SCNVector3(c.x - halfX, c.y, c.z + halfZ)
        ]
        for i in 0..<4 {
            nodes.append(scene.addLine(
                from: corners[i], to: corners[(i + 1) % 4],
                color: color, radius: lineRadius, placement: .table
            ))
        }
    }
}
