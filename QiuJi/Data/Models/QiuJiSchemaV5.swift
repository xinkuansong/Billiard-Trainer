import SwiftData

/// V5 = v54 official curriculum cursor, persisted today schedule, and session provenance.
enum QiuJiSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TrainingSession.self,
            DrillEntry.self,
            DrillSet.self,
            AngleTestResult.self,
            UserActivePlan.self,
            DrillFavorite.self,
            SyncPendingItem.self,
            CustomPlan.self,
            CustomPlanDrill.self,
            TodayTrainingSchedule.self,
            TodayScheduleItem.self
        ]
    }
}
