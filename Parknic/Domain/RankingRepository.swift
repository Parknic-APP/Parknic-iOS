protocol RankingRepository: Sendable {
    /// 공원의 주간 랭킹과 내 순위
    func ranking(parkID: Int, week: RankingWeek) async throws -> ParkRanking
}
