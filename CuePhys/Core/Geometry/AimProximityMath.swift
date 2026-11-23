import CoreGraphics
import Foundation

/// Near-aim proximity bands for closeup HUD + fine aiming (问题集合 v23).
///
/// **Coordinate contract**: planar points in one consistent system
/// (SceneKit XZ → `CGPoint(x: X, y: Z)`). Units: meters.
///
/// Geometry:
/// - offset = perpendicular distance from target center to aim line
///   (`AimPointGeometry.offsetDistance`)
/// - **2R = contact boundary**: offset < 2R ⇔ aim corridor hits the ball
///   (contact time exists; cut angle defined)
/// - enter **3R** / exit **3.5R**: hysteresis for HUD near-band only
/// - Requires **forward** (`proj > 0`): ball behind cue never counts as near
enum AimProximityMath {

    static let contactMultiple: CGFloat = 2
    static let enterMultiple: CGFloat = 3
    static let exitMultiple: CGFloat = 3.5

    enum Band: Equatable {
        /// Outside near zone (or not forward).
        case far
        /// Near but offset ≥ 2R — aim misses the ball.
        case skim
        /// Near and offset < 2R — geometric contact possible.
        case contact
    }

    struct Sample: Equatable {
        var band: Band
        /// Perpendicular distance target → aim line (meters). Infinite if direction degenerates.
        var offset: CGFloat
        var forward: Bool

        var isNear: Bool { band != .far }
    }

    /// Advance proximity with enter/exit hysteresis on `previouslyNear`.
    static func advance(
        cue: CGPoint,
        direction: CGPoint,
        target: CGPoint,
        ballRadius: CGFloat,
        previouslyNear: Bool
    ) -> Sample {
        let len = hypot(direction.x, direction.y)
        guard len > 1e-9 else {
            return Sample(band: .far, offset: .greatestFiniteMagnitude, forward: false)
        }
        let ux = direction.x / len
        let uy = direction.y / len
        let dx = target.x - cue.x
        let dy = target.y - cue.y
        let proj = dx * ux + dy * uy
        let forward = proj > 0
        let offset = AimPointGeometry.offsetDistance(
            lineOrigin: cue, direction: direction, targetCenter: target)

        guard forward else {
            return Sample(band: .far, offset: offset, forward: false)
        }

        let enter = enterMultiple * ballRadius
        let exit = exitMultiple * ballRadius
        let contact = contactMultiple * ballRadius
        let near = previouslyNear ? (offset <= exit) : (offset < enter)
        guard near else {
            return Sample(band: .far, offset: offset, forward: true)
        }
        if offset < contact {
            return Sample(band: .contact, offset: offset, forward: true)
        }
        return Sample(band: .skim, offset: offset, forward: true)
    }

    /// User ghost-ball center if the aim corridor hits `target` (offset < 2R, forward).
    /// Same geometry as `AngleSceneCalculator.freeAimFirstContact` for a single ball.
    static func userGhost(
        cue: CGPoint,
        direction: CGPoint,
        target: CGPoint,
        ballRadius: CGFloat
    ) -> CGPoint? {
        let len = hypot(direction.x, direction.y)
        guard len > 1e-9 else { return nil }
        let ux = direction.x / len
        let uy = direction.y / len
        let dx = target.x - cue.x
        let dy = target.y - cue.y
        let proj = dx * ux + dy * uy
        guard proj > 0 else { return nil }
        let perpSq = dx * dx + dy * dy - proj * proj
        let twoR = 2 * ballRadius
        let radSq = twoR * twoR - perpSq
        guard radSq > 0 else { return nil }
        let t = proj - CGFloat(sqrt(Double(radSq)))
        guard t > 0.0005 else { return nil }
        return CGPoint(x: cue.x + ux * t, y: cue.y + uy * t)
    }
}
