#if DEBUG
import Foundation

/// Pure argument parsing is available to Debug unit tests on any host. The
/// application entry and router mutation are Simulator-only at their call sites.
struct LiveReviewLaunchRequest: Equatable {
    enum Destination: Equatable {
        case theory(TheoryPageID)
        case drillDetail(String)
    }

    let destination: Destination

    var pageID: String {
        switch destination {
        case .theory: "theory"
        case .drillDetail: "drill-detail"
        }
    }

    var contentID: String {
        switch destination {
        case .theory(let id): id.rawValue
        case .drillDetail(let id): id
        }
    }

    #if targetEnvironment(simulator)
    /// Referenced by the active routing path so a controller can reject old or
    /// Release executables before launching them. This is capability, not READY.
    static let capabilityMarker = "QIUJI_LIVE_REVIEW_THEORY_V1"
    static let drillDetailCapabilityMarker = "QIUJI_LIVE_REVIEW_DRILL_DETAIL_V1"

    var capabilityMarker: String {
        switch destination {
        case .theory: Self.capabilityMarker
        case .drillDetail: Self.drillDetailCapabilityMarker
        }
    }
    #endif

    static func parse(arguments: [String], drillIndexData: Data? = nil) throws -> Self? {
        let reviewArguments = arguments.filter { $0.hasPrefix("-liveReview") }
        guard !reviewArguments.isEmpty else { return nil }

        var values: [String: String] = [:]
        for argument in reviewArguments {
            let parts = argument.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(parts[0])
            guard ["-liveReview.pageId", "-liveReview.contentId"].contains(key), parts.count == 2 else {
                throw LaunchError.invalidArgument(argument)
            }
            guard values[key] == nil else { throw LaunchError.duplicateArgument(key) }
            let value = String(parts[1])
            guard !value.isEmpty else { throw LaunchError.invalidArgument(argument) }
            values[key] = value
        }

        // RootView's legacy page hosts cannot compete with a real Tab route.
        let legacyPagePrefixes = [
            "-deeplink.", "-dailyInteraction.sharedPage", "-intro.preview", "-subscription.preview",
            "-v57.practiceCountFixture", "-v50.photoPermissionProbe", "-v51.phoneLoginPreview",
            "-v51.activeTraining", "-v51.minimizedTraining", "-v51.componentProbe", "-v51.sceneAiming2D",
            "-v54.todayState", "-v54.historySource", "-planThree.", "-snooker.", "-w29."
        ]
        if let conflict = arguments.first(where: { argument in
            legacyPagePrefixes.contains(where: argument.hasPrefix)
        }) {
            throw LaunchError.conflictingRoute(conflict)
        }
        guard let pageID = values["-liveReview.pageId"] else {
            throw LaunchError.missingArgument("-liveReview.pageId")
        }
        guard let contentID = values["-liveReview.contentId"] else {
            throw LaunchError.missingArgument("-liveReview.contentId")
        }
        switch pageID {
        case "theory":
            guard let id = TheoryPageID(rawValue: contentID),
                  TheoryCatalog.entry(for: id)?.isPublished == true else {
                throw LaunchError.unsupportedContent(contentID)
            }
            return Self(destination: .theory(id))
        case "drill-detail":
            // Synchronous, read-only Bundle lookup; no repository-loading race.
            let data: Data
            if let drillIndexData {
                data = drillIndexData
            } else {
                guard let url = Bundle.main.url(forResource: "index", withExtension: "json", subdirectory: "Drills") else {
                    throw LaunchError.missingDrillIndex
                }
                data = try Data(contentsOf: url)
            }
            let index = try JSONDecoder().decode(BundledDrillIndex.self, from: data)
            guard index.categories.contains(where: { $0.drills.contains(contentID) }) else {
                throw LaunchError.unsupportedContent(contentID)
            }
            return Self(destination: .drillDetail(contentID))
        default:
            throw LaunchError.unsupportedPage(pageID)
        }
    }

    private struct BundledDrillIndex: Decodable {
        struct Category: Decodable { let drills: [String] }
        let categories: [Category]
    }

    enum LaunchError: LocalizedError {
        case invalidArgument(String)
        case duplicateArgument(String)
        case missingArgument(String)
        case conflictingRoute(String)
        case unsupportedPage(String)
        case unsupportedContent(String)
        case missingDrillIndex

        var errorDescription: String? {
            switch self {
            case .invalidArgument(let argument): "Invalid live review argument: \(argument)"
            case .duplicateArgument(let key): "Duplicate live review argument: \(key)"
            case .missingArgument(let key): "Missing live review argument: \(key)"
            case .conflictingRoute(let argument): "Conflicting page route: \(argument)"
            case .unsupportedPage(let page): "Unsupported live review pageId: \(page)"
            case .unsupportedContent(let content): "Unsupported live review contentId: \(content)"
            case .missingDrillIndex: "Missing bundled Drills/index.json for live review"
            }
        }
    }
}
#endif
