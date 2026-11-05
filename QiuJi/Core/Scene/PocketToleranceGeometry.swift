import Foundation
import SceneKit

/// Target-only straight, ball-width corridor. XZ metres; no cue or obstacle input.
enum PocketToleranceGeometry {
    struct Edge: Sendable {
        let startX, startZ, endX, endZ: Float
    }
    struct Window: Sendable {
        let degrees: Double
        let edges: [Edge]
        let interpolated: Bool
    }
    enum Result: Sendable {
        case window(Window)
        case noStraightWindow
        case unavailable
    }

    static func evaluate(x: Float, z: Float, pocket: Int, useTable: Bool = true) -> Result {
        let r = AngleSceneCalculator.ballRadius
        guard x.isFinite, z.isFinite, (0..<6).contains(pocket),
              abs(x) <= AngleSceneCalculator.innerLength / 2 - r + 0.000001,
              abs(z) <= AngleSceneCalculator.innerWidth / 2 - r + 0.000001 else { return .unavailable }
        let target = SCNVector3(x, 0, z)
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)
        let capture = geometry.pockets[pocket]
        guard !geometry.pockets.contains(where: { $0.containsCapture(target) }) else { return .unavailable }
        let cached = useTable ? DefensePipeTable.shared?.window(target, pocket: pocket) : nil
        let raw = cached ?? AngleSceneCalculator.defenseCleanWindow(target, pocketIndex: pocket, stepDegrees: 0.025)
        guard let intervals = raw["intervals"] as? [[String: Any]],
              let base = raw["baseRadians"] as? Double,
              !(raw["edgeStates"] as? [Bool] ?? []).contains(true) else { return .unavailable }
        guard !intervals.isEmpty else { return .noStraightWindow }
        // Two visible edges can truthfully describe only one connected window.
        guard intervals.count == 1, let a = intervals[0]["leftDegrees"] as? Double,
              let b = intervals[0]["rightDegrees"] as? Double,
              a.isFinite, b.isFinite, b > a, b - a < 180 else { return .unavailable }
        var edges: [Edge] = []
        for (offset, side) in [(a, Float(-1)), (b, Float(1))] {
            let angle = base + offset * .pi / 180
            let dx = Float(cos(angle)), dz = Float(sin(angle))
            guard let length = capture.entryTime(position: target, velocity: SCNVector3(dx, 0, dz),
                acceleration: SCNVector3Zero, maxTime: 4), length > 0 else { return .unavailable }
            let startX = x - side * r * dz, startZ = z + side * r * dx
            edges.append(Edge(startX: startX, startZ: startZ, endX: startX + dx * length, endZ: startZ + dz * length))
        }
        return .window(Window(degrees: b - a, edges: edges, interpolated: cached != nil))
    }

    static func displayDegrees(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "—" }
        if value < 0.001 { return "<0.001°" }
        return String(format: value < 0.1 ? "%.3f°" : "%.2f°", value)
    }
}
