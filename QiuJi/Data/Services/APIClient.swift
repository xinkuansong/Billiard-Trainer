import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let body: (any Encodable)?
    let queryItems: [URLQueryItem]

    init(_ method: HTTPMethod, _ path: String, body: (any Encodable)? = nil, query: [URLQueryItem] = []) {
        self.method = method
        self.path = path
        self.body = body
        self.queryItems = query
    }
}

struct EmptyResponse: Decodable {}
struct APIErrorBody: Decodable { let message: String }

protocol APITokenStore: Sendable {
    func load(_ key: KeychainService.Key) -> String?
    @discardableResult func save(_ value: String, for key: KeychainService.Key) -> Bool
}

struct KeychainAPITokenStore: APITokenStore {
    func load(_ key: KeychainService.Key) -> String? { KeychainService.load(key: key) }
    func save(_ value: String, for key: KeychainService.Key) -> Bool {
        KeychainService.save(key: key, value: value)
    }
}

/// 日期编解码口径（v36 W3）。
///
/// 上行用 `.iso8601`（无小数秒），Mongoose 能解析。**下行不能也用 `.iso8601`**：
/// 后端 `res.json()` 序列化 Date 走 `toJSON()`，产出带毫秒的
/// `2026-08-12T03:00:00.000Z`，而 `JSONDecoder.DateDecodingStrategy.iso8601`
/// 只认无小数秒形式 —— 用它会让**每一个**含日期的响应整条解码失败。
/// 故解码侧同时接受两种写法；解析不了时抛带 `codingPath` 的 `dataCorrupted`
/// 而不是静默给个默认时间（FL-029）。
enum APIDateCoding {
    private static let withFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let withoutFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let decodingStrategy: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let date = withFractionalSeconds.date(from: raw) ?? withoutFractionalSeconds.date(from: raw) {
            return date
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "无法按 ISO8601（含/不含小数秒）解析日期：\"\(raw)\""
            )
        )
    }
}

final class APIClient: Sendable {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let tokenStore: any APITokenStore

    init(baseURL: URL = AppConfig.apiBaseURL,
         session: URLSession = .shared,
         tokenStore: any APITokenStore = KeychainAPITokenStore()) {
        self.baseURL = baseURL
        self.session = session
        self.tokenStore = tokenStore

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = APIDateCoding.decodingStrategy
        self.decoder = dec
    }

    // MARK: - Public

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let data = try await requestData(endpoint)
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
    }

    /// Raw response/upload path used by authenticated binary resources such as avatars.
    /// JSON endpoints continue to use `request(_:)`, so Views never construct URLRequests.
    func requestData(
        _ endpoint: Endpoint,
        rawBody: Data? = nil,
        contentType: String? = nil
    ) async throws -> Data {
        #if DEBUG
        // The identity-only UI fixture has no server credentials. Keep its local
        // presentation offline instead of sending synthetic identity to production
        // and allowing a real 401 to invalidate the fixture during screenshot tests.
        if ProcessInfo.processInfo.arguments.contains("-v53.authenticatedProfileFixture") {
            throw URLError(.notConnectedToInternet)
        }
        #endif
        let requestRefreshToken = tokenStore.load(.refreshToken)
        var request = try buildRequest(endpoint, rawBody: rawBody, contentType: contentType)
        authorize(&request)
        let (data, response) = try await perform(request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            // A background request may finish after a new interactive login.
            guard tokenStore.load(.refreshToken) == requestRefreshToken else { throw CancellationError() }
            guard try await refreshToken() else {
                let invalidated = await MainActor.run {
                    guard tokenStore.load(.refreshToken) == requestRefreshToken else { return false }
                    NotificationCenter.default.post(name: .authSessionInvalidated, object: nil)
                    return true
                }
                guard invalidated else { throw CancellationError() }
                throw AppError.authRequired
            }
            var retry = try buildRequest(endpoint, rawBody: rawBody, contentType: contentType)
            authorize(&retry)
            let (retryData, retryResponse) = try await perform(retry)
            return try validatedData(retryData, retryResponse)
        }
        return try validatedData(data, response)
    }

    // MARK: - Internals

    private func buildRequest(
        _ endpoint: Endpoint,
        rawBody: Data? = nil,
        contentType: String? = nil
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        guard let url = components.url else {
            throw AppError.networkError("Invalid URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method.rawValue
        req.setValue(contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        if let rawBody {
            req.httpBody = rawBody
        } else if let body = endpoint.body {
            req.httpBody = try encoder.encode(AnyEncodable(body))
        }
        return req
    }

    private func authorize(_ request: inout URLRequest) {
        if let token = tokenStore.load(.accessToken) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw AppError.networkError("网络连接失败，请检查网络后重试")
        }
    }

    private func validatedData(_ data: Data, _ response: URLResponse) throws -> Data {
        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("无效的服务器响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            let errBody = try? decoder.decode(APIErrorBody.self, from: data)
            throw AppError.serverError(
                statusCode: http.statusCode,
                message: errBody?.message ?? "服务器错误 (\(http.statusCode))"
            )
        }
        return data
    }

    private func refreshToken() async throws -> Bool {
        guard let refresh = tokenStore.load(.refreshToken) else { return false }

        struct Req: Encodable { let refreshToken: String }
        struct Res: Decodable { let accessToken: String; let refreshToken: String }

        let endpoint = Endpoint(.post, "/auth/refresh", body: Req(refreshToken: refresh))
        let req = try buildRequest(endpoint)
        let (data, response) = try await perform(req)
        guard tokenStore.load(.refreshToken) == refresh else { throw CancellationError() }

        guard let http = response as? HTTPURLResponse else {
            throw AppError.networkError("无效的服务器响应")
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            return false
        }
        _ = try validatedData(data, response)
        let res = try decoder.decode(Res.self, from: data)
        tokenStore.save(res.accessToken, for: .accessToken)
        tokenStore.save(res.refreshToken, for: .refreshToken)
        return true
    }
}

// Type-erased Encodable wrapper
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ value: any Encodable) {
        self._encode = { try value.encode(to: $0) }
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
