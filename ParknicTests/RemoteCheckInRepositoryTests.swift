import XCTest
@testable import Parknic

final class RemoteCheckInRepositoryTests: XCTestCase {
    private func makeRepository(handler: @escaping StubTransport.Handler) -> (RemoteCheckInRepository, StubTransport) {
        let transport = StubTransport(handler)
        let client = APIClient(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")), transport: transport)
        return (RemoteCheckInRepository(client: client), transport)
    }

    private func body(_ request: URLRequest?) throws -> [String: Any] {
        let data = try XCTUnwrap(request?.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private let sessionJSON = """
        {"id":7,"parkId":1024,"parkName":"보라매공원","latitude":37.4934,"longitude":126.9209,"radiusM":180,"startedAt":"2026-11-04T15:00:00+09:00"}
        """

    func test_시작하면_좌표를_보내고_서버_시작_시각을_받는다() async throws {
        let (repository, transport) = makeRepository { _ in (200, self.sessionJSON) }
        let session = try await repository.start(parkID: 1024, at: Coordinate(latitude: 37.49, longitude: 126.92))

        XCTAssertEqual(session.id, 7)
        XCTAssertEqual(session.radiusM, 180)
        XCTAssertEqual(session.startedAt, kst("2026-11-04T15:00:00+09:00"))
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/check-ins")
        XCTAssertEqual(transport.requests.first?.httpMethod, "POST")
        let json = try body(transport.requests.first)
        XCTAssertEqual(json["parkId"] as? Int, 1024)
        XCTAssertEqual(json["lat"] as? Double, 37.49)
        XCTAssertEqual(json["lng"] as? Double, 126.92)
    }

    func test_진행_중인_세션이_없으면_nil이다() async throws {
        let (repository, _) = makeRepository { _ in (404, "{}") }
        let current = try await repository.current()
        XCTAssertNil(current)
    }

    func test_진행_중인_세션을_돌려준다() async throws {
        let (repository, transport) = makeRepository { _ in (200, self.sessionJSON) }
        let current = try await repository.current()
        XCTAssertEqual(current?.parkName, "보라매공원")
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/check-ins/current")
    }

    func test_현재_세션_조회의_다른_오류는_던진다() async {
        let (repository, _) = makeRepository { _ in (500, "{}") }
        do {
            _ = try await repository.current()
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .server(status: 500, code: nil))
        }
    }

    func test_옛_서버가_monthlyRanking으로_줘도_배지는_정상_처리한다() async throws {
        let json = """
            {"badge":{"parkId":1024,"parkName":"보라매공원","parkType":"NEIGHBORHOOD","earnedAt":"2026-11-04T15:32:10+09:00"},
             "newAchievements":[],
             "monthlyRanking":{"rank":2,"badgeCount":9,"rankChange":0,"badgesToPodium":0},
             "canWriteReview":true}
            """
        let (repository, _) = makeRepository { _ in (200, json) }
        let result = try await repository.complete(sessionID: 7, at: Coordinate(latitude: 37.4, longitude: 126.9), pausedSeconds: 0)
        XCTAssertEqual(result.weeklyRanking, WeeklyRankingSummary(rank: 2, badgeCount: 9, rankChange: 0, badgesToPodium: 0))
    }

    func test_두_이름이_함께_오면_weeklyRanking을_쓴다() async throws {
        let json = """
            {"badge":{"parkId":1,"parkName":"A","parkType":"SMALL","earnedAt":"2026-11-04T15:32:10+09:00"},
             "newAchievements":[],
             "weeklyRanking":{"rank":1,"badgeCount":1,"rankChange":0,"badgesToPodium":0},
             "monthlyRanking":{"rank":9,"badgeCount":9,"rankChange":0,"badgesToPodium":0},
             "canWriteReview":false}
            """
        let (repository, _) = makeRepository { _ in (200, json) }
        let result = try await repository.complete(sessionID: 7, at: nil, pausedSeconds: 0)
        XCTAssertEqual(result.weeklyRanking.rank, 1)
    }

    func test_랭킹_정보가_둘_다_없으면_오류다() async {
        let json = """
            {"badge":{"parkId":1,"parkName":"A","parkType":"SMALL","earnedAt":"2026-11-04T15:32:10+09:00"},
             "newAchievements":[],"canWriteReview":false}
            """
        let (repository, _) = makeRepository { _ in (200, json) }
        do {
            _ = try await repository.complete(sessionID: 7, at: nil, pausedSeconds: 0)
            XCTFail("랭킹 정보가 없으면 해석에 실패해야 한다")
        } catch {
            // 해석 실패는 호출한 쪽에서 오류로 처리한다
        }
    }

    func test_완료_응답을_도메인_모델로_바꾼다() async throws {
        let json = """
            {"badge":{"parkId":1024,"parkName":"보라매공원","parkType":"NEIGHBORHOOD","earnedAt":"2026-11-04T15:32:10+09:00"},
             "newAchievements":[{"code":"PARKS_10","name":"공원 10곳 정복"}],
             "weeklyRanking":{"rank":5,"badgeCount":4,"rankChange":1,"badgesToPodium":3},
             "canWriteReview":true}
            """
        let (repository, transport) = makeRepository { _ in (200, json) }
        let result = try await repository.complete(sessionID: 7, at: Coordinate(latitude: 37.4, longitude: 126.9), pausedSeconds: 42)

        XCTAssertEqual(result.badge.parkType, .neighborhood)
        XCTAssertEqual(result.badge.earnedAt, kst("2026-11-04T15:32:10+09:00"))
        XCTAssertEqual(result.newAchievements, [Achievement(code: "PARKS_10", name: "공원 10곳 정복")])
        XCTAssertEqual(result.weeklyRanking, WeeklyRankingSummary(rank: 5, badgeCount: 4, rankChange: 1, badgesToPodium: 3))
        XCTAssertTrue(result.canWriteReview)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/check-ins/7/complete")
        XCTAssertEqual(try body(transport.requests.first)["lat"] as? Double, 37.4)
        XCTAssertEqual(try body(transport.requests.first)["pausedSeconds"] as? Int, 42, "반경 밖에 있던 시간을 서버에 알린다")
    }

    func test_완료_요청은_좌표가_없으면_좌표를_보내지_않는다() async throws {
        let json = """
            {"badge":{"parkId":1,"parkName":"a","parkType":"SMALL","earnedAt":"2026-11-04T15:32:10+09:00"},
             "newAchievements":[],"weeklyRanking":{"rank":1,"badgeCount":1,"rankChange":0,"badgesToPodium":0},"canWriteReview":false}
            """
        let (repository, transport) = makeRepository { _ in (200, json) }
        _ = try await repository.complete(sessionID: 7, at: nil, pausedSeconds: 0)
        let sent = try body(transport.requests.first)
        XCTAssertNil(sent["lat"])
        XCTAssertNil(sent["lng"])
    }

    func test_실패_사유를_서버_값으로_보낸다() async throws {
        let (repository, transport) = makeRepository { _ in (200, "{}") }
        try await repository.fail(sessionID: 7, reason: .appTerminated)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/check-ins/7/fail")
        XCTAssertEqual(try body(transport.requests.first)["reason"] as? String, "APP_TERMINATED")
    }

    func test_취소는_cancel_경로로_보낸다() async throws {
        let (repository, transport) = makeRepository { _ in (200, "{}") }
        try await repository.cancel(sessionID: 7)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/check-ins/7/cancel")
        XCTAssertEqual(transport.requests.first?.httpMethod, "POST")
    }

    func test_완료_거절_코드는_그대로_던진다() async {
        let (repository, _) = makeRepository { _ in (400, #"{"code":"CHECKIN_TOO_EARLY"}"#) }
        do {
            _ = try await repository.complete(sessionID: 7, at: nil, pausedSeconds: 0)
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual((error as? APIError)?.serverCode, .checkInTooEarly)
        }
    }
}

final class UserDefaultsCheckInStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "com.seongmo.parknic.tests.checkin"

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    private let session = CheckInSession(
        id: 7, parkID: 1024, parkName: "보라매공원", center: Coordinate(latitude: 37.49, longitude: 126.92),
        radiusM: 180, startedAt: Date(timeIntervalSince1970: 1_793_773_930))

    func test_저장한_세션을_다시_읽는다() {
        let store = UserDefaultsCheckInStore(defaults: defaults)
        store.save(session)
        XCTAssertEqual(store.load(), session)
    }

    func test_지우면_비어_있다() {
        let store = UserDefaultsCheckInStore(defaults: defaults)
        store.save(session)
        store.clear()
        XCTAssertNil(store.load())
    }

    func test_망가진_데이터는_nil로_읽는다() {
        defaults.set(Data("not json".utf8), forKey: "checkin.currentSession")
        XCTAssertNil(UserDefaultsCheckInStore(defaults: defaults).load())
    }
}
