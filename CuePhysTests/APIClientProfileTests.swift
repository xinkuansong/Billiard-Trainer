import XCTest
@testable import QiuJi

final class APIClientProfileTests: XCTestCase {
    private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
        struct Stub: @unchecked Sendable {
            let statusCode: Int
            let headers: [String: String]
            let data: Data
            var beforeResponse: (() -> Void)? = nil
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
            current.beforeResponse?()
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

    func testReleaseAPIConfigurationOnlyAllowsCompanyHTTPS() {
        let rejected: [String?] = [nil, "", "relative/path", "$(API_BASE_URL)", "http://api.cuephys.com",
            "https://api.qiuji.app", "https://badcuephys.com", "https://cuephys.com.invalid",
            "https://user:pass@api.cuephys.com", "https://.cuephys.com", "https://bad-.cuephys.com",
            "https://api.cuephys.com?token=value", "https://cuephys.com/#fragment", "https://cuephys.com:99999"]
        for raw in rejected { XCTAssertNil(AppConfig.validatedAPIBaseURL(raw, release: true), raw ?? "nil") }
        for raw in ["https://cuephys.com", "https://api.cuephys.com:443/v1"] {
            XCTAssertEqual(AppConfig.validatedAPIBaseURL(raw, release: true)?.absoluteString, raw)
        }
        XCTAssertNotNil(AppConfig.validatedAPIBaseURL("http://127.0.0.1:3000", release: false))
    }

    func testMisconfiguredAPIRejectsSyncLoginAndRefreshWithoutSendingRequests() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let unavailable = APIClient(baseURL: nil, session: URLSession(configuration: configuration), tokenStore: tokenStore)
        for endpoint in [Endpoint(.get, "/user/profile"), Endpoint(.post, "/auth/refresh"),
                         Endpoint(.post, "/auth/login-wechat"), Endpoint(.post, "/auth/bind-apple")] {
            StubURLProtocol.configure([])
            do {
                _ = try await unavailable.requestData(endpoint)
                XCTFail("Unconfigured endpoint must fail")
            } catch AppError.networkError {
                XCTAssertNil(StubURLProtocol.requestSnapshot())
            }
        }
    }

    private func accountToken(_ id: String) -> String {
        let payload = Data(("{\"sub\":\"" + id + "\"}").utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        return "header." + payload + ".signature"
    }

    func testAppleAccountBindsWeChatAndSignsInWithWeChat() async throws {
        try await verifyBinding(from: .apple, to: .wechat)
    }

    func testWeChatAccountBindsAppleAndSignsInWithApple() async throws {
        try await verifyBinding(from: .wechat, to: .apple)
    }

    private func verifyBinding(from first: MobileLoginMethod, to second: MobileLoginMethod) async throws {
        let service = BackendSyncService(api: client)
        let id = "fixture-account"
        let user = ["id": id, "provider": first.rawValue]
        let linked: [String: Any] = ["id": id, "provider": first.rawValue, "linkedProviders": [first.rawValue, second.rawValue]]
        func respond(_ payload: [String: Any]) throws {
            StubURLProtocol.configure(.init(statusCode: 200, headers: [:], data: try JSONSerialization.data(withJSONObject: payload)))
        }
        func grant(_ method: MobileLoginMethod) -> MobileAuthRequest {
            method == .apple ? MobileAuthRequest(identityToken: "apple-token", authorizationCode: "apple-code")
                             : MobileAuthRequest(code: "wechat-code")
        }
        func loginResponse(_ profile: [String: Any]) -> [String: Any] {
            ["user": profile, "accessToken": accountToken(id), "refreshToken": accountToken(id)]
        }

        try respond(loginResponse(user))
        let original = try await service.login(first, body: grant(first))
        XCTAssertEqual(AppUser(dto: original.user).linkedProviders, [first.provider])
        XCTAssertEqual(StubURLProtocol.requestSnapshot()?.url?.path, "/auth/login-" + first.rawValue)
        tokenStore.save(original.accessToken, for: .accessToken)

        try respond(["user": linked])
        var binding = grant(second)
        binding.refreshToken = original.refreshToken
        let result = try await service.bind(second, body: binding, accountID: original.user.id)
        XCTAssertEqual(result.id, original.user.id)
        XCTAssertEqual(AppUser(dto: result).linkedProviders, [first.provider, second.provider])
        XCTAssertEqual(StubURLProtocol.requestSnapshot()?.url?.path, "/auth/bind-" + second.rawValue)
        let data = try XCTUnwrap(StubURLProtocol.bodySnapshot())
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(body["refreshToken"], original.refreshToken)
        XCTAssertEqual(body["code"], binding.code)
        XCTAssertEqual(body["authorizationCode"], binding.authorizationCode)
        XCTAssertEqual(body["identityToken"], binding.identityToken)

        try respond(loginResponse(linked))
        let nextLogin = try await service.login(second, body: grant(second))
        XCTAssertEqual(nextLogin.user.id, original.user.id)
        XCTAssertEqual(StubURLProtocol.requestSnapshot()?.url?.path, "/auth/login-" + second.rawValue)
        XCTAssertNil(StubURLProtocol.requestSnapshot()?.value(forHTTPHeaderField: "Authorization"))
    }

    func testTrainingSyncDoesNotSendAfterCredentialSwitch() async throws {
        let service = BackendSyncService(api: client)
        tokenStore.save(accountToken("new-account"), for: .accessToken)
        StubURLProtocol.configure(.init(statusCode: 200, headers: [:], data: Data()))
        do {
            try await service.deleteSession(clientId: UUID().uuidString, accountID: "old-account")
            XCTFail("A queued deletion belonging to the old account was sent")
        } catch is CancellationError {}
        XCTAssertNil(StubURLProtocol.requestSnapshot())
    }

    func testSyncDisabledWhileRefreshingPreventsRetry() async throws {
        // Revoke sync after the original request returned 401, while refresh is in flight.
        let choice = TestTokenStore()
        choice.save("on", for: .accessToken)
        let token = accountToken("account")
        tokenStore.save(token, for: .accessToken)
        tokenStore.save("original-refresh", for: .refreshToken)
        let refreshed = try JSONEncoder().encode(["accessToken": token, "refreshToken": "renewed"])
        StubURLProtocol.configure([
            .init(statusCode: 401, headers: [:], data: Data()),
            .init(statusCode: 200, headers: [:], data: refreshed, beforeResponse: {
                choice.save("off", for: .accessToken)
            }),
            .init(statusCode: 200, headers: [:], data: Data()),
        ])
        do {
            try await APIClient.$syncIsCurrent.withValue({ choice.load(.accessToken) == "on" }) {
                try await BackendSyncService(api: client).deleteSession(clientId: "fixture", accountID: "account")
            }
            XCTFail("A disabled sync request was replayed")
        } catch is CancellationError {
            XCTAssertEqual(StubURLProtocol.requestSnapshot()?.url?.path, "/auth/refresh")
        }
    }

    func testBindingRejectsAccountSwitchBeforeSendingCode() async throws {
        tokenStore.save(accountToken("new"), for: .accessToken)
        StubURLProtocol.configure([])
        do {
            let _: EmptyResponse = try await client.request(Endpoint(.post, "/auth/bind-wechat",
                body: MobileAuthRequest(code: "fixture"), expectedAccountID: "old"))
            XCTFail("Account changed during authorization")
        } catch is CancellationError { XCTAssertNil(StubURLProtocol.requestSnapshot()) }
    }

    func testBindingConflictLeavesSessionIntact() async throws {
        tokenStore.save(accountToken("original"), for: .accessToken)
        tokenStore.save("original-refresh", for: .refreshToken)
        StubURLProtocol.configure(.init(statusCode: 409, headers: [:],
            data: Data(#"{"code":"IDENTITY_CONFLICT","message":"已绑定"}"#.utf8)))
        do {
            let _: EmptyResponse = try await client.request(Endpoint(.post, "/auth/bind-apple",
                body: MobileAuthRequest(authorizationCode: "fixture", refreshToken: "original-refresh"),
                expectedAccountID: "original"))
            XCTFail("Expected conflict")
        } catch AccountIdentityError.conflict {
            XCTAssertEqual(tokenStore.load(.refreshToken), "original-refresh")
            XCTAssertEqual(StubURLProtocol.requestSnapshot()?.value(forHTTPHeaderField: "Authorization"),
                           "Bearer " + accountToken("original"))
        }
    }

    func testUnknownWeChatLoginOffersChoiceAndSendsNoExistingBearer() async throws {
        tokenStore.save(accountToken("existing"), for: .accessToken)
        StubURLProtocol.configure(.init(statusCode: 409, headers: [:],
            data: Data(#"{"code":"IDENTITY_NOT_REGISTERED","message":"请选择"}"#.utf8)))
        do {
            let _: AuthResponse = try await client.request(Endpoint(.post, "/auth/login-wechat",
                body: MobileAuthRequest(code: "fixture", createIfMissing: false)))
            XCTFail("Expected registration choice")
        } catch AccountIdentityError.unregistered {
            XCTAssertNil(StubURLProtocol.requestSnapshot()?.value(forHTTPHeaderField: "Authorization"))
            let body = try XCTUnwrap(StubURLProtocol.bodySnapshot())
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["createIfMissing"] as? Bool, false)
        }
    }

    func testBinding401DoesNotReplaySingleUseCode() async throws {
        tokenStore.save(accountToken("a"), for: .accessToken)
        tokenStore.save("still-current", for: .refreshToken)
        StubURLProtocol.configure(.init(statusCode: 401, headers: [:], data: Data()))
        do {
            let _: EmptyResponse = try await client.request(Endpoint(.post, "/auth/bind-wechat", expectedAccountID: "a"))
            XCTFail("Expected denial")
        } catch AppError.serverError(let status, _) {
            XCTAssertEqual(status, 401)
            XCTAssertEqual(StubURLProtocol.requestSnapshot()?.url?.path, "/auth/bind-wechat")
            XCTAssertEqual(tokenStore.load(.refreshToken), "still-current")
        }
    }

    func testFormationRequestRejectsAnotherAccountBeforeSending() async {
        tokenStore.save(accountToken("b"), for: .accessToken)
        StubURLProtocol.configure([])
        do {
            let _: EmptyResponse = try await client.request(Endpoint(.put, "/custom-formations/test", expectedAccountID: "a"))
            XCTFail("Must reject another account")
        } catch is CancellationError { XCTAssertNil(StubURLProtocol.requestSnapshot()) }
        catch { XCTFail("Unexpected error: \(error)") }
    }
    func testFormationRetryCannotSendPayloadWithAnotherAccountsToken() async {
        tokenStore.save(accountToken("a"), for: .accessToken)
        tokenStore.save("refresh-a", for: .refreshToken)
        let response = "{\"accessToken\":\"" + accountToken("b") + "\",\"refreshToken\":\"refresh-b\"}"
        StubURLProtocol.configure([
            .init(statusCode: 401, headers: [:], data: Data()),
            .init(statusCode: 200, headers: [:], data: Data(response.utf8))
        ])
        do {
            let _: EmptyResponse = try await client.request(Endpoint(.put, "/custom-formations/test", expectedAccountID: "a"))
            XCTFail("Must not retry against a different account")
        } catch is CancellationError { XCTAssertEqual(StubURLProtocol.requestSnapshot()?.url?.path, "/auth/refresh") }
        catch { XCTFail("Unexpected error: \(error)") }
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

    func testOldUnauthorizedResponseCannotInvalidateNewLogin() async {
        tokenStore.save("old-refresh", for: .refreshToken)
        let store = tokenStore!
        StubURLProtocol.configure(.init(statusCode: 401, headers: [:], data: Data(), beforeResponse: {
            store.save("interactive-refresh", for: .refreshToken)
        }))
        do {
            let _: UserDTO = try await client.request(Endpoint(.get, "/user/profile"))
            XCTFail("Old response should be cancelled")
        } catch is CancellationError {
            XCTAssertEqual(store.load(.refreshToken), "interactive-refresh")
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    func testOldRefreshCannotOverwriteNewLoginCredentials() async {
        tokenStore.save("old-refresh", for: .refreshToken)
        let store = tokenStore!
        StubURLProtocol.configure([
            .init(statusCode: 401, headers: [:], data: Data()),
            .init(statusCode: 200, headers: [:],
                  data: Data(#"{"accessToken":"stale-access","refreshToken":"stale-refresh"}"#.utf8),
                  beforeResponse: {
                      store.save("interactive-access", for: .accessToken)
                      store.save("interactive-refresh", for: .refreshToken)
                  })
        ])
        do {
            let _: UserDTO = try await client.request(Endpoint(.get, "/user/profile"))
            XCTFail("Old refresh should be cancelled")
        } catch is CancellationError {
            XCTAssertEqual(store.load(.accessToken), "interactive-access")
            XCTAssertEqual(store.load(.refreshToken), "interactive-refresh")
        } catch { XCTFail("Unexpected error: \(error)") }
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
