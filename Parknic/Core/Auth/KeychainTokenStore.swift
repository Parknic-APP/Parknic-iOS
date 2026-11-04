import Foundation
import Security

/// Access / Refresh 토큰을 Keychain에 저장한다. 토큰은 로그에 출력하지 않는다.
struct KeychainTokenStore: TokenStore {
    struct KeychainError: Error, Equatable { let status: OSStatus }

    private let service: String
    private let account = "auth-tokens"

    init(service: String = "com.seongmo.parknic") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> AuthTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    func save(_ tokens: AuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            // 체크인 중 백그라운드에서도 재발급이 필요하므로 첫 잠금 해제 이후 접근을 허용한다.
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
