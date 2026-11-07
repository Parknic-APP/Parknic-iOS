import XCTest
@testable import Parknic

final class AppConfigTests: XCTestCase {
    func test_서버_주소가_빌드_설정에서_주입된다() {
        // 설정이 없으면 호스트가 없는 주소("/")가 나온다. 주입됐다면 호스트가 있다.
        XCTAssertNotNil(AppConfig.apiBaseURL.host)
    }
}
