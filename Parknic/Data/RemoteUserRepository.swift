import Foundation

struct RemoteUserRepository: UserRepository {
    // 응답 형식은 서버와 확정 전 클라이언트 가정이다(docs/api-spec.md).
    private struct NicknameCheckResponse: Decodable { let available: Bool }

    let client: APIClient

    func checkNickname(_ nickname: String) async throws -> Bool {
        let endpoint = Endpoint(.get, "/api/users/nickname/check", query: [.init(name: "nickname", value: nickname)])
        do {
            let response: NicknameCheckResponse = try await client.send(endpoint)
            return response.available
        } catch let error as APIError where error.serverCode == .nicknameDuplicated {
            return false
        }
    }
}
