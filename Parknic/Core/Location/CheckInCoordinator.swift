import Foundation
import Observation

/// 체크인 한 번의 전체 과정을 이끈다: 위치·시간 입력 → `CheckInTracker` → 서버 API·로컬 알림.
/// 화면은 `state`, `remaining`, `result`만 보면 된다.
@MainActor @Observable
final class CheckInCoordinator {
    private(set) var state: CheckInState = .idle
    /// 남은 시간(초). 진행 중이 아니면 nil.
    private(set) var remaining: TimeInterval?
    /// 반경 안에서 머문 시간(초). 실패·취소 화면의 "머문 시간"에 쓴다.
    private(set) var stayed: TimeInterval?
    /// 반경 밖에 있을 때만 값이 있다(경계에서 벗어난 거리, 돌아올 수 있는 남은 시간).
    private(set) var outOfRange: OutOfRangeInfo?
    /// 20분 달성으로 받은 결과(배지 획득 화면에 쓴다)
    private(set) var result: CheckInResult?
    /// 시작하지 못했을 때 보여줄 한국어 문구
    private(set) var startErrorMessage: String?
    private(set) var isStarting = false

    struct OutOfRangeInfo: Equatable {
        let metersOutside: Double
        let graceRemaining: TimeInterval
    }

    private var tracker: CheckInTracker

    private let repository: CheckInRepository
    private let location: LocationSampleSource
    private let notifier: CheckInNotifying
    private let store: CheckInStore
    private let tickInterval: Duration
    private let sleep: @Sendable (Duration) async throws -> Void

    private var locationTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?

    init(
        repository: CheckInRepository, location: LocationSampleSource, notifier: CheckInNotifying,
        store: CheckInStore, clock: AppClock = SystemClock(), tickInterval: Duration = .seconds(1),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.repository = repository
        self.location = location
        self.notifier = notifier
        self.store = store
        self.tracker = CheckInTracker(clock: clock)
        self.tickInterval = tickInterval
        self.sleep = sleep
    }

    // MARK: 화면에서 부르는 동작

    /// 체크인을 시작한다. 시작·완료 시점의 좌표만 서버로 보낸다.
    func begin(parkID: Int, at coordinate: Coordinate) async {
        guard !isStarting, !state.isActive else { return }
        isStarting = true
        startErrorMessage = nil
        defer { isStarting = false }

        do {
            let session = try await repository.start(parkID: parkID, at: coordinate)
            result = nil
            tracker.reset()
            tracker.start(session, at: coordinate)
            store.save(session)
            sync()
            startMeasuring()
        } catch {
            startErrorMessage = (error as? APIError)?.userMessage ?? APIError.network.userMessage
        }
    }

    /// 사용자 취소(확인 다이얼로그 이후에 부른다)
    func cancel() async {
        await handle(tracker.cancel())
    }

    /// 앱을 다시 실행했을 때 한 번 부른다. 끊긴 측정을 실패 처리하고 사용자에게 알릴 수 있게 한다.
    func recoverOnLaunch() async {
        guard !state.isActive else { return }
        // 기기에 저장된 세션을 우선하고, 없으면 서버에 진행 중인 세션을 묻는다.
        let saved = store.load()
        let remote = saved == nil ? (try? await repository.current()) : nil
        guard let session = saved ?? remote else { return }
        await handle(tracker.recoverAfterTermination(of: session))
    }

    /// 결과·실패 안내를 닫고 처음 상태로 돌아간다.
    func dismiss() {
        tracker.reset()
        result = nil
        sync()
    }

    /// 주기적으로 불린다(위치 업데이트가 없어도 이탈·자정·20분 판정을 하기 위해).
    func tick() async {
        await handle(tracker.tick())
    }

    // MARK: 입력 연결

    private func startMeasuring() {
        locationTask?.cancel()
        tickTask?.cancel()
        let samples = location.start()
        locationTask = Task { [weak self] in
            for await sample in samples {
                guard let self else { return }
                await self.receive(sample)
            }
        }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let interval = self?.tickInterval, let sleep = self?.sleep else { return }
                try? await sleep(interval)
                if Task.isCancelled { return }
                await self?.tick()
            }
        }
    }

    private func stopMeasuring() {
        locationTask?.cancel()
        tickTask?.cancel()
        locationTask = nil
        tickTask = nil
        location.stop()
    }

    private func receive(_ sample: LocationSample) async {
        await handle(tracker.receive(sample))
    }

    // MARK: 효과 처리

    private func handle(_ effects: [CheckInEffect]) async {
        sync()
        for effect in effects {
            switch effect {
            case .warnOutOfRange:
                await notifier.warnOutOfRange()
            case .clearOutOfRangeWarning:
                await notifier.clearOutOfRangeWarning()
            case .requestComplete(let session, let coordinate, let pausedSeconds):
                await complete(session, at: coordinate, pausedSeconds: pausedSeconds)
            case .requestFail(let session, let reason):
                // 서버 기록은 최선을 다하되, 실패해도 사용자 흐름은 막지 않는다(서버가 세션을 만료시킨다).
                try? await repository.fail(sessionID: session.id, reason: reason)
            case .requestCancel(let session):
                try? await repository.cancel(sessionID: session.id)
            }
        }
        sync()
        if !state.isActive {
            stopMeasuring()
            store.clear()
        }
    }

    private func complete(_ session: CheckInSession, at coordinate: Coordinate?, pausedSeconds: Int) async {
        do {
            let result = try await repository.complete(
                sessionID: session.id, at: coordinate, pausedSeconds: pausedSeconds)
            tracker.completionSucceeded()
            self.result = result
            await notifier.clearOutOfRangeWarning()
            await notifier.notifyEarned(parkName: session.parkName)
        } catch let error as APIError {
            switch error.serverCode {
            case .checkInExpiredMidnight: tracker.completionFailed(.midnight)
            case .checkInOutOfRange: tracker.completionFailed(.outOfRange)
            case .badgeAlreadyEarnedToday: tracker.completionAbandoned()
            // 서버 기준으로 아직 20분 미달이거나 연결 문제면 잠시 뒤 다시 요청한다.
            default: tracker.completionRejected()
            }
        } catch {
            tracker.completionRejected()
        }
    }

    private func sync() {
        state = tracker.state
        remaining = tracker.remaining
        stayed = tracker.stayed
        if let meters = tracker.metersOutside, let grace = tracker.outOfRangeGraceRemaining {
            outOfRange = OutOfRangeInfo(metersOutside: meters, graceRemaining: grace)
        } else {
            outOfRange = nil
        }
    }
}
