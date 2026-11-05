import XCTest
@testable import Parknic

@MainActor
private struct FakeProvider: SocialLoginProvider {
    let provider: AuthProvider
    var outcome: Result<String, SocialLoginError> = .success("social-token")
    func authenticate() async throws -> String { try outcome.get() }
}

private final class RecordingRepository: AuthRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [(AuthProvider, String)] = []
    let result: Result<LoginResult, APIError>
    init(_ result: Result<LoginResult, APIError>) { self.result = result }
    var calls: [(AuthProvider, String)] { lock.withLock { _calls } }
    func login(provider: AuthProvider, socialToken: String) async throws -> LoginResult {
        lock.withLock { _calls.append((provider, socialToken)) }
        return try result.get()
    }
    func logout() async {}
    func deleteAccount() async throws {}
}

@MainActor
final class LoginViewModelTests: XCTestCase {
    private func makeModel(
        provider: FakeProvider = FakeProvider(provider: .apple),
        repository: RecordingRepository,
        onLoggedIn: @escaping (LoginResult) -> Void = { _ in }
    ) -> LoginViewModel {
        LoginViewModel(providers: [provider], repository: repository, onLoggedIn: onLoggedIn)
    }

    func test_성공하면_소셜_토큰을_서버로_보내고_결과를_전달한다() async {
        let repository = RecordingRepository(.success(LoginResult(isNewUser: true)))
        var received: LoginResult?
        let model = makeModel(repository: repository) { received = $0 }

        await model.login(with: .apple)

        XCTAssertEqual(received, LoginResult(isNewUser: true))
        XCTAssertEqual(repository.calls.first?.0, .apple)
        XCTAssertEqual(repository.calls.first?.1, "social-token")
        XCTAssertEqual(model.state, .idle)
    }

    func test_사용자가_취소하면_에러_없이_처음_상태로_돌아간다() async {
        let repository = RecordingRepository(.success(LoginResult(isNewUser: false)))
        let model = makeModel(provider: FakeProvider(provider: .apple, outcome: .failure(.cancelled)), repository: repository)

        await model.login(with: .apple)

        XCTAssertEqual(model.state, .idle)
        XCTAssertTrue(repository.calls.isEmpty)
    }

    func test_서버_에러는_한글_메시지로_보여준다() async {
        let repository = RecordingRepository(.failure(.network))
        let model = makeModel(repository: repository)

        await model.login(with: .apple)

        XCTAssertEqual(model.state, .failed(APIError.network.userMessage))
    }

    func test_소셜_로그인_실패는_일반_문구를_보여준다() async {
        let repository = RecordingRepository(.success(LoginResult(isNewUser: true)))
        let model = makeModel(provider: FakeProvider(provider: .apple, outcome: .failure(.failed)), repository: repository)

        await model.login(with: .apple)

        XCTAssertEqual(model.state, .failed("로그인하지 못했어요. 다시 시도해주세요"))
    }

    func test_실패_후_다시_시도하면_성공한다() async {
        let repository = RecordingRepository(.failure(.network))
        let model = makeModel(provider: FakeProvider(provider: .apple, outcome: .failure(.failed)), repository: repository)
        await model.login(with: .apple)
        XCTAssertNotEqual(model.state, .idle)

        let retry = LoginViewModel(
            providers: [FakeProvider(provider: .apple)],
            repository: RecordingRepository(.success(LoginResult(isNewUser: false))), onLoggedIn: { _ in })
        await retry.login(with: .apple)
        XCTAssertEqual(retry.state, .idle)
    }

    func test_등록되지_않은_제공자는_무시한다() async {
        let repository = RecordingRepository(.success(LoginResult(isNewUser: true)))
        let model = makeModel(repository: repository)

        await model.login(with: .kakao)

        XCTAssertTrue(repository.calls.isEmpty)
        XCTAssertEqual(model.state, .idle)
    }

    func test_제공자_목록은_주어진_순서를_따른다() {
        let model = LoginViewModel(
            providers: [FakeProvider(provider: .kakao), FakeProvider(provider: .apple)],
            repository: RecordingRepository(.failure(.network)), onLoggedIn: { _ in })
        XCTAssertEqual(model.availableProviders, [.kakao, .apple])
    }
}

#if DEBUG
@MainActor
final class LoginDevelopmentTests: XCTestCase {
    private func makeModel(onLoggedIn: @escaping (LoginResult) -> Void) -> LoginViewModel {
        LoginViewModel(
            providers: [], repository: MockAuthRepository(result: .failure(.network), delay: .zero), onLoggedIn: onLoggedIn)
    }

    func test_개발용_로그인은_소셜_로그인과_서버_없이_바로_로그인된다() {
        var received: [LoginResult] = []
        let model = makeModel { received.append($0) }

        model.loginForDevelopment(isNewUser: true)
        model.loginForDevelopment(isNewUser: false)

        XCTAssertEqual(received, [LoginResult(isNewUser: true), LoginResult(isNewUser: false)])
        XCTAssertEqual(model.state, .idle)
    }

    func test_개발용_로그인으로_앱_단계가_바뀐다() {
        let session = AppSession(tokenStore: MemoryTokenStore(nil))
        let model = makeModel { session.didLogin($0) }

        model.loginForDevelopment(isNewUser: false)
        XCTAssertEqual(session.phase, .main)
    }

    func test_신규_회원으로_개발용_로그인하면_온보딩으로_간다() {
        let session = AppSession(tokenStore: MemoryTokenStore(nil))
        let model = makeModel { session.didLogin($0) }

        model.loginForDevelopment(isNewUser: true)
        XCTAssertEqual(session.phase, .onboarding)
    }
}
#endif
