import XCTest
@testable import QiuJi

/// v7 W1/C2：历史筛选项含瞄准点三档，文案对齐 HistoryViewModel.AngleQuizType。
final class AngleQuizTypeFilterTests: XCTestCase {

    func testAimPointFilters_presentAndAligned() {
        let cases: [(AngleQuizTypeFilter, String, String)] = [
            (.aimPoint, "aimPoint", AngleQuizType.aimPoint.displayNameZh),
            (.aimPoint2D, "aimPoint2D", AngleQuizType.aimPoint2D.displayNameZh),
            (.aimPoint3D, "aimPoint3D", AngleQuizType.aimPoint3D.displayNameZh),
        ]
        for (filter, query, display) in cases {
            XCTAssertTrue(AngleQuizTypeFilter.allCases.contains(filter))
            XCTAssertEqual(filter.queryValue, query)
            XCTAssertEqual(filter.rawValue, display)
        }
    }
}
