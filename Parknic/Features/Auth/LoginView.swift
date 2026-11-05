import SwiftUI

/// 12e — 로그인. 일러스트는 에셋(`login-hero`)으로 교체한다.
struct LoginView: View {
    let viewModel: LoginViewModel

    var body: some View {
        VStack(spacing: 0) {
            hero
            sheet
        }
        .background(Color.leaf50.ignoresSafeArea())
        .overlay {
            if viewModel.isLoading {
                Color.ink900.opacity(0.12).ignoresSafeArea()
                ProgressView().tint(.leaf600).controlSize(.large)
            }
        }
        .animation(.easeOut(duration: 0.15), value: viewModel.isLoading)
    }

    private var hero: some View {
        VStack(spacing: Spacing.s8) {
            Spacer()
            PKIllustration(assetName: "login-hero", fallbackSymbol: "leaf.fill")
            Text("파크닉").pkTextStyle(.timer).foregroundStyle(Color.leaf600)
            Text("공원에서 20분, 배지 하나").pkTextStyle(.headline).foregroundStyle(Color.ink700)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var sheet: some View {
        VStack(spacing: Spacing.s12) {
            if case .failed(let message) = viewModel.state {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .pkTextStyle(.callout)
                    .foregroundStyle(Color.danger600)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isStaticText)
            }
            ForEach(viewModel.availableProviders, id: \.self) { provider in
                SocialLoginButton(provider: provider) {
                    Task { await viewModel.login(with: provider) }
                }
                .disabled(viewModel.isLoading)
            }
            #if DEBUG
            developmentLogin
            #endif
            terms.padding(.top, Spacing.s8)
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.top, Spacing.s28)
        .padding(.bottom, Spacing.s16)
        .background(
            Color.white.clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.r30, topTrailingRadius: Radius.r30))
                .ignoresSafeArea(edges: .bottom))
    }

    #if DEBUG
    /// 개발용 로그인(Debug 빌드에서만 보인다). Apple 로그인 없이 시뮬레이터에서 앱 흐름을 확인한다.
    private var developmentLogin: some View {
        VStack(spacing: Spacing.s8) {
            Text("개발용 (Debug 빌드에서만 보여요)").pkTextStyle(.caption).foregroundStyle(Color.ink500)
            HStack(spacing: Spacing.s8) {
                Button("신규 회원\n(온보딩부터)") { viewModel.loginForDevelopment(isNewUser: true) }
                Button("기존 회원\n(바로 메인)") { viewModel.loginForDevelopment(isNewUser: false) }
            }
            .buttonStyle(.pk(.tonal, size: .large))
            .multilineTextAlignment(.center)
            .disabled(viewModel.isLoading)
        }
        .padding(.top, Spacing.s8)
    }
    #endif

    private var terms: some View {
        Text("계속하면 [이용약관](\(LegalLinks.terms.absoluteString))과 [개인정보 처리방침](\(LegalLinks.privacy.absoluteString))에 동의하게 돼요")
            .pkTextStyle(.callout)
            .foregroundStyle(Color.ink500)
            .tint(Color.ink500)
            .multilineTextAlignment(.center)
    }
}

/// 약관·개인정보처리방침 주소. 실제 주소가 정해지면 교체한다.
enum LegalLinks {
    static let terms = URL(string: "https://parknic.example/terms") ?? URL(filePath: "/")
    static let privacy = URL(string: "https://parknic.example/privacy") ?? URL(filePath: "/")
}

private struct SocialLoginButton: View {
    let provider: AuthProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s8) {
                Image(systemName: symbol)
                Text(title)
            }
            .pkTextStyle(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(background, in: RoundedRectangle(cornerRadius: Radius.r20))
            .overlay {
                if provider == .google {
                    RoundedRectangle(cornerRadius: Radius.r20).stroke(Color.ink100, lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var title: LocalizedStringKey {
        switch provider {
        case .apple: "Apple로 계속하기"
        case .kakao: "카카오로 계속하기"
        case .google: "Google로 계속하기"
        }
    }

    private var symbol: String {
        switch provider {
        case .apple: "apple.logo"
        case .kakao: "bubble.fill"
        case .google: "globe"
        }
    }

    private var foreground: Color {
        switch provider {
        case .apple: .white
        case .kakao: .ink900
        case .google: .ink900
        }
    }

    private var background: Color {
        switch provider {
        case .apple: .brandApple
        case .kakao: .brandKakao
        case .google: .white
        }
    }
}

// MARK: - Preview

private struct PreviewProvider_: SocialLoginProvider {
    let provider: AuthProvider
    func authenticate() async throws -> String { "token" }
}

@MainActor
private func previewModel(state: LoginViewModel.State) -> LoginViewModel {
    LoginViewModel(
        providers: [PreviewProvider_(provider: .apple), PreviewProvider_(provider: .kakao)],
        repository: MockAuthRepository(result: .failure(.network), delay: .zero),
        initialState: state, onLoggedIn: { _ in })
}

#Preview("기본") {
    LoginView(viewModel: previewModel(state: .idle))
}

#Preview("로그인 중") {
    LoginView(viewModel: previewModel(state: .loading(.apple)))
}

#Preview("에러") {
    LoginView(viewModel: previewModel(state: .failed(APIError.network.userMessage)))
}
