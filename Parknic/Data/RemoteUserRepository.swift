import Foundation

struct RemoteUserRepository: UserRepository {
    // 응답·요청 형식은 서버와 확정 전 클라이언트 가정이다(docs/api-spec.md).
    private struct NicknameCheckResponse: Decodable { let available: Bool }
    private struct CharactersResponse: Decodable {
        struct Item: Decodable { let id: Int; let name: String }
        let characters: [Item]
    }
    private struct ProfileRequest: Encodable {
        let nickname: String
        let characterId: Int
    }

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

    func characters() async throws -> [AvatarCharacter] {
        let response: CharactersResponse = try await client.send(Endpoint(.get, "/api/characters"))
        return response.characters.map { AvatarCharacter(id: $0.id, name: $0.name) }
    }

    func updateProfile(nickname: String, characterID: Int) async throws {
        let endpoint = try Endpoint(
            .patch, "/api/users/me", body: ProfileRequest(nickname: nickname, characterId: characterID))
        try await client.send(endpoint)
    }
}
