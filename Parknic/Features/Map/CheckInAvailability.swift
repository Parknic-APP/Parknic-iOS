import Foundation

/// 공원 시트의 체크인 버튼 상태(04a 활성 / 04b 반경 밖 / 04c 오늘 획득)와 그 밖의 막힌 이유
enum CheckInAvailability: Equatable {
    case available
    /// 판정 반경 밖. `distanceM`는 공원까지의 거리
    case outOfRange(distanceM: Int)
    case earnedToday
    case waitingForLocation
    case locationDenied
    /// 지금 이 공원에서 체크인 중
    case inProgressHere
    /// 동시에 체크인할 수 있는 공원은 1곳이다.
    case anotherInProgress(parkName: String)

    static func make(
        park: Park, location: Coordinate?, authorization: LocationAuthorization,
        activeSession: CheckInSession?
    ) -> CheckInAvailability {
        if let activeSession {
            return activeSession.parkID == park.id ? .inProgressHere : .anotherInProgress(parkName: activeSession.parkName)
        }
        if park.status == .earnedToday { return .earnedToday }
        if authorization == .denied { return .locationDenied }
        guard let location else { return .waitingForLocation }
        if park.contains(location) { return .available }
        return .outOfRange(distanceM: Int(park.coordinate.distance(to: location).rounded()))
    }

    /// 버튼을 누를 수 있는 상태인지
    var isEnabled: Bool {
        switch self {
        case .available, .inProgressHere: true
        default: false
        }
    }
}
