import XCTest
@testable import QiuJi

@MainActor
final class DrillStaticPreviewTests: XCTestCase {

    func test_representative_prefersA1_overManualAndSnipaste() {
        let forms: [DrillTryoutFormation] = [
            stubFormation(token: "manual01", file: "drill_c053__manual01-x-0杆.json"),
            stubFormation(token: "A3", file: "drill_c053__A3-x-0杆.json"),
            stubFormation(token: "A1", file: "drill_c053__A1-x-0杆.json"),
            stubFormation(token: "Snipaste_1", file: "drill_c053__Snipaste_1-x-1杆.json"),
        ]
        let picked = DrillTryoutBoardStore.representative(from: forms)
        XCTAssertEqual(picked?.token, "A1")
    }

    func test_representative_preferredTokenWins() {
        let forms: [DrillTryoutFormation] = [
            stubFormation(token: "A1", file: "a1.json"),
            stubFormation(token: "A4", file: "a4.json"),
        ]
        let picked = DrillTryoutBoardStore.representative(from: forms, preferredToken: "A4")
        XCTAssertEqual(picked?.token, "A4")
    }

    func test_representative_legacyEmptyTokenBeforeManual() {
        let forms: [DrillTryoutFormation] = [
            stubFormation(token: "manual01", file: "drill_c001__manual01-x-1杆.json"),
            stubFormation(token: "", file: "drill_c001-半台直线球-1杆.json"),
        ]
        let picked = DrillTryoutBoardStore.representative(from: forms)
        XCTAssertEqual(picked?.token, "")
        XCTAssertEqual(picked?.fileName, "drill_c001-半台直线球-1杆.json")
    }

    func test_resolveSource_multiFormationUsesA1Board() async throws {
        guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: "drill_c053") else {
            throw XCTSkip("drill_c053 not in bundle")
        }
        let source = try XCTUnwrap(DrillStaticPreview.resolveSource(for: drill))
        XCTAssertEqual(source.token, "A1")
        XCTAssertFalse(source.board.onTable.isEmpty)
        XCTAssertNotNil(source.board.onTable[PositionPlayBall.cueKey])
        // A1 board should not force every object ball to "_8" when sequence has real keys.
        let objectKeys = source.board.onTable.keys.filter { !PositionPlayBall.isCue($0) }
        XCTAssertFalse(objectKeys.isEmpty)
    }

    func test_options_listBallScale_vs_detailTrueSize() {
        // v24 E2/E3: list PNG readability vs live detail true size (no second PNG set).
        XCTAssertEqual(DrillStaticPreview.Options.thumbnail.ballScale, 1.8, accuracy: 0.001)
        XCTAssertEqual(DrillStaticPreview.Options.detail.ballScale, 1.0, accuracy: 0.001)
    }

    func test_renderThumbnail_smoke_c001_and_c053() async throws {
        for id in ["drill_c001", "drill_c053"] {
            guard let drill = await DrillContentService.shared.loadDrillFromBundle(id: id) else {
                throw XCTSkip("\(id) not in bundle")
            }
            let image = try XCTUnwrap(
                DrillThumbnailRenderer.render(drill: drill),
                "render failed for \(id)"
            )
            let png = try XCTUnwrap(image.pngData())
            XCTAssertGreaterThan(png.count, 4_000, "\(id) thumbnail too small")
        }
    }

    // MARK: - Helpers

    private func stubFormation(token: String, file: String) -> DrillTryoutFormation {
        DrillTryoutFormation(
            token: token,
            title: file,
            fileName: file,
            initial: BoardSnapshot(onTable: [
                PositionPlayBall.cueKey: CanvasPoint(x: 0.5, y: 0.2),
                "_8": CanvasPoint(x: 0.5, y: 0.35),
            ]),
            stepCount: 0,
            firstShot: nil,
            steps: []
        )
    }
}
