import Foundation
import AuthenticationServices

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    private var appleSignInContinuation: CheckedContinuation<AppUser, Error>?

    // MARK: - Sign in with Apple

    func loginWithApple() async throws -> AppUser {
        return try await withCheckedThrowingContinuation { continuation in
            self.appleSignInContinuation = continuation
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Logout

    func logout() {
        KeychainService.clearAll()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                self.appleSignInContinuation?.resume(throwing: AppError.authFailed("Apple 登录凭证无效"))
                self.appleSignInContinuation = nil
            }
            return
        }

        let userID = credential.user
        let displayName = [
            credential.fullName?.givenName,
            credential.fullName?.familyName
        ].compactMap { $0 }.joined(separator: " ")

        var identityTokenString: String?
        if let tokenData = credential.identityToken {
            identityTokenString = String(data: tokenData, encoding: .utf8)
        }

        Task { @MainActor in
            KeychainService.save(key: .appleUserID, value: userID)
            if let token = identityTokenString {
                KeychainService.save(key: .appleIdentityToken, value: token)
            }

            let user = AppUser(
                id: userID,
                provider: .apple,
                displayName: displayName.isEmpty ? nil : displayName,
                phoneNumber: nil
            )
            self.appleSignInContinuation?.resume(returning: user)
            self.appleSignInContinuation = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            if (error as? ASAuthorizationError)?.code == .canceled {
                self.appleSignInContinuation?.resume(throwing: AppError.authFailed("已取消 Apple 登录"))
            } else {
                self.appleSignInContinuation?.resume(
                    throwing: AppError.authFailed("Apple 登录失败，请重试")
                )
            }
            self.appleSignInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let window = DispatchQueue.main.sync {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
        }
        return window
    }
}
