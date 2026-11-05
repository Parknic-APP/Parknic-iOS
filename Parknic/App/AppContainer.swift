import Foundation
import UserNotifications

/// 의존성 조립. 서버가 준비되기 전(Debug)에는 Mock Repository를 쓴다.
@MainActor
final class AppContainer {
    let session: AppSession
    let loginViewModel: LoginViewModel
    private(set) var onboardingViewModel: OnboardingViewModel
    let myPageViewModel: MyPageViewModel
    let collectionViewModel: CollectionViewModel
    private let makeOnboarding: () -> OnboardingViewModel
    let checkInCoordinator: CheckInCoordinator
    let mapViewModel: MapHomeViewModel
    let connectivity = ConnectivityMonitor(source: NWPathConnectivitySource())
    let profileStore: ProfileStore = UserDefaultsProfileStore()
    private let notificationPresenter = ForegroundNotificationPresenter()

    init() {
        let tokenStore = KeychainTokenStore()
        let session = AppSession(tokenStore: tokenStore)
        self.session = session

        let client = APIClient(
            baseURL: AppConfig.apiBaseURL, tokenStore: tokenStore,
            onSessionExpired: { Task { @MainActor in session.didLogout() } })

        #if DEBUG
        let authRepository: AuthRepository = MockAuthRepository()
        let userRepository: UserRepository = MockUserRepository()
        let checkInRepository: CheckInRepository = MockCheckInRepository()
        let parkRepository: ParkRepository = MockParkRepository()
        let rankingRepository: RankingRepository = MockRankingRepository()
        let reviewRepository: ReviewRepository = MockReviewRepository()
        let collectionRepository: CollectionRepository = MockCollectionRepository()
        let myPageRepository: MyPageRepository = MockMyPageRepository()
        #else
        let authRepository: AuthRepository = RemoteAuthRepository(client: client, tokenStore: tokenStore)
        let userRepository: UserRepository = RemoteUserRepository(client: client)
        let checkInRepository: CheckInRepository = RemoteCheckInRepository(client: client)
        let parkRepository: ParkRepository = RemoteParkRepository(client: client)
        let rankingRepository: RankingRepository = RemoteRankingRepository(client: client)
        let reviewRepository: ReviewRepository = RemoteReviewRepository(client: client)
        let collectionRepository: CollectionRepository = RemoteCollectionRepository(client: client)
        let myPageRepository: MyPageRepository = RemoteMyPageRepository(client: client)
        #endif

        loginViewModel = LoginViewModel(providers: [AppleLoginProvider()], repository: authRepository) { result in
            session.didLogin(result)
        }
        let profileStore = self.profileStore
        let makeOnboarding: () -> OnboardingViewModel = {
            OnboardingViewModel(
                repository: userRepository, location: CoreLocationPermissionRequester(),
                notification: UserNotificationPermissionRequester(), profileStore: profileStore
            ) { session.didFinishOnboarding() }
        }
        self.makeOnboarding = makeOnboarding
        onboardingViewModel = makeOnboarding()

        let coordinator = CheckInCoordinator(
            repository: checkInRepository, location: CoreLocationSampleSource(),
            notifier: LocalCheckInNotifier(), store: UserDefaultsCheckInStore())
        checkInCoordinator = coordinator
        mapViewModel = MapHomeViewModel(
            location: CoreLocationProvider(), nearby: NearbyParksViewModel(repository: parkRepository),
            checkIn: coordinator, parks: parkRepository, rankings: rankingRepository, reviews: reviewRepository, profile: profileStore)
        myPageViewModel = MyPageViewModel(
            auth: authRepository, profile: profileStore, repository: myPageRepository, userRepository: userRepository,
            isCheckInActive: { coordinator.state.isActive },
            onSignedOut: { session.didLogout() })
        collectionViewModel = CollectionViewModel(repository: collectionRepository)
        UNUserNotificationCenter.current().delegate = notificationPresenter

        // 로그아웃·탈퇴·세션 만료 뒤 다시 가입하면 이전 온보딩 입력이 남지 않게 새로 만든다.
        session.onSignedOut = { [weak self] in
            self?.profileStore.clear()
            self?.onboardingViewModel = makeOnboarding()
        }
    }
}
