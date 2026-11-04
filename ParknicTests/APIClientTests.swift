import XCTest
@testable import Parknic

/// 준비된 응답을 순서대로 돌려주고, 받은 요청을 기록하는 가짜 통신
private final class StubTransport: HTTPTransport, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, String)

    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    private let handler: Handler

    init(_ handler: @escaping Handler) { self.handler = handler }

    var requests: [URLRequest] { lock.withLock { _requests } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { _requests.append(request) }
        let (status, body) = try handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

private final class MemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: AuthTokens?
    init(_ tokens: AuthTokens?) { self.tokens = tokens }
    func load() -> AuthTokens? { lock.withLock { tokens } }
    func save(_ tokens: AuthTokens) throws { lock.withLock { self.tokens = tokens } }
    func clear() { lock.withLock { tokens = nil } }
}

private struct Sample: Decodable, Equatable, Sendable { let name: String }
private struct Stamped: Decodable, Sendable { let at: Date }

final class APIClientTests: XCTestCase {
    private let baseURL = URL(string: "https://example.test")!
    private let oldTokens = AuthTokens(accessToken: "old-access", refreshToken: "old-refresh")

    private func makeClient(
        store: TokenStore, expired: (@Sendable () -> Void)? = nil, handler: @escaping StubTransport.Handler
    ) -> (APIClient, StubTransport) {
        let transport = StubTransport(handler)
        let client = APIClient(
            baseURL: baseURL, tokenStore: store, transport: transport, onSessionExpired: expired ?? {})
        return (client, transport)
    }

    private func bearer(_ request: URLRequest) -> String? {
        request.value(forHTTPHeaderField: "Authorization")
    }

    func test_성공_응답을_디코딩하고_Bearer_헤더를_붙인다() async throws {
        let (client, transport) = makeClient(store: MemoryTokenStore(oldTokens)) { _ in (200, #"{"name":"공원"}"#) }
        let result: Sample = try await client.send(Endpoint(.get, "/api/parks/1"))
        XCTAssertEqual(result, Sample(name: "공원"))
        XCTAssertEqual(bearer(transport.requests[0]), "Bearer old-access")
    }

    func test_쿼리가_URL에_붙는다() async throws {
        let (client, transport) = makeClient(store: MemoryTokenStore(oldTokens)) { _ in (200, #"{"name":"a"}"#) }
        let endpoint = Endpoint(.get, "/api/parks/nearby", query: [.init(name: "lat", value: "37.5"), .init(name: "radius", value: "1000")])
        let _: Sample = try await client.send(endpoint)
        XCTAssertEqual(transport.requests[0].url?.absoluteString, "https://example.test/api/parks/nearby?lat=37.5&radius=1000")
    }

    func test_서버_에러는_code로_분기된다() async {
        let (client, _) = makeClient(store: MemoryTokenStore(oldTokens)) { _ in
            (409, #"{"code":"NICKNAME_DUPLICATED","message":"dup"}"#)
        }
        do {
            try await client.send(Endpoint(.patch, "/api/users/me"))
            XCTFail("에러가 나야 한다")
        } catch let error as APIError {
            XCTAssertEqual(error, .server(status: 409, code: "NICKNAME_DUPLICATED"))
            XCTAssertEqual(error.serverCode, .nicknameDuplicated)
        } catch {
            XCTFail("APIError가 아님: \(error)")
        }
    }

    func test_401이면_재발급_후_원_요청을_한_번_재시도한다() async throws {
        let store = MemoryTokenStore(oldTokens)
        let (client, transport) = makeClient(store: store) { request in
            if request.url?.path == "/api/auth/reissue" {
                return (200, #"{"accessToken":"new-access","refreshToken":"new-refresh"}"#)
            }
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer old-access" {
                return (401, #"{"code":"TOKEN_EXPIRED"}"#)
            }
            return (200, #"{"name":"ok"}"#)
        }
        let result: Sample = try await client.send(Endpoint(.get, "/api/users/me"))
        XCTAssertEqual(result, Sample(name: "ok"))
        XCTAssertEqual(transport.requests.map { $0.url?.path }, ["/api/users/me", "/api/auth/reissue", "/api/users/me"])
        XCTAssertEqual(bearer(transport.requests[2]), "Bearer new-access")
        XCTAssertEqual(store.load(), AuthTokens(accessToken: "new-access", refreshToken: "new-refresh"))
        XCTAssertNil(bearer(transport.requests[1]), "재발급 요청에는 Access 토큰을 붙이지 않는다")
    }

    func test_재발급이_거부되면_토큰을_지우고_로그인으로_보낸다() async {
        let store = MemoryTokenStore(oldTokens)
        let expired = Expectation()
        let (client, _) = makeClient(store: store, expired: { expired.fulfill() }) { request in
            request.url?.path == "/api/auth/reissue" ? (401, "{}") : (401, "{}")
        }
        do {
            try await client.send(Endpoint(.get, "/api/users/me"))
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .sessionExpired)
        }
        XCTAssertNil(store.load())
        XCTAssertTrue(expired.isFulfilled)
    }

    func test_재시도도_401이면_무한반복하지_않고_세션을_끝낸다() async {
        let store = MemoryTokenStore(oldTokens)
        let (client, transport) = makeClient(store: store) { request in
            request.url?.path == "/api/auth/reissue"
                ? (200, #"{"accessToken":"new-access","refreshToken":"new-refresh"}"#) : (401, "{}")
        }
        do {
            try await client.send(Endpoint(.get, "/api/users/me"))
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .sessionExpired)
        }
        XCTAssertEqual(transport.requests.count, 3, "원 요청, 재발급, 재시도 1회로 끝나야 한다")
        XCTAssertNil(store.load())
    }

    func test_재발급_중_연결_문제는_토큰을_유지한다() async {
        let store = MemoryTokenStore(oldTokens)
        let (client, _) = makeClient(store: store) { request in
            if request.url?.path == "/api/auth/reissue" { throw URLError(.notConnectedToInternet) }
            return (401, "{}")
        }
        do {
            try await client.send(Endpoint(.get, "/api/users/me"))
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .network)
        }
        XCTAssertEqual(store.load(), oldTokens)
    }

    func test_재발급_중_서버_오류는_토큰을_유지한다() async {
        let store = MemoryTokenStore(oldTokens)
        let (client, _) = makeClient(store: store) { request in
            request.url?.path == "/api/auth/reissue" ? (503, "{}") : (401, "{}")
        }
        do {
            try await client.send(Endpoint(.get, "/api/users/me"))
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .server(status: 503, code: nil))
        }
        XCTAssertEqual(store.load(), oldTokens)
    }

    func test_동시에_401이_와도_재발급은_한_번만_한다() async throws {
        let store = MemoryTokenStore(oldTokens)
        let (client, transport) = makeClient(store: store) { request in
            if request.url?.path == "/api/auth/reissue" {
                return (200, #"{"accessToken":"new-access","refreshToken":"new-refresh"}"#)
            }
            return request.value(forHTTPHeaderField: "Authorization") == "Bearer old-access"
                ? (401, "{}") : (200, #"{"name":"ok"}"#)
        }
        try await withThrowingTaskGroup(of: Sample.self) { group in
            for _ in 0..<5 { group.addTask { try await client.send(Endpoint(.get, "/api/users/me")) } }
            for try await _ in group {}
        }
        let reissues = transport.requests.filter { $0.url?.path == "/api/auth/reissue" }.count
        XCTAssertEqual(reissues, 1)
    }

    func test_인증이_필요없는_요청은_재발급하지_않는다() async {
        let (client, transport) = makeClient(store: MemoryTokenStore(nil)) { _ in (401, "{}") }
        do {
            try await client.send(Endpoint(.post, "/api/auth/login/apple", requiresAuth: false))
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .server(status: 401, code: nil))
        }
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertNil(bearer(transport.requests[0]))
    }

    func test_연결_실패는_network_에러다() async {
        let (client, _) = makeClient(store: MemoryTokenStore(oldTokens)) { _ in throw URLError(.timedOut) }
        do {
            try await client.send(Endpoint(.get, "/api/parks/1"))
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .network)
        }
    }

    func test_KST_오프셋_날짜를_해석한다() async throws {
        let (client, _) = makeClient(store: MemoryTokenStore(oldTokens)) { _ in
            (200, #"{"at":"2026-11-04T15:32:10+09:00"}"#)
        }
        let result: Stamped = try await client.send(Endpoint(.get, "/api/check-ins/current"))
        XCTAssertEqual(result.at, Date(timeIntervalSince1970: 1_793_773_930))
    }

    func test_해석할_수_없는_응답은_decoding_에러다() async {
        let (client, _) = makeClient(store: MemoryTokenStore(oldTokens)) { _ in (200, "not json") }
        do {
            let _: Sample = try await client.send(Endpoint(.get, "/api/parks/1"))
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }
}

private final class Expectation: @unchecked Sendable {
    private let lock = NSLock()
    private var fulfilled = false
    func fulfill() { lock.withLock { fulfilled = true } }
    var isFulfilled: Bool { lock.withLock { fulfilled } }
}
