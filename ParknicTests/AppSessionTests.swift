import XCTest
@testable import Parknic

@MainActor
final class AppSessionTests: XCTestCase {
    func test_토큰이_없으면_로그인_화면에서_시작한다() {
        XCTAssertEqual(AppSession(tokenStore: MemoryTokenStore(nil)).phase, .loggedOut)
    }

    func test_토큰이_있으면_자동_로그인된다() {
        let store = MemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r"))
        XCTAssertEqual(AppSession(tokenStore: store).phase, .main)
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
