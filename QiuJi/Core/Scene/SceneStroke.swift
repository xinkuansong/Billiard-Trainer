import SceneKit

/// Shared SceneKit stroke helpers for constraint / overlay rings (C17).
/// - Circle: 36 segments, line radius 0.0022
/// - `y`: when non-nil, ring is drawn at that height (Snooker cloth lift);
///   when nil, uses `center.y` (Silu / PlanThree constraint centers already lifted).
enum SceneStroke {
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
                nodes.append(scene.addLine(from: pr, to: p, color: color, radius: lineRadius))
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
                color: color, radius: lineRadius
            ))
        }
    }
}
