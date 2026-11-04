/// 위치 입력. 실제 구현(CoreLocation)은 따로 두고, 코디네이터는 이 프로토콜에만 의존한다.
@MainActor
protocol LocationSampleSource {
    /// 위치 수신을 시작하고 샘플 스트림을 돌려준다. `stop()`을 부르면 스트림이 끝난다.
    func start() -> AsyncStream<LocationSample>
    func stop()
}

/// 체크인 중 보내는 로컬 알림
protocol CheckInNotifying: Sendable {
    /// 즉시 경고 "1분 안에 공원으로 돌아오세요"
    func warnOutOfRange() async
    /// 복귀했으니 경고를 거둔다
    func clearOutOfRangeWarning() async
    /// 20분 달성(앱이 백그라운드여도 보인다)
    func notifyEarned(parkName: String) async
}
