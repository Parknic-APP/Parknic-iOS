import Foundation
import Observation

/// 내 리뷰 전체 목록(09b "전체 ›"). 커서 기반으로 이어 불러온다.
@MainActor @Observable
final class MyReviewsViewModel {
    enum State: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var reviews: [MyReview] = []
    private(set) var totalCount = 0
    private(set) var isLoadingMore = false

    private let repository: MyPageRepository
    private let clock: AppClock
    private var nextCursor: String?

    init(repository: MyPageRepository, clock: AppClock = SystemClock()) {
        self.repository = repository
        self.clock = clock
    }

    func relativeTime(of review: MyReview) -> String {
        RelativeTimeFormatter.text(from: review.createdAt, now: clock.now)
    }

    func load() async {
        state = .loading
        do {
            let page = try await repository.reviews(cursor: nil)
            reviews = page.reviews
            totalCount = page.totalCount
            nextCursor = page.nextCursor
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            state = .failed((error as? APIError)?.userMessage ?? APIError.network.userMessage)
        }
    }

    /// 마지막 항목이 보이면 다음 페이지를 이어 붙인다. 실패하면 조용히 두고 다시 보일 때 재시도한다.
    func loadMoreIfNeeded(current review: MyReview) async {
        guard review.id == reviews.last?.id, let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        guard let page = try? await repository.reviews(cursor: cursor) else { return }
        let known = Set(reviews.map(\.id))
        reviews += page.reviews.filter { !known.contains($0.id) }
        totalCount = page.totalCount
        nextCursor = page.nextCursor
    }
}
