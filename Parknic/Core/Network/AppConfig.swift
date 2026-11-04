import Foundation

/// 빌드 설정(Debug / Release)에서 주입된 값. 값은 `project.yml`의 `API_BASE_URL`이다.
enum AppConfig {
    static var apiBaseURL: URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String else { return nil }
        return URL(string: text)
    }
}
