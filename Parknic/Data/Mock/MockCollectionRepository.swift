import Foundation

/// 서버 없이 화면을 완성하기 위한 가짜 구현체(디자인 12h·09a와 같은 데이터)
struct MockCollectionRepository: CollectionRepository {
    var delay: Duration = .milliseconds(300)
    /// true면 아직 배지가 하나도 없는 신규 회원
    var isEmpty = false
    /// 값이 있으면 그 에러로 실패한다(에러 화면 확인용)
    var failure: APIError?

    func collection() async throws -> BadgeCollection {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        if isEmpty {
            return BadgeCollection(
                totalBadges: 0, visitedParks: 0, typeCounts: [:],
                achievements: Self.achievements(visited: 0, streak: 0, firstAt: nil, tenAt: nil))
        }
        return BadgeCollection(
            totalBadges: 23, visitedParks: 11,
            typeCounts: [
                .neighborhood: 9, .children: 2, .sports: 3, .waterfront: 6, .history: 3,
            ],
            achievements: Self.achievements(
                visited: 11, streak: 5, firstAt: Self.date(2026, 9, 2), tenAt: Self.date(2026, 10, 19)))
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.kst.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    private static func achievements(visited: Int, streak: Int, firstAt: Date?, tenAt: Date?) -> [AchievementProgress] {
        [
            AchievementProgress(id: "FIRST_BADGE", name: "첫 배지", label: "첫", achievedAt: firstAt, progress: firstAt == nil ? 0 : 1, target: 1),
            AchievementProgress(id: "PARKS_10", name: "서로 다른 공원 10곳", label: "10", achievedAt: tenAt, progress: min(visited, 10), target: 10),
            AchievementProgress(id: "PARKS_20", name: "서로 다른 공원 20곳", label: "20", achievedAt: nil, progress: visited, target: 20),
            AchievementProgress(id: "PARKS_50", name: "서로 다른 공원 50곳", label: "50", achievedAt: nil, progress: visited, target: 50),
            AchievementProgress(id: "PARKS_100", name: "서로 다른 공원 100곳", label: "100", achievedAt: nil, progress: visited, target: 100),
            AchievementProgress(id: "STREAK_7", name: "7일 연속 산책", label: "7일", achievedAt: nil, progress: streak, target: 7),
        ]
    }
}
