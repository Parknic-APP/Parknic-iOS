import XCTest
@testable import Parknic

final class ParkTypeTests: XCTestCase {
    func test_서버_값으로_디코딩된다() throws {
        let data = Data(#""NEIGHBORHOOD""#.utf8)
        let type = try JSONDecoder().decode(ParkType.self, from: data)
        XCTAssertEqual(type, .neighborhood)
    }

    func test_모든_유형에_표시_이름이_있다() {
        for type in ParkType.allCases {
            XCTAssertFalse(type.displayName.isEmpty)
        }
    }
}
