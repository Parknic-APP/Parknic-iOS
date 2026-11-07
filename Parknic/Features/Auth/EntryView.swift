import SwiftUI

/// 12e — 입장 화면. 로그인하지 않은 회원에게는 로그인 버튼을, 이미 로그인한 회원에게는 「산책하러 가기」를 보여준다.
/// 일러스트의 캐릭터는 따로 그려서 살짝살짝 흔들리고, 누르면 폴짝 뛴다.
struct EntryView: View {
    let viewModel: LoginViewModel
    let isLoggedIn: Bool
    let onStart: () -> Void

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
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: Spacing.s8) {
                Text("파크닉").pkTextStyle(.timer).foregroundStyle(Color.leaf600)
                Text("공원에서 20분, 배지 하나").pkTextStyle(.headline).foregroundStyle(Color.ink700)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            EntryScene()
        }
        .frame(maxWidth: .infinity)
    }

    private var sheet: some View {
        VStack(spacing: Spacing.s12) {
            if isLoggedIn {
                Button(action: onStart) {
                    Label("산책하러 가기", systemImage: "figure.walk")
                }
                .buttonStyle(.pk(.primary))
                .accessibilityHint("지도로 이동해요")
            } else {
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
                terms.padding(.top, Spacing.s8)
            }
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.top, Spacing.s28)
        .padding(.bottom, Spacing.s16)
        .frame(maxWidth: .infinity)
        .background(
            Color.white.clipShape(UnevenRoundedRectangle(topLeadingRadius: Radius.r30, topTrailingRadius: Radius.r30))
                .ignoresSafeArea(edges: .bottom))
    }

    private var terms: some View {
        Text("계속하면 [이용약관](\(AppConfig.termsURL.absoluteString))과 [개인정보 처리방침](\(AppConfig.privacyPolicyURL.absoluteString))에 동의하게 돼요")
            .pkTextStyle(.callout)
            .foregroundStyle(Color.ink500)
            .tint(Color.ink500)
            .multilineTextAlignment(.center)
    }
}

/// 하늘·해·구름·언덕 위에 캐릭터 네 마리가 서 있는 장면. 캐릭터는 뒷언덕과 앞언덕 사이에 끼워 앞언덕 뒤로 몸이 살짝 가려진다.
/// 배치 값은 `tools/generate_art.py`의 `LOGIN_CHARACTERS`와 같다(캐릭터 100×100 좌표계의 왼쪽 위 x, y와 크기).
struct EntryScene: View {
    struct Placement: Identifiable {
        let assetName: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let angle: Double
        let period: Double
        let phase: Double
        var id: String { assetName }
    }

    static let characters: [Placement] = [
        Placement(assetName: "character-6", x: 40, y: 168, size: 70, angle: 3.5, period: 2.6, phase: 0.6),
        Placement(assetName: "character-1", x: 132, y: 146, size: 130, angle: 2.2, period: 2.2, phase: 0),
        Placement(assetName: "character-3", x: 292, y: 178, size: 62, angle: 4, period: 2.0, phase: 2.1),
        Placement(assetName: "character-8", x: 350, y: 236, size: 34, angle: 5, period: 1.7, phase: 4),
    ]

    private static let designWidth: CGFloat = 393
    private static let designHeight: CGFloat = 330

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / Self.designWidth
            ZStack(alignment: .topLeading) {
                Image("login-back").resizable().scaledToFit()
                ForEach(Self.characters) { placement in
                    character(placement, scale: scale)
                }
                Image("login-front").resizable().scaledToFit()
            }
        }
        .aspectRatio(Self.designWidth / Self.designHeight, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    /// 캐릭터 에셋은 124×116 안에서 머리 그림(100×100 좌표계)이 (12, 12)에서 시작한다.
    private func character(_ p: Placement, scale: CGFloat) -> some View {
        let k = p.size / 100 * scale
        return TapHopCharacter(assetName: p.assetName, angle: p.angle, period: p.period, phase: p.phase)
            .frame(width: 124 * k, height: 116 * k)
            .position(x: (p.x * scale) - 12 * k + 62 * k, y: (p.y * scale) - 12 * k + 58 * k)
    }
}

/// 흔들리는 캐릭터. 누르면 폴짝 뛴다.
private struct TapHopCharacter: View {
    let assetName: String
    let angle: Double
    let period: Double
    let phase: Double

    @State private var hop: CGFloat = 0

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .pkWiggle(angle: angle, period: period, phase: phase)
            .offset(y: hop)
            .onTapGesture {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { hop = -16 }
                Task {
                    try? await Task.sleep(for: .milliseconds(160))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { hop = 0 }
                }
            }
    }
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
        }
        .buttonStyle(PKBrandButtonStyle(palette: palette))
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

    /// 브랜드 색 위에 올라가는 글자·두께 색
    private var palette: PKButtonPalette {
        switch provider {
        case .apple: PKButtonPalette(foreground: .white, background: .brandApple, depth: .ink700)
        case .kakao: PKButtonPalette(foreground: .ink900, background: .brandKakao, depth: Color.ink900.opacity(0.35))
        case .google: PKButtonPalette(foreground: .ink900, background: .white, depth: .ink300, border: .ink100)
        }
    }
}

// MARK: - Preview

private struct PreviewProvider_: SocialLoginProvider {
    let provider: AuthProvider
    func authenticate() async throws -> SocialCredential { SocialCredential(token: "token") }
}

@MainActor
private func previewModel(state: LoginViewModel.State) -> LoginViewModel {
    LoginViewModel(
        providers: [PreviewProvider_(provider: .apple), PreviewProvider_(provider: .kakao)],
        repository: MockAuthRepository(result: .failure(.network), delay: .zero),
        initialState: state, onLoggedIn: { _ in })
}

#Preview("로그인 전") {
    EntryView(viewModel: previewModel(state: .idle), isLoggedIn: false, onStart: {})
}

#Preview("로그인 중") {
    EntryView(viewModel: previewModel(state: .loading(.apple)), isLoggedIn: false, onStart: {})
}

#Preview("에러") {
    EntryView(viewModel: previewModel(state: .failed(APIError.network.userMessage)), isLoggedIn: false, onStart: {})
}

#Preview("로그인 후(산책하러 가기)") {
    EntryView(viewModel: previewModel(state: .idle), isLoggedIn: true, onStart: {})
}
