/// 소셜 SDK가 돌려준 자격 증명.
struct SocialCredential: Equatable, Sendable {
    /// Apple identityToken, 카카오 accessToken 등
    let token: String
    /// Apple만 쓴다. 서버가 이 코드로 Apple refresh token을 받아 두었다가 회원 탈퇴 때 revoke한다.
    var authorizationCode: String?
}

/// 소셜 SDK 래퍼.
@MainActor
protocol SocialLoginProvider {
    var provider: AuthProvider { get }
    func authenticate() async throws -> SocialCredential
}

enum SocialLoginError: Error, Equatable {
    /// 사용자가 로그인 창을 닫았다. 에러로 보여주지 않는다.
    case cancelled
    case failed
}
