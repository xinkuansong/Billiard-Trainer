import SwiftUI
import UIKit

/// Unified magazine-cover palette for practice home + training plan posters (v27 W2 / DR-044).
///
/// - Practice zones (学 / 练 / 打 / 解): one hue family each; within-zone steps use **per-zone**
///   brightness + saturation ranges (not a shared formula — warm gold must not enter mud-brown).
/// - Training plan levels: editorial six-color palette restored from the pre-v27 magazine covers.
/// - Light/Dark share these RGB values — do not invent dark variants.
enum CoverPalette {

    struct Pair: Equatable {
        let top: Color
        let bottom: Color

        /// Watermark color chosen against cover top (Constraint A).
        var glyphColor: Color { Glyph.color(against: top) }
    }

    // MARK: - Glyph token (shared by BTPlanCover + AngleGridCard)

    enum Glyph {
        /// Near-ink watermark — default for all covers (DR-055/056; replaces ghost white).
        static let darkColor = Color(red: 0.08, green: 0.07, blue: 0.05)
        /// Soft ink (DR-056): lighter than 0.85 solid, still clearly darker than old ghost white.
        static let darkOpacity: Double = 0.52
        /// Fallback on charcoal / graphite tops where dark ink disappears.
        static let goldGlyph = Color(red: 0.84, green: 0.65, blue: 0.20)
        static let goldOpacity: Double = 0.62
        /// Tops darker than this use gold (charcoal / brown / red / graphite).
        static let charcoalLuminanceCeiling: CGFloat = 0.15
        /// Soft-ink floor (DR-056). Gold on charcoal still clears a stronger delta.
        /// Dark blend ≈ `|ΔL| = darkOpacity · |L_dark − L|`; gold ≈ `goldOpacity · |L_gold − L|`.
        static let minLuminanceDelta: CGFloat = 0.07
        /// Glyph size ÷ min(cover width, height). Practice grid ≈37pt; plan list ≈96pt at typical sizes.
        static let sizeRatio: CGFloat = 0.48
        /// Absolute size for practice grid cards (`Font.btCoverWatermark`) — single-line ≈2/3 of prior 56.
        static let gridAbsoluteSize: CGFloat = 37
        /// Default absolute size for plan list posters (replaces former inline `system(size: 96)`).
        static let planListAbsoluteSize: CGFloat = 96
        /// Detail Hero watermark size (v28 W2 list/hero split).
        static let planHeroAbsoluteSize: CGFloat = 170

        /// Unified cover watermark: soft dark ink on mid/light tops; gold on charcoal-class tops.
        /// Never uses translucent white.
        static func color(against background: Color) -> Color {
            if prefersDarkInk(against: background) {
                return darkColor.opacity(darkOpacity)
            }
            return goldGlyph.opacity(goldOpacity)
        }

        /// Dark ink on non-charcoal tops (keeps soft ink from flipping to gold when opacity drops).
        static func prefersDarkInk(against background: Color) -> Bool {
            relativeLuminance(of: background) >= charcoalLuminanceCeiling
        }

        /// sRGB relative luminance (WCAG), components in 0…1.
        static func relativeLuminance(of color: Color) -> CGFloat {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            func lin(_ c: CGFloat) -> CGFloat {
                c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        }

        /// `|ΔL|` for the color that `color(against:)` would pick.
        static func luminanceDelta(against background: Color) -> CGFloat {
            prefersDarkInk(against: background)
                ? darkLuminanceDelta(against: background)
                : goldLuminanceDelta(against: background)
        }

        static func darkLuminanceDelta(against background: Color) -> CGFloat {
            let L = relativeLuminance(of: background)
            let Ld = relativeLuminance(of: darkColor)
            return CGFloat(darkOpacity) * abs(Ld - L)
        }

        static func goldLuminanceDelta(against background: Color) -> CGFloat {
            let L = relativeLuminance(of: background)
            let Lg = relativeLuminance(of: goldGlyph)
            return CGFloat(goldOpacity) * abs(Lg - L)
        }
    }

    // MARK: - Historical multicolor practice covers (pre-v27)

    /// Original per-card palette restored for the practice home after the zone ladders proved too uniform.
    /// Values are byte-identical to the former `AngleCoverPalette` constants.
    enum PracticeMulticolor {
        /// 球理索引卡（v30 W0 / v32 理区）：靛蓝，与学区既有绿/橙/紫系区分。
        static let theoryIndex = Pair(
            top: Color(red: 0.24, green: 0.34, blue: 0.62),
            bottom: Color(red: 0.12, green: 0.18, blue: 0.38)
        )
        static let aimingPrinciple = Pair(
            top: Color(red: 0.16, green: 0.55, blue: 0.34),
            bottom: Color(red: 0.09, green: 0.34, blue: 0.21)
        )
        static let aimingMethods = Pair(
            top: Color(red: 0.12, green: 0.58, blue: 0.50),
            bottom: Color(red: 0.05, green: 0.34, blue: 0.30)
        )
        static let aimingCorrection = Pair(
            top: Color(red: 0.72, green: 0.38, blue: 0.22),
            bottom: Color(red: 0.42, green: 0.20, blue: 0.12)
        )
        static let spinAndEnglish = Pair(
            top: Color(red: 0.78, green: 0.42, blue: 0.16),
            bottom: Color(red: 0.48, green: 0.24, blue: 0.08)
        )
        static let separationAngleAtlas = Pair(
            top: Color(red: 0.72, green: 0.22, blue: 0.48),
            bottom: Color(red: 0.42, green: 0.10, blue: 0.30)
        )
        static let cushionEnglishAtlas = Pair(
            top: Color(red: 0.10, green: 0.58, blue: 0.62),
            bottom: Color(red: 0.04, green: 0.32, blue: 0.48)
        )
        static let angleDynamic = Pair(
            top: Color(red: 0.11, green: 0.46, blue: 0.95),
            bottom: Color(red: 0.05, green: 0.24, blue: 0.58)
        )
        static let ballFeel = Pair(
            top: Color(red: 0.48, green: 0.36, blue: 0.72),
            bottom: Color(red: 0.28, green: 0.20, blue: 0.46)
        )
        static let contactPointTable = Pair(
            top: Color(red: 0.42, green: 0.45, blue: 0.50),
            bottom: Color(red: 0.24, green: 0.26, blue: 0.30)
        )

        static let geometricQuiz = Pair(
            top: Color(red: 0.85, green: 0.52, blue: 0.13),
            bottom: Color(red: 0.55, green: 0.32, blue: 0.05)
        )
        static let sceneAiming2D = Pair(
            top: Color(red: 0.0, green: 0.60, blue: 0.60),
            bottom: Color(red: 0.0, green: 0.36, blue: 0.40)
        )
        static let sceneAiming3D = Pair(
            top: Color(red: 0.13, green: 0.42, blue: 0.66),
            bottom: Color(red: 0.05, green: 0.24, blue: 0.42)
        )
        static let aimPointTraining = Pair(
            top: Color(red: 0.72, green: 0.28, blue: 0.30),
            bottom: Color(red: 0.44, green: 0.14, blue: 0.16)
        )
        static let aimPointScene2D = Pair(
            top: Color(red: 0.0, green: 0.52, blue: 0.48),
            bottom: Color(red: 0.0, green: 0.30, blue: 0.28)
        )
        static let aimPointScene3D = Pair(
            top: Color(red: 0.30, green: 0.34, blue: 0.72),
            bottom: Color(red: 0.16, green: 0.18, blue: 0.44)
        )

        static let shotSimulation = Pair(
            top: Color(red: 0.13, green: 0.55, blue: 0.36),
            bottom: Color(red: 0.06, green: 0.33, blue: 0.20)
        )
        static let positionPlayComposer = Pair(
            top: Color(red: 0.72, green: 0.55, blue: 0.13),
            bottom: Color(red: 0.45, green: 0.33, blue: 0.05)
        )
        static let freePlay = Pair(
            top: Color(red: 0.13, green: 0.42, blue: 0.85),
            bottom: Color(red: 0.05, green: 0.22, blue: 0.52)
        )
        static let ballExtraction = Pair(
            top: Color(red: 0.16, green: 0.50, blue: 0.62),
            bottom: Color(red: 0.07, green: 0.28, blue: 0.36)
        )
        static let batchDrillStudio = Pair(
            top: Color(red: 0.20, green: 0.40, blue: 0.70),
            bottom: Color(red: 0.10, green: 0.22, blue: 0.42)
        )

        static let positionPlaySolver = Pair(
            top: Color(red: 0.50, green: 0.20, blue: 0.62),
            bottom: Color(red: 0.28, green: 0.10, blue: 0.40)
        )
        static let planThree = Pair(
            top: Color(red: 0.16, green: 0.46, blue: 0.62),
            bottom: Color(red: 0.08, green: 0.26, blue: 0.38)
        )
        static let snookerTactics = Pair(
            top: Color(red: 0.60, green: 0.10, blue: 0.30),
            bottom: Color(red: 0.34, green: 0.04, blue: 0.16)
        )
        static let bankShot = Pair(
            top: Color(red: 0.62, green: 0.14, blue: 0.14),
            bottom: Color(red: 0.36, green: 0.06, blue: 0.06)
        )
        static let diamondSystem = Pair(
            top: Color(red: 0.0, green: 0.45, blue: 0.55),
            bottom: Color(red: 0.0, green: 0.26, blue: 0.34)
        )

        /// Production practice-home covers (DR-052). Prefer this over zone-ladder pairs for UI.
        static var allPairs: [Pair] {
            [
                theoryIndex,
                aimingPrinciple, aimingMethods, aimingCorrection, spinAndEnglish,
                separationAngleAtlas, cushionEnglishAtlas, angleDynamic, ballFeel, contactPointTable,
                geometricQuiz, sceneAiming2D, sceneAiming3D, aimPointTraining, aimPointScene2D, aimPointScene3D,
                shotSimulation, positionPlayComposer, freePlay, ballExtraction, batchDrillStudio,
                positionPlaySolver, planThree, snookerTactics, bankShot, diamondSystem
            ]
        }
    }

    // MARK: - Per-zone ladder (parameterized; no per-card RGB overrides)

    /// Brightness/saturation endpoints for step 0 … last. `t` lerps start→end.
    private struct ZoneLadder {
        let hue: CGFloat
        let saturationStart: CGFloat
        let saturationEnd: CGFloat
        let topBrightnessStart: CGFloat
        let topBrightnessEnd: CGFloat
        let bottomBrightnessStart: CGFloat
        let bottomBrightnessEnd: CGFloat

        /// 学 — brand green; mid→deep, high sat OK at low B.
        static let learn = ZoneLadder(
            hue: 145.0 / 360.0,
            saturationStart: 0.70, saturationEnd: 0.80,
            topBrightnessStart: 0.52, topBrightnessEnd: 0.34,
            bottomBrightnessStart: 0.32, bottomBrightnessEnd: 0.16
        )

        /// 练 — gold/amber aligned with `btAccent`.
        /// Brightness floor stays ≥ ~0.44 so hue 40° never enters mud-brown; depth via sat↑ + mild B↓.
        static let train = ZoneLadder(
            hue: 40.0 / 360.0,
            saturationStart: 0.68, saturationEnd: 0.90,
            topBrightnessStart: 0.80, topBrightnessEnd: 0.62,
            bottomBrightnessStart: 0.60, bottomBrightnessEnd: 0.44
        )

        /// 打 — blue-cyan.
        static let play = ZoneLadder(
            hue: 205.0 / 360.0,
            saturationStart: 0.64, saturationEnd: 0.80,
            topBrightnessStart: 0.54, topBrightnessEnd: 0.34,
            bottomBrightnessStart: 0.34, bottomBrightnessEnd: 0.18
        )

        /// 解 — graphite. Starts mid-dark so gold watermark clears Constraint A (DR-055);
        /// depth via further B↓ + slight sat↑ (still low-sat cool gray).
        static let solve = ZoneLadder(
            hue: 220.0 / 360.0,
            saturationStart: 0.08, saturationEnd: 0.18,
            topBrightnessStart: 0.36, topBrightnessEnd: 0.16,
            bottomBrightnessStart: 0.22, bottomBrightnessEnd: 0.08
        )
    }

    private static func pair(ladder: ZoneLadder, step: Int, stepCount: Int) -> Pair {
        precondition(stepCount >= 1)
        let t = stepCount == 1 ? 0 : CGFloat(step) / CGFloat(stepCount - 1)
        let sat = lerp(ladder.saturationStart, ladder.saturationEnd, t)
        let topB = lerp(ladder.topBrightnessStart, ladder.topBrightnessEnd, t)
        let botB = lerp(ladder.bottomBrightnessStart, ladder.bottomBrightnessEnd, t)
        return Pair(
            top: hsb(ladder.hue, sat, topB),
            bottom: hsb(ladder.hue, sat, botB)
        )
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private static func hsb(_ h: CGFloat, _ s: CGFloat, _ b: CGFloat) -> Color {
        Color(UIColor(hue: h, saturation: s, brightness: b, alpha: 1))
    }

    // MARK: - 学（9）

    static let aimingPrinciple      = pair(ladder: .learn, step: 0, stepCount: 9)
    static let aimingMethods        = pair(ladder: .learn, step: 1, stepCount: 9)
    static let aimingCorrection     = pair(ladder: .learn, step: 2, stepCount: 9)
    static let spinAndEnglish       = pair(ladder: .learn, step: 3, stepCount: 9)
    static let angleDynamic         = pair(ladder: .learn, step: 4, stepCount: 9)
    static let separationAngleAtlas = pair(ladder: .learn, step: 5, stepCount: 9)
    static let cushionEnglishAtlas  = pair(ladder: .learn, step: 6, stepCount: 9)
    static let ballFeel             = pair(ladder: .learn, step: 7, stepCount: 9)
    static let contactPointTable    = pair(ladder: .learn, step: 8, stepCount: 9)

    // MARK: - 练（6）

    static let geometricQuiz    = pair(ladder: .train, step: 0, stepCount: 6)
    static let sceneAiming2D    = pair(ladder: .train, step: 1, stepCount: 6)
    static let sceneAiming3D    = pair(ladder: .train, step: 2, stepCount: 6)
    static let aimPointTraining = pair(ladder: .train, step: 3, stepCount: 6)
    static let aimPointScene2D  = pair(ladder: .train, step: 4, stepCount: 6)
    static let aimPointScene3D  = pair(ladder: .train, step: 5, stepCount: 6)

    // MARK: - 打（5，含 SIM）

    static let shotSimulation       = pair(ladder: .play, step: 0, stepCount: 5)
    static let positionPlayComposer = pair(ladder: .play, step: 1, stepCount: 5)
    static let freePlay             = pair(ladder: .play, step: 2, stepCount: 5)
    static let ballExtraction       = pair(ladder: .play, step: 3, stepCount: 5)
    /// Simulator-only batch studio card.
    static let batchDrillStudio     = pair(ladder: .play, step: 4, stepCount: 5)

    // MARK: - 解（5）

    static let positionPlaySolver = pair(ladder: .solve, step: 0, stepCount: 5)
    static let planThree          = pair(ladder: .solve, step: 1, stepCount: 5)
    static let snookerTactics     = pair(ladder: .solve, step: 2, stepCount: 5)
    static let bankShot           = pair(ladder: .solve, step: 3, stepCount: 5)
    static let diamondSystem      = pair(ladder: .solve, step: 4, stepCount: 5)

    /// All practice cover pairs — for invariant tests (Constraint A / B).
    static var allPracticePairs: [Pair] {
        [
            aimingPrinciple, aimingMethods, aimingCorrection, spinAndEnglish,
            angleDynamic, separationAngleAtlas, cushionEnglishAtlas, ballFeel, contactPointTable,
            geometricQuiz, sceneAiming2D, sceneAiming3D, aimPointTraining, aimPointScene2D, aimPointScene3D,
            shotSimulation, positionPlayComposer, freePlay, ballExtraction, batchDrillStudio,
            positionPlaySolver, planThree, snookerTactics, bankShot, diamondSystem
        ]
    }

    // MARK: - Training plan level covers（editorial six-color palette）

    /// Ordered publishable plan target levels.
    static let planLevelKeys: [String] = ["L0→L1", "L1", "L1→L2", "L2", "L3", "L3→L4"]

    struct PlanStyle: Equatable {
        let top: Color
        let bottom: Color
        /// Same watermark rule as practice covers (`Glyph.color(against:)`).
        var glyphColor: Color { Glyph.color(against: top) }

        static func forLevel(_ level: String) -> PlanStyle {
            switch level {
            case "L0→L1":
                return .init(
                    top: Color(red: 0.16, green: 0.55, blue: 0.34),
                    bottom: Color(red: 0.09, green: 0.34, blue: 0.21)
                )
            case "L1", "L0→L2":
                return .init(
                    top: Color(red: 0.11, green: 0.46, blue: 0.95),
                    bottom: Color(red: 0.05, green: 0.24, blue: 0.58)
                )
            case "L1→L2", "L1→L3":
                return .init(
                    top: Color(red: 0.0, green: 0.60, blue: 0.60),
                    bottom: Color(red: 0.0, green: 0.36, blue: 0.40)
                )
            case "L2", "L2→L3":
                return .init(
                    top: Color(red: 0.18, green: 0.18, blue: 0.20),
                    bottom: Color(red: 0.07, green: 0.07, blue: 0.08)
                )
            case "L3":
                return .init(
                    top: Color(red: 0.55, green: 0.32, blue: 0.05),
                    bottom: Color(red: 0.33, green: 0.18, blue: 0.02)
                )
            case "L3→L4", "L2→L4":
                return .init(
                    top: Color(red: 0.62, green: 0.14, blue: 0.14),
                    bottom: Color(red: 0.36, green: 0.06, blue: 0.06)
                )
            default:
                return .init(
                    top: Color(red: 0.16, green: 0.55, blue: 0.34),
                    bottom: Color(red: 0.09, green: 0.34, blue: 0.21)
                )
            }
        }
    }

    /// All plan cover pairs — for invariant tests (order / uniqueness).
    static var allPlanPairs: [Pair] {
        planLevelKeys.map {
            let s = PlanStyle.forLevel($0)
            return Pair(top: s.top, bottom: s.bottom)
        }
    }
}

/// Backward-compatible alias — call sites may keep `AngleCoverPalette.*` (v7 C20).
typealias AngleCoverPalette = CoverPalette
