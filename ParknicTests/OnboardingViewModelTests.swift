import XCTest
@testable import Parknic

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    private func makeModel(
        repository: UserRepository = MockUserRepository(takenNicknames: ["두부산책"], delay: .zero),
        finished: @escaping () -> Void = {}
    ) -> OnboardingViewModel {
        OnboardingViewModel(repository: repository, onFinished: finished)
    }

    private func confirmNickname(_ model: OnboardingViewModel, _ name: String) async {
        model.nickname.text = name
        for _ in 0..<400 where !model.nickname.canProceed {
            try? await Task.sleep(for: .milliseconds(5))
        }
        model.nicknameConfirmed()
    }

    func test_닉네임이_확인되지_않으면_다음_단계로_가지_않는다() {
        let model = makeModel()
        model.nicknameConfirmed()
        XCTAssertEqual(model.step, .nickname)
        XCTAssertNil(model.character)
    }

    func test_닉네임을_확인하면_캐릭터_단계로_간다() async {
        let model = makeModel()
        await confirmNickname(model, "나뭇잎")
        XCTAssertEqual(model.step, .character)
        XCTAssertEqual(model.character?.nickname, "나뭇잎")
        XCTAssertTrue(model.canGoBack)
    }

    func test_뒤로_가서_닉네임을_바꾸면_새_닉네임으로_저장한다() async {
        let model = makeModel()
        await confirmNickname(model, "나뭇잎")
        model.goBack()
        XCTAssertEqual(model.step, .nickname)

        await confirmNickname(model, "솔방울")
        XCTAssertEqual(model.character?.nickname, "솔방울")
    }

    func test_저장에_성공하면_권한_안내로_가고_끝내면_완료를_알린다() async {
        var finished = false
        let model = makeModel { finished = true }
        await confirmNickname(model, "나뭇잎")

        await model.character?.loadIfNeeded()
        await model.character?.confirm()
        XCTAssertEqual(model.step, .permission)

        model.finish()
        XCTAssertTrue(finished)
    }

    func test_저장_중_중복이_드러나면_닉네임_단계로_돌아가_안내한다() async {
        // 확인 때는 쓸 수 있었지만 저장 시점에 다른 사람이 쓰고 있는 상황
        let model = makeModel(repository: LateDuplicateRepository())
        await confirmNickname(model, "나뭇잎")
        await model.character?.loadIfNeeded()

        await model.character?.confirm()

        XCTAssertEqual(model.step, .nickname)
        if case .duplicated = model.nickname.status {} else { XCTFail("중복 상태여야 한다: \(model.nickname.status)") }
        XCTAssertFalse(model.nickname.canProceed)
    }

    func test_첫_단계에서는_뒤로_갈_수_없다() {
        let model = makeModel()
        XCTAssertFalse(model.canGoBack)
        model.goBack()
        XCTAssertEqual(model.step, .nickname)
    }
}

/// 확인은 통과하지만 저장은 중복으로 실패한다.
private struct LateDuplicateRepository: UserRepository {
    func checkNickname(_ nickname: String) async throws -> Bool { true }
    func characters() async throws -> [AvatarCharacter] { MockUserRepository.characters }
    func updateProfile(nickname: String, characterID: Int) async throws {
        throw APIError.server(status: 409, code: "NICKNAME_DUPLICATED")
    }
}
