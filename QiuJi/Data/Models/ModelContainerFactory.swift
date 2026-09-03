import Foundation
import SwiftData

enum ModelContainerFactory {

    /// 当前（V5）模型集。历史形态见 `QiuJiSchemaV1`–`QiuJiSchemaV4`。
    static let allModels: [any PersistentModel.Type] = QiuJiSchemaV5.models

    static let currentSchema = Schema(versionedSchema: QiuJiSchemaV5.self)

    static func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: currentSchema, isStoredInMemoryOnly: false)
        do {
            let needsDoseNormalization = CustomPlanDoseMigration.storeNeedsNormalization(at: config.url)
            let container = try ModelContainer(
                for: currentSchema,
                migrationPlan: QiuJiMigrationPlan.self,
                configurations: config
            )
            if needsDoseNormalization {
                try CustomPlanDoseMigration.normalizeMigratedVolume(in: container)
            }
            try OwnerV4Migration.normalizeUnassigned(
                in: container,
                guestOwnerKey: DeviceGuestIdentity.ownerKey()
            )
            try V54DataMigration.normalize(in: container)
            return container
        } catch {
            fatalError("SwiftData ModelContainer init failed: \(error)")
        }
    }

    // Used in SwiftUI Previews and XCTests
    static func makeInMemoryContainer() -> ModelContainer {
        let config = ModelConfiguration(schema: currentSchema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(
                for: currentSchema,
                migrationPlan: QiuJiMigrationPlan.self,
                configurations: config
            )
            try OwnerV4Migration.normalizeUnassigned(
                in: container,
                guestOwnerKey: DeviceGuestIdentity.ownerKey()
            )
            try V54DataMigration.normalize(in: container)
            return container
        } catch {
            fatalError("SwiftData in-memory ModelContainer init failed: \(error)")
        }
    }

    /// 指定 store 文件打开当前版本容器（走迁移计划）。迁移测试用此入口打开旧库。
    static func makeContainer(at url: URL) throws -> ModelContainer {
        let needsDoseNormalization = CustomPlanDoseMigration.storeNeedsNormalization(at: url)
        let config = ModelConfiguration(schema: currentSchema, url: url)
        let container = try ModelContainer(
            for: currentSchema,
            migrationPlan: QiuJiMigrationPlan.self,
            configurations: config
        )
        if needsDoseNormalization {
            try CustomPlanDoseMigration.normalizeMigratedVolume(in: container)
        }
        try OwnerV4Migration.normalizeUnassigned(
            in: container,
            guestOwnerKey: DeviceGuestIdentity.ownerKey()
        )
        try V54DataMigration.normalize(in: container)
        return container
    }
}
