import XCTest
@testable import Parknic

private final class StubTopRatedRepository: ParkRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [(Coordinate, Int)] = []
    var result: Result<[TopRatedPark], APIError> = .success([])
    var requests: [(Coordinate, Int)] { lock.withLock { _requests } }

    func nearby(center: Coordinate, radiusM: Int) async throws -> [Park] { [] }
    func detail(parkID: Int) async throws -> ParkDetail { throw APIError.network }
    func topRated(center: Coordinate, radiusM: Int) async throws -> [TopRatedPark] {
        lock.withLock { _requests.append((center, radiusM)) }
        return try result.get()
    }
}

@MainActor
final class TopRatedParksViewModelTests: XCTestCase {
    private let center = Coordinate(latitude: 37.4934, longitude: 126.9209)
    private func item(_ id: Int, rating: Double = 4.8, reviews: Int = 12) -> TopRatedPark {
        TopRatedPark(park: MockParkRepository.sample[id % 6], distanceM: 320, averageRating: rating, reviewCount: reviews)
    }

    func test_반경_5km로_조회하고_결과를_보여준다() async {
        let repository = StubTopRatedRepository()
        repository.result = .success([item(0), item(1)])
        let model = TopRatedParksViewModel(repository: repository, center: center)
        await model.load()
        XCTAssertEqual(model.state, .loaded([item(0), item(1)]))
        XCTAssertEqual(repository.requests.first?.1, 5000)
        XCTAssertEqual(repository.requests.first?.0, center)
    }

    func test_결과가_없으면_빈_상태다() async {
        let model = TopRatedParksViewModel(repository: StubTopRatedRepository(), center: center)
        await model.load()
        XCTAssertEqual(model.state, .empty)
    }

    func test_실패하면_에러_문구를_보여주고_재시도로_복구된다() async {
        let repository = StubTopRatedRepository()
        repository.result = .failure(.network)
        let model = TopRatedParksViewModel(repository: repository, center: center)
        await model.load()
        XCTAssertEqual(model.state, .failed(APIError.network.userMessage))
        repository.result = .success([item(0)])
        await model.load()
        XCTAssertEqual(model.state, .loaded([item(0)]))
    }

    func test_별점_문구() {
        XCTAssertEqual(TopRatedParksViewModel.ratingText(4.75), "4.8")
        XCTAssertEqual(TopRatedParksViewModel.ratingText(5), "5.0")
    }

    func test_기준은_리뷰_10개_이상_별점_4_5_이상이다() {
        XCTAssertEqual(TopRatedPark.minReviewCount, 10)
        XCTAssertEqual(TopRatedPark.minRating, 4.5)
        XCTAssertEqual(TopRatedPark.searchRadiusM, 5000)
    }
}

final class RemoteTopRatedParksTests: XCTestCase {
    private func make(handler: @escaping StubTransport.Handler) -> (RemoteParkRepository, StubTransport) {
        let transport = StubTransport(handler)
        let client = APIClient(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")), transport: transport)
        return (RemoteParkRepository(client: client), transport)
    }

    func test_응답을_해석하고_좌표와_반경을_쿼리로_보낸다() async throws {
        let body = """
            {"parks":[{"id":7,"name":"좋은 공원","parkType":"NEIGHBORHOOD","latitude":37.5,"longitude":126.9,"radiusM":150,
            "distanceM":1250,"averageRating":4.8,"reviewCount":31,"myStatus":"EARNED","myBadgeCount":2}]}
            """
        let (repository, transport) = make { _ in (200, body) }
        let result = try await repository.topRated(center: Coordinate(latitude: 37.4934, longitude: 126.9209), radiusM: 5000)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].park.name, "좋은 공원")
        XCTAssertEqual(result[0].park.status, .earned)
        XCTAssertEqual(result[0].park.badgeCount, 2)
        XCTAssertEqual(result[0].distanceM, 1250)
        XCTAssertEqual(result[0].averageRating, 4.8, accuracy: 0.001)
        XCTAssertEqual(result[0].reviewCount, 31)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/parks/top-rated")
        let query = transport.requests.first?.url?.query ?? ""
        XCTAssertTrue(query.contains("radius=5000"))
        XCTAssertTrue(query.contains("lat=37.4934"))
    }

    func test_빈_목록도_해석한다() async throws {
        let (repository, _) = make { _ in (200, #"{"parks":[]}"#) }
        let result = try await repository.topRated(center: Coordinate(latitude: 0, longitude: 0), radiusM: 5000)
        XCTAssertTrue(result.isEmpty)
    }
}

final class DistanceFormatterTests: XCTestCase {
    func test_1km_미만은_미터로_보여준다() {
        XCTAssertEqual(DistanceFormatter.text(meters: 320), "320m")
        XCTAssertEqual(DistanceFormatter.text(meters: 999), "999m")
    }

    func test_1km_이상은_km로_보여주고_쉼표를_붙이지_않는다() {
        XCTAssertEqual(DistanceFormatter.text(meters: 1000), "1.0km")
        XCTAssertEqual(DistanceFormatter.text(meters: 2961), "3.0km")
        XCTAssertEqual(DistanceFormatter.text(meters: 4870), "4.9km")
    }

    func test_아주_가까우면_50m_이내로_보여준다() {
        XCTAssertEqual(DistanceFormatter.text(meters: 0), "50m 이내")
        XCTAssertEqual(DistanceFormatter.text(meters: 49), "50m 이내")
        XCTAssertEqual(DistanceFormatter.text(meters: 50), "50m")
    }
}
