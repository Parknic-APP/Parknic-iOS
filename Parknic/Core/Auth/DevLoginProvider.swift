#if DEBUG
/// 개발 전용: Apple 로그인 창 없이 서버의 로컬 전용 `dev:<이름>` 토큰으로 로그인한다(서버가 `parknic.dev-login=true`일 때만 받는다).
/// 시뮬레이터나 Team이 없는 환경에서 서버 연동을 시험하는 용도이며 Release 빌드에는 포함되지 않는다.
struct DevLoginProvider: SocialLoginProvider {
    let provider: AuthProvider = .apple
    var name = "simulator"

    func authenticate() async throws -> SocialCredential {
        SocialCredential(token: "dev:\(name)", authorizationCode: nil)
    }
}
#endif
