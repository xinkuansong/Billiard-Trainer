import XCTest
@testable import QiuJi

/// v28 W1：route → PracticeCoverVisual 全覆盖，禁止 generic fallback。
final class PracticeCoverCatalogTests: XCTestCase {

    func testOfficialRoutesCountIs24PublishableEntries() {
        XCTAssertEqual(PracticeCoverCatalog.officialRoutes.count, 24)
    }

    func testEveryOfficialRouteHasExplicitVisualWithoutFallback() {
        for route in PracticeCoverCatalog.officialRoutes {
            let visual = PracticeCoverCatalog.visual(for: route)
            let layout = visual.layout
            XCTAssertFalse(layout.balls.isEmpty, "\(route) cover must place at least one ball")
            XCTAssertFalse(layout.tintTopKey.isEmpty)
            // palette(for:) preconditions on unknown keys — exercising it is the fallback guard.
            _ = PracticeCoverCatalog.palette(for: layout.tintTopKey)
        }
    }

    func testLearnRoutesUseGeometricKind() {
        let learn: [AngleRoute] = [
            .aimingPrinciple, .aimingMethods, .aimingCorrection, .spinAndEnglish,
            .angleDynamic, .separationAngleAtlas, .cushionEnglishAtlas, .ballFeel, .contactPointTable,
        ]
        for route in learn {
            XCTAssertTrue(
                PracticeCoverCatalog.visual(for: route).isGeometric,
                "\(route) must be geometric (学区)"
            )
        }
    }

    func testTrainPlaySolveUseTablePreview() {
        let routes: [AngleRoute] = [
            .geometricQuiz, .sceneAiming2D, .sceneAiming3D, .aimPointTraining,
            .aimPointScene2D, .aimPointScene3D,
            .shotSimulation, .positionPlayComposer, .freePlay, .ballExtraction,
            .positionPlaySolver, .planThree, .snookerTactics, .bankShot, .diamondSystem,
        ]
        for route in routes {
            XCTAssertFalse(
                PracticeCoverCatalog.visual(for: route).isGeometric,
                "\(route) must be tablePreview"
            )
        }
    }

    func testSimulatorBatchStudioHasDedicatedVisual() {
        let visual = PracticeCoverCatalog.visual(for: .batchDrillStudio)
        XCTAssertFalse(visual.isGeometric)
        XCTAssertEqual(visual.layout.tintTopKey, "batchDrillStudio")
    }

    func testOfficialLayoutsAreVisuallyDistinctByBallFingerprint() {
        var seen = Set<String>()
        for route in PracticeCoverCatalog.officialRoutes {
            let key = fingerprint(PracticeCoverCatalog.visual(for: route).layout)
            XCTAssertFalse(seen.contains(key), "duplicate cover layout for \(route): \(key)")
            seen.insert(key)
        }
        XCTAssertEqual(seen.count, PracticeCoverCatalog.officialRoutes.count)
    }

    private func fingerprint(_ layout: PracticeCoverLayout) -> String {
        let balls = layout.balls
            .map { "\($0.number.map(String.init) ?? "cue"):\($0.x),\($0.z)" }
            .joined(separator: "|")
        let segs = layout.segments
            .map { "\($0.style.rawValue):\($0.x0),\($0.z0)->\($0.x1),\($0.z1)" }
            .joined(separator: ";")
        return "\(layout.tintTopKey)#\(balls)#\(segs)#geo=\(layout.closeup != nil)"
    }
}
