import Foundation
import AuthenticationServices
import CuePhysWeChat

enum MobileLoginMethod: String, CaseIterable, Identifiable {
    case apple, wechat
    var id: Self { self }
    var title: String { self == .apple ? "Apple" : "微信" }
    var provider: AuthProvider { self == .apple ? .apple : .wechat }
    var available: Bool {
        self == .apple || (WeChatAuthorization.configured(appID: AppConfig.wechatAppId,
                                                         link: AppConfig.wechatUniversalLink)
            && AppConfig.hasSecureAccountEndpoint
            && URL(string: AppConfig.wechatUniversalLink)?.host == AppConfig.wechatLinkHost)
    }
}

struct MobileAuthRequest: Encodable {
    var code: String?
    var identityToken: String?
    var authorizationCode: String?
    var displayName: String?
    var age14Confirmed: Bool?
    var createIfMissing: Bool?
    var refreshToken: String?
}

enum AccountIdentityError: LocalizedError {
    case unregistered, conflict
    var errorDescription: String? {
        switch self {
        case .unregistered: return "此登录方式尚未关联 CuePhys 账号"
        case .conflict: return "此登录方式已有绑定。请使用原登录方式，两个账号的训练记录都会保留。"
        }
    }
}

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()
    private var pending: CheckedContinuation<MobileAuthRequest, Error>?
    private var anchorProvider: ApplePresentationAnchor?
    private var controller: ASAuthorizationController?

    private func authorization(_ method: MobileLoginMethod) async throws -> MobileAuthRequest {
        if method == .wechat {
            let code = try await WeChatAuthorization.shared.authorize(appID: AppConfig.wechatAppId,
                                                                    link: AppConfig.wechatUniversalLink)
            return MobileAuthRequest(code: code)
        }
        guard controller == nil else { throw AppError.authFailed("Apple 授权正在进行") }
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .filter({ $0.activationState == .foregroundActive }).flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { throw AppError.authFailed("请回到 App 后重新授权") }
        anchorProvider = ApplePresentationAnchor(window: window)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let active = ASAuthorizationController(authorizationRequests: [request])
        controller = active
        active.delegate = self
        active.presentationContextProvider = anchorProvider
        defer { controller = nil; anchorProvider = nil }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation {
                pending = $0
                active.performRequests()
            }
        } onCancel: {
            Task { @MainActor in
                if self.controller === active { active.cancel() }
            }
        }
    }

    func signIn(_ method: MobileLoginMethod, create: Bool, age14Confirmed: Bool, state: AuthState) async throws -> AppUser {
        guard age14Confirmed, !state.localTrainingOnly else { throw AppError.authFailed(AuthState.localTrainingMessage) }
        #if DEBUG && targetEnvironment(simulator)
        if method == .apple && ProcessInfo.processInfo.arguments.contains("-syncRepair.loginSheet") {
            return AppUser(id: "sync-repair-user", provider: .apple, displayName: "同步测试球友")
        }
        #endif
        guard AppConfig.hasSecureAccountEndpoint else { throw AppError.networkError("账号授权需要 HTTPS 服务") }
        let generation = state.sessionGeneration
        var body = try await authorization(method)
        try Task.checkCancellation()
        guard generation == state.sessionGeneration else { throw CancellationError() }
        guard !state.localTrainingOnly else { throw AppError.authFailed(AuthState.localTrainingMessage) }
        body.age14Confirmed = true
        body.createIfMissing = create
        let response = try await BackendSyncService.shared.login(method, body: body)
        try Task.checkCancellation()
        guard generation == state.sessionGeneration else { throw CancellationError() }
        let user = AppUser(dto: response.user)
        guard !AuthState.requiresLocalTraining(birthday: user.birthDate), !state.localTrainingOnly else {
            state.chooseLocalTrainingForAge()
            throw AppError.authFailed(AuthState.localTrainingMessage)
        }
        guard APIClient.hasAgeDeclaration(response.refreshToken) else { throw AppError.authFailed("账号服务尚未更新，请稍后再试") }
        guard user.provider != .anonymous, APIClient.subject(of: response.accessToken) == user.id,
              APIClient.subject(of: response.refreshToken) == user.id else { throw AppError.authFailed("登录凭据与账号不一致") }
        guard KeychainService.save(key: .accessToken, value: response.accessToken),
              KeychainService.save(key: .refreshToken, value: response.refreshToken) else {
            KeychainService.clearAll()
            throw AppError.authFailed("无法保存登录状态，请重试")
        }
        return user
    }

    func bind(_ method: MobileLoginMethod, state: AuthState) async throws {
        guard state.isLoggedIn, let id = state.currentUser?.id else { throw AppError.authRequired }
        guard AppConfig.hasSecureAccountEndpoint else { throw AppError.networkError("账号授权需要 HTTPS 服务") }
        let generation = state.sessionGeneration
        // Refresh an expired access token on a repeatable read before asking for a single-use code.
        let _: UserDTO = try await APIClient.shared.request(Endpoint(.get, "/user/profile", expectedAccountID: id))
        try Task.checkCancellation()
        guard generation == state.sessionGeneration else { throw CancellationError() }
        var body = try await authorization(method)
        try Task.checkCancellation()
        guard generation == state.sessionGeneration, let refresh = KeychainService.load(key: .refreshToken),
              APIClient.subject(of: refresh) == id else { throw CancellationError() }
        body.refreshToken = refresh
        let user = try await BackendSyncService.shared.bind(method, body: body, accountID: id)
        try Task.checkCancellation()
        guard generation == state.sessionGeneration, user.id == id else { throw CancellationError() }
        state.replaceAuthenticatedUser(AppUser(dto: user))
    }

    private func finish(_ source: ASAuthorizationController, _ result: Result<MobileAuthRequest, Error>) {
        guard controller === source, let pending else { return }
        self.pending = nil
        pending.resume(with: result)
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization auth: ASAuthorization) {
        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }), !token.isEmpty,
              let code = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }), !code.isEmpty else {
            Task { @MainActor in self.finish(controller, .failure(AppError.authFailed("Apple 未返回完整授权凭据"))) }
            return
        }
        let name = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
        let body = MobileAuthRequest(identityToken: token, authorizationCode: code, displayName: name.isEmpty ? nil : name)
        Task { @MainActor in self.finish(controller, .success(body)) }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        Task { @MainActor in
            if cancelled { self.finish(controller, .failure(CancellationError())) }
            else { self.finish(controller, .failure(AppError.authFailed("Apple 授权失败，请重试"))) }
        }
    }
}

private final class ApplePresentationAnchor: NSObject, ASAuthorizationControllerPresentationContextProviding {
    let window: UIWindow
    init(window: UIWindow) { self.window = window }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { window }
}
