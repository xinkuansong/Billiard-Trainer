import XCTest
import SwiftUI
@testable import QiuJi

/// W1 regression: off-screen share-card render contract (问题集合_v9 §四.5).
@MainActor
final class ShareCardImageRendererTests: XCTestCase {

    private var sampleSession: TrainingSessionSummary {
        TrainingSessionSummary(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            planName: "力量训练 Day 1",
            durationMinutes: 48,
            completedDrills: 3,
            totalSets: 12,
            overallSuccessRate: 0.72,
            drills: [
                .init(name: "定点红球进袋", setsCount: 4, madeBalls: 31, targetBalls: 40),
                .init(name: "斯诺克直线进袋", setsCount: 3, madeBalls: 28, targetBalls: 30),
                .init(name: "走位练习 A", setsCount: 5, madeBalls: 28, targetBalls: 50),
            ]
        )
    }

    func test_render_producesNonNilImage_withBoundedPixelSize() throws {
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
        let expectedW = Int(ShareCardImageRenderer.cardWidth * scale)
        let expectedH = Int(ShareCardImageRenderer.cardHeight * scale)

        XCTAssertEqual(pixelW, expectedW, "width must be cardWidth × scale")
        XCTAssertEqual(pixelH, expectedH, "height must be cardHeight × scale (Preview-aligned)")
        XCTAssertLessThan(
            pixelH,
            ShareCardImageRenderer.maxReasonablePixelHeight,
            "height must stay far below runaway Spacer magnitude"
        )
        XCTAssertLessThan(elapsedMs, 5_000, "bounded render should finish in reasonable time")
    }

    func test_render_at3xScale_staysWithinReasonableBounds() throws {
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
        XCTAssertEqual(pixelH, Int(ShareCardImageRenderer.cardHeight * scale))
        XCTAssertLessThan(pixelH, ShareCardImageRenderer.maxReasonablePixelHeight)
    }

    func test_sizeConstants_matchPreviewContract() {
        XCTAssertEqual(ShareCardImageRenderer.cardWidth, 361)
        XCTAssertEqual(ShareCardImageRenderer.cardHeight, 480)
    }
}
