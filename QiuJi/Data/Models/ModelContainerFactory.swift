import Foundation
import SwiftData

enum ModelContainerFactory {

    /// 当前（V2）模型集。历史形态见 `QiuJiSchemaV1`。
    static let allModels: [any PersistentModel.Type] = QiuJiSchemaV2.models

    static let currentSchema = Schema(versionedSchema: QiuJiSchemaV2.self)

    static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: currentSchema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(
                for: currentSchema,
                migrationPlan: QiuJiMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("SwiftData ModelContainer init failed: \(error)")
        }
    }

    // Used in SwiftUI Previews and XCTests
    static func makeInMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: currentSchema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(
                for: currentSchema,
                migrationPlan: QiuJiMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("SwiftData in-memory ModelContainer init failed: \(error)")
        }
    }

    /// 指定 store 文件打开当前版本容器（走迁移计划）。迁移测试用此入口打开旧库。
    static func makeContainer(at url: URL) throws -> ModelContainer {
        let config = ModelConfiguration(schema: currentSchema, url: url)
        return try ModelContainer(
            for: currentSchema,
            migrationPlan: QiuJiMigrationPlan.self,
            configurations: config
        )
    }
}
