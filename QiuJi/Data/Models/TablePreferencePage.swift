import Foundation

/// Stable product entry identities shared by display preferences and control layouts.
enum TablePreferencePage: String, CaseIterable, Codable {
    case dailyClearance, freePlay, shotSimulation, snakePractice, composer, drillTryout
    case customFormationPractice, customFormationEditor
    case bankShot, diamondSystem, silu, planThree, snookerTactics
    case angleDynamic, separationAngleAtlas, cushionEnglishAtlas
    case drillDetailPreview, drillRecordPreview
    case sceneAiming2D, sceneAiming3D, aimPointScene2D, aimPointScene3D
    case accuracy2D, accuracy3D
    case separationPractice2D, separationPractice3D
    case twoBallPractice2D, twoBallPractice3D
}
