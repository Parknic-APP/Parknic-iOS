import Observation

/// 닉네임 입력 단계(07b·07c). 입력이 멈추면 자동으로 중복을 확인한다.
@MainActor @Observable
final class NicknameViewModel {
    enum Status: Equatable {
        case empty
        case tooShort
        case checking
        case available
        case duplicated(suggestions: [String])
        case failed(String)
    }

    static let lengthRange = 2...10

    private(set) var status: Status
    var text: String {
        didSet { textDidChange(from: oldValue) }
    }

    /// 닉네임을 바꾸는 중이라면 지금 쓰는 이름. 같은 이름은 중복 확인 없이 쓸 수 있다.
    private let ownNickname: String?
    private let repository: UserRepository
    private let clock: any Clock<Duration>
    private let debounce: Duration
    private var checkTask: Task<Void, Never>?

    init(
        repository: UserRepository, clock: any Clock<Duration> = ContinuousClock(),
        debounce: Duration = .milliseconds(500), initialText: String = "", initialStatus: Status = .empty,
        ownNickname: String? = nil
    ) {
        self.ownNickname = ownNickname
        self.repository = repository
        self.clock = clock
        self.debounce = debounce
        self.text = initialText
        self.status = initialStatus
    }

    /// 다음 단계로 갈 수 있는 닉네임. 사용 가능으로 확인된 경우에만 값이 있다.
    var confirmedNickname: String? {
        status == .available ? trimmed : nil
    }

    var canProceed: Bool { confirmedNickname != nil }

    private var trimmed: String { text.trimmingCharacters(in: .whitespaces) }

    /// 키보드의 완료(return)를 눌렀을 때. 기다리지 않고 바로 확인한다.
    func checkNow() {
        guard validate(), !confirmsOwnNickname() else { return }
        startCheck(delay: .zero)
    }

    /// 저장 단계에서 중복이 드러난 경우
    func markDuplicated() {
        checkTask?.cancel()
        status = .duplicated(suggestions: Self.suggestions(for: trimmed))
    }

    /// 서버가 닉네임에 쓸 수 없는 말이 들어 있다고 거절한 경우(입력 중 확인이나 저장 단계)
    func markInappropriate() {
        checkTask?.cancel()
        status = .failed(APIErrorCode.nicknameInappropriate.message)
    }

    func select(suggestion: String) {
        text = suggestion
    }

    // MARK: 내부

    private func textDidChange(from old: String) {
        if text.count > Self.lengthRange.upperBound {
            text = String(text.prefix(Self.lengthRange.upperBound))
            return
        }
        guard text != old else { return }
        guard validate(), !confirmsOwnNickname() else { return }
        startCheck(delay: debounce)
    }

    /// 지금 쓰는 이름 그대로면 서버에 묻지 않고 사용 가능으로 본다(서버는 자기 이름도 중복이라고 답한다).
    private func confirmsOwnNickname() -> Bool {
        guard let ownNickname, trimmed == ownNickname else { return false }
        checkTask?.cancel()
        status = .available
        return true
    }

    /// 형식이 맞지 않으면 상태를 갱신하고 진행 중인 확인을 취소한다.
    private func validate() -> Bool {
        let name = trimmed
        if name.isEmpty {
            cancelCheck(status: .empty)
            return false
        }
        if name.contains(where: \.isWhitespace) || name.count < Self.lengthRange.lowerBound {
            cancelCheck(status: .tooShort)
            return false
        }
        return true
    }

    private func cancelCheck(status: Status) {
        checkTask?.cancel()
        self.status = status
    }

    private func startCheck(delay: Duration) {
        checkTask?.cancel()
        status = .checking
        let name = trimmed
        checkTask = Task { [repository, clock] in
            do {
                if delay > .zero { try await clock.sleep(for: delay) }
                let available = try await repository.checkNickname(name)
                guard !Task.isCancelled, name == trimmed else { return }
                status = available ? .available : .duplicated(suggestions: Self.suggestions(for: name))
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, name == trimmed else { return }
                let message = (error as? APIError)?.userMessage ?? APIError.network.userMessage
                status = .failed(message)
            }
        }
    }

    /// 중복일 때 보여줄 대안. 길이 제한(10자)을 넘으면 앞부분을 잘라 맞춘다.
    static func suggestions(for name: String) -> [String] {
        let limit = lengthRange.upperBound
        return ["2", "숲", "이"].map { suffix in
            String(name.prefix(limit - suffix.count)) + suffix
        }
    }
}
