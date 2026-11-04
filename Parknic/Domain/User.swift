protocol UserRepository: Sendable {
    /// 닉네임을 쓸 수 있으면 true, 이미 쓰는 사람이 있으면 false
    func checkNickname(_ nickname: String) async throws -> Bool
    /// 선택 가능한 캐릭터 목록
    func characters() async throws -> [AvatarCharacter]
    /// 온보딩에서 정한 닉네임·캐릭터를 저장한다. 닉네임이 중복이면 `NICKNAME_DUPLICATED`로 실패한다.
    func updateProfile(nickname: String, characterID: Int) async throws
}
