import CoreGraphics
import Foundation
import SceneKit

/// Shared world↔loupe mapping for `topDown2DRotated` aim closeup (问题集合 v23).
///
/// **Coordinate contract** (same as `AngleSceneCalculator.bearingDeg` / flat labels):
/// - Planar input: `CGPoint(x: worldX, y: worldZ)`, meters
/// - Screen-up = world **+X**
/// - Screen-right = world **+Z**
///
/// Do **not** use landscape top-down mapping (+X→right, −Z→up) here — AimPoint 2D
/// and most solver stages use the rotated camera.
enum AimCloseupCoords {

    /// Map a world XZ point into loupe/view space (origin = top-leading of `size`
    /// when used for a full view; for the circular loupe, pass the loupe size and
    /// center via `focus` + uniform `scale`).
    static func mapRotated(
        world: CGPoint,
        focus: CGPoint,
        origin: CGPoint,
        scale: CGFloat
    ) -> CGPoint {
        let dX = world.x - focus.x
        let dZ = world.y - focus.y
        return CGPoint(
            x: origin.x + dZ * scale,
            y: origin.y - dX * scale
        )
    }
}

// The loupe retains its canonical 2D drawing space, but live scenes first map
// every world point through the actual camera. Uniform screen magnification
// preserves both perspective foreshortening and orientation.
extension AimCloseupSnapshot {
    @MainActor
    func projected(in view: SCNView, surfaceY: Float) -> AimCloseupSnapshot? {
        guard let camera = view.pointOfView, view.bounds.width > 1, view.bounds.height > 1 else { return nil }
        let y = surfaceY + Float(ballRadius)
        func world(_ p: CGPoint) -> SCNVector3 { SCNVector3(Float(p.x), y, Float(p.y)) }
        func screen(_ p: CGPoint) -> CGPoint {
            let s = view.projectPoint(world(p))
            return CGPoint(x: CGFloat(s.x), y: CGFloat(s.y))
        }
        let f3 = view.projectPoint(world(focus))
        guard f3.z > 0, f3.z < 1 else { return nil }
        let f = screen(focus)
        // A sphere's apparent radius follows the camera's right vector, not a
        // flattened table axis. Use the same uniform scale for all layers.
        let right = camera.presentation.convertVector(SCNVector3(1, 0, 0), to: nil)
        let origin = world(focus)
        let edge = view.projectPoint(SCNVector3(origin.x + right.x * Float(ballRadius),
                                              origin.y + right.y * Float(ballRadius),
                                              origin.z + right.z * Float(ballRadius)))
        let pointsPerMeter = hypot(CGFloat(edge.x) - f.x, CGFloat(edge.y) - f.y) / ballRadius
        guard pointsPerMeter.isFinite, pointsPerMeter > 0.001 else { return nil }
        func local(_ p: CGPoint) -> CGPoint {
            let s = screen(p)
            return CGPoint(x: -(s.y - f.y) / pointsPerMeter,
                           y: (s.x - f.x) / pointsPerMeter)
        }
        func segment(_ s: AimCloseupSegment?) -> AimCloseupSegment? {
            s.map { AimCloseupSegment(start: local($0.start), end: local($0.end)) }
        }
        func norm(_ p: CGPoint) -> CGPoint {
            let s = screen(p)
            return CGPoint(x: s.x / view.bounds.width, y: s.y / view.bounds.height)
        }
        func radiusScale(at p: CGPoint) -> CGFloat {
            let w = world(p)
            let center = screen(p)
            let edge = view.projectPoint(SCNVector3(w.x + right.x * Float(ballRadius),
                                                  w.y + right.y * Float(ballRadius),
                                                  w.z + right.z * Float(ballRadius)))
            return hypot(CGFloat(edge.x) - center.x, CGFloat(edge.y) - center.y) / (pointsPerMeter * ballRadius)
        }
        var result = self
        result.cueRadiusScale = cue.map(radiusScale) ?? 1
        result.ghostRadiusScale = ghost.map(radiusScale) ?? 1
        result.focus = .zero
        result.cue = cue.map(local)
        result.ghost = ghost.map(local)
        result.aimPointMarker = aimPointMarker.map(local)
        result.contactMarker = contactMarker.map(local)
        result.aimLine = segment(aimLine)
        result.potLine = segment(potLine)
        result.auxLine = segment(auxLine)
        result.idealLine = segment(idealLine)
        result.focusNorm = norm(focus)
        if let pot = potLine {
            result.sightKeepout = .init(potStartNorm: norm(pot.start), potEndNorm: norm(pot.end),
                                       aimStartNorm: aimLine.map { norm($0.start) },
                                       aimEndNorm: aimLine.map { norm($0.end) })
        } else if let aim = aimLine {
            result.sightKeepout = .init(potStartNorm: norm(focus), potEndNorm: norm(focus),
                                       aimStartNorm: norm(aim.start), aimEndNorm: norm(aim.end),
                                       pocketRadius: 0)
        }
        return result
    }
}
