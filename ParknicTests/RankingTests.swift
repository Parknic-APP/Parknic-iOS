import XCTest
@testable import Parknic

final class YearMonthTests: XCTestCase {
    func test_서버_파라미터_형식() {
        XCTAssertEqual(YearMonth(year: 2026, month: 11).apiValue, "2026-11")
        XCTAssertEqual(YearMonth(year: 2026, month: 3).apiValue, "2026-03")
    }

    func test_이전_달과_다음_달은_해를_넘긴다() {
        XCTAssertEqual(YearMonth(year: 2026, month: 1).previous, YearMonth(year: 2025, month: 12))
        XCTAssertEqual(YearMonth(year: 2025, month: 12).next, YearMonth(year: 2026, month: 1))
        XCTAssertEqual(YearMonth(year: 2026, month: 6).next, YearMonth(year: 2026, month: 7))
    }

    func test_크기를_비교한다() {
        XCTAssertTrue(YearMonth(year: 2025, month: 12) < YearMonth(year: 2026, month: 1))
        XCTAssertTrue(YearMonth(year: 2026, month: 2) < YearMonth(year: 2026, month: 10))
    }

    func test_그_달의_마지막_날() {
        XCTAssertEqual(YearMonth(year: 2026, month: 10).lastDay, 31)
        XCTAssertEqual(YearMonth(year: 2026, month: 11).lastDay, 30)
        XCTAssertEqual(YearMonth(year: 2026, month: 2).lastDay, 28)
        XCTAssertEqual(YearMonth(year: 2028, month: 2).lastDay, 29, "윤년")
    }

    func test_한국_시간_기준으로_달을_정한다() {
        // 10월 31일 23:30 UTC = 11월 1일 08:30 KST → 11월
        let date = Date(timeIntervalSince1970: ISO8601DateFormatter().date(from: "2026-10-31T23:30:00Z")?.timeIntervalSince1970 ?? 0)
        XCTAssertEqual(YearMonth(date: date), YearMonth(year: 2026, month: 11))
    }
}

final class MyRankingFooterTests: XCTestCase {
    private func entry(_ rank: Int, _ count: Int) -> RankingEntry {
        RankingEntry(rank: rank, userID: rank, nickname: "n\(rank)", characterID: 1, badgeCount: count)
    }
    private func ranking(podium: [RankingEntry], me: MyRanking?) -> ParkRanking {
        ParkRanking(month: YearMonth(year: 2026, month: 10), podium: podium, others: [], me: me)
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

    func test_이번_달_배지가_없으면_바로_몇_등인지_알려준다() {
        let r = ranking(podium: [entry(1, 3)], me: MyRanking(rank: nil, badgeCount: 0))
        XCTAssertEqual(MyRankingFooter.make(for: r), MyRankingFooter(title: "이번 달 아직 배지가 없어요", subtitle: "20분만 머물러도 바로 2등이에요"))
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
    private var _months: [String] = []
    var error: APIError?
    var months: [String] { lock.withLock { _months } }

    func ranking(parkID: Int, month: YearMonth) async throws -> ParkRanking {
        lock.withLock { _months.append(month.apiValue) }
        if let error { throw error }
        return ParkRanking(month: month, podium: [], others: [], me: nil)
    }
}

@MainActor
final class RankingViewModelTests: XCTestCase {
    private let clock = FixedClock(kst("2026-11-04T10:00:00+09:00"))

    private func make(_ repository: RankingRepository) -> RankingViewModel {
        RankingViewModel(parkID: 1, parkName: "보라매공원", repository: repository, clock: clock)
    }

    func test_이번_달을_먼저_불러온다() async {
        let repository = RecordingRankingRepository()
        let model = make(repository)
        await model.load()
        XCTAssertEqual(repository.months, ["2026-11"])
        XCTAssertEqual(model.ranking?.month, YearMonth(year: 2026, month: 11))
    }

    func test_이번_달에서는_다음_달로_갈_수_없다() async {
        let model = make(RecordingRankingRepository())
        XCTAssertFalse(model.canGoNext)
        await model.showNextMonth()
        XCTAssertEqual(model.month, YearMonth(year: 2026, month: 11))
    }

    func test_이전_달로_넘기면_그_달을_다시_불러온다() async {
        let repository = RecordingRankingRepository()
        let model = make(repository)
        await model.load()
        await model.showPreviousMonth()
        XCTAssertEqual(model.month, YearMonth(year: 2026, month: 10))
        XCTAssertEqual(repository.months, ["2026-11", "2026-10"])
        XCTAssertTrue(model.canGoNext)
    }

    func test_이전_달에서_다음_달로_돌아올_수_있다() async {
        let repository = RecordingRankingRepository()
        let model = make(repository)
        await model.showPreviousMonth()
        await model.showNextMonth()
        XCTAssertEqual(model.month, YearMonth(year: 2026, month: 11))
        XCTAssertEqual(repository.months, ["2026-10", "2026-11"])
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

    func test_확정_안내_문구는_이번_달과_지난_달이_다르다() async {
        let model = make(RecordingRankingRepository())
        XCTAssertEqual(model.confirmationText, "11월 30일 자정에 확정돼요 · 배지 수 기준")
        await model.showPreviousMonth()
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
        {"month":"2026-11",
         "podium":[{"rank":2,"userId":3,"nickname":"초록발","characterId":3,"badgeCount":9},{"rank":1,"userId":7,"nickname":"두부산책","characterId":5,"badgeCount":12}],
         "others":[{"rank":4,"userId":11,"nickname":"구름빵","characterId":6,"badgeCount":7}],
         "me":{"rank":17,"badgeCount":4}}
        """

    func test_랭킹을_순위_순으로_해석한다() async throws {
        let (repository, transport) = make { _ in (200, self.json) }
        let ranking = try await repository.ranking(parkID: 1024, month: YearMonth(year: 2026, month: 11))

        XCTAssertEqual(ranking.podium.map(\.rank), [1, 2], "서버 순서와 관계없이 순위 순으로 둔다")
        XCTAssertEqual(ranking.podiumEntry(rank: 1)?.nickname, "두부산책")
        XCTAssertNil(ranking.podiumEntry(rank: 3), "빈 자리는 비어 있다")
        XCTAssertEqual(ranking.others.map(\.nickname), ["구름빵"])
        XCTAssertEqual(ranking.me, MyRanking(rank: 17, badgeCount: 4))
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/parks/1024/rankings")
        XCTAssertTrue(transport.requests.first?.url?.query?.contains("month=2026-11") ?? false)
    }

    func test_내_순위가_없으면_nil이다() async throws {
        let body = #"{"podium":[],"others":[],"me":{"rank":null,"badgeCount":0}}"#
        let (repository, _) = make { _ in (200, body) }
        let ranking = try await repository.ranking(parkID: 1, month: YearMonth(year: 2026, month: 11))
        XCTAssertEqual(ranking.me, MyRanking(rank: nil, badgeCount: 0))
    }

    func test_me_필드가_없어도_해석한다() async throws {
        let body = #"{"podium":[],"others":[]}"#
        let (repository, _) = make { _ in (200, body) }
        let ranking = try await repository.ranking(parkID: 1, month: YearMonth(year: 2026, month: 11))
        XCTAssertNil(ranking.me)
    }
}
