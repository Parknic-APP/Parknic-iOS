import Foundation

/// 서버 없이 화면을 완성하기 위한 가짜 구현체(디자인 12g·08b와 같은 데이터)
struct MockRankingRepository: RankingRepository {
    var delay: Duration = .milliseconds(300)
    /// true면 시상대가 거의 빈 공원(08b)
    var isNearlyEmpty = false

    func ranking(parkID: Int, week: RankingWeek) async throws -> ParkRanking {
        try await Task.sleep(for: delay)
        if isNearlyEmpty {
            return ParkRanking(
                week: week, podium: [RankingEntry(rank: 1, userID: 1, nickname: "대방동주민", characterID: 4, badgeCount: 3)],
                others: [], me: MyRanking(rank: nil, badgeCount: 0))
        }
        let names = ["두부산책", "초록발", "오리걸음", "구름빵", "솜사탕", "아침공기", "펭펭", "호수한바퀴", "산책중독", "밤산책"]
        let counts = [12, 9, 6, 7, 6, 6, 5, 5, 5, 4]
        let ranked = names.indices.map {
            RankingEntry(rank: $0 + 1, userID: $0 + 1, nickname: names[$0], characterID: ($0 % 8) + 1, badgeCount: counts[$0])
        }
        return ParkRanking(
            week: week, podium: Array(ranked.prefix(3)), others: Array(ranked.dropFirst(3)),
            me: MyRanking(rank: 17, badgeCount: 4))
    }
}
