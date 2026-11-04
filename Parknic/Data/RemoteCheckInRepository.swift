import Foundation

/// 요청·응답 형식은 서버와 확정 전 클라이언트 가정이다(docs/api-spec.md).
struct RemoteCheckInRepository: CheckInRepository {
    private struct StartRequest: Encodable {
        let parkId: Int
        let lat: Double
        let lng: Double
    }
    private struct CompleteRequest: Encodable {
        let lat: Double?
        let lng: Double?
    }
    private struct FailRequest: Encodable { let reason: String }

    private struct SessionDTO: Decodable {
        let id: Int
        let parkId: Int
        let parkName: String
        let latitude: Double
        let longitude: Double
        let radiusM: Double
        let startedAt: Date

        var session: CheckInSession {
            CheckInSession(
                id: id, parkID: parkId, parkName: parkName,
                center: Coordinate(latitude: latitude, longitude: longitude), radiusM: radiusM, startedAt: startedAt)
        }
    }

    private struct ResultDTO: Decodable {
        struct Badge: Decodable {
            let parkId: Int
            let parkName: String
            let parkType: ParkType
            let earnedAt: Date
        }
        struct Achievement: Decodable { let code: String; let name: String }
        struct Ranking: Decodable {
            let rank: Int
            let badgeCount: Int
            let rankChange: Int
            let badgesToPodium: Int
        }
        let badge: Badge
        let newAchievements: [Achievement]
        let monthlyRanking: Ranking
        let canWriteReview: Bool

        var result: CheckInResult {
            CheckInResult(
                badge: EarnedBadge(
                    parkID: badge.parkId, parkName: badge.parkName, parkType: badge.parkType, earnedAt: badge.earnedAt),
                newAchievements: newAchievements.map { Parknic.Achievement(code: $0.code, name: $0.name) },
                monthlyRanking: MonthlyRankingSummary(
                    rank: monthlyRanking.rank, badgeCount: monthlyRanking.badgeCount,
                    rankChange: monthlyRanking.rankChange, badgesToPodium: monthlyRanking.badgesToPodium),
                canWriteReview: canWriteReview)
        }
    }

    let client: APIClient

    func start(parkID: Int, at coordinate: Coordinate) async throws -> CheckInSession {
        let endpoint = try Endpoint(
            .post, "/api/check-ins", body: StartRequest(parkId: parkID, lat: coordinate.latitude, lng: coordinate.longitude))
        let dto: SessionDTO = try await client.send(endpoint)
        return dto.session
    }

    func current() async throws -> CheckInSession? {
        do {
            let dto: SessionDTO = try await client.send(Endpoint(.get, "/api/check-ins/current"))
            return dto.session
        } catch APIError.server(status: 404, _) {
            return nil
        }
    }

    func complete(sessionID: Int, at coordinate: Coordinate?) async throws -> CheckInResult {
        let endpoint = try Endpoint(
            .post, "/api/check-ins/\(sessionID)/complete",
            body: CompleteRequest(lat: coordinate?.latitude, lng: coordinate?.longitude))
        let dto: ResultDTO = try await client.send(endpoint)
        return dto.result
    }

    func fail(sessionID: Int, reason: CheckInFailureReason) async throws {
        let endpoint = try Endpoint(
            .post, "/api/check-ins/\(sessionID)/fail", body: FailRequest(reason: reason.rawValue))
        try await client.send(endpoint)
    }

    func cancel(sessionID: Int) async throws {
        try await client.send(Endpoint(.post, "/api/check-ins/\(sessionID)/cancel"))
    }
}
