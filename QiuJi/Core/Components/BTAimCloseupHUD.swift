import SwiftUI

/// Aim closeup loupe: **same user geometry as the scene**, tighter framing
/// (问题集合 v23 / D-v23-2′ / D-v23-8).
///
/// Magnification = larger meters→points scale inside the circle, not a bitmap
/// crop. Layers are optional — pages only fill what the main scene already shows.
struct BTAimCloseupHUD: View {
    let snapshot: AimCloseupSnapshot
    var diameter: CGFloat = 128

    // Flat fill = median of the plain-pipeline USDZ cloth (SCNRenderer sample
    // ≈ RGB 25/111/18). No radial darkening — that made the loupe read as a
    // darker sticker even when the centre channel matched. Do **not** use
    // `btTableFelt` (#1B6B3A): its blue channel is ~40/255 too high (FL-028).
    private static let feltFill = Color(red: 25 / 255, green: 111 / 255, blue: 18 / 255)

    var body: some View {
        let half = snapshot.halfWorld
        let scale = diameter / (2 * half)
        ZStack {
            Circle()
                .fill(Self.feltFill)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.16), lineWidth: HUDStyle.hairlineWidth)
                )

            Canvas { ctx, size in
                drawLines(ctx: &ctx, size: size, scale: scale)
            }
            .clipShape(Circle())

            // Balls / markers as SwiftUI (PoolBallFace fidelity).
            ZStack {
                if let cue = snapshot.cue, inFrame(cue) {
                    ballView(number: nil, at: cue, scale: scale)
                }
                if let ghost = snapshot.ghost, inFrame(ghost) {
                    BTGhostCircle(diameter: snapshot.ballRadius * 2 * scale,
                                  showsAimPoint: snapshot.ghostShowsAimPoint)
                        .position(map(ghost, in: CGSize(width: diameter, height: diameter),
                                      scale: scale))
                }
                if snapshot.showsTargetBall, inFrame(snapshot.focus) {
                    ballView(number: snapshot.targetBallNumber, at: snapshot.focus, scale: scale)
                }
                if let p = snapshot.aimPointMarker, inFrame(p) {
                    BTAimPointDot(diameter: max(4, snapshot.ballRadius * 0.36 * scale))
                        .position(map(p, in: CGSize(width: diameter, height: diameter),
                                      scale: scale))
                }
                if let p = snapshot.contactMarker, inFrame(p) {
                    BTContactDot(diameter: max(3.5, snapshot.ballRadius * 0.30 * scale))
                        .position(map(p, in: CGSize(width: diameter, height: diameter),
                                      scale: scale))
                }
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())

            if snapshot.showMissCaption {
                Text("打空")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.45), in: Capsule())
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
        .accessibilityLabel(snapshot.showMissCaption ? "瞄准特写，打空" : "瞄准特写")
    }

    @ViewBuilder
    private func ballView(number: Int?, at world: CGPoint, scale: CGFloat) -> some View {
        let d = snapshot.ballRadius * 2 * scale
        BTFigureBall(number: number, diameter: d, showsShadow: false)
            .position(map(world, in: CGSize(width: diameter, height: diameter), scale: scale))
    }

    private func inFrame(_ p: CGPoint) -> Bool {
        let dx = p.x - snapshot.focus.x
        let dz = p.y - snapshot.focus.y
        return hypot(dx, dz) < snapshot.halfWorld * 1.35
    }

    private func map(_ world: CGPoint, in size: CGSize, scale: CGFloat) -> CGPoint {
        AimCloseupCoords.mapRotated(
            world: world,
            focus: snapshot.focus,
            origin: CGPoint(x: size.width / 2, y: size.height / 2),
            scale: scale
        )
    }

    private func drawLines(ctx: inout GraphicsContext, size: CGSize, scale: CGFloat) {
        func stroke(_ a: CGPoint, _ b: CGPoint, color: Color, width: CGFloat, dashed: Bool) {
            var path = Path()
            path.move(to: map(a, in: size, scale: scale))
            path.addLine(to: map(b, in: size, scale: scale))
            if dashed {
                ctx.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: width, dash: [5, 3.5]))
            } else {
                ctx.stroke(path, with: .color(color), lineWidth: width)
            }
        }

        if let pot = snapshot.potLine {
            stroke(pot.start, pot.end,
                   color: FigureLine.pot(number: snapshot.targetBallNumber),
                   width: 2.0, dashed: true)
        }
        if let aux = snapshot.auxLine {
            stroke(aux.start, aux.end, color: FigureLine.hint, width: 1.2, dashed: true)
        }
        if let aim = snapshot.aimLine {
            stroke(aim.start, aim.end, color: FigureLine.aim, width: 2.2, dashed: false)
        }
    }
}

/// Shared stage overlay for the loupe (问题集合 v23 W3): three-dot preference gate,
/// focus-relative placement, and center hysteresis in one place so host pages add
/// a single line instead of re-deriving placement.
///
/// Size the overlay to the **scene area** (same rect the `ShotStageProxy` uses),
/// since placement is expressed in scene points.
struct BTAimCloseupOverlay: View {
    let snapshot: AimCloseupSnapshot?
    let sceneSize: CGSize
    var diameter: CGFloat = 128
    var safeInsets: AimCloseupPlacement.SafeInsets = .aimWheelPage
    /// Column occupied by the aim wheel / thumb (loupe is pushed to the far side).
    var blockedSide: AimCloseupPlacement.Side? = .leading

    @ObservedObject private var prefs = UserPreferences.shared
    /// Placement hysteresis (scene pts); cleared when the loupe hides.
    @State private var center: CGPoint?

    private var isVisible: Bool { prefs.showAimCloseup && snapshot != nil }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if prefs.showAimCloseup, let snap = snapshot, sceneSize.height > 1 {
                let c = AimCloseupPlacement.center(
                    focusNorm: snap.focusNorm ?? CGPoint(x: 0.5, y: 0.5),
                    sceneSize: sceneSize,
                    diameter: diameter,
                    safeInsets: safeInsets,
                    blockedSide: blockedSide,
                    previous: center,
                    sightKeepout: snap.sightKeepout)
                BTAimCloseupHUD(snapshot: snap, diameter: diameter)
                    .position(c)
                    .onAppear { center = c }
                    .onChange(of: c) { _, new in center = new }
                    .transition(.opacity)
            }
        }
        .frame(width: sceneSize.width, height: sceneSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .animation(BTMotion.easeInOutFast, value: isVisible)
        .animation(BTMotion.easeInOutFast, value: center)
        .onChange(of: isVisible) { _, visible in
            if !visible { center = nil }
        }
    }
}

/// Layered closeup frame (planar meters: `CGPoint(x:X, y:Z)`).
/// Loupe mapping uses `AimCloseupCoords.mapRotated` (screen-up=+X, screen-right=+Z).
/// Omit a layer with `nil` / false.
struct AimCloseupSnapshot: Equatable {
    var band: AimProximityMath.Band
    /// Framing center (usually object-ball center).
    var focus: CGPoint
    var ballRadius: CGFloat
    /// Ortho half-height in meters (≈3.2R → object ball fills ~1/3 of loupe).
    var halfWorld: CGFloat

    var showsTargetBall: Bool = true
    var targetBallNumber: Int? = nil
    var cue: CGPoint? = nil
    var aimLine: AimCloseupSegment? = nil
    var potLine: AimCloseupSegment? = nil
    var auxLine: AimCloseupSegment? = nil
    var ghost: CGPoint? = nil
    var ghostShowsAimPoint: Bool = true
    var aimPointMarker: CGPoint? = nil
    var contactMarker: CGPoint? = nil
    var showMissCaption: Bool = false

    /// Focus in scene view 0…1 (top-leading origin) for placement; nil → trailing.
    var focusNorm: CGPoint? = nil
    /// Full-scene pot corridor the loupe must not cover (D-v23-5⁗); nil → no sight filter.
    var sightKeepout: AimCloseupPlacement.SightKeepout? = nil
}

struct AimCloseupSegment: Equatable {
    var start: CGPoint
    var end: CGPoint
}
