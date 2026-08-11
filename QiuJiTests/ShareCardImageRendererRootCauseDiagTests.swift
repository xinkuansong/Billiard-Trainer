import XCTest
import SwiftUI
@testable import QiuJi

/// W1 / B1 root-cause probe (问题集合_v9): compare ImageRenderer with width-only
/// vs width+height bounds.
///
/// Historical context: the width-only path used to run away (or stall) because
/// `BTShareCard` had a greedy `Spacer(minLength: 0)` at its root. That Spacer is
/// gone in the long-image revision, so width-only is now the **production** path
/// and `test_diag_unboundedHeight_widthOnly_behavior` has been turned from a
/// "document the damage" probe into a guard that the Spacer never comes back.
///
/// Evidence is written to build/w1-evidence/root-cause-diag.json when possible.
@MainActor
final class ShareCardImageRendererRootCauseDiagTests: XCTestCase {

    private let cardWidth: CGFloat = 361
    private let previewHeight: CGFloat = 480
    private let scale: CGFloat = 2

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

    private func shareCard() -> some View {
        BTShareCard(
            session: sampleSession,
            theme: .defaultGreen,
            fontChoice: .system,
            hideSuccessRate: false
        )
    }

    /// Bounded path (matches Preview `.frame(height: 480)`).
    func test_diag_boundedHeight_completesWithReasonablePixels() throws {
        let started = CFAbsoluteTimeGetCurrent()
        let renderer = ImageRenderer(
            content: shareCard().frame(width: cardWidth, height: previewHeight)
        )
        renderer.scale = scale
        let image = try XCTUnwrap(renderer.uiImage, "bounded ImageRenderer returned nil")
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - started) * 1000

        let pixelW = Int(image.size.width * image.scale)
        let pixelH = Int(image.size.height * image.scale)

        XCTAssertEqual(pixelW, Int(cardWidth * scale))
        XCTAssertEqual(pixelH, Int(previewHeight * scale))
        XCTAssertLessThan(elapsedMs, 5_000, "bounded render should finish quickly")

        writeEvidence(
            caseName: "bounded",
            completed: true,
            elapsedMs: elapsedMs,
            pixelWidth: pixelW,
            pixelHeight: pixelH,
            note: "Preview-aligned frame(width:361, height:480) @ scale 2"
        )
    }

    /// Width-only render (current production path): must stay bounded and fast.
    /// A regression here means a greedy `Spacer` / `maxHeight: .infinity` was
    /// reintroduced into `BTShareCard`.
    func test_diag_unboundedHeight_widthOnly_behavior() throws {
        let started = CFAbsoluteTimeGetCurrent()
        let renderer = ImageRenderer(
            content: shareCard().frame(width: cardWidth)
        )
        renderer.scale = scale
        let image = renderer.uiImage
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - started) * 1000

        let unwrapped = try XCTUnwrap(image, "width-only ImageRenderer must produce an image")

        let pixelW = Int(unwrapped.size.width * unwrapped.scale)
        let pixelH = Int(unwrapped.size.height * unwrapped.scale)
        writeEvidence(
            caseName: "unbounded_width_only",
            completed: true,
            elapsedMs: elapsedMs,
            pixelWidth: pixelW,
            pixelHeight: pixelH,
            note: "Production path frame(width:) only; BTShareCard must contain no greedy Spacer"
        )

        XCTAssertEqual(pixelW, Int(cardWidth * scale))
        XCTAssertLessThan(
            pixelH,
            Int(ShareCardImageRenderer.maxCardHeight * scale),
            "width-only render must stay bounded — a greedy Spacer would blow this up"
        )
        XCTAssertLessThan(elapsedMs, 5_000, "width-only render must not stall the main actor")
    }

    private func writeEvidence(
        caseName: String,
        completed: Bool,
        elapsedMs: Double,
        pixelWidth: Int?,
        pixelHeight: Int?,
        note: String
    ) {
        let dir = URL(fileURLWithPath: "/Users/song/projects/13.billiard_trainer/build/w1-evidence")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("root-cause-\(caseName).json")
        var payload: [String: Any] = [
            "case": caseName,
            "completed": completed,
            "elapsedMs": elapsedMs,
            "note": note,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]
        if let pixelWidth { payload["pixelWidth"] = pixelWidth }
        if let pixelHeight { payload["pixelHeight"] = pixelHeight }
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
        }
    }
}
