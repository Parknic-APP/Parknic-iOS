protocol ParkRepository: Sendable {
    /// 중심 좌표 주변 `radiusM`(m) 안의 공원과 내 상태
    func nearby(center: Coordinate, radiusM: Int) async throws -> [Park]
    func detail(parkID: Int) async throws -> ParkDetail
    /// 중심 좌표 주변 `radiusM`(m) 안에서 리뷰가 좋은 공원(별점 높은 순)
    func topRated(center: Coordinate, radiusM: Int) async throws -> [TopRatedPark]
}
