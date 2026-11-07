import XCTest
@testable import Parknic

private final class SpyAuthRepository: AuthRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [String] = []
    var deleteError: APIError?
    var calls: [String] { lock.withLock { _calls } }

    func login(provider: AuthProvider, socialToken: String, authorizationCode: String?) async throws -> LoginResult { LoginResult(isNewUser: false) }
    func logout() async { lock.withLock { _calls.append("logout") } }
    func deleteAccount() async throws {
        if let deleteError { throw deleteError }
        lock.withLock { _calls.append("delete") }
    }
}

struct StubNotificationStatus: NotificationStatusReading {
    var enabled: Bool
    func isEnabled() async -> Bool { enabled }
}

@MainActor
final class MyPageViewModelTests: XCTestCase {
    private var signedOut = 0
    private let profile = MemoryProfileStore()

    private func make(_ auth: SpyAuthRepository, checkInActive: Bool = false) -> MyPageViewModel {
        signedOut = 0
        profile.save(nickname: "나뭇잎", characterID: 5)
        return MyPageViewModel(
            auth: auth, profile: profile, repository: MockMyPageRepository(delay: .zero), userRepository: MockUserRepository(),
            notificationStatus: StubNotificationStatus(enabled: true),
            isCheckInActive: { checkInActive }, onSignedOut: { [self] in signedOut += 1 })
    }

    func test_내_리뷰를_누르면_그_공원의_리뷰_목록을_만든다() {
        let model = make(SpyAuthRepository())
        let review = MyReview(id: 7, parkID: 42, parkName: "서서울호수공원", rating: 5, content: "산책하기 좋아요", createdAt: Date())

        let list = model.makeReviewListViewModel(for: review)

        XCTAssertEqual(list.parkID, 42)
        XCTAssertEqual(list.parkName, "서서울호수공원")
    }

    func test_내_리뷰_수정_화면은_수정_모드로_만들어진다() {
        let model = make(SpyAuthRepository())
        let review = Review(id: 7, userID: 1, nickname: "나뭇잎", characterID: 1, badgeCount: 3, rating: 4, content: "산책하기 좋아요 정말로", createdAt: Date(), isMine: true)

        let editor = model.makeReviewEditorViewModel(for: review) { _ in }

        XCTAssertEqual(editor.mode, .edit(review))
        XCTAssertTrue(editor.isEditing)
        XCTAssertEqual(editor.rating, 4)
        XCTAssertEqual(editor.content, "산책하기 좋아요 정말로")
    }

    func test_주변_공원_범위를_고르면_저장하고_지도에_알린다() {
        var notified = 0
        let defaults = UserDefaults(suiteName: "tests.mypage.radius.\(UUID().uuidString)")!
        let setting = SearchRadiusSetting(store: UserDefaultsSearchRadiusStore(defaults: defaults))
        let model = MyPageViewModel(
            auth: SpyAuthRepository(), profile: profile, repository: MockMyPageRepository(delay: .zero), userRepository: MockUserRepository(),
            searchRadius: setting, onSearchRadiusChanged: { notified += 1 },
            notificationStatus: StubNotificationStatus(enabled: true), isCheckInActive: { false }, onSignedOut: {})

        model.selectSearchRadius(.km1_5)
        model.selectSearchRadius(.km1_5)  // 같은 값을 다시 골라도 다시 알리지 않는다

        XCTAssertEqual(setting.radius, .km1_5)
        XCTAssertEqual(notified, 1)
    }

    func test_프로필을_보여준다() {
        let model = make(SpyAuthRepository())
        XCTAssertEqual(model.nickname, "나뭇잎")
        XCTAssertEqual(model.characterAssetName, "character-5")
    }

    func test_프로필이_없으면_기본_닉네임을_보여준다() {
        let model = make(SpyAuthRepository())
        profile.clear()
        XCTAssertEqual(model.nickname, "산책러")
        XCTAssertNil(model.characterAssetName)
    }

    func test_로그아웃하면_서버에_알리고_기기_정보를_지우고_로그인으로_돌아간다() async {
        let auth = SpyAuthRepository()
        let model = make(auth)
        await model.logout()
        XCTAssertEqual(auth.calls, ["logout"])
        XCTAssertEqual(signedOut, 1)
        XCTAssertNil(profile.nickname)
        XCTAssertFalse(model.isWorking)
    }

    func test_탈퇴하면_서버에_알리고_기기_정보를_지우고_로그인으로_돌아간다() async {
        let auth = SpyAuthRepository()
        let model = make(auth)
        await model.deleteAccount()
        XCTAssertEqual(auth.calls, ["delete"])
        XCTAssertEqual(signedOut, 1)
        XCTAssertNil(profile.characterID)
    }

    func test_탈퇴에_실패하면_로그인으로_돌아가지_않고_안내한다() async {
        let auth = SpyAuthRepository()
        auth.deleteError = .network
        let model = make(auth)
        await model.deleteAccount()
        XCTAssertEqual(signedOut, 0)
        XCTAssertEqual(model.errorMessage, APIError.network.userMessage)
        XCTAssertEqual(profile.nickname, "나뭇잎", "탈퇴가 안 됐으니 기기 정보를 지우지 않는다")
        XCTAssertFalse(model.isWorking)
    }

    func test_탈퇴를_다시_시도하면_이전_오류_문구를_지우고_성공한다() async {
        let auth = SpyAuthRepository()
        auth.deleteError = .network
        let model = make(auth)
        await model.deleteAccount()
        auth.deleteError = nil
        await model.deleteAccount()
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(signedOut, 1)
    }

    func test_체크인_중에는_로그아웃과_탈퇴를_막는다() async {
        let auth = SpyAuthRepository()
        let model = make(auth, checkInActive: true)
        XCTAssertTrue(model.blocksAccountActions)
        await model.logout()
        await model.deleteAccount()
        XCTAssertTrue(auth.calls.isEmpty)
        XCTAssertEqual(signedOut, 0)
    }
}

@MainActor
final class AppSessionSignOutTests: XCTestCase {
    func test_로그아웃하면_정리_훅을_먼저_부르고_로그인_화면으로_간다() {
        let session = AppSession(tokenStore: MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")))
        var phaseWhenHookRan: AppSession.Phase?
        session.onSignedOut = { phaseWhenHookRan = session.phase }
        session.didLogout()
        XCTAssertEqual(phaseWhenHookRan, .main, "화면이 바뀌기 전에 새 상태를 준비한다")
        XCTAssertEqual(session.phase, .loggedOut)
    }
}

final class RemoteAuthSignOutTests: XCTestCase {
    private func make(handler: @escaping StubTransport.Handler) -> (RemoteAuthRepository, StubTransport, MemoryTokenStore) {
        let store = MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r"))
        let transport = StubTransport(handler)
        let client = APIClient(baseURL: URL(string: "https://example.test")!, tokenStore: store, transport: transport)
        return (RemoteAuthRepository(client: client, tokenStore: store), transport, store)
    }

    func test_로그아웃은_서버에_알리고_토큰을_지운다() async {
        let (repository, transport, store) = make { _ in (200, "{}") }
        await repository.logout()
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/auth/logout")
        XCTAssertEqual(transport.requests.first?.httpMethod, "POST")
        XCTAssertNil(store.load())
    }

    func test_서버가_실패해도_기기에서는_로그아웃된다() async {
        let (repository, _, store) = make { _ in (500, "{}") }
        await repository.logout()
        XCTAssertNil(store.load(), "서버 오류로 로그아웃이 안 되면 사용자가 갇힌다")
    }

    func test_연결이_끊겨도_기기에서는_로그아웃된다() async {
        let (repository, _, store) = make { _ in throw URLError(.notConnectedToInternet) }
        await repository.logout()
        XCTAssertNil(store.load())
    }

    func test_탈퇴는_서버가_성공해야_토큰을_지운다() async throws {
        let (repository, transport, store) = make { _ in (200, "{}") }
        try await repository.deleteAccount()
        XCTAssertEqual(transport.requests.first?.url?.path, "/api/users/me")
        XCTAssertEqual(transport.requests.first?.httpMethod, "DELETE")
        XCTAssertNil(store.load())
    }

    func test_탈퇴가_실패하면_토큰을_유지한다() async {
        let (repository, _, store) = make { _ in (500, "{}") }
        do {
            try await repository.deleteAccount()
            XCTFail("에러가 나야 한다")
        } catch {
            XCTAssertNotNil(store.load(), "탈퇴가 안 됐으니 로그인 상태를 유지한다")
        }
    }
}

final class LegalLinksConfigTests: XCTestCase {
    func test_약관과_개인정보_주소가_빌드_설정에서_주입된다() {
        XCTAssertEqual(AppConfig.termsURL.scheme, "https")
        XCTAssertEqual(AppConfig.privacyPolicyURL.scheme, "https")
        XCTAssertNotEqual(AppConfig.termsURL, AppConfig.privacyPolicyURL)
    }
}
