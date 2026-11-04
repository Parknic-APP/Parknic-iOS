import Foundation
@testable import Parknic

/// 준비된 응답을 순서대로 돌려주고, 받은 요청을 기록하는 가짜 통신
final class StubTransport: HTTPTransport, @unchecked Sendable {
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

final class MemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: AuthTokens?
    init(_ tokens: AuthTokens?) { self.tokens = tokens }
    func load() -> AuthTokens? { lock.withLock { tokens } }
    func save(_ tokens: AuthTokens) throws { lock.withLock { self.tokens = tokens } }
    func clear() { lock.withLock { tokens = nil } }
}
