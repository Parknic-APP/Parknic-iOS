import XCTest
@testable import Parknic

private func review(_ id: Int, user: Int? = nil, mine: Bool = false) -> Review {
    Review(id: id, userID: user ?? id, nickname: "유저\(id)", characterID: 1, badgeCount: 1, rating: 5, content: "내용\(id)", createdAt: Date(timeIntervalSince1970: 1_000_000 - Double(id)), isMine: mine)
}

private final class PagingRepository: ReviewRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _cursors: [String?] = []
    private var _reported: [(Int, ReportReason)] = []
    private var _blocked: [Int] = []
    var pages: [String?: ReviewPage] = [:]
    var error: APIError?
    var failCursor: String?
    var actionError: APIError?

    var cursors: [String?] { lock.withLock { _cursors } }
    var reported: [(Int, ReportReason)] { lock.withLock { _reported } }
    var blocked: [Int] { lock.withLock { _blocked } }

    func list(parkID: Int, cursor: String?) async throws -> ReviewPage {
        lock.withLock { _cursors.append(cursor) }
        if let error { throw error }
        if let failCursor, cursor == failCursor { throw APIError.network }
        return pages[cursor] ?? ReviewPage(reviews: [], nextCursor: nil)
    }
    func create(parkID: Int, rating: Int, content: String) async throws {}
    func update(reviewID: Int, rating: Int, content: String) async throws {}
    func delete(reviewID: Int) async throws {}
    func report(reviewID: Int, reason: ReportReason) async throws {
        if let actionError { throw actionError }
        lock.withLock { _reported.append((reviewID, reason)) }
    }
    func blockUser(userID: Int) async throws {
        if let actionError { throw actionError }
        lock.withLock { _blocked.append(userID) }
    }
}

@MainActor
final class ReviewListViewModelTests: XCTestCase {
    private func make(_ repository: PagingRepository) -> ReviewListViewModel {
        ReviewListViewModel(parkID: 1, parkName: "보라매공원", repository: repository)
    }

    private func twoPages() -> PagingRepository {
        let repository = PagingRepository()
        repository.pages[nil] = ReviewPage(reviews: (1...5).map { review($0) }, nextCursor: "c1")
        repository.pages["c1"] = ReviewPage(reviews: (6...8).map { review($0) }, nextCursor: nil)
        return repository
    }

    func test_첫_페이지를_불러온다() async {
        let model = make(twoPages())
        await model.load()
        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.reviews.count, 5)
        XCTAssertTrue(model.hasMore)
    }

    func test_리뷰가_없으면_빈_상태다() async {
        let model = make(PagingRepository())
        await model.load()
        XCTAssertEqual(model.state, .empty)
    }

    func test_불러오기에_실패하면_에러이고_재시도로_복구된다() async {
        let repository = twoPages()
        repository.error = .network
        let model = make(repository)
        await model.load()
        XCTAssertEqual(model.state, .failed(APIError.network.userMessage))
        repository.error = nil
        await model.load()
        XCTAssertEqual(model.state, .loaded)
    }

    func test_끝에_가까운_리뷰가_보이면_다음_페이지를_불러온다() async {
        let repository = twoPages()
        let model = make(repository)
        await model.load()
        await model.loadMoreIfNeeded(currentItem: model.reviews[0])
        XCTAssertEqual(repository.cursors.count, 1, "첫 리뷰에서는 미리 불러오지 않는다")

        await model.loadMoreIfNeeded(currentItem: model.reviews[3])
        XCTAssertEqual(model.reviews.count, 8)
        XCTAssertFalse(model.hasMore)
        XCTAssertEqual(repository.cursors, [nil, "c1"])
    }

    func test_마지막_페이지_뒤에는_더_요청하지_않는다() async {
        let repository = twoPages()
        let model = make(repository)
        await model.load()
        await model.loadMore()
        await model.loadMore()
        XCTAssertEqual(repository.cursors.count, 2)
    }

    func test_다음_페이지가_실패하면_기존_목록을_유지하고_재시도할_수_있다() async {
        let repository = twoPages()
        repository.failCursor = "c1"
        let model = make(repository)
        await model.load()
        await model.loadMore()
        XCTAssertEqual(model.reviews.count, 5)
        XCTAssertTrue(model.loadMoreFailed)
        XCTAssertEqual(model.state, .loaded)

        repository.failCursor = nil
        await model.loadMore()
        XCTAssertEqual(model.reviews.count, 8)
        XCTAssertFalse(model.loadMoreFailed)
    }

    func test_페이지_경계가_밀려_같은_리뷰가_오면_중복으로_넣지_않는다() async {
        let repository = PagingRepository()
        repository.pages[nil] = ReviewPage(reviews: (1...3).map { review($0) }, nextCursor: "c1")
        repository.pages["c1"] = ReviewPage(reviews: [review(3), review(4)], nextCursor: nil)
        let model = make(repository)
        await model.load()
        await model.loadMore()
        XCTAssertEqual(model.reviews.map(\.id), [1, 2, 3, 4])
    }

    func test_새로고침하면_처음부터_다시_불러온다() async {
        let repository = twoPages()
        let model = make(repository)
        await model.load()
        await model.loadMore()
        await model.load()
        XCTAssertEqual(model.reviews.count, 5)
        XCTAssertTrue(model.hasMore)
    }

    func test_내_리뷰를_찾는다() async {
        let repository = PagingRepository()
        repository.pages[nil] = ReviewPage(reviews: [review(1), review(2, mine: true)], nextCursor: nil)
        let model = make(repository)
        await model.load()
        XCTAssertEqual(model.myReview?.id, 2)
    }

    func test_신고하면_서버에_보내고_안내한다() async {
        let repository = twoPages()
        let model = make(repository)
        await model.load()
        await model.report(model.reviews[1], reason: .spam)
        XCTAssertEqual(repository.reported.first?.0, 2)
        XCTAssertEqual(repository.reported.first?.1, .spam)
        XCTAssertEqual(model.toastMessage, "신고했어요. 확인 후 조치할게요")
    }

    func test_신고에_실패하면_에러_문구를_안내한다() async {
        let repository = twoPages()
        repository.actionError = .network
        let model = make(repository)
        await model.load()
        await model.report(model.reviews[0], reason: .abuse)
        XCTAssertEqual(model.toastMessage, APIError.network.userMessage)
    }

    func test_차단하면_그_유저의_리뷰가_모두_사라진다() async {
        let repository = PagingRepository()
        repository.pages[nil] = ReviewPage(reviews: [review(1, user: 7), review(2, user: 8), review(3, user: 7)], nextCursor: nil)
        let model = make(repository)
        await model.load()
        await model.block(model.reviews[0])
        XCTAssertEqual(repository.blocked, [7])
        XCTAssertEqual(model.reviews.map(\.id), [2])
        XCTAssertEqual(model.toastMessage, "차단했어요. 이 유저의 리뷰는 보이지 않아요")
    }

    func test_차단으로_목록이_비면_빈_상태가_된다() async {
        let repository = PagingRepository()
        repository.pages[nil] = ReviewPage(reviews: [review(1, user: 7)], nextCursor: nil)
        let model = make(repository)
        await model.load()
        await model.block(model.reviews[0])
        XCTAssertEqual(model.state, .empty)
    }

    func test_차단에_실패하면_목록을_그대로_둔다() async {
        let repository = twoPages()
        repository.actionError = .network
        let model = make(repository)
        await model.load()
        await model.block(model.reviews[0])
        XCTAssertEqual(model.reviews.count, 5)
        XCTAssertEqual(model.toastMessage, APIError.network.userMessage)
    }
}

final class RelativeTimeFormatterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000_000)
    private func text(secondsAgo: Double) -> String {
        RelativeTimeFormatter.text(from: now.addingTimeInterval(-secondsAgo), now: now)
    }

    func test_단위별_한국어_표기() {
        XCTAssertEqual(text(secondsAgo: 5), "방금 전")
        XCTAssertEqual(text(secondsAgo: 5 * 60), "5분 전")
        XCTAssertEqual(text(secondsAgo: 3 * 3600), "3시간 전")
        XCTAssertEqual(text(secondsAgo: 2 * 86_400), "2일 전")
        XCTAssertEqual(text(secondsAgo: 8 * 86_400), "1주 전")
        XCTAssertEqual(text(secondsAgo: 60 * 86_400), "2개월 전")
        XCTAssertEqual(text(secondsAgo: 800 * 86_400), "2년 전")
    }

    func test_경계값() {
        XCTAssertEqual(text(secondsAgo: 59), "방금 전")
        XCTAssertEqual(text(secondsAgo: 60), "1분 전")
        XCTAssertEqual(text(secondsAgo: 3599), "59분 전")
        XCTAssertEqual(text(secondsAgo: 86_399), "23시간 전")
        XCTAssertEqual(text(secondsAgo: 7 * 86_400 - 1), "6일 전")
    }

    func test_미래_시각은_방금_전으로_본다() {
        XCTAssertEqual(text(secondsAgo: -30), "방금 전", "기기 시계 오차로 서버 시각이 앞설 때")
    }
}

final class RemoteReviewRepositoryTests: XCTestCase {
    private func make(handler: @escaping StubTransport.Handler) -> (RemoteReviewRepository, StubTransport) {
        let transport = StubTransport(handler)
        let client = APIClient(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")), transport: transport)
        return (RemoteReviewRepository(client: client), transport)
    }

    private func body(_ request: URLRequest?) throws -> [String: Any] {
        let data = try XCTUnwrap(request?.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func test_목록을_해석하고_커서를_보낸다() async throws {
        let json = """
            {"reviews":[{"id":1,"userId":7,"nickname":"두부산책","characterId":5,"badgeCount":47,"rating":5,"content":"좋아요 좋아요 좋아요","createdAt":"2026-11-02T09:00:00+09:00","isMine":false},
                        {"id":2,"userId":1,"nickname":"나뭇잎","characterId":1,"badgeCount":23,"rating":4,"content":"그늘이 많아요 정말로","createdAt":"2026-10-28T09:00:00+09:00"}],
             "nextCursor":"abc"}
            """
        let (repository, transport) = make { _ in (200, json) }
        let page = try await repository.list(parkID: 1024, cursor: "xyz")

        XCTAssertEqual(page.reviews.count, 2)
        XCTAssertEqual(page.nextCursor, "abc")
        XCTAssertFalse(page.reviews[1].isMine, "isMine이 없으면 내 리뷰가 아닌 것으로 본다")
        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.path, "/api/parks/1024/reviews")
        XCTAssertTrue(url.query?.contains("sort=latest") ?? false)
        XCTAssertTrue(url.query?.contains("cursor=xyz") ?? false)
    }

    func test_첫_페이지는_커서를_보내지_않는다() async throws {
        let (repository, transport) = make { _ in (200, #"{"reviews":[],"nextCursor":null}"#) }
        let page = try await repository.list(parkID: 1, cursor: nil)
        XCTAssertNil(page.nextCursor)
        XCTAssertFalse(transport.requests.first?.url?.query?.contains("cursor") ?? true)
    }

    func test_작성_수정_삭제_요청() async throws {
        let (repository, transport) = make { _ in (200, "{}") }
        try await repository.create(parkID: 3, rating: 4, content: "호수 둘레길이 평평해요")
        try await repository.update(reviewID: 9, rating: 5, content: "다시 써 봤어요 정말로")
        try await repository.delete(reviewID: 9)

        XCTAssertEqual(transport.requests.map { "\($0.httpMethod ?? "") \($0.url?.path ?? "")" },
                       ["POST /api/parks/3/reviews", "PATCH /api/reviews/9", "DELETE /api/reviews/9"])
        let created = try body(transport.requests[0])
        XCTAssertEqual(created["rating"] as? Int, 4)
        XCTAssertEqual(created["content"] as? String, "호수 둘레길이 평평해요")
    }

    func test_신고와_차단_요청() async throws {
        let (repository, transport) = make { _ in (200, "{}") }
        try await repository.report(reviewID: 5, reason: .abuse)
        try await repository.blockUser(userID: 7)
        XCTAssertEqual(transport.requests[0].url?.path, "/api/reviews/5/reports")
        XCTAssertEqual(try body(transport.requests[0])["reason"] as? String, "ABUSE")
        XCTAssertEqual(transport.requests[1].url?.path, "/api/users/7/block")
        XCTAssertEqual(transport.requests[1].httpMethod, "POST")
    }

    func test_서버_에러_코드를_그대로_던진다() async {
        let (repository, _) = make { _ in (403, #"{"code":"REVIEW_BADGE_REQUIRED"}"#) }
        do {
            try await repository.create(parkID: 1, rating: 5, content: "배지가 없는 공원입니다 정말")
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual((error as? APIError)?.serverCode, .reviewBadgeRequired)
        }
    }
}
