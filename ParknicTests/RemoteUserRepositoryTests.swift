import XCTest
@testable import Parknic

final class RemoteUserRepositoryTests: XCTestCase {
    private func makeRepository(handler: @escaping StubTransport.Handler) -> (RemoteUserRepository, StubTransport) {
        let transport = StubTransport(handler)
        let client = APIClient(
            baseURL: URL(string: "https://example.test")!,
            tokenStore: MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")), transport: transport)
        return (RemoteUserRepository(client: client), transport)
    }

    func test_사용_가능한_닉네임() async throws {
        let (repository, transport) = makeRepository { _ in (200, #"{"available":true}"#) }
        let available = try await repository.checkNickname("나뭇잎")
        XCTAssertTrue(available)
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/users/nickname/check")
        let query = URLComponents(url: try XCTUnwrap(transport.requests.first?.url), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(query?.first?.value, "나뭇잎")
    }

    func test_이미_쓰는_닉네임은_false() async throws {
        let (repository, _) = makeRepository { _ in (200, #"{"available":false}"#) }
        let available = try await repository.checkNickname("두부산책")
        XCTAssertFalse(available)
    }

    func test_409_중복_코드도_false로_다룬다() async throws {
        let (repository, _) = makeRepository { _ in (409, #"{"code":"NICKNAME_DUPLICATED"}"#) }
        let available = try await repository.checkNickname("두부산책")
        XCTAssertFalse(available)
    }

    func test_다른_서버_오류는_그대로_던진다() async {
        let (repository, _) = makeRepository { _ in (500, "{}") }
        do {
            _ = try await repository.checkNickname("나뭇잎")
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .server(status: 500, code: nil))
        }
    }
}
