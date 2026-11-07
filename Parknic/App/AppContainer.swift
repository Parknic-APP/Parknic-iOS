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

        // Debug는 빌드 설정(DEV_USE_REMOTE_API)에 따라 Mock 또는 로컬 서버를 쓴다.
        #if DEBUG
        let useRemote = AppConfig.devUseRemoteAPI
        #else
        let useRemote = true
        #endif
        let authRepository: AuthRepository =
            useRemote ? RemoteAuthRepository(client: client, tokenStore: tokenStore) : MockAuthRepository()
        let userRepository: UserRepository = useRemote ? RemoteUserRepository(client: client) : MockUserRepository()
        let checkInRepository: CheckInRepository =
            useRemote ? RemoteCheckInRepository(client: client) : MockCheckInRepository()
        let parkRepository: ParkRepository = useRemote ? RemoteParkRepository(client: client) : MockParkRepository()
        let rankingRepository: RankingRepository =
            useRemote ? RemoteRankingRepository(client: client) : MockRankingRepository()
        let reviewRepository: ReviewRepository =
            useRemote ? RemoteReviewRepository(client: client) : MockReviewRepository()
        let collectionRepository: CollectionRepository =
            useRemote ? RemoteCollectionRepository(client: client) : MockCollectionRepository()
        let myPageRepository: MyPageRepository =
            useRemote ? RemoteMyPageRepository(client: client) : MockMyPageRepository()

        // Debug + 서버 모드에서 개발용 비밀키(Config/Local.xcconfig)가 있을 때만 개발용 로그인을 쓴다(Apple 로그인을 못 쓰는 무료 팀용).
        // 비밀키가 없으면 실제 Apple 로그인으로 서버에 연결한다.
        #if DEBUG
        let loginProviders: [SocialLoginProvider] =
            useRemote && !AppConfig.devLoginSecret.isEmpty ? [DevLoginProvider()] : [AppleLoginProvider()]
        #else
        let loginProviders: [SocialLoginProvider] = [AppleLoginProvider()]
        #endif
        loginViewModel = LoginViewModel(providers: loginProviders, repository: authRepository) { result in
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
            checkIn: coordinator, parks: parkRepository, rankings: rankingRepository, reviews: reviewRepository, profile: profileStore,
            neighborhood: GeocoderNeighborhoodNamer(), myPage: myPageRepository)
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
            self?.mapViewModel.accountDidChange(isSignedIn: false)
        }
        session.onSignedIn = { [weak self] in self?.mapViewModel.accountDidChange(isSignedIn: true) }
    }
}
