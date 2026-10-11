import Foundation

/// Reversible device trial. Original USDZ files stay in the bundle unchanged.
/// Set enabled to false and rebuild, or launch with -modelAssetTrialUseOriginal YES.
enum ModelAssetTrial {
    static let enabled = true
    static let originals: Set<String> = ["TaiQiuZhuo", "CueUV"]

    static func url(_ name: String, subdirectory: String? = nil,
                    bundle: Bundle = .main,
                    useOriginal: Bool = UserDefaults.standard.bool(forKey: "modelAssetTrialUseOriginal")) -> URL? {
        if enabled && !useOriginal && originals.contains(name) {
            let candidate = "ModelTrial20261010_" + name
            if let url = bundle.url(forResource: candidate, withExtension: "usdz") {
                NSLog("[ModelAssetTrial] selected %@", url.lastPathComponent)
                return url
            }
            NSLog("[ModelAssetTrial] missing %@; falling back to original", candidate)
        }
        return bundle.url(forResource: name, withExtension: "usdz", subdirectory: subdirectory)
    }
}
