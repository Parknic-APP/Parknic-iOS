import XCTest
@testable import Parknic

private struct StubCollectionRepository: CollectionRepository, @unchecked Sendable {
    var results: [Result<BadgeCollection, APIError>]
    private let counter = Counter()

    final class Counter: @unchecked Sendable {
        var value = 0
    }

    init(_ results: [Result<BadgeCollection, APIError>]) { self.results = results }

    func collection() async throws -> BadgeCollection {
        let index = min(counter.value, results.count - 1)
        counter.value += 1
        return try results[index].get()
    }
}

private func sampleCollection(total: Int = 23) -> BadgeCollection {
    BadgeCollection(
        totalBadges: total, visitedParks: 11, typeCounts: [.neighborhood: 9, .sports: 3],
        achievements: [
            AchievementProgress(id: "A", name: "첫 배지", label: "첫", achievedAt: Date(timeIntervalSince1970: 0), progress: 1, target: 1),
            AchievementProgress(id: "B", name: "20곳", label: "20", achievedAt: nil, progress: 11, target: 20),
        ])
}

final class BadgeCollectionTests: XCTestCase {
    func test_받지_못한_유형은_0개로_읽고_모은_유형_수를_센다() {
        let collection = sampleCollection()
        XCTAssertEqual(collection.count(of: .neighborhood), 9)
        XCTAssertEqual(collection.count(of: .culture), 0)
        XCTAssertEqual(collection.collectedTypeCount, 2)
    }

    func test_달성한_업적_수를_센다() {
        XCTAssertEqual(sampleCollection().achievedCount, 1)
    }

    func test_배지가_없으면_비어_있다() {
        XCTAssertTrue(sampleCollection(total: 0).isEmpty)
        XCTAssertFalse(sampleCollection().isEmpty)
    }

    func test_진행도는_0에서_1_사이이고_달성하면_1이다() {
        let progress = AchievementProgress(id: "A", name: "n", label: "l", achievedAt: nil, progress: 11, target: 20)
        XCTAssertEqual(progress.fraction, 0.55, accuracy: 0.0001)
        let over = AchievementProgress(id: "A", name: "n", label: "l", achievedAt: nil, progress: 30, target: 20)
        XCTAssertEqual(over.fraction, 1)
        let zeroTarget = AchievementProgress(id: "A", name: "n", label: "l", achievedAt: nil, progress: 3, target: 0)
        XCTAssertEqual(zeroTarget.fraction, 0)
        let done = AchievementProgress(id: "A", name: "n", label: "l", achievedAt: Date(), progress: 0, target: 20)
        XCTAssertEqual(done.fraction, 1)
    }

    func test_달성일은_한국_시간_기준으로_표시한다() {
        // 2026-10-19 23:30 KST == 2026-10-19 14:30 UTC (UTC 기준으로 보면 같은 날이라 구분이 안 되므로 자정 직전으로 확인)
        let lateNight = Calendar.kst.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 23, minute: 30))!
        let achievement = AchievementProgress(id: "A", name: "n", label: "l", achievedAt: lateNight, progress: 1, target: 1)
        XCTAssertEqual(achievement.achievedDateText, "2026.10.19 달성")
        // 2026-10-19 15:30 UTC == 2026-10-20 00:30 KST
        let pastMidnight = Date(timeIntervalSince1970: 1_792_423_800)
        let next = AchievementProgress(id: "A", name: "n", label: "l", achievedAt: pastMidnight, progress: 1, target: 1)
        XCTAssertEqual(next.achievedDateText, "2026.10.20 달성")
    }

    func test_미달성은_날짜_대신_진행도를_보여준다() {
        let achievement = AchievementProgress(id: "A", name: "n", label: "l", achievedAt: nil, progress: 25, target: 20)
        XCTAssertNil(achievement.achievedDateText)
        XCTAssertEqual(achievement.progressText, "20/20")
    }
}

@MainActor
final class CollectionViewModelTests: XCTestCase {
    func test_불러오면_도감을_보여준다() async {
        let model = CollectionViewModel(repository: StubCollectionRepository([.success(sampleCollection())]))
        XCTAssertEqual(model.state, .loading)
        await model.load()
        XCTAssertEqual(model.state, .loaded(sampleCollection()))
    }

    func test_처음_실패하면_에러_문구를_보여주고_다시_시도하면_성공한다() async {
        let model = CollectionViewModel(
            repository: StubCollectionRepository([.failure(.network), .success(sampleCollection())]))
        await model.load()
        XCTAssertEqual(model.state, .failed(APIError.network.userMessage))
        await model.load()
        XCTAssertEqual(model.state, .loaded(sampleCollection()))
    }

    func test_이미_보여주는_중에_새로고침이_실패해도_화면을_유지한다() async {
        let model = CollectionViewModel(
            repository: StubCollectionRepository([.success(sampleCollection()), .failure(.network)]))
        await model.load()
        await model.load()
        XCTAssertEqual(model.state, .loaded(sampleCollection()))
    }

    func test_새로고침하면_새_배지_수가_반영된다() async {
        let model = CollectionViewModel(
            repository: StubCollectionRepository([.success(sampleCollection(total: 23)), .success(sampleCollection(total: 24))]))
        await model.load()
        await model.load()
        XCTAssertEqual(model.collection?.totalBadges, 24)
    }
}

final class RemoteCollectionRepositoryTests: XCTestCase {
    private func makeRepository(handler: @escaping StubTransport.Handler) -> (RemoteCollectionRepository, StubTransport) {
        let transport = StubTransport(handler)
        let client = APIClient(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")), transport: transport)
        return (RemoteCollectionRepository(client: client), transport)
    }

    func test_응답을_도감으로_바꾼다() async throws {
        let json = """
        {"totalBadges":23,"visitedParks":11,
         "types":[{"parkType":"NEIGHBORHOOD","count":9},{"parkType":"UNKNOWN_TYPE","count":4}],
         "achievements":[
           {"code":"FIRST_BADGE","name":"첫 배지","label":"첫","achievedAt":"2026-09-02T12:00:00+09:00","progress":1,"target":1},
           {"code":"PARKS_20","name":"서로 다른 공원 20곳","label":"20","achievedAt":null,"progress":11,"target":20}]}
        """
        let (repository, transport) = makeRepository { _ in (200, json) }
        let collection = try await repository.collection()

        XCTAssertEqual(transport.requests.first?.url?.path, "/api/users/me/collection")
        XCTAssertEqual(collection.totalBadges, 23)
        XCTAssertEqual(collection.visitedParks, 11)
        XCTAssertEqual(collection.count(of: .neighborhood), 9)
        XCTAssertEqual(collection.typeCounts.count, 1, "알 수 없는 유형은 건너뛴다")
        XCTAssertEqual(collection.achievements.map(\.id), ["FIRST_BADGE", "PARKS_20"])
        XCTAssertTrue(collection.achievements[0].isAchieved)
        XCTAssertFalse(collection.achievements[1].isAchieved)
    }

    func test_서버_오류는_그대로_던진다() async {
        let (repository, _) = makeRepository { _ in (500, "{}") }
        do {
            _ = try await repository.collection()
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .server(status: 500, code: nil))
        }
    }
}
