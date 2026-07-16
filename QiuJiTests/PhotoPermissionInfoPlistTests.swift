import XCTest

/// W1 返工回归（问题集合_v9）：权限文案必须真实进包。
///
/// 根因留档：主 target 显式 INFOPLIST_FILE（GENERATE_INFOPLIST_FILE=NO）时，
/// pbxproj 里的 INFOPLIST_KEY_* 被 Xcode 全部忽略——权限描述缺失导致真机
/// `PHPhotoLibrary.requestAuthorization` 首次弹框被 TCC 强杀（秒闪退）。
/// 本测试钉死：文案必须存在于宿主 App 的 Info.plist（host bundle）。
final class PhotoPermissionInfoPlistTests: XCTestCase {

    private var hostBundle: Bundle {
        // Unit tests run inside the host app; Bundle.main is 球迹.app.
        Bundle.main
    }

    func test_photoLibraryAddUsageDescription_present() {
        let value = hostBundle.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") as? String
        XCTAssertNotNil(value, "NSPhotoLibraryAddUsageDescription 缺失——保存相册在真机会被 TCC 强杀")
        XCTAssertFalse(value?.isEmpty ?? true, "权限文案不得为空字符串")
    }

    func test_photoLibraryUsageDescription_present() {
        let value = hostBundle.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") as? String
        XCTAssertNotNil(value, "NSPhotoLibraryUsageDescription 缺失")
        XCTAssertFalse(value?.isEmpty ?? true)
    }

    func test_cameraUsageDescription_present() {
        let value = hostBundle.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String
        XCTAssertNotNil(value, "NSCameraUsageDescription 缺失")
        XCTAssertFalse(value?.isEmpty ?? true)
    }
}
