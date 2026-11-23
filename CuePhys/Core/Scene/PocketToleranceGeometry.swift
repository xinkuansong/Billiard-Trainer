import Foundation
import SceneKit

/// Target-only straight, ball-width corridor. XZ metres; no cue or obstacle input.
enum PocketToleranceGeometry {
    struct Edge: Sendable {
        let startX, startZ, endX, endZ: Float
    }
    struct Window: Sendable {
        let degrees: Double
        /// The nominal pot direction through the target-ball centre.
        let center: Edge
        let edges: [Edge]
        /// The one-ball-width reference pipe, parallel to `center`.
        let standardEdges: [Edge]
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
        let halfWidth = (b - a) / 2
        // Use the solver's effective target-ball aim for the displayed pipe.
        // The measured width still comes from the clean-window scan, while
        // the visual centre follows the same near-rail clearance that keeps
        // the ball-width tube off the adjacent cushion.
        let effectiveAim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: pocket, surfaceY: 0)
        let effectiveDX = effectiveAim.x - x
        let effectiveDZ = effectiveAim.z - z
        let effectiveLength = hypot(effectiveDX, effectiveDZ)
        guard effectiveLength.isFinite, effectiveLength > 0.0001 else { return .unavailable }
        let centerAngle = atan2(Double(effectiveDZ), Double(effectiveDX))
        let centerEnd = SCNVector3(effectiveAim.x, 0, effectiveAim.z)
        let centerDirection = SCNVector3(Float(cos(centerAngle)), 0, Float(sin(centerAngle)))

        func makeLine(angle: Double, side: Float) -> Edge? {
            let dx = Float(cos(angle)), dz = Float(sin(angle))
            let startX = x - side * r * dz
            let startZ = z + side * r * dx
            let start = SCNVector3(startX, 0, startZ)
            // The target-ball pipe has its own finite mouth intersection. Do
            // not reuse the centre-line distance for an offset boundary. That
            // would carry the side wall past the opening and onto the jaw.
            let length: Float?
            if let captured = capture.entryTime(position: start,
                velocity: SCNVector3(dx, 0, dz), acceleration: SCNVector3Zero, maxTime: 4) {
                length = captured
            } else {
                let denominator = centerDirection.x * dx + centerDirection.z * dz
                guard denominator > 0.000001 else { return nil }
                length = ((centerEnd.x - start.x) * centerDirection.x
                    + (centerEnd.z - start.z) * centerDirection.z) / denominator
            }
            guard let length else { return nil }
            guard length.isFinite, length > 0 else { return nil }
            return Edge(startX: startX, startZ: startZ,
                        endX: startX + dx * length, endZ: startZ + dz * length)
        }

        // The reference line is the direct target-centre to pocket-centre line.
        // Keep the measured window width, but express its two visible sides
        // symmetrically around this line for a stable teaching pipe.
        guard let center = makeLine(angle: centerAngle, side: 0),
              let left = makeLine(angle: centerAngle - halfWidth * .pi / 180, side: -1),
              let right = makeLine(angle: centerAngle + halfWidth * .pi / 180, side: 1) else {
            return .unavailable
        }
        let standardEdges = [-1 as Float, 1].compactMap { makeLine(angle: centerAngle, side: $0) }
        guard standardEdges.count == 2 else { return .unavailable }
        return .window(Window(degrees: b - a, center: center,
                              edges: [left, right], standardEdges: standardEdges,
                              interpolated: cached != nil))
    }

    /// Builds the solver-style visual reference pipe even when the clean-window
    /// evaluator cannot certify a straight tolerance interval. The zero-width
    /// case intentionally makes the solid and dashed sides coincide while the
    /// caller keeps the unavailable/no-window status.
    static func referenceWindow(x: Float, z: Float, pocket: Int) -> Window? {
        let r = AngleSceneCalculator.ballRadius
        guard x.isFinite, z.isFinite, (0..<6).contains(pocket),
              abs(x) <= AngleSceneCalculator.innerLength / 2 - r + 0.000001,
              abs(z) <= AngleSceneCalculator.innerWidth / 2 - r + 0.000001 else { return nil }
        let target = SCNVector3(x, 0, z)
        let geometry = TableGeometry.chineseEightBallQiuJi(surfaceY: 0)
        let capture = geometry.pockets[pocket]
        guard !capture.containsCapture(target) else { return nil }
        // This path is only used after the evaluator declined to certify a
        // clean window. Keep the visual reference at exactly zero tolerance.
        let width = 0.0
        // Reuse the solver's effective aim point. Near a cushion it moves the
        // visual direction parallel to the opening until the ball-width pipe
        // clears the adjacent rail by ballRadius + aimMargin.
        let aim = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: target, pocketIndex: pocket, surfaceY: 0)
        let aimDX = aim.x - target.x
        let aimDZ = aim.z - target.z
        let aimLength = hypot(aimDX, aimDZ)
        guard aimLength.isFinite, aimLength > 0.0001 else { return nil }
        let base = atan2(Double(aimDZ), Double(aimDX))

        let centerEnd = SCNVector3(aim.x, 0, aim.z)

        func makeLine(angle: Double, side: Float) -> Edge? {
            let dx = Float(cos(angle)), dz = Float(sin(angle))
            let startX = x - side * r * dz
            let startZ = z + side * r * dx
            let lineLength = capture.entryTime(
                position: SCNVector3(startX, 0, startZ),
                velocity: SCNVector3(dx, 0, dz),
                acceleration: SCNVector3Zero,
                maxTime: 4
            ) ?? hypot(centerEnd.x - startX, centerEnd.z - startZ)
            guard lineLength.isFinite, lineLength > 0 else { return nil }
            return Edge(startX: startX, startZ: startZ,
                        endX: startX + dx * lineLength, endZ: startZ + dz * lineLength)
        }

        guard let center = makeLine(angle: base, side: 0) else { return nil }
        let halfWidth = width / 2 * .pi / 180
        guard let left = makeLine(angle: base - halfWidth, side: -1),
              let right = makeLine(angle: base + halfWidth, side: 1) else { return nil }
        let standardEdges = [-1 as Float, 1].compactMap { makeLine(angle: base, side: $0) }
        guard standardEdges.count == 2 else { return nil }
        return Window(degrees: width, center: center, edges: [left, right],
                      standardEdges: standardEdges, interpolated: false)
    }

    static func displayDegrees(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "—" }
        if value < 0.001 { return "<0.001°" }
        return String(format: value < 0.1 ? "%.3f°" : "%.2f°", value)
    }
}
