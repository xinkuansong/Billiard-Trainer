import XCTest
@testable import QiuJi

@MainActor
final class AppRouterTests: XCTestCase {

    func test_resumeMinimizedTraining_expandsRestOverlay() {
        let router = AppRouter()
        let vm = ActiveTrainingViewModel(mode: .free)
        vm.isRestTimerActive = true
        vm.minimizeRestOverlay()
        XCTAssertTrue(vm.isRestOverlayMinimized)
        XCTAssertFalse(vm.shouldShowRestOverlay)

        router.minimizeTraining(vm)
        router.resumeMinimizedTraining()

        XCTAssertFalse(vm.isRestOverlayMinimized)
        XCTAssertTrue(vm.shouldShowRestOverlay)
        XCTAssertNil(router.minimizedTrainingVM)
        XCTAssertNotNil(router.activeTrainingMode)
    }
}
