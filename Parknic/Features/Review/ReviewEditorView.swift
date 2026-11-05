import SwiftUI

/// 08e·08f — 리뷰 쓰기/수정
struct ReviewEditorView: View {
    @Bindable var viewModel: ReviewEditorViewModel
    let park: Park
    let onClose: () -> Void

    @State private var confirmsDelete = false
    @FocusState private var isEditing: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s20) {
                parkCard
                ratingSection
                contentSection
                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.circle.fill")
                        .pkTextStyle(.callout).foregroundStyle(Color.danger600)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if viewModel.isEditing {
                    Button("리뷰 삭제") { confirmsDelete = true }
                        .pkTextStyle(.headline).foregroundStyle(Color.danger600)
                        .frame(minHeight: TouchTarget.minimum)
                        .disabled(viewModel.isWorking)
                }
            }
            .padding(Spacing.s16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white)
        .navigationTitle(viewModel.isEditing ? "내 리뷰 수정" : "리뷰 쓰기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) { Image(systemName: "xmark") }.accessibilityLabel("닫기")
            }
        }
        .safeAreaInset(edge: .bottom) { submitButton }
        .alert("리뷰를 삭제할까요?", isPresented: $confirmsDelete) {
            Button("삭제하기", role: .destructive) { Task { await viewModel.delete() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("삭제한 리뷰는 되돌릴 수 없어요.")
        }
    }

    // MARK: 구성

    private var parkCard: some View {
        HStack(spacing: Spacing.s12) {
            Image(systemName: park.type.symbolName)
                .foregroundStyle(Color.ink900)
                .frame(width: 48, height: 48)
                .background(park.type.color, in: RoundedRectangle(cornerRadius: Radius.r16))
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(park.name).pkTextStyle(.title2).foregroundStyle(Color.ink900)
                Text("\(park.type.displayName) · 내 배지 \(park.badgeCount)개").pkTextStyle(.callout).foregroundStyle(Color.ink500)
            }
            Spacer()
        }
        .padding(Spacing.s16)
        .background(Color.canvas, in: RoundedRectangle(cornerRadius: Radius.r20))
        .accessibilityElement(children: .combine)
    }

    private var ratingSection: some View {
        VStack(spacing: Spacing.s12) {
            Text("이 공원 어땠어요?").pkTextStyle(.title2).foregroundStyle(Color.ink900)
            HStack(spacing: Spacing.s8) {
                ForEach(1...5, id: \.self) { value in
                    Button { viewModel.rating = value } label: {
                        Image(systemName: value <= viewModel.rating ? "star.fill" : "star")
                            .font(.system(size: 40))
                            .foregroundStyle(value <= viewModel.rating ? Color.sun500 : Color.ink300)
                            .frame(width: 52, height: 52)
                    }
                    .accessibilityLabel("별점 \(value)점")
                    .accessibilityAddTraits(value == viewModel.rating ? .isSelected : [])
                }
            }
            Text(viewModel.ratingTitle).pkTextStyle(.title2).foregroundStyle(Color.sun700).frame(minHeight: 28)
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $viewModel.content)
                    .pkTextStyle(.body).foregroundStyle(Color.ink900)
                    .scrollContentBackground(.hidden)
                    .focused($isEditing)
                    .padding(Spacing.s12)
                    .frame(minHeight: 160)
                    .background(Color.canvas, in: RoundedRectangle(cornerRadius: Radius.r20))
                    .accessibilityLabel("리뷰 내용")
                Text("\(viewModel.content.count)/\(ReviewEditorViewModel.contentRange.upperBound)")
                    .pkTextStyle(.callout).foregroundStyle(Color.ink500).padding(Spacing.s12)
            }
            if !viewModel.isContentLongEnough {
                Text("\(ReviewEditorViewModel.contentRange.lowerBound)자 이상 써주세요")
                    .pkTextStyle(.callout).foregroundStyle(Color.leaf600)
            }
        }
    }

    private var submitButton: some View {
        Button {
            isEditing = false
            Task { await viewModel.submit() }
        } label: {
            if viewModel.isWorking {
                ProgressView().tint(.white)
            } else {
                Text(viewModel.isEditing ? "수정하기" : "등록하기")
            }
        }
        .buttonStyle(.pk(.primary))
        .disabled(!viewModel.canSubmit)
        .padding(.horizontal, Spacing.s16)
        .padding(.bottom, Spacing.s8)
        .background(Color.white)
    }
}

/// 08g — 배지를 받은 공원만 리뷰를 쓸 수 있다.
struct ReviewNotAllowedView: View {
    let park: Park
    let onViewOnMap: () -> Void
    let onReadOnly: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s20) {
            Spacer()
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: park.type.symbolName)
                    .font(.system(size: 64)).foregroundStyle(Color.ink300)
                    .frame(width: 140, height: 140)
                    .background(Color.ink100, in: RoundedRectangle(cornerRadius: Radius.r30))
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44).background(Color.ink900, in: Circle())
            }
            .accessibilityHidden(true)
            VStack(spacing: Spacing.s8) {
                Text("배지를 받은 공원만\n리뷰를 쓸 수 있어요").pkTextStyle(.title1).foregroundStyle(Color.ink900)
                Text("\(park.name)에서 20분 머물고 배지를 받으면 리뷰를 남길 수 있어요. 직접 다녀온 이야기만 모으고 있어요.")
                    .pkTextStyle(.body).foregroundStyle(Color.ink500)
            }
            .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: Spacing.s8) {
                Button("지도에서 공원 보기", action: onViewOnMap).buttonStyle(.pk(.primary))
                Button("리뷰만 읽어볼게요", action: onReadOnly).buttonStyle(.pk(.tonal))
            }
        }
        .padding(.horizontal, Spacing.s16)
        .padding(.bottom, Spacing.s16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .navigationTitle("리뷰 쓰기")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

private let previewPark = MockParkRepository.sample[0]

@MainActor
private func editor(_ mode: ReviewEditorViewModel.Mode) -> some View {
    NavigationStack {
        ReviewEditorView(
            viewModel: ReviewEditorViewModel(mode: mode, repository: MockReviewRepository(delay: .zero), onFinished: { _ in }),
            park: previewPark, onClose: {})
    }
}

#Preview("작성") { editor(.create(parkID: 1)) }
#Preview("수정") { editor(.edit(MockReviewRepository.sample[2])) }
#Preview("쓸 수 없음(08g)") {
    NavigationStack {
        ReviewNotAllowedView(park: MockParkRepository.sample[1], onViewOnMap: {}, onReadOnly: {})
    }
}
