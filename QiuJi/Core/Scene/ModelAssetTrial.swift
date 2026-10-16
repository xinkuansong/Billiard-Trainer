import Foundation

/// Reversible device trial. Original USDZ files stay in the bundle unchanged.
/// Set enabled to false and rebuild, or launch with -modelAssetTrialUseOriginal YES.
enum ModelAssetTrial {
    // Constant-channel compaction and 1024px wood maps; geometry is unchanged.
    private static let assetSHA256: [String: String] = [
        "ModelTrial20261010_TaiQiuZhuo.usdz": "274727a9a6bd92956a4a745cb271b5ef8a7ae48aa03c01fc18403f22efe706e1",
        "ModelTrial20261010_CueUV.usdz": "9288907e666d897e4f3be5b94e7ec989eb5a75116f74a07d3790e4340f2e117e",
        "TaiQiuZhuo.usdz": "0e011ae72889d56a97255d8d69f2a7c0615ad779340ab64b938c2947817b48d1",
        "CueUV.usdz": "ad24d3696bc78a02cb3a08a9c09af5f04c657a79404754d8b555c744ba429e7f",
    ]
    static func identity(_ name: String, subdirectory: String? = nil) -> String {
        guard let source = url(name, subdirectory: subdirectory, logsSelection: false) else { return "missing:" + name }
        return source.lastPathComponent + ":" + (assetSHA256[source.lastPathComponent] ?? "unversioned")
    }
    static let enabled = true
    static let originals: Set<String> = ["TaiQiuZhuo", "CueUV"]

    static func url(_ name: String, subdirectory: String? = nil,
                    bundle: Bundle = .main,
                    useOriginal: Bool = UserDefaults.standard.bool(forKey: "modelAssetTrialUseOriginal"),
                    logsSelection: Bool = true) -> URL? {
        if enabled && !useOriginal && originals.contains(name) {
            let candidate = "ModelTrial20261010_" + name
            if let url = bundle.url(forResource: candidate, withExtension: "usdz") {
                if logsSelection { NSLog("[ModelAssetTrial] selected %@", url.lastPathComponent) }
                return url
            }
            NSLog("[ModelAssetTrial] missing %@; falling back to original", candidate)
        }
        return bundle.url(forResource: name, withExtension: "usdz", subdirectory: subdirectory)
    }
}
