import Observation

/// 지도 홈. 위치 이벤트를 받아 주변 공원 조회로 넘기고, 선택한 공원과 권한 상태를 관리한다.
@MainActor @Observable
final class MapHomeViewModel {
    let nearby: NearbyParksViewModel
    private(set) var authorization: LocationAuthorization = .notDetermined
    /// 마커를 눌러 고른 공원(공원 시트가 이 값으로 열린다)
    var selectedParkID: Int?
    /// 값이 바뀌면 지도가 내 위치로 이동한다(현위치 버튼, 첫 위치 수신)
    private(set) var recenterToken = 0
    /// 사용자가 「둘러보기만 할게요」를 눌러 권한 안내를 닫았다
    private(set) var isBrowsingWithoutLocation = false

    private let location: LocationProviding
    private var hasCentered = false

    init(location: LocationProviding, nearby: NearbyParksViewModel) {
        self.location = location
        self.nearby = nearby
    }

    var selectedPark: Park? {
        nearby.parks.first { $0.id == selectedParkID }
    }

    /// 권한 거부 안내(10c)를 보여줄지
    var showsLocationDenied: Bool { authorization == .denied && !isBrowsingWithoutLocation }

    /// 화면이 나타날 때 한 번 부른다. 위치 이벤트가 끝날 때까지 계속 처리한다.
    func run() async {
        location.requestPermissionIfNeeded()
        for await event in location.events() {
            switch event {
            case .authorization(let value):
                authorization = value
                if value == .authorized { isBrowsingWithoutLocation = false }
            case .location(let coordinate):
                nearby.locationDidUpdate(coordinate)
                if !hasCentered {
                    hasCentered = true
                    recenterToken += 1
                }
            }
        }
    }

    func recenter() {
        recenterToken += 1
    }

    func browseWithoutLocation() {
        isBrowsingWithoutLocation = true
    }
}
