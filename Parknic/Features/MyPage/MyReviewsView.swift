import SwiftUI

/// 내 리뷰 한 줄: 공원 이름 + 별점 + 시간, 아래에 본문.
struct MyReviewRow: View {
    let review: MyReview
    let timeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            HStack(spacing: Spacing.s8) {
                Text(review.parkName).pkTextStyle(.headline).foregroundStyle(Color.ink900).lineLimit(1)
                Text(String(repeating: "★", count: max(0, min(review.rating, 5))))
                    .pkTextStyle(.callout).foregroundStyle(Color.sun500)
                Spacer(minLength: Spacing.s8)
                Text(timeText).pkTextStyle(.callout).foregroundStyle(Color.ink500)
            }
            Text(review.content).pkTextStyle(.body).foregroundStyle(Color.ink700)
        }
        .padding(.vertical, Spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(review.parkName), 별점 \(review.rating)점, \(timeText). \(review.content)")
    }
}

/// 내 리뷰를 눌러 연 그 공원의 리뷰 목록과 강조할 리뷰
struct OpenedMyReview {
    let viewModel: ReviewListViewModel
    let focusReviewID: Int
}

/// 09b — 내 리뷰 전체 목록. 로딩·빈 상태·에러(재시도)를 갖는다.
struct MyReviewsView: View {
    let viewModel: MyReviewsViewModel
    /// 리뷰를 눌렀을 때 그 공원의 리뷰 목록을 만든다. nil이면 눌러도 이동하지 않는다.
    var makeReviewList: ((MyReview) -> ReviewListViewModel)?

    @State private var opened: OpenedMyReview?

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                PKLoadingView(title: "내 리뷰를 불러오고 있어요", message: "잠깐만요, 금방 끝나요")
            case .failed(let message):
                PKErrorView(title: "리뷰를 불러오지 못했어요", message: LocalizedStringKey(message), retryTitle: "다시 시도") {
                    Task { await viewModel.load() }
                }
            case .loaded:
                if viewModel.reviews.isEmpty {
                    PKEmptyView(
                        title: "아직 쓴 리뷰가 없어요", message: "공원에서 배지를 받으면 리뷰를 남길 수 있어요", symbol: "text.bubble")
                } else {
                    list
                }
            }
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("내 리뷰")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .navigationDestination(isPresented: Binding(get: { opened != nil }, set: { if !$0 { opened = nil } })) {
            if let opened { ReviewListView(viewModel: opened.viewModel, focusReviewID: opened.focusReviewID) }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.reviews.enumerated()), id: \.element.id) { index, review in
                    if index > 0 { Divider() }
                    Button {
                        if let makeReviewList { opened = OpenedMyReview(viewModel: makeReviewList(review), focusReviewID: review.id) }
                    } label: {
                        MyReviewRow(review: review, timeText: viewModel.relativeTime(of: review))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(makeReviewList == nil ? "" : "그 공원의 리뷰로 이동해요")
                    .task { await viewModel.loadMoreIfNeeded(current: review) }
                }
                if viewModel.isLoadingMore { ProgressView().tint(.leaf600).padding(Spacing.s16) }
            }
            .padding(.horizontal, Spacing.s16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
            .padding(Spacing.s16)
        }
    }
}

#Preview("내 리뷰") {
    NavigationStack { MyReviewsView(viewModel: MyReviewsViewModel(repository: MockMyPageRepository(delay: .zero))) }
}

#Preview("비어 있음") {
    NavigationStack {
        MyReviewsView(viewModel: MyReviewsViewModel(repository: MockMyPageRepository(delay: .zero, isNewcomer: true)))
    }
}
