import XCTest
@testable import Parknic

final class APIErrorTests: XCTestCase {
    func test_모든_서버_코드가_한글_메시지를_가진다() {
        for code in APIErrorCode.allCases {
            XCTAssertFalse(code.message.isEmpty, "\(code.rawValue) 메시지 없음")
        }
    }

    func test_서버_코드_원문으로_매핑된다() {
        let cases: [(String, APIErrorCode)] = [
            ("CHECKIN_OUT_OF_RANGE", .checkInOutOfRange),
            ("CHECKIN_ALREADY_IN_PROGRESS", .checkInAlreadyInProgress),
            ("BADGE_ALREADY_EARNED_TODAY", .badgeAlreadyEarnedToday),
            ("CHECKIN_TOO_EARLY", .checkInTooEarly),
            ("CHECKIN_EXPIRED_MIDNIGHT", .checkInExpiredMidnight),
            ("REVIEW_BADGE_REQUIRED", .reviewBadgeRequired),
            ("REVIEW_ALREADY_EXISTS", .reviewAlreadyExists),
            ("NICKNAME_DUPLICATED", .nicknameDuplicated),
            ("TOKEN_EXPIRED", .tokenExpired),
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(APIError.server(status: 400, code: raw).serverCode, expected)
        }
    }

    func test_알_수_없는_코드는_일반_문구로_대체된다() {
        let error = APIError.server(status: 500, code: "SOMETHING_NEW")
        XCTAssertNil(error.serverCode)
        XCTAssertEqual(error.userMessage, "문제가 생겼어요. 잠시 후 다시 시도해주세요")
    }

    func test_코드가_없는_응답도_일반_문구를_쓴다() {
        XCTAssertEqual(
            APIError.server(status: 502, code: nil).userMessage, "문제가 생겼어요. 잠시 후 다시 시도해주세요")
    }

    func test_닉네임_중복_메시지() {
        XCTAssertEqual(
            APIError.server(status: 409, code: "NICKNAME_DUPLICATED").userMessage, "이미 사용 중인 닉네임이에요")
    }

    func test_네트워크_오류와_세션_만료_문구() {
        XCTAssertEqual(
            APIError.network.userMessage, "인터넷 연결이 불안정해요. 연결 상태를 확인하고 다시 시도해주세요")
        XCTAssertEqual(APIError.sessionExpired.userMessage, "로그인이 만료됐어요. 다시 로그인해주세요")
    }
}
