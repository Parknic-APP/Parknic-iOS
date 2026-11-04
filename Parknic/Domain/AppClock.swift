import Foundation

/// 현재 시각 공급자. 시간에 의존하는 로직(체크인 경과 시간, 자정 판정)은 이것을 주입받아 테스트에서 시각을 고정한다.
protocol AppClock: Sendable {
    var now: Date { get }
}

struct SystemClock: AppClock {
    var now: Date { Date() }
}

extension Calendar {
    /// 날짜 경계(자정) 판정에 쓰는 한국 표준시 달력
    static let kst: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600) ?? .current
        return calendar
    }()
}
