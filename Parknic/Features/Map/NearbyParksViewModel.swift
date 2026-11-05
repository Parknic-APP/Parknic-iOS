import Observation

/// 지도 홈의 주변 공원. 앱 진입 시와 위치가 300m 이상 바뀌면 반경 1km 공원을 다시 조회한다.
@MainActor @Observable
final class NearbyParksViewModel {
    enum State: Equatable {
        case loading
        case loaded([Park])
        /// 1km 안에 공원이 없다(03c)
        case empty
        case failed(String)
    }

    static let searchRadiusM = 1000
    static let refetchDistanceM = 300.0

    private(set) var state: State
    /// 마지막으로 받은 현재 위치. 체크인 가능 여부 계산에 쓴다.
    private(set) var currentLocation: Coordinate?

    private let repository: ParkRepository
    private var lastFetchCenter: Coordinate?
    private var fetchTask: Task<Void, Never>?

    init(repository: ParkRepository, initialState: State = .loading) {
        self.repository = repository
        self.state = initialState
    }

    var parks: [Park] {
        if case .loaded(let parks) = state { return parks }
        return []
    }

    /// 현재 위치가 판정 반경 안인 공원들. 2곳 이상이면 사용자가 고른다.
    var parksInRange: [Park] {
        guard let currentLocation else { return [] }
        return parks.filter { $0.contains(currentLocation) }
    }

    /// 위치가 들어왔다. 처음이거나 마지막 조회 위치에서 300m 이상 벗어났을 때만 다시 조회한다.
    func locationDidUpdate(_ location: Coordinate) {
        currentLocation = location
        if let center = lastFetchCenter, center.distance(to: location) < Self.refetchDistanceM { return }
        startFetch(at: location)
    }

    /// 에러 화면의 「다시 시도」
    func retry() {
        guard let currentLocation else { return }
        startFetch(at: currentLocation)
    }

    /// 체크인 등으로 내 상태(배지 수, 오늘 받음)가 바뀐 뒤 다시 조회한다.
    func refresh() {
        guard let currentLocation else { return }
        startFetch(at: currentLocation, showsLoading: false)
    }

    private func startFetch(at center: Coordinate, showsLoading: Bool = true) {
        fetchTask?.cancel()
        if showsLoading, parks.isEmpty { state = .loading }
        lastFetchCenter = center
        fetchTask = Task { [repository] in
            do {
                let parks = try await repository.nearby(center: center, radiusM: Self.searchRadiusM)
                guard !Task.isCancelled else { return }
                state = parks.isEmpty ? .empty : .loaded(parks)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                // 실패하면 다음 위치 업데이트에서 다시 시도할 수 있게 기준 위치를 비운다.
                lastFetchCenter = nil
                state = .failed((error as? APIError)?.userMessage ?? APIError.network.userMessage)
            }
        }
    }
}
