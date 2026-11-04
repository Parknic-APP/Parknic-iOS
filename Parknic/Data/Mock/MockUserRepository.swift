import Foundation

/// 서버 없이 화면을 완성하기 위한 가짜 구현체. `takenNicknames`에 있는 이름은 중복이다.
struct MockUserRepository: UserRepository {
    var takenNicknames: Set<String> = ["두부산책", "초록발", "오리걸음"]
    var delay: Duration = .milliseconds(300)

    static let characters = [
        AvatarCharacter(id: 1, name: "치즈냥"), AvatarCharacter(id: 2, name: "까망냥"),
        AvatarCharacter(id: 3, name: "삼색냥"), AvatarCharacter(id: 4, name: "턱시도냥"),
        AvatarCharacter(id: 5, name: "시바"), AvatarCharacter(id: 6, name: "말티"),
        AvatarCharacter(id: 7, name: "비글"), AvatarCharacter(id: 8, name: "코기"),
    ]

    func checkNickname(_ nickname: String) async throws -> Bool {
        try await Task.sleep(for: delay)
        return !takenNicknames.contains(nickname)
    }

    func characters() async throws -> [AvatarCharacter] {
        try await Task.sleep(for: delay)
        return Self.characters
    }

    func updateProfile(nickname: String, characterID: Int) async throws {
        try await Task.sleep(for: delay)
        if takenNicknames.contains(nickname) {
            throw APIError.server(status: 409, code: APIErrorCode.nicknameDuplicated.rawValue)
        }
    }
}
