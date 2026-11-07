import Foundation

/// 서버 에러 응답의 `code`. 목록은 docs/api-spec.md 1장과 맞춘다.
enum APIErrorCode: String, CaseIterable, Sendable {
    case checkInOutOfRange = "CHECKIN_OUT_OF_RANGE"
    case checkInAlreadyInProgress = "CHECKIN_ALREADY_IN_PROGRESS"
    case badgeAlreadyEarnedToday = "BADGE_ALREADY_EARNED_TODAY"
    case checkInTooEarly = "CHECKIN_TOO_EARLY"
    case checkInExpiredMidnight = "CHECKIN_EXPIRED_MIDNIGHT"
    case reviewBadgeRequired = "REVIEW_BADGE_REQUIRED"
    case reviewAlreadyExists = "REVIEW_ALREADY_EXISTS"
    case nicknameDuplicated = "NICKNAME_DUPLICATED"
    case nicknameInappropriate = "NICKNAME_INAPPROPRIATE"
    case tokenExpired = "TOKEN_EXPIRED"

    /// `code → 한글 메시지` 매핑은 여기 한 곳에서만 관리한다.
    var message: String {
        switch self {
        case .checkInOutOfRange: String(localized: "공원 안에서 체크인할 수 있어요")
        case .checkInAlreadyInProgress: String(localized: "이미 진행 중인 체크인이 있어요")
        case .badgeAlreadyEarnedToday: String(localized: "오늘 이 공원의 배지는 이미 받았어요")
        case .checkInTooEarly: String(localized: "아직 20분이 지나지 않았어요")
        case .checkInExpiredMidnight: String(localized: "날짜가 바뀌어 체크인이 끝났어요")
        case .reviewBadgeRequired: String(localized: "배지를 받은 공원에만 리뷰를 쓸 수 있어요")
        case .reviewAlreadyExists: String(localized: "이미 이 공원에 리뷰를 썼어요")
        case .nicknameDuplicated: String(localized: "이미 사용 중인 닉네임이에요")
        case .nicknameInappropriate: String(localized: "사용할 수 없는 닉네임이에요. 다른 이름을 써 주세요")
        case .tokenExpired: String(localized: "로그인이 만료됐어요. 다시 로그인해주세요")
        }
    }
}

/// 네트워크 계층이 던지는 에러.
enum APIError: Error, Equatable, Sendable {
    /// 서버가 에러 응답을 줬다. `code`는 응답 본문의 값(없거나 모르는 값이면 nil 또는 원문).
    case server(status: Int, code: String?)
    /// 연결 실패·타임아웃 등
    case network
    /// 응답을 해석하지 못했다
    case decoding
    /// 재발급까지 실패해 다시 로그인해야 한다
    case sessionExpired
    case invalidRequest

    /// 서버 에러 코드. 모르는 코드면 nil.
    var serverCode: APIErrorCode? {
        guard case .server(_, let code?) = self else { return nil }
        return APIErrorCode(rawValue: code)
    }

    /// 사용자에게 보여줄 한국어 문구
    var userMessage: String {
        switch self {
        case .server:
            serverCode?.message ?? String(localized: "문제가 생겼어요. 잠시 후 다시 시도해주세요")
        case .network:
            String(localized: "인터넷 연결이 불안정해요. 연결 상태를 확인하고 다시 시도해주세요")
        case .sessionExpired:
            APIErrorCode.tokenExpired.message
        case .decoding, .invalidRequest:
            String(localized: "문제가 생겼어요. 잠시 후 다시 시도해주세요")
        }
    }
}
