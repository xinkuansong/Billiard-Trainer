import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class DrillTrainingPlanServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Add to existing plan

    func test_addDrill_appendsAndPersists() throws {
        let plan = CustomPlan(name: "晚练清单", sessionsPerWeek: 3)
        context.insert(plan)
        try context.save()

        let drill = makeDrill(id: "drill_c042", name: "初级蛇彩走位")
        let result = try DrillTrainingPlanService.addDrill(drill, to: plan, context: context)

        XCTAssertEqual(result, .added(planName: "晚练清单", appearsInToday: false))

        let fetched = try context.fetch(FetchDescriptor<CustomPlan>()).first
        XCTAssertEqual(fetched?.drills.count, 1)
        XCTAssertEqual(fetched?.drills.first?.drillId, "drill_c042")
        XCTAssertEqual(fetched?.drills.first?.drillNameZh, "初级蛇彩走位")
        XCTAssertEqual(fetched?.drills.first?.sets, 5)
        XCTAssertEqual(fetched?.drills.first?.ballsPerSet, 3)
    }

    func test_addDrill_toActiveCustomPlan_appearsInToday() throws {
        let plan = CustomPlan(name: "今日清单", sessionsPerWeek: 4)
        context.insert(plan)
        context.insert(UserActivePlan(planId: plan.id.uuidString, isCustom: true))
        try context.save()

        let drill = makeDrill(id: "drill_c001", name: "直线瞄准")
        let result = try DrillTrainingPlanService.addDrill(drill, to: plan, context: context)

        XCTAssertEqual(result, .added(planName: "今日清单", appearsInToday: true))

        let active = try DrillTrainingPlanService.activeCustomPlan(context: context)
        XCTAssertEqual(active?.id, plan.id)
        XCTAssertTrue(DrillTrainingPlanService.planContainsDrill(plan, drillId: "drill_c001"))

        // Mirror TrainingHomeViewModel custom-plan path: today's drill list includes the id.
        let todayIds = plan.drills.map(\.drillId)
        XCTAssertTrue(todayIds.contains("drill_c001"))
    }

    func test_addDrill_duplicate_doesNotInsertTwice() throws {
        let plan = CustomPlan(name: "清单", sessionsPerWeek: 3)
        plan.drills = [
            CustomPlanDrill(drillId: "drill_c042", drillNameZh: "蛇彩", sets: 5, ballsPerSet: 3, order: 0)
        ]
        context.insert(plan)
        try context.save()

        let result = try DrillTrainingPlanService.addDrill(
            makeDrill(id: "drill_c042", name: "初级蛇彩走位"),
            to: plan,
            context: context
        )

        XCTAssertEqual(result, .alreadyPresent(planName: "清单", appearsInToday: false))
        XCTAssertEqual(plan.drills.count, 1)
    }

    // MARK: - Create + activate

    func test_createPlan_activateAsToday_writesUserActivePlan() throws {
        let drill = makeDrill(id: "drill_c010", name: "中袋准度")
        let (plan, result) = try DrillTrainingPlanService.createPlan(
            name: "从动作库 · 中袋准度",
            drill: drill,
            activateAsToday: true,
            context: context
        )

        XCTAssertEqual(result, .added(planName: "从动作库 · 中袋准度", appearsInToday: true))

        let plans = try context.fetch(FetchDescriptor<CustomPlan>())
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans.first?.drills.first?.drillId, "drill_c010")

        let actives = try context.fetch(FetchDescriptor<UserActivePlan>())
        XCTAssertEqual(actives.count, 1)
        XCTAssertTrue(actives[0].isCustom)
        XCTAssertEqual(actives[0].planId, plan.id.uuidString)

        let activePlan = try DrillTrainingPlanService.activeCustomPlan(context: context)
        XCTAssertEqual(activePlan?.drills.map(\.drillId), ["drill_c010"])
    }

    func test_createPlan_withoutActivate_doesNotTouchToday() throws {
        let existing = CustomPlan(name: "原今日", sessionsPerWeek: 2)
        context.insert(existing)
        context.insert(UserActivePlan(planId: existing.id.uuidString, isCustom: true))
        try context.save()

        let (_, result) = try DrillTrainingPlanService.createPlan(
            name: "旁路计划",
            drill: makeDrill(id: "drill_c002", name: "侧袋"),
            activateAsToday: false,
            context: context
        )

        XCTAssertEqual(result, .added(planName: "旁路计划", appearsInToday: false))
        let active = try DrillTrainingPlanService.activeCustomPlan(context: context)
        XCTAssertEqual(active?.id, existing.id)
        XCTAssertFalse(DrillTrainingPlanService.planContainsDrill(active!, drillId: "drill_c002"))
    }

    func test_createPlan_emptyName_throws() {
        XCTAssertThrowsError(
            try DrillTrainingPlanService.createPlan(
                name: "   ",
                drill: makeDrill(id: "x", name: "x"),
                activateAsToday: false,
                context: context
            )
        ) { error in
            XCTAssertEqual(error as? DrillTrainingPlanService.ServiceError, .emptyName)
        }
    }

    // MARK: - Helpers

    private func makeDrill(id: String, name: String) -> DrillContent {
        DrillContent(
            id: id,
            nameZh: name,
            nameEn: "Test",
            category: "positioning",
            subcategory: "test",
            ballType: ["universal"],
            level: "L1",
            difficulty: 2,
            isPremium: false,
            description: "Test",
            coachingPoints: ["p"],
            standardCriteria: "criteria",
            sets: DrillContent.DrillSetsConfig(defaultSets: 5, defaultBallsPerSet: 3),
            animation: DrillAnimation(
                cueBall: BallAnimation(
                    start: CanvasPoint(x: 0.5, y: 0.25),
                    path: [PathPoint(x: 0.5, y: 0.4)]
                ),
                targetBall: BallAnimation(
                    start: CanvasPoint(x: 0.5, y: 0.42),
                    path: [PathPoint(x: 0.5, y: 0.5)]
                ),
                pocket: "bottomCenter",
                cueDirection: CanvasPoint(x: 0.5, y: 0.0)
            )
        )
    }
}
