import SwiftUI

/// Six Tab / leftover-motif stills (v45). `allCases` must stay these six — custom
/// plans hash a separate `CoverArtKey` pool (v46 D-v46-6 / D-v46-16).
enum AtmosphereKey: String, CaseIterable, Equatable, Sendable {
    case feltEntry
    case feltAim
    case feltCue
    case feltRoute
    case feltForce
    case feltMix

    var imageName: String { rawValue }
}

/// Per-card / per-template generated stills (v46). Asset name == `rawValue`.
enum CoverArtKey: String, CaseIterable, Equatable, Sendable {
    case coverPlanBeginner
    case coverPlanAccuracy
    case coverPlanIntermediate
    case coverPlanForce
    case coverPlanCueball
    case coverPlanEnglish
    case coverPlanAccuracy3
    case coverPlanSeparation
    case coverPlanPositioning
    case coverPlanPositioning2
    case coverPlanAdvanced
    case coverPlanFullskill

    case coverPracticeAimingPrinciple
    case coverPracticeAimingMethods
    case coverPracticeAimingCorrection
    case coverPracticeSpinAndEnglish
    case coverPracticeAngleDynamic
    case coverPracticeSeparationAtlas
    case coverPracticeCushionEnglish
    case coverPracticeBallFeel
    case coverPracticeContactPoint
    case coverPracticeT01
    case coverPracticeT02
    case coverPracticeT03
    case coverPracticeT04
    case coverPracticeT09
    case coverPracticeT05
    case coverPracticeT06
    case coverPracticeT07
    case coverPracticeT08
    case coverPracticeT10
    case coverPracticeFlow
    case coverPracticeQuickRef
    case coverPracticeGeometricQuiz
    case coverPracticeSceneAiming2D
    case coverPracticeSceneAiming3D
    case coverPracticeAimPoint
    case coverPracticeAimPoint2D
    case coverPracticeAimPoint3D
    case coverPracticeShotSim
    case coverPracticeComposer
    case coverPracticeFreePlay
    case coverPracticeBallExtraction
    case coverPracticeSolver
    case coverPracticePlanThree
    case coverPracticeSnooker
    case coverPracticeBankShot
    case coverPracticeDiamond

    case coverTemplate01
    case coverTemplate02
    case coverTemplate03
    case coverTemplate04
    case coverTemplate05
    case coverTemplate06
    case coverTemplate07
    case coverTemplate08
    case coverTemplate09
    case coverTemplate10
    case coverTemplate11
    case coverTemplate12

    var imageName: String { rawValue }
}

enum AtmosphereImage: Equatable, Sendable {
    case motif(AtmosphereKey)
    case art(CoverArtKey)

    var imageName: String {
        switch self {
        case .motif(let key): return key.imageName
        case .art(let art): return art.imageName
        }
    }
}

/// Plan covers, practice cards, Tab bands (v45 motifs + v46 per-card art).
enum AtmosphereCatalog {

    static let fallbackKey: AtmosphereKey = .feltEntry

    static let officialPlanIds: [String] = [
        "plan_beginner",
        "plan_accuracy",
        "plan_intermediate",
        "plan_accuracy3",
        "plan_cueball",
        "plan_english",
        "plan_positioning",
        "plan_positioning2",
        "plan_force",
        "plan_separation",
        "plan_advanced",
        "plan_fullskill",
    ]

    static let templatePool: [CoverArtKey] = [
        .coverTemplate01, .coverTemplate02, .coverTemplate03, .coverTemplate04,
        .coverTemplate05, .coverTemplate06, .coverTemplate07, .coverTemplate08,
        .coverTemplate09, .coverTemplate10, .coverTemplate11, .coverTemplate12,
    ]

    static func coverArt(forPlanId planId: String) -> CoverArtKey? {
        switch planId {
        case "plan_beginner": return .coverPlanBeginner
        case "plan_accuracy": return .coverPlanAccuracy
        case "plan_intermediate": return .coverPlanIntermediate
        case "plan_force": return .coverPlanForce
        case "plan_cueball": return .coverPlanCueball
        case "plan_english": return .coverPlanEnglish
        case "plan_accuracy3": return .coverPlanAccuracy3
        case "plan_separation": return .coverPlanSeparation
        case "plan_positioning": return .coverPlanPositioning
        case "plan_positioning2": return .coverPlanPositioning2
        case "plan_advanced": return .coverPlanAdvanced
        case "plan_fullskill": return .coverPlanFullskill
        default: return nil
        }
    }

    static func image(forPlanId planId: String) -> AtmosphereImage {
        if let art = coverArt(forPlanId: planId) { return .art(art) }
        return .motif(fallbackKey)
    }

    /// Motif fallback for unknown plan ids. Official plans use `coverArt` / `image`.
    static func key(forPlanId planId: String) -> AtmosphereKey {
        _ = planId
        return fallbackKey
    }

    static func key(for tab: AppTab) -> AtmosphereKey {
        switch tab {
        case .training: return .feltEntry
        case .drillLibrary: return .feltRoute
        case .angle: return .feltCue
        case .history: return .feltForce
        case .profile: return .feltAim
        }
    }

    static func cover(for route: AngleRoute) -> (image: AtmosphereImage, pair: CoverPalette.Pair) {
        (image(for: route), pair(for: route))
    }

    static func image(for route: AngleRoute) -> AtmosphereImage {
        if let art = coverArt(for: route) { return .art(art) }
        return .motif(key(for: route))
    }

    static func coverArt(for route: AngleRoute) -> CoverArtKey? {
        switch route {
        case .aimingPrinciple: return .coverPracticeAimingPrinciple
        case .aimingMethods: return .coverPracticeAimingMethods
        case .aimingCorrection: return .coverPracticeAimingCorrection
        case .spinAndEnglish: return .coverPracticeSpinAndEnglish
        case .angleDynamic: return .coverPracticeAngleDynamic
        case .separationAngleAtlas: return .coverPracticeSeparationAtlas
        case .cushionEnglishAtlas: return .coverPracticeCushionEnglish
        case .ballFeel: return .coverPracticeBallFeel
        case .contactPointTable: return .coverPracticeContactPoint
        case .theoryPage(let pageID): return coverArt(forTheoryPage: pageID)
        case .geometricQuiz: return .coverPracticeGeometricQuiz
        case .sceneAiming2D: return .coverPracticeSceneAiming2D
        case .sceneAiming3D: return .coverPracticeSceneAiming3D
        case .aimPointTraining: return .coverPracticeAimPoint
        case .aimPointScene2D: return .coverPracticeAimPoint2D
        case .aimPointScene3D: return .coverPracticeAimPoint3D
        case .shotSimulation: return .coverPracticeShotSim
        case .positionPlayComposer: return .coverPracticeComposer
        case .freePlay: return .coverPracticeFreePlay
        case .ballExtraction: return .coverPracticeBallExtraction
        case .positionPlaySolver: return .coverPracticeSolver
        case .planThree: return .coverPracticePlanThree
        case .snookerTactics: return .coverPracticeSnooker
        case .bankShot: return .coverPracticeBankShot
        case .diamondSystem: return .coverPracticeDiamond
        case .theoryIndex, .batchDrillStudio, .drillDetail:
            return nil
        }
    }

    /// Motif fallback when a route has no dedicated cover art.
    static func key(for route: AngleRoute) -> AtmosphereKey {
        fallbackKey
    }

    static func pair(for route: AngleRoute) -> CoverPalette.Pair {
        let multicolor = CoverPalette.PracticeMulticolor.self
        return switch route {
        case .theoryIndex: multicolor.theoryIndex
        case .theoryPage(let pageID): pair(forTheoryPage: pageID)
        case .aimingPrinciple: multicolor.aimingPrinciple
        case .aimingMethods: multicolor.aimingMethods
        case .aimingCorrection: multicolor.aimingCorrection
        case .spinAndEnglish: multicolor.spinAndEnglish
        case .separationAngleAtlas: multicolor.separationAngleAtlas
        case .cushionEnglishAtlas: multicolor.cushionEnglishAtlas
        case .angleDynamic: multicolor.angleDynamic
        case .geometricQuiz: multicolor.geometricQuiz
        case .sceneAiming2D: multicolor.sceneAiming2D
        case .sceneAiming3D: multicolor.sceneAiming3D
        case .aimPointTraining: multicolor.aimPointTraining
        case .aimPointScene2D: multicolor.aimPointScene2D
        case .aimPointScene3D: multicolor.aimPointScene3D
        case .ballFeel: multicolor.ballFeel
        case .contactPointTable: multicolor.contactPointTable
        case .shotSimulation: multicolor.shotSimulation
        case .positionPlayComposer: multicolor.positionPlayComposer
        case .freePlay: multicolor.freePlay
        case .ballExtraction: multicolor.ballExtraction
        case .batchDrillStudio: multicolor.batchDrillStudio
        case .positionPlaySolver: multicolor.positionPlaySolver
        case .planThree: multicolor.planThree
        case .snookerTactics: multicolor.snookerTactics
        case .bankShot: multicolor.bankShot
        case .diamondSystem: multicolor.diamondSystem
        case .drillDetail: multicolor.aimingPrinciple
        }
    }

    static func pair(forTheoryPage pageID: TheoryPageID) -> CoverPalette.Pair {
        let multicolor = CoverPalette.PracticeMulticolor.self
        switch TheoryCatalog.entry(for: pageID)?.group {
        case .collision: return multicolor.theoryIndex
        case .spin: return multicolor.aimingMethods
        case .tactics: return multicolor.aimingCorrection
        case .flow: return multicolor.cushionEnglishAtlas
        case .none: return multicolor.theoryIndex
        }
    }

    private static func coverArt(forTheoryPage pageID: TheoryPageID) -> CoverArtKey {
        switch pageID {
        case .t01: return .coverPracticeT01
        case .t02: return .coverPracticeT02
        case .t03: return .coverPracticeT03
        case .t04: return .coverPracticeT04
        case .t09: return .coverPracticeT09
        case .t05: return .coverPracticeT05
        case .t06: return .coverPracticeT06
        case .t07: return .coverPracticeT07
        case .t08: return .coverPracticeT08
        case .t10: return .coverPracticeT10
        case .flow: return .coverPracticeFlow
        case .quickRef: return .coverPracticeQuickRef
        }
    }
}
