import Foundation

/// Shared single-shot comfort, XZ metres. A ranking score, never a pot probability.
enum ShotComfortScore {
    struct Geometry {
        let length, width, radius: Double
        static let qiuJi = Self(length: Double(AngleSceneCalculator.innerLength),
            width: Double(AngleSceneCalculator.innerWidth), radius: Double(AngleSceneCalculator.ballRadius))
    }
    struct Result { let distance, space, angle, total: Double }
    static func evaluate(cue: (Double, Double), ball: (Double, Double), aim p: (Double, Double),
                         geometry g: Geometry = .qiuJi, pocketDistanceAngle: Bool = true) -> Result? {
        guard [cue.0, cue.1, ball.0, ball.1, p.0, p.1, g.length, g.width, g.radius].allSatisfy(\.isFinite),
              g.radius > 0, g.length > 2*g.radius, g.width > 2*g.radius else { return nil }
        let d = hypot(p.0-ball.0,p.1-ball.1), cueDistance = hypot(cue.0-ball.0,cue.1-ball.1)
        guard d > 1e-9, cueDistance >= 2*g.radius else { return nil }
        let ux = (p.0-ball.0)/d, uz = (p.1-ball.1)/d
        let vx = ball.0-2*g.radius*ux-cue.0, vz = ball.1-2*g.radius*uz-cue.1
        let norm = hypot(vx,vz), dot = vx*ux+vz*uz
        guard norm > 1e-9, dot > 1e-12, (d*norm/dot).isFinite else { return nil }
        let cutDegrees = atan2(abs(vx*uz-vz*ux),dot)*180/Double.pi
        let length = hypot(p.0-ball.0, p.1-ball.1)
        let nx = (p.0-ball.0)/length, nz = (p.1-ball.1)/length
        let hx = g.length/2, hz = g.width/2, r = g.radius
        let depth = max(0, zip([ball.0, ball.1], zip([-nx, -nz], [hx-r, hz-r])).compactMap { pos, axis -> Double? in
            let (direction, bound) = axis
            guard abs(direction) > 1e-12 else { return nil }
            return ((direction > 0 ? bound : -bound)-pos)/direction
        }.min() ?? 0)
        let scale = min(1, max(0.4, depth/0.9)), lo = 0.5*scale, hi = 0.8*scale
        let near = max(lo-cueDistance, 0)/(0.8*lo), far = max(cueDistance-hi, 0)/0.75
        let distance = 100*exp(-near*near-far*far)
        let bx = -vx/norm, bz = -vz/norm
        let gaps = [hx-cue.0-r, hx+cue.0-r, hz-cue.1-r, hz+cue.1-r]
        let directions: [Double] = [bx, -bx, bz, -bz]
        let penalties: [Double] = zip(gaps, directions).map { gap, direction in
            let t = max(direction, 0.0)
            let proximity = max(gap, 0.0) * 100.0 / 8.0
            return (45.0 + 15.0 * t * t) * exp(-pow(proximity, 1.2))
        }
        let main = penalties.indices.max(by: { penalties[$0] < penalties[$1] }) ?? 0
        let adjacent = main < 2 ? max(penalties[2], penalties[3]) : max(penalties[0], penalties[1])
        let space = 100-penalties[main]-min(8, 0.25*adjacent)
        // Metres internally: at <= 60 cm the plateau is 15 degrees and decay scale is 20.
        // Beyond 60 cm both contract. Short pots never widen the full-score plateau.
        let plateau = pocketDistanceAngle ? min(15, 9/length) : 15
        let decay = pocketDistanceAngle ? min(20, 20*sqrt(0.6/length)) : 30
        let angle = 100*exp(-pow(max(cutDegrees-plateau, 0)/decay, 2))
        let geometricMean = pow(distance*space*angle, 1.0/3)
        let total = pocketDistanceAngle ? 0.5*min(distance, space, angle) + 0.5*geometricMean : geometricMean
        return .init(distance: distance, space: space, angle: angle, total: total)
    }
}
