import XCTest
@testable import Parknic

// MARK: - 가짜 구현

private final class FakeCheckInRepository: CheckInRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [String] = []
    private var _completeCoordinates: [Coordinate?] = []
    private var _pausedSeconds: [Int] = []
    var startResult: Result<CheckInSession, APIError>
    var completeResults: [Result<CheckInResult, APIError>] = []
    var currentSession: CheckInSession?
    var failError: APIError?

    init(session: CheckInSession) { startResult = .success(session) }

    var calls: [String] { lock.withLock { _calls } }
    var completeCoordinates: [Coordinate?] { lock.withLock { _completeCoordinates } }
    var pausedSeconds: [Int] { lock.withLock { _pausedSeconds } }

    func start(parkID: Int, at coordinate: Coordinate) async throws -> CheckInSession {
        lock.withLock { _calls.append("start:\(parkID)") }
        return try startResult.get()
    }

    func current() async throws -> CheckInSession? {
        lock.withLock { _calls.append("current") }
        return currentSession
    }

    func complete(sessionID: Int, at coordinate: Coordinate?, pausedSeconds: Int) async throws -> CheckInResult {
        let result = lock.withLock { () -> Result<CheckInResult, APIError> in
            _calls.append("complete:\(sessionID)")
            _completeCoordinates.append(coordinate)
            _pausedSeconds.append(pausedSeconds)
            return completeResults.isEmpty ? .success(Self.sampleResult) : completeResults.removeFirst()
        }
        return try result.get()
    }

    func fail(sessionID: Int, reason: CheckInFailureReason) async throws {
        lock.withLock { _calls.append("fail:\(sessionID):\(reason.rawValue)") }
        if let failError { throw failError }
    }

    func cancel(sessionID: Int) async throws {
        lock.withLock { _calls.append("cancel:\(sessionID)") }
    }

    static let sampleResult = CheckInResult(
        badge: EarnedBadge(parkID: 1024, parkName: "보라매공원", parkType: .neighborhood, earnedAt: Date(timeIntervalSince1970: 0)),
        newAchievements: [Achievement(code: "PARKS_10", name: "공원 10곳 정복")],
        monthlyRanking: MonthlyRankingSummary(rank: 5, badgeCount: 4, rankChange: 1, badgesToPodium: 3),
        canWriteReview: true)
}

@MainActor
private final class FakeLocation: LocationSampleSource {
    private var continuation: AsyncStream<LocationSample>.Continuation?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() -> AsyncStream<LocationSample> {
        startCount += 1
        return AsyncStream { continuation in self.continuation = continuation }
    }

    func stop() {
        stopCount += 1
        continuation?.finish()
        continuation = nil
    }

    func send(_ sample: LocationSample) { continuation?.yield(sample) }
}

private final class FakeNotifier: CheckInNotifying, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [String] = []
    var events: [String] { lock.withLock { _events } }
    func warnOutOfRange() async { lock.withLock { _events.append("warn") } }
    func clearOutOfRangeWarning() async { lock.withLock { _events.append("clear") } }
    func notifyEarned(parkName: String) async { lock.withLock { _events.append("earned:\(parkName)") } }
}

private final class MemoryCheckInStore: CheckInStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: CheckInSession?
    init(_ session: CheckInSession? = nil) { self.session = session }
    func load() -> CheckInSession? { lock.withLock { session } }
    func save(_ session: CheckInSession) { lock.withLock { self.session = session } }
    func clear() { lock.withLock { session = nil } }
}

// MARK: - 테스트

@MainActor
final class CheckInCoordinatorTests: XCTestCase {
    private let center = Coordinate(latitude: 37.4934, longitude: 126.9209)
    private let start = kst("2026-11-04T15:00:00+09:00")
    private var clock: FixedClock!
    private var session: CheckInSession!
    private var repository: FakeCheckInRepository!
    private var location: FakeLocation!
    private var notifier: FakeNotifier!
    private var store: MemoryCheckInStore!

    override func setUp() async throws {
        clock = FixedClock(start)
        session = CheckInSession(id: 7, parkID: 1024, parkName: "보라매공원", center: center, radiusM: 180, startedAt: start)
        repository = FakeCheckInRepository(session: session)
        location = FakeLocation()
        notifier = FakeNotifier()
        store = MemoryCheckInStore()
    }

    /// 틱은 테스트가 직접 부른다(자동 틱은 아주 오래 기다리게 한다).
    private func makeCoordinator(
        tickInterval: Duration = .seconds(3600),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { _ in try await Task.sleep(for: .seconds(3600)) }
    ) -> CheckInCoordinator {
        CheckInCoordinator(
            repository: repository, location: location, notifier: notifier, store: store, clock: clock,
            tickInterval: tickInterval, sleep: sleep)
    }

    private func point(metersNorth: Double, accuracy: Double = 10) -> LocationSample {
        LocationSample(
            coordinate: Coordinate(latitude: center.latitude + metersNorth / 111_195, longitude: center.longitude),
            horizontalAccuracy: accuracy)
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<400 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertTrue(condition(), "조건이 시간 안에 충족되지 않았다", file: file, line: line)
    }

    private func begun() async -> CheckInCoordinator {
        let coordinator = makeCoordinator()
        await coordinator.begin(parkID: 1024, at: center)
        return coordinator
    }

    // MARK: 시작

    func test_시작하면_세션을_저장하고_위치_수신을_시작한다() async {
        let coordinator = await begun()
        XCTAssertEqual(coordinator.state, .inProgress(session))
        XCTAssertEqual(coordinator.remaining, 1200)
        XCTAssertEqual(store.load(), session)
        XCTAssertEqual(location.startCount, 1)
        XCTAssertEqual(repository.calls, ["start:1024"])
    }

    func test_시작에_실패하면_안내_문구를_주고_아무것도_시작하지_않는다() async {
        repository.startResult = .failure(.server(status: 409, code: "CHECKIN_ALREADY_IN_PROGRESS"))
        let coordinator = makeCoordinator()
        await coordinator.begin(parkID: 1024, at: center)

        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertEqual(coordinator.startErrorMessage, "이미 진행 중인 체크인이 있어요")
        XCTAssertNil(store.load())
        XCTAssertEqual(location.startCount, 0)
    }

    func test_진행_중에는_다시_시작하지_않는다() async {
        let coordinator = await begun()
        await coordinator.begin(parkID: 9, at: center)
        XCTAssertEqual(repository.calls, ["start:1024"])
    }

    // MARK: 이탈과 복귀

    func test_반경을_벗어나면_경고_알림을_보낸다() async {
        let coordinator = await begun()
        location.send(point(metersNorth: 300))
        await waitUntil { self.notifier.events == ["warn"] }
        if case .outOfRange = coordinator.state {} else { XCTFail("이탈 상태여야 한다: \(coordinator.state)") }
    }

    func test_1분_안에_돌아오면_경고를_거두고_이어간다() async {
        let coordinator = await begun()
        location.send(point(metersNorth: 300))
        await waitUntil { self.notifier.events == ["warn"] }
        clock.advance(by: 30)
        location.send(point(metersNorth: 20))
        await waitUntil { self.notifier.events == ["warn", "clear"] }
        XCTAssertEqual(coordinator.state, .inProgress(session))
    }

    func test_이탈_후_1분이_지나면_실패를_서버에_알리고_측정을_멈춘다() async {
        let coordinator = await begun()
        location.send(point(metersNorth: 300))
        await waitUntil { self.notifier.events == ["warn"] }

        clock.advance(by: 60)
        await coordinator.tick()

        XCTAssertEqual(coordinator.state, .failed(session, .outOfRange))
        XCTAssertEqual(coordinator.stayed, 0, "이탈한 시점까지 반경 안에 머문 시간만 센다")
        XCTAssertEqual(repository.calls.last, "fail:7:OUT_OF_RANGE")
        XCTAssertEqual(location.stopCount, 1)
        XCTAssertNil(store.load(), "끝난 세션은 복구 대상이 아니다")
    }

    // MARK: 완료

    func test_20분이_지나면_마지막_위치와_함께_완료하고_알림을_보낸다() async {
        let coordinator = await begun()
        let inside = point(metersNorth: 40)
        location.send(inside)
        await waitUntil { coordinator.state == .inProgress(self.session) && self.location.startCount == 1 }
        try? await Task.sleep(for: .milliseconds(30))

        clock.advance(by: 1200)
        await coordinator.tick()

        XCTAssertEqual(coordinator.state, .completed(session))
        XCTAssertEqual(coordinator.result, FakeCheckInRepository.sampleResult)
        XCTAssertEqual(repository.completeCoordinates.first, inside.coordinate)
        XCTAssertEqual(notifier.events.last, "earned:보라매공원")
        XCTAssertEqual(location.stopCount, 1)
        XCTAssertNil(store.load())
    }

    func test_밖에_있던_시간은_완료_요청에_함께_보내고_그만큼_더_머물러야_한다() async {
        let coordinator = await begun()
        location.send(point(metersNorth: 300))
        await waitUntil { self.notifier.events == ["warn"] }
        clock.advance(by: 30)
        location.send(point(metersNorth: 20))
        await waitUntil { self.notifier.events == ["warn", "clear"] }

        // 시작 후 1200초가 지났지만 밖에 30초 있었으므로 아직 20분이 안 됐다
        clock.advance(by: 1170)
        await coordinator.tick()
        XCTAssertEqual(coordinator.state, .inProgress(session))
        XCTAssertEqual(coordinator.remaining, 30)

        clock.advance(by: 30)
        await coordinator.tick()
        XCTAssertEqual(coordinator.state, .completed(session))
        XCTAssertEqual(repository.pausedSeconds, [30])
    }

    func test_서버가_아직_20분_미달이라고_하면_진행을_이어가고_나중에_다시_요청한다() async {
        repository.completeResults = [.failure(.server(status: 400, code: "CHECKIN_TOO_EARLY"))]
        let coordinator = await begun()
        clock.advance(by: 1200)
        await coordinator.tick()
        XCTAssertEqual(coordinator.state, .inProgress(session))
        XCTAssertNil(coordinator.result)
        XCTAssertEqual(location.stopCount, 0, "측정은 계속된다")

        clock.advance(by: 10)
        await coordinator.tick()
        XCTAssertEqual(coordinator.state, .completed(session))
        XCTAssertEqual(repository.calls.filter { $0.hasPrefix("complete") }.count, 2)
    }

    func test_연결_문제로_완료에_실패해도_진행을_이어간다() async {
        repository.completeResults = [.failure(.network)]
        let coordinator = await begun()
        clock.advance(by: 1200)
        await coordinator.tick()
        XCTAssertEqual(coordinator.state, .inProgress(session))
    }

    func test_서버가_자정_경과라고_하면_자정_실패로_끝낸다() async {
        repository.completeResults = [.failure(.server(status: 400, code: "CHECKIN_EXPIRED_MIDNIGHT"))]
        let coordinator = await begun()
        clock.advance(by: 1200)
        await coordinator.tick()
        XCTAssertEqual(coordinator.state, .failed(session, .midnight))
        XCTAssertEqual(location.stopCount, 1)
        XCTAssertNil(store.load())
    }

    func test_서버가_반경_밖이라고_하면_이탈_실패로_끝낸다() async {
        repository.completeResults = [.failure(.server(status: 400, code: "CHECKIN_OUT_OF_RANGE"))]
        let coordinator = await begun()
        clock.advance(by: 1200)
        await coordinator.tick()
        XCTAssertEqual(coordinator.state, .failed(session, .outOfRange))
    }

    func test_이미_오늘_받은_공원이면_배지_없이_끝낸다() async {
        repository.completeResults = [.failure(.server(status: 409, code: "BADGE_ALREADY_EARNED_TODAY"))]
        let coordinator = await begun()
        clock.advance(by: 1200)
        await coordinator.tick()
        XCTAssertEqual(coordinator.state, .cancelled(session))
        XCTAssertNil(coordinator.result)
        XCTAssertEqual(location.stopCount, 1)
    }

    // MARK: 자정·취소

    func test_자정이_되면_진행_중인_체크인을_실패_처리한다() async {
        let late = kst("2026-11-04T23:50:00+09:00")
        clock.set(late)
        session = CheckInSession(id: 7, parkID: 1024, parkName: "보라매공원", center: center, radiusM: 180, startedAt: late)
        repository.startResult = .success(session)
        let coordinator = await begun()

        clock.set(kst("2026-11-05T00:00:00+09:00"))
        await coordinator.tick()

        XCTAssertEqual(coordinator.state, .failed(session, .midnight))
        XCTAssertEqual(repository.calls.last, "fail:7:MIDNIGHT")
        XCTAssertNil(store.load())
    }

    func test_취소하면_서버에_알리고_측정을_멈춘다() async {
        let coordinator = await begun()
        await coordinator.cancel()
        XCTAssertEqual(coordinator.state, .cancelled(session))
        XCTAssertEqual(repository.calls.last, "cancel:7")
        XCTAssertEqual(location.stopCount, 1)
        XCTAssertNil(store.load())
    }

    // MARK: 재실행 복구

    func test_기기에_저장된_세션이_있으면_강제_종료로_보고_실패_처리한다() async {
        store = MemoryCheckInStore(session)
        let coordinator = makeCoordinator()

        await coordinator.recoverOnLaunch()

        XCTAssertEqual(coordinator.state, .failed(session, .appTerminated))
        XCTAssertEqual(repository.calls, ["fail:7:APP_TERMINATED"])
        XCTAssertNil(store.load())
    }

    func test_기기에_없어도_서버에_진행_중인_세션이_있으면_실패_처리한다() async {
        repository.currentSession = session
        let coordinator = makeCoordinator()

        await coordinator.recoverOnLaunch()

        XCTAssertEqual(coordinator.state, .failed(session, .appTerminated))
        XCTAssertEqual(repository.calls, ["current", "fail:7:APP_TERMINATED"])
    }

    func test_복구할_세션이_없으면_아무것도_하지_않는다() async {
        let coordinator = makeCoordinator()
        await coordinator.recoverOnLaunch()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertEqual(repository.calls, ["current"])
    }

    func test_서버에_실패를_알리지_못해도_사용자에게는_실패로_안내한다() async {
        store = MemoryCheckInStore(session)
        repository.failError = .network
        let coordinator = makeCoordinator()

        await coordinator.recoverOnLaunch()

        XCTAssertEqual(coordinator.state, .failed(session, .appTerminated))
        XCTAssertNil(store.load(), "다음 실행에서 같은 안내가 반복되지 않게 지운다")
    }

    func test_진행_중에는_복구를_건너뛴다() async {
        store = MemoryCheckInStore(session)
        let coordinator = await begun()
        await coordinator.recoverOnLaunch()
        XCTAssertEqual(coordinator.state, .inProgress(session))
        XCTAssertFalse(repository.calls.contains { $0.hasPrefix("fail") })
    }

    // MARK: 마무리

    func test_안내를_닫으면_처음_상태로_돌아가고_다시_시작할_수_있다() async {
        let coordinator = await begun()
        await coordinator.cancel()
        coordinator.dismiss()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertNil(coordinator.result)

        await coordinator.begin(parkID: 1024, at: center)
        XCTAssertEqual(coordinator.state, .inProgress(session))
        XCTAssertEqual(location.startCount, 2)
    }

    func test_주기_타이머가_스스로_틱을_돌려_20분을_완료한다() async {
        let coordinator = makeCoordinator(
            tickInterval: .milliseconds(10), sleep: { try await Task.sleep(for: $0) })
        await coordinator.begin(parkID: 1024, at: center)
        clock.advance(by: 1200)

        await waitUntil { coordinator.state == .completed(self.session) }
        XCTAssertEqual(coordinator.result, FakeCheckInRepository.sampleResult)
    }
}
