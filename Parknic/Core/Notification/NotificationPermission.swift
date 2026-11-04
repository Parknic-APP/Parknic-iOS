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
