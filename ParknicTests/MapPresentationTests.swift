import XCTest
@testable import Parknic

private final class StubNamer: NeighborhoodNaming, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [Coordinate] = []
    var results: [String?]
    init(_ results: [String?]) { self.results = results }
    var requests: [Coordinate] { lock.withLock { _requests } }

    func name(at coordinate: Coordinate) async -> String? {
        let index = lock.withLock { () -> Int in
            _requests.append(coordinate)
            return _requests.count - 1
        }
        return results[min(index, results.count - 1)]
    }
}

final class ParkAreaTests: XCTestCase {
    private func park(id: Int, radius: Double) -> Park {
        Park(
            id: id, name: "공원", type: .neighborhood, coordinate: Coordinate(latitude: 37.4934, longitude: 126.9209),
            radiusM: radius, status: .none, badgeCount: 0)
    }

    func test_공원_면은_반경_둘레에서_일정_폭_안으로만_일렁인다() {
        let park = park(id: 1024, radius: 180)
        let outline = ParkArea.outline(for: park)
        XCTAssertEqual(outline.count, ParkArea.outlinePointCount)
        for point in outline {
            let distance = park.coordinate.distance(to: point)
            XCTAssertGreaterThan(distance, 180.0 * (1 - ParkArea.maxWobble) - 1)
            XCTAssertLessThan(distance, 180.0 * (1 + ParkArea.maxWobble) + 1)
        }
    }

    func test_같은_공원은_언제나_같은_모양이고_공원마다_모양이_다르다() {
        XCTAssertEqual(ParkArea.outline(for: park(id: 7, radius: 100)), ParkArea.outline(for: park(id: 7, radius: 100)))
        XCTAssertNotEqual(ParkArea.outline(for: park(id: 7, radius: 100)), ParkArea.outline(for: park(id: 8, radius: 100)))
    }
}

@MainActor
final class NeighborhoodNameTests: XCTestCase {
    private let origin = Coordinate(latitude: 37.4934, longitude: 126.9209)

    private func make(_ namer: StubNamer) -> (MapHomeViewModel, FakeLocationSource, Task<Void, Never>) {
        let provider = FakeLocationSource()
        let model = MapHomeViewModel(
            location: provider, nearby: NearbyParksViewModel(repository: EmptyParks()),
            checkIn: CheckInCoordinator(
                repository: MockCheckInRepository(), location: CoreLocationSampleSource(), notifier: LocalCheckInNotifier(),
                store: UserDefaultsCheckInStore(defaults: UserDefaults(suiteName: "tests.map.name") ?? .standard)),
            parks: EmptyParks(), neighborhood: namer)
        return (model, provider, Task { await model.run() })
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<300 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }

    func test_위치가_들어오면_동네_이름을_구한다() async {
        let (model, provider, task) = make(StubNamer(["신대방동"]))
        XCTAssertNil(model.neighborhoodName)
        await waitUntil { provider.started }
        provider.send(.location(origin))
        await waitUntil { model.neighborhoodName != nil }
        XCTAssertEqual(model.neighborhoodName, "신대방동")
        provider.finish(); await task.value
    }

    func test_300m_안에서는_다시_구하지_않고_넘어가면_다시_구한다() async {
        let namer = StubNamer(["신대방동", "대방동"])
        let (model, provider, task) = make(namer)
        await waitUntil { provider.started }
        provider.send(.location(origin))
        await waitUntil { model.neighborhoodName == "신대방동" }

        provider.send(.location(Coordinate(latitude: 37.4934 + 0.001, longitude: 126.9209)))  // 약 110m
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(namer.requests.count, 1)

        provider.send(.location(Coordinate(latitude: 37.4934 + 0.004, longitude: 126.9209)))  // 약 445m
        await waitUntil { model.neighborhoodName == "대방동" }
        XCTAssertEqual(namer.requests.count, 2)
        provider.finish(); await task.value
    }

    func test_이름을_못_구하면_이전_이름을_그대로_둔다() async {
        let (model, provider, task) = make(StubNamer(["신대방동", nil]))
        await waitUntil { provider.started }
        provider.send(.location(origin))
        await waitUntil { model.neighborhoodName == "신대방동" }
        provider.send(.location(Coordinate(latitude: 37.4934 + 0.004, longitude: 126.9209)))
        try? await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(model.neighborhoodName, "신대방동")
        provider.finish(); await task.value
    }
}

@MainActor
private final class FakeLocationSource: LocationProviding {
    private var continuation: AsyncStream<LocationEvent>.Continuation?
    private(set) var started = false
    func events() -> AsyncStream<LocationEvent> {
        started = true
        return AsyncStream { self.continuation = $0 }
    }
    func requestPermissionIfNeeded() {}
    func send(_ event: LocationEvent) { continuation?.yield(event) }
    func finish() { continuation?.finish() }
}

private struct EmptyParks: ParkRepository {
    func nearby(center: Coordinate, radiusM: Int) async throws -> [Park] { [] }
    func detail(parkID: Int) async throws -> ParkDetail { throw APIError.network }
    func topRated(center: Coordinate, radiusM: Int) async throws -> [TopRatedPark] { [] }
}
