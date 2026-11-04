import Foundation

/// 진행 중인 체크인 세션을 기기에 저장해 재실행 시 복구한다. 좌표 이동 경로는 저장하지 않는다(세션 정보만).
protocol CheckInStore: Sendable {
    func load() -> CheckInSession?
    func save(_ session: CheckInSession)
    func clear()
}

struct UserDefaultsCheckInStore: CheckInStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "checkin.currentSession"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> CheckInSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CheckInSession.self, from: data)
    }

    func save(_ session: CheckInSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
