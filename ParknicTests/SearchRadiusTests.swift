import XCTest
@testable import Parknic

final class SearchRadiusTests: XCTestCase {
    private func makeStore() -> UserDefaultsSearchRadiusStore {
        let defaults = UserDefaults(suiteName: "tests.searchRadius.\(UUID().uuidString)")!
        return UserDefaultsSearchRadiusStore(defaults: defaults)
    }

    func test_선택지는_1km_1점5km_2km이고_기본은_1km다() {
        XCTAssertEqual(SearchRadius.allCases.map(\.meters), [1000, 1500, 2000])
        XCTAssertEqual(SearchRadius.allCases.map(\.label), ["1km", "1.5km", "2km"])
        XCTAssertEqual(SearchRadius.default, .km1)
    }

    func test_저장한_값이_없으면_기본값이다() {
        XCTAssertEqual(makeStore().radius, .km1)
    }

    func test_고른_반경은_저장되고_다시_읽힌다() {
        let store = makeStore()
        store.save(.km2)
        XCTAssertEqual(store.radius, .km2)
    }

    func test_알_수_없는_저장값은_기본값으로_본다() {
        let defaults = UserDefaults(suiteName: "tests.searchRadius.\(UUID().uuidString)")!
        defaults.set(3000, forKey: "settings.searchRadiusM")
        XCTAssertEqual(UserDefaultsSearchRadiusStore(defaults: defaults).radius, .km1)
    }

    @MainActor
    func test_설정을_바꾸면_저장되고_새_설정이_같은_값을_본다() {
        let store = makeStore()
        let setting = SearchRadiusSetting(store: store)
        XCTAssertEqual(setting.radius, .km1)

        setting.select(.km1_5)

        XCTAssertEqual(setting.radius, .km1_5)
        XCTAssertEqual(SearchRadiusSetting(store: store).radius, .km1_5)
    }
}
