import XCTest
import SwiftUI
@testable import QiuJi

/// W1 regression: off-screen share-card render contract (问题集合_v9 §四.5).
///
/// Long-image revision: height is no longer a constant. The contract is now
/// (a) width is exactly `cardWidth × scale`, (b) height grows with content, and
/// (c) the card's folding rules keep height under `maxCardHeight`.
@MainActor
final class ShareCardImageRendererTests: XCTestCase {

    private func session(
        drillCount: Int,
        setsPerDrill: Int,
        note: String = ""
    ) -> TrainingSessionSummary {
        let drills = (0..<drillCount).map { index in
            TrainingSessionSummary.DrillResult(
                name: "训练项目 \(index + 1)",
                setsCount: setsPerDrill,
                madeBalls: setsPerDrill * 7,
                targetBalls: setsPerDrill * 10,
                drillId: "drill_c\(String(format: "%03d", index + 1))",
                sets: (1...max(1, setsPerDrill)).map {
                    .init(id: $0, madeBalls: 7, targetBalls: 10)
                }
            )
        }
        return TrainingSessionSummary(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            planName: "力量训练 Day 1",
            durationMinutes: 48,
            completedDrills: drillCount,
            totalSets: drillCount * setsPerDrill,
            overallSuccessRate: 0.7,
            drills: drills,
            note: note
        )
    }

    private var sampleSession: TrainingSessionSummary {
        session(drillCount: 3, setsPerDrill: 4)
    }

    func test_render_producesNonNilImage_withExactWidthAndBoundedHeight() throws {
        let scale: CGFloat = 2
        let started = CFAbsoluteTimeGetCurrent()
        let image = try XCTUnwrap(
            ShareCardImageRenderer.render(
                session: sampleSession,
                theme: .defaultGreen,
                fontChoice: .system,
                hideSuccessRate: false,
                scale: scale
            ),
            "ShareCardImageRenderer must produce a non-nil UIImage"
        )
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - started) * 1000

        let pixelW = Int(image.size.width * image.scale)
        let pixelH = Int(image.size.height * image.scale)

        XCTAssertEqual(pixelW, Int(ShareCardImageRenderer.cardWidth * scale), "width must be cardWidth × scale")
        XCTAssertGreaterThan(pixelH, pixelW, "long image: height must exceed width for a normal session")
        XCTAssertLessThan(
            pixelH,
            Int(ShareCardImageRenderer.maxCardHeight * scale),
            "folding rules must keep height under maxCardHeight"
        )
        XCTAssertLessThan(elapsedMs, 5_000, "render should finish in reasonable time")
    }

    func test_render_at3xScale_keepsWidthContractAndBoundedHeight() throws {
        let scale: CGFloat = 3
        let image = try XCTUnwrap(
            ShareCardImageRenderer.render(
                session: sampleSession,
                theme: .nightBlue,
                fontChoice: .rounded,
                hideSuccessRate: true,
                scale: scale
            )
        )
        let pixelW = Int(image.size.width * image.scale)
        let pixelH = Int(image.size.height * image.scale)
        XCTAssertEqual(pixelW, Int(ShareCardImageRenderer.cardWidth * scale))
        XCTAssertLessThan(pixelH, Int(ShareCardImageRenderer.maxCardHeight * scale))
    }

    /// The whole point of the long image: more content ⇒ taller export.
    func test_height_growsWithDrillCount() throws {
        let small = try XCTUnwrap(renderHeight(session(drillCount: 1, setsPerDrill: 2)))
        let large = try XCTUnwrap(renderHeight(session(drillCount: 4, setsPerDrill: 2)))
        XCTAssertGreaterThan(large, small, "more drills must produce a taller image")
    }

    func test_height_growsWhenNoteIsPresent() throws {
        let without = try XCTUnwrap(renderHeight(session(drillCount: 2, setsPerDrill: 2)))
        let with = try XCTUnwrap(
            renderHeight(session(drillCount: 2, setsPerDrill: 2, note: "今天长台准度掉得厉害，后半段调整站位后稳定了一些。"))
        )
        XCTAssertGreaterThan(with, without, "note section must add height")
    }

    /// Worst case must still be bounded — this is what replaces the old magic 480pt.
    func test_height_staysBounded_forOversizedSession() throws {
        let huge = session(drillCount: 30, setsPerDrill: 20, note: String(repeating: "复盘要点。", count: 60))
        let height = try XCTUnwrap(renderHeight(huge))
        XCTAssertLessThan(
            height,
            ShareCardImageRenderer.maxCardHeight,
            "folding rules (maxDrillCards / setGridBudget) must cap the export height"
        )
    }

    func test_sizeConstants_matchPreviewContract() {
        XCTAssertEqual(ShareCardImageRenderer.cardWidth, 375)
        XCTAssertEqual(ShareCardImageRenderer.maxCardHeight, 3_000)
    }

    func test_paperTheme_isLightAndRenders() throws {
        XCTAssertTrue(ShareCardTheme.paper.isLight)
        XCTAssertFalse(ShareCardTheme.defaultGreen.isLight)
        XCTAssertEqual(ShareCardTheme.allCases.first, .paper, "浅色 must be the default / first swatch")

        let image = try XCTUnwrap(
            ShareCardImageRenderer.render(
                session: sampleSession,
                theme: .paper,
                fontChoice: .system,
                hideSuccessRate: false,
                scale: 2
            )
        )
        XCTAssertEqual(Int(image.size.width * image.scale), Int(ShareCardImageRenderer.cardWidth * 2))
    }

    /// Points, not pixels — comparisons are scale-independent.
    private func renderHeight(_ session: TrainingSessionSummary) -> CGFloat? {
        ShareCardImageRenderer.render(
            session: session,
            theme: .defaultGreen,
            fontChoice: .system,
            hideSuccessRate: false,
            scale: 1
        )?.size.height
    }
}

/// Derived share-card statistics. These feed user-visible numbers, so
/// "no target recorded" must stay distinguishable from "0% success".
final class TrainingSessionSummaryStatsTests: XCTestCase {

    private func summary(sets: [(made: Int, target: Int)]) -> TrainingSessionSummary {
        let results = sets.enumerated().map { index, value in
            TrainingSessionSummary.DrillResult.SetResult(
                id: index + 1, madeBalls: value.made, targetBalls: value.target
            )
        }
        let drill = TrainingSessionSummary.DrillResult(
            name: "测试项目",
            setsCount: results.count,
            madeBalls: sets.reduce(0) { $0 + $1.made },
            targetBalls: sets.reduce(0) { $0 + $1.target },
            drillId: "drill_c001",
            sets: results
        )
        return TrainingSessionSummary(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            planName: "测试",
            durationMinutes: 10,
            completedDrills: 1,
            totalSets: results.count,
            overallSuccessRate: 0,
            drills: [drill]
        )
    }

    func test_unscoredSets_areNotTreatedAsZeroPercent() {
        let s = summary(sets: [(0, 0), (0, 0), (0, 0)])
        XCTAssertFalse(s.hasScoredBalls, "no target balls at all ⇒ success rate is undefined, not 0%")
        XCTAssertTrue(s.scoredSetRates.isEmpty)
        XCTAssertNil(s.bestSet, "an unscored set must not be reported as the best set")
        XCTAssertNil(s.setRateStdDev)
    }

    func test_setGrid_isSuppressedWhenNothingWasRecorded() {
        let blank = try? XCTUnwrap(summary(sets: [(0, 0), (0, 0), (0, 0)]).drills.first)
        XCTAssertEqual(blank?.hasRecordedSetData, false, "all-zero sets carry no information")

        let partial = try? XCTUnwrap(summary(sets: [(0, 0), (3, 0)]).drills.first)
        XCTAssertEqual(partial?.hasRecordedSetData, true, "made balls without a target are still data")
    }

    func test_bestSet_picksHighestRate_notHighestMadeCount() {
        let s = summary(sets: [(9, 20), (5, 5), (7, 10)])
        XCTAssertEqual(s.bestSet?.madeBalls, 5)
        XCTAssertEqual(s.bestSet?.targetBalls, 5)
    }

    func test_stdDev_isZeroForIdenticalSets_andNilForSingleSet() {
        XCTAssertNil(summary(sets: [(7, 10)]).setRateStdDev, "one scored set has no spread")
        let flat = try? XCTUnwrap(summary(sets: [(7, 10), (7, 10), (7, 10)]).setRateStdDev)
        XCTAssertEqual(flat ?? -1, 0, accuracy: 1e-9)
    }

    func test_stdDev_matchesPopulationFormula() throws {
        // rates 0.2 / 0.8 → mean 0.5, population σ = 0.3
        let spread = try XCTUnwrap(summary(sets: [(2, 10), (8, 10)]).setRateStdDev)
        XCTAssertEqual(spread, 0.3, accuracy: 1e-9)
    }
}
