#if DEBUG
import XCTest
@testable import QiuJi

final class LiveReviewLaunchRequestTests: XCTestCase {
    func testNoRequestLeavesLegacyArgumentsAlone() throws {
        XCTAssertNil(try LiveReviewLaunchRequest.parse(arguments: ["App", "-deeplink.settings"]))
        XCTAssertNil(try LiveReviewLaunchRequest.parse(arguments: ["App", "-v54.todayState=empty"]))
    }

    func testRegisteredTheoryIDsUseExistingCatalogIdentity() throws {
        for entry in TheoryCatalog.entries where entry.isPublished {
            let request = try XCTUnwrap(LiveReviewLaunchRequest.parse(arguments: [
                "App", "-liveReview.pageId=theory", "-liveReview.contentId=\(entry.id.rawValue)",
                "-v51.followSystemAppearance", "-v50.inMemoryStore"
            ]))
            XCTAssertEqual(request.destination, .theory(entry.id))
        }
    }

    func testInvalidMissingUnknownAndDuplicateArgumentsAreRejected() {
        let valid = ["-liveReview.pageId=theory", "-liveReview.contentId=t01"]
        let invalid = [
            ["-liveReview.pageId=theory"], ["-liveReview.contentId=t01"],
            ["-liveReview.pageId=", "-liveReview.contentId=t01"],
            ["-liveReview.pageId", "-liveReview.contentId=t01"],
            ["-liveReview.pageId=home", "-liveReview.contentId=t01"],
            ["-liveReview.pageId=theory", "-liveReview.contentId=T01"],
            ["-liveReview.pageId=theory", "-liveReview.contentId=t99"],
            valid + ["-liveReview.unknown=value"],
            valid + ["-liveReview.pageId=theory"], valid + ["-liveReview.contentId=t01"],
            valid + ["-liveReview.contentId=t02"]
        ]
        for arguments in invalid {
            XCTAssertThrowsError(try LiveReviewLaunchRequest.parse(arguments: arguments), "\(arguments)")
        }
    }

    func testLegacyPageHostsCannotCompeteWithReviewRoute() {
        let valid = ["-liveReview.pageId=theory", "-liveReview.contentId=t01"]
        for route in ["-deeplink.settings", "-deeplink.drillDetail=drill_c001", "-intro.preview",
                      "-v54.todayState=empty", "-v54.historySource=official",
                      "-dailyInteraction.sharedPage=angleDynamic", "-planThree.cleared",
                      "-v51.componentProbe", "-w29.emptyCTA"] {
            XCTAssertThrowsError(try LiveReviewLaunchRequest.parse(arguments: valid + [route]), route)
        }
    }

    func testDrillDetailUsesBundledIndexAndRejectsMissingOrUnknownIdentity() throws {
        let request = try XCTUnwrap(LiveReviewLaunchRequest.parse(arguments: [
            "-liveReview.pageId=drill-detail", "-liveReview.contentId=drill_c001"
        ]))
        XCTAssertEqual(request.destination, .drillDetail("drill_c001"))
        XCTAssertEqual(request.pageID, "drill-detail")
        XCTAssertEqual(request.contentID, "drill_c001")
        for id in ["drill_c002", "drill_c999", "../drill_c001", "drill_c001=other", ""] {
            XCTAssertThrowsError(try LiveReviewLaunchRequest.parse(arguments: [
                "-liveReview.pageId=drill-detail", "-liveReview.contentId=\(id)"
            ]), id)
        }
    }

    func testDrillDetailRejectsDuplicateConflictingAndMalformedIndexRequests() {
        let valid = ["-liveReview.pageId=drill-detail", "-liveReview.contentId=drill_c001"]
        for extra in ["-liveReview.pageId=theory", "-liveReview.contentId=drill_c012",
                      "-liveReview.contentId=drill_c001", "-deeplink.drillDetail=drill_c001",
                      "-v54.todayState=empty", "-liveReview.unknown=value"] {
            XCTAssertThrowsError(try LiveReviewLaunchRequest.parse(arguments: valid + [extra]), extra)
        }
        XCTAssertThrowsError(try LiveReviewLaunchRequest.parse(arguments: valid, drillIndexData: Data("{}".utf8)))
        XCTAssertThrowsError(try LiveReviewLaunchRequest.parse(arguments: valid, drillIndexData: Data("broken".utf8)))
    }

    #if targetEnvironment(simulator)
    @MainActor
    func testRouterConsumesOnceAndDoesNotRepushAfterBackOrTabChange() throws {
        let router = AppRouter()
        let request = try XCTUnwrap(LiveReviewLaunchRequest.parse(arguments: [
            "-liveReview.pageId=theory", "-liveReview.contentId=t01"
        ]))
        XCTAssertEqual(router.selectedTab, .training)
        XCTAssertEqual(router.anglePath.count, 0)
        XCTAssertTrue(router.applyLiveReviewLaunchOnce(request))
        XCTAssertEqual(router.selectedTab, .angle)
        XCTAssertEqual(router.anglePath.count, 1)
        router.anglePath.removeLast()
        router.switchTab(.profile)
        XCTAssertFalse(router.applyLiveReviewLaunchOnce(request))
        XCTAssertEqual(router.selectedTab, .profile)
        XCTAssertEqual(router.anglePath.count, 0)
    }

    @MainActor
    func testDrillRouterConsumesOnceAndDoesNotRepushAfterBackOrTabChange() throws {
        let router = AppRouter()
        let request = try XCTUnwrap(LiveReviewLaunchRequest.parse(arguments: [
            "-liveReview.pageId=drill-detail", "-liveReview.contentId=drill_c001"
        ]))
        XCTAssertTrue(router.applyLiveReviewLaunchOnce(request))
        XCTAssertEqual(router.selectedTab, .drillLibrary)
        XCTAssertEqual(router.drillLibraryPath.count, 1)
        XCTAssertEqual(router.anglePath.count, 0)
        router.drillLibraryPath.removeLast()
        router.switchTab(.profile)
        XCTAssertFalse(router.applyLiveReviewLaunchOnce(request))
        XCTAssertEqual(router.selectedTab, .profile)
        XCTAssertEqual(router.drillLibraryPath.count, 0)
    }
    #endif
}
#endif
