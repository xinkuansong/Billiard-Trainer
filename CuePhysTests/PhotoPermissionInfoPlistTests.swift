import XCTest

/// W1 返工回归（问题集合_v9）：权限文案必须真实进包。
///
/// 根因留档：主 target 显式 INFOPLIST_FILE（GENERATE_INFOPLIST_FILE=NO）时，
/// pbxproj 里的 INFOPLIST_KEY_* 被 Xcode 全部忽略——权限描述缺失导致真机
/// `PHPhotoLibrary.requestAuthorization` 首次弹框被 TCC 强杀（秒闪退）。
/// 本测试钉死：文案必须存在于宿主 App 的 Info.plist（host bundle）。
final class PhotoPermissionInfoPlistTests: XCTestCase {

    private var hostBundle: Bundle {
        // Unit tests run inside the host app; Bundle.main is CuePhys.app.
        Bundle.main
    }

    func test_photoLibraryAddUsageDescription_present() {
        let value = hostBundle.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") as? String
        XCTAssertNotNil(value, "NSPhotoLibraryAddUsageDescription 缺失——保存相册在真机会被 TCC 强杀")
        XCTAssertFalse(value?.isEmpty ?? true, "权限文案不得为空字符串")
    }

    func test_systemImagePickerDoesNotDeclarePhotoLibraryReadAccess() {
        XCTAssertNil(hostBundle.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription"))
    }

    func test_noCameraCapturePermissionInCurrentApp() {
        XCTAssertNil(hostBundle.object(forInfoDictionaryKey: "NSCameraUsageDescription"))
    }

    /// v50 多设备巡游发现系统导航按钮显示英文 “Back”。App 的产品语言是
    /// 简体中文，开发语言必须跟随产品语言，系统生成控件才能选中中文资源。
    func test_developmentRegion_isSimplifiedChinese() {
        let value = hostBundle.object(forInfoDictionaryKey: "CFBundleDevelopmentRegion") as? String
        XCTAssertEqual(value, "zh-Hans")
    }

    /// TP03/TP30: phone navigation returns to portrait; table pages also support landscape.
    /// This tests the declared capability; route rotation is covered by UI tests.
    func test_supportedOrientations_includePortraitAndBothLandscapeDirections() {
        let values = hostBundle.object(
            forInfoDictionaryKey: "UISupportedInterfaceOrientations"
        ) as? [String]
        XCTAssertEqual(Set(values ?? []), Set(["UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]))
    }
}
