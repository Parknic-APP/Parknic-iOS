import Foundation

/// 서버가 기준인 내 프로필(`GET /api/users/me`)
struct UserProfile: Equatable, Sendable {
    let nickname: String
    let characterID: Int
    let characterName: String
    let joinedAt: Date
}

/// 마이페이지 통계 4칸(12i·09b)
struct UserStats: Equatable, Sendable {
    let totalBadges: Int
    let visitedParks: Int
    let currentStreak: Int
    let bestStreak: Int
    /// 시상대(1~3등)에 오른 공원 수
    let podiumParks: Int
}

/// 내가 쓴 리뷰 한 건
struct MyReview: Equatable, Identifiable, Sendable {
    let id: Int
    let parkID: Int
    let parkName: String
    /// 별점 1~5
    let rating: Int
    let content: String
    let createdAt: Date
}

struct MyReviewPage: Equatable, Sendable {
    let reviews: [MyReview]
    /// 내가 쓴 리뷰 전체 개수("내 리뷰 3")
    let totalCount: Int
    /// nil이면 마지막 페이지
    let nextCursor: String?
}

struct MyPageSummary: Equatable, Sendable {
    let profile: UserProfile
    let stats: UserStats
    let recentReviews: MyReviewPage
}

protocol MyPageRepository: Sendable {
    func profile() async throws -> UserProfile
    func stats() async throws -> UserStats
    /// 최신순. `cursor`가 nil이면 첫 페이지
    func reviews(cursor: String?) async throws -> MyReviewPage
}
