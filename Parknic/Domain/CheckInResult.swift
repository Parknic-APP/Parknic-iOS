import Foundation

/// 체크인 완료로 받은 배지
struct EarnedBadge: Equatable, Sendable {
    let parkID: Int
    let parkName: String
    let parkType: ParkType
    let earnedAt: Date
}

struct Achievement: Equatable, Sendable {
    let code: String
    let name: String
}

/// 이번 주 이 공원 랭킹에서 내 위치(배지 획득 화면 06a에 쓴다)
struct WeeklyRankingSummary: Equatable, Sendable {
    let rank: Int
    let badgeCount: Int
    /// 지난 순위 대비 변동(올랐으면 양수)
    let rankChange: Int
    /// 시상대(3등)까지 남은 배지 수
    let badgesToPodium: Int
}

struct CheckInResult: Equatable, Sendable {
    let badge: EarnedBadge
    let newAchievements: [Achievement]
    let weeklyRanking: WeeklyRankingSummary
    let canWriteReview: Bool
}
