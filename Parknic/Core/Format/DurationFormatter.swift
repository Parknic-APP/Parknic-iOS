import Foundation

/// 체크인 화면의 시간 표기
enum DurationFormatter {
    /// 남은 시간 "12:34". 1초라도 남았으면 0:00으로 보이지 않도록 올림한다.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// 머문 시간을 분 단위로 내린 값("20분 중 7분 머물렀어요")
    static func wholeMinutes(_ seconds: TimeInterval) -> Int {
        max(0, Int(seconds) / 60)
    }

    /// "7분 26초", 1분 미만은 "42초"
    static func minutesAndSeconds(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let minutes = total / 60
        let rest = total % 60
        if minutes == 0 { return String(localized: "\(rest)초") }
        return String(localized: "\(minutes)분 \(rest)초")
    }
}
