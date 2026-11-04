import Foundation

/// 서버 없이 화면을 완성하기 위한 가짜 구현체. 항상 신규 회원으로 로그인된다.
struct MockAuthRepository: AuthRepository {
    var result: Result<LoginResult, APIError> = .success(LoginResult(isNewUser: true))
    var delay: Duration = .milliseconds(400)

    func login(provider: AuthProvider, socialToken: String) async throws -> LoginResult {
        try await Task.sleep(for: delay)
        return try result.get()
    }
}
