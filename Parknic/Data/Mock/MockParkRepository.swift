import Foundation

/// 서버 없이 화면을 완성하기 위한 가짜 구현체. 디자인(12a)의 신대방동 주변 공원 6곳을 돌려준다.
struct MockParkRepository: ParkRepository {
    var delay: Duration = .milliseconds(300)
    var parks: [Park] = MockParkRepository.sample

    static let sample: [Park] = [
        Park(id: 1024, name: "보라매공원", type: .neighborhood, coordinate: Coordinate(latitude: 37.4934, longitude: 126.9209), radiusM: 180, status: .earned, badgeCount: 3),
        Park(id: 1025, name: "사육신역사공원", type: .history, coordinate: Coordinate(latitude: 37.5128, longitude: 126.9439), radiusM: 90, status: .none, badgeCount: 0),
        Park(id: 1026, name: "신대방어린이공원", type: .children, coordinate: Coordinate(latitude: 37.4905, longitude: 126.9136), radiusM: 60, status: .none, badgeCount: 0),
        Park(id: 1027, name: "도림천수변공원", type: .waterfront, coordinate: Coordinate(latitude: 37.4889, longitude: 126.9262), radiusM: 120, status: .earnedToday, badgeCount: 2),
        Park(id: 1028, name: "대방소공원", type: .small, coordinate: Coordinate(latitude: 37.4872, longitude: 126.9201), radiusM: 50, status: .none, badgeCount: 0),
        Park(id: 1029, name: "상도체육공원", type: .sports, coordinate: Coordinate(latitude: 37.4981, longitude: 126.9330), radiusM: 110, status: .earned, badgeCount: 1),
    ]

    func nearby(center: Coordinate, radiusM: Int) async throws -> [Park] {
        try await Task.sleep(for: delay)
        return parks.filter { $0.coordinate.distance(to: center) <= Double(radiusM) }
    }

    func detail(parkID: Int) async throws -> ParkDetail {
        try await Task.sleep(for: delay)
        guard let park = parks.first(where: { $0.id == parkID }) else {
            throw APIError.server(status: 404, code: nil)
        }
        return ParkDetail(park: park, address: "동작구 여의대방로20길 33", averageRating: 4.6, reviewCount: 128)
    }

    /// 목 데이터: 앞의 세 곳에 리뷰가 많고 별점이 높다고 가정한다.
    func topRated(center: Coordinate, radiusM: Int) async throws -> [TopRatedPark] {
        try await Task.sleep(for: delay)
        let ratings: [(Double, Int)] = [(4.8, 128), (4.7, 64), (4.5, 21)]
        return zip(parks, ratings).compactMap { park, rating in
            let distance = park.coordinate.distance(to: center)
            guard distance <= Double(radiusM) else { return nil }
            return TopRatedPark(park: park, distanceM: Int(distance.rounded()), averageRating: rating.0, reviewCount: rating.1)
        }
        .sorted { $0.averageRating > $1.averageRating }
    }
}
