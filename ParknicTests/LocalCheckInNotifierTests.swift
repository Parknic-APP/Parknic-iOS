import XCTest
@testable import Parknic

private final class FakeScheduler: NotificationScheduling, @unchecked Sendable {
    struct Added: Equatable { let identifier: String; let title: String; let body: String }
    private let lock = NSLock()
    private var _added: [Added] = []
    private var _removed: [[String]] = []
    var added: [Added] { lock.withLock { _added } }
    var removed: [[String]] { lock.withLock { _removed } }

    func add(identifier: String, title: String, body: String) async {
        lock.withLock { _added.append(Added(identifier: identifier, title: title, body: body)) }
    }

    func remove(identifiers: [String]) async {
        lock.withLock { _removed.append(identifiers) }
    }
}

final class LocalCheckInNotifierTests: XCTestCase {
    func test_이탈하면_1분_안에_돌아오라는_경고를_보낸다() async {
        let scheduler = FakeScheduler()
        await LocalCheckInNotifier(scheduler: scheduler).warnOutOfRange()
        XCTAssertEqual(
            scheduler.added,
            [.init(identifier: "checkin.out-of-range", title: "공원을 벗어났어요", body: "1분 안에 공원으로 돌아오세요")])
    }

    func test_복귀하면_이탈_경고만_거둔다() async {
        let scheduler = FakeScheduler()
        await LocalCheckInNotifier(scheduler: scheduler).clearOutOfRangeWarning()
        XCTAssertEqual(scheduler.removed, [["checkin.out-of-range"]])
        XCTAssertTrue(scheduler.added.isEmpty)
    }

    func test_20분을_채우면_공원_이름과_함께_알린다() async {
        let scheduler = FakeScheduler()
        await LocalCheckInNotifier(scheduler: scheduler).notifyEarned(parkName: "보라매공원")
        XCTAssertEqual(
            scheduler.added,
            [.init(identifier: "checkin.earned", title: "배지를 받았어요", body: "보라매공원에서 20분을 채웠어요")])
    }

    func test_경고와_달성_알림은_서로_다른_식별자를_쓴다() {
        XCTAssertNotEqual(LocalCheckInNotifier.outOfRangeIdentifier, LocalCheckInNotifier.earnedIdentifier)
    }
}
