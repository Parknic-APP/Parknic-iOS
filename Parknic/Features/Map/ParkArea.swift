import Foundation

/// 지도에 그리는 공원 면. 실제 공원 경계 데이터가 없어서, 체크인 판정 반경을 둘레로 삼아
/// 시안(12a)의 손그림 공원처럼 살짝 일렁이는 모양으로 그린다. 같은 공원은 언제나 같은 모양이다.
enum ParkArea {
    static let outlinePointCount = 28
    /// 반경 대비 일렁임 폭의 최대치(±15%)
    static let maxWobble = 0.15

    static func outline(for park: Park) -> [Coordinate] {
        let phase = Double(park.id % 11) * 0.7
        return (0..<outlinePointCount).map { index in
            let angle = Double(index) / Double(outlinePointCount) * 2 * .pi
            let scale = 1 + 0.10 * sin(3 * angle + phase) + 0.05 * sin(5 * angle + 2 * phase)
            return offset(from: park.coordinate, meters: Double(park.radiusM) * scale, angle: angle)
        }
    }

    private static func offset(from center: Coordinate, meters: Double, angle: Double) -> Coordinate {
        let metersPerDegreeLatitude = 111_320.0
        let latitude = center.latitude + meters * cos(angle) / metersPerDegreeLatitude
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(center.latitude * .pi / 180)
        let longitude = center.longitude + meters * sin(angle) / metersPerDegreeLongitude
        return Coordinate(latitude: latitude, longitude: longitude)
    }
}
