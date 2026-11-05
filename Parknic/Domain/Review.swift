import Foundation

struct Review: Equatable, Identifiable, Sendable {
    let id: Int
    let userID: Int
    let nickname: String
    let characterID: Int
    /// 작성자의 총 배지 수(\"배지 47\")
    let badgeCount: Int
    /// 별점 1~5
    let rating: Int
    let content: String
    let createdAt: Date
    /// 내가 쓴 리뷰인지
    let isMine: Bool

    var characterAssetName: String { "character-\(characterID)" }
}

struct ReviewPage: Equatable, Sendable {
    let reviews: [Review]
    /// nil이면 마지막 페이지
    let nextCursor: String?
}

/// 신고 사유. 값은 서버 `reason`과 같다(서버와 확정 필요).
enum ReportReason: String, CaseIterable, Sendable {
    case spam = "SPAM"
    case abuse = "ABUSE"
    case inappropriate = "INAPPROPRIATE"
    case other = "OTHER"

    var displayName: String {
        switch self {
        case .spam: String(localized: "스팸·광고")
        case .abuse: String(localized: "욕설·비방")
        case .inappropriate: String(localized: "부적절한 내용")
        case .other: String(localized: "기타")
        }
    }
}
