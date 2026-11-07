import Observation

/// 닉네임·캐릭터 변경(마이페이지 [수정]). 온보딩의 닉네임·캐릭터 단계를 그대로 다시 쓴다.
@MainActor @Observable
final class ProfileEditViewModel {
    enum Step: Int, Equatable {
        case nickname = 1
        case character
    }

    private(set) var step: Step = .nickname
    let nickname: NicknameViewModel
    private(set) var character: CharacterSelectViewModel?

    private let repository: UserRepository
    private let profileStore: ProfileStore
    private let initialCharacterID: Int?
    private let onFinished: () -> Void

    init(
        currentNickname: String, currentCharacterID: Int?, repository: UserRepository, profileStore: ProfileStore,
        onFinished: @escaping () -> Void
    ) {
        self.repository = repository
        self.profileStore = profileStore
        self.initialCharacterID = currentCharacterID
        self.onFinished = onFinished
        self.nickname = NicknameViewModel(
            repository: repository, initialText: currentNickname, initialStatus: .available, ownNickname: currentNickname)
    }

    var canGoBack: Bool { step == .character }

    func nicknameConfirmed() {
        guard let confirmed = nickname.confirmedNickname else { return }
        if character == nil {
            character = CharacterSelectViewModel(
                repository: repository, selectedID: initialCharacterID,
                onSaved: { [weak self] in self?.saved() },
                onNicknameDuplicated: { [weak self] in self?.returnToNicknameAsDuplicated() },
                onNicknameInappropriate: { [weak self] in self?.returnToNicknameAsInappropriate() })
        }
        character?.nickname = confirmed
        step = .character
    }

    func goBack() {
        if step == .character { step = .nickname }
    }

    /// 서버에 저장이 끝났다. 지도의 내 캐릭터·랭킹의 "나"가 바로 바뀌도록 기기에도 남긴다.
    private func saved() {
        if let name = nickname.confirmedNickname, let characterID = character?.selectedID {
            profileStore.save(nickname: name, characterID: characterID)
        }
        onFinished()
    }

    /// 저장하는 사이 다른 사람이 같은 이름을 쓴 경우
    private func returnToNicknameAsDuplicated() {
        nickname.markDuplicated()
        step = .nickname
    }

    /// 서버가 닉네임에 쓸 수 없는 말이 들어 있다고 거절한 경우
    private func returnToNicknameAsInappropriate() {
        nickname.markInappropriate()
        step = .nickname
    }
}
