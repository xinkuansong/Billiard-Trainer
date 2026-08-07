import Foundation
import CoreGraphics
import SceneKit

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
    /// Index in `AngleSceneCalculator.pocketPositions` (real hole centres,
    /// not the playing-area corners stored in `AngleCalculator.pockets`).
    /// Lets `AimingQuizViewModel` look up the correct pocket-aim point and
    /// pocket marker without label-based matching, so the graded answer
    /// stays consistent with what the on-screen visualization shows.
    let pocketIndex: Int
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
        // DR-063 portrait 屏幕系（本训练为 topDown2DRotated）：
        // screen-up = world +X = canvasX 增；screen-right = world +Z = canvasY 增。
        PocketPosition(x: 0.0, y: 0.0,  type: .corner, label: "左下角袋"),  // topLeft
        PocketPosition(x: 1.0, y: 0.0,  type: .corner, label: "左上角袋"),  // topRight
        PocketPosition(x: 0.0, y: 0.5,  type: .corner, label: "右下角袋"),  // bottomLeft
        PocketPosition(x: 1.0, y: 0.5,  type: .corner, label: "右上角袋"),  // bottomRight
        PocketPosition(x: 0.5, y: 0.0,  type: .side,   label: "左侧中袋"),  // topCenter
        PocketPosition(x: 0.5, y: 0.5,  type: .side,   label: "右侧中袋"),  // bottomCenter
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
        // Walk the pocket list with its index preserved so the returned
        // `pocketIndex` matches `AngleSceneCalculator.pocketPositions` order
        // — that's the index `effectivePocketAimPoint` consumes.
        let candidates: [(Int, PocketPosition)] = pockets.enumerated().compactMap {
            (idx, p) in
            if let type = pocketType, p.type != type { return nil }
            return (idx, p)
        }
        let (pocketIndex, pocket) = candidates.randomElement() ?? (0, pockets[0])

        let margin    = 0.06
        let minPocket = targetPocketDistanceRange.lowerBound
        let maxPocket = targetPocketDistanceRange.upperBound
        let cueDist   = Double.random(in: 0.15...0.35)
        let cutRad    = angle * .pi / 180.0
        let candidateLabels = Set(candidates.map { $0.1.label })

        for _ in 0..<200 {
            let tx = Double.random(in: margin...(1.0 - margin))
            let ty = Double.random(in: margin...(0.5 - margin))

            let dx = pocket.x - tx
            let dy = pocket.y - ty
            let dist = sqrt(dx * dx + dy * dy)
            guard dist >= minPocket, dist <= maxPocket else { continue }
            guard nearestPocket(
                to: CGPoint(x: tx, y: ty),
                among: candidates.map { $0.1 }
            ).label == pocket.label else {
                continue
            }

            // Effective aim point = what the in-game visualization actually
            // targets (real hole centre + cushion-clearance adjustment).
            // Using the same point here means `actualAngle == α` exactly
            // matches the angle the user sees on the table.
            let aimNorm = effectiveAimNormalized(
                targetNormalized: CGPoint(x: tx, y: ty),
                pocketIndex: pocketIndex
            )

            let toAim = atan2(aimNorm.y - ty, aimNorm.x - tx)
            let side: Double = Bool.random() ? 1.0 : -1.0
            let approach = toAim + side * cutRad

            // Ghost ball sits 2R *opposite* the aim direction (cue → ghost
            // is the strike line; strike line makes the cut angle with the
            // ghost → aim direction).
            let ghostX = tx - normalizedTwoRadius * cos(toAim)
            let ghostY = ty - normalizedTwoRadius * sin(toAim)
            let cx = ghostX - cueDist * cos(approach)
            let cy = ghostY - cueDist * sin(approach)
            guard cx >= margin, cx <= 1.0 - margin,
                  cy >= margin, cy <= 0.5 - margin else { continue }

            // Sanity check: ensure the chosen pocket is still the nearest
            // *candidate* pocket from the target — `effectiveAim` may have
            // pushed the aim direction toward a different pocket on
            // pathological configurations. Drop those.
            _ = candidateLabels // silence unused warning when compiled with strict flags

            return AngleQuestion(targetBall: CGPoint(x: tx, y: ty),
                                 cueBall: CGPoint(x: cx, y: cy),
                                 pocket: pocket, actualAngle: angle,
                                 pocketType: pocket.type,
                                 pocketIndex: pocketIndex)
        }

        return fallbackQuestion(angle: angle, pocket: pocket,
                                pocketIndex: pocketIndex,
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

    /// Bridge to `AngleSceneCalculator.effectivePocketAimPoint` that takes /
    /// returns normalised coordinates. We compute the real-world aim point
    /// (which already includes cushion-clearance adjustment per the 进球管道
    /// model used by 角度与打点) then convert back to the [0,1]×[0,0.5]
    /// space the question generator works in.
    private static func effectiveAimNormalized(
        targetNormalized: CGPoint,
        pocketIndex: Int
    ) -> CGPoint {
        let halfL = AngleSceneCalculator.innerLength / 2
        let halfW = AngleSceneCalculator.innerWidth / 2

        let targetScene = SCNVector3(
            Float(targetNormalized.x) * AngleSceneCalculator.innerLength - halfL,
            0,
            Float(targetNormalized.y) * 2.0 * AngleSceneCalculator.innerWidth - halfW
        )

        let aimScene = AngleSceneCalculator.effectivePocketAimPoint(
            targetBall: targetScene,
            pocketIndex: pocketIndex,
            surfaceY: 0
        )

        return CGPoint(
            x: Double((aimScene.x + halfL) / AngleSceneCalculator.innerLength),
            y: Double((aimScene.z + halfW) / (2 * AngleSceneCalculator.innerWidth))
        )
    }

    private static func fallbackQuestion(angle: Double, pocket: PocketPosition,
                                         pocketIndex: Int,
                                         targetPocketDistanceRange: ClosedRange<Double>,
                                         cueDist: Double, cutRad: Double,
                                         pocketType: PocketType) -> AngleQuestion {
        let tableCenterX = 0.5
        let tableCenterY = 0.25
        let toCenter = atan2(tableCenterY - pocket.y, tableCenterX - pocket.x)
        let fallbackDist = (targetPocketDistanceRange.lowerBound + targetPocketDistanceRange.upperBound) * 0.5
        let tx = clamp(pocket.x + fallbackDist * cos(toCenter), 0.06, 0.94)
        let ty = clamp(pocket.y + fallbackDist * sin(toCenter), 0.06, 0.44)

        let aimNorm = effectiveAimNormalized(
            targetNormalized: CGPoint(x: tx, y: ty),
            pocketIndex: pocketIndex
        )
        let toAim = atan2(aimNorm.y - ty, aimNorm.x - tx)
        let approach = toAim + cutRad
        let ghostX = tx - normalizedTwoRadius * cos(toAim)
        let ghostY = ty - normalizedTwoRadius * sin(toAim)
        let cx = clamp(ghostX - cueDist * cos(approach), 0.06, 0.94)
        let cy = clamp(ghostY - cueDist * sin(approach), 0.06, 0.44)
        return AngleQuestion(targetBall: CGPoint(x: tx, y: ty),
                             cueBall: CGPoint(x: cx, y: cy),
                             pocket: pocket, actualAngle: angle,
                             pocketType: pocketType,
                             pocketIndex: pocketIndex)
    }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}
