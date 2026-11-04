import CoreLocation

/// 위치 권한 요청. "앱을 사용하는 동안"만 요청하고 "항상 허용"은 요청하지 않는다.
@MainActor
protocol LocationPermissionRequesting {
    /// 아직 묻지 않았다면 시스템 권한 창을 띄우고, 사용자가 답할 때까지 기다린다.
    func requestWhenInUse() async
}

@MainActor
final class CoreLocationPermissionRequester: NSObject, LocationPermissionRequesting, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestWhenInUse() async {
        guard manager.authorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        Task { @MainActor in
            continuation?.resume()
            continuation = nil
        }
    }
}
