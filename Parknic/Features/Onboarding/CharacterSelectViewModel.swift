import Observation

/// 캐릭터 선택 단계(12f). 선택하면 닉네임과 함께 서버에 저장한다.
@MainActor @Observable
final class CharacterSelectViewModel {
    enum State: Equatable {
        case loading
        case loaded([AvatarCharacter])
        case failed(String)
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case failed(String)
    }

    private(set) var state: State
    private(set) var saveState: SaveState = .idle
    private(set) var selectedID: Int?

    /// 저장할 닉네임. 이 단계에 들어오기 전에 정해진다.
    var nickname = ""

    private let repository: UserRepository
    private let onSaved: () -> Void
    private let onNicknameDuplicated: () -> Void

    init(
        repository: UserRepository, initialState: State = .loading, selectedID: Int? = nil,
        onSaved: @escaping () -> Void, onNicknameDuplicated: @escaping () -> Void
    ) {
        self.repository = repository
        self.state = initialState
        self.selectedID = selectedID
        self.onSaved = onSaved
        self.onNicknameDuplicated = onNicknameDuplicated
    }

    var characters: [AvatarCharacter] {
        if case .loaded(let characters) = state { return characters }
        return []
    }

    var selected: AvatarCharacter? {
        characters.first { $0.id == selectedID }
    }

    var isSaving: Bool { saveState == .saving }

    func loadIfNeeded() async {
        if case .loaded = state { return }
        await load()
    }

    func load() async {
        state = .loading
        do {
            let characters = try await repository.characters()
            state = .loaded(characters)
            // 처음 들어오면 첫 캐릭터를 고른 상태로 시작한다.
            if !characters.contains(where: { $0.id == selectedID }) { selectedID = characters.first?.id }
        } catch {
            state = .failed(Self.message(for: error))
        }
    }

    func select(_ character: AvatarCharacter) {
        guard !isSaving else { return }
        selectedID = character.id
        saveState = .idle
    }

    func confirm() async {
        guard let selected, !isSaving else { return }
        saveState = .saving
        do {
            try await repository.updateProfile(nickname: nickname, characterID: selected.id)
            saveState = .idle
            onSaved()
        } catch let error as APIError where error.serverCode == .nicknameDuplicated {
            saveState = .idle
            onNicknameDuplicated()
        } catch {
            saveState = .failed(Self.message(for: error))
        }
    }

    private static func message(for error: Error) -> String {
        (error as? APIError)?.userMessage ?? APIError.network.userMessage
    }
}
