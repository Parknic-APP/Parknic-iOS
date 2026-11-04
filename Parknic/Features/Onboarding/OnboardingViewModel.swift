import Observation

/// 온보딩 흐름(닉네임 → 캐릭터 → 권한 안내)을 이끈다.
@MainActor @Observable
final class OnboardingViewModel {
    enum Step: Int, Equatable {
        case nickname = 1
        case character
        case permission
    }

    private(set) var step: Step = .nickname
    let nickname: NicknameViewModel
    private(set) var character: CharacterSelectViewModel?
    let permission: PermissionGuideViewModel

    private let repository: UserRepository

    init(
        repository: UserRepository, location: LocationPermissionRequesting,
        notification: NotificationPermissionRequesting, onFinished: @escaping () -> Void
    ) {
        self.repository = repository
        self.nickname = NicknameViewModel(repository: repository)
        self.permission = PermissionGuideViewModel(location: location, notification: notification, onFinished: onFinished)
    }

    var canGoBack: Bool { step != .nickname }

    func nicknameConfirmed() {
        guard let confirmed = nickname.confirmedNickname else { return }
        if character == nil {
            character = CharacterSelectViewModel(
                repository: repository,
                onSaved: { [weak self] in self?.step = .permission },
                onNicknameDuplicated: { [weak self] in self?.returnToNicknameAsDuplicated() })
        }
        character?.nickname = confirmed
        step = .character
    }

    func goBack() {
        switch step {
        case .nickname: break
        case .character: step = .nickname
        case .permission: step = .character
        }
    }

    /// 저장하는 사이 다른 사람이 같은 이름을 쓴 경우
    private func returnToNicknameAsDuplicated() {
        nickname.markDuplicated()
        step = .nickname
    }
}
