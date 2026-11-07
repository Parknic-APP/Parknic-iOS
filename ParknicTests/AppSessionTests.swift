import XCTest
@testable import Parknic

@MainActor
final class AppSessionTests: XCTestCase {
    func test_토큰이_없으면_로그인_화면에서_시작한다() {
        XCTAssertEqual(AppSession(tokenStore: MemoryTokenStore(nil)).phase, .loggedOut)
    }

    func test_토큰이_있으면_바로_지도로_가지_않고_입장_화면에서_시작한다() {
        let store = MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r"))
        XCTAssertEqual(AppSession(tokenStore: store).phase, .welcome)
    }

    func test_입장_화면의_산책하러_가기를_누르면_메인으로_간다() {
        let store = MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r"))
        let session = AppSession(tokenStore: store)
        session.enterApp()
        XCTAssertEqual(session.phase, .main)
    }

    func test_산책하러_가기를_여러_번_눌러도_같다() {
        let store = MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r"))
        let session = AppSession(tokenStore: store)
        session.enterApp()
        session.enterApp()
        XCTAssertEqual(session.phase, .main)
    }

    func test_로그인_전에는_산책하러_가기가_아무것도_하지_않는다() {
        let session = AppSession(tokenStore: MemoryTokenStore(nil))
        session.enterApp()
        XCTAssertEqual(session.phase, .loggedOut)
    }

    func test_온보딩_중에는_입장_버튼이_온보딩을_건너뛰지_못한다() {
        let session = AppSession(tokenStore: MemoryTokenStore(nil))
        session.didLogin(LoginResult(isNewUser: true))
        session.enterApp()
        XCTAssertEqual(session.phase, .onboarding)
    }

    func test_입장_화면에서_토큰이_만료돼_로그아웃되면_로그인_화면으로_간다() {
        let store = MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r"))
        let session = AppSession(tokenStore: store)
        session.didLogout()
        XCTAssertEqual(session.phase, .loggedOut)
        session.enterApp()
        XCTAssertEqual(session.phase, .loggedOut, "로그아웃 뒤에는 입장 버튼이 통하지 않는다")
    }

    func test_신규_회원은_온보딩으로_간다() {
        let session = AppSession(tokenStore: MemoryTokenStore(nil))
        session.didLogin(LoginResult(isNewUser: true))
        XCTAssertEqual(session.phase, .onboarding)
        session.didFinishOnboarding()
        XCTAssertEqual(session.phase, .main)
    }

    func test_기존_회원은_바로_메인으로_간다() {
        let session = AppSession(tokenStore: MemoryTokenStore(nil))
        session.didLogin(LoginResult(isNewUser: false))
        XCTAssertEqual(session.phase, .main)
    }

    func test_세션이_끝나면_로그인_화면으로_돌아간다() {
        let store = MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r"))
        let session = AppSession(tokenStore: store)
        session.didLogout()
        XCTAssertEqual(session.phase, .loggedOut)
    }
}
