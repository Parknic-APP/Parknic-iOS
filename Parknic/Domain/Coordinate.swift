import Foundation

/// 위경도 좌표. 이동 경로로 저장하거나 로그로 남기지 않는다.
struct Coordinate: Equatable, Codable, Sendable {
    var latitude: Double
    var longitude: Double

    /// 두 좌표 사이의 거리(m). 하버사인 공식.
    func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
