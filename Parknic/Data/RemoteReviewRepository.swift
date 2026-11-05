import Foundation

/// 요청·응답 형식은 서버와 확정 전 클라이언트 가정이다(docs/api-spec.md).
struct RemoteReviewRepository: ReviewRepository {
    private struct ReviewDTO: Decodable {
        let id: Int
        let userId: Int
        let nickname: String
        let characterId: Int
        let badgeCount: Int
        let rating: Int
        let content: String
        let createdAt: Date
        let isMine: Bool?

        var review: Review {
            Review(
                id: id, userID: userId, nickname: nickname, characterID: characterId, badgeCount: badgeCount,
                rating: rating, content: content, createdAt: createdAt, isMine: isMine ?? false)
        }
    }
    private struct PageDTO: Decodable {
        let reviews: [ReviewDTO]
        let nextCursor: String?
    }
    private struct WriteRequest: Encodable {
        let rating: Int
        let content: String
    }
    private struct ReportRequest: Encodable { let reason: String }

    let client: APIClient

    func list(parkID: Int, cursor: String?) async throws -> ReviewPage {
        var query = [URLQueryItem(name: "sort", value: "latest")]
        if let cursor { query.append(.init(name: "cursor", value: cursor)) }
        let page: PageDTO = try await client.send(Endpoint(.get, "/api/parks/\(parkID)/reviews", query: query))
        return ReviewPage(reviews: page.reviews.map(\.review), nextCursor: page.nextCursor)
    }

    func create(parkID: Int, rating: Int, content: String) async throws {
        try await client.send(
            Endpoint(.post, "/api/parks/\(parkID)/reviews", body: WriteRequest(rating: rating, content: content)))
    }

    func update(reviewID: Int, rating: Int, content: String) async throws {
        try await client.send(
            Endpoint(.patch, "/api/reviews/\(reviewID)", body: WriteRequest(rating: rating, content: content)))
    }

    func delete(reviewID: Int) async throws {
        try await client.send(Endpoint(.delete, "/api/reviews/\(reviewID)"))
    }

    func report(reviewID: Int, reason: ReportReason) async throws {
        try await client.send(
            Endpoint(.post, "/api/reviews/\(reviewID)/reports", body: ReportRequest(reason: reason.rawValue)))
    }

    func blockUser(userID: Int) async throws {
        try await client.send(Endpoint(.post, "/api/users/\(userID)/block"))
    }
}
