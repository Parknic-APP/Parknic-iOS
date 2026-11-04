import XCTest
@testable import Parknic

final class KoreanParticleTests: XCTestCase {
    func test_받침이_있으면_이랑() {
        XCTAssertEqual(KoreanParticle.withIRang("치즈냥"), "치즈냥이랑")
        XCTAssertEqual(KoreanParticle.withIRang("비글"), "비글이랑")
        XCTAssertEqual(KoreanParticle.withIRang("턱시도냥"), "턱시도냥이랑")
    }

    func test_받침이_없으면_랑() {
        XCTAssertEqual(KoreanParticle.withIRang("시바"), "시바랑")
        XCTAssertEqual(KoreanParticle.withIRang("코기"), "코기랑")
        XCTAssertEqual(KoreanParticle.withIRang("말티"), "말티랑")
    }

    func test_한글이_아니면_괄호_표기를_쓴다() {
        XCTAssertEqual(KoreanParticle.withIRang("Mimi"), "Mimi(이)랑")
        XCTAssertEqual(KoreanParticle.withIRang(""), "(이)랑")
    }
}
