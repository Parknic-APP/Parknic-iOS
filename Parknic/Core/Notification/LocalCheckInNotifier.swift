import UserNotifications

/// 로컬 알림 전송을 추상화해 테스트에서 가짜로 바꿀 수 있게 한다.
protocol NotificationScheduling: Sendable {
    func add(identifier: String, title: String, body: String) async
    func remove(identifiers: [String]) async
}

struct SystemNotificationScheduler: NotificationScheduling {
    func add(identifier: String, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // 트리거가 없으면 즉시 전달된다.
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func remove(identifiers: [String]) async {
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// 체크인 중 보내는 로컬 알림(1차는 서버 푸시 없음).
struct LocalCheckInNotifier: CheckInNotifying {
    static let outOfRangeIdentifier = "checkin.out-of-range"
    static let earnedIdentifier = "checkin.earned"

    private let scheduler: NotificationScheduling

    init(scheduler: NotificationScheduling = SystemNotificationScheduler()) {
        self.scheduler = scheduler
    }

    func warnOutOfRange() async {
        await scheduler.add(
            identifier: Self.outOfRangeIdentifier,
            title: String(localized: "공원을 벗어났어요"),
            body: String(localized: "1분 안에 공원으로 돌아오세요"))
    }

    func clearOutOfRangeWarning() async {
        await scheduler.remove(identifiers: [Self.outOfRangeIdentifier])
    }

    func notifyEarned(parkName: String) async {
        await scheduler.add(
            identifier: Self.earnedIdentifier,
            title: String(localized: "배지를 받았어요"),
            body: String(localized: "\(parkName)에서 20분을 채웠어요"))
    }
}

/// 앱이 열려 있을 때도 알림을 배너로 보여준다(기본값은 앱이 켜져 있으면 숨긴다).
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
