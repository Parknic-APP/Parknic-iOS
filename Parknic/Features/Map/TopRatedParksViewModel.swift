import Foundation
import Observation

/// 리뷰가 좋은 공원 목록(내 위치 반경 5km, 리뷰 10개 이상 && 별점 4.5 이상).
@MainActor @Observable
final class TopRatedParksViewModel {
    enum State: Equatable {
        case loading
        case loaded([TopRatedPark])
        case empty
        case failed(String)
    }

    private(set) var state: State

    private let repository: ParkRepository
    private let center: Coordinate

    init(repository: ParkRepository, center: Coordinate, initialState: State = .loading) {
        self.repository = repository
        self.center = center
        self.state = initialState
    }

    func load() async {
        state = .loading
        do {
            let parks = try await repository.topRated(center: center, radiusM: TopRatedPark.searchRadiusM)
            state = parks.isEmpty ? .empty : .loaded(parks)
        } catch is CancellationError {
            return
        } catch {
            state = .failed((error as? APIError)?.userMessage ?? APIError.network.userMessage)
        }
    }

    /// "4.8"
    static func ratingText(_ rating: Double) -> String {
        String(format: "%.1f", rating)
    }
}
