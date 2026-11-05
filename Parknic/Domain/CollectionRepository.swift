protocol CollectionRepository: Sendable {
    /// 내 배지 도감
    func collection() async throws -> BadgeCollection
}
