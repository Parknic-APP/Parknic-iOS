import SwiftUI

/// 12f — 캐릭터 선택
struct CharacterSelectView: View {
    let viewModel: CharacterSelectViewModel
    /// 온보딩에서만 "나중에 바꿀 수 있어요" 안내를 보여준다.
    var showsLaterHint = true

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s12), count: 4)

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                PKLoadingView(title: "친구들을 불러오고 있어요")
            case .failed(let message):
                PKErrorView(
                    title: "친구들을 불러오지 못했어요", message: LocalizedStringKey(message),
                    retryTitle: "다시 시도", onRetry: { Task { await viewModel.load() } })
            case .loaded:
                content
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.s20) {
            VStack(alignment: .leading, spacing: Spacing.s8) {
                Text("함께 산책할 친구를\n골라주세요").pkTextStyle(.title1).foregroundStyle(Color.ink900)
                if showsLaterHint {
                    Text("나중에 마이페이지에서 바꿀 수 있어요").pkTextStyle(.body).foregroundStyle(Color.ink500)
                }
            }
            preview
            LazyVGrid(columns: columns, spacing: Spacing.s12) {
                ForEach(viewModel.characters) { character in
                    CharacterCell(character: character, isSelected: character.id == viewModel.selectedID) {
                        viewModel.select(character)
                    }
                }
            }
            if case .failed(let message) = viewModel.saveState {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .pkTextStyle(.callout).foregroundStyle(Color.danger600)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.top, Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
        .safeAreaInset(edge: .bottom) { confirmButton }
    }

    private var preview: some View {
        VStack(spacing: Spacing.s12) {
            ZStack {
                Circle().fill(Color.leaf100)
                if let selected = viewModel.selected {
                    PKIllustration(assetName: selected.assetName, fallbackSymbol: "pawprint.fill", size: 120)
                }
            }
            .frame(width: 156, height: 156)
            Text(viewModel.selected?.name ?? "").pkTextStyle(.display).foregroundStyle(Color.ink900)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var confirmButton: some View {
        Button {
            Task { await viewModel.confirm() }
        } label: {
            if viewModel.isSaving {
                ProgressView().tint(.white)
            } else if let selected = viewModel.selected {
                Text("\(KoreanParticle.withIRang(selected.name)) 함께할게요")
            } else {
                Text("함께할게요")
            }
        }
        .buttonStyle(.pk(.primary))
        .disabled(viewModel.selected == nil || viewModel.isSaving)
        .padding(.horizontal, Spacing.s16)
        .padding(.bottom, Spacing.s16)
        .background(Color.white)
    }
}

private struct CharacterCell: View {
    let character: AvatarCharacter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s4) {
                PKIllustration(assetName: character.assetName, fallbackSymbol: "pawprint.fill", size: 52)
                Text(character.name).pkTextStyle(.caption).foregroundStyle(Color.ink900).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(isSelected ? Color.leaf50 : Color.white, in: RoundedRectangle(cornerRadius: Radius.r20))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.r20)
                    .stroke(isSelected ? Color.leaf600 : Color.ink100, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                // 색만으로 구분하지 않도록 체크 표시를 함께 둔다.
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.white, Color.leaf600)
                        .font(.title3)
                        .offset(x: 6, y: -6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(character.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

@MainActor
private func previewModel(_ state: CharacterSelectViewModel.State, selectedID: Int? = 1) -> CharacterSelectViewModel {
    CharacterSelectViewModel(
        repository: MockUserRepository(), initialState: state, selectedID: selectedID,
        onSaved: {}, onNicknameDuplicated: {})
}

#Preview("선택") {
    CharacterSelectView(viewModel: previewModel(.loaded(MockUserRepository.characters)))
}
#Preview("다른 캐릭터 선택") {
    CharacterSelectView(viewModel: previewModel(.loaded(MockUserRepository.characters), selectedID: 5))
}
#Preview("로딩") { CharacterSelectView(viewModel: previewModel(.loading, selectedID: nil)) }
#Preview("에러") {
    CharacterSelectView(viewModel: previewModel(.failed(APIError.network.userMessage), selectedID: nil))
}
