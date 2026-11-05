import Foundation

/// 응답 형식은 서버와 확정 전 클라이언트 가정이다(docs/api-spec.md `GET /api/users/me/collection`).
/// 알 수 없는 `parkType`은 건너뛰고, `achievedAt`이 null이면 미달성이다.
struct RemoteCollectionRepository: CollectionRepository {
    private struct TypeDTO: Decodable {
        let parkType: String
        let count: Int
    }
    private struct AchievementDTO: Decodable {
        let code: String
        let name: String
        let label: String
        let achievedAt: Date?
        let progress: Int
        let target: Int
    }
    private struct Response: Decodable {
        let totalBadges: Int
        let visitedParks: Int
        let types: [TypeDTO]
        let achievements: [AchievementDTO]
    }

    let client: APIClient

    func collection() async throws -> BadgeCollection {
        let response: Response = try await client.send(Endpoint(.get, "/api/users/me/collection"))
        var counts: [ParkType: Int] = [:]
        for item in response.types {
            if let type = ParkType(rawValue: item.parkType) { counts[type] = item.count }
        }
        return BadgeCollection(
            totalBadges: response.totalBadges, visitedParks: response.visitedParks, typeCounts: counts,
            achievements: response.achievements.map {
                AchievementProgress(
                    id: $0.code, name: $0.name, label: $0.label, achievedAt: $0.achievedAt,
                    progress: $0.progress, target: $0.target)
            })
    }
}
