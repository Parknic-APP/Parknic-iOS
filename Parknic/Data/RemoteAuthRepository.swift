import Foundation

/// 실제 서버 구현체. 로그인 성공 시 서버 JWT를 Keychain에 저장한다.
struct RemoteAuthRepository: AuthRepository {
    private struct Request: Encodable {
        let token: String
        let authorizationCode: String?
    }
    private struct Response: Decodable {
        let accessToken: String
        let refreshToken: String
        let isNewUser: Bool
    }

    let client: APIClient
    let tokenStore: TokenStore

    func login(provider: AuthProvider, socialToken: String, authorizationCode: String?) async throws -> LoginResult {
        let endpoint = try Endpoint(
            .post, "/api/auth/login/\(provider.rawValue)", body: Request(token: socialToken, authorizationCode: authorizationCode), requiresAuth: false)
        let response: Response = try await client.send(endpoint)
        do {
            try tokenStore.save(AuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken))
        } catch {
            throw APIError.invalidRequest
        }
        return LoginResult(isNewUser: response.isNewUser)
    }

    func logout() async {
        // 서버에서 Refresh 토큰을 지우도록 요청하되, 실패해도 기기에서는 로그아웃한다.
        try? await client.send(Endpoint(.post, "/api/auth/logout"))
        tokenStore.clear()
    }

    func deleteAccount() async throws {
        try await client.send(Endpoint(.delete, "/api/users/me"))
        tokenStore.clear()
    }
}
