import Foundation
import WechatOpenSDK

@MainActor
public final class WeChatAuthorization: NSObject, WXApiDelegate {
    public static let shared = WeChatAuthorization()
    private var pending: (state: String, continuation: CheckedContinuation<String, Error>)?
    private var timeout: Task<Void, Never>?
    private var registeredID: String?
    private var callbackBase: URL?

    public nonisolated static func configured(appID: String, link: String) -> Bool {
        guard appID.range(of: #"^wx[0-9a-fA-F]{16}$"#, options: .regularExpression) != nil,
              let url = URL(string: link), url.scheme == "https", url.host != nil,
              url.host != "yourdomain.com", url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, link.hasSuffix("/") else { return false }
        return true
    }

    public func authorize(appID: String, link: String) async throws -> String {
        guard Self.configured(appID: appID, link: link) else { throw Failure.unavailable }
        if registeredID != appID || callbackBase?.absoluteString != link {
            guard WXApi.registerApp(appID, universalLink: link) else { throw Failure.unavailable }
            registeredID = appID
            callbackBase = URL(string: link)
        }
        guard WXApi.isWXAppInstalled() else { throw Failure.notInstalled }
        guard pending == nil else { throw Failure.busy }
        let state = UUID().uuidString
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                pending = (state, continuation)
                timeout = Task {
                    do { try await Task.sleep(for: .seconds(120)) } catch { return }
                    finish(state, .failure(Failure.expired))
                }
                let request = SendAuthReq()
                request.scope = "snsapi_userinfo"
                request.state = state
                WXApi.send(request) { sent in
                    if !sent { Task { @MainActor in self.finish(state, .failure(Failure.unavailable)) } }
                }
            }
        } onCancel: {
            Task { @MainActor in self.finish(state, .failure(CancellationError())) }
        }
    }

    public func handle(url: URL) {
        guard pending != nil, url.scheme == registeredID else { return }
        _ = WXApi.handleOpen(url, delegate: self)
    }

    public func handle(activity: NSUserActivity) {
        guard pending != nil, let url = activity.webpageURL, let base = callbackBase,
              url.scheme == "https", url.host == base.host, url.port == base.port,
              url.path == base.path || url.path.hasPrefix(base.path.hasSuffix("/") ? base.path : base.path + "/") else { return }
        _ = WXApi.handleOpenUniversalLink(activity, delegate: self)
    }

    public nonisolated func onResp(_ response: BaseResp) {
        guard let auth = response as? SendAuthResp, let state = auth.state else { return }
        let code = auth.code
        let result = auth.errCode
        Task { @MainActor in
            if result == -2 { self.finish(state, .failure(CancellationError())) }
            else if result == 0, let code, !code.isEmpty { self.finish(state, .success(code)) }
            else { self.finish(state, .failure(Failure.denied)) }
        }
    }

    private func finish(_ state: String, _ result: Result<String, Error>) {
        guard let active = pending, active.state == state else { return }
        pending = nil
        timeout?.cancel()
        timeout = nil
        active.continuation.resume(with: result)
    }

    private enum Failure: LocalizedError {
        case unavailable, notInstalled, busy, expired, denied
        var errorDescription: String? {
            switch self {
            case .unavailable: return "微信登录暂不可用"
            case .notInstalled: return "请先安装微信，再回来授权"
            case .busy: return "微信授权正在进行"
            case .expired: return "微信授权已超时，请重新尝试"
            case .denied: return "微信未授权，请重新尝试"
            }
        }
    }
}
