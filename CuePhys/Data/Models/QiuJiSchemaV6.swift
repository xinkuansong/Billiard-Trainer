import SwiftData

/// V6 adds versioned scene-training metadata. V5 keeps its frozen result model.
enum QiuJiSchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)
    static var models: [any PersistentModel.Type] {
        [TrainingSession.self, DrillEntry.self, DrillSet.self, AngleTestResult.self,
         UserActivePlan.self, DrillFavorite.self, SyncPendingItem.self, CustomPlan.self,
         CustomPlanDrill.self, TodayTrainingSchedule.self, TodayScheduleItem.self]
    }
}
