import XCTest
import SwiftUI
import UIKit
@testable import QiuJi

/// v46 W0：一卡一 `CoverArtKey`；Tab 母题仍是 6 张 `felt*`。
final class AtmosphereCatalogTests: XCTestCase {

    private let expectedPlanArt: [(String, CoverArtKey)] = [
        ("plan_beginner", .coverPlanBeginner),
        ("plan_accuracy", .coverPlanAccuracy),
        ("plan_intermediate", .coverPlanIntermediate),
        ("plan_accuracy3", .coverPlanAccuracy3),
        ("plan_cueball", .coverPlanCueball),
        ("plan_english", .coverPlanEnglish),
        ("plan_positioning", .coverPlanPositioning),
        ("plan_positioning2", .coverPlanPositioning2),
        ("plan_force", .coverPlanForce),
        ("plan_separation", .coverPlanSeparation),
        ("plan_advanced", .coverPlanAdvanced),
        ("plan_fullskill", .coverPlanFullskill),
    ]

    func testCoverArtKeyCountIsSixtyAndMotifsStaySix() {
        XCTAssertEqual(CoverArtKey.allCases.count, 60)
        XCTAssertEqual(AtmosphereKey.allCases.count, 6)
        XCTAssertEqual(AtmosphereCatalog.templatePool.count, 12)
        XCTAssertEqual(
            Set(AtmosphereCatalog.templatePool),
            Set(CoverArtKey.allCases.filter { $0.rawValue.hasPrefix("coverTemplate") })
        )
    }

    func testTwelveOfficialPlanIdsResolveToUniqueCoverArt() {
        XCTAssertEqual(AtmosphereCatalog.officialPlanIds.count, 12)
        XCTAssertEqual(Set(expectedPlanArt.map(\.0)), Set(AtmosphereCatalog.officialPlanIds))
        var seen = Set<CoverArtKey>()
        for (planId, expected) in expectedPlanArt {
            XCTAssertEqual(AtmosphereCatalog.coverArt(forPlanId: planId), expected)
            XCTAssertEqual(AtmosphereCatalog.image(forPlanId: planId), .art(expected))
            XCTAssertTrue(seen.insert(expected).inserted, "duplicate art for \(planId)")
        }
    }

    func testFiveTabsEachHaveAMotifKey() {
        let expected: [(AppTab, AtmosphereKey)] = [
            (.training, .feltEntry),
            (.drillLibrary, .feltRoute),
            (.angle, .feltCue),
            (.history, .feltForce),
            (.profile, .feltAim),
        ]
        XCTAssertEqual(AppTab.allCases.count, 5)
        for (tab, key) in expected {
            XCTAssertEqual(AtmosphereCatalog.key(for: tab), key, "tab \(tab.title)")
        }
    }

    func testUnknownPlanIdAndUnclassifiedRouteFallBackToFeltEntry() {
        XCTAssertNil(AtmosphereCatalog.coverArt(forPlanId: "plan_does_not_exist"))
        XCTAssertEqual(AtmosphereCatalog.image(forPlanId: "plan_does_not_exist"), .motif(.feltEntry))
        XCTAssertEqual(AtmosphereCatalog.image(forPlanId: ""), .motif(.feltEntry))
        XCTAssertEqual(AtmosphereCatalog.cover(for: .drillDetail("missing")).image, .motif(.feltEntry))
        XCTAssertNil(AtmosphereCatalog.coverArt(for: .theoryIndex))
        XCTAssertEqual(AtmosphereCatalog.cover(for: .theoryIndex).image, .motif(.feltEntry))
    }

    func testPracticeHomeRoutesHaveUniqueCoverArt() {
        let routes: [AngleRoute] = [
            .aimingPrinciple, .aimingMethods, .aimingCorrection, .spinAndEnglish,
            .angleDynamic, .separationAngleAtlas, .cushionEnglishAtlas, .ballFeel,
            .contactPointTable,
            .theoryPage(.t01), .theoryPage(.t02), .theoryPage(.t03), .theoryPage(.t04),
            .theoryPage(.t09), .theoryPage(.t05), .theoryPage(.t06), .theoryPage(.t07),
            .theoryPage(.t08), .theoryPage(.t10), .theoryPage(.flow), .theoryPage(.quickRef),
            .geometricQuiz, .sceneAiming2D, .sceneAiming3D,
            .aimPointTraining, .aimPointScene2D, .aimPointScene3D,
            .shotSimulation, .positionPlayComposer, .freePlay, .ballExtraction,
            .positionPlaySolver, .planThree, .snookerTactics, .bankShot, .diamondSystem,
        ]
        XCTAssertEqual(routes.count, 36)
        var seen = Set<CoverArtKey>()
        for route in routes {
            guard let art = AtmosphereCatalog.coverArt(for: route) else {
                XCTFail("route \(route) must have cover art")
                continue
            }
            XCTAssertTrue(seen.insert(art).inserted, "duplicate art \(art.rawValue)")
        }
        XCTAssertEqual(seen.count, 36)
    }

    func testRepresentativeAngleRoutesHaveArtAndTheoryPalette() {
        let aiming = AtmosphereCatalog.cover(for: .aimingPrinciple)
        XCTAssertEqual(aiming.image, .art(.coverPracticeAimingPrinciple))
        XCTAssertEqual(
            colorKey(aiming.pair.top),
            colorKey(CoverPalette.PracticeMulticolor.aimingPrinciple.top)
        )

        let t01 = AtmosphereCatalog.cover(for: .theoryPage(.t01))
        XCTAssertEqual(t01.image, .art(.coverPracticeT01))
        XCTAssertEqual(TheoryCatalog.entry(for: .t01)?.group, .collision)
        XCTAssertEqual(
            colorKey(t01.pair.top),
            colorKey(CoverPalette.PracticeMulticolor.theoryIndex.top)
        )
    }

    func testHeroAndCardShareTheSameCoverLookup() {
        let routes: [AngleRoute] = [.aimingPrinciple, .theoryIndex, .theoryPage(.t01)]
        for route in routes {
            let cover = AtmosphereCatalog.cover(for: route)
            XCTAssertEqual(cover.image, AtmosphereCatalog.image(for: route))
            XCTAssertEqual(
                colorKey(cover.pair.top),
                colorKey(AtmosphereCatalog.pair(for: route).top)
            )
        }
    }

    func testTheoryPagePairsFollowTheoryGroupMicroDiffs() {
        let samples: [(TheoryPageID, TheoryGroup, CoverPalette.Pair)] = [
            (.t01, .collision, CoverPalette.PracticeMulticolor.theoryIndex),
            (.t04, .spin, CoverPalette.PracticeMulticolor.aimingMethods),
            (.t05, .tactics, CoverPalette.PracticeMulticolor.aimingCorrection),
            (.flow, .flow, CoverPalette.PracticeMulticolor.cushionEnglishAtlas),
        ]
        for (pageID, group, pair) in samples {
            XCTAssertEqual(TheoryCatalog.entry(for: pageID)?.group, group)
            XCTAssertEqual(
                colorKey(AtmosphereCatalog.pair(forTheoryPage: pageID).top),
                colorKey(pair.top)
            )
        }
    }

    func testCustomPlanHashStaysOnTemplatePool() {
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        XCTAssertEqual(CustomPlanAtmosphere.art(for: a), CustomPlanAtmosphere.art(for: b))
        XCTAssertTrue(AtmosphereCatalog.templatePool.contains(CustomPlanAtmosphere.art(for: a)))
    }

    func testAtmosphereMotifImagesDecodeAndAreLargerThanPlaceholders() {
        let minPixelArea = 800 * 600
        for key in AtmosphereKey.allCases {
            let image = UIImage(named: key.imageName)
            XCTAssertNotNil(image, "\(key.rawValue) must decode from the asset catalog")
            guard let image else { continue }
            let pixelWidth = Int(image.size.width * image.scale)
            let pixelHeight = Int(image.size.height * image.scale)
            let area = pixelWidth * pixelHeight
            XCTAssertGreaterThan(
                area,
                minPixelArea,
                "\(key.rawValue) pixel area \(pixelWidth)×\(pixelHeight)=\(area) must exceed ~800×600"
            )
        }
    }

    private func colorKey(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%.3f-%.3f-%.3f", r, g, b)
    }
}
