import XCTest
@testable import QiuJi

final class V54PlanContentModelTests: XCTestCase {
    func testBundledStagePlanKeepsStableStagesAndLessons() async throws {
        let plan = await PlanContentService.shared.loadPlanFromBundle(id: "plan_beginner")
        let decoded = try XCTUnwrap(plan)

        XCTAssertEqual(decoded.stages.count, 3)
        XCTAssertEqual(decoded.lessonCount, 9)
        XCTAssertEqual(decoded.stages[1].id, "plan_beginner.stage02")
        XCTAssertEqual(decoded.stages[1].lessons[0].id, "plan_beginner.stage02.lesson01")
        XCTAssertEqual(decoded.stages[1].lessons[0].title, "直线推白球")
    }

    func testLegacyWeekPayloadStillDecodesIntoStableStagesAndLessons() throws {
        var payload = basePayload()
        payload.removeValue(forKey: "estimatedMinutesPerLesson")
        payload["durationWeeks"] = 1
        payload["sessionsPerWeek"] = 1
        payload["minutesPerSession"] = 75
        payload["weeks"] = [[
            "weekNumber": 1,
            "theme": "旧阶段",
            "sessions": [["dayNumber": 1, "phases": [phase()]]],
        ]]

        let decoded = try decode(payload)
        XCTAssertEqual(decoded.stages[0].id, "plan_v54_test.stage01")
        XCTAssertEqual(decoded.stages[0].lessons[0].id, "plan_v54_test.stage01.lesson01")
        XCTAssertEqual(decoded.stages[0].lessons[0].title, "第 1 课")
    }

    func testNewStagePlanDecodesAndFlattensInCurriculumOrder() throws {
        let plan = try decode(stages: [
            stage(id: "stage-b", order: 2, lessons: [lesson(id: "lesson-b", order: 1)]),
            stage(id: "stage-a", order: 1, lessons: [lesson(id: "lesson-a", order: 1)]),
        ])

        XCTAssertEqual(plan.stages.count, 2)
        XCTAssertEqual(plan.lessons.map(\.id), ["lesson-a", "lesson-b"])
        XCTAssertEqual(plan.minutesPerSession, 75)
    }

    func testNewStagePlanRejectsEmptyStages() {
        XCTAssertThrowsError(try decode(stages: []))
    }

    func testNewStagePlanRejectsMissingStageID() throws {
        var invalid = stage(id: "stage-a", order: 1, lessons: [lesson(id: "lesson-a", order: 1)])
        invalid.removeValue(forKey: "id")

        XCTAssertThrowsError(try decode(stages: [invalid]))
    }

    func testNewStagePlanRejectsDuplicateStageOrder() {
        XCTAssertThrowsError(try decode(stages: [
            stage(id: "stage-a", order: 1, lessons: [lesson(id: "lesson-a", order: 1)]),
            stage(id: "stage-b", order: 1, lessons: [lesson(id: "lesson-b", order: 1)]),
        ]))
    }

    func testNewStagePlanRejectsEmptyLessons() {
        XCTAssertThrowsError(try decode(stages: [stage(id: "stage-a", order: 1, lessons: [])]))
    }

    func testNewStagePlanRejectsDuplicateLessonIDAcrossStages() {
        XCTAssertThrowsError(try decode(stages: [
            stage(id: "stage-a", order: 1, lessons: [lesson(id: "same", order: 1)]),
            stage(id: "stage-b", order: 2, lessons: [lesson(id: "same", order: 1)]),
        ]))
    }

    func testPlanRejectsAmbiguousNewAndLegacyStructures() throws {
        var payload = basePayload()
        payload["stages"] = [stage(
            id: "stage-a",
            order: 1,
            lessons: [lesson(id: "lesson-a", order: 1)]
        )]
        payload["weeks"] = [[
            "weekNumber": 1,
            "theme": "legacy",
            "sessions": [["dayNumber": 1, "phases": [phase()]]],
        ]]

        XCTAssertThrowsError(try decode(payload))
    }

    private func decode(stages: [[String: Any]]) throws -> OfficialPlan {
        var payload = basePayload()
        payload["stages"] = stages
        return try decode(payload)
    }

    private func decode(_ payload: [String: Any]) throws -> OfficialPlan {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return try JSONDecoder().decode(OfficialPlan.self, from: data)
    }

    private func basePayload() -> [String: Any] {
        [
            "id": "plan_v54_test",
            "nameZh": "测试计划",
            "nameEn": "Test Plan",
            "targetLevel": "L0→L1",
            "estimatedMinutesPerLesson": 75,
            "isPremium": false,
            "description": "fixture",
        ]
    }

    private func stage(
        id: String,
        order: Int,
        lessons: [[String: Any]]
    ) -> [String: Any] {
        [
            "id": id,
            "order": order,
            "title": "阶段 \(order)",
            "goal": "目标",
            "lessons": lessons,
        ]
    }

    private func lesson(id: String, order: Int) -> [String: Any] {
        [
            "id": id,
            "order": order,
            "title": "课程 \(order)",
            "summary": "摘要",
            "phases": [phase()],
        ]
    }

    private func phase() -> [String: Any] {
        [
            "type": "focused",
            "durationMinutes": 75,
            "drills": [["drillId": "drill_c001"]],
        ]
    }
}
