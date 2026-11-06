import XCTest
@testable import QiuJi

/// v7 W1/C2：历史筛选项含瞄准点三档，文案对齐 HistoryViewModel.AngleQuizType。
final class AngleQuizTypeFilterTests: XCTestCase {

    func testFiltersUseCurrentPageNamesAndKeepDistinctQueryKeys() {
        let cases: [(AngleQuizTypeFilter, String?, String)] = [
            (.all, nil, "全部"),
            (.geometric, "geometric", "角度预测"),
            (.table2D, "table2D", "球台角度练习"),
            (.scene2D, "scene2D", "角度练习 · 2D"),
            (.scene3D, "scene3D", "角度练习 · 3D"),
            (.aimPoint, "aimPoint", "假想球练习"),
            (.aimPoint2D, "aimPoint2D", "瞄准点练习 · 2D"),
            (.aimPoint3D, "aimPoint3D", "瞄准点练习 · 3D")
        ]
        XCTAssertEqual(cases.count, AngleQuizTypeFilter.allCases.count)
        for (filter, query, display) in cases {
            XCTAssertEqual(filter.queryValue, query)
            XCTAssertEqual(filter.title, display)
        }
    }

    func testHistoryTitleKeepsLegacyViewAndMixedSessions() {
        XCTAssertEqual(TrainingProject.accuracy.historyTitle(presentation: nil, is3D: true), "准度练习 · 3D")
        var mixed = TrainingPresentation(is3D: false)
        let question = UUID()
        mixed.observe(.twoD, questionID: question)
        mixed.observe(.threeD, questionID: question)
        XCTAssertEqual(TrainingProject.separation.historyTitle(presentation: mixed, is3D: false), "分离角练习 · 混合视图")
    }
}
