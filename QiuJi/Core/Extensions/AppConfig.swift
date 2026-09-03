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

    // MARK: - Published legal documents

    static var termsURL: URL? {
        validatedLegalURL(Bundle.main.infoDictionary?["LEGAL_TERMS_URL"] as? String)
    }

    static var privacyURL: URL? {
        validatedLegalURL(Bundle.main.infoDictionary?["LEGAL_PRIVACY_URL"] as? String)
    }

    /// Legal links fail closed: an unset value, a non-HTTPS URL, or a known placeholder
    /// keeps the honest "尚未发布" state instead of exposing a broken compliance link.
    static func validatedLegalURL(_ raw: String?) -> URL? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              !host.isEmpty,
              host != "example.com",
              host != "yourdomain.com" else {
            return nil
        }
        return components.url
    }
}
