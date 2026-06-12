import SwiftData

enum ModelContainerFactory {

    static let allModels: [any PersistentModel.Type] = [
        TrainingSession.self,
        DrillEntry.self,
        DrillSet.self,
        AngleTestResult.self,
        UserActivePlan.self,
        DrillFavorite.self,
        SyncPendingItem.self,
        CustomPlan.self,
        CustomPlanDrill.self
    ]

    static func makeContainer() -> ModelContainer {
        let schema = Schema(allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("SwiftData ModelContainer init failed: \(error)")
        }
    }

    // Used in SwiftUI Previews and XCTests
    static func makeInMemoryContainer() -> ModelContainer {
        let schema = Schema(allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("SwiftData in-memory ModelContainer init failed: \(error)")
        }
    }
}
