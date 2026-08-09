import XCTest
import SwiftData
@testable import QiuJi

@MainActor
final class CustomPlanBuilderViewModelTests: XCTestCase {

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

    // MARK: - Initial state

    func test_initial_state() {
        let vm = CustomPlanBuilderViewModel()
        XCTAssertTrue(vm.name.isEmpty)
        XCTAssertEqual(vm.sessionsPerWeek, 3)
        XCTAssertTrue(vm.drillItems.isEmpty)
        XCTAssertFalse(vm.showDrillPicker)
        XCTAssertNil(vm.saveError)
        XCTAssertNil(vm.editingPlanId)
        XCTAssertFalse(vm.isEditing)
        XCTAssertFalse(vm.canSave)
    }

    // MARK: - canSave validation

    func test_canSave_empty_name() {
        let vm = CustomPlanBuilderViewModel()
        vm.drillItems = [makeItem()]
        vm.name = ""
        XCTAssertFalse(vm.canSave)
    }

    func test_canSave_whitespace_name() {
        let vm = CustomPlanBuilderViewModel()
        vm.drillItems = [makeItem()]
        vm.name = "   "
        XCTAssertFalse(vm.canSave)
    }

    func test_canSave_empty_drills() {
        let vm = CustomPlanBuilderViewModel()
        vm.name = "Test Plan"
        XCTAssertFalse(vm.canSave)
    }

    func test_canSave_valid() {
        let vm = CustomPlanBuilderViewModel()
        vm.name = "My Plan"
        vm.drillItems = [makeItem()]
        XCTAssertTrue(vm.canSave)
    }

    // MARK: - Drill management

    func test_removeDrills() {
        let vm = CustomPlanBuilderViewModel()
        vm.drillItems = [makeItem(), makeItem(), makeItem()]
        vm.removeDrills(at: IndexSet(integer: 1))
        XCTAssertEqual(vm.drillItems.count, 2)
    }

    func test_moveDrills() {
        let vm = CustomPlanBuilderViewModel()
        let item0 = makeItem(name: "First")
        let item1 = makeItem(name: "Second")
        vm.drillItems = [item0, item1]
        vm.moveDrills(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(vm.drillItems[0].nameZh, "Second")
        XCTAssertEqual(vm.drillItems[1].nameZh, "First")
    }

    // MARK: - Update rounds（v31 W2：只调轮数，球数内容派生）

    func test_updateRounds_clamped() {
        let vm = CustomPlanBuilderViewModel()
        let item = makeItem()
        vm.drillItems = [item]
        vm.updateRounds(for: item.id, rounds: 25)
        XCTAssertEqual(vm.drillItems[0].rounds, 20) // max 20
        XCTAssertEqual(vm.drillItems[0].id, item.id, "改轮数不应换掉行标识")

        vm.updateRounds(for: item.id, rounds: 0)
        XCTAssertEqual(vm.drillItems[0].rounds, 1) // min 1
    }

    /// 每轮球数由 drill 内容派生（v31 R4：计划不再存裸球数），且逐球形展开。
    func test_rounds_deriveBallsFromContent_perFormation() throws {
        let content = try XCTUnwrap(DrillContentService.decodeDrillFromBundle(id: "drill_c053"))
        let perFormation = try XCTUnwrap(content.sets.perFormation)

        let vm = CustomPlanBuilderViewModel()
        vm.addDrill(content)
        let item = try XCTUnwrap(vm.drillItems.first)

        vm.updateRounds(for: item.id, rounds: 2)
        let updated = vm.drillItems[0]
        XCTAssertEqual(updated.rounds, 2)
        XCTAssertEqual(updated.setCount, perFormation.count * 2)
        XCTAssertEqual(updated.plannedSets.map(\.targetBalls),
                       perFormation.flatMap { Array(repeating: $0.ballsPerRound, count: 2) })
        XCTAssertEqual(updated.totalBalls,
                       perFormation.reduce(0) { $0 + $1.ballsPerRound * 2 })
        XCTAssertEqual(vm.totalSetsCount, updated.setCount)
        XCTAssertEqual(vm.totalBallsCount, updated.totalBalls)
    }

    func test_updateRounds_unknown_id_no_crash() {
        let vm = CustomPlanBuilderViewModel()
        vm.drillItems = [makeItem()]
        vm.updateRounds(for: UUID(), rounds: 5) // should not crash
    }

    /// 保存落库的是轮数（`CustomPlanDrill.roundsPerFormation`，schema V3）。
    func test_save_persistsRoundsPerFormation() throws {
        let vm = CustomPlanBuilderViewModel()
        vm.name = "轮数计划"
        vm.drillItems = [makeItem(rounds: 4)]

        XCTAssertNotNil(vm.save(context: context))
        let plan = try XCTUnwrap(try context.fetch(FetchDescriptor<CustomPlan>()).first)
        XCTAssertEqual(plan.drills.first?.roundsPerFormation, 4)
    }

    // MARK: - Save

    func test_save_creates_customPlan() {
        let vm = CustomPlanBuilderViewModel()
        vm.name = "My Plan"
        vm.drillItems = [makeItem(name: "Drill A"), makeItem(name: "Drill B")]
        vm.sessionsPerWeek = 4

        let savedId = vm.save(context: context)
        XCTAssertNotNil(savedId)
        XCTAssertNil(vm.saveError)

        let plans = try? context.fetch(FetchDescriptor<CustomPlan>())
        XCTAssertEqual(plans?.count, 1)
        XCTAssertEqual(plans?.first?.name, "My Plan")
        XCTAssertEqual(plans?.first?.sessionsPerWeek, 4)
        XCTAssertEqual(plans?.first?.drills.count, 2)
    }

    func test_save_trims_name() {
        let vm = CustomPlanBuilderViewModel()
        vm.name = "  Trimmed  "
        vm.drillItems = [makeItem()]

        let savedId = vm.save(context: context)
        XCTAssertNotNil(savedId)

        let plans = try? context.fetch(FetchDescriptor<CustomPlan>())
        XCTAssertEqual(plans?.first?.name, "Trimmed")
    }

    func test_save_empty_name_fails() {
        let vm = CustomPlanBuilderViewModel()
        vm.name = "   "
        vm.drillItems = [makeItem()]

        let savedId = vm.save(context: context)
        XCTAssertNil(savedId)
        XCTAssertNotNil(vm.saveError)
    }

    func test_save_no_drills_fails() {
        let vm = CustomPlanBuilderViewModel()
        vm.name = "Plan"
        vm.drillItems = []

        let savedId = vm.save(context: context)
        XCTAssertNil(savedId)
        XCTAssertNotNil(vm.saveError)
    }

    func test_save_preserves_drill_order() {
        let vm = CustomPlanBuilderViewModel()
        vm.name = "Ordered"
        vm.drillItems = [makeItem(name: "A"), makeItem(name: "B"), makeItem(name: "C")]

        let savedId = vm.save(context: context)
        XCTAssertNotNil(savedId)

        let plans = try? context.fetch(FetchDescriptor<CustomPlan>())
        let sortedDrills = plans?.first?.drills.sorted { $0.order < $1.order }
        XCTAssertEqual(sortedDrills?.map(\.drillNameZh), ["A", "B", "C"])
    }

    // MARK: - Activate

    func test_activate_creates_userActivePlan() {
        let vm = CustomPlanBuilderViewModel()
        vm.name = "Plan"
        vm.drillItems = [makeItem()]

        guard let planId = vm.save(context: context) else {
            XCTFail("Save should succeed")
            return
        }

        vm.activate(planId: planId, context: context)

        let activePlans = try? context.fetch(FetchDescriptor<UserActivePlan>())
        XCTAssertEqual(activePlans?.count, 1)
        XCTAssertEqual(activePlans?.first?.planId, planId.uuidString)
        XCTAssertTrue(activePlans?.first?.isCustom ?? false)
    }

    func test_activate_replaces_existing() {
        let vm = CustomPlanBuilderViewModel()
        let existing = UserActivePlan(planId: "plan_beginner")
        context.insert(existing)
        try? context.save()

        vm.name = "New"
        vm.drillItems = [makeItem()]
        guard let planId = vm.save(context: context) else {
            XCTFail("Save should succeed")
            return
        }

        vm.activate(planId: planId, context: context)

        let activePlans = try? context.fetch(FetchDescriptor<UserActivePlan>())
        XCTAssertEqual(activePlans?.count, 1)
        XCTAssertTrue(activePlans?.first?.isCustom ?? false)
    }

    // MARK: - Edit existing plan

    func test_edit_existing_plan() {
        let plan = CustomPlan(name: "Original", sessionsPerWeek: 2)
        plan.drills = [
            CustomPlanDrill(drillId: "d1", drillNameZh: "动作1", roundsPerFormation: 3, order: 0)
        ]
        context.insert(plan)
        try? context.save()

        let vm = CustomPlanBuilderViewModel(editingPlanId: plan.id)
        XCTAssertTrue(vm.isEditing)

        vm.loadExistingPlan(context: context)
        XCTAssertEqual(vm.name, "Original")
        XCTAssertEqual(vm.sessionsPerWeek, 2)
        XCTAssertEqual(vm.drillItems.count, 1)
        XCTAssertEqual(vm.drillItems.first?.drillId, "d1")
    }

    func test_save_existing_plan_updates() {
        let plan = CustomPlan(name: "Original", sessionsPerWeek: 2)
        plan.drills = [
            CustomPlanDrill(drillId: "d1", drillNameZh: "动作1", roundsPerFormation: 3, order: 0)
        ]
        context.insert(plan)
        try? context.save()

        let vm = CustomPlanBuilderViewModel(editingPlanId: plan.id)
        vm.loadExistingPlan(context: context)
        vm.name = "Updated"
        vm.sessionsPerWeek = 5

        let savedId = vm.save(context: context)
        XCTAssertEqual(savedId, plan.id)

        let plans = try? context.fetch(FetchDescriptor<CustomPlan>())
        XCTAssertEqual(plans?.count, 1)
        XCTAssertEqual(plans?.first?.name, "Updated")
        XCTAssertEqual(plans?.first?.sessionsPerWeek, 5)
    }

    // MARK: - Helpers

    private func makeItem(name: String = "测试动作", rounds: Int = 3) -> CustomDrillItem {
        // content 为 nil ⇒ 走汇总兜底路径（`TrainingDoseResolver` 分支 3）。
        CustomPlanBuilderViewModel.makeItem(
            drillId: "drill_test_\(UUID().uuidString.prefix(8))",
            nameZh: name,
            content: nil,
            rounds: rounds
        )
    }
}
