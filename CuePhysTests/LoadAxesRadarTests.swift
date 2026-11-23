import XCTest
@testable import QiuJi

final class LoadAxesRadarTests: XCTestCase {

    private let sample = LoadAxes(aim: 0, cue: 1, spin: 2, position: 3, constraint: 4, speed: 0)

    func test_displayScore_addsOne_andStaysInOneToFive() {
        XCTAssertEqual(sample.displayScore(for: .aim), 1)
        XCTAssertEqual(sample.displayScore(for: .cue), 2)
        XCTAssertEqual(sample.displayScore(for: .spin), 3)
        XCTAssertEqual(sample.displayScore(for: .position), 4)
        XCTAssertEqual(sample.displayScore(for: .constraint), 5)
        XCTAssertEqual(sample.displayScore(for: .speed), 1)
        XCTAssertEqual(LoadAxes.displayMax, 5)
        XCTAssertEqual(LoadAxes.displayOffset, 1)
    }

    func test_radarFraction_usesDisplayOverFive() {
        XCTAssertEqual(sample.radarFraction(for: .aim), 0.2, accuracy: 1e-12)
        XCTAssertEqual(sample.radarFraction(for: .constraint), 1.0, accuracy: 1e-12)
        XCTAssertEqual(sample.radarFractions.count, 6)
    }

    func test_vertexZero_isAboveCenter() {
        let center = CGPoint(x: 100, y: 100)
        let top = LoadRadarGeometry.vertex(index: 0, center: center, radius: 50)
        XCTAssertEqual(top.x, 100, accuracy: 1e-9)
        XCTAssertEqual(top.y, 50, accuracy: 1e-9)
    }

    func test_distinctLoads_produceDistinctPolygons() {
        let low = LoadAxes(aim: 1, cue: 1, spin: 0, position: 0, constraint: 0, speed: 0)
        let high = LoadAxes(aim: 3, cue: 3, spin: 0, position: 0, constraint: 0, speed: 2)
        let center = CGPoint(x: 0, y: 0)
        let lowPoly = LoadRadarGeometry.polygon(fractions: low.radarFractions, center: center, radius: 100)
        let highPoly = LoadRadarGeometry.polygon(fractions: high.radarFractions, center: center, radius: 100)
        XCTAssertNotEqual(lowPoly.map(\.x), highPoly.map(\.x))
        XCTAssertGreaterThan(highPoly[0].y.magnitude, lowPoly[0].y.magnitude)
    }

    func test_sectionCopy_isAudienceFacing() {
        XCTAssertEqual(LoadRadarCopy.sectionTitle, "难度画像")
        XCTAssertFalse(LoadRadarCopy.sectionTitle.contains("负荷"))
    }

    func test_nilLoadFallback_doesNotRequireScores() {
        XCTAssertNil(Optional<LoadAxes>.none)
        XCTAssertEqual(LoadAxes.Axis.allCases.map(\.title), ["进球", "杆法", "加塞", "走位", "约束", "力度"])
    }
}
