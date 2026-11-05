import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        switch container.session.phase {
        case .loggedOut:
            LoginView(viewModel: container.loginViewModel)
        case .onboarding:
            OnboardingView(viewModel: container.onboardingViewModel)
        case .main:
            RootTabView(mapViewModel: container.mapViewModel)
                // 앱을 다시 켰을 때 끊긴 체크인을 정리한다.
                .task { await container.checkInCoordinator.recoverOnLaunch() }
        }
    }
}
