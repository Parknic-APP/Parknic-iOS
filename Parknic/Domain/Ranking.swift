import Foundation

/// 연-월. 랭킹은 월 단위(한국 시간 기준)로 집계된다.
struct YearMonth: Equatable, Comparable, Hashable, Sendable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: Date, calendar: Calendar = .kst) {
        let parts = calendar.dateComponents([.year, .month], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1)
    }

    /// 서버 `month` 파라미터 값 ("2026-11")
    var apiValue: String { String(format: "%04d-%02d", year, month) }

    var previous: YearMonth { month == 1 ? YearMonth(year: year - 1, month: 12) : YearMonth(year: year, month: month - 1) }
    var next: YearMonth { month == 12 ? YearMonth(year: year + 1, month: 1) : YearMonth(year: year, month: month + 1) }

    /// 그 달의 마지막 날(랭킹이 확정되는 날)
    var lastDay: Int {
        var components = DateComponents(year: year, month: month, day: 1)
        components.timeZone = Calendar.kst.timeZone
        guard let first = Calendar.kst.date(from: components), let range = Calendar.kst.range(of: .day, in: .month, for: first)
        else { return 30 }
        return range.count
    }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

struct RankingEntry: Equatable, Identifiable, Sendable {
    let rank: Int
    let userID: Int
    let nickname: String
    let characterID: Int
    let badgeCount: Int

    var id: Int { userID }
    var characterAssetName: String { "character-\(characterID)" }
}

/// 내 순위. 이번 달 배지가 없으면 순위가 없다.
struct MyRanking: Equatable, Sendable {
    let rank: Int?
    let badgeCount: Int
}

struct ParkRanking: Equatable, Sendable {
    let month: YearMonth
    /// 시상대(1~3등). 자리가 비면 그 순위는 없다.
    let podium: [RankingEntry]
    /// 4등 이하
    let others: [RankingEntry]
    let me: MyRanking?

    func podiumEntry(rank: Int) -> RankingEntry? {
        podium.first { $0.rank == rank }
    }
}
