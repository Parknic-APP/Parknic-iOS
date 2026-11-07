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
    /// 로그아웃·탈퇴·세션 만료로 로그인 화면으로 돌아갈 때 부른다(이전 사용자의 화면 상태를 비운다).
    var onSignedOut: (() -> Void)?
    /// 로그인에 성공했다(온보딩 여부와 무관). 계정이 바뀐 걸 화면 상태에 알릴 때 쓴다.
    var onSignedIn: (() -> Void)?

    /// 저장된 토큰이 있으면 자동 로그인한다.
    /// 온보딩 도중 종료한 경우의 복구는 `/api/users/me` 연동 후 추가한다.
    init(tokenStore: TokenStore) {
        phase = tokenStore.load() == nil ? .loggedOut : .main
    }

    func didLogin(_ result: LoginResult) {
        phase = result.isNewUser ? .onboarding : .main
        onSignedIn?()
    }

    func didFinishOnboarding() {
        phase = .main
    }

    /// 재발급 실패, 로그아웃, 탈퇴
    func didLogout() {
        onSignedOut?()
        phase = .loggedOut
    }
}
