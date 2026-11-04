import SwiftUI

struct RootView: View {
    let container: AppContainer

    var body: some View {
        switch container.session.phase {
        case .loggedOut:
            LoginView(viewModel: container.loginViewModel)
        case .onboarding:
            // 닉네임·캐릭터·권한 안내는 온보딩 작업에서 구현한다.
            PKEmptyView(title: "온보딩", message: "준비 중이에요")
        case .main:
            RootTabView()
        }
    }
}
