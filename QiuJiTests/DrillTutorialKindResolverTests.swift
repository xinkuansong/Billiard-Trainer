import XCTest
import SwiftUI
@testable import QiuJi

@MainActor
final class DrillTutorialKindResolverTests: XCTestCase {

    func test_multiShotDrill_readsExplicitField() async throws {
        let drill = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c001")
        let kind = DrillTutorialKindResolver.resolve(for: try XCTUnwrap(drill))
        XCTAssertEqual(kind, .multiShot)
    }

    func test_singleShotDrill_readsExplicitField() async throws {
        let drill = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c006")
        let kind = DrillTutorialKindResolver.resolve(for: try XCTUnwrap(drill))
        XCTAssertEqual(kind, .singleShot)
    }

    func test_rulesetDrill_readsExplicitField() async throws {
        let drill = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c065")
        let kind = DrillTutorialKindResolver.resolve(for: try XCTUnwrap(drill))
        XCTAssertEqual(kind, .ruleset)
    }

    func test_bundleCounts_tutorialKindPartition() async {
        let drills = await DrillContentService.shared.loadFallbackDrills()
        XCTAssertFalse(drills.isEmpty)

        var singleShot = 0
        var multiShot = 0
        var ruleset = 0
        var missing = 0
        for drill in drills {
            switch DrillTutorialKindResolver.resolve(for: drill) {
            case .singleShot: singleShot += 1
            case .multiShot: multiShot += 1
            case .ruleset: ruleset += 1
            case .none: missing += 1
            }
        }
        // v26 W0 inventory: 6 singleShot / 66 multiShot / 5 ruleset / 0 missing.
        XCTAssertEqual(singleShot + multiShot + ruleset + missing, drills.count)
        XCTAssertEqual(missing, 0, "All bundled drills must ship tutorial.tutorialKind")
        XCTAssertEqual(singleShot, 6)
        XCTAssertEqual(multiShot, 66)
        XCTAssertEqual(ruleset, 5)
    }

    func test_levelFilter_matchesTrainingTabMapping() {
        XCTAssertTrue(DrillLevelFilter.beginner.matches("L0"))
        XCTAssertFalse(DrillLevelFilter.beginner.matches("L1"))
        XCTAssertTrue(DrillLevelFilter.elementary.matches("L1"))
        XCTAssertTrue(DrillLevelFilter.intermediate.matches("L2"))
        XCTAssertTrue(DrillLevelFilter.advanced.matches("L3"))
        XCTAssertTrue(DrillLevelFilter.advanced.matches("L4"))
        XCTAssertFalse(DrillLevelFilter.advanced.matches("L2"))
    }

    func test_rulesetTitles_haveDedicatedIconAndColor() {
        for title in DrillTutorialSectionChrome.rulesetTitles {
            let icon = DrillTutorialSectionChrome.icons[title]
            XCTAssertNotNil(icon, "\(title) missing icon")
            XCTAssertNotEqual(icon, DrillTutorialSectionChrome.fallbackIcon,
                              "\(title) must not use fallback icon")
            XCTAssertNotNil(DrillTutorialSectionChrome.colors[title],
                            "\(title) missing color")
        }
    }

    /// Constructive render proof: ruleset section headers with dedicated chrome.
    /// Writes PNG under build/v26-w0-screenshots/ (library has no ruleset body yet).
    func test_rulesetSectionChrome_renderSnapshot() throws {
        let view = RulesetSectionChromeProbeView()
            .frame(width: 390, height: 420)
            .padding()
            .background(Color(.systemBackground))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.uiImage else {
            XCTFail("ImageRenderer failed to produce UIImage")
            return
        }

        let outDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/v26-w0-screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let outURL = outDir.appendingPathComponent("ruleset-section-chrome.png")
        guard let data = image.pngData() else {
            XCTFail("pngData() failed")
            return
        }
        try data.write(to: outURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outURL.path))
        XCTAssertGreaterThan(data.count, 10_000, "snapshot should be a non-trivial PNG")
    }
}

/// Minimal probe: four ruleset titles with the production chrome maps.
private struct RulesetSectionChromeProbeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("规则流程课 · section chrome")
                .font(.headline)
            ForEach(DrillTutorialSectionChrome.rulesetTitles, id: \.self) { title in
                HStack(spacing: 12) {
                    Image(systemName: DrillTutorialSectionChrome.icons[title]
                          ?? DrillTutorialSectionChrome.fallbackIcon)
                        .font(.title3)
                        .foregroundStyle(DrillTutorialSectionChrome.colors[title] ?? .primary)
                        .frame(width: 28)
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DrillTutorialSectionChrome.colors[title] ?? .primary)
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
