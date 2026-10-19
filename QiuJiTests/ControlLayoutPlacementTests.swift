import XCTest
import CoreGraphics
#if canImport(QiuJi)
@testable import QiuJi
#else
@testable import ControlLayoutHarness
#endif

final class ControlLayoutPlacementTests: XCTestCase {
    private var input: ControlLayoutPlacement.Input {
        .init(page: CGRect(x: 0, y: 0, width: 1000, height: 800),
              leading: CGRect(x: 4, y: 44, width: 60, height: 756),
              trailing: CGRect(x: 936, y: 44, width: 60, height: 756),
              defaults: [.direction: CGRect(x: 4, y: 180, width: 60, height: 240),
                         .replay: CGRect(x: 4, y: 424, width: 60, height: 100),
                         .instrument: CGRect(x: 936, y: 180, width: 60, height: 260),
                         .primary: CGRect(x: 936, y: 444, width: 60, height: 60),
                         .camera: CGRect(x: 880, y: 240, width: 44, height: 188)])
    }
    func test_floatingKeyboardUsesOwnRegionsAndRetainsNativeSize() {
        let keyboard = CGRect(x: 620, y: 500, width: 280, height: 260)
        let sample = ControlLayoutPlacement.Input(page: input.page, leading: input.leading, trailing: input.trailing,
            defaults: [.information: CGRect(x: 4, y: 200, width: 60, height: 140), .keyboard: keyboard],
            groupRegions: [.keyboard: .init(leading: CGRect(x: 100, y: 44, width: 280, height: 736),
                                            trailing: CGRect(x: 620, y: 44, width: 280, height: 736))])
        let moved = ControlLayoutPlacement.place(intent([.keyboard: [.lane: .lane(.leading), .offset: .offset(-8)]]), in: sample, allowClamping: false)
        XCTAssertEqual(moved.status, .customized)
        XCTAssertEqual(moved.frames[.keyboard], CGRect(x: 100, y: 492, width: 280, height: 260))
        XCTAssertEqual(moved.frames[.information], sample.defaults[.information])
        XCTAssertEqual(ControlLayoutPlacement.place(intent([.keyboard: [.offset: .offset(80)]]), in: sample, allowClamping: false).status, .temporaryDefault)
        XCTAssertEqual(ControlLayoutPlacement.place(intent([.keyboard: [.order: .order(0)]]), in: sample).status, .temporaryDefault)
        var obstructed = sample
        obstructed.obstacles = [CGRect(x: 100, y: 500, width: 30, height: 30)]
        XCTAssertEqual(ControlLayoutPlacement.place(intent([.keyboard: [.lane: .lane(.leading)]]), in: obstructed).status, .temporaryDefault)
    }
    private func intent(_ values: [ControlLayoutGroup: [ControlLayoutProperty: ControlLayoutValue]]) -> ControlLayoutResolved {
        .init(values: values)
    }
    func test_defaultExactlyPreservesHostFrames() {
        let result = ControlLayoutPlacement.place(.init(), in: input)
        XCTAssertEqual(result.status, .original)
        XCTAssertEqual(result.frames, input.defaults)
    }
    func test_independentMovesUseLogicalPointsAndCameraFollowsInstrument() {
        let result = ControlLayoutPlacement.place(intent([.primary: [.offset: .offset(20)], .direction: [.offset: .offset(-20)]]), in: input)
        XCTAssertEqual(result.status, .customized)
        XCTAssertEqual(result.frames[.primary]?.minY, 464)
        XCTAssertEqual(result.frames[.direction]?.minY, 160)
        XCTAssertEqual(result.frames[.instrument], input.defaults[.instrument])
        XCTAssertEqual(result.frames[.camera], input.defaults[.camera])
    }
    func test_orderAndWholeLaneSwapPreserveSizesAndMirrorCameraTowardTable() {
        let ordered = ControlLayoutPlacement.place(intent([.primary: [.order: .order(0)], .instrument: [.order: .order(1)]]), in: input)
        XCTAssertEqual(ordered.status, .customized)
        XCTAssertEqual(ordered.frames[.primary]?.minY, 180)
        XCTAssertEqual(ordered.frames[.instrument]?.minY, 244)
        let swapped = ControlLayoutPlacement.place(intent([
            .direction: [.lane: .lane(.trailing)], .replay: [.lane: .lane(.trailing)],
            .instrument: [.lane: .lane(.leading)], .primary: [.lane: .lane(.leading)]]), in: input)
        XCTAssertEqual(swapped.status, .customized)
        XCTAssertEqual(swapped.frames[.primary]?.minX, 4)
        XCTAssertEqual(swapped.frames[.direction]?.minX, 936)
        XCTAssertEqual(swapped.frames[.camera]?.minX, 76)
        for (group, frame) in input.defaults { XCTAssertEqual(swapped.frames[group]?.size, frame.size) }
    }
    func test_invalidOverlapAndNonfiniteRejectWholeConfiguration() {
        for value in [-100.0, Double.nan, Double.infinity] {
            let result = ControlLayoutPlacement.place(intent([.primary: [.offset: .offset(value)]]), in: input)
            XCTAssertEqual(result.status, .temporaryDefault)
            XCTAssertEqual(result.frames, input.defaults)
        }
        let unavailableTier = ControlLayoutPlacement.place(intent([.direction: [.size: .size(.compact)]]), in: input)
        XCTAssertEqual(unavailableTier.status, .temporaryDefault)
    }
    func test_clampsAtBoundaryAndRejectsObstacles() {
        let result = ControlLayoutPlacement.place(intent([.primary: [.offset: .offset(2048)]]), in: input)
        XCTAssertEqual(result.status, .customized)
        XCTAssertEqual(result.frames[.primary]?.maxY, 800)
        var blocked = input
        blocked.obstacles = [CGRect(x: 930, y: 735, width: 70, height: 65)]
        XCTAssertEqual(ControlLayoutPlacement.place(intent([.primary: [.offset: .offset(2048)]]), in: blocked).status, .temporaryDefault)
    }
    func test_newEditorDropRejectsOutOfBoundsWhileRuntimeKeepsSavedIntent() {
        let outside = intent([.primary: [.offset: .offset(2048)]])
        let drop = ControlLayoutPlacement.place(outside, in: input, allowClamping: false)
        XCTAssertEqual(drop.status, .temporaryDefault)
        XCTAssertEqual(drop.frames, input.defaults)
        XCTAssertEqual(ControlLayoutPlacement.place(outside, in: input).frames[.primary]?.maxY, 800)
        XCTAssertEqual(outside[.primary, .offset], .offset(2048))
        let valid = ControlLayoutPlacement.place(intent([.primary: [.offset: .offset(8)]]), in: input, allowClamping: false)
        XCTAssertEqual(valid.status, .customized)
        XCTAssertEqual(valid.frames[.primary]?.minY, 452)
    }
    func test_narrowWindowFallbackDoesNotMutateIntentAndRecovers() {
        let draft = intent([.primary: [.order: .order(0)]])
        var narrow = input
        narrow.leading.size.height = 200
        narrow.trailing.size.height = 200
        XCTAssertEqual(ControlLayoutPlacement.place(draft, in: narrow).status, .temporaryDefault)
        XCTAssertEqual(ControlLayoutPlacement.place(draft, in: input).status, .customized)
        narrow.defaultFits = false
        XCTAssertEqual(ControlLayoutPlacement.place(draft, in: narrow).status, .insufficientSpace)
    }
    func test_cameraMirrorIsValidatedAgainstOtherControls() {
        let result = ControlLayoutPlacement.place(intent([.camera: [.cameraSlot: .cameraSlot(.mirrored)]]), in: input)
        XCTAssertEqual(result.status, .customized)
        XCTAssertEqual(result.frames[.camera]?.minX, 76)
        var blocked = input
        blocked.obstacles = [CGRect(x: 70, y: 230, width: 60, height: 200)]
        XCTAssertEqual(ControlLayoutPlacement.place(intent([.camera: [.cameraSlot: .cameraSlot(.mirrored)]]), in: blocked).status, .temporaryDefault)
    }
    func test_uneditedGroupsKeepNativeHorizontalAlignmentAndWideReplayIsRejected() {
        var asymmetric = input
        asymmetric.defaults[.replay] = CGRect(x: 15, y: 424, width: 44, height: 100)
        let moved = ControlLayoutPlacement.place(intent([.primary: [.offset: .offset(20)]]), in: asymmetric)
        XCTAssertEqual(moved.frames[.replay], asymmetric.defaults[.replay])
        asymmetric.defaults[.replay] = CGRect(x: 4, y: 424, width: 92, height: 44)
        let rejected = ControlLayoutPlacement.place(intent([.primary: [.offset: .offset(20)]]), in: asymmetric)
        XCTAssertEqual(rejected.status, .temporaryDefault)
        XCTAssertEqual(rejected.frames, asymmetric.defaults)
    }

    func test_smallTeachingCameraUsesActualInstrumentBounds() {
        let small = ControlLayoutPlacement.Input(page: CGRect(x: 0, y: 0, width: 667, height: 375),
            leading: CGRect(x: 4, y: 44, width: 60, height: 331),
            trailing: CGRect(x: 603, y: 44, width: 60, height: 331),
            defaults: [.planning: CGRect(x: 4, y: 77.25, width: 60, height: 297.75),
                       .instrument: CGRect(x: 609, y: 63, width: 48, height: 232),
                       .primary: CGRect(x: 603, y: 299, width: 60, height: 60),
                       .camera: CGRect(x: 563, y: 118, width: 44, height: 188)])
        let result = ControlLayoutPlacement.place(intent([.primary: [.offset: .offset(8)]]), in: small, allowClamping: false)
        XCTAssertEqual(result.status, .customized)
        XCTAssertEqual(result.frames[.primary]?.minY, 307)
        XCTAssertEqual(result.frames[.camera], small.defaults[.camera])
        XCTAssertEqual(result.frames[.instrument], small.defaults[.instrument])
    }

}
