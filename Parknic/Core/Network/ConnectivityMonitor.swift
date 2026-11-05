import Foundation
import Network
import Observation

/// 네트워크 연결 상태를 알려주는 원천. 테스트에서는 가짜로 바꾼다.
@MainActor
protocol ConnectivitySource {
    /// 연결되면 true, 끊기면 false. 시작할 때 현재 상태를 한 번 알려준다.
    func updates() -> AsyncStream<Bool>
}

@MainActor
final class NWPathConnectivitySource: ConnectivitySource {
    func updates() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in continuation.yield(path.status == .satisfied) }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "com.seongmo.parknic.connectivity"))
        }
    }
}

/// 연결이 끊기면 안내를 보여준다. 잠깐 끊겼다 돌아오는 경우(엘리베이터 등)에 깜빡이지 않게 일정 시간 끊겨 있을 때만 보인다.
@MainActor @Observable
final class ConnectivityMonitor {
    /// 안내를 보여줄지
    private(set) var showsOfflineNotice = false

    private let source: ConnectivitySource
    private let offlineDelay: Duration
    private let sleep: @Sendable (Duration) async throws -> Void
    private var pendingNotice: Task<Void, Never>?

    init(
        source: ConnectivitySource, offlineDelay: Duration = .seconds(1),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.source = source
        self.offlineDelay = offlineDelay
        self.sleep = sleep
    }

    /// 화면이 나타날 때 한 번 부른다. 상태가 끝날 때까지 계속 처리한다.
    func run() async {
        for await isOnline in source.updates() {
            handle(isOnline: isOnline)
        }
    }

    func handle(isOnline: Bool) {
        pendingNotice?.cancel()
        pendingNotice = nil
        if isOnline {
            showsOfflineNotice = false
            return
        }
        pendingNotice = Task { [offlineDelay, sleep] in
            try? await sleep(offlineDelay)
            guard !Task.isCancelled else { return }
            showsOfflineNotice = true
        }
    }
}
