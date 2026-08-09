import XCTest
import SwiftData
import SQLite3
@testable import QiuJi

/// v29 W3 迁移实证：用 V1 schema 写一个真实旧库（落盘），再用当前容器（带
/// `QiuJiMigrationPlan`）打开，断言旧数据零丢失且新字段取默认值。
/// 红线：不得以删库重建绕过迁移——本用例正是该红线的守卫。
final class SwiftDataMigrationTests: XCTestCase {

    private var storeDirectory: URL!
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QiuJiMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        storeURL = storeDirectory.appendingPathComponent("QiuJi-V1.store")
    }

    override func tearDownWithError() throws {
        if let storeDirectory { try? FileManager.default.removeItem(at: storeDirectory) }
        storeDirectory = nil
        storeURL = nil
        try super.tearDownWithError()
    }

    // MARK: - V1 旧库构造

    /// 用 V1 schema 写入 2 个 session（各含 entry / set）与 3 条角度成绩，落盘后释放容器。
    private func seedV1Store() throws {
        let v1Schema = Schema(versionedSchema: QiuJiSchemaV1.self)
        let config = ModelConfiguration(schema: v1Schema, url: storeURL)
        let container = try ModelContainer(for: v1Schema, configurations: config)
        let context = ModelContext(container)

        for sessionIndex in 0..<2 {
            let session = QiuJiSchemaV1.TrainingSession(ballType: sessionIndex == 0 ? "chinese8" : "snooker")
            session.totalDurationMinutes = 30 + sessionIndex
            session.note = "旧库训练心得 \(sessionIndex)"
            context.insert(session)

            let entry = QiuJiSchemaV1.DrillEntry(
                drillId: "drill_c00\(sessionIndex + 1)",
                drillNameZh: "旧库动作 \(sessionIndex + 1)"
            )
            entry.session = session
            session.drillEntries.append(entry)
            context.insert(entry)

            for setNumber in 1...2 {
                let set = QiuJiSchemaV1.DrillSet(
                    setNumber: setNumber,
                    targetBalls: 10,
                    madeBalls: 5 + setNumber
                )
                set.entry = entry
                entry.sets.append(set)
                context.insert(set)
            }
        }

        for angleIndex in 0..<3 {
            let result = QiuJiSchemaV1.AngleTestResult(
                actualAngle: 30.0 + Double(angleIndex),
                userAngle: 28.0 + Double(angleIndex),
                pocketType: "corner",
                quizType: "geometric",
                errorMM: Double(angleIndex)
            )
            context.insert(result)
        }

        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QiuJiSchemaV1.TrainingSession>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QiuJiSchemaV1.DrillEntry>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QiuJiSchemaV1.DrillSet>()), 4)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QiuJiSchemaV1.AngleTestResult>()), 3)
    }

    /// 直读 sqlite 表结构：用于证明迁移前后是**同一个物理文件**在原地加列，
    /// 而不是被删库重建（红线守卫）。
    private func columnNames(ofTable table: String) -> Set<String> {
        var db: OpaquePointer?
        guard sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            XCTFail("无法打开 store: \(storeURL.path)")
            return []
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &statement, nil) == SQLITE_OK else {
            XCTFail("PRAGMA table_info(\(table)) 准备失败")
            return []
        }
        defer { sqlite3_finalize(statement) }
        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let raw = sqlite3_column_text(statement, 1) {
                names.insert(String(cString: raw).uppercased())
            }
        }
        return names
    }

    // MARK: - 迁移断言

    func test_migration_V1_to_V2_preservesAllData_andDefaultsNewFields() throws {
        try seedV1Store()
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path),
                      "V1 store 未落盘，后续断言无意义")

        // 迁移前：物理表里没有 V2 新增列
        let sessionColumnsBefore = columnNames(ofTable: "ZTRAININGSESSION")
        XCTAssertTrue(sessionColumnsBefore.contains("ZBALLTYPE"), "表名或列名解析失败：\(sessionColumnsBefore)")
        XCTAssertFalse(sessionColumnsBefore.contains("ZKIND"), "V1 store 不应已有 kind 列")
        XCTAssertFalse(columnNames(ofTable: "ZDRILLSET").contains("ZDURATIONSECONDS"))
        XCTAssertFalse(columnNames(ofTable: "ZANGLETESTRESULT").contains("ZSESSIONID"))

        // 用当前版本容器打开同一个 store 文件 → 触发 V1 → V2 轻量迁移
        let container = try ModelContainerFactory.makeContainer(at: storeURL)
        let context = ModelContext(container)

        let sessions = try context.fetch(
            FetchDescriptor<TrainingSession>(sortBy: [SortDescriptor(\.totalDurationMinutes)])
        )
        let entries = try context.fetch(FetchDescriptor<DrillEntry>(sortBy: [SortDescriptor(\.drillId)]))
        let sets = try context.fetch(FetchDescriptor<DrillSet>(sortBy: [SortDescriptor(\.setNumber)]))
        let angles = try context.fetch(FetchDescriptor<AngleTestResult>(sortBy: [SortDescriptor(\.actualAngle)]))

        // 1) 旧数据零丢失：条数与内容都在
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(sets.count, 4)
        XCTAssertEqual(angles.count, 3)

        XCTAssertEqual(sessions.map(\.ballType), ["chinese8", "snooker"])
        XCTAssertEqual(sessions.map(\.totalDurationMinutes), [30, 31])
        XCTAssertEqual(sessions.map(\.note), ["旧库训练心得 0", "旧库训练心得 1"])
        XCTAssertEqual(entries.map(\.drillId), ["drill_c001", "drill_c002"])
        XCTAssertEqual(entries.map(\.drillNameZh), ["旧库动作 1", "旧库动作 2"])
        XCTAssertEqual(sets.map(\.madeBalls).sorted(), [6, 6, 7, 7])
        XCTAssertEqual(sets.map(\.targetBalls), [10, 10, 10, 10])
        XCTAssertEqual(angles.map(\.actualAngle), [30.0, 31.0, 32.0])
        XCTAssertEqual(angles.map(\.quizType), ["geometric", "geometric", "geometric"])
        XCTAssertEqual(angles.map(\.errorMM), [0.0, 1.0, 2.0])

        // 2) 关系仍然完整（迁移未打断 entry ↔ session ↔ set 图）
        for session in sessions {
            XCTAssertEqual(session.drillEntries.count, 1)
            XCTAssertEqual(session.drillEntries.first?.sets.count, 2)
            XCTAssertEqual(session.drillEntries.first?.session?.id, session.id)
        }

        // 3) 新字段取默认值
        for session in sessions {
            XCTAssertEqual(session.kind, "drill")
            XCTAssertNil(session.planId)
        }
        for entry in entries {
            XCTAssertEqual(entry.orderIndex, 0)
            XCTAssertEqual(entry.note, "")
            XCTAssertEqual(entry.criteriaText, "")
        }
        for set in sets {
            XCTAssertNil(set.formationToken)
            XCTAssertNil(set.formationName)
            XCTAssertEqual(set.unitLabel, "球")
            XCTAssertEqual(set.passMade, 0)
            XCTAssertEqual(set.passTotal, 0)
            XCTAssertNil(set.durationSeconds)
        }
        for angle in angles {
            XCTAssertNil(angle.sessionId)
        }

        // 4) 迁移后：同一物理文件已就地加列（非删库重建）
        let sessionColumnsAfter = columnNames(ofTable: "ZTRAININGSESSION")
        XCTAssertTrue(sessionColumnsAfter.contains("ZKIND"))
        XCTAssertTrue(sessionColumnsAfter.isSuperset(of: sessionColumnsBefore),
                      "迁移后不得丢失任何 V1 列")
        let setColumnsAfter = columnNames(ofTable: "ZDRILLSET")
        for column in ["ZFORMATIONTOKEN", "ZFORMATIONNAME", "ZUNITLABEL",
                       "ZPASSMADE", "ZPASSTOTAL", "ZDURATIONSECONDS"] {
            XCTAssertTrue(setColumnsAfter.contains(column), "DrillSet 缺列 \(column)")
        }
        let entryColumnsAfter = columnNames(ofTable: "ZDRILLENTRY")
        for column in ["ZORDERINDEX", "ZNOTE", "ZCRITERIATEXT"] {
            XCTAssertTrue(entryColumnsAfter.contains(column), "DrillEntry 缺列 \(column)")
        }
        XCTAssertTrue(columnNames(ofTable: "ZANGLETESTRESULT").contains("ZSESSIONID"))
    }

    /// 迁移后写入新字段并重开容器，证明 V2 形态可持久化（不是只读兼容）。
    func test_migration_thenWriteNewFields_persists() throws {
        try seedV1Store()

        let sessionId: UUID
        do {
            let container = try ModelContainerFactory.makeContainer(at: storeURL)
            let context = ModelContext(container)
            let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
            let session = try XCTUnwrap(sessions.first)
            sessionId = session.id
            session.kind = "cognitive"
            let entry = try XCTUnwrap(session.drillEntries.first)
            entry.orderIndex = 3
            entry.note = "W3 写入"
            entry.criteriaText = "10 球进 7"
            let set = try XCTUnwrap(entry.sets.first)
            set.formationToken = "A2"
            set.formationName = "斜线中袋"
            set.unitLabel = "次"
            set.passMade = 7
            set.passTotal = 10
            set.durationSeconds = 95
            try context.save()
        }

        let reopened = try ModelContainerFactory.makeContainer(at: storeURL)
        let context = ModelContext(reopened)
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(sessions.count, 2, "写入不应丢失任何 session")
        let session = try XCTUnwrap(sessions.first { $0.id == sessionId })
        XCTAssertEqual(session.kind, "cognitive")
        let entry = try XCTUnwrap(session.drillEntries.first)
        XCTAssertEqual(entry.orderIndex, 3)
        XCTAssertEqual(entry.note, "W3 写入")
        XCTAssertEqual(entry.criteriaText, "10 球进 7")
        let set = try XCTUnwrap(entry.sets.first { $0.formationToken != nil })
        XCTAssertEqual(set.formationName, "斜线中袋")
        XCTAssertEqual(set.unitLabel, "次")
        XCTAssertEqual(set.passMade, 7)
        XCTAssertEqual(set.passTotal, 10)
        XCTAssertEqual(set.durationSeconds, 95)
    }

    // MARK: - V2 → V3（自定义计划改存强度系数，v31 W0 / ADR-v31-01）

    /// 用 V2 schema 写一个含自定义计划的真实旧库。三条目分别覆盖单球形 / 双球形 / 三球形，
    /// 用于验证 `rounds = max(1, sets / 球形数)` 的三种取整分支。
    private func seedV2Store() throws {
        let v2Schema = Schema(versionedSchema: QiuJiSchemaV2.self)
        let config = ModelConfiguration(schema: v2Schema, url: storeURL)
        let container = try ModelContainer(for: v2Schema, configurations: config)
        let context = ModelContext(container)

        let session = TrainingSession(ballType: "chinese8")
        session.note = "V2 旧库训练"
        context.insert(session)

        let plan = QiuJiSchemaV2.CustomPlan(name: "V2 自定义计划", sessionsPerWeek: 4)
        context.insert(plan)
        let legacyDrills = [
            // drill_c001：单球形（无 tutorial.formations）→ 6 / 1 = 6
            QiuJiSchemaV2.CustomPlanDrill(
                drillId: "drill_c001", drillNameZh: "半台直线球",
                sets: 6, ballsPerSet: 5, order: 0
            ),
            // drill_c013：2 球形 → 6 / 2 = 3
            QiuJiSchemaV2.CustomPlanDrill(
                drillId: "drill_c013", drillNameZh: "分离角控制",
                sets: 6, ballsPerSet: 9, order: 1
            ),
            // drill_c026：3 球形，2 / 3 = 0 → 下限钳到 1
            QiuJiSchemaV2.CustomPlanDrill(
                drillId: "drill_c026", drillNameZh: "多球走位",
                sets: 2, ballsPerSet: 10, order: 2
            )
        ]
        for drill in legacyDrills { context.insert(drill) }
        plan.drills = legacyDrills

        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QiuJiSchemaV2.CustomPlan>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QiuJiSchemaV2.CustomPlanDrill>()), 3)
    }

    func test_migration_V2_to_V3_convertsSetsToRounds_andPreservesData() throws {
        try seedV2Store()

        let planColumnsBefore = columnNames(ofTable: "ZCUSTOMPLANDRILL")
        XCTAssertTrue(planColumnsBefore.contains("ZSETS"), "V2 store 应有 sets 列：\(planColumnsBefore)")
        XCTAssertTrue(planColumnsBefore.contains("ZBALLSPERSET"))
        XCTAssertFalse(planColumnsBefore.contains("ZROUNDSPERFORMATION"), "V2 store 不应已有 V3 列")

        // 用当前版本容器打开同一个 store 文件 → 触发 V2 → V3 自定义迁移
        let container = try ModelContainerFactory.makeContainer(at: storeURL)
        let context = ModelContext(container)

        // 1) 旧数据零丢失
        let plans = try context.fetch(FetchDescriptor<CustomPlan>())
        XCTAssertEqual(plans.count, 1)
        let plan = try XCTUnwrap(plans.first)
        XCTAssertEqual(plan.name, "V2 自定义计划")
        XCTAssertEqual(plan.sessionsPerWeek, 4)
        XCTAssertEqual(plan.drills.count, 3, "迁移不得丢失计划条目")

        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.note, "V2 旧库训练")

        // 2) 身份字段与顺序原样保留
        let drills = plan.drills.sorted { $0.order < $1.order }
        XCTAssertEqual(drills.map(\.drillId), ["drill_c001", "drill_c013", "drill_c026"])
        XCTAssertEqual(drills.map(\.drillNameZh), ["半台直线球", "分离角控制", "多球走位"])
        XCTAssertEqual(drills.map(\.order), [0, 1, 2])

        // 3) 折算规则 rounds = max(1, sets / 球形数)
        XCTAssertEqual(drills[0].roundsPerFormation, 6, "单球形：6 / 1")
        XCTAssertEqual(drills[1].roundsPerFormation, 3, "双球形：6 / 2")
        XCTAssertEqual(drills[2].roundsPerFormation, 1, "三球形：2 / 3 向下取 0，下限钳到 1")

        // 4) 同一物理文件就地改列（非删库重建）
        let planColumnsAfter = columnNames(ofTable: "ZCUSTOMPLANDRILL")
        XCTAssertTrue(planColumnsAfter.contains("ZROUNDSPERFORMATION"))
        for retained in ["ZDRILLID", "ZDRILLNAMEZH", "ZORDER"] {
            XCTAssertTrue(planColumnsAfter.contains(retained), "缺列 \(retained)")
        }
    }

    /// 迁移后写入并重开，证明 V3 形态可持久化。
    func test_migration_V2_to_V3_thenWrite_persists() throws {
        try seedV2Store()

        do {
            let container = try ModelContainerFactory.makeContainer(at: storeURL)
            let context = ModelContext(container)
            let plan = try XCTUnwrap(try context.fetch(FetchDescriptor<CustomPlan>()).first)
            let drill = try XCTUnwrap(plan.drills.first { $0.drillId == "drill_c013" })
            drill.roundsPerFormation = 5
            try context.save()
        }

        let reopened = try ModelContainerFactory.makeContainer(at: storeURL)
        let context = ModelContext(reopened)
        let plan = try XCTUnwrap(try context.fetch(FetchDescriptor<CustomPlan>()).first)
        XCTAssertEqual(plan.drills.count, 3)
        let drill = try XCTUnwrap(plan.drills.first { $0.drillId == "drill_c013" })
        XCTAssertEqual(drill.roundsPerFormation, 5)
    }

    /// 新增字段的默认值契约（裸构造），与迁移默认值保持一致。
    func test_newFields_defaultValues_onFreshObjects() throws {
        XCTAssertEqual(TrainingSession().kind, "drill")

        let entry = DrillEntry(drillId: "drill_c001", drillNameZh: "测试动作")
        XCTAssertEqual(entry.orderIndex, 0)
        XCTAssertEqual(entry.note, "")
        XCTAssertEqual(entry.criteriaText, "")

        let set = DrillSet(setNumber: 1, targetBalls: 10)
        XCTAssertNil(set.formationToken)
        XCTAssertNil(set.formationName)
        XCTAssertEqual(set.unitLabel, "球")
        XCTAssertEqual(set.passMade, 0)
        XCTAssertEqual(set.passTotal, 0)
        XCTAssertNil(set.durationSeconds)

        let angle = AngleTestResult(actualAngle: 30, userAngle: 28, pocketType: "corner")
        XCTAssertNil(angle.sessionId)
    }
}
