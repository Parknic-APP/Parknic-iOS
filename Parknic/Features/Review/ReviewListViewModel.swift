import Foundation
import Observation

/// 공원 리뷰 목록(08c). 최신순, 커서 기반 무한 스크롤이며 신고·차단을 처리한다.
@MainActor @Observable
final class ReviewListViewModel {
    enum State: Equatable {
        case loading
        case loaded
        /// 아직 리뷰가 없다
        case empty
        case failed(String)
    }

    let parkID: Int
    let parkName: String
    private(set) var state: State
    private(set) var reviews: [Review]
    private(set) var isLoadingMore = false
    /// 다음 페이지를 못 불러왔다(목록 끝의 「다시 시도」)
    private(set) var loadMoreFailed = false
    /// 신고·차단 결과를 짧게 알리는 문구
    var toastMessage: String?

    private let repository: ReviewRepository
    private var nextCursor: String?
    /// 새로고침으로 목록이 바뀌면 이전 요청의 응답을 버리기 위한 값
    private var generation = 0

    /// 끝에서 이만큼 남았을 때 다음 페이지를 미리 불러온다.
    static let prefetchDistance = 3

    init(
        parkID: Int, parkName: String, repository: ReviewRepository, initialState: State = .loading,
        initialReviews: [Review] = []
    ) {
        self.parkID = parkID
        self.parkName = parkName
        self.repository = repository
        self.state = initialState
        self.reviews = initialReviews
    }

    var hasMore: Bool { nextCursor != nil }
    var myReview: Review? { reviews.first(where: \.isMine) }

    func load() async {
        generation += 1
        let current = generation
        state = .loading
        nextCursor = nil
        loadMoreFailed = false
        do {
            let page = try await repository.list(parkID: parkID, cursor: nil)
            guard current == generation else { return }
            reviews = page.reviews
            nextCursor = page.nextCursor
            state = page.reviews.isEmpty ? .empty : .loaded
        } catch {
            guard current == generation else { return }
            state = .failed(Self.message(for: error))
        }
    }

    /// 목록에서 `review`가 보였을 때 부른다. 끝에 가까우면 다음 페이지를 불러온다.
    func loadMoreIfNeeded(currentItem review: Review) async {
        guard let index = reviews.firstIndex(where: { $0.id == review.id }),
            index >= reviews.count - Self.prefetchDistance
        else { return }
        await loadMore()
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore, state == .loaded else { return }
        isLoadingMore = true
        loadMoreFailed = false
        let current = generation
        defer { isLoadingMore = false }
        do {
            let page = try await repository.list(parkID: parkID, cursor: cursor)
            guard current == generation else { return }
            // 같은 리뷰가 두 번 보이지 않게 한다(새 리뷰가 올라와 페이지 경계가 밀리는 경우).
            let known = Set(reviews.map(\.id))
            reviews += page.reviews.filter { !known.contains($0.id) }
            nextCursor = page.nextCursor
        } catch {
            guard current == generation else { return }
            loadMoreFailed = true
        }
    }

    /// `reviewID`가 목록에 보일 때까지 다음 페이지를 이어 불러온다(내 리뷰로 바로 이동할 때 쓴다). 못 찾으면 그대로 둔다.
    func ensureLoaded(reviewID: Int, maxPages: Int = 10) async {
        var pages = 0
        while !reviews.contains(where: { $0.id == reviewID }), hasMore, !loadMoreFailed, pages < maxPages {
            let before = reviews.count
            await loadMore()
            pages += 1
            if reviews.count == before { break }
        }
    }

    // MARK: 신고·차단

    func report(_ review: Review, reason: ReportReason) async {
        do {
            try await repository.report(reviewID: review.id, reason: reason)
            toastMessage = String(localized: "신고했어요. 확인 후 조치할게요")
        } catch {
            toastMessage = Self.message(for: error)
        }
    }

    /// 차단하면 이 유저의 리뷰를 내 화면에서 숨긴다(서버도 이후 목록에서 제외한다).
    func block(_ review: Review) async {
        do {
            try await repository.blockUser(userID: review.userID)
            reviews.removeAll { $0.userID == review.userID }
            if reviews.isEmpty, nextCursor == nil { state = .empty }
            toastMessage = String(localized: "차단했어요. 이 유저의 리뷰는 보이지 않아요")
        } catch {
            toastMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        (error as? APIError)?.userMessage ?? APIError.network.userMessage
    }
}
