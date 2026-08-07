import CoreGraphics
import Foundation

/// Static, deterministic practice-grid cover description (v28 W1 / D-v28-4).
///
/// Covers only consume this value — never ViewModels, solvers, physics playback, or full SceneKit pages.
enum PracticeCoverVisual: Equatable, Hashable {
    /// 「学」— geometric micro-illustration (often close-up on real felt).
    case geometric(PracticeCoverLayout)
    /// 「练 / 打 / 解」— full-table (or mild crop) scene preview on the shared USDZ backdrop.
    case tablePreview(PracticeCoverLayout)

    var layout: PracticeCoverLayout {
        switch self {
        case .geometric(let layout), .tablePreview(let layout):
            return layout
        }
    }

    var isGeometric: Bool {
        if case .geometric = self { return true }
        return false
    }
}

/// World-meter layout on the table plane (X long axis, Z short axis, origin at center).
struct PracticeCoverLayout: Equatable, Hashable {
    struct Ball: Equatable, Hashable {
        /// `nil` = cue ball.
        var number: Int?
        var x: CGFloat
        var z: CGFloat
    }

    struct Segment: Equatable, Hashable {
        enum Style: String, Hashable {
            case aim
            case pot
            case hint
            case separation
        }

        var x0: CGFloat
        var z0: CGFloat
        var x1: CGFloat
        var z1: CGFloat
        var style: Style
        /// Used when `style == .pot`.
        var potNumber: Int? = nil
    }

    struct Ghost: Equatable, Hashable {
        var x: CGFloat
        var z: CGFloat
    }

    var balls: [Ball]
    var segments: [Segment] = []
    var ghosts: [Ghost] = []
    /// Optional close-up: world center (x,z) + orthographic half-height (m).
    var closeup: (x: CGFloat, z: CGFloat, halfHeight: CGFloat)? = nil
    /// Zone tint pair from `CoverPalette` (light overlay, not full-bleed poster).
    var tintTopKey: String
    var tintBottomKey: String

    // Manual Hashable — tuple closeup is not Hashable by default.
    func hash(into hasher: inout Hasher) {
        hasher.combine(balls)
        hasher.combine(segments)
        hasher.combine(ghosts)
        hasher.combine(closeup?.x)
        hasher.combine(closeup?.z)
        hasher.combine(closeup?.halfHeight)
        hasher.combine(tintTopKey)
        hasher.combine(tintBottomKey)
    }

    static func == (lhs: PracticeCoverLayout, rhs: PracticeCoverLayout) -> Bool {
        lhs.balls == rhs.balls
            && lhs.segments == rhs.segments
            && lhs.ghosts == rhs.ghosts
            && lhs.closeup?.x == rhs.closeup?.x
            && lhs.closeup?.z == rhs.closeup?.z
            && lhs.closeup?.halfHeight == rhs.closeup?.halfHeight
            && lhs.tintTopKey == rhs.tintTopKey
            && lhs.tintBottomKey == rhs.tintBottomKey
    }
}

/// Exhaustive route → visual map for official Practice IA entries (v28 W1).
enum PracticeCoverCatalog {
    /// 25 official publishable routes (excludes SIM-only batch studio + drillDetail deep links).
    static let officialRoutes: [AngleRoute] = [
        .aimingPrinciple, .aimingMethods, .aimingCorrection, .spinAndEnglish,
        .angleDynamic, .separationAngleAtlas, .cushionEnglishAtlas, .ballFeel, .contactPointTable,
        .geometricQuiz, .sceneAiming2D, .sceneAiming3D, .aimPointTraining, .aimPointScene2D, .aimPointScene3D,
        .shotSimulation, .positionPlayComposer, .freePlay, .ballExtraction,
        .positionPlaySolver, .planThree, .snookerTactics, .bankShot, .diamondSystem,
    ]

    static func visual(for route: AngleRoute) -> PracticeCoverVisual {
        switch route {
        case .aimingPrinciple:
            return .geometric(cutGeometry(
                tint: "aimingPrinciple",
                cue: (-0.12, -0.08), target: (0.18, -0.02), ghost: (0.12, -0.05),
                pocket: (0.55, -0.22), closeup: (0.18, -0.08, 0.34)
            ))
        case .aimingMethods:
            return .geometric(pipelineGeometry(tint: "aimingMethods"))
        case .aimingCorrection:
            return .geometric(throwGeometry(tint: "aimingCorrection"))
        case .spinAndEnglish:
            return .geometric(spinFanGeometry(tint: "spinAndEnglish"))
        case .angleDynamic:
            return .geometric(cutGeometry(
                tint: "angleDynamic",
                cue: (-0.18, 0.04), target: (0.10, 0.00), ghost: (0.04, 0.02),
                pocket: (0.48, -0.18), closeup: (0.10, -0.02, 0.36)
            ))
        case .separationAngleAtlas:
            return .geometric(separationGeometry(tint: "separationAngleAtlas"))
        case .cushionEnglishAtlas:
            return .geometric(cushionGeometry(tint: "cushionEnglishAtlas"))
        case .ballFeel:
            return .geometric(cutGeometry(
                tint: "ballFeel",
                cue: (-0.10, 0.06), target: (0.16, 0.02), ghost: (0.10, 0.04),
                pocket: (0.50, -0.10), closeup: (0.12, 0.00, 0.32)
            ))
        case .contactPointTable:
            return .geometric(contactTableGeometry(tint: "contactPointTable"))

        case .geometricQuiz:
            return .tablePreview(quizPreview(tint: "geometricQuiz"))
        case .sceneAiming2D:
            return .tablePreview(aimingLane(tint: "sceneAiming2D", objectNumber: 3, zShift: -0.08))
        case .sceneAiming3D:
            return .tablePreview(aimingLane(tint: "sceneAiming3D", objectNumber: 5, zShift: 0.12))
        case .aimPointTraining:
            return .tablePreview(ghostDragPreview(tint: "aimPointTraining"))
        case .aimPointScene2D:
            return .tablePreview(aimingLane(tint: "aimPointScene2D", objectNumber: 2, zShift: -0.16))
        case .aimPointScene3D:
            return .tablePreview(aimingLane(tint: "aimPointScene3D", objectNumber: 6, zShift: 0.18))

        case .shotSimulation:
            return .tablePreview(collisionPreview(tint: "shotSimulation"))
        case .positionPlayComposer:
            return .tablePreview(multiBallPreview(tint: "positionPlayComposer", count: 4))
        case .freePlay:
            return .tablePreview(rackPreview(tint: "freePlay"))
        case .ballExtraction:
            return .tablePreview(photoBoardPreview(tint: "ballExtraction"))
        case .batchDrillStudio:
            return .tablePreview(toolGridPreview(tint: "batchDrillStudio"))

        case .positionPlaySolver:
            return .tablePreview(solverPreview(tint: "positionPlaySolver"))
        case .planThree:
            return .tablePreview(threeShotPreview(tint: "planThree"))
        case .snookerTactics:
            return .tablePreview(safetyPreview(tint: "snookerTactics"))
        case .bankShot:
            return .tablePreview(bankPreview(tint: "bankShot"))
        case .diamondSystem:
            return .tablePreview(kickPreview(tint: "diamondSystem"))

        case .drillDetail, .theoryIndex, .theoryPage:
            // Deep-link / glyph-cover routes — not publishable entries of this legacy catalog
            // (v30 W0 球理 cards render through `AngleGridCard`'s glyph cover); still exhaustive.
            return .tablePreview(aimingLane(tint: "aimingPrinciple", objectNumber: 1, zShift: 0))
        }
    }

    static func palette(for tintKey: String) -> CoverPalette.Pair {
        switch tintKey {
        case "aimingPrinciple": return CoverPalette.aimingPrinciple
        case "aimingMethods": return CoverPalette.aimingMethods
        case "aimingCorrection": return CoverPalette.aimingCorrection
        case "spinAndEnglish": return CoverPalette.spinAndEnglish
        case "angleDynamic": return CoverPalette.angleDynamic
        case "separationAngleAtlas": return CoverPalette.separationAngleAtlas
        case "cushionEnglishAtlas": return CoverPalette.cushionEnglishAtlas
        case "ballFeel": return CoverPalette.ballFeel
        case "contactPointTable": return CoverPalette.contactPointTable
        case "geometricQuiz": return CoverPalette.geometricQuiz
        case "sceneAiming2D": return CoverPalette.sceneAiming2D
        case "sceneAiming3D": return CoverPalette.sceneAiming3D
        case "aimPointTraining": return CoverPalette.aimPointTraining
        case "aimPointScene2D": return CoverPalette.aimPointScene2D
        case "aimPointScene3D": return CoverPalette.aimPointScene3D
        case "shotSimulation": return CoverPalette.shotSimulation
        case "positionPlayComposer": return CoverPalette.positionPlayComposer
        case "freePlay": return CoverPalette.freePlay
        case "ballExtraction": return CoverPalette.ballExtraction
        case "batchDrillStudio": return CoverPalette.batchDrillStudio
        case "positionPlaySolver": return CoverPalette.positionPlaySolver
        case "planThree": return CoverPalette.planThree
        case "snookerTactics": return CoverPalette.snookerTactics
        case "bankShot": return CoverPalette.bankShot
        case "diamondSystem": return CoverPalette.diamondSystem
        default:
            preconditionFailure("Unknown practice cover tint key: \(tintKey)")
        }
    }

    // MARK: - Learn geometries

    private static func cutGeometry(
        tint: String,
        cue: (CGFloat, CGFloat),
        target: (CGFloat, CGFloat),
        ghost: (CGFloat, CGFloat),
        pocket: (CGFloat, CGFloat),
        closeup: (CGFloat, CGFloat, CGFloat)
    ) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: cue.0, z: cue.1),
                .init(number: 1, x: target.0, z: target.1),
            ],
            segments: [
                .init(x0: cue.0, z0: cue.1, x1: ghost.0, z1: ghost.1, style: .aim),
                .init(x0: target.0, z0: target.1, x1: pocket.0, z1: pocket.1, style: .pot, potNumber: 1),
            ],
            ghosts: [.init(x: ghost.0, z: ghost.1)],
            closeup: closeup,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func pipelineGeometry(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.22, z: 0.00),
                .init(number: 3, x: 0.20, z: 0.00),
            ],
            segments: [
                .init(x0: -0.22, z0: 0.00, x1: 0.14, z1: 0.00, style: .aim),
                .init(x0: 0.20, z0: 0.00, x1: 0.55, z1: 0.00, style: .pot, potNumber: 3),
                .init(x0: -0.22, z0: 0.06, x1: 0.55, z1: 0.06, style: .hint),
                .init(x0: -0.22, z0: -0.06, x1: 0.55, z1: -0.06, style: .hint),
            ],
            ghosts: [.init(x: 0.14, z: 0.00)],
            closeup: (0.10, 0.00, 0.30),
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func throwGeometry(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.16, z: -0.04),
                .init(number: 2, x: 0.14, z: 0.02),
            ],
            segments: [
                .init(x0: -0.16, z0: -0.04, x1: 0.08, z1: 0.00, style: .aim),
                .init(x0: 0.14, z0: 0.02, x1: 0.48, z1: -0.08, style: .hint),
                .init(x0: 0.14, z0: 0.02, x1: 0.46, z1: 0.10, style: .pot, potNumber: 2),
            ],
            ghosts: [.init(x: 0.08, z: 0.00)],
            closeup: (0.12, 0.02, 0.32),
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func spinFanGeometry(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.05, z: 0.00),
                .init(number: 4, x: 0.28, z: 0.00),
            ],
            segments: [
                .init(x0: -0.05, z0: 0.00, x1: 0.22, z1: 0.00, style: .aim),
                .init(x0: 0.28, z0: 0.00, x1: 0.20, z1: 0.28, style: .separation),
                .init(x0: 0.28, z0: 0.00, x1: 0.05, z1: 0.32, style: .hint),
                .init(x0: 0.28, z0: 0.00, x1: -0.05, z1: 0.28, style: .hint),
            ],
            ghosts: [.init(x: 0.22, z: 0.00)],
            closeup: (0.12, 0.10, 0.34),
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func separationGeometry(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.20, z: -0.06),
                .init(number: 8, x: 0.10, z: 0.00),
            ],
            segments: [
                .init(x0: -0.20, z0: -0.06, x1: 0.04, z1: -0.02, style: .aim),
                .init(x0: 0.10, z0: 0.00, x1: 0.42, z1: -0.18, style: .pot, potNumber: 8),
                .init(x0: 0.04, z0: -0.02, x1: -0.05, z1: 0.30, style: .separation),
            ],
            ghosts: [.init(x: 0.04, z: -0.02)],
            closeup: (0.08, 0.04, 0.36),
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func cushionGeometry(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.35, z: -0.20),
            ],
            segments: [
                .init(x0: -0.35, z0: -0.20, x1: -0.55, z1: 0.35, style: .aim),
                .init(x0: -0.55, z0: 0.35, x1: 0.10, z1: 0.45, style: .hint),
                .init(x0: -0.55, z0: 0.35, x1: 0.25, z1: 0.20, style: .separation),
            ],
            ghosts: [],
            closeup: (-0.20, 0.10, 0.42),
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func contactTableGeometry(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.08, z: 0.00),
                .init(number: 1, x: 0.12, z: 0.00),
            ],
            segments: [
                .init(x0: -0.08, z0: 0.00, x1: 0.06, z1: 0.00, style: .aim),
            ],
            ghosts: [.init(x: 0.06, z: 0.00)],
            closeup: (0.02, 0.00, 0.22),
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    // MARK: - Train / play / solve previews

    private static func quizPreview(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.55, z: 0.10),
                .init(number: 1, x: 0.15, z: -0.05),
            ],
            segments: [
                .init(x0: -0.55, z0: 0.10, x1: 0.08, z1: -0.02, style: .aim),
                .init(x0: 0.15, z0: -0.05, x1: 0.85, z1: -0.35, style: .hint),
            ],
            ghosts: [.init(x: 0.08, z: -0.02)],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func aimingLane(tint: String, objectNumber: Int, zShift: CGFloat) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.70, z: zShift),
                .init(number: objectNumber, x: 0.25, z: zShift + 0.04),
            ],
            segments: [
                .init(x0: -0.70, z0: zShift, x1: 0.18, z1: zShift + 0.03, style: .aim),
                .init(
                    x0: 0.25, z0: zShift + 0.04,
                    x1: 0.95, z1: zShift - 0.25,
                    style: .pot, potNumber: objectNumber
                ),
            ],
            ghosts: [.init(x: 0.18, z: zShift + 0.03)],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func ghostDragPreview(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.40, z: -0.15),
                .init(number: 9, x: 0.30, z: 0.05),
            ],
            segments: [
                .init(x0: -0.40, z0: -0.15, x1: 0.22, z1: 0.02, style: .aim),
            ],
            ghosts: [.init(x: 0.22, z: 0.02)],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func collisionPreview(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.45, z: 0.00),
                .init(number: 1, x: 0.05, z: 0.00),
            ],
            segments: [
                .init(x0: -0.45, z0: 0.00, x1: -0.02, z1: 0.00, style: .aim),
                .init(x0: 0.05, z0: 0.00, x1: 0.70, z1: -0.30, style: .pot, potNumber: 1),
                .init(x0: -0.02, z0: 0.00, x1: -0.25, z1: 0.40, style: .separation),
            ],
            ghosts: [.init(x: -0.02, z: 0.00)],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func multiBallPreview(tint: String, count: Int) -> PracticeCoverLayout {
        var balls: [PracticeCoverLayout.Ball] = [
            .init(number: nil, x: -0.80, z: -0.20),
        ]
        let spots: [(Int, CGFloat, CGFloat)] = [
            (1, 0.10, 0.05), (2, 0.35, -0.15), (3, 0.55, 0.20), (5, 0.75, -0.05),
        ]
        for (i, spot) in spots.prefix(count).enumerated() {
            balls.append(.init(number: spot.0, x: spot.1, z: spot.2))
            _ = i
        }
        return PracticeCoverLayout(
            balls: balls,
            segments: [
                .init(x0: -0.80, z0: -0.20, x1: 0.04, z1: 0.03, style: .aim),
            ],
            ghosts: [.init(x: 0.04, z: 0.03)],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func rackPreview(tint: String) -> PracticeCoverLayout {
        // Sparse break-board cue + triangle hint (not a full 15-ball solver).
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.65, z: 0.00),
                .init(number: 1, x: 0.45, z: 0.00),
                .init(number: 2, x: 0.55, z: 0.06),
                .init(number: 3, x: 0.55, z: -0.06),
                .init(number: 8, x: 0.65, z: 0.00),
            ],
            segments: [
                .init(x0: -0.65, z0: 0.00, x1: 0.40, z1: 0.00, style: .aim),
            ],
            ghosts: [],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func photoBoardPreview(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.30, z: 0.25),
                .init(number: 1, x: 0.20, z: -0.10),
                .init(number: 7, x: 0.50, z: 0.20),
                .init(number: 9, x: -0.10, z: -0.30),
            ],
            segments: [],
            ghosts: [],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func toolGridPreview(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.40, z: 0.15),
                .init(number: 1, x: 0.00, z: 0.00),
                .init(number: 2, x: 0.35, z: -0.20),
            ],
            segments: [
                .init(x0: -0.40, z0: 0.15, x1: -0.06, z1: 0.02, style: .hint),
            ],
            ghosts: [],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func solverPreview(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.50, z: -0.25),
                .init(number: 4, x: 0.20, z: 0.10),
            ],
            segments: [
                .init(x0: -0.50, z0: -0.25, x1: 0.12, z1: 0.08, style: .aim),
                .init(x0: 0.20, z0: 0.10, x1: 0.90, z1: 0.35, style: .pot, potNumber: 4),
                .init(x0: 0.12, z0: 0.08, x1: -0.10, z1: 0.45, style: .hint),
            ],
            ghosts: [.init(x: 0.12, z: 0.08)],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func threeShotPreview(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.70, z: -0.15),
                .init(number: 1, x: -0.10, z: 0.05),
                .init(number: 2, x: 0.40, z: -0.20),
                .init(number: 3, x: 0.75, z: 0.15),
            ],
            segments: [
                .init(x0: -0.70, z0: -0.15, x1: -0.16, z1: 0.03, style: .aim),
                .init(x0: -0.10, z0: 0.05, x1: 0.34, z1: -0.16, style: .hint),
                .init(x0: 0.40, z0: -0.20, x1: 0.70, z1: 0.10, style: .hint),
            ],
            ghosts: [.init(x: -0.16, z: 0.03)],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func safetyPreview(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: 0.60, z: -0.30),
                .init(number: 8, x: -0.20, z: 0.25),
                .init(number: 1, x: -0.55, z: -0.10),
            ],
            segments: [
                .init(x0: 0.60, z0: -0.30, x1: 0.70, z1: 0.40, style: .aim),
                .init(x0: 0.70, z0: 0.40, x1: -0.10, z1: 0.28, style: .hint),
            ],
            ghosts: [],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func bankPreview(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.60, z: -0.25),
                .init(number: 5, x: 0.10, z: 0.15),
            ],
            segments: [
                .init(x0: -0.60, z0: -0.25, x1: 0.04, z1: 0.12, style: .aim),
                .init(x0: 0.10, z0: 0.15, x1: 0.55, z1: 0.50, style: .pot, potNumber: 5),
                .init(x0: 0.55, z0: 0.50, x1: 0.95, z1: -0.10, style: .hint),
            ],
            ghosts: [.init(x: 0.04, z: 0.12)],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }

    private static func kickPreview(tint: String) -> PracticeCoverLayout {
        PracticeCoverLayout(
            balls: [
                .init(number: nil, x: -0.40, z: -0.35),
                .init(number: 6, x: 0.45, z: 0.10),
                .init(number: 2, x: 0.00, z: 0.00),
            ],
            segments: [
                .init(x0: -0.40, z0: -0.35, x1: -0.70, z1: 0.20, style: .aim),
                .init(x0: -0.70, z0: 0.20, x1: 0.35, z1: 0.12, style: .hint),
            ],
            ghosts: [],
            closeup: nil,
            tintTopKey: tint,
            tintBottomKey: tint
        )
    }
}
