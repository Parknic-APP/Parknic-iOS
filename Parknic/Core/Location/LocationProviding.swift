import CoreLocation

enum LocationAuthorization: Equatable, Sendable {
    case notDetermined
    /// 거부됐거나 제한됨(설정 앱에서만 바꿀 수 있다)
    case denied
    case authorized
}

enum LocationEvent: Equatable, Sendable {
    case authorization(LocationAuthorization)
    case location(Coordinate)
}

/// 지도 화면용 위치 수신(앱을 보고 있을 때만). 체크인 중 측정은 `LocationSampleSource`가 따로 맡는다.
@MainActor
protocol LocationProviding {
    func events() -> AsyncStream<LocationEvent>
    /// 아직 권한을 묻지 않았다면 "앱을 사용하는 동안" 권한을 요청한다.
    func requestPermissionIfNeeded()
}

@MainActor
final class CoreLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<LocationEvent>.Continuation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    func events() -> AsyncStream<LocationEvent> {
        continuation?.finish()
        let stream = AsyncStream<LocationEvent> { continuation in self.continuation = continuation }
        let authorization = Self.map(manager.authorizationStatus)
        continuation?.yield(.authorization(authorization))
        if authorization == .authorized { manager.startUpdatingLocation() }
        return stream
    }

    func requestPermissionIfNeeded() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    private static func map(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted, .denied: .denied
        case .authorizedWhenInUse, .authorizedAlways: .authorized
        @unknown default: .denied
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            let authorization = Self.map(status)
            continuation?.yield(.authorization(authorization))
            if authorization == .authorized { self.manager.startUpdatingLocation() } else { self.manager.stopUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 정확도가 100m보다 나쁜 위치는 무시한다.
        guard let last = locations.last(where: { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 100 }) else { return }
        let coordinate = Coordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        Task { @MainActor in continuation?.yield(.location(coordinate)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
