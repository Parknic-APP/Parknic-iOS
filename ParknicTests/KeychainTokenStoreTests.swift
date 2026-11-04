import XCTest
@testable import Parknic

final class KeychainTokenStoreTests: XCTestCase {
    private let store = KeychainTokenStore(service: "com.seongmo.parknic.tests")

    override func setUp() { store.clear() }
    override func tearDown() { store.clear() }

    func test_저장한_토큰을_읽는다() throws {
        let tokens = AuthTokens(accessToken: "a", refreshToken: "r")
        try store.save(tokens)
        XCTAssertEqual(store.load(), tokens)
    }

    func test_다시_저장하면_교체된다() throws {
        try store.save(AuthTokens(accessToken: "a1", refreshToken: "r1"))
        try store.save(AuthTokens(accessToken: "a2", refreshToken: "r2"))
        XCTAssertEqual(store.load(), AuthTokens(accessToken: "a2", refreshToken: "r2"))
    }

    func test_삭제하면_비어_있다() throws {
        try store.save(AuthTokens(accessToken: "a", refreshToken: "r"))
        store.clear()
        XCTAssertNil(store.load())
    }
}
