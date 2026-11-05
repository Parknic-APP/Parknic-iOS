import Foundation

/// 온보딩에서 정한 내 캐릭터·닉네임을 기기에 보관한다(배지 획득·랭킹 화면의 "나" 표시용).
/// 서버가 기준이며, `/api/users/me` 연동 후에는 서버 값으로 갱신한다.
protocol ProfileStore: Sendable {
    var characterID: Int? { get }
    var nickname: String? { get }
    func save(nickname: String, characterID: Int)
    func clear()
}

struct UserDefaultsProfileStore: ProfileStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let characterKey = "profile.characterID"
    private let nicknameKey = "profile.nickname"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var characterID: Int? { defaults.object(forKey: characterKey) as? Int }
    var nickname: String? { defaults.string(forKey: nicknameKey) }

    func save(nickname: String, characterID: Int) {
        defaults.set(nickname, forKey: nicknameKey)
        defaults.set(characterID, forKey: characterKey)
    }

    func clear() {
        defaults.removeObject(forKey: characterKey)
        defaults.removeObject(forKey: nicknameKey)
    }
}
