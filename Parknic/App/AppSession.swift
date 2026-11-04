import Observation

/// 앱이 어느 단계(로그인 / 온보딩 / 메인)에 있는지 관리한다.
@MainActor @Observable
final class AppSession {
    enum Phase: Equatable {
        case loggedOut
        case onboarding
        case main
    }

    private(set) var phase: Phase

    /// 저장된 토큰이 있으면 자동 로그인한다.
    /// 온보딩 도중 종료한 경우의 복구는 `/api/users/me` 연동 후 추가한다.
    init(tokenStore: TokenStore) {
        phase = tokenStore.load() == nil ? .loggedOut : .main
    }

    func didLogin(_ result: LoginResult) {
        phase = result.isNewUser ? .onboarding : .main
    }

    func didFinishOnboarding() {
        phase = .main
    }

    /// 재발급 실패, 로그아웃, 탈퇴
    func didLogout() {
        phase = .loggedOut
    }
}
