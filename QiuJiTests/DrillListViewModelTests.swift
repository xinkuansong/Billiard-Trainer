import XCTest
import Combine
@testable import QiuJi

@MainActor
final class DrillListViewModelTests: XCTestCase {

    var viewModel: DrillListViewModel!

    override func setUp() {
        super.setUp()
        viewModel = DrillListViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_isLoading() {
        XCTAssertTrue(viewModel.isLoading)
        XCTAssertTrue(viewModel.drillsByCategory.isEmpty)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.ballTypeFilter, .all)
    }

    // MARK: - Load Drills

    func test_loadDrills_populatesCategories() async {
        await viewModel.loadDrills()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.drillsByCategory.isEmpty)
    }

    func test_reloadDoesNotFlipIsLoadingWhenDrillsAlreadyPresent() async {
        await viewModel.loadDrills()
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.drillsByCategory.isEmpty)

        var sawLoadingTrue = false
        let sub = viewModel.$isLoading.sink { if $0 { sawLoadingTrue = true } }
        await viewModel.loadDrills()
        XCTAssertFalse(sawLoadingTrue, "二次 loadDrills 不得再出骨架（会拆掉网格、滚回顶）")
        XCTAssertFalse(viewModel.isLoading)
        _ = sub
    }

    func test_loadDrills_has8Categories() async {
        await viewModel.loadDrills()
        XCTAssertEqual(viewModel.drillsByCategory.count, 8,
                       "All 8 categories should be present with 'all' filter")
    }

    func test_loadDrills_totalDrillCount() async {
        await viewModel.loadDrills()
        let total = viewModel.drillsByCategory.reduce(0) { $0 + $1.drills.count }
        XCTAssertEqual(total, 74, "Total drills across all categories should match index.json (74)")
    }

    // MARK: - Search Filtering

    func test_searchFilter_narrowsResults() async {
        await viewModel.loadDrills()

        viewModel.searchText = "直线"
        viewModel.applyFiltersSync()

        let total = viewModel.drillsByCategory.reduce(0) { $0 + $1.drills.count }
        XCTAssertGreaterThan(total, 0, "Searching '直线' should find at least one drill")
        XCTAssertLessThan(total, 74, "Search should narrow down from 74")
    }

    func test_searchFilter_noResults() async {
        await viewModel.loadDrills()

        viewModel.searchText = "zzzzz_nonexistent"
        viewModel.applyFiltersSync()

        XCTAssertTrue(viewModel.drillsByCategory.isEmpty,
                      "Nonsense search should return no results")
    }

    func test_searchFilter_clearRestoresAll() async {
        await viewModel.loadDrills()

        viewModel.searchText = "直线"
        viewModel.applyFiltersSync()
        let narrowed = viewModel.drillsByCategory.reduce(0) { $0 + $1.drills.count }

        viewModel.searchText = ""
        viewModel.applyFiltersSync()
        let restored = viewModel.drillsByCategory.reduce(0) { $0 + $1.drills.count }

        XCTAssertEqual(restored, 74)
        XCTAssertGreaterThan(restored, narrowed)
    }

    func test_searchFilter_caseInsensitive() async {
        await viewModel.loadDrills()

        viewModel.searchText = "grip"
        viewModel.applyFiltersSync()
        let lowerResults = viewModel.drillsByCategory.reduce(0) { $0 + $1.drills.count }

        viewModel.searchText = "Grip"
        viewModel.applyFiltersSync()
        let upperResults = viewModel.drillsByCategory.reduce(0) { $0 + $1.drills.count }

        XCTAssertEqual(lowerResults, upperResults,
                       "Search should be case insensitive")
    }

    // MARK: - Ball Type Filtering

    func test_ballTypeFilter_chinese8() async {
        await viewModel.loadDrills()

        viewModel.ballTypeFilter = .chinese8
        viewModel.applyFiltersSync()

        let total = viewModel.drillsByCategory.reduce(0) { $0 + $1.drills.count }
        XCTAssertGreaterThan(total, 0, "Chinese8 filter should find drills")
        XCTAssertLessThanOrEqual(total, 74)
    }

    func test_ballTypeFilter_nineBall() async {
        await viewModel.loadDrills()

        viewModel.ballTypeFilter = .nineBall
        viewModel.applyFiltersSync()

        let total = viewModel.drillsByCategory.reduce(0) { $0 + $1.drills.count }
        XCTAssertGreaterThan(total, 0, "9ball filter should find drills")
    }

    func test_ballTypeFilter_all_showsEverything() async {
        await viewModel.loadDrills()

        viewModel.ballTypeFilter = .all
        viewModel.applyFiltersSync()

        let total = viewModel.drillsByCategory.reduce(0) { $0 + $1.drills.count }
        XCTAssertEqual(total, 74)
    }

    // MARK: - Level / Badge Filtering (W7 E18–E19)

    func test_levelFilter_beginner_onlyL0() async {
        await viewModel.loadDrills()
        viewModel.levelFilter = .beginner
        viewModel.applyFiltersSync()
        let drills = viewModel.drillsByCategory.flatMap(\.drills)
        XCTAssertFalse(drills.isEmpty)
        XCTAssertTrue(drills.allSatisfy { $0.level == "L0" })
    }

    func test_badgeFilter_multiShotTutorial() async {
        await viewModel.loadDrills()
        viewModel.badgeFilter = .multiShotTutorial
        viewModel.applyFiltersSync()
        let drills = viewModel.drillsByCategory.flatMap(\.drills)
        XCTAssertFalse(drills.isEmpty)
        XCTAssertTrue(drills.allSatisfy {
            DrillTutorialKindResolver.resolve(for: $0) == .multiShot
        })
    }

    func test_badgeFilter_singleShotTutorial() async {
        await viewModel.loadDrills()
        viewModel.badgeFilter = .singleShotTutorial
        viewModel.applyFiltersSync()
        let drills = viewModel.drillsByCategory.flatMap(\.drills)
        // 2026-08-26 暂时下架全部 singleShot 课后，该角标筛为空是现网事实。
        XCTAssertTrue(drills.isEmpty)
        XCTAssertTrue(drills.allSatisfy {
            DrillTutorialKindResolver.resolve(for: $0) == .singleShot
        })
    }

    func test_badgeFilter_rulesetTutorial() async {
        await viewModel.loadDrills()
        viewModel.badgeFilter = .rulesetTutorial
        viewModel.applyFiltersSync()
        let drills = viewModel.drillsByCategory.flatMap(\.drills)
        XCTAssertFalse(drills.isEmpty)
        XCTAssertTrue(drills.allSatisfy {
            DrillTutorialKindResolver.resolve(for: $0) == .ruleset
        })
    }

    func test_combinedFilters_emptyStatePath() async {
        await viewModel.loadDrills()
        viewModel.ballTypeFilter = .nineBall
        viewModel.levelFilter = .beginner
        viewModel.badgeFilter = .multiShotTutorial
        viewModel.searchText = "zzzzz_nonexistent"
        viewModel.applyFiltersSync()
        XCTAssertTrue(viewModel.drillsByCategory.isEmpty)
    }

    func test_ballTypeFilter_combinedWithSearch() async {
        await viewModel.loadDrills()

        viewModel.ballTypeFilter = .chinese8
        viewModel.searchText = "直线"
        viewModel.applyFiltersSync()

        let total = viewModel.drillsByCategory.reduce(0) { $0 + $1.drills.count }
        XCTAssertGreaterThanOrEqual(total, 0)
    }

    // MARK: - v31 W2: 副分类（契约 §3.3）

    /// 按分类筛选命中「主 ∪ 副」；分组仍只按主分类（统计口径不变）。
    func test_categoryFilter_matchesSecondaryCategory_butGroupsByPrimary() async {
        await viewModel.loadDrills()
        let all = viewModel.drillsByCategory.flatMap(\.drills)
        let crossListed = all.filter {
            $0.category != DrillCategory.positioning.rawValue
                && ($0.secondaryCategories?.contains(DrillCategory.positioning.rawValue) ?? false)
        }
        XCTAssertFalse(crossListed.isEmpty, "库内应存在副分类为 positioning 的跨类 drill")

        viewModel.categoryFilter = .positioning
        viewModel.applyFiltersSync()

        let hitIds = Set(viewModel.drillsByCategory.flatMap(\.drills).map(\.id))
        for drill in crossListed {
            XCTAssertTrue(hitIds.contains(drill.id),
                          "\(drill.id) 副分类 positioning，筛选应命中")
        }

        // 分组归属仍是主分类
        for (category, drills) in viewModel.drillsByCategory {
            XCTAssertTrue(drills.allSatisfy { $0.category == category.rawValue },
                          "\(category.rawValue) 分节里出现了非本主分类的 drill")
        }
        let sections = Set(viewModel.drillsByCategory.map(\.category.rawValue))
        XCTAssertGreaterThan(sections.count, 1,
                             "副分类命中后应出现多个主分类分节，实际：\(sections)")
    }

    func test_categoryFilter_excludesUnrelatedCategories() async {
        await viewModel.loadDrills()
        viewModel.categoryFilter = .positioning
        viewModel.applyFiltersSync()

        let drills = viewModel.drillsByCategory.flatMap(\.drills)
        XCTAssertFalse(drills.isEmpty)
        XCTAssertTrue(drills.allSatisfy {
            $0.category == DrillCategory.positioning.rawValue
                || ($0.secondaryCategories?.contains(DrillCategory.positioning.rawValue) ?? false)
        })
    }

    // MARK: - Category Ordering

    func test_categoryOrder_followsDrillCategoryAllCases() async {
        await viewModel.loadDrills()

        let resultOrder = viewModel.drillsByCategory.map(\.category)
        let expectedOrder = DrillCategory.allCases

        for (i, cat) in resultOrder.enumerated() {
            let expectedIndex = expectedOrder.firstIndex(of: cat)!
            if i > 0 {
                let prevExpectedIndex = expectedOrder.firstIndex(of: resultOrder[i - 1])!
                XCTAssertGreaterThan(expectedIndex, prevExpectedIndex,
                                     "Categories should follow DrillCategory.allCases order")
            }
        }
    }
}
