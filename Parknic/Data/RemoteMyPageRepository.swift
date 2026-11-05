import Foundation

/// 응답 형식은 서버와 확정 전 클라이언트 가정이다(docs/api-spec.md의 "마이페이지" 항목).
struct RemoteMyPageRepository: MyPageRepository {
    private struct ProfileDTO: Decodable {
        let nickname: String
        let characterId: Int
        let characterName: String
        let createdAt: Date
    }
    private struct StatsDTO: Decodable {
        let totalBadges: Int
        let visitedParks: Int
        let currentStreak: Int
        let bestStreak: Int
        let podiumParks: Int
    }
    private struct ReviewDTO: Decodable {
        let id: Int
        let parkId: Int
        let parkName: String
        let rating: Int
        let content: String
        let createdAt: Date
    }
    private struct ReviewsDTO: Decodable {
        let reviews: [ReviewDTO]
        let totalCount: Int
        let nextCursor: String?
    }

    let client: APIClient

    func profile() async throws -> UserProfile {
        let dto: ProfileDTO = try await client.send(Endpoint(.get, "/api/users/me"))
        return UserProfile(
            nickname: dto.nickname, characterID: dto.characterId, characterName: dto.characterName, joinedAt: dto.createdAt)
    }

    func stats() async throws -> UserStats {
        let dto: StatsDTO = try await client.send(Endpoint(.get, "/api/users/me/stats"))
        return UserStats(
            totalBadges: dto.totalBadges, visitedParks: dto.visitedParks, currentStreak: dto.currentStreak,
            bestStreak: dto.bestStreak, podiumParks: dto.podiumParks)
    }

    func reviews(cursor: String?) async throws -> MyReviewPage {
        let query = cursor.map { [URLQueryItem(name: "cursor", value: $0)] } ?? []
        let dto: ReviewsDTO = try await client.send(Endpoint(.get, "/api/users/me/reviews", query: query))
        return MyReviewPage(
            reviews: dto.reviews.map {
                MyReview(
                    id: $0.id, parkID: $0.parkId, parkName: $0.parkName, rating: $0.rating, content: $0.content,
                    createdAt: $0.createdAt)
            },
            totalCount: dto.totalCount, nextCursor: dto.nextCursor)
    }
}
