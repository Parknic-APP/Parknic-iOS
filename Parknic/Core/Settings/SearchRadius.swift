import Foundation
import Observation

/// 지도에서 주변 공원을 불러오는 반경 선택지. 기본은 1km.
enum SearchRadius: Int, CaseIterable, Identifiable, Sendable {
    case km1 = 1000
    case km1_5 = 1500
    case km2 = 2000

    static let `default`: SearchRadius = .km1

    var id: Int { rawValue }
    var meters: Int { rawValue }

    /// "1km", "1.5km", "2km"
    var label: String {
        switch self {
        case .km1: "1km"
        case .km1_5: "1.5km"
        case .km2: "2km"
        }
    }
}

/// 선택한 반경을 기기에 보관한다.
protocol SearchRadiusStore: Sendable {
    var radius: SearchRadius { get }
    func save(_ radius: SearchRadius)
}

struct UserDefaultsSearchRadiusStore: SearchRadiusStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "settings.searchRadiusM"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 저장된 값이 없거나 알 수 없는 값이면 기본값을 쓴다.
    var radius: SearchRadius {
        (defaults.object(forKey: key) as? Int).flatMap(SearchRadius.init(rawValue:)) ?? .default
    }

    func save(_ radius: SearchRadius) {
        defaults.set(radius.rawValue, forKey: key)
    }
}

/// 현재 선택한 반경. 지도(공원 조회)와 마이페이지(설정)가 같은 값을 본다.
@MainActor @Observable
final class SearchRadiusSetting {
    private(set) var radius: SearchRadius
    private let store: SearchRadiusStore

    init(store: SearchRadiusStore = UserDefaultsSearchRadiusStore()) {
        self.store = store
        self.radius = store.radius
    }

    func select(_ radius: SearchRadius) {
        self.radius = radius
        store.save(radius)
    }
}
