import Foundation

/// 실제 서버 구현체. 로그인 성공 시 서버 JWT를 Keychain에 저장한다.
struct RemoteAuthRepository: AuthRepository {
    private struct Request: Encodable { let token: String }
    private struct Response: Decodable {
        let accessToken: String
        let refreshToken: String
        let isNewUser: Bool
    }

    let client: APIClient
    let tokenStore: TokenStore

    func login(provider: AuthProvider, socialToken: String) async throws -> LoginResult {
        let endpoint = try Endpoint(
            .post, "/api/auth/login/\(provider.rawValue)", body: Request(token: socialToken), requiresAuth: false)
        let response: Response = try await client.send(endpoint)
        do {
            try tokenStore.save(AuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken))
        } catch {
            throw APIError.invalidRequest
        }
        return LoginResult(isNewUser: response.isNewUser)
    }
}
