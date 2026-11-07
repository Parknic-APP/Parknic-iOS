import Foundation

/// 응답 형식은 docs/api-spec.md의 랭킹 응답 예를 따른다. `me`가 없거나 `rank`가 null이면 이번 주 배지가 없는 것이다.
struct RemoteRankingRepository: RankingRepository {
    private struct EntryDTO: Decodable {
        let rank: Int
        let userId: Int
        let nickname: String
        let characterId: Int
        let badgeCount: Int

        var entry: RankingEntry {
            RankingEntry(rank: rank, userID: userId, nickname: nickname, characterID: characterId, badgeCount: badgeCount)
        }
    }
    private struct MeDTO: Decodable {
        let rank: Int?
        let badgeCount: Int
    }
    private struct Response: Decodable {
        let podium: [EntryDTO]
        let others: [EntryDTO]
        let me: MeDTO?
    }

    let client: APIClient

    func ranking(parkID: Int, week: RankingWeek) async throws -> ParkRanking {
        let endpoint = Endpoint(.get, "/api/parks/\(parkID)/rankings", query: [.init(name: "week", value: week.apiValue)])
        let response: Response = try await client.send(endpoint)
        return ParkRanking(
            week: week, podium: response.podium.map(\.entry).sorted { $0.rank < $1.rank },
            others: response.others.map(\.entry).sorted { $0.rank < $1.rank },
            me: response.me.map { MyRanking(rank: $0.rank, badgeCount: $0.badgeCount) })
    }
}
