import SwiftUI

/// 07b·07c — 닉네임 설정
struct NicknameView: View {
    @Bindable var viewModel: NicknameViewModel
    let onNext: (String) -> Void
    @FocusState private var focused: Bool
    /// 입력칸에 보이는 글자. 뷰모델 값을 같은 갱신 안에서 되돌리면 입력칸이 다시 그려지지 않아 길이 제한이 화면에 안 먹으므로,
    /// 입력칸 자체의 값을 잘라서 화면에 반영한다.
    @State private var fieldText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s20) {
            header
            field
            feedback
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.top, Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .safeAreaInset(edge: .bottom) {
            Button("다음") {
                if let nickname = viewModel.confirmedNickname { onNext(nickname) }
            }
            .buttonStyle(.pk(.primary))
            .disabled(!viewModel.canProceed)
            .padding(.horizontal, Spacing.s16)
            .padding(.bottom, Spacing.s16)
            .background(Color.white)
        }
        .onAppear {
            focused = true
            fieldText = viewModel.text
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                Text("공원에서 불릴\n이름을 정해주세요").pkTextStyle(.title1).foregroundStyle(Color.ink900)
                Text("랭킹 시상대와 리뷰에 보여요").pkTextStyle(.body).foregroundStyle(Color.ink500)
            }
            Spacer()
            PKIllustration(assetName: "character-default", fallbackSymbol: "pawprint.fill", size: 72)
        }
    }

    private var field: some View {
        HStack(spacing: Spacing.s12) {
            HStack {
                TextField("닉네임", text: $fieldText)
                    .pkTextStyle(.headline)
                    .foregroundStyle(Color.ink900)
                    .focused($focused)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { viewModel.checkNow() }
                    .onChange(of: fieldText) { _, newValue in
                        let limited = String(newValue.prefix(NicknameViewModel.lengthRange.upperBound))
                        if limited != newValue { fieldText = limited }
                        if viewModel.text != limited { viewModel.text = limited }
                    }
                    // 추천 닉네임 선택처럼 뷰모델에서 값이 바뀐 경우를 입력칸에 반영한다.
                    .onChange(of: viewModel.text) { _, newValue in
                        if fieldText != newValue { fieldText = newValue }
                    }
                Text("\(viewModel.text.count)/\(NicknameViewModel.lengthRange.upperBound)")
                    .pkTextStyle(.callout)
                    .foregroundStyle(Color.ink500)
            }
            .padding(.horizontal, Spacing.s16)
            .frame(minHeight: 56)
            .background(Color.canvas, in: RoundedRectangle(cornerRadius: Radius.r16))
            .overlay(RoundedRectangle(cornerRadius: Radius.r16).stroke(borderColor, lineWidth: 2))

            Button("중복 확인") { viewModel.checkNow() }
                .buttonStyle(.pk(.tonal, size: .large, fillsWidth: false))
        }
    }

    private var borderColor: Color {
        switch viewModel.status {
        case .available: .leaf500
        case .duplicated, .failed: .danger600
        default: focused ? .leaf300 : .ink100
        }
    }

    @ViewBuilder
    private var feedback: some View {
        switch viewModel.status {
        case .empty:
            EmptyView()
        case .tooShort:
            message("2자 이상, 공백 없이 입력해주세요", symbol: "info.circle.fill", color: .ink500)
        case .checking:
            message("확인하고 있어요", symbol: "ellipsis.circle.fill", color: .ink500)
        case .available:
            message("사용할 수 있는 닉네임이에요", symbol: "checkmark.circle.fill", color: .leaf600)
        case .duplicated(let suggestions):
            message("이미 누가 쓰고 있어요", symbol: "exclamationmark.circle.fill", color: .danger600)
            VStack(alignment: .leading, spacing: Spacing.s12) {
                Text("이런 이름은 어때요?").pkTextStyle(.callout).foregroundStyle(Color.ink700)
                HStack(spacing: Spacing.s8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) { viewModel.select(suggestion: suggestion) }
                            .buttonStyle(.pk(.secondary, size: .small, fillsWidth: false))
                    }
                }
            }
        case .failed(let message):
            self.message(LocalizedStringKey(message), symbol: "exclamationmark.circle.fill", color: .danger600)
        }
    }

    private func message(_ text: LocalizedStringKey, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .pkTextStyle(.callout)
            .foregroundStyle(color)
    }
}

// MARK: - Preview

@MainActor
private func previewModel(_ text: String, _ status: NicknameViewModel.Status) -> NicknameViewModel {
    NicknameViewModel(repository: MockUserRepository(), initialText: text, initialStatus: status)
}

#Preview("비어 있음") { NicknameView(viewModel: previewModel("", .empty), onNext: { _ in }) }
#Preview("확인 중") { NicknameView(viewModel: previewModel("나뭇잎", .checking), onNext: { _ in }) }
#Preview("사용 가능") { NicknameView(viewModel: previewModel("나뭇잎", .available), onNext: { _ in }) }
#Preview("중복") {
    NicknameView(
        viewModel: previewModel("두부산책", .duplicated(suggestions: ["두부산책2", "두부산책숲", "두부산책이"])),
        onNext: { _ in })
}
#Preview("에러") {
    NicknameView(viewModel: previewModel("나뭇잎", .failed(APIError.network.userMessage)), onNext: { _ in })
}
