import XCTest
@testable import Parknic

final class BadgeEarnedDisplayTests: XCTestCase {
    private func display(
        rank: Int = 5, change: Int = 1, toPodium: Int = 3, achievements: [Achievement] = [], canReview: Bool = true,
        number: Int? = 4
    ) -> BadgeEarnedDisplay {
        BadgeEarnedDisplay(
            result: CheckInResult(
                badge: EarnedBadge(parkID: 1, parkName: "보라매공원", parkType: .neighborhood, earnedAt: Date()),
                newAchievements: achievements,
                monthlyRanking: MonthlyRankingSummary(rank: rank, badgeCount: 4, rankChange: change, badgesToPodium: toPodium),
                canWriteReview: canReview),
            badgeNumberAtPark: number, characterAssetName: nil)
    }

    func test_이_공원에서_몇_번째_배지인지_보여준다() {
        XCTAssertEqual(display(number: 4).subtitle, "보라매공원 · 이 공원에서 4번째 배지예요")
    }

    func test_순번을_모르면_공원_이름만_보여준다() {
        XCTAssertEqual(display(number: nil).subtitle, "보라매공원")
    }

    func test_순위가_오르면_위_화살표와_숫자() {
        XCTAssertEqual(display(change: 2).rankChangeText, "▲2")
    }

    func test_순위가_내리면_아래_화살표와_숫자() {
        XCTAssertEqual(display(change: -3).rankChangeText, "▼3")
    }

    func test_순위가_그대로면_변동을_표시하지_않는다() {
        XCTAssertNil(display(change: 0).rankChangeText)
    }

    func test_시상대_밖이면_남은_배지_수를_알려준다() {
        XCTAssertEqual(display(rank: 5, toPodium: 3).podiumText, "시상대까지\n배지 3개")
    }

    func test_시상대_안이면_올랐다고_알려준다() {
        XCTAssertEqual(display(rank: 3, toPodium: 0).podiumText, "시상대에 올랐어요")
        XCTAssertEqual(display(rank: 1, toPodium: 0).podiumText, "시상대에 올랐어요")
    }

    func test_리뷰_작성이_불가능하면_버튼을_숨긴다() {
        XCTAssertTrue(display(canReview: true).showsReviewButton)
        XCTAssertFalse(display(canReview: false).showsReviewButton)
    }

    func test_새_업적이_있으면_첫_업적을_보여준다() {
        let achievement = Achievement(code: "PARKS_10", name: "서로 다른 공원 10곳")
        XCTAssertEqual(display(achievements: [achievement]).achievement, achievement)
        XCTAssertNil(display(achievements: []).achievement)
    }

    func test_배지_에셋_이름은_공원_유형으로_정해진다() {
        XCTAssertEqual(ParkType.neighborhood.badgeAssetName, "badge-neighborhood")
        XCTAssertEqual(ParkType.waterfront.badgeAssetName, "badge-waterfront")
    }
}

final class ProfileStoreTests: XCTestCase {
    private let suite = "com.seongmo.parknic.tests.profile"
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func test_저장한_닉네임과_캐릭터를_읽는다() {
        let store = UserDefaultsProfileStore(defaults: defaults)
        XCTAssertNil(store.characterID)
        store.save(nickname: "나뭇잎", characterID: 5)
        XCTAssertEqual(store.nickname, "나뭇잎")
        XCTAssertEqual(store.characterID, 5)
    }

    func test_지우면_비어_있다() {
        let store = UserDefaultsProfileStore(defaults: defaults)
        store.save(nickname: "나뭇잎", characterID: 5)
        store.clear()
        XCTAssertNil(store.nickname)
        XCTAssertNil(store.characterID)
    }
}
