import Foundation
import Observation

/// 공원 월간 랭킹(12g·08b·08a). 이번 달이 기본이고, 이전 달로 넘겨 볼 수 있다.
@MainActor @Observable
final class RankingViewModel {
    enum State: Equatable {
        case loading
        case loaded(ParkRanking)
        case failed(String)
    }

    let parkID: Int
    let parkName: String
    private(set) var month: YearMonth
    private(set) var state: State

    private let repository: RankingRepository
    private let currentMonth: YearMonth
    private var loadTask: Task<Void, Never>?

    init(
        parkID: Int, parkName: String, repository: RankingRepository, clock: AppClock = SystemClock(),
        initialState: State = .loading
    ) {
        self.parkID = parkID
        self.parkName = parkName
        self.repository = repository
        self.currentMonth = YearMonth(date: clock.now)
        self.month = YearMonth(date: clock.now)
        self.state = initialState
    }

    var canGoNext: Bool { month < currentMonth }

    var ranking: ParkRanking? {
        if case .loaded(let ranking) = state { return ranking }
        return nil
    }

    func load() async {
        loadTask?.cancel()
        let requested = month
        state = .loading
        let task = Task {
            do {
                let ranking = try await repository.ranking(parkID: parkID, month: requested)
                guard !Task.isCancelled, requested == month else { return }
                state = .loaded(ranking)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, requested == month else { return }
                state = .failed((error as? APIError)?.userMessage ?? APIError.network.userMessage)
            }
        }
        loadTask = task
        await task.value
    }

    func showPreviousMonth() async {
        month = month.previous
        await load()
    }

    func showNextMonth() async {
        guard canGoNext else { return }
        month = month.next
        await load()
    }

    /// 「10월 31일 자정에 확정돼요」
    var confirmationText: String {
        month == currentMonth
            ? String(localized: "\(month.month)월 \(month.lastDay)일 자정에 확정돼요 · 배지 수 기준")
            : String(localized: "확정된 랭킹이에요 · 배지 수 기준")
    }
}

/// 하단 고정 "내 순위" 문구
struct MyRankingFooter: Equatable {
    let title: String
    let subtitle: String

    static func make(for ranking: ParkRanking) -> MyRankingFooter {
        guard let me = ranking.me, let rank = me.rank else {
            // 이번 달 배지가 없다 → 20분만 머물러도 몇 등이 되는지 알려준다.
            let next = ranking.podium.count + 1
            let subtitle = next <= 3
                ? String(localized: "20분만 머물러도 바로 \(next)등이에요")
                : String(localized: "20분 머물러 첫 배지를 받아 보세요")
            return MyRankingFooter(title: String(localized: "이번 달 아직 배지가 없어요"), subtitle: subtitle)
        }
        let title = String(localized: "나는 \(rank)등 · 배지 \(me.badgeCount)개")
        if rank <= 3 { return MyRankingFooter(title: title, subtitle: String(localized: "시상대에 올랐어요")) }
        // 동점이면 먼저 도달한 사람이 위이므로, 3등보다 1개 더 모아야 시상대에 오른다.
        let third = ranking.podiumEntry(rank: 3)?.badgeCount ?? 0
        let needed = max(1, third + 1 - me.badgeCount)
        return MyRankingFooter(title: title, subtitle: String(localized: "3등까지 배지 \(needed)개 남았어요"))
    }
}
