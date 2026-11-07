import Observation

/// 지도 홈의 주변 공원. 앱 진입 시와 위치가 300m 이상 바뀌면 설정한 반경(기본 1km)의 공원을 다시 조회한다.
@MainActor @Observable
final class NearbyParksViewModel {
    enum State: Equatable {
        case loading
        case loaded([Park])
        /// 반경 안에 공원이 없다(03c)
        case empty
        case failed(String)
    }

    static let refetchDistanceM = 300.0

    private(set) var state: State
    /// 마지막으로 받은 현재 위치. 체크인 가능 여부 계산에 쓴다.
    private(set) var currentLocation: Coordinate?

    private let repository: ParkRepository
    /// 마이페이지 설정에서 고른 조회 반경
    let radiusSetting: SearchRadiusSetting
    private var lastFetchCenter: Coordinate?
    private var fetchTask: Task<Void, Never>?

    init(repository: ParkRepository, radiusSetting: SearchRadiusSetting? = nil, initialState: State = .loading) {
        self.repository = repository
        self.radiusSetting = radiusSetting ?? SearchRadiusSetting()
        self.state = initialState
    }

    /// 지금 쓰는 조회 반경(m)
    var radiusM: Int { radiusSetting.radius.meters }

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

    /// 설정에서 반경을 바꿨다. 지금 위치 기준으로 새 반경의 공원을 다시 불러온다(그동안 이전 공원은 그대로 보인다).
    func radiusDidChange() {
        guard let currentLocation else { return }
        startFetch(at: currentLocation, showsLoading: false)
    }

    /// 로그아웃·탈퇴로 계정이 바뀌었다. 이전 사용자의 공원 상태(배지·오늘 받음)가 남지 않게 비우고, 다음 조회를 다시 받게 한다.
    func reset() {
        fetchTask?.cancel()
        lastFetchCenter = nil
        state = .loading
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

    /// `refresh()`와 같지만 조회가 끝날 때까지 기다린다. 배지를 받은 직후 최신 배지 수가 필요한 화면 전환에 쓴다.
    func refreshAndWait() async {
        guard let currentLocation else { return }
        startFetch(at: currentLocation, showsLoading: false)
        await fetchTask?.value
    }

    private func startFetch(at center: Coordinate, showsLoading: Bool = true) {
        fetchTask?.cancel()
        if showsLoading, parks.isEmpty { state = .loading }
        lastFetchCenter = center
        fetchTask = Task { [repository] in
            do {
                let parks = try await repository.nearby(center: center, radiusM: radiusM)
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
