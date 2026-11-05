import Foundation

/// 서버 없이 화면을 완성하기 위한 가짜 구현체(메모리에만 저장). 디자인 08c의 리뷰를 담고 있다.
actor MockReviewRepository: ReviewRepository {
    private var reviews: [Review]
    private var blockedUserIDs: Set<Int> = []
    private var nextID = 100
    private let pageSize: Int
    private let delay: Duration

    init(delay: Duration = .milliseconds(300), pageSize: Int = 10, reviews: [Review]? = nil) {
        self.delay = delay
        self.pageSize = pageSize
        self.reviews = reviews ?? MockReviewRepository.sample
    }

    static var sample: [Review] {
        let now = Date()
        func ago(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }
        return [
            Review(id: 1, userID: 7, nickname: "두부산책", characterID: 5, badgeCount: 47, rating: 5, content: "아침 7시쯤 오면 정말 조용해요. 호수 한 바퀴 돌면 딱 20분이라 배지 받기 좋아요.", createdAt: ago(2), isMine: false),
            Review(id: 2, userID: 11, nickname: "구름빵", characterID: 6, badgeCount: 12, rating: 4, content: "벤치가 많아서 쉬기 좋아요. 주말 오후엔 사람이 꽤 많으니 참고하세요.", createdAt: ago(5), isMine: false),
            Review(id: 3, userID: 1, nickname: "나뭇잎", characterID: 1, badgeCount: 23, rating: 5, content: "그늘이 많아서 한낮에도 산책하기 괜찮아요.", createdAt: ago(8), isMine: true),
            Review(id: 4, userID: 9, nickname: "오리걸음", characterID: 8, badgeCount: 31, rating: 5, content: "강아지랑 오기 좋아요. 잔디밭이 넓어서 뛰어놀기 좋습니다.", createdAt: ago(20), isMine: false),
        ]
    }

    func list(parkID: Int, cursor: String?) async throws -> ReviewPage {
        try await Task.sleep(for: delay)
        let visible = reviews.filter { !blockedUserIDs.contains($0.userID) }.sorted { $0.createdAt > $1.createdAt }
        let start = cursor.flatMap(Int.init) ?? 0
        let end = min(start + pageSize, visible.count)
        let slice = start < end ? Array(visible[start..<end]) : []
        return ReviewPage(reviews: slice, nextCursor: end < visible.count ? String(end) : nil)
    }

    func create(parkID: Int, rating: Int, content: String) async throws {
        try await Task.sleep(for: delay)
        if reviews.contains(where: \.isMine) { throw APIError.server(status: 409, code: APIErrorCode.reviewAlreadyExists.rawValue) }
        nextID += 1
        reviews.append(Review(id: nextID, userID: 1, nickname: "나뭇잎", characterID: 1, badgeCount: 4, rating: rating, content: content, createdAt: Date(), isMine: true))
    }

    func update(reviewID: Int, rating: Int, content: String) async throws {
        try await Task.sleep(for: delay)
        guard let index = reviews.firstIndex(where: { $0.id == reviewID }) else { throw APIError.server(status: 404, code: nil) }
        let old = reviews[index]
        reviews[index] = Review(id: old.id, userID: old.userID, nickname: old.nickname, characterID: old.characterID, badgeCount: old.badgeCount, rating: rating, content: content, createdAt: old.createdAt, isMine: old.isMine)
    }

    func delete(reviewID: Int) async throws {
        try await Task.sleep(for: delay)
        reviews.removeAll { $0.id == reviewID }
    }

    func report(reviewID: Int, reason: ReportReason) async throws {
        try await Task.sleep(for: delay)
    }

    func blockUser(userID: Int) async throws {
        try await Task.sleep(for: delay)
        blockedUserIDs.insert(userID)
    }
}
