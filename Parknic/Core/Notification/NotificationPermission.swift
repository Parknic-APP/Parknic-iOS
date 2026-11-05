import UserNotifications

/// 알림 권한 요청. 1차는 로컬 알림만 쓴다.
protocol NotificationPermissionRequesting: Sendable {
    func requestAuthorization() async
}

struct UserNotificationPermissionRequester: NotificationPermissionRequesting {
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}

/// 마이페이지 "알림 켜짐/꺼짐" 표시용. 권한이 허용돼 있으면 true.
protocol NotificationStatusReading: Sendable {
    func isEnabled() async -> Bool
}

struct UserNotificationStatusReader: NotificationStatusReading {
    func isEnabled() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }
}
