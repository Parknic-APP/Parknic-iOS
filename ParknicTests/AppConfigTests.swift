import XCTest
@testable import Parknic

final class AppConfigTests: XCTestCase {
    func test_서버_주소가_빌드_설정에서_주입된다() {
        // 설정이 없으면 호스트가 없는 주소("/")가 나온다. 주입됐다면 호스트가 있다.
        XCTAssertNotNil(AppConfig.apiBaseURL.host)
    }

    func test_양수_숫자만_초로_읽는다() {
        XCTAssertEqual(AppConfig.positiveSeconds(from: "65"), 65)
        XCTAssertEqual(AppConfig.positiveSeconds(from: " 90 "), 90)
        XCTAssertNil(AppConfig.positiveSeconds(from: nil))
        XCTAssertNil(AppConfig.positiveSeconds(from: ""))
        XCTAssertNil(AppConfig.positiveSeconds(from: "abc"))
        XCTAssertNil(AppConfig.positiveSeconds(from: "0"))
        XCTAssertNil(AppConfig.positiveSeconds(from: "-5"))
    }

    func test_평소_빌드는_체크인_시간을_바꾸지_않는다() {
        // 시험용 값(CHECKIN_REQUIRED_SECONDS_OVERRIDE)은 fastlane quick_checkin:true일 때만 채워진다.
        XCTAssertNil(AppConfig.checkInRequiredSecondsOverride)
    }
}
