/// 소셜 SDK 래퍼. SDK 토큰(Apple identityToken, 카카오 accessToken 등)을 돌려준다.
@MainActor
protocol SocialLoginProvider {
    var provider: AuthProvider { get }
    func authenticate() async throws -> String
}

enum SocialLoginError: Error, Equatable {
    /// 사용자가 로그인 창을 닫았다. 에러로 보여주지 않는다.
    case cancelled
    case failed
}
