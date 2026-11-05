protocol RankingRepository: Sendable {
    /// 공원의 월간 랭킹과 내 순위
    func ranking(parkID: Int, month: YearMonth) async throws -> ParkRanking
}
