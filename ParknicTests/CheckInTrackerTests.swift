import XCTest
@testable import Parknic

/// 테스트에서 시각을 마음대로 움직이는 시계
final class FixedClock: AppClock, @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    init(_ now: Date) { _now = now }
    var now: Date { lock.withLock { _now } }
    func advance(by seconds: TimeInterval) { lock.withLock { _now = _now.addingTimeInterval(seconds) } }
    func set(_ date: Date) { lock.withLock { _now = date } }
}

func kst(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso) ?? Date(timeIntervalSince1970: 0)
}

final class CheckInTrackerTests: XCTestCase {
    private let center = Coordinate(latitude: 37.4934, longitude: 126.9209)
    /// 중심에서 북쪽으로 약 meters 떨어진 좌표(위도 1도 ≈ 111.19km)
    private func point(metersNorth meters: Double) -> Coordinate {
        Coordinate(latitude: center.latitude + meters / 111_195, longitude: center.longitude)
    }
    private func sample(metersNorth: Double, accuracy: Double = 10) -> LocationSample {
        LocationSample(coordinate: point(metersNorth: metersNorth), horizontalAccuracy: accuracy)
    }

    private let start = kst("2026-11-04T15:00:00+09:00")
    private var clock: FixedClock!
    private var tracker: CheckInTracker!
    private var session: CheckInSession!

    override func setUp() {
        clock = FixedClock(start)
        tracker = CheckInTracker(clock: clock)
        session = makeSession(startedAt: start)
    }

    private func makeSession(startedAt: Date, radius: Double = 180) -> CheckInSession {
        CheckInSession(id: 7, parkID: 1024, parkName: "보라매공원", center: center, radiusM: radius, startedAt: startedAt)
    }

    private func startTracking() {
        XCTAssertTrue(tracker.start(session, at: center))
    }

    // MARK: 시작

    func test_처음에는_idle이다() {
        XCTAssertEqual(tracker.state, .idle)
        XCTAssertNil(tracker.remaining)
    }

    func test_시작하면_진행_중이고_남은_시간은_20분이다() {
        startTracking()
        XCTAssertEqual(tracker.state, .inProgress(session))
        XCTAssertEqual(tracker.remaining, 1200)
    }

    func test_진행_중에는_다른_공원을_시작할_수_없다() {
        startTracking()
        let other = CheckInSession(id: 8, parkID: 9, parkName: "다른공원", center: center, radiusM: 100, startedAt: start)
        XCTAssertFalse(tracker.start(other))
        XCTAssertEqual(tracker.state.session?.parkID, 1024)
    }

    func test_경과_시간은_시작_시각과_현재_시각의_차이로_계산한다() {
        startTracking()
        clock.advance(by: 300)
        XCTAssertEqual(tracker.remaining, 900)
        // 앱이 한동안 멈췄다가 깨어나도 시계 기준이라 어긋나지 않는다
        clock.advance(by: 600)
        XCTAssertEqual(tracker.remaining, 300)
    }

    func test_서버_시작_시각이_과거면_그만큼_남은_시간이_줄어든다() {
        session = makeSession(startedAt: start.addingTimeInterval(-600))
        startTracking()
        XCTAssertEqual(tracker.remaining, 600)
    }

    // MARK: 반경

    func test_반경_안_위치는_상태를_바꾸지_않는다() {
        startTracking()
        XCTAssertEqual(tracker.receive(sample(metersNorth: 100)), [])
        XCTAssertEqual(tracker.state, .inProgress(session))
    }

    func test_반경_경계는_안으로_본다() {
        startTracking()
        XCTAssertEqual(tracker.receive(sample(metersNorth: 179)), [])
        XCTAssertEqual(tracker.state, .inProgress(session))
    }

    func test_반경을_벗어나면_즉시_경고한다() {
        startTracking()
        clock.advance(by: 30)
        let effects = tracker.receive(sample(metersNorth: 260))
        XCTAssertEqual(effects, [.warnOutOfRange])
        XCTAssertEqual(tracker.state, .outOfRange(session, since: start.addingTimeInterval(30)))
    }

    func test_이탈_중_계속_밖이면_경고를_반복하지_않는다() {
        startTracking()
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 20)
        XCTAssertEqual(tracker.receive(sample(metersNorth: 300)), [])
        XCTAssertEqual(tracker.state, .outOfRange(session, since: start))
    }

    // MARK: 이탈과 복귀

    func test_1분_안에_복귀하면_이어서_진행한다() {
        startTracking()
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 59)
        let effects = tracker.receive(sample(metersNorth: 50))
        XCTAssertEqual(effects, [.clearOutOfRangeWarning])
        XCTAssertEqual(tracker.state, .inProgress(session))
    }

    func test_복귀해도_경과_시간은_처음부터_이어진다() {
        startTracking()
        clock.advance(by: 600)
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 30)
        _ = tracker.receive(sample(metersNorth: 10))
        XCTAssertEqual(tracker.remaining, 1200 - 630)
    }

    func test_이탈_후_정확히_1분이_지나면_실패한다() {
        startTracking()
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 60)
        XCTAssertEqual(tracker.tick(), [.requestFail(session, .outOfRange)])
        XCTAssertEqual(tracker.state, .failed(session, .outOfRange))
    }

    func test_59초까지는_실패하지_않는다() {
        startTracking()
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 59.9)
        XCTAssertEqual(tracker.tick(), [])
        XCTAssertEqual(tracker.state, .outOfRange(session, since: start))
    }

    func test_1분이_지난_뒤_늦게_복귀_위치가_와도_실패다() {
        startTracking()
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 75)
        let effects = tracker.receive(sample(metersNorth: 10))
        XCTAssertEqual(effects, [.requestFail(session, .outOfRange)])
        XCTAssertEqual(tracker.state, .failed(session, .outOfRange))
    }

    func test_이탈_중_위치_업데이트가_없어도_tick으로_실패한다() {
        // distanceFilter 때문에 가만히 서 있으면 위치가 오지 않는다
        startTracking()
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 61)
        XCTAssertEqual(tracker.tick(), [.requestFail(session, .outOfRange)])
    }

    func test_복귀한_뒤_다시_이탈하면_1분을_새로_센다() {
        startTracking()
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 50)
        _ = tracker.receive(sample(metersNorth: 10))
        clock.advance(by: 20)
        XCTAssertEqual(tracker.receive(sample(metersNorth: 260)), [.warnOutOfRange])
        clock.advance(by: 59)
        XCTAssertEqual(tracker.tick(), [])
        clock.advance(by: 1)
        XCTAssertEqual(tracker.tick(), [.requestFail(session, .outOfRange)])
    }

    // MARK: 20분 달성

    func test_20분_전에는_완료를_요청하지_않는다() {
        startTracking()
        clock.advance(by: 1199)
        XCTAssertEqual(tracker.receive(sample(metersNorth: 10)), [])
        XCTAssertEqual(tracker.state, .inProgress(session))
    }

    func test_20분이_되면_마지막_위치와_함께_완료를_요청한다() {
        startTracking()
        let inside = sample(metersNorth: 40)
        _ = tracker.receive(inside)
        clock.advance(by: 1200)
        XCTAssertEqual(tracker.tick(), [.requestComplete(session, at: inside.coordinate)])
        XCTAssertEqual(tracker.state, .completing(session))
    }

    func test_완료_요청은_한_번만_나간다() {
        startTracking()
        clock.advance(by: 1200)
        XCTAssertEqual(tracker.tick().count, 1)
        XCTAssertEqual(tracker.tick(), [])
        XCTAssertEqual(tracker.receive(sample(metersNorth: 10)), [])
    }

    func test_완료_응답을_받으면_completed다() {
        startTracking()
        clock.advance(by: 1200)
        _ = tracker.tick()
        tracker.completionSucceeded()
        XCTAssertEqual(tracker.state, .completed(session))
        XCTAssertFalse(tracker.state.isActive)
    }

    func test_완료가_거절되면_진행_중으로_돌아가고_10초_뒤_다시_요청한다() {
        startTracking()
        clock.advance(by: 1200)
        _ = tracker.tick()
        tracker.completionRejected()
        XCTAssertEqual(tracker.state, .inProgress(session))

        clock.advance(by: 9)
        XCTAssertEqual(tracker.tick(), [], "재시도 간격 안에는 다시 요청하지 않는다")
        clock.advance(by: 1)
        XCTAssertEqual(tracker.tick().count, 1)
    }

    func test_서버가_자정_경과로_거절하면_실패로_끝난다() {
        startTracking()
        clock.advance(by: 1200)
        _ = tracker.tick()
        tracker.completionFailed(.midnight)
        XCTAssertEqual(tracker.state, .failed(session, .midnight))
    }

    func test_완료_요청_중이_아니면_서버_거절은_무시한다() {
        startTracking()
        tracker.completionFailed(.midnight)
        tracker.completionAbandoned()
        XCTAssertEqual(tracker.state, .inProgress(session))
    }

    func test_이미_받은_공원이면_배지_없이_취소로_끝낸다() {
        startTracking()
        clock.advance(by: 1200)
        _ = tracker.tick()
        tracker.completionAbandoned()
        XCTAssertEqual(tracker.state, .cancelled(session))
    }

    func test_이탈한_채_20분이_되어도_복귀하기_전에는_완료하지_않는다() {
        startTracking()
        clock.advance(by: 1180)
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 30)
        XCTAssertEqual(tracker.tick(), [])
        XCTAssertEqual(tracker.state.session, session)
    }

    func test_이탈한_뒤_복귀했을_때_이미_20분이_지났으면_바로_완료를_요청한다() {
        startTracking()
        clock.advance(by: 1180)
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 30)
        let effects = tracker.receive(sample(metersNorth: 10))
        XCTAssertEqual(effects.first, .clearOutOfRangeWarning)
        if case .requestComplete = effects.last {} else { XCTFail("완료를 요청해야 한다: \(effects)") }
    }

    // MARK: 정확도

    func test_정확도가_100m보다_나쁜_위치는_무시한다() {
        startTracking()
        XCTAssertEqual(tracker.receive(sample(metersNorth: 900, accuracy: 101)), [])
        XCTAssertEqual(tracker.state, .inProgress(session), "튀는 위치로 이탈 처리하면 안 된다")
    }

    func test_정확도_100m는_사용한다() {
        startTracking()
        XCTAssertEqual(tracker.receive(sample(metersNorth: 900, accuracy: 100)), [.warnOutOfRange])
    }

    func test_정확도가_음수인_위치는_무시한다() {
        startTracking()
        XCTAssertEqual(tracker.receive(sample(metersNorth: 900, accuracy: -1)), [])
        XCTAssertEqual(tracker.state, .inProgress(session))
    }

    func test_정확도가_나빠도_시간_판정은_한다() {
        startTracking()
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 61)
        XCTAssertEqual(tracker.receive(sample(metersNorth: 10, accuracy: 500)), [.requestFail(session, .outOfRange)])
    }

    // MARK: 자정

    func test_자정이_되면_진행_중인_체크인은_실패한다() {
        session = makeSession(startedAt: kst("2026-11-04T23:50:00+09:00"))
        clock.set(kst("2026-11-04T23:50:00+09:00"))
        startTracking()
        clock.set(kst("2026-11-05T00:00:00+09:00"))
        XCTAssertEqual(tracker.tick(), [.requestFail(session, .midnight)])
        XCTAssertEqual(tracker.state, .failed(session, .midnight))
    }

    func test_자정_1초_전에는_실패하지_않는다() {
        session = makeSession(startedAt: kst("2026-11-04T23:50:00+09:00"))
        clock.set(kst("2026-11-04T23:50:00+09:00"))
        startTracking()
        clock.set(kst("2026-11-04T23:59:59+09:00"))
        XCTAssertEqual(tracker.tick(), [])
        XCTAssertEqual(tracker.state, .inProgress(session))
    }

    func test_자정을_넘겨_20분을_채워도_완료가_아니라_자정_실패다() {
        session = makeSession(startedAt: kst("2026-11-04T23:45:00+09:00"))
        clock.set(kst("2026-11-04T23:45:00+09:00"))
        startTracking()
        clock.set(kst("2026-11-05T00:06:00+09:00"))
        XCTAssertEqual(tracker.tick(), [.requestFail(session, .midnight)])
    }

    func test_이탈_중에_자정이_되어도_자정_실패다() {
        session = makeSession(startedAt: kst("2026-11-04T23:55:00+09:00"))
        clock.set(kst("2026-11-04T23:55:00+09:00"))
        startTracking()
        clock.set(kst("2026-11-04T23:59:30+09:00"))
        _ = tracker.receive(sample(metersNorth: 260))
        clock.set(kst("2026-11-05T00:00:10+09:00"))
        XCTAssertEqual(tracker.tick(), [.requestFail(session, .midnight)])
    }

    func test_자정_판정은_UTC가_아니라_한국_시간_기준이다() {
        // 08:00 KST는 UTC로는 전날 23:00이다. UTC 기준으로 날짜를 비교하면 10:00 KST에 자정 실패로 잘못 판정된다.
        session = makeSession(startedAt: kst("2026-11-04T08:00:00+09:00"))
        clock.set(kst("2026-11-04T08:00:00+09:00"))
        startTracking()
        clock.set(kst("2026-11-04T10:00:00+09:00"))
        if case .completing = {
            _ = tracker.tick()
            return tracker.state
        }() {} else { XCTFail("같은 한국 날짜이므로 자정 실패가 아니라 완료 요청이어야 한다: \(tracker.state)") }
    }

    // MARK: 취소·복구

    func test_취소하면_서버에_알린다() {
        startTracking()
        XCTAssertEqual(tracker.cancel(), [.requestCancel(session)])
        XCTAssertEqual(tracker.state, .cancelled(session))
    }

    func test_이탈_중에도_취소할_수_있다() {
        startTracking()
        _ = tracker.receive(sample(metersNorth: 260))
        XCTAssertEqual(tracker.cancel(), [.requestCancel(session)])
    }

    func test_진행_중이_아니면_취소할_수_없다() {
        XCTAssertEqual(tracker.cancel(), [])
        XCTAssertEqual(tracker.state, .idle)
    }

    func test_강제_종료_후_재실행하면_실패_처리한다() {
        XCTAssertEqual(tracker.recoverAfterTermination(of: session), [.requestFail(session, .appTerminated)])
        XCTAssertEqual(tracker.state, .failed(session, .appTerminated))
    }

    func test_이미_진행_중이면_복구_요청을_무시한다() {
        startTracking()
        XCTAssertEqual(tracker.recoverAfterTermination(of: session), [])
        XCTAssertEqual(tracker.state, .inProgress(session))
    }

    // MARK: 종료 후

    func test_끝난_뒤에는_위치와_시간_입력을_무시한다() {
        startTracking()
        _ = tracker.receive(sample(metersNorth: 260))
        clock.advance(by: 61)
        _ = tracker.tick()
        XCTAssertEqual(tracker.state, .failed(session, .outOfRange))
        XCTAssertEqual(tracker.receive(sample(metersNorth: 10)), [])
        XCTAssertEqual(tracker.tick(), [])
        XCTAssertEqual(tracker.state, .failed(session, .outOfRange))
    }

    func test_실패한_뒤에는_다시_시작할_수_있다() {
        startTracking()
        _ = tracker.cancel()
        let again = makeSession(startedAt: clock.now)
        XCTAssertTrue(tracker.start(again))
        XCTAssertEqual(tracker.state, .inProgress(again))
    }

    func test_reset하면_idle로_돌아간다() {
        startTracking()
        _ = tracker.cancel()
        tracker.reset()
        XCTAssertEqual(tracker.state, .idle)
    }

    func test_진행_중에는_reset해도_유지된다() {
        startTracking()
        tracker.reset()
        XCTAssertEqual(tracker.state, .inProgress(session))
    }
}

final class CoordinateTests: XCTestCase {
    func test_같은_좌표의_거리는_0이다() {
        let c = Coordinate(latitude: 37.5, longitude: 127.0)
        XCTAssertEqual(c.distance(to: c), 0, accuracy: 0.001)
    }

    func test_위도_0_001도는_약_111m다() {
        let a = Coordinate(latitude: 37.5, longitude: 127.0)
        let b = Coordinate(latitude: 37.501, longitude: 127.0)
        XCTAssertEqual(a.distance(to: b), 111.2, accuracy: 0.5)
    }

    func test_서울_시청에서_강남역은_약_9km다() {
        let cityHall = Coordinate(latitude: 37.5663, longitude: 126.9779)
        let gangnam = Coordinate(latitude: 37.4979, longitude: 127.0276)
        XCTAssertEqual(cityHall.distance(to: gangnam), 8_800, accuracy: 400)
    }
}
