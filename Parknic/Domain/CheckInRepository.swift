protocol CheckInRepository: Sendable {
    /// 체크인을 시작한다. 서버가 시작 시각(`startedAt`)과 판정 반경을 정해 돌려준다.
    func start(parkID: Int, at coordinate: Coordinate) async throws -> CheckInSession
    /// 서버에 진행 중인 세션. 없으면 nil.
    func current() async throws -> CheckInSession?
    /// 20분 달성 후 완료를 요청한다. 최종 판정은 서버가 한다.
    func complete(sessionID: Int, at coordinate: Coordinate?) async throws -> CheckInResult
    func fail(sessionID: Int, reason: CheckInFailureReason) async throws
    func cancel(sessionID: Int) async throws
}
