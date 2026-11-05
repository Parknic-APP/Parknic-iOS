import CoreLocation

/// 좌표의 동네 이름("신대방동"). 지도 위 "신대방동 주변 1km" 표시에 쓴다. 이름을 못 구하면 nil.
/// 좌표는 이름을 조회하는 데만 쓰고 저장하지 않는다.
protocol NeighborhoodNaming: Sendable {
    func name(at coordinate: Coordinate) async -> String?
}

/// 이름을 쓰지 않는 기본 구현(테스트·미리보기에서 실제 조회가 나가지 않게 한다)
struct NoNeighborhoodNamer: NeighborhoodNaming {
    func name(at coordinate: Coordinate) async -> String? { nil }
}

struct GeocoderNeighborhoodNamer: NeighborhoodNaming {
    func name(at coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(
            location, preferredLocale: Locale(identifier: "ko_KR"))
        guard let placemark = placemarks?.first else { return nil }
        // 동 단위가 없으면 시·구 이름을 쓴다.
        return placemark.subLocality ?? placemark.locality
    }
}
