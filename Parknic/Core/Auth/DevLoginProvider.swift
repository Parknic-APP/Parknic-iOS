#if DEBUG
import Foundation

/// 개발 전용: Apple 로그인 창 없이 서버의 개발용 토큰으로 로그인한다. Release 빌드에는 포함되지 않는다.
/// - 로컬 서버(`parknic.dev-login=true`)는 `dev:<이름>`을 받는다.
/// - 배포 서버는 `DEV_LOGIN_SECRET`을 아는 요청만 받는다. 키는 `Config/Local.xcconfig`(Git 제외)에서 Info.plist `DevLoginSecret`로 들어오고, 있으면 `dev:<키>:<이름>`을 보낸다.
/// 시뮬레이터와 실기기가 서로 다른 계정을 쓰도록 이름을 나눈다.
struct DevLoginProvider: SocialLoginProvider {
    let provider: AuthProvider = .apple
    #if targetEnvironment(simulator)
    var name = "simulator"
    #else
    var name = "phone"
    #endif

    func authenticate() async throws -> SocialCredential {
        let secret = (Bundle.main.object(forInfoDictionaryKey: "DevLoginSecret") as? String) ?? ""
        let token = secret.isEmpty ? "dev:\(name)" : "dev:\(secret):\(name)"
        return SocialCredential(token: token, authorizationCode: nil)
    }
}
#endif
