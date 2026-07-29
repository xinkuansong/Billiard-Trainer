import Foundation

/// Single façade for Practice-tab UserDefaults keys (C24).
///
/// **Migration policy**: string values are frozen — only references are centralized.
/// Renaming a raw value would wipe existing user data.
enum PracticeStorageKey {
    /// Daily free-tier question count (`AngleUsageLimiter`).
    static let angleUsageCount = "AngleUsage_count"
    /// Calendar day stamp for the count (`yyyy-MM-dd`).
    static let angleUsageDate = "AngleUsage_date"
    /// Adaptive zone history blob (`AdaptiveQuestionEngine`).
    static let adaptiveQuestionEngine = "AdaptiveQuestionEngine_v1"
    /// Shared cushion / bank-shot power (`CushionReflectionSettings`).
    static let cushionReflectionPower = "cushionReflectionPower"
    /// First-drag coach tip dismissed (`AngleDynamicView` `@AppStorage`).
    static let angleDynamicHasDraggedOnce = "angleDynamic.hasDraggedOnce"
    /// Aim closeup loupe HUD visibility (`UserPreferences`, default on).
    static let showAimCloseup = "showAimCloseup"
    /// UITest-only forced geometric angle (production default 0 = unused).
    static let geometricQuizForcedAngle = "geometricQuiz.forcedAngle"
}
