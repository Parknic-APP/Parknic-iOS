import Foundation

/// 빌드 설정(Debug / Release)에서 주입된 값. 값은 `project.yml`의 `API_BASE_URL`이다.
enum AppConfig {
    /// 설정이 없거나 잘못되면 어떤 요청도 성공하지 못하는 주소를 돌려준다(`AppConfigTests`가 주입을 검사).
    static var apiBaseURL: URL {
        if let text = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String, let url = URL(string: text) {
            return url
        }
        return URL(filePath: "/")
    }

    /// 이용약관 주소(빌드 설정 `TERMS_URL`). 심사 제출 전에 실제 주소로 바꿔야 한다.
    static var termsURL: URL { url(forKey: "TermsURL") }
    /// 개인정보 처리방침 주소(빌드 설정 `PRIVACY_POLICY_URL`). 심사 제출 전에 실제 주소로 바꿔야 한다.
    static var privacyPolicyURL: URL { url(forKey: "PrivacyPolicyURL") }

    private static func url(forKey key: String) -> URL {
        if let text = Bundle.main.object(forInfoDictionaryKey: key) as? String, let url = URL(string: text) { return url }
        return URL(filePath: "/")
    }
}
