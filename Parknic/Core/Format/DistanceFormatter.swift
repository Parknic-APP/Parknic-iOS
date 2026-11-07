import Foundation

/// 거리 문구. 1km 미만은 미터("320m"), 이상은 km 소수 한 자리("1.2km")로 보여준다.
/// 천 단위 구분 쉼표가 붙지 않도록 직접 만든 문자열을 쓴다.
enum DistanceFormatter {
    static func text(meters: Int) -> String {
        if meters < 50 { return String(localized: "50m 이내") }
        return meters < 1000 ? "\(meters)m" : String(format: "%.1fkm", Double(meters) / 1000)
    }
}
