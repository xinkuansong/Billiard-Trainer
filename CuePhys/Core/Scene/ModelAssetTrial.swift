import Foundation

/// Production model resource identities. Historical filenames remain stable for caches.
/// Trial originals are archived in the repository and are no longer packaged.
enum ModelAssetTrial {
    // Constant-channel compaction, 1024px wood maps and 2,880 triangles per ball.
    private static let assetSHA256: [String: String] = [
        "ModelTrial20261010_TaiQiuZhuo.usdz": "73e43df002f07637656b767fdc105033d10f0d764f6d91aa7a5276cf1c885fb6",
        "ModelTrial20261010_CueUV.usdz": "9288907e666d897e4f3be5b94e7ec989eb5a75116f74a07d3790e4340f2e117e",
    ]
    static func identity(_ name: String, subdirectory: String? = nil) -> String {
        guard let source = url(name, subdirectory: subdirectory, logsSelection: false) else { return "missing:" + name }
        return source.lastPathComponent + ":" + (assetSHA256[source.lastPathComponent] ?? "unversioned")
    }
    private static let productionNames: Set<String> = ["TaiQiuZhuo", "CueUV"]

    static func url(_ name: String, subdirectory: String? = nil,
                    bundle: Bundle = .main,
                    logsSelection: Bool = true) -> URL? {
        if productionNames.contains(name) {
            let resource = "ModelTrial20261010_" + name
            let url = bundle.url(forResource: resource, withExtension: "usdz")
            if logsSelection {
                if let url { NSLog("[ModelAssetTrial] selected %@", url.lastPathComponent) }
                else { NSLog("[ModelAssetTrial] missing production model %@", resource) }
            }
            return url
        }
        return bundle.url(forResource: name, withExtension: "usdz", subdirectory: subdirectory)
    }
}
