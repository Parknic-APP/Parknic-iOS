import XCTest
@testable import Parknic

private final class SpyUserRepository: UserRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _checked: [String] = []
    private var _saved: [(String, Int)] = []
    var taken: Set<String> = []
    var saveError: APIError?

    var checked: [String] { lock.withLock { _checked } }
    var saved: [(String, Int)] { lock.withLock { _saved } }

    func checkNickname(_ nickname: String) async throws -> Bool {
        lock.withLock { _checked.append(nickname) }
        return !taken.contains(nickname)
    }

    func characters() async throws -> [AvatarCharacter] { MockUserRepository.characters }

    func updateProfile(nickname: String, characterID: Int) async throws {
        if let saveError { throw saveError }
        lock.withLock { _saved.append((nickname, characterID)) }
    }
}

@MainActor
final class NicknameOwnNameTests: XCTestCase {
    private func settle(_ model: NicknameViewModel) async {
        for _ in 0..<200 where model.status == .checking {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    func test_지금_쓰는_이름으로_되돌리면_서버에_묻지_않고_사용_가능으로_본다() async {
        let repository = SpyUserRepository()
        repository.taken = ["나뭇잎"]  // 서버는 자기 이름도 중복이라고 답한다
        let model = NicknameViewModel(
            repository: repository, debounce: .zero, initialText: "나뭇잎", initialStatus: .available, ownNickname: "나뭇잎")
        model.text = "초록발"
        await settle(model)
        model.text = "나뭇잎"

        XCTAssertEqual(model.status, .available)
        XCTAssertEqual(model.confirmedNickname, "나뭇잎")
        XCTAssertFalse(repository.checked.contains("나뭇잎"))
    }

    func test_다른_이름은_평소처럼_중복을_확인한다() async {
        let repository = SpyUserRepository()
        repository.taken = ["두부산책"]
        let model = NicknameViewModel(
            repository: repository, debounce: .zero, initialText: "나뭇잎", initialStatus: .available, ownNickname: "나뭇잎")
        model.text = "두부산책"
        await settle(model)
        if case .duplicated = model.status {} else { XCTFail("중복으로 나와야 한다: \(model.status)") }
    }

    func test_중복_확인_버튼도_지금_이름이면_서버에_묻지_않는다() {
        let repository = SpyUserRepository()
        let model = NicknameViewModel(
            repository: repository, debounce: .zero, initialText: "나뭇잎", initialStatus: .available, ownNickname: "나뭇잎")
        model.checkNow()
        XCTAssertEqual(model.status, .available)
        XCTAssertTrue(repository.checked.isEmpty)
    }

    func test_이름을_바꾸는_상황이_아니면_같은_이름도_평소처럼_확인한다() async {
        let repository = SpyUserRepository()
        repository.taken = ["나뭇잎"]
        let model = NicknameViewModel(repository: repository, debounce: .zero)
        model.text = "나뭇잎"
        await settle(model)
        if case .duplicated = model.status {} else { XCTFail("중복으로 나와야 한다: \(model.status)") }
    }
}

@MainActor
final class ProfileEditViewModelTests: XCTestCase {
    private var finished = 0
    private let store = MemoryProfileStore()

    private func make(_ repository: SpyUserRepository) -> ProfileEditViewModel {
        finished = 0
        return ProfileEditViewModel(
            currentNickname: "나뭇잎", currentCharacterID: 3, repository: repository, profileStore: store,
            onFinished: { [self] in finished += 1 })
    }

    func test_지금_닉네임으로_시작하고_바로_다음으로_갈_수_있다() {
        let model = make(SpyUserRepository())
        XCTAssertEqual(model.step, .nickname)
        XCTAssertEqual(model.nickname.text, "나뭇잎")
        XCTAssertTrue(model.nickname.canProceed)
        XCTAssertFalse(model.canGoBack)
    }

    func test_다음으로_가면_지금_캐릭터가_골라진_상태로_시작한다() async {
        let model = make(SpyUserRepository())
        model.nicknameConfirmed()
        XCTAssertEqual(model.step, .character)
        XCTAssertEqual(model.character?.selectedID, 3)
        await model.character?.load()
        XCTAssertEqual(model.character?.selectedID, 3, "목록을 불러와도 고른 캐릭터를 유지한다")
        XCTAssertTrue(model.canGoBack)
    }

    func test_뒤로_가면_닉네임_단계로_돌아간다() {
        let model = make(SpyUserRepository())
        model.nicknameConfirmed()
        model.goBack()
        XCTAssertEqual(model.step, .nickname)
    }

    func test_저장하면_서버와_기기에_남기고_끝났다고_알린다() async {
        let repository = SpyUserRepository()
        let model = make(repository)
        model.nickname.text = "초록잎"
        for _ in 0..<200 where !model.nickname.canProceed { try? await Task.sleep(for: .milliseconds(5)) }
        model.nicknameConfirmed()
        await model.character?.load()
        if let other = model.character?.characters.first(where: { $0.id == 5 }) { model.character?.select(other) }

        await model.character?.confirm()

        XCTAssertEqual(repository.saved.count, 1)
        XCTAssertEqual(repository.saved.first?.0, "초록잎")
        XCTAssertEqual(repository.saved.first?.1, 5)
        XCTAssertEqual(store.nickname, "초록잎")
        XCTAssertEqual(store.characterID, 5)
        XCTAssertEqual(finished, 1)
    }

    func test_저장_중_닉네임이_중복이면_닉네임_단계로_돌아가고_끝나지_않는다() async {
        let repository = SpyUserRepository()
        repository.saveError = .server(status: 409, code: APIErrorCode.nicknameDuplicated.rawValue)
        let model = make(repository)
        model.nicknameConfirmed()
        await model.character?.load()

        await model.character?.confirm()

        XCTAssertEqual(model.step, .nickname)
        if case .duplicated = model.nickname.status {} else { XCTFail("중복 안내가 보여야 한다") }
        XCTAssertEqual(finished, 0)
        XCTAssertNil(store.nickname, "실패하면 기기 값을 바꾸지 않는다")
    }

    func test_저장_실패는_캐릭터_단계에_머문다() async {
        let repository = SpyUserRepository()
        repository.saveError = .network
        let model = make(repository)
        model.nicknameConfirmed()
        await model.character?.load()
        await model.character?.confirm()
        XCTAssertEqual(model.step, .character)
        XCTAssertEqual(finished, 0)
    }
}
