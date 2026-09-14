//
//  PocketNetPresentation.swift
//  QiuJi
//
//  W17-B/D (v63, DR-294 / DR-297 / DR-298): presentation-only descent of a planar-potted
//  ball through the net and down the ball-return rail, ending at a deterministic resting
//  slot against the rail's end stop (or the ball below). The pot verdict is the planar
//  drop-circle rule (DR-293); nothing here feeds back into physics or scoring.
//
//  Coordinate contract: SceneKit world, X–Z horizontal, Y up, metres. Pocket centres come
//  from `TableGeometry.pockets` (TablePhysics constants). The wall profile below is the
//  ball-CENTRE free region measured against the bundled USDZ (leather liner + cushion
//  jaws + net strands) with a sphere-vs-mesh flood probe at surfaceY = 0.8 (2 mm grid,
//  5 mm layers, 2026-09-14, `output/3d-v63/W17/leather-probe.log`) and is gated by
//  `PocketNetPresentationTests.testProfileMatchesBundledPocketMeshes`.
//

import Foundation
import SceneKit

/// Pocket wall profile used for the scripted descent, expressed directly for the ball
/// centre: at a given depth the centre may lie anywhere inside the star-shaped region
/// spanned by `reaches` around the ring axis. Rings run from the cloth surface down to the
/// net floor. The mouth is not round (jaws + back liner; the corner cup sits ~24 mm inward
/// of the planar drop centre), hence the polar table instead of one radius (DR-297).
struct PocketNetProfile {
    /// Polar directions per ring, 30° apart, angle measured from the inward X axis toward
    /// the inward Z axis (see `Ring.dx`).
    static let directions=12
    struct Ring {
        /// Depth of the ball's LOWEST point below the cloth surface (so depth 0 is a ball
        /// still sitting on the cloth, centre at surfaceY + R).
        let depth:Double
        /// Ring axis offset from the planar pocket centre along the mirror-consistent
        /// inward axes: `dx` along −sign(centre.x)·X, `dz` along −sign(centre.z)·Z (both
        /// point toward the table centre).
        let dx:Double
        let dz:Double
        /// Ball-centre reach (free distance) from the axis in each of the `directions`.
        /// Directions open toward the table are capped at the planar drop circle + 2 mm
        /// (the ball is inside the slate hole by the planar verdict).
        let reaches:[Double]
        /// Periodic linear interpolation of the reach at local `angle` (radians).
        func reach(atAngle angle:Double)->Double {
            let n=Double(reaches.count)
            var u=angle/(2*Double.pi)*n
            u=u-(u/n).rounded(.down)*n
            let i=Int(u)%reaches.count,j=(i+1)%reaches.count,f=u-Double(i)
            return reaches[i]+(reaches[j]-reaches[i])*f
        }
    }
    let rings:[Ring]
    /// Depth of the resting ball CENTRE below the cloth for the lowest slot.
    let restingDepth:Double

    /// Corner pockets (probe of pocket_0; pockets 1–3 are mirror-identical). Resting centre
    /// from the capture boundary: 0.69731 at surfaceY 0.8.
    static let corner=PocketNetProfile(rings:[
        Ring(depth:0.0000,dx:0.0183,dz:0.0163,reaches:[0.0170,0.0200,0.0205,0.0170,0.0125,0.0135,0.0175,0.0225,0.0225,0.0175,0.0135,0.0125]),
        Ring(depth:0.0050,dx:0.0184,dz:0.0161,reaches:[0.0190,0.0200,0.0205,0.0170,0.0150,0.0140,0.0175,0.0225,0.0225,0.0175,0.0135,0.0145]),
        Ring(depth:0.0100,dx:0.0190,dz:0.0170,reaches:[0.0205,0.0190,0.0195,0.0205,0.0140,0.0140,0.0180,0.0235,0.0235,0.0180,0.0140,0.0140]),
        Ring(depth:0.0150,dx:0.0188,dz:0.0168,reaches:[0.0220,0.0190,0.0195,0.0225,0.0145,0.0140,0.0180,0.0230,0.0230,0.0180,0.0140,0.0145]),
        Ring(depth:0.0200,dx:0.0203,dz:0.0184,reaches:[0.0200,0.0170,0.0175,0.0210,0.0150,0.0135,0.0195,0.0250,0.0250,0.0195,0.0135,0.0150]),
        Ring(depth:0.0250,dx:0.0186,dz:0.0167,reaches:[0.0225,0.0195,0.0200,0.0225,0.0145,0.0135,0.0180,0.0230,0.0230,0.0180,0.0135,0.0145]),
        Ring(depth:0.0300,dx:0.0170,dz:0.0152,reaches:[0.0200,0.0185,0.0185,0.0220,0.0140,0.0140,0.0165,0.0205,0.0205,0.0165,0.0145,0.0140]),
        Ring(depth:0.0350,dx:0.0162,dz:0.0147,reaches:[0.0190,0.0175,0.0180,0.0205,0.0145,0.0130,0.0175,0.0195,0.0185,0.0180,0.0140,0.0150]),
        Ring(depth:0.0400,dx:0.0155,dz:0.0136,reaches:[0.0200,0.0180,0.0180,0.0195,0.0160,0.0150,0.0165,0.0195,0.0195,0.0170,0.0155,0.0160]),
        Ring(depth:0.0450,dx:0.0142,dz:0.0124,reaches:[0.0190,0.0175,0.0180,0.0210,0.0170,0.0175,0.0175,0.0190,0.0185,0.0175,0.0180,0.0175]),
        Ring(depth:0.0500,dx:0.0125,dz:0.0107,reaches:[0.0210,0.0170,0.0175,0.0225,0.0190,0.0205,0.0195,0.0205,0.0205,0.0200,0.0205,0.0195]),
        Ring(depth:0.0550,dx:0.0106,dz:0.0087,reaches:[0.0225,0.0190,0.0210,0.0225,0.0235,0.0230,0.0220,0.0230,0.0230,0.0220,0.0230,0.0240]),
        Ring(depth:0.0600,dx:0.0071,dz:0.0047,reaches:[0.0260,0.0250,0.0240,0.0265,0.0285,0.0305,0.0265,0.0255,0.0255,0.0260,0.0300,0.0300]),
        Ring(depth:0.0650,dx:0.0069,dz:0.0040,reaches:[0.0245,0.0235,0.0245,0.0250,0.0280,0.0300,0.0240,0.0255,0.0245,0.0255,0.0290,0.0280]),
        Ring(depth:0.0700,dx:0.0070,dz:0.0041,reaches:[0.0240,0.0235,0.0240,0.0250,0.0265,0.0280,0.0245,0.0235,0.0245,0.0235,0.0280,0.0265]),
        Ring(depth:0.0750,dx:0.0072,dz:0.0040,reaches:[0.0220,0.0230,0.0240,0.0230,0.0245,0.0260,0.0225,0.0235,0.0220,0.0235,0.0270,0.0255]),
        Ring(depth:0.0800,dx:0.0072,dz:0.0041,reaches:[0.0220,0.0220,0.0220,0.0230,0.0245,0.0260,0.0225,0.0215,0.0225,0.0215,0.0245,0.0230]),
        Ring(depth:0.0850,dx:0.0074,dz:0.0044,reaches:[0.0200,0.0205,0.0220,0.0210,0.0220,0.0240,0.0205,0.0215,0.0210,0.0215,0.0235,0.0230]),
        Ring(depth:0.0900,dx:0.0078,dz:0.0046,reaches:[0.0195,0.0200,0.0215,0.0205,0.0190,0.0210,0.0190,0.0195,0.0205,0.0200,0.0225,0.0200]),
        Ring(depth:0.0950,dx:0.0086,dz:0.0048,reaches:[0.0185,0.0190,0.0215,0.0185,0.0190,0.0185,0.0180,0.0200,0.0195,0.0180,0.0205,0.0190]),
        Ring(depth:0.1000,dx:0.0092,dz:0.0049,reaches:[0.0160,0.0185,0.0190,0.0165,0.0165,0.0165,0.0185,0.0190,0.0185,0.0180,0.0185,0.0160]),
        Ring(depth:0.1050,dx:0.0102,dz:0.0049,reaches:[0.0150,0.0165,0.0190,0.0145,0.0145,0.0155,0.0175,0.0180,0.0165,0.0160,0.0165,0.0150]),
        Ring(depth:0.1100,dx:0.0112,dz:0.0043,reaches:[0.0120,0.0140,0.0170,0.0130,0.0125,0.0135,0.0145,0.0150,0.0155,0.0155,0.0155,0.0115]),
        Ring(depth:0.1150,dx:0.0121,dz:0.0038,reaches:[0.0110,0.0130,0.0155,0.0115,0.0130,0.0105,0.0115,0.0140,0.0145,0.0150,0.0125,0.0105]),
        Ring(depth:0.1200,dx:0.0135,dz:0.0032,reaches:[0.0080,0.0115,0.0140,0.0100,0.0115,0.0100,0.0105,0.0125,0.0120,0.0125,0.0115,0.0090]),
        Ring(depth:0.1250,dx:0.0141,dz:0.0020,reaches:[0.0070,0.0080,0.0105,0.0090,0.0105,0.0085,0.0095,0.0105,0.0105,0.0115,0.0100,0.0080]),
        Ring(depth:0.1300,dx:0.0147,dz:0.0012,reaches:[0.0065,0.0075,0.0090,0.0080,0.0075,0.0070,0.0060,0.0085,0.0075,0.0085,0.0090,0.0050])
    ],restingDepth:0.10269)
    /// Middle pockets (probe of pocket_4; pocket_5 mirror). Resting centre 0.69660.
    static let middle=PocketNetProfile(rings:[
        Ring(depth:0.0000,dx:-0.0000,dz:0.0071,reaches:[0.0150,0.0175,0.0390,0.0380,0.0390,0.0175,0.0150,0.0175,0.0280,0.0385,0.0280,0.0175]),
        Ring(depth:0.0050,dx:-0.0000,dz:0.0074,reaches:[0.0150,0.0175,0.0385,0.0380,0.0385,0.0175,0.0150,0.0175,0.0285,0.0385,0.0285,0.0175]),
        Ring(depth:0.0100,dx:-0.0000,dz:0.0077,reaches:[0.0150,0.0200,0.0385,0.0375,0.0385,0.0200,0.0150,0.0175,0.0290,0.0390,0.0290,0.0175]),
        Ring(depth:0.0150,dx:-0.0000,dz:0.0082,reaches:[0.0150,0.0200,0.0380,0.0370,0.0380,0.0200,0.0150,0.0175,0.0295,0.0395,0.0295,0.0175]),
        Ring(depth:0.0200,dx:-0.0003,dz:0.0110,reaches:[0.0175,0.0225,0.0355,0.0300,0.0355,0.0220,0.0170,0.0170,0.0295,0.0425,0.0310,0.0180]),
        Ring(depth:0.0250,dx:-0.0016,dz:0.0051,reaches:[0.0170,0.0240,0.0300,0.0300,0.0325,0.0180,0.0135,0.0155,0.0255,0.0365,0.0295,0.0195]),
        Ring(depth:0.0300,dx:-0.0013,dz:0.0017,reaches:[0.0165,0.0215,0.0270,0.0295,0.0295,0.0185,0.0140,0.0160,0.0235,0.0330,0.0285,0.0190]),
        Ring(depth:0.0350,dx:-0.0010,dz:-0.0005,reaches:[0.0185,0.0235,0.0245,0.0300,0.0275,0.0185,0.0160,0.0165,0.0240,0.0305,0.0260,0.0190]),
        Ring(depth:0.0400,dx:-0.0009,dz:-0.0022,reaches:[0.0180,0.0210,0.0225,0.0295,0.0245,0.0210,0.0165,0.0165,0.0245,0.0290,0.0265,0.0185]),
        Ring(depth:0.0450,dx:-0.0012,dz:-0.0045,reaches:[0.0185,0.0190,0.0225,0.0295,0.0250,0.0230,0.0160,0.0160,0.0240,0.0290,0.0265,0.0190]),
        Ring(depth:0.0500,dx:-0.0011,dz:-0.0069,reaches:[0.0185,0.0200,0.0230,0.0300,0.0255,0.0230,0.0160,0.0165,0.0240,0.0285,0.0280,0.0190]),
        Ring(depth:0.0550,dx:-0.0012,dz:-0.0089,reaches:[0.0205,0.0190,0.0245,0.0300,0.0255,0.0210,0.0180,0.0160,0.0240,0.0305,0.0280,0.0190]),
        Ring(depth:0.0600,dx:-0.0012,dz:-0.0110,reaches:[0.0185,0.0190,0.0245,0.0325,0.0280,0.0230,0.0160,0.0160,0.0255,0.0300,0.0285,0.0190]),
        Ring(depth:0.0650,dx:-0.0014,dz:-0.0128,reaches:[0.0205,0.0200,0.0250,0.0340,0.0275,0.0230,0.0180,0.0165,0.0275,0.0325,0.0290,0.0190]),
        Ring(depth:0.0700,dx:-0.0016,dz:-0.0131,reaches:[0.0190,0.0205,0.0260,0.0345,0.0270,0.0225,0.0195,0.0180,0.0270,0.0320,0.0295,0.0200]),
        Ring(depth:0.0750,dx:-0.0015,dz:-0.0115,reaches:[0.0190,0.0195,0.0240,0.0305,0.0260,0.0225,0.0195,0.0195,0.0250,0.0320,0.0275,0.0215]),
        Ring(depth:0.0800,dx:-0.0017,dz:-0.0100,reaches:[0.0170,0.0195,0.0220,0.0295,0.0230,0.0200,0.0195,0.0200,0.0230,0.0270,0.0255,0.0195]),
        Ring(depth:0.0850,dx:-0.0016,dz:-0.0080,reaches:[0.0170,0.0170,0.0215,0.0270,0.0220,0.0180,0.0175,0.0185,0.0200,0.0255,0.0220,0.0195]),
        Ring(depth:0.0900,dx:-0.0014,dz:-0.0058,reaches:[0.0165,0.0170,0.0195,0.0270,0.0195,0.0180,0.0160,0.0180,0.0195,0.0235,0.0210,0.0170]),
        Ring(depth:0.0950,dx:-0.0015,dz:-0.0036,reaches:[0.0145,0.0145,0.0170,0.0250,0.0195,0.0160,0.0160,0.0160,0.0195,0.0215,0.0205,0.0170]),
        Ring(depth:0.1000,dx:-0.0011,dz:-0.0014,reaches:[0.0145,0.0140,0.0170,0.0225,0.0190,0.0140,0.0140,0.0155,0.0185,0.0200,0.0205,0.0155]),
        Ring(depth:0.1050,dx:-0.0012,dz:-0.0004,reaches:[0.0125,0.0120,0.0155,0.0215,0.0160,0.0140,0.0120,0.0140,0.0170,0.0190,0.0170,0.0145]),
        Ring(depth:0.1100,dx:-0.0009,dz:0.0008,reaches:[0.0120,0.0115,0.0120,0.0185,0.0165,0.0125,0.0125,0.0120,0.0160,0.0160,0.0160,0.0140]),
        Ring(depth:0.1150,dx:-0.0007,dz:0.0009,reaches:[0.0120,0.0115,0.0115,0.0165,0.0130,0.0120,0.0125,0.0120,0.0140,0.0140,0.0155,0.0140]),
        Ring(depth:0.1200,dx:-0.0005,dz:0.0007,reaches:[0.0115,0.0090,0.0110,0.0145,0.0135,0.0125,0.0110,0.0100,0.0135,0.0140,0.0140,0.0115]),
        Ring(depth:0.1250,dx:-0.0004,dz:0.0001,reaches:[0.0095,0.0090,0.0080,0.0130,0.0105,0.0100,0.0090,0.0100,0.0095,0.0115,0.0110,0.0110]),
        Ring(depth:0.1300,dx:-0.0000,dz:-0.0002,reaches:[0.0075,0.0065,0.0065,0.0095,0.0100,0.0085,0.0090,0.0085,0.0100,0.0090,0.0105,0.0100])
    ],restingDepth:0.10340)

    static func forPocket(isCorner:Bool)->PocketNetProfile { isCorner ? corner : middle }

    /// Ball-centre height (world) at which the ball has left the net: the bottom ring of
    /// the bundled bag. Below it the polar table has no more rings and the ball is in the
    /// air above the return rail (DR-298).
    func netExitY(clothY:Double)->Double { clothY-restingDepth }

    /// Linear interpolation at (ball-bottom) `depth`, clamped to the first/last ring.
    func ring(atDepth depth:Double)->Ring {
        if depth<=rings[0].depth { return rings[0] }
        if depth>=rings[rings.count-1].depth { return rings[rings.count-1] }
        var i=0
        while i+1<rings.count-1 && rings[i+1].depth<depth { i+=1 }
        let a=rings[i],b=rings[i+1]
        let u=(depth-a.depth)/(b.depth-a.depth)
        return Ring(depth:depth,dx:a.dx+(b.dx-a.dx)*u,dz:a.dz+(b.dz-a.dz)*u,
                    reaches:zip(a.reaches,b.reaches).map { $0+($1-$0)*u })
    }
}

/// Ball-return rail under each net: two parallel rods (asset material `Black`) running
/// from the bottom ring of the bag along the inward X axis (`NetPocket.axisX`) down to a
/// `Gold` end stop at the table leg. Measured with a sphere-vs-mesh support probe on the
/// bundled USDZ (`TmpRailProbe`, 2026-09-14, DR-298): the ball-centre trough is a straight
/// line in the vertical plane through the pocket centre, lateral offset ≤ 3 mm (ignored).
///
/// Coordinates: SceneKit world, Y up, metres. `s` is the horizontal distance from the
/// pocket centre along `axisX`; the trough height is `clothY - startDrop + slope * s`.
struct PocketRailProfile {
    /// Cloth height minus ball-centre trough height at s = 0 (the pocket centre).
    let startDrop:Double
    /// dy/ds of the trough (negative: downhill away from the pocket).
    let slope:Double
    /// `s` of a ball centre resting against the end stop.
    let stopDistance:Double
    /// Smallest `s` at which the ball body is clear of the bag's bottom ring; no resting
    /// slot is placed closer to the pocket than this.
    let firstClearDistance:Double

    /// Corner pockets: trough 0.6190 m at s 0.030 → 0.5635 m at s 0.160 (cloth 0.8),
    /// end stop touched at s 0.165.
    static let corner=PocketRailProfile(startDrop:0.1682,slope:-0.427,stopDistance:0.162,firstClearDistance:0.030)
    /// Middle pockets: trough 0.6170 m at s 0.015 → 0.5615 m at s 0.145, end stop at s 0.150.
    static let middle=PocketRailProfile(startDrop:0.1766,slope:-0.427,stopDistance:0.148,firstClearDistance:0.015)

    static func forPocket(isCorner:Bool)->PocketRailProfile { isCorner ? corner : middle }

    /// cos of the incline angle (horizontal advance per unit of arc length).
    var cosIncline:Double { 1/sqrt(1+slope*slope) }
    /// sin of the incline angle.
    var sinIncline:Double { -slope*cosIncline }
}

/// Builds and attaches the scripted net descent for every planar pot in a recorder.
enum PocketNetPresentation {
    typealias V=SIMD3<Double>
    typealias State=LocalPocketSimulation.State

    /// Fixed presentation step. 240 Hz keeps the wall projection error far below a pixel
    /// at any playback speed while a 1.5 s descent stays under 400 samples.
    static let sampleStep:Double=1/240
    /// Hard cap on the scripted fall; a ball not resting by then is eased to its slot.
    static let maxDescentDuration:Double=1.5
    /// Eased settle onto the exact slot after the scripted wall/floor contact.
    static let settleDuration:Double=0.12
    /// Rolling factor of a solid sphere on the rail (a = g sinθ / (1 + 2/5)), the rods
    /// treated as a plane support.
    static let rollingFactor:Double=5.0/7.0
    /// Time constant over which the V of the two rods centres a ball that landed off the
    /// trough line (the ball leaves the bag up to ~7 mm off its axis). Short: the landing
    /// impulse itself throws the ball into the groove.
    static let railCentringTime:Double=0.01
    /// Normal approach speed above which the ARRIVAL at the liner counts as an impact
    /// (tangential velocity and spin scaled once by the retention, DR-292). Slower
    /// arrivals and every later step are sustained sliding.
    static let impactSpeed:Double=0.05
    /// While sliding on the liner, the azimuthal (orbiting) velocity decays with this
    /// time constant (soft leather grip). The downslope motion is never damped except by
    /// Coulomb friction on the normal load, so the fall follows gravity and the wall
    /// shape (DR-297 — the previous per-step retention on the whole velocity made the
    /// ball creep down corner pockets at ~0.07 m/s).
    static let linerGripTime:Double=0.05
    /// Spin decay time constant while in contact (visual only).
    static let spinDecayTime:Double=0.15
    /// The planar drop circle (R 42–43 mm around the planar centre) is larger than the
    /// visual mouth, so a capture snapshot can already overlap the liner. That initial
    /// overlap is bled off over this duration instead of snapping the ball.
    static let entryRelaxDuration:Double=0.06

    struct NetPocket {
        let id:String
        let center:V
        let dropRadius:Double
        /// Inward unit axes (toward the table centre), see `PocketNetProfile.Ring`.
        let axisX:V
        let axisZ:V
        let profile:PocketNetProfile
        let rail:PocketRailProfile
        init(pocket:Pocket,surfaceY:Double) {
            id=pocket.id
            center=V(Double(pocket.center.x),surfaceY,Double(pocket.center.z))
            dropRadius=Double(pocket.radius)
            profile=PocketNetProfile.forPocket(isCorner:pocket.isCorner)
            rail=PocketRailProfile.forPocket(isCorner:pocket.isCorner)
            axisX=V(pocket.center.x>0 ? -1 : 1,0,0)
            axisZ=V(0,0,pocket.center.z>0 ? -1 : 1)
        }
        /// Ball-centre height at which the ball leaves the bag through its bottom ring.
        var netExitY:Double { profile.netExitY(clothY:center.y) }
        /// Trough point at horizontal distance `s` along the rail (`axisX`).
        func railPoint(atDistance s:Double)->V {
            center+axisX*s+V(0,-rail.startDrop+rail.slope*s,0)
        }
        /// Unit tangent of the rail, pointing downhill (away from the pocket).
        var railTangent:V { simd_normalize(axisX+V(0,rail.slope,0)) }
        /// Unit normal of the rail support, pointing up out of the trough.
        var railNormal:V { let t=railTangent; return simd_normalize(V(0,1,0)-t*t.y) }
        /// Horizontal distance of `p` along the rail from the pocket centre.
        func railDistance(of p:V)->Double { dot(p-center,axisX) }
        /// Trough height under horizontal position `p` (its `s` along the rail).
        func railHeight(under p:V)->Double { railPoint(atDistance:railDistance(of:p)).y }
        /// Interpolated ring for a ball whose centre is at world `y`.
        func ring(at y:Double,ballRadius:Double)->PocketNetProfile.Ring {
            profile.ring(atDepth:center.y-(y-ballRadius))
        }
        /// Ring axis point (world) for a ball centre at world `y`.
        func axis(at y:Double,ballRadius:Double)->V {
            let r=ring(at:y,ballRadius:ballRadius)
            let a=center+axisX*r.dx+axisZ*r.dz
            return V(a.x,y,a.z)
        }
        /// Local polar angle of a horizontal unit direction (from inward X toward inward Z).
        func angle(of direction:V)->Double { atan2(dot(direction,axisZ),dot(direction,axisX)) }
        /// Ball-centre reach from the axis toward horizontal unit `outward` at world `y`.
        func reach(at y:Double,toward outward:V,ballRadius:Double)->Double {
            max(0.001,ring(at:y,ballRadius:ballRadius).reach(atAngle:angle(of:outward)))
        }
        /// Point on the wall surface at height `y` in direction `outward`.
        func surfacePoint(at y:Double,toward outward:V,ballRadius:Double)->V {
            axis(at:y,ballRadius:ballRadius)+outward*reach(at:y,toward:outward,ballRadius:ballRadius)
        }
        /// Outward unit normal of the wall surface met by a centre at height `y` in
        /// horizontal direction `outward` (unit): cross product of the vertical and
        /// azimuthal surface tangents (central differences over the polar table), so a
        /// narrowing wall tilts the normal downward and a flaring one upward.
        func wallNormal(at y:Double,outward:V,ballRadius:Double)->V {
            let h=0.001,da=Double.pi/72
            let up=surfacePoint(at:y+h,toward:outward,ballRadius:ballRadius)
            let down=surfacePoint(at:y-h,toward:outward,ballRadius:ballRadius)
            let side=V(outward.z,0,-outward.x)
            let plus=simd_normalize(outward*cos(da)+side*sin(da)),minus=simd_normalize(outward*cos(da)-side*sin(da))
            let left=surfacePoint(at:y,toward:plus,ballRadius:ballRadius)
            let right=surfacePoint(at:y,toward:minus,ballRadius:ballRadius)
            var n=cross(up-down,left-right)
            let len=length(n)
            guard len>1e-12 else { return outward }
            n/=len
            return dot(n,outward)<0 ? -n : n
        }
        /// Deterministic resting slots on the rail, lowest first: the first ball rests
        /// against the end stop, each later one against the ball below it (centre
        /// distance 2R along the incline). Slots stop where the ball body would still be
        /// inside the bag's bottom ring; that count is the pocket's FIFO capacity.
        func slots(ballRadius:Double)->[V] {
            var slots:[V]=[]
            var s=rail.stopDistance
            while s>=rail.firstClearDistance-1e-9 {
                slots.append(railPoint(atDistance:s))
                s-=2*ballRadius*rail.cosIncline
            }
            return slots
        }
    }

    /// Script one ball's fall from its planar capture snapshot to `slot` on the rail.
    ///
    /// Gravity is the only accelerating force. Three phases (DR-298):
    /// 1. **Net** (centre above `pocket.netExitY`): the liner is the dissipative body of
    ///    DR-292 — an approach faster than `impactSpeed` scales the tangential velocity by
    ///    `retention` (the same `TablePhysics.pocketLinerRetention` as the spatial model);
    ///    sustained contact removes the normal component (sliding along the wall slope)
    ///    and bleeds the horizontal velocity with `linerGripTime`.
    /// 2. **Air**: below the bag's bottom ring the ball falls freely onto the rail. (The
    ///    bundled ring is modelled ~2.5 mm tighter than the ball; the real product is
    ///    open, so the script passes through it.)
    /// 3. **Rail**: zero-restitution landing keeps only the downhill component, then the
    ///    ball rolls (`rollingFactor`) down the trough and stops dead at the slot — the
    ///    end stop or the ball below it.
    static func descent(from start:State,pocket:NetPocket,slot:V,ballRadius:Double,gravity:Double,
                        retention:Double,friction:Double=Double(TablePhysics.cushionFriction))->[State] {
        var s=start,samples=[start]
        let dt=sampleStep
        let end=start.time+maxDescentDuration
        let slideKeep=exp(-dt/linerGripTime),spinKeep=exp(-dt/spinDecayTime)
        let centringKeep=exp(-dt/railCentringTime)
        var inContact=false,onRail=false
        var along=0.0,vAlong=0.0,lateral=0.0
        let tangent=pocket.railTangent,normal=pocket.railNormal,cosIncline=pocket.rail.cosIncline
        let slotDistance=pocket.railDistance(of:slot)
        let entryOverlap:Double={
            let a=pocket.axis(at:start.position.y,ballRadius:ballRadius)
            let d=V(start.position.x-a.x,0,start.position.z-a.z),dist=length(d)
            return dist>1e-12 ? max(0,dist-pocket.reach(at:start.position.y,toward:d/dist,ballRadius:ballRadius)) : 0
        }()
        while s.time<end {
            var v=s.velocity,omega=s.omega
            let t=s.time+dt
            if onRail {
                // Rolling down the incline; the rods centre the ball onto the trough line.
                vAlong+=gravity*pocket.rail.sinIncline*rollingFactor*dt
                along+=vAlong*cosIncline*dt
                lateral*=centringKeep
                if along>=slotDistance {
                    // Dead stop against the end stop / the ball below: exactly on the slot.
                    s=State(time:t,position:slot,velocity:.zero,omega:.zero)
                    samples.append(s)
                    break
                }
                v=tangent*vAlong
                omega=cross(normal,v)/ballRadius
                s=State(time:t,position:pocket.railPoint(atDistance:along)+pocket.axisZ*lateral,velocity:v,omega:omega)
                samples.append(s)
                continue
            }
            v.y-=gravity*dt
            var p=s.position+v*dt
            // Landing on the rail (only reachable below the bag's bottom ring).
            if p.y<=pocket.railHeight(under:p) {
                onRail=true
                along=pocket.railDistance(of:p)
                lateral=dot(p-pocket.center,pocket.axisZ)
                // Dead landing: the rods take the normal and lateral components; the
                // ball never rolls back up into the net.
                vAlong=max(0,dot(v,tangent))
                v=tangent*vAlong
                omega=cross(normal,v)/ballRadius
                s=State(time:t,position:pocket.railPoint(atDistance:along)+pocket.axisZ*lateral,velocity:v,omega:omega)
                samples.append(s)
                continue
            }
            if p.y<=pocket.netExitY {
                // Through the bottom ring: free fall, no more walls.
                inContact=false
                s=State(time:t,position:p,velocity:v,omega:omega)
                samples.append(s)
                continue
            }
            // Wall: project the centre back inside the ring, then respond to the approach.
            let allowance=entryOverlap*max(0,1-(t-start.time)/entryRelaxDuration)
            let axis=pocket.axis(at:p.y,ballRadius:ballRadius)
            let d=V(p.x-axis.x,0,p.z-axis.z)
            let dist=length(d)
            let outward=dist>1e-12 ? d/dist : pocket.axisX
            let reach=pocket.reach(at:p.y,toward:outward,ballRadius:ballRadius)
            if dist>reach+allowance {
                let n=pocket.wallNormal(at:p.y,outward:outward,ballRadius:ballRadius)
                p.x=axis.x+outward.x*(reach+allowance);p.z=axis.z+outward.z*(reach+allowance)
                let vn=dot(v,n)
                if vn>0 {
                    // Geometry first: the wall removes the approach component, so a sloped
                    // wall redirects the fall (the only thing that ever shapes `v.y`).
                    v-=n*vn
                    if !inContact && vn>impactSpeed {
                        // Arrival impact on the soft liner (DR-292): keep `retention` of the
                        // tangential velocity and spin, exactly like the spatial `linerSink`.
                        v*=retention;omega*=retention
                    } else {
                        // Sustained sliding. Split the tangent plane into the downslope
                        // direction `slope` (gravity's pull along the wall) and the azimuthal
                        // direction `around` (orbiting the cup). The liner grips the orbit
                        // (`linerGripTime`) and resists the slide only through Coulomb
                        // friction on the normal load; gravity along the slope is untouched.
                        var slope=V(0,-1,0)-n*dot(V(0,-1,0),n)
                        let slopeLen=length(slope)
                        if slopeLen>1e-9 {
                            slope/=slopeLen
                            let around=cross(n,slope)
                            let vAround=dot(v,around),vSlope=dot(v,slope)
                            let load=max(0,-gravity*n.y)+vAround*vAround/max(reach,0.001)
                            let slid=vSlope>0 ? max(0,vSlope-friction*load*dt) : vSlope
                            v=slope*slid+around*(vAround*slideKeep)
                        } else {
                            v.x*=slideKeep;v.z*=slideKeep
                        }
                        omega*=spinKeep
                    }
                }
                // The soft skirt absorbs; it never lifts the ball.
                if v.y>0 { v.y=0 }
                inContact=true
            } else {
                inContact=false
            }
            s=State(time:t,position:p,velocity:v,omega:omega)
            samples.append(s)
        }
        // Eased settle onto the exact slot (position only; residual spin decays with it).
        let from=s
        let steps=max(1,Int((settleDuration/dt).rounded(.up)))
        for k in 1...steps {
            let u=Double(k)/Double(steps),e=1-(1-u)*(1-u)
            samples.append(State(time:from.time+settleDuration*u,position:k==steps ? slot : from.position+(slot-from.position)*e,
                                 velocity:.zero,omega:from.omega*(1-u)))
        }
        return samples
    }

    /// Short eased move used when a resting ball slides down after a FIFO eviction.
    static func shift(from start:State,to slot:V)->[State] {
        let dt=sampleStep,steps=max(1,Int((settleDuration/dt).rounded(.up)))
        var samples=[start]
        for k in 1...steps {
            let u=Double(k)/Double(steps),e=1-(1-u)*(1-u)
            samples.append(State(time:start.time+settleDuration*u,position:k==steps ? slot : start.position+(slot-start.position)*e,
                                 velocity:.zero,omega:.zero))
        }
        return samples
    }

    /// Attach net tails for every planar pocket entry that has none yet. Idempotent.
    /// Failures are printed (never swallowed) and leave the legacy fade path in place.
    static func attach(to recorder:TrajectoryRecorder) {
        let entries=recorder.pocketEntries.filter { recorder.collectionTailsByBallName[$0.ball.name]==nil }
        guard !entries.isEmpty else { return }
        let ballRadius=Double(BallPhysics.radius),gravity=Double(TablePhysics.gravity)
        let retention=Double(TablePhysics.pocketLinerRetention)
        // Every snapshot carries the planar geometry it was judged against; its pocket
        // centres sit on the cloth surface (TableGeometry.chineseEightBallQiuJi(surfaceY:)).
        // `TrajectoryPlayback.surfaceY` is the ball-centre plane and is deliberately not used.
        var pockets:[String:NetPocket]=[:]
        for entry in recorder.pocketEntries {
            for pocket in entry.geometry.pockets where pockets[pocket.id]==nil {
                pockets[pocket.id]=NetPocket(pocket:pocket,surfaceY:Double(pocket.center.y))
            }
        }
        // Planar tails already in this recorder occupy slots (FIFO order by entry time).
        var queues:[String:[(ball:String,slot:Int,time:Double)]]=[:]
        for (name,tail) in recorder.collectionTailsByBallName where tail.samples != nil && tail.fadeStart==nil {
            guard let entry=recorder.pocketEntries.last(where:{$0.ball.name==name}),let pocket=pockets[entry.pocketID] else { continue }
            let slots=pocket.slots(ballRadius:ballRadius)
            let slot=slots.indices.min { length(slots[$0]-tail.end.position)<length(slots[$1]-tail.end.position) } ?? 0
            queues[entry.pocketID,default:[]].append((name,slot,Double(entry.time)))
        }
        for pocketID in queues.keys { queues[pocketID]?.sort { $0.time<$1.time } }
        for entry in entries.sorted(by:{ $0.time<$1.time }) {
            guard let pocket=pockets[entry.pocketID] else {
                print("[W17 net presentation] unknown pocket \(entry.pocketID) for \(entry.ball.name)")
                continue
            }
            let b=entry.ball
            let start=State(time:Double(entry.time),
                            position:V(Double(b.position.x),pocket.center.y+ballRadius,Double(b.position.z)),
                            velocity:V(Double(b.velocity.x),0,Double(b.velocity.z)),
                            omega:V(Double(b.angularVelocity.x),Double(b.angularVelocity.y),Double(b.angularVelocity.z)))
            let slots=pocket.slots(ballRadius:ballRadius)
            var queue=queues[entry.pocketID] ?? []
            do {
                if queue.count>=slots.count {
                    // FIFO: the oldest ball is recycled the moment the new one starts falling;
                    // everyone above it slides down one slot.
                    let evicted=queue.removeFirst()
                    if let old=recorder.collectionTailsByBallName[evicted.ball],let samples=old.samples {
                        try recorder.recordPlanarCollectionTail(ballName:evicted.ball,
                            tail:PocketCollectionTail(samples:samples,gravity:gravity,fadeStart:start.time))
                    }
                    for i in queue.indices where queue[i].slot>0 {
                        let name=queue[i].ball
                        guard let old=recorder.collectionTailsByBallName[name],var samples=old.samples else { continue }
                        var from=old.end
                        from.time=max(old.end.time,start.time)
                        if from.time>old.end.time { samples.append(from) }
                        samples.append(contentsOf:shift(from:from,to:slots[queue[i].slot-1]).dropFirst())
                        try recorder.recordPlanarCollectionTail(ballName:name,tail:PocketCollectionTail(samples:samples,gravity:gravity))
                        queue[i].slot-=1
                    }
                }
                let slotIndex=min(queue.count,slots.count-1)
                let samples=descent(from:start,pocket:pocket,slot:slots[slotIndex],ballRadius:ballRadius,gravity:gravity,retention:retention)
                try recorder.recordPlanarCollectionTail(ballName:b.name,tail:PocketCollectionTail(samples:samples,gravity:gravity))
                queue.append((b.name,slotIndex,start.time))
                queues[entry.pocketID]=queue
            } catch {
                print("[W17 net presentation] failed for \(b.name) in \(entry.pocketID): \(error)")
            }
        }
    }
}
