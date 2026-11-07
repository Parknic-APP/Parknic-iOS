import Foundation
import Observation

/// 마이페이지(12i·09b·09c): 프로필, 통계, 내 리뷰, 설정(알림·위치 권한·약관·로그아웃·회원 탈퇴).
@MainActor @Observable
final class MyPageViewModel {
    enum SummaryState: Equatable {
        case loading
        case loaded(MyPageSummary)
        case failed(String)
    }

    private(set) var isWorking = false
    private(set) var summaryState: SummaryState
    /// nil이면 아직 확인하지 못했다.
    private(set) var notificationsEnabled: Bool?
    /// 탈퇴에 실패했을 때의 안내 문구
    var errorMessage: String?

    private let auth: AuthRepository
    private let profile: ProfileStore
    private let repository: MyPageRepository
    private let userRepository: UserRepository
    private let reviewRepository: ReviewRepository
    /// 주변 공원 조회 반경 설정(지도와 같은 값을 본다)
    let searchRadius: SearchRadiusSetting
    private let onSearchRadiusChanged: () -> Void
    private let notificationStatus: NotificationStatusReading
    let clock: AppClock
    private let isCheckInActive: () -> Bool
    private let onSignedOut: () -> Void

    init(
        auth: AuthRepository, profile: ProfileStore, repository: MyPageRepository, userRepository: UserRepository,
        reviewRepository: ReviewRepository = MockReviewRepository(delay: .zero),
        searchRadius: SearchRadiusSetting? = nil, onSearchRadiusChanged: @escaping () -> Void = {},
        notificationStatus: NotificationStatusReading = UserNotificationStatusReader(),
        clock: AppClock = SystemClock(), initialState: SummaryState = .loading,
        isCheckInActive: @escaping () -> Bool, onSignedOut: @escaping () -> Void
    ) {
        self.auth = auth
        self.profile = profile
        self.repository = repository
        self.userRepository = userRepository
        self.reviewRepository = reviewRepository
        self.searchRadius = searchRadius ?? SearchRadiusSetting()
        self.onSearchRadiusChanged = onSearchRadiusChanged
        self.notificationStatus = notificationStatus
        self.clock = clock
        self.summaryState = initialState
        self.isCheckInActive = isCheckInActive
        self.onSignedOut = onSignedOut
    }

    var summary: MyPageSummary? {
        if case .loaded(let summary) = summaryState { return summary }
        return nil
    }

    /// 서버에서 받은 값이 있으면 그것을, 없으면 기기에 저장된 값을 쓴다.
    var nickname: String { summary?.profile.nickname ?? profile.nickname ?? String(localized: "산책러") }
    var characterAssetName: String? {
        (summary?.profile.characterID ?? profile.characterID).map { "character-\($0)" }
    }

    /// "치즈냥 · 2026년 9월부터 산책 중"(프로필을 못 받았으면 "파크닉에서 산책 중")
    var subtitle: String {
        guard let profile = summary?.profile else { return String(localized: "파크닉에서 산책 중") }
        let parts = Calendar.kst.dateComponents([.year, .month], from: profile.joinedAt)
        guard let year = parts.year, let month = parts.month else { return profile.characterName }
        return String(localized: "\(profile.characterName) · \(String(year))년 \(month)월부터 산책 중")
    }

    /// 마이페이지에 보여줄 최근 리뷰(최대 3개)
    var recentReviews: [MyReview] { Array((summary?.recentReviews.reviews ?? []).prefix(3)) }

    /// 닉네임·캐릭터 변경 흐름. 저장되면 `onFinished`가 불린다.
    func makeProfileEditViewModel(onFinished: @escaping () -> Void) -> ProfileEditViewModel {
        ProfileEditViewModel(
            currentNickname: nickname, currentCharacterID: summary?.profile.characterID ?? profile.characterID,
            repository: userRepository, profileStore: profile, onFinished: onFinished)
    }

    /// 설정에서 주변 공원 범위를 골랐다. 저장하고 지도가 새 반경으로 공원을 다시 불러오게 한다.
    func selectSearchRadius(_ radius: SearchRadius) {
        guard radius != searchRadius.radius else { return }
        searchRadius.select(radius)
        onSearchRadiusChanged()
    }

    func makeReviewsViewModel() -> MyReviewsViewModel { MyReviewsViewModel(repository: repository, clock: clock) }

    /// 내 리뷰를 눌렀을 때 열 그 공원의 리뷰 목록
    func makeReviewListViewModel(for review: MyReview) -> ReviewListViewModel {
        ReviewListViewModel(parkID: review.parkID, parkName: review.parkName, repository: reviewRepository)
    }

    /// 공원 리뷰 목록에서 내 리뷰의 「수정」을 눌렀을 때 쓰는 수정 화면
    func makeReviewEditorViewModel(
        for review: Review, onFinished: @escaping (ReviewEditorViewModel.Result) -> Void
    ) -> ReviewEditorViewModel {
        ReviewEditorViewModel(mode: .edit(review), repository: reviewRepository, onFinished: onFinished)
    }

    func relativeTime(of review: MyReview) -> String {
        RelativeTimeFormatter.text(from: review.createdAt, now: clock.now)
    }

    /// 프로필·통계·내 리뷰를 함께 불러온다. 이미 보여주는 내용이 있으면 실패해도 그대로 둔다.
    func load() async {
        notificationsEnabled = await notificationStatus.isEnabled()
        if summary == nil { summaryState = .loading }
        do {
            async let loadedProfile = repository.profile()
            async let loadedStats = repository.stats()
            async let loadedReviews = repository.reviews(cursor: nil)
            let result = MyPageSummary(
                profile: try await loadedProfile, stats: try await loadedStats, recentReviews: try await loadedReviews)
            profile.save(nickname: result.profile.nickname, characterID: result.profile.characterID)
            summaryState = .loaded(result)
        } catch is CancellationError {
            return
        } catch {
            if summary == nil {
                summaryState = .failed((error as? APIError)?.userMessage ?? APIError.network.userMessage)
            }
        }
    }

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
