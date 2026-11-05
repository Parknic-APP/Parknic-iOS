import SwiftUI

/// 07b·12f 재사용 — 닉네임 → 캐릭터 두 단계. 첫 단계는 닫기(✕), 둘째 단계는 뒤로(‹)가 왼쪽에 놓인다.
struct ProfileEditView: View {
    let viewModel: ProfileEditViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            switch viewModel.step {
            case .nickname:
                NicknameView(viewModel: viewModel.nickname) { _ in viewModel.nicknameConfirmed() }
            case .character:
                if let character = viewModel.character {
                    CharacterSelectView(viewModel: character, showsLaterHint: false)
                }
            }
        }
        .background(Color.white)
        .animation(.easeOut(duration: 0.2), value: viewModel.step)
    }

    private var header: some View {
        ZStack {
            OnboardingProgress(step: viewModel.step.rawValue, total: 2)
            HStack {
                Button {
                    if viewModel.canGoBack { viewModel.goBack() } else { onClose() }
                } label: {
                    Image(systemName: viewModel.canGoBack ? "chevron.left" : "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ink900)
                        .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                }
                .accessibilityLabel(viewModel.canGoBack ? "뒤로" : "닫기")
                Spacer()
            }
        }
        .padding(.horizontal, Spacing.s8)
        .padding(.top, Spacing.s8)
    }
}

#Preview("닉네임") {
    ProfileEditView(
        viewModel: ProfileEditViewModel(
            currentNickname: "나뭇잎", currentCharacterID: 1, repository: MockUserRepository(),
            profileStore: UserDefaultsProfileStore(), onFinished: {}),
        onClose: {})
}
