import XCTest
@testable import Parknic

final class DurationFormatterTests: XCTestCase {
    func test_남은_시간은_분과_초로_표기한다() {
        XCTAssertEqual(DurationFormatter.clock(754), "12:34")
        XCTAssertEqual(DurationFormatter.clock(1200), "20:00")
        XCTAssertEqual(DurationFormatter.clock(42), "0:42")
        XCTAssertEqual(DurationFormatter.clock(5), "0:05")
    }

    func test_1초라도_남았으면_0시00분으로_보이지_않는다() {
        XCTAssertEqual(DurationFormatter.clock(0.2), "0:01")
        XCTAssertEqual(DurationFormatter.clock(0), "0:00")
    }

    func test_음수는_0으로_본다() {
        XCTAssertEqual(DurationFormatter.clock(-3), "0:00")
        XCTAssertEqual(DurationFormatter.wholeMinutes(-30), 0)
    }

    func test_머문_분은_내림한다() {
        XCTAssertEqual(DurationFormatter.wholeMinutes(446), 7)
        XCTAssertEqual(DurationFormatter.wholeMinutes(59.9), 0)
        XCTAssertEqual(DurationFormatter.wholeMinutes(1200), 20)
    }

    func test_머문_시간을_한국어로_표기한다() {
        XCTAssertEqual(DurationFormatter.minutesAndSeconds(446), "7분 26초")
        XCTAssertEqual(DurationFormatter.minutesAndSeconds(42), "42초")
        XCTAssertEqual(DurationFormatter.minutesAndSeconds(600), "10분 0초")
    }
}
