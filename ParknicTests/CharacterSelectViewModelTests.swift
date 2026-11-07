import XCTest
@testable import Parknic

private final class StubProfileRepository: UserRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _saved: [(String, Int)] = []
    private var characterFailures: Int
    var charactersResult: [AvatarCharacter] = MockUserRepository.characters
    var saveError: APIError?

    init(characterFailures: Int = 0) { self.characterFailures = characterFailures }

    var saved: [(String, Int)] { lock.withLock { _saved } }

    func checkNickname(_ nickname: String) async throws -> Bool { true }

    func characters() async throws -> [AvatarCharacter] {
        let shouldFail = lock.withLock { () -> Bool in
            defer { characterFailures = max(0, characterFailures - 1) }
            return characterFailures > 0
        }
        if shouldFail { throw APIError.network }
        return charactersResult
    }

    func updateProfile(nickname: String, characterID: Int) async throws {
        if let saveError { throw saveError }
        lock.withLock { _saved.append((nickname, characterID)) }
    }
}

@MainActor
final class CharacterSelectViewModelTests: XCTestCase {
    private var savedCount = 0
    private var duplicatedCount = 0
    private var inappropriateCount = 0

    private func makeModel(_ repository: StubProfileRepository) -> CharacterSelectViewModel {
        let model = CharacterSelectViewModel(
            repository: repository, onSaved: { [self] in savedCount += 1 },
            onNicknameDuplicated: { [self] in duplicatedCount += 1 },
            onNicknameInappropriate: { [self] in inappropriateCount += 1 })
        model.nickname = "나뭇잎"
        return model
    }

    func test_불러오면_첫_캐릭터가_선택되어_있다() async {
        let model = makeModel(StubProfileRepository())
        await model.load()
        XCTAssertEqual(model.characters.count, 8)
        XCTAssertEqual(model.selected?.name, "치즈냥")
    }

    func test_다른_캐릭터를_고를_수_있다() async {
        let model = makeModel(StubProfileRepository())
        await model.load()
        model.select(MockUserRepository.characters[4])
        XCTAssertEqual(model.selected?.name, "시바")
    }

    func test_다시_불러와도_고른_캐릭터는_유지된다() async {
        let model = makeModel(StubProfileRepository())
        await model.load()
        model.select(MockUserRepository.characters[4])
        await model.load()
        XCTAssertEqual(model.selected?.name, "시바")
    }

    func test_불러오기에_실패하면_에러_상태이고_재시도로_복구된다() async {
        let model = makeModel(StubProfileRepository(characterFailures: 1))
        await model.load()
        XCTAssertEqual(model.state, .failed(APIError.network.userMessage))
        XCTAssertNil(model.selected)

        await model.load()
        XCTAssertEqual(model.selected?.name, "치즈냥")
    }

    func test_확인하면_닉네임과_캐릭터를_저장하고_다음으로_간다() async {
        let repository = StubProfileRepository()
        let model = makeModel(repository)
        await model.load()
        model.select(MockUserRepository.characters[1])

        await model.confirm()

        XCTAssertEqual(repository.saved.first?.0, "나뭇잎")
        XCTAssertEqual(repository.saved.first?.1, 2)
        XCTAssertEqual(savedCount, 1)
        XCTAssertEqual(model.saveState, .idle)
    }

    func test_저장_중_닉네임이_중복이면_알린다() async {
        let repository = StubProfileRepository()
        repository.saveError = .server(status: 409, code: "NICKNAME_DUPLICATED")
        let model = makeModel(repository)
        await model.load()

        await model.confirm()

        XCTAssertEqual(duplicatedCount, 1)
        XCTAssertEqual(savedCount, 0)
    }

    func test_저장_중_쓸_수_없는_닉네임이면_닉네임_단계로_돌려보낸다() async {
        let repository = StubProfileRepository()
        repository.saveError = .server(status: 400, code: "NICKNAME_INAPPROPRIATE")
        let model = makeModel(repository)
        await model.load()

        await model.confirm()

        XCTAssertEqual(inappropriateCount, 1)
        XCTAssertEqual(duplicatedCount, 0)
        XCTAssertEqual(savedCount, 0)
        XCTAssertEqual(model.saveState, .idle)
    }

    func test_저장에_실패하면_메시지를_보여주고_다시_시도할_수_있다() async {
        let repository = StubProfileRepository()
        repository.saveError = .network
        let model = makeModel(repository)
        await model.load()

        await model.confirm()
        XCTAssertEqual(model.saveState, .failed(APIError.network.userMessage))
        XCTAssertEqual(savedCount, 0)

        repository.saveError = nil
        await model.confirm()
        XCTAssertEqual(savedCount, 1)
    }

    func test_캐릭터를_다시_고르면_저장_오류_표시가_사라진다() async {
        let repository = StubProfileRepository()
        repository.saveError = .network
        let model = makeModel(repository)
        await model.load()
        await model.confirm()
        model.select(MockUserRepository.characters[2])
        XCTAssertEqual(model.saveState, .idle)
    }
}
