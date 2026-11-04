/// 소셜 로그인 제공자. 서버 `/api/auth/login/{provider}`의 값과 같다.
enum AuthProvider: String, CaseIterable, Sendable {
    case apple
    case kakao
    case google
}

struct LoginResult: Equatable, Sendable {
    /// true면 온보딩(닉네임·캐릭터)으로 보낸다.
    let isNewUser: Bool
}

protocol AuthRepository: Sendable {
    /// 소셜 SDK 토큰을 서버로 보내 로그인하고, 받은 서버 토큰을 저장한다.
    func login(provider: AuthProvider, socialToken: String) async throws -> LoginResult
}
