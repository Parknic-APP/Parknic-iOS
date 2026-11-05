import Foundation

/// "방금 전", "5분 전", "2일 전" 같은 한국어 상대 시간
enum RelativeTimeFormatter {
    static func text(from date: Date, now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return String(localized: "방금 전")
        case 60..<3600: return String(localized: "\(seconds / 60)분 전")
        case 3600..<86_400: return String(localized: "\(seconds / 3600)시간 전")
        case 86_400..<(7 * 86_400): return String(localized: "\(seconds / 86_400)일 전")
        case (7 * 86_400)..<(30 * 86_400): return String(localized: "\(seconds / (7 * 86_400))주 전")
        case (30 * 86_400)..<(365 * 86_400): return String(localized: "\(seconds / (30 * 86_400))개월 전")
        default: return String(localized: "\(seconds / (365 * 86_400))년 전")
        }
    }
}
