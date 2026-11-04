protocol UserRepository: Sendable {
    /// 닉네임을 쓸 수 있으면 true, 이미 쓰는 사람이 있으면 false
    func checkNickname(_ nickname: String) async throws -> Bool
}
