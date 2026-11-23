import Foundation

enum AppMetadata {
    static let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "CuePhys"
    static var defaultUserName: String { "\(displayName) 用户" }

    static var versionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "版本 \(version)（\(build)）"
    }
}
