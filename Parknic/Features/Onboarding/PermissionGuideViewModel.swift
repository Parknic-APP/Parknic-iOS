import Observation

/// 권한 안내 단계(07e). 안내를 보여준 뒤 위치 → 알림 순서로 시스템 권한을 요청한다.
/// 사용자가 거부해도 온보딩은 끝낸다(거부 안내는 지도 화면의 10c에서 한다).
@MainActor @Observable
final class PermissionGuideViewModel {
    private(set) var isRequesting = false

    private let location: LocationPermissionRequesting
    private let notification: NotificationPermissionRequesting
    private let onFinished: () -> Void

    init(
        location: LocationPermissionRequesting, notification: NotificationPermissionRequesting,
        onFinished: @escaping () -> Void
    ) {
        self.location = location
        self.notification = notification
        self.onFinished = onFinished
    }

    /// 「확인했어요」
    func confirm() async {
        guard !isRequesting else { return }
        isRequesting = true
        await location.requestWhenInUse()
        await notification.requestAuthorization()
        isRequesting = false
        onFinished()
    }

    /// 「나중에 설정할게요」 — 시스템 권한 창을 띄우지 않는다.
    func skip() {
        guard !isRequesting else { return }
        onFinished()
    }
}
