import XCTest
@testable import Parknic

final class RankingWeekTests: XCTestCase {
    private func week(_ iso: String) -> RankingWeek { RankingWeek(date: kst(iso)) }

    func test_한_주는_월요일에_시작한다() {
        // 2026-11-04는 수요일 → 그 주 월요일은 11월 2일
        XCTAssertEqual(week("2026-11-04T10:00:00+09:00").apiValue, "2026-11-02")
        XCTAssertEqual(week("2026-11-02T00:00:00+09:00").apiValue, "2026-11-02", "월요일 0시는 새 주")
        XCTAssertEqual(week("2026-11-01T23:59:59+09:00").apiValue, "2026-10-26", "일요일 밤은 아직 지난주")
        XCTAssertEqual(week("2026-11-08T23:59:59+09:00").apiValue, "2026-11-02", "일요일 24시 직전까지 같은 주")
    }

    func test_한국_시간_기준으로_주를_정한다() {
        // 일요일 14:30 UTC(= 23:30 KST)는 아직 그 주, 15:00 UTC(= 월요일 00:00 KST)부터 새 주
        XCTAssertEqual(week("2026-11-08T14:30:00Z").apiValue, "2026-11-02")
        XCTAssertEqual(week("2026-11-08T15:00:00Z").apiValue, "2026-11-09")
    }

    func test_이전_주와_다음_주는_달과_해를_넘긴다() {
        XCTAssertEqual(week("2026-11-04T10:00:00+09:00").previous.apiValue, "2026-10-26")
        XCTAssertEqual(week("2026-11-04T10:00:00+09:00").next.apiValue, "2026-11-09")
        XCTAssertEqual(week("2026-01-01T10:00:00+09:00").previous.apiValue, "2025-12-22")
        XCTAssertEqual(week("2025-12-31T10:00:00+09:00").next.apiValue, "2026-01-05")
    }

    func test_크기를_비교한다() {
        XCTAssertTrue(week("2026-10-30T10:00:00+09:00") < week("2026-11-04T10:00:00+09:00"))
        XCTAssertFalse(week("2026-11-02T00:00:00+09:00") < week("2026-11-08T23:00:00+09:00"), "같은 주")
    }

    func test_기간_문구() {
        XCTAssertEqual(week("2026-11-04T10:00:00+09:00").rangeLabel, "11월 2일 ~ 8일")
        XCTAssertEqual(week("2026-10-28T10:00:00+09:00").rangeLabel, "10월 26일 ~ 11월 1일")
        XCTAssertEqual(week("2026-11-04T10:00:00+09:00").shortLabel, "11/2~8")
        XCTAssertEqual(week("2026-10-28T10:00:00+09:00").shortLabel, "10/26~11/1")
        XCTAssertEqual(week("2026-11-04T10:00:00+09:00").resetLabel, "11월 9일")
    }
}

final class MyRankingFooterTests: XCTestCase {
    private func entry(_ rank: Int, _ count: Int) -> RankingEntry {
        RankingEntry(rank: rank, userID: rank, nickname: "n\(rank)", characterID: 1, badgeCount: count)
    }
    private func ranking(podium: [RankingEntry], me: MyRanking?) -> ParkRanking {
        ParkRanking(week: RankingWeek(date: kst("2026-11-04T10:00:00+09:00")), podium: podium, others: [], me: me)
    }

    func test_시상대_밖이면_3등까지_남은_배지를_알려준다() {
        // 3등이 6개 → 동점은 먼저 도달한 쪽이 위이므로 7개가 필요. 내가 4개면 3개 남음
        let r = ranking(podium: [entry(1, 12), entry(2, 9), entry(3, 6)], me: MyRanking(rank: 17, badgeCount: 4))
        XCTAssertEqual(MyRankingFooter.make(for: r), MyRankingFooter(title: "나는 17등 · 배지 4개", subtitle: "3등까지 배지 3개 남았어요"))
    }

    func test_이미_시상대면_올랐다고_알려준다() {
        let r = ranking(podium: [entry(1, 12), entry(2, 9), entry(3, 6)], me: MyRanking(rank: 2, badgeCount: 9))
        XCTAssertEqual(MyRankingFooter.make(for: r).subtitle, "시상대에 올랐어요")
    }

    func test_이번_주_배지가_없으면_바로_몇_등인지_알려준다() {
        let r = ranking(podium: [entry(1, 3)], me: MyRanking(rank: nil, badgeCount: 0))
        XCTAssertEqual(MyRankingFooter.make(for: r), MyRankingFooter(title: "이번 주 아직 배지가 없어요", subtitle: "20분만 머물러도 바로 2등이에요"))
    }

    func test_시상대가_비어_있으면_1등이_된다() {
        let r = ranking(podium: [], me: nil)
        XCTAssertEqual(MyRankingFooter.make(for: r).subtitle, "20분만 머물러도 바로 1등이에요")
    }

    func test_시상대가_가득_찼는데_배지가_없으면_첫_배지를_권한다() {
        let r = ranking(podium: [entry(1, 12), entry(2, 9), entry(3, 6)], me: MyRanking(rank: nil, badgeCount: 0))
        XCTAssertEqual(MyRankingFooter.make(for: r).subtitle, "20분 머물러 첫 배지를 받아 보세요")
    }

    func test_3등보다_배지가_많아도_남은_개수는_최소_1개다() {
        let r = ranking(podium: [entry(1, 12), entry(2, 9), entry(3, 6)], me: MyRanking(rank: 4, badgeCount: 6))
        XCTAssertEqual(MyRankingFooter.make(for: r).subtitle, "3등까지 배지 1개 남았어요", "6개 동점이면 먼저 도달한 3등이 위다")
    }
}

private final class RecordingRankingRepository: RankingRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _weeks: [String] = []
    var error: APIError?
    var weeks: [String] { lock.withLock { _weeks } }

    func ranking(parkID: Int, week: RankingWeek) async throws -> ParkRanking {
        lock.withLock { _weeks.append(week.apiValue) }
        if let error { throw error }
        return ParkRanking(week: week, podium: [], others: [], me: nil)
    }
}

@MainActor
final class RankingViewModelTests: XCTestCase {
    private let clock = FixedClock(kst("2026-11-04T10:00:00+09:00"))

    private func make(_ repository: RankingRepository) -> RankingViewModel {
        RankingViewModel(parkID: 1, parkName: "보라매공원", repository: repository, clock: clock)
    }

    func test_이번_주를_먼저_불러온다() async {
        let repository = RecordingRankingRepository()
        let model = make(repository)
        await model.load()
        XCTAssertEqual(repository.weeks, ["2026-11-02"])
        XCTAssertEqual(model.ranking?.week.apiValue, "2026-11-02")
    }

    func test_이번_주에서는_다음_주로_갈_수_없다() async {
        let model = make(RecordingRankingRepository())
        XCTAssertFalse(model.canGoNext)
        await model.showNextWeek()
        XCTAssertEqual(model.week.apiValue, "2026-11-02")
    }

    func test_이전_주로_넘기면_그_주를_다시_불러온다() async {
        let repository = RecordingRankingRepository()
        let model = make(repository)
        await model.load()
        await model.showPreviousWeek()
        XCTAssertEqual(model.week.apiValue, "2026-10-26")
        XCTAssertEqual(repository.weeks, ["2026-11-02", "2026-10-26"])
        XCTAssertTrue(model.canGoNext)
    }

    func test_이전_주에서_다음_주로_돌아올_수_있다() async {
        let repository = RecordingRankingRepository()
        let model = make(repository)
        await model.showPreviousWeek()
        await model.showNextWeek()
        XCTAssertEqual(model.week.apiValue, "2026-11-02")
        XCTAssertEqual(repository.weeks, ["2026-10-26", "2026-11-02"])
    }

    func test_불러오기에_실패하면_에러이고_재시도로_복구된다() async {
        let repository = RecordingRankingRepository()
        repository.error = .network
        let model = make(repository)
        await model.load()
        XCTAssertEqual(model.state, .failed(APIError.network.userMessage))
        repository.error = nil
        await model.load()
        XCTAssertNotNil(model.ranking)
    }

    func test_안내_문구는_이번_주와_지난_주가_다르다() async {
        let model = make(RecordingRankingRepository())
        XCTAssertEqual(model.confirmationText, "11월 9일 월요일 0시에 새로 시작해요 · 배지 수 기준")
        await model.showPreviousWeek()
        XCTAssertEqual(model.confirmationText, "확정된 랭킹이에요 · 배지 수 기준")
    }
}

final class RemoteRankingRepositoryTests: XCTestCase {
    private func make(handler: @escaping StubTransport.Handler) -> (RemoteRankingRepository, StubTransport) {
        let transport = StubTransport(handler)
        let client = APIClient(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")), transport: transport)
        return (RemoteRankingRepository(client: client), transport)
    }

    private let json = """
        {"weekStart":"2026-11-02","weekEnd":"2026-11-08",
         "podium":[{"rank":2,"userId":3,"nickname":"초록발","characterId":3,"badgeCount":9},{"rank":1,"userId":7,"nickname":"두부산책","characterId":5,"badgeCount":12}],
         "others":[{"rank":4,"userId":11,"nickname":"구름빵","characterId":6,"badgeCount":7}],
         "me":{"rank":17,"badgeCount":4}}
        """

    func test_랭킹을_순위_순으로_해석한다() async throws {
        let (repository, transport) = make { _ in (200, self.json) }
        let ranking = try await repository.ranking(parkID: 1024, week: RankingWeek(date: kst("2026-11-04T10:00:00+09:00")))

        XCTAssertEqual(ranking.podium.map(\.rank), [1, 2], "서버 순서와 관계없이 순위 순으로 둔다")
        XCTAssertEqual(ranking.podiumEntry(rank: 1)?.nickname, "두부산책")
        XCTAssertNil(ranking.podiumEntry(rank: 3), "빈 자리는 비어 있다")
        XCTAssertEqual(ranking.others.map(\.nickname), ["구름빵"])
        XCTAssertEqual(ranking.me, MyRanking(rank: 17, badgeCount: 4))
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/parks/1024/rankings")
        XCTAssertTrue(transport.requests.first?.url?.query?.contains("week=2026-11-02") ?? false)
    }

    func test_내_순위가_없으면_nil이다() async throws {
        let body = #"{"podium":[],"others":[],"me":{"rank":null,"badgeCount":0}}"#
        let (repository, _) = make { _ in (200, body) }
        let ranking = try await repository.ranking(parkID: 1, week: RankingWeek(date: kst("2026-11-04T10:00:00+09:00")))
        XCTAssertEqual(ranking.me, MyRanking(rank: nil, badgeCount: 0))
    }

    func test_me_필드가_없어도_해석한다() async throws {
        let body = #"{"podium":[],"others":[]}"#
        let (repository, _) = make { _ in (200, body) }
        let ranking = try await repository.ranking(parkID: 1, week: RankingWeek(date: kst("2026-11-04T10:00:00+09:00")))
        XCTAssertNil(ranking.me)
    }
}

private final class TickingClock: AppClock, @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(_ date: Date) { self.date = date }
    var now: Date { lock.withLock { date } }
    func set(_ newDate: Date) { lock.withLock { date = newDate } }
}

@MainActor
final class RankingWeekRolloverTests: XCTestCase {
    func test_일요일_밤에_연_화면은_월요일_0시가_지나면_지난주가_된다() async {
        let clock = TickingClock(kst("2026-11-08T23:50:00+09:00"))  // 일요일 밤
        let model = RankingViewModel(
            parkID: 1, parkName: "보라매공원", repository: RecordingRankingRepository(), clock: clock)
        XCTAssertEqual(model.week.apiValue, "2026-11-02")
        XCTAssertFalse(model.canGoNext)
        XCTAssertEqual(model.confirmationText, "11월 9일 월요일 0시에 새로 시작해요 · 배지 수 기준")

        clock.set(kst("2026-11-09T00:10:00+09:00"))  // 월요일 0시 10분: 새 주가 시작됐다

        XCTAssertTrue(model.canGoNext, "보고 있던 주가 지난주가 되어 새 주로 넘어갈 수 있다")
        XCTAssertEqual(model.confirmationText, "확정된 랭킹이에요 · 배지 수 기준")
        await model.showNextWeek()
        XCTAssertEqual(model.week.apiValue, "2026-11-09")
        XCTAssertFalse(model.canGoNext)
    }
}
