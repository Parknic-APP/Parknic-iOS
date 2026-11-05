import Foundation

/// 서버 없이 화면을 완성하기 위한 가짜 구현체(디자인 12i·09b와 같은 데이터)
struct MockMyPageRepository: MyPageRepository {
    var delay: Duration = .milliseconds(300)
    /// true면 막 가입해 기록이 하나도 없는 회원
    var isNewcomer = false
    var failure: APIError?
    var clock: AppClock = SystemClock()

    func profile() async throws -> UserProfile {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        return UserProfile(
            nickname: "나뭇잎", characterID: 1, characterName: "치즈냥",
            joinedAt: Calendar.kst.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12)) ?? clock.now)
    }

    func stats() async throws -> UserStats {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        if isNewcomer { return UserStats(totalBadges: 0, visitedParks: 0, currentStreak: 0, bestStreak: 0, podiumParks: 0) }
        return UserStats(totalBadges: 23, visitedParks: 11, currentStreak: 5, bestStreak: 9, podiumParks: 2)
    }

    func reviews(cursor: String?) async throws -> MyReviewPage {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        if isNewcomer { return MyReviewPage(reviews: [], totalCount: 0, nextCursor: nil) }
        let now = clock.now
        func ago(_ days: Int) -> Date { now.addingTimeInterval(-Double(days) * 86_400) }
        let all = [
            MyReview(id: 1, parkID: 1024, parkName: "보라매공원", rating: 5, content: "그늘이 많아서 한낮에도 산책하기 괜찮아요.", createdAt: ago(7)),
            MyReview(id: 2, parkID: 1027, parkName: "도림천수변공원", rating: 4, content: "물소리 들으면서 걷기 좋아요. 자전거가 많으니 조심!", createdAt: ago(14)),
            MyReview(id: 3, parkID: 1029, parkName: "상도체육공원", rating: 4, content: "운동기구가 많고 트랙이 잘 돼 있어요.", createdAt: ago(21)),
        ]
        return MyReviewPage(reviews: all, totalCount: all.count, nextCursor: nil)
    }
}
