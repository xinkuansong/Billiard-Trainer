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
        PocketPosition(x: 0.0, y: 0.0,  type: .corner, label: "左上"),
        PocketPosition(x: 1.0, y: 0.0,  type: .corner, label: "右上"),
        PocketPosition(x: 0.0, y: 0.5,  type: .corner, label: "左下"),
        PocketPosition(x: 1.0, y: 0.5,  type: .corner, label: "右下"),
        PocketPosition(x: 0.5, y: 0.0,  type: .side,   label: "上中"),
        PocketPosition(x: 0.5, y: 0.5,  type: .side,   label: "下中"),
    ]

    // MARK: Question generation

    static func generateQuestion(angle: Double, pocketType: PocketType) -> AngleQuestion {
        let candidates = pockets.filter { $0.type == pocketType }
        let pocket = candidates.randomElement()!

        let margin    = 0.06
        let minPocket = 0.12
        let maxPocket = 0.65
        let cueDist   = Double.random(in: 0.15...0.35)
        let cutRad    = angle * .pi / 180.0

        for _ in 0..<200 {
            let tx = Double.random(in: margin...(1.0 - margin))
            let ty = Double.random(in: margin...(0.5 - margin))

            let dx = pocket.x - tx
            let dy = pocket.y - ty
            let dist = sqrt(dx * dx + dy * dy)
            guard dist >= minPocket, dist <= maxPocket else { continue }

            let toPocket = atan2(dy, dx)
            let side: Double = Bool.random() ? 1.0 : -1.0
            let approach = toPocket + side * cutRad

            let cx = tx - cueDist * cos(approach)
            let cy = ty - cueDist * sin(approach)
            guard cx >= margin, cx <= 1.0 - margin,
                  cy >= margin, cy <= 0.5 - margin else { continue }

            return AngleQuestion(targetBall: CGPoint(x: tx, y: ty),
                                 cueBall: CGPoint(x: cx, y: cy),
                                 pocket: pocket, actualAngle: angle,
                                 pocketType: pocketType)
        }

        return fallbackQuestion(angle: angle, pocket: pocket,
                                cueDist: cueDist, cutRad: cutRad,
                                pocketType: pocketType)
    }

    // MARK: - Private

    private static func fallbackQuestion(angle: Double, pocket: PocketPosition,
                                         cueDist: Double, cutRad: Double,
                                         pocketType: PocketType) -> AngleQuestion {
        let tx = 0.5, ty = 0.25
        let toPocket = atan2(pocket.y - ty, pocket.x - tx)
        let approach = toPocket + cutRad
        let cx = clamp(tx - cueDist * cos(approach), 0.06, 0.94)
        let cy = clamp(ty - cueDist * sin(approach), 0.06, 0.44)
        return AngleQuestion(targetBall: CGPoint(x: tx, y: ty),
                             cueBall: CGPoint(x: cx, y: cy),
                             pocket: pocket, actualAngle: angle,
                             pocketType: pocketType)
    }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}
