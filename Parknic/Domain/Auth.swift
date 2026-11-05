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
    /// 로그아웃. 서버 호출이 실패해도 기기의 토큰은 항상 지운다.
    func logout() async
    /// 회원 탈퇴(앱 안에서 가능해야 한다). 서버가 Apple 토큰을 해제한다. 성공하면 기기의 토큰을 지운다.
    func deleteAccount() async throws
}
