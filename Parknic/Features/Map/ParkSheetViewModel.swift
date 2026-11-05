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

    private let repository: ParkRepository

    init(park: Park, repository: ParkRepository, initialState: State = .loading) {
        self.park = park
        self.repository = repository
        self.state = initialState
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
}
