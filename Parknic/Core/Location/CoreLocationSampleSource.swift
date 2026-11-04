import CoreLocation

/// 실제 위치 수신. 체크인 중에만 켜고, 앱을 내리거나 화면을 꺼도 측정이 이어지게 설정한다.
/// 좌표는 전달만 하고 저장하거나 로그로 남기지 않는다.
@MainActor
final class CoreLocationSampleSource: NSObject, LocationSampleSource, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<LocationSample>.Continuation?
    /// 체크인 시작 시 만들고 종료 시 무효화한다(앱을 내려도 위치 수신이 유지된다).
    private var backgroundSession: CLBackgroundActivitySession?

    override init() {
        super.init()
        manager.delegate = self
    }

    func start() -> AsyncStream<LocationSample> {
        stop()

        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        backgroundSession = CLBackgroundActivitySession()

        let stream = AsyncStream<LocationSample> { continuation in
            self.continuation = continuation
        }
        // 권한이 없으면 위치가 오지 않는다. 권한 안내(10c)는 체크인 버튼을 누르기 전에 화면에서 처리한다.
        manager.startUpdatingLocation()
        return stream
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        backgroundSession?.invalidate()
        backgroundSession = nil
        continuation?.finish()
        continuation = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations.map {
            LocationSample(
                coordinate: Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude),
                horizontalAccuracy: $0.horizontalAccuracy)
        }
        Task { @MainActor in
            for sample in samples { continuation?.yield(sample) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 일시적인 위치 오류는 무시한다. 이탈·종료 판정은 시간(tick)이 한다.
    }
}
