import XCTest
@testable import Parknic

private final class StubUserRepository: UserRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _checked: [String] = []
    var taken: Set<String> = []
    var error: APIError?
    func characters() async throws -> [AvatarCharacter] { [] }
    func updateProfile(nickname: String, characterID: Int) async throws {}

    var checked: [String] { lock.withLock { _checked } }

    func checkNickname(_ nickname: String) async throws -> Bool {
        lock.withLock { _checked.append(nickname) }
        if let error { throw error }
        return !taken.contains(nickname)
    }
}

@MainActor
final class NicknameViewModelTests: XCTestCase {
    private func makeModel(_ repository: StubUserRepository, debounce: Duration = .zero) -> NicknameViewModel {
        NicknameViewModel(repository: repository, debounce: debounce)
    }

    /// 확인 작업이 끝날 때까지 기다린다.
    private func settle(_ model: NicknameViewModel) async {
        for _ in 0..<200 where model.status == .checking {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    func test_처음에는_비어_있고_다음으로_갈_수_없다() {
        let model = makeModel(StubUserRepository())
        XCTAssertEqual(model.status, .empty)
        XCTAssertFalse(model.canProceed)
    }

    func test_한_글자는_너무_짧다고_안내하고_서버에_묻지_않는다() async {
        let repository = StubUserRepository()
        let model = makeModel(repository)
        model.text = "나"
        XCTAssertEqual(model.status, .tooShort)
        XCTAssertTrue(repository.checked.isEmpty)
    }

    func test_공백이_들어간_이름은_거부한다() {
        let model = makeModel(StubUserRepository())
        model.text = "나 뭇잎"
        XCTAssertEqual(model.status, .tooShort)
    }

    func test_사용_가능하면_다음으로_갈_수_있다() async {
        let model = makeModel(StubUserRepository())
        model.text = "나뭇잎"
        XCTAssertEqual(model.status, .checking)
        await settle(model)
        XCTAssertEqual(model.status, .available)
        XCTAssertEqual(model.confirmedNickname, "나뭇잎")
    }

    func test_중복이면_다음_버튼이_비활성이고_대안을_준다() async {
        let repository = StubUserRepository()
        repository.taken = ["두부산책"]
        let model = makeModel(repository)
        model.text = "두부산책"
        await settle(model)
        XCTAssertEqual(model.status, .duplicated(suggestions: ["두부산책2", "두부산책숲", "두부산책이"]))
        XCTAssertFalse(model.canProceed)
    }

    func test_대안은_10자를_넘지_않는다() {
        let suggestions = NicknameViewModel.suggestions(for: "열글자닉네임입니다요")
        XCTAssertEqual(suggestions.map(\.count), [10, 10, 10])
        XCTAssertTrue(suggestions[0].hasSuffix("2"))
    }

    func test_대안을_고르면_입력이_바뀌고_다시_확인한다() async {
        let repository = StubUserRepository()
        repository.taken = ["두부산책"]
        let model = makeModel(repository)
        model.text = "두부산책"
        await settle(model)

        model.select(suggestion: "두부산책2")
        await settle(model)

        XCTAssertEqual(model.text, "두부산책2")
        XCTAssertEqual(model.status, .available)
    }

    func test_10자를_넘게_입력하면_잘린다() {
        let model = makeModel(StubUserRepository())
        model.text = "열한글자닉네임입니다요요"
        XCTAssertEqual(model.text.count, 10)
    }

    func test_연속으로_입력하면_마지막_값만_확인한다() async {
        let repository = StubUserRepository()
        let model = makeModel(repository, debounce: .milliseconds(80))
        model.text = "가나"
        model.text = "가나다"
        model.text = "가나다라"
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertTrue(repository.checked.isEmpty, "디바운스 시간 안에는 요청하지 않는다")
        await settle(model)
        XCTAssertEqual(repository.checked, ["가나다라"])
    }

    func test_확인_중_입력이_바뀌면_이전_결과는_버린다() async {
        let repository = StubUserRepository()
        repository.taken = ["가나"]
        let model = makeModel(repository)
        model.text = "가나"
        model.text = "가"
        await settle(model)
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(model.status, .tooShort)
    }

    func test_입력을_지우면_처음_상태로_돌아간다() async {
        let model = makeModel(StubUserRepository())
        model.text = "나뭇잎"
        await settle(model)
        model.text = ""
        XCTAssertEqual(model.status, .empty)
        XCTAssertFalse(model.canProceed)
    }

    func test_이름이_바뀌면_사용_가능_표시가_사라진다() async {
        let model = makeModel(StubUserRepository())
        model.text = "나뭇잎"
        await settle(model)
        model.text = "나뭇잎2"
        XCTAssertFalse(model.canProceed, "새 이름은 확인이 끝나기 전에는 진행할 수 없다")
    }

    func test_서버가_쓸_수_없는_닉네임이라고_하면_안내하고_진행할_수_없다() async {
        let repository = StubUserRepository()
        repository.error = .server(status: 400, code: "NICKNAME_INAPPROPRIATE")
        let model = makeModel(repository)
        model.text = "나쁜말"
        await settle(model)
        XCTAssertEqual(model.status, .failed(APIErrorCode.nicknameInappropriate.message))
        XCTAssertFalse(model.canProceed)
    }

    func test_저장_단계에서_쓸_수_없는_닉네임으로_드러나면_안내한다() {
        let model = makeModel(StubUserRepository())
        model.text = "나쁜말"
        model.markInappropriate()
        XCTAssertEqual(model.status, .failed(APIErrorCode.nicknameInappropriate.message))
        XCTAssertFalse(model.canProceed)
    }

    func test_서버_오류는_메시지를_보여주고_진행할_수_없다() async {
        let repository = StubUserRepository()
        repository.error = .network
        let model = makeModel(repository)
        model.text = "나뭇잎"
        await settle(model)
        XCTAssertEqual(model.status, .failed(APIError.network.userMessage))
        XCTAssertFalse(model.canProceed)
    }

    func test_키보드_완료는_기다리지_않고_바로_확인한다() async {
        let repository = StubUserRepository()
        let model = makeModel(repository, debounce: .seconds(30))
        model.text = "나뭇잎"
        model.checkNow()
        await settle(model)
        XCTAssertEqual(repository.checked, ["나뭇잎"])
        XCTAssertEqual(model.status, .available)
    }
}
