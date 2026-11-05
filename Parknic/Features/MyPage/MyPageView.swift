import SwiftUI

/// 12i·09c — 마이페이지. 심사 필수 항목(로그아웃, 앱 안 회원 탈퇴, 약관·개인정보 링크)을 포함한다.
struct MyPageView: View {
    @Bindable var viewModel: MyPageViewModel
    @Environment(\.openURL) private var openURL

    @State private var confirmsLogout = false
    @State private var withdrawStep: WithdrawStep?

    private enum WithdrawStep: Identifiable {
        case explain, final
        var id: Int { self == .explain ? 1 : 2 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s20) {
                Text("마이페이지").pkTextStyle(.display).foregroundStyle(Color.ink900)
                profileCard
                Text("설정").pkTextStyle(.title2).foregroundStyle(Color.ink900)
                settingsCard
                accountCard
                if viewModel.blocksAccountActions {
                    Label("체크인 중에는 로그아웃하거나 탈퇴할 수 없어요", systemImage: "info.circle")
                        .pkTextStyle(.callout).foregroundStyle(Color.ink500)
                }
                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.circle.fill")
                        .pkTextStyle(.callout).foregroundStyle(Color.danger600)
                }
                Text(viewModel.appVersion)
                    .pkTextStyle(.callout).foregroundStyle(Color.ink500).frame(maxWidth: .infinity)
            }
            .padding(Spacing.s16)
        }
        .background(Color.canvas.ignoresSafeArea())
        .overlay { if viewModel.isWorking { ProgressView().controlSize(.large).tint(.leaf600) } }
        .alert("로그아웃할까요?", isPresented: $confirmsLogout) {
            Button("로그아웃", role: .destructive) { Task { await viewModel.logout() } }
            Button("취소", role: .cancel) {}
        }
        .alert("회원 탈퇴", isPresented: withdrawBinding(.explain)) {
            Button("계속하기", role: .destructive) { withdrawStep = .final }
            Button("취소", role: .cancel) {}
        } message: {
            Text("탈퇴하면 배지, 랭킹 기록, 작성한 리뷰 등 모든 정보가 사라지고 되돌릴 수 없어요.")
        }
        .alert("정말 탈퇴할까요?", isPresented: withdrawBinding(.final)) {
            Button("탈퇴하기", role: .destructive) { Task { await viewModel.deleteAccount() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("마지막 확인이에요. 탈퇴하면 같은 계정으로 다시 가입해도 기록을 되찾을 수 없어요.")
        }
    }

    // MARK: 구성

    private var profileCard: some View {
        HStack(spacing: Spacing.s16) {
            PKIllustration(assetName: viewModel.characterAssetName, fallbackSymbol: "pawprint.fill", size: 72)
                .padding(Spacing.s4).background(Color.leaf100, in: Circle())
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(viewModel.nickname).pkTextStyle(.title1).foregroundStyle(Color.ink900)
                Text("파크닉에서 산책 중").pkTextStyle(.callout).foregroundStyle(Color.ink500)
            }
            Spacer()
        }
        .padding(Spacing.s20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r30))
        .accessibilityElement(children: .combine)
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            row("알림", detail: "설정에서 바꾸기", action: openSystemSettings)
            Divider()
            row("위치 권한", detail: "앱을 사용하는 동안", action: openSystemSettings)
            Divider()
            row("이용약관") { openURL(AppConfig.termsURL) }
            Divider()
            row("개인정보 처리방침") { openURL(AppConfig.privacyPolicyURL) }
        }
        .padding(.horizontal, Spacing.s16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
    }

    private var accountCard: some View {
        VStack(spacing: 0) {
            Button { confirmsLogout = true } label: {
                Text("로그아웃").pkTextStyle(.headline).foregroundStyle(Color.ink700)
                    .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 56)
            }
            Divider()
            Button { withdrawStep = .explain } label: {
                Text("회원 탈퇴").pkTextStyle(.headline).foregroundStyle(Color.danger600)
                    .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 56)
            }
        }
        .disabled(viewModel.blocksAccountActions || viewModel.isWorking)
        .padding(.horizontal, Spacing.s16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
    }

    private func row(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).pkTextStyle(.headline).foregroundStyle(Color.ink900)
                Spacer()
                if let detail { Text(detail).pkTextStyle(.callout).foregroundStyle(Color.ink500) }
                Image(systemName: "chevron.right").foregroundStyle(Color.ink300)
            }
            .frame(minHeight: 56)
        }
    }

    private func withdrawBinding(_ step: WithdrawStep) -> Binding<Bool> {
        Binding(get: { withdrawStep?.id == step.id }, set: { if !$0, withdrawStep?.id == step.id { withdrawStep = nil } })
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

// MARK: - Preview

private struct PreviewAuth: AuthRepository {
    func login(provider: AuthProvider, socialToken: String) async throws -> LoginResult { LoginResult(isNewUser: false) }
    func logout() async {}
    func deleteAccount() async throws {}
}

@MainActor
private func previewModel(checkInActive: Bool = false) -> MyPageViewModel {
    MyPageViewModel(auth: PreviewAuth(), profile: UserDefaultsProfileStore(), isCheckInActive: { checkInActive }, onSignedOut: {})
}

#Preview("기본") { MyPageView(viewModel: previewModel()) }
#Preview("체크인 중") { MyPageView(viewModel: previewModel(checkInActive: true)) }
