// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CuePhysWeChat",
    platforms: [.iOS(.v17)],
    products: [.library(name: "CuePhysWeChat", targets: ["CuePhysWeChat"])],
    targets: [
        .binaryTarget(name: "WechatOpenSDK",
                      path: "Artifacts/WechatOpenSDK.xcframework.zip"),
        .target(name: "CuePhysWeChat", dependencies: ["WechatOpenSDK"],
                resources: [.copy("PrivacyInfo.xcprivacy")],
                linkerSettings: [.linkedFramework("Security"), .linkedFramework("UIKit"),
                                 .linkedFramework("CoreGraphics"), .linkedFramework("WebKit"),
                                 .linkedLibrary("z"), .linkedLibrary("sqlite3"), .linkedLibrary("c++")])
    ]
)
