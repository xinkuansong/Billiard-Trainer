import Foundation

enum AppConfig {
    // MARK: - 自建后端 API
    static var apiBaseURL: URL? {
        let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        #if DEBUG
        return validatedAPIBaseURL(raw, release: false)
        #else
        return validatedAPIBaseURL(raw, release: true)
        #endif
    }

    /// Production endpoints belong to the company's registered domain. Port and
    /// base path may be explicitly configured without changing account ownership.
    static func validatedAPIBaseURL(_ raw: String?, release: Bool) -> URL? {
        guard let raw, !raw.isEmpty,
              let url = URL(string: raw, encodingInvalidCharacters: false),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased(), !host.isEmpty,
              components.percentEncodedHost?.lowercased() == host,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || (!release && scheme == "http"),
              components.port.map({ (1...65535).contains($0) }) ?? true else { return nil }
        if release {
            let labels = host.split(separator: ".", omittingEmptySubsequences: false)
            guard host == "cuephys.com" || host.hasSuffix(".cuephys.com"),
                  host.utf8.count <= 253, labels.allSatisfy({
                      $0.range(of: #"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$"#, options: .regularExpression) != nil
                  }) else { return nil }
        }
        return url
    }

    static var hasSecureAccountEndpoint: Bool {
        apiBaseURL?.scheme?.lowercased() == "https"
    }

    // MARK: - WeChat
    static var wechatAppId: String {
        Bundle.main.infoDictionary?["WECHAT_APP_ID"] as? String ?? ""
    }
    static var wechatUniversalLink: String {
        Bundle.main.infoDictionary?["WECHAT_UNIVERSAL_LINK"] as? String ?? ""
    }

    static var wechatLinkHost: String {
        Bundle.main.infoDictionary?["WECHAT_LINK_HOST"] as? String ?? ""
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
