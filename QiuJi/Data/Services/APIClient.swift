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

    private init() {
        self.baseURL = AppConfig.apiBaseURL
        self.session = .shared

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = APIDateCoding.decodingStrategy
        self.decoder = dec
    }

    // MARK: - Public

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var req = try buildRequest(endpoint)
        if let token = KeychainService.load(key: .accessToken) {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await perform(req)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            let refreshed = try await refreshToken()
            if refreshed {
                var retry = try buildRequest(endpoint)
                if let newToken = KeychainService.load(key: .accessToken) {
                    retry.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                let (retryData, retryResp) = try await perform(retry)
                return try handleResponse(retryData, retryResp)
            } else {
                throw AppError.authRequired
            }
        }

        return try handleResponse(data, response)
    }

    // MARK: - Internals

    private func buildRequest(_ endpoint: Endpoint) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        guard let url = components.url else {
            throw AppError.networkError("Invalid URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        if let body = endpoint.body {
            req.httpBody = try encoder.encode(AnyEncodable(body))
        }
        return req
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw AppError.networkError("网络连接失败，请检查网络后重试")
        }
    }

    private func handleResponse<T: Decodable>(_ data: Data, _ response: URLResponse) throws -> T {
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
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
    }

    private func refreshToken() async throws -> Bool {
        guard let refresh = KeychainService.load(key: .refreshToken) else { return false }

        struct Req: Encodable { let refreshToken: String }
        struct Res: Decodable { let accessToken: String; let refreshToken: String }

        let endpoint = Endpoint(.post, "/auth/refresh", body: Req(refreshToken: refresh))
        let req = try buildRequest(endpoint)
        let (data, response) = try await perform(req)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            KeychainService.clearAll()
            return false
        }
        let res = try decoder.decode(Res.self, from: data)
        KeychainService.save(key: .accessToken, value: res.accessToken)
        KeychainService.save(key: .refreshToken, value: res.refreshToken)
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
