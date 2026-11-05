import Foundation
import UserNotifications

/// 의존성 조립. 서버가 준비되기 전(Debug)에는 Mock Repository를 쓴다.
@MainActor
final class AppContainer {
    let session: AppSession
    let loginViewModel: LoginViewModel
    let onboardingViewModel: OnboardingViewModel
    let checkInCoordinator: CheckInCoordinator
    let mapViewModel: MapHomeViewModel
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
        #else
        let authRepository: AuthRepository = RemoteAuthRepository(client: client, tokenStore: tokenStore)
        let userRepository: UserRepository = RemoteUserRepository(client: client)
        let checkInRepository: CheckInRepository = RemoteCheckInRepository(client: client)
        let parkRepository: ParkRepository = RemoteParkRepository(client: client)
        #endif

        loginViewModel = LoginViewModel(providers: [AppleLoginProvider()], repository: authRepository) { result in
            session.didLogin(result)
        }
        onboardingViewModel = OnboardingViewModel(
            repository: userRepository, location: CoreLocationPermissionRequester(),
            notification: UserNotificationPermissionRequester()
        ) { session.didFinishOnboarding() }

        checkInCoordinator = CheckInCoordinator(
            repository: checkInRepository, location: CoreLocationSampleSource(),
            notifier: LocalCheckInNotifier(), store: UserDefaultsCheckInStore())
        mapViewModel = MapHomeViewModel(location: CoreLocationProvider(), nearby: NearbyParksViewModel(repository: parkRepository))
        UNUserNotificationCenter.current().delegate = notificationPresenter
    }
}
