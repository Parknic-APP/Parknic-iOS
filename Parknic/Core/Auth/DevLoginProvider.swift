#if DEBUG
import Foundation

/// 개발 전용: Apple 로그인 창 없이 서버의 개발용 토큰으로 로그인한다. Release 빌드에는 포함되지 않는다.
/// Apple 로그인을 쓸 수 없는 개발자(무료 Personal Team)만 쓴다. 비밀키(`DevLoginSecret`)가 없으면 앱은 이 방식을 쓰지 않고 실제 Apple 로그인을 쓴다.
/// - 로컬 서버(`parknic.dev-login=true`)는 `dev:<이름>`을 받는다.
/// - 배포 서버는 `DEV_LOGIN_SECRET`을 아는 요청만 받는다. 키는 `Config/Local.xcconfig`(Git 제외)에서 Info.plist `DevLoginSecret`로 들어오고, 있으면 `dev:<키>:<이름>`을 보낸다.
/// 계정 이름은 `Config/Local.xcconfig`의 `DEV_LOGIN_NAME`(Info.plist `DevLoginName`)으로 정한다. 비어 있으면 시뮬레이터는 `simulator`, 실기기는 `phone`이다.
/// 여러 사람이 같은 서버를 시험할 때는 사람마다 다른 이름을 써야 서로 다른 계정이 된다.
struct DevLoginProvider: SocialLoginProvider {
    let provider: AuthProvider = .apple
    var name = Self.configuredName ?? Self.defaultName

    #if targetEnvironment(simulator)
    private static let defaultName = "simulator"
    #else
    private static let defaultName = "phone"
    #endif

    /// 영문·숫자·`-`·`_`만 허용한다(서버 계정 식별자에 그대로 쓰인다).
    private static var configuredName: String? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "DevLoginName") as? String, !text.isEmpty,
              text.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { return nil }
        return text
    }

    func authenticate() async throws -> SocialCredential {
        let secret = AppConfig.devLoginSecret
        let token = secret.isEmpty ? "dev:\(name)" : "dev:\(secret):\(name)"
        return SocialCredential(token: token, authorizationCode: nil)
    }
}
#endif
