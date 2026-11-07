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

}
