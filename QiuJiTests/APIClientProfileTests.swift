import XCTest
@testable import QiuJi

final class APIClientProfileTests: XCTestCase {
    private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
        struct Stub: @unchecked Sendable {
            let statusCode: Int
            let headers: [String: String]
            let data: Data
        }

        private static let lock = NSLock()
        private static var stubs: [Stub] = []
        private static var observedRequest: URLRequest?
        private static var observedBody: Data?

        static func configure(_ newStub: Stub) {
            lock.lock()
            stubs = [newStub]
            observedRequest = nil
            observedBody = nil
            lock.unlock()
        }

        static func configure(_ newStubs: [Stub]) {
            lock.lock()
            stubs = newStubs
            observedRequest = nil
            observedBody = nil
            lock.unlock()
        }

        static func requestSnapshot() -> URLRequest? {
            lock.lock()
            defer { lock.unlock() }
            return observedRequest
        }

        static func bodySnapshot() -> Data? {
            lock.lock()
            defer { lock.unlock() }
            return observedBody
        }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let body = request.httpBody ?? Self.readBodyStream(request.httpBodyStream)
            Self.lock.lock()
            let current = Self.stubs.isEmpty ? nil : Self.stubs.removeFirst()
            Self.observedRequest = request
            Self.observedBody = body
            Self.lock.unlock()

            guard let current,
                  let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: current.statusCode,
                    httpVersion: nil,
                    headerFields: current.headers
                  ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: current.data)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}

        private static func readBodyStream(_ stream: InputStream?) -> Data? {
            guard let stream else { return nil }
            stream.open()
            defer { stream.close() }
            var result = Data()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                result.append(buffer, count: count)
            }
            return result
        }
    }

    private var client: APIClient!
    private var tokenStore: TestTokenStore!

    override func setUp() {
        super.setUp()
        tokenStore = TestTokenStore()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        client = APIClient(
            baseURL: URL(string: "https://unit.test")!,
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore
        )
    }

    override func tearDown() {
        client = nil
        tokenStore = nil
        super.tearDown()
    }

    func testJSON2xxDecodesProfile() async throws {
        StubURLProtocol.configure(.init(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            data: Data(#"{"id":"u1","displayName":"球徒","email":null,"provider":"apple"}"#.utf8)
        ))

        let user: UserDTO = try await client.request(Endpoint(.get, "/user/profile"))

        XCTAssertEqual(user.id, "u1")
        XCTAssertEqual(user.displayName, "球徒")
    }

    func test400PreservesServerMessage() async {
        StubURLProtocol.configure(.init(
            statusCode: 400,
            headers: ["Content-Type": "application/json"],
            data: Data(#"{"message":"昵称长度须为 1–20 个字符"}"#.utf8)
        ))

        await assertServerError(status: 400, message: "昵称长度须为 1–20 个字符")
    }

    func test401WithoutRefreshTokenBecomesAuthRequired() async {
        StubURLProtocol.configure(.init(
            statusCode: 401,
            headers: ["Content-Type": "application/json"],
            data: Data(#"{"message":"Unauthorized"}"#.utf8)
        ))

        do {
            let _: UserDTO = try await client.request(Endpoint(.get, "/user/profile"))
            XCTFail("401 应抛出 authRequired")
        } catch AppError.authRequired {
            // Expected.
        } catch {
            XCTFail("错误类型不正确：\(error)")
        }
    }

    func testExpiredAccessTokenRefreshesAndRetriesOriginalRequest() async throws {
        tokenStore.save("old-refresh", for: .refreshToken)
        StubURLProtocol.configure([
            .init(
                statusCode: 401,
                headers: ["Content-Type": "application/json"],
                data: Data(#"{"message":"Access expired"}"#.utf8)
            ),
            .init(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                data: Data(#"{"accessToken":"new-access","refreshToken":"new-refresh"}"#.utf8)
            ),
            .init(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                data: Data(#"{"id":"u1","displayName":"球徒","email":null,"provider":"apple"}"#.utf8)
            ),
        ])

        let user: UserDTO = try await client.request(Endpoint(.get, "/user/profile"))

        XCTAssertEqual(user.id, "u1")
        XCTAssertEqual(tokenStore.load(.accessToken), "new-access")
        XCTAssertEqual(tokenStore.load(.refreshToken), "new-refresh")
    }

    func test5xxPreservesStatusAndMessage() async {
        StubURLProtocol.configure(.init(
            statusCode: 503,
            headers: ["Content-Type": "application/json"],
            data: Data(#"{"message":"Service unavailable"}"#.utf8)
        ))

        await assertServerError(status: 503, message: "Service unavailable")
    }

    func testInvalidJSONSurfacesDecodingFailure() async {
        StubURLProtocol.configure(.init(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            data: Data("not-json".utf8)
        ))

        do {
            let _: UserDTO = try await client.request(Endpoint(.get, "/user/profile"))
            XCTFail("非法 JSON 不应被吞掉")
        } catch is DecodingError {
            // Expected.
        } catch {
            XCTFail("应保留 DecodingError，实际为：\(error)")
        }
    }

    func testRawJPEGUploadAndRead() async throws {
        let jpeg = Data([0xFF, 0xD8, 0x41, 0xFF, 0xD9])
        StubURLProtocol.configure(.init(
            statusCode: 200,
            headers: ["Content-Type": "image/jpeg"],
            data: jpeg
        ))

        let response = try await client.requestData(
            Endpoint(.put, "/user/avatar"),
            rawBody: jpeg,
            contentType: "image/jpeg"
        )
        let request = try XCTUnwrap(StubURLProtocol.requestSnapshot())

        XCTAssertEqual(response, jpeg)
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
        XCTAssertEqual(StubURLProtocol.bodySnapshot(), jpeg)
    }

    private func assertServerError(status: Int, message: String) async {
        do {
            let _: UserDTO = try await client.request(Endpoint(.get, "/user/profile"))
            XCTFail("HTTP \(status) 应抛错")
        } catch AppError.serverError(let actualStatus, let actualMessage) {
            XCTAssertEqual(actualStatus, status)
            XCTAssertEqual(actualMessage, message)
        } catch {
            XCTFail("错误类型不正确：\(error)")
        }
    }
}

private final class TestTokenStore: APITokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [KeychainService.Key: String] = [:]

    func load(_ key: KeychainService.Key) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func save(_ value: String, for key: KeychainService.Key) -> Bool {
        lock.lock()
        values[key] = value
        lock.unlock()
        return true
    }
}
