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

/// 리뷰가 좋은 공원 목록의 한 항목. 리뷰 10개 이상 && 평균 별점 4.5 이상인 공원만 온다.
struct TopRatedPark: Equatable, Identifiable, Sendable {
    let park: Park
    /// 내 위치에서의 거리(m)
    let distanceM: Int
    let averageRating: Double
    let reviewCount: Int

    var id: Int { park.id }

    /// 서버가 가려내는 기준(안내 문구에 쓴다)
    static let minReviewCount = 10
    static let minRating = 4.5
    /// 이 목록을 찾는 반경(m)
    static let searchRadiusM = 5000
}

/// 공원 상세(공원 시트)
struct ParkDetail: Equatable, Sendable {
    let park: Park
    let address: String
    /// 리뷰가 없으면 nil
    let averageRating: Double?
    let reviewCount: Int
}
