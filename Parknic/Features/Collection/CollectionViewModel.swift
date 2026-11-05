import Foundation
import Observation

/// 도감 탭(12h·09a). 탭이 보일 때마다 새로 불러와 방금 받은 배지가 바로 반영된다.
@MainActor @Observable
final class CollectionViewModel {
    enum State: Equatable {
        case loading
        case loaded(BadgeCollection)
        case failed(String)
    }

    private(set) var state: State
    private let repository: CollectionRepository

    init(repository: CollectionRepository, initialState: State = .loading) {
        self.repository = repository
        self.state = initialState
    }

    var collection: BadgeCollection? {
        if case .loaded(let collection) = state { return collection }
        return nil
    }

    /// 이미 불러온 내용이 있으면 화면은 그대로 두고 조용히 갱신한다(깜빡임 방지).
    func load() async {
        if collection == nil { state = .loading }
        do {
            state = .loaded(try await repository.collection())
        } catch is CancellationError {
            return
        } catch {
            if collection == nil {
                state = .failed((error as? APIError)?.userMessage ?? APIError.network.userMessage)
            }
        }
    }
}
