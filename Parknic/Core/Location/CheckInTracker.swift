import Foundation

/// 체크인 상태 머신. 위치와 시간 입력을 받아 상태를 바꾸고, 바깥에 시킬 일(`CheckInEffect`)을 돌려준다.
///
/// - 경과 시간은 앱 타이머가 아니라 서버가 준 시작 시각과 현재 시각의 차이로 계산하고,
///   반경 밖에 있던 시간은 뺀다(밖에 있는 동안 타이머가 멈춘다).
/// - 시간 입력은 `AppClock`으로 받으므로 테스트에서 시각을 고정할 수 있다.
/// - 최종 판정은 서버가 한다. 트래커는 조건이 맞으면 `complete`를 요청할 뿐이다.
/// - 좌표는 보관하지 않는다(마지막 위치 한 건만 완료 요청에 쓴다).
struct CheckInTracker {
    /// 연속 체류해야 하는 시간
    static let requiredDuration: TimeInterval = {
        #if DEBUG
        // 개발용: 줄여서 시험한다(서버 로컬 설정과 맞춰야 한다). Release에는 없다.
        if let seconds = AppConfig.devCheckInRequiredSeconds { return seconds }
        #endif
        return 20 * 60
    }()
    /// 반경 이탈 후 복귀할 수 있는 시간
    static let outOfRangeGracePeriod: TimeInterval = 60
    /// 이 값보다 부정확한 위치는 무시한다(GPS 튐 방지).
    static let maxHorizontalAccuracy: Double = 100
    /// 완료 요청이 거절된 뒤 다시 요청하기까지의 간격(요청 폭주 방지)
    static let completionRetryInterval: TimeInterval = 10

    private(set) var state: CheckInState = .idle

    private let clock: AppClock
    private var lastKnownCoordinate: Coordinate?
    private var completionRetryAfter: Date?
    /// 반경 밖에 있었던 시간의 합(복귀를 마친 구간만). 이 시간은 20분에 포함하지 않는다.
    private var pausedDuration: TimeInterval = 0
    /// 끝난 체크인의 머문 시간(실패·취소 화면에 보여준다)
    private var endedStayed: TimeInterval?

    init(clock: AppClock = SystemClock()) {
        self.clock = clock
    }

    // MARK: 조회

    /// 남은 시간(초). 진행 중이 아니면 nil. 반경 밖에 있는 동안은 줄어들지 않는다.
    var remaining: TimeInterval? {
        guard state.isActive else { return nil }
        return max(0, Self.requiredDuration - effectiveElapsed(at: clock.now))
    }

    /// 지금까지 반경 안에서 머문 시간(초). 진행 중이면 현재 값, 끝났으면 끝난 시점의 값, 알 수 없으면 nil.
    var stayed: TimeInterval? {
        state.isActive ? effectiveElapsed(at: clock.now) : endedStayed
    }

    /// 마지막으로 확인된 위치가 공원 경계에서 벗어난 거리(m). 반경 밖에 있을 때만 값이 있다.
    var metersOutside: Double? {
        guard case .outOfRange(let session, _) = state, let coordinate = lastKnownCoordinate else { return nil }
        return max(0, session.center.distance(to: coordinate) - session.radiusM)
    }

    /// 돌아올 수 있는 남은 시간(초). 반경 밖에 있을 때만 값이 있다.
    var outOfRangeGraceRemaining: TimeInterval? {
        guard case .outOfRange(_, let since) = state else { return nil }
        return max(0, Self.outOfRangeGracePeriod - clock.now.timeIntervalSince(since))
    }

    /// 서버에 알릴 반경 밖 체류 시간(초)
    var pausedSeconds: Int { Int(pausedDuration.rounded()) }

    /// 시작 시각부터 `date`까지의 시간에서 반경 밖에 있던 시간을 뺀 값.
    private func effectiveElapsed(at date: Date) -> TimeInterval {
        guard let session = state.session else { return 0 }
        var elapsed = date.timeIntervalSince(session.startedAt) - pausedDuration
        if case .outOfRange(_, let since) = state {
            elapsed -= max(0, date.timeIntervalSince(since))
        }
        return max(0, elapsed)
    }

    /// 끝난 상태로 바꾸면서 머문 시간을 기록한다.
    private mutating func end(_ newState: CheckInState, stayedAt date: Date? = nil) {
        endedStayed = effectiveElapsed(at: date ?? clock.now)
        state = newState
    }

    // MARK: 시작·종료

    /// 체크인을 시작한다. 동시에 체크인할 수 있는 공원은 1곳이므로 진행 중이면 무시하고 false를 돌려준다.
    @discardableResult
    mutating func start(_ session: CheckInSession, at coordinate: Coordinate? = nil) -> Bool {
        guard !state.isActive else { return false }
        lastKnownCoordinate = coordinate
        completionRetryAfter = nil
        pausedDuration = 0
        endedStayed = nil
        state = .inProgress(session)
        return true
    }

    /// 사용자 취소
    mutating func cancel() -> [CheckInEffect] {
        switch state {
        case .inProgress(let session), .outOfRange(let session, _):
            end(.cancelled(session))
            return [.requestCancel(session)]
        default:
            return []
        }
    }

    /// 앱이 강제 종료됐다가 다시 실행된 경우. 측정이 끊겼으므로 실패 처리한다.
    mutating func recoverAfterTermination(of session: CheckInSession) -> [CheckInEffect] {
        guard !state.isActive else { return [] }
        endedStayed = nil
        state = .failed(session, .appTerminated)
        return [.requestFail(session, .appTerminated)]
    }

    /// 완료·실패·취소 후 처음 상태로 돌아간다.
    mutating func reset() {
        guard !state.isActive else { return }
        state = .idle
        lastKnownCoordinate = nil
        completionRetryAfter = nil
        pausedDuration = 0
        endedStayed = nil
    }

    // MARK: 서버 응답

    /// `complete` 요청이 성공했다.
    mutating func completionSucceeded() {
        guard case .completing(let session) = state else { return }
        end(.completed(session))
    }

    /// `complete` 요청이 거절됐다(예: 서버 기준으로 아직 20분 미달). 진행 중으로 돌아가 잠시 뒤 다시 시도한다.
    mutating func completionRejected() {
        guard case .completing(let session) = state else { return }
        completionRetryAfter = clock.now.addingTimeInterval(Self.completionRetryInterval)
        state = .inProgress(session)
    }

    /// 서버가 완료 요청을 거절하며 세션이 끝났다고 알려준 경우(자정 경과, 서버 기준 반경 밖)
    mutating func completionFailed(_ reason: CheckInFailureReason) {
        guard case .completing(let session) = state else { return }
        end(.failed(session, reason))
    }

    /// 배지 없이 세션만 끝난 경우(예: 이미 오늘 받은 공원)
    mutating func completionAbandoned() {
        guard case .completing(let session) = state else { return }
        end(.cancelled(session))
    }

    // MARK: 입력

    /// 위치가 들어왔다. 정확도가 낮은 샘플은 위치로는 무시하지만 시간 판정은 항상 한다.
    mutating func receive(_ sample: LocationSample) -> [CheckInEffect] {
        guard state.isActive else { return [] }
        var effects = evaluateTime()
        guard state.isActive else { return effects }
        guard sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= Self.maxHorizontalAccuracy else {
            return effects
        }
        lastKnownCoordinate = sample.coordinate
        effects += applyLocation(sample.coordinate)
        return effects
    }

    /// 시간이 흘렀다. 위치 업데이트가 없어도(가만히 서 있어도) 주기적으로 호출한다.
    mutating func tick() -> [CheckInEffect] {
        guard state.isActive else { return [] }
        return evaluateTime()
    }

    // MARK: 내부

    private mutating func applyLocation(_ coordinate: Coordinate) -> [CheckInEffect] {
        switch state {
        case .inProgress(let session):
            guard !isInside(session, coordinate) else { return evaluateCompletion() }
            state = .outOfRange(session, since: clock.now)
            return [.warnOutOfRange]
        case .outOfRange(let session, let since):
            guard isInside(session, coordinate) else { return [] }
            // 돌아왔으니 밖에 있던 시간만큼은 20분에서 제외한다.
            pausedDuration += max(0, clock.now.timeIntervalSince(since))
            state = .inProgress(session)
            return [.clearOutOfRangeWarning] + evaluateCompletion()
        default:
            return []
        }
    }

    /// 우선순위: 자정 실패 → 이탈 1분 경과 실패 → 20분 달성
    private mutating func evaluateTime() -> [CheckInEffect] {
        let now = clock.now
        guard let session = state.session else { return [] }

        let midnight = Calendar.kst.startOfDay(for: now)
        if midnight > session.startedAt {
            // 판정이 늦어도 머문 시간은 자정까지만 센다.
            end(.failed(session, .midnight), stayedAt: midnight)
            return [.requestFail(session, .midnight)]
        }
        if case .outOfRange(_, let since) = state,
            now.timeIntervalSince(since) >= Self.outOfRangeGracePeriod
        {
            end(.failed(session, .outOfRange))
            return [.requestFail(session, .outOfRange)]
        }
        return evaluateCompletion()
    }

    /// 반경 안에서 20분을 채웠으면 완료를 요청한다.
    private mutating func evaluateCompletion() -> [CheckInEffect] {
        guard case .inProgress(let session) = state else { return [] }
        let now = clock.now
        guard effectiveElapsed(at: now) >= Self.requiredDuration else { return [] }
        if let retryAfter = completionRetryAfter, now < retryAfter { return [] }
        state = .completing(session)
        return [.requestComplete(session, at: lastKnownCoordinate, pausedSeconds: pausedSeconds)]
    }

    private func isInside(_ session: CheckInSession, _ coordinate: Coordinate) -> Bool {
        session.center.distance(to: coordinate) <= session.radiusM
    }
}
