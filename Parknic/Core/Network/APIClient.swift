import Foundation

/// 서버 통신의 유일한 진입점. Repository는 이 클라이언트만 쓴다.
/// - 인증 요청에 Bearer 헤더를 붙인다.
/// - 401이면 Refresh 토큰으로 재발급하고 원 요청을 1회만 재시도한다.
/// - 재발급이 거부되면 토큰을 지우고 `onSessionExpired`로 로그인 화면 이동을 알린다.
actor APIClient {
    private struct ErrorBody: Decodable { let code: String? }
    private struct ReissueBody: Encodable { let refreshToken: String }

    private let baseURL: URL
    private let transport: HTTPTransport
    private let tokenStore: TokenStore
    private let onSessionExpired: @Sendable () -> Void
    private let decoder: JSONDecoder

    /// 동시에 여러 요청이 401을 받아도 재발급은 한 번만 한다.
    private var refreshTask: Task<AuthTokens, Error>?

    init(
        baseURL: URL,
        tokenStore: TokenStore,
        transport: HTTPTransport = URLSession.shared,
        onSessionExpired: @escaping @Sendable () -> Void = {}
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.transport = transport
        self.onSessionExpired = onSessionExpired
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = Self.parseDate(text) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "날짜 형식이 올바르지 않다"))
        }
    }

    // MARK: 공개 API

    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint, as type: Response.Type = Response.self) async throws
        -> Response
    {
        let data = try await perform(endpoint, allowRetry: true)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    /// 응답 본문이 필요 없는 요청(204 등)
    func send(_ endpoint: Endpoint) async throws {
        _ = try await perform(endpoint, allowRetry: true)
    }

    // MARK: 요청 실행

    private func perform(_ endpoint: Endpoint, allowRetry: Bool) async throws -> Data {
        let usedAccessToken = endpoint.requiresAuth ? tokenStore.load()?.accessToken : nil
        let request = try makeRequest(endpoint, accessToken: usedAccessToken)
        let (data, response) = try await execute(request)

        switch response.statusCode {
        case 200..<300:
            return data
        case 401 where endpoint.requiresAuth && allowRetry:
            try await recoverFromUnauthorized(failedAccessToken: usedAccessToken)
            return try await perform(endpoint, allowRetry: false)
        case 401 where endpoint.requiresAuth:
            expireSession()
            throw APIError.sessionExpired
        default:
            let code = try? decoder.decode(ErrorBody.self, from: data).code
            throw APIError.server(status: response.statusCode, code: code)
        }
    }

    private func execute(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            return try await transport.send(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.network
        }
    }

    private func makeRequest(_ endpoint: Endpoint, accessToken: String?) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidRequest
        }
        components.path = endpoint.path
        components.queryItems = endpoint.query.isEmpty ? nil : endpoint.query
        guard let url = components.url else { throw APIError.invalidRequest }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: 토큰 재발급

    private func recoverFromUnauthorized(failedAccessToken: String?) async throws {
        // 다른 요청이 이미 토큰을 갈아 끼웠다면 재발급 없이 바로 재시도한다.
        if let current = tokenStore.load()?.accessToken, current != failedAccessToken { return }

        let task: Task<AuthTokens, Error>
        if let existing = refreshTask {
            task = existing
        } else {
            guard let refreshToken = tokenStore.load()?.refreshToken else {
                expireSession()
                throw APIError.sessionExpired
            }
            task = Task { try await self.reissue(refreshToken: refreshToken) }
            refreshTask = task
        }
        defer { refreshTask = nil }

        do {
            let tokens = try await task.value
            try? tokenStore.save(tokens)
        } catch let error as APIError {
            // Refresh 토큰이 거부된 경우에만 세션을 끝낸다. 연결 문제·서버 오류는 토큰을 유지한다.
            if case .server(let status, _) = error, [400, 401, 403].contains(status) {
                expireSession()
                throw APIError.sessionExpired
            }
            throw error
        }
    }

    private func reissue(refreshToken: String) async throws -> AuthTokens {
        let endpoint = try Endpoint(
            .post, "/api/auth/reissue", body: ReissueBody(refreshToken: refreshToken), requiresAuth: false)
        let request = try makeRequest(endpoint, accessToken: nil)
        let (data, response) = try await execute(request)
        guard (200..<300).contains(response.statusCode) else {
            throw APIError.server(status: response.statusCode, code: nil)
        }
        do {
            return try decoder.decode(AuthTokens.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func expireSession() {
        tokenStore.clear()
        onSessionExpired()
    }

    // MARK: 날짜

    private static func parseDate(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: text) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }
}
