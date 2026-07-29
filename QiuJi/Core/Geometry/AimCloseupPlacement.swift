import CoreGraphics
import Foundation
import SwiftUI

/// Screen placement for aim closeup HUD
/// (问题集合 v23 / D-v23-5′ … / 5 formal / **5.1**).
///
/// **Product rule**: loupe stays near the focus ball (~0.92×diameter) but sits in
/// the **open table quadrant** (larger of L/R × larger of T/B — usually a
/// diagonal into empty felt), not merely the single longest cardinal edge.
/// Hard-clears aim wheel / submit, and must not cover aim line / pot line /
/// pocket when those are known (`SightKeepout`).
///
/// Uses the same axis contract as `AimCloseupCoords.mapRotated`
/// (screen-up = world +X, screen-right = world +Z).
enum AimCloseupPlacement {

    enum Corner: Equatable, CaseIterable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        var isTrailing: Bool { self == .topTrailing || self == .bottomTrailing }
        var isBottom: Bool { self == .bottomLeading || self == .bottomTrailing }
    }

    /// Horizontal screen side.
    enum Side: Equatable {
        case leading, trailing

        var opposite: Side { self == .leading ? .trailing : .leading }
    }

    /// Chrome reserves inside the scene view (points).
    struct SafeInsets: Equatable {
        var top: CGFloat = 12
        var leading: CGFloat = 12
        var bottom: CGFloat = 12
        var trailing: CGFloat = 12

        /// Aim-wheel column + thumb — pages that drive the loupe from the wheel
        /// pass ~56 so the loupe never lands under the finger.
        static let aimWheelPage = SafeInsets(
            top: 12, leading: 56, bottom: 46, trailing: 12)
    }

    /// Full-scene sight corridor the loupe must not cover (D-v23-5⁗ / 5.1).
    /// Norms use the same 0…1 space as `focusNorm` (top-leading origin).
    struct SightKeepout: Equatable {
        /// Object-ball end of the pot line (usually ≈ focus).
        var potStartNorm: CGPoint
        /// Pocket end of the pot line.
        var potEndNorm: CGPoint
        /// Cue → object (or line end); nil when the page has no aim line.
        var aimStartNorm: CGPoint? = nil
        var aimEndNorm: CGPoint? = nil
        /// Extra clearance around segments (scene points).
        var segmentMargin: CGFloat = 10
        /// Disc around the pocket (scene points).
        var pocketRadius: CGFloat = 24

        /// Build from world XZ meters via the rotated top-down norm map.
        static func fromWorld(
            object: CGPoint,
            pocket: CGPoint,
            halfLength: CGFloat,
            halfWidth: CGFloat,
            cue: CGPoint? = nil,
            aimEnd: CGPoint? = nil,
            segmentMargin: CGFloat = 10,
            pocketRadius: CGFloat = 24
        ) -> SightKeepout {
            let objN = focusNormInRotatedTopDown(
                worldXZ: object, halfLength: halfLength, halfWidth: halfWidth)
            let potN = focusNormInRotatedTopDown(
                worldXZ: pocket, halfLength: halfLength, halfWidth: halfWidth)
            let cueN = cue.map {
                focusNormInRotatedTopDown(
                    worldXZ: $0, halfLength: halfLength, halfWidth: halfWidth)
            }
            let aimN: CGPoint? = cue == nil ? nil : focusNormInRotatedTopDown(
                worldXZ: aimEnd ?? object,
                halfLength: halfLength, halfWidth: halfWidth)
            return SightKeepout(
                potStartNorm: objN,
                potEndNorm: potN,
                aimStartNorm: cueN,
                aimEndNorm: aimN,
                segmentMargin: segmentMargin,
                pocketRadius: pocketRadius
            )
        }
    }

    /// Normalized focus in the scene view (0…1, origin top-leading).
    /// `halfLength` / `halfWidth` = table outer half extents (meters).
    static func focusNormInRotatedTopDown(
        worldXZ: CGPoint,
        halfLength: CGFloat,
        halfWidth: CGFloat
    ) -> CGPoint {
        let hl = max(halfLength, 1e-3)
        let hw = max(halfWidth, 1e-3)
        let mapped = AimCloseupCoords.mapRotated(
            world: worldXZ,
            focus: .zero,
            origin: CGPoint(x: hw, y: hl),
            scale: 1
        )
        let x = mapped.x / (2 * hw)
        let y = mapped.y / (2 * hl)
        return CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y)))
    }

    /// Pick a coarse opposite corner (kept for tests / chrome padding decisions).
    ///
    /// - `blockedSide`: side occupied by the driving control (aim wheel → leading).
    /// - `previous` is only kept while the focus sits inside the `hysteresis`
    ///   band around a midline. Half-plane hysteresis is forbidden (FL-028).
    static func corner(
        focusNorm: CGPoint,
        previous: Corner?,
        hysteresis: CGFloat = 0.08,
        blockedSide: Side? = nil
    ) -> Corner {
        var wantsTrailing = blockedSide.map { $0.opposite == .trailing }
            ?? (focusNorm.x < 0.5)
        var wantsBottom = focusNorm.y < 0.5

        if let previous {
            if blockedSide == nil, previous.isTrailing != wantsTrailing,
               abs(focusNorm.x - 0.5) < hysteresis {
                wantsTrailing = previous.isTrailing
            }
            if previous.isBottom != wantsBottom,
               abs(focusNorm.y - 0.5) < hysteresis {
                wantsBottom = previous.isBottom
            }
        }

        switch (wantsTrailing, wantsBottom) {
        case (false, false): return .topLeading
        case (true, false):  return .topTrailing
        case (false, true):  return .bottomLeading
        case (true, true):   return .bottomTrailing
        }
    }

    /// Cardinal clearance of the focus toward each table edge in **norm** space
    /// (0…1). Larger = more open felt in that direction.
    struct EdgeClearance: Equatable {
        var top: CGFloat      // focusNorm.y
        var bottom: CGFloat   // 1 − focusNorm.y
        var leading: CGFloat  // focusNorm.x
        var trailing: CGFloat // 1 − focusNorm.x

        /// Horizontal open sign: +1 trailing, −1 leading.
        var openHorizontal: CGFloat { trailing >= leading ? 1 : -1 }
        /// Vertical open sign: +1 bottom, −1 top.
        var openVertical: CGFloat { bottom >= top ? 1 : -1 }

        /// Diagonal into the open quadrant (the “larger empty region”).
        var openQuadrantDirection: (CGFloat, CGFloat) {
            (openHorizontal, openVertical)
        }

        static func of(_ focusNorm: CGPoint) -> EdgeClearance {
            EdgeClearance(
                top: max(0, focusNorm.y),
                bottom: max(0, 1 - focusNorm.y),
                leading: max(0, focusNorm.x),
                trailing: max(0, 1 - focusNorm.x)
            )
        }

        /// Unit directions sorted by clearance descending (ties: bottom →
        /// trailing → top → leading).
        var directionsByOpenness: [(CGFloat, CGFloat)] {
            var ranked: [(clear: CGFloat, pri: Int, dir: (CGFloat, CGFloat))] = [
                (bottom, 0, (0, 1)),
                (trailing, 1, (1, 0)),
                (top, 2, (0, -1)),
                (leading, 3, (-1, 0))
            ]
            ranked.sort { a, b in
                if abs(a.clear - b.clear) > 1e-6 { return a.clear > b.clear }
                return a.pri < b.pri
            }
            return ranked.map(\.dir)
        }

        /// How far along unit dir `(dx,dy)` until a table edge (norm units).
        func freeRun(along dir: (CGFloat, CGFloat), from focusNorm: CGPoint) -> CGFloat {
            let dx = dir.0, dy = dir.1
            var t = CGFloat.greatestFiniteMagnitude
            if dx > 1e-6 { t = min(t, (1 - focusNorm.x) / dx) }
            if dx < -1e-6 { t = min(t, focusNorm.x / -dx) }
            if dy > 1e-6 { t = min(t, (1 - focusNorm.y) / dy) }
            if dy < -1e-6 { t = min(t, focusNorm.y / -dy) }
            return max(0, t)
        }
    }

    /// Loupe **center** in scene-view points: offset from the focus into the
    /// open table quadrant, then clamped into the safe rect. Stays near the
    /// ball (true loupe) rather than pinning to a screen corner.
    ///
    /// Invariant: distance(center, focus) ≥ `diameter * minSeparation`.
    /// When `sightKeepout` is set, reject centres that intersect aim/pot
    /// segments or the pocket disc.
    static func center(
        focusNorm: CGPoint,
        sceneSize: CGSize,
        diameter: CGFloat,
        safeInsets: SafeInsets = .aimWheelPage,
        blockedSide: Side? = .leading,
        previous: CGPoint? = nil,
        hysteresis: CGFloat = 28,
        minSeparation: CGFloat = 0.92,
        sightKeepout: SightKeepout? = nil
    ) -> CGPoint {
        let w = max(sceneSize.width, 1)
        let h = max(sceneSize.height, 1)
        let focus = CGPoint(x: focusNorm.x * w, y: focusNorm.y * h)

        if let previous,
           isValid(previous, focus: focus, diameter: diameter,
                   sceneSize: sceneSize, insets: safeInsets,
                   minSeparation: minSeparation,
                   sightKeepout: sightKeepout) {
            let ideal = preferredCenter(
                focus: focus, focusNorm: focusNorm, sceneSize: sceneSize,
                diameter: diameter, insets: safeInsets, blockedSide: blockedSide,
                minSeparation: minSeparation, sightKeepout: sightKeepout)
            if hypot(previous.x - ideal.x, previous.y - ideal.y) < hysteresis {
                return previous
            }
        }

        return preferredCenter(
            focus: focus, focusNorm: focusNorm, sceneSize: sceneSize,
            diameter: diameter, insets: safeInsets, blockedSide: blockedSide,
            minSeparation: minSeparation, sightKeepout: sightKeepout)
    }

    /// Penetration of loupe into keepout (0 = clear). Exposed for tests.
    static func keepoutOverlap(
        center: CGPoint,
        diameter: CGFloat,
        sceneSize: CGSize,
        keepout: SightKeepout
    ) -> CGFloat {
        let w = max(sceneSize.width, 1)
        let h = max(sceneSize.height, 1)
        let r = diameter / 2
        let potA = CGPoint(x: keepout.potStartNorm.x * w, y: keepout.potStartNorm.y * h)
        let potB = CGPoint(x: keepout.potEndNorm.x * w, y: keepout.potEndNorm.y * h)
        let potPen = max(0, r + keepout.segmentMargin
            - distancePointToSegment(center, a: potA, b: potB))
        let pocketPen = max(0, r + keepout.pocketRadius
            - hypot(center.x - potB.x, center.y - potB.y))
        var aimPen: CGFloat = 0
        if let asN = keepout.aimStartNorm, let aeN = keepout.aimEndNorm {
            let a = CGPoint(x: asN.x * w, y: asN.y * h)
            let b = CGPoint(x: aeN.x * w, y: aeN.y * h)
            aimPen = max(0, r + keepout.segmentMargin
                - distancePointToSegment(center, a: a, b: b))
        }
        return max(potPen, max(pocketPen, aimPen))
    }

    // MARK: - Internals

    private static func preferredCenter(
        focus: CGPoint,
        focusNorm: CGPoint,
        sceneSize: CGSize,
        diameter: CGFloat,
        insets: SafeInsets,
        blockedSide: Side?,
        minSeparation: CGFloat,
        sightKeepout: SightKeepout?
    ) -> CGPoint {
        let candidates = directionCandidates(
            focus: focus, focusNorm: focusNorm, sceneSize: sceneSize,
            blockedSide: blockedSide, sightKeepout: sightKeepout)

        let gaps = [minSeparation, minSeparation * 1.1, minSeparation * 1.25]
        var bestSoft: CGPoint?
        var bestSoftOverlap: CGFloat = .greatestFiniteMagnitude

        // Greedy in openness order; first hard-clear win (D-v23-5.1).
        for gapFactor in gaps {
            let gap = diameter * gapFactor
            for (dx, dy) in candidates {
                let len = hypot(dx, dy)
                guard len > 1e-6 else { continue }
                let ideal = CGPoint(x: focus.x + dx / len * gap,
                                    y: focus.y + dy / len * gap)
                let clamped = clampCenter(ideal, sceneSize: sceneSize,
                                          diameter: diameter, insets: insets)
                let sep = hypot(clamped.x - focus.x, clamped.y - focus.y)
                guard sep >= diameter * minSeparation - 0.5 else { continue }

                let overlap = sightKeepout.map {
                    keepoutOverlap(center: clamped, diameter: diameter,
                                   sceneSize: sceneSize, keepout: $0)
                } ?? 0

                if overlap <= 0.5 {
                    return clamped
                }
                if overlap < bestSoftOverlap {
                    bestSoftOverlap = overlap
                    bestSoft = clamped
                }
            }
        }
        if let bestSoft { return bestSoft }

        // Last resort: screen corner of the open quadrant.
        let edges = EdgeClearance.of(focusNorm)
        let r = diameter / 2
        var x = edges.openHorizontal > 0
            ? sceneSize.width - insets.trailing - r
            : insets.leading + r
        if blockedSide == .leading {
            x = sceneSize.width - insets.trailing - r
        } else if blockedSide == .trailing {
            x = insets.leading + r
        }
        let y = edges.openVertical > 0
            ? sceneSize.height - insets.bottom - r
            : insets.top + r
        return CGPoint(x: x, y: y)
    }

    /// Open-quadrant diagonal first (ranked by free-run), then cardinals,
    /// then −potDir / ±perp.
    private static func directionCandidates(
        focus: CGPoint,
        focusNorm: CGPoint,
        sceneSize: CGSize,
        blockedSide: Side?,
        sightKeepout: SightKeepout?
    ) -> [(CGFloat, CGFloat)] {
        let edges = EdgeClearance.of(focusNorm)
        var scored: [(run: CGFloat, dir: (CGFloat, CGFloat))] = []

        func consider(_ raw: (CGFloat, CGFloat)) {
            let len = hypot(raw.0, raw.1)
            guard len > 1e-6 else { return }
            let u = (raw.0 / len, raw.1 / len)
            if blockedSide == .leading, u.0 < -1e-6 { return }
            if blockedSide == .trailing, u.0 > 1e-6 { return }
            let run = edges.freeRun(along: u, from: focusNorm)
            scored.append((run, u))
        }

        // 1) Empty quadrant diagonal — “更大的一部分区域”.
        consider(edges.openQuadrantDirection)
        // 2) The two open cardinals of that quadrant (stronger axis first).
        consider((edges.openHorizontal, 0))
        consider((0, edges.openVertical))
        // 3) Remaining cardinals by raw edge clearance.
        for d in edges.directionsByOpenness { consider(d) }

        if let keepout = sightKeepout {
            let w = max(sceneSize.width, 1)
            let h = max(sceneSize.height, 1)
            let pot = CGPoint(x: keepout.potEndNorm.x * w, y: keepout.potEndNorm.y * h)
            let pdx = pot.x - focus.x
            let pdy = pot.y - focus.y
            let plen = hypot(pdx, pdy)
            if plen > 1e-3 {
                let ux = pdx / plen, uy = pdy / plen
                consider((-ux, -uy))
                consider((-uy, ux))
                consider((uy, -ux))
            }
            if let asN = keepout.aimStartNorm, let aeN = keepout.aimEndNorm {
                let a = CGPoint(x: asN.x * w, y: asN.y * h)
                let b = CGPoint(x: aeN.x * w, y: aeN.y * h)
                let adx = b.x - a.x, ady = b.y - a.y
                let alen = hypot(adx, ady)
                if alen > 1e-3 {
                    let ax = adx / alen, ay = ady / alen
                    consider((-ay, ax))
                    consider((ay, -ax))
                }
            }
        }

        // Prefer longer free-run; stable dedup of near-identical dirs.
        scored.sort { $0.run > $1.run }
        var unique: [(CGFloat, CGFloat)] = []
        for item in scored {
            if unique.contains(where: {
                hypot($0.0 - item.dir.0, $0.1 - item.dir.1) < 1e-3
            }) { continue }
            unique.append(item.dir)
        }
        // Ensure open-quadrant diagonal is tried early even if free-run ties
        // with a cardinal (prepend if filtered out by sort noise).
        let quad = edges.openQuadrantDirection
        let qLen = hypot(quad.0, quad.1)
        if qLen > 1e-6 {
            let qu = (quad.0 / qLen, quad.1 / qLen)
            let wheelOK = (blockedSide != .leading || qu.0 >= -1e-6)
                && (blockedSide != .trailing || qu.0 <= 1e-6)
            if wheelOK, let idx = unique.firstIndex(where: {
                hypot($0.0 - qu.0, $0.1 - qu.1) < 1e-3
            }), idx > 0 {
                unique.remove(at: idx)
                unique.insert(qu, at: 0)
            }
        }
        return unique
    }

    static func alignment(_ corner: Corner) -> Alignment {
        switch corner {
        case .topLeading:     return .topLeading
        case .topTrailing:    return .topTrailing
        case .bottomLeading:  return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }

    private static func clampCenter(
        _ c: CGPoint,
        sceneSize: CGSize,
        diameter: CGFloat,
        insets: SafeInsets
    ) -> CGPoint {
        let r = diameter / 2
        let minX = insets.leading + r
        let maxX = sceneSize.width - insets.trailing - r
        let minY = insets.top + r
        let maxY = sceneSize.height - insets.bottom - r
        return CGPoint(
            x: min(max(c.x, minX), max(minX, maxX)),
            y: min(max(c.y, minY), max(minY, maxY))
        )
    }

    private static func isValid(
        _ center: CGPoint,
        focus: CGPoint,
        diameter: CGFloat,
        sceneSize: CGSize,
        insets: SafeInsets,
        minSeparation: CGFloat,
        sightKeepout: SightKeepout?
    ) -> Bool {
        let r = diameter / 2
        guard center.x >= insets.leading + r - 0.5,
              center.x <= sceneSize.width - insets.trailing - r + 0.5,
              center.y >= insets.top + r - 0.5,
              center.y <= sceneSize.height - insets.bottom - r + 0.5
        else { return false }
        guard hypot(center.x - focus.x, center.y - focus.y)
                >= diameter * minSeparation - 0.5
        else { return false }
        if let keepout = sightKeepout {
            return keepoutOverlap(center: center, diameter: diameter,
                                  sceneSize: sceneSize, keepout: keepout) <= 0.5
        }
        return true
    }

    /// Distance from point `p` to segment `a`–`b`.
    private static func distancePointToSegment(
        _ p: CGPoint, a: CGPoint, b: CGPoint
    ) -> CGFloat {
        let abx = b.x - a.x, aby = b.y - a.y
        let len2 = abx * abx + aby * aby
        guard len2 > 1e-12 else { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * abx + (p.y - a.y) * aby) / len2
        t = min(1, max(0, t))
        let qx = a.x + t * abx, qy = a.y + t * aby
        return hypot(p.x - qx, p.y - qy)
    }
}
