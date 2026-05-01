import Foundation
import CoreGraphics

// MARK: - Pocket Type

enum PocketType: String, CaseIterable, Codable {
    case corner
    case side
}

// MARK: - Pocket Position

struct PocketPosition: Equatable {
    let x: Double
    let y: Double
    let type: PocketType
    let label: String
}

// MARK: - Angle Question

struct AngleQuestion {
    let targetBall: CGPoint
    let cueBall: CGPoint
    let pocket: PocketPosition
    let actualAngle: Double
    let pocketType: PocketType
}

// MARK: - Calculator

enum AngleCalculator {

    /// sin(α) × R  — contact point offset as fraction of ball radius.
    static func contactPointOffset(angle: Double) -> Double {
        sin(angle * .pi / 180.0)
    }

    /// Random angle in 5° increments for the given pocket type.
    static func randomAngle(pocketType: PocketType) -> Double {
        switch pocketType {
        case .corner: return Double(Int.random(in: 1...17) * 5)   // 5–85
        case .side:   return Double(Int.random(in: 3...12) * 5)   // 15–60
        }
    }

    // MARK: Pocket geometry (normalised table coords: x 0→1, y 0→0.5)

    static let pockets: [PocketPosition] = [
        // Labels are named from the rotated 2D training view:
        // screen-up = world +X, screen-right = world +Z.
        PocketPosition(x: 0.0, y: 0.0,  type: .corner, label: "左下"),
        PocketPosition(x: 1.0, y: 0.0,  type: .corner, label: "左上"),
        PocketPosition(x: 0.0, y: 0.5,  type: .corner, label: "右下"),
        PocketPosition(x: 1.0, y: 0.5,  type: .corner, label: "右上"),
        PocketPosition(x: 0.5, y: 0.0,  type: .side,   label: "左中"),
        PocketPosition(x: 0.5, y: 0.5,  type: .side,   label: "右中"),
    ]

    // MARK: Question generation

    /// 2R expressed in normalised coordinates. Both axes scale identically: 1 normalised
    /// unit = innerLength (2.54 m) per `AngleSceneCalculator.normalizedToScene`.
    private static let normalizedTwoRadius: Double =
        Double(2 * AngleSceneCalculator.ballRadius) / Double(AngleSceneCalculator.innerLength)

    static func generateQuestion(
        angle: Double,
        pocketType: PocketType? = nil,
        targetPocketDistanceRange: ClosedRange<Double> = 0.12...0.65
    ) -> AngleQuestion {
        let candidates = pocketType.map { type in pockets.filter { $0.type == type } } ?? pockets
        let pocket = candidates.randomElement()!

        let margin    = 0.06
        let minPocket = targetPocketDistanceRange.lowerBound
        let maxPocket = targetPocketDistanceRange.upperBound
        let cueDist   = Double.random(in: 0.15...0.35)
        let cutRad    = angle * .pi / 180.0

        for _ in 0..<200 {
            let tx = Double.random(in: margin...(1.0 - margin))
            let ty = Double.random(in: margin...(0.5 - margin))

            let dx = pocket.x - tx
            let dy = pocket.y - ty
            let dist = sqrt(dx * dx + dy * dy)
            guard dist >= minPocket, dist <= maxPocket else { continue }
            guard nearestPocket(to: CGPoint(x: tx, y: ty), among: candidates).label == pocket.label else {
                continue
            }

            let toPocket = atan2(dy, dx)
            let side: Double = Bool.random() ? 1.0 : -1.0
            let approach = toPocket + side * cutRad

            // Place cue ball relative to GHOST ball (target - 2R along pocket line),
            // not target — strike line (cue→ghost) must make angle α with pocket line.
            let ghostX = tx - normalizedTwoRadius * cos(toPocket)
            let ghostY = ty - normalizedTwoRadius * sin(toPocket)
            let cx = ghostX - cueDist * cos(approach)
            let cy = ghostY - cueDist * sin(approach)
            guard cx >= margin, cx <= 1.0 - margin,
                  cy >= margin, cy <= 0.5 - margin else { continue }

            return AngleQuestion(targetBall: CGPoint(x: tx, y: ty),
                                 cueBall: CGPoint(x: cx, y: cy),
                                 pocket: pocket, actualAngle: angle,
                                 pocketType: pocket.type)
        }

        return fallbackQuestion(angle: angle, pocket: pocket,
                                targetPocketDistanceRange: targetPocketDistanceRange,
                                cueDist: cueDist, cutRad: cutRad,
                                pocketType: pocket.type)
    }

    // MARK: - Private

    private static func nearestPocket(to target: CGPoint, among candidates: [PocketPosition]) -> PocketPosition {
        candidates.min { a, b in
            let da = hypot(a.x - Double(target.x), a.y - Double(target.y))
            let db = hypot(b.x - Double(target.x), b.y - Double(target.y))
            return da < db
        } ?? candidates[0]
    }

    private static func fallbackQuestion(angle: Double, pocket: PocketPosition,
                                         targetPocketDistanceRange: ClosedRange<Double>,
                                         cueDist: Double, cutRad: Double,
                                         pocketType: PocketType) -> AngleQuestion {
        let tableCenterX = 0.5
        let tableCenterY = 0.25
        let toCenter = atan2(tableCenterY - pocket.y, tableCenterX - pocket.x)
        let fallbackDist = (targetPocketDistanceRange.lowerBound + targetPocketDistanceRange.upperBound) * 0.5
        let tx = clamp(pocket.x + fallbackDist * cos(toCenter), 0.06, 0.94)
        let ty = clamp(pocket.y + fallbackDist * sin(toCenter), 0.06, 0.44)
        let toPocket = atan2(pocket.y - ty, pocket.x - tx)
        let approach = toPocket + cutRad
        let ghostX = tx - normalizedTwoRadius * cos(toPocket)
        let ghostY = ty - normalizedTwoRadius * sin(toPocket)
        let cx = clamp(ghostX - cueDist * cos(approach), 0.06, 0.94)
        let cy = clamp(ghostY - cueDist * sin(approach), 0.06, 0.44)
        return AngleQuestion(targetBall: CGPoint(x: tx, y: ty),
                             cueBall: CGPoint(x: cx, y: cy),
                             pocket: pocket, actualAngle: angle,
                             pocketType: pocketType)
    }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}
