import XCTest
@testable import Parknic

private final class StubParkRepository: ParkRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _centers: [Coordinate] = []
    private var _radii: [Int] = []
    var parks: [Park] = MockParkRepository.sample
    var error: APIError?

    var centers: [Coordinate] { lock.withLock { _centers } }
    var radii: [Int] { lock.withLock { _radii } }

    func nearby(center: Coordinate, radiusM: Int) async throws -> [Park] {
        lock.withLock { _centers.append(center); _radii.append(radiusM) }
        if let error { throw error }
        return parks
    }

    func detail(parkID: Int) async throws -> ParkDetail {
        throw APIError.server(status: 404, code: nil)
    }

    func topRated(center: Coordinate, radiusM: Int) async throws -> [TopRatedPark] { [] }
}

@MainActor
final class NearbyParksViewModelTests: XCTestCase {
    private let origin = Coordinate(latitude: 37.4934, longitude: 126.9209)

    private func moved(meters: Double) -> Coordinate {
        Coordinate(latitude: origin.latitude + meters / 111_195, longitude: origin.longitude)
    }

    private func settle(_ model: NearbyParksViewModel) async {
        for _ in 0..<200 where model.state == .loading { try? await Task.sleep(for: .milliseconds(5)) }
        try? await Task.sleep(for: .milliseconds(10))
    }

    func test_처음_위치를_받으면_주변_공원을_조회한다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository)
        model.locationDidUpdate(origin)
        await settle(model)
        XCTAssertEqual(model.parks.count, 6)
        XCTAssertEqual(repository.centers, [origin])
    }

    func test_공원이_없으면_빈_상태다() async {
        let repository = StubParkRepository()
        repository.parks = []
        let model = NearbyParksViewModel(repository: repository)
        model.locationDidUpdate(origin)
        await settle(model)
        XCTAssertEqual(model.state, .empty)
    }

    func test_300m_미만_이동하면_다시_조회하지_않는다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository)
        model.locationDidUpdate(origin)
        await settle(model)
        model.locationDidUpdate(moved(meters: 299))
        await settle(model)
        XCTAssertEqual(repository.centers.count, 1)
        XCTAssertEqual(model.currentLocation, moved(meters: 299), "조회는 안 해도 현재 위치는 갱신한다")
    }

    func test_300m_이상_이동하면_다시_조회한다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository)
        model.locationDidUpdate(origin)
        await settle(model)
        model.locationDidUpdate(moved(meters: 301))
        await settle(model)
        XCTAssertEqual(repository.centers.count, 2)
    }

    func test_이동_거리는_마지막_조회_위치_기준으로_센다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository)
        model.locationDidUpdate(origin)
        await settle(model)
        // 조금씩 이동해도 누적되어 기준(마지막 조회 위치)에서 300m를 넘으면 조회한다
        model.locationDidUpdate(moved(meters: 200))
        model.locationDidUpdate(moved(meters: 310))
        await settle(model)
        XCTAssertEqual(repository.centers.count, 2)
    }

    func test_조회에_실패하면_에러이고_재시도로_복구된다() async {
        let repository = StubParkRepository()
        repository.error = .network
        let model = NearbyParksViewModel(repository: repository)
        model.locationDidUpdate(origin)
        await settle(model)
        XCTAssertEqual(model.state, .failed(APIError.network.userMessage))

        repository.error = nil
        model.retry()
        await settle(model)
        XCTAssertEqual(model.parks.count, 6)
    }

    func test_실패한_뒤에는_작은_이동에도_다시_조회한다() async {
        let repository = StubParkRepository()
        repository.error = .network
        let model = NearbyParksViewModel(repository: repository)
        model.locationDidUpdate(origin)
        await settle(model)
        repository.error = nil
        model.locationDidUpdate(moved(meters: 20))
        await settle(model)
        XCTAssertEqual(model.parks.count, 6)
    }

    func test_위치가_들어오기_전에는_재시도할_수_없다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository)
        model.retry()
        XCTAssertTrue(repository.centers.isEmpty)
    }

    func test_판정_반경_안의_공원만_체크인_후보다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository)
        // 보라매공원(반경 180m) 중심에서 100m 떨어진 곳
        model.locationDidUpdate(moved(meters: 100))
        await settle(model)
        XCTAssertEqual(model.parksInRange.map(\.name), ["보라매공원"])
    }

    func test_반경이_겹치면_여러_공원이_후보로_나온다() async {
        let repository = StubParkRepository()
        let near = Park(id: 1, name: "가", type: .small, coordinate: origin, radiusM: 100, status: .none, badgeCount: 0)
        let overlap = Park(id: 2, name: "나", type: .small, coordinate: moved(meters: 60), radiusM: 100, status: .none, badgeCount: 0)
        repository.parks = [near, overlap]
        let model = NearbyParksViewModel(repository: repository)
        model.locationDidUpdate(moved(meters: 30))
        await settle(model)
        XCTAssertEqual(model.parksInRange.count, 2)
    }

    func test_반경_밖이면_후보가_없다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository)
        model.locationDidUpdate(moved(meters: 5000))
        await settle(model)
        XCTAssertTrue(model.parksInRange.isEmpty)
    }

    func test_refreshAndWait는_조회가_끝난_뒤에_돌아온다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository)
        model.locationDidUpdate(origin)
        await settle(model)
        XCTAssertEqual(model.parks.count, 6)

        repository.parks = []
        await model.refreshAndWait()

        XCTAssertEqual(model.state, .empty)  // 기다리지 않고 바로 확인해도 새 결과가 반영돼 있다
    }

    func test_위치가_없으면_refreshAndWait는_아무것도_하지_않는다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository)
        await model.refreshAndWait()
        XCTAssertTrue(repository.centers.isEmpty)
    }


    func test_기본_반경은_1km이고_그_반경으로_조회한다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository, radiusSetting: SearchRadiusSetting(store: UserDefaultsSearchRadiusStore(defaults: UserDefaults(suiteName: "tests.nearby.radius.\(UUID().uuidString)")!)))
        model.locationDidUpdate(origin)
        await settle(model)
        XCTAssertEqual(repository.radii, [1000])
    }

    func test_반경을_바꾸면_새_반경으로_다시_조회한다() async {
        let repository = StubParkRepository()
        let setting = SearchRadiusSetting(store: UserDefaultsSearchRadiusStore(defaults: UserDefaults(suiteName: "tests.nearby.radius.\(UUID().uuidString)")!))
        let model = NearbyParksViewModel(repository: repository, radiusSetting: setting)
        model.locationDidUpdate(origin)
        await settle(model)

        setting.select(.km2)
        model.radiusDidChange()
        for _ in 0..<200 where repository.radii.count < 2 { try? await Task.sleep(for: .milliseconds(5)) }

        XCTAssertEqual(repository.radii, [1000, 2000])
        XCTAssertEqual(model.radiusM, 2000)
    }

    func test_위치가_없으면_반경을_바꿔도_조회하지_않는다() async {
        let repository = StubParkRepository()
        let model = NearbyParksViewModel(repository: repository)
        model.radiusDidChange()
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(repository.radii.isEmpty)
    }

}

final class ParkTests: XCTestCase {
    private let center = Coordinate(latitude: 37.4934, longitude: 126.9209)
    private func park(radius: Double) -> Park {
        Park(id: 1, name: "a", type: .small, coordinate: center, radiusM: radius, status: .none, badgeCount: 0)
    }

    func test_반경_안에서는_경계까지_거리가_0이다() {
        XCTAssertEqual(park(radius: 180).distanceToBoundary(from: center), 0)
        XCTAssertTrue(park(radius: 180).contains(center))
    }

    func test_반경_밖에서는_경계까지의_거리를_알려준다() {
        let far = Coordinate(latitude: center.latitude + 260.0 / 111_195, longitude: center.longitude)
        XCTAssertEqual(park(radius: 180).distanceToBoundary(from: far), 80, accuracy: 2)
        XCTAssertFalse(park(radius: 180).contains(far))
    }
}

final class RemoteParkRepositoryTests: XCTestCase {
    private func make(handler: @escaping StubTransport.Handler) -> (RemoteParkRepository, StubTransport) {
        let transport = StubTransport(handler)
        let client = APIClient(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")), transport: transport)
        return (RemoteParkRepository(client: client), transport)
    }

    func test_주변_공원을_조회한다() async throws {
        let json = """
            {"parks":[{"id":1024,"name":"보라매공원","parkType":"NEIGHBORHOOD","latitude":37.4934,"longitude":126.9209,"radiusM":180,"distanceM":320,"myStatus":"EARNED_TODAY","myBadgeCount":3}]}
            """
        let (repository, transport) = make { _ in (200, json) }
        let parks = try await repository.nearby(center: Coordinate(latitude: 37.49, longitude: 126.92), radiusM: 1000)

        XCTAssertEqual(parks.count, 1)
        XCTAssertEqual(parks[0].status, .earnedToday)
        XCTAssertEqual(parks[0].badgeCount, 3)
        XCTAssertEqual(parks[0].type, .neighborhood)
        let url = try XCTUnwrap(transport.requests.first?.url)
        XCTAssertEqual(url.path, "/api/parks/nearby")
        let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value) })
        XCTAssertEqual(query["radius"], "1000")
        XCTAssertEqual(query["lat"], "37.49")
    }

    func test_알_수_없는_상태_값은_미획득으로_본다() async throws {
        let json = """
            {"parks":[{"id":1,"name":"a","parkType":"SMALL","latitude":37.0,"longitude":127.0,"radiusM":50,"distanceM":1,"myStatus":"SOMETHING_NEW","myBadgeCount":0}]}
            """
        let (repository, _) = make { _ in (200, json) }
        let parks = try await repository.nearby(center: Coordinate(latitude: 37, longitude: 127), radiusM: 1000)
        XCTAssertEqual(parks[0].status, .none)
    }

    func test_공원_상세를_조회한다() async throws {
        let json = """
            {"id":1024,"name":"보라매공원","parkType":"NEIGHBORHOOD","address":"동작구 여의대방로20길 33","latitude":37.4934,"longitude":126.9209,"radiusM":180,"averageRating":4.6,"reviewCount":128,"myStatus":"EARNED","myBadgeCount":3}
            """
        let (repository, transport) = make { _ in (200, json) }
        let detail = try await repository.detail(parkID: 1024)
        XCTAssertEqual(detail.address, "동작구 여의대방로20길 33")
        XCTAssertEqual(detail.averageRating, 4.6)
        XCTAssertEqual(detail.reviewCount, 128)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/parks/1024")
    }

    func test_리뷰가_없으면_평균_별점이_nil이다() async throws {
        let json = """
            {"id":1,"name":"a","parkType":"SMALL","address":"x","latitude":37.0,"longitude":127.0,"radiusM":50,"averageRating":null,"reviewCount":0,"myStatus":"NONE","myBadgeCount":0}
            """
        let (repository, _) = make { _ in (200, json) }
        let detail = try await repository.detail(parkID: 1)
        XCTAssertNil(detail.averageRating)
    }
}
