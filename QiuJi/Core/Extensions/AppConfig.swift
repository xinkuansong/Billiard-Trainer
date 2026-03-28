import Foundation

enum AppConfig {
    // MARK: - 自建后端 API
    static var apiBaseURL: URL {
        let raw = Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? "https://api.qiuji.app"
        return URL(string: raw) ?? URL(string: "https://api.qiuji.app")!
    }

    // MARK: - WeChat
    static var wechatAppId: String {
        Bundle.main.infoDictionary?["WECHAT_APP_ID"] as? String ?? ""
    }
    static var wechatUniversalLink: String {
        Bundle.main.infoDictionary?["WECHAT_UNIVERSAL_LINK"] as? String ?? ""
    }
}
