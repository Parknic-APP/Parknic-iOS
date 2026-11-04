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
            RootTabView()
        }
    }
}
