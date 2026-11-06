import Observation

@MainActor @Observable
final class LoginViewModel {
    enum State: Equatable {
        case idle
        /// 로그인 진행 중인 제공자
        case loading(AuthProvider)
        case failed(String)
    }

    private(set) var state: State = .idle

    private let providers: [AuthProvider: SocialLoginProvider]
    private let repository: AuthRepository
    private let onLoggedIn: (LoginResult) -> Void

    /// 화면에 보여줄 로그인 수단(주어진 순서대로)
    let availableProviders: [AuthProvider]

    init(
        providers: [SocialLoginProvider], repository: AuthRepository, initialState: State = .idle,
        onLoggedIn: @escaping (LoginResult) -> Void
    ) {
        self.state = initialState
        self.providers = Dictionary(providers.map { ($0.provider, $0) }, uniquingKeysWith: { first, _ in first })
        self.availableProviders = providers.map(\.provider)
        self.repository = repository
        self.onLoggedIn = onLoggedIn
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    #if DEBUG
    /// 개발용: 소셜 로그인·서버 없이 바로 로그인된 것으로 처리한다. Release 빌드에는 포함되지 않는다.
    func loginForDevelopment(isNewUser: Bool) {
        guard !isLoading else { return }
        onLoggedIn(LoginResult(isNewUser: isNewUser))
    }
    #endif

    func login(with provider: AuthProvider) async {
        guard !isLoading, let socialProvider = providers[provider] else { return }
        state = .loading(provider)
        do {
            let credential = try await socialProvider.authenticate()
            let result = try await repository.login(
                provider: provider, socialToken: credential.token, authorizationCode: credential.authorizationCode)
            state = .idle
            onLoggedIn(result)
        } catch SocialLoginError.cancelled {
            state = .idle
        } catch let error as APIError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed(String(localized: "로그인하지 못했어요. 다시 시도해주세요"))
        }
    }
}
