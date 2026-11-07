import Foundation

/// 빌드 설정(Debug / Release)에서 주입된 값. 값은 `project.yml`의 `API_BASE_URL`이다.
enum AppConfig {
    /// 설정이 없거나 잘못되면 어떤 요청도 성공하지 못하는 주소를 돌려준다(`AppConfigTests`가 주입을 검사).
    static var apiBaseURL: URL {
        #if DEBUG
        // 개발용: 스킴 환경변수 PARKNIC_API_BASE_URL로 서버 주소를 덮어쓴다(실기기에서 맥의 로컬 서버에 붙을 때). Release에는 없다.
        if let text = ProcessInfo.processInfo.environment["PARKNIC_API_BASE_URL"], let url = URL(string: text) {
            return url
        }
        #endif
        if let text = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String, let url = URL(string: text) {
            return url
        }
        return URL(filePath: "/")
    }

    #if DEBUG
    /// 개발용: Debug에서 Mock 대신 서버를 쓸지. 스킴 환경변수 PARKNIC_USE_REMOTE_API(1/0)가 우선하고, 없으면 빌드 설정(DEV_USE_REMOTE_API)을 따른다.
    /// 환경변수는 Xcode가 앱을 띄울 때만 있으므로, 홈 화면에서 직접 켜도 같은 동작이 되게 빌드 설정에도 둔다.
    static var devUseRemoteAPI: Bool {
        if let value = ProcessInfo.processInfo.environment["PARKNIC_USE_REMOTE_API"] { return value == "1" }
        return (Bundle.main.object(forInfoDictionaryKey: "DevUseRemoteAPI") as? String) == "YES"
    }

    /// 개발용 로그인 비밀키(`Config/Local.xcconfig`). 비어 있으면 실제 Apple 로그인을 쓴다.
    static var devLoginSecret: String {
        (Bundle.main.object(forInfoDictionaryKey: "DevLoginSecret") as? String) ?? ""
    }
    #endif

    /// 시험용 빌드(TestFlight 등)에서 체크인 완료까지 걸리는 시간(초). 모든 빌드가 읽지만 평소에는 비어 있어 nil이다(20분).
    /// fastlane `quick_checkin:true`로 만든 빌드에서만 값이 들어간다. App Store 제출 빌드에는 넣지 않는다.
    static var checkInRequiredSecondsOverride: Double? {
        positiveSeconds(from: Bundle.main.object(forInfoDictionaryKey: "CheckInRequiredSecondsOverride") as? String)
    }

    /// 양수 숫자 문자열만 초로 읽는다. 비었거나 숫자가 아니거나 0 이하면 nil.
    static func positiveSeconds(from text: String?) -> Double? {
        guard let text, let seconds = Double(text.trimmingCharacters(in: .whitespaces)), seconds > 0 else { return nil }
        return seconds
    }

    #if DEBUG
    /// 개발용: 체크인 완료까지 걸리는 시간(초). 환경변수 PARKNIC_CHECKIN_REQUIRED_SECONDS가 우선하고, 없으면 빌드 설정을 따른다.
    static var devCheckInRequiredSeconds: Double? {
        let env = ProcessInfo.processInfo.environment["PARKNIC_CHECKIN_REQUIRED_SECONDS"]
        let plist = Bundle.main.object(forInfoDictionaryKey: "DevCheckInRequiredSeconds") as? String
        return positiveSeconds(from: env) ?? positiveSeconds(from: plist)
    }
    #endif

    /// 이용약관 주소(빌드 설정 `TERMS_URL`). 심사 제출 전에 실제 주소로 바꿔야 한다.
    static var termsURL: URL { url(forKey: "TermsURL") }
    /// 개인정보 처리방침 주소(빌드 설정 `PRIVACY_POLICY_URL`). 심사 제출 전에 실제 주소로 바꿔야 한다.
    static var privacyPolicyURL: URL { url(forKey: "PrivacyPolicyURL") }

    private static func url(forKey key: String) -> URL {
        if let text = Bundle.main.object(forInfoDictionaryKey: key) as? String, let url = URL(string: text) { return url }
        return URL(filePath: "/")
    }
}
