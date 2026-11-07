import XCTest
@testable import Parknic

@MainActor
private final class FakeLocationProvider: LocationProviding {
    private var continuation: AsyncStream<LocationEvent>.Continuation?
    private(set) var permissionRequests = 0

    func events() -> AsyncStream<LocationEvent> {
        AsyncStream { self.continuation = $0 }
    }

    func requestPermissionIfNeeded() { permissionRequests += 1 }
    func send(_ event: LocationEvent) { continuation?.yield(event) }
    func finish() { continuation?.finish() }
}

private struct FixedParks: ParkRepository {
    func nearby(center: Coordinate, radiusM: Int) async throws -> [Park] { MockParkRepository.sample }
    func detail(parkID: Int) async throws -> ParkDetail { throw APIError.network }
    func topRated(center: Coordinate, radiusM: Int) async throws -> [TopRatedPark] { [] }
}

@MainActor
final class MapHomeViewModelTests: XCTestCase {
    private let origin = Coordinate(latitude: 37.4934, longitude: 126.9209)

    private func make() -> (MapHomeViewModel, FakeLocationProvider, Task<Void, Never>) {
        let provider = FakeLocationProvider()
        let model = MapHomeViewModel(location: provider, nearby: NearbyParksViewModel(repository: FixedParks()), checkIn: CheckInCoordinator(repository: MockCheckInRepository(), location: CoreLocationSampleSource(), notifier: LocalCheckInNotifier(), store: UserDefaultsCheckInStore(defaults: UserDefaults(suiteName: "tests.map") ?? .standard)), parks: FixedParks())
        let task = Task { await model.run() }
        return (model, provider, task)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<300 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }

    func test_시작하면_권한을_요청한다() async {
        let (_, provider, task) = make()
        await waitUntil { provider.permissionRequests == 1 }
        XCTAssertEqual(provider.permissionRequests, 1)
        provider.finish(); await task.value
    }

    func test_위치가_들어오면_주변_공원을_조회하고_지도를_내_위치로_옮긴다() async {
        let (model, provider, task) = make()
        await waitUntil { provider.permissionRequests == 1 }
        provider.send(.authorization(.authorized))
        provider.send(.location(origin))
        await waitUntil { model.nearby.parks.count == 6 }

        XCTAssertEqual(model.nearby.parks.count, 6)
        XCTAssertEqual(model.recenterToken, 1)
        provider.finish(); await task.value
    }

    func test_위치가_계속_들어와도_지도를_다시_옮기지_않는다() async {
        let (model, provider, task) = make()
        await waitUntil { provider.permissionRequests == 1 }
        provider.send(.location(origin))
        provider.send(.location(Coordinate(latitude: 37.4940, longitude: 126.9209)))
        await waitUntil { model.nearby.currentLocation?.latitude == 37.4940 }
        XCTAssertEqual(model.recenterToken, 1, "사용자가 지도를 움직이는 중에 계속 끌려오면 안 된다")
        provider.finish(); await task.value
    }

    func test_현위치_버튼을_누르면_다시_옮긴다() {
        let provider = FakeLocationProvider()
        let model = MapHomeViewModel(location: provider, nearby: NearbyParksViewModel(repository: FixedParks()), checkIn: CheckInCoordinator(repository: MockCheckInRepository(), location: CoreLocationSampleSource(), notifier: LocalCheckInNotifier(), store: UserDefaultsCheckInStore(defaults: UserDefaults(suiteName: "tests.map") ?? .standard)), parks: FixedParks())
        model.recenter()
        XCTAssertEqual(model.recenterToken, 1)
    }

    func test_권한이_거부되면_안내_화면을_보여준다() async {
        let (model, provider, task) = make()
        await waitUntil { provider.permissionRequests == 1 }
        provider.send(.authorization(.denied))
        await waitUntil { model.authorization == .denied }
        XCTAssertTrue(model.showsLocationDenied)
        provider.finish(); await task.value
    }

    func test_둘러보기를_고르면_안내를_닫는다() async {
        let (model, provider, task) = make()
        await waitUntil { provider.permissionRequests == 1 }
        provider.send(.authorization(.denied))
        await waitUntil { model.authorization == .denied }
        model.browseWithoutLocation()
        XCTAssertFalse(model.showsLocationDenied)
        XCTAssertTrue(model.isBrowsingWithoutLocation)
        provider.finish(); await task.value
    }

    func test_나중에_권한을_켜면_안내가_사라지고_둘러보기_상태가_풀린다() async {
        let (model, provider, task) = make()
        await waitUntil { provider.permissionRequests == 1 }
        provider.send(.authorization(.denied))
        await waitUntil { model.authorization == .denied }
        model.browseWithoutLocation()
        provider.send(.authorization(.authorized))
        await waitUntil { model.authorization == .authorized }
        XCTAssertFalse(model.isBrowsingWithoutLocation)
        XCTAssertFalse(model.showsLocationDenied)
        provider.finish(); await task.value
    }

    func test_권한을_아직_묻지_않았으면_거부_안내를_보이지_않는다() async {
        let (model, provider, task) = make()
        await waitUntil { provider.permissionRequests == 1 }
        provider.send(.authorization(.notDetermined))
        XCTAssertFalse(model.showsLocationDenied)
        provider.finish(); await task.value
    }

    func test_선택한_공원을_찾는다() async {
        let (model, provider, task) = make()
        await waitUntil { provider.permissionRequests == 1 }
        provider.send(.location(origin))
        await waitUntil { model.nearby.parks.count == 6 }
        model.selectedParkID = 1024
        XCTAssertEqual(model.selectedPark?.name, "보라매공원")
        model.selectedParkID = 999
        XCTAssertNil(model.selectedPark)
        provider.finish(); await task.value
    }

    func test_배지_결과가_없으면_리뷰_쓰기로_공원을_열지_않는다() async {
        let (model, _, task) = make()
        defer { task.cancel() }
        model.showsCheckInFlow = true

        await model.openReviewAfterBadge()

        XCTAssertFalse(model.showsCheckInFlow)
        XCTAssertNil(model.selectedParkID)
        XCTAssertNil(model.pendingReviewParkID)
    }


    func test_공원_시트를_닫으면_배지_화면에서_요청한_리뷰_랭킹_이동도_사라진다() {
        let (model, _, task) = make()
        defer { task.cancel() }
        model.pendingReviewParkID = 1024
        model.pendingRankingParkID = 1024

        model.closeParkSheet()

        XCTAssertNil(model.pendingReviewParkID)
        XCTAssertNil(model.pendingRankingParkID, "닫은 뒤 같은 공원을 다시 열었을 때 엉뚱하게 리뷰·랭킹 화면이 열리지 않는다")
    }

    func test_배지_화면에서_요청한_이동은_잠깐만_유효하다() {
        let (model, _, task) = make()
        defer { task.cancel() }
        XCTAssertEqual(model.pendingExpiresAt, .distantPast, "요청이 없으면 유효하지 않다")
        XCTAssertGreaterThan(MapHomeViewModel.pendingLifetime, 5)
        XCTAssertLessThanOrEqual(MapHomeViewModel.pendingLifetime, 30)
    }

    // MARK: 겹친 마커

    private func makeWithParks(_ parks: [Park]) -> MapHomeViewModel {
        MapHomeViewModel(
            location: FakeLocationProvider(),
            nearby: NearbyParksViewModel(repository: FixedParks(), initialState: .loaded(parks)),
            checkIn: CheckInCoordinator(repository: MockCheckInRepository(), location: CoreLocationSampleSource(), notifier: LocalCheckInNotifier(), store: UserDefaultsCheckInStore(defaults: UserDefaults(suiteName: "tests.map.overlap") ?? .standard)),
            parks: FixedParks())
    }

    private func park(_ id: Int, _ name: String, at coordinate: Coordinate) -> Park {
        Park(id: id, name: name, type: .children, coordinate: coordinate, radiusM: 100, status: .none, badgeCount: 0)
    }

    func test_겹친_마커를_누르면_공원_목록을_보여준다() {
        let here = Coordinate(latitude: 37.5016, longitude: 126.9858)
        let model = makeWithParks([
            park(2, "만남공원", at: here), park(1, "한수공원", at: here),
            park(3, "먼공원", at: Coordinate(latitude: 37.52, longitude: 127.0)),
        ])

        model.markerTapped(model.nearby.parks.first { $0.id == 1 }!)

        XCTAssertEqual(model.markerChoices?.map(\.name), ["만남공원", "한수공원"], "거리가 같으면 이름순, 먼 공원은 빠진다")
        XCTAssertNil(model.selectedParkID, "고르기 전에는 공원 정보를 열지 않는다")
    }

    func test_가까이_있어도_50m를_넘으면_겹친_것으로_보지_않는다() {
        let a = Coordinate(latitude: 37.5016, longitude: 126.9858)
        let b = Coordinate(latitude: 37.5016 + 0.0006, longitude: 126.9858)  // 약 67m
        let model = makeWithParks([park(1, "가", at: a), park(2, "나", at: b)])

        model.markerTapped(model.nearby.parks[0])

        XCTAssertNil(model.markerChoices)
        XCTAssertEqual(model.selectedParkID, 1)
    }

    func test_겹치지_않은_마커는_바로_공원_정보를_연다() {
        let model = makeWithParks([park(1, "혼자공원", at: Coordinate(latitude: 37.5, longitude: 127.0))])

        model.markerTapped(model.nearby.parks[0])

        XCTAssertNil(model.markerChoices)
        XCTAssertEqual(model.selectedParkID, 1)
    }

    func test_목록에서_공원을_고르면_목록을_닫고_그_공원을_연다() {
        let here = Coordinate(latitude: 37.5016, longitude: 126.9858)
        let model = makeWithParks([park(1, "한수공원", at: here), park(2, "만남공원", at: here)])
        model.markerTapped(model.nearby.parks[0])

        model.chooseMarkerPark(model.nearby.parks[1])

        XCTAssertNil(model.markerChoices)
        XCTAssertEqual(model.selectedParkID, 2)
    }

    func test_시트를_닫으면_목록과_선택이_모두_사라진다() {
        let here = Coordinate(latitude: 37.5016, longitude: 126.9858)
        let model = makeWithParks([park(1, "한수공원", at: here), park(2, "만남공원", at: here)])
        model.markerTapped(model.nearby.parks[0])

        model.closeParkSheet()

        XCTAssertNil(model.markerChoices)
        XCTAssertNil(model.selectedParkID)
    }

    func test_시트를_절반으로_되돌리라는_요청은_닫았다가_같은_공원으로_다시_연다() async {
        let model = makeWithParks([park(1, "한수공원", at: Coordinate(latitude: 37.5, longitude: 127.0))])
        model.selectedParkID = 1

        await model.reopenParkSheetAtHalf(after: .zero)

        XCTAssertEqual(model.selectedParkID, 1)
    }

    func test_열린_시트가_없으면_다시_열지_않는다() async {
        let model = makeWithParks([park(1, "한수공원", at: Coordinate(latitude: 37.5, longitude: 127.0))])

        await model.reopenParkSheetAtHalf(after: .zero)

        XCTAssertNil(model.selectedParkID)
    }

    func test_배지_결과가_없으면_랭킹_보기로_공원을_열지_않는다() async {
        let model = makeWithParks([])
        model.showsCheckInFlow = true

        await model.openRankingAfterBadge()

        XCTAssertFalse(model.showsCheckInFlow)
        XCTAssertNil(model.selectedParkID)
        XCTAssertNil(model.pendingRankingParkID)
    }

}
