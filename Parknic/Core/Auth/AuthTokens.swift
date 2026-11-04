import Foundation

/// 서버가 발급한 JWT 한 쌍
struct AuthTokens: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
}

/// 토큰 저장소. 운영에서는 Keychain, 테스트에서는 메모리 구현을 쓴다.
protocol TokenStore: Sendable {
    func load() -> AuthTokens?
    func save(_ tokens: AuthTokens) throws
    func clear()
}
