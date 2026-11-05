import Foundation

/// 내가 이 공원에서 배지를 받은 상태. 서버 `myStatus` 값과 같다.
enum ParkVisitStatus: String, Equatable, Sendable {
    case none = "NONE"
    case earned = "EARNED"
    case earnedToday = "EARNED_TODAY"
}

struct Park: Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let type: ParkType
    let coordinate: Coordinate
    /// 공원 판정 반경(m). 서버가 면적 기반으로 계산한다(50~500m).
    let radiusM: Double
    let status: ParkVisitStatus
    /// 내가 이 공원에서 받은 배지 수
    let badgeCount: Int

    /// 현재 위치가 판정 반경 안인지(체크인 버튼 활성 조건)
    func contains(_ location: Coordinate) -> Bool {
        coordinate.distance(to: location) <= radiusM
    }

    /// 판정 반경 경계까지의 남은 거리(m). 반경 안이면 0.
    func distanceToBoundary(from location: Coordinate) -> Double {
        max(0, coordinate.distance(to: location) - radiusM)
    }
}

/// 공원 상세(공원 시트)
struct ParkDetail: Equatable, Sendable {
    let park: Park
    let address: String
    /// 리뷰가 없으면 nil
    let averageRating: Double?
    let reviewCount: Int
}
