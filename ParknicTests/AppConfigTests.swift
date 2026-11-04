import XCTest
@testable import Parknic

final class AppConfigTests: XCTestCase {
    func test_서버_주소가_빌드_설정에서_주입된다() {
        XCTAssertEqual(AppConfig.apiBaseURL?.host, "localhost")
    }
}
