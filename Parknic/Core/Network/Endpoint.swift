import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// API 한 건의 요청 정의. 경로는 `/api/...`로 시작한다.
struct Endpoint: Sendable {
    var method: HTTPMethod
    var path: String
    var query: [URLQueryItem] = []
    var body: Data?
    /// false면 Authorization 헤더를 붙이지 않고 401 재발급도 하지 않는다(로그인·재발급).
    var requiresAuth = true

    init(_ method: HTTPMethod, _ path: String, query: [URLQueryItem] = [], requiresAuth: Bool = true) {
        self.method = method
        self.path = path
        self.query = query
        self.requiresAuth = requiresAuth
    }

    init<Body: Encodable>(
        _ method: HTTPMethod, _ path: String, query: [URLQueryItem] = [], body: Body, requiresAuth: Bool = true
    ) throws {
        self.init(method, path, query: query, requiresAuth: requiresAuth)
        self.body = try JSONEncoder().encode(body)
    }
}
