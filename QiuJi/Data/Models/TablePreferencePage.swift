import Foundation

/// Stable product entry identities shared by display preferences and control layouts.
enum TablePreferencePage: String, CaseIterable, Codable {
    case dailyClearance, freePlay, shotSimulation, snakePractice, multiBallPractice, multiBallPractice3D, composer, drillTryout
    case customFormationPractice, customFormationEditor
    case bankShot, diamondSystem, silu, planThree
    case pocketTolerance, angleDynamic, separationAngleAtlas, cushionEnglishAtlas
    case drillDetailPreview, drillRecordPreview
    case sceneAiming2D, sceneAiming3D, aimPointScene2D, aimPointScene3D
    case accuracy2D, accuracy3D
    case separationPractice2D, separationPractice3D
    case kickPractice2D, kickPractice3D
    case defensePractice2D, defensePractice3D
    case bankPractice2D, bankPractice3D
    case kBallPractice2D, kBallPractice3D
    case twoBallPractice2D, twoBallPractice3D
    case threeBallPractice2D, threeBallPractice3D
}
