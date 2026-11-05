import SwiftUI

/// 08c·08d — 공원 리뷰 목록. 최신순 무한 스크롤, 신고·차단. 작성·수정은 다음 작업에서 `onWrite`로 연결한다.
struct ReviewListView: View {
    @Bindable var viewModel: ReviewListViewModel
    var averageRating: Double?
    var reviewCount: Int?
    var onWrite: (() -> Void)?
    var onEdit: ((Review) -> Void)?
    var now: () -> Date = { Date() }

    @State private var actionTarget: Review?
    @State private var reportTarget: Review?
    @State private var blockTarget: Review?

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                PKLoadingView(title: "리뷰를 불러오고 있어요")
            case .failed(let message):
                PKErrorView(
                    title: "리뷰를 불러오지 못했어요", message: LocalizedStringKey(message), retryTitle: "다시 시도",
                    onRetry: { Task { await viewModel.load() } })
            case .empty:
                PKEmptyView(title: "아직 리뷰가 없어요", message: "배지를 받은 뒤 첫 리뷰를 남겨 보세요.", symbol: "text.bubble")
            case .loaded:
                list
            }
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("\(viewModel.parkName) 리뷰")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { writeButton }
        .overlay(alignment: .bottom) { toast }
        .task { if viewModel.state == .loading, viewModel.reviews.isEmpty { await viewModel.load() } }
        .confirmationDialog(
            actionTarget.map { String(localized: "\($0.nickname)님의 리뷰") } ?? "", isPresented: actionBinding,
            titleVisibility: .visible
        ) {
            Button("신고하기") { reportTarget = actionTarget }
            Button("이 유저 차단하기", role: .destructive) { blockTarget = actionTarget }
        }
        .confirmationDialog("신고 사유를 선택해 주세요", isPresented: reportBinding, titleVisibility: .visible) {
            ForEach(ReportReason.allCases, id: \.self) { reason in
                Button(reason.displayName) {
                    if let review = reportTarget { Task { await viewModel.report(review, reason: reason) } }
                }
            }
        }
        .alert("이 유저를 차단할까요?", isPresented: blockBinding) {
            Button("차단하기", role: .destructive) {
                if let review = blockTarget { Task { await viewModel.block(review) } }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("차단하면 이 유저의 리뷰가 보이지 않아요.")
        }
    }

    // MARK: 구성

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.s12) {
                summary
                ForEach(viewModel.reviews) { review in
                    ReviewRow(
                        review: review, now: now(),
                        onMore: { actionTarget = review }, onEdit: { onEdit?(review) })
                        .task { await viewModel.loadMoreIfNeeded(currentItem: review) }
                }
                footer
            }
            .padding(.horizontal, Spacing.s16)
            .padding(.bottom, 96)
        }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private var summary: some View {
        if let averageRating {
            HStack(spacing: Spacing.s16) {
                Text(String(format: "%.1f", averageRating)).pkTextStyle(.timer).foregroundStyle(Color.ink900)
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    StarRow(rating: Int(averageRating.rounded()), size: 18)
                    if let reviewCount { Text("리뷰 \(reviewCount)개").pkTextStyle(.callout).foregroundStyle(Color.ink500) }
                }
                Spacer()
            }
            .padding(Spacing.s20)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("평균 별점 \(String(format: "%.1f", averageRating))점")
        }
    }

    @ViewBuilder
    private var footer: some View {
        if viewModel.isLoadingMore {
            ProgressView().frame(maxWidth: .infinity, minHeight: 56)
        } else if viewModel.loadMoreFailed {
            Button("다음 리뷰를 불러오지 못했어요 · 다시 시도") { Task { await viewModel.loadMore() } }
                .buttonStyle(.pk(.tonal, size: .medium))
        }
    }

    @ViewBuilder
    private var writeButton: some View {
        if let onWrite {
            HStack {
                Spacer()
                Button(action: onWrite) {
                    Label(viewModel.myReview == nil ? "리뷰 쓰기" : "내 리뷰 수정", systemImage: "pencil")
                }
                .buttonStyle(.pk(.primary, size: .medium, fillsWidth: false))
            }
            .padding(.horizontal, Spacing.s16)
            .padding(.bottom, Spacing.s8)
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let message = viewModel.toastMessage {
            Text(message)
                .pkTextStyle(.callout).foregroundStyle(Color.white)
                .padding(.horizontal, Spacing.s16).padding(.vertical, Spacing.s12)
                .background(Color.ink900, in: Capsule())
                .padding(.bottom, 88)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(2.2))
                    viewModel.toastMessage = nil
                }
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private var actionBinding: Binding<Bool> {
        Binding(get: { actionTarget != nil && reportTarget == nil && blockTarget == nil }, set: { if !$0 && reportTarget == nil && blockTarget == nil { actionTarget = nil } })
    }
    private var reportBinding: Binding<Bool> {
        Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil; actionTarget = nil } })
    }
    private var blockBinding: Binding<Bool> {
        Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil; actionTarget = nil } })
    }
}

/// 별점 표시. 색만으로 전달하지 않도록 접근성 라벨에 점수를 둔다.
struct StarRow: View {
    let rating: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index <= rating ? Color.sun500 : Color.ink300)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("별점 \(rating)점")
    }
}

private struct ReviewRow: View {
    let review: Review
    let now: Date
    let onMore: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            HStack(alignment: .top, spacing: Spacing.s12) {
                PKIllustration(assetName: review.characterAssetName, fallbackSymbol: "pawprint.fill", size: 44)
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    HStack(spacing: Spacing.s8) {
                        Text(review.nickname).pkTextStyle(.headline).foregroundStyle(Color.ink900)
                        Text("배지 \(review.badgeCount)")
                            .pkTextStyle(.caption).foregroundStyle(Color.leaf600)
                            .padding(.horizontal, Spacing.s8).frame(minHeight: 22)
                            .background(Color.leaf100, in: Capsule())
                    }
                    HStack(spacing: Spacing.s4) {
                        StarRow(rating: review.rating)
                        Text("· \(RelativeTimeFormatter.text(from: review.createdAt, now: now))")
                            .pkTextStyle(.callout).foregroundStyle(Color.ink500)
                    }
                }
                Spacer(minLength: 0)
                if review.isMine {
                    Button("수정", action: onEdit).buttonStyle(.pk(.tonal, size: .small, fillsWidth: false))
                } else {
                    Button(action: onMore) {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.ink500)
                            .frame(width: TouchTarget.minimum, height: TouchTarget.minimum)
                    }
                    .accessibilityLabel("더보기")
                }
            }
            Text(review.content).pkTextStyle(.body).foregroundStyle(Color.ink900)
        }
        .padding(Spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
    }
}

// MARK: - Preview

@MainActor
private func previewModel(_ state: ReviewListViewModel.State, reviews: [Review] = MockReviewRepository.sample) -> ReviewListViewModel {
    ReviewListViewModel(
        parkID: 1, parkName: "보라매공원", repository: MockReviewRepository(delay: .seconds(60)), initialState: state,
        initialReviews: reviews)
}

#Preview("목록") {
    NavigationStack { ReviewListView(viewModel: previewModel(.loaded), averageRating: 4.6, reviewCount: 128, onWrite: {}) }
}
#Preview("빈 상태") { NavigationStack { ReviewListView(viewModel: previewModel(.empty, reviews: [])) } }
#Preview("에러") { NavigationStack { ReviewListView(viewModel: previewModel(.failed(APIError.network.userMessage), reviews: [])) } }
#Preview("로딩") { NavigationStack { ReviewListView(viewModel: previewModel(.loading, reviews: [])) } }
