import CoreGraphics
import Foundation

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
