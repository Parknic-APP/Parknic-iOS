import XCTest
@testable import Parknic

@MainActor
private final class FakeConnectivity: ConnectivitySource {
    private var continuation: AsyncStream<Bool>.Continuation?
    func updates() -> AsyncStream<Bool> { AsyncStream { self.continuation = $0 } }
    func send(_ online: Bool) { continuation?.yield(online) }
    func finish() { continuation?.finish() }
}

@MainActor
final class ConnectivityMonitorTests: XCTestCase {
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<300 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }

    func test_연결이_있으면_안내를_보이지_않는다() {
        let monitor = ConnectivityMonitor(source: FakeConnectivity(), offlineDelay: .zero)
        monitor.handle(isOnline: true)
        XCTAssertFalse(monitor.showsOfflineNotice)
    }

    func test_끊긴_상태가_이어지면_안내를_보인다() async {
        let monitor = ConnectivityMonitor(source: FakeConnectivity(), offlineDelay: .milliseconds(10))
        monitor.handle(isOnline: false)
        XCTAssertFalse(monitor.showsOfflineNotice, "바로 보이지 않고 잠깐 기다린다")
        await waitUntil { monitor.showsOfflineNotice }
        XCTAssertTrue(monitor.showsOfflineNotice)
    }

    func test_잠깐_끊겼다_돌아오면_안내가_깜빡이지_않는다() async {
        let monitor = ConnectivityMonitor(source: FakeConnectivity(), offlineDelay: .milliseconds(100))
        monitor.handle(isOnline: false)
        try? await Task.sleep(for: .milliseconds(20))
        monitor.handle(isOnline: true)
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(monitor.showsOfflineNotice)
    }

    func test_다시_연결되면_안내가_사라진다() async {
        let monitor = ConnectivityMonitor(source: FakeConnectivity(), offlineDelay: .milliseconds(5))
        monitor.handle(isOnline: false)
        await waitUntil { monitor.showsOfflineNotice }
        monitor.handle(isOnline: true)
        XCTAssertFalse(monitor.showsOfflineNotice)
    }

    func test_끊김이_반복되어도_마지막_상태를_따른다() async {
        let monitor = ConnectivityMonitor(source: FakeConnectivity(), offlineDelay: .milliseconds(20))
        monitor.handle(isOnline: false)
        monitor.handle(isOnline: false)
        monitor.handle(isOnline: true)
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertFalse(monitor.showsOfflineNotice)
    }

    func test_원천의_상태_변화를_따라간다() async {
        let source = FakeConnectivity()
        let monitor = ConnectivityMonitor(source: source, offlineDelay: .milliseconds(5))
        let task = Task { await monitor.run() }
        await waitUntil { true }
        try? await Task.sleep(for: .milliseconds(20))
        source.send(false)
        await waitUntil { monitor.showsOfflineNotice }
        XCTAssertTrue(monitor.showsOfflineNotice)
        source.send(true)
        await waitUntil { !monitor.showsOfflineNotice }
        XCTAssertFalse(monitor.showsOfflineNotice)
        source.finish()
        await task.value
    }
}
