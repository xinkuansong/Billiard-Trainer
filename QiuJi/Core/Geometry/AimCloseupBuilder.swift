import CoreGraphics
import Foundation

/// Shared `AimCloseupSnapshot` builders for the aim closeup loupe (问题集合 v23 W3).
///
/// **Coordinate contract**: planar points in one consistent system
/// (SceneKit XZ → `CGPoint(x: X, y: Z)`), meters. Same contract as
/// `AimProximityMath` / `AimCloseupCoords.mapRotated`.
///
/// Layer policy (D-v23-2′): a page only gets the layers its **main scene already
/// draws**. Free-aim pages (自由击球 / 编排台 / 分离角 / 翻袋·反射 自由模式) draw
/// aim line + ghost ball + contact dot, so those are the layers built here — no
/// pot line, no perpendicular helper, nothing the scene does not show.
enum AimCloseupBuilder {

    /// Framing tightness: `halfWorld = 3.2R` ⇒ object ball ≈ 1/3 of the loupe.
    static let halfWorldMultiple: CGFloat = 3.2

    struct Ball: Equatable {
        var pos: CGPoint
        /// Ball number for `BTFigureBall` fidelity; nil = plain white.
        var number: Int?

        init(pos: CGPoint, number: Int? = nil) {
            self.pos = pos
            self.number = number
        }
    }

    struct Result: Equatable {
        var snapshot: AimCloseupSnapshot?
        /// Feed back into `previouslyNear` next tick (enter 3R / exit 3.5R hysteresis).
        var isNear: Bool
    }

    /// Free-aim closeup: focus = first ball the aim corridor hits; if none is hit,
    /// the nearest **near-band** ball being skimmed (offset < 3R/3.5R) is framed and
    /// captioned 「打空」. `railEnd` = aim line end when nothing is contacted.
    ///
    /// Returns `snapshot == nil` when no ball is in the near band (caller hides HUD).
    static func freeAim(
        cue: CGPoint,
        direction: CGPoint,
        balls: [Ball],
        ballRadius r: CGFloat,
        railEnd: CGPoint,
        halfLength: CGFloat,
        halfWidth: CGFloat,
        previouslyNear: Bool
    ) -> Result {
        struct Candidate {
            var ball: Ball
            var sample: AimProximityMath.Sample
            var ghost: CGPoint?
            /// Distance cue → ghost (contact order along the ray).
            var travel: CGFloat
        }

        let candidates: [Candidate] = balls.compactMap { ball in
            let sample = AimProximityMath.advance(
                cue: cue, direction: direction, target: ball.pos,
                ballRadius: r, previouslyNear: previouslyNear)
            guard sample.isNear else { return nil }
            let ghost = AimProximityMath.userGhost(
                cue: cue, direction: direction, target: ball.pos, ballRadius: r)
            let travel = ghost.map { hypot($0.x - cue.x, $0.y - cue.y) }
                ?? .greatestFiniteMagnitude
            return Candidate(ball: ball, sample: sample, ghost: ghost, travel: travel)
        }

        // 首碰优先（沿射线最先被碰到的那颗），其次擦身带里垂距最小的一颗；
        // 不叠多个 HUD（E1）。
        let picked = candidates.min { a, b in
            let aContact = a.ghost != nil, bContact = b.ghost != nil
            if aContact != bContact { return aContact }
            return aContact ? a.travel < b.travel : a.sample.offset < b.sample.offset
        }
        guard let picked else { return Result(snapshot: nil, isNear: false) }

        let focus = picked.ball.pos
        let lineEnd = picked.ghost ?? railEnd
        let contactMarker = picked.ghost.flatMap { ghost -> CGPoint? in
            let dx = focus.x - ghost.x, dy = focus.y - ghost.y
            let len = hypot(dx, dy)
            guard len > 1e-5 else { return nil }
            return CGPoint(x: ghost.x + dx / len * r, y: ghost.y + dy / len * r)
        }
        let halfWorld = r * halfWorldMultiple
        let cueInFrame = hypot(cue.x - focus.x, cue.y - focus.y) < halfWorld * 1.35

        let snapshot = AimCloseupSnapshot(
            band: picked.sample.band,
            focus: focus,
            ballRadius: r,
            halfWorld: halfWorld,
            showsTargetBall: true,
            targetBallNumber: picked.ball.number,
            cue: cueInFrame ? cue : nil,
            aimLine: AimCloseupSegment(start: cue, end: lineEnd),
            potLine: nil,
            auxLine: nil,
            ghost: picked.ghost,
            // 场景里假想球是一颗整球圈 + 独立接触点，不带瞄准点十字 ⇒ HUD 同步。
            ghostShowsAimPoint: false,
            aimPointMarker: nil,
            contactMarker: contactMarker,
            showMissCaption: picked.sample.band == .skim,
            focusNorm: AimCloseupPlacement.focusNormInRotatedTopDown(
                worldXZ: focus, halfLength: halfLength, halfWidth: halfWidth)
        )
        return Result(snapshot: snapshot, isNear: true)
    }
}
