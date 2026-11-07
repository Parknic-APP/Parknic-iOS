import AuthenticationServices
import UIKit

/// Sign in with Apple. 서버로 보낼 identityToken과 authorizationCode(탈퇴 시 토큰 revoke용)를 돌려준다.
@MainActor
final class AppleLoginProvider: NSObject, SocialLoginProvider {
    let provider = AuthProvider.apple
    private var continuation: CheckedContinuation<SocialCredential, Error>?

    func authenticate() async throws -> SocialCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    #if DEBUG
    /// 마지막 Apple 로그인 실패의 오류 도메인과 코드(Debug 전용).
    static var lastDebugError: String?
    #endif

    private func finish(_ result: Result<SocialCredential, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

extension AppleLoginProvider: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let data = credential.identityToken,
            let token = String(data: data, encoding: .utf8)
        else {
            finish(.failure(SocialLoginError.failed))
            return
        }
        let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        finish(.success(SocialCredential(token: token, authorizationCode: code)))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        #if DEBUG
        // 개발용: 원인을 알 수 있게 오류 코드를 남긴다(화면 문구 뒤에 붙는다). Release에는 없다.
        let nsError = error as NSError
        Self.lastDebugError = "\(nsError.domain) \(nsError.code)"
        #endif
        finish(.failure(cancelled ? SocialLoginError.cancelled : SocialLoginError.failed))
    }
}

extension AppleLoginProvider: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
