import SwiftUI

/// 온보딩 흐름: 닉네임 → 캐릭터 → 권한 안내
struct OnboardingView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            switch viewModel.step {
            case .nickname:
                NicknameView(viewModel: viewModel.nickname) { _ in viewModel.nicknameConfirmed() }
            case .character:
                if let character = viewModel.character {
                    CharacterSelectView(viewModel: character)
                }
            case .permission:
                PermissionGuideView(viewModel: viewModel.permission)
            }
        }
        .background(Color.white)
        .animation(.easeOut(duration: 0.2), value: viewModel.step)
    }

    private var header: some View {
        ZStack {
            OnboardingProgress(step: viewModel.step.rawValue)
            HStack {
                Button {
                    viewModel.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ink900)
                        .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                }
                .accessibilityLabel("뒤로")
                // 첫 단계에서는 자리만 차지하고 보이지 않는다.
                .opacity(viewModel.canGoBack ? 1 : 0)
                .disabled(!viewModel.canGoBack)
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.s8)
        .padding(.top, Spacing.s8)
    }
}

#Preview("닉네임") {
    OnboardingView(
        viewModel: OnboardingViewModel(
            repository: MockUserRepository(), location: CoreLocationPermissionRequester(),
            notification: UserNotificationPermissionRequester(), onFinished: {}))
}
