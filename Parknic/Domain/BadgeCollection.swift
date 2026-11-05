import Foundation

/// 업적 하나. `achievedAt`이 있으면 달성, 없으면 `progress/target`으로 진행도를 보여준다.
struct AchievementProgress: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    /// 업적 배지 안에 들어가는 짧은 글자(예: "첫", "10", "7일")
    let label: String
    let achievedAt: Date?
    let progress: Int
    let target: Int

    var isAchieved: Bool { achievedAt != nil }

    /// 0~1. 목표가 0이면 달성 여부로만 판단한다.
    var fraction: Double {
        if isAchieved { return 1 }
        guard target > 0 else { return 0 }
        return min(max(Double(progress) / Double(target), 0), 1)
    }
}

/// 배지 도감(12h·09a): 지금까지 모은 배지 수, 유형별 개수, 업적.
struct BadgeCollection: Equatable, Sendable {
    let totalBadges: Int
    let visitedParks: Int
    /// 서버가 일부 유형을 빼고 줘도 모든 유형을 순서대로 보여주기 위해 `ParkType.allCases` 기준으로 읽는다.
    let typeCounts: [ParkType: Int]
    let achievements: [AchievementProgress]

    func count(of type: ParkType) -> Int { typeCounts[type] ?? 0 }

    var collectedTypeCount: Int { ParkType.allCases.filter { count(of: $0) > 0 }.count }
    var achievedCount: Int { achievements.filter(\.isAchieved).count }
    var isEmpty: Bool { totalBadges == 0 }
}
