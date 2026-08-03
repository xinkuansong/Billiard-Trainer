import SwiftUI
import UIKit

/// Unified magazine-cover palette for practice home + training plan posters (v27 W2 / DR-044).
///
/// - Practice zones (学 / 练 / 打 / 解): one hue family each; cards differ by lightness steps only.
/// - Training plan levels: same saturation budget, same RGB source file.
/// - Light/Dark share these RGB values — do not invent dark variants.
enum CoverPalette {

    struct Pair: Equatable {
        let top: Color
        let bottom: Color
    }

    // MARK: - Glyph token (shared by BTPlanCover + AngleGridCard)

    enum Glyph {
        /// Watermark white opacity — single token (was 0.16 plan / 0.22 practice).
        static let opacity: Double = 0.20
        /// Glyph size ÷ min(cover width, height). Practice grid ≈56pt; plan list ≈96pt at typical sizes.
        static let sizeRatio: CGFloat = 0.48
        /// Absolute size for practice grid cards (`Font.btCoverWatermark`).
        static let gridAbsoluteSize: CGFloat = 56
        /// Default absolute size for plan list posters (replaces former inline `system(size: 96)`).
        static let planListAbsoluteSize: CGFloat = 96
        /// L2 mid-level uses gold watermark instead of white.
        static let goldGlyph = Color(red: 0.84, green: 0.65, blue: 0.20)
        static let goldOpacity: Double = 0.55
    }

    // MARK: - Zone hue families (HSB; shared Light/Dark)

    private enum Zone {
        /// 学 — brand green (aligned with `btPrimary` light).
        case learn
        /// 练 — gold / amber (aligned with `btAccent` light).
        case train
        /// 打 — blue-cyan.
        case play
        /// 解 — graphite / cool gray.
        case solve

        var hue: CGFloat {
            switch self {
            case .learn: return 145.0 / 360.0
            case .train: return 38.0 / 360.0
            case .play:  return 205.0 / 360.0
            case .solve: return 220.0 / 360.0
            }
        }

        var saturation: CGFloat {
            switch self {
            case .learn: return 0.72
            case .train: return 0.82
            case .play:  return 0.70
            case .solve: return 0.12
            }
        }
    }

    /// Builds a top→bottom gradient at one lightness step within a zone.
    /// `step` 0 = lightest card; higher = deeper. `stepCount` spreads brightness range.
    private static func pair(zone: Zone, step: Int, stepCount: Int) -> Pair {
        precondition(stepCount >= 1)
        let t = stepCount == 1 ? 0.0 : CGFloat(step) / CGFloat(stepCount - 1)
        // Readable mid→deep range with clear within-zone lightness steps.
        let topB = 0.62 - t * 0.28
        let bottomB = 0.38 - t * 0.24
        let satBoost = zone == .solve ? 0.0 : 0.04
        return Pair(
            top: hsb(zone.hue, zone.saturation, topB),
            bottom: hsb(zone.hue, min(1, zone.saturation + satBoost), max(0.08, bottomB))
        )
    }

    private static func hsb(_ h: CGFloat, _ s: CGFloat, _ b: CGFloat) -> Color {
        Color(UIColor(hue: h, saturation: s, brightness: b, alpha: 1))
    }

    // MARK: - 学（9）— brand green steps

    static let aimingPrinciple      = pair(zone: .learn, step: 0, stepCount: 9)
    static let aimingMethods        = pair(zone: .learn, step: 1, stepCount: 9)
    static let aimingCorrection     = pair(zone: .learn, step: 2, stepCount: 9)
    static let spinAndEnglish       = pair(zone: .learn, step: 3, stepCount: 9)
    static let angleDynamic         = pair(zone: .learn, step: 4, stepCount: 9)
    static let separationAngleAtlas = pair(zone: .learn, step: 5, stepCount: 9)
    static let cushionEnglishAtlas  = pair(zone: .learn, step: 6, stepCount: 9)
    static let ballFeel             = pair(zone: .learn, step: 7, stepCount: 9)
    static let contactPointTable    = pair(zone: .learn, step: 8, stepCount: 9)

    // MARK: - 练（6）— gold / amber steps

    static let geometricQuiz   = pair(zone: .train, step: 0, stepCount: 6)
    static let sceneAiming2D   = pair(zone: .train, step: 1, stepCount: 6)
    static let sceneAiming3D   = pair(zone: .train, step: 2, stepCount: 6)
    static let aimPointTraining = pair(zone: .train, step: 3, stepCount: 6)
    static let aimPointScene2D = pair(zone: .train, step: 4, stepCount: 6)
    static let aimPointScene3D = pair(zone: .train, step: 5, stepCount: 6)

    // MARK: - 打（5，含 SIM）— blue-cyan steps

    static let shotSimulation        = pair(zone: .play, step: 0, stepCount: 5)
    static let positionPlayComposer  = pair(zone: .play, step: 1, stepCount: 5)
    static let freePlay              = pair(zone: .play, step: 2, stepCount: 5)
    static let ballExtraction        = pair(zone: .play, step: 3, stepCount: 5)
    /// Simulator-only batch studio card.
    static let batchDrillStudio      = pair(zone: .play, step: 4, stepCount: 5)

    // MARK: - 解（5）— graphite steps

    static let positionPlaySolver = pair(zone: .solve, step: 0, stepCount: 5)
    static let planThree          = pair(zone: .solve, step: 1, stepCount: 5)
    static let snookerTactics     = pair(zone: .solve, step: 2, stepCount: 5)
    static let bankShot           = pair(zone: .solve, step: 3, stepCount: 5)
    static let diamondSystem      = pair(zone: .solve, step: 4, stepCount: 5)

    // MARK: - Training plan level covers（same saturation budget）

    struct PlanStyle: Equatable {
        let top: Color
        let bottom: Color
        let glyph: String
        let glyphColor: Color

        static func forLevel(_ level: String) -> PlanStyle {
            switch level {
            case "L0→L1":
                let p = CoverPalette.aimingPrinciple
                return .init(top: p.top, bottom: p.bottom, glyph: "入",
                             glyphColor: .white.opacity(Glyph.opacity))
            case "L1":
                let p = CoverPalette.freePlay
                return .init(top: p.top, bottom: p.bottom, glyph: "初",
                             glyphColor: .white.opacity(Glyph.opacity))
            case "L1→L2":
                let p = CoverPalette.shotSimulation
                return .init(top: p.top, bottom: p.bottom, glyph: "进",
                             glyphColor: .white.opacity(Glyph.opacity))
            case "L2":
                let p = CoverPalette.diamondSystem
                return .init(top: p.top, bottom: p.bottom, glyph: "中",
                             glyphColor: Glyph.goldGlyph.opacity(Glyph.goldOpacity))
            case "L3":
                let p = CoverPalette.aimPointTraining
                return .init(top: p.top, bottom: p.bottom, glyph: "高",
                             glyphColor: .white.opacity(Glyph.opacity))
            case "L3→L4":
                let p = CoverPalette.aimPointScene3D
                return .init(top: p.top, bottom: p.bottom, glyph: "专",
                             glyphColor: .white.opacity(Glyph.opacity))
            default:
                let p = CoverPalette.aimingPrinciple
                return .init(top: p.top, bottom: p.bottom, glyph: "球",
                             glyphColor: .white.opacity(Glyph.opacity))
            }
        }
    }
}

/// Backward-compatible alias — call sites may keep `AngleCoverPalette.*` (v7 C20).
typealias AngleCoverPalette = CoverPalette
