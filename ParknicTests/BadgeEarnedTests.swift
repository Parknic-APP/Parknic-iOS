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
                weeklyRanking: WeeklyRankingSummary(rank: rank, badgeCount: 4, rankChange: change, badgesToPodium: toPodium),
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

final class ConfettiTests: XCTestCase {
    func test_꽃가루_개수를_늘렸다() {
        XCTAssertEqual(Confetti.pieces.count, Confetti.count)
        XCTAssertGreaterThan(Confetti.count, 9, "예전에는 9개였다")
    }

    func test_배치는_항상_같다() {
        XCTAssertEqual(Confetti.pieces, Confetti.pieces)
        XCTAssertEqual(Set(Confetti.pieces.map(\.x)).count, Confetti.pieces.count, "조각마다 가로 위치가 다르다")
    }

    func test_시간이_흐르면_아래로_내려가고_화면_밖으로_나가면_위에서_다시_온다() {
        let size = CGSize(width: 390, height: 800)
        let piece = Confetti.pieces[0]
        let first = Confetti.position(of: piece, in: size, time: 0)
        let later = Confetti.position(of: piece, in: size, time: 1)
        XCTAssertGreaterThan(later.y, first.y, "아래로 떨어진다")
        for second in stride(from: 0.0, through: 120.0, by: 0.7) {
            let point = Confetti.position(of: piece, in: size, time: second)
            XCTAssertGreaterThanOrEqual(point.y, -24)
            XCTAssertLessThanOrEqual(point.y, size.height + 24, "화면 아래로 영영 사라지지 않고 다시 위로 돌아온다")
        }
    }

    func test_좌우로_흔들리되_너무_멀리_가지_않는다() {
        let size = CGSize(width: 390, height: 800)
        for piece in Confetti.pieces {
            for second in stride(from: 0.0, through: 30.0, by: 1.3) {
                let point = Confetti.position(of: piece, in: size, time: second)
                XCTAssertLessThanOrEqual(abs(point.x - piece.x * size.width), piece.sway + 0.001)
            }
        }
    }
}

final class EntrySceneTests: XCTestCase {
    func test_캐릭터는_네_마리이고_모두_에셋이_있다() {
        XCTAssertEqual(EntryScene.characters.count, 4)
        for placement in EntryScene.characters {
            XCTAssertNotNil(UIImage(named: placement.assetName), "\(placement.assetName) 에셋이 없다")
        }
        XCTAssertNotNil(UIImage(named: "login-back"))
        XCTAssertNotNil(UIImage(named: "login-front"))
    }

    func test_캐릭터마다_흔들리는_박자가_달라_함께_움직이지_않는다() {
        let periods = Set(EntryScene.characters.map(\.period))
        let phases = Set(EntryScene.characters.map(\.phase))
        XCTAssertEqual(periods.count, EntryScene.characters.count)
        XCTAssertEqual(phases.count, EntryScene.characters.count)
    }

    func test_흔들림은_살짝만_기운다() {
        for placement in EntryScene.characters {
            XCTAssertLessThanOrEqual(placement.angle, 6)
        }
    }
}

final class CheckInCheerTests: XCTestCase {
    private func display(stayedSeconds: TimeInterval, phase: CheckInProgressDisplay.Phase = .inside) -> CheckInProgressDisplay {
        let total = CheckInProgressDisplay.totalDuration
        return CheckInProgressDisplay(
            parkName: "보라매공원", parkType: .neighborhood, remaining: total - stayedSeconds, stayed: stayedSeconds, phase: phase)
    }

    func test_진행도에_따라_응원_문구가_바뀐다() {
        let total = CheckInProgressDisplay.totalDuration
        XCTAssertEqual(display(stayedSeconds: 0).cheer, "좋아요, 출발!")
        XCTAssertEqual(display(stayedSeconds: total * 0.2).cheer, "공원 공기가 참 좋죠?")
        XCTAssertEqual(display(stayedSeconds: total * 0.5).cheer, "벌써 절반이 다 돼 가요")
        XCTAssertEqual(display(stayedSeconds: total * 0.7).cheer, "조금만 더 힘내요!")
        XCTAssertEqual(display(stayedSeconds: total * 0.95).cheer, "거의 다 왔어요!")
    }

    func test_경계에서는_다음_문구로_넘어간다() {
        let total = CheckInProgressDisplay.totalDuration
        XCTAssertEqual(display(stayedSeconds: total * 0.099).cheer, "좋아요, 출발!")
        XCTAssertEqual(display(stayedSeconds: total * 0.101).cheer, "공원 공기가 참 좋죠?")
        XCTAssertEqual(display(stayedSeconds: total * 0.851).cheer, "거의 다 왔어요!")
    }

    func test_배지_확인_중이거나_반경_밖이면_상황에_맞는_문구를_쓴다() {
        let total = CheckInProgressDisplay.totalDuration
        XCTAssertEqual(display(stayedSeconds: total, phase: .completing).cheer, "배지를 만들고 있어요!")
        XCTAssertEqual(
            display(stayedSeconds: total * 0.5, phase: .outOfRange(metersOutside: 80, graceRemaining: 30)).cheer, "얼른 돌아와요!")
    }

    func test_장면_에셋이_있다() {
        XCTAssertNotNil(UIImage(named: "checkin-scene"))
        XCTAssertNotNil(UIImage(named: "character-default"))
    }
}
