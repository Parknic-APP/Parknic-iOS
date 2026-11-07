import Foundation

/// 랭킹 한 주(월요일 0시 ~ 일요일 24시, 한국 시간). 랭킹은 매주 월요일 0시에 새로 시작한다.
struct RankingWeek: Equatable, Comparable, Hashable, Sendable {
    /// 그 주 월요일 0시(KST)
    let start: Date

    /// `date`가 속한 주
    init(date: Date, calendar: Calendar = .kst) {
        let weekday = calendar.component(.weekday, from: date)  // 1=일 … 7=토
        let daysSinceMonday = (weekday + 5) % 7
        let day = calendar.startOfDay(for: date)
        self.start = calendar.date(byAdding: .day, value: -daysSinceMonday, to: day) ?? day
    }

    private func shifted(byDays days: Int) -> RankingWeek {
        RankingWeek(date: Calendar.kst.date(byAdding: .day, value: days, to: start) ?? start)
    }

    var previous: RankingWeek { shifted(byDays: -7) }
    var next: RankingWeek { shifted(byDays: 7) }

    /// 일요일(그 주의 마지막 날)
    var end: Date { Calendar.kst.date(byAdding: .day, value: 6, to: start) ?? start }
    /// 다음 주 월요일(새 랭킹이 시작되는 날)
    var resetDate: Date { Calendar.kst.date(byAdding: .day, value: 7, to: start) ?? start }

    /// 서버 `week` 파라미터 값(그 주 월요일, "2026-11-02")
    var apiValue: String {
        let parts = Calendar.kst.dateComponents([.year, .month, .day], from: start)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    /// "11월 2일 ~ 8일", 달이 걸치면 "10월 27일 ~ 11월 2일"
    var rangeLabel: String {
        let a = Calendar.kst.dateComponents([.month, .day], from: start)
        let b = Calendar.kst.dateComponents([.month, .day], from: end)
        guard let am = a.month, let ad = a.day, let bm = b.month, let bd = b.day else { return "" }
        return am == bm
            ? String(localized: "\(am)월 \(ad)일 ~ \(bd)일")
            : String(localized: "\(am)월 \(ad)일 ~ \(bm)월 \(bd)일")
    }

    /// 공원 시트의 작은 태그용 "11/2~8"
    var shortLabel: String {
        let a = Calendar.kst.dateComponents([.month, .day], from: start)
        let b = Calendar.kst.dateComponents([.month, .day], from: end)
        guard let am = a.month, let ad = a.day, let bm = b.month, let bd = b.day else { return "" }
        return am == bm ? "\(am)/\(ad)~\(bd)" : "\(am)/\(ad)~\(bm)/\(bd)"
    }

    /// 새 랭킹이 시작되는 날 "11월 9일"
    var resetLabel: String {
        let parts = Calendar.kst.dateComponents([.month, .day], from: resetDate)
        return String(localized: "\(parts.month ?? 1)월 \(parts.day ?? 1)일")
    }

    static func < (lhs: RankingWeek, rhs: RankingWeek) -> Bool { lhs.start < rhs.start }
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

/// 내 순위. 이번 주 배지가 없으면 순위가 없다.
struct MyRanking: Equatable, Sendable {
    let rank: Int?
    let badgeCount: Int
}

struct ParkRanking: Equatable, Sendable {
    let week: RankingWeek
    /// 시상대(1~3등). 자리가 비면 그 순위는 없다.
    let podium: [RankingEntry]
    /// 4등 이하
    let others: [RankingEntry]
    let me: MyRanking?

    func podiumEntry(rank: Int) -> RankingEntry? {
        podium.first { $0.rank == rank }
    }
}
