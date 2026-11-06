import XCTest
@testable import Parknic

private final class StubMyPageRepository: MyPageRepository, @unchecked Sendable {
    var profileResult: Result<UserProfile, APIError>
    var statsResult: Result<UserStats, APIError>
    var pages: [String?: Result<MyReviewPage, APIError>]
    private let lock = NSLock()
    private var _cursors: [String?] = []
    var requestedCursors: [String?] { lock.withLock { _cursors } }

    init(
        profile: Result<UserProfile, APIError> = .success(sampleProfile),
        stats: Result<UserStats, APIError> = .success(sampleStats),
        pages: [String?: Result<MyReviewPage, APIError>] = [nil: .success(MyReviewPage(reviews: [], totalCount: 0, nextCursor: nil))]
    ) {
        self.profileResult = profile
        self.statsResult = stats
        self.pages = pages
    }

    func profile() async throws -> UserProfile { try profileResult.get() }
    func stats() async throws -> UserStats { try statsResult.get() }
    func reviews(cursor: String?) async throws -> MyReviewPage {
        lock.withLock { _cursors.append(cursor) }
        return try (pages[cursor] ?? .failure(.network)).get()
    }
}

private let sampleProfile = UserProfile(
    nickname: "나뭇잎", characterID: 1, characterName: "치즈냥",
    joinedAt: Calendar.kst.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12))!)
private let sampleStats = UserStats(totalBadges: 23, visitedParks: 11, currentStreak: 5, bestStreak: 9, podiumParks: 2)

private func review(_ id: Int, daysAgo: Int = 1, now: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> MyReview {
    MyReview(
        id: id, parkID: 1000 + id, parkName: "공원\(id)", rating: 4, content: "리뷰\(id)",
        createdAt: now.addingTimeInterval(-Double(daysAgo) * 86_400))
}

@MainActor
final class MyPageSummaryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func make(_ repository: StubMyPageRepository, notifications: Bool = true, store: MemoryProfileStore = MemoryProfileStore())
        -> MyPageViewModel
    {
        MyPageViewModel(
            auth: NoopAuth(), profile: store, repository: repository, userRepository: MockUserRepository(),
            notificationStatus: StubNotificationStatus(enabled: notifications), clock: FixedClock(now),
            isCheckInActive: { false }, onSignedOut: {})
    }

    func test_불러오면_프로필_통계_최근_리뷰를_보여준다() async {
        let repository = StubMyPageRepository(
            pages: [nil: .success(MyReviewPage(reviews: [review(1), review(2)], totalCount: 2, nextCursor: nil))])
        let model = make(repository)
        XCTAssertEqual(model.summaryState, .loading)

        await model.load()

        XCTAssertEqual(model.summary?.stats, sampleStats)
        XCTAssertEqual(model.recentReviews.map(\.id), [1, 2])
        XCTAssertEqual(model.nickname, "나뭇잎")
    }

    func test_최근_리뷰는_세_개까지만_보여주고_전체_개수는_따로_둔다() async {
        let repository = StubMyPageRepository(
            pages: [nil: .success(MyReviewPage(reviews: (1...5).map { review($0) }, totalCount: 12, nextCursor: "c"))])
        let model = make(repository)
        await model.load()
        XCTAssertEqual(model.recentReviews.map(\.id), [1, 2, 3])
        XCTAssertEqual(model.summary?.recentReviews.totalCount, 12)
    }

    func test_부제목은_캐릭터_이름과_가입한_달을_한국_시간으로_보여준다() async {
        let model = make(StubMyPageRepository())
        XCTAssertEqual(model.subtitle, "파크닉에서 산책 중")
        await model.load()
        XCTAssertEqual(model.subtitle, "치즈냥 · 2026년 9월부터 산책 중")
    }

    func test_가입_시각이_한국_기준_월초_직전이면_한국_달로_표시한다() async {
        // 2026-08-31 15:30 UTC == 2026-09-01 00:30 KST
        let joined = Date(timeIntervalSince1970: 1_788_190_200)
        let profile = UserProfile(nickname: "n", characterID: 1, characterName: "치즈냥", joinedAt: joined)
        let model = make(StubMyPageRepository(profile: .success(profile)))
        await model.load()
        XCTAssertEqual(model.subtitle, "치즈냥 · 2026년 9월부터 산책 중")
    }

    func test_서버의_프로필로_기기에_저장된_값을_갱신한다() async {
        let store = MemoryProfileStore()
        store.save(nickname: "옛이름", characterID: 8)
        let model = make(StubMyPageRepository(), store: store)
        await model.load()
        XCTAssertEqual(store.nickname, "나뭇잎")
        XCTAssertEqual(store.characterID, 1)
        XCTAssertEqual(model.characterAssetName, "character-1")
    }

    func test_하나라도_실패하면_에러_문구를_보여주고_다시_시도하면_성공한다() async {
        let repository = StubMyPageRepository(stats: .failure(.network))
        let model = make(repository)
        await model.load()
        XCTAssertEqual(model.summaryState, .failed(APIError.network.userMessage))

        repository.statsResult = .success(sampleStats)
        await model.load()
        XCTAssertNotNil(model.summary)
    }

    func test_이미_보여주는_중에_새로고침이_실패해도_화면을_유지한다() async {
        let repository = StubMyPageRepository()
        let model = make(repository)
        await model.load()
        repository.statsResult = .failure(.network)
        await model.load()
        XCTAssertNotNil(model.summary)
    }

    func test_알림_권한_상태를_읽는다() async {
        let on = make(StubMyPageRepository(), notifications: true)
        let off = make(StubMyPageRepository(), notifications: false)
        XCTAssertNil(on.notificationsEnabled)
        await on.load()
        await off.load()
        XCTAssertEqual(on.notificationsEnabled, true)
        XCTAssertEqual(off.notificationsEnabled, false)
    }

    func test_상대_시간은_주입한_시계를_따른다() async {
        let model = make(StubMyPageRepository())
        XCTAssertEqual(model.relativeTime(of: review(1, daysAgo: 7, now: now)), "1주 전")
    }
}

private struct NoopAuth: AuthRepository {
    func login(provider: AuthProvider, socialToken: String, authorizationCode: String?) async throws -> LoginResult { LoginResult(isNewUser: false) }
    func logout() async {}
    func deleteAccount() async throws {}
}

@MainActor
final class MyReviewsViewModelTests: XCTestCase {
    func test_첫_페이지를_불러온다() async {
        let repository = StubMyPageRepository(
            pages: [nil: .success(MyReviewPage(reviews: [review(1), review(2)], totalCount: 2, nextCursor: nil))])
        let model = MyReviewsViewModel(repository: repository)
        XCTAssertEqual(model.state, .loading)
        await model.load()
        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.reviews.map(\.id), [1, 2])
        XCTAssertEqual(model.totalCount, 2)
    }

    func test_마지막_항목이_보이면_다음_페이지를_이어_붙인다() async {
        let repository = StubMyPageRepository(pages: [
            nil: .success(MyReviewPage(reviews: [review(1), review(2)], totalCount: 3, nextCursor: "p2")),
            "p2": .success(MyReviewPage(reviews: [review(3)], totalCount: 3, nextCursor: nil)),
        ])
        let model = MyReviewsViewModel(repository: repository)
        await model.load()

        await model.loadMoreIfNeeded(current: review(1))
        XCTAssertEqual(model.reviews.map(\.id), [1, 2], "마지막 항목이 아니면 불러오지 않는다")

        await model.loadMoreIfNeeded(current: review(2))
        XCTAssertEqual(model.reviews.map(\.id), [1, 2, 3])

        await model.loadMoreIfNeeded(current: review(3))
        XCTAssertEqual(repository.requestedCursors.count, 2, "다음 페이지가 없으면 더 요청하지 않는다")
    }

    func test_이어_불러오다_실패해도_기존_목록은_유지하고_다시_보이면_재시도한다() async {
        let repository = StubMyPageRepository(pages: [
            nil: .success(MyReviewPage(reviews: [review(1)], totalCount: 2, nextCursor: "p2")),
            "p2": .failure(.network),
        ])
        let model = MyReviewsViewModel(repository: repository)
        await model.load()
        await model.loadMoreIfNeeded(current: review(1))
        XCTAssertEqual(model.reviews.map(\.id), [1])
        XCTAssertEqual(model.state, .loaded)

        repository.pages["p2"] = .success(MyReviewPage(reviews: [review(2)], totalCount: 2, nextCursor: nil))
        await model.loadMoreIfNeeded(current: review(1))
        XCTAssertEqual(model.reviews.map(\.id), [1, 2])
    }

    func test_중복된_리뷰는_한_번만_넣는다() async {
        let repository = StubMyPageRepository(pages: [
            nil: .success(MyReviewPage(reviews: [review(1), review(2)], totalCount: 3, nextCursor: "p2")),
            "p2": .success(MyReviewPage(reviews: [review(2), review(3)], totalCount: 3, nextCursor: nil)),
        ])
        let model = MyReviewsViewModel(repository: repository)
        await model.load()
        await model.loadMoreIfNeeded(current: review(2))
        XCTAssertEqual(model.reviews.map(\.id), [1, 2, 3])
    }

    func test_처음_실패하면_에러를_보여준다() async {
        let model = MyReviewsViewModel(repository: StubMyPageRepository(pages: [nil: .failure(.network)]))
        await model.load()
        XCTAssertEqual(model.state, .failed(APIError.network.userMessage))
    }
}

final class RemoteMyPageRepositoryTests: XCTestCase {
    private func makeRepository(handler: @escaping StubTransport.Handler) -> (RemoteMyPageRepository, StubTransport) {
        let transport = StubTransport(handler)
        let client = APIClient(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")), transport: transport)
        return (RemoteMyPageRepository(client: client), transport)
    }

    func test_프로필을_읽는다() async throws {
        let json = #"{"nickname":"나뭇잎","characterId":1,"characterName":"치즈냥","createdAt":"2026-09-02T12:00:00+09:00"}"#
        let (repository, transport) = makeRepository { _ in (200, json) }
        let profile = try await repository.profile()
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/users/me")
        XCTAssertEqual(profile.nickname, "나뭇잎")
        XCTAssertEqual(profile.characterName, "치즈냥")
    }

    func test_통계를_읽는다() async throws {
        let json = #"{"totalBadges":23,"visitedParks":11,"currentStreak":5,"bestStreak":9,"podiumParks":2}"#
        let (repository, transport) = makeRepository { _ in (200, json) }
        let stats = try await repository.stats()
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/users/me/stats")
        XCTAssertEqual(stats, sampleStats)
    }

    func test_내_리뷰를_읽고_커서를_보낸다() async throws {
        let json = """
        {"reviews":[{"id":7,"parkId":1024,"parkName":"보라매공원","rating":5,"content":"좋아요","createdAt":"2026-11-01T10:00:00+09:00"}],
         "totalCount":3,"nextCursor":"abc"}
        """
        let (repository, transport) = makeRepository { _ in (200, json) }
        let page = try await repository.reviews(cursor: "prev")
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/users/me/reviews")
        let query = URLComponents(url: try XCTUnwrap(transport.requests.first?.url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(query?.first?.name, "cursor")
        XCTAssertEqual(query?.first?.value, "prev")
        XCTAssertEqual(page.totalCount, 3)
        XCTAssertEqual(page.nextCursor, "abc")
        XCTAssertEqual(page.reviews.first?.parkName, "보라매공원")
    }

    func test_첫_페이지는_커서를_보내지_않는다() async throws {
        let (repository, transport) = makeRepository { _ in (200, #"{"reviews":[],"totalCount":0,"nextCursor":null}"#) }
        _ = try await repository.reviews(cursor: nil)
        XCTAssertNil(transport.requests.first?.url?.query)
    }
}
