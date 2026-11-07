import XCTest
@testable import Parknic

// MARK: - 체크인 버튼 상태

final class CheckInAvailabilityTests: XCTestCase {
    private let center = Coordinate(latitude: 37.4934, longitude: 126.9209)
    private func park(status: ParkVisitStatus = .none, radius: Double = 180) -> Park {
        Park(id: 1, name: "보라매공원", type: .neighborhood, coordinate: center, radiusM: radius, status: status, badgeCount: 0)
    }
    private func at(meters: Double) -> Coordinate {
        Coordinate(latitude: center.latitude + meters / 111_195, longitude: center.longitude)
    }
    private func session(parkID: Int) -> CheckInSession {
        CheckInSession(id: 9, parkID: parkID, parkName: "다른공원", center: center, radiusM: 100, startedAt: Date(timeIntervalSince1970: 0))
    }
    private func make(_ park: Park, _ location: Coordinate?, _ auth: LocationAuthorization = .authorized, active: CheckInSession? = nil) -> CheckInAvailability {
        CheckInAvailability.make(park: park, location: location, authorization: auth, activeSession: active)
    }

    func test_반경_안이면_체크인할_수_있다() {
        XCTAssertEqual(make(park(), at(meters: 100)), .available)
        XCTAssertTrue(make(park(), at(meters: 100)).isEnabled)
    }

    func test_반경_밖이면_공원까지의_거리를_알려주고_막는다() {
        guard case .outOfRange(let distance) = make(park(), at(meters: 870)) else { return XCTFail("반경 밖이어야 한다") }
        XCTAssertEqual(Double(distance), 870, accuracy: 3)
        XCTAssertFalse(make(park(), at(meters: 870)).isEnabled)
    }

    func test_오늘_받은_공원은_체크인할_수_없다() {
        XCTAssertEqual(make(park(status: .earnedToday), at(meters: 10)), .earnedToday)
        XCTAssertFalse(make(park(status: .earnedToday), at(meters: 10)).isEnabled)
    }

    func test_이전에_받은_적_있어도_오늘은_다시_체크인할_수_있다() {
        XCTAssertEqual(make(park(status: .earned), at(meters: 10)), .available)
    }

    func test_위치가_아직_없으면_기다린다() {
        XCTAssertEqual(make(park(), nil), .waitingForLocation)
    }

    func test_위치_권한이_거부되면_체크인할_수_없다() {
        XCTAssertEqual(make(park(), nil, .denied), .locationDenied)
        XCTAssertEqual(make(park(), at(meters: 10), .denied), .locationDenied)
    }

    func test_다른_공원에서_체크인_중이면_막는다() {
        XCTAssertEqual(make(park(), at(meters: 10), active: session(parkID: 2)), .anotherInProgress(parkName: "다른공원"))
        XCTAssertFalse(make(park(), at(meters: 10), active: session(parkID: 2)).isEnabled)
    }

    func test_같은_공원에서_체크인_중이면_진행_화면으로_돌아간다() {
        XCTAssertEqual(make(park(), at(meters: 10), active: session(parkID: 1)), .inProgressHere)
        XCTAssertTrue(make(park(), at(meters: 10), active: session(parkID: 1)).isEnabled)
    }

    func test_체크인_중이면_오늘_받은_공원이어도_진행_상태를_먼저_보여준다() {
        XCTAssertEqual(make(park(status: .earnedToday), at(meters: 10), active: session(parkID: 1)), .inProgressHere)
    }
}

// MARK: - 공원 시트 ViewModel

private struct DetailRepository: ParkRepository {
    var result: Result<ParkDetail, APIError>
    func nearby(center: Coordinate, radiusM: Int) async throws -> [Park] { [] }
    func detail(parkID: Int) async throws -> ParkDetail { try result.get() }
    func topRated(center: Coordinate, radiusM: Int) async throws -> [TopRatedPark] { [] }
}

@MainActor
final class ParkSheetViewModelTests: XCTestCase {
    private let park = MockParkRepository.sample[0]

    func test_상세를_불러오면_주소와_평점을_채운다() async {
        let detail = ParkDetail(park: park, address: "동작구", averageRating: 4.6, reviewCount: 128)
        let model = ParkSheetViewModel(park: park, repository: DetailRepository(result: .success(detail)))
        XCTAssertNil(model.detail, "불러오기 전에는 기본 정보만 있다")
        await model.load()
        XCTAssertEqual(model.detail, detail)
    }

    func test_상세_조회에_실패하면_에러_문구를_보여주고_재시도할_수_있다() async {
        let model = ParkSheetViewModel(park: park, repository: DetailRepository(result: .failure(.network)))
        await model.load()
        XCTAssertEqual(model.state, .failed(APIError.network.userMessage))
        XCTAssertNil(model.detail)
        XCTAssertEqual(model.park.name, "보라매공원", "상세가 실패해도 기본 정보는 그대로 보인다")
    }
}

// MARK: - 지도 홈의 체크인 시작

private final class CountingCheckInRepository: CheckInRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _started: [Int] = []
    var startError: APIError?
    var clock: AppClock = SystemClock()
    var completeResult: CheckInResult?
    var started: [Int] { lock.withLock { _started } }

    func start(parkID: Int, at coordinate: Coordinate) async throws -> CheckInSession {
        if let startError { throw startError }
        lock.withLock { _started.append(parkID) }
        return CheckInSession(
            id: 7, parkID: parkID, parkName: "공원\(parkID)", center: coordinate, radiusM: 180,
            startedAt: clock.now)
    }
    func current() async throws -> CheckInSession? { nil }
    func complete(sessionID: Int, at coordinate: Coordinate?, pausedSeconds: Int) async throws -> CheckInResult {
        guard let completeResult else { throw APIError.network }
        return completeResult
    }
    func fail(sessionID: Int, reason: CheckInFailureReason) async throws {}
    func cancel(sessionID: Int) async throws {}
}

@MainActor
private final class SilentLocationSource: LocationSampleSource {
    func start() -> AsyncStream<LocationSample> { AsyncStream { _ in } }
    func stop() {}
}

private struct SilentNotifier: CheckInNotifying {
    func warnOutOfRange() async {}
    func clearOutOfRangeWarning() async {}
    func notifyEarned(parkName: String) async {}
}

private struct MemoryStore: CheckInStore {
    func load() -> CheckInSession? { nil }
    func save(_ session: CheckInSession) {}
    func clear() {}
}

private struct ListRepository: ParkRepository {
    var parks: [Park]
    /// 주변 목록에는 없지만 상세로는 받을 수 있는 공원(예: 체크인하던 공원에서 멀리 벗어난 경우)
    var detailOnly: [Park] = []
    func nearby(center: Coordinate, radiusM: Int) async throws -> [Park] { parks }
    func detail(parkID: Int) async throws -> ParkDetail {
        guard let park = (parks + detailOnly).first(where: { $0.id == parkID }) else { throw APIError.network }
        return ParkDetail(park: park, address: "서울", averageRating: nil, reviewCount: 0)
    }
    func topRated(center: Coordinate, radiusM: Int) async throws -> [TopRatedPark] { [] }
}

private struct SilentLocationProvider: LocationProviding {
    func events() -> AsyncStream<LocationEvent> { AsyncStream { _ in } }
    func requestPermissionIfNeeded() {}
}

@MainActor
final class MapHomeCheckInTests: XCTestCase {
    private let center = Coordinate(latitude: 37.4934, longitude: 126.9209)
    private var repository: CountingCheckInRepository!

    override func setUp() async throws {
        repository = CountingCheckInRepository()
    }

    private func at(meters: Double) -> Coordinate {
        Coordinate(latitude: center.latitude + meters / 111_195, longitude: center.longitude)
    }

    private func park(_ id: Int, meters: Double, radius: Double = 100, status: ParkVisitStatus = .none) -> Park {
        Park(id: id, name: "공원\(id)", type: .small, coordinate: at(meters: meters), radiusM: radius, status: status, badgeCount: 0)
    }

    private let clock = FixedClock(Date(timeIntervalSince1970: 1_793_773_930))

    private func make(parks: [Park], detailOnly: [Park] = [], location: Coordinate?) async -> MapHomeViewModel {
        repository.clock = clock
        let coordinator = CheckInCoordinator(
            repository: repository, location: SilentLocationSource(), notifier: SilentNotifier(), store: MemoryStore(),
            clock: clock, sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        let model = MapHomeViewModel(
            location: SilentLocationProvider(), nearby: NearbyParksViewModel(repository: ListRepository(parks: parks)),
            checkIn: coordinator, parks: ListRepository(parks: parks, detailOnly: detailOnly))
        if let location {
            model.nearby.locationDidUpdate(location)
            for _ in 0..<200 where model.nearby.parks.isEmpty { try? await Task.sleep(for: .milliseconds(5)) }
        }
        return model
    }

    func test_반경_안_공원이_하나면_바로_체크인을_시작하고_체크인_화면을_연다() async {
        let target = park(1, meters: 0)
        let model = await make(parks: [target, park(2, meters: 600)], location: center)
        model.selectedParkID = 1

        await model.checkInTapped(on: target)

        XCTAssertEqual(repository.started, [1])
        XCTAssertTrue(model.showsCheckInFlow)
        XCTAssertNil(model.selectedParkID, "시작하면 공원 시트를 닫는다")
        XCTAssertNil(model.chooserParks)
    }

    func test_반경이_겹치면_바로_시작하지_않고_고르게_한다() async {
        let a = park(1, meters: 0)
        let b = park(2, meters: 40)
        let model = await make(parks: [a, b], location: at(meters: 10))

        await model.checkInTapped(on: a)

        XCTAssertTrue(repository.started.isEmpty)
        XCTAssertEqual(model.chooserParks?.map(\.id), [1, 2], "가까운 공원이 먼저 나온다")
    }

    func test_후보에서_고르면_그_공원으로_시작한다() async {
        let a = park(1, meters: 0)
        let b = park(2, meters: 40)
        let model = await make(parks: [a, b], location: at(meters: 30))
        await model.checkInTapped(on: a)

        await model.chooseForCheckIn(b)

        XCTAssertEqual(repository.started, [2])
        XCTAssertNil(model.chooserParks)
        XCTAssertTrue(model.showsCheckInFlow)
    }

    func test_오늘_이미_받은_공원은_후보에서_뺀다() async {
        let a = park(1, meters: 0)
        let todayDone = park(2, meters: 40, status: .earnedToday)
        let model = await make(parks: [a, todayDone], location: at(meters: 10))

        await model.checkInTapped(on: a)

        XCTAssertNil(model.chooserParks, "고를 후보가 하나뿐이면 묻지 않고 시작한다")
        XCTAssertEqual(repository.started, [1])
    }

    func test_반경_밖이면_아무것도_하지_않는다() async {
        let far = park(1, meters: 500)
        let model = await make(parks: [far], location: center)
        await model.checkInTapped(on: far)
        XCTAssertTrue(repository.started.isEmpty)
        XCTAssertFalse(model.showsCheckInFlow)
    }

    func test_위치를_모르면_시작하지_않는다() async {
        let target = park(1, meters: 0)
        let model = await make(parks: [target], location: nil)
        await model.checkInTapped(on: target)
        XCTAssertTrue(repository.started.isEmpty)
    }

    func test_시작에_실패하면_안내_문구를_보여주고_화면은_열지_않는다() async {
        repository.startError = .server(status: 409, code: "CHECKIN_ALREADY_IN_PROGRESS")
        let target = park(1, meters: 0)
        let model = await make(parks: [target], location: center)

        await model.checkInTapped(on: target)

        XCTAssertEqual(model.startErrorMessage, "이미 진행 중인 체크인이 있어요")
        XCTAssertFalse(model.showsCheckInFlow)
    }

    func test_체크인_중인_공원의_버튼을_누르면_진행_화면으로_돌아간다() async {
        let target = park(1, meters: 0)
        let model = await make(parks: [target], location: center)
        await model.checkInTapped(on: target)
        model.showsCheckInFlow = false

        await model.checkInTapped(on: target)

        XCTAssertTrue(model.showsCheckInFlow)
        XCTAssertEqual(repository.started, [1], "다시 시작하지 않는다")
    }

    func test_체크인_중에는_다른_공원을_시작할_수_없다() async {
        let a = park(1, meters: 0)
        let b = park(2, meters: 600)
        let model = await make(parks: [a, b], location: center)
        await model.checkInTapped(on: a)

        XCTAssertEqual(model.availability(for: b), .anotherInProgress(parkName: "공원1"), "반경 밖이어도 체크인 중이라는 이유를 먼저 보여준다")
        await model.checkInTapped(on: b)
        XCTAssertEqual(repository.started, [1])
    }

    func test_실패나_완료가_되면_체크인_화면을_연다() async {
        let target = park(1, meters: 0)
        let model = await make(parks: [target], location: center)
        let session = CheckInSession(id: 7, parkID: 1, parkName: "공원1", center: center, radiusM: 100, startedAt: Date())

        model.checkInStateDidChange(.failed(session, .outOfRange))
        XCTAssertTrue(model.showsCheckInFlow)
        model.showsCheckInFlow = false
        model.checkInStateDidChange(.completed(session))
        XCTAssertTrue(model.showsCheckInFlow)
    }

    func test_체크인이_정리되면_화면을_닫고_공원_목록을_새로_받는다() async {
        let target = park(1, meters: 0)
        let model = await make(parks: [target], location: center)
        model.showsCheckInFlow = true

        model.checkInStateDidChange(.idle)

        XCTAssertFalse(model.showsCheckInFlow)
    }

    func test_다시_체크인하기는_그_공원의_시트를_연다() async {
        let target = park(1, meters: 0)
        let model = await make(parks: [target], location: center)
        model.showsCheckInFlow = true

        await model.retryCheckIn(parkID: 1, after: .zero)

        XCTAssertFalse(model.showsCheckInFlow)
        XCTAssertEqual(model.selectedParkID, 1)
    }

    // MARK: 리뷰 좋은 공원

    func test_위치가_있으면_리뷰_좋은_공원_목록을_열_수_있다() async {
        let model = await make(parks: [park(1, meters: 0)], location: center)
        XCTAssertTrue(model.canShowTopRated)
        model.selectedParkID = 1

        model.openTopRated()

        XCTAssertTrue(model.showsTopRated)
        XCTAssertNil(model.selectedParkID, "열려 있던 공원 시트는 닫는다")
        XCTAssertNotNil(model.makeTopRatedViewModel())
    }

    func test_위치를_모르면_리뷰_좋은_공원_목록을_열_수_없다() async {
        let model = await make(parks: [park(1, meters: 0)], location: nil)
        XCTAssertFalse(model.canShowTopRated)
        model.openTopRated()
        XCTAssertFalse(model.showsTopRated)
        XCTAssertNil(model.makeTopRatedViewModel())
    }

    func test_목록에서_주변_공원을_고르면_목록을_닫고_공원_시트를_연다() async {
        let near = park(1, meters: 300)
        let model = await make(parks: [near], location: center)
        model.openTopRated()

        model.openTopRatedPark(near)

        XCTAssertFalse(model.showsTopRated)
        XCTAssertEqual(model.selectedParkID, 1)
        XCTAssertEqual(model.selectedPark?.id, 1)
        XCTAssertEqual(model.mapParks.map(\.id), [1], "이미 목록에 있으면 마커를 더하지 않는다")
        XCTAssertEqual(model.focusCoordinate, near.coordinate)
    }

    func test_목록에서_1km_밖_공원을_고르면_지도에_마커를_더하고_그_공원으로_옮긴다() async {
        let far = park(9, meters: 3800)
        let model = await make(parks: [park(1, meters: 300)], location: center)
        let token = model.focusToken

        model.openTopRatedPark(far)

        XCTAssertEqual(model.selectedPark?.id, 9, "주변 목록에 없어도 시트로 열린다")
        XCTAssertEqual(model.mapParks.map(\.id), [1, 9])
        XCTAssertEqual(model.focusCoordinate, far.coordinate)
        XCTAssertEqual(model.focusToken, token + 1)

        model.closeParkSheet()
        XCTAssertEqual(model.mapParks.map(\.id), [1], "시트를 닫으면 그 마커도 사라진다")
    }

    func test_다시_체크인하기는_주변_목록_밖으로_벗어난_공원도_시트로_연다() async {
        let far = park(7, meters: 2400)
        let model = await make(parks: [park(1, meters: 0)], detailOnly: [far], location: center)
        model.showsCheckInFlow = true

        await model.retryCheckIn(parkID: 7, after: .zero)

        XCTAssertFalse(model.showsCheckInFlow)
        XCTAssertEqual(model.selectedParkID, 7)
        XCTAssertEqual(model.selectedPark?.id, 7, "목록에 없어도 시트에 보여줄 공원이 있다")
    }

    func test_다시_체크인하기에서_상세도_못_받는_공원이면_시트를_열지_않는다() async {
        let model = await make(parks: [park(1, meters: 0)], location: center)
        await model.retryCheckIn(parkID: 99, after: .zero)
        XCTAssertNil(model.selectedParkID)
    }

    // MARK: 배지 획득 이후

    private func completedResult(parkID: Int) -> CheckInResult {
        CheckInResult(
            badge: EarnedBadge(parkID: parkID, parkName: "공원\(parkID)", parkType: .small, earnedAt: clock.now),
            newAchievements: [], weeklyRanking: WeeklyRankingSummary(rank: 5, badgeCount: 4, rankChange: 1, badgesToPodium: 3),
            canWriteReview: true)
    }

    private func completeCheckIn(_ model: MapHomeViewModel, park: Park) async {
        repository.completeResult = completedResult(parkID: park.id)
        await model.checkInTapped(on: park)
        clock.advance(by: 1200)
        await model.checkIn.tick()
    }

    func test_배지_순번은_목록의_내_배지_수에_이번_배지를_더한다() async {
        let target = Park(id: 1, name: "공원1", type: .small, coordinate: center, radiusM: 100, status: .earned, badgeCount: 3)
        let model = await make(parks: [target], location: center)
        await completeCheckIn(model, park: target)

        XCTAssertEqual(model.checkIn.state.isActive, false)
        XCTAssertEqual(model.badgeNumberAtPark, 4)
    }

    func test_배지_화면에서_랭킹이나_리뷰로_가면_체크인_화면을_닫고_그_공원_시트를_연다() async {
        let target = park(1, meters: 0)
        let model = await make(parks: [target], location: center)
        await completeCheckIn(model, park: target)
        model.showsCheckInFlow = true

        model.openParkAfterBadge()

        XCTAssertFalse(model.showsCheckInFlow)
        XCTAssertEqual(model.selectedParkID, 1)
        XCTAssertNil(model.checkIn.result, "결과 화면을 닫았으니 정리된다")
        XCTAssertEqual(model.checkIn.state, .idle)
    }

    func test_결과가_없으면_배지_순번을_모른다() async {
        let model = await make(parks: [park(1, meters: 0)], location: center)
        XCTAssertNil(model.badgeNumberAtPark)
    }
}
