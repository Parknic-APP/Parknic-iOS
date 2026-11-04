import Foundation

/// 서버 없이 체크인 흐름을 확인하기 위한 가짜 구현체. 시작하면 항상 `radiusM` 반경의 같은 공원 세션이 만들어진다.
final class MockCheckInRepository: CheckInRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _session: CheckInSession?
    private let clock: AppClock
    var center = Coordinate(latitude: 37.4934, longitude: 126.9209)
    var radiusM = 180.0

    init(clock: AppClock = SystemClock()) {
        self.clock = clock
    }

    func start(parkID: Int, at coordinate: Coordinate) async throws -> CheckInSession {
        let session = CheckInSession(
            id: 1, parkID: parkID, parkName: "보라매공원", center: center, radiusM: radiusM, startedAt: clock.now)
        lock.withLock { _session = session }
        return session
    }

    func current() async throws -> CheckInSession? {
        lock.withLock { _session }
    }

    func complete(sessionID: Int, at coordinate: Coordinate?, pausedSeconds: Int) async throws -> CheckInResult {
        let session = lock.withLock { () -> CheckInSession? in
            defer { _session = nil }
            return _session
        }
        return CheckInResult(
            badge: EarnedBadge(
                parkID: session?.parkID ?? 0, parkName: session?.parkName ?? "", parkType: .neighborhood,
                earnedAt: clock.now),
            newAchievements: [],
            monthlyRanking: MonthlyRankingSummary(rank: 5, badgeCount: 4, rankChange: 1, badgesToPodium: 3),
            canWriteReview: true)
    }

    func fail(sessionID: Int, reason: CheckInFailureReason) async throws {
        lock.withLock { _session = nil }
    }

    func cancel(sessionID: Int) async throws {
        lock.withLock { _session = nil }
    }
}
