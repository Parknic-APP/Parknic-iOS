import XCTest
@testable import Parknic

final class RemoteAuthRepositoryTests: XCTestCase {
    private func makeRepository(
        store: TokenStore, handler: @escaping StubTransport.Handler
    ) -> (RemoteAuthRepository, StubTransport) {
        let transport = StubTransport(handler)
        let client = APIClient(baseURL: URL(string: "https://example.test")!, tokenStore: store, transport: transport)
        return (RemoteAuthRepository(client: client, tokenStore: store), transport)
    }

    func test_로그인하면_토큰을_저장하고_신규_여부를_돌려준다() async throws {
        let store = MemoryTokenStore(nil)
        let (repository, transport) = makeRepository(store: store) { _ in
            (200, #"{"accessToken":"a","refreshToken":"r","isNewUser":true}"#)
        }

        let result = try await repository.login(provider: .apple, socialToken: "apple-token")

        XCTAssertEqual(result, LoginResult(isNewUser: true))
        XCTAssertEqual(store.load(), AuthTokens(accessToken: "a", refreshToken: "r"))
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/api/auth/login/apple")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), #"{"token":"apple-token"}"#)
    }

    func test_실패하면_토큰을_저장하지_않는다() async {
        let store = MemoryTokenStore(nil)
        let (repository, _) = makeRepository(store: store) { _ in (401, "{}") }

        do {
            _ = try await repository.login(provider: .kakao, socialToken: "t")
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .server(status: 401, code: nil))
        }
        XCTAssertNil(store.load())
    }
}
