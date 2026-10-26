import Foundation
import SceneKit

/// Target-ball centre region only; does not test cue access, obstacles or guarantee a pot.
enum MiddlePocketRegion {
    enum Assessment { case inside, outside, uncalibrated }
    struct Calibration {
        let halfWidth: Double
        let ballRadius: Double
        let inset: Double
        let slope: Double
        let version = "qiuji-r30-measured-lip-20261026"
    }
    /// Bound to the measured production mouths, not every table with a 2:1 rectangle.
    static func calibration(table: TableGeometry, length: Float, width: Float, radius: Float) -> Calibration? {
        guard length == Float(2.54), width == Float(1.27), radius == Float(0.028575),
              table.pockets.count == 6 else { return nil }
        let lip: [SIMD2<Double>] = [
            SIMD2(-0.0449813455, 0.6593745947),
            SIMD2(-0.0410947837, 0.6519642472),
            SIMD2(-0.0330508649, 0.6421130896),
            SIMD2(-0.0237892047, 0.6345483065),
            SIMD2(-0.0163746458, 0.63064605),
            SIMD2(-0.0083441976, 0.6282565594),
            SIMD2(0, 0.6274516582),
            SIMD2(0.0083441976, 0.6282565594),
            SIMD2(0.0163746458, 0.63064605),
            SIMD2(0.0237892047, 0.6345483065),
            SIMD2(0.0330508649, 0.6421130896),
            SIMD2(0.0410947837, 0.6519642472),
            SIMD2(0.0449813455, 0.6593745947),
        ]
        for (index, side) in [(4, -1.0), (5, 1.0)] {
            let p = table.pockets[index]
            let expectedLip = side > 0 ? lip : lip.reversed().map { SIMD2($0.x, -$0.y) }
            guard p.id == "pocket_\(index)", p.center.x == 0,
                  p.center.z == Float(side * 0.6759647130966187), p.radius == Float(0.043),
                  p.captureLip == expectedLip else { return nil }
            for hand: Float in [-1, 1] {
                let start: Float = side < 0 ? (hand < 0 ? 0 : .pi / 2) : (hand < 0 ? 1.5 * .pi : .pi)
                let end: Float = side < 0 ? (hand < 0 ? .pi / 2 : .pi) : (hand < 0 ? 2 * .pi : 1.5 * .pi)
                guard table.circularCushions.contains(where: {
                    abs($0.center.x - hand * 0.073) < 1e-7 && abs($0.center.z - Float(side) * 0.665) < 1e-7
                    && $0.radius == Float(0.03) && $0.startAngle == start && $0.endAngle == end
                }) else { return nil }
            }
        }
        return .init(halfWidth: Double(width)/2, ballRadius: Double(radius),
            inset: 0.009263577585997284, slope: 0.29983165331981754)
    }
    static let production = calibration(table: .chineseEightBallQiuJi(surfaceY: 0),
        length: AngleSceneCalculator.innerLength, width: AngleSceneCalculator.innerWidth,
        radius: AngleSceneCalculator.ballRadius)

    static func assess(target: SCNVector3, pocket: Int, calibration: Calibration?) -> Assessment {
        guard pocket == 4 || pocket == 5, let c = calibration,
              target.x.isFinite, target.z.isFinite else { return .uncalibrated }
        let side = pocket == 4 ? -1.0 : 1.0
        let depth = c.halfWidth - side * Double(target.z)
        // Solely absorb Float coordinate roundoff (not a gameplay safety margin).
        let roundoff = Double(4 * Float.ulpOfOne)
        return depth + roundoff >= c.inset + c.slope * abs(Double(target.x)) ? .inside : .outside
    }
}
