import Observation

/// 공원 시트. 목록에서 받은 기본 정보는 바로 보여주고, 주소·평점은 상세 조회가 끝나면 채운다.
@MainActor @Observable
final class ParkSheetViewModel {
    enum State: Equatable {
        case loading
        case loaded(ParkDetail)
        case failed(String)
    }

    let park: Park
    private(set) var state: State
    /// 이달의 시상대. 불러오지 못하면 nil이고 시트에는 랭킹 이동 행만 보인다.
    private(set) var ranking: ParkRanking?

    private let repository: ParkRepository
    private let rankingRepository: RankingRepository
    private let reviewRepository: ReviewRepository
    private let clock: AppClock

    init(
        park: Park, repository: ParkRepository, rankingRepository: RankingRepository = MockRankingRepository(delay: .zero),
        reviewRepository: ReviewRepository = MockReviewRepository(delay: .zero), clock: AppClock = SystemClock(), initialState: State = .loading, initialRanking: ParkRanking? = nil
    ) {
        self.park = park
        self.repository = repository
        self.rankingRepository = rankingRepository
        self.reviewRepository = reviewRepository
        self.clock = clock
        self.state = initialState
        self.ranking = initialRanking
    }

    var detail: ParkDetail? {
        if case .loaded(let detail) = state { return detail }
        return nil
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await repository.detail(parkID: park.id))
        } catch {
            state = .failed((error as? APIError)?.userMessage ?? APIError.network.userMessage)
        }
    }

    /// 시상대는 시트의 보조 정보라 실패해도 에러를 띄우지 않는다.
    func loadRanking() async {
        ranking = try? await rankingRepository.ranking(parkID: park.id, month: YearMonth(date: clock.now))
    }

    func makeRankingViewModel() -> RankingViewModel {
        RankingViewModel(parkID: park.id, parkName: park.name, repository: rankingRepository, clock: clock)
    }

    func makeReviewListViewModel() -> ReviewListViewModel {
        ReviewListViewModel(parkID: park.id, parkName: park.name, repository: reviewRepository)
    }

    func makeReviewEditorViewModel(
        mode: ReviewEditorViewModel.Mode, onFinished: @escaping (ReviewEditorViewModel.Result) -> Void
    ) -> ReviewEditorViewModel {
        ReviewEditorViewModel(mode: mode, repository: reviewRepository, onFinished: onFinished)
    }
}
