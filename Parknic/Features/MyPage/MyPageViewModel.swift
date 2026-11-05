import Foundation
import Observation

/// 마이페이지(12i·09c). 1차는 프로필과 설정(알림·위치 권한·약관·로그아웃·회원 탈퇴)만 둔다.
@MainActor @Observable
final class MyPageViewModel {
    private(set) var isWorking = false
    /// 탈퇴에 실패했을 때의 안내 문구
    var errorMessage: String?

    private let auth: AuthRepository
    private let profile: ProfileStore
    private let isCheckInActive: () -> Bool
    private let onSignedOut: () -> Void

    init(
        auth: AuthRepository, profile: ProfileStore, isCheckInActive: @escaping () -> Bool,
        onSignedOut: @escaping () -> Void
    ) {
        self.auth = auth
        self.profile = profile
        self.isCheckInActive = isCheckInActive
        self.onSignedOut = onSignedOut
    }

    var nickname: String { profile.nickname ?? String(localized: "산책러") }
    var characterAssetName: String? { profile.characterID.map { "character-\($0)" } }

    /// 체크인 중에는 로그아웃·탈퇴로 측정이 끊기지 않게 막는다.
    var blocksAccountActions: Bool { isCheckInActive() }

    var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        return String(localized: "파크닉 \(version)")
    }

    func logout() async {
        guard !isWorking, !blocksAccountActions else { return }
        isWorking = true
        await auth.logout()
        finishSignOut()
    }

    func deleteAccount() async {
        guard !isWorking, !blocksAccountActions else { return }
        isWorking = true
        errorMessage = nil
        do {
            try await auth.deleteAccount()
            finishSignOut()
        } catch {
            isWorking = false
            errorMessage = (error as? APIError)?.userMessage ?? APIError.network.userMessage
        }
    }

    private func finishSignOut() {
        profile.clear()
        isWorking = false
        onSignedOut()
    }
}
