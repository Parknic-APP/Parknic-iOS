import UIKit
import XCTest
@testable import Parknic

final class FontTests: XCTestCase {
    func test_디자인_시스템_폰트가_모두_등록되어_있다() {
        let names = [
            PKFontName.pretendardRegular, PKFontName.pretendardSemiBold,
            PKFontName.pretendardBold, PKFontName.pretendardExtraBold, PKFontName.jua,
        ]
        for name in names {
            XCTAssertNotNil(UIFont(name: name, size: 15), "\(name) 폰트를 찾을 수 없다")
        }
    }
}
