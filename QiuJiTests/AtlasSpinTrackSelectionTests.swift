import XCTest
@testable import QiuJi

final class AtlasSpinTrackSelectionTests: XCTestCase {

    func testDefault_allEightEnabled() {
        XCTAssertEqual(AtlasSpinTrackSelection.allEnabled, Set(0..<8))
        XCTAssertEqual(AtlasSpinTrackSelection.trackCount, 8)
    }

    func testToggle_turnsOffThenOn() {
        var set = AtlasSpinTrackSelection.allEnabled
        set = AtlasSpinTrackSelection.toggle(set, index: 2)
        XCTAssertFalse(set.contains(2))
        XCTAssertEqual(set.count, 7)
        set = AtlasSpinTrackSelection.toggle(set, index: 2)
        XCTAssertTrue(set.contains(2))
        XCTAssertEqual(set, AtlasSpinTrackSelection.allEnabled)
    }

    func testToggle_keepsLastTrack() {
        var set = AtlasSpinTrackSelection.allEnabled
        for i in 0..<7 {
            set = AtlasSpinTrackSelection.toggle(set, index: i)
        }
        XCTAssertEqual(set, [7])
        let same = AtlasSpinTrackSelection.toggle(set, index: 7)
        XCTAssertEqual(same, [7], "最后一档不可关")
    }

    func testToggle_outOfRangeIsNoOp() {
        let set = AtlasSpinTrackSelection.allEnabled
        XCTAssertEqual(AtlasSpinTrackSelection.toggle(set, index: -1), set)
        XCTAssertEqual(AtlasSpinTrackSelection.toggle(set, index: 8), set)
    }

    @MainActor
    func testSeparationVM_toggleKeepsLast() {
        let vm = SeparationAngleAtlasViewModel()
        XCTAssertEqual(vm.enabledTracks, AtlasSpinTrackSelection.allEnabled)
        for i in 0..<7 { vm.toggleTrack(i) }
        XCTAssertEqual(vm.enabledTracks, [7])
        vm.toggleTrack(7)
        XCTAssertEqual(vm.enabledTracks, [7])
        vm.toggleTrack(0)
        XCTAssertEqual(vm.enabledTracks, [0, 7])
    }

    @MainActor
    func testCushionVM_toggleKeepsLast() {
        let vm = CushionEnglishAtlasViewModel()
        XCTAssertEqual(vm.enabledTracks, AtlasSpinTrackSelection.allEnabled)
        for i in 1..<8 { vm.toggleTrack(i) }
        XCTAssertEqual(vm.enabledTracks, [0])
        vm.toggleTrack(0)
        XCTAssertEqual(vm.enabledTracks, [0])
    }
}
